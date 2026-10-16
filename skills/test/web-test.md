> **按需加载**：本文件由 test SKILL.md 在 PROJECT_TYPE=web 时 Read 加载，不随 SKILL.md 一起全量加载。

# Web 测试链路

> 以下内容仅在 PROJECT_TYPE=web 时执行

## 前置条件

### 必须满足

1. 存在前端工程（含 `package.json`）
2. 有可用的启动命令（`dev`/`start`/`serve`）
3. ego-browser 已安装

### ego-browser 依赖（唯一引擎）

**ego-browser** 是本技能的唯一驱动引擎，基于 Chromium 提供真实浏览器控制能力。

- **安装检测**：`command -v ego-browser`（通常位于 `~/.local/bin/ego-browser`）
- **CLI 用法**：`ego-browser nodejs <<'EOF' ... EOF` heredoc 方式
- **任务空间**：隔离浏览上下文，进程结束会话销毁，**登录态不跨任务空间保留**（详见「登录会话硬约束」）
- **三种工作流**：语义（snapshotText + refs）、视觉（截图 + 坐标）、DOM/CDP（js/cdp）
- **首次安装**：若 `ego-browser` 不可用，参考 ego-browser 技能的 `references/install.md` 安装 ego lite 浏览器

### 自动检测

```bash
# 检测前端工程
if [ -f "package.json" ]; then
    if grep -q '"dev"' package.json; then
        DEV_CMD="npm run dev"
    elif grep -q '"start"' package.json; then
        DEV_CMD="npm start"
    elif grep -q '"serve"' package.json; then
        DEV_CMD="npm run serve"
    fi
fi

# 检测引擎可用性
if ! command -v ego-browser &>/dev/null; then
    echo "❌ ego-browser 未安装，请先安装"
    exit 1
fi
```

---

## 执行模型：Plan + Executor

### 核心架构

Web 测试采用 **"AI 生成计划 → 执行器确定性执行"** 模型，解决传统 AI 写 heredoc 的不稳定问题：

```
┌─────────────────┐
│  AI（你）        │  分析需求 → 生成 plan.json（声明式测试计划）
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  web-run.cjs    │  读取 plan.json → 生成 ego-browser heredoc → 执行
│  （执行器）      │  确定性断言（数据/布局/样式/API）直接判定
│                  │  aiAssert 标记点暂停，输出上下文供 AI 判断
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  AI（你）        │  读取 aiAssert 上下文（截图+DOM）→ 判断 → 写回结果
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  web-run.cjs    │  读取 AI 判断结果 → 继续执行剩余步骤
└─────────────────┘
```

### 为什么这样设计

| 问题 | 传统方式（AI 写 heredoc） | 新方式（Plan + Executor） |
|------|------------------------|------------------------|
| **准确性** | AI 解读 snapshotText 含糊，断言不精确 | 结构化断言（assertText/assertStyle/assertApi），精确匹配 |
| **稳定性** | 每次 AI 生成不同代码，行为不一致 | 同一 plan.json 每次执行相同，结果可复现 |
| **速度** | AI 每次都要生成 heredoc 代码，慢 | 执行器直接读 plan.json，快 |
| **API 验证** | 完全缺失，只看页面文本 | 拦截 fetch/XHR，验证接口返回值 |
| **AI 参与** | AI 全程写代码，但判断不精准 | AI 只在 aiAssert 点介入（视觉/语义判断），其他交给确定性断言 |

### 执行器脚本

**位置**：`skills/test/scripts/web-run.cjs`

**三种执行模式**：

| 模式 | 命令 | 用途 |
|------|------|------|
| **完整流程** | `node web-run.cjs --plan plan.json` | 默认：collect → AI 判断 → run（推荐） |
| **仅收集** | `node web-run.cjs --plan plan.json --collect` | 只执行到 aiAssert 点，收集上下文，不判断 |
| **仅执行** | `node web-run.cjs --plan plan.json --run` | 使用预计算的 AI 判断结果执行（跳过 collect） |

**输出文件**：

