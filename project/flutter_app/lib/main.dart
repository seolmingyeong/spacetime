import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'core/supabase_client.dart';
import 'features/auth/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
