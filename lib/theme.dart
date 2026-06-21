import 'package:flutter/material.dart';

/// 全局主题：柔和的蓝紫色系，圆角卡片，友好留白。
class AppTheme {
  static const seed = Color(0xFF5B8DEF);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF6F7FB),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: Color(0xFF1B1D28),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F3F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  /// 日程分类可选颜色。
  static const palette = <int>[
    0xFF5B8DEF, // 蓝
    0xFF7C6CF0, // 紫
    0xFF34C2A8, // 青绿
    0xFFF5A623, // 橙
    0xFFEB5757, // 红
    0xFF56CCF2, // 浅蓝
  ];
}