| 文件 | 说明 |
|------|------|
| `result.json` | 测试结果（通过/失败/跳过，含截图路径） |
| `ai-contexts/ai-assert-{场景}-{步骤}.json` | aiAssert 上下文（截图路径 + DOM 快照 + 判断标准） |
| `ai-results.json` | AI 判断结果（完整流程模式下自动生成） |

---

## 测试会话硬约束（强制）

> 实战根因：plan-A 靠用户手动登录保活的会话才"碰巧"跑通（AI 感知不到该会话，不可复现）；plan 里的 `fill #login_name` 一直无效（该 id 在真实登录页不存在），每步无效操作触发等待/超时——这是测试慢 + 全场景失败的直接来源。

### 四条铁律

1. **场景 1 必须是真实登录**（被测页面无需登录时除外）：
   - ego 任务空间是隔离浏览上下文，进程结束会话销毁，登录态不跨任务空间保留
   - **禁止依赖外部手动登录的会话**——那是不可复现的偶然条件，AI 无法感知其存在与有效期
   - 测试会话的第一个 UI 场景必须完成完整登录流程，后续场景在同一 tab（`gotoAndWait`）内共享该登录态

2. **登录选择器必须来自真实快照**：
   - 生成 plan.json 前，先用 ego-browser 打开登录页 `snapshotText()` 拿真实结构
   - 选择器只能来自快照实测（id / class / name / 文本），**禁止凭记忆或猜测编写**（如 `#login_name` 这类实际不存在的 id）
   - 登录页若有"协议勾选" checkbox，plan 中必须包含勾选步骤（先 click checkbox 再点登录），否则登录无效

3. **选择器首次无效立即重取快照**：
   - fill/click 无效（元素不存在/超时）时，立即 `snapshotText()` 重取真实结构、修正选择器后重新生成 plan
   - **禁止同一无效选择器反复重试**——每次无效重试 = 白等一次 `stepTimeoutMs`（15s），是测试时长爆炸的主要来源

4. **回归测试禁止复用历史 plan.json（强制）**：
   - 每次测试（含回归）都必须重新 `snapshotText()` 快照 → 重新生成 plan.json，**禁止直接跑上次提交的 plan**
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
   - 点击提交/确认/删除类按钮后，先验证请求确实发出（performance entries / 网络拦截 / 组件状态变化），再核对页面文案
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
| 全局 | totalBudgetMs 预算到点 | 停止全部执行，输出已完成结果 + 阻塞清单，等人工介入 |

**禁止**：无观察的连续重试、同一通道反复重试、在未验证上一操作效果的状态下继续下一步。

### 登录 SOP（最高频卡点，强制）

> 实战根因（OMJF-18923 UAT 验证，2026-10-16）：协议勾选框 JS click 后 class 不变 → AI 换姿势盲试 3+ 轮；实际其中一次 CDP 点击已勾选且登录成功，但 AI 未验证 URL，误判"还在登录页"继续折腾——登录环节白耗 10+ 轮，整个测试被阻塞。

1. **登录成功唯一判据 = `pageInfo()` 验证 URL 已离开登录页**（出现系统主界面路由/右上角用户信息）。**禁止**用"checkbox class 是否变化"判断勾选态——自定义组件点击后 class 不一定变，也不反映登录结果
2. **点击无效果 → 先诊断再动手，禁止换姿势盲试**：点击后页面状态无变化时，第一动作是 `captureScreenshot()` + 抓目标元素真实 DOM/事件绑定，搞清"为什么没生效"再操作。`click icon → click 父级 → CDP` 式连环换姿势 = 乱操作，**每次换操作方式之前必须有一次观察**（截图或 DOM 检查），零观察的连续重试禁止
3. **YKC 系登录页已知结论**（写 plan / 现场操作直接采用，不重新试错）：协议勾选框是自定义 Vue 组件，JS 合成 click 不触发状态变更，**用 `clickCdp`（真实鼠标坐标）点击勾选框**，随后点击登录按钮，最后 `pageInfo()` 验证 URL 跳转
4. **风控/验证码预案**：弹验证码输入框 → 填测试验证码（UAT 通常 666666）后提交；弹"登录地址发生变化"类风控提示但主界面已可见 → 判定登录成功，在报告中记录说明

