import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../widgets/main_shell.dart';
import 'signup_extra_info_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  StreamSubscription<AuthState>? _subscription;
  bool _loading = false;
  bool _routing = false;

  @override
  void initState() {
    super.initState();
    _subscription = supabase.auth.onAuthStateChange.listen((event) {
      if (event.session != null) _routeAfterLogin();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (supabase.auth.currentSession != null) _routeAfterLogin();
    });
  }

  Future<void> _routeAfterLogin() async {
    if (_routing) return;
    _routing = true;
    try {
      final profile = await fetchMyProfile();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => profile == null
            ? const SignupExtraInfoScreen() : const MainShell()),
        (_) => false,
      );
    } finally { _routing = false; }
  }

  Future<void> _googleLogin() async {
    setState(() => _loading = true);
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? Uri.base.origin : 'io.supabase.traveltogether://login-callback/',
        authScreenLaunchMode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google 로그인 실패: $e')));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override void dispose() { _subscription?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Spacer(),
          const Icon(Icons.travel_explore, size: 76, color: AppColors.schedule),
          const SizedBox(height: 24),
          const Text('여행메이트', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('같이 가능한 날을 찾고, 함께 여행을 기록해요',
            textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
          const Spacer(),
          FilledButton.icon(
            onPressed: _loading ? null : _googleLogin,
            icon: _loading ? const SizedBox(width:18,height:18,
              child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))
              : const Icon(Icons.login),
            label: const Text('Google로 계속하기'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical:16)),
          ),
          const SizedBox(height: 12),
          const Text('계속하면 서비스 이용약관과 개인정보 처리방침에 동의하게 됩니다.',
            textAlign: TextAlign.center, style: TextStyle(fontSize:11,color:AppColors.textSecondary)),
          const SizedBox(height: 20),
        ]),
      ),
    ),
  );
}
