> **按需加载**：本文件由 test SKILL.md 在 PROJECT_TYPE=web 时 Read 加载，不随 SKILL.md 一起全量加载。

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
| 打开 {URL} | 首个场景：`openOrReuseTab(url, {wait:true})`；后续场景：`gotoAndWait(url)` | 语义 |
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

> ⚠️ 环境准备 + 全部测试场景写在**同一个 heredoc** 里执行（见下方"heredoc 粒度硬约束"），此处仅为说明拆解。

```bash
ego-browser nodejs <<'EOF'
// 创建任务空间（整个测试会话复用）
const task = await useOrCreateTaskSpace('cwork-test-{需求key}')
cliLog('任务空间 ID：' + task.id)

// 打开初始页面（整个会话唯一一次 openOrReuseTab）
await openOrReuseTab('{URL}', { wait: true, timeout: 20 })

// 确认页面可访问
const snap = await snapshotText()
cliLog('页面加载状态：' + (snap.length > 0 ? '正常' : '异常'))

// ...后续所有测试场景在此 heredoc 内继续，场景间用 gotoAndWait 导航...
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

**ego-browser**（同上面步骤 2 的 heredoc 内继续，不新开）：

```bash
# 仍在同一个 heredoc 内，紧接步骤 2 的代码：
const info = await pageInfo()
const snap = await snapshotText()
const hasError = snap.includes('Error') || snap.includes('报错') || info.w === 0
cliLog('页面状态：' + (hasError ? '异常' : '正常'))
cliLog('URL：' + info.url + ' 标题：' + info.title)
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

所有操作通过 `ego-browser nodejs <<'EOF' ... EOF` heredoc 执行。

**⚠️ heredoc 粒度硬约束（关键，避免开新页签）**：

- **同一测试场景的所有步骤必须在同一个 heredoc 内执行**，禁止步骤级拆分 heredoc
- **不同测试场景也在同一个 heredoc 内**，场景间用 `gotoAndWait(url)` 在同一 tab 内导航
- 整个测试会话 = 一个 heredoc，tab 状态自然连续，`openOrReuseTab` 能正确复用
- **禁止每个步骤开一个 heredoc**：跨 heredoc 时 tab 状态丢失，`openOrReuseTab` 无法复用，会反复开新页签，严重损耗性能

**正确做法**（场景级单 heredoc）：
```bash
ego-browser nodejs <<'EOF'
const task = await useOrCreateTaskSpace('cwork-test-{key}')

// 场景1：用户登录
await openOrReuseTab('http://localhost:3000/login', { wait: true, timeout: 20 })
await fillInput('input[name="username"]', 'testuser')
await click('button[type="submit"]', { label: '点击登录' })
await waitForLoad()
// ...验证...

// 场景2：数据列表（同一 tab 内导航，不开新页签）
await gotoAndWait('http://localhost:3000/dashboard')
await waitForNetworkIdle()
// ...验证...

// 全部完成
await completeTaskSpace(task.id, { keep: false })
EOF
```

**错误做法**（步骤级 heredoc，会开新页签）：
```bash
# ❌ 每个步骤一个 heredoc → 跨进程 tab 状态丢失 → openOrReuseTab 每次开新 tab
ego-browser nodejs <<'EOF'
const task = await useOrCreateTaskSpace('cwork-test-{key}')
await openOrReuseTab('http://localhost:3000/login', { wait: true })
EOF

ego-browser nodejs <<'EOF'
const task = await useOrCreateTaskSpace('cwork-test-{key}')
await fillInput('input[name="username"]', 'testuser')  # ← 新进程，不知道上一步的 tab
EOF
```

#### 语义工作流示例（表单操作）

> 以下示例均默认嵌在**会话级单 heredoc** 内：`openOrReuseTab` 只在整个会话开头调用一次，后续场景用 `gotoAndWait` 同 tab 导航。

