import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';
import 'dart:typed_data';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'dart:io';

class FaceDetectionService {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: true,
    ),
  );

  Future<List<Face>> detectFaces(CameraImage image) async {
    // Convert CameraImage to bytes
    final bytes = _concatenatePlanes(image.planes);

    final imageSize = Size(image.width.toDouble(), image.height.toDouble());

    // Create InputImage from bytes
    final inputImage = InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: imageSize,
        rotation: InputImageRotation.rotation0deg,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );

    return await _faceDetector.processImage(inputImage);
  }

  Future<List<Face>> detectFacesFromFile(File imageFile) async {
    try {
      print('📁 Detecting faces from file: ${imageFile.path}');

      // Use ML Kit's file-based constructor to avoid byte/format mismatches
      final inputImage = InputImage.fromFilePath(imageFile.path);

      final faces = await _faceDetector.processImage(inputImage);
      print('👥 Face detection completed: ${faces.length} faces found');

      // Filter out faces that are too small or have insufficient features (likely false positives)
      final validFaces =
          faces.where((face) {
            final faceArea = face.boundingBox.width * face.boundingBox.height;
            final minArea = 10000; // Minimum 100x100 pixels
            final hasEnoughLandmarks =
                face.landmarks.length >= 5; // At least 5 landmarks
            final hasEnoughContours =
                face.contours.length >= 3; // At least 3 contours

            final isValid =
                faceArea >= minArea && hasEnoughLandmarks && hasEnoughContours;

            if (!isValid) {
              if (faceArea < minArea) {
                print(
                  '⚠️ Filtered out small face: ${face.boundingBox.width}x${face.boundingBox.height} = $faceArea pixels',
                );
              }
              if (!hasEnoughLandmarks) {
                print(
                  '⚠️ Filtered out face with insufficient landmarks: ${face.landmarks.length} < 5',
                );
              }
              if (!hasEnoughContours) {
                print(
                  '⚠️ Filtered out face with insufficient contours: ${face.contours.length} < 3',
                );
              }
            }

            return isValid;
          }).toList();

      print('✅ Valid faces after filtering: ${validFaces.length}');
      return validFaces;
    } catch (e) {
      print('❌ Error in detectFacesFromFile: $e');
      throw Exception('Failed to detect faces from file: $e');
    }
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  // Generate face embedding using a highly unique approach
  List<double> generateFaceEmbedding(Face face) {
    List<double> embedding = [];

    print('🧠 Generating highly unique face embedding...');
    print('📊 Face bounding box: ${face.boundingBox}');

    // Use a highly unique approach: combine face features with cryptographic-like uniqueness
    final bbox = face.boundingBox;
    final centerX = bbox.center.dx;
    final centerY = bbox.center.dy;
    final width = bbox.width;
    final height = bbox.height;
    final aspectRatio = width / height;

    // Create a highly unique seed using face features + time + process info
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final processId = DateTime.now().millisecondsSinceEpoch % 1000000;
    final faceHash =
        (centerX * 100000 + centerY * 100000 + width * 10000 + height * 10000)
            .round();
    final uniqueSeed = faceHash + timestamp + processId;
    final random = Random(uniqueSeed);

    // Generate 128 highly unique values
    for (int i = 0; i < 128; i++) {
      double value = 0.0;

      // Use different unique patterns for different dimensions
      if (i < 30) {
        // First 30 values based on face geometry with maximum precision
        final baseValue = (i * 1000 + faceHash) % 1000000;
        switch (i % 15) {
          case 0:
            value = (centerX * 1000 + baseValue) % 1000000 / 1000000.0;
            break;
          case 1:
            value = (centerY * 1000 + baseValue) % 1000000 / 1000000.0;
            break;
          case 2:
            value = (width * 1000 + baseValue) % 1000000 / 1000000.0;
            break;
          case 3:
            value = (height * 1000 + baseValue) % 1000000 / 1000000.0;
            break;
          case 4:
            value = (aspectRatio * 1000000 + baseValue) % 1000000 / 1000000.0;
            break;
          case 5:
            value = (bbox.left * 1000 + baseValue) % 1000000 / 1000000.0;
            break;
          case 6:
            value = (bbox.top * 1000 + baseValue) % 1000000 / 1000000.0;
            break;
          case 7:
            value = (bbox.right * 1000 + baseValue) % 1000000 / 1000000.0;
            break;
          case 8:
            value = (bbox.bottom * 1000 + baseValue) % 1000000 / 1000000.0;
            break;
          case 9:
            value = ((width + height) * 1000 + baseValue) % 1000000 / 1000000.0;
            break;
          case 10:
            value = ((width * height) + baseValue) % 1000000 / 1000000.0;
            break;
          case 11:
            value =
                ((centerX + centerY) * 1000 + baseValue) % 1000000 / 1000000.0;
            break;
          case 12:
            value =
                ((centerX - centerY).abs() * 1000 + baseValue) %
                1000000 /
                1000000.0;
            break;
          case 13:
            value =
                ((width - height).abs() * 1000 + baseValue) %
                1000000 /
                1000000.0;
            break;
          case 14:
            value =
                ((width / height) * 1000000 + baseValue) % 1000000 / 1000000.0;
            break;
        }
      } else if (i < 60) {
        // Next 30 values based on landmarks with high precision
        if (face.landmarks.isNotEmpty) {
          final leftEye = face.landmarks[FaceLandmarkType.leftEye];
          final rightEye = face.landmarks[FaceLandmarkType.rightEye];
          final nose = face.landmarks[FaceLandmarkType.noseBase];
          final leftMouth = face.landmarks[FaceLandmarkType.leftMouth];
          final rightMouth = face.landmarks[FaceLandmarkType.rightMouth];

          double landmarkValue = 0.0;
          if (leftEye != null) {
            landmarkValue += (leftEye.position.x * 1000) % 1000000;
            landmarkValue += (leftEye.position.y * 1000) % 1000000;
          }
          if (rightEye != null) {
            landmarkValue += (rightEye.position.x * 1000) % 1000000;
            landmarkValue += (rightEye.position.y * 1000) % 1000000;
          }
          if (nose != null) {
            landmarkValue += (nose.position.x * 1000) % 1000000;
            landmarkValue += (nose.position.y * 1000) % 1000000;
          }
          if (leftMouth != null) {
            landmarkValue += (leftMouth.position.x * 1000) % 1000000;
            landmarkValue += (leftMouth.position.y * 1000) % 1000000;
          }
          if (rightMouth != null) {
            landmarkValue += (rightMouth.position.x * 1000) % 1000000;
            landmarkValue += (rightMouth.position.y * 1000) % 1000000;
          }
          value = (landmarkValue + i * 10000) % 1000000 / 1000000.0;
        } else {
          value = random.nextDouble();
        }
      } else {
        // Remaining values based on highly unique random with multiple seeds
        value = random.nextDouble();

        // Add multiple unique variations
        value += (timestamp % 1000000) / 1000000.0 * 0.1;
        value += (processId % 1000000) / 1000000.0 * 0.1;
        value += (faceHash % 1000000) / 1000000.0 * 0.1;
        value += (i * 1000000 % 1000000) / 1000000.0 * 0.1;
        value += (uniqueSeed % 1000000) / 1000000.0 * 0.1;

        value = value % 1.0;
      }

      embedding.add(value);
    }

    print(
      '✅ Generated highly unique face embedding with ${embedding.length} dimensions',
    );
    print('🔍 Face hash: $faceHash');
    print('🔍 Unique seed: $uniqueSeed');
    print('🔍 Timestamp: $timestamp');
    print('🔍 Process ID: $processId');
    print(
      '🔍 Embedding preview: [${embedding.take(5).map((e) => e.toStringAsFixed(6)).join(', ')}...]',
    );

    return embedding;
  }

  // Compare face embeddings
  double compareFaces(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) return 0.0;

    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
      norm1 += embedding1[i] * embedding1[i];
      norm2 += embedding2[i] * embedding2[i];
    }

    if (norm1 == 0.0 || norm2 == 0.0) return 0.0;

    return dotProduct / (sqrt(norm1) * sqrt(norm2));
  }

  void dispose() {
    _faceDetector.close();
  }
}
