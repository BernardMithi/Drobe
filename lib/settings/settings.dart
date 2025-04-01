import 'package:flutter/material.dart';
import 'package:drobe/auth/authService.dart';
import 'package:drobe/settings/profile.dart';
import 'package:drobe/settings/notifications.dart';
import 'package:drobe/settings/contactUs.dart';
import 'package:drobe/settings/dataManagement.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SETTINGS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSection(
            context,
            'Account',
            [
              _buildSettingTile(
                context,
                'Profile',
                Icons.person,
                    () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                ),
              ),
              _buildSettingTile(
                context,
                'Notifications',
                Icons.notifications,
                    () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NotificationsPage()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSection(
            context,
            'Support',
            [
              _buildSettingTile(
                context,
                'Contact Us',
                Icons.mail,
                    () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ContactUsPage()),
                ),
              ),
              _buildSettingTile(
                context,
                'About',
                Icons.info,
                    () => _showAboutDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSection(
            context,
            'Data Management',
            [
              _buildSettingTile(
                context,
                'Reset App Data',
                Icons.delete_forever,
                    () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DataManagementPage(),
                  ),
                ),
                subtitle: 'Clear items, outfits, and preferences',
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSection(
            context,
            'Account',
            [
              _buildSettingTile(
                context,
                'Sign Out',
                Icons.exit_to_app,
                    () => _signOut(context),
                isDestructive: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
            ),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingTile(
      BuildContext context,
      String title,
      IconData icon,
      VoidCallback onTap, {
        bool isDestructive = false,
        String? subtitle,
      }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive
            ? Colors.red
            : Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : null,
        ),
      ),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Drobe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/drobe_logo.png',
              height: 80,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            const Text('Drobe helps you organize your wardrobe and create outfits.'),
            const SizedBox(height: 16),
            const Text('Version: 1.0.0'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sign Out?'),
          content: const Text('Are you sure you want to sign out?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await AuthService().logout(); // Use the correct method name from your AuthService
                  // Navigate to login screen or home
                  Navigator.of(context).pushReplacementNamed('/login');
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error signing out: $e')),
                  );
                }
              },
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }
}

