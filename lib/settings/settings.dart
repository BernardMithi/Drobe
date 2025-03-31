import 'package:flutter/material.dart';
import 'package:drobe/auth/authService.dart';
import 'package:drobe/settings/passwordChange.dart';
import 'package:drobe/settings/privacyPolicy.dart';
import 'package:drobe/settings/term.dart';
import 'package:drobe/settings/contactUs.dart';
import 'package:drobe/settings/notifications.dart';
import 'package:drobe/settings/helpCenter.dart';
import 'package:drobe/settings/profileAvatar.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  Map<String, String> _userData = {};
  Key _avatarKey = ValueKey('settings_avatar_${DateTime.now().millisecondsSinceEpoch}');

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

  void _refreshAvatar() {
    setState(() {
      _avatarKey = ValueKey('settings_avatar_${DateTime.now().millisecondsSinceEpoch}');
    });
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
      title: 'PROFILE',
      subtitle: 'Manage your account information',
      onTap: () {
        Navigator.of(context).pushNamed('/settings/profile').then((_) {
          // Refresh when returning from profile page
          _refreshAvatar();
          _loadUserData();
        });
      },
    ),
    SettingsItem(
      icon: Icons.notifications_none,
      title: 'NOTIFICATIONS',
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
      title: 'PRIVACY',
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
      title: 'TERMS OF SERVICE',
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
      title: 'CHANGE PASSWORD',
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
      title: 'HELP & SUPPORT',
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
      title: 'CONTACT US',
      subtitle: 'Get in touch with our team',
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ContactUsPage(),
          ),
        );
      },
    ),
    SettingsItem(
      icon: Icons.info,
      title: 'ABOUT',
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
        title: const Text(
            'SETTINGS',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          // Profile picture in the app bar
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pushNamed('/settings/profile').then((_) {
                  // Refresh when returning from profile page
                  _refreshAvatar();
                  _loadUserData();
                });
              },
              child: ProfileAvatar(
                key: _avatarKey,
                size: 42,
                userId: _userData['id'] ?? '',
                name: _userData['name'] ?? '',
                email: _userData['email'] ?? '',
              ),
            ),
          ),
        ],
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
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(
                    icon,
                    size: 24,
                    color: Colors.grey[800]
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Avenir',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: 'Avenir',
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Colors.grey[400],
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
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

