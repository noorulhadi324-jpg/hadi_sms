class MessageThreadModel {
  final String id;
  final List<String> participantIds;
  final String lastMessage;
  final DateTime lastMessageTimestamp;

  MessageThreadModel({
    required this.id,
    required this.participantIds,
    required this.lastMessage,
    required this.lastMessageTimestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'participantIds': participantIds,
      'lastMessage': lastMessage,
      'lastMessageTimestamp': lastMessageTimestamp.toIso8601String(),
    };
  }

  factory MessageThreadModel.fromMap(Map<String, dynamic> map) {
    return MessageThreadModel(
      id: map['id'] ?? '',
      participantIds: List<String>.from(map['participantIds'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTimestamp: map['lastMessageTimestamp'] != null ? DateTime.parse(map['lastMessageTimestamp']) : DateTime.now(),
    );
  }
}
