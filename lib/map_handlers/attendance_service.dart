import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'history_entry.dart';
import 'student_model.dart';

class StudentAttendanceDetail {
  final String studentId;
  final String name;
  final bool counted; // whether included in denominator
  final bool present;
  final bool excused;
  final String? absenceReason;
  final int? presentDurationMinutes; // for daily computations (best-effort)

  StudentAttendanceDetail({
    required this.studentId,
    required this.name,
    required this.counted,
    required this.present,
    required this.excused,
    this.absenceReason,
    this.presentDurationMinutes,
  });
}

class AttendanceSummary {
  final DateTime asOf; // now for realtime, end-of-day for daily
  final int totalAssigned; // all assigned students
  final int eligibleCount; // denominator (e.g., during class hours)
  final int presentCount; // counted and present
  final int excusedCount; // counted and absent with excused reason
  final double percentage; // presentCount / eligibleCount * 100
  final List<StudentAttendanceDetail> details;

  AttendanceSummary({
    required this.asOf,
    required this.totalAssigned,
    required this.eligibleCount,
    required this.presentCount,
    required this.excusedCount,
    required this.percentage,
    required this.details,
  });
}

/// Computes attendance metrics for teachers based on assigned students.
/// Firestore structure used:
/// - teacherAssignments/{teacherId} -> { studentIds: [] }
/// - students/{studentId} (fields from Student model)
/// - students/{studentId}/history (status_change entries with 'status')
class AttendanceService {
  final FirebaseFirestore _firestore;
  AttendanceService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<String>> _fetchAssignedStudentIds(String teacherId) async {
    final snap =
        await _firestore.collection('teacherAssignments').doc(teacherId).get();
    if (!snap.exists) return <String>[];
  final data = snap.data();
    final raw = data?['studentIds'];
    if (raw is List) return raw.whereType<String>().toList();
    return <String>[];
  }

