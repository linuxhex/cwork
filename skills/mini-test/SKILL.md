---
name: cwork-mini-test
description: 微信小程序自动化测试，miniprogram-automator 驱动 + MCP 工具控制 + 页面交互 + 断言验证 + 截图 + 网络监控
---

# 微信小程序自动化测试

## 概述

`cwork-mini-test` 是 cwork 的微信小程序专用测试技能，通过 `miniprogram-automator` SDK（经 MCP Server 暴露）驱动微信开发者工具执行自动化测试。支持页面导航、元素交互（点击/输入/滑动/滚动）、数据断言、截图验证、网络请求监控，无需编写测试代码。

**与 `cwork-web-test` 的关系**：`cwork-web-test` 面向 Web 应用（ego-browser 驱动浏览器），`cwork-mini-test` 面向微信小程序（miniprogram-automator 驱动开发者工具模拟器）。两者互不依赖，按项目类型选用。

### 核心流程

1. **环境准备**：检测微信开发者工具 → 打开项目 → 开启自动化端口 → MCP 连接
2. **测试规划**：根据外部测试用例/需求文档，生成测试场景，自问自答质询测试设计
3. **测试执行**：通过 MCP 工具驱动小程序页面操作并验证结果
4. **结果报告**：记录测试结果（含截图证据），失败时诊断修复并重测，自问自答质询结果

### 在 cwork 流程中的位置

```
cwork-init → cwork-implement → cwork-mini-test → cwork-commit
                                       ↑
                                 本技能介入
```

- cwork-implement 完成后自动衔接（小程序项目时）
- 测试通过后进入 cwork-commit

## 语言约束（强制）

- **所有对话必须使用中文**
- **所有测试报告必须使用中文**
- 仅在必要处保留英文：命令、路径、选择器、代码

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

## 中文步骤 → 实际调用映射表

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

## 内部阶段一：环境准备

### 步骤 1：检测环境

```
═══════════════════════════════════════════════════════════════
【cwork-mini-test】环境检测
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

### 步骤 3：MCP 连接

通过 MCP 工具连接开发者工具：

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

### 步骤 4：确认小程序可操作

```
→ 获取当前页面：get_current_page()
→ 获取页面快照：get_page_snapshot()
→ 截图：screenshot({ path: "screenshots/初始状态.png" })
→ 页面加载状态：{正常/异常}
```

## 内部阶段二：测试规划

### 测试用例来源

`cwork-mini-test` 支持三种测试用例输入方式：

| 来源 | 说明 | 示例 |
|------|------|------|
| **外部传入** | 调用时直接传入测试场景列表 | `/cwork-mini-test 场景1: 登录流程; 场景2: 充电下单` |
| **需求文档** | 从 `analysis.md` / `plan.md` / `changes.md` 提取 | implement 衔接时自动读取 |
| **自动生成** | 分析小程序页面结构自动生成 | 独立使用时扫描 app.json 页面列表 |

### 外部测试用例格式

外部传入的测试用例使用以下格式：

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
【测试规划】生成测试场景
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

### 自问自答质询（测试设计质询）

对测试设计进行自我质询，确保覆盖面足够。全程自问自答，不涉及用户——自己扮演质疑者，自己回答，自己决策是否补充：

**质询规则**：
1. **逐层自问**：对每个测试场景，沿决策树追问"如果这里有 bug，我的场景能抓到吗？"
2. **每个自问带论据和自答**：提出质疑后，自己给出回答——"我怀疑覆盖不足，原因是 X，我决定补充场景 Y"
3. **一次只质疑一个场景**：逐个场景质询和自答，不要一次性罗列所有疑点
4. **事实自己查**：能从代码/需求文档确认的，直接查，不要空猜
5. **自己闭环**：每个质疑必须自己给出结论——是补充场景还是确认可靠，不留给用户判断

**自问自答示例**：
```
自问："登录只测了手机号验证码，微信一键登录路径呢？"
自答："代码里有 wx.login 路径，未覆盖。我补充微信一键登录场景。"
→ 补充场景

自问："充电下单只测了正常流程，余额不足场景呢？"
自答："这是核心支付路径，必须覆盖。补充余额不足提示场景。"
→ 补充场景

