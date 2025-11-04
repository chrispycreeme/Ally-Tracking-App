import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _isLoggedIn = false;
  static const String _loginStateKey = 'ally_user_logged_in';

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

    // Load login state from persistent storage
    await _loadLoginState();

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

  /// Shows a persistent foreground service notification that cannot be swiped away.
  /// Used for background tracking to ensure the notification remains visible.
  Future<void> showPersistentNotification({
    required String title,
    required String content,
    int notificationId = 9971,
  }) async {
    await init();

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'ally_background_tracking',
      'Background Tracking',
      channelDescription: 'Persistent notification for background location tracking',
      importance: Importance.low,
      priority: Priority.low,
      playSound: false,
      ongoing: true, // Cannot be swiped away
      autoCancel: false, // Does not auto-dismiss
      enableVibration: false,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _plugin.show(notificationId, title, content, notificationDetails);
      debugPrint('📌 Persistent notification shown: $title - $content');
    } catch (e) {
      debugPrint('❌ Failed to show persistent notification: $e');
    }
  }

  /// Sets the login state. When user is logged out, the persistent notification can be removed.
  void setLoggedIn(bool loggedIn) {
    _isLoggedIn = loggedIn;
    _saveLoginState();
    debugPrint('🔐 Login state: $_isLoggedIn');
  }

  /// Saves login state to persistent storage
  Future<void> _saveLoginState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_loginStateKey, _isLoggedIn);
      debugPrint('💾 Login state saved to storage: $_isLoggedIn');
    } catch (e) {
      debugPrint('❌ Failed to save login state: $e');
    }
  }

  /// Loads login state from persistent storage
  Future<void> _loadLoginState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isLoggedIn = prefs.getBool(_loginStateKey) ?? false;
      debugPrint('📂 Login state loaded from storage: $_isLoggedIn');
    } catch (e) {
      debugPrint('❌ Failed to load login state: $e');
    }
  }

  /// Clears the persistent foreground service notification (call on logout).
  Future<void> clearPersistentNotification({int notificationId = 9971}) async {
    await init();
    try {
      await _plugin.cancel(notificationId);
      debugPrint('🗑️ Persistent notification cleared');
    } catch (e) {
      debugPrint('❌ Failed to clear persistent notification: $e');
    }
  }

  /// Gets the current login state
  bool get isLoggedIn => _isLoggedIn;

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
