# UniTrack+（校園生活助手 / UniTrack Pro）

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com/)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Web%20%7C%20Desktop-4CAF50?style=for-the-badge)](#)
[![Version](https://img.shields.io/badge/Version-0.11.0%2B1-blue?style=for-the-badge)](#)

> **專為大學生打造的一站式綜合校園生活與學業管理助手**  
> 具備高度自適應的現代化跨平台體驗（Android、Web、桌面端），整合雲端即時同步與直覺設計，讓課程安排與大學生活更加有條不紊。

---

## 📖 目錄

- [專案簡介](#-專案簡介)
- [核心功能介紹](#-核心功能介紹)
  - [學期課程表（Timetable）](#1-學期課程表timetable)
  - [會員驗證與雲端同步（Auth & Cloud Sync）](#2-會員驗證與雲端同步auth--cloud-sync)
  - [系統設定與個人化體驗（Settings & Personalization）](#3-系統設定與個人化體驗settings--personalization)
  - [未來規劃模組（Roadmap）](#4-未來規劃功能roadmap)
- [技術棧（Tech Stack）](#-技術棧tech-stack)
- [專案目錄結構](#-專案目錄結構)
- [快速開始與安裝指南](#-快速開始與安裝指南)
  - [環境需求](#1-環境需求)
  - [安裝依賴套件](#2-安裝依賴套件)
  - [Firebase 設定](#3-firebase-設定說明)
  - [常用執行與建置指令](#4-常用執行與建置指令)
- [授權與聲明](#-授權與聲明)

---

## 🌟 專案簡介

**UniTrack+**（又名 **UniTrack Pro / 校園生活助手**）是一款專為大學生設計的跨平台校園生活與學業輔助工具。

大學課表多元且時間分散，學生常需於行動裝置與筆電間頻繁切換。UniTrack+ 採用 Flutter 搭配 Firebase 雲端技術，提供兼具美觀、流暢度與跨平台一體化的使用體驗：在手機端給予輕巧的時間軸導航，在平板與桌面端則展開資訊豐富的完整課表與側邊欄導航，實現全終端無縫銜接。

---

## 🚀 核心功能介紹

### 1. 學期課程表（Timetable）
課表為 UniTrack+ 的核心模組，針對學生在不同使用情境下的痛點量身打造：

* **雙檢視模式切換**：
  * **單日時間軸檢視（Daily Timeline View）**：以時間為軸線條列今日或指定星期的各節課程與地點，最適合手機端快速掌握下一堂課。
  * **整週完整檢視（Weekly View，直向免滑動適配）**：精細調校手機直向比例與欄寬，即便在手機螢幕上也能一覽週一至週五整週網格，無需頻繁橫向滑動；在平板與桌面寬螢幕下則提供寬裕的卡片排版。
* **智慧日期計算與動態標記**：
  * 自動計算當週各星期的真實日曆日期並顯示於欄位表頭。
  * **今日高亮標記**：進入課表時自動定位並以主題色醒目標記當天日期，課程時間一目了然。
* **彈性週末顯示**：支援平日（週一至週五）與週末（含週六、週日）靈活切換。
* **課程管理功能**：支援課程的新增、編輯、刪除、教室地點設定與學分/修別標記。

---

### 2. 會員驗證與雲端同步（Auth & Cloud Sync）
* **Firebase Authentication 身分驗證**：
  * 支援以電子信箱與密碼（Email / Password）進行註冊與登入，註冊時包含入學年份（民國年或西元年）格式驗證與個人檔案建立。
  * 透過 `authStateChanges` 狀態流監聽機制，自動路由與狀態恢復（登入後自動進入主系統，登出後返回登入介面）。
  * 內建完整的錯誤碼轉譯機制，提供清晰友善的繁體中文提示（如密碼過短、帳號已存在、格式錯誤等）。
* **Cloud Firestore 個人化雲端資料庫**：
  * 課表資料依使用者 UID 存放於 `users/{uid}/courses` 集合路徑，保障個別隱私與資料隔離。
  * 結合 Firestore Stream Snapshot，任何裝置上的課表異動皆能**秒級即時同步（Real-time Synchronization）**。

---

### 3. 系統設定與個人化體驗（Settings & Personalization）
* **個人帳號管理**：提供頭像與認證身分標籤、姓名即時修改（同步至 Firebase Auth 與 Cloud Firestore）以及密碼重設信發送。
* **外觀主題模式切換**：支援跟隨系統、淺色模式與深色模式即時切換，全域動態響應並持久化儲存。
* **提醒與推播偏好**：提供上課前 10 分鐘課堂提醒、晨間待辦摘要提醒、夜間記帳提醒開關設定。
* **資料清理與重置**：支援一鍵清除目前帳號的所有雲端課表、本地待辦事項與偏好設定快取，且系統啟動時自動清理舊版遺留假資料。
* **響應式雙欄佈局**：於寬螢幕（`>= 840px`）下自動採用左右雙欄卡片排版，行動端則以單欄清單呈現。

---

### 4. 未來規劃功能（Roadmap）
本專案已建置各模組的前端架構與頁面入口，未來將陸續完善以下功能：

* 📅 **校園行事曆（Campus Calendar）**：學期重大日程、選退選週、期中/期末考排程整合與行事曆匯入。
* 🎓 **畢業審查（Graduation Audit）**：專業必修、選修、通識各向度學分計算器與門檻達標視覺化進度條。
* 💰 **記帳本（Campus Expense Tracker）**：專為大學生設計的收支紀錄、飲食/娛樂分類與每月預算控管。
* 📝 **待辦與作業管理（To-Do & Assignments）**：課程作業繳交倒數、報告分組待辦清單與課前提醒推播。

---

## 🛠 技術棧（Tech Stack）

| 領域 | 技術 / 套件 | 說明 |
| :--- | :--- | :--- |
| **前端框架** | **Flutter (Dart 3.x)** | 跨平台 UI 框架，支援 Material 3 現代化設計系統 |
| **身分驗證** | **Firebase Authentication** (`firebase_auth`) | 提供安全的身分驗證與狀態流監聽 |
| **雲端資料庫** | **Cloud Firestore** (`cloud_firestore`) | NoSQL 雲端即時同步資料庫 |
| **底層配置** | **Firebase Core** (`firebase_core`) | 初始化跨平台 Firebase 專案配置 |
| **本地設定與快取** | **Shared Preferences** (`shared_preferences`) | 輕量使用者偏好、主題設定與本地待辦快取持久化 |
| **介面架構** | **ResponsiveLayout** | 自適應行動端（Mobile）、平板（Tablet）與桌面端（Desktop）佈局架構 |
| **狀態流管理** | **Stream-based Architecture** | 基於 Dart `Stream` 與 `StreamBuilder` 的即時反應式狀態更新機制 |
| **全域主題響應** | **ValueNotifier / Listenable** | 基於 `ThemeSettings` 的零依賴輕量級全域動態主題更換機制 |

---

## 📂 專案目錄結構

```text
lib/
├── firebase_options.dart      # Firebase CLI 自動產生的跨平台連線配置檔
├── main.dart                  # 應用程式啟動入口、Firebase 初始化與全域主題動態配置
├── main_screen.dart           # 多平台響應式導覽主框架（App Shell / 側邊欄與底欄自適應導航）
│
├── models/                    # 資料結構與實體模型層 (Data Models)
│   ├── course.dart            # 課程實體類別（定義節次、星期、學分、修別與 Firestore 雙向轉換）
│   └── models.md              # 資料模型層設計架構說明
│
├── screens/                   # 使用者介面畫面層 (UI Screens)
│   ├── auth/                  # 會員身分驗證相關介面
│   │   ├── auth_gate.dart     # 身分驗證路由守衛（監聽登入狀態並動態切換畫面）
│   │   ├── login_screen.dart  # 會員登入畫面
│   │   └── register_screen.dart # 會員註冊畫面
│   ├── calendar_screen.dart   # 校園行事曆畫面
│   ├── dashboard_screen.dart  # 首頁儀表板總覽畫面（整合即時上課狀態、待辦管理與捷徑）
│   ├── expense_screen.dart    # 記帳本模組畫面
│   ├── graduation_screen.dart # 畢業學分審查畫面
│   ├── settings_screen.dart   # 系統設定畫面（帳號管理、主題模式、通知提醒與資料清除）
│   ├── timetable_screen.dart  # 學期課程表核心畫面（單日時間軸 / 整週檢視雙模式、即時同步）
│   └── screens.md             # 畫面層設計規範與功能說明
│
├── services/                  # 商業邏輯與資料存取服務層 (Services)
│   ├── auth_service.dart      # Firebase Auth 封裝服務（註冊、登入、登出與中文錯誤處理）
│   ├── course_service.dart    # Cloud Firestore 課表資料流監聽與 CRUD 雲端服務
│   ├── settings_service.dart  # 系統偏好、主題設定、通知開關與本地持久化服務
│   └── services.md            # 服務層架構規劃說明
│
└── widgets/                   # 跨模組共用元件與自適應工具 (Shared Widgets)
    ├── app_notification.dart  # 跨平台自適應懸浮通知與 SnackBar 工具
    ├── hoverable_card.dart    # 支援滑鼠懸停反饋與游標變化的互動卡片
    ├── responsive_layout.dart # 螢幕斷點響應式佈局輔助元件 (Mobile / Tablet / Desktop)
    └── widgets.md             # 元件庫使用與擴充規範
```

---

## ⚡ 快速開始與安裝指南

### 1. 環境需求
在開始前，請確保開發環境已安裝以下工具：
* **Flutter SDK**：`^3.13.0` 或更高版本（建議使用最新穩定版）
* **Dart SDK**：`^3.13.2`
* **開發工具**：VS Code 或 Android Studio（建議安裝 Flutter 與 Dart 外掛程式）
* **Google Chrome**（用於 Web 端預覽）或 **Android 模擬器 / 實體裝置**

確認環境配置無誤：
```bash
flutter doctor
```

---

### 2. 安裝依賴套件
進入專案根目錄並拉取所需套件依賴：
```bash
flutter pub get
```

---

### 3. Firebase 設定說明
本專案深度整合 Firebase 服務（身分驗證與雲端課表），需配置 `lib/firebase_options.dart`：

1. **安裝 FlutterFire CLI**（若尚未安裝）：
   ```bash
   dart pub global activate flutterfire_cli
   ```
2. **綁定 Firebase 專案**：
   在專案根目錄執行以下指令，選取或建立您的 Firebase 專案：
   ```bash
   flutterfire configure
   ```
   CLI 將會自動生成並更新 `lib/firebase_options.dart`。
3. **在 Firebase 控制台啟用服務**：
   * **Authentication**：至 Firebase Console > Authentication > Sign-in method，啟用 **電子信箱/密碼 (Email/Password)**。
   * **Cloud Firestore**：至 Firebase Console > Firestore Database 建立資料庫，並設定適當的安全規則（Security Rules）。

> 💡 **開發期測試規則範例（僅供開發階段參考）**：
> ```javascript
> rules_version = '2';
> service cloud.firestore {
>   match /databases/{database}/documents {
>     match /users/{userId}/{document=**} {
>       allow read, write: if request.auth != null && request.auth.uid == userId;
>     }
>   }
> }
> ```

---

### 4. 常用執行與建置指令

#### 啟動偵錯模式（Debug Mode）
* **在 Chrome 瀏覽器上執行（Web 端）**：
  ```bash
  flutter run -d chrome
  ```
* **在 Android 裝置或模擬器上執行**：
  ```bash
  flutter run -d android
  ```
* **在 Windows 桌面端執行**：
  ```bash
  flutter run -d windows
  ```
* **列出目前可用的所有裝置**：
  ```bash
  flutter devices
  ```

#### 專案打包與發布（Release Build）
* **建置 Android APK**：
  ```bash
  flutter build apk --release
  ```
* **建置 Android App Bundle (AAB)**：
  ```bash
  flutter build appbundle --release
  ```
* **建置 Web 靜態資源**：
  ```bash
  flutter build web --release
  ```

---

## 📄 授權與聲明

本專案供學習與大學校園生活管理使用。歡迎提交 Issue 或 Pull Request 共同完善功能！
