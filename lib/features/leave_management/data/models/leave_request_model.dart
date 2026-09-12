class LeaveRequestModel {
  final String id;
  final String userId;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String status;

  LeaveRequestModel({
    required this.id,
    required this.userId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'leaveType': leaveType,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'reason': reason,
      'status': status,
    };
  }

  factory LeaveRequestModel.fromMap(Map<String, dynamic> map) {
    return LeaveRequestModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      leaveType: map['leaveType'] ?? '',
      startDate: map['startDate'] != null ? DateTime.parse(map['startDate']) : DateTime.now(),
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : DateTime.now(),
      reason: map['reason'] ?? '',
      status: map['status'] ?? 'pending',
    );
  }
}
