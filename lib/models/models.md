# `models/` 資料模型目錄簡介

`models/` 目錄負責定義 **UniTrack Pro** 應用程式中各功能模組所需的資料結構（Data Models）與列舉型別（Enums），確保跨頁面、服務與雲端資料庫（Cloud Firestore）之間的資料傳遞具備型別安全與一致性。

---

## 現有檔案說明

### 1. `course.dart`
定義與「課程表」、「首頁即時上課狀態」及「畢業學分審查」相關的核心資料結構與時間排程邏輯：

* **`CourseType` (Enum) 與 `CourseTypeExtension`**：
  * 區分課程的修別類型：
    * `required`：必修課程（對應中文標籤「必修」）
    * `elective`：選修課程（對應中文標籤「選修」）
    * `general`：通識課程（對應中文標籤「通識」）
  * 提供 `label` 擴充 getter 取得對應繁體中文顯示文字。

* **`TimetableSection` (Class)**：
  * 定義學校節次與真實時間區段的映射模型：
    * `section` (`int`)：節次索引值（如 `0` 代表晨間/第0節，`1` 代表第 1 節等）
    * `label` (`String`)：節次顯示名稱（如 `"1"`, `"2"`, `"A"`, `"B"`）
    * `startTime` (`String`)：開始時間（格式如 `"08:10"`）
    * `endTime` (`String`)：結束時間（格式如 `"09:00"`）
    * `timeRange` (`String`)：計算屬性，回傳格式化時間範圍（`"08:10 - 09:00"`）
  * 內建 `defaultSections` 靜態列表，提供涵蓋日間到夜間完整的標準大專院校節次時間表。

* **`Course` (Class)**：代表單一門課程的完整實體資訊：
  * **核心屬性**：
    * `id` (`String`)：課程唯一識別碼（對應 Firestore Document ID）
    * `name` (`String`)：課程名稱
    * `classroom` (`String`)：上課教室地點（例如：`工401`）
    * `professor` (`String`)：授課教師姓名
    * `weekday` (`int`)：上課星期（`1` 代表週一 ～ `7` 代表週日）
    * `startSection` / `endSection` (`int`)：起訖節次（用於計算課表網格跨度與衝堂檢查）
    * `credits` (`int`)：學分數（預設 `3` 學分，供畢業審查累計學分使用）
    * `type` (`CourseType`)：課程必選修分類
    * `color` (`Color`)：在課表網格與卡片上呈現的代表色彩
  * **雲端與序列化支援**：
    * `fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc, ...)`：由 Firestore 快照反序列化為 `Course` 實例。
    * `toFirestore()`：轉換為符合 Firestore 欄位格式的 Map 結構（顏色自動轉換為整數數值儲存）。
    * `fromMap(Map<String, dynamic> map, String id)` / `toMap()`：通用 Map 雙向轉換函式。
    * `copyWith(...)`：支援不可變狀態更新，便捷產生屬性異動後的新實體。

---

## 未來擴充規劃

隨著各功能頁面陸續完善，預計可於此目錄新增以下資料模型：
* **行事曆事件模型 (`calendar_event.dart`)**：記錄校園活動、選課日程、考試週期與個人待辦事項。
* **畢業門檻與審查模型 (`graduation_requirement.dart`)**：管理專業必修、選修與通識向度學分門檻與達標判定。
* **收支記帳模型 (`expense_record.dart`)**：記錄日常收支金額、分類標籤、消費日期與備註。

