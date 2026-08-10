import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/supabase_repository.dart';
import '../../core/theme.dart';
import 'room_dashboard_screen.dart';

class RoomCreateScreen extends StatefulWidget {
  const RoomCreateScreen({super.key});

  @override
  State<RoomCreateScreen> createState() => _RoomCreateScreenState();
}

class _RoomCreateScreenState extends State<RoomCreateScreen> {
  final _name = TextEditingController();

  int _days = 1;
  bool _recommend = true;
  bool _loading = false;

  // group: 여러 명이서 여행
  // solo: 혼자 여행
  String _travelType = 'group';

  // 혼자 여행일 때 직접 선택하는 시작 날짜
  DateTime? _startDate;

  String _code() {
    const c = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();

    return List.generate(
      6,
      (_) => c[r.nextInt(c.length)],
    ).join();
  }

  String _label(int d) {
    return d == 1 ? '당일치기' : '${d - 1}박 $d일';
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  DateTime? get _endDate {
    if (_startDate == null) return null;

    return DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day + _days - 1,
    );
  }

  Future<void> _selectStartDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3),
      helpText: '여행 시작일을 선택하세요',
      cancelText: '취소',
      confirmText: '선택',
    );

    if (picked == null) return;

    setState(() {
      _startDate = picked;
    });
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('방 이름을 입력해주세요.'),
        ),
      );
      return;
    }

    // 혼자 여행은 직접 날짜를 지정해야 함
    if (_travelType == 'solo' && _startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('혼자 여행은 여행 날짜를 선택해주세요.'),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final room = await SupabaseRepository().createRoom(
        name: _name.text,
        inviteCode: _code(),
        tripDays: _days,
        placeRecommendationEnabled: _recommend,
        travelType: _travelType,
        startDate: _travelType == 'solo' ? _startDate : null,
        endDate: _travelType == 'solo' ? _endDate : null,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RoomDashboardScreen(room: room),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('방 생성 실패: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('새 방 만들기'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            '여행 기본 정보',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            _travelType == 'solo'
                ? '혼자 여행할 날짜와 기간을 직접 정합니다.'
                : '멤버들이 가능한 날짜를 모아 여행 일정을 결정합니다.',
            style: const TextStyle(
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 24),

          TextField(
            controller: _name,
            maxLength: 30,
            decoration: const InputDecoration(
              labelText: '방 이름',
              hintText: '예: 제주도 여름 여행',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.groups),
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            '여행 유형',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const SizedBox(
                    width: double.infinity,
                    child: Center(
                      child: Text('여러 명이서 여행'),
                    ),
                  ),
                  selected: _travelType == 'group',
                  onSelected: (selected) {
                    if (!selected) return;

                    setState(() {
                      _travelType = 'group';
                      _startDate = null;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: const SizedBox(
                    width: double.infinity,
                    child: Center(
                      child: Text('혼자 여행'),
                    ),
                  ),
                  selected: _travelType == 'solo',
                  onSelected: (selected) {
                    if (!selected) return;

                    setState(() {
                      _travelType = 'solo';
                    });
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            _travelType == 'solo'
                ? '혼자 여행할 날짜를 직접 정합니다. 다른 멤버를 추가할 수 없습니다.'
                : '여러 명의 출발지와 이동 정보를 바탕으로 함께 가기 좋은 장소를 추천받습니다.',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            '여행 기간',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
              7,
              (i) {
                final d = i + 1;

                return ChoiceChip(
                  label: Text(_label(d)),
                  selected: _days == d,
                  onSelected: (_) {
                    setState(() {
                      _days = d;
                    });
                  },
                );
              },
            ),
          ),

          // 혼자 여행일 때만 날짜 선택 UI 표시
          if (_travelType == 'solo') ...[
            const SizedBox(height: 24),

            const Text(
              '여행 날짜',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.calendar_month,
                  color: AppColors.room,
                ),
                title: Text(
                  _startDate == null
                      ? '여행 시작일 선택'
                      : _formatDate(_startDate!),
                ),
                subtitle: Text(
                  _startDate == null
                      ? '혼자 여행은 날짜를 직접 정해야 합니다.'
                      : _endDate == null
                          ? ''
                          : '${_formatDate(_startDate!)} ~ ${_formatDate(_endDate!)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _selectStartDate,
              ),
            ),

            if (_startDate != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  _days == 1
                      ? '선택한 날짜에 여행합니다.'
                      : '${_formatDate(_startDate!)}부터 $_days일간 여행합니다.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],

          const SizedBox(height: 24),

          Card(
            child: SwitchListTile(
              value: _recommend,
              onChanged: (v) {
                setState(() {
                  _recommend = v;
                });
              },
              secondary: const Icon(
                Icons.auto_awesome,
                color: AppColors.room,
              ),
              title: const Text('AI 장소 추천'),
              subtitle: Text(
                _recommend
                    ? _travelType == 'solo'
                        ? '혼자 여행하기 좋은 장소를 추천받습니다.'
                        : '여행 조건을 고려해 장소를 추천받습니다.'
                    : '장소를 직접 검색하고 추가합니다.',
              ),
            ),
          ),

          const SizedBox(height: 28),

          FilledButton(
            onPressed: _loading ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.room,
              padding: const EdgeInsets.all(16),
            ),
            child: _loading
                ? const CircularProgressIndicator()
                : const Text('방 만들기'),
          ),
        ],
      ),
    );
  }
}