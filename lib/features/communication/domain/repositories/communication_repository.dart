import '../../data/models/notification_model.dart';
import '../entities/communication_thread.dart';

abstract class CommunicationRepository {
  Future<List<NotificationModel>> getSchoolNotifications(int schoolId);

  Future<NotificationModel> createNotification({
    required int schoolId,
    required String title,
    required String description,
    required String category,
    required String type,
    DateTime? startsAt,
    DateTime? expiresAt,
  });

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
  });

  Future<void> deleteNotification({
    required int id,
    required int schoolId,
  });

  Future<List<Map<String, dynamic>>> getSchoolUsers(int schoolId);
  Future<List<CommunicationThread>> getThreads(int schoolId);

  Future<int> createThread({
    required int schoolId,
    required String createdBy,
    String? title,
    required String threadType,
    required List<String> memberIds,
  });

  Future<void> sendMessage({
    required int threadId,
    required String senderId,
    required String body,
  });
}
