class SubmissionModel {
  final String id;
  final String assignmentId;
  final String studentId;
  final DateTime submissionDate;
  final String content;
  final String? fileUrl;
  final double? marksObtained;
  final String? feedback;

  SubmissionModel({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    required this.submissionDate,
    required this.content,
    this.fileUrl,
    this.marksObtained,
    this.feedback,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'assignmentId': assignmentId,
      'studentId': studentId,
      'submissionDate': submissionDate.toIso8601String(),
      'content': content,
      'fileUrl': fileUrl,
      'marksObtained': marksObtained,
      'feedback': feedback,
    };
  }

  factory SubmissionModel.fromMap(Map<String, dynamic> map) {
    return SubmissionModel(
      id: map['id'] ?? '',
      assignmentId: map['assignmentId'] ?? '',
      studentId: map['studentId'] ?? '',
      submissionDate: map['submissionDate'] != null ? DateTime.parse(map['submissionDate']) : DateTime.now(),
      content: map['content'] ?? '',
      fileUrl: map['fileUrl'],
      marksObtained: map['marksObtained'] != null ? (map['marksObtained'] as num).toDouble() : null,
      feedback: map['feedback'],
    );
  }
}
