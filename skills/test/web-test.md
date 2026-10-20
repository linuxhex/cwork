> **按需加载**：本文件由 test SKILL.md 在 PROJECT_TYPE=web 时 Read 加载，不随 SKILL.md 一起全量加载。

# Web 测试链路

> 以下内容仅在 PROJECT_TYPE=web 时执行

## 前置条件

### 必须满足

1. 存在前端工程（含 `package.json`）——或测试目标为已部署的远程环境
2. 本地模式：有可用的启动命令（`dev`/`start`/`serve`）
3. ego-browser 已安装

### ego-browser 依赖（唯一引擎）

**ego-browser** 是本技能的唯一驱动引擎，基于 Chromium 提供真实浏览器控制能力。

- **安装检测**：`command -v ego-browser`（通常位于 `~/.local/bin/ego-browser`）
- **CLI 用法**：`ego-browser nodejs <<'EOF' ... EOF` heredoc 方式
- **任务空间**：隔离浏览上下文，进程结束会话销毁，**登录态不跨任务空间保留**（详见「测试会话硬约束」）
- **三种工作流**：语义（snapshotText + refs）、视觉（截图 + 坐标）、DOM/CDP（js/cdp）
- **首次安装**：若 `ego-browser` 不可用，参考 ego-browser 技能的 `references/install.md` 安装 ego lite 浏览器

### 测试目标环境（两种模式）

| 模式 | 适用场景 | baseUrl |
|------|---------|---------|
| **本地模式** | 前端代码刚改完，验证本地改动 | `http://localhost:{port}`（启动 dev server） |
| **远程直测** | 验证 UAT/test 环境已部署的版本 | 远程环境地址（如 UAT 域名） |

远程直测时**不需要**启动本地服务，plan.json 的 `baseUrl` 直接指向远程环境，测试账号用环境对应的测试账号（登录场景 plan 片段见「登录场景模板」）。

---

## 测试三原则（质量把关，强制）

> 测试是质量把关，不是走过场。以下三条是测试设计的底线，不满足即测试无效。

### 原则 1：场景结合需求改动（可追溯）

- 每个测试场景必须能追溯到需求改动：`changes.md` 的每个改动点、`analysis.md` 的每个功能点、`plan.md` 的每个页面/接口，**至少对应一个测试场景**
- 禁止只测"页面能打开"——改动点没被场景覆盖 = 该改动未被验证
- 测试报告中每个场景标注来源（`来源: changes.md#xxx`），不可追溯的场景是垃圾场景

### 原则 2：正反面都测试（全面覆盖）

- **正面**：正常操作路径（合法输入、正常流程、预期结果）
- **反面**：异常路径——空数据、错误输入、边界值、权限不足、接口失败提示
- 反面场景不需要接口 mock 也能测：非法输入触发前端校验、权限账号访问受限页面、空列表页展示
- 覆盖面检查清单（测试规划时逐项过）：
  - [ ] 主路径（快乐路径）覆盖
  - [ ] 异常路径覆盖（错误输入、空数据、越权）
  - [ ] 边界条件覆盖（空列表、大数据量、特殊字符）
  - [ ] 交互状态覆盖（加载中、禁用状态、弹框）

### 原则 3：断言全面准确（判定客观）

- **确定性断言优先**：数据/文本/数量/样式/接口状态码/业务码/页面↔接口一致性，全部走断言 action，判定客观可复现
- 断言的核心价值不是速度，是**判定标准客观**：`expectStatus: 200` 跑多少次结果一致；"看截图觉得正常"是主观判断，同一截图两次判断可能不同
- 截图+接口数据各看各的发现不了的问题，断言能发现：
  - `assertApi`：接口返回 500/业务码 -1，页面可能只是列表空着没报错
  - `assertDataConsistency`：页面显示的数据与接口返回不一致（渲染错位）
- **aiAssert 只兜底视觉/语义判断**（布局是否美观、文案是否合适），能用确定性断言的不用 aiAssert

---

## 执行模型：Plan + Executor

### 核心架构（单遍执行）

Web 测试采用 **"AI 生成计划 → 执行器单遍执行 → AI 跑后判断"** 模型，解决传统 AI 写 heredoc 的不稳定问题：

```
┌─────────────────┐
│  AI（你）        │  分析需求 → --snapshot 采集页面 → 生成 plan.json（声明式测试计划）
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  web-run.cjs    │  读取 plan.json → 生成 ego-browser heredoc → 单遍执行
│  （执行器）      │  确定性断言（数据/布局/样式/接口）直接判定
│                  │  aiAssert 点仅采集证据（截图+DOM），步骤标 aiPending 不计 passed
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  AI（你）        │  读 AI_ASSERT_PENDING 输出的 ctx 文件（截图+DOM）
│  （跑后判断）    │  → 判断 pass/fail → 合入 result.json → 出报告
└─────────────────┘
```

**单遍契约（关键）**：执行器只跑一遍。aiAssert 步骤不重跑、不阻塞——步骤标 `{ok: null, pending: true}`，场景标 `aiPending`，**不计入 passed**；跑完输出 `AI_ASSERT_PENDING:{contexts, ctxDir, planTotal, resultPath}`，AI 读取各 ctx 文件判断 pass/fail 后**直接合入 result.json 出报告**，不再触发第二次执行。

### 为什么这样设计

| 问题 | 传统方式（AI 写 heredoc） | 新方式（Plan + Executor） |
|------|------------------------|------------------------|
| **准确性** | AI 解读 snapshotText 含糊，断言不精确 | 结构化断言精确匹配，结果可复现 |
| **稳定性** | 每次 AI 生成不同代码，行为不一致 | 同一 plan.json 每次执行相同 |
| **判定客观性** | 判断标准随 AI 状态漂移 | 确定性断言为主，AI 只兜底视觉/语义 |
| **API 验证** | 完全缺失，只看页面文本 | 拦截 fetch/XHR，`assertApi`/`assertDataConsistency` 验证接口 |
| **登录态** | 多个 heredoc 多个进程，登录态丢失 | 单 heredoc 单 tab，登录态全程保持 |

### 执行器脚本与 CLI

**位置**：`skills/test/scripts/web-run.cjs`

