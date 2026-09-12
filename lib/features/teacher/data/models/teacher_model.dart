class TeacherModel {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final String department;
  final DateTime joinDate;
  final bool isActive;

  TeacherModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    required this.department,
    required this.joinDate,
    required this.isActive,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phoneNumber': phoneNumber,
      'department': department,
      'joinDate': joinDate.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory TeacherModel.fromMap(Map<String, dynamic> map) {
    return TeacherModel(
      id: map['id'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      department: map['department'] ?? '',
      joinDate: map['joinDate'] != null ? DateTime.parse(map['joinDate']) : DateTime.now(),
      isActive: map['isActive'] ?? false,
    );
  }
}
