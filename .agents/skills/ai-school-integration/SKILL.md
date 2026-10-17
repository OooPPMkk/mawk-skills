---
name: ai-school-integration
description: '推进 ai-school（中国高科 AI 教育产品平台）真实后端对接的批次工作：载入计划与历史上下文 → 后端源码级对账 → 列决策点待用户拍板 → 先更新文档再实施 → 四件套自审 → 真机验收并给点击流程 → 收尾回写与开新会话交接。坚持独立设计：bt 分支前端实现与原型只作参考（重点理解其设计思路与实现方式），再结合本仓现状与规范改进，交付附参考对照表。USE FOR: 推进 Bxx 批次、继续上个会话的对接、后端 bt/1.0.x 新增功能是否同步完、新会话接续对接任务、更新 ai-school-integration-plan / history、登记 harness v3 issue / replies、给本批改动的验收点击流程、核对本批是否独立设计（有没有照搬参考）。DO NOT USE FOR: 与后端对接无关的纯界面设计打磨、web-baseline 基线改动、后端仓代码修改、harness 仓 issues / replies 以外的文档。'
argument-hint: '推进 B37 / 继续上个会话的对接 / 后端 1.0.2 都同步完了吗'
---

# ai-school 后端对接批次推进

把「载入上下文 → 后端源码对账 → 拍板 → 文档先行 → 实施 → 自审 → 真机验收 → 回写收尾」这套固定节奏固化下来，不再依赖口头重复约定。

## 适用边界

- 用于：ai-school 仓与真实后端（`aiuniv-cloud-*` 五服务 + 工程化仓）对接的批次推进、文档维护、后端差异核对。
- 不用于：纯界面设计判断（界面设计走 oil-ui 技能）、web-baseline 基线模板改动、后端仓任何写入、harness 仓 issues / replies 之外的文档改动。

## 状态源（先认清哪份文件是权威）

**单一来源原则**：同一件事只在一处描述——**流程与规范**的权威源是本技能（配合 `ai-school/doc/backend-reference.md`），**状态与决策**的权威源是 plan / history，**缺陷与需求**的权威源是 harness v3。互相只写指针、不复述；发现两处说法不一致时以权威源为准，并删掉另一处的复述。

| 文档 | 权威范围 | 每批是否改 |
| --- | --- | --- |
| `ai-school/doc/ai-school-integration-plan.md` | 状态与计划：§1 当前状态 / §2 批次范围与口径 / §4 授权四态 / §6 台账（§3 / §5 是指针） | 改 |
| `ai-school/doc/ai-school-integration-history.md` | 决策与明细：§1 批次明细 / §2 `Dn`（**新增决策也记这里**） | 改 |
| `后端联调文档/ai-school-integration-issues-v3.md` | 缺陷与登记需求（**新问题只记这里**，v1 / v2 已冻结） | 需要后端动作时改 |
| `后端联调文档/ai-school-integration-replies-v3.md` | 后端答复 | 只读，出现后同读 |
| **本技能**（含 `references/`） | 流程与规范：推进步骤 / 自审 / 验收 / 参考使用原则 / 后端仓边界；文档写法、对账清单、独立设计、验收口径 | 流程变化时改 |
| `ai-school/doc/backend-reference.md` | 后端可读范围、对账顺序、版本同步与分支派生 | 口径变化时改 |
| `ai-school/AGENTS.md`、`doc/business-domain/README.md`、`doc/project-structure.md` | 代码规范红线、领域规则、页面入口 | 只读 |

