import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keys for prefs to communicate between UI isolate and service isolate
class BgKeys {
  static const String studentId = 'bg_student_id';
  static const String classHours = 'bg_class_hours';
  static const String enabled = 'bg_enabled';
}

/// Initializes the background service. Call once during app start (after Firebase).
Future<void> initBackgroundService() async {
  final service = FlutterBackgroundService();
  final isRunning = await service.isRunning();
  if (isRunning) return; // Avoid double start

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: backgroundServiceEntry,
      isForegroundMode: true,
      autoStart: false,
      initialNotificationTitle: 'Ally Tracking',
      initialNotificationContent: 'Preparing background tracking...',
      foregroundServiceNotificationId: 9971,
    ),
    iosConfiguration: IosConfiguration(),
  );
}

/// Entry point for the background isolate.
@pragma('vm:entry-point')
Future<void> backgroundServiceEntry(ServiceInstance service) async {
  // Required for plugin registration in background isolate
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }

  final firestore = FirebaseFirestore.instance;
  final prefs = await SharedPreferences.getInstance();

  service.on('stopService').listen((event) {
    service.stopSelf();
  });
  service.on('refreshNotification').listen((event) async {
    final enabled = prefs.getBool(BgKeys.enabled) ?? false;
    if (service is AndroidServiceInstance) {
      if (enabled) {
        service.setForegroundNotificationInfo(
          title: 'Ally Tracking Active',
          content: 'Background location running during class hours',
        );
      } else {
        service.setForegroundNotificationInfo(
          title: 'Ally Tracking Idle',
          content: 'Outside class hours',
        );
      }
    }
  });

  // Initial notification state
  if (service is AndroidServiceInstance) {
    final enabled = prefs.getBool(BgKeys.enabled) ?? false;
    service.setForegroundNotificationInfo(
      title: enabled ? 'Ally Tracking Active' : 'Ally Tracking Idle',
      content: enabled ? 'Background location running during class hours' : 'Waiting for next class hours window',
    );
  }

  // Periodic timer (adjust interval for battery/performance balance)
  Timer.periodic(const Duration(minutes: 1), (timer) async {
    try {
      final enabled = prefs.getBool(BgKeys.enabled) ?? false;
      if (!enabled) {
        // Periodically keep idle notification fresh (every ~15 mins implicitly by minute loop)
        if (service is AndroidServiceInstance && timer.tick % 15 == 0) {
          service.setForegroundNotificationInfo(
            title: 'Ally Tracking Idle',
            content: 'Outside class hours',
          );
        }
        return; // Skip if outside class hours
      }

      final studentId = prefs.getString(BgKeys.studentId);
      final classHours = prefs.getString(BgKeys.classHours) ?? '';
      if (studentId == null || studentId.isEmpty) return;

      // Double-check still within class hour window
      if (!_isNowWithinClassHours(classHours)) {
        prefs.setBool(BgKeys.enabled, false);
        return;
      }

      final hasPermission = await Geolocator.checkPermission();
      if (hasPermission == LocationPermission.denied || hasPermission == LocationPermission.deniedForever) {
        return;
      }

      if (!await Geolocator.isLocationServiceEnabled()) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final geoPoint = GeoPoint(pos.latitude, pos.longitude);
      final now = DateTime.now();

      await firestore.collection('students').doc(studentId).update({
        'currentLocation': geoPoint,
        'lastUpdated': Timestamp.fromDate(now),
      });

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Ally Tracking Active',
          content: 'Last sent ${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}',
        );
      }
    } catch (e) {
      // Swallow errors to keep timer alive; optionally log
    }
  });
}

/// Called after login to provide student details to the service and start if needed.
Future<void> updateBackgroundTracking({required String studentId, required String classHours}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(BgKeys.studentId, studentId);
  await prefs.setString(BgKeys.classHours, classHours);

      final within = _isNowWithinClassHours(classHours);
  await prefs.setBool(BgKeys.enabled, within);

  final service = FlutterBackgroundService();
  final running = await service.isRunning();
  if (within) {
    if (!running) {
      await service.startService();
      // Give service a moment then refresh notification
      Future.delayed(const Duration(seconds: 1), () => service.invoke('refreshNotification'));
    }
    if (running) {
      service.invoke('refreshNotification');
    }
  } else {
    if (running) {
      service.invoke('stopService');
    }
  }
}

/// Call this whenever student data changes (e.g., schedule updated) or on app resume.
Future<void> reevaluateBackgroundTracking() async {
  final prefs = await SharedPreferences.getInstance();
  final classHours = prefs.getString(BgKeys.classHours) ?? '';
  final shouldEnable = _isNowWithinClassHours(classHours);
  final wasEnabled = prefs.getBool(BgKeys.enabled) ?? false;

  if (shouldEnable == wasEnabled) return; // No change

  await prefs.setBool(BgKeys.enabled, shouldEnable);
  final service = FlutterBackgroundService();
  final running = await service.isRunning();
  if (shouldEnable && !running) {
    await service.startService();
    Future.delayed(const Duration(seconds: 1), () => service.invoke('refreshNotification'));
  } else if (shouldEnable && running) {
    service.invoke('refreshNotification');
  } else if (!shouldEnable && running) {
    service.invoke('stopService');
  }
}

bool _isNowWithinClassHours(String classHours) {
  if (classHours.isEmpty || !classHours.contains('-')) return false;
  try {
    final parts = classHours.split('-');
    if (parts.length != 2) return false;
    final start = _parseTime(parts[0]);
    final end = _parseTime(parts[1]);
    final now = DateTime.now();
    final nowM = now.hour * 60 + now.minute;
    final sM = start.hour * 60 + start.minute;
    final eM = end.hour * 60 + end.minute;
    return nowM >= sM && nowM <= eM;
  } catch (_) {
    return false;
  }
}

_TimeOfDay _parseTime(String raw) {
  raw = raw.trim();
  final ampm = raw.toUpperCase().endsWith('AM') || raw.toUpperCase().endsWith('PM');
  if (ampm) {
    final isPM = raw.toUpperCase().endsWith('PM');
    raw = raw.substring(0, raw.length - 2).trim();
    final parts = raw.split(':');
    if (parts.length != 2) return _TimeOfDay(0,0);
    var h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    if (isPM && h != 12) h += 12;
    if (!isPM && h == 12) h = 0;
    return _TimeOfDay(h, m);
  } else {
    final parts = raw.split(':');
    if (parts.length != 2) return _TimeOfDay(0,0);
    return _TimeOfDay(int.parse(parts[0]), int.parse(parts[1]));
  }
}

class _TimeOfDay { final int hour; final int minute; const _TimeOfDay(this.hour,this.minute); }
