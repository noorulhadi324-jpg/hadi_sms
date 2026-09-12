import 'package:go_router/go_router.dart';
import '../../auth/auth_state_notifier.dart';
import '../../network/supabase_client.dart';

class AuthGuard {
  AuthGuard._();

  static const Set<String> _publicRoutes = {
    '/session-router',
    '/login',
    '/teacher-login',
    '/parent-login',
    '/staff-login',
    '/forgot-password',
    '/register-school',
  };

  static const Set<String> _teacherRoutes = {
    '/teacher-dashboard',
    '/attendance',
    '/assignment',
    '/examination',
    '/result',
    '/communication',
    '/profile',
  };

  static const Set<String> _parentRoutes = {
    '/parent-dashboard',
    '/attendance',
    '/assignment',
    '/examination',
    '/result',
    '/finance',
    '/communication',
    '/profile',
  };

  static const Set<String> _staffRoutes = {
    '/staff-dashboard',
    '/attendance',
    '/assignment',
    '/examination',
    '/result',
    '/finance',
    '/accounting',
    '/fee',
    '/library',
    '/communication',
    '/profile',
  };

  static Future<String?> redirect(GoRouterState state) async {
    final location = state.uri.path;
    final auth = AuthStateNotifier.instance;

    if (auth.isRecovering && location != '/reset-password') {
      return '/reset-password';
    }

    if (location == '/reset-password') {
      return auth.session == null ? '/login' : null;
    }

    if (location == '/splash' || _publicRoutes.contains(location)) {
      if (auth.session == null) return null;
      if (location == '/teacher-login' ||
          location == '/parent-login' ||
          location == '/staff-login') {
        return null;
      }
      return await _portalForCurrentUser();
    }

    if (auth.session == null) return '/login';

    final role = await _currentRole();
    if (role == null) return '/login';

    if (role == 'teacher') {
      if (_teacherRoutes.contains(location)) return null;
      return '/teacher-dashboard';
    }

    if (role == 'parent') {
      if (_parentRoutes.contains(location)) return null;
      return '/parent-dashboard';
    }

    if (role == 'staff') {
      if (_staffRoutes.contains(location)) return null;
      return '/staff-dashboard';
    }

    if (location == '/teacher-dashboard' ||
        location == '/parent-dashboard' ||
        location == '/staff-dashboard') {
      return '/dashboard';
    }

    return null;
  }

  static Future<String?> _portalForCurrentUser() async =>
      _portalForRole(await _currentRole());

  static String _portalForRole(String? role) {
    switch (role) {
      case 'parent':
        return '/parent-dashboard';
      case 'teacher':
        return '/teacher-dashboard';
      case 'staff':
        return '/staff-dashboard';
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

      if (profile == null ||
          profile['is_active'] == false ||
          profile['school_id'] == null) {
        await SupabaseConfig.client.auth.signOut();
        return null;
      }

      return profile['role']?.toString().trim().toLowerCase();
    } catch (_) {
      return null;
    }
  }
}
