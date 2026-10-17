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

## 浏览器验证

- 优先用 Chrome DevTools MCP / 隔离 Chrome（`--remote-debugging-port=9222` + 独立 `--user-data-dir`）；VS Code 内置预览页的尺寸与截图不可信（viewport 被宿主改回、截图是旧合成帧），布局判定一律用 `evaluate` 读几何。
- 启动 Chrome 时加 `--disable-backgrounding-occluded-windows --disable-renderer-backgrounding --disable-background-timer-throttling --disable-features=CalculateNativeWinOcclusion`，避免窗口被遮挡导致 rAF / 过渡冻结。
- 点击优先 `el.click()`（对 Vue 监听与 Ant 组件有效），原始鼠标事件只用于 hover / 拖拽。
- 长会话与流式页面的等待预算放宽，或用「停止按钮 / 持久化消息」判断进度，不要靠固定 sleep。
- 细节见用户记忆 `tooling-windows.md` 与仓库记忆 `cdp-debug-playbook.md`。

## 验收结论要写进 history

每条批次明细的「验收」段至少给出：测试身份与环境、走的端点与关键字段实测值、页面可见结果、边界项如何验证（真实数据不具备时的构造方式，如页面内 XHR 拦截）。

## 常见页面入口（给点击流程时用）

| 页面 | 进入路径 | 常见验证点 |
| --- | --- | --- |
| 工具货架 | 工具货架菜单 | 筛选（类型 / 厂商 / 场景）、上架状态、卡片标签按字典渲染 |
| AI 底座（AI大模型 / AI应用） | AI底座菜单两页 | 按域取已上架工具、类型行显隐、筛选项按域字典 |
| 资产与合同 | 运营中心 → 资产与合同 | 批次卡生效 / 截止、用量配额面板、工具消耗明细（个人口径） |
| 账户总览 | 个人中心 / 账户总览 | 工具消耗构成、总量与按工具拆分 |
| 课程中心 / 学习页 | 课程中心 → 卡片 → 学习页 | 授权四态、解锁时长、讲次可用性 |
| 对话面板（大厅助手 / 工具导师 / 课程导师） | 对应入口打开对话 | 首屏分段、滚顶翻页、「已到对话开头」、流式与追问建议 |
| 团队数据中心 | 运营中心 → 数据中心 | 成员表服务端分页 / 筛选 / 排序、用量口径一致 |
