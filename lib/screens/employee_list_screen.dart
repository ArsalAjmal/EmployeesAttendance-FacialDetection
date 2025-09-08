import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../models/employee.dart';
import '../models/attendance.dart';
import '../widgets/employee_card.dart';
import '../widgets/loading_widget.dart';

class EmployeeListScreen extends StatefulWidget {
  @override
  _EmployeeListScreenState createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  bool _isLoading = true;
  List<Employee> _employees = [];
  List<Attendance> _todayAttendance = [];
  
  late FirebaseService _firebaseService;

  @override
  void initState() {
    super.initState();
    _firebaseService = Provider.of<FirebaseService>(context, listen: false);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final employees = await _firebaseService.getAllEmployees();
      final attendance = await _firebaseService.getTodayAttendance();
      
      setState(() {
        _employees = employees;
        _todayAttendance = attendance;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load data: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getEmployeeAttendanceStatus(String employeeId) {
    final attendance = _getEmployeeAttendance(employeeId);
    return attendance?.status ?? 'pending';
  }

  Attendance? _getEmployeeAttendance(String employeeId) {
    try {
      return _todayAttendance.firstWhere(
        (att) => att.employeeId == employeeId,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Employees'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? LoadingWidget()
          : _employees.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 80, color: Colors.grey),
                      SizedBox(height: 20),
                      Text(
                        'No employees registered',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: EdgeInsets.all(10),
                    itemCount: _employees.length,
                    itemBuilder: (context, index) {
                      final employee = _employees[index];
                      final attendance = _getEmployeeAttendance(employee.id);
                      final attendanceStatus = attendance?.status ?? 'pending';
                      
                      return EmployeeCard(
                        employee: employee,
                        attendanceStatus: attendanceStatus,
                        checkInTime: attendance?.checkInTime,
                        checkOutTime: attendance?.checkOutTime,
                      );
                    },
                  ),
                ),
    );
  }
}