| 命令 | 用途 |
|------|------|
| `node web-run.cjs --plan plan.json` | **完整流程（默认推荐）**：单遍执行——确定性断言直接判定，aiAssert 仅采集证据；跑完输出 AI_ASSERT_PENDING，AI 跑后判断合入 result.json |
| `node web-run.cjs --snapshot --url <页面地址>` | **标准化采集**（观察类操作）：打开页面 + 接口拦截 + snapshotText + pageInfo + 截图 |

通用参数：`--ctx-dir DIR`（aiAssert 上下文目录，默认 `/tmp/cwork-web-test-ctx`）、`--out FILE`（result.json 落点）、`--keep`（结束后移交任务空间保持登录态，人工核验用）。

**输出文件落点规则**：

| 文件 | 落点 |
|------|------|
| `result.json` | `--out` 指定；未指定时写 **plan.json 同目录** |
| 失败截图 | result.json 同目录 `screenshots/fail-s{场景}-i{步骤}.png` |
| aiAssert 上下文 | `--ctx-dir`（默认 /tmp/cwork-web-test-ctx），文件名 `s{场景}_i{步骤}.json` |
| AI 判断依据 | ctx-dir `s{场景}_i{步骤}.json`（截图+DOM 证据，AI 跑后读取） |
| --snapshot 输出 | `--out` 指定；未指定时写 ctx-dir/snapshot.json + 同名 .png |

---

## 测试会话硬约束（强制）

> 实战根因：plan-A 靠用户手动登录保活的会话才"碰巧"跑通（AI 感知不到该会话，不可复现）；plan 里的 `fill #login_name` 一直无效（该 id 在真实登录页不存在），每步无效操作触发等待/超时——这是测试慢 + 全场景失败的直接来源。

### 四条铁律

1. **场景 1 必须是真实登录**（被测页面无需登录时除外）：
   - ego 任务空间是隔离浏览上下文，进程结束会话销毁，登录态不跨任务空间保留
   - **禁止依赖外部手动登录的会话**——那是不可复现的偶然条件，AI 无法感知其存在与有效期
   - 测试会话的第一个 UI 场景必须完成完整登录流程，后续场景在同一 tab（`gotoAndWait`）内共享该登录态

2. **登录选择器必须来自真实快照**：
   - 生成 plan.json 前，先用 `--snapshot` 打开登录页拿真实结构（snapshotText + 截图 + 接口响应）
   - 选择器只能来自快照实测（id / class / name / 文本），**禁止凭记忆或猜测编写**（如 `#login_name` 这类实际不存在的 id）
   - 登录页若有"协议勾选" checkbox，plan 中必须包含勾选步骤（YKC 系用 `clickCdp`，见「登录 SOP」），否则登录无效

3. **选择器首次无效立即重取快照**：
   - fill/click 无效（元素不存在/超时）时，立即 `--snapshot` 重取真实结构、修正选择器后重新生成 plan
   - **禁止同一无效选择器反复重试**——无效重试是测试时长爆炸的主要来源

4. **回归测试禁止复用历史 plan.json（强制）**：
   - 每次测试（含回归）都必须重新 `--snapshot` → 重新生成 plan.json，**禁止直接跑上次提交的 plan**
   - 为什么：复用旧 plan 存在「软失效」漏报——页面改版后旧选择器仍可能匹配到语义已变的元素（僵尸 class 未删、列表 index 错位、同名 class 被复用），断言照样通过但没测到真东西，**绿色但失真**
   - 选择器来自当前真实页面是测试真实性的唯一来源，AI 每页一次快照决策的成本不省
   - 某步骤选择器失效重快照时，**该场景整个 plan 重新生成**，不只修单个选择器（页面结构变了，其他步骤的选择器可能也站在软失效边缘）

### 交互稳定性硬约束（强制）

> 实战根因（OMJF-19293 占位单清单处理测试）：场景 A 的错误弹框未关闭，残留弹框与新确认框在快照中叠层，ref 错位导致点到旧弹框按钮，误判"请求已发出"，多轮查 MySQL/日志才实锤第二次请求根本没发出——约一半调试轮次浪费在弹框叠层上。

5. **弹框生命周期（弹框即断言即关闭）**：
   - 出现任何弹框（确认框/成功/错误提示）→ 断言内容 → **立即点关闭/确认 → snapshot 验证页面回到无弹框状态** → 才允许下一步操作
   - **禁止在弹框叠加状态下点击任何按钮**——快照里同时出现两个弹框的文案 = 必须清场重来（关闭全部弹框 + 快照验证），不允许接着点
   - **禁止跨弹框复用 ref**——每次点击前以最新快照为准；残留弹框按钮的 ref 与新弹框相邻时极易点错

6. **captureScreenshot 返回值判据**：
   - 返回值是**文件路径**（如 `/var/folders/.../ego-browser-shot-N.png`），直接 Read 该路径
   - 非 `/` 开头的输出 = 异常/空截图，立即重截，**禁止当 base64 写文件**（写出来只有几十字节）

7. **选择器歧义处理**：
   - `text=` 仅用于唯一精确文本节点；matched > 1 时立即改用快照 ref 或限定容器的 CSS 选择器（如 `.ykc-table :text("清单处理")`），**禁止在歧义结果上猜 index**
   - 表格操作列/列表行内按钮优先用「容器 + 文本」或快照 ref，不用全局 `text=`

8. **提交类操作后先验证请求发出**：
   - 点击提交/确认/删除类按钮后，先验证请求确实发出（`assertApi` 断言 / 接口响应记录 / 组件状态变化），再核对页面文案
   - **禁止只看页面弹框文案判断操作是否生效**——残留弹框的文案是旧的，会骗人（文案在、请求没发）

9. **JS 绕过准则（页面自身 bug 时）**：
   - 页面既有 bug 导致正常 UI 前置条件走不通时（如组件初始化 `radioType={}` 导致表单校验必失败），允许用 JS 调组件方法/直接赋值**造前置状态**
   - 被测功能链路本身必须走真实 UI 操作，**禁止 JS 直接调接口替代被测操作**
   - 测试报告必须记录：绕过原因（页面 bug 现象）、绕过方式、影响范围（该前置条件的 UI 交互未覆盖）

### 探索套路与止损极值（防卡死，通用强制）

> 实战根因（OMJF-18923 UAT，2026-10-16）：勾选框点不动 → 换姿势盲试 3+ 轮、轮间零观察；实际操作已生效却没验证状态 → 误判失败继续折腾。任何页面的陌生组件都可能触发同类卡死——必须按套路探索、按极值止损。

