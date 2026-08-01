---
name: cwork-test
description: 页面自动化测试，自动识别 Web/小程序项目，分别走 ego-browser 或 miniprogram-automator 链路
---

# 页面自动化测试

## 概述

`cwork-test` 是 cwork 的统一测试技能，**启动时自动识别项目类型**，然后走对应测试链路：

| 项目类型 | 识别条件 | 驱动引擎 | 测试链路 |
|---------|---------|---------|---------|
| **微信小程序** | 存在 `project.config.json` 且含 `appid` | miniprogram-automator（MCP） | 小程序链路 |
| **Web 应用** | 存在 `package.json`（无小程序配置） | ego-browser / page-agent | Web 链路 |

### 核心流程

1. **项目识别**：自动检测项目类型，选择对应测试链路
2. **环境准备**：按项目类型启动对应环境
3. **测试规划**：根据需求分析/实现计划，生成测试场景，自问自答质询测试设计
4. **测试执行**：按项目类型驱动对应引擎操作并验证结果
5. **结果报告**：记录测试结果（含截图证据），发现问题自动修复并重测，自问自答质询结果

### 在 cwork 流程中的位置

```
cwork-init → cwork-implement → cwork-test → cwork-commit
                                    ↑
                              本技能介入
```

- cwork-implement 完成后自动衔接
- 测试通过后进入 cwork-commit

## 语言约束（强制）

- **所有对话必须使用中文**
- **所有测试报告必须使用中文**
- 仅在必要处保留英文：命令、路径、选择器、代码

## 项目类型识别

启动时执行以下检测，**只走一条链路**：

```bash
# ① 优先检测小程序
if [ -f "project.config.json" ] && grep -q '"appid"' project.config.json; then
    PROJECT_TYPE="mini"
    echo "识别为微信小程序项目，走小程序测试链路"
else
    PROJECT_TYPE="web"
    echo "识别为 Web 项目，走 Web 测试链路"
fi
```

识别后输出：

```
═══════════════════════════════════════════════════════════════
【cwork-test】项目类型识别
═══════════════════════════════════════════════════════════════

→ 项目类型：{mini/web}
→ 驱动引擎：{miniprogram-automator / ego-browser}
→ 进入对应链路...
```

---

# Web 测试链路

> 以下内容仅在 PROJECT_TYPE=web 时执行

## 前置条件

### 必须满足

1. 存在前端工程（含 `package.json`）
2. 有可用的启动命令（`dev`/`start`/`serve`）
3. ego-browser 已安装 **或** page-agent 可用（备选）

### ego-browser 依赖（主引擎）

**ego-browser** 是本技能的核心驱动引擎，基于 Chromium 提供真实浏览器控制能力。

- **安装检测**：`command -v ego-browser`（通常位于 `~/.local/bin/ego-browser`）
- **CLI 用法**：`ego-browser nodejs <<'EOF' ... EOF` heredoc 方式
- **任务空间**：隔离浏览上下文，继承用户登录态，场景间互不干扰
- **三种工作流**：语义（snapshotText + refs）、视觉（截图 + 坐标）、DOM/CDP（js/cdp）
- **首次安装**：若 `ego-browser` 不可用，参考 ego-browser 技能的 `references/install.md` 安装 ego lite 浏览器

### page-agent 依赖（备选引擎）

当 ego-browser 不可用时，降级到 **page-agent** 驱动。

- **NPM 安装**：`npm install page-agent`，然后 `import { PageAgent } from 'page-agent'`
- **CDN 注入**：`<script src="https://cdn.jsdelivr.net/npm/page-agent@1.12.2/dist/iife/page-agent.demo.js"></script>`
- **模型配置**：PageAgent 需要 LLM API 配置（model / baseURL / apiKey）
- **语言设置**：`language: 'zh-CN'`

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
if command -v ego-browser &>/dev/null; then
    ENGINE="ego-browser"
else
    ENGINE="page-agent"
fi
```

## 引擎选择

### 检测逻辑

优先使用 ego-browser，不可用时回退到 page-agent：

| 引擎 | 检测条件 | 特点 |
|------|---------|------|
| **ego-browser**（主） | `command -v ego-browser` 成功 | 精确 API 调用、三种工作流、任务空间隔离、截图验证、继承登录态 |
| **page-agent**（备） | ego-browser 不可用 | 自然语言驱动、LLM 理解指令、无任务空间、无截图 |

### 引擎差异

| 能力 | ego-browser | page-agent |
|------|------------|------------|
| 操作方式 | 精确 API（click/fillInput/js） | 自然语言（agent.execute） |
| 页面观察 | snapshotText() 语义树 + captureScreenshot() 截图 | LLM 自行理解页面 |
| 断言方式 | js() 精确提取 + snapshotText 文本匹配 | agent.execute("检查...") |
| 截图验证 | ✅ captureScreenshot() | ❌ |
| 任务空间隔离 | ✅ 每个测试会话独立空间 | ❌ |
| 登录态继承 | ✅ 继承用户浏览器登录态 | ❌ 需脚本登录 |
| 用户接管 | ✅ handOffTaskSpace / takeOverTaskSpace | ❌ |
| DOM/CDP 操作 | ✅ js() / cdp() | ❌ |

## 中文步骤翻译表（Web）

agent 根据此表将中文测试步骤翻译为 ego-browser API 调用：

| 中文测试步骤模式 | ego-browser 操作序列 | 工作流 |
|---|---|---|
| 打开 {URL} | `openOrReuseTab(url, {wait:true})` | 语义 |
| 点击 {元素描述} | `snapshotText()` → 找到匹配的 ref → `click('@N')` | 语义 |
| 在 {输入框} 中输入 {文本} | `snapshotText()` → 找到匹配的 ref → `fillInput('@N', text)` | 语义 |
| 按下 {键名} | `pressKey(key)` | 语义 |
| 确认/验证 {预期文本} | `snapshotText()` → 检查输出是否包含预期文本 | 语义 |
| 验证页面显示 {视觉特征} | `captureScreenshot()` → 检查截图 | 视觉 |
| 等待页面加载完成 | `waitForLoad()` 或 `waitForNetworkIdle()` | 语义 |
| 等待 {元素} 出现 | `waitForElement(selector)` | 语义 |
| 滚动到页面底部 | `scrollToBottomUntil(() => true)` | 语义 |
| 上传文件 {路径} | `uploadFile(selector, path)` | 语义 |
| 需要用户操作（登录/验证码） | `handOffTaskSpace()` → 等待确认 → `takeOverTaskSpace()` | 控制交接 |
| 提取页面数据/断言 | `js(...)` IIFE | DOM/CDP |

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

### 步骤 2：初始化浏览器引擎

**ego-browser 模式（主）：**

```bash
ego-browser nodejs <<'EOF'
// 创建任务空间（整个测试会话复用）
const task = await useOrCreateTaskSpace('cwork-test-{需求key}')
cliLog('任务空间 ID：' + task.id)

// 打开初始页面
await openOrReuseTab('{URL}', { wait: true, timeout: 20 })

