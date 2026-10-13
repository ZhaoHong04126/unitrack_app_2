import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum CourseType {
  required, // 必修
  elective, // 選修
  general, // 通識
}

extension CourseTypeExtension on CourseType {
  String get label {
    switch (this) {
      case CourseType.required:
        return '必修';
      case CourseType.elective:
        return '選修';
      case CourseType.general:
        return '通識';
    }
  }
}

/// 課表節次與時間區段定義
class TimetableSection {
  final int section;
  final String label;
  final String startTime;
  final String endTime;

  const TimetableSection({
    required this.section,
    required this.label,
    required this.startTime,
    required this.endTime,
  });

  String get timeRange => '$startTime - $endTime';
}

class Course {
  final String id;
  final String name; // 課程名稱
  final String classroom; // 教室 (如: 工401)
  final String professor; // 授課教授
  final int weekday; // 星期幾 (1: 週一, 2: 週二 ... 7: 週日)
  final int startSection; // 開始節次 (0 ~ 15，例如 0 代表第 0 節)
  final int endSection; // 結束節次 (0 ~ 15，例如 3 代表第 3 節)
  final int credits; // 學分數 (畢業審查會用到)
  final CourseType type; // 必選修類別
  final Color color; // 課表格子顏色

  const Course({
    required this.id,
    required this.name,
    required this.classroom,
    this.professor = '',
    required this.weekday,
    required this.startSection,
    required this.endSection,
    this.credits = 3,
    this.type = CourseType.required,
    this.color = Colors.indigo,
  });

  /// 支援預設課表配色盤（區分不同課程卡片背景色）
  static const List<Color> colorPalette = [
    Color(0xFF3F51B5), // 靛藍 Indigo
    Color(0xFF00897B), // 湖水綠 Teal
    Color(0xFFE65100), // 琥珀橘 Deep Orange
    Color(0xFF8E24AA), // 羅蘭紫 Purple
    Color(0xFF1E88E5), // 海洋藍 Blue
    Color(0xFFD81B60), // 玫瑰紅 Pink
    Color(0xFF43A047), // 森林綠 Green
    Color(0xFF6D4C41), // 可可棕 Brown
    Color(0xFF00ACC1), // 青色 Cyan
    Color(0xFF5E35B1), // 深紫 Deep Purple
  ];

  /// 預設第 0 節至第 15 節時間表（全時段皆為 10 分到整點：07:10 - 23:00）
  static const List<TimetableSection> defaultSections = [
    TimetableSection(
      section: 0,
      label: '第 0 節',
      startTime: '07:10',
      endTime: '08:00',
    ),
    TimetableSection(
      section: 1,
      label: '第 1 節',
      startTime: '08:10',
      endTime: '09:00',
    ),
    TimetableSection(
      section: 2,
      label: '第 2 節',
      startTime: '09:10',
      endTime: '10:00',
    ),
    TimetableSection(
      section: 3,
      label: '第 3 節',
      startTime: '10:10',
      endTime: '11:00',
    ),
    TimetableSection(
      section: 4,
      label: '第 4 節',
      startTime: '11:10',
      endTime: '12:00',
    ),
    TimetableSection(
      section: 5,
      label: '第 5 節',
      startTime: '12:10',
      endTime: '13:00',
    ),
    TimetableSection(
      section: 6,
      label: '第 6 節',
      startTime: '13:10',
      endTime: '14:00',
    ),
    TimetableSection(
      section: 7,
      label: '第 7 節',
      startTime: '14:10',
      endTime: '15:00',
    ),
    TimetableSection(
      section: 8,
      label: '第 8 節',
      startTime: '15:10',
      endTime: '16:00',
    ),
    TimetableSection(
      section: 9,
      label: '第 9 節',
      startTime: '16:10',
      endTime: '17:00',
    ),
    TimetableSection(
      section: 10,
      label: '第 10 節',
      startTime: '17:10',
      endTime: '18:00',
    ),
    TimetableSection(
      section: 11,
      label: '第 11 節',
      startTime: '18:10',
      endTime: '19:00',
    ),
    TimetableSection(
      section: 12,
      label: '第 12 節',
      startTime: '19:10',
      endTime: '20:00',
    ),
    TimetableSection(
      section: 13,
      label: '第 13 節',
      startTime: '20:10',
      endTime: '21:00',
    ),
    TimetableSection(
      section: 14,
      label: '第 14 節',
      startTime: '21:10',
      endTime: '22:00',
    ),
  ];

