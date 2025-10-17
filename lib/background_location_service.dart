import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'map_handlers/presence_service.dart';

/// Keys for prefs to communicate between UI isolate and service isolate
class BgKeys {
  static const String studentId = 'bg_student_id';
  static const String classHours = 'bg_class_hours';
  static const String enabled = 'bg_enabled';
  static const String cachedExcuseStatus = 'bg_excuse_cached_status';
  static const String cachedExcuseExpiry = 'bg_excuse_cached_expiry';
  static const String cachedExcuseReason = 'bg_excuse_cached_reason';
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
      final studentId = prefs.getString(BgKeys.studentId);
      final classHours = prefs.getString(BgKeys.classHours) ?? '';
      if (studentId == null || studentId.isEmpty) return;

      final now = DateTime.now();
      final withinClassHours = _isNowWithinClassHours(classHours);
      final excuseState = await _resolveExcuseState(
        firestore: firestore,
        prefs: prefs,
        studentId: studentId,
      );
      final shouldTrack = withinClassHours && !excuseState.isExcused;
      final previouslyEnabled = prefs.getBool(BgKeys.enabled) ?? false;

      if (previouslyEnabled != shouldTrack) {
        await prefs.setBool(BgKeys.enabled, shouldTrack);
      }

      if (!shouldTrack) {
        if (service is AndroidServiceInstance) {
          final pausedMessage = withinClassHours
              ? 'Monitoring paused: ${excuseState.reasonLabel ?? 'Excused'}'
              : 'Outside class hours';
          service.setForegroundNotificationInfo(
            title: 'Ally Tracking Paused',
            content: pausedMessage,
          );
        }
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
      await firestore.collection('students').doc(studentId).update({
        'currentLocation': geoPoint,
        'lastUpdated': Timestamp.fromDate(now),
      });

      // Also send an explicit presence heartbeat (best-effort). This helps
      // teachers get a very recent 'online' indicator even if lastUpdated
      // is delayed by client clock or network.
      try {
        final presence = PresenceService(firestore: firestore);
        await presence.heartbeat(studentId, isOnline: true);
      } catch (_) {}

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

  final firestore = FirebaseFirestore.instance;
  final excuseState = await _resolveExcuseState(
    firestore: firestore,
    prefs: prefs,
    studentId: studentId,
    forceRefresh: true,
  );
  final within = _isNowWithinClassHours(classHours);
  final shouldTrack = within && !excuseState.isExcused;
  await prefs.setBool(BgKeys.enabled, shouldTrack);

  final service = FlutterBackgroundService();
  final running = await service.isRunning();
  if (shouldTrack) {
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
  final studentId = prefs.getString(BgKeys.studentId);
  if (studentId == null || studentId.isEmpty) return;

  final firestore = FirebaseFirestore.instance;
  final excuseState = await _resolveExcuseState(
    firestore: firestore,
    prefs: prefs,
    studentId: studentId,
    forceRefresh: true,
  );
  final shouldEnable = _isNowWithinClassHours(classHours) && !excuseState.isExcused;
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

class _ExcuseState {
  final bool isExcused;
  final DateTime? validUntil;
  final String? reasonLabel;

  const _ExcuseState({required this.isExcused, this.validUntil, this.reasonLabel});
}

Future<_ExcuseState> _resolveExcuseState({
  required FirebaseFirestore firestore,
  required SharedPreferences prefs,
  required String studentId,
  bool forceRefresh = false,
  Duration fallbackCacheDuration = const Duration(minutes: 2),
}) async {
  final now = DateTime.now();
  if (!forceRefresh) {
    final cachedStatus = prefs.getBool(BgKeys.cachedExcuseStatus);
    final cachedExpiryMs = prefs.getInt(BgKeys.cachedExcuseExpiry);
    final cachedReason = prefs.getString(BgKeys.cachedExcuseReason);
    if (cachedStatus != null && cachedExpiryMs != null) {
      final expiry = DateTime.fromMillisecondsSinceEpoch(cachedExpiryMs);
      if (now.isBefore(expiry)) {
        return _ExcuseState(
          isExcused: cachedStatus,
          validUntil: expiry,
          reasonLabel: cachedReason,
        );
      }
    }
  }

  final fresh = await _fetchExcuseState(firestore: firestore, studentId: studentId);
  final expiry = fresh.validUntil ?? now.add(fallbackCacheDuration);

  await prefs.setBool(BgKeys.cachedExcuseStatus, fresh.isExcused);
  await prefs.setInt(BgKeys.cachedExcuseExpiry, expiry.millisecondsSinceEpoch);
  if (fresh.reasonLabel != null && fresh.reasonLabel!.isNotEmpty) {
    await prefs.setString(BgKeys.cachedExcuseReason, fresh.reasonLabel!);
  } else {
    await prefs.remove(BgKeys.cachedExcuseReason);
  }

  return fresh;
}

Future<_ExcuseState> _fetchExcuseState({
  required FirebaseFirestore firestore,
  required String studentId,
}) async {
  final now = DateTime.now();
  try {
    final studentDocRef = firestore.collection('students').doc(studentId);
    final todayKey = _dateKey(now);
    final plannedAbsenceRef = studentDocRef.collection('plannedAbsences').doc(todayKey);

    final snapshots = await Future.wait<DocumentSnapshot<Map<String, dynamic>>>([
      plannedAbsenceRef.get(),
      studentDocRef.get(),
    ]);

    final plannedDoc = snapshots[0];
    final studentDoc = snapshots[1];

    bool isExcused = false;
    DateTime? validUntil;
    String? reasonLabel;

    if (plannedDoc.exists) {
      final data = plannedDoc.data();
      if (data != null) {
        DateTime start = _timestampToDateTime(data['forStartDateTime']) ??
            DateTime(now.year, now.month, now.day, 0, 0);
        DateTime end = _timestampToDateTime(data['forEndDateTime']) ??
            DateTime(now.year, now.month, now.day, 23, 59, 59);
        if (end.isBefore(start)) {
          end = start.add(const Duration(minutes: 1));
        }

        if (now.isBefore(start)) {
          validUntil = start;
        } else if (!now.isAfter(end)) {
          isExcused = true;
          validUntil = end;
          final reason = data['reason'] as String?;
          if (reason != null && reason.isNotEmpty) {
            reasonLabel = reason;
          }
        }
      }
    }

    if (!isExcused && studentDoc.exists) {
      final data = studentDoc.data();
      if (data != null) {
        final Timestamp? submittedTs = data['absenceReasonSubmittedAt'] as Timestamp?;
        final String? reason = data['absenceReason'] as String?;
        if (submittedTs != null && reason != null && reason.isNotEmpty) {
          final submittedAt = submittedTs.toDate();
          if (_isSameDay(submittedAt, now) && _reasonIndicatesExcuse(reason)) {
            isExcused = true;
            reasonLabel ??= reason;
            validUntil ??= DateTime(now.year, now.month, now.day, 23, 59, 59);
          }
        }
      }
    }

    return _ExcuseState(
      isExcused: isExcused,
      validUntil: validUntil,
      reasonLabel: reasonLabel,
    );
  } catch (_) {
    return const _ExcuseState(isExcused: false);
  }
}

String _dateKey(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final da = d.day.toString().padLeft(2, '0');
  return '$y$m$da';
}

DateTime? _timestampToDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool _reasonIndicatesExcuse(String raw) {
  final reason = raw.toLowerCase();
  const keywords = [
    'excuse',
    'excused',
    'medical',
    'doctor',
    'clinic',
    'hospital',
    'appointment',
    'sick',
    'ill',
    'family',
    'school activity',
    'off-campus',
    'competition',
    'tournament',
    'practice',
  ];
  for (final keyword in keywords) {
    if (reason.contains(keyword)) {
      return true;
    }
  }
  return false;
}
