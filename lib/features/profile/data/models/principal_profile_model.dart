class PrincipalProfileModel {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final String? bio;
  final String qualification;
  final int experienceYears;
  final DateTime lastUpdated;

  PrincipalProfileModel({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
    this.bio,
    required this.qualification,
    required this.experienceYears,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'bio': bio,
      'qualification': qualification,
      'experienceYears': experienceYears,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory PrincipalProfileModel.fromMap(Map<String, dynamic> map) {
    return PrincipalProfileModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'],
      bio: map['bio'],
      qualification: map['qualification'] ?? '',
      experienceYears: map['experienceYears'] ?? 0,
      lastUpdated: map['lastUpdated'] != null ? DateTime.parse(map['lastUpdated']) : DateTime.now(),
    );
  }
}
