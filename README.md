# mac-disk-space

磁碟快滿時，量出空間去哪了、哪些能清、清了能拿回多少。

與 [`mac-dropbox-fix`](https://github.com/MacHelpdesk/mac-dropbox-fix)、[`mac-timemachine-fix`](https://github.com/MacHelpdesk/mac-timemachine-fix) 同一個系列：先量測，再判讀，最後才動手。

> **狀態：設計中（v0.0.1）。** 這個 repo 目前只有骨架，還沒有可用的 skill 或腳本。需求與決定記在 [MacHelpdesk/mac-helpdesk#9](https://github.com/MacHelpdesk/mac-helpdesk/issues/9)，沒有任何行為已實測。

## 它要解決什麼

磁碟快滿時，「哪裡佔了空間、哪些能清、清了能拿回多少」三件事常常互相誤導：

| 你看到的 | 實際上 |
|---|---|
| `du` 量到某個快取幾百 GB，刪了 `df` 卻幾乎沒變 | APFS 用 clone 讓快取與其他檔案共用磁碟區塊，刪一邊不一定釋放 |
| 刪了大檔，空間沒有回來 | 時光機的本機快照還保留著那些檔案 |
| `df` 與 `du` 加起來對不上 | 記憶體交換檔在同一個容器的另一個卷，兩者都看不到 |
| 雲端資料夾很大，想刪掉本機那份 | 本機刪除會同步刪掉雲端；只能改成僅線上 |

## 預計的範圍（尚未實作）

- **量測（只讀）**：APFS 容器各卷、本機快照、swap、常見的候選位置；量不完的照實標記。
- **兩種量法**：叫它時量一次；每週在背景量一次，與上一次比較。
- **判讀**：已知問題的知識庫，格式沿用同系列工具的 `problems.json`。
- **能不能重建逐項判定**：候選清單只決定量哪裡，不決定可以刪。
- **界線**：每個會改動系統的動作都寫明是直接做、先問、由你做，還是不做。刪除你的檔案與雲端同步資料夾裡的檔案屬於不做。

範圍是封閉的：Mac 內建磁碟的空間。外接碟、網路磁碟、備份碟的內容都不處理（時光機的問題見 `mac-timemachine-fix`）。

## 這個 repo 只放方法與工具

你的量測紀錄與個人設定放在 `~/.config/mac-disk-space/`，不放在這個 repo 裡。

## 開發

```bash
for t in tests/test_*.sh; do /bin/bash "$t"; done
/bin/bash scripts/check-privacy.sh
```

腳本維持 macOS 內建 `/bin/bash` 3.2 相容，不解析會隨系統語言改變的文字。

## License

MIT
