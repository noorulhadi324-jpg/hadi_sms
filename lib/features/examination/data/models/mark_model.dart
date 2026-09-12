class MarkModel {
  final String id;
  final String examId;
  final String studentId;
  final String subjectId;
  final double marksObtained;
  final double maxMarks;

  MarkModel({
    required this.id,
    required this.examId,
    required this.studentId,
    required this.subjectId,
    required this.marksObtained,
    required this.maxMarks,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'examId': examId,
      'studentId': studentId,
      'subjectId': subjectId,
      'marksObtained': marksObtained,
      'maxMarks': maxMarks,
    };
  }

  factory MarkModel.fromMap(Map<String, dynamic> map) {
    return MarkModel(
      id: map['id'] ?? '',
      examId: map['examId'] ?? '',
      studentId: map['studentId'] ?? '',
      subjectId: map['subjectId'] ?? '',
      marksObtained: (map['marksObtained'] ?? 0.0).toDouble(),
      maxMarks: (map['maxMarks'] ?? 0.0).toDouble(),
    );
  }
}