**探索套路（操作不生效时的标准循环，每轮必须「观察 → 操作 → 验证」闭环）**：

1. **操作后必须验证效果**：每次 fill/click 后用断言/截图/URL 确认状态变化，**未验证的操作不算完成**——这是防止"实际成功了却继续折腾"的唯一手段
2. **无效 → 先观察再换方式**：captureScreenshot + 抓目标元素真实 DOM（outerHTML / 事件绑定方式）；本地有前端工程时直接查组件源码找事件绑定——这是最准路径，快过任何盲试
3. **通道升级顺序**（每升一级前必须有一次观察）：快照 ref / CSS 选择器 → JS 合成 click → 容器/父级点击 → `clickCdp` 真实鼠标坐标 → 查组件源码 → JS 绕过造前置状态（铁律 9）

**止损极值（三层，防无限折腾）**：

| 层级 | 极值 | 触发后动作 |
|------|------|-----------|
| 单目标 | 同一元素 3 次操作（含换通道）仍无效 | 停手，输出卡点报告（截图 + DOM + 已试方式），该步骤标 BLOCKED，继续后续步骤 |
| 单场景 | 场景含 BLOCKED 步骤 / 失败重试 2 次 | 场景失败收场，跳下一场景，禁止无限诊断 |
| 全局 | totalBudgetMs 预算到点 | 执行器看门狗触发：落盘部分结果 → 退出 → 输出已完成结果 + 阻塞清单，等人工介入 |

**plan 执行与止损的关系**：plan 驱动执行时**首败即停**（场景内第一个失败步骤自动截图 → 结束该场景 → 继续下一场景），失败原因在 result.json 的 `steps[].error`；止损极值约束的是**生成 plan 前的探索与 plan 修正循环**（快照 → 修 plan → 重跑），不是单次 plan 执行内部。

**禁止**：无观察的连续重试、同一通道反复重试、在未验证上一操作效果的状态下继续下一步。

### 登录 SOP（最高频卡点，强制）

> 实战根因 1（OMJF-18923 UAT 验证，2026-10-16）：协议勾选框 JS click 后 class 不变 → AI 换姿势盲试 3+ 轮；实际其中一次 CDP 点击已勾选且登录成功，但 AI 未验证 URL，误判"还在登录页"继续折腾——登录环节白耗 10+ 轮。
>
> 实战根因 2（OMJF-18923 UAT 取证，2026-10-20）：验证码弹窗确认按钮选择器 `.el-dialog__footer button:has-text('确认')` 匹配到**隐藏 el-dialog**（忘记密码/多账号弹窗），不是验证码弹窗真实按钮 → 点击无效 → 校验接口从未发出 → 弹窗滞留 + 登录按钮永久灰死（loginDisabled=true 不复位），而 plan 里"等待+aiAssert 凑数"照样跑出通过——假通过。

1. **登录成功唯一判据 = 确定性 URL 断言（`waitForUrl` / `assertUrl`），禁止其他判据**：
   - plan 中登录场景最后一步必须写 `{ "action": "waitForUrl", "notContains": "/login", "desc": "登录成功判据：URL 已离开登录页" }`
   - **禁止**用 aiAssert/按钮状态/checkbox class/凑数等待判断登录成功——aiAssert 只是证据采集不计入 passed，凑数等待掩盖真实结果（根因 2 的假通过来源）
2. **点击无效果 → 先诊断再动手，禁止换姿势盲试**：点击后页面状态无变化时，第一动作是 `captureScreenshot()` + 抓目标元素真实 DOM/事件绑定，搞清"为什么没生效"再操作。`click icon → click 父级 → CDP` 式连环换姿势 = 乱操作，**每次换操作方式之前必须有一次观察**（截图或 DOM 检查），零观察的连续重试禁止
3. **YKC 系登录页已知结论**（写 plan / 现场操作直接采用，不重新试错）：协议勾选框是自定义 Vue 组件，JS 合成 click 不触发状态变更，**用 `clickCdp`（真实鼠标坐标）点击勾选框**，随后点击登录按钮，最后断言 URL 跳转
4. **OMP（云快充运营管理平台）验证码弹窗已知结论**（实测取证，直接采用）：
   - 弹窗来源：`Login.vue verifyCodePop()` 用 `$cusDialog`（ykc-dialog 自绘组件）动态挂 body，**不是 el-dialog**——DOM 里 `.el-dialog__footer` 属于登录页隐藏的忘记密码/多账号弹窗，与验证码弹窗无关
   - 弹窗出现条件：`isCommonlyUsed==='1'`（登录 IP 判断）——换 IP 可能不弹，plan 用 `waitForElement .customize-dialog` 短超时探测分支，超时不代表失败
   - 正确选择器：弹窗容器 `.customize-dialog`；标题 `.customize-dialog .title`（文案"登录地址发生变化，请输入验证码"）；验证码输入框 `#verificationCode input`（ykc-input 的 id 透传到根 div，需后代选择器，见 element-ui 坑 11）；确认按钮 `.customize-dialog .bnt-right`；取消按钮 `.customize-dialog .bnt-box button` 第 1 个
   - **验证码是真实短信验证码**：点"获取验证码"会真实发短信（URL_SENDVERIFYCODEBYACCOUNTID）。自动测试**禁止点获取验证码**（零副作用原则）；有万能码/测试码用之，没有则该分支标 BLOCKED 转人工——**禁止瞎填 666666 等猜测值当通过**
5. **风控/验证码预案**：弹"登录地址发生变化"类风控提示但主界面已可见 → 判定登录成功，在报告中记录说明；验证码分支走不通按第 4 条标 BLOCKED，不阻塞后续无需登录的场景

---

## Web 阶段一：环境准备

### 本地模式

```
═══════════════════════════════════════════════════════════════
【cwork-test·Web】启动测试环境
═══════════════════════════════════════════════════════════════

→ 检测启动命令：{DEV_CMD}
→ 启动开发服务器...
→ 等待服务就绪...
→ 服务地址：{URL}
```

1. 在后台启动开发服务器（`npm run dev` / `npm start` / `npm run serve`，按 package.json 实际脚本）
2. 等待服务就绪（轮询检测端口可用）
3. 记录服务地址（默认 `http://localhost:3000`，端口冲突时自动递增）

### 远程直测模式

- 跳过本地启动，确认远程环境可达（curl 探活登录页）
- 确认测试账号与该环境匹配（UAT 账号 ≠ 本地账号）
- plan.json 的 `baseUrl` 直接填远程地址

