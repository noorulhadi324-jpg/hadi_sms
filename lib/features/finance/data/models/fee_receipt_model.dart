class FeeReceiptModel {
  final String id;
  final String paymentId;
  final String receiptNumber;
  final DateTime generatedDate;
  final String studentName;
  final double amount;

  FeeReceiptModel({
    required this.id,
    required this.paymentId,
    required this.receiptNumber,
    required this.generatedDate,
    required this.studentName,
    required this.amount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'paymentId': paymentId,
      'receiptNumber': receiptNumber,
      'generatedDate': generatedDate.toIso8601String(),
      'studentName': studentName,
      'amount': amount,
    };
  }

  factory FeeReceiptModel.fromMap(Map<String, dynamic> map) {
    return FeeReceiptModel(
      id: map['id'] ?? '',
      paymentId: map['paymentId'] ?? '',
      receiptNumber: map['receiptNumber'] ?? '',
      generatedDate: map['generatedDate'] != null ? DateTime.parse(map['generatedDate']) : DateTime.now(),
      studentName: map['studentName'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
    );
  }
}
