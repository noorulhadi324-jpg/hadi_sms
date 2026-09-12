import '../repositories/communication_repository.dart';

class SendMessage {
  final CommunicationRepository repository;

  const SendMessage(this.repository);

  Future<void> call({
    required int threadId,
    required String senderId,
    required String body,
  }) {
    return repository.sendMessage(
      threadId: threadId,
      senderId: senderId,
      body: body,
    );
  }
}
