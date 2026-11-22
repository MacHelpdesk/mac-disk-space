# Changelog

## 0.1.1 — 2026-11-23

0.1.0 發布後兩輪 spectra-verify 與 spectra-review 找到的問題。0.1.0 有一個嚴重錯誤（第一項），請更新。

### 修正

- 候選清單讀取時，指令欄空白的列不再整欄位移（連續的 tab 不再被合併）。0.1.0 在這種列上會把理由印進指令欄。
- 每次執行只建一個暫存目錄，結束時刪除；0.1.0 的 `probe` 每次會留下五個。
- 雲端同步資料夾的 `du` 與僅線上掃描共用同一個 60 秒；逾時被停止的量測不會留在背景。`du` 以非零狀態結束時，那一列是 `not-measured`。時間上限的輪詢前 1 秒改為每 0.1 秒一次。
- `sizes` 每量完一個位置就印一行（照候選清單的順序，不排序），中途被停下時保留已量完的列；收到 TERM 或 INT 時，正在跑的量測一起停。
- `online-only` 只把 `evict.js` 對那個路徑回報 `ok` 的檔案算成完成，其他都算失敗（結束碼 2）。判斷是否已是僅線上改用一次 `find`，不再每個檔案各跑一次 `stat`。`evict.js` 每處理完一個檔案就印出結果。`online-only` 被停下（TERM 或 INT）時，停掉正在跑的步驟，仍印出三個計數再結束。
- 暫存目錄建不起來時（例如磁碟全滿），直接結束並說明原因，結束碼 1，不再回報空的或不完整的結果。

### 資料與 skill

- `candidates.tsv`：`~/Library/CloudStorage` 拆成 Dropbox、OneDrive、Google Drive 三列，共二十一個位置。
- `SKILL.md`：`online-only` 的 Bash 逾時與被停下時輸出的意思；沒有指令的 cache、download、build 列與 `unsafe_` 列交給使用者；`sizes` 要把 Bash 逾時設到 330 秒以上或放到背景；`not-measured` 說明兩種原因；「無法估計（清了才知道）」的寫法統一。

### 規格

- 新增 `disk-space-online-only`；探測的卷角色、不安全字元改成封閉列舉（tab 屬於控制字元，算不安全）。

### 實測範圍

- 與 0.1.0 相同；0.1.1 的改動只在測試與替身指令上驗證，沒有重跑實機量測。

## 0.1.0 — 2026-11-22

第一個可用的版本。規格在 Spectra change `add-disk-space-measure-and-clean`（MacHelpdesk/mac-helpdesk#9）。

### Skill

- `disk-space`：量測 → 對照知識庫 → 量候選位置 → 逐項判定表 → 只做使用者點名的列（前後各量一次 `df`）→ 寫紀錄。界線是四張封閉列舉的表。

### Scripts

- `plugin/scripts/disk-space.sh`：`probe`、`sizes`、`candidates`、`match`、`list`、`show`、`validate` 只讀；`online-only` 只接受 iCloud 雲碟與 Dropbox 底下的路徑。
- `plugin/scripts/kb.js`：取自 mac-timemachine-fix。`capacity.js` 讀可清除量，`evict.js` 把檔案改成僅線上。

### 資料

- `problems.json` 六筆，全部 `unverified`。`candidates.tsv` 十九個位置，四欄（路徑、種類、指令、理由）；`personal`、`cloud-sync`、`system` 沒有指令。

### 實測範圍

- macOS 27.3（2026-11-22）：`probe` 實跑；`online-only` 的機制在 iCloud 雲碟與 Dropbox 各實測一個測試檔；`sizes` 實跑一次（見 README〈驗證到哪裡〉）。清理指令未驗證。

## 0.0.1 — 2026-11-22

骨架。只有 plugin manifest、文件、CI 與檢查腳本，還沒有 skill 或量測腳本。需求與決定見 MacHelpdesk/mac-helpdesk#9。
