// lib/student_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
  final String role; // 'student' or 'teacher'
  final String? absenceReason; // Reason for being outside during class hours
  final DateTime? absenceReasonSubmittedAt; // When the reason was submitted

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
    this.role = 'student',
    this.absenceReason,
    this.absenceReasonSubmittedAt,
  });

  bool get isTeacher => role.toLowerCase() == 'teacher';

  // Check if current time is during class hours
  bool get isDuringClassHours {
    if (classHours == 'N/A' || classHours.isEmpty) return false;
    
    try {
      // Parse class hours format like "08:00-15:00" or "8:00 AM - 3:00 PM"
      final now = DateTime.now();
      final classTimeParts = classHours.split('-');
      
      if (classTimeParts.length != 2) return false;
      
      final startTimeStr = classTimeParts[0].trim();
      final endTimeStr = classTimeParts[1].trim();
      
      // Parse time strings (handle both 24-hour and 12-hour formats)
      final startTime = _parseTimeString(startTimeStr, now);
      final endTime = _parseTimeString(endTimeStr, now);
      
      if (startTime == null || endTime == null) return false;
      
      final currentTime = TimeOfDay.fromDateTime(now);
      final currentMinutes = currentTime.hour * 60 + currentTime.minute;
      final startMinutes = startTime.hour * 60 + startTime.minute;
      final endMinutes = endTime.hour * 60 + endTime.minute;
      
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    } catch (e) {
      print('Error parsing class hours: $e');
      return false;
    }
  }
  
  TimeOfDay? _parseTimeString(String timeStr, DateTime referenceDate) {
    try {
      // Remove extra whitespace
      timeStr = timeStr.trim();
      
      // Handle 12-hour format (e.g., "8:00 AM", "3:00 PM")
      if (timeStr.toUpperCase().contains('AM') || timeStr.toUpperCase().contains('PM')) {
        final isPM = timeStr.toUpperCase().contains('PM');
        final timeOnly = timeStr.replaceAll(RegExp(r'[APM\s]', caseSensitive: false), '');
        final parts = timeOnly.split(':');
        
        if (parts.length != 2) return null;
        
        int hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        
        if (isPM && hour != 12) hour += 12;
        if (!isPM && hour == 12) hour = 0;
        
        return TimeOfDay(hour: hour, minute: minute);
      } else {
        // Handle 24-hour format (e.g., "08:00", "15:00")
        final parts = timeStr.split(':');
        if (parts.length != 2) return null;
        
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (e) {
      return null;
    }
  }

  String get statusDisplay {
    switch (status) {
      case LocationStatus.insideSchool:
        return 'Inside School';
      case LocationStatus.outsideSchool:
        return 'Outside School';
      case LocationStatus.unknown:
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
      role: (data['role'] as String?) ?? 'student',
      absenceReason: data['absenceReason'] as String?,
      absenceReasonSubmittedAt: (data['absenceReasonSubmittedAt'] as Timestamp?)?.toDate(),
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
    String? role,
    String? absenceReason,
    DateTime? absenceReasonSubmittedAt,
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
      role: role ?? this.role,
      absenceReason: absenceReason ?? this.absenceReason,
      absenceReasonSubmittedAt: absenceReasonSubmittedAt ?? this.absenceReasonSubmittedAt,
    );
  }
}