---

## Web 阶段一：环境准备

### 步骤 1：启动开发服务器

```
═══════════════════════════════════════════════════════════════
【cwork-test·Web】启动测试环境
═══════════════════════════════════════════════════════════════

→ 检测启动命令：{DEV_CMD}
→ 启动开发服务器...
→ 等待服务就绪...
→ 服务地址：{URL}
```

1. 在后台启动开发服务器
2. 等待服务就绪（轮询检测端口可用）
3. 记录服务地址（默认 `http://localhost:3000`，端口冲突时自动递增）

### 步骤 2：检测 ego-browser

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

### 测试场景来源

从以下文档中提取测试场景：

| 来源 | 提取内容 |
|------|---------|
| `analysis.md` | 业务功能点、用户操作流程 |
| `plan.md` | 实现的功能清单、页面列表 |
| `changes.md` | 改动点、新增功能 |
| `design-system.md` / `DESIGN.md` | UI 预期表现（样式/布局/交互） |

### plan.json 结构

```json
{
  "baseUrl": "http://localhost:3000",
  "taskSpaceName": "cwork-test-{需求key}",
  "stepTimeoutMs": 15000,
  "totalBudgetMs": 600000,

  "apiTests": [
    {
      "name": "用户登录接口",
      "priority": "P0",
      "request": {
        "url": "/api/user/login",
        "method": "POST",
        "headers": { "Content-Type": "application/json" },
        "body": { "username": "testuser", "password": "password123" }
      },
      "assertions": [
        { "type": "status", "expected": 200 },
        { "type": "jsonPath", "path": "$.token", "assert": "exists" },
        { "type": "jsonPath", "path": "$.user.level", "expected": "NORMAL" }
      ]
    }
  ],

  "uiTests": {
    "scenarios": [
      {
        "name": "用户登录",
        "priority": "P0",
        "steps": [
          { "action": "navigate", "url": "/login" },
          { "action": "waitForNetworkIdle" },
          { "action": "fill", "selector": "input[name='username']", "value": "testuser" },
          { "action": "fill", "selector": "input[name='password']", "value": "password123" },
          { "action": "click", "selector": "button[type='submit']" },
          { "action": "waitForNavigation" },
          { "action": "assertText", "selector": "h1", "contains": "欢迎" },
          { "action": "assertVisible", "selector": ".user-avatar" },
          { "action": "aiAssert", "criteria": "页面显示用户头像和欢迎信息，布局正常", "screenshot": true }
        ]
      }
    ]
  },

  "e2eTests": [
    {
      "name": "完整下单流程",
      "priority": "P1",
      "scenarios": ["用户登录", "浏览商品", "加入购物车", "提交订单"]
    }
  ]
}
```

### 断言类型详解

#### UI 测试断言（uiTests.scenarios[].steps[]）

