import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'student_model.dart';
class MapService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Future<List<List<LatLng>>> fetchBuildingData(LatLngBounds bounds) async {

    return [];
  }

  // New method to get a real-time stream of all students
  Stream<List<Student>> getStudentsStream() {
    return _firestore.collection('students').snapshots().map((snapshot) {
      try {
        return snapshot.docs
            .map((doc) => Student.fromFirestore(doc))
            .toList();
      } catch (e) {
        print('❌ Error parsing student data: $e');
        return [];
      }
    });
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
}