class GradeModel {
  final String id;
  final String gradeName;
  final double minPercentage;
  final double maxPercentage;
  final double gradePoint;

  GradeModel({
    required this.id,
    required this.gradeName,
    required this.minPercentage,
    required this.maxPercentage,
    required this.gradePoint,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'gradeName': gradeName,
      'minPercentage': minPercentage,
      'maxPercentage': maxPercentage,
      'gradePoint': gradePoint,
    };
  }

  factory GradeModel.fromMap(Map<String, dynamic> map) {
    return GradeModel(
      id: map['id'] ?? '',
      gradeName: map['gradeName'] ?? '',
      minPercentage: (map['minPercentage'] ?? 0.0).toDouble(),
      maxPercentage: (map['maxPercentage'] ?? 0.0).toDouble(),
      gradePoint: (map['gradePoint'] ?? 0.0).toDouble(),
    );
  }
}
