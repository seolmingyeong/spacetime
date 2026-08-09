import 'package:flutter/material.dart';

/// 플로우차트의 보라/초록/주황/파랑 4색 구조(내 일정 / 방 목록 / 기록 / 프로필)를
/// 그대로 앱 컬러 시스템으로 사용합니다.
class AppColors {
  static const schedule = Color(0xFF7C6FF0); // 내 일정 - 보라
  static const room = Color(0xFF3CB878); // 방 목록 - 초록
  static const record = Color(0xFFFF9F40); // 기록 - 주황
  static const profile = Color(0xFF5B8DEF); // 프로필 - 파랑

  static const background = Color(0xFFF7F8FA);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF8A8A8E);
  static const divider = Color(0xFFEAEAEA);
}

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.schedule,
        primary: AppColors.schedule,
        background: AppColors.background,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.divider),
        ),
      ),
      fontFamily: 'Pretendard',
    );
  }
}
