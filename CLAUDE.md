# CLAUDE.md

MacHelpdesk 系列的磁碟空間工具。整個系列共用的規則（公開 repo 不寫任何人的環境、只寫實測過的行為、會改設定的動作寫明界線、`/bin/bash` 3.2 相容、Git 流程）在 umbrella repo `MacHelpdesk/mac-helpdesk` 的 CLAUDE.md，這裡不重抄。

## 狀態

設計中。需求、決定與診斷在 MacHelpdesk/mac-helpdesk#9。下一步是 `spectra-discuss`，不要在 discuss 定案前寫 skill 或刪除類的子命令。

## 這個工具特有的

- **能不能重建逐項判定。** 候選清單只決定「要量哪裡」，不決定「可以刪」。每一項都要說明刪了會失去什麼。
- **雲端同步資料夾（Dropbox、OneDrive、Google Drive、iCloud 雲碟）不屬於可重建。** 本機刪除會同步刪掉雲端；能做的只有改成僅線上，且要先問。
- **可釋放量估不出時照實寫「無法估計」。** APFS clone 與本機快照讓「刪了能拿回多少」常常無法事前得知；清前清後各量一次 `df`。
- **列程序時不印完整指令列**：有些程式把憑證放在參數裡。
- 個人紀錄放 `~/.config/mac-disk-space/`，`.gitignore` 已擋相關檔名。
