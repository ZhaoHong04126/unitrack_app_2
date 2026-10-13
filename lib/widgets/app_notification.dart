// 跨平台適應性通知工具（電腦端頂部右上角懸浮通知 / 行動端底部 SnackBar）
import 'dart:async';
import 'package:flutter/material.dart';
import 'responsive_layout.dart';

/// 跨平台通知管理工具
///
/// * **電腦版（Web / Windows / 寬螢幕）**：於視窗**右上角**以精緻懸浮卡片展示，具備滑入淡入動畫、手動關閉與自動隱藏。
/// * **行動端（Android / iOS 窄螢幕）**：自動適配為原生底部浮動 SnackBar。
class AppNotification {
  static OverlayEntry? _activeEntry;
  static _TopRightNotificationBannerState? _activeState;
  static Timer? _dismissTimer;

  /// 顯示適應性系統通知
  static void show(
    BuildContext context, {
    required String message,
    String title = '系統通知',
    IconData icon = Icons.notifications_active_outlined,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(milliseconds: 3500),
  }) {
    // 行動端窄螢幕使用標準底部 SnackBar
    if (ResponsiveLayout.isMobile(context)) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            action: actionLabel != null && onAction != null
                ? SnackBarAction(
                    label: actionLabel,
                    onPressed: onAction,
                  )
                : null,
          ),
        );
        return;
      }
    }

    // 電腦版（Web / Windows 桌面端 / 寬螢幕）：顯示右上角懸浮通知卡片
    _showTopRightOverlay(
      context,
      title: title,
      message: message,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// 移除目前顯示中的右上角通知
  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;

    if (_activeState != null && _activeState!.mounted) {
      _activeState!.animateOut().then((_) {
        _cleanup();
      });
    } else {
      _cleanup();
    }
  }

  static void _cleanup() {
    try {
      _activeEntry?.remove();
    } catch (_) {}
    _activeEntry = null;
    _activeState = null;
  }

  static void _showTopRightOverlay(
    BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
    String? actionLabel,
    VoidCallback? onAction,
    required Duration duration,
  }) {
    // 若已有通知顯示，先立即關閉前一個通知
    _dismissTimer?.cancel();
    _dismissTimer = null;
    if (_activeEntry != null) {
      try {
        _activeEntry?.remove();
      } catch (_) {}
      _activeEntry = null;
      _activeState = null;
    }

    final overlay = Overlay.maybeOf(context, rootOverlay: true) ??
        Overlay.maybeOf(context);

    if (overlay == null) {
      // 若找不到 Overlay 則降級使用 SnackBar
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final theme = Theme.of(context);
    final topOffset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12.0;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: topOffset,
          right: 20,
          child: Material(
            color: Colors.transparent,
            child: _TopRightNotificationBanner(
              title: title,
              message: message,
              icon: icon,
              actionLabel: actionLabel,
              onAction: onAction,
              theme: theme,
              onDismiss: () => dismiss(),
              onMounted: (state) {
                _activeState = state;
              },
            ),
          ),
        );
      },
    );

    _activeEntry = entry;
    overlay.insert(entry);

    // 設定自動關閉計時器
    _dismissTimer = Timer(duration, () {
      dismiss();
    });
  }
}

class _TopRightNotificationBanner extends StatefulWidget {
  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final ThemeData theme;
  final VoidCallback onDismiss;
  final ValueChanged<_TopRightNotificationBannerState> onMounted;

  const _TopRightNotificationBanner({
    required this.title,
    required this.message,
    required this.icon,
    this.actionLabel,
    this.onAction,
    required this.theme,
    required this.onDismiss,
    required this.onMounted,
  });

  @override
  State<_TopRightNotificationBanner> createState() =>
      _TopRightNotificationBannerState();
}

class _TopRightNotificationBannerState
    extends State<_TopRightNotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 200),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.25, -0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );

    widget.onMounted(this);
    _controller.forward();
  }

  Future<void> animateOut() async {
    if (mounted) {
      await _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.theme.colorScheme;
    final textTheme = widget.theme.textTheme;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          constraints: const BoxConstraints(
            minWidth: 280,
            maxWidth: 380,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.7),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 18,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 通知圖示徽章
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  size: 20,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),

              // 通知標題與內容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.title,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '剛剛',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.message,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    if (widget.actionLabel != null &&
                        widget.onAction != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            widget.onDismiss();
                            widget.onAction!();
                          },
                          child: Text(widget.actionLabel!),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // 關閉按鈕
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 24,
                  minHeight: 24,
                ),
                splashRadius: 16,
                iconSize: 18,
                tooltip: '關閉通知',
                onPressed: widget.onDismiss,
                icon: Icon(
                  Icons.close_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
