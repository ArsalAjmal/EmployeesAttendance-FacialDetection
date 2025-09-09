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
import 'package:geolocator/geolocator.dart';
import '../utils/constants.dart';

class CheckInScreen extends StatefulWidget {
  @override
  _CheckInScreenState createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  bool _isLoading = false;
  bool _isCameraInitialized = false;
  bool _isScanning = false;

  late CameraService _cameraService;
  late FaceDetectionService _faceDetectionService;
  late FirebaseService _firebaseService;

  List<Employee> _employees = [];
  Employee? _recognizedEmployee;

  @override
  void initState() {
    super.initState();
    _initializeServices();
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
      final employees = await _firebaseService.getAllEmployees();
      setState(() {
        _employees = employees;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load employees: $e');
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

      // Find best and second-best matches among employees (use all samples)
      double bestScore = -1.0;
      double secondBestScore = -1.0;
      Employee? bestEmployee;
      for (final emp in _employees) {
        final samples =
            (emp.faceEmbeddings.isNotEmpty)
                ? emp.faceEmbeddings
                : (emp.faceEmbedding.isNotEmpty
                    ? [emp.faceEmbedding]
                    : <List<double>>[]);
        if (samples.isEmpty) continue;
        double bestForEmp = -1.0;
        for (final sample in samples) {
          final s = _faceDetectionService.compareFaces(liveEmbedding, sample);
          if (s > bestForEmp) bestForEmp = s;
        }
        if (bestForEmp > bestScore) {
          secondBestScore = bestScore;
          bestScore = bestForEmp;
          bestEmployee = emp;
        } else if (bestForEmp > secondBestScore) {
          secondBestScore = bestForEmp;
        }
      }

      final bool passesThreshold = bestScore >= AppConstants.faceMatchThreshold;
      final bool passesGap =
          bestScore - secondBestScore >= AppConstants.faceSecondBestMinGap;

      print('🔍 Face recognition scores:');
      print('   Best match: ${bestEmployee?.name} (ID: ${bestEmployee?.id})');
      print(
        '   Best score: ${bestScore.toStringAsFixed(4)} (threshold: ${AppConstants.faceMatchThreshold})',
      );
      print('   Second best: ${secondBestScore.toStringAsFixed(4)}');
      print(
        '   Gap: ${(bestScore - secondBestScore).toStringAsFixed(4)} (required: ${AppConstants.faceSecondBestMinGap})',
      );
      print('   Passes threshold: $passesThreshold');
      print('   Passes gap: $passesGap');

      if (bestEmployee == null || !passesThreshold || !passesGap) {
        _showError(
          'Face not recognized with sufficient confidence (Score: ${bestScore.toStringAsFixed(3)})',
        );
        return;
      }

      // Allow operator to pick from top matches to avoid misidentification
      final List<MapEntry<Employee, double>> scored = [];
      for (final emp in _employees) {
        final samples =
            (emp.faceEmbeddings.isNotEmpty)
                ? emp.faceEmbeddings
                : (emp.faceEmbedding.isNotEmpty
                    ? [emp.faceEmbedding]
                    : <List<double>>[]);
        if (samples.isEmpty) continue;
        double bestForEmp = -1.0;
        for (final sample in samples) {
          final s = _faceDetectionService.compareFaces(liveEmbedding, sample);
          if (s > bestForEmp) bestForEmp = s;
        }
        scored.add(MapEntry(emp, bestForEmp));
      }
      scored.sort((a, b) => b.value.compareTo(a.value));
      final top = scored.take(3).toList();

      final Employee? selected = await showDialog<Employee>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Confirm Employee'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Top matches:'),
                SizedBox(height: 8),
                ...top.map(
                  (e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${e.key.name} (${e.key.id})'),
                    subtitle: Text('Score: ${e.value.toStringAsFixed(3)}'),
                    onTap: () => Navigator.of(context).pop(e.key),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: Text('Cancel'),
              ),
            ],
          );
        },
      );
      if (selected == null) {
        _showError('Check-in cancelled. Please try again.');
        return;
      }
      bestEmployee = selected;

      // Check if this employee already checked in today
      print(
        '🔍 Checking existing check-in for employee: ${bestEmployee.id} (${bestEmployee.name})',
      );
      final existingAttendance = await _firebaseService
          .getEmployeeAttendanceToday(bestEmployee.id);

      if (existingAttendance != null) {
        if (existingAttendance.checkOutTime == null) {
          _showError(
            '${bestEmployee.name} has already checked in today. Please use Check Out option.',
          );
          return;
        } else {
          _showError(
            '${bestEmployee.name} has already completed attendance for today.',
          );
          return;
        }
      }

      setState(() {
        _recognizedEmployee = bestEmployee;
      });

      // Proceed with check-in
      print('✅ No existing check-in found - proceeding with check-in');
      _showSuccess(
        'Face recognized: ${bestEmployee.name} - Ready for Check In',
      );
      await _markCheckIn(bestEmployee);
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

  String _getAttendanceStatus(DateTime checkInTime) {
    // Office start time boundary: 09:00 of the same day
    final officeStart = DateTime(
      checkInTime.year,
      checkInTime.month,
      checkInTime.day,
      9,
      0,
      0,
    );

    // On or before 09:00 -> present; after 09:00 -> late
    if (checkInTime.isBefore(officeStart) ||
        checkInTime.isAtSameMomentAs(officeStart)) {
      return 'present';
    }
    return 'late';
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

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Check In'), centerTitle: true),
      body:
          _isLoading
              ? LoadingWidget(message: 'Preparing camera...')
              : Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.login, color: Colors.green, size: 32),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Check In',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                                Text(
                                  'Position your face for check-in',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.green.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20),

                    // Camera Preview
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

                    // Recognition Status
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
                              Icons.check_circle,
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
                              'Check-in completed successfully',
                              style: TextStyle(color: Colors.green.shade600),
                            ),
                          ],
                        ),
                      ),

                    SizedBox(height: 20),

                    // Scan Button
                    ElevatedButton(
                      onPressed: _isScanning ? null : _startFaceRecognition,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child:
                          _isScanning
                              ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 10),
                                  Text('Scanning...'),
                                ],
                              )
                              : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.camera_alt),
                                  SizedBox(width: 8),
                                  Text('Scan Face for Check-In'),
                                ],
                              ),
                    ),
                  ],
                ),
              ),
    );
  }
}
