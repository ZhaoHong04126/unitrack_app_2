// 課表畫面（支援週一至週五/週末彈性切換、課程新增/詳情/編輯/刪除、手機橫向滑動與桌面平鋪響應式佈局，串接 Cloud Firestore 雲端即時同步）
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/course.dart';
import '../services/course_service.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/app_notification.dart';

class TimetableScreen extends StatefulWidget {
  /// 外部可傳入初始課程列表（預設為空列表，呈現優雅的空課表狀態）
  final List<Course> initialCourses;

  /// 當課表內容變更時可通知外部（供日後跨頁面同步使用）
  final ValueChanged<List<Course>>? onCoursesChanged;

  const TimetableScreen({
    super.key,
    this.initialCourses = const [],
    this.onCoursesChanged,
  });

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  /// 課程狀態快取列表（由 Firestore 串流即時更新）
  List<Course> _courses = [];
  List<Course>? _lastCourses;

  /// 是否手動切換顯示週末（週六、週日）
  bool _showWeekend = false;

  /// 每節課列的高度（足夠在單節高度內完整呈現課程名稱、教室代碼與授課教師）
  static const double _sectionRowHeight = 88.0;

  /// 左側節次/時間軸欄寬
  static const double _timeColumnWidth = 82.0;

  /// 手機端單一星期欄位的最小寬度（觸發橫向滑動檢視）
  static const double _mobileMinDayColumnWidth = 116.0;

