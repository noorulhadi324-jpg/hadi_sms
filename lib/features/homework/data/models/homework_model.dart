class HomeworkModel {
  final String id;
  final String teacherId;
  final String subjectId;
  final String title;
  final String description;
  final DateTime assignedDate;
  final DateTime dueDate;

  HomeworkModel({
    required this.id,
    required this.teacherId,
    required this.subjectId,
    required this.title,
    required this.description,
    required this.assignedDate,
    required this.dueDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teacherId': teacherId,
      'subjectId': subjectId,
      'title': title,
      'description': description,
      'assignedDate': assignedDate.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
    };
  }

  factory HomeworkModel.fromMap(Map<String, dynamic> map) {
    return HomeworkModel(
      id: map['id'] ?? '',
      teacherId: map['teacherId'] ?? '',
      subjectId: map['subjectId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      assignedDate: map['assignedDate'] != null ? DateTime.parse(map['assignedDate']) : DateTime.now(),
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : DateTime.now(),
    );
  }
}
