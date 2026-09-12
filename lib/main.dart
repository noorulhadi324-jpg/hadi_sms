import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/network/supabase_client.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? startupError;

  try {
    await SupabaseConfig.init();
  } catch (e) {
    startupError = e;
  }

  runApp(
    ProviderScope(
      child: HadiSmsApp(
        startupError: startupError,
      ),
    ),
  );
}

class HadiSmsApp extends StatelessWidget {
  final Object? startupError;

  const HadiSmsApp({
    super.key,
    this.startupError,
  });

  @override
  Widget build(BuildContext context) {
    if (startupError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText(
                'Startup Error\n\n$startupError',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'HADI SMS',
      theme: AppTheme.dark,
      routerConfig: AppRouter.router,
    );
  }
}