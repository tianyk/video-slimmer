import 'package:flutter/material.dart';

class AppTheme {
  // 黑金主题色彩
  static const Color prosperityBlack = Color(0xFF0A0A0A);
  static const Color prosperityGold = Color(0xFFB89B6E);
  static const Color prosperityLightGold = Color(0xFFD4C19A);
  static const Color prosperityDarkGold = Color(0xFF8F7A50);
  static const Color prosperityGray = Color(0xFF2A2A2A);
  static const Color prosperityLightGray = Color(0xFF505050);

  // 主题配置
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: prosperityGold,
    scaffoldBackgroundColor: prosperityBlack,
    colorScheme: const ColorScheme.light(
      primary: prosperityGold,
      secondary: prosperityLightGold,
      surface: prosperityGray,
      background: prosperityBlack,
      onPrimary: prosperityBlack,
      onSecondary: prosperityBlack,
      onSurface: prosperityLightGold,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: prosperityBlack,
      foregroundColor: prosperityGold,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: prosperityGold,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    cardTheme: CardTheme(
      color: prosperityGray,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: prosperityGold,
        foregroundColor: prosperityBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: prosperityGold,
        disabledForegroundColor: prosperityLightGray,
      ),
    ),
    iconTheme: const IconThemeData(color: prosperityGold),
    checkboxTheme: CheckboxThemeData(
      fillColor: MaterialStateProperty.all(prosperityGold),
      checkColor: MaterialStateProperty.all(prosperityBlack),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: prosperityGold,
    scaffoldBackgroundColor: prosperityBlack,
    colorScheme: const ColorScheme.dark(
      primary: prosperityGold,
      secondary: prosperityLightGold,
      surface: prosperityGray,
      background: prosperityBlack,
      onPrimary: prosperityBlack,
      onSecondary: prosperityBlack,
      onSurface: prosperityLightGold,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: prosperityBlack,
      foregroundColor: prosperityGold,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardTheme(
      color: prosperityGray,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: prosperityGold,
        foregroundColor: prosperityBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    ),
    iconTheme: const IconThemeData(color: prosperityGold),
  );

  // 文本样式
  static const TextStyle titleLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: prosperityGold,
  );
  
  static const TextStyle titleMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: prosperityGold,
  );
  
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    color: prosperityLightGold,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    color: prosperityLightGray,
  );
  
  static const TextStyle labelSmall = TextStyle(
    fontSize: 12,
    color: prosperityGold,
    fontWeight: FontWeight.w500,
  );

  // 边框样式
  static InputDecorationTheme inputDecorationTheme = InputDecorationTheme(
    filled: true,
    fillColor: prosperityGray,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: prosperityDarkGold),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: prosperityDarkGold.withOpacity(0.5)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: prosperityGold, width: 2),
    ),
    labelStyle: const TextStyle(color: prosperityGold),
    hintStyle: TextStyle(color: prosperityLightGray.withOpacity(0.7)),
  );
}