### 检测 ego-browser

```bash
if ! command -v ego-browser &>/dev/null; then
    echo "❌ ego-browser 未安装"
    echo "安装方式：参考 ego-browser 技能的 references/install.md"
    exit 1
fi
echo "✓ ego-browser 可用：$(command -v ego-browser)"
```

---

## Web 阶段二：测试规划（生成 plan.json）

### 场景来源与三原则落地

从需求文档提取场景，并按三原则补全：

| 来源 | 提取内容 |
|------|---------|
| `changes.md` | **改动点清单——每个改动点至少一个场景（原则 1）** |
| `analysis.md` | 业务功能点、用户操作流程 |
| `plan.md` | 实现的功能清单、页面列表、接口清单（接口清单 → `assertApi` 场景） |
| `design-system.md` / `DESIGN.md` | UI 预期表现（样式/布局 → `assertStyle`/`assertLayout` 场景） |

按原则 2 补反面场景：每个核心功能的正常路径之外，补空数据/错误输入/边界/越权至少一类反面场景。

### plan.json 唯一 schema

**顶层是 `scenarios` 扁平数组**——执行器只识别这个结构，`uiTests`/`apiTests`/`e2eTests` 均不识别（写了会被 0 场景防护拒绝执行）。接口断言不是独立测试类型，是场景内的 `assertApi` action。

```json
{
  "baseUrl": "http://localhost:3000",
  "taskSpaceName": "cwork-test-{需求key}",
  "totalBudgetMs": 600000,
  "scenarios": [
    {
      "name": "登录（YKC 系）",
      "priority": "P0",
      "steps": [
        { "action": "navigate", "url": "/login", "desc": "打开登录页" },
        { "action": "waitForNetworkIdle", "desc": "等待登录页就绪" },
        { "action": "fill", "selector": "input[placeholder='账号']", "value": "szcsl", "desc": "输入账号" },
        { "action": "fill", "selector": "input[placeholder='密码']", "value": "***", "desc": "输入密码" },
        { "action": "clickCdp", "selector": ".login-agreement .el-checkbox__inner", "desc": "CDP 点击协议勾选框" },
        { "action": "click", "selector": ".login-btn", "desc": "点击登录" },
        { "action": "waitForUrl", "notContains": "/login", "desc": "登录成功唯一判据：URL 离开登录页" },
        { "action": "aiAssert", "prompt": "取证：登录后首屏主界面渲染正常", "capture": ["screenshot", "dom"] }
      ]
    },
    {
      "name": "订单列表数据",
      "priority": "P0",
      "steps": [
        { "action": "navigate", "url": "/orders" },
        { "action": "waitForNetworkIdle" },
        { "action": "assertVisible", "selector": ".order-list", "desc": "订单列表可见" },
        { "action": "assertText", "selector": ".page-title", "expectContains": "订单管理", "desc": "标题正确" },
        { "action": "assertCount", "selector": ".order-item", "min": 1, "desc": "至少 1 条订单" },
        { "action": "assertApi", "urlPattern": "/api/orders", "expectStatus": 200, "expectBodyCode": 0, "desc": "订单接口正常" },
        { "action": "assertDataConsistency", "selector": ".order-no", "urlPattern": "/api/orders", "apiField": "data.orders[0].orderNo", "desc": "首行订单号页面与接口一致" }
      ]
    }
  ]
}
```

### 顶层参数

| 参数 | 必填 | 说明 |
|------|------|------|
| `baseUrl` | 是 | 测试目标地址（本地 dev server 或远程环境） |
| `taskSpaceName` | 建议 | ego 任务空间名（默认 `cwork-test`；同一 taskSpaceName 的会话登录态独立） |
| `totalBudgetMs` | 建议 | 全局看门狗预算（默认 600000 = 10 分钟；到点落盘部分结果后退出） |
| `scenarios` | **是** | 场景数组；**空数组会被执行器拒绝** |

### 断言与操作 action 详解（场景 steps[]）

**导航与操作**：

| action | 参数 | 说明 |
|--------|------|------|
| `navigate` | `url` | 导航到页面；相对路径自动拼 baseUrl，绝对 URL 原样使用 |
| `waitForNetworkIdle` | 无 | 等待网络空闲 |
| `waitForLoad` / `waitForNavigation` | 无 | 等待页面加载/跳转完成（两者等价） |
| `waitForElement` | `selector`, `timeout?`（秒，默认 10） | **等待元素出现**再采集——根治动态渲染导致的选择器乱跑。超时后标记 BLOCKED 继续后续步骤，不报错 |
| `waitForUrl` | `contains?`/`notContains?`/`matches?`（至少其一，多条件 AND）, `timeout?`（秒，默认 15） | **轮询等待 URL 满足条件**——登录成功判据的标准写法（`waitForUrl notContains /login`）。超时后标记 BLOCKED 继续后续步骤，不报错 |
| `click` | `selector`, `fallback?` | 点击元素（ego click，带遮挡检查）。`fallback` 见「选择器自愈」 |
| `dispatchClick` | `selector`, `index?`, `fallback?` | JS 合成 MouseEvent click（bubbles），绕过遮挡检查；用于被悬浮横幅遮挡、ego click 静默点在横幅上的按钮（如 OMP top-tip 横幅盖住筛选按钮）。对标准 @click 监听的按钮有效 |
| `clickCdp` | `selector`, `index?`, `fallback?` | CDP 真实鼠标坐标点击（mousePressed/Released 全链）；用于自定义组件勾选框、依赖真实鼠标事件的元素 |
| `openDatePicker` | `selector`, `index?` | JS 合成事件打开 el-date-picker 面板（element-ui 专用，见下） |
| `fill` | `selector`, `value`, `fallback?` | 填充输入框 |
| `responsive` | `viewport: {width, height}`, `steps: [...]` | 切换视口执行子步骤后恢复（响应式测试） |

**确定性断言**：

