import '../controllers/communication_controller.dart';

/// Central place for communication dependencies.
/// Riverpod providers are lazily created, so no manual initialization is needed.
class CommunicationBinding {
  const CommunicationBinding();

  static const providers = [communicationRepositoryProvider, communicationSchoolUsersProvider];
}
