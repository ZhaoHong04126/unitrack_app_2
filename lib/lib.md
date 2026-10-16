# `lib/` 專案核心程式碼目錄簡介

`lib/` 是 **校園生活助手 UniTrack Pro** 的核心原始碼目錄，採用清晰的分層與模組化架構設計，支援跨平台（Android、iOS、Web、Windows 等）響應式介面體驗。

## 目錄與檔案結構總覽

```text
lib/
├── main.dart               # 應用程式入口與主題配置
├── main_screen.dart        # 多平台響應式導覽主框架
├── models/                 # 資料模型定義 (Data Models)
├── screens/                # 各功能頁面畫面 (UI Screens)
├── services/               # 業務邏輯、資料儲存與外部服務 (Services)
└── widgets/                # 跨頁面共用的通用元件與響應式工具 (Shared Widgets)
```

---

## 核心入口檔案說明

### 1. `main.dart`
* **功能定位**：應用程式啟動入口點（Entry Point）。
* **主要職責**：
  * 執行 `runApp(const CampusAssistantApp())` 啟動應用。
  * 設定全域 Material 3 主題（以 `Colors.indigo` 作為主題色種子）。
  * 掛載自定義的 `AdaptiveScrollBehavior`，讓滑鼠滾輪、觸控板與觸控螢幕皆具備流暢的拖曳滾動體驗。
  * 指定首頁框架為 `MainScreen`。

### 2. `main_screen.dart`
* **功能定位**：多平台響應式導覽主框架（App Shell / Navigation Host）。
* **主要職責**：
  * 整合六大核心功能分頁：**首頁總覽**、**課程表**、**校園行事曆**、**畢業審查**、**記帳本**、**系統設定**。
  * 依據裝置平台與視窗寬度自動切換最佳導覽模式：
    * **行動裝置窄螢幕 (`Mobile`)**：原生行動端提供底部 `NavigationBar` 與側邊抽屜 `Drawer`；Web/桌面窄視窗則使用左上角漢堡選單開啟 `Drawer`。
    * **平板與中尺寸視窗 (`Tablet`)**：左側配置精簡型 `NavigationRail` 搭配右側主內容區。
    * **桌面與寬螢幕 (`Desktop`)**：左側配置完整展開的側邊導覽欄（含品牌標題與底部學生資訊卡，整合系統設定捷徑按鈕）。

---

## 子目錄說明

* **[`models/`](./models/models.md)**：定義應用程式中使用的結構化資料模型（如課程 `Course`、修別列舉 `CourseType` 等）。
* **[`screens/`](./screens/screens.md)**：存放五大核心功能模組的獨立頁面（首頁儀表板、課表、行事曆、畢業學分審查、記帳本）。
* **[`services/`](./services/services.md)**：預留供本地端資料持久化、API 串接、狀態同步或通知提醒等背景服務使用。
* **[`widgets/`](./widgets/widgets.md)**：封裝可重複使用的 UI 元件與跨平台佈局工具（如 `ResponsiveLayout` 與 `HoverableCard`）。
