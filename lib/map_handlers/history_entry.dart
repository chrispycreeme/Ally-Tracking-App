import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class HistoryEntry {
  final String id; // Firestore doc id
  final String studentId; // LRN/id, not auth uid
  final DateTime timestamp;
  final String type; // e.g. status_change, absence_reason
  final String message; // human-friendly text
  final LatLng? location; // optional
  final String? status; // Inside School / Outside School / Unknown
  final String? placeName; // optional human-readable place

  HistoryEntry({
    required this.id,
    required this.studentId,
    required this.timestamp,
    required this.type,
    required this.message,
    this.location,
    this.status,
    this.placeName,
  });

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type,
      'message': message,
      if (location != null)
        'location': GeoPoint(location!.latitude, location!.longitude),
      if (status != null) 'status': status,
      if (placeName != null) 'placeName': placeName,
    };
  }

  factory HistoryEntry.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final ts = data['timestamp'] as Timestamp?;
    final gp = data['location'] as GeoPoint?;
    return HistoryEntry(
      id: doc.id,
      studentId: (data['studentId'] as String?) ?? '',
      timestamp: ts?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      type: (data['type'] as String?) ?? 'unknown',
      message: (data['message'] as String?) ?? '',
      location: gp != null ? LatLng(gp.latitude, gp.longitude) : null,
      status: data['status'] as String?,
      placeName: data['placeName'] as String?,
    );
  }
}
