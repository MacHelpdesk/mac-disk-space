# Changelog

## 0.2.0 — 2026-11-23

量測交給 subagent。規格在 Spectra change `idd-3-disk-space-measure-agent`（MacHelpdesk/mac-disk-space#3）。

### Agent

- 新增 `mac-disk-space:disk-space-measure`（`plugin/agents/disk-space-measure.md`，model `sonnet`，工具只有 Bash 與 Read）。它只跑五個唯讀指令（`probe`、`match`、`show`、`sizes 5`、`df -k /`），交回固定格式的報告，最後一行是核對數字。不清理、不改設定、不寫檔。
- 唯讀界線靠工具清單與定義檔裡的封閉列舉。Claude Code 不提供針對 plugin subagent 的逐指令限制，所以平台不會強制這條界線。

### Skill

- `disk-space` 的量測、對照知識庫、量候選位置三步合成一步：派 agent，拿回報告後核對列數，再列逐項判定表。任務清單從六項變四項。
- 四種情形退回在主對話直接量（使用者不同意、沒有 Agent 工具、agent 失敗、核對列數沒過），先跟使用者說一句。
- 「直接做」的表從四件變五件，多了派 agent。清理、問使用者、寫紀錄都留在主對話，界線不變。

### 測試

- `tests/test_agent.sh`：定義檔的 frontmatter 與工具清單、指令清單與 `disk-space.sh` 的子命令一致、報告格式、skill 的五件／四種／三種情形，以及 agent 與退路列的子命令相同。

### 修正（第一次實機執行發現）

- `disk-space.sh` 發布時不帶執行權限，直接執行回 `permission denied`（0.1.0 的 skill 也是這樣呼叫）。skill 與 agent 都改成 `/bin/bash <完整路徑> <子命令>`。
- agent 一次 Bash 呼叫只放一個指令；指令失敗時回報、不診斷。

### 實測範圍

- agent 標為未驗證：列數相符、指令都在清單內、版本都已記錄，但互動 session 的權限提示次數沒有量到。細節在 README〈驗證到哪裡〉。

### 規格

- 前一個 change `add-disk-space-measure-and-clean` 封存，四份主規格建立在 `docs/spectra/specs/`。

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
