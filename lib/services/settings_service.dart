// 系統設定服務層（管理主題外觀、使用者偏好与通知提醒持久化）
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主題外觀設定資料模型
class ThemeSettings {
  final ThemeMode themeMode;
  final Color seedColor;
  final String colorName;

  const ThemeSettings({
    required this.themeMode,
    required this.seedColor,
    required this.colorName,
  });

  ThemeSettings copyWith({
    ThemeMode? themeMode,
    Color? seedColor,
    String? colorName,
  }) {
    return ThemeSettings(
      themeMode: themeMode ?? this.themeMode,
      seedColor: seedColor ?? this.seedColor,
      colorName: colorName ?? this.colorName,
    );
  }
}

/// 支援的主題代表色選項
class AppColorOption {
  final String name;
  final Color color;

  const AppColorOption(this.name, this.color);
}

/// 系統設定服務單例
class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  // 應用程式版本
  static const String appVersion = 'v0.11.0';

  // SharedPreferences Keys
  static const String _keyThemeMode = 'unitrack_settings_theme_mode_v1';
  static const String _keyColorSeed = 'unitrack_settings_color_seed_v1';
  static const String _keyClassReminder = 'unitrack_settings_reminder_class_v1';
  static const String _keyTodoReminder = 'unitrack_settings_reminder_todo_v1';
  static const String _keyExpenseReminder = 'unitrack_settings_reminder_expense_v1';
  static const String _keyWeekendTimetable = 'unitrack_settings_weekend_timetable_v1';

  // 舊版或假資料遺留 Keys（啟動時自動清理）
  static const List<String> _legacyFakeKeys = [
    'unitrack_todo_items_v1',
    'unitrack_todo_initialized_v1',
    'unitrack_todo_items_v2',
    'unitrack_todo_initialized_v2',
    'unitrack_settings_department_v1',
    'unitrack_settings_student_id_v1',
    'unitrack_semester_info_v1',
  ];

  /// 預設可選主題色調
  static const List<AppColorOption> availableColors = [
    AppColorOption('經典靛藍', Colors.indigo),
    AppColorOption('蔚藍海灣', Colors.blue),
    AppColorOption('清爽藍綠', Colors.teal),
    AppColorOption('典雅紫羅蘭', Colors.deepPurple),
    AppColorOption('活力暖橘', Colors.orange),
    AppColorOption('自然翠綠', Colors.green),
    AppColorOption('浪漫櫻粉', Colors.pink),
  ];

  /// 主題設定監聽器，供 MaterialApp 即時響應
  final ValueNotifier<ThemeSettings> themeNotifier = ValueNotifier<ThemeSettings>(
    const ThemeSettings(
      themeMode: ThemeMode.system,
      seedColor: Colors.indigo,
      colorName: '經典靛藍',
    ),
  );

  bool _initialized = false;
  bool get isInitialized => _initialized;

  // 暫存欄位
  bool _classReminder = true;
  bool _todoReminder = true;
  bool _expenseReminder = false;
  bool _weekendTimetable = false;

  bool get classReminder => _classReminder;
  bool get todoReminder => _todoReminder;
  bool get expenseReminder => _expenseReminder;
  bool get weekendTimetable => _weekendTimetable;

  /// 初始化讀取設定並自動清除舊版假資料快取
  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();

    // 自動清除舊版預設假資料與廢棄欄位
    for (final key in _legacyFakeKeys) {
      if (prefs.containsKey(key)) {
        await prefs.remove(key);
      }
    }

    // 1. 主題模式
    final modeIndex = prefs.getInt(_keyThemeMode);
    final themeMode = (modeIndex != null && modeIndex >= 0 && modeIndex < ThemeMode.values.length)
        ? ThemeMode.values[modeIndex]
        : ThemeMode.system;

    // 2. 主題顏色種子
    final colorVal = prefs.getInt(_keyColorSeed);
    Color seedColor = Colors.indigo;
    String colorName = '經典靛藍';
    if (colorVal != null) {
      final found = availableColors.firstWhere(
        (c) => c.color.toARGB32() == colorVal,
        orElse: () => AppColorOption('自訂色', Color(colorVal)),
      );
      seedColor = found.color;
      colorName = found.name;
    }

    themeNotifier.value = ThemeSettings(
      themeMode: themeMode,
      seedColor: seedColor,
      colorName: colorName,
    );

    // 3. 偏好資訊
    _classReminder = prefs.getBool(_keyClassReminder) ?? true;
    _todoReminder = prefs.getBool(_keyTodoReminder) ?? true;
    _expenseReminder = prefs.getBool(_keyExpenseReminder) ?? false;
    _weekendTimetable = prefs.getBool(_keyWeekendTimetable) ?? false;

    _initialized = true;
  }

  /// 更新主題模式（跟隨系統 / 淺色 / 深色）
  Future<void> setThemeMode(ThemeMode mode) async {
    themeNotifier.value = themeNotifier.value.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyThemeMode, mode.index);
  }

  /// 更新主題色調
  Future<void> setSeedColor(AppColorOption option) async {
    themeNotifier.value = themeNotifier.value.copyWith(
      seedColor: option.color,
      colorName: option.name,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyColorSeed, option.color.toARGB32());
  }

  /// 切換上課前提醒
  Future<void> setClassReminder(bool value) async {
    _classReminder = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyClassReminder, value);
  }

  /// 切換待辦提醒
  Future<void> setTodoReminder(bool value) async {
    _todoReminder = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTodoReminder, value);
  }

  /// 切換記帳提醒
  Future<void> setExpenseReminder(bool value) async {
    _expenseReminder = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyExpenseReminder, value);
  }

  /// 切換週末課表顯示
  Future<void> setWeekendTimetable(bool value) async {
    _weekendTimetable = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyWeekendTimetable, value);
  }

  /// 重設為原廠預設值並清空所有本地快取資料（含待辦事項）
  Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    _classReminder = true;
    _todoReminder = true;
    _expenseReminder = false;
    _weekendTimetable = false;

    themeNotifier.value = const ThemeSettings(
      themeMode: ThemeMode.system,
      seedColor: Colors.indigo,
      colorName: '經典靛藍',
    );
  }
}
