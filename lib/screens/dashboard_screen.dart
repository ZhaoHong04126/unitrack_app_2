// 主畫面 / 首頁（支援 Android 單欄直式與 Web / Windows 雙欄多格響應式排版，串接今日課程動態追蹤與待辦管理）
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/course.dart';
import '../services/auth_service.dart';
import '../services/course_service.dart';
import '../widgets/hoverable_card.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/app_notification.dart';
import 'timetable_screen.dart';
import 'calendar_screen.dart';
import 'graduation_screen.dart';
import 'expense_screen.dart';

class DashboardScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateToTab;

  /// 外部可傳入的動態資料參數（預設為空值或空集合，供日後串接真實 API 或單元測試使用）
  final String userName;
  final String semesterLabel;
  final String nextCourseTimeLabel;
  final String weekdayLabel;
  final String nextCourseTitle;
  final String nextCourseLocation;
  final String todayExpenseText;
  final String creditProgressText;
  final List<TodoItem> initialTodoItems;
  final Stream<List<Course>>? coursesStream;
  final DateTime? customNow;

  const DashboardScreen({
    super.key,
    this.onNavigateToTab,
    this.userName = '',
    this.semesterLabel = '',
    this.nextCourseTimeLabel = '',
    this.weekdayLabel = '',
    this.nextCourseTitle = '',
    this.nextCourseLocation = '',
    this.todayExpenseText = '',
    this.creditProgressText = '',
    this.initialTodoItems = const [],
    this.coursesStream,
    this.customNow,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ScrollController _scrollController = ScrollController();

  late String _semesterLabel = widget.semesterLabel.isNotEmpty
      ? widget.semesterLabel
      : '113學年度 第 1 學期';

  late List<TodoItem> _todoItems = List<TodoItem>.from(widget.initialTodoItems);

  static const String _semesterPrefKey = 'unitrack_semester_info_v1';
  static const String _todosPrefKey = 'unitrack_todo_items_v2';
  static const String _todosInitializedKey = 'unitrack_todo_initialized_v2';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 讀取自訂學期資訊
      if (widget.semesterLabel.isEmpty) {
        final savedSemester = prefs.getString(_semesterPrefKey);
        if (savedSemester != null && savedSemester.isNotEmpty && mounted) {
          setState(() {
            _semesterLabel = savedSemester;
          });
        }
      }

      // 若未由外部傳入 initialTodoItems，則從本地儲存讀取
      if (widget.initialTodoItems.isEmpty) {
        final todosJsonStr = prefs.getString(_todosPrefKey);
        final isInitialized = prefs.getBool(_todosInitializedKey) ?? false;

        if (todosJsonStr != null && todosJsonStr.isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(todosJsonStr);
          final loadedItems = decoded
              .map((item) => TodoItem.fromJson(item as Map<String, dynamic>))
              .toList();
          if (mounted) {
            setState(() {
              _todoItems = loadedItems;
            });
          }
        } else if (!isInitialized) {
          final initialDefaults = [
            TodoItem(
              id: 'init_1',
              title: '確認本學期選課與學分門檻',
              subtitle: '至教務系統確認選課結果及畢業學分進度',
              category: '作業',
              icon: Icons.assignment_outlined,
              color: Colors.indigo,
            ),
            TodoItem(
              id: 'init_2',
              title: '預習今日課程教材與講義',
              subtitle: '下載教學平台簡報並完成課前閱讀',
              category: '課業',
              icon: Icons.menu_book_rounded,
              color: Colors.teal,
            ),
            TodoItem(
              id: 'init_3',
              title: '安排本週運動與生活預算',
              subtitle: '維持規律校園作息，檢視日常支出',
              category: '生活',
              icon: Icons.favorite_outline,
              color: Colors.pink,
            ),
          ];
          await prefs.setBool(_todosInitializedKey, true);
          await _saveTodosToPrefs(initialDefaults);
          if (mounted) {
            setState(() {
              _todoItems = initialDefaults;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [DashboardScreen] 載入本地偏好失敗: $e');
    }
  }

  Future<void> _saveTodosToPrefs(List<TodoItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = items.map((e) => e.toJson()).toList();
      await prefs.setString(_todosPrefKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('⚠️ [DashboardScreen] 儲存待辦失敗: $e');
    }
  }

  Future<void> _saveSemesterToPrefs(String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_semesterPrefKey, value);
    } catch (e) {
      debugPrint('⚠️ [DashboardScreen] 儲存學期失敗: $e');
    }
  }

  void _navigateOrPush(
    BuildContext context,
    int tabIndex,
    Widget fallbackScreen,
  ) {
    if (widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(tabIndex);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => fallbackScreen),
      );
    }
  }


  void _resetTodos() {
    setState(() {
      for (final item in _todoItems) {
        item.isCompleted = false;
      }
    });
    _saveTodosToPrefs(_todoItems);
    AppNotification.show(
      context,
      title: '已重置待辦狀態',
      message: '所有待辦事項已設為未完成',
      icon: Icons.refresh_rounded,
    );
  }

  Future<void> _deleteTodo(TodoItem item) async {
    setState(() {
      _todoItems.removeWhere((e) => e.id == item.id);
    });
    await _saveTodosToPrefs(_todoItems);
    if (mounted) {
      AppNotification.show(
        context,
        title: '已刪除待辦事項',
        message: '已將「${item.title}」自清單移除',
        icon: Icons.delete_outline_rounded,
      );
    }
  }

  Future<void> _showEditSemesterDialog() async {
    final controller = TextEditingController(text: _semesterLabel);
    const presets = [
      '113學年度 第 1 學期',
      '113學年度 第 2 學期',
      '113-1 第 8 週',
      '113-2 第 1 週',
    ];

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(Icons.edit_calendar_rounded, color: Colors.indigo),
              SizedBox(width: 8),
              Text('編輯學期資訊'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '自訂主畫面與導覽列顯示的當前學期或週次資訊：',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: '學期 / 週次名稱',
                    hintText: '例：113學年度 第 1 學期',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => controller.clear(),
                    ),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                const Text(
                  '快速選取：',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: presets.map((preset) {
                    return ActionChip(
                      label: Text(preset, style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        controller.text = preset;
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.text = '113學年度 第 1 學期';
              },
              child: const Text('恢復預設'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                Navigator.of(ctx).pop(
                  text.isNotEmpty ? text : '113學年度 第 1 學期',
                );
              },
              child: const Text('儲存'),
            ),
          ],
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _semesterLabel = result;
      });
      await _saveSemesterToPrefs(result);
      if (mounted) {
        AppNotification.show(
          context,
          title: '學期資訊已更新',
          message: '已設定為「$result」',
          icon: Icons.check_circle_outline,
        );
      }
    }
  }

  Future<void> _showAddTodoDialog() async {
    final titleController = TextEditingController();
    final subtitleController = TextEditingController();
    String selectedCategory = '作業';

    final categories = TodoCategory.defaultCategories;

    final result = await showDialog<TodoItem>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final activeCat = TodoCategory.fromName(selectedCategory);
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.add_task_rounded, color: Colors.indigo),
                  SizedBox(width: 8),
                  Text('新增待辦事項'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: '待辦事項名稱 *',
                        hintText: '例：微積分作業二、系學會開會',
                        prefixIcon: Icon(activeCat.icon, color: activeCat.color),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: subtitleController,
                      decoration: InputDecoration(
                        labelText: '詳細備註或截止時間（選填）',
                        hintText: '例：週五下午 5:00 前上傳平台',
                        prefixIcon: const Icon(Icons.notes_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '分類標籤：',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((cat) {
                        final isSelected = cat.name == selectedCategory;
                        return ChoiceChip(
                          label: Text(cat.name),
                          avatar: Icon(
                            cat.icon,
                            size: 16,
                            color: isSelected ? Colors.white : cat.color,
                          ),
                          selected: isSelected,
                          selectedColor: cat.color,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() {
                                selectedCategory = cat.name;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    if (title.isEmpty) {
                      AppNotification.show(
                        ctx,
                        title: '請輸入名稱',
                        message: '待辦事項名稱不能為空',
                        icon: Icons.warning_amber_rounded,
                      );
                      return;
                    }
                    final cat = TodoCategory.fromName(selectedCategory);
                    final newItem = TodoItem(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      title: title,
                      subtitle: subtitleController.text.trim(),
                      category: cat.name,
                      icon: cat.icon,
                      color: cat.color,
                      isCompleted: false,
                      createdAt: DateTime.now(),
                    );
                    Navigator.of(ctx).pop(newItem);
                  },
                  child: const Text('確認新增'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _todoItems.insert(0, result);
      });
      await _saveTodosToPrefs(_todoItems);
      if (mounted) {
        AppNotification.show(
          context,
          title: '已新增待辦',
          message: '已成功新增待辦「${result.title}」',
          icon: Icons.check_circle_outline,
        );
      }
    }
  }

  int _timeToMinutes(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length < 2) return 0;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return hour * 60 + minute;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasUser = widget.userName.trim().isNotEmpty;
    final greetingText = hasUser ? '早安，${widget.userName} 👋' : '早安 👋';
    final subTitleText = '$_semesterLabel (${ResponsiveLayout.platformLabel(context)})';

    return StreamBuilder<List<Course>>(
      stream: widget.coursesStream ?? CourseService().getCoursesStream(),
      initialData: const [],
      builder: (context, snapshot) {
        final courses = snapshot.data ?? const <Course>[];

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
                Text(
                  greetingText,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                InkWell(
                  onTap: _showEditSemesterDialog,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            subTitleText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.edit_outlined,
                          size: 13,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: '系統通知',
                onPressed: () {
                  AppNotification.show(
                    context,
                    title: '系統通知',
                    message: '目前沒有新的系統通知',
                    icon: Icons.notifications_none_rounded,
                  );
                },
                icon: const Icon(Icons.notifications_outlined),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: PopupMenuButton<String>(
                  tooltip: '個人帳號與設定',
                  offset: const Offset(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onSelected: (val) async {
                    if (val == 'logout') {
                      final shouldLogout = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: const Row(
                            children: [
                              Icon(Icons.logout_rounded, color: Colors.redAccent),
                              SizedBox(width: 8),
                              Text('確認登出'),
                            ],
                          ),
                          content: const Text(
                            '確定要登出目前帳號嗎？登出後需重新輸入電子信箱與密碼登入。',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('取消'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    Theme.of(ctx).colorScheme.error,
                                foregroundColor:
                                    Theme.of(ctx).colorScheme.onError,
                              ),
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('登出'),
                            ),
                          ],
                        ),
                      );

                      if (shouldLogout == true && context.mounted) {
                        try {
                          await AuthService().signOut();
                          if (context.mounted) {
                            AppNotification.show(
                              context,
                              title: '已登出',
                              message: '您已成功登出帳號。',
                              icon: Icons.check_circle_outline,
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            AppNotification.show(
                              context,
                              title: '登出失敗',
                              message: e.toString(),
                              icon: Icons.error_outline,
                            );
                          }
                        }
                      }
                    }
                  },
                  itemBuilder: (ctx) {
                    final user = AuthService().currentUser;
                    final email = user?.email ?? '';
                    final displayName = hasUser
                        ? widget.userName
                        : (email.isNotEmpty ? email.split('@').first : '同學');

                    return [
                      PopupMenuItem<String>(
                        enabled: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                fontSize: 15,
                              ),
                            ),
                            if (email.isNotEmpty)
                              Text(
                                email,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem<String>(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(
                              Icons.logout_rounded,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text(
                              '登出帳號',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ];
                  },
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: colorScheme.primaryContainer,
                    child: hasUser
                        ? Text(
                            widget.userName.trim().substring(0, 1),
                            style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : Icon(
                            Icons.person_outline,
                            size: 18,
                            color: colorScheme.onPrimaryContainer,
                          ),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDualColumn = constraints.maxWidth >= 840;
                final isMedium = constraints.maxWidth >= 560;
                final horizontalPadding = isDualColumn
                    ? 28.0
                    : (isMedium ? 20.0 : 16.0);

                return Scrollbar(
                  controller: _scrollController,
                  thumbVisibility:
                      ResponsiveLayout.isDesktopOrWebPlatform(context),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      20,
                      horizontalPadding,
                      28,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: Breakpoints.desktopMaxContentWidth,
                        ),
                        child: isDualColumn
                            ? _buildDesktopDualColumnLayout(context, courses)
                            : _buildMobileSingleColumnLayout(
                                context,
                                courses: courses,
                                crossAxisCount: isMedium ? 4 : 2,
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// Android / 窄視窗：單欄直式排版
  Widget _buildMobileSingleColumnLayout(
    BuildContext context, {
    required List<Course> courses,
    required int crossAxisCount,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTodayOverviewBanner(context, courses),
        const SizedBox(height: 24),
        _buildShortcutSectionHeader(context),
        const SizedBox(height: 12),
        _buildShortcutGrid(
          context,
          crossAxisCount: crossAxisCount,
          childAspectRatio: crossAxisCount == 4 ? 1.3 : 1.25,
          courses: courses,
        ),
        const SizedBox(height: 24),
        _buildTodoSectionHeader(context),
        const SizedBox(height: 8),
        if (_todoItems.isEmpty)
          _buildTodoEmptyState(context)
        else
          ..._todoItems.map((item) => _buildTodoCard(context, item)),
      ],
    );
  }

  /// Web / Windows 寬螢幕：左右雙欄 + 網格排版
  Widget _buildDesktopDualColumnLayout(
    BuildContext context,
    List<Course> courses,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左欄（主視覺橫幅 + 2x2/4欄功能捷徑網格）
        Expanded(
          flex: 7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTodayOverviewBanner(context, courses),
              const SizedBox(height: 24),
              _buildShortcutSectionHeader(context),
              const SizedBox(height: 12),
              _buildShortcutGrid(
                context,
                crossAxisCount: 2,
                childAspectRatio: 1.65,
                courses: courses,
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),

        // 右欄（獨立卡片式「今日摘要與近期待辦」側邊面板）
        Expanded(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTodoSectionHeader(context),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _todoItems.isEmpty
                      ? 0
                      : _todoItems.where((e) => e.isCompleted).length /
                          _todoItems.length,
                  borderRadius: BorderRadius.circular(8),
                  minHeight: 6,
                ),
                const SizedBox(height: 16),
                if (_todoItems.isEmpty)
                  _buildTodoEmptyState(context)
                else
                  ..._todoItems.map((item) => _buildTodoCard(context, item)),
                const SizedBox(height: 12),
                Text(
                  '💡 提示：在 Web 與 Windows 版可使用滑鼠滾輪捲動，點擊下方「功能捷徑」卡片即可快速切換至各功能分頁。',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 無待辦事項時的優雅空狀態（Empty State）
  Widget _buildTodoEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 44,
            color: colorScheme.outline,
          ),
          const SizedBox(height: 10),
          Text(
            '尚無待辦事項',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '目前沒有今日摘要或近期待辦，保持好節奏！',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: _showAddTodoDialog,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('新增第一筆待辦'),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutSectionHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '功能捷徑',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '點擊卡片快速切換分頁',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildShortcutGrid(
    BuildContext context, {
    required int crossAxisCount,
    required double childAspectRatio,
    required List<Course> courses,
  }) {
    final totalCredits = courses.fold<int>(0, (sum, c) => sum + c.credits);
    final shortcuts = [
      _ShortcutData(
        title: '課表',
        subtitle: courses.isEmpty ? '尚無課程資料' : '本學期已排定 ${courses.length} 門課',
        badgeText: '點擊查看',
        icon: Icons.table_chart_rounded,
        accentColor: Colors.indigo,
        onTap: () => _navigateOrPush(context, 1, const TimetableScreen()),
      ),
      _ShortcutData(
        title: '記帳本',
        subtitle: '尚無支出紀錄',
        badgeText: '點擊查看',
        icon: Icons.account_balance_wallet_rounded,
        accentColor: Colors.teal,
        onTap: () => _navigateOrPush(context, 4, const ExpenseScreen()),
      ),
      _ShortcutData(
        title: '行事曆',
        subtitle: '尚無近期活動',
        badgeText: '點擊查看',
        icon: Icons.calendar_month_rounded,
        accentColor: Colors.deepOrange,
        onTap: () => _navigateOrPush(context, 2, const CalendarScreen()),
      ),
      _ShortcutData(
        title: '學分進度',
        subtitle: courses.isEmpty ? '尚無學分紀錄' : '已排定 $totalCredits 學分',
        badgeText: '點擊查看',
        icon: Icons.school_rounded,
        accentColor: Colors.purple,
        onTap: () => _navigateOrPush(context, 3, const GraduationScreen()),
      ),
    ];

    return GridView.builder(
      itemCount: shortcuts.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (context, index) {
        return _ShortcutCard(data: shortcuts[index]);
      },
    );
  }

  Widget _buildTodoSectionHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          '今日摘要與近期待辦',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        FilledButton.tonalIcon(
          onPressed: _showAddTodoDialog,
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('新增', style: TextStyle(fontSize: 12)),
        ),
        const SizedBox(width: 6),
        TextButton.icon(
          onPressed: _todoItems.isEmpty ? null : _resetTodos,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          ),
          icon: const Icon(Icons.refresh, size: 15),
          label: const Text('重置', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  /// 頂部今日校園生活總覽橫幅（具備即時雲端課表動態比對、狀態切換與跳轉導航）
  Widget _buildTodayOverviewBanner(BuildContext context, List<Course> courses) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = widget.customNow ?? DateTime.now();
    final todayWeekday = now.weekday; // 1: Mon ... 7: Sun
    final weekdayName = Course.weekdayName(todayWeekday, short: true);
    final remainingTodos = _todoItems.where((e) => !e.isCompleted).length;
    final totalCredits = courses.fold<int>(0, (sum, c) => sum + c.credits);

    // 篩選今日的所有課程並依照開始節次排序
    final todayCourses =
        courses.where((c) => c.weekday == todayWeekday).toList();
    todayCourses.sort((a, b) => a.startSection.compareTo(b.startSection));

    final currentMinutes = now.hour * 60 + now.minute;

    String timeBadgeText;
    String weekdayText;
    String courseTitleText;
    String courseLocationText;
    bool isOngoing = false;
    IconData badgeIcon = Icons.schedule_rounded;

    if (widget.nextCourseTitle.isNotEmpty) {
      timeBadgeText = widget.nextCourseTimeLabel.isNotEmpty
          ? widget.nextCourseTimeLabel
          : '目前尚無課程';
      weekdayText = widget.weekdayLabel.isNotEmpty
          ? widget.weekdayLabel
          : weekdayName;
      courseTitleText = widget.nextCourseTitle;
      courseLocationText = widget.nextCourseLocation.isNotEmpty
          ? widget.nextCourseLocation
          : '尚無教室與授課資訊';
    } else if (todayCourses.isEmpty) {
      timeBadgeText = '今日無排定課程';
      weekdayText = weekdayName;
      courseTitleText = '今日尚無排定課程';
      courseLocationText = courses.isEmpty
          ? '點擊此卡片前往課表新增本學期課程 📅'
          : '今天沒有排定課程，好好放鬆或自主學習吧！';
      badgeIcon = Icons.event_available_rounded;
    } else {
      // 尋找進行中的課程
      Course? ongoingCourse;
      for (final c in todayCourses) {
        final startSec = Course.sectionOf(c.startSection);
        final endSec = Course.sectionOf(c.endSection);
        final sMin = _timeToMinutes(startSec.startTime);
        final eMin = _timeToMinutes(endSec.endTime);
        if (currentMinutes >= sMin && currentMinutes <= eMin) {
          ongoingCourse = c;
          break;
        }
      }

      if (ongoingCourse != null) {
        final startSec = Course.sectionOf(ongoingCourse.startSection);
        final endSec = Course.sectionOf(ongoingCourse.endSection);
        final secLabel = ongoingCourse.startSection == ongoingCourse.endSection
            ? '第 ${ongoingCourse.startSection} 節'
            : '第 ${ongoingCourse.startSection}-${ongoingCourse.endSection} 節';
        timeBadgeText = '上課中 (${startSec.startTime} - ${endSec.endTime})';
        weekdayText = '$weekdayName ・ $secLabel';
        courseTitleText = ongoingCourse.name;
        final room = ongoingCourse.classroom.isNotEmpty
            ? ongoingCourse.classroom
            : '未排定教室';
        final prof = ongoingCourse.professor.isNotEmpty
            ? ' ・ ${ongoingCourse.professor}'
            : '';
        courseLocationText = '📍 $room$prof';
        isOngoing = true;
        badgeIcon = Icons.play_circle_fill_rounded;
      } else {
        // 尋找下一堂即將開始的課程
        Course? upcomingCourse;
        for (final c in todayCourses) {
          final startSec = Course.sectionOf(c.startSection);
          final sMin = _timeToMinutes(startSec.startTime);
          if (sMin > currentMinutes) {
            upcomingCourse = c;
            break;
          }
        }

        if (upcomingCourse != null) {
          final startSec = Course.sectionOf(upcomingCourse.startSection);
          final endSec = Course.sectionOf(upcomingCourse.endSection);
          final secLabel = upcomingCourse.startSection ==
                  upcomingCourse.endSection
              ? '第 ${upcomingCourse.startSection} 節'
              : '第 ${upcomingCourse.startSection}-${upcomingCourse.endSection} 節';
          timeBadgeText = '下一堂 (${startSec.startTime} - ${endSec.endTime})';
          weekdayText = '$weekdayName ・ $secLabel';
          courseTitleText = upcomingCourse.name;
          final room = upcomingCourse.classroom.isNotEmpty
              ? upcomingCourse.classroom
              : '未排定教室';
          final prof = upcomingCourse.professor.isNotEmpty
              ? ' ・ ${upcomingCourse.professor}'
              : '';
          courseLocationText = '📍 $room$prof';
          badgeIcon = Icons.schedule_rounded;
        } else {
          // 今日所有課程均已結束
          timeBadgeText = '今日課表已結束';
          weekdayText = '$weekdayName ・ 共 ${todayCourses.length} 門課';
          courseTitleText = '今日課程已全部結束 🎉';
          courseLocationText = '今天辛苦了，好好放鬆或複習一下課業吧！';
          badgeIcon = Icons.task_alt_rounded;
        }
      }
    }

    final expenseText = widget.todayExpenseText.isNotEmpty
        ? widget.todayExpenseText
        : 'NT\$ 0';
    final creditText = widget.creditProgressText.isNotEmpty
        ? widget.creditProgressText
        : '$totalCredits / 128';

    final gradientColors = isOngoing
        ? [
            const Color(0xFF1E3A8A), // 深海靛藍
            const Color(0xFF0D9488), // 活力湖綠
          ]
        : [
            colorScheme.primary,
            colorScheme.tertiary,
          ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isOngoing
                    ? const Color(0xFF0D9488)
                    : colorScheme.primary)
                .withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isOngoing
                      ? Colors.amberAccent.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: isOngoing
                      ? Border.all(
                          color: Colors.amberAccent.withValues(alpha: 0.8),
                          width: 1,
                        )
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      badgeIcon,
                      color: isOngoing ? Colors.amberAccent : Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeBadgeText,
                      style: TextStyle(
                        color: isOngoing ? Colors.amberAccent : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                weekdayText,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            courseTitleText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            courseLocationText,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBannerMetric(
                label: '今日待辦',
                value: '$remainingTodos 項',
              ),
              _buildBannerMetric(
                label: '今日花費',
                value: expenseText,
              ),
              _buildBannerMetric(
                label: '畢業學分',
                value: creditText,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBannerMetric({
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  /// 單筆待辦與今日摘要卡片（使用 HoverableCard 支援桌面端滑鼠懸停反饋與刪除管理）
  Widget _buildTodoCard(BuildContext context, TodoItem item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return HoverableCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: BorderRadius.circular(14),
      accentColor: item.color,
      onTap: () {
        setState(() {
          item.isCompleted = !item.isCompleted;
        });
        _saveTodosToPrefs(_todoItems);
      },
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: item.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration:
                        item.isCompleted ? TextDecoration.lineThrough : null,
                    color: item.isCompleted
                        ? colorScheme.outline
                        : colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.category,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: item.color,
                        ),
                      ),
                    ),
                    if (item.subtitle.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Checkbox(
            value: item.isCompleted,
            activeColor: colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            onChanged: (bool? val) {
              setState(() {
                item.isCompleted = val ?? false;
              });
              _saveTodosToPrefs(_todoItems);
            },
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: colorScheme.outline,
            ),
            tooltip: '刪除待辦事項',
            onPressed: () => _deleteTodo(item),
          ),
        ],
      ),
    );
  }
}

class _ShortcutData {
  final String title;
  final String subtitle;
  final String badgeText;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _ShortcutData({
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });
}

/// 功能捷徑卡片元件（封裝 HoverableCard 支援滑鼠懸停上浮與邊框高亮）
class _ShortcutCard extends StatelessWidget {
  final _ShortcutData data;

  const _ShortcutCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return HoverableCard(
      accentColor: data.accentColor,
      onTap: data.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: data.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, color: data.accentColor, size: 22),
              ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: data.accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    data.badgeText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: data.accentColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 待辦事項分類模型
class TodoCategory {
  final String name;
  final IconData icon;
  final Color color;

  const TodoCategory({
    required this.name,
    required this.icon,
    required this.color,
  });

  static const List<TodoCategory> defaultCategories = [
    TodoCategory(
      name: '作業',
      icon: Icons.assignment_outlined,
      color: Colors.indigo,
    ),
    TodoCategory(
      name: '考試',
      icon: Icons.quiz_outlined,
      color: Colors.deepOrange,
    ),
    TodoCategory(
      name: '課業',
      icon: Icons.menu_book_rounded,
      color: Colors.teal,
    ),
    TodoCategory(
      name: '活動',
      icon: Icons.event_outlined,
      color: Colors.blueAccent,
    ),
    TodoCategory(
      name: '生活',
      icon: Icons.favorite_outline,
      color: Colors.pink,
    ),
    TodoCategory(
      name: '其他',
      icon: Icons.check_circle_outline,
      color: Colors.purple,
    ),
  ];

  static TodoCategory fromName(String name) {
    return defaultCategories.firstWhere(
      (c) => c.name == name,
      orElse: () => defaultCategories.first,
    );
  }
}

/// 待辦與今日摘要資料模型（支援 JSON 序列化與本地持久化儲存）
class TodoItem {
  final String id;
  String title;
  String subtitle;
  String category;
  IconData icon;
  Color color;
  bool isCompleted;
  DateTime? createdAt;

  TodoItem({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.category = '作業',
    this.icon = Icons.assignment_outlined,
    this.color = Colors.indigo,
    this.isCompleted = false,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'category': category,
        'iconCode': icon.codePoint,
        'colorValue': color.toARGB32(),
        'isCompleted': isCompleted,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      };

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    final categoryName = json['category'] as String? ?? '作業';
    final category = TodoCategory.fromName(categoryName);
    return TodoItem(
      id: json['id'] as String? ?? UniqueKey().toString(),
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      category: categoryName,
      icon: category.icon,
      color: category.color,
      isCompleted: json['isCompleted'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}
