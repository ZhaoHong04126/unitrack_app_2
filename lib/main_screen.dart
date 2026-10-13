// 多平台響應式導覽主框架（整合手機底部 NavigationBar / Drawer 與桌面側邊欄 NavigationRail，並串接 Firebase Auth 登入狀態與登出）
import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'screens/timetable_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/graduation_screen.dart';
import 'screens/expense_screen.dart';
import 'services/auth_service.dart';
import 'widgets/app_notification.dart';
import 'widgets/responsive_layout.dart';

class _NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

class MainScreen extends StatefulWidget {
  /// 外部可傳入的使用者資訊（未傳入時預設為空，顯示無資料預設狀態）
  final String userName;
  final String userDepartment;
  final String creditSummary;

  const MainScreen({
    super.key,
    this.userName = '',
    this.userDepartment = '',
    this.creditSummary = '',
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  static const List<_NavItem> _navItems = [
    _NavItem(
      label: '首頁總覽',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
    ),
    _NavItem(
      label: '課程表',
      icon: Icons.table_chart_outlined,
      selectedIcon: Icons.table_chart,
    ),
    _NavItem(
      label: '校園行事曆',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month,
    ),
    _NavItem(
      label: '畢業審查',
      icon: Icons.school_outlined,
      selectedIcon: Icons.school,
    ),
    _NavItem(
      label: '記帳本',
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet,
    ),
  ];

  void _switchTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  /// 執行帳號登出確認與呼叫
  Future<void> _handleSignOut(BuildContext context) async {
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
        content: const Text('確定要登出目前帳號嗎？登出後需重新輸入電子信箱與密碼登入。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
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
            title: '已安全登出',
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

  /// 取得當前使用者名稱與電子信箱資訊
  ({String displayName, String email, String initial}) _getUserProfile() {
    final user = AuthService().currentUser;
    final email = user?.email ?? '';
    final rawName = user?.displayName?.trim() ?? '';
    final name = rawName.isNotEmpty
        ? rawName
        : (widget.userName.trim().isNotEmpty
            ? widget.userName.trim()
            : (email.isNotEmpty ? email.split('@').first : '同學'));
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U';

    return (displayName: name, email: email, initial: initial);
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = _getUserProfile();

    final List<Widget> pages = [
      DashboardScreen(
        onNavigateToTab: _switchTab,
        userName: userProfile.displayName,
      ),
      const TimetableScreen(),
      const CalendarScreen(),
      const GraduationScreen(),
      const ExpenseScreen(),
    ];

    final currentPage = pages[_currentIndex];

    // 僅在原生行動裝置（如 Android / iOS）顯示底部 NavigationBar；
    // Web 小介面或 Windows 窄視窗時不顯示底部導覽列，改由左上角 Drawer 選單導航
    final bool showBottomNav = !ResponsiveLayout.isDesktopOrWebPlatform(context);

    return ResponsiveLayout(
      // 1. 窄螢幕模式：Android 顯示底部 NavigationBar；Web 小介面隱藏底部導覽列、使用左上角 Drawer
      mobile: Scaffold(
        drawer: _buildMobileDrawer(context, userProfile),
        body: currentPage,
        bottomNavigationBar: showBottomNav
            ? NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: _switchTab,
                destinations: _navItems
                    .map(
                      (item) => NavigationDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.selectedIcon),
                        label: item.label,
                      ),
                    )
                    .toList(),
              )
            : null,
      ),

      // 2. 平板 / 中尺寸視窗：左側精簡型 NavigationRail + 右側內容區
      tablet: Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: _currentIndex,
                onDestinationSelected: _switchTab,
                labelType: NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      userProfile.initial,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                trailing: Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: IconButton(
                        icon: const Icon(Icons.logout_rounded),
                        tooltip: '登出帳號 (${userProfile.email.isNotEmpty ? userProfile.email : userProfile.displayName})',
                        color: Theme.of(context).colorScheme.error,
                        onPressed: () => _handleSignOut(context),
                      ),
                    ),
                  ),
                ),
                destinations: _navItems
                    .map(
                      (item) => NavigationRailDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.selectedIcon),
                        label: Text(item.label),
                      ),
                    )
                    .toList(),
              ),
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(child: currentPage),
            ],
          ),
        ),
      ),

      // 3. Web / Windows 寬螢幕桌面端：完整展開側邊導覽列 (Extended NavigationRail / Sidebar)
      desktop: Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              _buildDesktopSidebar(context, userProfile),
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(child: currentPage),
            ],
          ),
        ),
      ),
    );
  }

  /// 手機端抽屜選單（Drawer），搭配底部導覽列提供雙重便利性，並展示登入者 Email 與登出功能
  Widget _buildMobileDrawer(
    BuildContext context,
    ({String displayName, String email, String initial}) userProfile,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 使用者資訊頂部橫幅
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.45),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: colorScheme.primary,
                    child: Text(
                      userProfile.initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userProfile.displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          userProfile.email.isNotEmpty
                              ? userProfile.email
                              : (widget.userDepartment.isNotEmpty
                                  ? widget.userDepartment
                                  : '已登入使用者'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 導覽選單項目
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _navItems.length,
                itemBuilder: (context, index) {
                  final item = _navItems[index];
                  final isSelected = _currentIndex == index;
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    selected: isSelected,
                    selectedTileColor:
                        colorScheme.primaryContainer.withValues(alpha: 0.6),
                    leading: Icon(
                      isSelected ? item.selectedIcon : item.icon,
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      _switchTab(index);
                    },
                  );
                },
              ),
            ),

            const Divider(height: 1, indent: 16, endIndent: 16),

            // 登出按鈕
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: Icon(
                  Icons.logout_rounded,
                  color: colorScheme.error,
                ),
                title: Text(
                  '登出帳號',
                  style: TextStyle(
                    color: colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _handleSignOut(context);
                },
              ),
            ),

            // 平台環境標籤
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                '目前環境：${ResponsiveLayout.platformLabel(context)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Web / Windows 桌面端展開式側邊欄導航（含品牌標題與底部使用者資訊與登出卡片）
  Widget _buildDesktopSidebar(
    BuildContext context,
    ({String displayName, String email, String initial}) userProfile,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: 250,
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 頂部品牌區
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'UniTrack Pro',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        ResponsiveLayout.platformLabel(context),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 16, indent: 16, endIndent: 16),

          // 展開式 NavigationRail
          Expanded(
            child: NavigationRail(
              extended: true,
              minExtendedWidth: 250,
              backgroundColor: Colors.transparent,
              selectedIndex: _currentIndex,
              onDestinationSelected: _switchTab,
              destinations: _navItems
                  .map(
                    (item) => NavigationRailDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.selectedIcon),
                      label: Text(item.label),
                    ),
                  )
                  .toList(),
            ),
          ),

          // 底部使用者資訊與登出卡片
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    userProfile.initial,
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userProfile.displayName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        userProfile.email.isNotEmpty
                            ? userProfile.email
                            : (widget.creditSummary.isNotEmpty
                                ? widget.creditSummary
                                : '已登入使用者'),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  tooltip: '登出帳號',
                  color: colorScheme.error,
                  onPressed: () => _handleSignOut(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}