| action | 说明 | 参数 | 示例 |
|--------|------|------|------|
| `navigate` | 导航到页面 | `url` | `{"action": "navigate", "url": "/login"}` |
| `waitForNetworkIdle` | 等待网络空闲 | 无 | `{"action": "waitForNetworkIdle"}` |
| `waitForNavigation` | 等待页面跳转 | 无 | `{"action": "waitForNavigation"}` |
| `click` | 点击元素 | `selector`, `index?` | `{"action": "click", "selector": "button.submit"}` |
| `fill` | 填充输入框 | `selector`, `value` | `{"action": "fill", "selector": "input[name='user']", "value": "test"}` |
| `assertVisible` | 元素可见 | `selector` | `{"action": "assertVisible", "selector": ".user-avatar"}` |
| `assertText` | 文本匹配 | `selector`, `contains`/`exact`/`regex` | `{"action": "assertText", "selector": "h1", "contains": "欢迎"}` |
| `assertCount` | 元素数量 | `selector`, `count`/`min`/`max` | `{"action": "assertCount", "selector": ".item", "min": 5}` |
| `assertStyle` | 样式检查 | `selector`, `property`, `expected` | `{"action": "assertStyle", "selector": ".btn", "property": "background-color", "expected": "rgb(255, 0, 0)"}` |
| `assertLayout` | 布局检查 | `selector`, `position?`, `size?` | `{"action": "assertLayout", "selector": ".header", "position": {top: 0}}` |
| `assertApi` | API 响应断言 | `urlPattern`, `status?`, `body?` | `{"action": "assertApi", "urlPattern": "/api/user", "status": 200}` |
| `assertDataConsistency` | 数据一致性 | `apiPath`, `uiSelector`, `transform?` | `{"action": "assertDataConsistency", "apiPath": "$.user.name", "uiSelector": ".username"}` |
| `aiAssert` | AI 判断 | `criteria`, `screenshot?` | `{"action": "aiAssert", "criteria": "页面布局正常，无错位", "screenshot": true}` |
| `responsive` | 响应式测试 | `viewports`, `assertions` | `{"action": "responsive", "viewports": [[375,667],[1920,1080]], "assertions": [...]}` |
| `openDatePicker` | 打开 el-date-picker 日历面板（JS 合成事件派发 focus/mousedown/click，实测唯一稳定通道） | `selector`, `index?`（同 selector 多框时按 querySelectorAll 索引取第 N 个） | `{"action": "openDatePicker", "selector": "input[placeholder='选择时间']", "index": 0}` |
| `clickCdp` | CDP 真实鼠标坐标点击（mousePressed/Released，坐标经 Runtime.evaluate 求值） | `selector`, `index?` | `{"action": "clickCdp", "selector": ".el-picker-panel td"}` |

#### element-ui 组件自动化坑（强制，写 plan 前必读）

1. **el-date-picker 面板打开**：合成 click 与 CDP 真实鼠标点击都**打不开**面板（focus 不落地）。必须用 `openDatePicker` action。面板打开后，面板内部元素（日期格 td、上一年/上一月按钮、确定按钮）用普通 `click` 即可（标准 @click 监听）。
2. **确定按钮真实 class**：本项目 element-ui 版本确定按钮是 `plain + size mini`，**没有** `el-button--primary`！正确 selector：`.el-picker-panel__footer button.is-plain`（「此刻」按钮是 `type:"text"` → `el-button--text`）。
3. **YKCDateInterval 等区间组件**（`:editable="false"`）：input readonly，`fill` **永不生效**，只能 `openDatePicker` + 面板点击。时间框真实 placeholder 通常是「选择时间」（不是「开始日期/结束日期」），写 plan 前必须用 `assertCount` 实测确认。
4. **面板步进 selector**（element-ui 标准）：上一年 `.el-date-picker__prev-btn.el-icon-d-arrow-left`、上一月 `.el-date-picker__prev-btn.el-icon-arrow-left`（class token 精确匹配，不会互串）、日期格 `.el-date-table tr:nth-child(N) td:nth-child(M)`（第一列为周日）、确定 `.el-picker-panel__footer button.is-plain`。
5. **同 selector 多个输入框**：用 `index` 字段取第 N 个（如页面 4 个「选择时间」框：0/1=开始充电组、2/3=结束充电组，按渲染顺序）。
6. **列表页筛选区默认收起**（YKC OMP 系页面只显 3 项）：先 `click .ykc-search-arrow` 展开再操作深部筛选控件，否则 v-show 隐藏元素全部 Element not found。
7. **多 tab 会话**：登录态不跨任务空间——新 taskSpaceName 必须自带登录场景。

#### API 测试断言（apiTests[].assertions[]）

| type | 说明 | 参数 | 示例 |
|------|------|------|------|
| `status` | HTTP 状态码 | `expected` | `{"type": "status", "expected": 200}` |
| `jsonPath` | JSON 路径断言 | `path`, `expected?`/`assert?` | `{"type": "jsonPath", "path": "$.token", "assert": "exists"}` |
| `header` | 响应头断言 | `name`, `expected` | `{"type": "header", "name": "content-type", "expected": "application/json"}` |
| `responseTime` | 响应时间 | `maxMs` | `{"type": "responseTime", "maxMs": 500}` |

### AI 生成 plan.json 的原则

