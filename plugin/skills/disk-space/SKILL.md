---
name: disk-space
description: Mac 內建磁碟快滿時，量出空間去哪了（APFS 容器各卷、時光機本機快照、可清除量、記憶體交換檔、常見的快取與下載位置），對照已知情況，把每個位置列成一列讓使用者逐項判定，只做使用者點名的那幾列。使用者說「磁碟快滿了」「空間不夠」「Mac 沒空間」「刪了東西空間沒變」「哪些可以刪」「清一下快取」「騰出空間」時使用。雲端同步資料夾只能改成僅線上，不刪除。外接碟、網路磁碟、備份碟都不在範圍。
allowed-tools:
  - Read
---

# disk-space：磁碟快滿時，先量出空間去哪了，再逐項判定

磁碟快滿時，直覺的量法常常是錯的：`du` 量到某個快取幾百 GB，清掉之後 `df` 卻幾乎沒變（APFS clone 讓它和其他檔案共用區塊）；刪了大檔，空間沒有回來（時光機的本機快照還留著它）；`df /` 和家目錄的 `du` 都看不到記憶體交換檔。這個 skill 先把這些量出來，再把每個候選位置列成一列，由使用者決定哪幾列要處理。

**實測範圍**：`probe`、`online-only` 的機制在 macOS 27.3 實測過；知識庫每一筆都是 `unverified`，清理指令沒有在實機上由這個 skill 執行過。跟使用者說明時，把這個狀態一起說出來。

## Step 0：建立任務清單

用 TaskCreate 建立下面四個 task（subject 直接複製），一次建完。做完一個就標 completed。

| # | subject | 類型 |
|---|---|---|
| 1 | 派 agent 量測並對照知識庫 | 機械 |
| 2 | ⚠️ 核對列數，列出逐項判定表，問使用者要處理哪幾列 | **判斷** |
| 3 | 依界線處理使用者點名的列，前後各量一次 df | **判斷** |
| 4 | 寫紀錄 | 驗證 |

第 2 步不能省：表上最大的那一列不一定是最該清的，有些位置刪了就找不回來，只有使用者知道哪些東西重要。第 3 步只做點名的列：同一類的其他列，使用者沒點名就不動。

## 腳本與資料的位置

- 腳本：`${CLAUDE_PLUGIN_ROOT}/scripts/disk-space.sh`。讀不到時，改用載入本 skill 時顯示的 base directory 往上兩層的 `scripts/disk-space.sh`。下文寫成 `disk-space.sh <子命令>`，實際執行一律是 `/bin/bash <完整路徑> <子命令>`：腳本發布時不帶執行權限，直接執行會回 `permission denied`。
- 知識庫 `${CLAUDE_PLUGIN_ROOT}/data/problems.json`、候選清單 `${CLAUDE_PLUGIN_ROOT}/data/candidates.tsv`：隨 plugin 發布，不要改它們。
- 使用者自己的條目與位置：`~/.config/mac-disk-space/problems.local.json`、`~/.config/mac-disk-space/candidates.local.tsv`。
- 紀錄：`~/.config/mac-disk-space/records/`。

## 先講清楚的一件事

**候選清單只決定「要量哪裡」，不決定「可以刪」。** 列表之前先講這一句。清單上的每個位置，刪了會失去什麼都寫在那一列；要不要處理由使用者逐列決定。

## 行為界線

下面四張表是封閉列舉，不得依性質相似類推。知識庫解法的 `class` 與這裡不一致時，以比較嚴的那一邊為準。

### 直接做，做完回報：只有這五件

| # | 動作 |
|---|---|
| 1 | `disk-space.sh` 的 `probe`、`sizes`、`candidates`、`match`、`list`、`show`、`validate`（都只讀） |
| 2 | `df -k /` |
| 3 | 派 `mac-disk-space:disk-space-measure` agent 量測與判讀（它只跑唯讀指令，見 Step 1） |
| 4 | 在 `~/.config/mac-disk-space/records/` 寫這次的紀錄 |
| 5 | 在 `~/.config/mac-disk-space/problems.local.json` 新增條目，或在 `candidates.local.tsv` 新增一行，寫完跑 `validate` |

