import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'student_model.dart';
class MapService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  Future<List<List<LatLng>>> fetchBuildingData(LatLngBounds bounds) async {
    return [];
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
      ) async {
    try {
      await _firestore.collection('students').doc(studentId).update({
        'currentLocation': GeoPoint(newLocation.latitude, newLocation.longitude),
        'status': newStatus.toString().split('.').last, // Convert enum to string
        'recentActivity': recentActivity,
        'lastUpdated': Timestamp.fromDate(lastUpdated), // Convert DateTime to Timestamp
      });
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
}