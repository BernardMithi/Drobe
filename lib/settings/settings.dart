import 'package:flutter/material.dart';
import 'contactUs.dart';
import 'helpCenter.dart';
import 'notifications.dart';
import 'passwordChange.dart';
import 'privacyPolicy.dart';
import 'profile.dart';
import 'term.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Settings state
  bool _notificationsEnabled = true;
  bool _darkMode = false;
  String _selectedUnit = 'Celsius';
  String _selectedCurrency = 'USD';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'SETTINGS',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: const CircleAvatar(
              backgroundColor: Color(0xFF4A4A4A),
              child: Icon(Icons.person, color: Colors.white),
            ),
          ),
        ],
      ),
      body: ListView(
        children: [
          const SizedBox(height: 20),

          // Account section
          _buildSectionHeader('Account'),
          _buildSettingItem(
            'Profile',
            'Edit your personal information',
            Icons.person_outline,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
          ),
          _buildSettingItem(
            'Password',
            'Change your password',
            Icons.lock_outline,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PasswordPage()),
              );
            },
          ),
          _buildSettingItem(
            'Notifications',
            'Manage your notifications',
            Icons.notifications_none,
            toggle: true,
            toggleValue: _notificationsEnabled,
            onToggleChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
            },
          ),

          const SizedBox(height: 20),

          // Appearance section
          _buildSectionHeader('Appearance'),
          _buildSettingItem(
            'Dark Mode',
            'Switch between light and dark theme',
            Icons.dark_mode_outlined,
            toggle: true,
            toggleValue: _darkMode,
            onToggleChanged: (value) {
              setState(() {
                _darkMode = value;
              });
            },
          ),
          const SizedBox(height: 20),
          // Support section
          _buildSectionHeader('Support'),
          _buildSettingItem(
            'Help Center',
            'Get help with the app',
            Icons.help_outline,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpCenterPage()),
              );
            },
          ),
          _buildSettingItem(
            'Contact Us',
            'Reach out to our support team',
            Icons.mail_outline,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ContactUsPage()),
              );
            },
          ),

          const SizedBox(height: 20),

          // About section
          _buildSectionHeader('About'),
          _buildSettingItem(
            'Version',
            '1.0.0',
            Icons.info_outline,
            onTap: () {},
          ),
          _buildSettingItem(
            'Terms of Service',
            'Read our terms and conditions',
            Icons.description_outlined,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TermsPage()),
              );
            },
          ),
          _buildSettingItem(
            'Privacy Policy',
            'Read our privacy policy',
            Icons.privacy_tip_outlined,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PrivacyPolicyPage()),
              );
            },
          ),

          const SizedBox(height: 20),

          // Logout button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton(
              onPressed: () {
                _showLogoutDialog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Log Out',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildSettingItem(
      String title,
      String subtitle,
      IconData icon, {
        Function()? onTap,
        bool toggle = false,
        bool? toggleValue,
        Function(bool)? onToggleChanged,
      }) {
    return InkWell(
      onTap: toggle ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Colors.black,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (toggle)
              Switch(
                value: toggleValue ?? false,
                onChanged: onToggleChanged,
                activeColor: Colors.black,
              )
            else
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  void _showUnitPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Temperature Unit',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                title: const Text('Celsius'),
                trailing: _selectedUnit == 'Celsius'
                    ? const Icon(Icons.check, color: Colors.black)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedUnit = 'Celsius';
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Fahrenheit'),
                trailing: _selectedUnit == 'Fahrenheit'
                    ? const Icon(Icons.check, color: Colors.black)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedUnit = 'Fahrenheit';
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCurrencyPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Currency',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                title: const Text('USD - US Dollar'),
                trailing: _selectedCurrency == 'USD'
                    ? const Icon(Icons.check, color: Colors.black)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedCurrency = 'USD';
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('EUR - Euro'),
                trailing: _selectedCurrency == 'EUR'
                    ? const Icon(Icons.check, color: Colors.black)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedCurrency = 'EUR';
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('GBP - British Pound'),
                trailing: _selectedCurrency == 'GBP'
                    ? const Icon(Icons.check, color: Colors.black)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedCurrency = 'GBP';
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Perform logout
            },
            child: const Text('LOG OUT', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

