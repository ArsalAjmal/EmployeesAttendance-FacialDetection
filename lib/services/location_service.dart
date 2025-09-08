import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/material.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Cache for location data
  Position? _cachedPosition;
  DateTime? _lastLocationUpdate;
  static const Duration _cacheValidity = Duration(minutes: 5);

  // Location settings
  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10, // Update every 10 meters
  );

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      print('❌ Error checking location service status: $e');
      return false;
    }
  }

  /// Check location permissions
  Future<LocationPermission> checkLocationPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (e) {
      print('❌ Error checking location permission: $e');
      return LocationPermission.denied;
    }
  }

  /// Request location permissions with proper handling
  Future<LocationPermission> requestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationPermission.denied;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationPermission.deniedForever;
      }

      return permission;
    } catch (e) {
      print('❌ Error requesting location permission: $e');
      return LocationPermission.denied;
    }
  }

  /// Get current location with timeout and error handling
  Future<Position?> getCurrentLocation({
    Duration timeout = const Duration(seconds: 30),
    bool useCache = true,
  }) async {
    try {
      // Check if we can use cached location
      if (useCache && _cachedPosition != null && _lastLocationUpdate != null) {
        final timeSinceUpdate = DateTime.now().difference(_lastLocationUpdate!);
        if (timeSinceUpdate < _cacheValidity) {
          print('📍 Using cached location: ${_cachedPosition!.latitude}, ${_cachedPosition!.longitude}');
          return _cachedPosition;
        }
      }

      // Check location service
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('❌ Location services are disabled');
        return null;
      }

      // Check permissions
      LocationPermission permission = await checkLocationPermission();
      if (permission == LocationPermission.denied) {
        permission = await requestLocationPermission();
        if (permission == LocationPermission.denied) {
          print('❌ Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('❌ Location permission permanently denied');
        return null;
      }

      // Get current position with timeout
      print('📍 Getting current location...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: timeout,
      ).timeout(timeout);

      // Cache the position
      _cachedPosition = position;
      _lastLocationUpdate = DateTime.now();

      print('✅ Location obtained: ${position.latitude}, ${position.longitude}');
      print('📍 Accuracy: ${position.accuracy}m, Altitude: ${position.altitude}m');
      
      return position;
    } catch (e) {
      print('❌ Error getting current location: $e');
      return null;
    }
  }

  /// Get location with address information
  Future<Map<String, dynamic>?> getLocationWithAddress({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      final position = await getCurrentLocation(timeout: timeout);
      if (position == null) return null;

      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 10));

      String address = 'Unknown location';
      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        address = '${place.street ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}'.trim();
        if (address.endsWith(',')) {
          address = address.substring(0, address.length - 1);
        }
      }

      return {
        'position': position,
        'address': address,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': position.timestamp,
      };
    } catch (e) {
      print('❌ Error getting location with address: $e');
      return null;
    }
  }

  /// Calculate distance between two points using Haversine formula
  double calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Check if location is within specified radius
  bool isWithinRadius(
    double userLat, double userLon,
    double targetLat, double targetLon,
    double radiusInMeters,
  ) {
    final distance = calculateDistance(userLat, userLon, targetLat, targetLon);
    return distance <= radiusInMeters;
  }

  /// Get location permission status message
  String getPermissionStatusMessage(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.denied:
        return 'Location permission is denied. Please enable it in settings.';
      case LocationPermission.deniedForever:
        return 'Location permission is permanently denied. Please enable it in device settings.';
      case LocationPermission.whileInUse:
        return 'Location permission granted for app usage.';
      case LocationPermission.always:
        return 'Location permission granted for always.';
      case LocationPermission.unableToDetermine:
        return 'Unable to determine location permission status.';
    }
  }

  /// Show location permission dialog
  Future<bool> showLocationPermissionDialog(BuildContext context) async {
    final permission = await requestLocationPermission();
    
    if (permission == LocationPermission.deniedForever) {
      // Show dialog to open settings
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Location Permission Required'),
          content: Text(
            'Location permission is permanently denied. Please enable it in device settings to use attendance features.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
                Geolocator.openAppSettings();
              },
              child: Text('Open Settings'),
            ),
          ],
        ),
      );
      return result ?? false;
    }
    
    return permission == LocationPermission.whileInUse || 
           permission == LocationPermission.always;
  }

  /// Clear cached location data
  void clearCache() {
    _cachedPosition = null;
    _lastLocationUpdate = null;
    print('📍 Location cache cleared');
  }

  /// Get location accuracy description
  String getAccuracyDescription(double accuracy) {
    if (accuracy <= 5) return 'Excellent (≤5m)';
    if (accuracy <= 10) return 'Good (≤10m)';
    if (accuracy <= 20) return 'Fair (≤20m)';
    if (accuracy <= 50) return 'Poor (≤50m)';
    return 'Very Poor (>50m)';
  }

  /// Validate location accuracy for attendance
  bool isLocationAccurateForAttendance(Position position) {
    // Require accuracy better than 50 meters for attendance
    return position.accuracy <= 50;
  }

  /// Get location status summary
  Future<Map<String, dynamic>> getLocationStatus() async {
    try {
      final serviceEnabled = await isLocationServiceEnabled();
      final permission = await checkLocationPermission();
      final position = await getCurrentLocation(useCache: true);
      
      return {
        'serviceEnabled': serviceEnabled,
        'permission': permission,
        'permissionMessage': getPermissionStatusMessage(permission),
        'hasLocation': position != null,
        'position': position,
        'isAccurate': position != null ? isLocationAccurateForAttendance(position) : false,
        'accuracy': position?.accuracy,
        'accuracyDescription': position != null ? getAccuracyDescription(position.accuracy) : null,
      };
    } catch (e) {
      print('❌ Error getting location status: $e');
      return {
        'serviceEnabled': false,
        'permission': LocationPermission.denied,
        'permissionMessage': 'Error checking location status',
        'hasLocation': false,
        'position': null,
        'isAccurate': false,
        'accuracy': null,
        'accuracyDescription': null,
      };
    }
  }
}
