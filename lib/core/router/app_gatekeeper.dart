import 'package:flutter/material.dart';
import '../../../features/auth/presentation/screens/login_screen.dart';
import '../../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../network/supabase_client.dart';

class ApplicationPipelineGate extends StatelessWidget {
  const ApplicationPipelineGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SupabaseConfig.client.auth.currentSession;

    if (session == null) {
      return const LoginScreen();
    }

    return const DashboardScreen();
  }
}
