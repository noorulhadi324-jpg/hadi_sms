class StudentModel {
  final String id;
  final String name;
  final String? schoolId;

  const StudentModel({
    required this.id,
    required this.name,
    this.schoolId,
  });

  factory StudentModel.fromMap(Map<String, dynamic> map) => StudentModel(
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