| action | 参数 | 说明 |
|--------|------|------|
| `assertVisible` | `selector`, `fallback?` | 真实可见性：元素存在 + 宽高 > 0 + 未被 display:none/visibility:hidden 隐藏 |
| `assertUrl` | `contains?`/`notContains?`/`matches?`（至少其一，多条件 AND） | **立即断言当前 URL**（不轮询）——页面跳转后核对落点、防止误停留在登录页/错误页 |
| `assertText` | `selector`, `expectContains` 或 `expect`, `fallback?` | 文本包含 / 全等匹配（trim 后） |
| `assertCount` | `selector`, `expect` 或 `min`/`max` 至少其一 | 元素数量精确匹配或范围 |
| `assertStyle` | `selector`, `property`, `expect` 或 `expectPattern` | computed style 精确匹配或正则匹配 |
| `assertLayout` | `selector`, `expectAlign: "center"` 或 `expectGrid: {columns: N}` | 居中（偏差 ≤ 10px）/ 网格列数 |
| `assertApi` | `urlPattern`, `expectStatus?`, `expectBodyCode?` | 接口断言：状态码 / 业务码（body.code）；同接口多次调用取**最新**一条 |
| `assertDataConsistency` | `selector`, `urlPattern`, `apiField` | **页面 ↔ 接口一致性**：页面元素文本 vs 接口响应字段（apiField 支持 `data.orders[0].orderNo` 路径语法）；生成期强制要求 urlPattern + apiField |
| `exportApi` | `urlPattern` 或 `urlPatterns[]`, `filename`, `filter?` | **导出完整 API 响应到文件**（result.json 同目录）。支持单接口或多接口批量导出；`filter: { status: 200 }` 过滤条件。用于 Doris vs ES 数据比对等场景 |
| `aiAssert` | `prompt`, `capture?: ["screenshot","dom","apiResponses"]` | AI 判断兜底：**单遍契约下仅采集证据**（截图+DOM 写 ctx 文件），步骤标 aiPending 不计入 passed；跑完 AI 读 ctx 判断后合入 result.json。prompt 必须写成可判定判据 |

**选择器自愈（fallback 策略，所有支持 selector 的 action 通用）**：

主选择器失败时，执行器自动按 fallback 顺序尝试备选定位策略，根治动态 class/id 导致的选择器乱跑：

```json
{
  "action": "click",
  "selector": ".el-button--primary",
  "fallback": {
    "text": "登录",
    "classContains": "login-btn",
    "containerAndIndex": { "container": ".login-form", "tag": "button", "index": 0 }
  }
}
```

| fallback 字段 | 说明 |
|--------------|------|
| `text` | 找包含指定文本的可点击元素（BUTTON/A/有 onclick 的元素） |
| `classContains` | 找 class 包含关键字的元素 |
| `containerAndIndex` | 在指定容器内找第 N 个元素（`{container, tag, index}`） |

每个 step 可带 `desc`（人类可读描述，输出与 result.json 使用）。

### element-ui 组件自动化坑（强制，写 plan 前必读）

1. **el-date-picker 面板打开**：合成 click 与 CDP 真实鼠标点击都**打不开**面板（focus 不落地）。必须用 `openDatePicker` action。面板打开后，面板内部元素（日期格 td、上一年/上一月按钮、确定按钮）用普通 `click` 即可（标准 @click 监听）。
2. **确定按钮真实 class（element-ui 版本差异，勿依赖具体 class）**：不同项目 element-ui 版本确定按钮 class 不同——有的版本是 `plain + size mini`（`button.is-plain`、无 `el-button--primary`），实测另有版本页脚为 `[此刻 el-button--text, 确定 el-button--default]`。**统一写法：`.el-picker-panel__footer button` 取 `index: 1`**（页脚按钮顺序固定：[此刻, 确定]），不猜 class；不确定时先 `--snapshot` 实测页脚结构。
3. **YKCDateInterval 等区间组件**（`:editable="false"`）：input readonly，`fill` **永不生效**，只能 `openDatePicker` + 面板点击。时间框真实 placeholder 通常是「选择时间」（不是「开始日期/结束日期」），写 plan 前必须用 `assertCount` 实测确认。**OMP ykc interval 实测补充**（2026-10-16）：控件实际是「单日期+时间」面板（el-date-picker has-time）而非 daterange——每个输入框独立开面板、**必须点面板「确定」才提交表单值**；input0 的面板重复选日期会覆盖起始值（建议每输入框一次性选完整值）；日历 tbody 有空首行导致 `tr:nth-child(N)` 错位（选格前先 `--snapshot` 确认行号）；输入框显示值可与表单真值不一致（断言用 `assertDataConsistency` 或 `__vue__` 链读 searchForm 真值，勿信 input 显示值）。
4. **面板步进 selector**（element-ui 标准）：上一年 `.el-date-picker__prev-btn.el-icon-d-arrow-left`、上一月 `.el-date-picker__prev-btn.el-icon-arrow-left`（class token 精确匹配，不会互串）、日期格 `.el-date-table tr:nth-child(N) td:nth-child(M)`（第一列为周日）、确定 `.el-picker-panel__footer button` 取 `index: 1`（见坑 2，勿依赖 `.is-plain` 等具体 class）。
5. **同 selector 多个输入框**：用 `index` 字段取第 N 个（如页面 4 个「选择时间」框：0/1=开始充电组、2/3=结束充电组，按渲染顺序）。
6. **列表页筛选区默认收起**（YKC OMP 系页面只显 3 项）：先 `click .ykc-search-arrow` 展开再操作深部筛选控件，否则 v-show 隐藏元素全部 Element not found。
7. **多 tab 会话**：登录态不跨任务空间——新 taskSpaceName 必须自带登录场景。
8. **展开/收起 toggle 操作前必须先读状态**（实战：恢复默认保留了展开态，AI 以为要展开又点一次 toggle，反而收起）：toggle 是**反向操作**，点之前用 js 查容器可见元素数或展开态 class 确认当前状态——「恢复默认/翻页/切 tab 后状态可能被重置」，历史状态不可信，盲点 toggle 必反。
9. **v-show 隐藏元素：DOM 存在 ≠ 可点**：收起状态下筛选控件仍留在 DOM（`querySelectorAll` 找得到、assertCount 也能过）但坐标/宽高全 0，click 无效或被遮挡拦截。判可交互必须查可见性（`assertVisible` 已内置 zero-size 检查；探索时用 js 查 `getBoundingClientRect`），plan 里对筛选控件的步骤必须前置「展开容器」步骤，不用元素存在性断言替代可见性。
10. **ego click 遮挡检查被拦 / 静默点在横幅上（OMP top-tip 横幅实战）**：ego 对被遮挡元素会拒绝 click（遮挡检查）；更隐蔽的是**静默落空**——横幅盖住按钮行时 ego 宽松点击实际点在横幅上，查询不发出产生假结果。plan 中直接改用 `dispatchClick`（JS 合成事件通道，绕过遮挡检查，对标准 @click 监听的按钮有效）；`dispatchClick` 无效（自定义组件不监听合成事件）再升 `clickCdp` 真实鼠标坐标，每次升级前先观察一次（铁律：探索套路）。
11. **ykc 系组件 id 透传在根 div，内部 input 需后代选择器**：Vue 2 非 prop 属性继承——`<ykc-input :id="verificationCode">` 的 id 落在组件根 div（`.ykc-input-box`）上，**内部 `<input>` 没有该 id**。`fill #verificationCode` 会报 Element not found，正确写法是后代选择器 `#verificationCode input`（OMP 验证码输入框实测）。同理适用 ykc-select/ykc-date 等所有 ykc 封装组件。
12. **`:has-text()` 仅操作类通道支持，断言类原生 querySelector 会炸**：执行器 `window.__locateElement` 自定义解析支持 `:has-text`（click/dispatchClick/clickCdp/fill 可用），但 **assertVisible/assertText/assertCount 无 fallback 时走原生 `document.querySelector`，遇到 `:has-text` 直接 SyntaxError**（伪类不是标准 CSS）。断言类步骤的文本匹配用 `assertText` + `expectContains`，不要往 selector 里塞 `:has-text`。另注意：**同名选择器可能匹配到隐藏弹窗**——`.el-dialog__footer button:has-text('确认')` 这类宽选择器会命中页面上隐藏 el-dialog 的按钮（OMP 登录页假点击根因），断言/点击前先 `assertCount` 确认匹配数，弹窗类操作限定容器（如 `.customize-dialog .bnt-right`）。

