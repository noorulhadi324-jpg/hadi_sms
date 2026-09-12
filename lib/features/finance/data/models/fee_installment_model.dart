class FeeInstallmentModel {
  final String id;
  final String feeStructureId;
  final String installmentName;
  final double amount;
  final DateTime dueDate;

  FeeInstallmentModel({
    required this.id,
    required this.feeStructureId,
    required this.installmentName,
    required this.amount,
    required this.dueDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'feeStructureId': feeStructureId,
      'installmentName': installmentName,
      'amount': amount,
      'dueDate': dueDate.toIso8601String(),
    };
  }

  factory FeeInstallmentModel.fromMap(Map<String, dynamic> map) {
    return FeeInstallmentModel(
      id: map['id'] ?? '',
      feeStructureId: map['feeStructureId'] ?? '',
      installmentName: map['installmentName'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : DateTime.now(),
    );
  }
}
