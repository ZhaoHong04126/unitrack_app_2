# `models/` 資料模型目錄簡介

`models/` 目錄負責定義 **UniTrack Pro** 應用程式中各功能模組所需的資料結構（Data Models）與列舉型別（Enums），確保跨頁面與服務之間的資料傳遞具備型別安全與一致性。

---

## 現有檔案說明

### 1. `course.dart`
定義與「課程表」及「畢業學分審查」相關的核心資料結構：

* **`CourseType` (Enum)**：區分課程的修別類型：
  * `required`：必修課程
  * `elective`：選修課程
  * `general`：通識課程
* **`Course` (Class)**：代表單一門課程的完整資訊：
  * `id` (`String`)：課程唯一識別碼
  * `name` (`String`)：課程名稱
  * `classroom` (`String`)：上課教室位置（例如：`工401`）
  * `professor` (`String`)：授課教師姓名
  * `weekday` (`int`)：上課星期（`1` 代表週一 ～ `5` 代表週五）
  * `startSection` / `endSection` (`int`)：起訖節次（用於計算課表網格跨度）
  * `credits` (`int`)：學分數（預設 `3` 學分，供畢業審查累計學分使用）
  * `type` (`CourseType`)：課程必選修分類
  * `color` (`Color`)：在課表與卡片上呈現的代表色

---

## 未來擴充規劃

隨著各功能頁面陸續完善，預計可於此目錄新增以下資料模型：
* **行事曆事件模型 (`calendar_event.dart`)**：記錄校園活動、考試日程與個人待辦事項。
* **畢業門檻與修課紀錄模型 (`graduation_requirement.dart`)**：管理各類學分門檻與歷年修課成績。
* **收支記帳模型 (`expense_record.dart`)**：記錄日常收支金額、分類標籤、日期與備註。
