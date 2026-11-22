# Changelog

## 0.1.0 — 2026-11-22

第一個可用的版本。規格在 Spectra change `add-disk-space-measure-and-clean`（MacHelpdesk/mac-helpdesk#9）。

### Skill

- `disk-space`：量測 → 對照知識庫 → 量候選位置 → 逐項判定表 → 只做使用者點名的列（前後各量一次 `df`）→ 寫紀錄。界線是四張封閉列舉的表。

### Scripts

- `plugin/scripts/disk-space.sh`：`probe`、`sizes`、`candidates`、`match`、`list`、`show`、`validate` 只讀；`online-only` 只接受 iCloud 雲碟與 Dropbox 底下的路徑。
- `plugin/scripts/kb.js`：取自 mac-timemachine-fix。`capacity.js` 讀可清除量，`evict.js` 把檔案改成僅線上。

### 資料

- `problems.json` 六筆，全部 `unverified`。`candidates.tsv` 二十一個位置（雲端同步資料夾依服務分列），四欄（路徑、種類、指令、理由）；`personal`、`cloud-sync`、`system` 沒有指令。

### 驗證後的修正（spectra-verify 與 spectra-review）

- 候選清單讀取時，指令欄空白的列不再整欄位移（連續的 tab 不再被合併）。
- 每次執行只建一個暫存目錄，結束時刪除；先前 `probe` 每次會留下五個。
- 雲端同步資料夾的 `du` 與僅線上掃描共用同一個 60 秒；逾時被停止的掃描不會留在背景。`du` 以非零狀態結束時，那一列是 `not-measured`。
- `online-only` 把 `evict.js` 沒有回報的檔案算成失敗，結束碼 2。
- 時間上限的輪詢前 1 秒改為每 0.1 秒一次。
- 新增規格 `disk-space-online-only`；沒有指令的 cache、download、build 列，刪除交給使用者。

### 實測範圍

- macOS 27.3（2026-11-22）：`probe` 實跑；`online-only` 的機制在 iCloud 雲碟與 Dropbox 各實測一個測試檔；`sizes` 實跑一次（見 README〈驗證到哪裡〉）。清理指令未驗證。

## 0.0.1 — 2026-11-22

骨架。只有 plugin manifest、文件、CI 與檢查腳本，還沒有 skill 或量測腳本。需求與決定見 MacHelpdesk/mac-helpdesk#9。