### 先問，使用者在這次對話同意才做：只有這三件

| # | 動作 | 問的時候要說的 |
|---|---|---|
| 1 | 執行種類是 `cache`、`download`、`build` 的列在指令欄寫的那一個指令（`sizes` 輸出的第 4 欄），原樣執行，不改寫、不加參數 | 刪了會失去什麼（理由欄）、之後要重新下載或重建，知道要多久時一併說（例如模型檔很大、要下載很久）；可釋放量寫「無法估計（清了才知道）」時照實說。來源是 `local` 的列（使用者自己的清單），先把指令全文給使用者看 |
| 2 | `disk-space.sh online-only <路徑>`，路徑是使用者點名的那一列、而且在 iCloud 雲碟或 Dropbox 資料夾底下 | 本機那份會被移除，內容留在雲端；離線時打不開，下次開啟要重新下載。腳本會拒絕這兩處以外的路徑 |
| 3 | 刪除時光機本機快照 | 快照裡保留了「快照之後被改寫或刪掉的檔案的舊版本」，刪了就救不回來；下一次備份可能要從頭掃描；要輸入管理者密碼 |

每一列做之前與做之後各跑一次 `df -k /`，把兩個數字都給使用者看。一次只做一列。

刪除本機快照要管理者權限。開一個「終端機」視窗並帶入指令，密碼由使用者在那個視窗輸入：

```bash
osascript -e 'tell application "Terminal"' -e 'activate' \
  -e 'do script "sudo tmutil deletelocalsnapshots /"' -e 'end tell'
```

- 不用 `sudo -S`、不把密碼寫進檔案或環境變數。
- 不請使用者在 Claude Code 輸入 `! sudo …`：`!` 沒有終端機，`sudo` 讀不到密碼而失敗。
- 刪完之後再跑一次 `probe`，看 `local_snapshots` 與 `df`。APFS 會在背景慢慢回收，可用空間在幾分鐘內持續增加是正常的，隔一兩分鐘再量一次。

### 只說明步驟，由使用者自己做：只有這五件

| # | 動作 | 原因 |
|---|---|---|
| 1 | 刪除使用者自己的檔案或資料夾，包括種類是 `personal` 的列 | 刪了會失去什麼只有使用者知道；這些列沒有指令 |
| 2 | 刪除種類是 `cache`、`download`、`build`、但指令欄是空的列（例如 DerivedData、下載的模型） | 這些位置沒有該工具自己的清理指令；不可以自己組指令，也不可以用 `rm -rf` 代替 |
| 3 | 關掉程式、虛擬機、Claude Code 的 session | 使用者手上的工作會中斷 |
| 4 | 把 OneDrive、Google Drive 等其他服務的檔案改成僅線上（在 Finder 對檔案按右鍵「移除下載項目」） | 這些服務的機制還沒有驗證 |
| 5 | 種類是 `system` 的列裡、需要管理者權限的動作（本機快照除外） | 系統層級的檔案 |

### 不做

`disk-space.sh show <id>` 的最後一段會印出知識庫的 `never` 清單，一共五項：

- 不刪除、不修改雲端同步資料夾（Dropbox、OneDrive、Google Drive、iCloud 雲碟）裡的任何檔案：本機刪除會同步刪除雲端那份。使用者要求刪掉雲端資料夾時，說明這一點，改提議僅線上。
- 不用 `rm -rf` 清快取資料夾，取代該工具自己的清理指令。
- 不碰備份碟。
- 不把密碼放進對話、檔案或環境變數。
- 不處理使用者沒有點名的列，不把同意擴大到同一類的其他列。

## Step 1：派 agent 量測與判讀

量測的輸出很長（`sizes` 可能有上百列），交給 agent 做，主對話只留整理好的報告。

