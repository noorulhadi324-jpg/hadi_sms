class FeeCategoryModel {
  final String id;
  final String name;
  final String description;

  FeeCategoryModel({
    required this.id,
    required this.name,
    required this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
    };
  }

  factory FeeCategoryModel.fromMap(Map<String, dynamic> map) {
    return FeeCategoryModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
    );
  }
}
