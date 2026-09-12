class TeacherSubjectModel {
  final String id;
  final String teacherId;
  final String subjectId;
  final String subjectName;
  final String className;

  TeacherSubjectModel({
    required this.id,
    required this.teacherId,
    required this.subjectId,
    required this.subjectName,
    required this.className,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teacherId': teacherId,
      'subjectId': subjectId,
      'subjectName': subjectName,
      'className': className,
    };
  }

  factory TeacherSubjectModel.fromMap(Map<String, dynamic> map) {
    return TeacherSubjectModel(
      id: map['id'] ?? '',
      teacherId: map['teacherId'] ?? '',
      subjectId: map['subjectId'] ?? '',
      subjectName: map['subjectName'] ?? '',
      className: map['className'] ?? '',
    );
  }
}
