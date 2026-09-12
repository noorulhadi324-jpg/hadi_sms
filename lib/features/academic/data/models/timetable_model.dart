class TimetableModel {
  final String id;
  final String sectionId;
  final String teacherId;
  final String subjectId;
  final String dayOfWeek; // Monday, Tuesday...
  final String startTime;
  final String endTime;
  final String? roomNumber;

  const TimetableModel({
    required this.id,
    required this.sectionId,
    required this.teacherId,
    required this.subjectId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.roomNumber,
  });

  factory TimetableModel.fromMap(Map<String, dynamic> map) => TimetableModel(
        id: map['id'] as String,
        sectionId: map['section_id'] as String,
        teacherId: map['teacher_id'] as String,
        subjectId: map['subject_id'] as String,
        dayOfWeek: map['day_of_week'] as String,
        startTime: map['start_time'] as String,
        endTime: map['end_time'] as String,
        roomNumber: map['room_number'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'section_id': sectionId,
        'teacher_id': teacherId,
        'subject_id': subjectId,
        'day_of_week': dayOfWeek,
        'start_time': startTime,
        'end_time': endTime,
        'room_number': roomNumber,
      };
}