### 登录场景模板（固化复用，选择器必须实测）

登录场景是每个 plan 的固定开头（铁律 1）。以下模板直接套用，但**选择器/账号每次用 `--snapshot` 实测确认**（铁律 2/4），不盲抄历史 plan：

```json
{
  "name": "登录",
  "priority": "P0",
  "steps": [
    { "action": "navigate", "url": "/login" },
    { "action": "waitForNetworkIdle" },
    { "action": "fill", "selector": "{实测：账号输入框}", "value": "{测试账号}" },
    { "action": "fill", "selector": "{实测：密码输入框}", "value": "{测试密码}" },
    { "action": "clickCdp", "selector": "{实测：协议勾选框}", "desc": "YKC 系协议框 JS click 无效，必须 CDP" },
    { "action": "click", "selector": "{实测：登录按钮}" },
    { "action": "waitForUrl", "notContains": "/login", "desc": "登录成功唯一判据：URL 已离开登录页（确定性断言，禁止用 aiAssert/按钮状态替代）" },
    { "action": "aiAssert", "prompt": "取证：主界面已渲染（导航/菜单可见），记录登录后首屏状态", "capture": ["screenshot", "dom"] }
  ]
}
```

- 通用系统（协议框是原生 checkbox）把 `clickCdp` 换成普通 `click` 即可
- **登录成功判据必须是 `waitForUrl`（确定性）**，aiAssert 只做跑后取证不计入 passed——凭"按钮变灰/等待 N 秒/aiAssert 兜底"判登录成功 = 假通过（实战根因 2）
- **验证码预案（见登录 SOP 第 4 条）**：验证码分支用 `waitForElement .customize-dialog` 短超时探测；确认按钮限定弹窗容器（OMP：`.customize-dialog .bnt-right`）；**验证码是真实短信码，禁止点"获取验证码"、禁止瞎填猜测值当通过**，无万能码则该分支标 BLOCKED 转人工
- 登录失败重跑不换账号——先按「登录 SOP」诊断，禁止盲换账号或盲改密码

### 复杂场景降级路径（plan 表达不了时，强制）

> 实战根因（USAGE_NOTES 10-15 遗留）：测试需要 MySQL 造数 + 后端落库验证时，plan.json 表达不了，曾退化回手写 heredoc——破坏单 heredoc 登录态约束。必须走降级路径而不是破坏执行模型。

plan.json 是 UI 层声明式计划，以下场景**不在 plan 内硬造**，按归属分流：

| 场景 | plan 内做法 | plan 外联动 |
|------|------------|------------|
| 需要 DB 造数（特定状态订单/边界数据） | UI 层不造数 | 测试前用 `cwork-data` 查/确认数仓已有数据；无现成数据则向用户说明，改用现有数据设计场景 |
| 后端落库验证（操作后数据是否正确写入） | UI 层只断言 `assertApi`（接口返回正确） | 调 `cwork-log` 查服务日志/链路确认写入成功，或 `cwork-data` 查落库结果 |
| 接口本身的功能测试（不依赖 UI） | 场景内 `assertApi` 断言被页面触发的接口 | 独立接口测试不属于 cwork-test，走 `cwork-log`/`cwork-data` 查证或向用户说明限制 |
| 性能验证 | 不在 plan 内 | `cwork-graf` 查监控 / `arms_traces.sh` 查 P99 |

**禁止**：为了造数/验证落库在 plan 外手写第二个 heredoc（登录态丢失）、在 plan 里用 JS 直调后端接口造状态（违反铁律 9）。

### AI 生成 plan.json 的原则

1. **确定性断言优先**：能用 `assertText`/`assertCount`/`assertApi`/`assertDataConsistency` 的，不用 `aiAssert`（三原则 3）
2. **aiAssert 只兜底视觉/语义判断**：布局是否美观、颜色是否协调、文案是否合适等主观判断；aiAssert 的 prompt 必须写成**可判定的判据**（"URL 已离开 /login 且主界面可见"），不写模糊描述（"页面正常"）
3. **选择器先实测后生成（强制）**：生成 plan.json 前必须 `--snapshot` 拿真实页面结构（含接口响应），基于实测结构写选择器，含登录场景的真实选择器与协议勾选步骤
4. **场景间通过登录态关联、通过导航独立**：场景 1 登录后，其余场景各自 `navigate` 到目标页，不依赖前一场景留下的页面状态
5. **选择器优先级**：`[data-testid]` > `id` > 稳定业务 class > **文本定位** > XPath。注意两类步骤语法不同：
   - **操作类（click/clickCdp）**：selector 原样透传给 ego 定位引擎，支持 ego 定位表达式——`text=登录`、`.ykc-table :text("清单处理")`（容器限定的文本定位，推荐用于列表/表格按钮，文本比编译产物 class 稳定，YKC 系 class 常是混淆名）。`text=` 仅用于唯一精确文本节点，歧义时改用容器限定或 ref。
   - **断言类（assertVisible/assertText/assertCount/assertStyle/assertLayout）**：走 `querySelector`，**只支持 CSS 选择器**，不支持 `text=`。