自问："网络超时场景测了吗？"
自答："小程序有全局请求拦截和重试机制，超时场景可在开发者工具 Network 面板模拟，暂不作为自动化测试重点。确认可靠。"
→ 记录：经自问验证，场景可靠
```

**覆盖面检查清单**：
- [ ] 主路径（快乐路径）覆盖
- [ ] 异常路径覆盖（错误输入、网络异常等）
- [ ] 边界条件覆盖（空数据、特殊字符）
- [ ] 交互状态覆盖（加载中、禁用状态、权限限制）
- [ ] 小程序特有场景（页面栈溢出、onShow/onHide 生命周期、分包加载）

## 内部阶段三：测试执行

### 执行流程

```
对于每个测试场景：
    1. 输出当前场景名称
    2. 导航到目标页面：navigate_to({ path })
    3. 等待页面加载：wait_for({ selector: "page", timeout: 5000 })
    4. 根据测试步骤执行操作：
       - 点击：query_selector → click
       - 输入：query_selector → input_text
       - 选择：query_selector → set_form_control
       - 验证文本：assert_text
       - 验证属性：assert_attribute
       - 验证状态：assert_state
       - 等待：wait_for
       - 截图：screenshot
       - 执行 JS：evaluate_script
    5. 每步执行后验证结果
    6. 记录通过/失败
    7. 失败时：
       a. screenshot 截图
       b. get_page_snapshot 获取页面快照
       c. list_network_requests 检查网络请求
       d. list_console_messages 检查 Console 错误
       e. 诊断根因 → 尝试自动修复并重试（最多 3 次）
    8. 场景完成后截图留证：screenshot({ path: "screenshots/{场景名}-最终.png" })
```

### 执行输出格式

```
═══════════════════════════════════════════════════════════════
【测试执行】场景 1/3：用户登录
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

### 失败处理

```
步骤 3：点击获取验证码
  → click({ uid: "button.get-code" })
  → 结果：✗ 元素未找到

  诊断：
  → 截图：screenshots/场景1-步骤3-fail.png
  → 页面快照：get_page_snapshot()
  → 网络请求：list_network_requests()
  → Console 错误：list_console_messages()
  → 可见元素：debug_page_elements()
  → 可能原因：按钮选择器不匹配或按钮未渲染

  处理：
  → 尝试替代选择器：query_selector({ selector: "button:contains('验证码')" })
  → 重试结果：✓ 找到并点击成功
```

### 失败诊断

步骤失败时，收集全面诊断信息：

1. **截图**：`screenshot({ path: "screenshots/{场景名}-步骤{N}-fail.png" })`
2. **页面快照**：`get_page_snapshot()` — 获取当前 DOM 结构
3. **网络请求**：`list_network_requests()` — 检查是否有接口失败（4xx/5xx/超时）
4. **Console 错误**：`list_console_messages()` — 检查 JS 报错
5. **元素调试**：`debug_page_elements()` — 列出可见交互元素
6. **连接诊断**：`diagnose_connection()` — 检查连接是否正常

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

### 自动修复循环

```
if 测试失败:
    1. 收集诊断信息
    2. 定位根因（前端/后端/环境）
    3. 若为前端问题 → 修前端代码
    4. 等待开发者工具热更新
    5. 重新执行失败的场景
    6. 最多重试 3 次
    7. 仍失败则记录到报告（含截图 + 诊断证据），等待人工处理
```

## 内部阶段四：结果报告

### 自问自答质询（结果质询）

对测试结果进行自我质询。全程自问自答，不涉及用户：

**质询规则**：
1. **逐层自问**：对每个测试结论，沿决策树追问"如果这个判断是错的呢？"
2. **每个自问带论据和自答**：提出质疑后，自己给出回答
3. **一次只质疑一个结论**：逐个结论质询和自答
4. **事实自己查**：能从截图/网络请求/代码验证的，直接查
5. **自己闭环**：每个质疑必须自己给出结论

**自问模板**：
1. "全部通过是真的没问题，还是我的测试太浅了？"
2. "失败的用例是 bug 还是测试本身的问题？我确信吗？"
3. "有没有我刻意跳过的'不好测'的场景？"

### 报告格式

测试结果记录到 `docs/requirements/{requirement_key}/test-report.md`：

```markdown
# 测试报告

## 概要
- 测试时间：{YYYY-MM-DD HH:mm:ss}
- 测试环境：微信开发者工具模拟器
- 项目路径：{PROJECT_PATH}
- AppID：{APPID}
- 场景总数：{N}
- 通过：{M}
- 失败：{K}
- 通过率：{M/N * 100}%

## 详细结果

### 场景 1：用户登录 ✓
| 步骤 | 操作 | 结果 | 截图 |
|------|------|------|------|
| 1 | 打开 pages/login/login | ✓ | |
| 2 | 输入手机号 | ✓ | |
| 3 | 点击获取验证码 | ✓ | |
| 4 | 验证跳转到首页 | ✓ | screenshots/场景1-最终.png |

### 场景 2：扫码充电 ✗
| 步骤 | 操作 | 结果 | 截图 | 备注 |
|------|------|------|------|------|
| 1 | 打开 pages/scan/scan | ✓ | | |
| 2 | 点击扫码按钮 | ✗ | screenshots/场景2-步骤2-fail.png | 按钮未找到 |
| 3 | 验证扫码结果 | - | | 未执行 |

## 失败分析

### 场景 2：扫码充电
- 失败步骤：步骤 2 — 点击扫码按钮
- **前端诊断**：截图显示页面加载正常但扫码按钮未渲染；Console 无报错；网络请求无异常
- **后端诊断**：未触发（无接口调用，纯前端渲染问题）
- 定性：**纯前端问题**
- 可能原因：扫码按钮依赖权限判断，当前账号无扫码权限
- 建议：检查扫码权限逻辑或使用有权限的测试账号

## 修复建议
1. [场景2·前端] 检查扫码按钮的权限判断逻辑
2. [场景2·前端] 考虑使用有扫码权限的测试账号重测
```