1. **精确断言优先**：能用 `assertText`/`assertStyle`/`assertApi` 的，不用 `aiAssert`
2. **aiAssert 用于视觉/语义判断**：布局是否正常、颜色是否协调、文案是否合适等主观判断
3. **API 测试独立**：接口逻辑测试放在 `apiTests`，不依赖 UI
4. **场景间独立**：每个 scenario 可独立执行，不依赖前一个场景的状态
5. **选择器优先级**：`[data-testid]` > `id` > `class` > 文本内容 > XPath
6. **选择器先实测后生成（强制）**：生成 plan.json 前必须 snapshotText() 拿真实页面结构，基于实测结构写选择器，含登录场景的真实选择器与协议勾选步骤（见「登录会话硬约束」）

### 自动生成 plan.json

分析需求文档后，自动生成 plan.json 并向用户确认：

```
═══════════════════════════════════════════════════════════════
【测试规划】生成 plan.json
═══════════════════════════════════════════════════════════════

根据需求分析，生成以下测试计划：

API 测试（2 个）：
  1. [P0] 用户登录接口 — POST /api/user/login
  2. [P0] 查询用户信息接口 — GET /api/user/info

UI 测试（3 个场景）：
  1. [P0] 用户登录
     → 导航到 /login
     → 输入用户名密码
     → 点击登录
     → 验证跳转 + 欢迎文本（assertText）
     → 验证布局正常（aiAssert）

  2. [P0] 数据列表展示
     → 导航到 /dashboard
     → 验证列表加载（assertCount ≥ 1）
     → 验证 API 返回数据与页面一致（assertDataConsistency）

  3. [P1] 表单提交
     → 导航到 /form
     → 填写表单
     → 提交
     → 验证 API 调用成功（assertApi）
     → 验证成功提示（assertText）

E2E 测试（1 个）：
  1. [P1] 完整下单流程 — 登录 → 浏览 → 加购 → 下单

plan.json 已生成：docs/requirements/{key}/plan.json
是否开始执行？
```

---

## Web 阶段三：测试执行

### 执行流程

```bash
cd skills/test/scripts

# 完整流程（推荐）：collect → AI 判断 → run
node web-run.cjs --plan ../../../docs/requirements/{key}/plan.json --out ../../../docs/requirements/{key}/result.json

# 或分步执行：
# 步骤 1：收集 aiAssert 上下文
node web-run.cjs --plan ../../../docs/requirements/{key}/plan.json --collect

# 步骤 2：AI 判断 aiAssert 上下文
# （读取 ai-contexts/*.json，写 ai-results.json）

# 步骤 3：使用 AI 结果执行
node web-run.cjs --plan ../../../docs/requirements/{key}/plan.json --run
```

### 执行器内部流程

web-run.cjs 内部自动生成 ego-browser heredoc 并执行：

```
1. 读取 plan.json
2. 生成 ego-browser heredoc 代码：
   - 创建任务空间：useOrCreateTaskSpace(taskSpaceName)
   - 打开初始页面：openOrReuseTab(baseUrl)（整个会话唯一一次）
   - 注入网络拦截器（monkey-patch fetch/XHR）
   - 执行 apiTests（直接 HTTP 请求，不走浏览器）
   - 执行 uiTests.scenarios：
     - 场景间导航：gotoAndWait(url)（同一 tab 内，不开新页签）
     - 执行 steps（按 action 类型生成对应代码）
     - aiAssert 点：
       - collect 模式：截图 + snapshotText → 写 ai-contexts/*.json → 输出 AI_INTERVENTION_NEEDED 标记
       - run 模式：读 ai-results.json → 使用预计算结果
     - 失败时：截图 + 收集诊断信息 → 输出 FAILURE 标记
   - 关闭任务空间：completeTaskSpace(taskId)
3. 执行 heredoc（spawn ego-browser）
4. 解析输出，生成 result.json
```

### heredoc 粒度约束（已自动化）

**⚠️ 重要**：web-run.cjs 内部已保证整个测试会话在一个 heredoc 内执行，AI 无需手动管理。

