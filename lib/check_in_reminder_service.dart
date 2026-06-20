import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Local daily check-in reminder preferences and scheduling.
class CheckInReminderSettings {
  const CheckInReminderSettings({
    required this.enabled,
    required this.time,
  });

  final bool enabled;
  final TimeOfDay time;

  static const defaults = CheckInReminderSettings(
    enabled: false,
    time: TimeOfDay(hour: 9, minute: 0),
  );

  CheckInReminderSettings copyWith({
    bool? enabled,
    TimeOfDay? time,
  }) =>
      CheckInReminderSettings(
        enabled: enabled ?? this.enabled,
        time: time ?? this.time,
      );
}

class CheckInReminderService {
  CheckInReminderService._();

  static final CheckInReminderService instance = CheckInReminderService._();

  static const int notificationId = 9001;
  static const String androidChannelId = 'check_in_reminders';
  static const String androidChannelName = 'Daily check-in';
  static const String payloadType = 'check_in_reminder';

  static const _prefEnabled = 'check_in_reminder_enabled';
  static const _prefHour = 'check_in_reminder_hour';
  static const _prefMinute = 'check_in_reminder_minute';

  bool _timezonesReady = false;

  Future<void> _ensureTimezones() async {
    if (_timezonesReady) return;
    tz_data.initializeTimeZones();
    _timezonesReady = true;
  }

  Future<CheckInReminderSettings> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_prefEnabled) ?? false;
      final hour = prefs.getInt(_prefHour) ?? CheckInReminderSettings.defaults.time.hour;
      final minute =
          prefs.getInt(_prefMinute) ?? CheckInReminderSettings.defaults.time.minute;
      return CheckInReminderSettings(
        enabled: enabled,
        time: TimeOfDay(hour: hour, minute: minute),
      );
    } catch (e, st) {
      debugPrint('[CareSignal][CheckInReminder] load failed: $e');
      debugPrint('$st');
      return CheckInReminderSettings.defaults;
    }
  }

  Future<void> saveSettings(CheckInReminderSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, settings.enabled);
    await prefs.setInt(_prefHour, settings.time.hour);
    await prefs.setInt(_prefMinute, settings.time.minute);
  }

  static String formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> syncSchedule(FlutterLocalNotificationsPlugin local) async {
    if (kIsWeb) return;

    await _ensureTimezones();
    await local.cancel(id: notificationId);

    final settings = await loadSettings();
    if (!settings.enabled) return;

    final payload = jsonEncode({'type': payloadType});
    try {
      await local.zonedSchedule(
        id: notificationId,
        title: 'Daily check-in',
        body: 'Take 30 seconds to log how you\'re doing today.',
        scheduledDate: _nextInstanceOfTime(settings.time),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            androidChannelId,
            androidChannelName,
            channelDescription:
                'Reminds you to complete your daily wellness check-in',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
    } catch (e, st) {
      debugPrint('[CareSignal][CheckInReminder] schedule failed: $e');
      debugPrint('$st');
    }
  }

  Future<void> cancel(FlutterLocalNotificationsPlugin local) async {
    if (kIsWeb) return;
    await local.cancel(id: notificationId);
  }
}
