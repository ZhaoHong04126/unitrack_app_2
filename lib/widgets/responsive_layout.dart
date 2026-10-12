// 響應式佈局與多平台檢測工具
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 定義各裝置尺寸斷點
class Breakpoints {
  static const double mobile = 600.0;
  static const double tablet = 960.0;
  static const double desktopMaxContentWidth = 1280.0;
}

/// 支援滑鼠滾輪、觸控板與觸控拖曳的跨平台滾動行為（適用 Web / Windows / Android）
class AdaptiveScrollBehavior extends MaterialScrollBehavior {
  const AdaptiveScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

/// 通用響應式外框元件（ResponsiveLayout）
/// 依據父容器或視窗寬度，自動分流 Mobile（單欄直式）、Tablet（雙欄/收合側欄）、Desktop（寬螢幕多欄/展開側欄）
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  /// 判斷當前寬度是否為手機端窄螢幕 (< 600px)
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < Breakpoints.mobile;

  /// 判斷當前寬度是否為平板/中尺寸視窗 (600px ~ 960px)
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= Breakpoints.mobile && width < Breakpoints.tablet;
  }

  /// 判斷當前寬度是否為桌面端/大螢幕 (>= 960px)
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= Breakpoints.tablet;

  /// 判斷是否執行於桌面或 Web 平台（提供滑鼠 Hover 與桌面級互動參考）
  static bool isDesktopOrWebPlatform(BuildContext context) {
    if (kIsWeb) return true;
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;
  }

  /// 取得當前運行平台名稱標籤（用於 UI 狀態顯示）
  static String platformLabel(BuildContext context) {
    if (kIsWeb) return 'Web 網頁端';
    final platform = Theme.of(context).platform;
    switch (platform) {
      case TargetPlatform.android:
        return 'Android 行動端';
      case TargetPlatform.iOS:
        return 'iOS 行動端';
      case TargetPlatform.windows:
        return 'Windows 桌面端';
      case TargetPlatform.macOS:
        return 'macOS 桌面端';
      case TargetPlatform.linux:
        return 'Linux 桌面端';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }

  /// 當處於窄螢幕且外層 Scaffold 具備 Drawer 時，自動產生左上角漢堡選單按鈕
  static Widget? buildDrawerLeading(BuildContext context) {
    final parentScaffold = Scaffold.maybeOf(context);
    if (isMobile(context) && (parentScaffold?.hasDrawer ?? false)) {
      return IconButton(
        tooltip: '開啟導覽選單',
        icon: const Icon(Icons.menu_rounded),
        onPressed: () => parentScaffold?.openDrawer(),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (maxWidth >= Breakpoints.tablet) {
          return desktop;
        } else if (maxWidth >= Breakpoints.mobile) {
          return tablet ?? desktop;
        } else {
          return mobile;
        }
      },
    );
  }
}
