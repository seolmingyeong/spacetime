import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase 초기화 설정.
///
/// TODO(team): Supabase 프로젝트 생성 후 아래 두 값을 실제 값으로 교체하세요.
/// 대시보드 > Project Settings > API 에서 확인할 수 있습니다.
/// 실제 서비스에서는 이 값을 --dart-define 이나 .env 로 분리하는 것을 권장합니다.
class SupabaseConfig {
  static const String url = 'https://YOUR_PROJECT_ID.supabase.co';
  static const String anonKey = 'YOUR_SUPABASE_ANON_KEY';

  static Future<void> init() async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }
}

/// 앱 어디서든 `supabase` 로 바로 접근할 수 있도록 하는 getter.
final SupabaseClient supabase = Supabase.instance.client;
