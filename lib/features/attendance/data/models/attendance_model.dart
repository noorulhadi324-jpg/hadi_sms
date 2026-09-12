class AttendanceModel {
  final String id;
  final String studentId;
  final DateTime date;
  final String status;
  final String? remarks;

  AttendanceModel({
    required this.id,
    required this.studentId,
    required this.date,
    required this.status,
    this.remarks,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'date': date.toIso8601String(),
      'status': status,
      'remarks': remarks,
    };
  }

  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    return AttendanceModel(
      id: map['id'] ?? '',
      studentId: map['studentId'] ?? '',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      status: map['status'] ?? 'absent',
      remarks: map['remarks'],
    );
  }
}
