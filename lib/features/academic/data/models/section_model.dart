class SectionModel {
  final String id;
  final String classId;
  final String sectionName; // e.g., A, B, Blue
  final String? roomNumber;

  const SectionModel({
    required this.id,
    required this.classId,
    required this.sectionName,
    this.roomNumber,
  });

  factory SectionModel.fromMap(Map<String, dynamic> map) => SectionModel(
        id: map['id'] as String,
        classId: map['class_id'] as String,
        sectionName: map['section_name'] as String,
        roomNumber: map['room_number'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'class_id': classId,
        'section_name': sectionName,
        'room_number': roomNumber,
      };
}
