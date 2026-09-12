class InvitationModel {
  final String id;
  final int schoolId;
  final String createdBy;
  final String invitationType; // parent, teacher, staff
  final String codeHash;
  final String? targetStudentId;
  final DateTime expiresAt;
  final DateTime? usedAt;
  final DateTime createdAt;

  const InvitationModel({
    required this.id,
    required this.schoolId,
    required this.createdBy,
    required this.invitationType,
    required this.codeHash,
    this.targetStudentId,
    required this.expiresAt,
    this.usedAt,
    required this.createdAt,
  });

  factory InvitationModel.fromMap(Map<String, dynamic> map) => InvitationModel(
        id: map['id'] as String,
        schoolId: map['school_id'] as int,
        createdBy: map['created_by'] as String,
        invitationType: map['invitation_type'] as String,
        codeHash: map['code_hash'] as String,
        targetStudentId: map['target_student_id'] as String?,
        expiresAt: DateTime.parse(map['expires_at'].toString()),
        usedAt: map['used_at'] != null ? DateTime.parse(map['used_at'].toString()) : null,
        createdAt: DateTime.parse(map['created_at'].toString()),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'school_id': schoolId,
        'created_by': createdBy,
        'invitation_type': invitationType,
        'code_hash': codeHash,
        'target_student_id': targetStudentId,
        'expires_at': expiresAt.toIso8601String(),
        'used_at': usedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };
}