6. **接口断言跟着操作走**：提交/查询类操作后紧跟对应 `assertApi`（验证请求真的发出且成功），不只看页面提示（铁律 8）

### plan 确认（测试规划完成后）

```
═══════════════════════════════════════════════════════════════
【测试规划】plan.json 已生成
═══════════════════════════════════════════════════════════════

场景清单（{N} 个，覆盖 changes.md {M} 个改动点）：
  1. [P0] 登录（来源: 前置条件）
  2. [P0] 订单列表数据 — assertApi / assertDataConsistency（来源: changes.md#订单列表）
  3. [P0] 订单列表空数据展示（反面）（来源: analysis.md#列表）
  4. [P1] 导出功能 — click + assertApi（来源: changes.md#导出）

三原则自检：
  - 可追溯：{M}/{M} 改动点已覆盖 ✓
  - 正反面：正面 {a} + 反面 {b} ✓
  - 断言：确定性断言 {x} 处 / aiAssert {y} 处 ✓

plan.json 已生成：docs/requirements/{key}/plan.json
是否开始执行？
```

---

## Web 阶段三：测试执行

### 执行命令

```bash
cd docs/requirements/{key}

# 完整流程（单遍执行）：确定性断言直接判定，aiAssert 仅采集证据；跑完 AI 判断合入 result.json
node /path/to/skills/test/scripts/web-run.cjs --plan plan.json

# 指定结果落点（默认写 plan.json 同目录 result.json）
node web-run.cjs --plan plan.json --out result.json
```

### 执行器内部流程

web-run.cjs 内部自动生成 ego-browser heredoc 并执行：

```
1. 读取 plan.json（0 场景 → 拒绝执行）
2. 生成 ego-browser heredoc 代码：
   - 创建任务空间：useOrCreateTaskSpace(taskSpaceName)
   - 打开初始页面：openOrReuseTab(baseUrl)（整个会话唯一一次）
   - 注入接口拦截器（Page.addScriptToEvaluateOnNewDocument 注册 + 立即注入覆盖首屏）
   - 逐场景执行 steps（首败即停：截图归档 → 结束该场景 → 下一场景）
   - aiAssert 点：截图 + snapshotText + 接口响应 → 写 CTX_DIR/s{i}_i{j}.json → 输出 AI_ASSERT_COLLECTED 标记；步骤标 aiPending 不计入 passed
   - 全局看门狗：totalBudgetMs 到点 → 落盘部分结果 → 退出
   - 关闭任务空间：completeTaskSpace(task.id)
3. 执行 heredoc（spawn ego-browser nodejs）
4. 写 result.json（--out 或 plan.json 同目录）
```

### heredoc 粒度约束（已自动化）

**⚠️ 重要**：web-run.cjs 内部已保证整个测试会话在一个 heredoc 内执行，AI 无需手动管理。

**约束内容**（web-run.cjs 自动遵守）：
1. 整个测试会话只有一个 `ego-browser nodejs` 进程
2. 只有一个 `useOrCreateTaskSpace` 调用
3. 只有一个 `openOrReuseTab` 调用（在开头）
4. 所有后续场景用 `gotoAndWait` 导航
5. 只有一个 `completeTaskSpace` 调用（在结尾）

**为什么必须一个 heredoc**：
- 每个 `ego-browser nodejs` 是独立进程，进程结束后 tab 引用和浏览上下文丢失
- 下一个 heredoc 无法感知上一个进程的 tab，`openOrReuseTab` 会新开标签页
- 新标签页没有之前的 cookie/session，**导致登录态丢失，页面跳转到登录页**

### AI 跑后判断（aiAssert 合入，单遍契约）

单遍执行完成后，若 plan 含 aiAssert，执行器输出：

```
AI_ASSERT_PENDING:{"contexts":["/tmp/cwork-web-test-ctx/s0_i11.json"],"ctxDir":"/tmp/cwork-web-test-ctx","planTotal":1,"resultPath":"docs/requirements/{key}/result.json"}
```

**AI 操作步骤**（执行器已跑完，不再重跑）：

```bash
# 1. 读取上下文（含截图路径、DOM 快照、pageInfo.url）
cat /tmp/cwork-web-test-ctx/s0_i11.json

# 2. Read 截图文件做视觉判断

# 3. 按 prompt 判据判断 pass/fail，直接合入 result.json：
#    对应步骤 {ok: true/false, pending 删除}，场景 aiPending → 按实际结果计 passed/failed
#    判断依据必须引用证据：pageInfo.url / 截图内容 / DOM 文本，不写"看起来正常"
```

**假通过防线（执行器已内置）**：plan 声明的 aiAssert 数 vs 实际采集数比对——声明了却一个没采集到（步骤在 aiAssert 之前失败/标记丢失）时响亮告警「result.json 中的通过数不可视为真实通过」，此时必须人工核查 result.json 全文，禁止直接采信。

**判据要求**：合入时 `reason` 写实际观察到的证据（"URL=/orders，列表渲染 12 行"），不写"看起来正常"。

### 观察与诊断：--snapshot 标准化通道

生成 plan / 诊断失败时的页面观察，**统一走 --snapshot**（不手写 heredoc）：

```bash
# 采集单页：页面结构 + 接口响应 + 截图 一次拿全
node web-run.cjs --snapshot --url "http://localhost:3000/login" --out /tmp/snap-login.json

# 输出：/tmp/snap-login.json（snapshotText/pageInfo/apiResponses/screenshot 路径）+ /tmp/snap-login.png
```

适用：写 plan 前采集选择器、登录页结构实测、失败后重新观察页面状态。

**观察类 heredoc 的边界**：`--snapshot` 已覆盖单页观察需求；确需 --snapshot 表达不了的多步交互观察（如"点开筛选再截图"），允许手写**一次性观察 heredoc**，但必须满足：单 heredoc 内完成、只读不产生测试结论、观察后按铁律 3 修正 plan 重跑。测试执行本身永远走 plan + 执行器，禁止手写执行类 heredoc。

### 失败处理

