import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client.dart';
import '../../domain/entities/communication_thread.dart';
import '../../domain/repositories/communication_repository.dart';
import '../models/notification_model.dart';

class CommunicationRepositoryImpl implements CommunicationRepository {
  final SupabaseClient client;

  CommunicationRepositoryImpl({SupabaseClient? client})
      : client = client ?? SupabaseConfig.client;

  @override
  Future<List<NotificationModel>> getSchoolNotifications(int schoolId) async {
    final rows = await client
        .from('notifications')
        .select()
        .eq('school_id', schoolId)
        .eq('is_active', true)
        .order('created_at', ascending: false);

    return rows
        .map((row) => NotificationModel.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Future<NotificationModel> createNotification({
    required int schoolId,
    required String title,
    required String description,
    required String category,
    required String type,
    DateTime? startsAt,
    DateTime? expiresAt,
  }) async {
    final now = DateTime.now().toUtc();
    final userId = client.auth.currentUser?.id;

    final row = await client.from('notifications').insert({
      'school_id': schoolId,
      'title': title.trim(),
      'description': description.trim(),
      'message': description.trim(),
      'category': category.trim().isEmpty ? 'general' : category.trim(),
      'type': type.trim().isEmpty ? 'general' : type.trim(),
      'is_active': true,
      'is_read': false,
      'starts_at': (startsAt ?? now).toUtc().toIso8601String(),
      'expires_at': expiresAt?.toUtc().toIso8601String(),
      'created_by': userId,
    }).select().single();

    return NotificationModel.fromMap(Map<String, dynamic>.from(row));
  }

  @override
  Future<void> updateNotification({
    required int id,
    required int schoolId,
    required String title,
    required String description,
    required String category,
    required String type,
    required bool isActive,
    DateTime? startsAt,
    DateTime? expiresAt,
  }) async {
    await client.from('notifications').update({
      'title': title.trim(),
      'description': description.trim(),
      'message': description.trim(),
      'category': category.trim().isEmpty ? 'general' : category.trim(),
      'type': type.trim().isEmpty ? 'general' : type.trim(),
      'is_active': isActive,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'starts_at': (startsAt ?? DateTime.now().toUtc()).toUtc().toIso8601String(),
      'expires_at': expiresAt?.toUtc().toIso8601String(),
    }).eq('id', id).eq('school_id', schoolId);
  }

  @override
  Future<void> deleteNotification({required int id, required int schoolId}) async {
    await client.from('notifications').delete().eq('id', id).eq('school_id', schoolId);
  }

  @override
  Future<List<Map<String, dynamic>>> getSchoolUsers(int schoolId) async {
    final rows = await client
        .from('profiles')
        .select('id,full_name,email,role,staff_role,is_active')
        .eq('school_id', schoolId)
        .eq('is_active', true)
        .order('full_name');
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<List<CommunicationThread>> getThreads(int schoolId) async {
    final rows = await client
        .from('communication_threads')
        .select()
        .eq('school_id', schoolId)
        .eq('is_archived', false)
        .order('updated_at', ascending: false);
    return rows
        .map((row) => CommunicationThread.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Future<int> createThread({
    required int schoolId,
    required String createdBy,
    String? title,
    required String threadType,
    required List<String> memberIds,
  }) async {
    final row = await client.from('communication_threads').insert({
      'school_id': schoolId,
      'created_by': createdBy,
      'title': title?.trim().isEmpty == true ? null : title?.trim(),
      'thread_type': threadType,
    }).select('id').single();

    final threadId = (row['id'] as num).toInt();
    final uniqueMembers = <String>{createdBy, ...memberIds};
    await client.from('communication_thread_members').insert(
      uniqueMembers
          .map((userId) => {
                'thread_id': threadId,
                'user_id': userId,
                'member_role': userId == createdBy ? 'owner' : 'member',
              })
          .toList(),
    );
    return threadId;
  }

  @override
  Future<void> sendMessage({
    required int threadId,
    required String senderId,
    required String body,
  }) async {
    final text = body.trim();
    if (text.isEmpty) return;
    await client.from('communication_messages').insert({
      'thread_id': threadId,
      'sender_id': senderId,
      'body': text,
    });
    await client
        .from('communication_threads')
        .update({'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', threadId);
  }
}
