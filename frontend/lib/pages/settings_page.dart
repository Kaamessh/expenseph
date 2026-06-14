import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../services/translations.dart';
import '../services/notification_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _urlController = TextEditingController();
  bool _testingConnection = false;
  String? _testStatus;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    final apiConfig = Provider.of<ApiConfig>(context, listen: false);
    _urlController.text = apiConfig.baseUrl;
  }

  Future<void> _testConnection() async {
    setState(() {
      _testingConnection = true;
      _testStatus = 'Testing...';
      _isSuccess = false;
    });

    final testUrl = _urlController.text.trim();
    try {
      final response = await http.get(Uri.parse(testUrl)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        final status = body['status'] ?? 'unknown';
        final mode = body['mode'] ?? 'unknown';
        
        setState(() {
          _testingConnection = false;
          _isSuccess = true;
          _testStatus = 'Success! API Status: $status (Mode: $mode)';
        });
      } else {
        setState(() {
          _testingConnection = false;
          _isSuccess = false;
          _testStatus = 'Failed: HTTP Status ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _testingConnection = false;
        _isSuccess = false;
        _testStatus = 'Connection error: Could not reach the API. Make sure it is running.';
      });
    }
  }

  void _saveSettings() {
    final newUrl = _urlController.text.trim();
    if (newUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTranslations.t(context, 'api_url_empty'))),
      );
      return;
    }
    
    Provider.of<ApiConfig>(context, listen: false).updateBaseUrl(newUrl);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppTranslations.t(context, 'save_settings_success')),
        backgroundColor: Colors.cyan,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121218),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Settings Header
            Card(
              color: const Color(0xFF1E1E2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.settings_suggest, color: Colors.cyan, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          AppTranslations.t(context, 'sys_config'),
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppTranslations.t(context, 'config_desc'),
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Preferences Card (Language & Notifications)
            Card(
              color: const Color(0xFF1E1E2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Consumer<ApiConfig>(
                  builder: (context, apiConfig, child) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.translate, color: Colors.cyan, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              AppTranslations.t(context, 'language'),
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: apiConfig.languageCode,
                          dropdownColor: const Color(0xFF1E1E2E),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF12121F),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: const BorderSide(color: Colors.cyan),
                            ),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'en',
                              child: Text(AppTranslations.t(context, 'english')),
                            ),
                            DropdownMenuItem(
                              value: 'ta',
                              child: Text(AppTranslations.t(context, 'tamil')),
                            ),
                          ],
                          onChanged: (String? value) {
                            if (value != null) {
                              apiConfig.updateLanguage(value);
                            }
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Icon(Icons.notifications_active_outlined, color: Colors.cyan, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              AppTranslations.t(context, 'notifications'),
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          title: Text(
                            AppTranslations.t(context, apiConfig.notificationsEnabled ? 'on' : 'off'),
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          value: apiConfig.notificationsEnabled,
                          activeColor: Colors.cyanAccent,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (bool value) async {
                            apiConfig.updateNotifications(value);
                            if (value) {
                              await AppNotificationService.requestPermissions();
                              try {
                                final apiService = ApiService(apiConfig);
                                final debts = await apiService.getDebts();
                                await AppNotificationService.scheduleDebtReminders(debts, true);
                              } catch (_) {}
                            } else {
                              await AppNotificationService.cancelAll();
                            }
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Base URL Form Card
            Card(
              color: const Color(0xFF1E1E2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppTranslations.t(context, 'backend_settings'),
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _urlController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: AppTranslations.t(context, 'api_base_url'),
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.link, color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF12121F),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(color: Colors.cyan),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Actions Row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _testingConnection ? null : _testConnection,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.cyan,
                              side: const BorderSide(color: Colors.cyan),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                            ),
                            icon: _testingConnection
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyan))
                                : const Icon(Icons.sync, size: 18),
                            label: Text(AppTranslations.t(context, 'test_connection'), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saveSettings,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyan,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                            ),
                            icon: const Icon(Icons.save, size: 18),
                            label: Text(AppTranslations.t(context, 'save_url'), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),

                    if (_testStatus != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isSuccess ? Colors.green.withOpacity(0.15) : Colors.redAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _isSuccess ? Colors.green : Colors.redAccent, width: 0.5),
                        ),
                        child: Text(
                          _testStatus!,
                          style: TextStyle(
                            color: _isSuccess ? Colors.greenAccent : Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                      )
                    ]
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Help section
            Card(
              color: const Color(0xFF1E1E2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppTranslations.t(context, 'setup_inst'),
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildHelpBullet('1. Deploy your backend project to Vercel or run it locally.'),
                    _buildHelpBullet('2. For local emulator testing: use http://10.0.2.2:8000 for Android or http://127.0.0.1:8000 for iOS and Web.'),
                    _buildHelpBullet('3. For Vercel production: paste your vercel project deployment URL (e.g. https://your-app.vercel.app).'),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildHelpBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.arrow_right, color: Colors.cyan, size: 20),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          )
        ],
      ),
    );
  }
}
