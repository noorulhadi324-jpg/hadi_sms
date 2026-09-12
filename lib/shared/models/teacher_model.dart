class TeacherModel {
  final String id;
  final String name;
  final String? schoolId;

  const TeacherModel({
    required this.id,
    required this.name,
    this.schoolId,
  });

  factory TeacherModel.fromMap(Map<String, dynamic> map) => TeacherModel(
        id: map['id'].toString(),
        name: (map['name'] ?? map['full_name'] ?? '').toString(),
        schoolId: map['school_id']?.toString(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'school_id': schoolId,
      };
}
