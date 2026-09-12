import '../core/network/supabase_client.dart';

class AppBootstrap {
  AppBootstrap._();

  static Future<void> initialize() async {
    await SupabaseConfig.init();
  }
}
