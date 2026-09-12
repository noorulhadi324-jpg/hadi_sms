class ChatMessageModel {
  final String id;
  final String threadId;
  final String senderId;
  final String content;
  final DateTime timestamp;
  final bool isRead;

  ChatMessageModel({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.content,
    required this.timestamp,
    required this.isRead,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'threadId': threadId,
      'senderId': senderId,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
    };
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    return ChatMessageModel(
      id: map['id'] ?? '',
      threadId: map['threadId'] ?? '',
      senderId: map['senderId'] ?? '',
      content: map['content'] ?? '',
      timestamp: map['timestamp'] != null ? DateTime.parse(map['timestamp']) : DateTime.now(),
      isRead: map['isRead'] ?? false,
    );
  }
}
