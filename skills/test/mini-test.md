> **按需加载**：本文件由 test SKILL.md 在 PROJECT_TYPE=mini 时 Read 加载，不随 SKILL.md 一起全量加载。

# 小程序测试链路

> 以下内容仅在 PROJECT_TYPE=mini 时执行

## 前置条件

### 必须满足

1. 微信开发者工具已安装（macOS: `/Applications/wechatwebdevtools.app`）
2. 项目有 `project.config.json`（含 appid）
3. `miniprogram-automator` 已安装（`npm install -g miniprogram-automator` 或随 `weixin-devtools-mcp` 内嵌）

### 微信开发者工具 CLI

CLI 路径（macOS 默认）：

```
/Applications/wechatwebdevtools.app/Contents/MacOS/cli
```

核心命令：

| 命令 | 说明 |
|------|------|
| `cli open --project <path>` | 打开项目 |
| `cli auto --project <path> --auto-port <port>` | 开启自动化端口（⚠️ 是 `--auto-port`，不是 `--port`——`--port` 是 IDE HTTP 服务端口，用错会导致 automator 连不上） |
| `cli close --project <path>` | 关闭项目 |
| `cli quit` | 退出开发者工具 |

### 自动检测

```bash
CLI_PATH="/Applications/wechatwebdevtools.app/Contents/MacOS/cli"
PROJECT_PATH=""  # 从 project.config.json 所在目录推断

if [ ! -f "$CLI_PATH" ]; then
    echo "❌ 微信开发者工具未安装"
    exit 1
fi

if [ ! -f "project.config.json" ]; then
    echo "❌ 未找到 project.config.json"
    exit 1
fi

APPID=$(python3 -c "import json; print(json.load(open('project.config.json'))['appid'])")
```

## 执行引擎（唯一路径：mini-run.cjs 直连）

**小程序测试只走一条路径：`scripts/mini-run.cjs` 直连 automator**。不走 MCP，不生成 JS 脚本，不逐步交互。

**为什么不用 MCP**（均为源码/实测实证）：
1. **MCP 网络监控劫持业务请求**：`mockWxMethod('request'/...)` 替换 wx.request，业务响应变成占位符，停止监听也清不干净
2. **MCP 层无超时**：除 `connect_devtools`(45s) 外全部裸 await，命令挂起整个会话卡死
3. **MCP 每步一往返**：AI 每步 2-3 次工具调用 + 思考轮，一个场景十几轮，极慢

**三步流程**：

```
1. 探活 + 快照（2 条命令，~5 秒）
   node mini-run.cjs --check
   node mini-run.cjs --snapshot --out snap.json

2. AI 从快照生成 plan.json（选择器来自真实元素，不盲猜）

3. 一次执行（1 条命令，所有场景一次跑完）
   node mini-run.cjs --plan plan.json --out result.json
```

**执行器命令**：

| 命令 | 说明 | 输出 |
|------|------|------|
| `--check` | 探活：连接 + 当前页面 path | 控制台输出 |
| `--snapshot [--out snap.json]` | 快照：当前页 path + data + 可交互元素清单（含选择器） | `SNAPSHOT_JSON=...` + 文件 |
| `--plan plan.json [--out result.json]` | 执行测试计划 | `RESULT_JSON=...` + 文件 |

**快照输出格式**（`--snapshot`）：

```json
{
  "path": "pages/login/login",
  "data": { "phone": "", "code": "", "loading": false },
  "elements": [
    { "tag": "input", "text": "", "selector": "input[placeholder*=\"手机号\"]", "placeholder": "请输入手机号", "type": "number" },
    { "tag": "button", "text": "获取验证码", "selector": "button.get-code", "className": "get-code" },
    { "tag": "button", "text": "登录", "selector": "button.login-btn", "className": "login-btn" }
  ]
}
```

AI 从 `elements` 数组的 `selector` 字段直接取选择器，**禁止盲猜**——选择器必须来自快照输出。

