> **按需加载**：本文件由 test SKILL.md 在 PROJECT_TYPE=mini 时 Read 加载，不随 SKILL.md 一起全量加载。

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

### 连接方式（智能启动 + 复用，避免重复重启 IDE）

**核心原则：IDE 启动一次就保持运行，整个测试会话复用同一连接，仅在检测到代码改动时才重启。**

#### 启动决策流程（首次 vs 复用 vs 代码改动重启）

```
检测 IDE 是否已在运行且已打开本项目？
  │
  ├─ 否（IDE 未运行）→ 首次启动：
  │     cli open --project <path>
  │     cli auto --project <path> --port 9420
  │     connect_devtools({ strategy: "connect" })
  │
  ├─ 是（IDE 已运行）→ 检测代码是否有改动？
  │     │
  │     ├─ 无代码改动 → 直接复用：
  │     │     connect_devtools({ strategy: "connect" })
  │     │
  │     └─ 有代码改动 → 重启 IDE（让开发者工具重新编译）：
  │           disconnect_devtools()          # 断开旧连接
  │           cli close --project <path>     # 关闭项目
  │           cli open --project <path>      # 重新打开（触发重新编译）
  │           cli auto --project <path> --port 9420
  │           connect_devtools({ strategy: "connect" })
  │
  └─ 连接失败（IDE 在但端口未开）→ 补开自动化端口：
        cli auto --project <path> --port 9420
        connect_devtools({ strategy: "connect" })
```

#### 代码改动检测

```bash
# 检测自上次测试以来是否有代码改动
# 记录上次测试时间戳（存于 .cwork/last-test-time-{project}.txt）
LAST_TEST_TIME=$(cat .cwork/last-test-time-$(basename $PROJECT_PATH).txt 2>/dev/null || echo "0")

# 查找比上次测试时间更新的代码文件
CHANGED_FILES=$(find "$PROJECT_PATH" \
  -name "*.js" -o -name "*.json" -o -name "*.wxml" -o -name "*.wxss" -o -name "*.ts" \
  -newer "$LAST_TEST_TIME" \
  -not -path "*/node_modules/*" -not -path "*/miniprogram_npm/*" \
  2>/dev/null | head -1)

if [ -n "$CHANGED_FILES" ]; then
  echo "检测到代码改动，需要重启 IDE 重新编译"
  NEED_RESTART=true
else
  echo "无代码改动，复用已有 IDE 实例"
  NEED_RESTART=false
fi

# 测试完成后记录当前时间戳
date +%s > .cwork/last-test-time-$(basename $PROJECT_PATH).txt
```

#### 连接代码示例

```javascript
// ✅ 正确：用 connect 策略复用已有 IDE 实例（不启动新实例）
const miniProgram = await automator.connect({
  cliPath: '/Applications/wechatwebdevtools.app/Contents/MacOS/cli',
  projectPath: '/path/to/mini',
});
```

```javascript
// ❌ 错误：用 launch 每次启动新 IDE（会导致端口冲突 + 重复重启）
const miniProgram = await automator.launch({
  cliPath: '/Applications/wechatwebdevtools.app/Contents/MacOS/cli',
  projectPath: '/path/to/mini',
});
```

> **连接生命周期**：整个测试会话只 `connect` 一次，所有场景复用同一连接，最后才 `disconnect`。不要每测一个场景就重连。**仅在检测到代码改动时才断开 → 重启 IDE → 重新连接。**
>
> **⚠️ 禁止用 `strategy: "auto"`**：`weixin-devtools-mcp` 的 `auto` 策略实际总是先调 `launchMode`（启动新 IDE），即使 IDE 已在运行也会重启。必须用 `strategy: "connect"` 复用已有实例。

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

**导航操作强制 evaluate 规则（新增，关键）**：

所有导航操作（navigateTo/switchTab/reLaunch/navigateBack）**必须**通过 `mp.evaluate` 调用 `wx.*` API，**禁止直接调用** automator 的导航方法：

```javascript
// ❌ 禁止：直接调用（会永久卡住）
await miniProgram.navigateTo({ url: '/pages/station/index' });
await miniProgram.switchTab({ url: '/pages/home/index/index' });
await miniProgram.reLaunch({ url: '/pages/testExp/index' });
await miniProgram.navigateBack();

// ✅ 正确：通过 evaluate 绕行（稳定）
await miniProgram.evaluate(() => { wx.navigateTo({ url: '/pages/station/index' }) });
await miniProgram.evaluate(() => { wx.switchTab({ url: '/pages/home/index/index' }) });
await miniProgram.evaluate(() => { wx.reLaunch({ url: '/pages/testExp/index' }) });
await miniProgram.evaluate(() => { wx.navigateBack() });
```

**翻译时自动检测**：当测试步骤包含"打开页面"/"切换Tab"/"重启到"/"返回"时，自动翻译为 `mp.evaluate(() => wx.xxx(...))`，不翻译为 automator 的直接调用。

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

### 步骤 2：打开项目并开启自动化端口（智能复用）

按上方「连接方式（智能启动 + 复用）」的**启动决策流程**执行：

1. **检测 IDE 是否已在运行且已打开本项目**
   - 是 → 进入代码改动检测（见「连接方式」的代码改动检测逻辑）
     - 无代码改动 → **跳过本步骤**，直接进步骤 3 用 `connect` 复用
     - 有代码改动 → 需重启：`cli close` → `cli open` → `cli auto`（触发重新编译）
   - 否（IDE 未运行）→ 首次启动：
     ```bash
     "$CLI_PATH" open --project "$PROJECT_PATH"
     "$CLI_PATH" auto --project "$PROJECT_PATH" --port 9420
     ```
2. 等待项目加载完成（轮询检测，最多 30 秒）
3. 确认自动化端口已开启

> **关键**：IDE 已运行且无代码改动时，**本步骤整体跳过**，不重复 `cli open`/`cli auto`，避免重启。

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

充电小程序（YKC）常见场景模板见同目录 `test-scenarios.md`（P0 核心流程 / P1 重要功能 / P2 辅助功能 / 小程序特有测试场景），agent 按需选用。

---