先跟使用者說一句：「量測交給 `disk-space-measure` agent 做，最多 5 分鐘，它只跑唯讀指令。」然後用 Agent 工具派出，subagent 類型是 `mac-disk-space:disk-space-measure`。任務訊息只寫兩件事：

- `disk-space.sh` 的完整路徑（見〈腳本與資料的位置〉），寫成「腳本：<完整路徑>」。
- 「量測並交回報告」。

使用者要求清理的話（例如「清一下快取」）不要轉給 agent：agent 不清理，清理在 Step 3 由主對話逐列問過才做。

agent 交回的報告有四個部分：`Signals`（`probe` 的輸出）、`Matched entries`（比對到的知識庫條目與解法）、`Candidates`（一個位置一列）、最後一行核對數字。讀 `Signals` 時最常用的訊號：

| 訊號 | 看什麼 |
|---|---|
| `container_free_pct`、`container_free_gb` | 剩不到 10% 或不到 50 GB 就是「快滿了」 |
| `purgeable_gb` | 系統可以從可清除資料拿回的總量。**包含本機快照與其他可清除的資料，不是只有快照**；快照單獨佔多少量不出來 |
| `local_snapshots` | 時光機本機快照的數量；快照還在，刪掉的檔案就還佔著空間 |
| `volume_used_gb_VM`、`swap_used_gb` | 記憶體交換檔；`df /` 看不到 |
| `probe_result` | `partial` 表示有來源讀不到，那些訊號沒有印出；照實說，不要補猜的數字 |

`Candidates` 表裡種類以 `unsafe_` 開頭的列，路徑含 shell 特殊字元或控制字元、已經跳脫過；不要把它放進任何指令，原樣給使用者看。

### 核對列數

報告最後一行是 `sizes_rows=<n> table_rows=<n> not_measured=<n> matched=<n>`。自己數 `Candidates` 表有幾列，和 `sizes_rows` 比：

| 你數到的列數與 `sizes_rows` | 最後一行 | 怎麼做 |
|---|---|---|
| 相同 | 有 | 繼續 Step 2 |
| 不同 | 有 | 跟使用者說量到幾列、交回幾列，然後退回自己量 |
| 無法比較 | 沒有 | 跟使用者說報告缺核對數字，然後退回自己量 |

這個核對抓得到表格掉了幾列；agent 把兩個數字數錯成同一個值時抓不到。

### 退回自己量：只有這四種

下面四種情形，改由主對話自己量。這張表是封閉列舉，不得依性質相似類推。

| # | 情形 |
|---|---|
| 1 | 使用者不同意把量測交給 agent |
| 2 | 這個 session 沒有 Agent 工具，或找不到 `mac-disk-space:disk-space-measure` |
| 3 | agent 回報錯誤，或沒有交回報告 |
| 4 | 核對列數沒有通過（上一張表的後兩列） |

先跟使用者說一句「改成在這個對話裡直接量」和原因，再依序跑：

```bash
disk-space.sh probe
disk-space.sh match
disk-space.sh sizes 5
```

- `probe` 不到一秒，把輸出原樣給使用者看。
- `match` 每行一筆：`id`、驗證狀態、來源、標題。對每個 `id` 跑 `disk-space.sh show <id>`。結束碼 3 是沒有比對到：照實說，繼續下一個指令。
- `sizes 5` 最多 5 分鐘：每個位置最多 60 秒，超過的那一列是 `not-measured`，不算進任何總數。只量清單上的位置，不掃整個家目錄。每行是 tab 分隔的七欄：大小（GB）、種類、路徑、指令、理由、來源（`shipped` 或 `local`）、僅線上 GB（只有 `cloud-sync` 列有）。

## Step 2：逐項判定表

先講「清單只決定要量哪裡，不決定可以刪」，再列一張表，一個位置一列：

