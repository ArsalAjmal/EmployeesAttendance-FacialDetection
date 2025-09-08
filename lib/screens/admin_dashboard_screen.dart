import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import 'registration_screen.dart';
import 'admin_employee_list_screen.dart';
import 'location_management_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Removed unused authService variable

    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Panel'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 0,
              color: Colors.white,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 28, horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.admin_panel_settings,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Administrator',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Office Attendance Admin Panel',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Manage employees and control system settings.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
            _buildAdminButton(
              context,
              'Register New Employee',
              Icons.person_add_rounded,
              'Add new employees to the system',
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RegistrationScreen()),
              ),
            ),
            SizedBox(height: 12),
            _buildAdminButton(
              context,
              'Manage Employees',
              Icons.people_alt_rounded,
              'View and manage employee records',
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AdminEmployeeListScreen()),
              ),
            ),
            SizedBox(height: 12),
            _buildAdminButton(
              context,
              'Close Today',
              Icons.lock_clock_rounded,
              'Mark absent employees for today',
              () => _closeDayToday(context),
            ),
            SizedBox(height: 12),
            _buildAdminButton(
              context,
              'Undo Close Today',
              Icons.undo_rounded,
              'Revert today\'s absents back to pending',
              () => _undoCloseDayToday(context),
            ),
            SizedBox(height: 12),
            _buildAdminButton(
              context,
              'Office Locations',
              Icons.location_on_rounded,
              'Manage office locations and geofencing',
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => LocationManagementScreen()),
              ),
            ),
            SizedBox(height: 12),
            _buildAdminButton(
              context,
              'System Settings',
              Icons.settings_rounded,
              'Configure system preferences',
              () => _showComingSoon(context),
            ),
            SizedBox(height: 24),

            SizedBox(height: 40),
            Align(
              alignment: Alignment.center,
              child: Text(
                'Logged in as Administrator',
                style: TextStyle(color: Colors.black38, fontSize: 12),
              ),
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminButton(
    BuildContext context,
    String title,
    IconData icon,
    String subtitle,
    VoidCallback onPressed,
  ) {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.black26, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _logout(BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.signOut();
    Navigator.of(context).pop(); // Return to home screen
  }

  Future<void> _closeDayToday(BuildContext context) async {
    final firebaseService = Provider.of<FirebaseService>(
      context,
      listen: false,
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Closing ${_formatDate(today)}...'),
                ],
              ),
            ),
      );

      final employees = await firebaseService.getAllEmployees();
      final count = await firebaseService
          .markAbsentForRemainingEmployeesForDate(employees, today);

      Navigator.of(context).pop(); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Closed ${_formatDate(today)}. Marked $count employees absent.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to close day: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _undoCloseDayToday(BuildContext context) async {
    final firebaseService = Provider.of<FirebaseService>(
      context,
      listen: false,
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Reverting ${_formatDate(today)}...'),
                ],
              ),
            ),
      );

      final count = await firebaseService.undoCloseDayForDate(today);

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reverted $count absent records for ${_formatDate(today)}.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to undo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Feature coming soon!'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}
