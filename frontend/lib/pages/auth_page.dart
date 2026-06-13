import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_service.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _loginUsernameController = TextEditingController(); // email or mobile

  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _loginUsernameController.dispose();
    super.dispose();
  }

  void _showSettingsDialog() {
    final apiConfig = Provider.of<ApiConfig>(context, listen: false);
    final urlController = TextEditingController(text: apiConfig.baseUrl);
    bool testing = false;
    String? testResult;
    bool testSuccess = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> testConnection() async {
              setDialogState(() {
                testing = true;
                testResult = 'Testing connection...';
                testSuccess = false;
              });

              final testUrl = urlController.text.trim();
              try {
                final response = await http.get(Uri.parse('$testUrl/api/health')).timeout(const Duration(seconds: 5));
                if (response.statusCode == 200) {
                  final body = jsonDecode(response.body);
                  final status = body['status'] ?? 'unknown';
                  final mode = body['mode'] ?? 'unknown';
                  setDialogState(() {
                    testing = false;
                    testSuccess = true;
                    testResult = 'Success! API: $status (Mode: $mode)';
                  });
                } else {
                  setDialogState(() {
                    testing = false;
                    testSuccess = false;
                    testResult = 'Failed: HTTP Status ${response.statusCode}';
                  });
                }
              } catch (e) {
                setDialogState(() {
                  testing = false;
                  testSuccess = false;
                  testResult = 'Connection failed. Check URL & network.';
                });
              }
            }

            void save() {
              final newUrl = urlController.text.trim();
              if (newUrl.isNotEmpty) {
                apiConfig.updateBaseUrl(newUrl);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('API URL updated successfully!'),
                    backgroundColor: Colors.cyan,
                  ),
                );
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.api_rounded, color: Colors.cyanAccent),
                  SizedBox(width: 10),
                  Text('API Configuration', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Set the API URL for your backend server. Use your Vercel URL on mobile devices.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: urlController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'API Base URL',
                      labelStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFF121218),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.cyan.withOpacity(0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.cyan.withOpacity(0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.cyanAccent, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                  if (testResult != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      testResult!,
                      style: TextStyle(
                        color: testSuccess ? Colors.greenAccent : Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('CANCEL', style: TextStyle(color: Colors.grey[400])),
                ),
                TextButton(
                  onPressed: testing ? null : testConnection,
                  child: testing 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent))
                    : const Text('TEST URL', style: TextStyle(color: Colors.cyanAccent)),
                ),
                ElevatedButton(
                  onPressed: save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiService = ApiService(Provider.of<ApiConfig>(context, listen: false));
      if (_isSignUp) {
        await apiService.register(
          email: _emailController.text.trim(),
          mobileNumber: _mobileController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await apiService.login(
          _loginUsernameController.text.trim(),
          _passwordController.text,
        );
      }
      
      // Successfully authenticated, the main navigation shell will automatically rebuild
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isSignUp ? 'Registration successful!' : 'Welcome back!'),
            backgroundColor: Colors.cyan[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 600;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F0F1A), Color(0xFF1E1E2E), Color(0xFF121218)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 450),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2E).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.cyan.withOpacity(0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyan.withOpacity(0.1),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(32.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Brand Icon
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.cyan.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet,
                            size: 48,
                            color: Colors.cyanAccent,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Title
                        const Text(
                          'EXPENSE & DEBT',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Personal Financial Manager',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[400],
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Toggle Tabs
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF121218),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    if (_isSignUp) {
                                      setState(() {
                                        _isSignUp = false;
                                        _errorMessage = null;
                                      });
                                    }
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: !_isSignUp ? Colors.cyan.withOpacity(0.15) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: !_isSignUp ? Border.all(color: Colors.cyan.withOpacity(0.3)) : null,
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Login',
                                      style: TextStyle(
                                        color: !_isSignUp ? Colors.cyanAccent : Colors.grey[400],
                                        fontWeight: !_isSignUp ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    if (!_isSignUp) {
                                      setState(() {
                                        _isSignUp = true;
                                        _errorMessage = null;
                                      });
                                    }
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _isSignUp ? Colors.cyan.withOpacity(0.15) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      border: _isSignUp ? Border.all(color: Colors.cyan.withOpacity(0.3)) : null,
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Sign Up',
                                      style: TextStyle(
                                        color: _isSignUp ? Colors.cyanAccent : Colors.grey[400],
                                        fontWeight: _isSignUp ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Error Message Banner
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                            ),
                            width: double.infinity,
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Input Form Fields
                        if (!_isSignUp) ...[
                          // Login Username Field (Email or Mobile)
                          TextFormField(
                            controller: _loginUsernameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: _buildInputDecoration(
                              label: 'Email ID or Mobile Number',
                              icon: Icons.person_outline,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your email or mobile number';
                                  }
                                  return null;
                                },
                              ),
                            ] else ...[
                              // Register Email Field
                              TextFormField(
                                controller: _emailController,
                                style: const TextStyle(color: Colors.white),
                                keyboardType: TextInputType.emailAddress,
                                decoration: _buildInputDecoration(
                                  label: 'Email Address',
                                  icon: Icons.email_outlined,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter an email address';
                                  }
                                  final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                                  if (!regex.hasMatch(value.trim())) {
                                    return 'Enter a valid email address';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              // Register Mobile Number Field
                              TextFormField(
                                controller: _mobileController,
                                style: const TextStyle(color: Colors.white),
                                keyboardType: TextInputType.phone,
                                decoration: _buildInputDecoration(
                                  label: 'Mobile Number',
                                  icon: Icons.phone_android_outlined,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your mobile number';
                                  }
                                  if (value.trim().length < 8) {
                                    return 'Enter a valid mobile number';
                                  }
                                  return null;
                                },
                              ),
                            ],

                            const SizedBox(height: 16),

                            // Password Field (Shared)
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(color: Colors.white),
                              decoration: _buildInputDecoration(
                                label: 'Password',
                                icon: Icons.lock_outline,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    color: Colors.cyanAccent.withOpacity(0.6),
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                if (_isSignUp && value.length < 6) {
                                  return 'Password must be at least 6 characters long';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 32),

                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _submitForm,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.cyan,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 4,
                                  shadowColor: Colors.cyan.withOpacity(0.4),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.black,
                                        ),
                                      )
                                    : Text(
                                        _isSignUp ? 'CREATE ACCOUNT' : 'LOGIN TO APP',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.settings_outlined, color: Colors.cyanAccent),
                  tooltip: 'Configure API URL',
                  onPressed: _showSettingsDialog,
                ),
              ),
            ],
          ),
        );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.cyanAccent.withOpacity(0.6), size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFF121218),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.cyan.withOpacity(0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.cyan.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.cyanAccent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      errorStyle: const TextStyle(color: Colors.redAccent),
    );
  }
}
