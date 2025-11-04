import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'map_handlers/presence_service.dart';
import 'notification_service.dart';

const _kNotificationChannelId = 'ally_background_tracking';
const _kNotificationId = 9971;
const _kNotificationTitleActive = 'Ally Tracking Active';
const _kNotificationTitleIdle = 'Ally Tracking Idle';
const _kNotificationTitlePaused = 'Ally Tracking Paused';

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
  if (isRunning) return;

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: backgroundServiceEntry,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: _kNotificationChannelId,
      initialNotificationTitle: 'Ally Tracking',
      initialNotificationContent: 'Preparing background tracking...',
      foregroundServiceNotificationId: _kNotificationId,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
    ),
  );
}

/// Entry point for the background isolate.
@pragma('vm:entry-point')
Future<void> backgroundServiceEntry(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }

  // Initialize notification service for persistent notifications
  await NotificationService().init();

  final firestore = FirebaseFirestore.instance;
  final prefs = await SharedPreferences.getInstance();
  final presenceService = PresenceService(firestore: firestore);

  StreamSubscription<Position>? positionSubscription;
  Future<void> positionUpdateQueue = Future.value();
  GeoPoint? lastBroadcastPoint;
  DateTime? lastBroadcastAt;
  Timer? stateTimer;
  bool evaluating = false;
  bool forceNextExcuseRefresh = false;
  String notificationTitle = _kNotificationTitleIdle;
  String notificationContent = 'Waiting for next class hours window';
  late Future<void> Function({bool force}) evaluate;

  void updateNotification(String title, String content) {
    notificationTitle = title;
    notificationContent = content;
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(title: title, content: content);
    }
    // Also show as a persistent notification so it cannot be swiped away (only when logged in)
    if (NotificationService().isLoggedIn) {
      NotificationService().showPersistentNotification(
        title: title,
        content: content,
        notificationId: _kNotificationId,
      );
    }
  }

  Future<void> stopPositionStream({String? reason}) async {
    await positionSubscription?.cancel();
    positionSubscription = null;
    if (reason != null) {
      updateNotification(_kNotificationTitlePaused, reason);
    }
  }

  Future<void> pushPosition(Position position, String studentId) async {
    final now = DateTime.now();
    final GeoPoint nextPoint = GeoPoint(position.latitude, position.longitude);

    if (!_shouldBroadcast(
      lastPoint: lastBroadcastPoint,
      lastSentAt: lastBroadcastAt,
      candidate: nextPoint,
      now: now,
    )) {
      return;
    }

    lastBroadcastPoint = nextPoint;
    lastBroadcastAt = now;

    await firestore.collection('students').doc(studentId).update({
      'currentLocation': nextPoint,
      'lastUpdated': Timestamp.fromDate(now),
    });

    try {
      await presenceService.heartbeat(studentId, isOnline: true);
    } catch (_) {}

    updateNotification(_kNotificationTitleActive, 'Last update ${_formatClock(now)}');
  }

  Future<void> enqueuePosition(Position position, String studentId) {
    positionUpdateQueue = positionUpdateQueue
        .then((_) => pushPosition(position, studentId))
        .catchError((_, __) {});
    return positionUpdateQueue;
  }

  Future<void> startPositionStream(String studentId) async {
    if (positionSubscription != null) return;

    updateNotification(_kNotificationTitleActive, 'Acquiring GPS fix...');
    positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen(
      (position) {
        enqueuePosition(position, studentId);
      },
      onError: (Object error) async {
        await stopPositionStream(reason: 'Location error; retrying soon');
        forceNextExcuseRefresh = true;
        unawaited(evaluate(force: true));
      },
      cancelOnError: false,
    );

    try {
      final initial = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
      );
      await enqueuePosition(initial, studentId);
    } catch (_) {}
  }

  evaluate = ({bool force = false}) async {
    if (evaluating) return;
    evaluating = true;
    try {
      final studentId = prefs.getString(BgKeys.studentId);
      final classHours = prefs.getString(BgKeys.classHours) ?? '';

      if (studentId == null || studentId.isEmpty) {
        await stopPositionStream();
        await prefs.setBool(BgKeys.enabled, false);
        updateNotification(_kNotificationTitleIdle, 'Waiting for login');
        return;
      }

      final withinClassHours = _isNowWithinClassHours(classHours);
      final excuseState = await _resolveExcuseState(
        firestore: firestore,
        prefs: prefs,
        studentId: studentId,
        forceRefresh: force || forceNextExcuseRefresh,
      );
      forceNextExcuseRefresh = false;

      final shouldTrack = withinClassHours && !excuseState.isExcused;
      final previouslyEnabled = prefs.getBool(BgKeys.enabled) ?? false;
      if (previouslyEnabled != shouldTrack) {
        await prefs.setBool(BgKeys.enabled, shouldTrack);
      }

      if (!shouldTrack) {
        final pausedMessage = withinClassHours
            ? 'Monitoring paused: ${excuseState.reasonLabel ?? 'Excused'}'
            : 'Outside class hours';
        await stopPositionStream(reason: pausedMessage);
        return;
      }

      final locationPermission = await Geolocator.checkPermission();
      if (locationPermission == LocationPermission.denied ||
          locationPermission == LocationPermission.deniedForever) {
        await stopPositionStream(reason: 'Location permission required');
        return;
      }

      if (!await Geolocator.isLocationServiceEnabled()) {
        await stopPositionStream(reason: 'Location services disabled');
        return;
      }

      await startPositionStream(studentId);
    } finally {
      evaluating = false;
    }
  };

  updateNotification(notificationTitle, notificationContent);

  stateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
    unawaited(evaluate());
  });

  await evaluate(force: true);

  service.on('stopService').listen((event) async {
    stateTimer?.cancel();
    await stopPositionStream();
    await prefs.setBool(BgKeys.enabled, false);
    service.stopSelf();
  });

  service.on('refreshNotification').listen((event) {
    updateNotification(notificationTitle, notificationContent);
  });

  service.on('reevaluate').listen((event) {
    bool force = false;
    if (event is Map) {
      final map = event as Map<dynamic, dynamic>;
      final dynamic value = map['force'];
      force = value is bool && value;
    }
    unawaited(evaluate(force: force));
  });
}

