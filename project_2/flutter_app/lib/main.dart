import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme.dart';
import 'core/supabase_client.dart';
import 'features/auth/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 캘린더/날짜 포맷에서 'ko_KR' 로케일을 쓰기 위해 필요
  await initializeDateFormatting('ko_KR', null);

  // TODO(team): Supabase URL/Key를 core/supabase_client.dart 에 설정한 뒤 주석 해제
  // await SupabaseConfig.init();

  runApp(const TravelTogetherApp());
}

class TravelTogetherApp extends StatelessWidget {
  const TravelTogetherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '여행메이트',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const LoginScreen(),
    );
  }
}
