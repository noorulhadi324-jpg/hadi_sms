import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin Supabase datasource used by the communication feature.
/// Keeping database calls here makes the UI easy to evolve later.
class CommunicationRemoteDataSource {
  final SupabaseClient client;

  const CommunicationRemoteDataSource(this.client);

  Future<List<Map<String, dynamic>>> schoolUsers(int schoolId) async {
    final rows = await client
        .from('profiles')
        .select('id,full_name,email,role,staff_role,is_active')
        .eq('school_id', schoolId)
        .eq('is_active', true)
        .order('full_name');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> announcements(int schoolId) async {
    final rows = await client
        .from('notifications')
        .select()
        .eq('school_id', schoolId)
        .eq('is_active', true)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }
}
