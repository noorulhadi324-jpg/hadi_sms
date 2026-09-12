class TeacherQualificationModel {
  final String id;
  final String teacherId;
  final String degree;
  final String institution;
  final int yearOfPassing;
  final double percentage;

  TeacherQualificationModel({
    required this.id,
    required this.teacherId,
    required this.degree,
    required this.institution,
    required this.yearOfPassing,
    required this.percentage,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teacherId': teacherId,
      'degree': degree,
      'institution': institution,
      'yearOfPassing': yearOfPassing,
      'percentage': percentage,
    };
  }

  factory TeacherQualificationModel.fromMap(Map<String, dynamic> map) {
    return TeacherQualificationModel(
      id: map['id'] ?? '',
      teacherId: map['teacherId'] ?? '',
      degree: map['degree'] ?? '',
      institution: map['institution'] ?? '',
      yearOfPassing: map['yearOfPassing'] ?? 0,
      percentage: (map['percentage'] ?? 0.0).toDouble(),
    );
  }
}
