class AttendanceSummaryModel {
  final String id;
  final String studentId;
  final int month;
  final int year;
  final int totalClasses;
  final int presentCount;
  final int absentCount;
  final int leaveCount;

  AttendanceSummaryModel({
    required this.id,
    required this.studentId,
    required this.month,
    required this.year,
    required this.totalClasses,
    required this.presentCount,
    required this.absentCount,
    required this.leaveCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'month': month,
      'year': year,
      'totalClasses': totalClasses,
      'presentCount': presentCount,
      'absentCount': absentCount,
      'leaveCount': leaveCount,
    };
  }

  factory AttendanceSummaryModel.fromMap(Map<String, dynamic> map) {
    return AttendanceSummaryModel(
      id: map['id'] ?? '',
      studentId: map['studentId'] ?? '',
      month: map['month'] ?? 1,
      year: map['year'] ?? 2024,
      totalClasses: map['totalClasses'] ?? 0,
      presentCount: map['presentCount'] ?? 0,
      absentCount: map['absentCount'] ?? 0,
      leaveCount: map['leaveCount'] ?? 0,
    );
  }
}
