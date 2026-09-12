class TeacherProfileModel {
  final String id;
  final String teacherId;
  final String? photoUrl;
  final String? bio;
  final List<String> specializations;
  final DateTime lastUpdated;

  TeacherProfileModel({
    required this.id,
    required this.teacherId,
    this.photoUrl,
    this.bio,
    required this.specializations,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teacherId': teacherId,
      'photoUrl': photoUrl,
      'bio': bio,
      'specializations': specializations,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory TeacherProfileModel.fromMap(Map<String, dynamic> map) {
    return TeacherProfileModel(
      id: map['id'] ?? '',
      teacherId: map['teacherId'] ?? '',
      photoUrl: map['photoUrl'],
      bio: map['bio'],
      specializations: List<String>.from(map['specializations'] ?? []),
      lastUpdated: map['lastUpdated'] != null ? DateTime.parse(map['lastUpdated']) : DateTime.now(),
    );
  }
}