// 确认页面可访问
const snap = await snapshotText()
cliLog('页面加载状态：' + (snap.length > 0 ? '正常' : '异常'))
EOF
```

**page-agent 模式（备）：**

```javascript
import { PageAgent } from 'page-agent'
// 或 CDN 注入
const agent = new PageAgent({
    model: '当前使用的模型',
    baseURL: '模型 API 地址',
    apiKey: 'API Key',
    language: 'zh-CN',
})
```

### 步骤 3：确认页面可访问

**ego-browser：**

```bash
ego-browser nodejs <<'EOF'
const task = await useOrCreateTaskSpace('cwork-test-{需求key}')
const info = await pageInfo()
const snap = await snapshotText()
const hasError = snap.includes('Error') || snap.includes('报错') || info.w === 0
cliLog('页面状态：' + (hasError ? '异常' : '正常'))
cliLog('URL：' + info.url + ' 标题：' + info.title)
EOF
```

**page-agent：**

```
agent.execute("确认页面已正常加载，没有报错弹窗")
```

## Web 阶段二：测试规划

### 测试场景来源

从以下文档中提取测试场景：

| 来源 | 提取内容 |
|------|---------|
| `analysis.md` | 业务功能点、用户操作流程 |
| `plan.md` | 实现的功能清单、页面列表 |
| `changes.md` | 改动点、新增功能 |
| `design-system.md` / `DESIGN.md` | UI 预期表现 |

### 测试场景格式

```markdown
## 测试场景：{场景名称}

**前置条件**：{描述}
**工作流类型**：语义 / 视觉 / DOM-CDP
**测试步骤**：
1. 打开 {页面URL}
2. 点击 {元素描述}
3. 在 {输入框} 中输入 "{文本}"
4. 确认 {预期结果}

**预期结果**：{详细描述}
**优先级**：P0/P1/P2
```

### 工作流类型标注

每个测试场景需标注工作流类型，决定执行策略：

| 工作流 | 适用页面 | 核心操作 | 示例 |
|--------|---------|---------|------|
| **语义**（默认） | 表单、列表、按钮、表格等标准 DOM 页面 | `snapshotText()` + `@N` ref + `click`/`fillInput` | 登录、表单提交、列表翻页 |
| **视觉** | Canvas、拖拽、富文本编辑器、视觉密集页面 | `captureScreenshot()` + 坐标点击 + `typeText`/`pressKey` | 拖拽排序、画布操作、富文本编辑 |
| **DOM/CDP** | 数据提取、自定义断言、网络拦截 | `js()` IIFE / `cdp()` | 读取 localStorage、断言 DOM 状态、拦截网络 |

**工作流选择决策树：**

```
页面有标准 DOM 元素（表单/按钮/列表）？
  ├─ 是 → 页面有 Canvas 或富文本编辑器？
  │        ├─ 是 → 视觉工作流
  │        └─ 否 → 语义工作流（默认）
  └─ 否 → 需要提取数据或做自定义断言？
           ├─ 是 → DOM/CDP 工作流
           └─ 否 → 视觉工作流
```

> 工作流可在执行中切换：若语义工作流 `snapshotText()` 返回的 ref 不足以操作目标元素，自动切换到视觉工作流。

### 自动生成测试场景

分析需求文档后，自动生成测试场景并向用户确认：

```
═══════════════════════════════════════════════════════════════
【测试规划】生成测试场景
═══════════════════════════════════════════════════════════════

根据需求分析，生成以下测试场景：

场景 1（P0·语义）：用户登录
  → 打开 /login
  → 输入用户名和密码
  → 点击登录按钮
  → 验证跳转到首页

场景 2（P0·语义）：数据列表展示
  → 打开 /dashboard
  → 验证列表数据加载
  → 验证分页功能

场景 3（P1·视觉）：拖拽排序
  → 打开 /kanban
  → 拖拽卡片到新位置
  → 验证排序结果

场景 4（P1·DOM-CDP）：表单数据校验
  → 打开 /form
  → 填写并提交表单
  → 验证 localStorage 中数据正确

共 4 个场景，是否开始执行？
```

## Web 阶段三：测试执行

### ego-browser 执行模式

所有操作通过 `ego-browser nodejs <<'EOF' ... EOF` heredoc 执行。每个 heredoc 是一个独立的 Node.js 脚本，脚本间通过 `useOrCreateTaskSpace()` 复用同一任务空间。

#### 语义工作流示例（表单操作）

```bash
ego-browser nodejs <<'EOF'
const task = await useOrCreateTaskSpace('cwork-test-{需求key}')

// 打开页面
await openOrReuseTab('http://localhost:3000/login', { wait: true, timeout: 20 })

// 观察页面结构，获取 ref
const snap1 = await snapshotText()
cliLog('页面结构：' + snap1.substring(0, 300))

// 填写用户名（通过选择器或 ref）
await fillInput('input[name="username"]', 'testuser')

// 填写密码
await fillInput('input[name="password"]', 'password123')

// 点击登录按钮
await click('button[type="submit"]', { label: '点击登录' })

// 等待页面跳转
await waitForLoad()

// 验证结果
const info = await pageInfo()
const snap2 = await snapshotText()
const success = info.url.includes('/dashboard') || snap2.includes('欢迎')
cliLog('登录验证：' + (success ? '✓ 通过' : '✗ 失败'))
cliLog('当前URL：' + info.url)
EOF
```

#### 视觉工作流示例（拖拽/Canvas 操作）

```bash
ego-browser nodejs <<'EOF'
const task = await useOrCreateTaskSpace('cwork-test-{需求key}')
await openOrReuseTab('http://localhost:3000/kanban', { wait: true, timeout: 20 })

// 截图观察当前布局
const screenshot1 = await captureScreenshot()
cliLog('初始布局截图：' + screenshot1)

// 通过坐标执行拖拽
await dragMouse([[120, 200], [350, 200]], { label: '拖拽卡片' })

// 等待动画完成
await wait(1)

// 截图验证拖拽结果
const screenshot2 = await captureScreenshot()
cliLog('拖拽后截图：' + screenshot2)
EOF
```

#### DOM/CDP 工作流示例（数据提取与断言）

```bash
ego-browser nodejs <<'EOF'
const task = await useOrCreateTaskSpace('cwork-test-{需求key}')
await openOrReuseTab('http://localhost:3000/dashboard', { wait: true, timeout: 20 })

// 等待数据加载
await waitForNetworkIdle()

// 提取列表数据
const data = await js(String.raw`(() => {
  const rows = document.querySelectorAll('table tbody tr')
  return {
    rowCount: rows.length,
    firstRow: rows[0] ? rows[0].innerText : null,
    hasData: rows.length > 0
  }
})()`)
cliLog('列表数据：' + JSON.stringify(data))
cliLog('数据加载验证：' + (data.hasData ? '✓ 通过' : '✗ 失败'))

// 检查 localStorage
const storage = await js(String.raw`(() => {
  return JSON.stringify(Object.keys(localStorage).reduce((acc, k) => {
    acc[k] = localStorage.getItem(k); return acc
  }, {}))
})()`)
cliLog('localStorage：' + storage)
EOF
```

#### 控制交接示例（登录/验证码）

当测试遇到需要用户手动操作的场景（登录、验证码、二次确认等）：

```bash
ego-browser nodejs <<'EOF'
const task = await useOrCreateTaskSpace('cwork-test-{需求key}')
await openOrReuseTab('http://localhost:3000/login', { wait: true, timeout: 20 })

// 尝试自动操作
await fillInput('input[name="username"]', 'testuser')
await fillInput('input[name="password"]', 'password123')
await click('button[type="submit"]', { label: '点击登录' })
await wait(2)

