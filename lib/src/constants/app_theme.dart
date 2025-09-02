import 'package:flutter/material.dart';

/// 应用主题配置类
/// 包含黑金主题色彩搭配、文本样式、组件样式等
/// 提供亮色与暗色主题配置
class AppTheme {
  /// 黑金主题 - 主色调定义
  /// prosperityBlack: 主背景色，深黑色象征专业与沉稳
  /// prosperityGold: 主金色，象征繁荣与质量（用于主要按钮、标题等）
  /// prosperityLightGold: 浅金色，用于文本和内容（提供良好对比度）
  /// prosperityDarkGold: 暗金色，用于强调和悬停状态
  /// prosperityGray: 主要灰色调，用于卡片和次要元素背景
  /// prosperityLightGray: 浅灰色，用于辅助文本和边框
  static const Color prosperityBlack = Color(0xFF0A0A0A);
  static const Color prosperityGold = Color(0xFFB89B6E);     // 主金色 #B89B6E
  static const Color prosperityLightGold = Color(0xFFD4C19A); // 浅金色 #D4C19A
  static const Color prosperityDarkGold = Color(0xFF8F7A50);  // 暗金色 #8F7A50
  static const Color prosperityGray = Color(0xFF2A2A2A);      // 中世纪灰色 #2A2A2A
  static const Color prosperityLightGray = Color(0xFF505050); // 浅灰色 #505050

  /// 亮色主题配置
  /// 以黑金为主调，适合用户默认使用
  /// 特点：深色背景减少眼疲劳，金色提供高级感
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: prosperityGold,
    scaffoldBackgroundColor: prosperityBlack,
    colorScheme: const ColorScheme.light(
      primary: prosperityGold,
      secondary: prosperityLightGold,
      surface: prosperityGray,
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
      fillColor: WidgetStateProperty.all(prosperityGold),
      checkColor: WidgetStateProperty.all(prosperityBlack),
    ),
  );

  /// 暗色主题配置
  /// 与亮色主题相似，但专为暗色模式优化
  /// 用于系统级深色模式切换或用户偏好设置
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: prosperityGold, // 保持金色作为主色调
    scaffoldBackgroundColor: prosperityBlack, // 更暗的背景强调对比
    colorScheme: const ColorScheme.dark(
      primary: prosperityGold,
      secondary: prosperityLightGold,
      surface: prosperityGray,
      onPrimary: prosperityBlack,
      onSecondary: prosperityBlack,
      onSurface: prosperityLightGold,
    ),
    /// 应用栏主题 - 与亮色主题一致，保持一致性
    appBarTheme: const AppBarTheme(
      backgroundColor: prosperityBlack,
      foregroundColor: prosperityGold,
      elevation: 0, // 无阴影，更显沉稳
      centerTitle: true, // 居中对齐，视觉平衡
    ),
    /// 卡片组件样式 - 与亮色主题相同，保持一致性
    cardTheme: CardTheme(
      color: prosperityGray,
      elevation: 4, // 轻微阴影，提升层次感
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    /// 提升按钮样式 - 与亮色主题相同，保持品牌一致性
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: prosperityGold,
        foregroundColor: prosperityBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24), // 大圆角设计
        ),
      ),
    ),
    iconTheme: const IconThemeData(color: prosperityGold), // 图标统一金色
  );

  /// 文本样式系统
  /// 提供约定俗成的文字样式，确保应用内文本风格统一
  /// 
  /// [titleLarge] 标题大样式: 用于主要标题文字
  /// [titleMedium] 标题中样式: 用于次要标题文字
  /// [bodyLarge] 正文大样式: 用于主要内容文字
  /// [bodyMedium] 正文中样式: 用于次要内容文字
  /// [labelSmall] 标签小样式: 用于说明文字、标签
  static const TextStyle titleLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: prosperityGold,
  );
  
  static const TextStyle titleMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600, // 中粗字体，突出层次
    color: prosperityGold,
  );
  
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    color: prosperityLightGold,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    color: prosperityLightGray, // 浅灰色，良好阅读体验
  );
  
  /// 标签小样式
  /// 用于按钮、表单项的标签文本，提供清晰指引
  static const TextStyle labelSmall = TextStyle(
    fontSize: 12,
    color: prosperityGold,
    fontWeight: FontWeight.w500, // 中等字体，指示性强
  );

  /// 表单输入框样式配置
  /// 统一所有输入框的外观，包括
  /// - 文本框
  /// - 下拉菜单
  /// - 搜索框等控件
  /// 特点：深色背景配金色边框，视觉专业
  static InputDecorationTheme inputDecorationTheme = InputDecorationTheme(
    filled: true,
    fillColor: prosperityGray,
    /// 默认边框样式
    /// 中等粗细的暗金色边框，适用于一般状态
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: prosperityDarkGold),
    ),
    /// 启用但未聚焦状态
    /// 半透明暗金色边框，视觉较为弱化，引导用户注意力
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: prosperityDarkGold.withValues(alpha: 0.5)),
    ),
    /// 聚焦状态
    /// 明亮金色加粗边框，突出当前交互区域，增强视觉反馈
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: prosperityGold, width: 2),
    ),
    /// 标签文字样式
    /// 金色标签文字，清晰指示输入内容类型
    labelStyle: const TextStyle(color: prosperityGold),
    /// 提示文字样式
    /// 半透明白色提示文字，提供输入指导，不抢占主要视觉焦点
    hintStyle: TextStyle(color: prosperityLightGray.withValues(alpha: 0.7)),
  );
}