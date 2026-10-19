---
name: windows-toolchain-pitfalls
description: Windows + PowerShell 5.1 + Git + VS Code 编辑工具链的高频坑与修法：中文编码、命令规范化改写、进程清理、盘符大小写假成功、多块编辑冲突规则、git 伪修改与重定向编码、Prettier range 格式化 bug。USE FOR: 终端命令输出错乱或中文变问号、文件创建或编辑报成功但没落盘、git status 显示异常、保存后代码多出字符或断语法、批量清理进程失败、跨盘符路径操作报文件不存在。DO NOT USE FOR: 项目特有的构建与脚本问题（看各仓 AGENTS.md 与 package.json）、Node / nvm 环境安装（属各机 Copilot 记忆）。
---

# Windows 工具链坑（PowerShell 5.1 / 编辑工具 / Git / VS Code）

沉淀自 Windows 双机（家用 / 公司）的日常开发实践。本技能只收**通用坑**；本机特有的环境事实（已装版本、凭据、路径）记各自机器的 Copilot 记忆，不进本文件。

> 措辞约定（2026-10-19 校准）：「观察到 / 实测」= 真实发生过；「怀疑 / 候选」= 未定位的推断。三个环境前提家用机已验证、**公司机首次使用前核对**：默认 shell 是否 PowerShell 5.1、`core.autocrlf` 是否 `true`、`chrome.exe` 是否在 PATH。

## PowerShell 5.1

- **here-string 管道传 `node` 时中文变 `?`**（正则可能报语法错）：脚本尽量纯 ASCII；确需中文先设 UTF-8 的 `$OutputEncoding`。
- **命令规范化会把内嵌 JS 的 `&&` 改成 `;`**（run_in_terminal 工具实现行为，升级可能变化）：一次性检查脚本用分层 if / break 结构。
- **变量名大小写不敏感**：常量会被循环变量静默覆盖（`$REL` vs `foreach ($rel ...)` → `GetAttribute` 返空串）——两者用完全不同的词。
- **`Get-CimInstance … | Stop-Process -Force` 管道绑定会整批失败**（报「找不到名为 xxx 的进程」，实际进程存在且端口还活着）→ 改 `| ForEach-Object { Stop-Process -Id $_.ProcessId -Force }` 一次成功。
- 多语句 / 带循环的命令输出易错乱或丢失（含中文更明显）：复杂命令写 `.ps1` 文件再执行；切换目录用 `npm --prefix <dir> run <script>` 代替 Set-Location。

## 文件与编辑工具（VS Code agent 侧）

> 本节是 agent 编辑工具实现行为的观察（2026-10 工具集）：公开文档不覆盖这些行为，但工具随 VS Code Copilot 升级可能变化——失效时按症状重新观察，别按条目硬套。`multi_replace` 系列仅当工具集中存在该工具时适用。

- **盘符大小写敏感（工具侧，观察到一例）**：小写 `d:\...` 调 create_file 报成功但无文件、replace 报 `File does not exist`，read_file 同路径却正常 → 统一写大写 `D:\...`，改完 `Test-Path` 核对（此核对习惯即使 bug 被修复也无害）。
- **工作区外文件（`%TEMP%`）read_file 可能返陈旧缓存**：先 `Copy-Item` 换名再读，或 `Select-String` / `(Get-Item).Length` 核盘。
- **multi_replace 相邻块不能共享边界行**（前块末行 = 后块首行 → conflict）：删连续区块 = 「内容 + 尾随空行」→ 空串，逐块独立不重叠。
- **一轮放「同位置 / 互为前缀 / 完全相同」的多块 → 只执行第 1 块**，其余报 conflict（多刀必须分轮）；not found 才是真空不匹配。≥20 连续空格的 oldString 复刻不可靠，`\n` + ≤14 空格较准。
- **并发编辑期编辑回执不可信**（报成功但未落盘；read_file 可能返「另一种中间态」，连语法错误都是幻影）→ 改完 `Select-String` 按行复核磁盘。

## Git（Windows + core.autocrlf=true）

- `git mv` 目录被句柄占用会卡住（交互问 y/n，级联脚本连环挂）→ 用 `Move-Item` 搬 + `git add -A <范围>` 让 git 认 rename；批量移动收尾别用 `Remove-Item -Recurse -Force`（会误删未搬走的目录），用不带 `-Recurse` 的版本兜底。
- **PS 管道读 git 输出乱码**（按 GBK 解 UTF-8）→ `git log ... --output=<文件>` / `git diff --output=<文件>` 直写 UTF-8。
- **伪修改（CRLF/LF）**：`status` 报 M 但 `diff` 为空 ⇒ `git hash-object <file>` 等于 `git rev-parse HEAD:<path>` 即内容一致，`git add -- <file>` 刷索引消除（前提 `core.autocrlf=true`；`false` / `input` 时不会出现此类伪修改）。
- **PS 重定向 `git show ref:path > file` 写出 UTF-16** → `cmd /c "git show ref:path > file"` 或 `git diff --output=<文件>`。
- **分支差集别只看 diff 文本**（± 行极易读反）→ `git show A:path` / `git show B:path` 落盘对照后再解读。

## VS Code：保存多出裸分号（Prettier range 格式化 bug）

- 症状：保存后在「braced arrow 参数」的 `(` 后多出一个裸 `;`（如 `defineConfig(;({ mode }) => {`），断语法；该行本身并未被修改。
- 触发：全局 `editor.formatOnSaveMode: "modifications"`（保存只格式化与 git 的差异片段）+ 仓库 `.prettierrc` `semi: false`；当修改片段位于箭头函数体内（尤其与注释行相邻）时，Prettier 的 range 格式化会在箭头函数前插入裸分号（upstream：prettier/prettier#12964 家族；2.8 修了原 repro，3.9.6 仍能复现变体）。
- 修复：仓库 `.vscode/settings.json` 固定 `"editor.formatOnSaveMode": "file"`（工作区级覆盖用户设置，仅对该仓库生效）。
- 复发排查：再遇「保存即多字符 / 断语法」，先查是否命中 range-bug 条件；VS Code 输出面板 Prettier 日志可见 rangeStart / rangeEnd（modifications 模式）。

## 维护约定

- 新坑先落本技能（git 提交后双机即时生效）；只有某台机器特有的现象才记该机的 Copilot 记忆，并在记忆里注明机型差异。
- 收录标准：实测**发生过**且**修法验证过**（不要求二次复现，但「发生过一次」≠ 定律，单例要标注「一例」）；推断的成因必须标「怀疑 / 候选」，与事实分开写。
- 条目三要素：日期、频次（几次）、适用前提（PS 5.1 / autocrlf / 工具版本）；时效分三级——原理级（长期有效）/ 版本级（绑定软件版本，标注版本号）/ 工具实现级（绑定 agent 工具行为，升级后需复核）。
- 回看机制：技能启用满一个月（2026-11-19）后用 chronicle 查会话历史，统计实际触发与命中情况，据此裁剪或修订条目。
