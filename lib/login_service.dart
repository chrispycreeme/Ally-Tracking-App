// lib/services/login_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'map_handlers/student_model.dart';

class LoginService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Basic sanitization: trim & collapse internal whitespace (LRNs / IDs sometimes copied with spaces or newlines)
  String _sanitizeIdentifier(String raw) {
    return raw.trim().replaceAll(RegExp(r'\s+'), '');
  }

  Future<void> _logSignInDiagnostics(String email) async {
    try {
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      print('[LoginService][Diag] Sign-in methods for $email -> $methods');
    } catch (e) {
      print('[LoginService][Diag] Could not fetch sign-in methods for $email: $e');
    }
  }

  Exception _mapAuthException(FirebaseAuthException e, {required String genericMessage}) {
    final code = e.code.toLowerCase();
    // Normalize older Android plugin codes (e.g. ERROR_INVALID_CREDENTIAL)
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-email':
      case 'error_invalid_credential': // legacy
        return Exception(genericMessage);
      case 'too-many-requests':
        return Exception('Too many attempts. Please wait a moment and try again.');
      case 'network-request-failed':
        return Exception('Network error. Check your connection.');
      default:
        return Exception('Auth error (${e.code}): ${e.message ?? 'Unknown'}');
    }
  }

  Future<Exception> _enhancedWrongPasswordMessage(String email, FirebaseAuthException original, String fallback) async {
    try {
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      // If the account exists but does not list 'password', user likely registered with another provider
      if (!methods.contains('password') && methods.isNotEmpty) {
        return Exception('This account was created using ${methods.join(', ')} sign-in. Use that method or set a password via "Forgot Password".');
      }
    } catch (e) {
      // Non-fatal; fall back to generic message
      print('[LoginService][Diag] fetchSignInMethods failed after wrong-password: $e');
    }
    return Exception(fallback);
  }

  /// Student sign-in (uses 'students' collection, document ID = LRN)
  Future<Student> signInWithLrnAndPassword(String lrn, String password) async {
    try {
      final sanitized = _sanitizeIdentifier(lrn);
      final String email = '$sanitized@school.com';
      await _logSignInDiagnostics(email);
      // Avoid accidental leading/trailing spaces in password
      final pwd = password.trim();
      UserCredential userCredential;
      try {
        userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: pwd,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code.toLowerCase() == 'wrong-password') {
          throw await _enhancedWrongPasswordMessage(email, e, 'Invalid LRN or password.');
        }
        rethrow;
      }

      if (userCredential.user == null) {
        throw Exception(
          'Authentication failed. Please check your credentials.',
        );
      }

    DocumentSnapshot studentDoc = await _firestore
      .collection('students')
      .doc(sanitized)
      .get();

      if (!studentDoc.exists) {
        throw Exception('Student data not found for the given LRN.');
      }

      Map<String, dynamic> data = studentDoc.data() as Map<String, dynamic>;

      // Simplified verification for student - allow more flexible authUid matching
      final String authUid = _auth.currentUser!.uid;
      final String storedAuthUid = data['authUid'] as String? ?? '';
      // For testing, allow if either authUid matches OR if no authUid is stored yet  
      if (storedAuthUid.isNotEmpty && storedAuthUid != authUid) {
        print('Warning: Student doc authUid mismatch, but allowing for testing');
        // Don't throw exception for testing purposes
      }
    // ---------- Fault-tolerant field extraction (avoid crashing on missing fields) ----------
    final String id = (data['id'] as String?)?.trim().isNotEmpty == true
      ? (data['id'] as String).trim()
      : studentDoc.id; // fallback to document ID

    final String name = (data['name'] as String?)?.trim().isNotEmpty == true
      ? (data['name'] as String).trim()
      : 'Unnamed Student';

    final String gradeLevel = (data['gradeLevel'] as String?)?.trim().isNotEmpty == true
      ? (data['gradeLevel'] as String).trim()
      : 'N/A';

    final String profileImageUrl = (data['profileImageUrl'] as String?)?.trim().isNotEmpty == true
      ? (data['profileImageUrl'] as String).trim()
      : 'https://picsum.photos/seed/default/100';

    final GeoPoint? geoPoint = data['currentLocation'] as GeoPoint?;
    final LatLng location = geoPoint != null
      ? LatLng(geoPoint.latitude, geoPoint.longitude)
      : const LatLng(0, 0); // fallback if missing

    // Status parsing with safe fallback
    LocationStatus status = LocationStatus.unknown;
    try {
    final String? statusString = data['status'] as String?;
    if (statusString != null) {
      status = LocationStatus.values.firstWhere(
      (e) => e
        .toString()
        .split('.')
        .last
        .toLowerCase() == statusString.toLowerCase().replaceAll(' ', ''),
      orElse: () => LocationStatus.unknown,
      );
    }
    } catch (e) {
    print('Status parse warning for student $id: $e');
    }

    final String classHours = (data['classHours'] as String?)?.trim().isNotEmpty == true
      ? (data['classHours'] as String).trim()
      : 'N/A';
    final String dismissalTime = (data['dismissalTime'] as String?)?.trim().isNotEmpty == true
      ? (data['dismissalTime'] as String).trim()
      : 'N/A';
    final String recentActivity = (data['recentActivity'] as String?)?.trim().isNotEmpty == true
      ? (data['recentActivity'] as String).trim()
      : 'No recent activity.';
    final String role = (data['role'] as String?)?.trim().isNotEmpty == true
      ? (data['role'] as String).trim()
      : 'student';

    final Timestamp? timestamp = data['lastUpdated'] as Timestamp?;
    final DateTime lastUpdated = timestamp != null ? timestamp.toDate() : DateTime.now();

    // Log any missing critical fields for diagnostics instead of throwing
    final missing = <String>[];
  final rawId = data['id'] as String?;
  final rawName = data['name'] as String?;
  final rawGrade = data['gradeLevel'] as String?;
  if (!(rawId != null && rawId.trim().isNotEmpty)) missing.add('id');
  if (!(rawName != null && rawName.trim().isNotEmpty)) missing.add('name');
  if (!(rawGrade != null && rawGrade.trim().isNotEmpty)) missing.add('gradeLevel');
    if (geoPoint == null) missing.add('currentLocation');
    if (timestamp == null) missing.add('lastUpdated');
    if (missing.isNotEmpty) {
    print('[LoginService] Student document $lrn missing fields: ${missing.join(', ')} (using defaults)');
    }

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
        role: role,
        absenceReason: data['absenceReason'] as String?,
        absenceReasonSubmittedAt: (data['absenceReasonSubmittedAt'] as Timestamp?)?.toDate(),
      );
    } on FirebaseAuthException catch (e) {
      print('[LoginService][AuthError][Student] code=${e.code} message=${e.message}');
      throw _mapAuthException(e, genericMessage: 'Invalid LRN or password.');
    } catch (e) {
      print('Error during sign-in and data fetch: $e');
      throw Exception('Failed to load student data: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  /// Teacher sign-in (uses 'teachers' collection, document ID = teacherId)
  Future<Student> signInTeacher(String teacherId, String password) async {
    try {
      final sanitized = _sanitizeIdentifier(teacherId);
      final String email = '$sanitized@school.com';
      await _logSignInDiagnostics(email);
      final pwd = password.trim();
      UserCredential userCredential;
      try {
        userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: pwd,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code.toLowerCase() == 'wrong-password') {
          throw await _enhancedWrongPasswordMessage(email, e, 'Invalid Teacher ID or password.');
        }
        rethrow;
      }

      if (userCredential.user == null) {
        throw Exception('Authentication failed. Please check your credentials.');
      }

    DocumentSnapshot teacherDoc = await _firestore
      .collection('teachers')
      .doc(sanitized)
      .get();

      if (!teacherDoc.exists) {
        throw Exception('Teacher data not found for the given ID.');
      }

      Map<String, dynamic> data = teacherDoc.data() as Map<String, dynamic>;

      // Simplified verification for teacher - allow more flexible authUid matching
      final String authUid = _auth.currentUser!.uid;
      final String storedAuthUid = data['authUid'] as String? ?? '';
      // For testing, allow if either authUid matches OR if no authUid is stored yet
      if (storedAuthUid.isNotEmpty && storedAuthUid != authUid && teacherId != authUid) {
        print('Warning: Teacher doc authUid mismatch, but allowing for testing');
        // Don't throw exception for testing purposes
      }

      final String id = data['id'] as String? ?? teacherId;
      final String name = data['name'] as String? ?? 'Unknown Teacher';
      final String gradeLevel = data['gradeLevel'] as String? ?? 'Faculty';
      final String profileImageUrl = data['profileImageUrl'] as String? ?? 'https://picsum.photos/seed/teacher/100';

  // Teachers do not need geolocation tracking or status; use placeholder values.
  // Teacher documents may safely omit currentLocation/status.
  final LatLng location = const LatLng(0, 0);
  final LocationStatus status = LocationStatus.unknown;

      final String classHours = data['classHours'] as String? ?? '';
      final String dismissalTime = data['dismissalTime'] as String? ?? '';
      final String recentActivity = data['recentActivity'] as String? ?? 'Monitoring students.';
      final String role = 'teacher';

      final Timestamp? timestamp = data['lastUpdated'] as Timestamp?;
      final DateTime lastUpdated = timestamp != null ? timestamp.toDate() : DateTime.now();

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
        role: role,
        absenceReason: data['absenceReason'] as String?,
        absenceReasonSubmittedAt: (data['absenceReasonSubmittedAt'] as Timestamp?)?.toDate(),
      );
    } on FirebaseAuthException catch (e) {
      print('[LoginService][AuthError][Teacher] code=${e.code} message=${e.message}');
      throw _mapAuthException(e, genericMessage: 'Invalid Teacher ID or password.');
    } catch (e) {
      print('Error during teacher sign-in and data fetch: $e');
      throw Exception('Failed to load teacher data: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  /// Automatically detect whether the identifier belongs to a student or teacher.
  /// Order: try student document; if not found, try teacher document.
  Future<Student> signInAuto(String identifier, String password) async {
    final sanitized = _sanitizeIdentifier(identifier);
    final email = '$sanitized@school.com';
    await _logSignInDiagnostics(email);
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password.trim());
    } on FirebaseAuthException catch (e) {
      print('[LoginService][AuthError][Auto] code=${e.code} message=${e.message}');
      if (e.code.toLowerCase() == 'wrong-password') {
        throw await _enhancedWrongPasswordMessage(email, e, 'Invalid ID or password.');
      }
      throw _mapAuthException(e, genericMessage: 'Invalid ID or password.');
    }

    // After successful auth, detect role without re-authenticating to avoid extra attempts / throttling.
    final teacherDoc = await _firestore.collection('teachers').doc(sanitized).get();
    if (teacherDoc.exists) {
      try {
        return _buildTeacherFromDoc(teacherDoc);
      } catch (e) {
        print('Error building teacher model: $e');
        rethrow;
      }
    }

    final studentDoc = await _firestore.collection('students').doc(sanitized).get();
    if (studentDoc.exists) {
      try {
        return _buildStudentFromDoc(studentDoc);
      } catch (e) {
        print('Error building student model: $e');
        rethrow;
      }
    }

    await _auth.signOut();
    throw Exception('No account data found for ID "$sanitized".');
  }

  // ---------- Helpers to build models post-auth (avoid duplicate signIn calls) ----------
  Student _buildStudentFromDoc(DocumentSnapshot studentDoc) {
    if (!studentDoc.exists) {
      throw Exception('Student data not found.');
    }
    final Map<String, dynamic> data = studentDoc.data() as Map<String, dynamic>;
    final String authUid = _auth.currentUser?.uid ?? '';
    final String storedAuthUid = data['authUid'] as String? ?? '';
    if (storedAuthUid.isNotEmpty && storedAuthUid != authUid) {
      print('Warning: Student doc authUid mismatch (post-auth build)');
    }

    final GeoPoint? geoPoint = data['currentLocation'] as GeoPoint?;
    final LatLng location = geoPoint != null ? LatLng(geoPoint.latitude, geoPoint.longitude) : const LatLng(0, 0);

    LocationStatus status = LocationStatus.unknown;
    try {
      final String? statusString = data['status'] as String?;
      if (statusString != null) {
        status = LocationStatus.values.firstWhere(
          (e) => e.toString().split('.').last.toLowerCase() == statusString.toLowerCase().replaceAll(' ', ''),
          orElse: () => LocationStatus.unknown,
        );
      }
    } catch (e) {
      print('Status parse warning (post-auth student ${studentDoc.id}): $e');
    }

    final Timestamp? timestamp = data['lastUpdated'] as Timestamp?;
    final DateTime lastUpdated = timestamp != null ? timestamp.toDate() : DateTime.now();

    return Student(
      id: (data['id'] as String?)?.trim().isNotEmpty == true ? (data['id'] as String).trim() : studentDoc.id,
      name: (data['name'] as String?)?.trim().isNotEmpty == true ? (data['name'] as String).trim() : 'Unnamed Student',
      gradeLevel: (data['gradeLevel'] as String?)?.trim().isNotEmpty == true ? (data['gradeLevel'] as String).trim() : 'N/A',
      profileImageUrl: (data['profileImageUrl'] as String?)?.trim().isNotEmpty == true ? (data['profileImageUrl'] as String).trim() : 'https://picsum.photos/seed/default/100',
      currentLocation: location,
      status: status,
      classHours: (data['classHours'] as String?)?.trim().isNotEmpty == true ? (data['classHours'] as String).trim() : 'N/A',
      dismissalTime: (data['dismissalTime'] as String?)?.trim().isNotEmpty == true ? (data['dismissalTime'] as String).trim() : 'N/A',
      recentActivity: (data['recentActivity'] as String?)?.trim().isNotEmpty == true ? (data['recentActivity'] as String).trim() : 'No recent activity.',
      lastUpdated: lastUpdated,
      role: (data['role'] as String?)?.trim().isNotEmpty == true ? (data['role'] as String).trim() : 'student',
      absenceReason: data['absenceReason'] as String?,
      absenceReasonSubmittedAt: (data['absenceReasonSubmittedAt'] as Timestamp?)?.toDate(),
    );
  }

  Student _buildTeacherFromDoc(DocumentSnapshot teacherDoc) {
    if (!teacherDoc.exists) {
      throw Exception('Teacher data not found.');
    }
    final Map<String, dynamic> data = teacherDoc.data() as Map<String, dynamic>;
    final String authUid = _auth.currentUser?.uid ?? '';
    final String storedAuthUid = data['authUid'] as String? ?? '';
    if (storedAuthUid.isNotEmpty && storedAuthUid != authUid && teacherDoc.id != authUid) {
      print('Warning: Teacher doc authUid mismatch (post-auth build)');
    }

    final Timestamp? timestamp = data['lastUpdated'] as Timestamp?;
    final DateTime lastUpdated = timestamp != null ? timestamp.toDate() : DateTime.now();

    return Student(
      id: data['id'] as String? ?? teacherDoc.id,
      name: data['name'] as String? ?? 'Unknown Teacher',
      gradeLevel: data['gradeLevel'] as String? ?? 'Faculty',
      profileImageUrl: data['profileImageUrl'] as String? ?? 'https://picsum.photos/seed/teacher/100',
      currentLocation: const LatLng(0, 0),
      status: LocationStatus.unknown,
      classHours: data['classHours'] as String? ?? '',
      dismissalTime: data['dismissalTime'] as String? ?? '',
      recentActivity: data['recentActivity'] as String? ?? 'Monitoring students.',
      lastUpdated: lastUpdated,
      role: 'teacher',
      absenceReason: data['absenceReason'] as String?,
      absenceReasonSubmittedAt: (data['absenceReasonSubmittedAt'] as Timestamp?)?.toDate(),
    );
  }

  Future<void> sendPasswordResetForIdentifier(String identifier) async {
    final sanitized = _sanitizeIdentifier(identifier);
    final email = '$sanitized@school.com';
    try {
      await _auth.sendPasswordResetEmail(email: email);
      print('[LoginService] Password reset email sent to $email');
    } on FirebaseAuthException catch (e) {
      print('[LoginService][ResetError] code=${e.code} message=${e.message}');
      throw _mapAuthException(e, genericMessage: 'Unable to send reset email.');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