/// Called after login to provide student details to the service.
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
  var running = await service.isRunning();
  if (!running) {
    await service.startService();
    running = true;
    await Future.delayed(const Duration(milliseconds: 500));
  }

  if (running) {
    service.invoke('reevaluate', {'force': true});
  }
}

/// Call this whenever student data changes (e.g., schedule updated) or on app resume.
Future<void> reevaluateBackgroundTracking() async {
  final service = FlutterBackgroundService();
  var running = await service.isRunning();
  if (!running) {
    await service.startService();
    running = true;
    await Future.delayed(const Duration(milliseconds: 500));
  }

  if (running) {
    service.invoke('reevaluate', {'force': true});
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
    if (parts.length != 2) return _TimeOfDay(0, 0);
    var h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    if (isPM && h != 12) h += 12;
    if (!isPM && h == 12) h = 0;
    return _TimeOfDay(h, m);
  } else {
    final parts = raw.split(':');
    if (parts.length != 2) return _TimeOfDay(0, 0);
    return _TimeOfDay(int.parse(parts[0]), int.parse(parts[1]));
  }
}

class _TimeOfDay {
  final int hour;
  final int minute;
  const _TimeOfDay(this.hour, this.minute);
}

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

bool _shouldBroadcast({
  GeoPoint? lastPoint,
  DateTime? lastSentAt,
  required GeoPoint candidate,
  required DateTime now,
}) {
  if (lastPoint == null || lastSentAt == null) {
    return true;
  }

  final distance = Geolocator.distanceBetween(
    lastPoint.latitude,
    lastPoint.longitude,
    candidate.latitude,
    candidate.longitude,
  );

  if (distance >= 5) {
    return true;
  }

  return now.difference(lastSentAt).inSeconds >= 45;
}

String _formatClock(DateTime value) {
  final h = value.hour.toString().padLeft(2, '0');
  final m = value.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
