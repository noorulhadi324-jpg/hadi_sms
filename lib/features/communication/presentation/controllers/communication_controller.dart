import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/main_wrapper.dart';
import '../../data/repositories/communication_repository_impl.dart';

final communicationRepositoryProvider = Provider<CommunicationRepositoryImpl>((ref) {
  return CommunicationRepositoryImpl(client: SupabaseConfig.client);
});

final communicationSchoolUsersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final schoolId = await ref.watch(schoolIdProvider.future);
  if (schoolId == null) throw Exception('No school linked to your account.');
  return ref.read(communicationRepositoryProvider).getSchoolUsers(schoolId);
});
