class UserModel {
  final String id;
  final int? schoolId;
  final String fullName;
  final String email;
  final String? phone;
  final String role; // principal, teacher, parent, staff
  final String? avatarUrl;
  final bool isActive;
  final DateTime? createdAt;

  const UserModel({
    required this.id,
    this.schoolId,
    required this.fullName,
    required this.email,
    this.phone,
    required this.role,
    this.avatarUrl,
    this.isActive = true,
    this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        id: map['id'] as String,
        schoolId: map['school_id'] as int?,
        fullName: map['full_name'] as String? ?? '',
        email: map['email'] as String? ?? '',
        phone: map['phone'] as String?,
        role: map['role'] as String? ?? 'staff',
        avatarUrl: map['avatar_url'] as String?,
        isActive: map['is_active'] as bool? ?? true,
        createdAt: map['created_at'] != null
            ? DateTime.tryParse(map['created_at'].toString())
            : null,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'role': role,
        'avatar_url': avatarUrl,
        'is_active': isActive,
        'created_at': createdAt?.toIso8601String(),
      };
}
