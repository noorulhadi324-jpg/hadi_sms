class ExamModel {
  final String id;
  final String name;
  final String type;
  final DateTime startDate;
  final DateTime endDate;

  ExamModel({
    required this.id,
    required this.name,
    required this.type,
    required this.startDate,
    required this.endDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    };
  }

  factory ExamModel.fromMap(Map<String, dynamic> map) {
    return ExamModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? '',
      startDate: map['startDate'] != null ? DateTime.parse(map['startDate']) : DateTime.now(),
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : DateTime.now(),
    );
  }
}