```bash
ego-browser nodejs <<'EOF'
const task = await useOrCreateTaskSpace('cwork-test-{需求key}')

// 会话首次打开（唯一一次 openOrReuseTab，其后场景全部用 gotoAndWait）
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
// 场景间导航（同一 tab 内，不开新页签）
await gotoAndWait('http://localhost:3000/kanban')

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
// 场景间导航（同一 tab 内，不开新页签）
await gotoAndWait('http://localhost:3000/dashboard')

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
// 已在会话内（tab 已存在），用 gotoAndWait 导航到登录页，不开新页签
await gotoAndWait('http://localhost:3000/login')

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

### 前后端联合诊断（联动 cwork-log / cwork-config）

当失败诊断显示**后端接口异常**或**疑似配置问题**时，单看前端无法定位根因，需调用相关技能。

#### 自动联动机制（新增，关键）

**失败诊断后自动检查是否需要联动，无需人工判断：**

```javascript
// 失败诊断时自动执行
const events = await drainEvents();
const failedRequests = events
  .filter(e => e.type === 'network' || e.request || e.response)
  .filter(e => e.failed || e.errorText || (e.response?.status >= 400));

if (failedRequests.length > 0) {
  // 自动联动 cwork-log
  console.log('【自动联动】检测到后端接口失败，调用 cwork-log');
  for (const req of failedRequests) {
    const traceId = req.response?.headers?.['x-trace-id'] || req.response?.headers?.['trace-id'];
    const url = req.request?.url || req.url;
    const status = req.response?.status;
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
  ├─ 抓取网络请求（drainEvents）
  │
  ├─ 是否有后端接口失败（4xx/5xx/超时）？
  │    ├─ 否 → 纯前端问题：查截图 + 可见元素 + JS 报错 → 修前端代码
  │    │
  │    └─ 是 → 调用 cwork-log 查后端：
	  │            1. 从失败请求取 traceId（若有）/ 接口路径 / 时间戳 / 服务名
	  │            2. cwork-log 自动域感知路由（覆盖 16 域：CTP/Device/EMP/ZDL/DMP/OSP/IOP/银行/OMP/出站/MQ等）
	  │            3. sls_query.sh logs <logstore> 搜日志（logstore 已自动选择）
	  │            4. arms_trace.sh 还原链路，找耗时点/异常点
	  │            5. 判断：前端传参错？后端逻辑错？下游依赖超时？
  │
  └─ 是否疑似配置问题（开关未生效/阈值不对/行为与预期不符）？
       └─ 是 → 调用 cwork-config 查 Nacos 配置：
                1. 定 env + 服务名
                2. nacos_query.sh get/search 查配置真值
                3. 配置 ↔ 现象对应，定位根因
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
整个测试会话在一个 heredoc 内执行：

1. 创建任务空间：useOrCreateTaskSpace('cwork-test-{key}')
2. 首个场景：openOrReuseTab(url) 打开唯一标签页
3. 对于每个测试场景：
    a. 输出当前场景名称
    b. 场景间导航：gotoAndWait(url)（同一 tab 内，不开新页签）
    c. 等待页面加载：waitForLoad() 或 waitForNetworkIdle()
    d. 根据工作流类型执行步骤：
       - 语义：snapshotText() → click('@N') / fillInput('@N', text)
       - 视觉：captureScreenshot() → click([x,y]) / typeText(text)
       - DOM/CDP：js(...) / cdp(...)
    e. 每步执行后验证结果
    f. 记录通过/失败
    g. 失败时：
       - captureScreenshot() 截图
       - drainEvents() 抓网络请求 + snapshotText() 收集前端诊断
       - 若有后端接口失败 → 调用 cwork-log 查后端日志/链路（见"前后端联合诊断"）
       - 综合前后端证据定位根因 → 尝试自动修复并重试（最多 3 次）
    h. 遇到"用户控制中"错误：
       - handOffTaskSpace() 交接控制权
       - 等待用户确认
       - takeOverTaskSpace() 恢复控制权

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
  → ego-browser: gotoAndWait('http://localhost:3000/login')
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
