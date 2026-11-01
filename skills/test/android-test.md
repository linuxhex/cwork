> **按需加载**：本文件由 test SKILL.md 在 PROJECT_TYPE=android 时 Read 加载，不随 SKILL.md 一起全量加载。

# 安卓测试链路

> 以下内容仅在 PROJECT_TYPE=android 时执行

## 驱动选型与官方 Skill 关系

本链路用 **ADB 直连 BlueStacks 5**，不依赖 BlueStacks Desktop（官方 AI Agent Skill 所需，目前仅 Windows，Mac 未发）。
能力对齐官方 Skill：打开/切换 App、点击、滑动、输入、安装、截图、读界面结构。

| 官方 Skill 能力 | 本机实现 |
|----------------|----------|
| 打开/切换 App | `adb shell am start` / `monkey -p` |
| 点击/滑动 | `adb shell input tap/swipe` |
| 输入文本 | `adb shell input text`（特殊字符走广播兜底） |
| 安装 APK | `adb install -r` |
| 截图 | `adb exec-out screencap -p` |
| 读界面结构 | `uiautomator dump` → 解析 resource-id/text/content-desc/bounds |

**Windows + BlueStacks Desktop**：可选用官方 Skill 做人机探索；**结构化回归仍以 android-run.cjs 为准**（可复现、可出 result.json）。

## 前置条件

### 必须满足

1. BlueStacks 5 已安装（macOS: `/Applications/BlueStacks.app`）
2. ADB 可用：优先 `PATH` 的 `adb`，回退 BlueStacks 自带 `/Applications/BlueStacks.app/Contents/MacOS/hd-adb`
3. BlueStacks 高级设置里 **ADB 已开启**（Settings → Advanced → Android Debug Bridge → Save → 重启）
4. 有待测 APK 路径，或设备上已安装目标 `packageName`

### 自动检测

```bash
# BlueStacks 是否安装
[ -d "/Applications/BlueStacks.app" ] || echo "❌ BlueStacks 未安装"

# ADB 定位
ADB="$(command -v adb || echo /Applications/BlueStacks.app/Contents/MacOS/hd-adb)"
[ -x "$ADB" ] || echo "❌ ADB 不可用"

# BlueStacks 是否运行 + 设备在线
"$ADB" devices | grep -q "device$" || echo "❌ 无在线设备，需先开 BlueStacks 并在设置里启用 ADB"
```

### ADB 连接

BlueStacks 5 开启 ADB 后默认监听 `127.0.0.1:5555`（部分版本 5556）。连接：

```bash
adb connect 127.0.0.1:5555
adb devices   # 应出现 emulator-5554 或 127.0.0.1:5555
```

连接失败排查：确认 BlueStacks 设置里 ADB 已开 + 已重启；端口被占成 HTTP 服务时 `curl http://127.0.0.1:5555/` 验证（应非 404）。

## 执行引擎（唯一路径：android-run.cjs）

**三步流程**（与小程序/Web 一致）：

```
1. 探活 + 快照（2 条命令）
   node android-run.cjs --check
   node android-run.cjs --snapshot --out snap.json

2. AI 从快照生成 plan.json（选择器来自 resource-id/text，不盲猜坐标）

3. 一次执行（1 条命令，所有场景一次跑完）
   node android-run.cjs --plan plan.json --out result.json
```

**执行器命令**：

| 命令 | 说明 | 输出 |
|------|------|------|
| `--check` | 探活：设备 + 安卓版本 + 目标包是否已装 | 控制台输出 |
| `--snapshot [--out snap.json]` | 当前界面可交互节点清单（resource-id/text/content-desc/bounds） | `SNAPSHOT_JSON=...` + 文件 |
| `--plan plan.json [--out result.json]` | 执行测试计划 | `RESULT_JSON=...` + 文件 |
| `--install <apk>` | 安装/覆盖安装 APK | 控制台输出 |

