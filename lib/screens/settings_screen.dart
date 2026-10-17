// 系統設定畫面（支援個人檔案、外觀主題模式切換、通知提醒與版本資訊）
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../widgets/app_notification.dart';
import '../widgets/responsive_layout.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onProfileUpdated;
  final VoidCallback? onSignOut;

  const SettingsScreen({
    super.key,
    this.onProfileUpdated,
    this.onSignOut,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  bool _isLoading = true;

  // 使用者資訊暫存
  String _displayName = '';
  String _email = '';
  String _initial = 'U';

  @override
  void initState() {
    super.initState();
    _loadAllSettings();
  }

  Future<void> _loadAllSettings() async {
    await _settingsService.initialize();
    final user = AuthService().currentUser;
    final email = user?.email ?? '';
    final name = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim()
        : (email.isNotEmpty ? email.split('@').first : '同學');

    if (mounted) {
      setState(() {
        _displayName = name;
        _email = email;
        _initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U';
        _isLoading = false;
      });
    }
  }

  /// 編輯顯示名稱對話框
  Future<void> _showEditDisplayNameDialog() async {
    final controller = TextEditingController(text: _displayName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.badge_outlined),
            SizedBox(width: 8),
            Text('修改個人姓名'),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '顯示名稱',
            hintText: '請輸入您的姓名或暱稱',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('儲存'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != _displayName && mounted) {
      try {
        await AuthService().updateDisplayName(newName);
        setState(() {
          _displayName = newName;
          _initial = newName.substring(0, 1).toUpperCase();
        });
        widget.onProfileUpdated?.call();
        if (mounted) {
          AppNotification.show(
            context,
            title: '姓名已更新',
            message: '您的個人顯示名稱已成功儲存。',
            icon: Icons.check_circle_outline,
          );
        }
      } catch (e) {
        if (mounted) {
          AppNotification.show(
            context,
            title: '更新失敗',
            message: e.toString(),
            icon: Icons.error_outline,
          );
        }
      }
    }
  }

  /// 發送密碼重設信
  Future<void> _handleResetPassword() async {
    if (_email.isEmpty) {
      AppNotification.show(
        context,
        title: '無法重設密碼',
        message: '未偵測到目前登入帳號的電子信箱。',
        icon: Icons.warning_amber_rounded,
      );
      return;
    }

    try {
      await AuthService().sendPasswordResetEmail(email: _email);
      if (mounted) {
        AppNotification.show(
          context,
          title: '密碼重設信已寄出',
          message: '已寄送重設信至 $_email，請至信箱點擊連結完成密碼變更。',
          icon: Icons.mark_email_read_outlined,
        );
      }
    } catch (e) {
      if (mounted) {
        AppNotification.show(
          context,
          title: '寄送失敗',
          message: e.toString(),
          icon: Icons.error_outline,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: ResponsiveLayout.buildDrawerLeading(context),
        title: const Row(
          children: [
            Icon(Icons.tune_rounded),
            SizedBox(width: 8),
            Text('系統設定'),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTwoColumn = constraints.maxWidth >= 840;

          final leftColumn = [
            // 1. 個人檔案與身分卡片
            _buildSectionHeader('個人帳號與基本資料', Icons.person_outline_rounded),
            _buildProfileCard(context, colorScheme),
            const SizedBox(height: 24),

            // 2. 介面與外觀設定（僅保留主題模式）
            _buildSectionHeader('介面外觀與主題模式', Icons.palette_outlined),
            _buildThemeCard(context, colorScheme),
          ];

          final rightColumn = [
            // 4. 通知與提醒偏好
            _buildSectionHeader('通知與提醒通知', Icons.notifications_none_rounded),
            _buildNotificationsCard(context, colorScheme),
            const SizedBox(height: 24),

            // 5. 系統與版本資訊
            _buildSectionHeader('系統狀態與版本', Icons.info_outline_rounded),
            _buildSystemInfoCard(context, colorScheme),
            const SizedBox(height: 32),

            // 6. 登出帳號操作區
            if (widget.onSignOut != null)
              Center(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(color: colorScheme.error.withValues(alpha: 0.6)),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('登出目前帳號', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: widget.onSignOut,
                ),
              ),
            const SizedBox(height: 36),
          ];

          if (isTwoColumn) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: leftColumn,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: rightColumn,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            children: [
              ...leftColumn,
              const SizedBox(height: 24),
              ...rightColumn,
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 個人帳號卡片（已移除學系與學號輸入列，僅保留頭像、姓名、信箱與重設密碼）
  Widget _buildProfileCard(BuildContext context, ColorScheme colorScheme) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: colorScheme.primary,
              child: Text(
                _initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _displayName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: '修改姓名',
                        onPressed: _showEditDisplayNameDialog,
                      ),
                    ],
                  ),
                  Text(
                    _email.isNotEmpty ? _email : '無綁定信箱',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'UniTrack Pro 認證使用者',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.lock_reset_rounded, size: 18),
              label: const Text('重設密碼'),
              onPressed: _handleResetPassword,
            ),
          ],
        ),
      ),
    );
  }

  /// 介面外觀卡片（已移除主題色調種子選擇，僅保留深淺主題模式切換）
  Widget _buildThemeCard(BuildContext context, ColorScheme colorScheme) {
    return ValueListenableBuilder<ThemeSettings>(
      valueListenable: _settingsService.themeNotifier,
      builder: (context, themeSettings, _) {
        return Card(
          elevation: 0,
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('主題模式', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('跟隨系統'),
                      icon: Icon(Icons.brightness_auto_rounded),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('淺色模式'),
                      icon: Icon(Icons.light_mode_rounded),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('深色模式'),
                      icon: Icon(Icons.dark_mode_rounded),
                    ),
                  ],
                  selected: {themeSettings.themeMode},
                  onSelectionChanged: (Set<ThemeMode> newSelection) {
                    _settingsService.setThemeMode(newSelection.first);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 通知提醒偏好卡片
  Widget _buildNotificationsCard(BuildContext context, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('上課前課堂提醒'),
            subtitle: const Text('於課堂開始前 10 分鐘自動跳出通知並標示教室地點'),
            secondary: const Icon(Icons.alarm_on_rounded),
            value: _settingsService.classReminder,
            onChanged: (val) async {
              await _settingsService.setClassReminder(val);
              setState(() {});
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          SwitchListTile(
            title: const Text('晨間待辦摘要提醒'),
            subtitle: const Text('每日上午 08:00 彙整當日待辦事項與重要行程'),
            secondary: const Icon(Icons.wb_sunny_outlined),
            value: _settingsService.todoReminder,
            onChanged: (val) async {
              await _settingsService.setTodoReminder(val);
              setState(() {});
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          SwitchListTile(
            title: const Text('夜間記帳提醒'),
            subtitle: const Text('每日晚間 21:00 提醒登錄當日生活花費與收支'),
            secondary: const Icon(Icons.nights_stay_outlined),
            value: _settingsService.expenseReminder,
            onChanged: (val) async {
              await _settingsService.setExpenseReminder(val);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  /// 系統資訊卡片
  Widget _buildSystemInfoCard(BuildContext context, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.verified_outlined),
            title: const Text('應用程式版本'),
            subtitle: Text('UniTrack Pro ${SettingsService.appVersion} (Official Build)'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '已是最新版本',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.devices_rounded),
            title: const Text('目前執行環境'),
            subtitle: Text(ResponsiveLayout.platformLabel(context)),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.cloud_done_outlined),
            title: const Text('雲端同步服務'),
            subtitle: const Text('Google Firebase Authentication & Cloud Firestore 連線中'),
          ),
        ],
      ),
    );
  }
}