  Future<List<Student>> _fetchStudentsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    // Firestore whereIn is limited to 10 per query. Chunk requests.
    const chunk = 10;
    final List<Student> result = [];
    for (int i = 0; i < ids.length; i += chunk) {
      final sub = ids.sublist(i, min(i + chunk, ids.length));
      final qs = await _firestore
          .collection('students')
          .where(FieldPath.documentId, whereIn: sub)
          .get();
      for (final d in qs.docs) {
        try {
          result.add(Student.fromFirestore(d));
        } catch (_) {}
      }
    }
    return result;
  }

  /// Real-time attendance for a teacher's assigned students.
  /// - If [countOnlyDuringClassHours] is true (default), only students who are
  ///   currently within their class hours are counted in the denominator.
  /// - Presence is "insideSchool" at the moment.
  Future<AttendanceSummary> computeRealtimeForTeacher(
    String teacherId, {
    bool countOnlyDuringClassHours = true,
  }) async {
    final now = DateTime.now();
    final assignedIds = await _fetchAssignedStudentIds(teacherId);
    final students = await _fetchStudentsByIds(assignedIds);

    int eligible = 0;
    int present = 0;
    int excused = 0;
    final List<StudentAttendanceDetail> details = [];

    for (final s in students) {
      final duringClass = s.isDuringClassHours;
      final counted = countOnlyDuringClassHours ? duringClass : true;
      final isPresent = s.status == LocationStatus.insideSchool &&
          (!countOnlyDuringClassHours || duringClass);

      bool isExcused = false;
      if (!isPresent && counted) {
        // Consider same-day absence reason as excused if it contains 'Excused'.
        final submitted = s.absenceReasonSubmittedAt;
        if (submitted != null && _isSameDay(submitted, now)) {
          final r = (s.absenceReason ?? '').toLowerCase();
          if (r.contains('excused')) isExcused = true;
        }
      }

      if (counted) {
        eligible += 1;
        if (isPresent) present += 1;
        if (isExcused) excused += 1;
      }

      details.add(StudentAttendanceDetail(
        studentId: s.id,
        name: s.name,
        counted: counted,
        present: isPresent,
        excused: isExcused,
        absenceReason: s.absenceReason,
      ));
    }

    final pct = eligible == 0 ? 0.0 : (present / eligible) * 100.0;
    return AttendanceSummary(
      asOf: now,
      totalAssigned: students.length,
      eligibleCount: eligible,
      presentCount: present,
      excusedCount: excused,
      percentage: pct,
      details: details,
    );
  }

  /// Daily attendance over a specific [date] (local).
  /// Counts a student as present if they were inside the school at any time
  /// during their configured class hours on that date. Optionally, you can
  /// set [requireMinimumMinutesInside] to require a minimum inside duration.
  Future<AttendanceSummary> computeDailyForTeacher(
    String teacherId, {
    required DateTime date,
    int requireMinimumMinutesInside = 0,
    bool requireOnlineForPresent = false,
  }) async {
    final day = DateTime(date.year, date.month, date.day);
    final assignedIds = await _fetchAssignedStudentIds(teacherId);
    final students = await _fetchStudentsByIds(assignedIds);

    int eligible = 0;
    int present = 0;
    int excused = 0;
    final details = <StudentAttendanceDetail>[];

    for (final s in students) {
      final hours = _parseClassHours(s.classHours, day);
      if (hours == null) {
        // Skip if no valid class hours for that day
        details.add(StudentAttendanceDetail(
          studentId: s.id,
          name: s.name,
          counted: false,
          present: false,
          excused: false,
          absenceReason: s.absenceReason,
        ));
        continue;
      }
      final start = hours.$1;
      final end = hours.$2;
      if (!end.isAfter(start)) {
        details.add(StudentAttendanceDetail(
          studentId: s.id,
          name: s.name,
          counted: false,
          present: false,
          excused: false,
          absenceReason: s.absenceReason,
        ));
        continue;
      }

      eligible += 1;
      final timeline = await _fetchStatusTimeline(s.id, start, end);
      final insideMinutes = _computeInsideMinutes(timeline, start, end);
    final isPresent = insideMinutes >= requireMinimumMinutesInside &&
      (!requireOnlineForPresent || s.isOnline);

      bool isExcused = false;
      if (!isPresent) {
        final submitted = s.absenceReasonSubmittedAt;
        if (submitted != null && _isSameDay(submitted, day)) {
          final r = (s.absenceReason ?? '').toLowerCase();
          if (r.contains('excused')) isExcused = true;
        }
      }

      if (isPresent) present += 1;
      if (isExcused) excused += 1;

      details.add(StudentAttendanceDetail(
        studentId: s.id,
        name: s.name,
        counted: true,
        present: isPresent,
        excused: isExcused,
        absenceReason: s.absenceReason,
        presentDurationMinutes: insideMinutes,
      ));
    }

    final pct = eligible == 0 ? 0.0 : (present / eligible) * 100.0;
    return AttendanceSummary(
      asOf: day.add(const Duration(days: 1)).subtract(const Duration(seconds: 1)),
      totalAssigned: students.length,
      eligibleCount: eligible,
      presentCount: present,
      excusedCount: excused,
      percentage: pct,
      details: details,
    );
  }

  // Build a status timeline between [start, end], including one entry
  // right before start to infer initial state.
  Future<List<HistoryEntry>> _fetchStatusTimeline(
      String studentId, DateTime start, DateTime end) async {
    final col = _firestore
        .collection('students')
        .doc(studentId)
        .collection('history');

    // Last state before the window
    final beforeQs = await col
        .where('timestamp', isLessThan: Timestamp.fromDate(start))
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    final withinQs = await col
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThan: Timestamp.fromDate(end))
        .orderBy('timestamp', descending: false)
        .get();

    final entries = <HistoryEntry>[];
    if (beforeQs.docs.isNotEmpty) {
      try {
        entries.add(HistoryEntry.fromDoc(beforeQs.docs.first));
      } catch (_) {}
    }
    for (final d in withinQs.docs) {
      try {
        entries.add(HistoryEntry.fromDoc(d));
      } catch (_) {}
    }
    // Keep only entries that have type status_change (others may exist)
    entries.retainWhere((e) => (e.type == 'status_change'));
    return entries;
  }

  int _computeInsideMinutes(
      List<HistoryEntry> entries, DateTime start, DateTime end) {
    if (start.isAfter(end)) return 0;
    // Derive state at start
    String state = 'Outside School';
    if (entries.isNotEmpty && entries.first.timestamp.isBefore(start)) {
      state = entries.first.status ?? state;
    }

    DateTime cursor = start;
    int inside = 0;

    for (final e in entries) {
      if (e.timestamp.isBefore(start)) {
        // already accounted for initial state
        continue;
      }
      final segEnd = e.timestamp.isAfter(end) ? end : e.timestamp;
      if (segEnd.isAfter(cursor)) {
        if ((state.toLowerCase().contains('inside'))) {
          inside += segEnd.difference(cursor).inMinutes;
        }
        cursor = segEnd;
      }
      state = e.status ?? state;
      if (!cursor.isBefore(end)) break;
    }

    if (cursor.isBefore(end) && state.toLowerCase().contains('inside')) {
      inside += end.difference(cursor).inMinutes;
    }

    return inside;
  }

  (DateTime, DateTime)? _parseClassHours(String classHours, DateTime day) {
    if (classHours.trim().isEmpty || classHours == 'N/A') return null;
    final parts = classHours.split('-');
    if (parts.length != 2) return null;
    final startStr = parts[0].trim();
    final endStr = parts[1].trim();

    final startTod = _parseTimeOfDay(startStr);
    final endTod = _parseTimeOfDay(endStr);
    if (startTod == null || endTod == null) return null;

    final start = DateTime(day.year, day.month, day.day, startTod.$1, startTod.$2);
    final end = DateTime(day.year, day.month, day.day, endTod.$1, endTod.$2);
    return (start, end);
  }

  (int, int)? _parseTimeOfDay(String timeStr) {
    try {
      final s = timeStr.trim();
      final upper = s.toUpperCase();
      if (upper.contains('AM') || upper.contains('PM')) {
        final isPM = upper.contains('PM');
        final cleaned = upper.replaceAll(RegExp(r'[APM\s]'), '');
        final parts = cleaned.split(':');
        if (parts.length != 2) return null;
        int h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        if (isPM && h != 12) h += 12;
        if (!isPM && h == 12) h = 0;
        return (h, m);
      } else {
        final parts = s.split(':');
        if (parts.length != 2) return null;
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        return (h, m);
      }
    } catch (_) {
      return null;
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
