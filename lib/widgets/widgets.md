# `widgets/` 共用元件與響應式工具目錄簡介

`widgets/` 目錄封裝了 **UniTrack Pro** 跨頁面共用的可複用 UI 元件（Reusable Widgets）與跨平台響應式佈局工具，確保整體視覺風格一致，並同時最佳化桌面端滑鼠操作與行動端觸控體驗。

---

## 現有檔案說明

### 1. `responsive_layout.dart`
提供跨平台（Android、iOS、Web、Windows、macOS、Linux）的響應式斷點檢測與佈局分流工具：

* **`Breakpoints`**：定義統一的螢幕寬度斷點：
  * `mobile`: `< 600px`（手機端與窄視窗）
  * `tablet`: `600px ~ 960px`（平板與中尺寸視窗）
  * `desktop`: `>= 960px`（桌面端寬螢幕，並定義最大內容寬度 `1280px`）
* **`AdaptiveScrollBehavior`**：自定義跨平台滾動行為，支援觸控（Touch）、滑鼠拖曳（Mouse）、觸控板（Trackpad）與手寫筆（Stylus）流暢捲動。
* **`ResponsiveLayout`**：通用響應式容器元件，依據 `LayoutBuilder` 寬度自動切換渲染 `mobile`、`tablet` 或 `desktop` 子樹，並提供便捷的靜態輔助方法：
  * `isMobile(context)` / `isTablet(context)` / `isDesktop(context)`：視窗尺寸判斷。
  * `isDesktopOrWebPlatform(context)`：判斷是否運行於桌面或 Web 環境。
  * `platformLabel(context)`：回傳當前運行環境的中文顯示名稱（如 `Web 網頁端`、`Windows 桌面端`、`Android 行動端`）。
  * `buildDrawerLeading(context)`：當處於窄螢幕且外層 `Scaffold` 含有 `Drawer` 時，自動產生左上角漢堡選單按鈕。

### 2. `hoverable_card.dart`
* **`HoverableCard`**：兼顧桌面端滑鼠懸停（Hover）與行動端觸控水波紋（InkWell）的通用互動卡片元件。
* **核心特性**：
  * 當滑鼠游標移入（`MouseRegion`）時，具備平滑的上浮微動畫（`AnimatedContainer` 位移 `-3px`）、外框高亮染色與陰影加深效果。
  * 支援自訂強調色（`accentColor`）、圓角（`borderRadius`）、內外距（`padding` / `margin`）與點擊回呼（`onTap`）。
