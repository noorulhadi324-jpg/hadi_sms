class CommunicationThread {
  final int id;
  final int schoolId;
  final String? title;
  final String threadType;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;

  const CommunicationThread({
    required this.id,
    required this.schoolId,
    this.title,
    required this.threadType,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.isArchived,
  });

  factory CommunicationThread.fromMap(Map<String, dynamic> map) {
    return CommunicationThread(
      id: (map['id'] as num).toInt(),
      schoolId: (map['school_id'] as num).toInt(),
      title: map['title']?.toString(),
      threadType: map['thread_type']?.toString() ?? 'direct',
      createdBy: map['created_by'].toString(),
      createdAt: DateTime.parse(map['created_at'].toString()),
      updatedAt: DateTime.parse(map['updated_at'].toString()),
      isArchived: map['is_archived'] == true,
    );
  }
}
