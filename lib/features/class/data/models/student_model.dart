class StudentModel {
  final String id;
  final int schoolId;
  final String admissionNumber;
  final String fullName;
  final String? className;
  final String? sectionName;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? bloodGroup;
  final String? studentPhotoUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudentModel({
    required this.id,
    required this.schoolId,
    required this.admissionNumber,
    required this.fullName,
    this.className,
    this.sectionName,
    this.dateOfBirth,
    this.gender,
    this.bloodGroup,
    this.studentPhotoUrl,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudentModel.fromMap(Map<String, dynamic> map) => StudentModel(
        id: map['id'] as String,
        schoolId: map['school_id'] as int,
        admissionNumber: map['admission_number'] as String,
        fullName: map['full_name'] as String,
        className: map['class_name'] as String?,
        sectionName: map['section_name'] as String?,
        dateOfBirth: map['date_of_birth'] != null ? DateTime.parse(map['date_of_birth'].toString()) : null,
        gender: map['gender'] as String?,
        bloodGroup: map['blood_group'] as String?,
        studentPhotoUrl: map['student_photo_url'] as String?,
        isActive: map['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(map['created_at'].toString()),
        updatedAt: DateTime.parse(map['updated_at'].toString()),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'admission_number': admissionNumber,
        'full_name': fullName,
        'class_name': className,
        'section_name': sectionName,
        'date_of_birth': dateOfBirth?.toIso8601String(),
        'gender': gender,
        'blood_group': bloodGroup,
        'student_photo_url': studentPhotoUrl,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