| # | 位置 | 大小 | 是什麼、刪了會失去什麼 | 清理方式 | 能拿回多少 |
|---|---|---|---|---|---|
| 1 | `~/.cache/uv` | 40 GB | uv 的套件快取；之後安裝會重新下載 | `uv cache prune`（先問） | 無法估計（清了才知道；與虛擬環境共用區塊） |
| 2 | `~/Library/CloudStorage/Dropbox` | 本機 80 GB，已僅線上 30 GB | Dropbox 的同步資料夾；刪除會同步刪除雲端 | 改成僅線上（先問） | 改成僅線上的部分 |
| 3 | `~/Parallels` | 60 GB | 虛擬機；刪除就失去虛擬機 | 由你自己決定與操作 | 刪除才拿得回 |
| 4 | 時光機本機快照 | `local_snapshots=2` | 快照之後被改寫或刪掉的檔案的舊版本 | 刪除本機快照（先問） | `purgeable_gb` 的一部分，單獨多少量不出來 |

（數字是格式範例，不是實際量測。）

- 「清理方式」照四張界線表寫，每一列只會是下面其中一種：
  - 種類是 `cache`、`download`、`build` 而且有指令：寫那個指令，標「先問」。
  - 種類是 `cache`、`download`、`build` 但沒有指令，或種類是 `personal`：寫「由你自己決定與操作」。
  - 種類是 `cloud-sync`、路徑在 iCloud 雲碟或 Dropbox 底下：寫「改成僅線上（先問）」。
  - 種類是 `cloud-sync` 的其他服務（OneDrive、Google Drive）：寫「在 Finder 改成僅線上（由你自己做）」。
  - 種類是 `system`：寫「由你自己做」。
- 「能拿回多少」估不出就寫「無法估計（清了才知道）」，不給猜的數字。
- `not-measured` 的列也列出來，寫明「量不完」。

最後一次問完：「要處理哪幾列？」使用者回的列號就是這次能做的全部。

## Step 3：依界線處理

只做使用者點名的列，一次一列，照〈行為界線〉的表決定誰動手。每一列：

1. `df -k /`，記下可用空間。
2. 做那一列的動作。
3. `df -k /`，把前後兩個數字給使用者看。拿回的空間比量到的少時照實說，並說明可能的原因（區塊共用、本機快照）。

## Step 4：寫紀錄

寫到 `~/.config/mac-disk-space/records/`，檔名 `YYYY-MM-DDTHHMM±HHMM_<地點>.md`：處理前後的 `probe` 輸出、比對到的條目、使用者點名的列、每一列前後的可用空間。這份紀錄只留在使用者的電腦上。

## 驗證到哪裡

| 行為 | 狀態 |
|---|---|
| `probe` 讀出容器各卷、可清除量、本機快照、swap | 已實測一次（macOS 27.3，2026-11-22），不到一秒；可用空間與 `df` 一致 |
| `purgeable_gb` 的量法（兩個容量值相減） | 已實測一次；它包含哪些資料沒有逐項驗證 |
| `online-only` 的機制（`evictUbiquitousItemAtURL`） | iCloud 雲碟、Dropbox 各實測一個測試檔（macOS 27.3）：1 秒內變成 `dataless`，再讀一次內容完整；`online-only` 子命令本身只在 `tests/test_online_only.sh` 驗過 |
| `sizes` 的時間上限與 `not-measured` | 已實測一次（macOS 27.3）：整次 300 秒用完，萬用字元展開成兩百多列、大部分沒量到。標記照規格運作；列數過多的問題追蹤在 MacHelpdesk/mac-disk-space#1 |
| 刪除本機快照後可用空間回升 | 在 macOS 27.3 手動做過一次（不是由這個 skill 執行）：刪完後幾分鐘內持續增加 |
| 候選清單裡的清理指令 | 未驗證 |
| `disk-space-measure` agent（由 skill 派出量測與判讀） | 未驗證。唯讀界線靠工具清單（只有 Bash 與 Read）與定義檔裡的封閉列舉，平台不會強制；agent 實際跑了哪些指令，要在實機上讀它的 transcript 才知道 |
| 其他 macOS 版本 | 未驗證。讀不到的訊號不會出現，也不會被當成比對到 |
