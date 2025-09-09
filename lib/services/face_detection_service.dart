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

  // Generate face embedding deterministically from normalized geometry and landmarks
  List<double> generateFaceEmbedding(Face face) {
    final List<double> features = [];

    // Normalize all coordinates by bounding box to reduce scale/translation effects
    final bbox = face.boundingBox;
    final double bx = bbox.left;
    final double by = bbox.top;
    final double bw = max(bbox.width, 1.0);
    final double bh = max(bbox.height, 1.0);

    double nx(double x) => (x - bx) / bw; // 0..1
    double ny(double y) => (y - by) / bh; // 0..1

    // Aspect ratio
    features.add(bw / bh);

    // Landmarks of interest
    final leftEye = face.landmarks[FaceLandmarkType.leftEye]?.position;
    final rightEye = face.landmarks[FaceLandmarkType.rightEye]?.position;
    final nose = face.landmarks[FaceLandmarkType.noseBase]?.position;
    final leftMouth = face.landmarks[FaceLandmarkType.leftMouth]?.position;
    final rightMouth = face.landmarks[FaceLandmarkType.rightMouth]?.position;

    // Helper to push normalized point
    void pushPoint(Point<int>? p) {
      if (p == null) {
        features.addAll([0.0, 0.0]);
      } else {
        features.add(nx(p.x.toDouble()));
        features.add(ny(p.y.toDouble()));
      }
    }

    pushPoint(leftEye);
    pushPoint(rightEye);
    pushPoint(nose);
    pushPoint(leftMouth);
    pushPoint(rightMouth);

    // Distances normalized by bbox diagonal
    double diag = sqrt(bw * bw + bh * bh);
    double nd(Point<int>? a, Point<int>? b) {
      if (a == null || b == null) return 0.0;
      final dx = (a.x - b.x).toDouble();
      final dy = (a.y - b.y).toDouble();
      return sqrt(dx * dx + dy * dy) / max(diag, 1.0);
    }

    features.add(nd(leftEye, rightEye)); // inter-ocular distance
    features.add(nd(nose, leftEye));
    features.add(nd(nose, rightEye));
    features.add(nd(leftMouth, rightMouth));
    features.add(nd(nose, leftMouth));
    features.add(nd(nose, rightMouth));

    // Eye line angle (cos,sin) to be rotation-aware but bounded
    if (leftEye != null && rightEye != null) {
      final ex = (rightEye.x - leftEye.x).toDouble();
      final ey = (rightEye.y - leftEye.y).toDouble();
      final angle = atan2(ey, ex); // -pi..pi
      features.add(cos(angle));
      features.add(sin(angle));
    } else {
      features.addAll([0.0, 0.0]);
    }

    // Contour complexity (normalized length of face contour)
    final contour = face.contours[FaceContourType.face];
    if (contour != null && contour.points.isNotEmpty) {
      double sum = 0.0;
      for (int i = 1; i < contour.points.length; i++) {
        final a = contour.points[i - 1];
        final b = contour.points[i];
        final dx = (a.x - b.x).toDouble();
        final dy = (a.y - b.y).toDouble();
        sum += sqrt(dx * dx + dy * dy);
      }
      features.add(sum / max(diag, 1.0));
    } else {
      features.add(0.0);
    }

    // Classification probabilities
    features.add(face.smilingProbability ?? 0.0);
    features.add(face.leftEyeOpenProbability ?? 0.0);
    features.add(face.rightEyeOpenProbability ?? 0.0);

    // Deterministic expansion to fixed 128 dims using simple polynomial hashes
    // This ensures no randomness/time-based noise.
    List<double> embedding = List<double>.from(features);
    double hash = 0.0;
    for (final v in features) {
      hash = (hash * 1667.0 + v * 1000.0) % 100000.0;
    }
    while (embedding.length < 128) {
      hash = (hash * 48271.0 + 31.0) % 100000.0;
      embedding.add((hash % 1000.0) / 1000.0); // 0..1 deterministic filler
    }
    if (embedding.length > 128) embedding = embedding.sublist(0, 128);

    print('✅ Generated deterministic embedding with ${embedding.length} dims');
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
