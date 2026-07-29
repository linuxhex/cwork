---
name: cwork-web-test
description: Web 页面自动化测试，ego-browser 驱动 + 三种工作流 + 截图验证（page-agent 备选）
---

# 页面自动化测试

## 概述

`cwork-web-test` 是 cwork 的测试技能，通过 ego-browser 驱动真实浏览器执行自动化测试。支持语义/视觉/CDP 三种工作流，可截图验证、精确断言、任务空间隔离，无需编写测试代码。

**失败时联动 `cwork-log`**：测试失败常源于后端接口（4xx/5xx/超时/空数据），光看前端截图定位不了根因。失败时先用 ego-browser 抓前端网络请求，再调用 `cwork-log` 查后端日志和链路，判断是前端 bug 还是后端 bug。

### 核心流程

1. **环境准备**：启动开发服务器，初始化 ego-browser 任务空间
2. **测试规划**：根据需求分析/实现计划，生成测试场景并标注工作流类型，自问自答质询测试设计
3. **测试执行**：按工作流类型驱动浏览器操作并验证结果
4. **结果报告**：记录测试结果（含截图证据），发现问题自动修复并重测，自问自答质询结果
5. **失败诊断**：前端诊断 + `cwork-log` 后端日志联合定位根因（见"前后端联合诊断"章节）

### 在 cwork 流程中的位置

```
cwork-init → cwork-implement → cwork-web-test → cwork-commit
                                    ↑
                              本技能介入
```

- cwork-implement 完成后自动衔接
- 测试通过后进入 cwork-commit

## 语言约束（强制）

- **所有对话必须使用中文**
- **所有测试报告必须使用中文**
- 仅在必要处保留英文：命令、路径、选择器、代码

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

## 中文步骤翻译表

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

## 内部阶段一：环境准备

### 步骤 1：启动开发服务器

```
═══════════════════════════════════════════════════════════════
【cwork-web-test】启动测试环境
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
const task = await useOrCreateTaskSpace('cwork-web-test-{需求key}')
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
const task = await useOrCreateTaskSpace('cwork-web-test-{需求key}')
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

## 内部阶段二：测试规划

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

### 自问自答质询（测试设计质询）

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

## 内部阶段三：测试执行

### ego-browser 执行模式

所有操作通过 `ego-browser nodejs <<'EOF' ... EOF` heredoc 执行。每个 heredoc 是一个独立的 Node.js 脚本，脚本间通过 `useOrCreateTaskSpace()` 复用同一任务空间。

#### 语义工作流示例（表单操作）

```bash
ego-browser nodejs <<'EOF'
const task = await useOrCreateTaskSpace('cwork-web-test-{需求key}')

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
const task = await useOrCreateTaskSpace('cwork-web-test-{需求key}')
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
const task = await useOrCreateTaskSpace('cwork-web-test-{需求key}')
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
const task = await useOrCreateTaskSpace('cwork-web-test-{需求key}')
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
const task = await takeOverTaskSpace('cwork-web-test-{需求key}')
const info = await pageInfo()
const snap = await snapshotText()
const success = info.url.includes('/dashboard') || snap.includes('欢迎')
cliLog('用户操作后验证：' + (success ? '✓ 通过' : '✗ 失败'))
EOF
```

#### 失败诊断

步骤失败时，收集前端诊断信息 + **抓取网络请求**（判断是否后端接口问题）：

```bash
ego-browser nodejs <<'EOF'
const task = await useOrCreateTaskSpace('cwork-web-test-{需求key}')

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

> **联动原则**：cwork-web-test 负责"发现问题并定位到前后端哪一侧"，cwork-log 负责"深挖后端根因"。前端代码问题直接修；后端问题把日志证据带回来，定位到具体文件:行号再修。

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

### 执行流程

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

### 执行输出格式

**ego-browser 模式：**

```
═══════════════════════════════════════════════════════════════
【测试执行】场景 1/3·语义：用户登录
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
【测试执行】场景 1/3：用户登录
═══════════════════════════════════════════════════════════════

步骤 1：打开 /login
  → page-agent: "导航到登录页面"
  → 结果：✓ 页面加载成功

步骤 2：输入用户名
  → page-agent: "在用户名输入框输入 testuser"
  → 结果：✓ 输入成功

场景 1 结果：✓ 通过（5/5 步骤）
```

### 失败处理

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

## 内部阶段四：结果报告

### 自问自答质询（结果质询）

对测试结果进行自我质询。全程自问自答，不涉及用户——自己扮演质疑者，自己回答，自己决策：

**质询规则：**
1. **逐层自问**：对每个测试结论，沿决策树追问"如果这个判断是错的呢？"
2. **每个自问带论据和自答**：提出质疑后，自己给出回答——"我怀疑判断有误，原因是 X，我决定去验证 Y"
3. **一次只质疑一个结论**：逐个结论质询和自答，不要一次性罗列所有疑点
4. **事实自己查**：能从截图/网络请求/代码验证的，直接查，不要空猜
5. **自己闭环**：每个质疑必须自己给出结论——是补充测试还是确认结果可靠，不留给用户判断

