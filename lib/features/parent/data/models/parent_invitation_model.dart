class ParentInvitationModel {
  final String id;
  final String parentEmail;
  final String studentId;
  final String inviteCode;
  final String status;
  final DateTime expiryDate;

  ParentInvitationModel({
    required this.id,
    required this.parentEmail,
    required this.studentId,
    required this.inviteCode,
    required this.status,
    required this.expiryDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'parentEmail': parentEmail,
      'studentId': studentId,
      'inviteCode': inviteCode,
      'status': status,
      'expiryDate': expiryDate.toIso8601String(),
    };
  }

  factory ParentInvitationModel.fromMap(Map<String, dynamic> map) {
    return ParentInvitationModel(
      id: map['id'] ?? '',
      parentEmail: map['parentEmail'] ?? '',
      studentId: map['studentId'] ?? '',
      inviteCode: map['inviteCode'] ?? '',
      status: map['status'] ?? 'pending',
      expiryDate: map['expiryDate'] != null ? DateTime.parse(map['expiryDate']) : DateTime.now(),
    );
  }
}
