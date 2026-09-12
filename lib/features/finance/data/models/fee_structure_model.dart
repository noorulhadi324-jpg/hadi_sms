class FeeStructureModel {
  final String id;
  final String feeCategoryId;
  final String className;
  final String academicYear;
  final double totalAmount;

  FeeStructureModel({
    required this.id,
    required this.feeCategoryId,
    required this.className,
    required this.academicYear,
    required this.totalAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'feeCategoryId': feeCategoryId,
      'className': className,
      'academicYear': academicYear,
      'totalAmount': totalAmount,
    };
  }

  factory FeeStructureModel.fromMap(Map<String, dynamic> map) {
    return FeeStructureModel(
      id: map['id'] ?? '',
      feeCategoryId: map['feeCategoryId'] ?? '',
      className: map['className'] ?? '',
      academicYear: map['academicYear'] ?? '',
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
    );
  }
}
