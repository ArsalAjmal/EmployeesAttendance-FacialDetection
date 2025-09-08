import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';

import '../services/firebase_service.dart';
import '../services/face_detection_service.dart';
import '../services/camera_service.dart';
import '../models/employee.dart';
import '../widgets/camera_preview_widget.dart';
import '../widgets/loading_widget.dart';

import 'dart:io';


class RegistrationScreen extends StatefulWidget {
  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  bool _isCameraInitialized = false;
  bool _faceDetected = false;
  XFile? _capturedImage;
  
  late CameraService _cameraService;
  late FaceDetectionService _faceDetectionService;
  late FirebaseService _firebaseService;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  void _initializeServices() {
    _cameraService = Provider.of<CameraService>(context, listen: false);
    _faceDetectionService = Provider.of<FaceDetectionService>(context, listen: false);
    _firebaseService = Provider.of<FirebaseService>(context, listen: false);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    setState(() => _isLoading = true);
    final success = await _cameraService.initialize();
    setState(() {
      _isCameraInitialized = success;
      _isLoading = false;
    });
  }

  Future<void> _captureAndAnalyzeFace() async {
    if (!_isCameraInitialized) return;

    setState(() => _isLoading = true);
    
    try {
      final image = await _cameraService.takePicture();
      if (image != null) {
        print('📸 Image captured successfully: ${image.path}');
        
        // Process the saved image file for face detection
        try {
          final faces = await _faceDetectionService.detectFacesFromFile(File(image.path));
          print('👥 Found ${faces.length} faces in the image');
          
          if (faces.isNotEmpty) {
            // Generate face embedding for the first detected face
            final faceEmbedding = _faceDetectionService.generateFaceEmbedding(faces.first);
            print('🧠 Generated face embedding with ${faceEmbedding.length} dimensions');
            
            setState(() {
              _capturedImage = image;
              _faceDetected = true;
            });
            
            _showSuccess('Face detected and analyzed successfully!');
                     } else {
             // No face detected - don't allow registration
             print('❌ No face detected in the image');
             setState(() {
               _capturedImage = null;
               _faceDetected = false;
             });
             
             _showError('No face detected in the image. Please capture a clear photo of a person\'s face.');
           }
                 } catch (e) {
           print('❌ Face detection failed: $e');
           // Face detection failed - don't allow registration
           setState(() {
             _capturedImage = null;
             _faceDetected = false;
           });
           
           _showError('Face detection failed. Please try again with a clearer image.');
         }
      } else {
        _showError('Failed to capture image');
      }
    } catch (e) {
      print('❌ Error in _captureAndAnalyzeFace: $e');
      _showError('Failed to capture and analyze image: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _registerEmployee() async {
    if (!_formKey.currentState!.validate() || _capturedImage == null) {
      _showError('Please fill all fields and capture a face image');
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      print('🚀 Starting employee registration...');
      print('👤 Employee name: ${_nameController.text.trim()}');
      print('📸 Image path: ${_capturedImage!.path}');
      
      // Generate face embedding from the captured image file
      List<double> faceEmbedding;
      try {
        final faces = await _faceDetectionService.detectFacesFromFile(File(_capturedImage!.path));
        if (faces.isNotEmpty) {
          faceEmbedding = _faceDetectionService.generateFaceEmbedding(faces.first);
          print('🧠 Generated face embedding: ${faceEmbedding.length} dimensions');
                 } else {
           // No face detected - don't allow registration
           print('❌ No face detected during registration');
           throw Exception('No face detected in the image. Please capture a clear photo of a person\'s face.');
         }
             } catch (e) {
         print('❌ Face detection failed during registration: $e');
         throw Exception('Face detection failed. Please try again with a clearer image.');
       }
      
      final employee = Employee(
        id: '',
        name: _nameController.text.trim(),
        faceImageUrl: '',
        faceEmbedding: faceEmbedding,
        createdAt: DateTime.now(),
        isActive: true,
      );

      print('💾 Saving employee to Firebase...');
      final employeeId = await _firebaseService.registerEmployee(employee, File(_capturedImage!.path));
      print('✅ Employee registered successfully with ID: $employeeId');
      
      _showSuccess('Employee registered successfully!');
      Navigator.pop(context);
    } catch (e) {
      print('❌ Registration failed: $e');
      String errorMessage = e.toString();
      
      // Check if it's a duplicate face error
      if (errorMessage.contains('Face already registered')) {
        _showDuplicateFaceError(errorMessage);
      } else {
        _showError('Registration failed: $e');
      }
    } finally {
      setState(() => _isLoading = false);
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

  void _showDuplicateFaceError(String errorMessage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Duplicate Face Detected',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This face is already registered in the system.',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              SizedBox(height: 16),
              Text(
                'Each person can only be registered once in the system for security reasons.',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Reset the form
              setState(() {
                _capturedImage = null;
                _faceDetected = false;
              });
              _nameController.clear();
            },
            child: Text('Try Again'),
          ),

          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to admin dashboard
            },
            child: Text('Close'),
          ),
        ],
      ),
    );
  }



  @override
  void dispose() {
    _nameController.dispose();
    _cameraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Register Employee'),
      ),
      body: _isLoading
          ? LoadingWidget(message: 'Initializing camera...')
          : SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Employee Name',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter employee name';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20),
                    Container(
                      height: 400,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _isCameraInitialized
                          ? CameraPreviewWidget(
                              controller: _cameraService.controller!,
                              onFaceDetected: (detected) {
                                setState(() => _faceDetected = detected);
                              },
                            )
                          : Center(child: Text('Camera not available')),
                    ),
                    SizedBox(height: 10),
                    if (_faceDetected)
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 10),
                            Text('Face detected successfully!'),
                          ],
                        ),
                      ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isCameraInitialized ? _captureAndAnalyzeFace : null,
                      child: Text('Capture Face'),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _faceDetected ? _registerEmployee : null,
                      child: Text('Register Employee'),
                    ),

                  ],
                ),
              ),
            ),
    );
  }
}