// 检查是否出现验证码
const snap = await snapshotText()
if (snap.includes('验证码') || snap.includes('captcha')) {
  // 将控制权交给用户
  const result = await handOffTaskSpace(task.id)
  cliLog('已交接控制权，请用户完成验证码操作')
  cliLog('交接结果：' + JSON.stringify(result))
} else {
  const info = await pageInfo()
  cliLog('自动登录成功，URL：' + info.url)
}
EOF
```

用户完成操作后，用 `takeOverTaskSpace` 恢复：

```bash
ego-browser nodejs <<'EOF'
// 恢复控制权（注意：用 takeOverTaskSpace 而非 useOrCreateTaskSpace）
const task = await takeOverTaskSpace('cwork-test-{需求key}')
const info = await pageInfo()
const snap = await snapshotText()
const success = info.url.includes('/dashboard') || snap.includes('欢迎')
cliLog('用户操作后验证：' + (success ? '✓ 通过' : '✗ 失败'))
EOF
```

#### 失败诊断（Web）

步骤失败时，收集前端诊断信息 + **抓取网络请求**（判断是否后端接口问题）：

```bash
ego-browser nodejs <<'EOF'
const task = await useOrCreateTaskSpace('cwork-test-{需求key}')

// ① 先排空页面累积的网络事件（关键：抓接口调用结果）
const events = await drainEvents()
cliLog('--- 失败诊断（前端） ---')

// ② 页面基本信息
const info = await pageInfo()
const snap = await snapshotText()
const screenshot = await captureScreenshot()
cliLog('当前URL：' + info.url)
cliLog('页面标题：' + info.title)
cliLog('截图路径：' + screenshot)
cliLog('页面快照（前500字符）：' + snap.substring(0, 500))

// ③ 从事件中提取网络请求，标记失败的接口（非 2xx / 报错 / 超时）
const requests = (events || [])
  .filter(e => e.type === 'network' || e.request || e.response || e.url)
  .map(e => ({
    url: e.request?.url || e.url || '',
    method: e.request?.method || e.method || '',
    status: e.response?.status || e.status || '',
    failed: e.failed || e.errorText || (e.response?.status >= 400),
    resourceType: e.resourceType || e.type || ''
  }))
const failedReq = requests.filter(r => r.failed || r.status === '' || (r.status && r.status >= 400))
cliLog('网络请求总数：' + requests.length)
cliLog('失败/异常请求：' + JSON.stringify(failedReq, null, 2))

// ④ 提取可见交互元素（帮助诊断"元素未找到"问题）
const elements = await js(String.raw`(() => {
  return [...document.querySelectorAll('button, [role="button"], a, input, select, textarea')]
    .map(el => ({
      tag: el.tagName,
      text: el.innerText?.substring(0, 50) || '',
      type: el.type || '',
      name: el.name || '',
      placeholder: el.placeholder || ''
    }))
    .filter(e => e.text || e.name || e.placeholder)
})()`)
cliLog('可见交互元素：' + JSON.stringify(elements))

// ⑤ 提取页面 JS 报错（控制台 error）
const consoleErrors = await js(String.raw`(() => {
  return (window.__cworkErrors__ || []).slice(-10)
})()`)
cliLog('页面 JS 报错：' + JSON.stringify(consoleErrors))
EOF
```

> **关键判断**：若 `失败/异常请求` 列表非空（有接口 4xx/5xx/超时/跨域），或 `页面 JS 报错` 含网络相关异常，说明问题大概率在后端或接口层 → 进入下方"前后端联合诊断"调用 cwork-log 查后端日志。

### 前后端联合诊断（联动 cwork-log）

当失败诊断显示有**后端接口异常**时，单看前端无法定位根因，需调用 `cwork-log` 查后端日志和链路。

#### 诊断决策树

```
测试步骤失败
  │
  ├─ 抓取网络请求（drainEvents）
  │
  ├─ 是否有后端接口失败（4xx/5xx/超时）？
  │    ├─ 否 → 纯前端问题：查截图 + 可见元素 + JS 报错 → 修前端代码
  │    │
  │    └─ 是 → 调用 cwork-log 查后端：
  │            1. 从失败请求取 traceId（若有）/ 接口路径 / 时间戳
  │            2. sls_query.sh logs all 搜该接口/traceId 的日志
  │            3. arms_trace.sh 还原链路，找耗时点/异常点
  │            4. 判断：前端传参错？后端逻辑错？下游依赖超时？
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

> **traceId 来源**：ego-browser 抓到的失败请求响应头里常有 `x-trace-id` / `trace-id`；或在响应体 / 页面日志的 `trace` 字段。拿到后直接喂 `arms_trace.sh` 还原完整链路。

#### 诊断结论输出

```
═══════════════════════════════════════════════════════════════
【失败诊断】场景 3·表单提交
═══════════════════════════════════════════════════════════════

前端证据：
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

### page-agent 执行模式（备选）

当 ego-browser 不可用时，使用 page-agent 自然语言驱动：

```javascript
const agent = new PageAgent({
    model: '当前使用的模型',
    baseURL: '模型 API 地址',
    apiKey: 'API Key',
    language: 'zh-CN',
})

await agent.execute('点击登录按钮')
await agent.execute('在用户名输入框中输入 "testuser"')
await agent.execute('在密码输入框中输入 "password123"')
await agent.execute('点击提交按钮')
const result = await agent.execute('检查页面是否显示"欢迎"或用户头像')
```

### Web 执行流程

```
对于每个测试场景：
    1. 输出当前场景名称
    2. 在任务空间内打开新标签页：openOrReuseTab(url)
    3. 等待页面加载：waitForLoad() 或 waitForNetworkIdle()
    4. 根据工作流类型执行步骤：
       - 语义：snapshotText() → click('@N') / fillInput('@N', text)
       - 视觉：captureScreenshot() → click([x,y]) / typeText(text)
       - DOM/CDP：js(...) / cdp(...)
    5. 每步执行后验证结果
    6. 记录通过/失败
    7. 失败时：
       a. captureScreenshot() 截图
       b. drainEvents() 抓网络请求 + snapshotText() 收集前端诊断
       c. 若有后端接口失败 → 调用 cwork-log 查后端日志/链路（见"前后端联合诊断"）
       d. 综合前后端证据定位根因 → 尝试自动修复并重试（最多 3 次）
    8. 遇到"用户控制中"错误：
       a. handOffTaskSpace() 交接控制权
       b. 等待用户确认
       c. takeOverTaskSpace() 恢复控制权
    9. 关闭当前标签页，继续下一个场景

全部场景完成后：
    completeTaskSpace(task.id, { keep: false })
```

### Web 执行输出格式

**ego-browser 模式：**

```
═══════════════════════════════════════════════════════════════
【测试执行·Web】场景 1/3·语义：用户登录
═══════════════════════════════════════════════════════════════

步骤 1：打开 /login
  → ego-browser: openOrReuseTab('http://localhost:3000/login')
  → 结果：✓ 页面加载成功

步骤 2：输入用户名
  → ego-browser: fillInput('input[name="username"]', 'testuser')
  → 结果：✓ 输入成功

步骤 3：输入密码
  → ego-browser: fillInput('input[name="password"]', 'password123')
  → 结果：✓ 输入成功

步骤 4：点击登录
  → ego-browser: click('button[type="submit"]')
  → 结果：✓ 按钮点击成功

步骤 5：验证跳转
  → ego-browser: pageInfo() → url 包含 /dashboard
  → 结果：✓ 验证通过

场景 1 结果：✓ 通过（5/5 步骤）
```

**page-agent 模式：**

```
═══════════════════════════════════════════════════════════════
【测试执行·Web】场景 1/3：用户登录
═══════════════════════════════════════════════════════════════

步骤 1：打开 /login
  → page-agent: "导航到登录页面"
  → 结果：✓ 页面加载成功

步骤 2：输入用户名
  → page-agent: "在用户名输入框输入 testuser"
  → 结果：✓ 输入成功

