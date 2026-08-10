import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase 초기화 설정.
class SupabaseConfig {
  static const String url = 'https://kmglkpcpftsoalsqyalk.supabase.co';
  static const String anonKey = 'sb_publishable_rZhqYXUXu095W6wOEsVZrg_XBVJN2aR';

  static Future<void> init() async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }
}

/// 앱 어디서든 `supabase` 로 바로 접근할 수 있도록 하는 getter.
SupabaseClient get supabase => Supabase.instance.client;

/// 현재 로그인한 유저의 프로필(profiles 테이블 row)을 가져옵니다.
Future<Map<String, dynamic>?> fetchMyProfile() async {
  try {
    final user = supabase.auth.currentUser;
    if (user == null) return null;
    final result = await supabase
        .from('profiles')
        .select('id,nickname,user_id,avatar_url')
        .eq('id', user.id)
        .maybeSingle();
    return result;
  } catch (e) {
    // Supabase가 초기화되지 않았거나 네트워크 오류 발생 시 null 반환
    return null;
  }
}
