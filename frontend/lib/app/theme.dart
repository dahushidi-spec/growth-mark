import 'package:flutter/material.dart';

/// AppTheme - 成长印记应用主题配置
/// 定义温暖的暖橙色彩系统，营造温馨、亲切的儿童成长记录氛围
class AppTheme {
  AppTheme._();

  // ===== 主题色彩常量 =====

  /// 主色 - 暖橙
  static const Color accent = Color(0xFFE8833A);

  /// 辅色2 - 自然绿
  static const Color accent2 = Color(0xFF5B8C5A);

  /// 辅色3 - 沉稳蓝
  static const Color accent3 = Color(0xFF4A6FA5);

  /// 背景色 - 奶白
  static const Color bg = Color(0xFFFFFBF7);

  /// 表面色 - 浅橙
  static const Color bg2 = Color(0xFFFFF3E6);

  /// 主文字 - 深棕
  static const Color ink = Color(0xFF2D2420);

  /// 次要文字 - 灰棕
  static const Color muted = Color(0xFF8C7B6E);

  /// 边框色 - 米色
  static const Color rule = Color(0xFFE8D5C4);

  // ===== 派生色彩 =====

  static const Color accentLight = Color(0xFFF5A965);
  static const Color accentDark = Color(0xFFC56A28);
  static const Color errorRed = Color(0xFFD9534F);
  static const Color successGreen = Color(0xFF5B8C5A);
  static const Color warningYellow = Color(0xFFF0AD4E);

  // ===== 深色模式色彩 =====

  /// 深色背景 - 深棕
  static const Color darkBg = Color(0xFF1A1714);

  /// 深色表面 - 暖深棕
  static const Color darkBg2 = Color(0xFF241F1A);

  /// 深色主文字 - 浅米
  static const Color darkInk = Color(0xFFF5E6D3);

  /// 深色次要文字 - 暖灰
  static const Color darkMuted = Color(0xFFA89580);

  /// 深色边框 - 深棕
  static const Color darkRule = Color(0xFF3A3128);

