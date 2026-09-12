class ParentProfileModel {
  final String id;
  final String parentId;
  final String? photoUrl;
  final String? bio;
  final DateTime lastUpdated;

  ParentProfileModel({
    required this.id,
    required this.parentId,
    this.photoUrl,
    this.bio,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'parentId': parentId,
      'photoUrl': photoUrl,
      'bio': bio,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory ParentProfileModel.fromMap(Map<String, dynamic> map) {
    return ParentProfileModel(
      id: map['id'] ?? '',
      parentId: map['parentId'] ?? '',
      photoUrl: map['photoUrl'],
      bio: map['bio'],
      lastUpdated: map['lastUpdated'] != null ? DateTime.parse(map['lastUpdated']) : DateTime.now(),
    );
  }
}
