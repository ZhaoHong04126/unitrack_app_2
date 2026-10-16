// 課表畫面（支援週一至週五/週末彈性切換、課程新增/詳情/編輯/刪除、手機橫向滑動與桌面平鋪響應式佈局，串接 Cloud Firestore 雲端即時同步）
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/course.dart';
import '../services/course_service.dart';
import '../services/settings_service.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/app_notification.dart';

/// 課表檢視模式（手機版支援：單日時間軸清單 vs 整週網格課表）
enum TimetableViewMode {
  daily, // 單日時間軸清單
  weekly, // 整週網格課表
}

class TimetableScreen extends StatefulWidget {
  /// 外部可傳入初始課程列表（預設為空列表，呈現優雅的空課表狀態）
  final List<Course> initialCourses;

  /// 當課表內容變更時可通知外部（供日後跨頁面同步使用）
  final ValueChanged<List<Course>>? onCoursesChanged;

  /// 自訂課程資料流（供測試或外部注入使用，預設使用 CourseService().getCoursesStream()）
  final Stream<List<Course>>? coursesStream;

  const TimetableScreen({
    super.key,
    this.initialCourses = const [],
    this.onCoursesChanged,
    this.coursesStream,
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

  /// 手機端課表檢視模式（預設為單日時間軸清單）
  TimetableViewMode _mobileViewMode = TimetableViewMode.daily;

  /// 單日模式下目前選中的星期（1: 週一 ... 7: 週日，預設當天）
  late int _selectedWeekday;

  /// 手機/窄螢幕下節次列高度（56.0，適度調小讓手機直向一覽看見更多節次）
  static const double _mobileSectionRowHeight = 56.0;

  /// 桌面/平板寬螢幕下節次列高度（76.0，寬裕舒適，防止單節課卡片與時間軸溢出）
  static const double _desktopSectionRowHeight = 76.0;

  /// 桌面/平板寬螢幕左側節次/時間軸欄寬
  static const double _timeColumnWidthDesktop = 78.0;

  /// 手機/窄螢幕左側節次/時間軸欄寬（瘦身為 38.0，大幅節省橫向空間）
  static const double _timeColumnWidthMobile = 38.0;

  @override
  void initState() {
    super.initState();
    _selectedWeekday = DateTime.now().weekday;
    _courses = List<Course>.from(widget.initialCourses);
    // 若初始課程包含週六或週日，或設定開啟週末，顯示週末
    if (_courses.any((c) => c.weekday >= 6) || SettingsService().weekendTimetable) {
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
      (_showWeekend || SettingsService().weekendTimetable || _courses.any((c) => c.weekday >= 6)) ? 7 : 5;

  /// 當前課表顯示的完整節次清單（全時段完整顯示第 0 節至第 14 節）
  List<TimetableSection> get _visibleSections => Course.defaultSections;

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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
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

                      // 上課星期選擇
                      DropdownButtonFormField<int>(
                        initialValue: selectedWeekday,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: '上課星期',
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
                      const SizedBox(height: 12),

                      // 節次選擇（開始節次 至 結束節次）
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: selectedStartSection,
                              isExpanded: true,
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
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: selectedEndSection,
                              isExpanded: true,
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
                              isExpanded: true,
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
                              isExpanded: true,
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



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return StreamBuilder<List<Course>>(
      stream: widget.coursesStream ?? CourseService().getCoursesStream(),
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

        // 通知外部課程變更（若有監聽器）
        if (!listEquals(_lastCourses, currentCourses)) {
          _lastCourses = List<Course>.from(currentCourses);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _notifyChanged();
          });
        }

        final isMobile = ResponsiveLayout.isMobile(context);

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
        } else if (isMobile && _mobileViewMode == TimetableViewMode.daily) {
          // 手機版單日時間軸清單模式
          bodyContent = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 若無任何課程，顯示空課表提示橫幅
              if (currentCourses.isEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: _buildEmptyTimetableBanner(context),
                ),
                const SizedBox(height: 12),
              ] else
                const SizedBox(height: 12),

              // 星期切換 Tab 列（週一至週日，可點選切換，預設選中當天）
              _buildMobileWeekdayTabBar(
                context: context,
                currentCourses: currentCourses,
              ),
              const SizedBox(height: 8),

              // 下方單日課程清單（或該日無課的空狀態提示）
              Expanded(
                child: _buildDailyCourseListView(
                  context: context,
                  currentCourses: currentCourses,
                ),
              ),
            ],
          );
        } else {
          // 週課表模式（桌面/平板維持完整整週網格；手機若手動切換為週課表則可橫向滑動）
          bodyContent = LayoutBuilder(
            builder: (context, constraints) {
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
                          if (currentCourses.isEmpty) ...[
                            _buildEmptyTimetableBanner(context),
                            const SizedBox(height: 14),
                          ],

                          // 手機端整週一覽提示列
                          if (!isDesktopTiled)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_view_week_rounded,
                                    size: 15,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '手機整週檢視：一覽全週課表，點擊右上角可切換單日模式',
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
            titleSpacing: isMobile ? 4 : null,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        '學期課程表',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: '雲端資料即時同步',
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 4 : 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.cloud_done_rounded,
                              size: 12,
                              color: Colors.green,
                            ),
                            if (!isMobile) ...[
                              const SizedBox(width: 4),
                              const Text(
                                '雲端同步',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  isLoading
                      ? '載入中...'
                      : (currentCourses.isEmpty
                          ? (isMobile ? '尚未排定課程' : '尚未排定課程 ・ 點擊右上角按鈕即可新增')
                          : (isMobile
                              ? (_mobileViewMode == TimetableViewMode.daily
                                  ? '${Course.weekdayName(_selectedWeekday)} ・ 共 ${_courses.where((c) => c.weekday == _selectedWeekday).length} 門課程'
                                  : '共 ${currentCourses.length} 門 ・ $_totalCredits 學分')
                              : '共 ${currentCourses.length} 門課程 ・ 總計 $_totalCredits 學分')),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            actions: [
              if (isMobile) ...[
                // 手機端檢視模式切換（單日清單 vs 整週課表）
                IconButton(
                  tooltip: _mobileViewMode == TimetableViewMode.daily
                      ? '切換為整週網格模式'
                      : '切換為單日清單模式',
                  icon: Icon(
                    _mobileViewMode == TimetableViewMode.daily
                        ? Icons.calendar_view_week_rounded
                        : Icons.view_agenda_rounded,
                    color: colorScheme.primary,
                  ),
                  onPressed: () {
                    setState(() {
                      _mobileViewMode =
                          _mobileViewMode == TimetableViewMode.daily
                              ? TimetableViewMode.weekly
                              : TimetableViewMode.daily;
                    });
                  },
                ),
              ] else ...[
                // 桌面與平板寬螢幕模式：新增課程按鈕
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilledButton.icon(
                    onPressed: () => _showCourseFormDialog(),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('新增課程'),
                  ),
                ),
              ],
            ],
          ),
          body: SafeArea(child: bodyContent),
          floatingActionButton: isMobile
              ? FloatingActionButton.extended(
                  onPressed: () => _showCourseFormDialog(
                    initialWeekday: _mobileViewMode == TimetableViewMode.daily
                        ? _selectedWeekday
                        : 1,
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('新增課程'),
                )
              : null,
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



  /// 手機端星期 Tab 切換列（週一至週日，可點選切換，預設選中當天）
  Widget _buildMobileWeekdayTabBar({
    required BuildContext context,
    required List<Course> currentCourses,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final currentDay = now.weekday;

    // 計算當週星期一日期（以週一為起始日：now - (currentDay - 1) 天）
    final monday = DateTime(now.year, now.month, now.day).subtract(
      Duration(days: currentDay - 1),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: List.generate(7, (index) {
          final weekday = index + 1;
          final isSelected = weekday == _selectedWeekday;
          final isToday = weekday == currentDay;

          // 計算該星期對應的當週具體日期（月/日）
          final targetDate = DateTime(monday.year, monday.month, monday.day + index);
          final dateStr = '${targetDate.month}/${targetDate.day}';

          return Padding(
            padding: EdgeInsets.only(right: index == 6 ? 0 : 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedWeekday = weekday;
                });
              },
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary
                      : (isToday
                          ? colorScheme.primaryContainer.withValues(alpha: 0.35)
                          : colorScheme.surface),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.primary
                        : (isToday
                            ? colorScheme.primary.withValues(alpha: 0.5)
                            : colorScheme.outlineVariant
                                .withValues(alpha: 0.5)),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 第一行：星期名稱（如：週一、週三，若為今天保留小圓點）
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          Course.weekdayName(weekday, short: true),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected
                                ? colorScheme.onPrimary
                                : (isToday
                                    ? colorScheme.primary
                                    : colorScheme.onSurface),
                          ),
                        ),
                        if (isToday) ...[
                          const SizedBox(width: 4),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? colorScheme.onPrimary
                                  : colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    // 第二行：對應日期（如：10/12、10/14）
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? colorScheme.onPrimary.withValues(alpha: 0.9)
                            : (isToday
                                ? colorScheme.primary.withValues(alpha: 0.85)
                                : colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.75)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// 手機端單日課程清單視圖
  Widget _buildDailyCourseListView({
    required BuildContext context,
    required List<Course> currentCourses,
  }) {
    final dayCourses = currentCourses
        .where((c) => c.weekday == _selectedWeekday)
        .toList()
      ..sort((a, b) => a.startSection.compareTo(b.startSection));

    if (dayCourses.isEmpty) {
      return _buildDailyEmptyState(context, _selectedWeekday);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
      itemCount: dayCourses.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final course = dayCourses[index];
        return _buildDailyCourseCard(context, course);
      },
    );
  }

  /// 手機端單日無課空狀態提示
  Widget _buildDailyEmptyState(BuildContext context, int weekday) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isToday = weekday == DateTime.now().weekday;
    final dayName = Course.weekdayName(weekday);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isToday
                    ? Icons.beach_access_rounded
                    : Icons.event_available_rounded,
                size: 36,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '$dayName 無排定課程',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isToday
                  ? '今天沒有安排任何課程，好好放鬆、自主學習或充電吧！'
                  : '這一天沒有排課，享受自由充實的時間安排。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              onPressed: () => _showCourseFormDialog(initialWeekday: weekday),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('新增 $dayName 課程'),
            ),
          ],
        ),
      ),
    );
  }

  /// 手機端單日課程卡片
  Widget _buildDailyCourseCard(BuildContext context, Course course) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final startSec = Course.sectionOf(course.startSection);
    final endSec = Course.sectionOf(course.endSection);
    final sectionText = course.startSection == course.endSection
        ? '第 ${course.startSection} 節'
        : '第 ${course.startSection}-${course.endSection} 節';
    final timeText = '${startSec.startTime} - ${endSec.endTime}';

    return Material(
      color: colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showCourseDetailDialog(course),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 左側代表色飾條
              Container(
                width: 5,
                color: course.color,
              ),
              // 卡片主要內容
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 頂部時段標籤與必選修 Badge
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: course.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              sectionText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: course.color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 13,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    timeText,
                                    style:
                                        theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              course.type.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer
                                  .withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${course.credits}學分',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 課程名稱
                      Text(
                        course.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // 教室與授課教師
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 15,
                            color: course.color,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              course.classroom.isNotEmpty
                                  ? course.classroom
                                  : '未定教室',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.person_outline_rounded,
                            size: 15,
                            color: course.color,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              course.professor.isNotEmpty
                                  ? course.professor
                                  : '未定教師',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: colorScheme.outlineVariant,
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
    );
  }

  /// 響應式課表外框：寬度彈性適配，手機直立一覽完整顯示週一至週五（或整週），無需左右滑動
  Widget _buildResponsiveTimetableContainer({
    required BuildContext context,
    required double availableWidth,
    required bool isDesktopTiled,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCompact = !isDesktopTiled;
    final timeColWidth =
        isCompact ? _timeColumnWidthMobile : _timeColumnWidthDesktop;
    final sectionRowHeight =
        isCompact ? _mobileSectionRowHeight : _desktopSectionRowHeight;

    final timetableGrid = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
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
          _buildWeekdayHeaderRow(
            context,
            isCompact: isCompact,
            timeColWidth: timeColWidth,
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
          // 表格內容區：左側節次時間軸 + 各星期課程欄位
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 縱軸：節次與時間區段（支援動態過濾無課早鳥與夜間節次）
              SizedBox(
                width: timeColWidth,
                child: _buildTimeAxisColumn(
                  context,
                  isCompact: isCompact,
                  sectionRowHeight: sectionRowHeight,
                ),
              ),
              // 橫軸各星期欄位（使用 Expanded 自動等比例平分剩餘全部可用寬度）
              ...List.generate(_visibleDayCount, (index) {
                final weekday = index + 1;
                return Expanded(
                  child: _buildDayColumn(
                    context,
                    weekday,
                    isCompact: isCompact,
                    sectionRowHeight: sectionRowHeight,
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );

    return timetableGrid;
  }

  /// 表頭：左上角「節次 / 時間」與週一至週五（或週日）欄位標題
  Widget _buildWeekdayHeaderRow(
    BuildContext context, {
    required bool isCompact,
    required double timeColWidth,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentWeekday = DateTime.now().weekday;

    return Container(
      height: isCompact ? 42.0 : 48.0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      child: Row(
        children: [
          SizedBox(
            width: timeColWidth,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    isCompact ? '節次' : '節次 / 時間',
                    style: TextStyle(
                      fontSize: isCompact ? 11 : 12,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
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

            // 窄欄模式下星期標題精簡化：
            // 7 天全週顯示為「一、二...」，5 天平日顯示為「週一、週二...」
            final weekdayText = isCompact
                ? (_visibleDayCount == 7
                    ? Course.weekdayName(weekday, short: true).replaceAll('週', '')
                    : Course.weekdayName(weekday, short: true))
                : Course.weekdayName(weekday);

            return Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: isCompact ? 2 : 4),
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
                            weekdayText,
                            style: TextStyle(
                              fontSize: isCompact ? 12 : 13,
                              fontWeight:
                                  isToday ? FontWeight.bold : FontWeight.w600,
                              color: isToday
                                  ? colorScheme.primary
                                  : colorScheme.onSurface,
                            ),
                          ),
                          if (isToday) ...[
                            SizedBox(width: isCompact ? 2 : 4),
                            if (isCompact)
                              // 緊湊模式下使用小圓點標示今日，避免膠囊文字撐爆欄寬
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              )
                            else
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
                    if (dayCourseCount > 0) ...[
                      const SizedBox(height: 1),
                      if (isCompact)
                        // 緊湊模式下將課程數標籤改為小圓點，避免吃掉縱深與寬度
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: isToday
                                    ? colorScheme.primary
                                    : colorScheme.outline,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        )
                      else
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
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 左側縱軸：節次與時間欄（窄螢幕大幅瘦身為純節次數字 + 垂直微型時間排版）
  Widget _buildTimeAxisColumn(
    BuildContext context, {
    required bool isCompact,
    required double sectionRowHeight,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visibleSections = _visibleSections;
    final lastSectionNumber = visibleSections.last.section;

    return Column(
      children: visibleSections.map((sec) {
        final isLast = sec.section == lastSectionNumber;
        return Container(
          height: sectionRowHeight,
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 1 : 6,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest.withValues(alpha: 0.6),
            border: Border(
              bottom: !isLast
                  ? BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                    )
                  : BorderSide.none,
            ),
          ),
          child: Center(
            child: isCompact
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 節次數字精簡化：僅顯示節次數字（如 0、1、2...）
                        Container(
                          width: 18,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer
                                .withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            sec.section.toString(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        // 時間縮小並改以極小字體垂直排版
                        Text(
                          sec.startTime,
                          style: TextStyle(
                            fontSize: 8,
                            height: 1.0,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          sec.endTime,
                          style: TextStyle(
                            fontSize: 7.5,
                            height: 1.0,
                            color: colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer
                                .withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              sec.label,
                              maxLines: 1,
                              softWrap: false,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          sec.startTime,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          sec.endTime,
                          style: TextStyle(
                            fontSize: 9.5,
                            color: colorScheme.outline,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      }).toList(),
    );
  }

  /// 建構單一星期的節次欄位（支援跨節次合併課程卡片）
  Widget _buildDayColumn(
    BuildContext context,
    int weekday, {
    required bool isCompact,
    required double sectionRowHeight,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final visibleSections = _visibleSections;
    final minSection = visibleSections.first.section;
    final maxSection = visibleSections.last.section;
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
        final totalHeight = span * sectionRowHeight;
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
            padding: EdgeInsets.all(isCompact ? 2 : 4),
            child: _CourseSlotCard(
              course: course,
              span: span,
              isCompact: isCompact,
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
              height: sectionRowHeight,
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

/// 課表內的課程卡片元件（依欄寬自動切換緊湊防溢出模式與標準模式）
class _CourseSlotCard extends StatefulWidget {
  final Course course;
  final int span;
  final bool isCompact;
  final VoidCallback onTap;

  const _CourseSlotCard({
    required this.course,
    required this.span,
    this.isCompact = false,
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
    final isCompact = widget.isCompact;
    final span = widget.span;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: baseColor.withValues(alpha: _isHovered ? 0.22 : 0.14),
          borderRadius: BorderRadius.circular(isCompact ? 6 : 10),
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
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 左側色條識別（窄欄下縮至 3.0px）
                Container(
                  width: isCompact ? 3.0 : 4.5,
                  color: baseColor,
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 3.5 : 7,
                      vertical: isCompact ? 2.5 : 5,
                    ),
                    child: isCompact
                        ? _buildCompactContent(context, course, span, baseColor)
                        : _buildStandardContent(
                            context,
                            course,
                            span,
                            baseColor,
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

  /// 窄欄/手機緊湊模式排版（防文字溢出、maxLines: 2、字體 11sp）
  Widget _buildCompactContent(
    BuildContext context,
    Course course,
    int span,
    Color baseColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 課程名稱（maxLines: 2, ellipsis, 11sp）
        Flexible(
          child: Text(
            course.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              height: 1.15,
              color: Color.alphaBlend(
                Colors.black.withValues(alpha: 0.55),
                baseColor,
              ),
            ),
          ),
        ),
        // 教室（單節或跨節課若有教室則顯示，防溢出）
        if (course.classroom.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 1.0),
            child: Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 9,
                  color: baseColor,
                ),
                const SizedBox(width: 1),
                Expanded(
                  child: Text(
                    course.classroom,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: Color.alphaBlend(
                        Colors.black.withValues(alpha: 0.4),
                        baseColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        // 若跨 3 節以上且高度充足時，可顯示教師
        if (span >= 3 && course.professor.isNotEmpty)
          Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 9,
                color: baseColor.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 1),
              Expanded(
                child: Text(
                  course.professor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    color: Color.alphaBlend(
                      Colors.black.withValues(alpha: 0.35),
                      baseColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// 寬螢幕/桌面標準排版（防單節課溢出）
  Widget _buildStandardContent(
    BuildContext context,
    Course course,
    int span,
    Color baseColor,
  ) {
    final showProfessor = span > 1
        ? course.professor.isNotEmpty
        : (course.classroom.isEmpty && course.professor.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (span > 1) ...[
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
                const SizedBox(height: 3),
              ],
              Text(
                course.name,
                maxLines: span > 1 ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  height: 1.15,
                  color: Color.alphaBlend(
                    Colors.black.withValues(alpha: 0.45),
                    baseColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (course.classroom.isNotEmpty)
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
            if (showProfessor) ...[
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
          ],
        ),
      ],
    );
  }
}