import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
 // for AppLifecycleState

import '../background_task.dart';

class OfficeBranch {
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final String name;

  OfficeBranch(this.latitude, this.longitude, this.radiusMeters, this.name);
}

class AttendancePage extends StatefulWidget {
  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  Timer? timer;
  String attendanceStatus = 'Not Marked';
  DateTime? arrivalTime;
  DateTime? departureTime;
  Duration totalDuration = Duration.zero;
  Timer? durationTimer;
  String? currentOfficeName;
  bool _isOutsideConfirmed = false;
  int _outsideConfirmationCount = 0;

  final List<OfficeBranch> officeBranches = [
    OfficeBranch(13.058971971380322, 80.2425363696716, 100, "Nungambakkam"),
    OfficeBranch(13.056712575729241, 80.25333280685233, 80, "Greames Road"),
  ];

  Future<bool> isRegisteredUser(String email) async {
    final userQuery = await FirebaseFirestore.instance
        .collection('registered_users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    return userQuery.docs.isNotEmpty;
  }

  List<Map<String, String>> lastFiveRecords = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _startPeriodicLocationCheck();
    _loadLastFiveRecords();
    _checkAndPromptForName();
  }

  @override
  void dispose() {
    timer?.cancel();
    durationTimer?.cancel();
    super.dispose();
  }

  void _checkAndPromptForName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
    final snapshot = await userDoc.get();

