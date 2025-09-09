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
      home: const LoginScreen(),
    );
  }
}
