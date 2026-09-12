class ResultModel {
  final String id;
  final String examId;
  final String studentId;
  final double totalMarks;
  final double percentage;
  final String grade;
  final String status;

  ResultModel({
    required this.id,
    required this.examId,
    required this.studentId,
    required this.totalMarks,
    required this.percentage,
    required this.grade,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'examId': examId,
      'studentId': studentId,
      'totalMarks': totalMarks,
      'percentage': percentage,
      'grade': grade,
      'status': status,
    };
  }

  factory ResultModel.fromMap(Map<String, dynamic> map) {
    return ResultModel(
      id: map['id'] ?? '',
      examId: map['examId'] ?? '',
      studentId: map['studentId'] ?? '',
      totalMarks: (map['totalMarks'] ?? 0.0).toDouble(),
      percentage: (map['percentage'] ?? 0.0).toDouble(),
      grade: map['grade'] ?? '',
      status: map['status'] ?? '',
    );
  }
}
