import 'package:go_router/go_router.dart';
import '../../auth/auth_state_notifier.dart';
import '../../network/supabase_client.dart';

class AuthGuard {
  AuthGuard._();

  static Future<String?> redirect(GoRouterState state) async {
    final location = state.uri.path;
    final auth = AuthStateNotifier.instance;
    const publicRoutes = {
      '/session-router',
      '/login',
      '/teacher-login',
      '/parent-login',
      '/forgot-password',
      '/register-school',
    };

    if (auth.isRecovering && location != '/reset-password') {
      return '/reset-password';
    }

    if (location == '/reset-password') {
      return auth.session == null ? '/login' : null;
    }

    if (location == '/splash' || location == '/session-router') return null;

    if (auth.session == null && !publicRoutes.contains(location)) {
      return '/login';
    }

    if (auth.session == null) return null;

    final isLoginRoute = publicRoutes.contains(location);
    if (isLoginRoute) {
      if (location == '/teacher-login' || location == '/parent-login') {
        // Role-specific login pages remain available after logout.
      } else if (location != '/session-router') {
        return await _portalForCurrentUser();
      }
    }

    if (location == '/teacher-dashboard') {
      return await _roleRedirect('teacher');
    }

    if (location == '/parent-dashboard') {
      return await _roleRedirect('parent');
    }

    if (location == '/dashboard') {
      final role = await _currentRole();
      if (role == 'parent') return '/parent-dashboard';
      if (role == 'teacher') return '/teacher-dashboard';
    }

    return null;
  }

  static Future<String?> _roleRedirect(String requiredRole) async {
    final role = await _currentRole();
    if (role == requiredRole) return null;
    return _portalForRole(role);
  }

  static Future<String?> _portalForCurrentUser() async {
    return _portalForRole(await _currentRole());
  }

  static String _portalForRole(String? role) {
    switch (role) {
      case 'parent':
        return '/parent-dashboard';
      case 'teacher':
        return '/teacher-dashboard';
      default:
        return '/dashboard';
    }
  }

  static Future<String?> _currentRole() async {
    final session = AuthStateNotifier.instance.session;
    if (session == null) return null;

    try {
      final profile = await SupabaseConfig.client
          .from('profiles')
          .select('role, is_active, school_id')
          .eq('id', session.user.id)
          .maybeSingle();

      if (profile == null || profile['is_active'] == false || profile['school_id'] == null) {
        await SupabaseConfig.client.auth.signOut();
        return null;
      }

      return profile['role']?.toString().trim().toLowerCase();
    } catch (_) {
      return null;
    }
  }
}