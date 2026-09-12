import '../../data/models/fee_structure_model.dart';
import '../../data/models/fee_payment_model.dart';

abstract class FinanceRepository {
  Future<List<FeeStructureModel>> getFeeStructures(String className);
  Future<List<FeePaymentModel>> getPaymentsByStudent(String studentId);
  Future<void> recordPayment(FeePaymentModel payment);
  Future<void> createFeeStructure(FeeStructureModel structure);
}
