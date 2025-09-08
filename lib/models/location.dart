import 'dart:math';

class OfficeLocation {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double radiusInMeters; // Geofence radius
  final String description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  OfficeLocation({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.radiusInMeters,
    this.description = '',
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'radiusInMeters': radiusInMeters,
      'description': description,
      'isActive': isActive,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  // Create from Firestore document
  factory OfficeLocation.fromMap(Map<String, dynamic> map, String id) {
    return OfficeLocation(
      id: id,
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      radiusInMeters: (map['radiusInMeters'] ?? 100.0).toDouble(),
      description: map['description'] ?? '',
      isActive: map['isActive'] ?? true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] ?? 0),
    );
  }

  // Copy with method for updates
  OfficeLocation copyWith({
    String? id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    double? radiusInMeters,
    String? description,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OfficeLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusInMeters: radiusInMeters ?? this.radiusInMeters,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Calculate distance between two points (Haversine formula)
  double distanceTo(double lat, double lng) {
    const double earthRadius = 6371000; // Earth's radius in meters
    
    double lat1Rad = latitude * (pi / 180);
    double lat2Rad = lat * (pi / 180);
    double deltaLat = (lat - latitude) * (pi / 180);
    double deltaLng = (lng - longitude) * (pi / 180);

    double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
                cos(lat1Rad) * cos(lat2Rad) *
                sin(deltaLng / 2) * sin(deltaLng / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  // Check if a point is within geofence with accuracy consideration
  bool isWithinGeofence(double lat, double lng, {double? accuracy}) {
    double distance = distanceTo(lat, lng);
    
    // If accuracy is provided, add it to the radius for more lenient checking
    double effectiveRadius = radiusInMeters;
    if (accuracy != null && accuracy > 0) {
      // Add the full accuracy to the radius to account for GPS uncertainty
      // This makes the geofencing more lenient for users with less accurate GPS
      effectiveRadius = radiusInMeters + accuracy;
    }
    
    // Add a 10% buffer to the radius for better user experience
    effectiveRadius = effectiveRadius * 1.1;
    
    return distance <= effectiveRadius;
  }

  // Check if a point is within geofence with strict accuracy requirements
  bool isWithinGeofenceStrict(double lat, double lng, {double? accuracy}) {
    double distance = distanceTo(lat, lng);
    
    // For strict checking, subtract accuracy from radius
    double effectiveRadius = radiusInMeters;
    if (accuracy != null && accuracy > 0) {
      effectiveRadius = (radiusInMeters - accuracy).clamp(0, radiusInMeters);
    }
    
    return distance <= effectiveRadius;
  }

  // Get geofence status with detailed information
  Map<String, dynamic> getGeofenceStatus(double lat, double lng, {double? accuracy}) {
    double distance = distanceTo(lat, lng);
    bool withinGeofence = isWithinGeofence(lat, lng, accuracy: accuracy);
    bool withinStrict = isWithinGeofenceStrict(lat, lng, accuracy: accuracy);
    
    // Calculate effective radius with the new logic
    double effectiveRadius = radiusInMeters;
    if (accuracy != null && accuracy > 0) {
      effectiveRadius = radiusInMeters + accuracy;
    }
    effectiveRadius = effectiveRadius * 1.1; // 10% buffer
    
    return {
      'distance': distance,
      'radius': radiusInMeters,
      'withinGeofence': withinGeofence,
      'withinStrict': withinStrict,
      'accuracy': accuracy,
      'effectiveRadius': effectiveRadius,
      'strictRadius': accuracy != null ? (radiusInMeters - accuracy).clamp(0, radiusInMeters) : radiusInMeters,
    };
  }

  @override
  String toString() {
    return 'OfficeLocation(id: $id, name: $name, address: $address, lat: $latitude, lng: $longitude, radius: ${radiusInMeters}m)';
  }
}
