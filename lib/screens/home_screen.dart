import 'package:flutter/material.dart';
import 'attendance_selection_screen.dart';
import 'employee_list_screen.dart';
import 'admin_login_screen.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('Employee Attendance System')),
      drawer: _buildDrawer(context),
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 24),
            Card(
              elevation: 0,
              color: Colors.white,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 28, horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Employee Attendance System',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Manage registrations, mark attendance, and review employees.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
            _buildMenuButton(
              context,
              'Mark Attendance',
              Icons.verified_user_rounded,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AttendanceSelectionScreen()),
              ),
            ),
            SizedBox(height: 12),
            _buildMenuButton(
              context,
              'View Employees',
              Icons.people_alt_rounded,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EmployeeListScreen()),
              ),
            ),
            Spacer(),
            Align(
              alignment: Alignment.center,
              child: Text(
                '© ${DateTime.now().year} ACME Corp',
                style: TextStyle(color: Colors.black38, fontSize: 12),
              ),
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Text(
          title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.business_center, color: Colors.white, size: 48),
                SizedBox(height: 12),
                Text(
                  'Office Attendance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Management System',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.home_rounded),
            title: Text('Home'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: Icon(Icons.verified_user_rounded),
            title: Text('Mark Attendance'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AttendanceSelectionScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.people_alt_rounded),
            title: Text('View Employees'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EmployeeListScreen()),
              );
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.admin_panel_settings, color: Colors.orange),
            title: Text(
              'Admin Panel',
              style: TextStyle(color: Colors.orange.shade700),
            ),
            subtitle: Text('Requires authentication'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AdminLoginScreen()),
              );
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('About'),
            onTap: () {
              Navigator.pop(context);
              _showAboutDialog(context);
            },
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Office Attendance',
      applicationVersion: '1.0.0',
      applicationIcon: Icon(Icons.business_center, size: 48),
      children: [
        Text(
          'Employee attendance management system with face recognition capabilities.',
        ),
      ],
    );
  }
}
