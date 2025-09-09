class AppConstants {
  // Firebase Collections
  static const String employeesCollection = 'employees';
  static const String attendanceCollection = 'attendance';

  // Face Recognition thresholds
  // Balanced thresholds for reliable recognition
  static const double faceMatchThreshold = 0.70; // For attendance matching
  // Require the best score to exceed second-best by this margin
  static const double faceSecondBestMinGap = 0.03; // Very small gap required
  static const double duplicateDetectionThreshold =
      0.40; // Very permissive threshold to allow multiple registrations
  static const int maxFaceEmbeddingSize = 128;

  // Attendance Status
  static const String statusPresent = 'present';
  static const String statusLate = 'late';
  static const String statusAbsent = 'absent';

  // Time Settings
  static const int lateThresholdHour = 9;
  static const int absentThresholdHour = 10;

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double cardBorderRadius = 10.0;

  // Admin Security
  static const String adminCloseDayPin = '1234';
  static const String adminEmail = 'admin@office.com';
  static const String adminPassword = 'admin123';

  // Error Messages
  static const String cameraNotAvailable = 'Camera not available';
  static const String faceNotDetected = 'Face not detected';
  static const String employeeNotFound = 'Employee not found';
  static const String attendanceAlreadyMarked =
      'Attendance already marked for today';
}
