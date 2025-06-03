import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:permission_handler/permission_handler.dart';
import 'pages/attendance_page.dart';
import 'pages/auth_gate.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'background_task.dart';
import 'dart:io'; // For platform check
import 'package:geolocator/geolocator.dart'; // For permissions
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart'; // 👈 Add this for kIsWeb
import 'dart:io' show Platform;
// ✅ Keep this safely guarded for mobile only
Future<void> requestNotificationPermission() async {
  if (Platform.isAndroid) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt >= 33) {
      var status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    }
  }
}
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Firebase initialized");
  } catch (e) {
    print("Firebase Init Error: $e");
  }
  await requestNotificationPermission();
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    bool permissionGranted = await _checkAndRequestLocationPermission();

    if (permissionGranted) {
      await initializeService();
    } else {
      print("Location permission not granted. Background service not started.");
    }
  } else {
    print("Background service not supported on this platform.");
  }

  runApp(MyApp());
}

/// Checks and requests location permissions before starting background service.
Future<bool> _checkAndRequestLocationPermission() async {
  LocationPermission permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      print('Location permission denied');
      return false;
    }
  }

  if (permission == LocationPermission.deniedForever) {
    print('Location permission denied forever');
    return false;
  }

  // On Android 10+, ensure background permission is granted
  if (permission == LocationPermission.whileInUse) {
    permission = await Geolocator.requestPermission();
    if (permission != LocationPermission.always) {
      print('Background location permission not granted');
      return false;
    }
  }

  return true;
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.indigo,
      ),
      home: AuthGate(),
    );
  }
}
