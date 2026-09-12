class StudentAdmissionModel {
  final String id;
  final String studentId;
  final DateTime admissionDate;
  final String? previousSchool;
  final String? remarks;
  final double? admissionFee;

  const StudentAdmissionModel({
    required this.id,
    required this.studentId,
    required this.admissionDate,
    this.previousSchool,
    this.remarks,
    this.admissionFee,
  });

  factory StudentAdmissionModel.fromMap(Map<String, dynamic> map) => StudentAdmissionModel(
        id: map['id'] as String,
        studentId: map['student_id'] as String,
        admissionDate: DateTime.parse(map['admission_date'].toString()),
        previousSchool: map['previous_school'] as String?,
        remarks: map['remarks'] as String?,
        admissionFee: map['admission_fee'] != null ? (map['admission_fee'] as num).toDouble() : null,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'admission_date': admissionDate.toIso8601String(),
        'previous_school': previousSchool,
        'remarks': remarks,
        'admission_fee': admissionFee,
      };
}
