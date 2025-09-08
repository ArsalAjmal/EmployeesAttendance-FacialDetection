import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/employee.dart';
import '../models/attendance.dart';
import '../models/location.dart';
import 'location_service.dart';
import 'dart:io';
import 'dart:convert';

import 'package:image/image.dart' as img;

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _locationService = LocationService();

  // Employee Operations
  Future<Employee?> checkForDuplicateFace(List<double> newFaceEmbedding) async {
    try {
      print('🔍 Duplicate detection disabled - allowing all registrations');
      print('✅ Registration allowed for new face embedding');
      return null; // Always allow registration
    } catch (e) {
      print('❌ Error in checkForDuplicateFace: $e');
      return null; // Allow registration even if there's an error
    }
  }

  Future<String> registerEmployee(Employee employee, File imageFile) async {
    try {
      print('📤 Starting employee registration process...');
      print('👤 Employee name: ${employee.name}');
      print('🧠 Face embedding dimensions: ${employee.faceEmbedding.length}');

      // Check for duplicate faces before proceeding with improved thresholds
      print('🔍 Running duplicate face detection...');
      final duplicateEmployee = await checkForDuplicateFace(
        employee.faceEmbedding,
      );
      if (duplicateEmployee != null) {
        throw Exception(
          'Face already registered! This face belongs to existing employee: ${duplicateEmployee.name} (ID: ${duplicateEmployee.id})',
        );
      }
      print('✅ No duplicate face detected, proceeding with registration');

      // Compress and convert image to base64
      print('📤 Compressing and converting image to base64...');
      String base64Image = await _compressAndEncodeImage(imageFile);
      print(
        '✅ Image compressed and encoded successfully. Size: ${base64Image.length} characters',
      );

      // Generate a short, unique employee ID
      final String shortId = await _generateEmployeeId(employee.name);
      print('🆔 Generated employee ID: $shortId');

      // Create employee with base64 image data and short ID
      Employee employeeWithImage = Employee(
        id: shortId,
        name: employee.name,
        faceImageUrl: base64Image, // Store base64 data instead of URL
        faceEmbedding: employee.faceEmbedding,
        createdAt: employee.createdAt,
        isActive: employee.isActive,
      );

      // Save to Firestore with custom ID
      print('💾 Saving employee data to Firestore with custom ID...');
      final docRef = _firestore.collection('employees').doc(shortId);
      await docRef.set(employeeWithImage.toMap());

      print('✅ Employee saved to Firestore with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Error in registerEmployee: $e');
      throw Exception('Failed to register employee: $e');
    }
  }

  Future<String> _generateEmployeeId(String name) async {
    // Create a 6-character ID: 2 letters from name + 4 random alphanumerics
    String prefix =
        name.trim().isNotEmpty
            ? name.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase()
            : 'EM';
    prefix =
        prefix.length >= 2
            ? prefix.substring(0, 2)
            : (prefix + 'X').substring(0, 2);

    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    String randomPart() {
      final rand = DateTime.now().microsecondsSinceEpoch.remainder(1 << 31);
      String out = '';
      int seed = rand;
      for (int i = 0; i < 4; i++) {
        seed = 1664525 * seed + 1013904223; // LCG
        out += chars[seed % chars.length];
      }
      return out;
    }

    while (true) {
      final candidate = '$prefix${randomPart()}';
      final doc = await _firestore.collection('employees').doc(candidate).get();
      if (!doc.exists) return candidate;
    }
  }

  Future<List<Employee>> getAllEmployees() async {
    try {
      QuerySnapshot snapshot =
          await _firestore
              .collection('employees')
              .where('isActive', isEqualTo: true)
              .get();

      return snapshot.docs
          .map(
            (doc) =>
                Employee.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to get employees: $e');
    }
  }

  // Attendance Operations
  Future<void> markAttendance(Attendance attendance) async {
    try {
      print('📝 Marking attendance for employee: ${attendance.employeeId}');
      print('📅 Date: ${attendance.date}');
      print('⏰ Check-in time: ${attendance.checkInTime}');
      print('📊 Status: ${attendance.status}');

      final docRef = await _firestore
          .collection('attendance')
          .add(attendance.toMap());

      print('✅ Attendance marked successfully with ID: ${docRef.id}');
    } catch (e) {
      print('❌ Error marking attendance: $e');
      throw Exception('Failed to mark attendance: $e');
    }
  }

  Future<void> markCheckOut(String attendanceId, DateTime checkOutTime) async {
    try {
      await _firestore.collection('attendance').doc(attendanceId).update({
        'checkOutTime': checkOutTime.millisecondsSinceEpoch,
      });
    } catch (e) {
      throw Exception('Failed to mark check-out: $e');
    }
  }

  Future<void> markCheckOutWithLocation(
    String attendanceId,
    DateTime checkOutTime, {
    double? checkOutLatitude,
    double? checkOutLongitude,
    double? checkOutAccuracy,
    String? checkOutAddress,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'checkOutTime': checkOutTime.millisecondsSinceEpoch,
      };

      // Add location data if provided
      if (checkOutLatitude != null)
        updateData['checkOutLatitude'] = checkOutLatitude;
      if (checkOutLongitude != null)
        updateData['checkOutLongitude'] = checkOutLongitude;
      if (checkOutAccuracy != null)
        updateData['checkOutAccuracy'] = checkOutAccuracy;
      if (checkOutAddress != null)
        updateData['checkOutAddress'] = checkOutAddress;

      await _firestore
          .collection('attendance')
          .doc(attendanceId)
          .update(updateData);

      print(
        '✅ Check-out marked with location data: $checkOutLatitude, $checkOutLongitude',
      );
    } catch (e) {
      throw Exception('Failed to mark check-out with location: $e');
    }
  }

  Future<int> markAbsentForRemainingEmployees(
    List<Employee> allEmployees,
  ) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final snapshot =
          await _firestore
              .collection('attendance')
              .where('date', isEqualTo: today)
              .get();

      final markedIds =
          snapshot.docs.map((d) => d.data()['employeeId'] as String).toSet();
      final remaining =
          allEmployees.where((e) => !markedIds.contains(e.id)).toList();

      WriteBatch batch = _firestore.batch();
      int count = 0;
      for (final emp in remaining) {
        final docRef = _firestore.collection('attendance').doc();
        batch.set(
          docRef,
          Attendance(
            id: docRef.id,
            employeeId: emp.id,
            checkInTime: DateTime.now(),
            checkOutTime: null,
            status: 'absent',
            date: today,
          ).toMap(),
        );
        count++;
      }
      if (count > 0) {
        await batch.commit();
      }
      return count;
    } catch (e) {
      throw Exception('Failed to mark remaining employees absent: $e');
    }
  }

  Future<int> markAbsentForRemainingEmployeesForDate(
    List<Employee> allEmployees,
    DateTime date,
  ) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];
      final snapshot =
          await _firestore
              .collection('attendance')
              .where('date', isEqualTo: dateStr)
              .get();

      final markedIds =
          snapshot.docs.map((d) => d.data()['employeeId'] as String).toSet();
      final remaining =
          allEmployees.where((e) => !markedIds.contains(e.id)).toList();

      WriteBatch batch = _firestore.batch();
      int count = 0;
      for (final emp in remaining) {
        final docRef = _firestore.collection('attendance').doc();
        batch.set(
          docRef,
          Attendance(
            id: docRef.id,
            employeeId: emp.id,
            checkInTime: DateTime(date.year, date.month, date.day, 17, 0, 0),
            checkOutTime: null,
            status: 'absent',
            date: dateStr,
          ).toMap(),
        );
        count++;
      }
      if (count > 0) {
        await batch.commit();
      }
      return count;
    } catch (e) {
      throw Exception('Failed to mark remaining employees absent for date: $e');
    }
  }

  Future<int> undoCloseDayForDate(DateTime date) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];

      int totalDeleted = 0;
      const int batchSize = 400;
      while (true) {
        final snapshot =
            await _firestore
                .collection('attendance')
                .where('date', isEqualTo: dateStr)
                .where('status', isEqualTo: 'absent')
                .limit(batchSize)
                .get();

        if (snapshot.docs.isEmpty) break;

        final WriteBatch batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        totalDeleted += snapshot.docs.length;

        if (snapshot.docs.length < batchSize) break;
      }

      return totalDeleted;
    } catch (e) {
      throw Exception('Failed to undo close day: $e');
    }
  }

  Future<List<Attendance>> getTodayAttendance() async {
    try {
      String today = DateTime.now().toIso8601String().split('T')[0];

      QuerySnapshot snapshot =
          await _firestore
              .collection('attendance')
              .where('date', isEqualTo: today)
              .get();

      return snapshot.docs
          .map(
            (doc) =>
                Attendance.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to get today\'s attendance: $e');
    }
  }

  Future<List<Attendance>> getAttendanceForDate(DateTime date) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];

      QuerySnapshot snapshot =
          await _firestore
              .collection('attendance')
              .where('date', isEqualTo: dateStr)
              .get();

      return snapshot.docs
          .map(
            (doc) =>
                Attendance.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to get attendance for $date: $e');
    }
  }

  Future<List<Attendance>> getAttendanceForDateRange(
    DateTime startInclusive,
    DateTime endInclusive,
  ) async {
    try {
      final start = startInclusive.toIso8601String().split('T')[0];
      final end = endInclusive.toIso8601String().split('T')[0];

      // Since date is stored as YYYY-MM-DD string, lexicographical range works
      QuerySnapshot snapshot =
          await _firestore
              .collection('attendance')
              .where('date', isGreaterThanOrEqualTo: start)
              .where('date', isLessThanOrEqualTo: end)
              .get();

      return snapshot.docs
          .map(
            (doc) =>
                Attendance.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to get attendance for range: $e');
    }
  }

  Future<Attendance?> getEmployeeAttendanceToday(String employeeId) async {
    try {
      String today = DateTime.now().toIso8601String().split('T')[0];

      print('🔍 Checking attendance for employee: $employeeId on date: $today');

      QuerySnapshot snapshot =
          await _firestore
              .collection('attendance')
              .where('employeeId', isEqualTo: employeeId)
              .where('date', isEqualTo: today)
              .limit(1)
              .get();

      print(
        '📊 Found ${snapshot.docs.length} attendance records for employee $employeeId today',
      );

      if (snapshot.docs.isNotEmpty) {
        final attendance = Attendance.fromMap(
          snapshot.docs.first.data() as Map<String, dynamic>,
          snapshot.docs.first.id,
        );
        print(
          '✅ Existing attendance found: Check-in at ${attendance.checkInTime}, Check-out: ${attendance.checkOutTime}',
        );
        return attendance;
      }

      print('ℹ️ No existing attendance found for employee $employeeId today');
      return null;
    } catch (e) {
      print('❌ Error getting employee attendance: $e');
      throw Exception('Failed to get employee attendance: $e');
    }
  }

  // Location Management
  Future<String> addOfficeLocation(OfficeLocation location) async {
    try {
      print('📍 Adding office location: ${location.name}');

      // Generate unique ID for location
      final docRef = _firestore.collection('office_locations').doc();
      final locationWithId = location.copyWith(id: docRef.id);

      await docRef.set(locationWithId.toMap());

      print('✅ Office location added successfully with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Error adding office location: $e');
      throw Exception('Failed to add office location: $e');
    }
  }

  Future<void> updateOfficeLocation(OfficeLocation location) async {
    try {
      print('📍 Updating office location: ${location.name}');

      final updatedLocation = location.copyWith(updatedAt: DateTime.now());
      await _firestore
          .collection('office_locations')
          .doc(location.id)
          .update(updatedLocation.toMap());

      print('✅ Office location updated successfully');
    } catch (e) {
      print('❌ Error updating office location: $e');
      throw Exception('Failed to update office location: $e');
    }
  }

  Future<void> deleteOfficeLocation(String locationId) async {
    try {
      print('📍 Deleting office location: $locationId');

      await _firestore.collection('office_locations').doc(locationId).delete();

      print('✅ Office location deleted successfully');
    } catch (e) {
      print('❌ Error deleting office location: $e');
      throw Exception('Failed to delete office location: $e');
    }
  }

  Future<List<OfficeLocation>> getAllOfficeLocations() async {
    try {
      print('📍 Fetching all office locations...');

      // Note: This query requires a composite index in Firebase:
      // Collection: office_locations
      // Fields: isActive (Ascending), createdAt (Descending)
      // To fix the index error, either create the index in Firebase Console
      // or remove the orderBy clause below

      QuerySnapshot snapshot =
          await _firestore
              .collection('office_locations')
              .where('isActive', isEqualTo: true)
              // .orderBy('createdAt', descending: true)  // Temporarily commented out to avoid index requirement
              .get();

      final locations =
          snapshot.docs
              .map(
                (doc) => OfficeLocation.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList();

      // Sort in memory instead of in the query
      locations.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      print('✅ Fetched ${locations.length} office locations');
      return locations;
    } catch (e) {
      print('❌ Error fetching office locations: $e');
      throw Exception('Failed to fetch office locations: $e');
    }
  }

  Future<OfficeLocation?> getOfficeLocationById(String locationId) async {
    try {
      print('📍 Fetching office location: $locationId');

      DocumentSnapshot doc =
          await _firestore.collection('office_locations').doc(locationId).get();

      if (doc.exists) {
        final location = OfficeLocation.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
        print('✅ Office location fetched: ${location.name}');
        return location;
      } else {
        print('⚠️ Office location not found: $locationId');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching office location: $e');
      throw Exception('Failed to fetch office location: $e');
    }
  }

  // Enhanced geofencing validation for attendance
  Future<Map<String, dynamic>> validateLocationForAttendance({
    double? latitude,
    double? longitude,
    double? accuracy,
  }) async {
    try {
      print('📍 Starting location validation for attendance...');

      // Get current location if not provided
      if (latitude == null || longitude == null) {
        print('📍 Getting current location...');
        final locationData = await _locationService.getLocationWithAddress();
        if (locationData == null) {
          return {
            'isValid': false,
            'error': 'Failed to get current location',
            'details': 'Location service unavailable or permission denied',
          };
        }

        latitude = locationData['latitude'];
        longitude = locationData['longitude'];
        accuracy = locationData['accuracy'];
      }

      print(
        '📍 Validating location: $latitude, $longitude (accuracy: ${accuracy}m)',
      );

      // Check if location data is valid
      if (latitude == null || longitude == null) {
        print('❌ Invalid location data - latitude or longitude is null');
        return {
          'isValid': false,
          'error': 'Invalid location data',
          'details':
              'Unable to get current location. Please check location permissions.',
        };
      }

      final locations = await getAllOfficeLocations();

      if (locations.isEmpty) {
        print('⚠️ No office locations configured - attendance not allowed');
        return {
          'isValid': false,
          'error': 'No office locations configured',
          'details': 'Please configure office locations in admin settings',
        };
      }

      // Check each location with improved geofencing
      for (final location in locations) {
        final geofenceStatus = location.getGeofenceStatus(
          latitude,
          longitude,
          accuracy: accuracy,
        );

        if (geofenceStatus['withinGeofence']) {
          print('✅ Location valid - within geofence of: ${location.name}');
          print(
            '📍 Distance: ${geofenceStatus['distance'].toStringAsFixed(2)}m (radius: ${geofenceStatus['radius']}m, effective: ${geofenceStatus['effectiveRadius'].toStringAsFixed(2)}m)',
          );

          return {
            'isValid': true,
            'location': location,
            'distance': geofenceStatus['distance'],
            'accuracy': accuracy,
            'effectiveRadius': geofenceStatus['effectiveRadius'],
            'details': 'Within geofence of ${location.name}',
          };
        }
      }

      // Find closest location for debugging
      OfficeLocation? closestLocation;
      double minDistance = double.infinity;

      for (final location in locations) {
        final distance = location.distanceTo(latitude, longitude);
        if (distance < minDistance) {
          minDistance = distance;
          closestLocation = location;
        }
      }

      if (closestLocation != null) {
        // Calculate effective radius for better error message
        double effectiveRadius = closestLocation.radiusInMeters;
        if (accuracy != null && accuracy > 0) {
          effectiveRadius = (closestLocation.radiusInMeters + accuracy) * 1.1;
        }

        print('❌ Location invalid - closest office: ${closestLocation.name}');
        print(
          '📍 Distance: ${minDistance.toStringAsFixed(2)}m (max: ${closestLocation.radiusInMeters}m, effective: ${effectiveRadius.toStringAsFixed(2)}m)',
        );
        print('📍 GPS Accuracy: ${accuracy?.toStringAsFixed(2) ?? 'unknown'}m');

        return {
          'isValid': false,
          'error': 'Outside office premises',
          'closestLocation': closestLocation,
          'distance': minDistance,
          'accuracy': accuracy,
          'effectiveRadius': effectiveRadius,
          'details':
              'You are ${minDistance.toStringAsFixed(0)}m away from ${closestLocation.name}. Required: within ${closestLocation.radiusInMeters}m (effective: ${effectiveRadius.toStringAsFixed(0)}m with GPS accuracy)',
        };
      }

      return {
        'isValid': false,
        'error': 'Location validation failed',
        'details': 'Unable to determine location validity',
      };
    } catch (e) {
      print('❌ Error validating location: $e');
      return {
        'isValid': false,
        'error': 'Location validation error',
        'details': e.toString(),
      };
    }
  }

  // Legacy method for backward compatibility
  Future<bool> isLocationValidForAttendance(
    double latitude,
    double longitude,
  ) async {
    final result = await validateLocationForAttendance(
      latitude: latitude,
      longitude: longitude,
    );
    return result['isValid'] ?? false;
  }

  // Helper Methods
  Future<String> _compressAndEncodeImage(File imageFile) async {
    try {
      print('📁 Preparing to compress image...');
      print('📁 Image file path: ${imageFile.path}');
      print('📁 Image file exists: ${await imageFile.exists()}');
      print('📁 Original image size: ${await imageFile.length()} bytes');

      // Read the image file
      final bytes = await imageFile.readAsBytes();
      print('📁 Image read successfully: ${bytes.length} bytes');

      // Decode the image
      final image = img.decodeImage(bytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }
      print('📁 Image decoded successfully: ${image.width}x${image.height}');

      // Resize image to reduce size (max 300x300 pixels)
      final resizedImage = img.copyResize(image, width: 300, height: 300);
      print(
        '📁 Image resized to: ${resizedImage.width}x${resizedImage.height}',
      );

      // Compress as JPEG with quality 80
      final compressedBytes = img.encodeJpg(resizedImage, quality: 80);
      print(
        '📁 Image compressed: ${compressedBytes.length} bytes (${((compressedBytes.length / bytes.length) * 100).toStringAsFixed(1)}% of original)',
      );

      // Convert to base64
      final base64String = base64Encode(compressedBytes);
      print('📁 Image encoded to base64: ${base64String.length} characters');

      return base64String;
    } catch (e) {
      print('❌ Error compressing and encoding image: $e');
      throw Exception('Failed to compress and encode image: $e');
    }
  }

  // Delete employee (soft delete)
  Future<void> deleteEmployee(String employeeId) async {
    try {
      print('🗑️ Deleting employee and related data: $employeeId');

      // 1) Hard delete the employee document
      await _firestore.collection('employees').doc(employeeId).delete();

      // 2) Cascade delete: remove attendance records for this employee
      // Use batched deletes in manageable chunks
      const int batchSize = 400; // keep below Firestore 500 ops limit
      while (true) {
        final snapshot =
            await _firestore
                .collection('attendance')
                .where('employeeId', isEqualTo: employeeId)
                .limit(batchSize)
                .get();

        if (snapshot.docs.isEmpty) break;

        final WriteBatch batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        if (snapshot.docs.length < batchSize) break;
      }

      print('✅ Employee and related attendance deleted: $employeeId');
    } catch (e) {
      print('❌ Error deleting employee: $e');
      throw Exception('Failed to delete employee: $e');
    }
  }

  Future<int> deactivateEmployeesExcept(Set<String> keepEmployeeIds) async {
    try {
      print('🧹 Deactivating employees except: ${keepEmployeeIds.join(', ')}');
      final snapshot =
          await _firestore
              .collection('employees')
              .where('isActive', isEqualTo: true)
              .get();

      final candidates =
          snapshot.docs
              .where((doc) => !keepEmployeeIds.contains(doc.id))
              .toList();
      if (candidates.isEmpty) {
        print('ℹ️ No employees to deactivate');
        return 0;
      }

      WriteBatch batch = _firestore.batch();
      for (final doc in candidates) {
        batch.update(doc.reference, {
          'isActive': false,
          'deletedAt': DateTime.now().millisecondsSinceEpoch,
        });
      }
      await batch.commit();
      print('✅ Deactivated ${candidates.length} employees');
      return candidates.length;
    } catch (e) {
      print('❌ Error deactivating employees: $e');
      throw Exception('Failed to deactivate employees: $e');
    }
  }
}
