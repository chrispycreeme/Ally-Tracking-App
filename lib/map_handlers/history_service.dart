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

  // Fetch history entries for a given student limited to today (local device date)
  Future<List<HistoryEntry>> fetchTodayHistory(String studentId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final qs = await _studentHistoryCol(studentId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('timestamp', descending: false)
        .get();
    return qs.docs.map((d) => HistoryEntry.fromDoc(d)).toList();
  }

  // Fetch today's history for multiple students (in parallel)
  Future<List<HistoryEntry>> fetchTodayHistoryForStudents(List<String> studentIds) async {
    final futures = studentIds.map(fetchTodayHistory);
    final lists = await Future.wait(futures);
    final all = lists.expand((e) => e).toList();
    all.sort((a, b) {
      final byStudent = a.studentId.compareTo(b.studentId);
      if (byStudent != 0) return byStudent;
      return a.timestamp.compareTo(b.timestamp);
    });
    return all;
  }
}
