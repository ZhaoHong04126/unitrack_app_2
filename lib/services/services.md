# `services/` 服務與資料處理層目錄簡介

`services/` 目錄負責封裝 **UniTrack Pro** 的核心業務邏輯、Firebase 雲端資料庫存取、身分驗證、狀態串流以及本地偏好持久化（Local Persistence），將繁複的非同步資料操作與 UI 畫面（`screens/`）完全解耦。

---

## 現有服務模組詳情

### 1. `auth_service.dart` — Firebase 身分驗證服務 (`AuthService`)
* **設計模式**：單例模式（Singleton Pattern，`AuthService()`）。
* **核心職責**：
  * **狀態流監聽**：提供 `Stream<User?> get authStateChanges`，供 `AuthGate` 自動進行登入/登出畫面分流。
  * **註冊帳號 (`signUpWithEmail`)**：
    * 建立 Firebase Auth 帳號。
    * 同步更新使用者顯示名稱（`displayName`）。
    * 自動於 Cloud Firestore `users/{uid}` 建立個人設定文件（儲存姓名、入學年度與建立時間戳記）。
  * **登入帳號 (`signInWithEmail`)**：驗證信箱與密碼。
  * **重設密碼信 (`sendPasswordResetEmail`)**：向指定 Email 發送官方重設密碼連結。
  * **登出帳號 (`signOut`)**：安全登出並觸發驗證狀態流變更。
  * **個人資料更新 (`updateProfileName`)**：同步更新 Firebase Auth 使用者名稱與 Firestore 資料文件。
  * **例外錯誤中文化 (`AuthException`)**：攔截 `FirebaseAuthException`，將常見錯誤碼（如 `user-not-found`, `wrong-password`, `email-already-in-use`, `weak-password`, `invalid-email` 等）自動轉譯為繁體中文友善提示。

---

### 2. `course_service.dart` — 雲端課表資料服務 (`CourseService`)
* **設計模式**：單例模式（Singleton Pattern，`CourseService()`）。
* **核心職責**：
  * **使用者資料隔離**：以目前登入之 `currentUserId` 為依據，存取路徑為 `users/{uid}/courses` 的子集合，保障個人資料獨立性與隱私。
  * **強型別 Firestore Converter**：利用 `.withConverter<Course>` 自動處理 `Course.fromFirestore` 與 `toFirestore` 序列化。
  * **即時資料串流 (`getCoursesStream()`)**：
    * 監聽集合快照（`snapshots()`），任何裝置上的資料變動皆能即時推送給前端 `StreamBuilder`。
    * 串流自動依照「星期（週一至週日）」與「開始節次」進行升冪排序。
  * **單次讀取 (`getCoursesOnce()`)**：供無即時監聽需求之統計計算或一次性載入使用。
  * **CRUD 操作**：
    * `addCourse(Course course)`：新增課程至雲端，自動產生唯一 ID。
    * `updateCourse(Course course)`：更新既有課程資訊。
    * `deleteCourse(String courseId)`：刪除指定課程。

---

### 3. `settings_service.dart` — 系統偏好與設定服務 (`SettingsService`)
* **設計模式**：單例模式（Singleton Pattern，`SettingsService()`）。
* **核心職責**：
  * **非同步初始化 (`initialize()`)**：在 `main.dart` 啟動階段讀取 `SharedPreferences` 中的偏好快取。
  * **全域主題響應 (`themeNotifier`)**：
    * 提供 `ValueNotifier<ThemeSettings>`，無須依賴龐大的第三方狀態管理庫即可實現全域主題色彩與 `ThemeMode`（淺色/深色/跟隨系統）即時換色。
    * 內建 7 款 Material 3 主題代表色：經典靛藍、蔚藍晴空、海島藍綠、典雅紫羅蘭、活力暖橘、森林翠綠、櫻花淡粉。
  * **學籍與學期偏好**：
    * 持久化儲存學系名稱、學號與當前學年度學期（連動儀表板與課表顯示）。
  * **課表偏好設定**：週末課表（週六週日）預設顯示開關。
  * **提醒推播設定**：課前 10 分鐘通知、早晨待辦摘要、夜間記帳提醒設定。
  * **備份與還原**：
    * `exportSettingsAsJson()`：將所有本地設定封裝為標準 JSON 格式字串。
    * `resetToDefaults()`：一鍵重設所有個人偏好為出廠設定。

---

## 未來擴充規劃

後續版本隨著模組陸續完備，預計擴充以下服務：
* **`expense_service.dart`**：記帳收支統計、月預算超支警示與分類圓餅圖計算服務。
* **`calendar_service.dart`**：校園重大行事曆雲端同步與個人活動排程服務。
* **`graduation_service.dart`**：各學系畢業必選修、通識各向度學分檢核計算引擎。
* **`notification_service.dart`**：整合本地推播（Local Notifications）實現課前與待辦定時推播。


