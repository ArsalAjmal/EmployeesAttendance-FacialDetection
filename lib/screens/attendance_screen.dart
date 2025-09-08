import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../services/face_detection_service.dart';
import '../services/camera_service.dart';
import '../models/employee.dart';
import '../models/attendance.dart';
import '../widgets/camera_preview_widget.dart';
import '../widgets/loading_widget.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/constants.dart';

class AttendanceScreen extends StatefulWidget {
  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _isLoading = false;
  bool _isCameraInitialized = false;
  bool _isScanning = false;

  late CameraService _cameraService;
  late FaceDetectionService _faceDetectionService;
  late FirebaseService _firebaseService;

  List<Employee> _employees = [];
  Employee? _recognizedEmployee;
  Attendance? _existingAttendance;
  bool _isCheckOut = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _resetState();
  }

  void _resetState() {
    setState(() {
      _recognizedEmployee = null;
      _existingAttendance = null;
      _isCheckOut = false;
    });
  }

  void _initializeServices() {
    _cameraService = Provider.of<CameraService>(context, listen: false);
    _faceDetectionService = Provider.of<FaceDetectionService>(
      context,
      listen: false,
    );
    _firebaseService = Provider.of<FirebaseService>(context, listen: false);
    _loadEmployees();
    _initializeCamera();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    try {
      _employees = await _firebaseService.getAllEmployees();
    } catch (e) {
      _showError('Failed to load employees: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _initializeCamera() async {
    final success = await _cameraService.initialize();
    setState(() => _isCameraInitialized = success);
  }

  Future<void> _startFaceRecognition() async {
    if (!_isCameraInitialized) return;

    setState(() => _isScanning = true);

    try {
      // Reset state for new employee attempt
      setState(() {
        _recognizedEmployee = null;
        _existingAttendance = null;
        _isCheckOut = false;
      });

      // Capture a photo
      final captured = await _cameraService.takePicture();
      if (captured == null) {
        _showError('Failed to capture image');
        return;
      }

      // Detect face from file
      final faces = await _faceDetectionService.detectFacesFromFile(
        File(captured.path),
      );
      if (faces.isEmpty) {
        _showError('No face detected');
        return;
      }

      // Generate embedding for the first detected face
      final liveEmbedding = _faceDetectionService.generateFaceEmbedding(
        faces.first,
      );

      // Find best and second-best matches among employees
      double bestScore = -1.0;
      double secondBestScore = -1.0;
      Employee? bestEmployee;
      for (final emp in _employees) {
        if (emp.faceEmbedding.isEmpty) continue;
        final score = _faceDetectionService.compareFaces(
          liveEmbedding,
          emp.faceEmbedding,
        );
        if (score > bestScore) {
          secondBestScore = bestScore;
          bestScore = score;
          bestEmployee = emp;
        } else if (score > secondBestScore) {
          secondBestScore = score;
        }
      }

      final bool passesThreshold = bestScore >= AppConstants.faceMatchThreshold;
      final bool passesGap =
          bestScore - secondBestScore >= AppConstants.faceSecondBestMinGap;

      if (bestEmployee == null || !passesThreshold || !passesGap) {
        _showError('Face not recognized with sufficient confidence');
        return;
      }

      // Check if this employee already marked today
      print(
        '🔍 Checking existing attendance for employee: ${bestEmployee.id} (${bestEmployee.name})',
      );
      final existingAttendance = await _firebaseService
          .getEmployeeAttendanceToday(bestEmployee.id);

      setState(() {
        _recognizedEmployee = bestEmployee;
        _existingAttendance = existingAttendance;
        _isCheckOut =
            existingAttendance != null &&
            existingAttendance.checkOutTime == null;
      });

      if (existingAttendance == null) {
        // First time today - Check In
        print('✅ No existing attendance found - proceeding with check-in');
        _showSuccess(
          'Face recognized: ${bestEmployee.name} - Ready for Check In',
        );
        await _markCheckIn(bestEmployee);
      } else if (existingAttendance.checkOutTime == null) {
        // Already checked in, ready for check out
        print('✅ Existing check-in found - proceeding with check-out');
        _showSuccess(
          'Face recognized: ${bestEmployee.name} - Ready for Check Out',
        );
        await _markCheckOut(bestEmployee, existingAttendance);
      } else {
        // Both check-in and check-out already done
        print('❌ Both check-in and check-out already completed for today');
        _showError(
          '${bestEmployee.name} has already completed attendance for today',
        );
        return;
      }
    } catch (e) {
      _showError('Face recognition failed: $e');
    } finally {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _markCheckIn(Employee employee) async {
    try {
      // Validate location before allowing check-in
      final locationValid = await _validateLocation();
      if (!locationValid) {
        _showError(
          'Check-in not allowed at this location. Please be within office premises.',
        );
        return;
      }

      final now = DateTime.now();
      final status = _getAttendanceStatus(now);

      final attendance = Attendance(
        id: '',
        employeeId: employee.id,
        checkInTime: now,
        checkOutTime: null,
        status: status,
        date: now.toIso8601String().split('T')[0],
      );

      await _firebaseService.markAttendance(attendance);
      _showSuccess('Check-in successful! ${_getStatusMessage(status)}');

      // Navigate back after 2 seconds
      await Future.delayed(Duration(seconds: 2));
      Navigator.pop(context);
    } catch (e) {
      _showError('Failed to mark check-in: $e');
    }
  }

  Future<void> _markCheckOut(
    Employee employee,
    Attendance existingAttendance,
  ) async {
    try {
      // Validate location before allowing check-out
      final locationValid = await _validateLocation();
      if (!locationValid) {
        _showError(
          'Check-out not allowed at this location. Please be within office premises.',
        );
        return;
      }

      final now = DateTime.now();

      await _firebaseService.markCheckOut(existingAttendance.id, now);

      final workDuration = now.difference(existingAttendance.checkInTime);
      final hours = workDuration.inHours;
      final minutes = workDuration.inMinutes % 60;

      _showSuccess('Check-out successful! Work time: ${hours}h ${minutes}m');

      // Navigate back after 2 seconds
      await Future.delayed(Duration(seconds: 2));
      Navigator.pop(context);
    } catch (e) {
      _showError('Failed to mark check-out: $e');
    }
  }

  String _getAttendanceStatus(DateTime checkIn) {
    final hour = checkIn.hour;
    if (hour <= 9) return 'present';
    if (hour <= 10) return 'late';
    return 'late'; // Changed from 'absent' since they're physically checking in
  }

  String _getStatusMessage(String status) {
    switch (status) {
      case 'present':
        return 'On time!';
      case 'late':
        return 'Late arrival';
      default:
        return '';
    }
  }

  // Location validation for geofencing
  Future<bool> _validateLocation() async {
    try {
      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Location permission required for attendance');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError(
          'Location permissions permanently denied. Please enable in settings.',
        );
        return false;
      }

      // Get current location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Validate against office locations with detailed feedback
      final validationResult = await _firebaseService
          .validateLocationForAttendance(
            latitude: position.latitude,
            longitude: position.longitude,
            accuracy: position.accuracy,
          );

      if (validationResult['isValid']) {
        print(
          '✅ Location validation successful: ${position.latitude}, ${position.longitude}',
        );
        print('📍 ${validationResult['details']}');
        return true;
      } else {
        print(
          '❌ Location validation failed: ${position.latitude}, ${position.longitude}',
        );
        print('📍 ${validationResult['details']}');
        _showError(validationResult['details'] ?? 'Location validation failed');
        return false;
      }
    } catch (e) {
      print('❌ Error validating location: $e');
      _showError('Failed to validate location: $e');
      return false;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  String _formatTime(DateTime time) {
    return DateFormat('HH:mm').format(time);
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mark Attendance')),
      body:
          _isLoading
              ? LoadingWidget(message: 'Preparing camera...')
              : Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _existingAttendance == null
                          ? 'Position your face for Check-In'
                          : _existingAttendance!.checkOutTime == null
                          ? 'Position your face for Check-Out'
                          : 'Attendance Complete',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 20),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.black12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child:
                            _isCameraInitialized
                                ? CameraPreviewWidget(
                                  controller: _cameraService.controller!,
                                )
                                : Center(child: Text('Camera not available')),
                      ),
                    ),
                    SizedBox(height: 20),
                    if (_recognizedEmployee != null)
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _isCheckOut ? Icons.logout : Icons.login,
                              color: Colors.green,
                              size: 40,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Welcome, ${_recognizedEmployee!.name}!',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              _isCheckOut
                                  ? 'Check-out completed successfully'
                                  : 'Check-in completed successfully',
                            ),
                            if (_existingAttendance != null && _isCheckOut)
                              Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'Check-in: ${_formatTime(_existingAttendance!.checkInTime)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    SizedBox(height: 20),
                    if (_existingAttendance != null &&
                        _existingAttendance!.checkOutTime != null)
                      // Show reset button when attendance is complete
                      Column(
                        children: [
                          ElevatedButton(
                            onPressed: _resetState,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            child: Text('Mark Another Employee'),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Attendance Complete',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    else
                      // Show scan button for normal flow
                      ElevatedButton(
                        onPressed: _isScanning ? null : _startFaceRecognition,
                        child:
                            _isScanning
                                ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(width: 10),
                                    Text('Scanning...'),
                                  ],
                                )
                                : Text(
                                  _existingAttendance == null
                                      ? 'Scan Face for Check-In'
                                      : _existingAttendance!.checkOutTime ==
                                          null
                                      ? 'Scan Face for Check-Out'
                                      : 'Attendance Complete',
                                ),
                      ),
                  ],
                ),
              ),
    );
  }
}
