// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'dart:io';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:intl/date_symbol_data_local.dart';

// Make sure the path is correct based on your project structure
import 'notification_service.dart';
import 'login_screen.dart';
import 'background_location_service.dart';

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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          primary: const Color(0xFF6366F1),
          secondary: const Color(0xFF8B5CF6),
          surface: const Color(0xFFF8FAFC),
          error: const Color(0xFFEF4444),
        ),
        fontFamily: 'Inter',
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w800, letterSpacing: -1.5),
          displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w700, letterSpacing: -0.5),
          displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w600),
          headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
          headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
          headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
          titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
          bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
          bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          shadowColor: Colors.black.withOpacity(0.1),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
