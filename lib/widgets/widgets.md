# `widgets/` 共用元件與響應式工具目錄簡介

`widgets/` 目錄封裝了 **UniTrack Pro** 跨頁面共用的可複用 UI 元件（Reusable Widgets）與跨平台響應式佈局工具，確保整體視覺風格一致，並同時最佳化桌面端滑鼠操作與行動端觸控體驗。

---

## 現有檔案說明

### 1. `responsive_layout.dart` — 響應式佈局與跨平台檢測工具
提供跨平台（Android、iOS、Web、Windows、macOS、Linux）的螢幕尺寸斷點檢測與佈局分流工具：

* **`Breakpoints`**：定義專案統一的螢幕寬度斷點常數：
  * `mobile`: `< 600.0px`（手機直向與極窄視窗）
  * `tablet`: `600.0px ~ 960.0px`（平板直橫向與中尺寸視窗）
  * `desktop`: `>= 960.0px`（桌面端寬螢幕，並定義內容最大建議寬度 `desktopMaxContentWidth = 1280.0px`）
* **`AdaptiveScrollBehavior`**：自定義跨平台滾動行為（繼承 `MaterialScrollBehavior`），支援觸控（`touch`）、滑鼠滾輪與拖曳（`mouse`）、觸控板（`trackpad`）及手寫筆（`stylus`）流暢捲動，解決 Web/桌面端預設無法使用滑鼠拖曳長列表的問題。
* **`ResponsiveLayout`**：通用響應式容器元件，依據父容器或視窗寬度自動切換渲染 `mobile`、`tablet`（可選，未傳入時退回 `mobile`）或 `desktop` 子樹，並提供便捷的靜態輔助方法：
  * `isMobile(context)`：判斷當前視窗是否為手機窄螢幕。
  * `isTablet(context)`：判斷當前視窗是否為平板尺寸。
  * `isDesktop(context)`：判斷當前視窗是否為桌面端寬螢幕。
  * `isDesktopOrWebPlatform(context)`：判斷是否運行於桌面或 Web 環境（`kIsWeb` 或 Windows/macOS/Linux）。
  * `platformLabel(context)`：回傳當前運行環境的中文顯示名稱（如 `Web 網頁端`、`Windows 桌面端`、`Android 行動端`）。
  * `buildDrawerLeading(context)`：當處於窄螢幕且外層 `Scaffold` 含有 `Drawer` 時，自動產生左上角漢堡選單圖示按鈕。

---

### 2. `hoverable_card.dart` — 互動式懸停卡片元件 (`HoverableCard`)
* **核心定位**：兼顧桌面端滑鼠懸停（Hover）動態與行動端觸控水波紋（InkWell）的通用卡片容器。
* **核心特性與參數**：
  * **平滑微動畫**：滑鼠游標移入時（`MouseRegion`），卡片平滑上浮 `-3px`（`AnimatedContainer`），外框染色並加深立體陰影。
  * **參數支援**：
    * `child`：卡片內容元件。
    * `onTap`：點擊或觸控回呼事件。
    * `accentColor`：自訂強調色彩（懸停時外框線與底色自動融入此色系）。
    * `borderRadius`：圓角半徑（預設 `16.0`）。
    * `padding` / `margin`：自訂內距與外距。
    * `hoverTranslateY`：懸停垂直位移量（預設 `-3.0`）。

---

### 3. `app_notification.dart` — 跨平台自適應通知工具 (`AppNotification`)
* **核心定位**：統一全域系統提示與通知體驗，依據終端形態智能切換最佳展示形式。
* **核心特性**：
  * **電腦版（Web / Windows / 桌面端寬螢幕）**：
    * 使用 `OverlayEntry` 於視窗**右上角**以精緻懸浮卡片（Top-Right Floating Banner）呈現。
    * 具備滑入淡入（Slide + Fade）進場與退場微動畫、自動關閉倒數計時器（預設 3.5 秒）。
    * 支援手動「關閉 (X)」按鈕與自訂操作動作（如「復原」`actionLabel` / `onAction`）。
  * **行動端（Android / iOS 窄螢幕）**：
    * 自動切換為原生底部浮動 `SnackBar`（`SnackBarBehavior.floating`），符合行動單手操作人體工學。
* **呼叫方式**：
  ```dart
  AppNotification.show(
    context,
    title: '儲存成功',
    message: '課表內容已同步至雲端',
    icon: Icons.cloud_done_rounded,
    duration: const Duration(seconds: 3),
  );
  ```