### 截图证据

截图保存到 `docs/requirements/{requirement_key}/screenshots/` 目录：

| 截图类型 | 命名规则 | 何时捕获 |
|---------|---------|---------|
| 步骤失败 | `{场景名}-步骤{N}-fail.png` | 步骤执行失败时（必须） |
| 场景最终 | `{场景名}-最终.png` | 场景所有步骤完成后（必须） |
| 步骤成功 | `{场景名}-步骤{N}-pass.png` | 步骤执行成功时（可选，默认不捕获） |

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

- 微信开发者工具未安装，禁止执行
- project.config.json 不存在，禁止执行
- MCP Server 不可用，禁止执行
- 环境未就绪（自动化端口未开启），禁止执行测试
- 测试规划未经用户确认，禁止执行
- 所有 P0 场景必须通过才能进入 cwork-commit
- P1/P2 场景失败可记录但不阻塞提交

## 与 cwork-implement 的衔接

cwork-implement 完成后：

1. 自动检测是否为小程序项目（存在 `project.config.json` 且含 `appid`）
2. 小程序项目 + 有前端改动 → 自动进入 cwork-mini-test
3. Web 项目 + 有前端改动 → 自动进入 cwork-web-test
4. 无前端改动 → 跳过，直接进入 cwork-commit

```
═══════════════════════════════════════════════════════════════
【自动衔接】检测到小程序项目 + 前端改动，进入 cwork-mini-test
═══════════════════════════════════════════════════════════════
```

## 独立使用

cwork-mini-test 也可以独立使用（不依赖 cwork-implement）：

```
用户：帮我测试一下小程序的登录流程
→ 直接进入环境准备阶段
→ 用户提供的测试要求作为测试场景输入

用户：/cwork-mini-test 场景1: 登录流程; 场景2: 充电下单
→ 解析外部测试用例
→ 直接进入环境准备阶段
```

### 接收外部测试用例

当通过参数传入测试用例时，跳过自动生成，直接使用传入的场景：

```
/cwork-mini-test
测试用例：
1. 登录流程：打开登录页 → 输入手机号 → 获取验证码 → 验证登录成功
2. 充电下单：扫码 → 选择充电桩 → 确认下单 → 验证订单创建
3. 个人中心：查看余额 → 充值 → 验证余额更新
```

外部测试用例支持以下格式：
- 自然语言描述（自动解析为测试步骤）
- 结构化场景格式（见"外部测试用例格式"章节）
- 测试用例文件路径（读取文件内容解析）

## 小程序特有注意事项

### 页面栈管理

小程序页面栈最多 10 层，测试中需注意：
- 连续 `navigate_to` 不超过 10 次
- 超过时用 `relaunch` 重置页面栈
- 测试场景间用 `relaunch` 清理页面栈

### 分包页面

分包页面首次加载可能较慢：
- `wait_for` 的 timeout 适当增大（分包建议 10 秒）
- 首次进入分包页面时多等 1-2 秒

### 登录态

开发者工具中的登录态与真机不同：
- 需手动扫码登录一次（开发者工具会缓存登录态）
- 测试需要登录态的场景前，先检查登录状态
- 未登录时提示用户手动扫码

### 自定义组件

小程序自定义组件的查询：
- 使用 `component-name` 作为选择器（如 `login-dialog`）
- 组件内部元素用后代选择器（如 `login-dialog .btn-confirm`）
- 组件 data 通过 `evaluate_script` 读取

### TabBar 页面

TabBar 页面切换必须用 `switch_tab`，不能用 `navigate_to`：
- `switch_tab({ tabName: "home" })` — 正确
- `navigate_to({ path: "pages/index/index" })` — 错误（TabBar 页面不支持 navigateTo）

## 项目常见测试场景模板

以下是充电小程序（YKC）常见测试场景模板，agent 按需选用：

### P0 核心流程

