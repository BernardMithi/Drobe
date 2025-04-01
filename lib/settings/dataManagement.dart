import 'package:flutter/material.dart';
import 'package:drobe/services/hiveServiceManager.dart';
import 'package:drobe/auth/authService.dart';
import 'dart:async';

class DataManagementPage extends StatefulWidget {
  const DataManagementPage({Key? key}) : super(key: key);

  @override
  _DataManagementPageState createState() => _DataManagementPageState();
}

class _DataManagementPageState extends State<DataManagementPage> {
  bool _isLoading = false;
  String _statusMessage = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Management'),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_statusMessage.isNotEmpty ? _statusMessage : 'Clearing data...'),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reset Options',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose how you want to reset your app data.',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),

            // Reset Content Only
            _buildResetOption(
              title: 'Reset Content Only',
              description: 'Clear all your items, outfits, and preferences while staying logged in.',
              icon: Icons.refresh,
              color: Colors.blue,
              onTap: () => _showResetConfirmation(
                title: 'Reset Content Only?',
                content: 'This will clear all your items, outfits, and preferences. Your account will remain active and you will stay logged in. This action cannot be undone.',
                clearUserAuth: false,
              ),
            ),

            const SizedBox(height: 16),

            // Factory Reset
            _buildResetOption(
              title: 'Factory Reset',
              description: 'Clear everything including your account information. You will need to log in again.',
              icon: Icons.delete_forever,
              color: Colors.red,
              onTap: () => _showResetConfirmation(
                title: 'Factory Reset?',
                content: 'This will clear ALL data including your account information. You will be signed out and need to log in again. This action cannot be undone.',
                clearUserAuth: true,
              ),
            ),

            const SizedBox(height: 32),

            // Information section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'What gets deleted?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('• Content Reset: All items, outfits, lookbook entries, laundry items, and preferences'),
                  SizedBox(height: 4),
                  Text('• Factory Reset: Everything above plus your account information'),
                  SizedBox(height: 16),
                  Text(
                    'Note: This only affects data on this device. If you have synced data to the cloud, you may need to delete that separately.',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResetOption({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
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
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey.shade400,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showResetConfirmation({
    required String title,
    required String content,
    required bool clearUserAuth,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _resetData(clearUserAuth: clearUserAuth);
    }
  }

  Future<void> _resetData({required bool clearUserAuth}) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Preparing to clear data...';
    });

    try {
      // Get the HiveManager instance
      final hiveManager = HiveManager();

      // Update status
      setState(() {
        _statusMessage = 'Clearing data...';
      });

      // Clear the data with a timeout
      await Future.delayed(const Duration(milliseconds: 500)); // Small delay for UI feedback

      await hiveManager.clearAllData(clearUserAuth: clearUserAuth)
          .timeout(const Duration(seconds: 30), onTimeout: () {
        debugPrint('Data clearing operation timed out, but may have partially succeeded');
        throw TimeoutException('Operation timed out');
      });

      // Update status
      setState(() {
        _statusMessage = 'Data cleared successfully!';
      });

      // Small delay to show success message
      await Future.delayed(const Duration(seconds: 1));

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data cleared successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // If we cleared user auth, sign out and navigate to login
      if (clearUserAuth) {
        setState(() {
          _statusMessage = 'Signing out...';
        });

        final authService = AuthService();

        // Use the correct method name for signing out
        try {
          await authService.logout();
        } catch (e) {
          print('Error signing out: $e');
          // Continue even if logout fails
        }

        // Navigate to login screen
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      } else {
        // Just go back to settings
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error clearing data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = '';
        });
      }
    }
  }
}

