---
name: browser-verification
description: 前端改动的真机浏览器验证与 CDP 调试：预览与截图的可靠性分级与自证（几何读数优先）、隔离 Chrome 会话的启动与清理、遮挡窗口的动画冻结、探针脚本（视口几何 / 真窗截图 / 像素采样）、Vite dev 缓存陈旧诊断。USE FOR: 验证页面布局与响应式断点、模拟宽屏或窄屏视口、抓取悬停或弹层等交互态、自动化点击与填表、截图留档、改了样式却不生效的排查、当前模型不支持看图时的像素级视觉验证。DO NOT USE FOR: 不涉及浏览器的纯逻辑代码、后端接口协议调试（走接口日志与代码）。
---

# 浏览器真机验证与 CDP 调试

沉淀自 ai-school / web-baseline 两仓的真机验收实践（2026-10 起）。适用 Windows + 隔离 Chrome（CDP）+ Vite dev 场景。

> 措辞约定（2026-10-19 校准）：「观察到 / 实测」= 真实发生过；「怀疑 / 候选」= 未定位的推断；标注「一例」的为单次观察，泛化需谨慎。

## 核心原则

- **分清三类问题**：视口控制（resize 是否生效）、状态观测（读到的是不是当前状态）、结果判定（用什么下结论）——多数「预览不可信」事故源于把三者混为一谈。
- **视口控制不保证生效**：观察到请求的视口与实际 `innerWidth` 不一致的一例（同会话先后读到 1440 与 646；原因未定位，候选：宿主布局接管、预览面板被拖动）。因此 resize 后必须自证：resize 与读取放**同一工具调用**内、中间 `waitForTimeout(1200)`、返回值带 `innerWidth` 比对；不符就重试或换隔离 Chrome。
- **截图可能拍到旧合成帧**：内置预览上多次观察到截图内容是上一状态（宽度 / 换行 / 错位），`animations:'disabled'` / `clip` / `fullPage` 都救不回来；成因未定位（候选：窗口遮挡致合成器不出新帧，与下条 rAF 冻结可能同源）。截图**无法自证新鲜度**，故不作为几何判定的依据；要可控截图用隔离 Chrome 真窗（`scripts` 的 `shot` 模式）。
- **判定按信息类型选通道**：
  - 几何 / 布局 → DOM 读数（`getBoundingClientRect` / `getComputedStyle`）：精确、便宜、可搭配 `innerWidth` 自证。
  - 视觉质量（配色 / 渲染 / 观感）→ 截图：模型支持看图就看图；不支持就像素采样（`pixel-probe.ps1`）；并留档给人工复核（隔离 Chrome 真窗截图已两次与几何读数互相印证）。
  - 交互态（弹层 / 动画）→ 先查 `document.visibilityState`：为 `hidden`（内置预览常态）时 rAF 冻结（实测：打字机停 0 字、点击稳定性超时、antd 弹层状态已切换但动画卡住），换隔离 Chrome；可见时预览可用。
- **几何断言要全量比对**：只比左边缘或只比中心，会漏掉「位置对、大小错」（实测漏检一例：svg 回退 300×150，位置对、尺寸爆炸）——比对 `l/t/w/h` 四项再下结论。

## 隔离 Chrome 会话

- 启动（PowerShell）：

  ```powershell
  Start-Process chrome.exe -ArgumentList '--remote-debugging-port=9222',("--user-data-dir=$env:TEMP\chrome-<tag>"),'--window-size=1440,960','--new-window','<url>'
  ```

- `chrome.exe` 须在 PATH（家用机已验证；公司机首次使用若报找不到，改绝对路径）；9222 被占时换端口，并同步改脚本里的 `CDP` 常量。
- 启动前先 `Invoke-WebRequest http://127.0.0.1:9222/json/version` 确认端口没被遗留实例占用；启动后再查一次自证。
- 窗口被遮挡 ⇒ 页面 `hidden`：rAF 冻结、`Page.captureScreenshot` 返旧合成帧或挂起。`bringToFront` / `SetWindowPos TOPMOST` 等均不可靠；根治 = 启动参数加 `--disable-backgrounding-occluded-windows --disable-renderer-backgrounding --disable-background-timer-throttling --disable-features=CalculateNativeWinOcclusion`（先前会话实测加参数后恒 visible；与「截图旧合成帧」疑同源）。
- 关闭：`Stop-Process` 报「拒绝访问」时走 CDP `Browser.close`（`scripts/cdp-page-probe.mjs` 的 `close` 模式，可优雅退出并释放端口）。
- 僵尸排查：旧 9222 实例存在时，新 Chrome 会**静默降级为不可调试的普通窗口**（观察到一例）。按命令行匹配清理；PS 管道绑定整批失败的通用坑与修法见 `windows-toolchain-pitfalls`「PowerShell 5.1」节：

  ```powershell
  Get-CimInstance Win32_Process -Filter "Name = 'chrome.exe'" | Where-Object CommandLine -like '*chrome-<tag>*' | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
  ```

## 交互与状态采集

