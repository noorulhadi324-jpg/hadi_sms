class LeaveApprovalModel {
  final String id;
  final String leaveRequestId;
  final String approvedById;
  final DateTime approvalDate;
  final String? comments;

  LeaveApprovalModel({
    required this.id,
    required this.leaveRequestId,
    required this.approvedById,
    required this.approvalDate,
    this.comments,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'leaveRequestId': leaveRequestId,
      'approvedById': approvedById,
      'approvalDate': approvalDate.toIso8601String(),
      'comments': comments,
    };
  }

  factory LeaveApprovalModel.fromMap(Map<String, dynamic> map) {
    return LeaveApprovalModel(
      id: map['id'] ?? '',
      leaveRequestId: map['leaveRequestId'] ?? '',
      approvedById: map['approvedById'] ?? '',
      approvalDate: map['approvalDate'] != null ? DateTime.parse(map['approvalDate']) : DateTime.now(),
      comments: map['comments'],
    );
  }
}
