import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../models/employee.dart';
import '../models/attendance.dart';
import '../widgets/employee_card.dart';
import '../widgets/loading_widget.dart';

class AdminEmployeeListScreen extends StatefulWidget {
  @override
  _AdminEmployeeListScreenState createState() =>
      _AdminEmployeeListScreenState();
}

class _AdminEmployeeListScreenState extends State<AdminEmployeeListScreen> {
  bool _isLoading = true;
  List<Employee> _employees = [];
  List<Attendance> _selectedAttendance = [];
  DateTime _selectedDate = DateTime.now();
  late DateTime _recordsStartDate;

  bool _isFutureSelected = false;
  bool _isBeforeStartSelected = false;
  bool _autoAbsentRunForToday = false;

  late FirebaseService _firebaseService;

  @override
  void initState() {
    super.initState();
    _firebaseService = Provider.of<FirebaseService>(context, listen: false);
    // Records should be available starting from 8th September 2025
    _recordsStartDate = DateTime(2025, 9, 8);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final employees = await _firebaseService.getAllEmployees();
      List<Attendance> attendance;
      final today = DateTime.now();
      final normalizedToday = DateTime(today.year, today.month, today.day);
      _isFutureSelected = false;
      _isBeforeStartSelected = false;

      {
        final normalizedSelected = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
        );
        if (normalizedSelected.isAfter(normalizedToday)) {
          _isFutureSelected = true;
          attendance = [];
        } else if (normalizedSelected.isBefore(_recordsStartDate)) {
          _isBeforeStartSelected = true;
          attendance = [];
        } else {
          attendance = await _firebaseService.getAttendanceForDate(
            _selectedDate,
          );
        }
      }

