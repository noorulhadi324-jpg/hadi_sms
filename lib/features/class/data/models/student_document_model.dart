class StudentDocumentModel {
  final String id;
  final String studentId;
  final String documentName; // Birth Certificate, Previous Marksheet, etc.
  final String documentUrl;
  final DateTime uploadedAt;

  const StudentDocumentModel({
    required this.id,
    required this.studentId,
    required this.documentName,
    required this.documentUrl,
    required this.uploadedAt,
  });

  factory StudentDocumentModel.fromMap(Map<String, dynamic> map) => StudentDocumentModel(
        id: map['id'] as String,
        studentId: map['student_id'] as String,
        documentName: map['document_name'] as String,
        documentUrl: map['document_url'] as String,
        uploadedAt: DateTime.parse(map['uploaded_at'].toString()),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'document_name': documentName,
        'document_url': documentUrl,
        'uploaded_at': uploadedAt.toIso8601String(),
      };
}