**自问自答示例：**
```
自问："全部通过了，但我的测试够深吗？"
自答："我只测了主路径，异常输入没覆盖。我补充空数据和超长字符串场景。"
→ 补充测试

自问："失败用例是 bug 还是测试本身的问题？"
自答："截图显示按钮确实没渲染，但网络请求返回 200。我查下组件代码确认是前端渲染问题。"
→ 查代码确认后记录到修复建议

自问："有没有跳过的'不好测'场景？"
自答："文件上传场景我跳过了，因为需要本地文件。这个场景重要，我用 blob 构造测试文件来补。"
→ 补充测试
```

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

### 报告格式

测试结果记录到 `docs/requirements/{requirement_key}/test-report.md`：

```markdown
# 测试报告

## 概要
- 测试时间：2026-07-24 15:30:00
- 测试环境：http://localhost:3000
- 驱动引擎：ego-browser
- 场景总数：3
- 通过：2
- 失败：1
- 通过率：66.7%

## 详细结果

### 场景 1·语义：用户登录 ✓
| 步骤 | 操作 | 结果 | 截图 |
|------|------|------|------|
| 1 | 打开 /login | ✓ | |
| 2 | 输入用户名 | ✓ | |
| 3 | 输入密码 | ✓ | |
| 4 | 点击登录 | ✓ | |
| 5 | 验证跳转 | ✓ | screenshots/场景1-最终.png |

### 场景 2·语义：数据列表展示 ✓
| 步骤 | 操作 | 结果 | 截图 |
|------|------|------|------|
| 1 | 打开 /dashboard | ✓ | |
| 2 | 验证列表加载 | ✓ | |
| 3 | 验证分页 | ✓ | |

### 场景 3·视觉：拖拽排序 ✗
| 步骤 | 操作 | 结果 | 截图 | 备注 |
|------|------|------|------|------|
| 1 | 打开 /kanban | ✓ | | |
| 2 | 拖拽卡片 | ✗ | screenshots/场景3-步骤2-fail.png | 拖拽目标位置无效 |
| 3 | 验证排序 | - | | 未执行 |

## 失败分析

### 场景 3：拖拽排序
- 失败步骤：步骤 2 — 拖拽卡片
- **前端诊断**：截图显示卡片回到原位；网络请求无异常（无后端接口失败）
- **后端诊断**（cwork-log）：未触发（无接口调用，纯前端拖拽问题）
- 定性：**纯前端问题**
- 可能原因：拖拽目标区域不在有效放置区内
- 建议：调整拖拽目标坐标或使用 DOM 拖拽 API

### 场景 4·语义：表单提交 ✗（如有接口失败）
- 失败步骤：步骤 3 — 提交表单
- **前端诊断**：POST /api/order/submit 返回 500，traceId=abc123
- **后端诊断**（cwork-log）：
  - 日志：OrderService.submit 抛 NullPointerException
  - 链路：最慢 span 在 charge-server 调用（2.3s）
  - 代码位置：OrderService.java:128
- 定性：**后端问题**（非前端 bug）
- 建议：修 OrderService.java:128 空指针处理

## 修复建议
1. [场景3·前端] 检查拖拽目标区域的 CSS 定位
2. [场景3·前端] 考虑使用 js() 调用 DOM 拖拽 API 替代鼠标拖拽
3. [场景4·后端] 修 OrderService.java:128 空指针，参考 cwork-log 链路证据
```

### 截图证据

截图保存到 `docs/requirements/{requirement_key}/screenshots/` 目录：

| 截图类型 | 命名规则 | 何时捕获 |
|---------|---------|---------|
| 步骤失败 | `{场景名}-步骤{N}-fail.png` | 步骤执行失败时（必须） |
| 场景最终 | `{场景名}-最终.png` | 场景所有步骤完成后（必须） |
| 步骤成功 | `{场景名}-步骤{N}-pass.png` | 步骤执行成功时（可选，默认不捕获） |

### 自动修复循环

测试失败时，先做前后端联合诊断，再尝试自动修复：

```
if 测试失败:
    1. 前端诊断（ego-browser: drainEvents 抓网络请求 + captureScreenshot + snapshotText + pageInfo）
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

- 环境未就绪（服务未启动），禁止执行测试
- 测试规划未经用户确认，禁止执行
- 所有 P0 场景必须通过才能进入 cwork-commit
- P1/P2 场景失败可记录但不阻塞提交
- 调用 cwork-log 查后端日志需阿里云密钥已配置（`scripts/config.local.sh` 或环境变量），未配置时跳过后端诊断，仅保留前端证据

## 与 cwork-implement 的衔接

cwork-implement 完成后：

1. 自动检测是否有前端工程改动
2. 有前端改动 → 自动进入 cwork-web-test
3. 无前端改动 → 跳过，直接进入 cwork-commit

```
═══════════════════════════════════════════════════════════════
【自动衔接】检测到前端改动，进入 cwork-web-test
═══════════════════════════════════════════════════════════════
```

## 独立使用

cwork-web-test 也可以独立使用（不依赖 cwork-implement）：

```
用户：帮我测试一下这个页面
→ 直接进入环境准备阶段
→ 询问测试重点或自动分析页面生成场景
```

## ego-browser 常用 helpers 速查

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
