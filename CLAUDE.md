<!-- SPECTRA:START v1.3.0 -->

# Spectra Instructions

This project uses Spectra for Spec-Driven Development(SDD). Specs live in `docs/spectra/specs/`, change proposals in `docs/spectra/changes/`.

## Skills

Each `/spectra-*` skill carries its own trigger description; these are the groups:

- Shape and plan → `/spectra-discuss`, `/spectra-propose`
- Continue tasks for an identified change → `/spectra-apply`
- Update requirements or plans for an identified change → `/spectra-ingest`
- Quality gate → `/spectra-verify`, `/spectra-review`, `/spectra-analyze`, `/spectra-audit`, `/spectra-drift`, `/spectra-debug`
- Finish → `/spectra-archive`, `/spectra-commit`

Explicit skill invocation takes precedence. Apply existing authorization within its unchanged scope.

## Workflow

discuss? → propose → apply ⇄ ingest → verify / review → archive

- `discuss` is optional — skip if requirements are clear
- Requirements change mid-work? Plan mode → `ingest` → resume `apply`

## Parked Changes

Changes can be parked（暫存）— temporarily moved out of `docs/spectra/changes/`. Parked changes won't appear in `spectra list` but can be found with `spectra list --parked`. To restore: `spectra unpark <name>`. The `/spectra-apply` and `/spectra-ingest` skills disclose parking and restore when the named operation is already explicitly requested; respect a known refusal, otherwise ask for missing authorization.

<!-- SPECTRA:END -->

# CLAUDE.md

MacHelpdesk 系列的磁碟空間工具。整個系列共用的規則（公開 repo 不寫任何人的環境、只寫實測過的行為、會改設定的動作寫明界線、`/bin/bash` 3.2 相容、Git 流程）在 umbrella repo `MacHelpdesk/mac-helpdesk` 的 CLAUDE.md，這裡不重抄。

## 狀態

0.2.1。需求與決定在 MacHelpdesk/mac-helpdesk#9 與 MacHelpdesk/mac-disk-space#3，主規格在 `docs/spectra/specs/`。每週背景量測與通知（#9 的決定 6–8）是之後另一個 change，會重用 `disk-space.sh probe`。

## 這個工具特有的

- **能不能重建逐項判定。** 候選清單只決定「要量哪裡」，不決定「可以刪」。每一項都要說明刪了會失去什麼。
- **雲端同步資料夾（Dropbox、OneDrive、Google Drive、iCloud 雲碟）不屬於可重建。** 本機刪除會同步刪掉雲端；能做的只有改成僅線上，且要先問。
- **可釋放量估不出時照實寫「無法估計」。** APFS clone 與本機快照讓「刪了能拿回多少」常常無法事前得知；清前清後各量一次 `df`。
- **列程序時不印完整指令列**：有些程式把憑證放在參數裡。
- **量測由 `disk-space-measure` agent 做，清理留在主對話。** agent 的指令清單（`plugin/agents/disk-space-measure.md`）與 skill 退路列的子命令必須相同，`tests/test_agent.sh` 會比對；改一邊就要改另一邊。agent 的工具只有 Bash 與 Read，不要加會寫檔的工具。
- **`online-only` 是唯一會改動東西的子命令**，只接受 iCloud 雲碟與 Dropbox（spike 1.2 驗證過的兩個）。要加別的服務，先在實機驗證並記錄，再擴充 `online_only_roots`。
- 系統輸入都有 `DISK_SPACE_*` 覆寫，測試用 `tests/fixtures/` 與 `tests/stubs/`，不碰真的磁碟、快照與雲端。
- macOS 沒有 `timeout`，時間上限用 `run_limited` 輪詢；背景工作被結束時 bash 會印提示，只在那兩個呼叫上擋 stderr，不要整段擋（會吞掉候選清單的錯誤回報）。
- 個人紀錄放 `~/.config/mac-disk-space/`，`.gitignore` 已擋相關檔名。
- **Spectra 會把 git 的信箱寫進 `.openspec.yaml`**（`created_by`、`archived_by` 寫成「名字 <信箱>」），而且沒有設定可以關掉。每次 `spectra new change` 或 `spectra archive` 之後，把信箱拿掉、只留名字；`scripts/check-privacy.sh` 會擋下忘了拿掉的（MacHelpdesk/mac-disk-space#9）。封存的檔案在 `archive/` 底下，先跑 `/archive-first:archived-unlock`，改完重新上鎖。
