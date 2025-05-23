import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drobe/services/notificationService.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _pushNotifications = true;
  bool _outfitReminders = true;
  bool _laundryReminders = false;
  bool _weeklyDigest = false;
  bool _specialOffers = true;
  bool _newFeatures = true;

  String _outfitReminderTime = '7:00 AM';
  String _laundryReminderDay = 'Sunday';
  String _laundryReminderTime = '10:00 AM';

  bool _isLoading = true;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadSettings();
  }

  Future<void> _initializeNotifications() async {
    try {
      setState(() {
        _isLoading = true;
      });

      debugPrint('Initializing notifications...');
      final bool success = await _notificationService.init();

      if (success) {
        debugPrint('Notifications initialized successfully');
      } else {
        debugPrint('Failed to initialize notifications');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to initialize notifications. Some features may not work.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing notifications: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      setState(() {
        _pushNotifications = prefs.getBool('push_notifications') ?? true;
        _outfitReminders = prefs.getBool('outfit_reminders') ?? true;
        _laundryReminders = prefs.getBool('laundry_reminders') ?? false;
        _weeklyDigest = prefs.getBool('weekly_digest') ?? false;
        _specialOffers = prefs.getBool('special_offers') ?? true;
        _newFeatures = prefs.getBool('new_features') ?? true;

        _outfitReminderTime = prefs.getString('outfit_reminder_time') ?? '7:00 AM';
        _laundryReminderDay = prefs.getString('laundry_reminder_day') ?? 'Sunday';
        _laundryReminderTime = prefs.getString('laundry_reminder_time') ?? '10:00 AM';

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

// Modify the _saveSettings method to provide better feedback
  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('push_notifications', _pushNotifications);
      await prefs.setBool('outfit_reminders', _outfitReminders);
      await prefs.setBool('laundry_reminders', _laundryReminders);
      await prefs.setBool('weekly_digest', _weeklyDigest);
      await prefs.setBool('special_offers', _specialOffers);
      await prefs.setBool('new_features', _newFeatures);

      await prefs.setString('outfit_reminder_time', _outfitReminderTime);
      await prefs.setString('laundry_reminder_day', _laundryReminderDay);
      await prefs.setString('laundry_reminder_time', _laundryReminderTime);

      // Check if notifications are initialized before proceeding
      if (!_notificationService.isInitialized) {
        // Try to initialize again
        final bool success = await _notificationService.init();
        if (!success) {
          throw Exception('Notifications service could not be initialized');
        }
      }

      if (_pushNotifications) {
        // Handle outfit reminders
        if (_outfitReminders) {
          final outfitSuccess = await _scheduleOutfitReminders();
          if (outfitSuccess) {
            debugPrint('Outfit reminders scheduled successfully for $_outfitReminderTime');
          } else {
            debugPrint('Failed to schedule outfit reminders');
          }
        } else {
          await _cancelOutfitReminders();
          debugPrint('Outfit reminders cancelled');
        }

        // Handle laundry reminders
        if (_laundryReminders) {
          final laundrySuccess = await _scheduleLaundryReminders();
          if (laundrySuccess) {
            debugPrint('Laundry reminders scheduled successfully for $_laundryReminderDay at $_laundryReminderTime');
          } else {
            debugPrint('Failed to schedule laundry reminders');
          }
        } else {
          await _cancelLaundryReminders();
          debugPrint('Laundry reminders cancelled');
        }
      } else {
        await _cancelAllReminders();
        debugPrint('All reminders cancelled (push notifications disabled)');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getSuccessMessage()),
          duration: const Duration(seconds: 3),
        ),
      );

      setState(() {
        _isLoading = false;
      });

      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Error saving notification settings: $e');
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save notification settings: $e')),
      );
    }
  }

