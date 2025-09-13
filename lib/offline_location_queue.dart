import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

/// Model for a pending location update that couldn't be sent due to lack of connectivity.
class PendingLocationUpdate {
  final String studentId;
  final double latitude;
  final double longitude;
  final String status; // serialized enum value
  final String recentActivity;
  final DateTime lastUpdated;
  final String? currentBuilding;

  PendingLocationUpdate({
    required this.studentId,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.recentActivity,
    required this.lastUpdated,
    this.currentBuilding,
  });

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'latitude': latitude,
        'longitude': longitude,
        'status': status,
        'recentActivity': recentActivity,
        'lastUpdated': lastUpdated.toIso8601String(),
        'currentBuilding': currentBuilding,
      };

  factory PendingLocationUpdate.fromJson(Map<String, dynamic> json) =>
      PendingLocationUpdate(
        studentId: json['studentId'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        status: json['status'] as String,
        recentActivity: json['recentActivity'] as String,
        lastUpdated: DateTime.parse(json['lastUpdated'] as String),
        currentBuilding: json['currentBuilding'] as String?,
      );
}

/// A lightweight offline queue to buffer location updates when device is offline.
/// Uses SharedPreferences for persistence so data survives app restarts.
/// When connectivity is restored, the queue flushes items FIFO.
class OfflineLocationQueue {
  static const String _storageKey = 'pending_location_updates_v1';
  static final OfflineLocationQueue _instance = OfflineLocationQueue._internal();
  factory OfflineLocationQueue() => _instance;
  OfflineLocationQueue._internal();

  final List<PendingLocationUpdate> _queue = [];
  bool _initialized = false;
  bool _flushing = false;

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? [];
    _queue
      ..clear()
      ..addAll(raw.map((e) => PendingLocationUpdate.fromJson(jsonDecode(e) as Map<String, dynamic>)));
    _initialized = true;
  }

  int get length => _queue.length;
  bool get isEmpty => _queue.isEmpty;

  Future<void> add(PendingLocationUpdate update) async {
    await initialize();
    _queue.add(update);
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _queue.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_storageKey, list);
  }

  /// Attempt to flush the queue. Provide a function that performs the Firestore write.
  Future<void> flush(Future<void> Function(PendingLocationUpdate) sender) async {
    await initialize();
    if (_flushing) return; // prevent re-entrancy
    _flushing = true;
    try {
      while (_queue.isNotEmpty) {
        final item = _queue.first;
        try {
          await sender(item);
          _queue.removeAt(0);
          await _persist();
        } on FirebaseException catch (e) {
          // If it's a network error, stop and wait for next connectivity event
          if (e.code == 'unavailable') break; // Firestore offline
          rethrow;
        } catch (_) {
          // For generic errors, break to avoid tight loop.
          break;
        }
      }
    } finally {
      _flushing = false;
    }
  }

  /// Convenience creator from current data properties.
  PendingLocationUpdate create({
    required String studentId,
    required LatLng location,
    required String status,
    required String recentActivity,
    required DateTime lastUpdated,
    String? currentBuilding,
  }) => PendingLocationUpdate(
        studentId: studentId,
        latitude: location.latitude,
        longitude: location.longitude,
        status: status,
        recentActivity: recentActivity,
        lastUpdated: lastUpdated,
        currentBuilding: currentBuilding,
      );
}
