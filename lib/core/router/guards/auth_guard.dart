import 'package:go_router/go_router.dart';
import '../../auth/auth_state_notifier.dart';

class AuthGuard {
  AuthGuard._();

  static String? redirect(GoRouterState state) {
    final location = state.uri.path;
    final auth = AuthStateNotifier.instance;
    final publicRoutes = {
      '/login',
      '/forgot-password',
      '/register-school',
    };

    if (auth.isRecovering && location != '/reset-password') {
      return '/reset-password';
    }

    if (location == '/reset-password') {
      return auth.session == null ? '/login' : null;
    }

    if (location == '/splash') return null;

    if (auth.session == null && !publicRoutes.contains(location)) {
      return '/login';
    }

    if (auth.session != null && (location == '/login' || location == '/forgot-password' || location == '/register-school')) {
      return '/dashboard';
    }

    return null;
  }
}
