class LeaveRequestModel {
  final int id;
  final int schoolId;
  final String userId;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String status;
  final String? approvedBy;
  final DateTime? approvedAt;

  const LeaveRequestModel({
    required this.id,
    required this.schoolId,
    required this.userId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    this.approvedBy,
    this.approvedAt,
  });

  factory LeaveRequestModel.fromMap(Map<String, dynamic> map) => LeaveRequestModel(
    id: (map['id'] as num).toInt(),
    schoolId: (map['school_id'] as num).toInt(),
    userId: map['user_id'].toString(),
    leaveType: map['leave_type'].toString(),
    startDate: DateTime.parse(map['start_date'].toString()),
    endDate: DateTime.parse(map['end_date'].toString()),
    reason: map['reason'].toString(),
    status: map['status'].toString(),
    approvedBy: map['approved_by']?.toString(),
    approvedAt: map['approved_at'] == null ? null : DateTime.tryParse(map['approved_at'].toString()),
  );
}