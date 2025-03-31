import 'package:flutter/material.dart';
import 'package:drobe/auth/authService.dart';
import 'package:drobe/settings/passwordChange.dart';
import 'package:drobe/settings/privacyPolicy.dart';
import 'package:drobe/settings/term.dart';
import 'package:drobe/settings/contactUs.dart';
import 'package:drobe/settings/notifications.dart';
import 'package:drobe/settings/helpCenter.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  Map<String, String> _userData = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Ensure AuthService is initialized before using it
      final authService = AuthService();
      final initialized = await authService.ensureInitialized();

      if (!initialized) {
        // Handle initialization failure
        setState(() {
          _isLoading = false;
          // Set default empty data
          _userData = {'name': '', 'email': ''};
        });
        return;
      }

      final userData = await authService.getCurrentUser();

      setState(() {
        _userData = userData;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading user data: $e');
      setState(() {
        _isLoading = false;
        // Set default empty data
        _userData = {'name': '', 'email': ''};
      });
    }
  }

  Future<void> _logout() async {
    setState(() {
      _isLoading = true;
    });

    final success = await _authService.logout();

    setState(() {
      _isLoading = false;
    });

    if (success && mounted) {
      // Navigate to login page and remove all previous routes
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to log out')),
      );
    }
  }

  List<SettingsItem> get _settingsItems => [
    SettingsItem(
      icon: Icons.person,
      iconColor: Colors.blue,
      title: 'Profile',
      subtitle: 'Manage your account information',
      onTap: () {
        Navigator.of(context).pushNamed('/settings/profile');
      },
    ),
    SettingsItem(
      icon: Icons.notifications_none,
      iconColor: Colors.amber,
      title: 'Notifications',
      subtitle: 'Manage outfit and laundry reminders',
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const NotificationsPage(),
          ),
        );
      },
    ),
    SettingsItem(
      icon: Icons.privacy_tip,
      iconColor: Colors.green,
      title: 'Privacy',
      subtitle: 'View privacy policy',
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const PrivacyPolicyPage(),
          ),
        );
      },
    ),
    SettingsItem(
      icon: Icons.description,
      iconColor: Colors.purple,
      title: 'Terms of Service',
      subtitle: 'View terms of service',
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const TermsOfServicePage(),
          ),
        );
      },
    ),
    SettingsItem(
      icon: Icons.lock_outline,
      iconColor: Colors.orange,
      title: 'Change Password',
      subtitle: 'Update your password',
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const PasswordChangePage(),
          ),
        );
      },
    ),
    SettingsItem(
      icon: Icons.help,
      iconColor: Colors.teal,
      title: 'Help & Support',
      subtitle: 'Get help with the app',
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const HelpCenterPage(),
          ),
        );
      },
    ),
    SettingsItem(
      icon: Icons.mail_outline,
      iconColor: Colors.blue,
      title: 'Contact Us',
      subtitle: 'Get in touch with our team',
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ContactUsPage(),
          ),
        );
      },
    ),
    SettingsItem(
      icon: Icons.info,
      iconColor: Colors.indigo,
      title: 'About',
      subtitle: 'App information and version',
      onTap: () {
        _showAboutDialog(context);
      },
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('SETTINGS'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SizedBox(height: 6),

          // Settings Items
          ..._settingsItems.map((item) => _buildSettingsTile(
            icon: item.icon,
            iconColor: item.iconColor,
            title: item.title,
            subtitle: item.subtitle,
            onTap: item.onTap,
          )).toList(),

          const SizedBox(height: 24),

          // App Version
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
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
                          fontFamily: 'Avenir',
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: 'Avenir',
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Drobe',
      applicationVersion: 'v1.0.0',
      applicationIcon: Image.asset(
        'assets/images/drobe_logo.png',
        height: 50,
        width: 50,
      ),
      applicationLegalese: '© 2024 Drobe. All rights reserved.',
      children: [
        const SizedBox(height: 24),
        const Text(
          'Drobe is your personal capsule wardrobe assistant, helping you organize your clothes and plan your outfits.',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class SettingsItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  SettingsItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

