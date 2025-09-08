import 'package:flutter/material.dart';
import '../models/employee.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

class EmployeeCard extends StatelessWidget {
  final Employee employee;
  final String attendanceStatus;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final VoidCallback? onDelete;
  final bool showDeleteButton;

  const EmployeeCard({
    Key? key,
    required this.employee,
    required this.attendanceStatus,
    this.checkInTime,
    this.checkOutTime,
    this.onDelete,
    this.showDeleteButton = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            // Employee Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: _getStatusColor(attendanceStatus),
              backgroundImage: _getEmployeeImage(),
              child:
                  _getEmployeeImage() == null
                      ? Text(
                        employee.name.isNotEmpty
                            ? employee.name[0].toUpperCase()
                            : 'E',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      )
                      : null,
            ),
            SizedBox(width: 16),
            // Employee Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Employee Name
                  Text(
                    employee.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4),
                  // Employee ID (shorter version)
                  Text(
                    'ID: ${_getShortId(employee.id)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  // Check-in and Check-out Times
                  if (checkInTime != null || checkOutTime != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (checkInTime != null)
                          Row(
                            children: [
                              Icon(Icons.login, size: 14, color: Colors.green),
                              SizedBox(width: 4),
                              Text(
                                'In: ${_formatTime(checkInTime!)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        if (checkInTime != null && checkOutTime != null)
                          SizedBox(height: 4),
                        if (checkOutTime != null)
                          Row(
                            children: [
                              Icon(
                                Icons.logout,
                                size: 14,
                                color: Colors.orange,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Out: ${_formatTime(checkOutTime!)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        if (checkInTime != null && checkOutTime == null)
                          Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 14,
                                  color: Colors.blue,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Still at office',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (checkInTime != null && checkOutTime != null)
                          Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.timer,
                                  size: 14,
                                  color: Colors.purple,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Work: ${_calculateWorkHours(checkInTime!, checkOutTime!)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.purple,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  if (checkInTime == null &&
                      attendanceStatus.toLowerCase() != 'pending')
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.black26,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'No time recorded',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black38,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            // Status Badge and Delete Button
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(attendanceStatus).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(attendanceStatus).withOpacity(0.6),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    _getStatusText(attendanceStatus),
                    style: TextStyle(
                      color: _getStatusColor(attendanceStatus),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (showDeleteButton && onDelete != null) ...[
                  SizedBox(width: 8),
                  IconButton(
                    onPressed: onDelete,
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade600,
                    ),
                    iconSize: 20,
                    padding: EdgeInsets.all(4),
                    constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Delete Employee',
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Colors.green;
      case 'late':
        return Colors.orange;
      case 'absent':
        return Colors.red;
      case 'pending':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    return status.toUpperCase();
  }

  String _getShortId(String fullId) {
    // Return the last 6 characters or the full ID if shorter
    if (fullId.length <= 6) return fullId;
    return fullId.substring(fullId.length - 6);
  }

  String _formatTime(DateTime time) {
    return DateFormat('HH:mm').format(time);
  }

  String _calculateWorkHours(DateTime checkIn, DateTime checkOut) {
    final duration = checkOut.difference(checkIn);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  ImageProvider? _getEmployeeImage() {
    if (employee.faceImageUrl.isNotEmpty &&
        employee.faceImageUrl.startsWith('data:image')) {
      // Handle data URL format
      return MemoryImage(base64Decode(employee.faceImageUrl.split(',')[1]));
    } else if (employee.faceImageUrl.isNotEmpty) {
      // Handle base64 string directly
      try {
        return MemoryImage(base64Decode(employee.faceImageUrl));
      } catch (e) {
        print('Error decoding base64 image: $e');
        return null;
      }
    }
    return null;
  }
}