  /// 依節次編號取得對應的 TimetableSection
  static TimetableSection sectionOf(int sectionNumber) {
    final index = sectionNumber.clamp(0, defaultSections.length - 1);
    return defaultSections[index];
  }

  /// 取得星期名稱 (1 -> 星期一 ... 7 -> 星期日)
  static String weekdayName(int weekday, {bool short = false}) {
    const fullNames = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    const shortNames = ['週一', '週二', '週三', '週四', '週五', '週六', '週日'];
    final index = (weekday - 1).clamp(0, 6);
    return short ? shortNames[index] : fullNames[index];
  }

  /// 橫跨節次數
  int get sectionSpan => (endSection - startSection + 1).clamp(1, 20);

  /// 格式化節次與時間描述
  String get timeDescription {
    final startSec = sectionOf(startSection);
    final endSec = sectionOf(endSection);
    if (startSection == endSection) {
      return '${weekdayName(weekday)} 第 $startSection 節 (${startSec.startTime} - ${endSec.endTime})';
    }
    return '${weekdayName(weekday)} 第 $startSection - $endSection 節 (${startSec.startTime} - ${endSec.endTime})';
  }

  /// 檢查是否與指定星期及節次區間重疊
  bool conflictsWith({
    required int targetWeekday,
    required int targetStartSection,
    required int targetEndSection,
  }) {
    if (weekday != targetWeekday) return false;
    return startSection <= targetEndSection && endSection >= targetStartSection;
  }

  Course copyWith({
    String? id,
    String? name,
    String? classroom,
    String? professor,
    int? weekday,
    int? startSection,
    int? endSection,
    int? credits,
    CourseType? type,
    Color? color,
  }) {
    return Course(
      id: id ?? this.id,
      name: name ?? this.name,
      classroom: classroom ?? this.classroom,
      professor: professor ?? this.professor,
      weekday: weekday ?? this.weekday,
      startSection: startSection ?? this.startSection,
      endSection: endSection ?? this.endSection,
      credits: credits ?? this.credits,
      type: type ?? this.type,
      color: color ?? this.color,
    );
  }

  /// 轉成 Cloud Firestore 寫入資料（不含文件 ID）
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'classroom': classroom,
      'professor': professor,
      'weekday': weekday,
      'startSection': startSection,
      'endSection': endSection,
      'credits': credits,
      'type': type.name,
      'color': color.toARGB32(),
    };
  }

  /// 從 Cloud Firestore 快照反序列化為 Course 實例
  factory Course.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot, [
    SnapshotOptions? options,
  ]) {
    final data = snapshot.data();
    return Course.fromMap(data ?? {}, id: snapshot.id);
  }

  /// 轉為通用 Map
  Map<String, dynamic> toMap() {
    final map = toFirestore();
    map['id'] = id;
    return map;
  }

  /// 從通用 Map 建立 Course 實例
  factory Course.fromMap(Map<String, dynamic> map, {required String id}) {
    final colorValue = map['color'];
    Color parsedColor = Colors.indigo;
    if (colorValue is int) {
      parsedColor = Color(colorValue);
    }

    final typeStr = map['type'] as String?;
    final parsedType = CourseType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => CourseType.required,
    );

    return Course(
      id: id,
      name: map['name'] as String? ?? '',
      classroom: map['classroom'] as String? ?? '',
      professor: map['professor'] as String? ?? '',
      weekday: (map['weekday'] as num?)?.toInt() ?? 1,
      startSection: (map['startSection'] as num?)?.toInt() ?? 1,
      endSection: (map['endSection'] as num?)?.toInt() ?? 1,
      credits: (map['credits'] as num?)?.toInt() ?? 3,
      type: parsedType,
      color: parsedColor,
    );
  }

  /// 支援 JSON 序列化
  Map<String, dynamic> toJson() => toMap();

  /// 支援 JSON 反序列化
  factory Course.fromJson(Map<String, dynamic> json, {String? id}) =>
      Course.fromMap(json, id: id ?? json['id'] as String? ?? '');
}