**执行器内置防护**：每操作 15s 超时（挂起即报错，不卡死）、导航一律 evaluate 调 `wx.*`、无 screenshot、全局看门狗 10 分钟、场景内首败即停并自动取证（页面 path + data dump）、结果经 stdout 的 `RESULT_JSON=` 行返回供 AI 解析。

## miniprogram-automator 已知问题与绕行方案

### 导航 API 卡住问题（关键）

`miniprogram-automator` 的 `navigateTo`/`switchTab`/`reLaunch`/`navigateBack`/`screenshot` 会**永久卡住**（Promise 不 resolve 也不 reject）。WebSocket 通信层的已知问题。

**绕行方案**（mini-run.cjs 内部已实现）：用 `mp.evaluate()` 调 `wx.*` API 间接导航：

```javascript
// ❌ 直接调用（会卡住）
await miniProgram.navigateTo({ url: '/pages/station/index' });

// ✅ evaluate 绕行（稳定，mini-run.cjs 内部已用此方式）
await miniProgram.evaluate((url, t) => { wx[t]({ url }); }, '/pages/station/index', 'navigateTo');
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
| `screenshot` | ❌ 卡住 | ⚠️ 禁用 |

### 挂起检测与恢复（强制，实测踩坑总结）

**挂起机理**：automator 的 `Connection.send` 是裸 Promise——无请求超时。开发者工具端回包丢失时该 Promise 永久挂起。mini-run.cjs 的 `withTimeout()` 是唯一兜底（每操作 15s + 全局 10min）。

**挂起判定（三联症状，占其一即判定）**：

| 症状 | 表现 |
|---|---|
| mini-run.cjs 超时报错 | 输出含「超时」或「挂起」 |
| 小程序一直加载中 | 页面长时间转圈不渲染 |
| 手动点击无反应 | 模拟器手动点击任何位置均无响应 |

**恢复序列（挂起后必须执行，禁止原地重试）**：

```
判定挂起
  │
  ├─ 1. 放弃当前挂起的调用（超时报错自动放弃）
  │     ⚠️ 禁止对同一操作原地重试——队列已堵死
  │
  ├─ 2. 跑恢复脚本（重启开发者工具 + 重开自动化端口）：
  │     bash <mini-recover.sh 绝对路径> <小程序项目路径> [端口]
  │     脚本位置：
  │     - 源仓库：  $CWORK_HOME/skills/test/scripts/mini-recover.sh
  │     - Qoder：   ~/.qoder/skills/cwork-test/scripts/mini-recover.sh
  │
  ├─ 3. 重新探活：node mini-run.cjs --check
  │
  ├─ 4. 从当前场景的第一个步骤重跑（不从头跑全部场景）
  │
  └─ 5. 若恢复后再次在同一位置挂起 → 记该场景失败，跳过继续
```

**给用户的提示话术**：
> 检测到自动化命令挂起（小程序一直加载中、点击无反应是伴随现象）。正在重启开发者工具恢复，约 30 秒。

### 连接方式（智能复用，避免重复重启 IDE）

**核心原则：IDE 启动一次就保持运行，整个测试会话复用同一连接。**

```
检测 IDE 是否已在运行且已打开本项目？
  │
  ├─ 否（IDE 未运行）→ 首次启动：
  │     cli open --project <path>
  │     cli auto --project <path> --auto-port 9420
  │
  ├─ 是（IDE 已运行）→ 检测代码是否有改动？
  │     ├─ 无代码改动 → 直接复用（mini-run.cjs --check 验证即可）
  │     └─ 有代码改动 → 重启 IDE：
  │           cli close --project <path>
  │           cli open --project <path>
  │           cli auto --project <path> --auto-port 9420
  │
  └─ 连接失败 → 补开自动化端口：
        cli auto --project <path> --auto-port 9420
