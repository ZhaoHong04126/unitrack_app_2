# `services/` 服務與資料處理層目錄簡介

`services/` 目錄用於存放 **UniTrack Pro** 的業務邏輯、資料持久化存取（Local Storage / Database）、狀態管理服務以及外部 API 串接模組，將資料處理邏輯與 UI 畫面（`screens/`）解耦。

---

## 設計職責與規劃方向

目前此目錄為預留架構，後續開發預計涵蓋以下核心服務模組：

1. **本地資料儲存服務 (`storage_service.dart`)**
   * 負責將課表（`Course`）、待辦事項、記帳紀錄與畢業學分設定儲存於裝置本地端（例如使用 `SharedPreferences`、`Hive` 或 `SQLite`），確保重啟應用後資料不遺失。

2. **課程與學分計算服務 (`course_service.dart` / `graduation_service.dart`)**
   * 提供課程衝堂檢查、每週上課時數統計，以及依課程修別（必修、選修、通識）自動彙整畢業審查所需的學分達成率。

3. **記帳與預算統計服務 (`expense_service.dart`)**
   * 負責計算當月總支出、剩餘可用預算、各消費類別佔比與收支篩選查詢。

4. **行事曆與通知提醒服務 (`notification_service.dart`)**
   * 管理課前提醒、作業繳交期限通知與校園重要日程推播。
