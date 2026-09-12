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
    '/forgot-password',
    '/register-school',
  };

  // Routes a teacher is allowed to open.
  static const Set<String> _teacherRoutes = {
    '/teacher-dashboard',
    '/attendance',
    '/assignment',
    '/examination',
    '/result',
    '/profile',
  };

  // Routes a parent is allowed to open.
  static const Set<String> _parentRoutes = {
    '/parent-dashboard',
    '/attendance',
    '/assignment',
    '/examination',
    '/result',
    '/finance',
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

      // Keep role-specific login pages usable after logout, but if a user is
      // already signed in, send them to their correct portal.
      if (location == '/teacher-login' || location == '/parent-login') {
        return null;
      }

      return await _portalForCurrentUser();
    }

    if (auth.session == null) {
      return '/login';
    }

    final role = await _currentRole();
    if (role == null) return '/login';

    // Hard route-level role protection. RLS remains the database-level
    // protection; this prevents users from even opening unrelated screens.
    if (role == 'teacher') {
      if (_teacherRoutes.contains(location)) return null;
      return '/teacher-dashboard';
    }

    if (role == 'parent') {
      if (_parentRoutes.contains(location)) return null;
      return '/parent-dashboard';
    }

    // Principal/staff/admin accounts use the existing administration portal.
    if (location == '/teacher-dashboard' || location == '/parent-dashboard') {
      return '/dashboard';
    }

    return null;
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