路径推导：工作区根 `后端联调文档` 即工程化仓 `aiuniv-cloud-harness-engineering/docs/frontend`；其父目录是工程化仓，同级 `aiuniv-cloud-{core,ai,edu,workspace,billing,pay}` 是各服务仓（本机 `D:\10.project\back-end\`，公司机 `D:\06.M\02.Code\backend\`，家用机 `D:\06.source\MProject\back-end\`）。文档写法与收口口径见 [doc-conventions.md](./references/doc-conventions.md)。

## 流程

### 1. 载入上下文

读这几处即可，不要泛读全仓：

1. `plan.md` §1 当前状态、§2 批次计划、§6 台账（§3 / §5 是指针，不必读）；
2. `history.md` 中与本批相关的 `Bxx` 小节与 `Dn` 决策（引用到哪个 `Dn` 就读哪个）；
3. `issues-v3.md`（答复出现后同读 `replies-v3.md`）；
4. 本批涉及的 `src/service/*.service.ts` 与 `src/types/`。

从 §2 的首个「待开始」批次继续；批次的「范围 / 口径 / 依赖」以 §2 文字为准。

### 2. 后端源码级对账

**任何契约判断都要落到源码证据，不允许只凭 OpenAPI、api-guide 或印象下结论。** 清单、仓库职责、分支口径与报告格式见 [backend-recon.md](./references/backend-recon.md)。

要点：先跑 [backend-sync.ps1](./scripts/backend-sync.ps1)（`git fetch --prune` + 把六个服务仓主工作树检出到最新 `1.0.x`，dirty 的仓跳过）——**1.0.1 已冻结，新契约进 1.0.2**；需要与旧版本对照、或要看 `bt/*`（只读参考，不合并不搬运）时再用 `git worktree` 派生（约定路径见 `ai-school/doc/backend-reference.md`）；对照 Controller / DTO / 枚举 / 错误码 / SQL 迁移；能上 dev 实测的补实测。

**契约只从后端 Java 源码 / SQL / dev 实测取；`bt/*` 里的前端实现只用来理解设计思路与联调口径，读法见 [independent-design.md](./references/independent-design.md)（取思路，不取命名 / 组件结构 / 样式值 / 文案这些写法）。**

产出必须是**「差异 → 影响面 → 建议批次划分」**，而不是只处理眼前这一批——用户明确要求先想清楚后续几批再动手。

### 2.5 定独立性基线（本批参考过 `bt/*` 或原型时）

写实施计划前先声明：本批**只从参考取哪些意图**（如「参考确认了筛选项要随已选条件收敛」），以及本仓要按什么规范实现。这一步的作用是先把边界划出来，避免实施过程中被参考的写法带偏。

### 3. 列决策点，等拍板

把需要用户决策的事项写成**编号清单**（用户习惯逐条回「1. … 2. …」）。未拍板前不进实施；已在 §2 / `Dn` 里有明确口径的不要重复问。

### 4. 文档先行

先在 plan §2 写清批次范围与口径、在 history 追加 `Dn` 决策；需要后端动作的在 issues-v3 登记。口径以 §2 / `Dn` 为唯一来源，实施时按它执行。

### 5. 实施（独立设计，不照搬参考）

后端在 `bt/*` 上的前端改动为的是联调接口，不以前端规范与 UI 质量为目标，**命名 / 组件拆分 / 状态管理 / 样式数值 / 文案措辞 / 工程结构都不具备参考价值**。完整口径、禁止信号与自问清单见 [independent-design.md](./references/independent-design.md)。

- **顺序：先理解参考，再结合本仓改进。** 先读 `bt/*` 前端实现与原型，看懂它的设计思路、字段消费方式与边界处理（取「思路」不取「写法」），再结合本仓现状与 `AGENTS.md` 规范重写；契约仍以后端 Java 源码 / SQL / dev 实测为准，参考是实现、不是契约。
- 命名、组件拆分、状态管理、样式与文案一律按本仓 `AGENTS.md` 与既有同类页面决定；样式值只来自 Ant Token / `--palette-*` / `rem` 规范，不取参考里的色值与间距。
- 冲突处理顺序：**本仓 `AGENTS.md` 规范 > 需求与原型的设计目标 > 后端 `bt/*` 实现**；出现冲突先说明问题与替代方案，经确认再实施。
- 原型只提供功能目标与信息项，视觉细节与编造内容不照做，不合理处先优化再与用户讨论。
- 共享层（`components/`、`composables/`、`utils/`、`service/protocol/`、`types/`、`layout/`、`styles/`）先提到 web-baseline 再同步；业务组件（如对话面板相关）不强行回提。
- 页面级改动先看**同页已有区块的信息覆盖与分工**，再决定组件复用与展示开关，不要只从组件角度做决定。

### 6. 自审（四件套 + 规范核对）

**规范与最佳实践核对（2026-10-11 起）**：开发与自审须主动对照行业规范与官方最佳实践（Vue 3 / Ant Design Vue / TypeScript / 平台接口惯例）；发现冲突先说明问题与替代方案、经确认后再实施。

```
npx prettier --check <改动文件>
npm run type:check
npm run lint:check
npm run stylelint:check
```

运行方式与降级路径见 [acceptance.md](./references/acceptance.md)；也可直接跑 [check.ps1](./scripts/check.ps1)。

### 7. 真机验收

本地 dev server + 真实 dev 环境（`https://dev-api-gaoke.hobo.top`）实测，测试身份 chenqi（默认）。浏览器与探针口径见 [acceptance.md](./references/acceptance.md)。

### 8. 交付产物（每批都主动给，不等用户索要）

1. **验收点击流程**：用户每批都会问「告诉我大概的点击顺序」。给：从哪个菜单进入、点哪里、看到什么算通过、边界项在哪验证。不用太细，覆盖本批改动点即可。页面入口见 `ai-school/doc/project-structure.md`，验证方法与刷新鲜口径见 [acceptance.md](./references/acceptance.md)。
2. **独立性自查结论**（每批）：按 [independent-design.md](./references/independent-design.md) 的禁止信号过一遍，命中项先自行修正再交付；并在汇报里明确说「本批无照搬信号」或列出处理了什么。
3. **参考对照表**（本批参考过 `bt/*` 前端实现或原型时必给）：逐项列「参考做法 / 本仓实现 / 差异与理由」，模板见 [reference-matrix.md](./assets/reference-matrix.md)——这是用户核对有没有照搬的唯一抓手，缺了视为交付不完整。

### 9. 收尾回写与交接

- plan §1 更新当前状态（提交 SHA 填在用户提交后）、§2 把批次移入「已完成」、§6 台账删掉已闭环项；
- history §1 追加批次明细（范围 / 口径 / 实现 / 验收 / 验证边界 / 依赖），新增 `Dn`；
- issues-v3 中已闭环项**移除**（首版收口口径），同步 frontmatter 的 `open_issue_count` / 缺陷集列表；
- **不代为 `git add` / `commit` / `push`**：改动留在工作区，提示用户自行提交；用户提交后按需要补 SHA。
- 会话过长时主动给「新会话接续稿」，模板见 [handoff.md](./assets/handoff.md)。

## 红线清单（每步自查）

- 后端仓只读：不改代码、不提交、不建分支；每次对账先跑 `scripts/backend-sync.ps1` 把主工作树升到最新 `1.0.x`（dirty 的仓跳过并报告），对照旧版本才用 `git worktree` 派生；harness 仓不做任何检出 / 派生。
- harness 仓只有 `issues` / `replies` 可改（前端 owner），其余文档要动先问。
- 不代 `git add` / `commit` / `push`，不建分支，不动用户正在编辑的文件。
- 文档只记**高价值信息**：范围、口径、验收结论、依赖、验证边界；不入 diff 级实现细节（实现要看直接读源码）。
- 已闭环项从 issues-v3 移除，编号跳号属正常；v3 按**首版**对待，不留迭代痕迹（尚未被后端读取时）。
- 契约判断必须有源码证据（分支 + 文件 + 端点 / 字段），不凭文档或印象。
- **独立设计**：参考只用来理解契约与产品目标，不照搬命名 / 组件结构 / 状态管理 / 样式值 / 文案；先自研后对照；参考与本仓规范冲突时以本仓规范为准。
- 参考里的 mock、调试开关、临时兜底不带进本仓代码。
- UI 文案不用「·」拼接并列信息：短注用逗号、限定语用括号、身份状态用 `a-tag`、多指标用间距与主次色分层。
- markdown 表格单元格内不出现裸 `|`（含行内代码内），用 `/` 或转义，否则 GFM 会拆列、Prettier 会顺着错法重排。
- 写后端对接相关代码时优先看 `doc/business-domain/README.md`（点数 / 课时 / 订单 / 账单 / 权益 / 钱包 / 角色红线）。

## 请求路由

| 用户说 | 做什么 |
| --- | --- |
| 「推进 Bxx」 | 走流程 1 → 9 |
| 「还有可以做的任务吗 / 都同步完了吗」 | 读 plan §2 待开始 + 挂起 + §6 台账，再对后端各 `origin/1.0.x` 做一次差异扫描，给候选清单（按可推进度排序），不要擅自开工 |
| 「后端在 bt/1.0.1、1.0.2 新增的功能同步完了吗」 | 按 backend-recon 做全量对账，逐条给「已同步 / 待同步 / 不吸收」结论与证据 |
| 「这批是不是独立设计的 / 有没有照搬参考」 | 出参考对照表 + 禁止信号自查结论（逐条对，不要只说「没有照搬」） |
| 「给我验收点击流程」 | 按本批改动给点击路径（含边界项），入口参考 `ai-school/doc/project-structure.md`、方法参考 acceptance.md |
| 「把这个写进文档」 | 按 doc-conventions 落到 plan §2 / history `Dn` / issues-v3 对应位置 |
| 「开个新会话继续」 | 用 handoff.md 模板产出接续稿 |
| 「文档太啰嗦了 / 精简一下」 | 按 doc-conventions 的「精简口径」收口，删重复与过程性描述，保留口径与编号 |