  @override
  void initState() {
    super.initState();
    _courses = List<Course>.from(widget.initialCourses);
    // 若初始課程包含週六或週日，自動開啟週末顯示
    if (_courses.any((c) => c.weekday >= 6)) {
      _showWeekend = true;
    }
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  int get _visibleDayCount =>
      (_showWeekend || _courses.any((c) => c.weekday >= 6)) ? 7 : 5;

  int get _totalCredits =>
      _courses.fold<int>(0, (sum, course) => sum + course.credits);

  void _notifyChanged() {
    widget.onCoursesChanged?.call(List<Course>.unmodifiable(_courses));
  }

  /// 查詢特定星期與節次所屬的課程
  Course? _findCourseAt(int weekday, int section) {
    for (final course in _courses) {
      if (course.weekday == weekday &&
          course.startSection <= section &&
          course.endSection >= section) {
        return course;
      }
    }
    return null;
  }

  /// 檢查指定星期與節次範圍是否與現有課程衝堂（可排除正在編輯的課程 ID）
  Course? _findConflictCourse({
    required int weekday,
    required int startSection,
    required int endSection,
    String? excludeCourseId,
  }) {
    for (final course in _courses) {
      if (excludeCourseId != null && course.id == excludeCourseId) continue;
      if (course.conflictsWith(
        targetWeekday: weekday,
        targetStartSection: startSection,
        targetEndSection: endSection,
      )) {
        return course;
      }
    }
    return null;
  }

  /// 點擊新增課程按鈕或編輯按鈕：彈出 AlertDialog 新增（或編輯）課程
  Future<void> _showCourseFormDialog({
    int initialWeekday = 1,
    int initialSection = 1,
    Course? existingCourse,
  }) async {
    final isEditing = existingCourse != null;
    final nameController = TextEditingController(
      text: existingCourse?.name ?? '',
    );
    final classroomController = TextEditingController(
      text: existingCourse?.classroom ?? '',
    );
    final professorController = TextEditingController(
      text: existingCourse?.professor ?? '',
    );

    int selectedWeekday = existingCourse?.weekday ?? initialWeekday;
    int selectedStartSection = existingCourse?.startSection ?? initialSection;
    int selectedEndSection = existingCourse?.endSection ?? initialSection;
    int selectedCredits = existingCourse?.credits ?? 3;
    CourseType selectedType = existingCourse?.type ?? CourseType.required;
    Color selectedColor =
        existingCourse?.color ??
        Course.colorPalette[_courses.length % Course.colorPalette.length];

    String? errorMessage;

    final result = await showDialog<Course>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colorScheme = theme.colorScheme;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: selectedColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEditing ? Icons.edit_calendar_rounded : Icons.add_box_rounded,
                      color: selectedColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? '編輯課程' : '新增課程',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${Course.weekdayName(selectedWeekday)} ・ 第 $selectedStartSection 節${selectedEndSection > selectedStartSection ? ' - 第 $selectedEndSection 節' : ''}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: 18,
                                color: colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorMessage!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onErrorContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      // 課程名稱
                      TextField(
                        controller: nameController,
                        autofocus: !isEditing,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: '課程名稱 *',
                          hintText: '例如：資料結構、微積分(一)',
                          prefixIcon: const Icon(Icons.menu_book_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          isDense: true,
                        ),
                        onChanged: (_) {
                          if (errorMessage != null) {
                            setDialogState(() => errorMessage = null);
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // 教室代碼與授課教師
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: classroomController,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: '教室代碼',
                                hintText: '例如：工 401',
                                prefixIcon: const Icon(
                                  Icons.location_on_outlined,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: professorController,
                              textInputAction: TextInputAction.done,
                              decoration: InputDecoration(
                                labelText: '授課教師',
                                hintText: '例如：陳大明 教授',
                                prefixIcon: const Icon(Icons.person_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 星期與節次選擇
                      Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: DropdownButtonFormField<int>(
                              initialValue: selectedWeekday,
                              decoration: InputDecoration(
                                labelText: '星期',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                              items: List.generate(7, (index) {
                                final day = index + 1;
                                return DropdownMenuItem<int>(
                                  value: day,
                                  child: Text(Course.weekdayName(day)),
                                );
                              }),
                              onChanged: (val) {
                                if (val == null) return;
                                setDialogState(() {
                                  selectedWeekday = val;
                                  errorMessage = null;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<int>(
                              initialValue: selectedStartSection,
                              decoration: InputDecoration(
                                labelText: '開始節次',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 12,
                                ),
                              ),
                              items: Course.defaultSections.map((sec) {
                                return DropdownMenuItem<int>(
                                  value: sec.section,
                                  child: Text('第 ${sec.section} 節'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val == null) return;
                                setDialogState(() {
                                  selectedStartSection = val;
                                  if (selectedEndSection < val) {
                                    selectedEndSection = val;
                                  }
                                  errorMessage = null;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<int>(
                              initialValue: selectedEndSection,
                              decoration: InputDecoration(
                                labelText: '結束節次',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 12,
                                ),
                              ),
                              items: Course.defaultSections
                                  .where(
                                    (sec) =>
                                        sec.section >= selectedStartSection,
                                  )
                                  .map((sec) {
                                    return DropdownMenuItem<int>(
                                      value: sec.section,
                                      child: Text('第 ${sec.section} 節'),
                                    );
                                  })
                                  .toList(),
                              onChanged: (val) {
                                if (val == null) return;
                                setDialogState(() {
                                  selectedEndSection = val;
                                  errorMessage = null;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 必選修類別與學分數
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<CourseType>(
                              initialValue: selectedType,
                              decoration: InputDecoration(
                                labelText: '課程類別',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                              items: CourseType.values.map((type) {
                                return DropdownMenuItem<CourseType>(
                                  value: type,
                                  child: Text(type.label),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() => selectedType = val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: selectedCredits,
                              decoration: InputDecoration(
                                labelText: '學分數',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                              items: List.generate(7, (idx) {
                                return DropdownMenuItem<int>(
                                  value: idx,
                                  child: Text('$idx 學分'),
                                );
                              }),
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() => selectedCredits = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 課程卡片背景色選擇
                      Text(
                        '卡片代表色',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: Course.colorPalette.map((paletteColor) {
                          final isSelected =
                              paletteColor.toARGB32() ==
                              selectedColor.toARGB32();
                          return InkWell(
                            onTap: () {
                              setDialogState(
                                () => selectedColor = paletteColor,
                              );
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: paletteColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? colorScheme.onSurface
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: paletteColor.withValues(
                                            alpha: 0.4,
                                          ),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                FilledButton.icon(
                  icon: Icon(
                    isEditing ? Icons.check_rounded : Icons.add_rounded,
                    size: 18,
                  ),
                  label: Text(isEditing ? '儲存變更' : '加入課表'),
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      setDialogState(() {
                        errorMessage = '請輸入課程名稱';
                      });
                      return;
                    }

                    final conflict = _findConflictCourse(
                      weekday: selectedWeekday,
                      startSection: selectedStartSection,
                      endSection: selectedEndSection,
                      excludeCourseId: existingCourse?.id,
                    );
                    if (conflict != null) {
                      setDialogState(() {
                        errorMessage =
                            '時段衝突：與「${conflict.name}」(第 ${conflict.startSection}-${conflict.endSection} 節) 重疊';
                      });
                      return;
                    }

                    final classroom = classroomController.text.trim();
                    final professor = professorController.text.trim();

                    final newCourse = Course(
                      id:
                          existingCourse?.id ??
                          DateTime.now().microsecondsSinceEpoch.toString(),
                      name: name,
                      classroom: classroom.isEmpty ? '未定教室' : classroom,
                      professor: professor.isEmpty ? '未定教師' : professor,
                      weekday: selectedWeekday,
                      startSection: selectedStartSection,
                      endSection: selectedEndSection,
                      credits: selectedCredits,
                      type: selectedType,
                      color: selectedColor,
                    );

                    Navigator.of(dialogContext).pop(newCourse);
                  },
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    classroomController.dispose();
    professorController.dispose();

    if (result != null && mounted) {
      try {
        await CourseService().saveCourse(result);
        if (mounted) {
          AppNotification.show(
            context,
            title: isEditing ? '課程更新成功' : '新增課程成功',
            message: '已將「${result.name}」同步儲存至雲端課表',
            icon: Icons.cloud_done_rounded,
          );
        }
      } catch (e) {
        if (mounted) {
          AppNotification.show(
            context,
            title: '儲存失敗',
            message: '無法同步儲存至雲端資料庫：${e.toString().replaceFirst("Exception: ", "")}',
            icon: Icons.error_outline,
          );
        }
      }
    }
  }

  /// 點擊已有課程卡片：彈出詳細資訊 AlertDialog，並可編輯或刪除課程
  Future<void> _showCourseDetailDialog(Course course) async {
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colorScheme = theme.colorScheme;

        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: course.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.school_rounded,
                  color: course.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: course.color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            course.type.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: course.color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${course.credits} 學分',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      course.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 320, maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.45,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailInfoRow(
                    context: dialogContext,
                    icon: Icons.access_time_rounded,
                    label: '上課時段',
                    value: course.timeDescription,
                    accentColor: course.color,
                  ),
                  const Divider(height: 20),
                  _buildDetailInfoRow(
                    context: dialogContext,
                    icon: Icons.location_on_outlined,
                    label: '教室代碼',
                    value: course.classroom.isNotEmpty
                        ? course.classroom
                        : '未定教室',
                    accentColor: course.color,
                  ),
                  const Divider(height: 20),
                  _buildDetailInfoRow(
                    context: dialogContext,
                    icon: Icons.person_outline_rounded,
                    label: '授課教師',
                    value: course.professor.isNotEmpty
                        ? course.professor
                        : '未定教師',
                    accentColor: course.color,
                  ),
                ],
              ),
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop('delete'),
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.error,
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('刪除課程'),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('關閉'),
                ),
                const SizedBox(width: 6),
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(dialogContext).pop('edit'),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('編輯'),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (action == 'delete') {
      _deleteCourse(course);
    } else if (action == 'edit') {
      await _showCourseFormDialog(existingCourse: course);
    }
  }

  Widget _buildDetailInfoRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color accentColor,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: accentColor),
        const SizedBox(width: 10),
        SizedBox(
          width: 68,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  /// 刪除課程並提供雲端復原機制
  Future<void> _deleteCourse(Course course) async {
    try {
      await CourseService().deleteCourse(course.id);
      if (mounted) {
        AppNotification.show(
          context,
          title: '課程已刪除',
          message: '已自雲端課表移除「${course.name}」',
          icon: Icons.delete_outline_rounded,
          actionLabel: '復原',
          onAction: () async {
            try {
              await CourseService().saveCourse(course);
            } catch (e) {
              if (mounted) {
                AppNotification.show(
                  context,
                  title: '復原失敗',
                  message: e.toString().replaceFirst('Exception: ', ''),
                  icon: Icons.error_outline,
                );
              }
            }
          },
        );
      }
    } catch (e) {
      if (mounted) {
        AppNotification.show(
          context,
          title: '刪除失敗',
          message: '無法自雲端刪除課程：${e.toString().replaceFirst("Exception: ", "")}',
          icon: Icons.error_outline,
        );
      }
    }
  }

  /// 清空所有課程確認對話框
  Future<void> _confirmClearAllCourses() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空課表'),
        content: const Text('確定要移除雲端課表中的所有課程嗎？此動作將同步自雲端資料庫刪除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('確定清空'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await CourseService().clearAllCourses();
        if (mounted) {
          AppNotification.show(
            context,
            title: '課表已清空',
            message: '已成功移除所有雲端課程。',
            icon: Icons.delete_sweep_rounded,
          );
        }
      } catch (e) {
        if (mounted) {
          AppNotification.show(
            context,
            title: '清空失敗',
            message: '無法清空雲端課表：${e.toString().replaceFirst("Exception: ", "")}',
            icon: Icons.error_outline,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return StreamBuilder<List<Course>>(
      stream: CourseService().getCoursesStream(),
      initialData:
          widget.initialCourses.isNotEmpty ? widget.initialCourses : null,
      builder: (context, snapshot) {
        final isLoading =
            snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;
        final hasError = snapshot.hasError;
        final currentCourses =
            snapshot.data ?? (snapshot.hasError ? [] : _courses);
        _courses = currentCourses;

        // 若有週末課程且尚未開啟，自動切換
        final effectiveShowWeekend =
            _showWeekend || currentCourses.any((c) => c.weekday >= 6);

        // 通知外部課程變更（若有監聽器）
        if (!listEquals(_lastCourses, currentCourses)) {
          _lastCourses = List<Course>.from(currentCourses);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _notifyChanged();
          });
        }

        Widget bodyContent;
        if (isLoading) {
          bodyContent = const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  '正在同步雲端課表資料...',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        } else if (hasError) {
          bodyContent = Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 52,
                    color: colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '雲端課表載入失敗',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}'.replaceFirst('Exception: ', ''),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.tonalIcon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('重新整理'),
                  ),
                ],
              ),
            ),
          );
        } else {
          bodyContent = LayoutBuilder(
            builder: (context, constraints) {
              // 桌面或寬視窗 (>= 680px) 直接平鋪完整週課表；窄視窗 (< 680px) 啟用橫向滑動檢視
              final isDesktopTiled = constraints.maxWidth >= 680;
              final horizontalPadding = isDesktopTiled ? 24.0 : 12.0;

              return Scrollbar(
                controller: _verticalScrollController,
                thumbVisibility:
                    ResponsiveLayout.isDesktopOrWebPlatform(context),
                child: SingleChildScrollView(
                  controller: _verticalScrollController,
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    16,
                    horizontalPadding,
                    28,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: Breakpoints.desktopMaxContentWidth,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 頂部統計與操作提示列（空列表時呈現優雅的空課表狀態）
                          if (currentCourses.isEmpty)
                            _buildEmptyTimetableBanner(context)
                          else
                            _buildCourseSummaryBar(context),
                          const SizedBox(height: 14),

                          // 手機端橫向滑動提示列
                          if (!isDesktopTiled)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.swipe_rounded,
                                    size: 15,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '手機檢視模式：可左右滑動瀏覽完整週課表',
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // 課表主體（依視窗寬度自動切換「平鋪完整週課表」或「橫向滑動課表」）
                          _buildResponsiveTimetableContainer(
                            context: context,
                            availableWidth:
                                constraints.maxWidth - (horizontalPadding * 2),
                            isDesktopTiled: isDesktopTiled,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }

        return Scaffold(
          backgroundColor: colorScheme.surfaceContainerLowest,
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 2,
            backgroundColor: colorScheme.surface,
            leading: ResponsiveLayout.buildDrawerLeading(context),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '學期課程表',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_done_rounded,
                            size: 12,
                            color: Colors.green,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '雲端同步',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Text(
                  isLoading
                      ? '載入中...'
                      : (currentCourses.isEmpty
                          ? '尚未排定課程 ・ 點擊右上角按鈕即可新增'
                          : '共 ${currentCourses.length} 門課程 ・ 總計 $_totalCredits 學分'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            actions: [
              // 週末切換開關（週一至週五 / 週一至週日）
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: FilterChip(
                  selected: effectiveShowWeekend,
                  showCheckmark: false,
                  avatar: Icon(
                    effectiveShowWeekend
                        ? Icons.date_range_rounded
                        : Icons.view_week_outlined,
                    size: 16,
                    color: effectiveShowWeekend
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                  label: Text(effectiveShowWeekend ? '含週末 (7天)' : '週一至週五'),
                  onSelected: (val) {
                    setState(() {
                      _showWeekend = val;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              if (currentCourses.isNotEmpty)
                IconButton(
                  tooltip: '清空課表',
                  onPressed: _confirmClearAllCourses,
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton.icon(
                  onPressed: () => _showCourseFormDialog(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('新增課程'),
                ),
              ),
            ],
          ),
          body: SafeArea(child: bodyContent),
        );
      },
    );
  }

  /// 優雅的空課表狀態橫幅（預設無課程時顯示，引導使用者點擊按鈕新增）
  Widget _buildEmptyTimetableBanner(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.calendar_view_week_rounded,
              size: 28,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '目前課表尚無排定課程',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '點擊右上角「新增課程」或右側「開始排課」按鈕，開始規劃本學期課表。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonalIcon(
            onPressed: () => _showCourseFormDialog(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('開始排課'),
          ),
        ],
      ),
    );
  }

  /// 已有課程時的頂部學分與課程類別統計列
  Widget _buildCourseSummaryBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final requiredCredits = _courses
        .where((c) => c.type == CourseType.required)
        .fold<int>(0, (s, c) => s + c.credits);
    final electiveCredits = _courses
        .where((c) => c.type == CourseType.elective)
        .fold<int>(0, (s, c) => s + c.credits);
    final generalCredits = _courses
        .where((c) => c.type == CourseType.general)
        .fold<int>(0, (s, c) => s + c.credits);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSummaryChip(
                context,
                label: '總課程',
                value: '${_courses.length} 門',
                color: colorScheme.primary,
              ),
              const SizedBox(width: 10),
              _buildSummaryChip(
                context,
                label: '總學分',
                value: '$_totalCredits 學分',
                color: Colors.indigo,
              ),
              const SizedBox(width: 10),
              _buildSummaryChip(
                context,
                label: '必修 / 選修 / 通識',
                value: '$requiredCredits / $electiveCredits / $generalCredits',
                color: Colors.teal,
              ),
            ],
          ),
          Text(
            '💡 點擊課程卡片可查看詳細資訊、編輯或刪除',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label：',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// 響應式課表外框：桌面/Web 平鋪完整週課表，手機端支援橫向滑動
  Widget _buildResponsiveTimetableContainer({
    required BuildContext context,
    required double availableWidth,
    required bool isDesktopTiled,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final clampedAvailableWidth = math.max(
      availableWidth,
      320.0,
    ).clamp(320.0, Breakpoints.desktopMaxContentWidth);

    final minRequiredWidth =
        _timeColumnWidth + (_visibleDayCount * _mobileMinDayColumnWidth) + 2.0;

    final tableWidth = isDesktopTiled
        ? clampedAvailableWidth
        : math.max(clampedAvailableWidth, minRequiredWidth);

    final timetableGrid = Container(
      width: tableWidth,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 表頭列：星期一 ~ 星期五（或星期日）
          _buildWeekdayHeaderRow(context),
          Divider(
            height: 1,
            thickness: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
          // 表格內容區：左側節次時間軸 + 各星期課程欄位
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 縱軸：節次與時間區段（第 0 節 07:10 ~ 第 15 節 23:00）
              SizedBox(
                width: _timeColumnWidth,
                child: _buildTimeAxisColumn(context),
              ),
              // 橫軸各星期欄位（使用 Expanded 自動扣除邊框後等比例平鋪）
              ...List.generate(_visibleDayCount, (index) {
                final weekday = index + 1;
                return Expanded(
                  child: _buildDayColumn(context, weekday),
                );
              }),
            ],
          ),
        ],
      ),
    );

    if (isDesktopTiled) {
      return timetableGrid;
    }

    return Scrollbar(
      controller: _horizontalScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _horizontalScrollController,
        scrollDirection: Axis.horizontal,
        child: timetableGrid,
      ),
    );
  }

  /// 表頭：左上角「節次 / 星期」與週一至週五（或週日）欄位標題
  Widget _buildWeekdayHeaderRow(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentWeekday = DateTime.now().weekday;

    return Container(
      height: 50,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      child: Row(
        children: [
          SizedBox(
            width: _timeColumnWidth,
            child: Center(
              child: Text(
                '節次 / 時間',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          ...List.generate(_visibleDayCount, (index) {
            final weekday = index + 1;
            final isToday = weekday == currentWeekday;
            final dayCourseCount = _courses
                .where((c) => c.weekday == weekday)
                .length;

            return Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isToday
                      ? colorScheme.primaryContainer.withValues(alpha: 0.45)
                      : null,
                  border: Border(
                    left: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                    ),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            Course.weekdayName(weekday),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isToday
                                  ? colorScheme.primary
                                  : colorScheme.onSurface,
                            ),
                          ),
                          if (isToday) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '今日',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (dayCourseCount > 0)
                      Text(
                        '$dayCourseCount 門課',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: isToday
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 左側縱軸：第 0 節至第 15 節（全時段 10 分到整點：07:10 - 23:00）
  Widget _buildTimeAxisColumn(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final lastSectionNumber = Course.defaultSections.last.section;

    return Column(
      children: Course.defaultSections.map((sec) {
        return Container(
          height: _sectionRowHeight,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest.withValues(alpha: 0.6),
            border: Border(
              bottom: sec.section < lastSectionNumber
                  ? BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                    )
                  : BorderSide.none,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  sec.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                sec.startTime,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                sec.endTime,
                style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.outline,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// 建構單一星期的節次欄位（支援第 0 節至第 15 節跨節次合併課程卡片）
  Widget _buildDayColumn(BuildContext context, int weekday) {
    final colorScheme = Theme.of(context).colorScheme;
    final minSection = Course.defaultSections.first.section;
    final maxSection = Course.defaultSections.last.section;
    final List<Widget> slots = [];

    int currentSection = minSection;
    while (currentSection <= maxSection) {
      final course = _findCourseAt(weekday, currentSection);

      if (course != null) {
        final effectiveEnd = course.endSection.clamp(
          currentSection,
          maxSection,
        );
        final span = effectiveEnd - currentSection + 1;
        final totalHeight = span * _sectionRowHeight;
        final isLastRow = effectiveEnd == maxSection;

        slots.add(
          Container(
            height: totalHeight,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                ),
                bottom: isLastRow
                    ? BorderSide.none
                    : BorderSide(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.45,
                        ),
                      ),
              ),
            ),
            padding: const EdgeInsets.all(4),
            child: _CourseSlotCard(
              course: course,
              span: span,
              onTap: () => _showCourseDetailDialog(course),
            ),
          ),
        );

        currentSection = effectiveEnd + 1;
      } else {
        final sectionIndex = currentSection;
        final isLastRow = sectionIndex == maxSection;

        slots.add(
          InkWell(
            onTap: () => _showCourseFormDialog(
              initialWeekday: weekday,
              initialSection: sectionIndex,
            ),
            child: Container(
              height: _sectionRowHeight,
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                  ),
                  bottom: !isLastRow
                      ? BorderSide(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.45,
                          ),
                        )
                      : BorderSide.none,
                ),
              ),
            ),
          ),
        );

        currentSection++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: slots,
    );
  }
}

/// 課表內的課程卡片元件（呈現課程名稱、教室代碼、授課教師，並依課程代表色區分背景）
class _CourseSlotCard extends StatefulWidget {
  final Course course;
  final int span;
  final VoidCallback onTap;

  const _CourseSlotCard({
    required this.course,
    required this.span,
    required this.onTap,
  });

  @override
  State<_CourseSlotCard> createState() => _CourseSlotCardState();
}

class _CourseSlotCardState extends State<_CourseSlotCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final baseColor = course.color;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: baseColor.withValues(alpha: _isHovered ? 0.22 : 0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: baseColor.withValues(alpha: _isHovered ? 0.8 : 0.42),
            width: _isHovered ? 1.5 : 1.0,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: baseColor.withValues(alpha: 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: widget.onTap,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 左側色條識別
                Container(
                  width: 4.5,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(9),
                      bottomLeft: Radius.circular(9),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 5,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 課程名稱与跨節標籤
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.span > 1) ...[
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: baseColor.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      course.type.label,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: baseColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '第 ${course.startSection}-${course.endSection} 節',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: baseColor.withValues(
                                          alpha: 0.85,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                            ],
                            Text(
                              course.name,
                              maxLines: widget.span > 1 ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                                color: Color.alphaBlend(
                                  Colors.black.withValues(alpha: 0.45),
                                  baseColor,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // 教室代碼與授課教師
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 11,
                                  color: baseColor,
                                ),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Text(
                                    course.classroom,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color.alphaBlend(
                                        Colors.black.withValues(alpha: 0.35),
                                        baseColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 1),
                            Row(
                              children: [
                                Icon(
                                  Icons.person_outline_rounded,
                                  size: 11,
                                  color: baseColor.withValues(alpha: 0.85),
                                ),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Text(
                                    course.professor,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: Color.alphaBlend(
                                        Colors.black.withValues(alpha: 0.3),
                                        baseColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}