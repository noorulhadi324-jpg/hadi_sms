import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client.dart';

class AuthRepository {
  final SupabaseClient client = SupabaseConfig.client;

  static const String passwordRecoveryRedirect = 'hadi-sms://reset-password';

  Future<AuthResponse> login(
    String email,
    String password, {
    String? expectedRole,
  }) async {
    final response = await client.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );

    final user = response.user;
    if (user == null) throw const AuthException('Authentication failed.');

    await client.rpc('ensure_my_school_link');

    final profile = await client
        .from('profiles')
        .select('id, role, school_id, is_active')
        .eq('id', user.id)
        .maybeSingle();

    if (profile == null) {
      await client.auth.signOut();
      throw const AuthException('Your account profile was not found.');
    }
    if (profile['is_active'] == false) {
      await client.auth.signOut();
      throw const AuthException('Your account is inactive. Please contact the administrator.');
    }
    if (profile['school_id'] == null) {
      await client.auth.signOut();
      throw const AuthException('Your account is not linked to a school. Please contact the school administrator.');
    }

    final actualRole = profile['role']?.toString().trim().toLowerCase();
    final requiredRole = expectedRole?.trim().toLowerCase();
    if (requiredRole != null && requiredRole.isNotEmpty && actualRole != requiredRole) {
      await client.auth.signOut();
      final portalName = switch (requiredRole) {
        'teacher' => 'Teacher',
        'parent' => 'Parent',
        'staff' => 'Staff',
        _ => 'requested',
      };
      throw AuthException('This account is not a $portalName account. Please use the correct portal.');
    }

    return response;
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
