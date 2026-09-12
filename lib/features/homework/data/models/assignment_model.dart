class AssignmentModel {
  final String id;
  final String teacherId;
  final String subjectId;
  final String title;
  final String description;
  final double maxMarks;
  final DateTime dueDate;
  final String? fileUrl;

  AssignmentModel({
    required this.id,
    required this.teacherId,
    required this.subjectId,
    required this.title,
    required this.description,
    required this.maxMarks,
    required this.dueDate,
    this.fileUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teacherId': teacherId,
      'subjectId': subjectId,
      'title': title,
      'description': description,
      'maxMarks': maxMarks,
      'dueDate': dueDate.toIso8601String(),
      'fileUrl': fileUrl,
    };
  }

  factory AssignmentModel.fromMap(Map<String, dynamic> map) {
    return AssignmentModel(
      id: map['id'] ?? '',
      teacherId: map['teacherId'] ?? '',
      subjectId: map['subjectId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      maxMarks: (map['maxMarks'] ?? 0.0).toDouble(),
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : DateTime.now(),
      fileUrl: map['fileUrl'],
    );
  }
}
