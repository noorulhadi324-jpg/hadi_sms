class StudentGuardianModel {
  final String id;
  final String studentId;
  final String fullName;
  final String relationship; // Father, Mother, etc.
  final String? occupation;
  final String phone;
  final String? email;
  final String? address;
  final bool isPrimary;

  const StudentGuardianModel({
    required this.id,
    required this.studentId,
    required this.fullName,
    required this.relationship,
    this.occupation,
    required this.phone,
    this.email,
    this.address,
    this.isPrimary = false,
  });

  factory StudentGuardianModel.fromMap(Map<String, dynamic> map) => StudentGuardianModel(
        id: map['id'] as String,
        studentId: map['student_id'] as String,
        fullName: map['full_name'] as String,
        relationship: map['relationship'] as String? ?? 'Parent',
        occupation: map['occupation'] as String?,
        phone: map['phone'] as String? ?? '',
        email: map['email'] as String?,
        address: map['address'] as String?,
        isPrimary: map['is_primary'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'full_name': fullName,
        'relationship': relationship,
        'occupation': occupation,
        'phone': phone,
        'email': email,
        'address': address,
        'is_primary': isPrimary,
      };
}