```

#### 代码改动检测

```bash
LAST_TEST_TIME=$(cat .cwork/last-test-time-$(basename $PROJECT_PATH).txt 2>/dev/null || echo "0")
CHANGED_FILES=$(find "$PROJECT_PATH" \
  -name "*.js" -o -name "*.json" -o -name "*.wxml" -o -name "*.wxss" -o -name "*.ts" \
  -newer "$LAST_TEST_TIME" \
  -not -path "*/node_modules/*" -not -path "*/miniprogram_npm/*" \
  2>/dev/null | head -1)

if [ -n "$CHANGED_FILES" ]; then
  NEED_RESTART=true
else
  NEED_RESTART=false
fi

date +%s > .cwork/last-test-time-$(basename $PROJECT_PATH).txt
```

## 小程序阶段一：环境准备

### 步骤 1：检测环境

```
═══════════════════════════════════════════════════════════════
【cwork-test·小程序】环境检测
═══════════════════════════════════════════════════════════════

→ 检测微信开发者工具 CLI：{CLI_PATH}
→ 检测项目配置：project.config.json（appid: {APPID}）
→ 检测 miniprogram-automator：{已安装/未安装}
→ 项目路径：{PROJECT_PATH}
```

**环境不满足时**：
- CLI 不存在 → 提示安装微信开发者工具，终止
- project.config.json 不存在 → 提示指定项目路径，终止
- automator 未安装 → `npm install -g miniprogram-automator`

### 步骤 2：打开项目并开启自动化端口（智能复用）

按上方「连接方式」的启动决策流程执行：

1. **检测 IDE 是否已在运行**
   - 是 + 无代码改动 → **跳过本步骤**，直接探活
   - 是 + 有代码改动 → 重启：`cli close` → `cli open` → `cli auto`
   - 否 → 首次启动：
     ```bash
     "$CLI_PATH" open --project "$PROJECT_PATH"
     "$CLI_PATH" auto --project "$PROJECT_PATH" --auto-port 9420
     ```
2. 等待项目加载完成（最多 30 秒）
3. 确认自动化端口已开启

### 步骤 3：探活 + 快照

```bash
# 探活
node mini-run.cjs --check

# 快照（取当前页面真实结构）
node mini-run.cjs --snapshot --out snap.json
```

> `--check` 失败 → 确认自动化端口：`cli auto --project <路径> --auto-port 9420`；仍失败 → 跑 `mini-recover.sh`。

## 小程序阶段二：测试规划

### 测试用例来源

| 来源 | 说明 | 示例 |
|------|------|------|
| **外部传入** | 调用时直接传入测试场景列表 | `/cwork-test 场景1: 登录流程; 场景2: 充电下单` |
| **需求文档** | 从 `analysis.md` / `plan.md` / `changes.md` 提取 | implement 衔接时自动读取 |
| **自动生成** | 分析小程序页面结构自动生成 | 独立使用时扫描 app.json 页面列表 |

### 从快照生成 plan.json

AI 根据快照输出（`snap.json`）生成 `plan.json`。**选择器必须来自快照的 `elements[].selector`，禁止盲猜。**

**plan.json 格式**：

```json
{
  "wsEndpoint": "ws://127.0.0.1:9420",
  "stepTimeoutMs": 15000,
  "scenarios": [{
    "name": "用户登录", "priority": "P0",
    "steps": [
      {"action": "navigate", "url": "/pages/login/login"},
      {"action": "input", "selector": "input[placeholder*='手机号']", "text": "13800138000"},
      {"action": "click", "selector": "button.get-code"},
      {"action": "expectPage", "path": "pages/index/index"}
    ]
  }]
}
```

**支持的动作**（完整列表见 mini-run.cjs 头部注释）：

| 动作 | 参数 | 说明 |
|------|------|------|
| `navigate` | `{url, type?}` | 导航（type: navigateTo/switchTab/reLaunch/redirectTo） |
| `back` | `{}` | 返回上一页 |
| `click` | `{selector, index?}` | 点击元素 |
| `input` | `{selector, text}` | 输入文本 |
| `callMethod` | `{method, args?}` | 调用页面方法 |
| `setData` | `{data}` | 设置页面 data |
| `evaluate` | `{script}` | 执行 JS（小程序上下文） |
| `wait` | `{ms}` | 固定等待 |
| `expectPage` | `{path}` | 断言当前页面 |
| `expectData` | `{key, value?\|contains?}` | 断言页面 data |
| `expectText` | `{selector, contains}` | 断言元素文本 |
| `expectElement` | `{selector}` | 断言元素存在 |

### 多页面快照

如果测试场景涉及多个页面，需要分别快照：

```bash
# 先导航到目标页面再快照
node mini-run.cjs --plan '{"wsEndpoint":"ws://127.0.0.1:9420","scenarios":[{"name":"导航","steps":[{"action":"navigate","url":"/pages/login/login"}]}]}'
# 再快照当前页
node mini-run.cjs --snapshot --out snap-login.json
```

或者在 plan.json 中用 `evaluate` 动作先读取页面结构，减少连接次数：

```json
{"action": "evaluate", "script": "JSON.stringify({path: __page__.route, data: __page__.data})"}
```

## 小程序阶段三：测试执行

### 执行流程

```
1. 探活：node mini-run.cjs --check
   （失败 → 确认自动化端口 → mini-recover.sh）

