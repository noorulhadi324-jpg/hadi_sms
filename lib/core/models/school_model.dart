class SchoolModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String? logoUrl;
  final String? principalId;
  final bool isActive;
  final DateTime? createdAt;

  const SchoolModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    this.logoUrl,
    this.principalId,
    this.isActive = true,
    this.createdAt,
  });

  factory SchoolModel.fromMap(Map<String, dynamic> map) => SchoolModel(
        id: map['id'] as String,
        name: map['name'] as String? ?? '',
        email: map['email'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        address: map['address'] as String? ?? '',
        logoUrl: map['logo_url'] as String?,
        principalId: map['principal_id'] as String?,
        isActive: map['is_active'] as bool? ?? true,
        createdAt: map['created_at'] != null
            ? DateTime.tryParse(map['created_at'].toString())
            : null,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'logo_url': logoUrl,
        'principal_id': principalId,
        'is_active': isActive,
        'created_at': createdAt?.toIso8601String(),
      };
}
