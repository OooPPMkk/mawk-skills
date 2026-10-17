# ytyang-skills

个人技能知识库。沉淀日常工作中积累与自建的 SKILL，持续蒸馏、持续迭代。

## 仓库结构

```
.agents/skills/<技能名>/
├── SKILL.md          # 技能说明（VS Code Copilot 按需加载）
└── scripts/          # 技能捆绑的脚本与资源（可选）

skills-lock.json      # 记录第三方技能的安装来源与内容哈希
```

## 技能清单

| 技能 | 用途 |
| --- | --- |
| memory-sync | 导入、导出、合并 GitHub Copilot 记忆（家用机 ⇄ 公司机迁移与同步） |
| ai-school-integration | ai-school 后端对接批次推进：载入计划与历史 → 后端源码级对账 → 拍板 → 文档先行 → 实施 → 四件套自审 → 真机验收 → 收尾回写与交接 |
| impeccable | 界面设计与精修（第三方，源自 pbakaus/impeccable）：方向塑造、UX 评审、层级 / 排版 / 色彩 / 动效打磨、无障碍与响应式加固、DESIGN.md 设计系统沉淀 |
| frontend-design | 有辨识度的视觉设计（第三方，源自 anthropics/skills）：新界面或改版时的美学方向、排版与去模板化决策 |

## 使用流程

### 一、在各工作区加载本仓库（一次性）

1. 打开要使用技能的 `.code-workspace` 文件，在 `folders` 里加入本仓库（每台机器按本机实际路径填写，原有各根保持不变）：

```jsonc
{
  "folders": [
    { "path": "D:\\06.source\\MProject\\front-end\\ai-school", "name": "ai-school" },
    { "path": "D:\\06.source\\MProject\\front-end\\ytyang-skills", "name": "ytyang-skills" }
  ]
}
```

2. 重载窗口（Reload Window）后生效。
3. 验证：在 Copilot Chat 输入 `/`，技能列表中应出现 `memory-sync`。
4. 说明：VS Code 的用户级目录不支持技能（用户级只有提示、指令、智能体三类），所以技能跟随本仓库、由各工作区加载；本仓库没有 AGENTS.md，作为根只贡献技能清单，token 负担很小。

### 二、导出记忆（源机）

1. 在 Copilot Chat 里说「导出记忆」（或 `/memory-sync`），按技能指引确认导出目录。
2. 也可以直接运行脚本：

```powershell
powershell -ExecutionPolicy Bypass -File "D:\06.source\MProject\front-end\ytyang-skills\.agents\skills\memory-sync\scripts\export-memory.ps1" -OutDir "E:\00.work\copilot-memory-export-20261017" -WorkspaceFile "基线项目.code-workspace"
```

参数说明：

- `-OutDir`：导出目录，不存在会自动创建；
- `-WorkspaceFile`：要导出哪个工作区的仓库记忆；同一时刻只有一个工作区有仓库记忆时可省略（含中文的工作区文件名照常传）。

3. 产物结构与恢复说明由脚本写入导出包的 `README.md`：

```
<导出目录>/
├── README.md                 # 来源机、时间、文件清单、恢复说明
├── user-memory/              # 用户记忆（全局，跨工作区）
└── repo-memory/<工作区名>/    # 仓库记忆（按工作区隔离）
```

4. 把整个导出目录经中转（本地复制 / U 盘 / 网盘）带到目标机。

### 三、导入记忆（目标机）

1. 在 Copilot Chat 里说「从 <目录> 导入记忆」（或 `/memory-sync`）。
2. 技能流程：读包 → 评估分类（直搬 / 合并 / 机器特定改写 / 过时跳过）→ **与你确认** → 备份 → 导入 → 验证。
3. 也可以直接运行脚本（`-Skip` 列出留给人工合并的文件，格式 `user:<文件名>` / `repo:<文件名>`）：

```powershell
powershell -ExecutionPolicy Bypass -File "<本仓库路径>\.agents\skills\memory-sync\scripts\import-memory.ps1" -Source "<导出目录>" -WorkspaceFile "<当前工作区名>" -Skip user:preferences.md
```

4. 脚本会把目标机现有记忆备份到 `<导出目录>\pre-import-backup\`；删改任何记忆文件前先确认备份在。

### 四、维护技能

- 迭代：直接改 `.agents/skills/memory-sync/` 下的文件，git 提交后所有加载了本仓库的工作区立即生效（无需重装）。
- 双机同步：本仓库走 git，两台机器分别 pull / push。
- 新增技能：在 `.agents/skills/` 下新建 `<技能名>/SKILL.md`（frontmatter 需 `name` 与 `description`，触发词写进描述），提交推送即可。
- 第三方技能（当前为 `impeccable`、`frontend-design`）：整目录入库、不手改内部文件，来源与内容哈希由 `skills-lock.json` 记录。用 `npx skills add <owner/repo> --skill <技能名>` 安装、`npx skills list` 查看、`npx skills update` 升级、`npx skills remove <技能名>` 卸载；装完把 `README.md` 的技能清单补上，并提交推送。
- 约定：`.ps1` 脚本保存为 UTF-8 with BOM（PowerShell 5.1 读中文源码的要求）；脚本的执行提示用英文、生成物（导出包 README）用中文。
