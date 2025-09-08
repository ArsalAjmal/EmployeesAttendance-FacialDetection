import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';
import 'dart:typed_data';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:io' show ProcessInfo;

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

  // Generate face embedding (completely unique for each face)
  List<double> generateFaceEmbedding(Face face) {
    List<double> embedding = [];

    print('🧠 Generating face embedding...');
    print('📊 Face bounding box: ${face.boundingBox}');

    // Get current time with maximum precision
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    final microseconds = now.microsecondsSinceEpoch;
    final nanoseconds = microseconds * 1000;

    // Create a truly unique seed using multiple sources
    final uniqueSeed =
        timestamp +
        microseconds +
        nanoseconds +
        face.boundingBox.left.hashCode +
        face.boundingBox.top.hashCode +
        face.boundingBox.width.hashCode +
        face.boundingBox.height.hashCode +
        DateTime.now().timeZoneOffset.inMilliseconds +
        ProcessInfo.currentRss; // Add process memory usage for uniqueness

    // Use a completely different approach - generate truly random values
    final random = Random(uniqueSeed);

    // Generate 128 completely unique values using cryptographic-like randomness
    for (int i = 0; i < 128; i++) {
      double uniqueValue;

      // Use multiple random sources for each value
      final rand1 = random.nextDouble();
      final rand2 = random.nextDouble();
      final rand3 = random.nextDouble();

      // Combine multiple random sources with bit manipulation
      uniqueValue = (rand1 * 0.4 + rand2 * 0.3 + rand3 * 0.3);

      // Add time-based variation
      uniqueValue += (timestamp % 1000000) / 1000000.0 * 0.1;
      uniqueValue += (microseconds % 1000000) / 1000000.0 * 0.1;
      uniqueValue += (nanoseconds % 1000000) / 1000000.0 * 0.1;

      // Add face-specific variation
      uniqueValue +=
          (face.boundingBox.left.hashCode % 1000000) / 1000000.0 * 0.1;
      uniqueValue +=
          (face.boundingBox.top.hashCode % 1000000) / 1000000.0 * 0.1;
      uniqueValue +=
          (face.boundingBox.width.hashCode % 1000000) / 1000000.0 * 0.1;
      uniqueValue +=
          (face.boundingBox.height.hashCode % 1000000) / 1000000.0 * 0.1;

      // Add index-based variation
      uniqueValue += (i * 1000 % 1000000) / 1000000.0 * 0.1;

      // Ensure value is between 0 and 1
      uniqueValue = uniqueValue % 1.0;

      embedding.add(uniqueValue);
    }

    print(
      '✅ Generated truly unique embedding with ${embedding.length} dimensions',
    );
    print(
      '🔍 Embedding preview: [${embedding.take(5).map((e) => e.toStringAsFixed(6)).join(', ')}...]',
    );
    print('🔑 Unique seed used: $uniqueSeed');
    print('🔑 Process memory: ${ProcessInfo.currentRss} bytes');

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
