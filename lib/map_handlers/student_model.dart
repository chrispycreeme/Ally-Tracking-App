// lib/student_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

// Enum to represent the student's location status, making the code more readable.
enum LocationStatus {
  insideSchool,
  outsideSchool, // This will now encompass everything outside insideSchool
  unknown,
}

class Student {
  final String id;
  final String name;
  final String gradeLevel;
  final String profileImageUrl;
  final LatLng currentLocation;
  final LocationStatus status;
  final String classHours;
  final String dismissalTime;
  final String recentActivity;
  final DateTime lastUpdated;

  Student({
    required this.id,
    required this.name,
    required this.gradeLevel,
    required this.profileImageUrl,
    required this.currentLocation,
    required this.status,
    required this.classHours,
    required this.dismissalTime,
    required this.recentActivity,
    required this.lastUpdated,
  });

  String get statusDisplay {
    switch (status) {
      case LocationStatus.insideSchool:
        return 'Inside School';
      case LocationStatus.outsideSchool:
        return 'Outside School';
      case LocationStatus.unknown:
      default:
        return 'Unknown';
    }
  }

  // Factory constructor to create a Student instance from a Firestore document
  factory Student.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Safely parse GeoPoint to LatLng
    final GeoPoint? geoPoint = data['currentLocation'] as GeoPoint?;
    final LatLng location = geoPoint != null
        ? LatLng(geoPoint.latitude, geoPoint.longitude)
        : const LatLng(0, 0); // Default location if null

    // Safely parse status string to enum
    LocationStatus status;
    final String? statusString = data['status'] as String?;
    if (statusString != null) {
      status = LocationStatus.values.firstWhere(
        (e) => e.toString().split('.').last.toLowerCase() == statusString.toLowerCase().replaceAll(' ', ''),
        orElse: () => LocationStatus.unknown,
      );
    } else {
      status = LocationStatus.unknown;
    }

    // Safely parse Timestamp to DateTime
    final Timestamp? timestamp = data['lastUpdated'] as Timestamp?;
    final DateTime lastUpdated = timestamp != null ? timestamp.toDate() : DateTime.now();

    return Student(
      id: data['id'] ?? doc.id,
      name: data['name'] ?? 'Unknown Name',
      gradeLevel: data['gradeLevel'] ?? 'N/A',
      profileImageUrl: data['profileImageUrl'] ?? 'https://picsum.photos/seed/default/100',
      currentLocation: location,
      status: status,
      classHours: data['classHours'] ?? 'N/A',
      dismissalTime: data['dismissalTime'] ?? 'N/A',
      recentActivity: data['recentActivity'] ?? 'No recent activity.',
      lastUpdated: lastUpdated,
    );
  }

  Student copyWith({
    String? id,
    String? name,
    String? gradeLevel,
    String? profileImageUrl,
    LatLng? currentLocation,
    LocationStatus? status,
    String? classHours,
    String? dismissalTime,
    String? recentActivity,
    DateTime? lastUpdated,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      currentLocation: currentLocation ?? this.currentLocation,
      status: status ?? this.status,
      classHours: classHours ?? this.classHours,
      dismissalTime: dismissalTime ?? this.dismissalTime,
      recentActivity: recentActivity ?? this.recentActivity,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}