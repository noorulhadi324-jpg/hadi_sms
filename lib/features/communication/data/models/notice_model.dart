class NoticeModel {
  final String id;
  final String title;
  final String content;
  final DateTime publishedDate;
  final String publishedBy;
  final List<String> targetAudience;

  NoticeModel({
    required this.id,
    required this.title,
    required this.content,
    required this.publishedDate,
    required this.publishedBy,
    required this.targetAudience,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'publishedDate': publishedDate.toIso8601String(),
      'publishedBy': publishedBy,
      'targetAudience': targetAudience,
    };
  }

  factory NoticeModel.fromMap(Map<String, dynamic> map) {
    return NoticeModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      publishedDate: map['publishedDate'] != null ? DateTime.parse(map['publishedDate']) : DateTime.now(),
      publishedBy: map['publishedBy'] ?? '',
      targetAudience: List<String>.from(map['targetAudience'] ?? []),
    );
  }
}
