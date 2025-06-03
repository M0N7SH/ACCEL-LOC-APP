// lib/background_task.dart
import 'dart:async';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'firebase_options.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

Timer? timer;

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,
      autoStartOnBoot: true,
      initialNotificationTitle: 'My Background Service',
      initialNotificationContent: 'Running in the background',
    ),
    iosConfiguration: IosConfiguration(
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  await service.startService();
}

Future<void> _showNotification(String title, String body) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'location_channel',
    'Location Updates',
    channelDescription: 'Background location update notifications',
    importance: Importance.high,
    priority: Priority.high,
  );

  const NotificationDetails platformDetails = NotificationDetails(
    android: androidDetails,
  );

  await flutterLocalNotificationsPlugin.show(
    0,
    title,
    body,
    platformDetails,
  );
}

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Set foreground notification info to keep service alive on Android

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize flutter local notifications plugin
  const AndroidInitializationSettings androidSettings =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initSettings =
  InitializationSettings(android: androidSettings);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  // Listen for stop event to cancel timer and stop service
  service.on('stopService').listen((event) {
    timer?.cancel();
    service.stopSelf();
  });

  // Request location permissions before starting periodic task
  final permissionGranted = await _checkAndRequestLocationPermission();
  if (!permissionGranted) {
    // If permission not granted, stop the service
    service.stopSelf();
    return;
  }

  // Start periodic task every 15 minutes
  timer = Timer.periodic(const Duration(minutes: 15), (timer) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        await FirebaseFirestore.instance
            .collection('attendance')
            .doc(user.uid)
            .set({
          'lastLocation': {
            'latitude': position.latitude,
            'longitude': position.longitude,
          },
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'location_channel',
          'Location Updates',
          channelDescription: 'Background location update notifications',
          importance: Importance.high,
          priority: Priority.high,
        );

        const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

        await flutterLocalNotificationsPlugin.show(
          0,
          'Location Updated',
          'Your background location has been updated.',
          platformDetails,
        );
      } catch (e) {
        // Handle any errors, e.g., location service disabled, Firebase errors
        print('Background location update error: $e');
      }
    }
  });
}

/// Checks and requests location permissions if necessary.
/// Returns true if permission granted, false otherwise.
Future<bool> _checkAndRequestLocationPermission() async {
  LocationPermission permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      // Permissions are denied, next time you could try again.
      print('Location permission denied');
      await _showNotification(
        'Permission Denied',
        'Location permission was denied. Please enable it in settings.',
      );
      return false;
    }
  }

  if (permission == LocationPermission.deniedForever) {
    // Permissions are denied forever, handle appropriately.
    print('Location permission denied forever');
    await _showNotification(
      'Permission Denied Forever',
      'Location permission is permanently denied. Please enable it from app settings.',
    );
    return false;
  }

  // Check if background permission is granted (Android 10+)
  if (permission == LocationPermission.whileInUse) {
    // Request background permission
    permission = await Geolocator.requestPermission();
    if (permission != LocationPermission.always) {
      print('Background location permission not granted');
      await _showNotification(
        'Background Location Required',
        'Please grant background location access for full functionality.',
      );
      return false;
    }
  }

  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    print('Location services disabled');
    await _showNotification(
      'Location Services Disabled',
      'Please enable location services.',
    );
    return false;
  }

  return true;
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  // iOS background handler can perform limited tasks here
  return true;
}