- **点击优先用 `el.click()`**：观察到 `Input.dispatchMouseEvent` 完全不命中的一例（坐标与 `elementFromPoint` 都正确也无反应，原因未定位）；`el.click()` 对 Vue 监听、Ant 组件、popconfirm 实测有效。原始鼠标事件只用于 hover / 拖拽。
- **hover 终态**：遮挡窗口下 transition 冻结在起点值（`getComputedStyle` 读数骗人）。取终态：先 `transition='none'` → 真实 hover → 读 → 还原。
- 隐藏标签页 `setTimeout` 被钳到 ~1s/次：模拟流式要把窗口提到最前，或放宽等待预算到 10–15s 并用「停止按钮 / 持久化消息」判断进度。
- 短暂 UI 态（骨架 / 弹层中间态）：MCP `take_screenshot` 会等页面稳定，拍到时状态已过。改 Node 侧轮询选择器 → 立即截图 → 等状态消失再截对比图（观察到一例：`run_playwright_code` 与 chrome-devtools MCP 的页面注册表不互通，对 MCP 打开的页面报 Page not found，用 CDP 直连脚本替代）。
- **长 evaluate 跨导航会被中断**（IIFE 里 `await sleep` 期间路由跳转 → CDP 返回空 result）：流程编排放 Node 侧，每次 evaluate 保持短小。
- evaluate 异步 IIFE 要 `awaitPromise: true`，否则被序列化成 `{}`（像是没执行）。
- 页面标题含中文：先 `document.title += ' [TAG]'` 打 ASCII 标记供 PowerShell 匹配（免 .ps1 乱码）；脚本里 `Add-Type` 前用 `([System.Management.Automation.PSTypeName]'X.Y').Type` 守卫（重复 Add-Type 会静默失败）。
- 造文件选择事件：`new DataTransfer()` + `new File(...)`，无需真实文件框。

## 探针脚本（scripts/，ASCII only）

- `cdp-page-probe.mjs`（Node 22+，内置 WebSocket，无 npm 依赖）：
  - `node cdp-page-probe.mjs geom <urlSubstr> <exprFile> [WxH ...]`：`Emulation.setDeviceMetricsOverride` 逐档模拟视口，每档 evaluate 表达式文件（须返回可 JSON 化的值），输出 JSON 数组。**宽度变化时截图不可靠，但几何读数可信**——这是响应式断点验证的主力模式。
  - `node cdp-page-probe.mjs shot <urlSubstr> <W> <H> <outPng>`：`Browser.setWindowBounds` 把真实窗口调到目标尺寸再 `Page.captureScreenshot`（比 override 截图可靠；`setWindowBounds` 超过物理屏幕尺寸时的行为未验证、可能被 clamp，超屏场景改用 geom 模式）。
  - `node cdp-page-probe.mjs close`：优雅关闭调试 Chrome（`Browser.close`，释放端口）。
  - 附 `expr-example.js`：geom 模式的几何表达式模板（改 selectors 数组即用）。
- `pixel-probe.ps1`（把截图变成可判定的数据：颜色断言、与几何读数互证；模型不支持看图时是唯一视觉通道，支持看图时也可做定量断言）：
  - `powershell -ExecutionPolicy Bypass -File pixel-probe.ps1 -Png <图> -CssWidth <截图时视口CSS宽> -PatchesFile <面块清单>`
  - 面块清单每行 `label,x0,x1,y0,y1`（CSS px）；脚本按 `图宽 / CssWidth` 求 DPR 换算后 `GetPixel` 步进 3 求面块均值 RGB。
  - **`Page.captureScreenshot` 返回物理分辨率**（如 DPR 1.75：视口 1907×931 → 图 3338×1630），采样前必须换算；**单像素判色不可靠**（背景白 250 与面板白 254 得靠均值区分）；面块选位避开文字 / 按钮等强干扰（蓝色主按钮会把均值拉蓝）。
- 历史脚本模式（`%TEMP%` 原型已被上述脚本取代，需要时按模式重建）：hover 截图（真实 hover 后截图）；样式规则探针按子串扫 `document.styleSheets` 的 `rule.cssText`（只匹配 `selectorText` 会漏带属性选择器的规则）；长 JS 表达式一律落文件执行、不走终端内联（PS 命令规范化会改坏内嵌 JS，见 `windows-toolchain-pitfalls`）。

## Vite dev：改了样式但不生效（缓存陈旧）

- 症状：编辑 `.vue` 后 watcher 打印 `hmr update`，但再次请求仍返回**旧编译结果**（`v-bind(token.x)` 名还是旧的 → `var()` 取不到值、样式静默失效），touching、`?t=` 都无效；全局 SCSS 场景则可能整段被缓存成空（`document.body` 样式全丢、`style[data-vite-dev-id$=...]` 长度为 0），刷新不恢复。
- 判定三板斧（页面里或终端 fetch）：请求 `/src/<file>` 的 JS 包装 grep 新代码；**纯样式改动要抓 style 子模块**（主模块不含 `<style>`）：从主模块正则 `[^\s"']*type=style[^\s"']*` 提取 URL 再请求它 grep 新 class / keyframes（scoped 会重命名动画名）；加任意 query（`?direct` / `?probe=1`）拿到正确 CSS ⇒ 说明只有 module graph 里**确切 id** 的转换结果被污染，源码与 Sass 编译都正常。
- 修复：`.vue` 场景重启 dev server（`Get-CimInstance Win32_Process -Filter "Name='node.exe'"` 找 vite 的 pid 再 Stop-Process，**别误杀 chrome-devtools-mcp 的 node 进程**）；全局 SCSS 场景 `(Get-Item <file>).LastWriteTime = Get-Date` 触发一次 HMR 重编译即可。
- 教训：改样式后「样式整体没生效」，先查 module 内容与 style 标签长度，不要先怀疑自己的 CSS 语法。

## 维护约定

- 新通用经验先落本技能（git 双机同步）；本机细节（dev 端口、mock 登录、`%TEMP%` 脚本现状）记 repo 记忆 `cdp-debug-playbook.md`，两者冲突时以技能为准。
- 收录标准与措辞约定见文首：推断必须标「怀疑 / 候选」，单次观察标「一例」；记忆里新出现的通用条目要**及时同步进技能**（2026-10-19 曾发现记忆有而技能没有的好条目）。
- 回看机制：技能启用满一个月（2026-11-19）后用 chronicle 查会话历史，统计实际触发与命中情况，据此裁剪或修订条目。
