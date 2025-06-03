import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewAttendancePage extends StatefulWidget {
  const ViewAttendancePage({super.key});

  @override
  State<ViewAttendancePage> createState() => _ViewAttendancePageState();
}

class _ViewAttendancePageState extends State<ViewAttendancePage> {
  String? selectedUserId;
  String? selectedDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Text(
            "Admin Attendance Viewer",
            style: TextStyle(color: Colors.white),
          ),
        ),
        backgroundColor: Colors.deepPurple,
      ),
      body: Row(
        children: [
          // Users list pane
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.grey.shade400, width: 1),
                ),
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Employees',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(child: _buildUserList()),
                ],
              ),
            ),
          ),

          // Dates list pane
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.grey.shade400, width: 1),
                ),
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Dates',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  selectedUserId == null
                      ? const Center(
                    child: Text("Select an employee to view dates"),
                  )
                      : Expanded(child: _buildDateList()),
                ],
              ),
            ),
          ),

          // Attendance records pane
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Attendance Records',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  (selectedUserId == null || selectedDate == null)
                      ? const Expanded(
                    child: Center(
                      child: Text("Select an employee and date to view records"),
                    ),
                  )
                      : Expanded(child: _buildAttendanceDetails()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var users = snapshot.data!.docs;
        return ListView.separated(
          itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            var userDoc = users[index];
            String name = userDoc['name'] ?? 'Unnamed';
            bool isSelected = selectedUserId == userDoc.id;
            return ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected ? Colors.deepPurple : null,
                foregroundColor: isSelected ? Colors.white : null,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                setState(() {
                  selectedUserId = userDoc.id;
                  selectedDate = null;
                });
              },
              child: Text(name),
            );
          },
        );
      },
    );
  }

  Widget _buildDateList() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(selectedUserId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        Map<String, dynamic>? data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null || !data.containsKey('attendance')) {
          return const Center(child: Text("No attendance data"));
        }

        Map<String, dynamic> attendance = data['attendance'];
        List<String> dates = attendance.keys.toList();
        dates.sort((a, b) => b.compareTo(a)); // latest date first

        return ListView.separated(
          itemCount: dates.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            String date = dates[index];
            bool isSelected = selectedDate == date;
            return ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected ? Colors.deepPurple : null,
                foregroundColor: isSelected ? Colors.white : null,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                setState(() {
                  selectedDate = date;
                });
              },
              child: Text(date),
            );
          },
        );
      },
    );
  }

  Widget _buildAttendanceDetails() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(selectedUserId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        Map<String, dynamic>? data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null || !data.containsKey('attendance')) {
          return const Center(child: Text("No data"));
        }

        List records = data['attendance'][selectedDate] ?? [];
        if (records.isEmpty) {
          return const Center(child: Text("No records for this date"));
        }

        // Compute total duration from HH:mm strings
        Duration totalDuration = Duration();
        for (var record in records) {
          try {
            String inTimeStr = record['in'];
            String outTimeStr = record['out'];
            if (inTimeStr != null && outTimeStr != null) {
              final inParts = inTimeStr.split(':').map(int.parse).toList();
              final outParts = outTimeStr.split(':').map(int.parse).toList();

              final inTime = DateTime(0, 1, 1, inParts[0], inParts[1]);
              final outTime = DateTime(0, 1, 1, outParts[0], outParts[1]);

              totalDuration += outTime.difference(inTime);
            }
          } catch (_) {
            // Ignore invalid formats
          }
        }

        String durationText = "${totalDuration.inHours}h ${totalDuration.inMinutes.remainder(60)}m";

        return Column(
          children: [
            Expanded(
              child: ListView.separated(
                itemCount: records.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  var entry = records[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: ListTile(
                      title: Text("In: ${entry['in']} - Out: ${entry['out']}"),
                      subtitle: Text("Note: ${entry['note']}"),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Total Duration: $durationText",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