| 场景 | 页面路径 | 关键步骤 | 断言 |
|------|---------|---------|------|
| **手机号登录** | pages/login/login | 输入手机号 → 获取验证码 → 输入验证码 → 点击登录 | 跳转到首页 + 用户信息展示 |
| **微信一键登录** | pages/login/login | 点击微信登录按钮 → 授权 | 跳转到首页 + 用户信息展示 |
| **扫码充电** | pages/testExp/index | 点击扫码 → 扫码结果页 → 选择充电桩 → 确认下单 | 订单创建成功 + 跳转充电页 |
| **充电中状态** | pages/charge/charge | 进入充电中页面 | 充电功率/时长/费用实时更新 |
| **结束充电** | pages/charge/charge | 点击结束充电 → 确认 | 订单完成 + 费用展示 + 跳转订单详情 |
| **支付订单** | pages/order/pay | 选择支付方式 → 确认支付 | 支付成功 + 订单状态更新 |

### P1 重要功能

| 场景 | 页面路径 | 关键步骤 | 断言 |
|------|---------|---------|------|
| **首页展示** | pages/home/index/index | 打开首页 | 轮播图展示 + 推荐站点列表 + TabBar 可见 |
| **站点列表** | pages/home/citys/citys | 打开城市/站点列表 | 站点卡片展示 + 距离排序 + 下拉刷新 |
| **订单列表** | pages/order/index/index | 打开订单列表 | 订单卡片展示 + 状态筛选 + 上拉加载更多 |
| **订单详情** | pages/order/detail/detail | 进入订单详情 | 订单信息完整 + 充电明细 + 支付信息 |
| **个人中心** | pages/user/index/index | 打开个人中心 | 用户头像/昵称 + 余额 + 菜单列表 |
| **钱包/余额** | pages/user/wallet/index | 打开钱包 | 余额展示 + 充值入口 + 消费记录入口 |
| **充值流程** | pages/user/recharge/index | 选择金额 → 确认充值 → 支付 | 余额更新 + 充值记录生成 |

### P2 辅助功能

| 场景 | 页面路径 | 关键步骤 | 断言 |
|------|---------|---------|------|
| **设置页** | pages/user/settings/index | 打开设置 | 各设置项展示 + 退出登录按钮可见 |
| **消息列表** | pages/message/index | 打开消息 | 消息列表展示 + 未读标记 |
| **优惠券** | pages/user/coupon/index | 打开优惠券 | 优惠券列表 + 状态筛选 |
| **充电记录** | pages/user/card/consume-records/index | 打开消费记录 | 记录列表 + 时间筛选 |

### 小程序特有测试场景

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

## evaluate_script 高级用法

weixin-devtools-mcp 未直接暴露部分 miniprogram-automator 能力，但均可通过 `evaluate_script` 间接实现：

### 读取页面 data

```
evaluate_script({
  script: "JSON.stringify(__page__.data)"
})
```

返回当前页面的完整 data 对象（JSON 字符串，需 JSON.parse）。

### 设置页面 data

```
evaluate_script({
  script: "__page__.setData({ key: value })"
})
```

直接修改页面 data，触发视图更新。适用于：
- 设置表单默认值
- 模拟服务端返回数据
- 强制切换页面状态

### 调用页面方法

```
evaluate_script({
  script: "__page__.onPullDownRefresh()"
})
```

直接调用页面生命周期方法或自定义方法。适用于：
- 触发下拉刷新
- 调用内部请求方法
- 模拟生命周期变化

### 调用组件方法

```
evaluate_script({
  script: "const comp = __page__.selectComponent('#myComponent'); comp && comp.myMethod()"
})
```

### 读取组件 data

```
evaluate_script({
  script: "const comp = __page__.selectComponent('#myComponent'); comp ? JSON.stringify(comp.data) : 'not found'"
})
```

### 调用 wx API

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

### mock wx API（支付/授权等）

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

适用于：
- `wx.requestPayment` — mock 支付成功/失败
- `wx.getUserProfile` — mock 用户授权
- `wx.getLocation` — mock 定位返回
- `wx.chooseImage` — mock 图片选择

### 操作 Swiper 组件

```
evaluate_script({
  script: "const swiper = __page__.selectComponent('.my-swiper'); swiper && swiper.setData({ current: 2 })"
})
```

### 操作 ScrollView 滚动

```
evaluate_script({
  script: "const sv = __page__.selectComponent('.my-scroll'); sv && sv.setData({ scrollTop: 500 })"
})
```

### 检查登录状态

```
evaluate_script({
  script: "const token = wx.getStorageSync('token'); token ? 'logged_in' : 'not_logged_in'"
})
```

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

使用本 skill 遇到的不顺手 / 报错 / 结果不准 / 可省步骤，记一笔到 `../USAGE_NOTES.md`「未分析」区（格式 `[YYYY-MM-DD] [mini-test] 现象 | 建议改法`），能当场修的直接修。**每天最多分析一次**，据此优化各 skill——流程见 `../USAGE_NOTES.md` 顶部。
