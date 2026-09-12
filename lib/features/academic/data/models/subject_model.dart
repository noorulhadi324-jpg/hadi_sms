class SubjectModel {
  final String id;
  final int schoolId;
  final String subjectName; // e.g., Mathematics, English
  final String subjectCode;
  final String? subjectType; // Theory, Practical

  const SubjectModel({
    required this.id,
    required this.schoolId,
    required this.subjectName,
    required this.subjectCode,
    this.subjectType,
  });

  factory SubjectModel.fromMap(Map<String, dynamic> map) => SubjectModel(
        id: map['id'] as String,
        schoolId: map['school_id'] as int,
        subjectName: map['subject_name'] as String,
        subjectCode: map['subject_code'] as String,
        subjectType: map['subject_type'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'subject_name': subjectName,
        'subject_code': subjectCode,
        'subject_type': subjectType,
      };
}
