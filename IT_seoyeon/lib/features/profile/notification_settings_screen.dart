import 'package:flutter/material.dart';
import '../../core/supabase_repository.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  Map<String, dynamic> _preferences = {};
  bool _loading = true;
  static const labels = {
    'social_enabled': '친구 및 소셜',
    'room_enabled': '방과 멤버',
    'travel_schedule_enabled': '여행 일정',
    'personal_schedule_enabled': '개인 일정',
    'record_enabled': '기록 및 사진',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await SupabaseRepository().getNotificationPreferences();
    if (mounted) setState(() { _preferences = value; _loading = false; });
  }

  Future<void> _set(String key, bool value) async {
    setState(() => _preferences[key] = value);
    await SupabaseRepository().saveNotificationPreferences({key: value});
  }

  TimeOfDay _timeOf(dynamic value, String fallback) {
    final parts = (value ?? fallback).toString().split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  Future<void> _pickQuietTime(String key, String fallback) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _timeOf(_preferences[key], fallback),
      helpText: key == 'quiet_start' ? '방해 금지 시작 시간' : '방해 금지 종료 시간',
    );
    if (selected == null) return;
    final value = '${selected.hour.toString().padLeft(2, '0')}:'
        '${selected.minute.toString().padLeft(2, '0')}:00';
    setState(() => _preferences[key] = value);
    await SupabaseRepository().saveNotificationPreferences({key: value});
  }

  String _shortTime(dynamic value, String fallback) {
    final text = (value ?? fallback).toString();
    return text.length >= 5 ? text.substring(0, 5) : fallback;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('알림 설정')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile(
                  title: const Text('전체 알림'),
                  value: _preferences['all_enabled'] ?? true,
                  onChanged: (v) => _set('all_enabled', v),
                ),
                const Divider(),
                const ListTile(title: Text('수신 방법', style: TextStyle(fontWeight: FontWeight.bold))),
                SwitchListTile(
                  title: const Text('휴대폰 푸시 알림'),
                  subtitle: const Text('Firebase 연결과 기기 알림 권한이 필요합니다.'),
                  value: _preferences['push_enabled'] ?? true,
                  onChanged: (v) => _set('push_enabled', v),
                ),
                SwitchListTile(
                  title: const Text('이메일 알림'),
                  subtitle: const Text('이메일 발송 서비스 연결 후 실제 발송됩니다.'),
                  value: _preferences['email_enabled'] ?? true,
                  onChanged: (v) => _set('email_enabled', v),
                ),
                SwitchListTile(
                  title: const Text('이메일 하루 한 번 요약'),
                  value: _preferences['email_digest'] ?? false,
                  onChanged: (v) => _set('email_digest', v),
                ),
                const Divider(),
                const ListTile(title: Text('알림 종류', style: TextStyle(fontWeight: FontWeight.bold))),
                ...labels.entries.map(
                  (entry) => SwitchListTile(
                    title: Text(entry.value),
                    value: _preferences[entry.key] ?? true,
                    onChanged: (v) => _set(entry.key, v),
                  ),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('방해 금지 시간'),
                  subtitle: Text(
                    '${_shortTime(_preferences['quiet_start'], '22:00')} ~ '
                    '${_shortTime(_preferences['quiet_end'], '08:00')}',
                  ),
                  value: _preferences['quiet_hours_enabled'] ?? false,
                  onChanged: (v) => _set('quiet_hours_enabled', v),
                ),
                if (_preferences['quiet_hours_enabled'] ?? false) ...[
                  ListTile(
                    leading: const Icon(Icons.nightlight_outlined),
                    title: const Text('시작 시간'),
                    trailing: Text(_shortTime(_preferences['quiet_start'], '22:00')),
                    onTap: () => _pickQuietTime('quiet_start', '22:00'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.wb_sunny_outlined),
                    title: const Text('종료 시간'),
                    trailing: Text(_shortTime(_preferences['quiet_end'], '08:00')),
                    onTap: () => _pickQuietTime('quiet_end', '08:00'),
                  ),
                ],
              ],
            ),
    );
  }
}
