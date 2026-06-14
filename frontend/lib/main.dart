import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ota_update/ota_update.dart';
import 'services/api_service.dart';
import 'services/translations.dart';
import 'services/notification_service.dart';
import 'pages/dashboard_page.dart';
import 'pages/debt_page.dart';
import 'pages/reports_page.dart';
import 'pages/settings_page.dart';
import 'pages/auth_page.dart';
import 'pages/profile_page.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ApiConfig(),
      child: const ExpenseDebtTrackerApp(),
    ),
  );
}

class ExpenseDebtTrackerApp extends StatelessWidget {
  const ExpenseDebtTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiConfig = Provider.of<ApiConfig>(context);
    return MaterialApp(
      title: 'Expense & Debt Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: Colors.cyan,
        colorScheme: const ColorScheme.dark(
          primary: Colors.cyan,
          secondary: Colors.cyanAccent,
          background: Color(0xFF121218),
          surface: Color(0xFF1E1E2E),
        ),
        scaffoldBackgroundColor: const Color(0xFF121218),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E2E),
          elevation: 0,
          foregroundColor: Colors.white,
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Color(0xFF1E1E2E),
        ),
      ),
      home: const MainHomeWrapper(),
    );
  }
}

class MainHomeWrapper extends StatefulWidget {
  const MainHomeWrapper({super.key});

  @override
  State<MainHomeWrapper> createState() => _MainHomeWrapperState();
}

class _MainHomeWrapperState extends State<MainHomeWrapper> {
  static const String appVersion = "3.0.0"; // Local version of the app
  bool _checkedUpdate = false;