// Add a method to generate a more informative success message
  String _getSuccessMessage() {
    if (!_pushNotifications) {
      return 'Notification settings saved. Push notifications are disabled.';
    }

    List<String> enabledNotifications = [];

    if (_outfitReminders) {
      enabledNotifications.add('outfit reminders at $_outfitReminderTime');
    }

    if (_laundryReminders) {
      enabledNotifications.add('laundry reminders on $_laundryReminderDay at $_laundryReminderTime');
    }

    if (enabledNotifications.isEmpty) {
      return 'Notification settings saved. No reminders are enabled.';
    }

    return 'Notification settings saved. Scheduled: ${enabledNotifications.join(', ')}.';
  }

  Future<bool> _scheduleOutfitReminders() async {
    final success = await _notificationService.scheduleOutfitReminder(_outfitReminderTime);
    if (!success) {
      debugPrint('Failed to schedule outfit reminders');
    }
    return success;
  }

  Future<bool> _scheduleLaundryReminders() async {
    final success = await _notificationService.scheduleLaundryReminder(
        _laundryReminderDay,
        _laundryReminderTime
    );
    if (!success) {
      debugPrint('Failed to schedule laundry reminders');
    }
    return success;
  }

  Future<void> _cancelOutfitReminders() async {
    await _notificationService.cancelOutfitReminders();
  }

  Future<void> _cancelLaundryReminders() async {
    await _notificationService.cancelLaundryReminders();
  }

  Future<void> _cancelAllReminders() async {
    await _notificationService.cancelAllReminders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCard(
            title: 'General Notifications',
            children: [
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
            ],
          ),
          const SizedBox(height: 16),
          _buildCard(
            title: 'Outfit Planning Reminders',
            children: [
              _buildSwitchItem(
                title: 'Daily Outfit Reminders',
                subtitle: 'Get a reminder to plan your outfit for tomorrow',
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
                  time: _outfitReminderTime,
                  onTap: _showOutfitTimePicker,
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCard(
            title: 'Laundry Reminders',
            children: [
              _buildSwitchItem(
                title: 'Weekly Laundry Reminders',
                subtitle: 'Get a reminder to do your laundry',
                value: _laundryReminders,
                onChanged: (value) {
                  setState(() {
                    _laundryReminders = value;
                  });
                },
              ),
              if (_laundryReminders)
                ...[
                  _buildDaySelector(
                    title: 'Reminder Day',
                    subtitle: 'Which day to receive your laundry reminder',
                    day: _laundryReminderDay,
                    onTap: _showLaundryDayPicker,
                  ),
                  _buildTimeSelector(
                    title: 'Reminder Time',
                    subtitle: 'When to receive your laundry reminder',
                    time: _laundryReminderTime,
                    onTap: _showLaundryTimePicker,
                  ),
                ],
            ],
          ),


        ],
      ),
      bottomNavigationBar: _isLoading
          ? const SizedBox.shrink()
          : Padding(
        padding: const EdgeInsets.all(40),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[300],
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.black,
              ),
            )
                : const Text(
              'SAVE SETTINGS',
              style: TextStyle(
                fontFamily: 'Avenir',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required String title, required List<Widget> children}) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          ...children,
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                const SizedBox(height: 4),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  const SizedBox(height: 4),
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
                borderRadius: BorderRadius.circular(8),
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

  Widget _buildDaySelector({
    required String title,
    required String subtitle,
    required String day,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  const SizedBox(height: 4),
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
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                day,
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

  TimeOfDay _parseTimeString(String timeString) {
    final parts = timeString.split(' ');
    final timeParts = parts[0].split(':');
    int hour = int.parse(timeParts[0]);
    final int minute = int.parse(timeParts[1]);

    if (parts[1] == 'PM' && hour < 12) {
      hour += 12;
    } else if (parts[1] == 'AM' && hour == 12) {
      hour = 0;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTimeOfDay(TimeOfDay timeOfDay) {
    final hour = timeOfDay.hourOfPeriod == 0 ? 12 : timeOfDay.hourOfPeriod;
    final minute = timeOfDay.minute.toString().padLeft(2, '0');
    final period = timeOfDay.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  void _showOutfitTimePicker() async {
    final TimeOfDay initialTime = _parseTimeString(_outfitReminderTime);
    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
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
      setState(() {
        _outfitReminderTime = _formatTimeOfDay(selectedTime);
      });
    }
  }

  void _showLaundryTimePicker() async {
    final TimeOfDay initialTime = _parseTimeString(_laundryReminderTime);
    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
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
      setState(() {
        _laundryReminderTime = _formatTimeOfDay(selectedTime);
      });
    }
  }

  void _showLaundryDayPicker() async {
    final List<String> days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];

    final String? selectedDay = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Day'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: days.length,
              itemBuilder: (BuildContext context, int index) {
                return ListTile(
                  title: Text(days[index]),
                  onTap: () {
                    Navigator.of(context).pop(days[index]);
                  },
                  selected: days[index] == _laundryReminderDay,
                );
              },
            ),
          ),
        );
      },
    );

    if (selectedDay != null) {
      setState(() {
        _laundryReminderDay = selectedDay;
      });
    }
  }
}

