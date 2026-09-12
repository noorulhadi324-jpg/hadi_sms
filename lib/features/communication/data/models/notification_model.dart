class NotificationModel {
  final int id;
  final int schoolId;
  final String title;
  final String description;
  final String category;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isRead;
  final DateTime startsAt;
  final DateTime? expiresAt;
  final String? createdBy;
  final String? message;
  final String type;

  const NotificationModel({
    required this.id,
    required this.schoolId,
    required this.title,
    required this.description,
    required this.category,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.isRead,
    required this.startsAt,
    required this.expiresAt,
    required this.createdBy,
    required this.message,
    required this.type,
  });

  String get displayBody => (message?.trim().isNotEmpty == true)
      ? message!.trim()
      : description.trim();

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic value, DateTime fallback) {
      return DateTime.tryParse(value?.toString() ?? '') ?? fallback;
    }

    return NotificationModel(
      id: int.tryParse(map['id']?.toString() ?? '') ?? 0,
      schoolId: int.tryParse(map['school_id']?.toString() ?? '') ?? 0,
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      category: map['category']?.toString() ?? 'general',
      isActive: map['is_active'] == true,
      createdAt: parseDate(map['created_at'], DateTime.now()),
      updatedAt: parseDate(map['updated_at'], DateTime.now()),
      isRead: map['is_read'] == true,
      startsAt: parseDate(map['starts_at'], DateTime.now()),
      expiresAt: map['expires_at'] == null
          ? null
          : DateTime.tryParse(map['expires_at'].toString()),
      createdBy: map['created_by']?.toString(),
      message: map['message']?.toString(),
      type: map['type']?.toString() ?? 'general',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'school_id': schoolId,
      'title': title,
      'description': description,
      'category': category,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_read': isRead,
      'starts_at': startsAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'created_by': createdBy,
      'message': message,
      'type': type,
    };
  }
}