场景 1 结果：✓ 通过（5/5 步骤）
```

### Web 失败处理

**ego-browser 模式：**

```
步骤 4：点击登录
  → ego-browser: click('button[type="submit"]')
  → 结果：✗ 元素未找到

  诊断：
  → 截图：screenshots/场景1-步骤4-fail.png
  → 当前 URL：/login
  → 可见按钮：["注册", "忘记密码"]
  → 可见输入框：[{"tag":"INPUT","name":"username"}, {"tag":"INPUT","name":"password"}]
  → 可能原因：提交按钮选择器不匹配

  处理：
  → 尝试替代选择器：click('button.login-btn')
  → 重试结果：✓ 找到并点击成功
```

**page-agent 模式：**

```
步骤 4：点击登录
  → page-agent: "点击登录按钮"
  → 结果：✗ 按钮未找到

  诊断：
  → 页面当前 URL：/login
  → 页面可见按钮：["注册", "忘记密码"]
  → 可能原因：登录按钮文字与预期不符

  处理：
  → 尝试替代指令："点击包含'登录'文字的按钮"
  → 重试结果：✓ 找到并点击成功
```

---

# 小程序测试链路

> 以下内容仅在 PROJECT_TYPE=mini 时执行

## 前置条件

### 必须满足

1. 微信开发者工具已安装（macOS: `/Applications/wechatwebdevtools.app`）
2. 项目有 `project.config.json`（含 appid）
3. MCP Server `weixin-devtools-mcp` 已配置

### 微信开发者工具 CLI

CLI 路径（macOS 默认）：

```
/Applications/wechatwebdevtools.app/Contents/MacOS/cli
```

核心命令：

| 命令 | 说明 |
|------|------|
| `cli open --project <path>` | 打开项目 |
| `cli auto --project <path> --port <port>` | 开启自动化端口 |
| `cli close --project <path>` | 关闭项目 |
| `cli quit` | 退出开发者工具 |

### MCP Server 配置

使用 `weixin-devtools-mcp`（基于 `miniprogram-automator`）。

**安装方式**：

```bash
npm install -g weixin-devtools-mcp
```

**Claude Code MCP 配置**（项目 `.claude/settings.json` 或全局配置）：

```json
{
  "mcpServers": {
    "weixin-devtools": {
      "command": "npx",
      "args": ["-y", "weixin-devtools-mcp", "--tools-profile=full"]
    }
  }
}
```

> 也可用 `npm install -g weixin-devtools-mcp` 后直接用 `weixin-devtools-mcp` 命令。

### 自动检测

```bash
CLI_PATH="/Applications/wechatwebdevtools.app/Contents/MacOS/cli"
PROJECT_PATH=""  # 从 project.config.json 所在目录推断

# 检测 CLI
if [ ! -f "$CLI_PATH" ]; then
    echo "❌ 微信开发者工具未安装"
    exit 1
fi

# 检测项目配置
if [ ! -f "project.config.json" ]; then
    echo "❌ 未找到 project.config.json"
    exit 1
fi

# 提取 appid
APPID=$(python3 -c "import json; print(json.load(open('project.config.json'))['appid'])")
```

## MCP 工具速查表

weixin-devtools-mcp 暴露的 31 个工具，按类别分组：

### 连接与生命周期（4 个）

| 工具 | 说明 |
|------|------|
| `connect_devtools` | 连接微信开发者工具（auto/launch/connect 三种策略） |
| `reconnect_devtools` | 重新连接 |
| `disconnect_devtools` | 断开连接（保留开发者工具运行） |
| `get_connection_status` | 获取连接状态 |

### 页面查询与等待（4 个）

| 工具 | 说明 |
|------|------|
| `get_current_page` | 获取当前页面信息 |
| `get_page_snapshot` | 获取页面快照（DOM 结构） |
| `query_selector` | CSS 选择器查询单个元素 |
| `wait_for` | 等待元素/条件出现 |

### 页面交互（4 个）

| 工具 | 说明 |
|------|------|
| `click` | 点击元素（tap） |
| `input_text` | 输入文本（input/textarea） |
| `get_value` | 获取元素值 |
| `set_form_control` | 设置表单控件值（picker/switch/slider） |

### 断言验证（3 个）

| 工具 | 说明 |
|------|------|
| `assert_text` | 断言元素文本内容 |
| `assert_attribute` | 断言元素属性值 |
| `assert_state` | 断言元素状态（可见/启用等） |

### 导航（4 个）

| 工具 | 说明 |
|------|------|
| `navigate_to` | navigateTo 跳转页面 |
| `navigate_back` | navigateBack 返回 |
| `switch_tab` | switchTab 切换 TabBar |
| `relaunch` | reLaunch 重启到页面 |

### 脚本执行（1 个）

| 工具 | 说明 |
|------|------|
| `evaluate_script` | 在小程序上下文执行 JS |

### Console 监听（2 个，需启用 console 类别）

| 工具 | 说明 |
|------|------|
| `list_console_messages` | 列出 Console 消息 |
| `get_console_message` | 获取单条 Console 消息详情 |

### 网络监控（4 个，需启用 network 类别）

| 工具 | 说明 |
|------|------|
| `list_network_requests` | 列出网络请求 |
| `get_network_request` | 获取单条请求详情 |
| `stop_network_monitoring` | 停止网络监控 |
| `clear_network_requests` | 清空请求记录 |

### 调试诊断（5 个，需启用 debug 类别）

| 工具 | 说明 |
|------|------|
| `screenshot` | 页面截图 |
| `diagnose_connection` | 诊断连接问题 |
| `check_environment` | 检查环境配置 |
| `debug_page_elements` | 调试页面元素 |
| `debug_connection_flow` | 调试连接流程 |

## miniprogram-automator 已知问题与绕行方案

### 导航 API 卡住问题（关键）

`miniprogram-automator` 的 `navigateTo`/`switchTab`/`reLaunch`/`navigateBack`/`screenshot` 在某些小程序项目上会**永久卡住**（Promise 不 resolve 也不 reject）。这是微信开发者工具 WebSocket 通信层的已知问题。

**绕行方案**：用 `miniProgram.evaluate()` 调用 `wx.*` API 间接导航，**所有导航操作必须走 evaluate**：

```javascript
// ❌ 直接调用（会卡住）
await miniProgram.navigateTo({ url: '/pages/station/index' });

