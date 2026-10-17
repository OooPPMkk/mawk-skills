---
name: memory-sync
description: "导入、导出与合并 GitHub Copilot 记忆（用户记忆 + 当前工作区仓库记忆），用于家用机 / 公司机之间的记忆迁移与同步。USE FOR: 导出记忆、导入记忆、同步记忆、迁移 Copilot 记忆、备份记忆文件、合并记忆、memory export/import/sync。DO NOT USE FOR: 代码与文档同步（用 git）、聊天记录迁移（不支持）。"
---

# Copilot 记忆导入 / 导出（memory-sync）

把本机 Copilot 记忆导出为可迁移目录包，或在目标机导入导出包并按「评估 → 确认 → 备份 → 合并」流程恢复。本技能目录 = 本文件所在目录（下称 `<技能目录>`），脚本在其 `scripts/` 下。

## 记忆在哪（两处）

| 作用域 | 路径 | 说明 |
| --- | --- | --- |
| 用户记忆 | `%APPDATA%\Code\User\globalStorage\github.copilot-chat\memory-tool\memories\*.md` | 跨工作区，所有新会话自动加载 |
| 仓库记忆 | `%APPDATA%\Code\User\workspaceStorage\<工作区哈希>\GitHub.copilot-chat\memory-tool\memories\repo\*.md` | 按工作区隔离 |

- 工作区哈希由工作区路径决定，两台机器不一定相同；用 `<哈希目录>\workspace.json` 反查（内容为 `file:///...` + URL 编码，中文工作区名解码后为中文）。
- 记忆工具视图 `/memories/`、`/memories/repo/` 与磁盘一一对应：盘上复制 / 删除文件立即可见，`view` 可验证。
- **会话记忆**（`memories/<会话ID>/` 子目录）与聊天记录不在迁移范围。

## 导出流程

1. 与用户确认导出目录（建议 `<中转位置>\copilot-memory-export-<YYYYMMDD>`）。
2. 运行脚本（`<技能目录>` 替换为本文件所在目录的绝对路径）：
   ```powershell
   powershell -ExecutionPolicy Bypass -File "<技能目录>\scripts\export-memory.ps1" -OutDir "<导出目录>" -WorkspaceFile "<当前工作区文件名>"
   ```
   - `-WorkspaceFile` 可省略：仅一个工作区有仓库记忆时自动选用，多个时脚本报错并列出候选。
   - 中文工作区名照常传（如 `基线项目.code-workspace`）。
3. 核对产物：
   ```
   <导出目录>/
   ├── README.md                    # 来源机、时间、文件清单、恢复说明（脚本生成）
   ├── user-memory/*.md
   └── repo-memory/<工作区名>/*.md
   ```
4. 提醒用户把整个目录经中转（本地复制 / U 盘 / 网盘）带到目标机。

## 导入流程

1. 读导出包的 `README.md` 与**全部**记忆文件（这是评估输入）。
2. 与目标机现有记忆逐文件对比，分四类：
   - **A 直搬**：目标机无同名文件；
   - **B 合并**：同名且两边各有独有内容 → 合并版＝两边条目全保留、去重；
   - **C 机器特定**：内容含源机的路径 / 用户目录 / 环境事实 → 补目标机事实并标注归属（如「家机 / 公司机」两段）；
   - **D 跳过**：已被其它记忆覆盖、或明确作废的旧快照 → 列出理由。
3. **先与用户确认分类结果与合并方案，确认后才动盘**（硬性要求）。
4. 运行脚本搬 A 类与 C 类；B 类文件用 `-Skip` 排除，留给第 5 步手工合并：
   ```powershell
   powershell -ExecutionPolicy Bypass -File "<技能目录>\scripts\import-memory.ps1" -Source "<导出目录>" -WorkspaceFile "<当前工作区名>" -Skip user:a.md,repo:b.md
   ```
   - 脚本自动把目标机现有记忆备份到 `<导出目录>\pre-import-backup[-时间戳]\`；
   - 目标机还没有该工作区存储时脚本会提示（先打开一次该工作区再重试）。
5. 手工处理 B / C 类：用记忆工具写 `/memories/...`、`/memories/repo/...`（`create` 不能覆盖已存在文件 → 先 `delete` 再 `create`；小改用 `str_replace`）。
6. 清理与验证：
   - 旧文件被完整取代时先并入残留再删（列出删除清单让用户确认）；
   - `view /memories/` 与 `view /memories/repo/` 核对，必要时盘上 `Get-ChildItem` 复核数量；
   - 向用户总结：导入 / 合并 / 跳过数量、备份位置。
7. 提醒：用户记忆的自动加载在**新会话**生效；如需反向同步（把合并版带回源机），回传合并后的文件即可。

## 口径与坑

- 若包里带 `restore.ps1` 之类全量覆盖脚本，**不要直接跑**——会覆盖目标机独有内容，一律走上面的评估合并流程。
- 中文工作区名 / URL 编码：脚本已处理；手工查找时用 `[IO.File]::ReadAllText`（默认 UTF-8）+ `[uri]::UnescapeDataString`，不要用默认编码的 `Get-Content` 直接匹配中文。
- 脚本控制台输出为英文（避 PowerShell 5.1 中文编码问题），生成的 README 为中文；脚本源码保持 UTF-8 with BOM，改动后不要存成无 BOM。
- 记忆文件不受 git 管理，删改前必须有备份（导出包本体 + `pre-import-backup` 即两份）。
- 机器环境差异（nvm / Python / 路径）写记忆时标注归属，不要让两机事实互相覆盖。
- 一切批量复制都在用户确认之后执行。
