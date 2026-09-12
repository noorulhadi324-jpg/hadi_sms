import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repository/finance_repository.dart';
import '../models/fee_structure_model.dart';
import '../models/fee_payment_model.dart';
import '../../../../core/network/supabase_client.dart';

class SupabaseFinanceRepository implements FinanceRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  @override
  Future<List<FeeStructureModel>> getFeeStructures(String className) async {
    final response = await _client
        .from('fee_structures')
        .select()
        .eq('className', className);
    return (response as List).map((e) => FeeStructureModel.fromMap(e)).toList();
  }

  @override
  Future<List<FeePaymentModel>> getPaymentsByStudent(String studentId) async {
    final response = await _client
        .from('fee_payments')
        .select()
        .eq('studentId', studentId)
        .order('paymentDate', ascending: false);
    return (response as List).map((e) => FeePaymentModel.fromMap(e)).toList();
  }

  @override
  Future<void> recordPayment(FeePaymentModel payment) async {
    await _client.from('fee_payments').insert(payment.toMap());
  }

  @override
  Future<void> createFeeStructure(FeeStructureModel structure) async {
    await _client.from('fee_structures').insert(structure.toMap());
  }
}
