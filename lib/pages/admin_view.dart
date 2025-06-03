import 'package:flutter/material.dart';
import 'package:sample/pages/add_user.dart';
import 'package:sample/pages/view_employee_attendance.dart';
import 'package:sample/pages/remove_user.dart'; // <-- Make sure this file exists

class AdminView extends StatelessWidget {
  const AdminView({super.key});

  void _onAddUser(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddUserPage()),
    );
  }

  void _onViewAttendance(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ViewAttendancePage()),
    );
  }

  void _onRemoveUser(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RemoveUser()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text(
              'Welcome, Admin!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Row(
              children: [
                // Add User button
                Expanded(
                  child: SizedBox(
                    height: 120,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.person_add, size: 40, color: Colors.white),
                      label: const Text('Add User', style: TextStyle(fontSize: 22, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _onAddUser(context),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // View Attendance button
                Expanded(
                  child: SizedBox(
                    height: 120,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.visibility, size: 40, color: Colors.white),
                      label: const Text('View Attendance', style: TextStyle(fontSize: 22, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _onViewAttendance(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Remove User button
            SizedBox(
              width: double.infinity,
              height: 120,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.person_remove, size: 40, color: Colors.white),
                label: const Text('Remove User', style: TextStyle(fontSize: 22, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _onRemoveUser(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
