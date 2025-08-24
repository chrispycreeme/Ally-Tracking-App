import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import 'history_entry.dart';

class HistoryService {
  final FirebaseFirestore _firestore;
  HistoryService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _studentHistoryCol(String studentId) {
    return _firestore
        .collection('students')
        .doc(studentId)
        .collection('history');
  }

  Future<void> addStatusChange({
    required String studentId,
    required DateTime timestamp,
    required String statusDisplay,
    required LatLng location,
    String? placeName,
  }) async {
    await _studentHistoryCol(studentId).add({
      'studentId': studentId,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': 'status_change',
      'status': statusDisplay,
      'message': statusDisplay == 'Inside School'
          ? 'Entered school zone'
          : statusDisplay == 'Outside School'
              ? 'Left school zone'
              : 'Status changed',
      'location': GeoPoint(location.latitude, location.longitude),
      if (placeName != null) 'placeName': placeName,
    });
  }

  Future<void> addAbsenceReason({
    required String studentId,
    required DateTime timestamp,
    required String reason,
    LatLng? location,
    String? placeName,
  }) async {
    await _studentHistoryCol(studentId).add({
      'studentId': studentId,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': 'absence_reason',
      'message': 'Absence reason submitted: $reason',
      if (location != null)
        'location': GeoPoint(location.latitude, location.longitude),
      if (placeName != null) 'placeName': placeName,
    });
  }

  // Stream recent history for a student, newest first, limit optional
  Stream<List<HistoryEntry>> streamStudentHistory(String studentId, {int limit = 100}) {
    return _studentHistoryCol(studentId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((qs) => qs.docs.map((d) => HistoryEntry.fromDoc(d)).toList());
  }
}
