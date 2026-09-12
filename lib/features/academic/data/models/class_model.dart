class ClassModel {
  final String id;
  final int schoolId;
  final String className; // e.g., Class 1, Grade 10
  final int? numericLevel;

  const ClassModel({
    required this.id,
    required this.schoolId,
    required this.className,
    this.numericLevel,
  });

  factory ClassModel.fromMap(Map<String, dynamic> map) => ClassModel(
        id: map['id'] as String,
        schoolId: map['school_id'] as int,
        className: map['class_name'] as String,
        numericLevel: map['numeric_level'] as int?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'class_name': className,
        'numeric_level': numericLevel,
      };
}