**约束内容**（web-run.cjs 自动遵守）：
1. 整个测试会话只有一个 `ego-browser nodejs <<'EOF'` 开头
2. 只有一个 `useOrCreateTaskSpace` 调用
3. 只有一个 `openOrReuseTab` 调用（在开头）
4. 所有后续场景用 `gotoAndWait` 导航
5. 只有一个 `completeTaskSpace` 调用（在结尾）

**为什么必须一个 heredoc**：
- 每个 `ego-browser nodejs <<'EOF'` 是独立进程，进程结束后 tab 引用和浏览上下文丢失
- 下一个 heredoc 无法感知上一个进程的 tab，`openOrReuseTab` 会新开标签页
- 新标签页没有之前的 cookie/session，**导致登录态丢失，页面跳转到登录页**

### AI 介入 aiAssert（完整流程模式）

当 web-run.cjs 输出 `AI_INTERVENTION_NEEDED` 标记时：

```
═══════════════════════════════════════════════════════════════
【AI 介入】aiAssert 判断点
═══════════════════════════════════════════════════════════════

场景：用户登录
步骤：aiAssert — 验证页面布局正常
上下文文件：ai-contexts/ai-assert-0-6.json

请读取上下文文件并判断：
- 截图路径：/tmp/cwork-test/screenshots/ai-assert-0-6.png
- DOM 快照：（见上下文文件）
- 判断标准："页面显示用户头像和欢迎信息，布局正常，无错位"

判断结果写入：ai-results.json
格式：{"scenarioIndex": 0, "stepIndex": 6, "pass": true, "reason": "页面布局正常，头像和欢迎信息均显示"}
```

**AI 操作步骤**：

```bash
# 1. 读取上下文
cat docs/requirements/{key}/ai-contexts/ai-assert-0-6.json

# 2. 查看截图
open /tmp/cwork-test/screenshots/ai-assert-0-6.png

# 3. 判断并写结果
cat > docs/requirements/{key}/ai-results.json <<'EOF'
{
  "0-6": {"pass": true, "reason": "页面布局正常，头像和欢迎信息均显示"}
}
EOF

# 4. 继续执行（web-run.cjs 会自动读取 ai-results.json）
```

### 执行输出格式

```
═══════════════════════════════════════════════════════════════
【测试执行·Web】场景 1/3：用户登录
═══════════════════════════════════════════════════════════════

步骤 1：导航到 /login
  → 结果：✓ 页面加载成功

步骤 2：等待网络空闲
  → 结果：✓ 网络空闲

步骤 3：填充 input[name='username'] ← "testuser"
  → 结果：✓ 输入成功

步骤 4：填充 input[name='password'] ← "password123"
  → 结果：✓ 输入成功

步骤 5：点击 button[type='submit']
  → 结果：✓ 点击成功

步骤 6：等待页面跳转
  → 结果：✓ 跳转成功

步骤 7：assertText — h1 包含 "欢迎"
  → 结果：✓ 文本匹配

步骤 8：assertVisible — .user-avatar
  → 结果：✓ 元素可见

步骤 9：aiAssert — 页面布局正常
  → [AI 介入] 上下文已收集，等待 AI 判断...
  → AI 判断结果：✓ 通过（页面布局正常）

场景 1 结果：✓ 通过（9/9 步骤）
```

### 失败处理

```
步骤 7：assertText — h1 包含 "欢迎"
  → 结果：✗ 失败
  → 实际文本："登录失败，请重试"
  → 截图：screenshots/场景1-步骤7-fail.png

  诊断：
  → 当前 URL：/login
  → 网络请求：POST /api/user/login 返回 401
  → 可能原因：密码错误

  处理：
  → 标记场景失败，继续执行下一个场景
  → 记录到 result.json
```

---

## Web 阶段四：失败诊断

### 前端诊断（自动收集）

步骤失败时，web-run.cjs 自动收集以下诊断信息：

```json
{
  "failedStep": {
    "scenario": "用户登录",
    "stepIndex": 7,
    "action": "assertText",
    "selector": "h1",
    "expected": "欢迎",
    "actual": "登录失败，请重试"
  },
  "pageInfo": {
    "url": "http://localhost:3000/login",
    "title": "登录页"
  },
  "screenshot": "screenshots/场景1-步骤7-fail.png",
  "networkRequests": [
    {
      "url": "/api/user/login",
      "method": "POST",
      "status": 401,
      "responseBody": {"error": "密码错误"}
    }
  ],
  "consoleErrors": []
}
```