  /// 浅色主题
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: accent,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        primary: accent,
        secondary: accent2,
        tertiary: accent3,
        surface: bg,
        error: errorRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: ink,
      ),
      fontFamily: 'NotoSansSC',

      // AppBar主题 - 透明背景，温暖文字
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'NotoSansSC',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        iconTheme: IconThemeData(color: ink),
      ),

      // 卡片主题 - 圆角白底，柔和阴影
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: accent.withOpacity(0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // 输入框主题 - 圆角，温暖边框
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bg2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: muted, fontSize: 14),
        labelStyle: TextStyle(color: muted, fontSize: 14),
        prefixIconColor: muted,
        suffixIconColor: muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: rule, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: rule, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorRed, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorRed, width: 2),
        ),
      ),

      // 按钮主题
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: accent.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'NotoSansSC',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: const TextStyle(
            fontFamily: 'NotoSansSC',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: const BorderSide(color: accent, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // 底部导航栏主题
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: accent,
        unselectedItemColor: muted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: const TextStyle(
          fontFamily: 'NotoSansSC',
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'NotoSansSC',
          fontSize: 11,
        ),
      ),

      // 底部AppBar主题
      bottomAppBarTheme: const BottomAppBarThemeData(
        color: Colors.white,
        elevation: 8,
      ),

      // 文字主题
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'NotoSansSC',
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: ink,
        ),
        displayMedium: TextStyle(
          fontFamily: 'NotoSansSC',
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: ink,
        ),
        headlineLarge: TextStyle(
          fontFamily: 'NotoSansSC',
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'NotoSansSC',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        titleLarge: TextStyle(
          fontFamily: 'NotoSansSC',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        titleMedium: TextStyle(
          fontFamily: 'NotoSansSC',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: ink,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'NotoSansSC',
          fontSize: 16,
          color: ink,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'NotoSansSC',
          fontSize: 14,
          color: ink,
        ),
        bodySmall: TextStyle(
          fontFamily: 'NotoSansSC',
          fontSize: 12,
          color: muted,
        ),
        labelLarge: TextStyle(
          fontFamily: 'NotoSansSC',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
      ),

      // 分隔线主题
      dividerTheme: DividerThemeData(
        color: rule,
        thickness: 1,
        space: 1,
      ),

      // 图标主题
      iconTheme: const IconThemeData(
        color: ink,
        size: 24,
      ),

      // 浮动按钮主题
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Chip主题
      chipTheme: ChipThemeData(
        backgroundColor: bg2,
        selectedColor: accent,
        labelStyle: const TextStyle(
          fontFamily: 'NotoSansSC',
          fontSize: 12,
          color: ink,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: 'NotoSansSC',
          fontSize: 12,
          color: Colors.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: BorderSide(color: rule),
      ),

      // 进度指示器主题
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: bg2,
      ),
    );
  }

  /// 深色主题（预留，不默认启用）
  /// 基于现有色彩生成深色版本，accent 等强调色保持不变以维持品牌一致性。
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: accent,
      scaffoldBackgroundColor: darkBg,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
        primary: accent,
        secondary: accent2,
        tertiary: accent3,
        surface: darkBg2,
        error: errorRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: darkInk,
      ),
      fontFamily: 'NotoSansSC',

      // AppBar主题
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        foregroundColor: darkInk,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'NotoSansSC',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: darkInk,
        ),
        iconTheme: IconThemeData(color: darkInk),
      ),

      // 卡片主题
      cardTheme: CardThemeData(
        color: darkBg2,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // 输入框主题
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkBg2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: darkMuted, fontSize: 14),
        labelStyle: const TextStyle(color: darkMuted, fontSize: 14),
        prefixIconColor: darkMuted,
        suffixIconColor: darkMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkRule, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkRule, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorRed, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorRed, width: 2),
        ),
      ),

      // 按钮主题
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: accent.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'NotoSansSC',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: const TextStyle(
            fontFamily: 'NotoSansSC',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: const BorderSide(color: accent, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // 底部导航栏主题
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkBg2,
        selectedItemColor: accent,
        unselectedItemColor: darkMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: const TextStyle(
          fontFamily: 'NotoSansSC',
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'NotoSansSC',
          fontSize: 11,
        ),
      ),

      bottomAppBarTheme: const BottomAppBarThemeData(
        color: darkBg2,
        elevation: 8,
      ),

      // 文字主题
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'NotoSansSC',
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: darkInk,
        ),
        displayMedium: TextStyle(
          fontFamily: 'NotoSansSC',
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: darkInk,
        ),
        headlineLarge: TextStyle(
          fontFamily: 'NotoSansSC',
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: darkInk,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'NotoSansSC',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: darkInk,
        ),
        titleLarge: TextStyle(
          fontFamily: 'NotoSansSC',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: darkInk,
        ),
        titleMedium: TextStyle(
          fontFamily: 'NotoSansSC',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: darkInk,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'NotoSansSC',
          fontSize: 16,
          color: darkInk,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'NotoSansSC',
          fontSize: 14,
          color: darkInk,
        ),
        bodySmall: TextStyle(
          fontFamily: 'NotoSansSC',
          fontSize: 12,
          color: darkMuted,
        ),
        labelLarge: TextStyle(
          fontFamily: 'NotoSansSC',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: darkInk,
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: darkRule,
        thickness: 1,
        space: 1,
      ),

      iconTheme: const IconThemeData(
        color: darkInk,
        size: 24,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: darkBg2,
        selectedColor: accent,
        labelStyle: const TextStyle(
          fontFamily: 'NotoSansSC',
          fontSize: 12,
          color: darkInk,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: 'NotoSansSC',
          fontSize: 12,
          color: Colors.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: const BorderSide(color: darkRule),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: darkBg2,
      ),
    );
  }

  /// 获取主题：根据是否深色模式返回对应主题
  static ThemeData getTheme({bool isDark = false}) {
    return isDark ? darkTheme : lightTheme;
  }

  /// 获取分类对应的颜色
  static Color getCategoryColor(String category) {
    switch (category) {
      case '绘画':
        return accent;
      case '书法':
        return accent2;
      case '手工':
        return accent3;
      case '音乐':
        return const Color(0xFF9B59B6);
      case '写作':
        return const Color(0xFF3498DB);
      default:
        return muted;
    }
  }
}