    if (!snapshot.exists ||
        (snapshot.data()?['name'] ?? '').toString().isEmpty) {
      await Future.delayed(Duration.zero);
      String? name = await _showNameDialog();

      if (name != null && name.isNotEmpty) {
        await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
        await userDoc.set({'name': name}, SetOptions(merge: true));
      }
    }
  }

  Future<String?> _showNameDialog() async {
    String enteredName = '';

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enter your name'),
          content: TextField(
            autofocus: true,
            decoration: InputDecoration(hintText: 'Your full name'),
            onChanged: (value) {
              enteredName = value.trim();
            },
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Submit'),
              onPressed: () {
                Navigator.of(context).pop(enteredName);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      attendanceStatus = prefs.getString('attendanceStatus') ?? 'Not Marked';
      arrivalTime = prefs.containsKey('arrivalTime')
          ? DateTime.parse(prefs.getString('arrivalTime')!)
          : null;
      departureTime = prefs.containsKey('departureTime')
          ? DateTime.parse(prefs.getString('departureTime')!)
          : null;
      totalDuration = Duration(seconds: prefs.getInt('totalDuration') ?? 0);
    });
  }

  Future<void> _loadLastFiveRecords() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String uid = user.uid;
      DocumentSnapshot docSnapshot =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      Map<String, dynamic> data =
          docSnapshot.data() as Map<String, dynamic>? ?? {};
      Map<String, dynamic> attendance =
          Map<String, dynamic>.from(data['attendance'] ?? {});

      List<Map<String, String>> records = [];

      List<String> sortedDates = attendance.keys.toList()
        ..sort((a, b) => b.compareTo(a));

      for (String date in sortedDates) {
        List<dynamic> entries = List<dynamic>.from(attendance[date]);
        for (var entry in entries.reversed) {
          if (entry is Map) {
            records.add({
              'in': entry['in'] ?? '-',
              'out': entry['out'] ?? '-',
              'date': date,
            });
            if (records.length >= 5) break;
          }
        }
        if (records.length >= 5) break;
      }

      setState(() {
        lastFiveRecords = records;
      });
    } catch (e) {

    }
  }

  Future<void> _simulateCheckout() async {
    await testCheckout();
  }

  Future<void> _updateFirestoreAttendance(
      DateTime inTime, DateTime? outTime, String officeName) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String uid = user.uid;
      String dateKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
      String inFormatted = DateFormat('HH:mm').format(inTime);
      String? outFormatted =
          outTime != null ? DateFormat('HH:mm').format(outTime) : null;

      DocumentReference userDoc =
          FirebaseFirestore.instance.collection('users').doc(uid);

      DocumentSnapshot docSnapshot = await userDoc.get();
      Map<String, dynamic> data =
          docSnapshot.data() as Map<String, dynamic>? ?? {};
      Map<String, dynamic> attendance =
          Map<String, dynamic>.from(data['attendance'] ?? {});
      List<dynamic> dayAttendance =
          List<dynamic>.from(attendance[dateKey] ?? []);

      if (outFormatted == null) {
        dayAttendance.add({
          'in': inFormatted,
          'out': null,
          'at': officeName,
          'duration': '00:00',
        });
      } else {
        for (var record in dayAttendance.reversed) {
          if (record is Map && record['out'] == null) {
            record['out'] = outFormatted;
            record['at'] = officeName;

            DateTime inParsed = DateFormat('HH:mm').parse(record['in']);
            Duration duration =
                DateFormat('HH:mm').parse(outFormatted).difference(inParsed);
            record['duration'] = duration.toString().substring(0, 5);
            break;
          }
        }
      }

      attendance[dateKey] = dayAttendance;

      await userDoc.set({
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'attendance': attendance,
      }, SetOptions(merge: true));

      print('Firestore attendance updated for $dateKey: $dayAttendance');
    } catch (e) {
      print('Error updating Firestore: $e');
    }
  }

  void _startPeriodicLocationCheck() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationDialog();
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showLocationDialog();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) return;

    timer = Timer.periodic(Duration(seconds: 10), (_) async {
      try {
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best);

        OfficeBranch? nearbyOffice;
        bool isInsideAnyOffice = officeBranches.any((branch) {
          double distance = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            branch.latitude,
            branch.longitude,
          );
          if (distance <= branch.radiusMeters) {
            nearbyOffice = branch;
            return true;
          }
          return false;
        });

        final now = DateTime.now();
        SharedPreferences prefs = await SharedPreferences.getInstance();

        if (isInsideAnyOffice && nearbyOffice != null) {
          _outsideConfirmationCount = 0;
          _isOutsideConfirmed = false;

          if (attendanceStatus != 'Present') {
            await prefs.setString('attendanceStatus', 'Present');
            await prefs.setString('arrivalTime', now.toIso8601String());
            await prefs.remove('departureTime');

            setState(() {
              attendanceStatus = 'Present';
              arrivalTime = now;
              departureTime = null;
              currentOfficeName = nearbyOffice!.name;
            });

            await _updateFirestoreAttendance(now, null, nearbyOffice!.name);

            // Cancel any existing duration timer


            // Start new duration timer that updates both local state and Firestore
            if (durationTimer == null || !durationTimer!.isActive) {
              durationTimer =
                  Timer.periodic(Duration(minutes: 1), (timer) async {
                    if (arrivalTime == null) {
                      timer.cancel();
                      return;
                    }

                    Duration currentDuration =
                    DateTime.now().difference(arrivalTime!);
                    setState(() {
                      totalDuration = currentDuration;
                    });

                    // Update duration in SharedPreferences
                    await prefs.setInt(
                        'totalDuration', currentDuration.inSeconds);

                    // Update duration in Firestore
                    await _updateDurationOnly(currentDuration.inMinutes);
                  });
            }

            if (AppLifecycleState.resumed ==
                WidgetsBinding.instance.lifecycleState) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text("Check-In Successful"),
                  content: Text("Check in at: ${nearbyOffice!.name}"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("OK"),
                    ),
                  ],
                ),
              );
            } else {
              flutterLocalNotificationsPlugin.show(
                0,
                'Checked In',
                'Check in at: ${nearbyOffice!.name}',
                NotificationDetails(
                  android: AndroidNotificationDetails(
                    'channel_id',
                    'Check-In Notifications',
                    importance: Importance.max,
                    priority: Priority.high,
                  ),
                ),
              );
            }
          }
        } else {
          _outsideConfirmationCount++;
          if (_outsideConfirmationCount >= 2 && attendanceStatus == 'Present') {
            String officeName = currentOfficeName ?? 'Unknown';
            await _checkoutLogic(officeName);
            _isOutsideConfirmed = true;
          }
        }
      } catch (e) {
        print('Error in periodic location check: $e');
      }
    });
  }

  Future<void> _updateDurationOnly(int minutes) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String uid = user.uid;
      String dateKey = DateFormat('yyyy-MM-dd').format(DateTime.now());

      DocumentReference userDoc =
          FirebaseFirestore.instance.collection('users').doc(uid);
      DocumentSnapshot docSnapshot = await userDoc.get();
      Map<String, dynamic> data =
          docSnapshot.data() as Map<String, dynamic>? ?? {};
      Map<String, dynamic> attendance =
          Map<String, dynamic>.from(data['attendance'] ?? {});
      List<dynamic> dayAttendance =
          List<dynamic>.from(attendance[dateKey] ?? []);

      for (var record in dayAttendance.reversed) {
        if (record is Map && record['out'] == null) {
          record['duration'] =
              '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
          break;
        }
      }

      attendance[dateKey] = dayAttendance;

      await userDoc.set({
        'attendance': attendance,
      }, SetOptions(merge: true));

      print('Duration updated to $minutes min');
    } catch (e) {
      print('Error updating duration: $e');
    }
  }

  void _showLocationDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Enable Location'),
        content: Text('Location services are required to track attendance.'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openLocationSettings();
            },
            child: Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<Duration> getDailyDuration(String date) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return Duration.zero;

    final docRef = FirebaseFirestore.instance.collection('users').doc(userId);
    final docSnapshot = await docRef.get();

    if (!docSnapshot.exists) return Duration.zero;

    final data = docSnapshot.data();
    final attendanceMap = data?['attendance'] ?? {};

    final dayEntries = attendanceMap[date];
    if (dayEntries == null || dayEntries.isEmpty) return Duration.zero;

    Duration total = Duration.zero;
    bool hasActiveSession = false;
    Duration activeSessionDuration = Duration.zero;

    for (var record in List.from(dayEntries)) {
      String? inTime = record['in'];
      String? outTime = record['out'];

      if (inTime != null) {
        try {
          final inParts = inTime.split(':').map(int.parse).toList();
          final inDateTime = DateTime(0, 1, 1, inParts[0], inParts[1]);

          if (outTime != null) {
            // Completed session
            final outParts = outTime.split(':').map(int.parse).toList();
            final outDateTime = DateTime(0, 1, 1, outParts[0], outParts[1]);
            final diff = outDateTime.difference(inDateTime);
            if (diff.inMinutes > 0) {
              total += diff;
            }
          } else {
            // Active session (no out time)
            final now = DateTime.now();
            final currentTime = DateTime(0, 1, 1, now.hour, now.minute);
            activeSessionDuration = currentTime.difference(inDateTime);
            hasActiveSession = true;
          }
        } catch (e) {
          print("Error parsing times: $e");
        }
      }
    }

    return hasActiveSession ? total + activeSessionDuration : total;
  }

  Future<void> _checkoutLogic(String officeName) async {
    final now = DateTime.now();
    SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setString('attendanceStatus', 'Away');
    await prefs.setString('departureTime', now.toIso8601String());

    if (prefs.containsKey('arrivalTime')) {
      DateTime arrival = DateTime.parse(prefs.getString('arrivalTime')!);
      Duration previousDuration =
          Duration(seconds: prefs.getInt('totalDuration') ?? 0);
      Duration newDuration = now.difference(arrival);
      int totalSeconds = previousDuration.inSeconds + newDuration.inSeconds;
      await prefs.setInt('totalDuration', totalSeconds);

      await _updateFirestoreAttendance(arrival, now, officeName);
      durationTimer?.cancel();
      await prefs.remove('arrivalTime');
    }

    setState(() {
      attendanceStatus = 'Away';
      departureTime = now;
      arrivalTime = null;
      totalDuration = Duration(seconds: prefs.getInt('totalDuration') ?? 0);
      currentOfficeName = null;
    });

    await _loadLastFiveRecords();
  }

  Future<void> testCheckout() async {
    final now = DateTime.now();
    SharedPreferences prefs = await SharedPreferences.getInstance();

    if (attendanceStatus != 'Present') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You are not currently marked as Present.')),
      );
      return;
    }

    await prefs.setString('attendanceStatus', 'Test Checked Out');
    await prefs.setString('departureTime', now.toIso8601String());

    if (prefs.containsKey('arrivalTime')) {
      DateTime arrival = DateTime.parse(prefs.getString('arrivalTime')!);
      Duration previousDuration =
          Duration(seconds: prefs.getInt('totalDuration') ?? 0);
      Duration newDuration = now.difference(arrival);
      int totalSeconds = previousDuration.inSeconds + newDuration.inSeconds;
      await prefs.setInt('totalDuration', totalSeconds);
      await prefs.remove('arrivalTime');

      try {
        User? user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        String uid = user.uid;
        String dateKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
        String inFormatted = DateFormat('HH:mm').format(arrival);
        String outFormatted = DateFormat('HH:mm').format(now);

        DocumentReference userDoc =
            FirebaseFirestore.instance.collection('users').doc(uid);

        DocumentSnapshot docSnapshot = await userDoc.get();
        Map<String, dynamic> data =
            docSnapshot.data() as Map<String, dynamic>? ?? {};

        Map<String, dynamic> attendance =
            Map<String, dynamic>.from(data['attendance'] ?? {});
        List<dynamic> dayAttendance =
            List<dynamic>.from(attendance[dateKey] ?? []);

        dayAttendance.add(
            {'in': inFormatted, 'out': outFormatted, 'note': 'Test Checkout'});
        attendance[dateKey] = dayAttendance;

        await userDoc.set({
          'name': user.displayName ?? '',
          'email': user.email ?? '',
          'attendance': attendance,
        }, SetOptions(merge: true));
      } catch (e) {
        print('Error in test checkout Firestore update: $e');
      }
    }

    setState(() {
      attendanceStatus = prefs.getString('attendanceStatus') ?? 'Not Marked';
      arrivalTime = prefs.getString('arrivalTime') != null
          ? DateTime.parse(prefs.getString('arrivalTime')!)
          : null;
      departureTime = prefs.getString('departureTime') != null
          ? DateTime.parse(prefs.getString('departureTime')!)
          : null;
      totalDuration = Duration(seconds: prefs.getInt('totalDuration') ?? 0);
    });

    await _loadLastFiveRecords();
  }

  String formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    return '${twoDigits(d.inHours)}hr ${twoDigitMinutes}min';
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final String? userEmail = user?.email;

    return Scaffold(
        appBar: AppBar(
          title: Center(
              child: const Text('Attendance Tracker',
                  style: TextStyle(color: Colors.white))),
          backgroundColor: Colors.deepPurpleAccent,
        ),
        body: FutureBuilder<bool>(
            future: isRegisteredUser(userEmail ?? ''),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.data!) {
                return const Center(
                  child: Text("Access denied. You are not a registered user."),
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(25),
                        child: Column(
                          children: [
                            Icon(Icons.access_time_filled_rounded,
                                size: 60, color: Colors.deepPurple),
                            const SizedBox(height: 10),
                            Text('Status: $attendanceStatus',
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 10),
                            Text(
                                'Arrival: ${arrivalTime != null ? DateFormat.Hm().format(arrivalTime!) : "Not Arrived"}'),
                            Text(
                                'Departure: ${departureTime != null ? DateFormat.Hm().format(departureTime!) : "Not Left"}'),
                            const SizedBox(height: 10),
                            StreamBuilder<Duration>(
                              stream: Stream.periodic(
                                      Duration(minutes: 1),
                                      (_) => getDailyDuration(
                                          DateFormat('yyyy-MM-dd')
                                              .format(DateTime.now())))
                                  .asyncMap((future) => future),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                        ConnectionState.waiting &&
                                    !snapshot.hasData) {
                                  return CircularProgressIndicator();
                                } else if (snapshot.hasError) {
                                  return Text("Error: ${snapshot.error}");
                                } else {
                                  final duration =
                                      snapshot.data ?? Duration.zero;
                                  return Text(
                                      "Total Duration: ${formatDuration(duration)}",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold));
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Last 5 Records:',
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                    const SizedBox(height: 10),
                    ...lastFiveRecords.map((record) {
                      return Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 3,
                        child: ListTile(
                          leading: Icon(Icons.calendar_today,
                              color: Colors.deepPurpleAccent),
                          title: Text('${record['date']}'),
                          subtitle: Text(
                              'In: ${record['in']} | Out: ${record['out']}'),
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await _checkoutLogic(currentOfficeName ?? 'Manual Checkout');
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error during checkout: $e')),
                          );
                        }
                      },
                      icon: Icon(Icons.logout),
                      label: Text("Test Checkout"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              );
            }));
  }
}