执行首败即停：场景内第一个失败步骤自动截图归档（`screenshots/fail-s{场景}-i{步骤}.png`）→ 结束该场景 → 继续下一场景。

```
═══════════════════════════════════════════════════════════════
【测试执行·Web】场景 2/4：订单列表数据 ✗
═══════════════════════════════════════════════════════════════

步骤 5：assertCount — .order-item 最少 1 条
  → 结果：✗ 失败：最少 1, 实际 0
  → 失败截图：screenshots/fail-s1-i4.png

处理：
  → 该场景标记失败，继续执行下一场景
  → 全部场景跑完后进入失败诊断（Web 阶段四）
```

**plan 修正循环**：失败原因是选择器失效时，`--snapshot` 重取 → 重新生成该场景 plan（铁律 4）→ 重跑；失败原因是页面行为异常时，进入失败诊断（下一节）。两个方向都走完仍未收敛，按止损极值收场。

---

## Web 阶段四：失败诊断

### 前端证据（自动收集）

执行失败时自动归档：

- **失败截图**：result.json 同目录 `screenshots/fail-s{场景}-i{步骤}.png`
- **失败详情**：result.json 中 `steps[].error`（期望 vs 实际）
- **接口响应记录**：页面拦截的 fetch/XHR 响应（`assertApi` 失败时直接体现状态码/业务码）

### 前后端联合诊断（联动 cwork-log / cwork-config / cwork-data）

当失败证据显示**后端接口异常**（4xx/5xx/超时）或**疑似配置问题**时，调用相关技能深挖：

#### 诊断决策树

```
测试步骤失败
  │
  ├─ result.json / 失败截图：是选择器问题还是页面行为异常？
  │    ├─ 选择器失效（Element not found / 文本对不上）→ --snapshot 重取 → 修正 plan 重跑
  │    │
  │    └─ 页面行为异常（接口 4xx/5xx、数据错误、无响应）↓
  │
  ├─ 是否有后端接口失败（4xx/5xx/超时）？
  │    ├─ 否 → 纯前端问题：查截图 + 组件代码 → 修前端代码
  │    │
  │    └─ 是 → 调用 cwork-log 查后端：
  │            1. 从接口路径 / 时间戳 / 服务名定位
  │            2. sls_query.sh logs <logstore> 搜日志
  │            3. arms_trace.sh 还原链路，找耗时点/异常点
  │            4. 判断：前端传参错？后端逻辑错？下游依赖超时？
  │
  ├─ 是否疑似配置问题（开关未生效/阈值不对）？
  │    └─ 是 → 调用 cwork-config 查 Nacos 配置真值
  │
  └─ 是否涉及数据状态（特定订单/特定用户才触发）？
       └─ 是 → 调用 cwork-data 查数仓核对数据
```

#### 调用 cwork-log 的场景

| 场景 | 前端现象 | cwork-log 查什么 |
|------|---------|-----------------|
| 表单提交无响应 | 点击后页面无变化、无成功提示 | 查提交接口是否 5xx/超时，日志有无异常堆栈 |
| 列表数据为空 | 列表加载完但无数据 | 查查询接口返回内容，SQL 有无报错 |
| 数据不正确 | 显示值与预期不符 | 查接口响应体，核对后端返回字段 |
| 操作报错弹窗 | 页面弹出"系统异常"等 | 查对应 traceId 链路，定位异常 span |
| 性能慢/卡顿 | 页面加载 > 5s | arms_trace.sh 看链路 P99、最慢 span |

#### 联动执行示例

前端抓到 `/api/order/submit` 返回 500 后，调 cwork-log 排查：

```bash
# 1. 拿 pid（先查 ARMS_PID_CACHE.md，索引失效才跑 arms_apps.sh）
bash scripts/arms_apps.sh cn-hangzhou "order"

# 2. 用 traceId 查链路（traceId 从后端日志 trace 字段取）
bash scripts/arms_trace.sh "<pid>" "<traceId>" <ts_ms>

# 3. 或用接口关键字 + 时间窗查 SLS 日志
bash scripts/sls_query.sh <env> logs all "order/submit and ERROR" 100
```

#### 诊断结论输出

```
═══════════════════════════════════════════════════════════════
【失败诊断】场景 3·表单提交
═══════════════════════════════════════════════════════════════

前端证据（来自 result.json + 失败截图）：
- assertApi：POST /api/order/submit 实际 500（期望 200）
- 截图：screenshots/fail-s2-i4.png（页面弹"系统异常"）

后端证据（cwork-log）：
- 日志：OrderService.submit 抛 NullPointerException
- 链路：order-prod → charge-server，最慢 span 在 charge 调用（2.3s）
- 代码位置：OrderService.java:128

结论：后端 bug（非前端问题）
- 根因：OrderService.submit 未校验 chargeServer 返回 null
- 建议：修 OrderService.java:128 的空指针处理
```

> **联动原则**：cwork-test 负责"发现问题并定位到前后端哪一侧"，cwork-log 负责"深挖后端根因"。前端代码问题直接修；后端问题把日志证据带回来，定位到具体文件:行号再修。

---

## 输出文件

| 文件 | 说明 | 提交 |
|------|------|------|
| `plan.json` | 测试计划（声明式，唯一 schema） | 提交 |
| `result.json` | 测试结果（--out 或 plan.json 同目录） | 提交 |
| `screenshots/` | 失败截图证据（result.json 同目录） | 提交 |
| `s{i}_i{j}.json` | aiAssert 上下文（ctx-dir） | 不提交 |
| `s{i}_i{j}.json` | aiAssert 证据上下文（ctx-dir，AI 跑后判断依据） | 不提交 |
| snapshot 快照 | --snapshot 采集（观察用） | 不提交 |

---

## 自动衔接

1. **写测试报告**：无论通过/失败，均生成 `test-report.md`（含截图证据、场景来源标注、三原则自检结果）
2. **有失败场景**：询问用户"测试有失败场景，是否调起 cwork-bug 进行代码修复？"
   - 用户确认 → 进入 cwork-bug 修复 → 修复后重新生成 plan 执行失败场景 → 全部通过 → 进入 cwork-commit
   - 用户跳过 → 按 P0/P1/P2 分流（见 SKILL.md HARD GATE）：仅 P1/P2 失败可进 commit；P0 失败默认禁止提交
3. **全部通过**：询问用户是否调起 commit 技能进行代码提交，经用户确认后再进入 commit
