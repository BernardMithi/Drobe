import 'package:flutter/material.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _outfitReminders = true;
  bool _weeklyDigest = false;
  bool _specialOffers = true;
  bool _newFeatures = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'NOTIFICATIONS',
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
      ),
      body: ListView(
        children: [
          const SizedBox(height: 20),

          _buildSectionHeader('General Notifications'),
          _buildSwitchItem(
            title: 'Push Notifications',
            subtitle: 'Receive push notifications on your device',
            value: _pushNotifications,
            onChanged: (value) {
              setState(() {
                _pushNotifications = value;
              });
            },
          ),

          _buildSwitchItem(
            title: 'Email Notifications',
            subtitle: 'Receive notifications via email',
            value: _emailNotifications,
            onChanged: (value) {
              setState(() {
                _emailNotifications = value;
              });
            },
          ),

          const Divider(height: 40),

          _buildSectionHeader('Outfit Reminders'),
          _buildSwitchItem(
            title: 'Daily Outfit Reminders',
            subtitle: 'Get a reminder for your planned outfit',
            value: _outfitReminders,
            onChanged: (value) {
              setState(() {
                _outfitReminders = value;
              });
            },
          ),

          if (_outfitReminders)
            _buildTimeSelector(
              title: 'Reminder Time',
              subtitle: 'When to receive your outfit reminder',
              time: '7:00 AM',
              onTap: () {
                _showTimePicker();
              },
            ),

          const Divider(height: 40),

          _buildSectionHeader('Content & Updates'),
          _buildSwitchItem(
            title: 'Weekly Digest',
            subtitle: 'Receive a weekly summary of your outfits',
            value: _weeklyDigest,
            onChanged: (value) {
              setState(() {
                _weeklyDigest = value;
              });
            },
          ),

          _buildSwitchItem(
            title: 'Special Offers',
            subtitle: 'Be informed about promotions and deals',
            value: _specialOffers,
            onChanged: (value) {
              setState(() {
                _specialOffers = value;
              });
            },
          ),

          _buildSwitchItem(
            title: 'New Features',
            subtitle: 'Learn about new app features',
            value: _newFeatures,
            onChanged: (value) {
              setState(() {
                _newFeatures = value;
              });
            },
          ),

          const SizedBox(height: 40),

          // Save Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: () {
                // Save notification settings
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notification settings saved')),
                );
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'SAVE SETTINGS',
                style: TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildSwitchItem({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
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
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.black,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSelector({
    required String title,
    required String subtitle,
    required String time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                time,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTimePicker() async {
    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 7, minute: 0),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedTime != null) {
      // Handle the selected time
    }
  }
}

