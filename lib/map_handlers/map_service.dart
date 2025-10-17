import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'student_model.dart';
import 'building_model.dart';
class MapService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// Fetch building polygons within current map bounds.
  /// Expects a Firestore collection 'buildings' with documents shaped like:
  ///   name: String
  ///   polygon: [GeoPoint, GeoPoint, ...]  (ordered, no need to repeat first at end)
  ///   centroid: GeoPoint (optional)
  ///   level: int (optional)
  ///   color: '#RRGGBB' (optional)
  Future<List<Building>> fetchBuildings(LatLngBounds bounds) async {
    try {
      // Basic server-side geo filtering isn't native for polygons; we do a coarse filter
      // by checking if any vertex lies inside requested bounds. We'll fetch all and filter client-side
      // unless dataset becomes large – then you'd integrate a geohash index.
      final snap = await _firestore.collection('buildings').get();
    final buildings = snap.docs
      .map((d) => Building.fromFirestore(d))
      .where((b) => b.points.any((p) =>
              p.latitude >= bounds.south &&
              p.latitude <= bounds.north &&
              p.longitude >= bounds.west &&
              p.longitude <= bounds.east))
          .toList();
      return buildings;
    } catch (e) {
      print('❌ fetchBuildings error: $e');
      return [];
    }
  }

  /// Legacy compatibility for existing map_screen code calling fetchBuildingData
  Future<List<List<LatLng>>> fetchBuildingData(LatLngBounds bounds) async {
    final buildings = await fetchBuildings(bounds);
  return buildings.map((b) => b.points).toList();
  }

  /// Utility: determine which building (if any) contains a point.
  /// Uses winding number (ray casting) algorithm.
  String? buildingContainingPoint(LatLng point, List<Building> buildings) {
    for (final b in buildings) {
      if (_pointInPolygon(point, b.points)) return b.name;
    }
    return null;
  }

  bool _pointInPolygon(LatLng p, List<LatLng> poly) {
    if (poly.length < 3) return false;
    bool inside = false;
    for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final xi = poly[i].latitude, yi = poly[i].longitude;
      final xj = poly[j].latitude, yj = poly[j].longitude;
      final intersect = ((yi > p.longitude) != (yj > p.longitude)) &&
          (p.latitude < (xj - xi) * (p.longitude - yi) / (yj - yi + 1e-12) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  // Simplified method to get students based on user role - works for both students and teachers
  Stream<List<Student>> getStudentsStream() async* {
    final user = _auth.currentUser;
    if (user == null) {
      yield [];
      return;
    }

    try {
      // For development/testing: try to get all students and let the app filter them
      // This approach works when security rules are more permissive
      yield* _firestore.collection('students').snapshots().map((snapshot) {
        try {
          return snapshot.docs
              .map((doc) => Student.fromFirestore(doc))
              .toList();
        } catch (e) {
          print('❌ Error parsing student data: $e');
          return [];
        }
      });
    } catch (e) {
      print('❌ Error in getStudentsStream: $e');
      // Fallback: return empty list
      yield [];
    }
  }

  Future<void> updateStudentLocation(
      String studentId,
      LatLng newLocation,
      LocationStatus newStatus,
      String recentActivity,
      DateTime lastUpdated,
      {String? currentBuilding}
      ) async {
    try {
      final updateData = {
        'currentLocation': GeoPoint(newLocation.latitude, newLocation.longitude),
        'status': newStatus.toString().split('.').last,
        'recentActivity': recentActivity,
        'lastUpdated': Timestamp.fromDate(lastUpdated),
      };
      if (currentBuilding != null) {
        updateData['currentBuilding'] = currentBuilding;
      }
      await _firestore.collection('students').doc(studentId).update(updateData);
      print('✅ Student $studentId location updated in Firestore.');
    } catch (e) {
      print('❌ Error updating student location in Firestore: $e');
      rethrow;
    }
  }

  Future<void> updateAbsenceReason(
      String studentId,
      String reason,
      DateTime submittedAt,
      ) async {
    try {
      // Validate inputs
      if (studentId.trim().isEmpty) {
        throw Exception('Student ID cannot be empty');
      }
      
      if (reason.trim().isEmpty) {
        throw Exception('Absence reason cannot be empty');
      }
      
      print('🔄 Updating absence reason for student: $studentId');
      print('🔄 Reason: ${reason.trim()}');
      
      await _firestore.collection('students').doc(studentId).update({
        'absenceReason': reason.trim(),
        'absenceReasonSubmittedAt': Timestamp.fromDate(submittedAt),
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      });
      print('✅ Student $studentId absence reason updated in Firestore.');
    } catch (e) {
      print('❌ Error updating absence reason in Firestore: $e');
      print('❌ Student ID: $studentId');
      print('❌ Reason: $reason');
      rethrow;
    }
  }

  /// Add or update a planned absence for a specific date.
  /// Stores under students/{id}/plannedAbsences/{YYYYMMDD}
  Future<void> addPlannedAbsence(
    String studentId,
    DateTime forDate,
    String reason,
    DateTime submittedAt, {
    DateTime? forStartTime,
    DateTime? forEndTime,
  }) async {
    try {
      if (studentId.trim().isEmpty) throw Exception('Student ID cannot be empty');
      if (reason.trim().isEmpty) throw Exception('Planned absence reason cannot be empty');
      final key = _dateKey(forDate);
      await _firestore
          .collection('students')
          .doc(studentId)
          .collection('plannedAbsences')
          .doc(key)
          .set({
        'forDate': Timestamp.fromDate(DateTime(forDate.year, forDate.month, forDate.day)),
        'reason': reason.trim(),
        'submittedAt': Timestamp.fromDate(submittedAt),
        if (forStartTime != null) 'forStartDateTime': Timestamp.fromDate(forStartTime),
        if (forEndTime != null) 'forEndDateTime': Timestamp.fromDate(forEndTime),
      }, SetOptions(merge: true));
    } catch (e) {
      print('❌ addPlannedAbsence error: $e');
      rethrow;
    }
  }

  /// Get planned absence document for a specific date; returns map or null.
  Future<Map<String, dynamic>?> getPlannedAbsenceForDate(
    String studentId,
    DateTime forDate,
  ) async {
    try {
      final key = _dateKey(forDate);
      final doc = await _firestore
          .collection('students')
          .doc(studentId)
          .collection('plannedAbsences')
          .doc(key)
          .get();
      if (!doc.exists) return null;
      return doc.data() as Map<String, dynamic>;
    } catch (e) {
      print('❌ getPlannedAbsenceForDate error: $e');
      return null;
    }
  }

  String _dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}'
      '${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}'
  ;
}