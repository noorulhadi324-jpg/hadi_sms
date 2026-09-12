class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final DateTime sentDate;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.sentDate,
    required this.isRead,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'body': body,
      'sentDate': sentDate.toIso8601String(),
      'isRead': isRead,
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      sentDate: map['sentDate'] != null ? DateTime.parse(map['sentDate']) : DateTime.now(),
      isRead: map['isRead'] ?? false,
    );
  }
}