2. 快照：node mini-run.cjs --snapshot --out snap.json
   （取当前页 path + data + 可交互元素清单）

3. 生成 plan.json（选择器来自快照，禁止盲猜）

4. 执行：node mini-run.cjs --plan plan.json --out result.json
   （一次连接跑完所有场景）

5. 解析 RESULT_JSON：失败步骤看 evidence（页面 path + data dump）

6. 疑似后端接口问题 → 调 cwork-log 查后端日志

7. 自动修复代码后：只重跑失败场景的 plan，不重跑全部
```

### 执行输出格式

```
═══════════════════════════════════════════════════════════════
【测试执行·小程序】
═══════════════════════════════════════════════════════════════

→ 连接 ws://127.0.0.1:9420（原生 automator，无请求劫持）...

【场景】用户登录（P0）
  ✓ pages/login/login
  ✓ input[placeholder*="手机号"] ← "13800138000"
  ✓ button.get-code
  ✓ pages/index/index
  场景结果：✓ 通过

═══ 结果：通过 1 / 失败 0（共 1 场景），详情 result.json ═══
```

### 失败处理

步骤失败时，mini-run.cjs 自动取证（`evidence` 字段含当前页面 path + data dump）。AI 根据 evidence 诊断：

```
诊断决策树：
  │
  ├─ data 正常、元素/交互异常 → 纯前端问题：查快照元素 + 修前端代码
  │
  └─ data 空/加载中/错误态 → 疑似后端接口问题：
          调 cwork-log 查后端对应接口日志（时间窗对齐测试执行时刻）
```

**失败后重试**：修改 plan.json（调整选择器/断言），只重跑失败场景的 plan（场景数量 1 个的 plan.json），不重跑全部。最多重试 2 次。

### 小程序特有注意事项

#### 页面栈管理

小程序页面栈最多 10 层：
- 连续 `navigateTo` 不超过 10 次
- 超过时用 `reLaunch` 重置页面栈
- 场景间用 `reLaunch` 清理

#### TabBar 页面

TabBar 页面必须用 `switchTab`（plan.json 中 `{"action": "navigate", "type": "switchTab"}`），不能用 `navigateTo`。

#### 分包页面

分包页面首次加载较慢，`stepTimeoutMs` 适当增大或加 `wait` 步骤。

#### 登录态

开发者工具需手动扫码登录一次。测试需要登录态的场景前，先检查登录状态。

### 项目常见测试场景模板

充电小程序（YKC）常见场景模板见同目录 `test-scenarios.md`，agent 按需选用。

---
