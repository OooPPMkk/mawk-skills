# 后端源码级对账

> 「综合考虑后端源码」是这套流程的第一原则：契约的权威源是后端**源码**，不是 OpenAPI、api-guide 或历史印象。

## 仓库与职责

| 仓库 | 职责 |
| --- | --- |
| `aiuniv-cloud-harness-engineering` | 工程化仓（对接文档、SQL、脚本、原型、playwright 用例） |
| `aiuniv-cloud-core` | 基础服务（认证 / 用户 / 字典 / 租户） |
| `aiuniv-cloud-ai` | 智能服务（对话 / 工具 / 生成） |
| `aiuniv-cloud-edu` | 课程服务 |
| `aiuniv-cloud-workspace` | 工作台服务（画布 / 导师 / 工具目录） |
| `aiuniv-cloud-billing` | 计费服务（点数 / 套餐 / 合同 / 流水） |
| `aiuniv-cloud-pay` | 支付服务 |
| `ai-school-go-backend` | **已废弃**，看到直接跳过，不拉取不作参考 |
| `zhihui-cloud-parent` | 私有仓，当前账号无权限，需要其内容先问用户 |

位置：工作区根 `后端联调文档` 的父目录是工程化仓，同级目录是其余服务仓（本机 `D:\10.project\back-end\`，公司机 `D:\06.M\02.Code\backend\`，家用机 `D:\06.source\MProject\back-end\`）。harness 仓内若已有同名子工程目录，以子目录为准。

## 分支口径

- **1.0.1 已冻结，新契约一律进 `origin/1.0.2`**（`origin/master` 也可能带新端点，两边都看）。
- **每次对账先跑 [backend-sync.ps1](../scripts/backend-sync.ps1)**：`git fetch --prune` + 主工作树 `switch --detach` 到最新 `1.0.x`（dirty 则跳过该仓）；确认到手再下结论，不要拿旧版本实现说事。本机六个服务仓当前已在 `1.0.2`。
- 需要与旧版本对照（`1.0.1` ↔ `1.0.2`）时用 `git worktree` 派生旧分支（约定路径与清理见 `ai-school/doc/backend-reference.md`）。
- `bt/*` 分支是后端做的模拟对接提交，**只读参考**：理解契约与设计思路用，不合并、不搬运、不照抄其中的前端实现（读法与时机见 [independent-design.md](./independent-design.md)）。
- 对接接口基址 `https://dev-api-gaoke.hobo.top`，契约分段 `/admin-api/{service}/v3/api-docs`（system / edu / workspace / ai / billing / infra）。

## 对账顺序

1. 先看前端现状：`src/service/*.service.ts`（路径、入参、出参）与 `src/types/`（类型与领域语义），确认当前消费形态。
2. 再回后端源码：Controller（路径 / 参数 / 鉴权注解）→ DTO / VO（字段名与类型、可空性）→ 枚举与常量 → 错误码 → `resources/db` 下的 SQL 迁移（字段是否真在库里、是否曾改名）。
3. 两边不一致时**先与用户确认**，不要单方面按后端实现改前端。
4. 能上 dev 实测的补一条实测证据（真实账号 + 请求 / 响应片段），写进结论。

## 只看 diff 不够

- 后端一次提交常同时含「对 v2 / v3 台账的答复」「独立新功能」「本地联调用的环境配置」三类，**必须逐条归类**：答复类按台账闭环，新功能类评估是否吸收，环境配置类不吸收。
- 同样的提交在不同服务里含义不同（如 workspace 的 `productType` 与 billing 的商品类型），要落到各自的消费页面判断影响面，不要按提交名统一处理。
- 关注**共性破坏**：分页响应形状（`{list, total}`）、时间字段（epoch 毫秒 vs 字符串）、鉴权头（`tenant-id`）、游标语义（`beforeId`）这类改动会横跨多个链路，中标后要一次规划完整批次。

## bt/* 前端实现的读法

后端在那里的前端改动是为了联调接口，不以前端规范与 UI 质量为目标。

| | |
| --- | --- |
| **时机** | 对账阶段即可读，用于看懂设计思路与联调口径；读的是「思路」不是「写法」，落笔一律按本仓规范 |
| **读什么** | 接口调用时机与参数语义、字段消费顺序、边界与失败处理口径、页面要达成的交互意图 |
| **不读成依据** | 命名、组件拆分、状态管理方式、样式数值与配色、文案措辞、mock 与调试代码、注释 |

有分歧以本仓 `AGENTS.md` 规范为准；实现完成后产出参考对照表（[reference-matrix.md](../assets/reference-matrix.md)）。

## 产出格式（对用户汇报用）

```
## 对账结论（<日期>，<分支>）

### 归类
| 后端改动 | 分支/提交 | 归类 | 前端动作 |
| --- | --- | --- | --- |

### 证据
- <服务> <文件/类>：<实际契约>（必要时贴实测请求响应片段）

### 建议批次划分
- B<n> <批次名>：范围 / 依赖 / 风险
- 不吸收：<项> —— 理由

### 待拍板
1. <决策点>
2. <决策点>
```

结论必须能回答「**是不是都同步完了**」：逐条给「已同步 / 待同步（进哪个批次）/ 不吸收（理由）」，不留模糊项。

## 定位与读取的分工

后端仓在工作区之外，`grep_search` / `file_search` 不覆盖，所以对账要分两步：

1. **定位（主会话）**：主工作树已同步到最新版，`git -C <仓> grep -n <pattern>` 一次拿到命中文件与行号（输出很小，不会弄脏上下文）；对照旧版本时对派生树路径做同样的事。
2. **读取（subagent）**：按定位结果给的文件清单读绝对路径并归纳，**不要再自己逐层 `list_dir` 摸目录**（maven 多模块近 10 层，纯浪费）。

并发分片按「服务」切、**上限 3**，单服务批次用 1 个；每份报告必须带 `rev-parse --short HEAD` 的 SHA。

## 只读边界

- 后端仓不改代码、不提交、不建分支；允许 `git fetch` + 主工作树升到最新 `1.0.x`（脚本见上）+ `git worktree` 派生旧版本对照（约定路径 `\_recon\<仓名>@<分支>`，用完 `worktree remove`）。
- **harness 仓的 `docs/frontend` 就是本工作区的一个根**：不建 worktree、不切分支，按当前工作区读取。
- 后端仓在工作区之外：`read_file` / `list_dir` 可用（绝对路径），`grep_search` / `file_search` 不可用。
- harness 仓只有 `docs/frontend/ai-school-integration-issues-*.md` 与 `replies-*.md` 归前端 owner；`ai-school-api-guide.md`、`playwright-tests/**` 等默认不改，要动先问用户。
