import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client.dart';

class AuthRepository {
  final SupabaseClient client = SupabaseConfig.client;

  static const String passwordRecoveryRedirect = 'hadi-sms://reset-password';

  Future<AuthResponse> login(String email, String password) {
    return client.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }

  Future<void> resetPassword(String email) {
    return client.auth.resetPasswordForEmail(
      email.trim().toLowerCase(),
      redirectTo: passwordRecoveryRedirect,
    );
  }

  Future<void> updatePassword(String password) {
    return client.auth.updateUser(UserAttributes(password: password));
  }

  Future<void> logout() => client.auth.signOut();
}