**执行器内置防护**：每操作 20s 超时（ADB 挂起即报错）、全局看门狗 15 分钟、场景内首败即停并自动取证（截图 + window dump）、结果经 stdout 的 `RESULT_JSON=` 行返回。

## 阶段一：环境准备

### 步骤 1：检测环境

```
═══════════════════════════════════════════════════════════════
【cwork-test·安卓】环境检测
═══════════════════════════════════════════════════════════════

→ BlueStacks：{已安装/未安装}
→ ADB：{adb 路径}
→ 设备：{adb devices 输出}
→ 目标包：{packageName}
```

**环境不满足时**：BlueStacks 未装 → 终止；ADB 不可用 → 终止；无在线设备 → 提示开 BlueStacks + 启用 ADB + `adb connect`。

### 步骤 2：连接设备 + 可选安装

```bash
adb connect 127.0.0.1:5555
# 首次或 APK 更新时
node android-run.cjs --install path/to/app.apk
```

### 步骤 3：探活 + 快照

```bash
node android-run.cjs --check
node android-run.cjs --snapshot --out snap.json
```

## 阶段二：测试规划

AI 从 `snap.json` 生成 `plan.json`。**选择器必须来自快照的 resource-id/text，禁止盲猜坐标为唯一手段。**

**plan.json 格式**：

```json
{
  "deviceId": "127.0.0.1:5555",
  "packageName": "com.example.app",
  "stepTimeoutMs": 20000,
  "scenarios": [{
    "name": "打开并登录", "priority": "P0",
    "steps": [
      {"action": "launch", "packageName": "com.example.app"},
      {"action": "tap", "selector": {"text": "登录"}},
      {"action": "input", "selector": {"resourceId": "com.example.app:id/phone"}, "text": "13800138000"},
      {"action": "tap", "selector": {"text": "获取验证码"}},
      {"action": "assertText", "contains": "验证码"},
      {"action": "screenshot", "name": "login"}
    ]
  }]
}
```

**选择器优先级**：
1. `resourceId`
2. `text` / `contentDesc`
3. `bounds` 中心点（仅当上二者不可用，且必须来自当次 snapshot）

**支持的动作**：

| 动作 | 参数 | 说明 |
|------|------|------|
| `launch` | `{packageName}` | 启动 App |
| `tap` | `{selector}` | 点击（按 selector 定位，兜底 bounds） |
| `input` | `{selector, text}` | 输入文本（先 tap 聚焦再 input） |
| `swipe` | `{from, to, duration?}` | 滑动 |
| `back` | `{}` | 返回键 |
| `wait` | `{ms}` | 固定等待 |
| `assertText` | `{contains}` | 断言当前界面含文本 |
| `assertElement` | `{selector}` | 断言元素存在 |
| `screenshot` | `{name}` | 截图取证 |

## 阶段三：测试执行

```
1. 探活：node android-run.cjs --check
2. 快照：node android-run.cjs --snapshot --out snap.json
3. 生成 plan.json（选择器来自快照）
4. 执行：node android-run.cjs --plan plan.json --out result.json
5. 解析 RESULT_JSON：失败步骤看 evidence（截图 + window dump）
6. 疑似后端接口问题 → 调 cwork-log 查后端日志
7. 自动修复代码后：只重跑失败场景的 plan
```

## 阶段四：结果报告

报告格式与 Web/小程序共用 SKILL.md 的报告模板，项目类型填「安卓」，驱动引擎填「adb + BlueStacks 5」，截图证据来自 `screenshot` 动作 + 失败自动取证。

## HARD GATE（安卓链路专属）

- BlueStacks 5 未安装 / ADB 不可用 / `adb devices` 无在线设备，禁止执行测试
- 目标包未安装且无 APK 路径，禁止执行测试
- 测试规划未经用户确认，禁止执行
- 每个测试场景必须真实点击/交互执行，禁止模拟执行
- 回归测试禁止复用历史 plan.json，每次从最新快照重新生成
- 所有 P0 场景必须通过才能进入 cwork-commit
