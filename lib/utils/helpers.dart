import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

class Helpers {
  // Date formatting
  static String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static String formatTime(DateTime time) {
    return DateFormat('HH:mm').format(time);
  }

  static String formatDateTime(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
  }

  // Get today's date string
  static String getTodayDate() {
    return formatDate(DateTime.now());
  }

  // Check if date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  // Get attendance status based on check-in time
  static String getAttendanceStatus(DateTime checkInTime) {
    final hour = checkInTime.hour;

    if (hour <= 9) {
      return 'present';
    } else if (hour <= 10) {
      return 'late';
    } else {
      return 'absent';
    }
  }

  // Validate employee name
  static bool isValidEmployeeName(String name) {
    return name.trim().length >= 2 &&
        name.trim().length <= 50 &&
        RegExp(r'^[a-zA-Z\s]+$').hasMatch(name.trim());
  }

  // Generate unique ID (simple implementation)
  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  // Calculate similarity percentage
  static double calculateSimilarityPercentage(double similarity) {
    return (similarity * 100).clamp(0.0, 100.0);
  }

  // Show success message
  static void showSuccessSnackBar(context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  // Show error message
  static void showErrorSnackBar(context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  // Show info message
  static void showInfoSnackBar(context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 3),
      ),
    );
  }
}
