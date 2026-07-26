import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/supabase_client.dart';
import '../../widgets/main_shell.dart';

/// 로그인 / 회원가입 화면.
/// TODO(team): 이메일/소셜 로그인 버튼에 실제 Supabase Auth 로직 연결.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  Future<void> _handleLogin() async {
    setState(() => _loading = true);
    try {
      // TODO(team): 실제 Supabase 연동 전까지는 목업으로 바로 다음 화면 이동.
      // await supabase.auth.signInWithPassword(
      //   email: _emailController.text,
      //   password: _passwordController.text,
      // );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('로그인 실패: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 80),
              const Text('여행메이트',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('같이 계획하고, 같이 여행해요',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                    labelText: '이메일', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: '비밀번호', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loading ? null : _handleLogin,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.schedule,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('이메일로 로그인'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  // TODO(team): 회원가입 화면으로 이동
                },
                child: const Text('회원가입'),
              ),
              const SizedBox(height: 24),
              const Row(children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('또는', style: TextStyle(color: AppColors.textSecondary)),
                ),
                Expanded(child: Divider()),
              ]),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  // TODO(team): 소셜 로그인 (Google/Kakao/Apple 등) 연결
                },
                icon: const Icon(Icons.login),
                label: const Text('소셜 로그인'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
