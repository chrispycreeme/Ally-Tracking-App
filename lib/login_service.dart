// lib/services/login_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../map_handlers/student_model.dart';

class LoginService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Future<Student> signInWithLrnAndPassword(String lrn, String password) async {
    try {
      final String email = '$lrn@school.com';
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw Exception(
          'Authentication failed. Please check your credentials.',
        );
      }

      DocumentSnapshot studentDoc = await _firestore
          .collection('students')
          .doc(lrn)
          .get();

      if (!studentDoc.exists) {
        throw Exception('Student data not found for the given LRN.');
      }

      Map<String, dynamic> data = studentDoc.data() as Map<String, dynamic>;

      final String id = data['id'] as String? ?? (throw Exception('Student ID missing.'));
      final String name = data['name'] as String? ?? (throw Exception('Student name missing.'));
      final String gradeLevel = data['gradeLevel'] as String? ?? (throw Exception('Student grade level missing.'));
      final String profileImageUrl = data['profileImageUrl'] as String? ?? 'https://picsum.photos/seed/default/100';
      
      final GeoPoint? geoPoint = data['currentLocation'] as GeoPoint?;
      if (geoPoint == null) {
        throw Exception('Student current location (GeoPoint) missing or invalid.');
      }
      final LatLng location = LatLng(geoPoint.latitude, geoPoint.longitude);

      final String? statusString = data['status'] as String?;
      LocationStatus status;
      if (statusString != null) {
        status = LocationStatus.values.firstWhere(
          (e) => e.toString().split('.').last.toLowerCase() == statusString.toLowerCase().replaceAll(' ', ''),
          orElse: () => LocationStatus.unknown,
        );
      } else {
        status = LocationStatus.unknown;
      }

      final String classHours = data['classHours'] as String? ?? 'N/A';
      final String dismissalTime = data['dismissalTime'] as String? ?? 'N/A';
      final String recentActivity = data['recentActivity'] as String? ?? 'No recent activity.';
      
      final Timestamp? timestamp = data['lastUpdated'] as Timestamp?;
      if (timestamp == null) {
        throw Exception('Student last updated timestamp missing or invalid.');
      }
      final DateTime lastUpdated = timestamp.toDate();

      return Student(
        id: id,
        name: name,
        gradeLevel: gradeLevel,
        profileImageUrl: profileImageUrl,
        currentLocation: location,
        status: status,
        classHours: classHours,
        dismissalTime: dismissalTime,
        recentActivity: recentActivity,
        lastUpdated: lastUpdated,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        throw Exception('Invalid LRN or password.');
      } else {
        throw Exception('An authentication error occurred: ${e.message ?? "Unknown error."}');
      }
    } catch (e) {
      print('Error during sign-in and data fetch: $e');
      throw Exception('Failed to load student data: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
