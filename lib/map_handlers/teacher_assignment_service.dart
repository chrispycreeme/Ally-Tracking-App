import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to manage teacher -> student monitoring assignments.
/// Firestore structure (simple, compact):
/// Collection: teacherAssignments
///   Document ID: <teacherId>
///     Field: studentIds : [ "studentLrn1", "studentLrn2", ... ]
class TeacherAssignmentService {
  final FirebaseFirestore _firestore;
  TeacherAssignmentService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Stream of assigned student IDs for a teacher. Emits [] if doc absent.
  Stream<List<String>> getAssignedStudentIdsStream(String teacherId) {
    return _firestore
        .collection('teacherAssignments')
        .doc(teacherId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return <String>[];
      final data = doc.data() ?? {};
      final raw = data['studentIds'];
      if (raw is List) {
        return raw.whereType<String>().toList()..sort();
      }
      return <String>[];
    });
  }

  /// Ensure document exists (idempotent) before mutation.
  Future<void> _ensureDoc(String teacherId) async {
    final ref = _firestore.collection('teacherAssignments').doc(teacherId);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({'studentIds': <String>[]});
    }
  }

  Future<bool> addStudentToTeacher(String teacherId, String studentId) async {
    final sid = studentId.trim();
    if (sid.isEmpty) return false;
    await _ensureDoc(teacherId);
    final studentDoc =
        await _firestore.collection('students').doc(sid).get();
    if (!studentDoc.exists) {
      // Reject if student record missing.
      return false;
    }
    await _firestore.collection('teacherAssignments').doc(teacherId).update({
      'studentIds': FieldValue.arrayUnion([sid]),
    });
    return true;
  }

  Future<void> removeStudentFromTeacher(
      String teacherId, String studentId) async {
    await _firestore.collection('teacherAssignments').doc(teacherId).update({
      'studentIds': FieldValue.arrayRemove([studentId]),
    });
  }

  Future<void> replaceAllStudents(
      String teacherId, List<String> newStudentIds) async {
    await _firestore
        .collection('teacherAssignments')
        .doc(teacherId)
        .set({'studentIds': newStudentIds.where((e) => e.trim().isNotEmpty).toList()});
  }
}