// ✅ 用 evaluate 绕行（稳定）
await miniProgram.evaluate(() => { wx.navigateTo({ url: '/pages/station/index' }) });
await miniProgram.evaluate(() => { wx.switchTab({ url: '/pages/home/index/index' }) });
await miniProgram.evaluate(() => { wx.reLaunch({ url: '/pages/testExp/index' }) });
await miniProgram.evaluate(() => { wx.navigateBack() });
```

**实测结果**（2026-07-29）：

| API | 直接调用 | evaluate 绕行 |
|-----|---------|-------------|
| `launch` / `currentPage` | ✅ | — |
| `page.data` / `page.setData` | ✅ | — |
| `page.$` / `page.$$` | ✅ | — |
| `page.callMethod` | ✅ | — |
| `mp.evaluate` / `mp.callWxMethod` | ✅ | — |
| `navigateTo` / `switchTab` / `reLaunch` / `navigateBack` | ❌ 卡住 | ✅ |
| `screenshot` | ❌ 卡住 | ⚠️ 需调试 |

### 截图替代方案

`screenshot` 也可能卡住，替代方案：
1. 用 `page.$$` 获取页面元素结构，做结构化断言
2. 用 `page.data` 读取页面数据，做数据断言
3. 用开发者工具手动截图

### 超时保护（强制）

**所有 automator 调用必须加超时保护**，防止 Promise 永久挂起：

```javascript
function withTimeout(promise, ms, label) {
  return Promise.race([
    promise,
    new Promise((_, reject) => setTimeout(() => reject(new Error(label + ' 超时')), ms))
  ]);
}
```

### 连接方式

推荐用 `automator.launch`（自动启动 IDE + 开启自动化端口）：

```javascript
const miniProgram = await automator.launch({
  cliPath: '/Applications/wechatwebdevtools.app/Contents/MacOS/cli',
  projectPath: '/path/to/mini',
});
```

**launch 前必须关闭已有的 IDE 实例**，否则端口冲突。

> **连接生命周期**：整个测试会话只 `launch`/`connect` 一次，所有场景复用同一连接，最后才 `disconnect`。不要每测一个场景就重连。

## 中文步骤 → 实际调用映射表（小程序）

基于实测结果，agent 根据此表将中文测试步骤翻译为实际可用的调用：

| 中文测试步骤 | 实际调用 | 说明 |
|---|---|---|
| 打开页面 {path} | `mp.evaluate(() => wx.navigateTo({ url: '{path}' }))` | **必须走 evaluate** |
| 切换 Tab {url} | `mp.evaluate(() => wx.switchTab({ url: '{url}' }))` | **必须走 evaluate** |
| 重启到页面 {path} | `mp.evaluate(() => wx.reLaunch({ url: '{path}' }))` | **必须走 evaluate** |
| 返回上一页 | `mp.evaluate(() => wx.navigateBack())` | **必须走 evaluate** |
| 获取当前页面 | `mp.currentPage()` | 直接调用可用 |
| 读取页面 data | `page.data` | 直接调用可用 |
| 设置页面 data | `page.setData({ key: value })` | 直接调用可用 |
| 调用页面方法 | `page.callMethod('methodName', ...args)` | 直接调用可用 |
| 查找元素 | `page.$(selector)` / `page.$$(selector)` | 直接调用可用 |
| 点击元素 | `element.tap()` | 直接调用可用 |
| 输入文本 | `element.input(text)` | 直接调用可用 |
| 执行 JS | `mp.evaluate(() => { ... })` | 直接调用可用 |
| 调用 wx API | `mp.callWxMethod('methodName', ...args)` | 直接调用可用 |
| 截图 | `mp.screenshot({ path })` | ⚠️ 可能卡住，优先用 data/元素断言 |

## 小程序阶段一：环境准备

### 步骤 1：检测环境

```
═══════════════════════════════════════════════════════════════
【cwork-test·小程序】环境检测
═══════════════════════════════════════════════════════════════

→ 检测微信开发者工具 CLI：{CLI_PATH}
→ 检测项目配置：project.config.json（appid: {APPID}）
→ 检测 MCP Server：weixin-devtools-mcp
→ 项目路径：{PROJECT_PATH}
```

1. 检测微信开发者工具 CLI 是否存在
2. 读取 `project.config.json` 获取 appid
3. 确定项目路径（含 `project.config.json` 的目录）
4. 检测 MCP Server 是否可用（尝试调用 `get_connection_status`）

**环境不满足时**：
- CLI 不存在 → 提示安装微信开发者工具，终止
- project.config.json 不存在 → 提示指定项目路径，终止
- MCP Server 不可用 → 尝试自动安装 `npm install -g weixin-devtools-mcp`，仍失败则终止

### 步骤 2：打开项目并开启自动化端口

```bash
# 打开项目（如未打开）
"$CLI_PATH" open --project "$PROJECT_PATH"

# 开启自动化端口（默认 9420）
"$CLI_PATH" auto --project "$PROJECT_PATH" --port 9420
```

1. 调用 `cli open` 打开项目（如开发者工具已运行且已打开该项目，则跳过）
2. 等待项目加载完成（轮询检测，最多 30 秒）
3. 调用 `cli auto --port 9420` 开启自动化端口
4. 确认端口已开启

### 步骤 3：MCP 连接（整个测试会话只连一次）

通过 MCP 工具连接开发者工具，**整个测试会话只连接一次，所有场景复用同一连接**：

```
connect_devtools({
  projectPath: "{PROJECT_PATH}",
  strategy: "auto",
  verbose: true
})
```

连接策略说明：

| 策略 | 说明 |
|------|------|
| `auto` | 自动检测：先尝试连接已有实例，失败则启动新实例 |
| `launch` | 强制启动新实例 |
| `connect` | 仅连接已有实例（不启动） |

**推荐 `auto`**：大多数场景下最稳定。

> **关键原则**：连接一次，跑完所有场景，最后才断开。不要每测一个场景就重连/重启，这会极大拖慢测试速度且容易触发端口冲突。

### 步骤 4：确认小程序可操作

```
→ 获取当前页面：get_current_page()
→ 获取页面快照：get_page_snapshot()
→ 截图：screenshot({ path: "screenshots/初始状态.png" })
→ 页面加载状态：{正常/异常}
```

## 小程序阶段二：测试规划

### 测试用例来源

支持三种测试用例输入方式：

| 来源 | 说明 | 示例 |
|------|------|------|
| **外部传入** | 调用时直接传入测试场景列表 | `/cwork-test 场景1: 登录流程; 场景2: 充电下单` |
| **需求文档** | 从 `analysis.md` / `plan.md` / `changes.md` 提取 | implement 衔接时自动读取 |
| **自动生成** | 分析小程序页面结构自动生成 | 独立使用时扫描 app.json 页面列表 |

### 外部测试用例格式

```markdown
## 测试场景：{场景名称}

**前置条件**：{描述，如"用户已登录"}
**页面路径**：{小程序页面路径，如 pages/index/index}
**测试步骤**：
1. 打开 {页面路径}
2. 点击 {元素描述}
3. 在 {输入框} 中输入 "{文本}"
4. 验证 {预期结果}

**预期结果**：{详细描述}
**优先级**：P0/P1/P2
```

### 自动生成测试场景

当没有外部测试用例时，从以下信息自动生成：

1. **app.json** — 提取所有页面路径（`pages` + `subpackages`）
2. **需求文档** — 从 `analysis.md` / `plan.md` 提取功能点
3. **代码改动** — 从 `changes.md` 提取改动页面

生成后向用户确认：

```
═══════════════════════════════════════════════════════════════
【测试规划·小程序】生成测试场景
═══════════════════════════════════════════════════════════════

根据需求分析，生成以下测试场景：

场景 1（P0）：用户登录
  → 打开 pages/login/login
  → 输入手机号和验证码
  → 点击登录按钮
  → 验证跳转到首页

场景 2（P0）：扫码充电
  → 打开 pages/scan/scan
  → 点击扫码按钮
  → 验证扫码结果页面

场景 3（P1）：个人中心
  → 打开 pages/personalCenter/personalCenter
  → 验证用户信息展示
  → 点击充值入口
  → 验证跳转到充值页

