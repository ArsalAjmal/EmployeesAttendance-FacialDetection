class Attendance {
  final String id;
  final String employeeId;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final String status; // present, absent, late
  final String date;

  Attendance({
    required this.id,
    required this.employeeId,
    required this.checkInTime,
    this.checkOutTime,
    required this.status,
    required this.date,
  });

  factory Attendance.fromMap(Map<String, dynamic> map, String id) {
    return Attendance(
      id: id,
      employeeId: map['employeeId'] ?? '',
      checkInTime: DateTime.fromMillisecondsSinceEpoch(map['checkInTime']),
      checkOutTime: map['checkOutTime'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['checkOutTime'])
          : null,
      status: map['status'] ?? '',
      date: map['date'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'checkInTime': checkInTime.millisecondsSinceEpoch,
      'checkOutTime': checkOutTime?.millisecondsSinceEpoch,
      'status': status,
      'date': date,
    };
  }
}