# mac-disk-space

磁碟快滿時，量出空間去哪了、哪些能清、清了能拿回多少。

與 [`mac-dropbox-fix`](https://github.com/MacHelpdesk/mac-dropbox-fix)、[`mac-timemachine-fix`](https://github.com/MacHelpdesk/mac-timemachine-fix) 同一個系列：先量測，再判讀，最後才動手。

> **狀態：v0.1.0。** `probe` 與 `sizes` 在 macOS 27.3 上實跑過一次；`online-only` 的機制在 iCloud 雲碟與 Dropbox 各實測一個測試檔。知識庫每一筆都是 `unverified`，候選清單裡的清理指令沒有由這個 skill 在實機上執行過。見〈驗證到哪裡〉。

## 它解決什麼

磁碟快滿時，直覺的量法常常互相誤導：

| 你看到的 | 實際上 |
|---|---|
| `du` 量到某個快取幾百 GB，清了 `df` 卻幾乎沒變 | APFS 用 clone 讓快取與其他檔案共用磁碟區塊，刪一邊不一定釋放 |
| 刪了大檔，空間沒有回來 | 時光機的本機快照還保留著那些檔案 |
| `df` 與 `du` 加起來對不上 | 記憶體交換檔在同一個容器的另一個卷，兩者都看不到 |
| 雲端資料夾很大，想刪掉本機那份 | 本機刪除會同步刪除雲端；只能改成僅線上 |

**候選清單只決定「要量哪裡」，不決定「可以刪」。** 每個位置刪了會失去什麼都寫在那一列，由你逐列決定。

範圍是封閉的：Mac 內建磁碟的空間。外接碟、網路磁碟、備份碟都不處理（時光機的問題見 `mac-timemachine-fix`）。

## 四個部分

| 部分 | 位置 | 做什麼 |
|---|---|---|
| skill | `/mac-disk-space:disk-space` | 量測 → 對照知識庫 → 量候選位置 → 逐項判定表 → 只做你點名的列，前後各量一次 `df` → 寫紀錄 |
| 知識庫 | `plugin/data/problems.json` | 每種情況的症狀、訊號、原因、解法、驗證到哪裡，以及任何情況都不做的事 |
| 候選清單 | `plugin/data/candidates.tsv` | 要量的位置，四欄：路徑、種類、清理指令、理由。`personal`、`cloud-sync`、`system` 沒有指令 |
| 腳本 | `plugin/scripts/disk-space.sh` | 量測、比對；`online-only` 是唯一會改動東西的子命令 |

## 腳本

```bash
disk-space.sh probe             # signal=value，一行一個；不到一秒
disk-space.sh sizes 5           # 候選位置的大小（GB），最多 5 分鐘；量不完的標 not-measured
disk-space.sh match             # 比對到的已知情況；結束碼 3 是沒有比對到
disk-space.sh show <id>         # 一種情況的完整內容
disk-space.sh validate          # 檢查知識庫與候選清單（含你自己的追加）
disk-space.sh online-only PATH  # 把 PATH 底下已下載的檔案改成僅線上（只限 iCloud 雲碟與 Dropbox）
```

`probe` 輸出的範例（數字是虛構的）：

```
container_free_pct=4
container_free_gb=40
volume_used_gb_Data=900
volume_used_gb_VM=40
purgeable_gb=120
local_snapshots=2
swap_used_gb=38
probe_result=ok
```

`purgeable_gb` 是系統可以從可清除資料拿回的總量，包含本機快照與其他可清除的資料，不是只有快照；快照單獨佔多少量不出來。

不解析會隨系統語言改變的文字：容量讀 `diskutil … -plist` 與系統的容量值，快照只認 `YYYY-MM-DD-HHMMSS` 格式的名稱。

## 這個 repo 只放方法與工具

你的量測紀錄與個人設定放在 `~/.config/mac-disk-space/`，不放在這個 repo 裡：

```
~/.config/mac-disk-space/
├── candidates.local.tsv   # 你自己要量的位置（選用，格式同 candidates.tsv）
├── problems.local.json    # 你自己的條目（選用）
└── records/               # 每次處理的紀錄
```

## 驗證到哪裡

| 行為 | 狀態 |
|---|---|
| `probe` 讀出容器各卷、可清除量、本機快照、swap | 已實測一次（macOS 27.3，2026-11-22），不到一秒；可用空間與 `df` 一致 |
| `purgeable_gb` 的量法 | 已實測一次；它包含哪些資料沒有逐項驗證 |
| `sizes` 的時間上限與 `not-measured` | 已實測一次（macOS 27.3，2026-11-22）：整次 300 秒用完。萬用字元 `/Users/Shared/* Library` 在那台 Mac 上展開成兩百多個資料夾、每個一列，大部分沒量到；一個很大的套件快取超過 60 秒。標記照規格運作，但列數多到無法逐項判定，見 MacHelpdesk/mac-disk-space#1 |
| `online-only` 的機制（`evictUbiquitousItemAtURL`） | iCloud 雲碟、Dropbox 各實測一個測試檔：1 秒內變成僅線上，再讀一次內容完整。子命令本身只在 `tests/test_online_only.sh` 驗過 |
| 刪除本機快照後可用空間回升 | 手動做過一次（不是由這個 skill 執行）：刪完後幾分鐘內持續增加 |
| 候選清單裡的清理指令、OneDrive 與 Google Drive 的僅線上 | 未驗證 |
| `disk-space-measure` agent（由 skill 派出量測與判讀） | 未驗證。唯讀界線靠工具清單（只有 Bash 與 Read）與定義檔裡的封閉列舉，平台不會強制；agent 實際跑了哪些指令，要在實機上讀它的 transcript 才知道 |
| 其他 macOS 版本 | 未驗證。讀不到的訊號不會出現，也不會被當成比對到 |

## 開發

```bash
for t in tests/test_*.sh; do /bin/bash "$t"; done
/bin/bash scripts/check-privacy.sh
```

測試用合成的 plist 與替身指令（`tests/fixtures/`、`tests/stubs/`），不讀這台 Mac 的磁碟、快照與雲端。腳本維持 macOS 內建 `/bin/bash` 3.2 相容，不用 `timeout`、`jq`、`python3`。

## License

MIT
