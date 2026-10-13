// 主畫面 / 首頁（支援 Android 單欄直式與 Web / Windows 雙欄多格響應式排版）
import 'package:flutter/material.dart';
import '../widgets/hoverable_card.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/app_notification.dart';
import 'timetable_screen.dart';
import 'calendar_screen.dart';
import 'graduation_screen.dart';
import 'expense_screen.dart';

class DashboardScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateToTab;

  /// 外部可傳入的動態資料參數（預設為空值或空集合，供日後串接真實 API 使用）
  final String userName;
  final String semesterLabel;
  final String nextCourseTimeLabel;
  final String weekdayLabel;
  final String nextCourseTitle;
  final String nextCourseLocation;
  final String todayExpenseText;
  final String creditProgressText;
  final List<TodoItem> initialTodoItems;

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
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ScrollController _scrollController = ScrollController();

  // 待辦與今日摘要清單（預設為空集合，可由外部 initialTodoItems 注入）
  late final List<TodoItem> _todoItems = List<TodoItem>.from(
    widget.initialTodoItems,
  );

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasUser = widget.userName.trim().isNotEmpty;
    final greetingText = hasUser ? '早安，${widget.userName} 👋' : '早安 👋';
    final subTitleText = widget.semesterLabel.isNotEmpty
        ? '${widget.semesterLabel} (${ResponsiveLayout.platformLabel(context)})'
        : '尚無學期資訊 (${ResponsiveLayout.platformLabel(context)})';

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
            Text(
              subTitleText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
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
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 當內容區寬度 >= 840 時啟用桌面雙欄分流排版（Web / Windows 大螢幕）
            final isDualColumn = constraints.maxWidth >= 840;
            final isMedium = constraints.maxWidth >= 560;
            final horizontalPadding = isDualColumn
                ? 28.0
                : (isMedium ? 20.0 : 16.0);

            return Scrollbar(
              controller: _scrollController,
              thumbVisibility: ResponsiveLayout.isDesktopOrWebPlatform(context),
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
                        ? _buildDesktopDualColumnLayout(context)
                        : _buildMobileSingleColumnLayout(
                            context,
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
  }

  /// Android / 窄視窗：單欄直式排版
  Widget _buildMobileSingleColumnLayout(
    BuildContext context, {
    required int crossAxisCount,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTodayOverviewBanner(context),
        const SizedBox(height: 24),
        _buildShortcutSectionHeader(context),
        const SizedBox(height: 12),
        _buildShortcutGrid(
          context,
          crossAxisCount: crossAxisCount,
          childAspectRatio: crossAxisCount == 4 ? 1.3 : 1.25,
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
  Widget _buildDesktopDualColumnLayout(BuildContext context) {
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
              _buildTodayOverviewBanner(context),
              const SizedBox(height: 24),
              _buildShortcutSectionHeader(context),
              const SizedBox(height: 12),
              _buildShortcutGrid(
                context,
                crossAxisCount: 2,
                childAspectRatio: 1.65,
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
                  '💡 提示：在 Web 與 Windows 版可使用滑鼠滾輪捲動，並將游標移至卡片上預覽動態效果。',
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
            '尚無資料',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '目前沒有今日摘要或近期待辦事項',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.outline,
            ),
            textAlign: TextAlign.center,
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
  }) {
    final shortcuts = [
      _ShortcutData(
        title: '課表',
        subtitle: '尚無課程資料',
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
        subtitle: '尚無學分紀錄',
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '今日摘要與近期待辦',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        TextButton.icon(
          onPressed: _todoItems.isEmpty ? null : _resetTodos,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('重置狀態'),
        ),
      ],
    );
  }

  /// 頂部今日校園生活總覽橫幅
  Widget _buildTodayOverviewBanner(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final remainingTodos = _todoItems.where((e) => !e.isCompleted).length;

    final timeBadgeText = widget.nextCourseTimeLabel.isNotEmpty
        ? widget.nextCourseTimeLabel
        : '目前尚無課程';
    final weekdayText = widget.weekdayLabel.isNotEmpty
        ? widget.weekdayLabel
        : '--';
    final courseTitleText = widget.nextCourseTitle.isNotEmpty
        ? widget.nextCourseTitle
        : '尚無排定課程';
    final courseLocationText = widget.nextCourseLocation.isNotEmpty
        ? widget.nextCourseLocation
        : '尚無教室與授課資訊';
    final expenseText = widget.todayExpenseText.isNotEmpty
        ? widget.todayExpenseText
        : 'NT\$ 0';
    final creditText = widget.creditProgressText.isNotEmpty
        ? widget.creditProgressText
        : '0 / 0';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.tertiary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.25),
            blurRadius: 12,
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
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      timeBadgeText,
                      style: const TextStyle(
                        color: Colors.white,
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
              _buildBannerMetric('今日待辦', '$remainingTodos 項'),
              _buildBannerMetric('今日花費', expenseText),
              _buildBannerMetric('畢業學分', creditText),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBannerMetric(String label, String value) {
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

  /// 單筆待辦與今日摘要卡片（使用 HoverableCard 支援桌面端滑鼠懸停反饋）
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
            },
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

/// 待辦與今日摘要資料模型（保留供日後串接真實 API 使用）
class TodoItem {
  final String title;
  final String subtitle;
  final String category;
  final IconData icon;
  final Color color;
  bool isCompleted;

  TodoItem({
    required this.title,
    required this.subtitle,
    required this.category,
    required this.icon,
    required this.color,
    this.isCompleted = false,
  });
}
