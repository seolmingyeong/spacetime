import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../../core/supabase_client.dart';
import '../../widgets/main_shell.dart';

/// 구글 인증 직후, 서비스에서 쓸 추가 정보(닉네임/사용자ID/위치정보 동의)를 받는 화면.
/// 이 화면을 통과해야 실제로 profiles 테이블에 row가 생기고 "가입 완료" 처리됩니다.
class SignupExtraInfoScreen extends StatefulWidget {
  const SignupExtraInfoScreen({super.key});

  @override
  State<SignupExtraInfoScreen> createState() => _SignupExtraInfoScreenState();
}

class _SignupExtraInfoScreenState extends State<SignupExtraInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _userIdController = TextEditingController();
  bool _locationConsent = false;
  bool _submitting = false;

  static final _alphanumericOnly = RegExp(r'^[A-Za-z0-9]+$');

  @override
  void dispose() {
    _nicknameController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_locationConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치정보 사용 동의가 필요해요.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw Exception('로그인 세션이 만료됐어요. 처음부터 다시 시도해주세요.');
      }

      await supabase.from('profiles').insert({
        'id': user.id,
        'email' : user.email,
        'nickname': _nicknameController.text.trim(),
        'user_id': _userIdController.text.trim(),
        'location_consent': _locationConsent,
        'avatar_url': user.userMetadata?['avatar_url'] ?? user.userMetadata?['picture'],
      });

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필 설정이 완료됐어요!')),
      );
    } on PostgrestException catch (e) {
      // user_id unique 제약 위반(중복 아이디) 등 DB 에러
      final msg = e.code == '23505'
          ? '이미 사용 중인 사용자 ID예요. 다른 ID를 입력해주세요.'
          : '회원가입 실패: ${e.message}';
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('회원가입 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = supabase.auth.currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('추가 정보 입력'),
        automaticallyImplyLeading: false, // 뒤로가기로 어중간한 상태 방지
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (email.isNotEmpty) ...[
                Text('구글 계정: $email',
                    style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 20),
              ],
              TextFormField(
                controller: _nicknameController,
                decoration: const InputDecoration(
                  labelText: '닉네임',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '닉네임을 입력해주세요.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _userIdController,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(_alphanumericOnly),
                ],
                decoration: const InputDecoration(
                  labelText: '사용자 ID (영문/숫자만)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '사용자 ID를 입력해주세요.';
                  if (!_alphanumericOnly.hasMatch(v.trim())) {
                    return '영문과 숫자만 사용할 수 있어요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _locationConsent,
                onChanged: (v) => setState(() => _locationConsent = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: const Text('위치정보(GPS) 사용에 동의합니다 (필수)'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.schedule,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('가입 완료'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