### 前后端联合诊断（联动 cwork-log / cwork-config）

当失败诊断显示**后端接口异常**（4xx/5xx/超时）或**疑似配置问题**时，调用相关技能。

#### 自动联动机制

**失败诊断后自动检查是否需要联动，无需人工判断：**

```javascript
// 从 result.json 中提取失败步骤的网络请求
const failedRequests = result.scenarios
  .flatMap(s => s.steps)
  .filter(step => !step.ok)
  .flatMap(step => step.networkRequests || [])
  .filter(req => req.status >= 400 || req.failed);

if (failedRequests.length > 0) {
  // 自动联动 cwork-log
  console.log('【自动联动】检测到后端接口失败，调用 cwork-log');
  for (const req of failedRequests) {
    const traceId = req.responseHeaders?.['x-trace-id'] || req.responseHeaders?.['trace-id'];
    const url = req.url;
    const status = req.status;
    console.log(`  → 接口：${url}，状态：${status}，traceId：${traceId}`);
  }
  // 触发 cwork-log 查询（见下方调用示例）
} else {
  // 纯前端问题
  console.log('【诊断结论】纯前端问题，查前端代码');
}
```

#### 诊断决策树

```
测试步骤失败
  │
  ├─ 从 result.json 提取网络请求
  │
  ├─ 是否有后端接口失败（4xx/5xx/超时）？
  │    ├─ 否 → 纯前端问题：查截图 + 选择器 + 文本 → 修前端代码
  │    │
  │    └─ 是 → 调用 cwork-log 查后端：
  │            1. 从失败请求取 traceId（若有）/ 接口路径 / 时间戳 / 服务名
  │            2. cwork-log 自动域感知路由（覆盖 16 域）
  │            3. sls_query.sh logs <logstore> 搜日志
  │            4. arms_trace.sh 还原链路，找耗时点/异常点
  │            5. 判断：前端传参错？后端逻辑错？下游依赖超时？
  │
  └─ 是否疑似配置问题（开关未生效/阈值不对）？
       └─ 是 → 调用 cwork-config 查 Nacos 配置
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

# 2. 用 traceId 查链路（traceId 从前端失败请求的响应头或日志 trace 字段取）
bash scripts/arms_trace.sh "<pid>" "<traceId>" <ts_ms>

# 3. 或用接口关键字 + 时间窗查 SLS 日志
bash scripts/sls_query.sh <env> logs all "order/submit and ERROR" 100
```

> **traceId 来源**：result.json 的 `networkRequests[].responseHeaders['x-trace-id']`。拿到后直接喂 `arms_trace.sh` 还原完整链路。

#### 诊断结论输出

```
═══════════════════════════════════════════════════════════════
【失败诊断】场景 3·表单提交
═══════════════════════════════════════════════════════════════

前端证据（来自 result.json）：
- 接口 POST /api/order/submit 返回 500
- traceId: abc123def456
- 截图：screenshots/场景3-步骤3-fail.png

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
| `plan.json` | 测试计划（声明式） | 提交 |
| `result.json` | 测试结果（含截图路径） | 提交 |
| `ai-results.json` | AI 判断结果（aiAssert） | 提交 |
| `ai-contexts/` | aiAssert 上下文（截图+DOM） | 不提交 |
| `screenshots/` | 截图证据 | 提交 |

---

## 自动衔接

1. **写测试报告**：无论通过/失败，均生成 `test-report.md`（含截图证据）
2. **有失败场景**：询问用户"测试有失败场景，是否调起 cwork-bug 进行代码修复？"
   - 用户确认 → 进入 cwork-bug 修复 → 修复后重新执行失败场景 → 全部通过 → 进入 cwork-commit
   - 用户跳过 → 直接进入 cwork-commit
3. **全部通过**：询问用户是否调起 commit 技能进行代码提交，经用户确认后再进入 commit
