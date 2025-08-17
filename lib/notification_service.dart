import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings();

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

  await _plugin.initialize(initSettings);

    // Android channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'geofence_channel',
      'Geofence Alerts',
      description: 'Notifications when entering or exiting school vicinity',
      importance: Importance.high,
      playSound: true,
    );

  await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);

  // Request permissions (Android 13+ requires POST_NOTIFICATIONS at runtime, iOS requires user auth)
  await _requestPermissions();

    _initialized = true;
  }

  Future<void> showGeofenceNotification({required bool entered, required String studentName}) async {
    await init();

    final title = entered ? 'Entered School Vicinity' : 'Exited School Vicinity';
    final body = entered
        ? '$studentName has arrived at school.'
        : '$studentName has left the school area.';

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'geofence_channel',
      'Geofence Alerts',
      channelDescription: 'Notifications when entering or exiting school vicinity',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _plugin.show(DateTime.now().millisecondsSinceEpoch ~/ 1000, title, body, notificationDetails);
      debugPrint('📣 Notification shown: $title - $body');
    } catch (e) {
      debugPrint('❌ Failed to show notification: $e');
    }
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted = await androidPlugin.areNotificationsEnabled();
        if (!(granted ?? false)) {
          // Newer versions expose requestNotificationsPermission; fallback if absent
          try {
            // ignore: deprecated_member_use
            final requested = await androidPlugin.requestNotificationsPermission();
            debugPrint('🔔 Android notification permission granted: $requested');
          } catch (_) {
            debugPrint('⚠️ Could not request Android notifications permission via plugin API.');
          }
        }
      }
    } else if (Platform.isIOS) {
      final iosPlugin = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        final result = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        debugPrint('🔔 iOS notification permission result: $result');
      }
    }
  }
}
