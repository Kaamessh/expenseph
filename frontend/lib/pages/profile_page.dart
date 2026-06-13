import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final apiConfig = Provider.of<ApiConfig>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF121218),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            // Profile Avatar / Header Card
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Colors.cyan, Colors.cyanAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyan.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFF1E1E2E),
                      child: Icon(
                        Icons.person_rounded,
                        size: 56,
                        color: Colors.cyanAccent.withOpacity(0.9),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    apiConfig.email ?? 'Registered User',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Active Session Profile',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.cyanAccent.withOpacity(0.7),
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Account Details Card
            _buildProfileCard(
              title: 'Account Information',
              icon: Icons.account_box_rounded,
              children: [
                _buildInfoRow(
                  label: 'Email Address',
                  value: apiConfig.email ?? 'N/A',
                  icon: Icons.email_outlined,
                ),
                const Divider(color: Colors.grey, height: 24, thickness: 0.1),
                _buildInfoRow(
                  label: 'Mobile Number',
                  value: apiConfig.mobileNumber ?? 'N/A',
                  icon: Icons.phone_android_outlined,
                ),
                const Divider(color: Colors.grey, height: 24, thickness: 0.1),
                _buildInfoRow(
                  label: 'User Session ID',
                  value: apiConfig.userId ?? 'N/A',
                  icon: Icons.vpn_key_outlined,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Server connection details
            _buildProfileCard(
              title: 'Server Configuration',
              icon: Icons.dns_rounded,
              children: [
                _buildInfoRow(
                  label: 'API Base URL',
                  value: apiConfig.baseUrl,
                  icon: Icons.link_rounded,
                ),
                const Divider(color: Colors.grey, height: 24, thickness: 0.1),
                _buildInfoRow(
                  label: 'Database Sync',
                  value: 'Connected (Supabase)',
                  icon: Icons.cloud_done_outlined,
                  valueColor: Colors.greenAccent,
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.cyan.withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.cyanAccent, size: 22),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey[400], size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
