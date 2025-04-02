import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static const String outfitChannelId = 'outfit_reminders';
  static const String laundryChannelId = 'laundry_reminders';

  // Notification IDs
  static const int outfitReminderId = 1;
  static const int laundryReminderId = 2;

  bool _isInitialized = false;

  // Add a method to check if the service is initialized
  bool get isInitialized => _isInitialized;

  // Improve the init method to ensure proper initialization
  Future<bool> init() async {
    // Prevent multiple initializations
    if (_isInitialized) {
      debugPrint('NotificationService already initialized');
      return true;
    }

    try {
      debugPrint('Initializing NotificationService...');
      tz_data.initializeTimeZones();

      // Create notification channels with sound and vibration
      const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/launcher_icon');

      // Updated iOS initialization settings - removed onDidReceiveLocalNotification
      final DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      final InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      final bool success = await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) async {
          // Handle notification tap
          debugPrint('Notification tapped: ${notificationResponse.payload}');
        },
      ) ?? false;

      if (!success) {
        debugPrint('Failed to initialize NotificationService');
        return false;
      }

      // Request permission (for iOS and Android 13+)
      await _requestPermissions();

      // Create notification channels for Android
      await _createNotificationChannels();

      _isInitialized = true;
      debugPrint('NotificationService initialized successfully');
      return true;
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
      // Don't set _isInitialized to true if there was an error
      return false;
    }
  }

  // Improve permission request method
  Future<void> _requestPermissions() async {
    try {
      // Request iOS permissions
      final iOS = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

      if (iOS != null) {
        await iOS.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
          critical: true,
        );
        debugPrint('iOS notification permissions requested');
      }

      // For Android, permissions are requested during initialization
      // or through the app settings on newer Android versions
      debugPrint('Android notification permissions are handled through app settings');
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
  }

  // Add a method to create notification channels for Android
  Future<void> _createNotificationChannels() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
    flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // Create outfit reminders channel
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          outfitChannelId,
          'Outfit Reminders',
          description: 'Daily reminders to plan your outfit',
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        ),
      );

      // Create laundry reminders channel
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          laundryChannelId,
          'Laundry Reminders',
          description: 'Weekly reminders to do your laundry',
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        ),
      );

      debugPrint('Android notification channels created');
    }
  }

  // Modify the scheduleOutfitReminder method to ensure exact timing
  Future<bool> scheduleOutfitReminder(String time) async {
    if (!_isInitialized) {
      debugPrint('NotificationService not initialized');
      return false;
    }

    try {
      // Cancel any existing outfit reminders first
      await cancelOutfitReminders();

      // Parse time (format: "7:00 AM")
      final timeParts = time.split(' ');
      final hourMinute = timeParts[0].split(':');
      int hour = int.parse(hourMinute[0]);
      final int minute = int.parse(hourMinute[1]);

      // Convert to 24-hour format
      if (timeParts[1] == 'PM' && hour < 12) {
        hour += 12;
      } else if (timeParts[1] == 'AM' && hour == 12) {
        hour = 0;
      }

      // Calculate next occurrence
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // If the time has already passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      debugPrint('Scheduling outfit reminder for: ${scheduledDate.toString()}');

      // Configure notification details
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        outfitChannelId,
        'Outfit Reminders',
        channelDescription: 'Daily reminders to plan your outfit',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Schedule the notification to repeat daily - updated to remove UILocalNotificationDateInterpretation
      await flutterLocalNotificationsPlugin.zonedSchedule(
        outfitReminderId,
        'Plan Your Outfit',
        'Time to plan your outfit for tomorrow!',
        scheduledDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time, // Repeat daily at the same time
        payload: 'outfit_reminder',
      );

      debugPrint('Outfit reminder scheduled for $time (${scheduledDate.toString()})');
      return true;
    } catch (e) {
      debugPrint('Error scheduling outfit reminder: $e');
      return false;
    }
  }

  // Modify the scheduleLaundryReminder method to ensure exact timing
  Future<bool> scheduleLaundryReminder(String day, String time) async {
    if (!_isInitialized) {
      debugPrint('NotificationService not initialized');
      return false;
    }

    try {
      // Cancel any existing laundry reminders first
      await cancelLaundryReminders();

      // Parse time (format: "10:00 AM")
      final timeParts = time.split(' ');
      final hourMinute = timeParts[0].split(':');
      int hour = int.parse(hourMinute[0]);
      final int minute = int.parse(hourMinute[1]);

      // Convert to 24-hour format
      if (timeParts[1] == 'PM' && hour < 12) {
        hour += 12;
      } else if (timeParts[1] == 'AM' && hour == 12) {
        hour = 0;
      }

      // Map day string to day of week (1 = Monday, 7 = Sunday)
      final Map<String, int> dayMap = {
        'Monday': 1,
        'Tuesday': 2,
        'Wednesday': 3,
        'Thursday': 4,
        'Friday': 5,
        'Saturday': 6,
        'Sunday': 7,
      };

      final int dayOfWeek = dayMap[day] ?? 7; // Default to Sunday

      // Calculate next occurrence of the specified day
      final now = tz.TZDateTime.now(tz.local);
      int daysUntilTarget = dayOfWeek - now.weekday;
      if (daysUntilTarget < 0) {
        daysUntilTarget += 7;
      } else if (daysUntilTarget == 0) {
        // Same day, check if time has passed
        final targetTime = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
        if (targetTime.isBefore(now)) {
          daysUntilTarget = 7; // Schedule for next week
        }
      }

      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + daysUntilTarget,
        hour,
        minute,
      );

      debugPrint('Scheduling laundry reminder for: ${scheduledDate.toString()} (${day} at ${time})');

      // Configure notification details
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        laundryChannelId,
        'Laundry Reminders',
        channelDescription: 'Weekly reminders to do your laundry',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Schedule the notification to repeat weekly - updated to remove UILocalNotificationDateInterpretation
      await flutterLocalNotificationsPlugin.zonedSchedule(
        laundryReminderId,
        'Laundry Day',
        'Time to do your laundry!',
        scheduledDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime, // Repeat weekly on the same day and time
        payload: 'laundry_reminder',
      );

      debugPrint('Laundry reminder scheduled for $day at $time (${scheduledDate.toString()})');
      return true;
    } catch (e) {
      debugPrint('Error scheduling laundry reminder: $e');
      return false;
    }
  }

  Future<void> cancelOutfitReminders() async {
    if (!_isInitialized) {
      debugPrint('NotificationService not initialized');
      return;
    }

    try {
      await flutterLocalNotificationsPlugin.cancel(outfitReminderId);
      debugPrint('Outfit reminders cancelled');
    } catch (e) {
      debugPrint('Error cancelling outfit reminders: $e');
    }
  }

  Future<void> cancelLaundryReminders() async {
    if (!_isInitialized) {
      debugPrint('NotificationService not initialized');
      return;
    }

    try {
      await flutterLocalNotificationsPlugin.cancel(laundryReminderId);
      debugPrint('Laundry reminders cancelled');
    } catch (e) {
      debugPrint('Error cancelling laundry reminders: $e');
    }
  }

  Future<void> cancelAllReminders() async {
    if (!_isInitialized) {
      debugPrint('NotificationService not initialized');
      return;
    }

    try {
      await flutterLocalNotificationsPlugin.cancelAll();
      debugPrint('All reminders cancelled');
    } catch (e) {
      debugPrint('Error cancelling all reminders: $e');
    }
  }
}

