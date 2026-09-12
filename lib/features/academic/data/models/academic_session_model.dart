class AcademicSessionModel {
  final String id;
  final int schoolId;
  final String sessionName; // e.g., 2024-2025
  final DateTime startDate;
  final DateTime endDate;
  final bool isCurrent;

  const AcademicSessionModel({
    required this.id,
    required this.schoolId,
    required this.sessionName,
    required this.startDate,
    required this.endDate,
    this.isCurrent = false,
  });

  factory AcademicSessionModel.fromMap(Map<String, dynamic> map) => AcademicSessionModel(
        id: map['id'] as String,
        schoolId: map['school_id'] as int,
        sessionName: map['session_name'] as String,
        startDate: DateTime.parse(map['start_date'].toString()),
        endDate: DateTime.parse(map['end_date'].toString()),
        isCurrent: map['is_current'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'session_name': sessionName,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'is_current': isCurrent,
      };
}
