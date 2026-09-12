import '../../data/models/notification_model.dart';

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
}
