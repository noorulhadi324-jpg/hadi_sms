import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../network/supabase_client.dart';

class AuthStateNotifier extends ChangeNotifier {
  AuthStateNotifier._() {
    _subscription = SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
      _isRecovering = data.event == AuthChangeEvent.passwordRecovery;
      notifyListeners();
    });
  }

  static final AuthStateNotifier instance = AuthStateNotifier._();

  late final StreamSubscription<AuthState> _subscription;
  bool _isRecovering = false;

  bool get isRecovering => _isRecovering;
  Session? get session => SupabaseConfig.client.auth.currentSession;

  void clearRecovery() {
    if (!_isRecovering) return;
    _isRecovering = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
