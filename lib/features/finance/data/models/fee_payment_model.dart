class FeePaymentModel {
  final String id;
  final String studentId;
  final String installmentId;
  final double amountPaid;
  final DateTime paymentDate;
  final String paymentMethod;
  final String transactionId;

  FeePaymentModel({
    required this.id,
    required this.studentId,
    required this.installmentId,
    required this.amountPaid,
    required this.paymentDate,
    required this.paymentMethod,
    required this.transactionId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'installmentId': installmentId,
      'amountPaid': amountPaid,
      'paymentDate': paymentDate.toIso8601String(),
      'paymentMethod': paymentMethod,
      'transactionId': transactionId,
    };
  }

  factory FeePaymentModel.fromMap(Map<String, dynamic> map) {
    return FeePaymentModel(
      id: map['id'] ?? '',
      studentId: map['studentId'] ?? '',
      installmentId: map['installmentId'] ?? '',
      amountPaid: (map['amountPaid'] ?? 0.0).toDouble(),
      paymentDate: map['paymentDate'] != null ? DateTime.parse(map['paymentDate']) : DateTime.now(),
      paymentMethod: map['paymentMethod'] ?? '',
      transactionId: map['transactionId'] ?? '',
    );
  }
}
