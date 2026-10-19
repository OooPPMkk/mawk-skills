# 自审与真机验收

## 四件套（自审硬要求）

在 ai-school 仓目录执行（终端切换目录易被工具简化，统一用 `npm --prefix`）：

```
npx prettier --check <改动文件>
npm --prefix <ai-school 绝对路径> run type:check
npm --prefix <ai-school 绝对路径> run lint:check
npm --prefix <ai-school 绝对路径> run stylelint:check
```

- 也可直接跑 [check.ps1](../scripts/check.ps1)：`powershell -ExecutionPolicy Bypass -File "<技能目录>\scripts\check.ps1" -RepoDir "<ai-school>" -Files "<改动文件,逗号分隔>"`。
- `npm run check`（含全量 `format:check`）只在确认需要时用，全仓 prettier 检查容易被无关文件干扰。
- 自审不止于工具链：主动对照行业规范与官方最佳实践（Vue 3 / Ant Design Vue / TypeScript / 平台接口惯例），有冲突先说明问题与替代方案。
- pre-commit 钩子会强制 `type:check` 与 lint-staged，自审通过才交人工 review。

## dev 环境与测试身份

- 接口基址 `https://dev-api-gaoke.hobo.top`；本机 dev server 用工作区任务「启动 ai-school」或 `npm --prefix <ai-school> run dev`。
- 常用身份：`chenqi`（默认）、`linxia`、`zhounan`，密码 `Aiuniv2026`。
- Node 版本按仓内 `.nvmrc`（22.23.1）。

## 契约复验（后端答复的 rerun_criteria）

- 手法：写一个**一次性 node 脚本**（Node 自带 `fetch`）登录取 token 后逐批打端点断言，同时把完整结果写 JSON 文件再读文件核对（终端中文易乱码，JSON 更可靠）；脚本放系统临时目录（如 `%TEMP%`）、**不落仓**，需要留档时提示用户自行保存。
- 断言口径（实测踩坑）：平台把 Long 序列化成**字符串**（`total`、雪花 id、点数都是 `"3"` / `"7076"`）；断言与比较一律先 `Number()` / `BigInt()`，别写 `typeof total === 'number'`，否则整批假失败。
- 只读优先：会改数据的探针（讲次解锁消耗课时券、改密撤销令牌、创建订购单）**先跳过并写进验证边界**，需要跑先问用户。
- 更能说明问题的判据：能拿全量基线就对比全量（如游标翻页结果与 `pageNo` 升序全量遍历逐条一致），比只看单页形状有力。
- 落点：复验结论写 history `Dn`（日期 + 身份 + 端点 + 关键实测值 + 验证边界）与 plan §1 一行；**不写进 v3**。有产品影响的差异才过「缺陷登记闸门」→ **先与用户确认**，同意后才登记缺陷或写入 v3 `NOT_REPORTED_ON_PURPOSE` 留档。

## 浏览器验证

- 优先用 Chrome DevTools MCP / 隔离 Chrome（`--remote-debugging-port=9222` + 独立 `--user-data-dir`）；VS Code 内置预览页的尺寸与截图不可信（viewport 被宿主改回、截图是旧合成帧），布局判定一律用 `evaluate` 读几何。
- 启动 Chrome 时加 `--disable-backgrounding-occluded-windows --disable-renderer-backgrounding --disable-background-timer-throttling --disable-features=CalculateNativeWinOcclusion`，避免窗口被遮挡导致 rAF / 过渡冻结。
- 点击优先 `el.click()`（对 Vue 监听与 Ant 组件有效），原始鼠标事件只用于 hover / 拖拽。
- 长会话与流式页面的等待预算放宽，或用「停止按钮 / 持久化消息」判断进度，不要靠固定 sleep。
- 细节见用户记忆 `tooling-windows.md` 与仓库记忆 `cdp-debug-playbook.md`。

## 验收结论要写进 history

每条批次明细的「验收」段至少给出：测试身份与环境、走的端点与关键字段实测值、页面可见结果、边界项如何验证（真实数据不具备时的构造方式，如页面内 XHR 拦截）。验收与复验结论的落点是 history / plan §1，**不进 v3**（v3 只收「要后端做什么」，见 [doc-conventions.md](./doc-conventions.md) 的「缺陷登记闸门」）。

## 常见页面入口

页面入口表（菜单 → 页面 → 验证点）已下沉到 `ai-school/doc/project-structure.md`「常用页面入口（真机验收用）」——入口随菜单 / 路由重构变化，属于仓库侧状态；本文件只维护验证方法与口径。
