import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  CameraController? get controller => _controller;

  Future<bool> initialize() async {
    try {
      // Request camera permission
      final status = await Permission.camera.request();
      if (status != PermissionStatus.granted) {
        return false;
      }

      // Get available cameras
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        return false;
      }

      // Initialize front camera for face recognition
      final frontCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      _isInitialized = true;
      return true;
    } catch (e) {
      print('Camera initialization error: $e');
      return false;
    }
  }

  Future<XFile?> takePicture() async {
    if (!_isInitialized || _controller == null) return null;
    
    try {
      return await _controller!.takePicture();
    } catch (e) {
      print('Error taking picture: $e');
      return null;
    }
  }

  Future<CameraImage?> getCameraImage() async {
    if (!_isInitialized || _controller == null) return null;
    
    try {
      // Start image stream to get the latest frame
      final completer = Completer<CameraImage>();
      
      void imageListener(CameraImage image) {
        if (!completer.isCompleted) {
          completer.complete(image);
        }
      }
      
      _controller!.startImageStream(imageListener);
      
      // Wait for the first image
      final image = await completer.future;
      
      // Stop the stream after getting the image
      await _controller!.stopImageStream();
      
      return image;
    } catch (e) {
      print('Error getting camera image: $e');
      return null;
    }
  }

  void dispose() {
    _controller?.dispose();
    _isInitialized = false;
  }
}