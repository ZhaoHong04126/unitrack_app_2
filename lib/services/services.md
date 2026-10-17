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
  * **個人資料更新 (`updateDisplayName`)**：同步更新 Firebase Auth 使用者名稱與 Firestore 資料文件。
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
  * **CRUD 與批次清除操作**：
    * `saveCourse(Course course)`：新增或更新課程至雲端（若 `id` 為空則自動產生文件 ID）。
    * `deleteCourse(String courseId)`：依據文件 ID 刪除指定雲端課程。
    * `clearAllCourses()`：批次刪除清空目前使用者的所有雲端課程。

---

### 3. `settings_service.dart` — 系統偏好與設定服務 (`SettingsService`)
* **設計模式**：單例模式（Singleton Pattern，`SettingsService()`）。
* **核心職責**：
  * **非同步初始化與假資料清理 (`initialize()`)**：在 `main.dart` 啟動階段讀取 `SharedPreferences` 中的偏好快取，並自動清除舊版遺留的預設假資料與廢棄鍵值（`_legacyFakeKeys`）。
  * **全域主題響應 (`themeNotifier`)**：
    * 提供 `ValueNotifier<ThemeSettings>`，無須依賴龐大的第三方狀態管理庫即可實現全域主題模式 `ThemeMode`（淺色/深色/跟隨系統）與主題代表色即時切換。
  * **課表與提醒偏好設定**：
    * `setClassReminder(bool)`：上課前 10 分鐘課堂提醒開關。
    * `setTodoReminder(bool)`：晨間待辦摘要提醒開關。
    * `setExpenseReminder(bool)`：夜間記帳提醒開關。
    * `setWeekendTimetable(bool)`：週末課表預設顯示開關。
  * **資料重置 (`resetToDefaults()`)**：一鍵清空本地所有 `SharedPreferences` 快取資料（含待辦事項與偏好設定）並還原為出廠預設值。

---

## 未來擴充規劃

後續版本隨著模組陸續完備，預計擴充以下服務：
* **`expense_service.dart`**：記帳收支統計、月預算超支警示與分類圓餅圖計算服務。
* **`calendar_service.dart`**：校園重大行事曆雲端同步與個人活動排程服務。
* **`graduation_service.dart`**：各學系畢業必選修、通識各向度學分檢核計算引擎。
* **`notification_service.dart`**：整合本地推播（Local Notifications）實現課前與待辦定時推播。