共 3 个场景，是否开始执行？
```

## 小程序阶段三：测试执行

### 连接生命周期原则（关键）

**整个测试会话：连接一次 → 跑完所有场景 → 最后断开。**

```
❌ 错误做法：每个场景都 disconnect → reconnect（慢 + 易端口冲突）
✅ 正确做法：connect_devtools 一次 → 场景1 → 场景2 → ... → 场景N → disconnect_devtools
```

场景间切换用 `mp.evaluate(() => wx.reLaunch(...))` 重置页面栈即可，**不需要重新连接**。

### 执行流程

```
对于每个测试场景：
    1. 输出当前场景名称
    2. 导航到目标页面：mp.evaluate(() => wx.navigateTo({ url: '{path}' })) 或 mp.evaluate(() => wx.reLaunch({ url: '{path}' }))
    3. 等待页面加载：wait_for({ selector: "page", timeout: 5000 })
    4. 根据测试步骤执行操作：
       - 点击：query_selector → click
       - 输入：query_selector → input_text
       - 选择：query_selector → set_form_control
       - 验证文本：assert_text
       - 验证属性：assert_attribute
       - 验证状态：assert_state
       - 等待：wait_for
       - 截图：screenshot（注意：可能卡住，优先用 data/元素断言）
       - 执行 JS：evaluate_script
    5. 每步执行后验证结果
    6. 记录通过/失败
    7. 失败时：
       a. get_page_snapshot 获取页面快照
       b. list_network_requests 检查网络请求
       c. list_console_messages 检查 Console 错误
       d. 诊断根因 → 尝试自动修复并重试（最多 3 次）
    8. 场景间用 mp.evaluate(() => wx.reLaunch(...)) 重置页面栈（不要重连 MCP）

全部场景完成后：
    disconnect_devtools() 断开连接
```

### 执行输出格式

```
═══════════════════════════════════════════════════════════════
【测试执行·小程序】场景 1/3：用户登录
═══════════════════════════════════════════════════════════════

步骤 1：打开 pages/login/login
  → navigate_to({ path: "pages/login/login" })
  → 结果：✓ 页面跳转成功

步骤 2：输入手机号
  → query_selector({ selector: "input[placeholder*='手机号']" })
  → input_text({ uid: "input[placeholder*='手机号']", text: "13800138000" })
  → 结果：✓ 输入成功

步骤 3：点击获取验证码
  → query_selector({ selector: "button.get-code" })
  → click({ uid: "button.get-code" })
  → 结果：✓ 点击成功

步骤 4：验证跳转到首页
  → get_current_page()
  → 当前页面：pages/index/index
  → assert_text({ uid: ".welcome", textContains: "欢迎" })
  → 结果：✓ 验证通过

场景 1 结果：✓ 通过（4/4 步骤）
```

### 小程序失败处理

```
步骤 3：点击获取验证码
  → click({ uid: "button.get-code" })
  → 结果：✗ 元素未找到

  诊断：
  → 页面快照：get_page_snapshot()
  → 页面 data：evaluate_script({ script: "JSON.stringify(__page__.data)" })
  → 网络请求：list_network_requests()
  → Console 错误：list_console_messages()
  → 可见元素：debug_page_elements()
  → 可能原因：按钮选择器不匹配或按钮未渲染

  处理：
  → 尝试替代选择器：query_selector({ selector: "button:contains('验证码')" })
  → 重试结果：✓ 找到并点击成功
```

> **注意**：失败诊断优先用 `get_page_snapshot()` + `evaluate_script` 读取 data/元素，避免 `screenshot` 卡住。

### 小程序失败诊断

步骤失败时，收集全面诊断信息：

1. **页面快照**：`get_page_snapshot()` — 获取当前 DOM 结构（优先，不卡）
2. **页面 data**：`evaluate_script({ script: "JSON.stringify(__page__.data)" })` — 读取页面数据
3. **网络请求**：`list_network_requests()` — 检查是否有接口失败（4xx/5xx/超时）
4. **Console 错误**：`list_console_messages()` — 检查 JS 报错
5. **元素调试**：`debug_page_elements()` — 列出可见交互元素
6. **连接诊断**：`diagnose_connection()` — 仅在怀疑连接断开时调用

**诊断决策树**：

```
测试步骤失败
  │
  ├─ 收集诊断信息（截图 + 快照 + 网络请求 + Console + 元素列表）
  │
  ├─ 是否有后端接口失败（4xx/5xx/超时）？
  │    ├─ 否 → 纯前端问题：查截图 + 可见元素 + Console 错误 → 修前端代码
  │    │
  │    └─ 是 → 后端接口问题：
  │            1. 从失败请求取接口路径 / 状态码 / 响应体
  │            2. 判断：前端传参错？后端逻辑错？网络超时？
  │            3. 前端传参错 → 修前端代码
  │            4. 后端逻辑错 → 记录到报告（含接口证据），等待人工处理
