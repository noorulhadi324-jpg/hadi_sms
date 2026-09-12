class ExamScheduleModel {
  final String id;
  final String examId;
  final String subjectId;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String roomNumber;

  ExamScheduleModel({
    required this.id,
    required this.examId,
    required this.subjectId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.roomNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'examId': examId,
      'subjectId': subjectId,
      'date': date.toIso8601String(),
      'startTime': startTime,
      'endTime': endTime,
      'roomNumber': roomNumber,
    };
  }

  factory ExamScheduleModel.fromMap(Map<String, dynamic> map) {
    return ExamScheduleModel(
      id: map['id'] ?? '',
      examId: map['examId'] ?? '',
      subjectId: map['subjectId'] ?? '',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      startTime: map['startTime'] ?? '',
      endTime: map['endTime'] ?? '',
      roomNumber: map['roomNumber'] ?? '',
    );
  }
}
