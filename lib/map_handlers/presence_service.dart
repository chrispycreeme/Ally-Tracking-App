import 'package:cloud_firestore/cloud_firestore.dart';

/// Presence entries live under: students/{studentId}/presence
/// Document shape:
/// {
///   lastSeen: Timestamp (serverTimestamp when updated),
///   isOnline: bool (true while client actively heartbeating),
/// }
class PresenceService {
  final FirebaseFirestore _firestore;
  PresenceService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Update presence for [studentId]. Use server timestamp to avoid clock skew.
  Future<void> heartbeat(String studentId, {bool isOnline = true}) async {
    final doc = _firestore.collection('students').doc(studentId).collection('presence').doc('current');
    try {
      await doc.set({
        'lastSeen': FieldValue.serverTimestamp(),
        'isOnline': isOnline,
      }, SetOptions(merge: true));
    } catch (e) {
      // swallow - presence is best-effort
    }
  }

  /// Mark explicitly offline (optional)
  Future<void> setOffline(String studentId) async {
    final doc = _firestore.collection('students').doc(studentId).collection('presence').doc('current');
    try {
      await doc.set({'isOnline': false, 'lastSeen': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    } catch (e) {}
  }

  /// Returns presence doc snapshot stream for a student (or null if missing)
  Stream<DocumentSnapshot<Map<String, dynamic>>> presenceStream(String studentId) {
    return _firestore.collection('students').doc(studentId).collection('presence').doc('current').snapshots();
  }

  /// Read presence once
  Future<DocumentSnapshot<Map<String, dynamic>>?> readPresence(String studentId) async {
    try {
      final d = await _firestore.collection('students').doc(studentId).collection('presence').doc('current').get();
      return d;
    } catch (_) {
      return null;
    }
  }
}
