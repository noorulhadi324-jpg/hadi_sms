import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  SupabaseConfig._();

  static const String supabaseUrl =
      'https://sbjytvbrqjmawhyjwcvy.supabase.co';

  static const String supabasePublishableKey =
      'sb_publishable_8lzNq7-VBuERBSA47Il9ww_bcpBDNH8';

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> init() async {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
  }
}