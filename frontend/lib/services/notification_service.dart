import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/debt.dart';

class AppNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  static Future<void> init() async {
    if (kIsWeb) return;
    if (_isInitialized) return;
    
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
    
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle click
      },
    );
    _isInitialized = true;
  }

  static Future<void> requestPermissions() async {
    if (kIsWeb) return;
    final androidImplementation = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
  }

  static Future<void> cancelAll() async {
    if (kIsWeb) return;
    await init();
    await _plugin.cancelAll();
  }

  static Future<void> scheduleDebtReminder(Debt debt) async {
    if (kIsWeb) return;
    await init();
    
    int day = debt.dueDay;
    if (day < 1 || day > 31) day = 1;
    
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, day, 9, 0); // 9:00 AM
    
    if (scheduledDate.isBefore(now)) {
      scheduledDate = tz.TZDateTime(tz.local, now.year, now.month + 1, day, 9, 0);
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'interest_reminders_channel',
      'Interest Payment Reminders',
      channelDescription: 'Reminders to pay interest on loans and debts',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);

    final int notificationId = debt.id.hashCode;

    await _plugin.zonedSchedule(
      notificationId,
      'Interest Payment Due!',
      'Reminder to pay interest for ${debt.personName} (Original Amount: ₹${debt.originalAmount})',
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
    );
  }

  static Future<void> scheduleDebtReminders(List<Debt> debts, bool enabled) async {
    if (kIsWeb) return;
    await cancelAll();
    if (!enabled) return;

    for (final debt in debts) {
      if (debt.interestRate > 0) {
        await scheduleDebtReminder(debt);
      }
    }
  }
}