```

### 小程序特有注意事项

#### 页面栈管理

小程序页面栈最多 10 层，测试中需注意：
- 连续 `navigate_to` 不超过 10 次
- 超过时用 `relaunch` 重置页面栈
- 测试场景间用 `relaunch` 清理页面栈

#### 分包页面

分包页面首次加载可能较慢：
- `wait_for` 的 timeout 适当增大（分包建议 10 秒）
- 首次进入分包页面时多等 1-2 秒

#### 登录态

开发者工具中的登录态与真机不同：
- 需手动扫码登录一次（开发者工具会缓存登录态）
- 测试需要登录态的场景前，先检查登录状态
- 未登录时提示用户手动扫码

#### 自定义组件

小程序自定义组件的查询：
- 使用 `component-name` 作为选择器（如 `login-dialog`）
- 组件内部元素用后代选择器（如 `login-dialog .btn-confirm`）
- 组件 data 通过 `evaluate_script` 读取

#### TabBar 页面

TabBar 页面切换必须用 `switch_tab`，不能用 `navigate_to`：
- `switch_tab({ tabName: "home" })` — 正确
- `navigate_to({ path: "pages/index/index" })` — 错误（TabBar 页面不支持 navigateTo）

### evaluate_script 高级用法

weixin-devtools-mcp 未直接暴露部分 miniprogram-automator 能力，但均可通过 `evaluate_script` 间接实现：

#### 读取页面 data

```
evaluate_script({
  script: "JSON.stringify(__page__.data)"
})
```

#### 设置页面 data

```
evaluate_script({
  script: "__page__.setData({ key: value })"
})
```

#### 调用页面方法

```
evaluate_script({
  script: "__page__.onPullDownRefresh()"
})
```

#### 调用组件方法

```
evaluate_script({
  script: "const comp = __page__.selectComponent('#myComponent'); comp && comp.myMethod()"
})
```

#### 调用 wx API

```
evaluate_script({
  script: "wx.getSystemInfoSync()"
})
```

适用于：
- `wx.getSystemInfoSync()` — 获取系统信息
- `wx.getStorageSync('key')` — 读取本地缓存
- `wx.setStorageSync('key', value)` — 写入本地缓存
- `wx.getNetworkType()` — 获取网络类型

#### mock wx API（支付/授权等）

```
evaluate_script({
  script: `
    const original = wx.requestPayment;
    wx.requestPayment = function(options) {
      options.success && options.success({ errMsg: 'requestPayment:ok' });
    };
    // 恢复：wx.requestPayment = original;
    'mocked'
  `
})
```

### 项目常见测试场景模板

以下是充电小程序（YKC）常见测试场景模板，agent 按需选用：

#### P0 核心流程

| 场景 | 页面路径 | 关键步骤 | 断言 |
|------|---------|---------|------|
| **手机号登录** | pages/login/login | 输入手机号 → 获取验证码 → 输入验证码 → 点击登录 | 跳转到首页 + 用户信息展示 |
| **微信一键登录** | pages/login/login | 点击微信登录按钮 → 授权 | 跳转到首页 + 用户信息展示 |
| **扫码充电** | pages/testExp/index | 点击扫码 → 扫码结果页 → 选择充电桩 → 确认下单 | 订单创建成功 + 跳转充电页 |
| **充电中状态** | pages/charge/charge | 进入充电中页面 | 充电功率/时长/费用实时更新 |
| **结束充电** | pages/charge/charge | 点击结束充电 → 确认 | 订单完成 + 费用展示 + 跳转订单详情 |
| **支付订单** | pages/order/pay | 选择支付方式 → 确认支付 | 支付成功 + 订单状态更新 |

#### P1 重要功能

| 场景 | 页面路径 | 关键步骤 | 断言 |
|------|---------|---------|------|
| **首页展示** | pages/home/index/index | 打开首页 | 轮播图展示 + 推荐站点列表 + TabBar 可见 |
| **站点列表** | pages/home/citys/citys | 打开城市/站点列表 | 站点卡片展示 + 距离排序 + 下拉刷新 |
| **订单列表** | pages/order/index/index | 打开订单列表 | 订单卡片展示 + 状态筛选 + 上拉加载更多 |
| **订单详情** | pages/order/detail/detail | 进入订单详情 | 订单信息完整 + 充电明细 + 支付信息 |
| **个人中心** | pages/user/index/index | 打开个人中心 | 用户头像/昵称 + 余额 + 菜单列表 |
| **钱包/余额** | pages/user/wallet/index | 打开钱包 | 余额展示 + 充值入口 + 消费记录入口 |
| **充值流程** | pages/user/recharge/index | 选择金额 → 确认充值 → 支付 | 余额更新 + 充值记录生成 |

#### P2 辅助功能

| 场景 | 页面路径 | 关键步骤 | 断言 |
|------|---------|---------|------|
| **设置页** | pages/user/settings/index | 打开设置 | 各设置项展示 + 退出登录按钮可见 |
| **消息列表** | pages/message/index | 打开消息 | 消息列表展示 + 未读标记 |
| **优惠券** | pages/user/coupon/index | 打开优惠券 | 优惠券列表 + 状态筛选 |
| **充电记录** | pages/user/card/consume-records/index | 打开消费记录 | 记录列表 + 时间筛选 |

#### 小程序特有测试场景

| 场景 | 测试内容 | 实现方式 |
|------|---------|---------|
| **页面生命周期** | onLoad 参数接收、onShow 刷新、onHide 暂停、onUnload 清理 | `evaluate_script` 检查 data 状态 |
| **页面参数传递** | navigateTo 带 query 参数，目标页面 onLoad 接收 | `navigate_to({ path: "pages/xxx?param=val" })` |
| **分包加载** | 首次进入分包页面的加载耗时和正确性 | `navigate_to` + `wait_for({ timeout: 10000 })` |
| **TabBar 切换** | 5 个 Tab 页面间切换，页面状态保持 | `switch_tab` + `assert_text` |
| **页面栈管理** | 连续 navigateTo 不超 10 层，navigateBack 正确回退 | 循环 `navigate_to` + `navigate_back` |
| **下拉刷新** | 列表页下拉触发刷新，数据更新 | `evaluate_script` 触发 `onPullDownRefresh` |
| **登录态依赖** | 未登录时访问需登录页面，自动跳转登录页 | `relaunch` + `evaluate_script` 清除登录态 + `navigate_to` |
| **网络异常处理** | 接口超时/5xx 时页面展示错误提示 | 开发者工具 Network 面板模拟 + `assert_text` |
| **轮播图交互** | Swiper 自动播放 + 手动滑动 + 点击跳转 | `evaluate_script` 调用 `swiper.setCurrent()` |
| **长列表滚动** | ScrollView / 列表页上拉加载更多 | `evaluate_script` 设置 `scrollTop` + `wait_for` 新数据 |
| **web-view 页面** | 嵌套 H5 页面加载和交互 | `navigate_to` + `screenshot` 截图验证 |

---

# 通用阶段（Web 和小程序共用）

## 自问自答质询（测试设计质询）

对测试设计进行自我质询，确保覆盖面足够。全程自问自答，不涉及用户——自己扮演质疑者，自己回答，自己决策是否补充：

**质询规则：**
1. **逐层自问**：对每个测试场景，沿决策树追问"如果这里有 bug，我的场景能抓到吗？"
2. **每个自问带论据和自答**：提出质疑后，自己给出回答——"我怀疑覆盖不足，原因是 X，我决定补充场景 Y"
3. **一次只质疑一个场景**：逐个场景质询和自答，不要一次性罗列所有疑点
4. **事实自己查**：能从代码/需求文档确认的，直接查，不要空猜
5. **自己闭环**：每个质疑必须自己给出结论——是补充场景还是确认可靠，不留给用户判断

**自问自答示例：**
```
自问："导出功能只测了 CSV，Excel 路径呢？"
自答："代码里有两条导出路径，Excel 路径未覆盖。我补充 Excel 导出场景。"
→ 补充场景

自问："大数据量导出只测了 1000 行，边界是多少？"
自答："我查下数据库，最大表 50 万行。只测 1000 行不够，补充 10 万行场景。"
→ 补充场景

自问："网络超时场景测了吗？"
自答："这是前端测试，导出是同步下载，网络超时不适用。确认可靠。"
→ 记录：经自问验证，场景可靠
```

**自问模板：**
1. "最可能出问题的场景我测了吗？"
2. "有没有只测了快乐路径，忽略了异常路径？"
3. "测试数据是否覆盖了边界情况？"

**自问自答循环：**
```
for each 测试场景:
    自问：这个场景能发现真正的 bug 吗？如果这里有 bug，我的场景能抓到吗？
    自答：我怀疑/确认...，原因是...
    如果发现覆盖不足：
        自己决定补充测试场景，不问用户
    如果确认可靠：
        记录：经自问验证，测试设计可靠
```

**覆盖面检查清单：**
- [ ] 主路径（快乐路径）覆盖
- [ ] 异常路径覆盖（错误输入、网络异常等）
- [ ] 边界条件覆盖（空数据、大数据量、特殊字符）
- [ ] 交互状态覆盖（加载中、禁用状态、权限限制）

## 自问自答质询（结果质询）

对测试结果进行自我质询。全程自问自答，不涉及用户——自己扮演质疑者，自己回答，自己决策：

**质询规则：**
1. **逐层自问**：对每个测试结论，沿决策树追问"如果这个判断是错的呢？"
2. **每个自问带论据和自答**：提出质疑后，自己给出回答——"我怀疑判断有误，原因是 X，我决定去验证 Y"
3. **一次只质疑一个结论**：逐个结论质询和自答，不要一次性罗列所有疑点
4. **事实自己查**：能从截图/网络请求/代码验证的，直接查，不要空猜
5. **自己闭环**：每个质疑必须自己给出结论——是补充测试还是确认结果可靠，不留给用户判断

**自问模板：**
1. "全部通过是真的没问题，还是我的测试太浅了？"
2. "失败的用例是 bug 还是测试本身的问题？我确信吗？"
3. "有没有我刻意跳过的'不好测'的场景？"

**自问自答循环：**
```
if 全部通过:
    自问：我是否因为测试通过就放松了警惕？如果这里有隐藏 bug，最可能藏在哪？
    自答：我怀疑/确认...，原因是...
    如果发现遗漏：自己决定补充测试，不问用户
elif 有失败:
    自问：失败是真的 bug 还是测试环境/用例问题？如果判断错了呢？
    自答：从截图/网络请求/代码看，原因是...
    如果确认是 bug：记录到修复建议
    如果是测试问题：自己调整测试用例
```

## 阶段四：结果报告

### 报告格式

测试结果记录到 `docs/requirements/{requirement_key}/test-report.md`：

```markdown
# 测试报告

