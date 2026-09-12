class ParentStudentLinkModel {
  final String id;
  final String parentId;
  final String studentId;
  final String relationship;

  ParentStudentLinkModel({
    required this.id,
    required this.parentId,
    required this.studentId,
    required this.relationship,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'parentId': parentId,
      'studentId': studentId,
      'relationship': relationship,
    };
  }

  factory ParentStudentLinkModel.fromMap(Map<String, dynamic> map) {
    return ParentStudentLinkModel(
      id: map['id'] ?? '',
      parentId: map['parentId'] ?? '',
      studentId: map['studentId'] ?? '',
      relationship: map['relationship'] ?? '',
    );
  }
}