      // If viewing today and time is at/after 5 PM, auto-mark pending as absent once
      final now = DateTime.now();
      final isToday = _isSameDate(_selectedDate, now);
      final officeEnd = DateTime(now.year, now.month, now.day, 17, 0, 0);
      if (isToday &&
          (now.isAfter(officeEnd) || now.isAtSameMomentAs(officeEnd)) &&
          !_autoAbsentRunForToday) {
        final pendingEmployeeIds =
            employees
                .where((e) => !_hasAttendanceForEmployee(attendance, e.id))
                .map((e) => e.id)
                .toSet();
        if (pendingEmployeeIds.isNotEmpty) {
          // Mark remaining as absent via service
          final markedCount = await _firebaseService
              .markAbsentForRemainingEmployees(employees);
          _autoAbsentRunForToday = true;
          // Reload attendance after marking
          attendance = await _firebaseService.getAttendanceForDate(
            _selectedDate,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Auto-marked $markedCount employees as absent.'),
              backgroundColor: Colors.blue,
            ),
          );
        } else {
          _autoAbsentRunForToday = true;
        }
      }

      setState(() {
        _employees = employees;
        _selectedAttendance = attendance;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Removed unused _getEmployeeAttendance

  Future<void> _deleteEmployee(Employee employee) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Delete Employee'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Are you sure you want to delete this employee?'),
                SizedBox(height: 8),
                Text(
                  'Employee: ${employee.name}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('ID: ${employee.id}'),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red.shade600, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This action cannot be undone. The employee will be removed from the system.',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Deleting employee...'),
                ],
              ),
            ),
      );

      await _firebaseService.deleteEmployee(employee.id);

      // Close loading dialog
      Navigator.of(context).pop();

      // Reload data
      await _loadData();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Employee "${employee.name}" deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Close loading dialog if it's still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete employee: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build per-employee attendance index for the selected date (active employees only)
    final Set<String> activeEmployeeIds = _employees.map((e) => e.id).toSet();
    final Map<String, Attendance> employeeIdToBestAttendance = {};
    for (final att in _selectedAttendance.where(
      (a) => activeEmployeeIds.contains(a.employeeId),
    )) {
      final current = employeeIdToBestAttendance[att.employeeId];
      final isPresentOrLate = att.status == 'present' || att.status == 'late';
      if (current == null) {
        employeeIdToBestAttendance[att.employeeId] = att;
      } else {
        final currentPresentOrLate =
            current.status == 'present' || current.status == 'late';
        if (isPresentOrLate && !currentPresentOrLate) {
          // Prefer present/late over absent/pending
          employeeIdToBestAttendance[att.employeeId] = att;
        } else if (isPresentOrLate && currentPresentOrLate) {
          // If both are present/late, keep the earliest check-in
          if (att.checkInTime.isBefore(current.checkInTime)) {
            employeeIdToBestAttendance[att.employeeId] = att;
          }
        } else if (!currentPresentOrLate) {
          // For absent vs absent, keep the first one
          // No action needed unless you want to replace
        }
      }
    }

    final Set<String> anyAttendanceIds =
        employeeIdToBestAttendance.keys.toSet();

    final int presentCount =
        employeeIdToBestAttendance.values
            .where((a) => a.status == 'present')
            .length;
    final int lateCount =
        employeeIdToBestAttendance.values
            .where((a) => a.status == 'late')
            .length;
    // Absent should only count explicit 'absent' attendance records
    final int absentCount =
        employeeIdToBestAttendance.values
            .where((a) => a.status == 'absent')
            .length;
    // Pending are employees with no attendance record for the date
    final int pendingCount = _employees.length - anyAttendanceIds.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Employees'),
        actions: [IconButton(icon: Icon(Icons.refresh), onPressed: _loadData)],
      ),
      body:
          _isLoading
              ? LoadingWidget(message: 'Loading employees...')
              : _employees.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 80, color: Colors.black26),
                    SizedBox(height: 20),
                    Text(
                      'No employees registered',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
              : Column(
                children: [
                  // Filters
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final now = DateTime.now();
                              final todayOnly = DateTime(
                                now.year,
                                now.month,
                                now.day,
                              );
                              final picked = await showDatePicker(
                                context: context,
                                initialDate:
                                    _selectedDate.isAfter(todayOnly)
                                        ? todayOnly
                                        : _selectedDate,
                                firstDate: DateTime(2020, 1, 1),
                                lastDate: DateTime(2100, 12, 31),
                              );
                              if (picked != null) {
                                setState(() {
                                  _selectedDate = picked;
                                });
                                await _loadData();
                              }
                            },
                            icon: Icon(Icons.calendar_today),
                            label: Text(
                              '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                      ],
                    ),
                  ),

                  if (_isBeforeStartSelected)
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Records start from ${_formatDate(_recordsStartDate)}. No data for selected date.',
                                style: TextStyle(color: Colors.blue.shade800),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (_isFutureSelected)
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.amber.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Selected date is in the future. Record not updated.',
                                style: TextStyle(color: Colors.orange.shade800),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Summary Card
                  Container(
                    margin: EdgeInsets.all(16),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildSummaryItem(
                            'Present',
                            presentCount,
                            Colors.green,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.grey.shade300,
                        ),
                        Expanded(
                          child: _buildSummaryItem(
                            'Late',
                            lateCount,
                            Colors.orange,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.grey.shade300,
                        ),
                        Expanded(
                          child: _buildSummaryItem(
                            'Absent',
                            absentCount < 0 ? 0 : absentCount,
                            Colors.red,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.grey.shade300,
                        ),
                        Expanded(
                          child: _buildSummaryItem(
                            'Pending',
                            pendingCount < 0 ? 0 : pendingCount,
                            Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Employee List
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _employees.length,
                        itemBuilder: (context, index) {
                          final employee = _employees[index];
                          final attendance =
                              employeeIdToBestAttendance[employee.id];
                          final attendanceStatus =
                              attendance?.status ?? 'pending';

                          return EmployeeCard(
                            employee: employee,
                            attendanceStatus: attendanceStatus,
                            checkInTime: attendance?.checkInTime,
                            checkOutTime: attendance?.checkOutTime,
                            showDeleteButton: true,
                            onDelete: () => _deleteEmployee(employee),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildSummaryItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _hasAttendanceForEmployee(List<Attendance> records, String employeeId) {
    for (final r in records) {
      if (r.employeeId == employeeId) return true;
    }
    return false;
  }
}