  @override
  void initState() {
    super.initState();
    AppNotificationService.init();
    if (!kIsWeb) {
      // Check for updates on mobile devices after a short delay
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkForUpdates();
        AppNotificationService.requestPermissions();
      });
    }
  }

  Future<void> _checkForUpdates() async {
    if (_checkedUpdate) return;
    try {
      final config = Provider.of<ApiConfig>(context, listen: false);
      final response = await http.get(Uri.parse('${config.baseUrl}/api/version'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final latestVersion = data['version'] as String;
        final apkUrl = data['apk_url'] as String;

        if (_isNewerVersion(latestVersion, appVersion)) {
          _checkedUpdate = true;
          _showUpdateDialog(latestVersion, apkUrl);
        }
      }
    } catch (_) {
      // Silently ignore update check errors to avoid disrupting user
    }
  }

  bool _isNewerVersion(String latest, String current) {
    List<int> latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      int latestVal = i < latestParts.length ? latestParts[i] : 0;
      int currentVal = i < currentParts.length ? currentParts[i] : 0;
      if (latestVal > currentVal) return true;
      if (latestVal < currentVal) return false;
    }
    return false;
  }

  void _showUpdateDialog(String version, String apkUrl) {
    showDialog(
      context: context,
      barrierDismissible: false, // Force them to choose
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFF1E1E2E),
        title: Row(
          children: [
            const Icon(Icons.system_update_rounded, color: Colors.cyanAccent),
            const SizedBox(width: 10),
            const Text(
              'Update Available!',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'A new version of the app is available (v$version).\n\nWould you like to download and install the latest update now?',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'LATER',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startOTAUpdate(apkUrl);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyan,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('UPDATE NOW', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _startOTAUpdate(String apkUrl) {
    final ValueNotifier<double> downloadProgress = ValueNotifier<double>(0.0);
    final ValueNotifier<String> statusMessage = ValueNotifier<String>('Starting update...');
    final ValueNotifier<bool> hasError = ValueNotifier<bool>(false);
    bool isClosed = false;

    final subscription = OtaUpdate()
        .execute(
      apkUrl,
      destinationFilename: 'expense_tracker_update.apk',
    )
        .listen(
      (OtaEvent event) {
        switch (event.status) {
          case OtaStatus.DOWNLOADING:
            statusMessage.value = 'Downloading update...';
            downloadProgress.value = double.tryParse(event.value ?? '0') ?? 0.0;
            break;
          case OtaStatus.INSTALLING:
            statusMessage.value = 'Preparing installation...';
            if (!isClosed) {
              isClosed = true;
              Navigator.of(context, rootNavigator: true).pop();
            }
            break;
          case OtaStatus.ALREADY_UP_TO_DATE:
            statusMessage.value = 'Already up to date.';
            break;
          case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
            statusMessage.value = 'Storage permission not granted.';
            hasError.value = true;
            break;
          case OtaStatus.DOWNLOAD_ERROR:
          case OtaStatus.INTERNAL_ERROR:
          default:
            statusMessage.value = 'Download failed: ${event.value}';
            hasError.value = true;
            break;
        }
      },
      onError: (err) {
        statusMessage.value = 'Error: $err';
        hasError.value = true;
      },
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: const Color(0xFF1E1E2E),
            title: Row(
              children: const [
                Icon(Icons.downloading, color: Colors.cyanAccent),
                SizedBox(width: 10),
                Text(
                  'Downloading Update',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            content: AnimatedBuilder(
              animation: Listenable.merge([downloadProgress, statusMessage, hasError]),
              builder: (context, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      statusMessage.value,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    if (!hasError.value) ...[
                      LinearProgressIndicator(
                        value: downloadProgress.value / 100.0,
                        backgroundColor: Colors.grey[800],
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyan),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${downloadProgress.value.toStringAsFixed(0)}%',
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          subscription.cancel();
                          Navigator.of(context, rootNavigator: true).pop();
                        },
                        child: const Text('CLOSE', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final apiConfig = Provider.of<ApiConfig>(context);
    if (!apiConfig.isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.cyanAccent),
        ),
      );
    }
    return apiConfig.isLoggedIn ? const MainNavigationShell() : const AuthPage();
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _selectedPageIndex = 0;
  static const String appVersion = "3.0.0"; // Local version of the app

  // List of page widgets
  final List<Widget> _pages = const [
    DashboardPage(),
    DebtPage(),
    SettingsPage(),
    ReportsPage(),
    ProfilePage(),
  ];

  String _getPageTitle(BuildContext context, int index) {
    switch (index) {
      case 0:
        return AppTranslations.t(context, 'transaction_dashboard');
      case 1:
        return AppTranslations.t(context, 'debt_management');
      case 2:
        return AppTranslations.t(context, 'application_settings');
      case 3:
        return AppTranslations.t(context, 'advanced_reports');
      case 4:
        return AppTranslations.t(context, 'my_user_profile');
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getPageTitle(context, _selectedPageIndex),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              // Quick helper alert about the mode
              final config = Provider.of<ApiConfig>(context, listen: false);
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('API Connection Status'),
                  content: Text('Your application is pointing to:\n\n${config.baseUrl}\n\nVerify this URL matches your backend environment in the Settings page.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    )
                  ],
                ),
              );
            },
            icon: const Icon(Icons.info_outline, color: Colors.grey),
          )
        ],
      ),
      drawer: Drawer(
        child: Consumer<ApiConfig>(
          builder: (context, apiConfig, child) {
            return Column(
              children: [
                // Drawer Header with user info
                DrawerHeader(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1E1E2E), Color(0xFF0F0F1A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.cyan.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.account_circle_outlined,
                            size: 38,
                            color: Colors.cyanAccent,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          apiConfig.email ?? 'Active Session',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          apiConfig.mobileNumber ?? '',
                          style: TextStyle(
                            fontSize: 11.0,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Drawer Navigation Links
                 _buildDrawerTile(
                   index: 4,
                   icon: Icons.person_outline,
                   selectedIcon: Icons.person,
                   label: AppTranslations.t(context, 'my_user_profile'),
                 ),
                 _buildDrawerTile(
                   index: 0,
                   icon: Icons.dashboard_outlined,
                   selectedIcon: Icons.dashboard,
                   label: AppTranslations.t(context, 'transaction_dashboard'),
                 ),
                 _buildDrawerTile(
                   index: 1,
                   icon: Icons.people_outline,
                   selectedIcon: Icons.people,
                   label: AppTranslations.t(context, 'debt_management'),
                 ),
                 _buildDrawerTile(
                   index: 3, // Group reports near debts
                   icon: Icons.bar_chart_outlined,
                   selectedIcon: Icons.bar_chart,
                   label: AppTranslations.t(context, 'advanced_reports'),
                 ),
                 _buildDrawerTile(
                   index: 2, // Settings last
                   icon: Icons.settings_outlined,
                   selectedIcon: Icons.settings,
                   label: AppTranslations.t(context, 'application_settings'),
                 ),

                const Divider(color: Colors.cyan, thickness: 0.2, indent: 16, endIndent: 16),
                
                // Logout Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                    leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                    title: Text(
                      AppTranslations.t(context, 'logout_account'),
                      style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                    ),
                    onTap: () {
                      Navigator.pop(context); // close drawer first
                      apiConfig.clearSession();
                    },
                  ),
                ),

                const Spacer(),
                
                // Footer details in drawer
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'v$appVersion • Supabase Connected',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: _pages[_selectedPageIndex],
    );
  }

  Widget _buildDrawerTile({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    final isSelected = _selectedPageIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: ListTile(
        selected: isSelected,
        selectedTileColor: Colors.cyan.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        leading: Icon(
          isSelected ? selectedIcon : icon,
          color: isSelected ? Colors.cyanAccent : Colors.grey,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[400],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () {
          setState(() {
            _selectedPageIndex = index;
          });
          Navigator.pop(context); // Close Drawer
        },
      ),
    );
  }
}
