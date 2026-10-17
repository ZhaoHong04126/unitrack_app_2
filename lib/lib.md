# `lib/` 專案核心程式碼目錄簡介

`lib/` 是 **校園生活助手 UniTrack Pro** 的核心原始碼目錄，採用清晰的分層與模組化架構設計，支援跨平台（Android、iOS、Web、Windows 等）響應式介面體驗。

## 目錄與檔案結構總覽

```text
lib/
├── firebase_options.dart      # Firebase CLI 自動產生的跨平台連線配置檔
├── main.dart                  # 應用程式啟動入口、Firebase 初始化與全域主題動態配置
├── main_screen.dart           # 多平台響應式導覽主框架（App Shell）
├── models/                    # 資料結構與實體模型層 (Data Models)
├── screens/                   # 各功能頁面畫面與身分驗證守衛 (UI Screens & Auth)
├── services/                  # 業務邏輯、Firebase 雲端同步與本地持久化服務 (Services)
└── widgets/                   # 跨頁面共用的通用元件與響應式工具 (Shared Widgets)
```

---

## 核心入口檔案說明

### 1. `main.dart`
* **功能定位**：應用程式啟動入口點（Entry Point）。
* **主要職責**：
  * 初始化 Flutter 綁定 (`WidgetsFlutterBinding.ensureInitialized()`)。
  * 初始化跨平台 Firebase 配置 (`Firebase.initializeApp`)。
  * 初始化系統設定與偏好服務 (`SettingsService().initialize()`)，讀取本地持久化的深淺色外觀設定並自動清理舊版遺留假資料快取。
  * 透過 `ValueListenableBuilder<ThemeSettings>` 監聽全域 `ThemeMode`（淺色/深色/跟隨系統）與主題色彩，實現無延遲、零額外第三方套件依賴的全域動態即時換色。
  * 掛載自定義的 `AdaptiveScrollBehavior`，讓滑鼠滾輪、觸控板與觸控螢幕皆具備流暢的拖曳滾動體驗。
  * 首頁掛載 `AuthGate`，依據 Firebase 登入狀態自動分流。

### 2. `main_screen.dart`
* **功能定位**：多平台響應式導覽主框架（App Shell / Navigation Host）。
* **主要職責**：
  * 整合六大核心功能分頁：**首頁總覽**、**課程表**、**校園行事曆**、**畢業審查**、**記帳本**、**系統設定**。
  * 接收外部傳入之目前登入使用者名稱（`userName`）與學系/電子郵件（`userDepartment`）。
  * 依據裝置平台與視窗寬度自動切換最佳導覽模式：
    * **行動裝置窄螢幕 (`Mobile`)**：原生行動端提供底部 `NavigationBar` 與側邊抽屜 `Drawer`；Web/桌面窄視窗則使用左上角漢堡選單開啟 `Drawer`。
    * **平板與中尺寸視窗 (`Tablet`)**：左側配置精簡型 `NavigationRail` 搭配右側主內容區。
    * **桌面與寬螢幕 (`Desktop`)**：左側配置完整展開的側邊導覽欄（含品牌標題、快速分頁導航、系統設定捷徑按鈕與登出按鈕）。
  * 整合標準登出確認對話框，呼叫 `AuthService().signOut()` 安全登出並透過 `AuthGate` 自動跳轉回登入畫面。

### 3. `firebase_options.dart`
* **功能定位**：由 FlutterFire CLI 自動生成的各平台（Web、Android、Windows、iOS、macOS）Firebase 專案金鑰與組態配置檔。

---

## 子目錄說明

* **[`models/`](./models/models.md)**：定義應用程式中使用的結構化資料模型（如課程實體 `Course`、修別列舉 `CourseType`、節次時間模型 `TimetableSection` 等）。
* **[`screens/`](./screens/screens.md)**：存放所有核心功能模組的獨立頁面與驗證流程（包含 `auth/` 身分驗證守衛與登入註冊頁面、首頁儀表板、即時同步課程表、校園行事曆、畢業審查、記帳本與系統設定）。
* **[`services/`](./services/services.md)**：封裝商業邏輯與資料存取層（包含 Firebase Auth 身分驗證 `AuthService`、Cloud Firestore 課表同步 `CourseService`，以及 SharedPreferences 本地持久化與主題設定 `SettingsService`）。
* **[`widgets/`](./widgets/widgets.md)**：封裝可重複使用的 UI 元件與跨平台佈局工具（如螢幕斷點分流 `ResponsiveLayout`、互動式卡片 `HoverableCard` 與自適應懸浮通知 `AppNotification`）。

