class ProfileModel {
  final String id;
  final String name;
  final String? schoolId;

  const ProfileModel({
    required this.id,
    required this.name,
    this.schoolId,
  });

  factory ProfileModel.fromMap(Map<String, dynamic> map) => ProfileModel(
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