## 概要
- 测试时间：{YYYY-MM-DD HH:mm:ss}
- 项目类型：{Web/小程序}
- 测试环境：{http://localhost:3000 / 微信开发者工具模拟器}
- 驱动引擎：{ego-browser / page-agent / miniprogram-automator}
- 场景总数：{N}
- 通过：{M}
- 失败：{K}
- 通过率：{M/N * 100}%

## 详细结果

### 场景 1：用户登录 ✓
| 步骤 | 操作 | 结果 | 截图 |
|------|------|------|------|
| 1 | 打开 /login | ✓ | |
| 2 | 输入用户名 | ✓ | |
| 3 | 输入密码 | ✓ | |
| 4 | 点击登录 | ✓ | |
| 5 | 验证跳转 | ✓ | screenshots/场景1-最终.png |

### 场景 2：数据列表展示 ✗
| 步骤 | 操作 | 结果 | 截图 | 备注 |
|------|------|------|------|------|
| 1 | 打开 /dashboard | ✓ | | |
| 2 | 验证列表加载 | ✗ | screenshots/场景2-步骤2-fail.png | 接口返回 500 |

## 失败分析

### 场景 2：数据列表展示
- 失败步骤：步骤 2 — 验证列表加载
- **前端诊断**：接口 GET /api/dashboard 返回 500，traceId=abc123
- **后端诊断**（cwork-log）：
  - 日志：DashboardService.query 抛 NullPointerException
  - 代码位置：DashboardService.java:45
- 定性：**后端问题**（非前端 bug）
- 建议：修 DashboardService.java:45 空指针处理

## 修复建议
1. [场景2·后端] 修 DashboardService.java:45 空指针，参考 cwork-log 链路证据
```

### 截图证据

截图保存到 `docs/requirements/{requirement_key}/screenshots/` 目录：

| 截图类型 | 命名规则 | 何时捕获 |
|---------|---------|---------|
| 步骤失败 | `{场景名}-步骤{N}-fail.png` | 步骤执行失败时（必须） |
| 场景最终 | `{场景名}-最终.png` | 场景所有步骤完成后（必须） |
| 步骤成功 | `{场景名}-步骤{N}-pass.png` | 步骤执行成功时（可选，默认不捕获） |

### 自动修复循环

测试失败时，先做诊断，再尝试自动修复：

```
if 测试失败:
    1. 诊断（Web: drainEvents + captureScreenshot + snapshotText + pageInfo; 小程序: get_page_snapshot + evaluate_script 读 data + list_network_requests + list_console_messages）
    2. 若有后端接口失败 → 调用 cwork-log 查后端日志/链路，拿到异常堆栈 + 文件:行号
    3. 综合前后端证据定位根因：
       - 纯前端：修前端代码
       - 后端问题：按 cwork-log 指出的文件:行号修后端代码
    4. 等待热更新
    5. 重新执行失败的场景
    6. 最多重试 3 次
    7. 仍失败则记录到报告（含前端截图 + 后端日志证据），等待人工处理
```

## 阶段切换通知

```
═══════════════════════════════════════════════════════════════
【阶段切换】进入阶段 N/4：{阶段名称}
═══════════════════════════════════════════════════════════════
```

四个阶段：
1. 阶段 1/4：环境准备
2. 阶段 2/4：测试规划
3. 阶段 3/4：测试执行
4. 阶段 4/4：结果报告

## HARD GATE

- **Web**：环境未就绪（服务未启动），禁止执行测试
- **小程序**：微信开发者工具未安装 / project.config.json 不存在 / MCP Server 不可用，禁止执行
- 测试规划未经用户确认，禁止执行
- 所有 P0 场景必须通过才能进入 cwork-commit
- P1/P2 场景失败可记录但不阻塞提交
- 调用 cwork-log 查后端日志需阿里云密钥已配置（`scripts/.config.local.sh` 或环境变量），未配置时跳过后端诊断，仅保留前端证据

## 与 cwork-implement 的衔接

cwork-implement 完成后：

1. 自动检测项目类型（小程序 or Web）
2. 有前端改动 → 自动进入 cwork-test（内部按项目类型走对应链路）
3. 无前端改动 → 跳过，直接进入 cwork-commit

```
═══════════════════════════════════════════════════════════════
【自动衔接】检测到前端改动，进入 cwork-test（{项目类型}）
═══════════════════════════════════════════════════════════════
```

## 独立使用

cwork-test 也可以独立使用（不依赖 cwork-implement）：

```
用户：帮我测试一下这个页面
→ 自动识别项目类型
→ 直接进入环境准备阶段
→ 询问测试重点或自动分析页面生成场景
```

## ego-browser 常用 helpers 速查（Web 链路）

| 分类 | Helper | 说明 |
|------|--------|------|
| **任务空间** | `useOrCreateTaskSpace(name)` | 创建或复用任务空间 |
| | `completeTaskSpace(id, {keep})` | 完成并关闭任务空间 |
| | `handOffTaskSpace(id)` | 将控制权交给用户 |
| | `takeOverTaskSpace(id)` | 从用户恢复控制权 |
| **导航** | `openOrReuseTab(url, {wait})` | 打开或复用标签页 |
| | `gotoAndWait(url)` | 当前标签页内导航 |
| | `closeTab(target)` | 关闭标签页 |
| | `pageInfo()` | 获取 URL/标题/视口信息 |
| **观察** | `snapshotText()` | 获取页面语义树（含 ref 标注） |
| | `captureScreenshot()` | 截图并返回路径 |
| **操作** | `click(target, {label})` | 点击元素或坐标 |
| | `fillInput(target, text)` | 填充输入框 |
| | `typeText(text)` | 逐字输入文本 |
| | `pressKey(key)` | 按键 |
| | `hover(target)` | 悬停 |
| | `dragMouse([from, to])` | 拖拽 |
| | `uploadFile(selector, path)` | 上传文件 |
| **等待** | `wait(seconds)` | 等待指定秒数 |
| | `waitForLoad()` | 等待页面加载 |
| | `waitForElement(selector)` | 等待元素出现 |
| | `waitForNetworkIdle()` | 等待网络空闲 |
| **滚动** | `scrollBy(px)` | 滚动指定像素 |
| | `scrollToBottomUntil(fn)` | 滚动到底部直到条件满足 |
| **执行** | `js(expr)` | 在浏览器中执行 JS |
| | `cdp(method, params)` | 调用 Chrome DevTools Protocol |
| **输出** | `cliLog(value)` | 输出到终端（heredoc 内唯一输出方式） |

> **注意**：`@N` ref 仅对最近一次 `snapshotText()` 有效。跨步骤引用元素时，使用 `loc=...` 值或 CSS 选择器。

## 输出文件

| 文件 | 说明 | 提交 |
|------|------|------|
| test-report.md | 测试报告 | 提交 |
| test-scenarios.md | 测试场景定义（可选） | 提交 |
| screenshots/ | 截图证据目录 | 提交 |

## 自动衔接

1. **写测试报告**：无论通过/失败，均生成 `test-report.md`（含截图证据）
2. **有失败场景**：询问用户"测试有失败场景，是否调起 cwork-bug 进行代码修复？"
   - 用户确认 → 进入 cwork-bug 修复 → 修复后重新执行失败场景 → 全部通过 → 进入 cwork-commit
   - 用户跳过 → 直接进入 cwork-commit
3. **全部通过**：询问用户是否调起 commit 技能进行代码提交，经用户确认后再进入 commit

---

## 使用记录与闭环

使用本 skill 遇到的不顺手 / 报错 / 结果不准 / 可省步骤，记一笔到 `../USAGE_NOTES.md`「未分析」区（格式 `[YYYY-MM-DD] [test] 现象 | 建议改法`），能当场修的直接修。**每天最多分析一次**，据此优化各 skill——流程见 `../USAGE_NOTES.md` 顶部。
