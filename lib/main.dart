// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:intl/date_symbol_data_local.dart';

// Make sure the path is correct based on your project structure
import 'notification_service.dart';
import 'login_screen.dart';
import 'background_location_service.dart';
import 'map_screen.dart';
import 'ui_theme.dart';
import 'map_handlers/student_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // Initialize date formatting symbols (e.g., for en_US) to avoid Intl exceptions
  try {
    await initializeDateFormatting('en_US', null);
  } catch (_) {
    // Safe to ignore; fallback formats still work for numeric patterns
  }
  // Configure global HTTP client for timeouts & fewer simultaneous connections
  HttpClient client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 6);
  client.idleTimeout = const Duration(seconds: 10);
  client.maxConnectionsPerHost = 4;
  HttpOverrides.global = _HttpOverridesWithClient(client);

  // Initialize tile caching
  await FMTCObjectBoxBackend().initialise();
  await FMTCStore('defaultStore').manage.create();
  bool kAppCheckDebugMode = true; 
  if (kAppCheckDebugMode) {
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.debug,
      );
      debugPrint('App Check running in DEBUG mode (development only).');
    } catch (e) {
      debugPrint('Failed to activate App Check debug providers: $e');
    }
  // ignore: dead_code
  } else {
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.deviceCheck,
      );
      debugPrint('App Check production providers active.');
    } catch (e) {
      debugPrint('App Check production activation failed: $e');
    }
  }
  // Initialize local notifications for geofence alerts
  await NotificationService().init();
  // Initialize background service (does not start yet)
  await initBackgroundService();
  runApp(const MyApp());
}

class _HttpOverridesWithClient extends HttpOverrides {
  final HttpClient _client;
  _HttpOverridesWithClient(this._client);
  @override
  HttpClient createHttpClient(SecurityContext? context) => _client;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ALLY Tracking',
      theme: AllyTheme.getTheme(),
      home: const AppRouter(),
    );
  }
}

/// Router widget that determines whether to show login screen or map screen
class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Wait a moment to ensure NotificationService has restored login state
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        // Check if user is logged in
        final isLoggedIn = NotificationService().isLoggedIn;
        final currentUser = FirebaseAuth.instance.currentUser;

        // If user is logged in and Firebase auth persists, navigate to map
        if (isLoggedIn && currentUser != null) {
          return FutureBuilder<Student?>(
            future: _getStudentData(currentUser.uid),
            builder: (context, studentSnapshot) {
              if (studentSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (studentSnapshot.hasData && studentSnapshot.data != null) {
                return FixedMapScreen(student: studentSnapshot.data!);
              }

              // If we can't get student data, go to login
              return const LoginScreen();
            },
          );
        }

        // Otherwise show login screen
        return const LoginScreen();
      },
    );
  }

  /// Retrieve student data from Firestore based on Firebase user ID
  Future<Student?> _getStudentData(String uid) async {
    try {
      final student = await FirebaseFirestore.instance
          .collection('students')
          .doc(uid)
          .get()
          .then((doc) {
        if (doc.exists) {
          return Student.fromFirestore(doc);
        }
        return null;
      });
      return student;
    } catch (e) {
      debugPrint('Failed to get student data: $e');
      return null;
    }
  }
}
