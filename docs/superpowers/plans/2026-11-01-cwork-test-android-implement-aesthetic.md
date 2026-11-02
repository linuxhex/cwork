# cwork-test 安卓链路 + 小程序加速 + implement 审美/编码增强 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 给 cwork-test 加安卓链路（BlueStacks5+ADB，对齐官方 Skill 能力）+ 小程序执行器加速；借鉴 impeccable 思想增强 implement 前端设计；借鉴 ponytail 思想增强 implement 编码。

**Architecture:** 三线并行、落点文件不重叠。A 线新增 `android-test.md`+`android-run.cjs` 并改 `mini-run.cjs`/`mini-test.md`/`SKILL.md`；B 线增强 `design-guide.md`+`review-checklist.md`；C 线增强 `phases.md`+`core-os.md`+`review-checklist.md`。全部双写源仓库 `skills/` + 安装副本 `.cwork/refs/`。

**Tech Stack:** Node.js (cjs)、ADB、miniprogram-automator、Markdown 技能文档

**工程约束：**
- 源仓库权威：`skills/<name>/`；安装副本：`.cwork/refs/cwork-<name>/`。改完必须双写，否则下次分发被冲掉。
- 改完当场记一笔到 `skills/USAGE_NOTES.md`「未分析」区（静默，不打印）。
- 分支已建：`feat/cwork-test-android-implement-aesthetic`。提交作者固定 this_way。
- 双写校验：每次改完用 `diff` 确认源与副本一致。

**双写路径对照表：**

| 源仓库 | 安装副本 |
|--------|---------|
| `skills/test/SKILL.md` | `.cwork/refs/cwork-test/SKILL.md` |
| `skills/test/mini-test.md` | `.cwork/refs/cwork-test/mini-test.md` |
| `skills/test/scripts/mini-run.cjs` | `.cwork/refs/cwork-test/scripts/mini-run.cjs` |
| `skills/test/android-test.md`（新） | `.cwork/refs/cwork-test/android-test.md`（新） |
| `skills/test/scripts/android-run.cjs`（新） | `.cwork/refs/cwork-test/scripts/android-run.cjs`（新） |
| `skills/implement/design-guide.md` | `.cwork/refs/cwork-implement/design-guide.md` |
| `skills/implement/review-checklist.md` | `.cwork/refs/cwork-implement/review-checklist.md` |
| `skills/implement/phases.md` | `.cwork/refs/cwork-implement/phases.md` |
| `skills/implement/core-os.md` | `.cwork/refs/cwork-implement/core-os.md` |

---

## 阶段一：cwork-test 安卓链路（A 线）

### Task 1: 新增 android-test.md 链路文档

**Files:**
- Create: `skills/test/android-test.md`
- Create: `.cwork/refs/cwork-test/android-test.md`（双写）

- [ ] **Step 1: 写 android-test.md 源文件**

写入 `skills/test/android-test.md`：

````markdown
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
- 目标包未安装且无 APK 路径，禁止执行
- 测试规划未经用户确认，禁止执行
- 每个测试场景必须真实点击/交互执行，禁止模拟执行
- 回归测试禁止复用历史 plan.json，每次从最新快照重新生成
- 所有 P0 场景必须通过才能进入 cwork-commit
````

- [ ] **Step 2: 双写到安装副本**

```bash
cp /Users/caomunian/Study/cwork/skills/test/android-test.md /Users/caomunian/Study/cwork/.cwork/refs/cwork-test/android-test.md
diff /Users/caomunian/Study/cwork/skills/test/android-test.md /Users/caomunian/Study/cwork/.cwork/refs/cwork-test/android-test.md && echo "✓ 双写一致"
```

- [ ] **Step 3: Commit**

```bash
git add skills/test/android-test.md .cwork/refs/cwork-test/android-test.md
git commit -m "【cwork-test 安卓链路】<feat> 新增 android-test.md：BlueStacks5+ADB 驱动文档

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 2: 新增 android-run.cjs 执行器

**Files:**
- Create: `skills/test/scripts/android-run.cjs`
- Create: `.cwork/refs/cwork-test/scripts/android-run.cjs`（双写）

- [ ] **Step 1: 写 android-run.cjs 源文件**

写入 `skills/test/scripts/android-run.cjs`：

````javascript
#!/usr/bin/env node
/**
 * cwork-test 安卓测试执行器（ADB 直连 BlueStacks 5）
 *
 * 对齐 BlueStacks 官方 AI Agent Skill 能力，但不依赖 Desktop（仅 Windows）。
 * 所有操作经 adb shell，带超时看门狗，挂起即报错不卡死。
 *
 * 用法：
 *   node android-run.cjs --check                              # 探活：设备+版本+目标包
 *   node android-run.cjs --snapshot [--out snap.json]          # 当前界面可交互节点清单
 *   node android-run.cjs --plan plan.json [--out result.json]  # 跑测试计划
 *   node android-run.cjs --install <apk>                       # 安装/覆盖安装
 *
 * plan.json 结构：
 * {
 *   "deviceId": "127.0.0.1:5555",
 *   "packageName": "com.example.app",
 *   "stepTimeoutMs": 20000,
 *   "scenarios": [{
 *     "name": "登录", "priority": "P0",
 *     "steps": [
 *       {"action": "launch", "packageName": "com.example.app"},
 *       {"action": "tap", "selector": {"text": "登录"}},
 *       {"action": "input", "selector": {"resourceId": "com.example.app:id/phone"}, "text": "13800138000"},
 *       {"action": "assertText", "contains": "验证码"},
 *       {"action": "screenshot", "name": "login"}
 *     ]
 *   }]
 * }
 *
 * 支持的动作：
 *   launch {packageName}        am start 启动 App
 *   tap {selector}              按 resource-id/text/content-desc/bounds 定位点击
 *   input {selector, text}      先 tap 聚焦再 input text
 *   swipe {from, to, duration?} 滑动（坐标数组）
 *   back {}                     返回键
 *   wait {ms}                   固定等待
 *   assertText {contains}       当前界面含文本
 *   assertElement {selector}    元素存在
 *   screenshot {name}           截图取证
 */

'use strict';

const fs = require('fs');
const { execFileSync } = require('child_process');

// ── ADB 定位 ──
function findAdb() {
  const candidates = [
    process.env.ADB_PATH,
    '/opt/homebrew/bin/adb',
    '/usr/local/bin/adb',
    '/Applications/BlueStacks.app/Contents/MacOS/hd-adb',
  ].filter(Boolean);
  for (const c of candidates) {
    try { fs.accessSync(c, fs.constants.X_OK); return c; } catch (_) {}
  }
  // 兜底：PATH 里找
  try { return execFileSync('which', ['adb'], { encoding: 'utf8' }).trim(); } catch (_) {}
  console.error('❌ 未找到 adb，设置 ADB_PATH 环境变量或安装到 PATH');
  process.exit(1);
}

const ADB = findAdb();

// ── adb 命令封装（带超时，同步执行避免并发状态错乱）──
function adb(args, { timeoutMs = 20000 } = {}) {
  try {
    return execFileSync(ADB, args, { encoding: 'utf8', timeout: timeoutMs, maxBuffer: 10 * 1024 * 1024 });
  } catch (err) {
    const msg = err.stderr ? err.stderr.toString().trim() : err.message;
    throw new Error(`adb ${args.join(' ')} 失败：${msg}`);
  }
}

function adbShell(cmd, opts) { return adb(['shell', cmd], opts); }

// ── 超时 sleep ──
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ── uiautomator dump 解析 ──
function dumpNodes() {
  // dump 到设备文件再 pull，避免 stdout 编码问题
  adbShell('uiautomator dump /sdcard/ui.xml', { timeoutMs: 15000 });
  const xml = adb(['shell', 'cat', '/sdcard/ui.xml'], { timeoutMs: 10000 });
  const nodes = [];
  // 解析 <node .../> 的关键属性
  const re = /<node\b[^>]*?(?:\/>|><\/node>)/g;
  let m;
  while ((m = re.exec(xml)) !== null) {
    const tag = m[0];
    const get = (k) => {
      const r = new RegExp(`\\b${k}="([^"]*)"`).exec(tag);
      return r ? r[1] : '';
    };
    const bounds = get('bounds');
    // bounds=[x1,y1][x2,y2] → 中心点
    let center = null;
    const bm = /\[(\d+),(\d+)\]\[(\d+),(\d+)\]/.exec(bounds);
    if (bm) {
      center = [Math.round((+bm[1] + +bm[3]) / 2), Math.round((+bm[2] + +bm[4]) / 2)];
    }
    const resourceId = get('resource-id');
    const text = get('text');
    const contentDesc = get('content-desc');
    const clickable = get('clickable') === 'true';
    // 只收可交互或有标识的节点
    if (clickable || resourceId || text || contentDesc) {
      nodes.push({ resourceId, text, contentDesc, clickable, bounds, center });
    }
  }
  return nodes;
}

// ── 按 selector 定位节点 → 坐标 ──
function locate(selector, nodes) {
  if (selector.resourceId) {
    const n = nodes.find((n) => n.resourceId === selector.resourceId);
    if (n && n.center) return n.center;
  }
  if (selector.text) {
    const n = nodes.find((n) => n.text === selector.text || (n.text && n.text.includes(selector.text)));
    if (n && n.center) return n.center;
  }
  if (selector.contentDesc) {
    const n = nodes.find((n) => n.contentDesc === selector.contentDesc || (n.contentDesc && n.contentDesc.includes(selector.contentDesc)));
    if (n && n.center) return n.center;
  }
  if (selector.bounds) {
    const bm = /\[(\d+),(\d+)\]\[(\d+),(\d+)\]/.exec(selector.bounds);
    if (bm) return [Math.round((+bm[1] + +bm[3]) / 2), Math.round((+bm[2] + +bm[4]) / 2)];
  }
  if (selector.center) return selector.center;
  return null;
}

class Runner {
  constructor(plan) {
    this.packageName = plan.packageName;
    this.deviceId = plan.deviceId;
    this.stepTimeoutMs = plan.stepTimeoutMs || 20000;
  }

  async runStep(step) {
    try {
      switch (step.action) {
        case 'launch': {
          const pkg = step.packageName || this.packageName;
          adbShell(`monkey -p ${pkg} -c android.intent.category.LAUNCHER 1`, { timeoutMs: this.stepTimeoutMs });
          await sleep(1500); // 等启动
          return { ok: true, detail: `launch ${pkg}` };
        }
        case 'tap': {
          const nodes = dumpNodes();
          const coord = locate(step.selector, nodes);
          if (!coord) throw new Error(`定位失败：${JSON.stringify(step.selector)}`);
          adbShell(`input tap ${coord[0]} ${coord[1]}`, { timeoutMs: this.stepTimeoutMs });
          await sleep(500);
          return { ok: true, detail: `tap (${coord[0]},${coord[1]})` };
        }
        case 'input': {
          const nodes = dumpNodes();
          const coord = locate(step.selector, nodes);
          if (!coord) throw new Error(`定位失败：${JSON.stringify(step.selector)}`);
          adbShell(`input tap ${coord[0]} ${coord[1]}`, { timeoutMs: this.stepTimeoutMs });
          await sleep(300);
          // input text 不支持中文/特殊字符，仅 ASCII；中文场景后续接广播兜底
          adbShell(`input text "${String(step.text).replace(/["\\]/g, '\\$&')}"`, { timeoutMs: this.stepTimeoutMs });
          return { ok: true, detail: `input ${step.text}` };
        }
        case 'swipe': {
          const [x1, y1] = step.from;
          const [x2, y2] = step.to;
          const dur = step.duration || 300;
          adbShell(`input swipe ${x1} ${y1} ${x2} ${y2} ${dur}`, { timeoutMs: this.stepTimeoutMs });
          await sleep(300);
          return { ok: true, detail: `swipe` };
        }
        case 'back':
          adbShell('input keyevent 4', { timeoutMs: this.stepTimeoutMs });
          await sleep(300);
          return { ok: true, detail: 'back' };
        case 'wait':
          await sleep(Math.min(step.ms || 1000, 10000));
          return { ok: true, detail: `${step.ms || 1000}ms` };
        case 'assertText': {
          const nodes = dumpNodes();
          const hit = nodes.some((n) => n.text && n.text.includes(String(step.contains)));
          if (!hit) throw new Error(`当前界面未含文本 "${step.contains}"`);
          return { ok: true, detail: `assertText "${step.contains}"` };
        }
        case 'assertElement': {
          const nodes = dumpNodes();
          const coord = locate(step.selector, nodes);
          if (!coord) throw new Error(`元素不存在：${JSON.stringify(step.selector)}`);
          return { ok: true, detail: `assertElement` };
        }
        case 'screenshot': {
          const name = step.name || `s${Date.now()}`;
          const outPath = `screenshots/${name}.png`;
          fs.mkdirSync('screenshots', { recursive: true });
          const buf = execFileSync(ADB, ['exec-out', 'screencap', '-p'], { timeout: 15000, maxBuffer: 20 * 1024 * 1024 });
          fs.writeFileSync(outPath, buf);
          return { ok: true, detail: outPath };
        }
        default:
          throw new Error(`未知 action: ${step.action}`);
      }
    } catch (err) {
      return { ok: false, detail: `${step.action} 失败：${err.message}` };
    }
  }

  async evidence() {
    try {
      const name = `fail-${Date.now()}`;
      const outPath = `screenshots/${name}.png`;
      fs.mkdirSync('screenshots', { recursive: true });
      const buf = execFileSync(ADB, ['exec-out', 'screencap', '-p'], { timeout: 15000, maxBuffer: 20 * 1024 * 1024 });
      fs.writeFileSync(outPath, buf);
      let dump = '';
      try { dump = dumpNodes().slice(0, 20).map((n) => `${n.resourceId || n.text} @ ${n.bounds}`).join('\n'); } catch (_) {}
      return { screenshot: outPath, dump };
    } catch (err) {
      return { error: `取证失败: ${err.message}` };
    }
  }
}

async function main() {
  const args = process.argv.slice(2);
  const planFile = args.includes('--plan') ? args[args.indexOf('--plan') + 1] : null;
  const outFile = args.includes('--out') ? args[args.indexOf('--out') + 1] : null;
  const checkOnly = args.includes('--check');
  const snapshotMode = args.includes('--snapshot');
  const installApk = args.includes('--install') ? args[args.indexOf('--install') + 1] : null;

  if (!planFile && !checkOnly && !snapshotMode && !installApk) {
    console.error('用法：node android-run.cjs --check | --snapshot [--out] | --plan plan.json [--out] | --install <apk>');
    process.exit(1);
  }

  // 指定 deviceId 时先 connect
  if (planFile) {
    const plan = JSON.parse(fs.readFileSync(planFile, 'utf8'));
    if (plan.deviceId) { try { adb(['connect', plan.deviceId]); } catch (_) {} }
  }

  // 全局看门狗
  const budgetMs = 15 * 60 * 1000;
  setTimeout(() => { console.error(`❌ 全局看门狗触发（${budgetMs}ms），强制退出——疑似 ADB 挂起`); process.exit(2); }, budgetMs).unref();

  try {
    if (installApk) {
      console.log(`→ 安装 ${installApk}...`);
      const out = adb(['install', '-r', installApk], { timeoutMs: 120000 });
      console.log(`✓ 安装完成：${out.split('\n').pop().trim()}`);
      return;
    }

    if (checkOnly) {
      const device = adb(['get-state'], { timeoutMs: 5000 }).trim();
      const version = adbShell('getprop ro.build.version.release', { timeoutMs: 5000 }).trim();
      console.log(`✓ 探活成功：设备 ${device}，Android ${version}`);
      return;
    }

    if (snapshotMode) {
      const nodes = dumpNodes();
      const snap = { elements: nodes.slice(0, 80).map((n) => ({
        resourceId: n.resourceId, text: n.text, contentDesc: n.contentDesc,
        clickable: n.clickable, bounds: n.bounds, center: n.center,
      })) };
      if (outFile) fs.writeFileSync(outFile, JSON.stringify(snap, null, 2), 'utf8');
      console.log(`✓ 快照完成：${snap.elements.length} 个可交互节点${outFile ? `，已存 ${outFile}` : ''}`);
      console.log('SNAPSHOT_JSON=' + JSON.stringify(snap));
      return;
    }

    const plan = JSON.parse(fs.readFileSync(planFile, 'utf8'));
    const runner = new Runner(plan);
    const scenarios = plan.scenarios || [];
    if (!Array.isArray(scenarios) || scenarios.length === 0) {
      throw new Error('plan.json 无 scenarios——拒绝执行空测试计划');
    }
    const summary = { scenarios: [], startedAt: new Date().toISOString() };
    let failed = 0;

    for (const sc of scenarios) {
      console.log(`\n【场景】${sc.name}（${sc.priority || 'P1'}）`);
      const result = { name: sc.name, priority: sc.priority || 'P1', steps: [], ok: true };
      for (let i = 0; i < (sc.steps || []).length; i++) {
        const step = sc.steps[i];
        const r = await runner.runStep(step);
        result.steps.push({ action: step.action, ...r });
        console.log(`  ${r.ok ? '✓' : '✗'} ${r.detail}`);
        if (!r.ok) {
          result.ok = false;
          result.evidence = await runner.evidence();
          break;
        }
      }
      result.ok ? console.log(`  场景结果：✓ 通过`) : (failed++, console.log(`  场景结果：✗ 失败`));
      summary.scenarios.push(result);
    }

    summary.finishedAt = new Date().toISOString();
    summary.passed = summary.scenarios.length - failed;
    summary.failed = failed;
    if (outFile) fs.writeFileSync(outFile, JSON.stringify(summary, null, 2), 'utf8');
    console.log(`\n═══ 结果：通过 ${summary.passed} / 失败 ${summary.failed}（共 ${summary.scenarios.length} 场景）${outFile ? `，详情 ${outFile}` : ''} ═══`);
    console.log('RESULT_JSON=' + JSON.stringify(summary));
    process.exitCode = failed > 0 ? 1 : 0;
  } catch (err) {
    console.error(`❌ ${err.message}`);
    process.exitCode = 2;
  }
}

main();
````

- [ ] **Step 2: 双写到安装副本**

```bash
cp /Users/caomunian/Study/cwork/skills/test/scripts/android-run.cjs /Users/caomunian/Study/cwork/.cwork/refs/cwork-test/scripts/android-run.cjs
diff /Users/caomunian/Study/cwork/skills/test/scripts/android-run.cjs /Users/caomunian/Study/cwork/.cwork/refs/cwork-test/scripts/android-run.cjs && echo "✓ 双写一致"
```

- [ ] **Step 3: 语法自检**

```bash
node --check /Users/caomunian/Study/cwork/skills/test/scripts/android-run.cjs && echo "✓ 语法OK"
```

- [ ] **Step 4: 记 USAGE_NOTES**

在 `skills/USAGE_NOTES.md`「未分析」区追加一行：
```
- [2026-11-01] [test] 新增 android-run.cjs，BlueStacks5+ADB 驱动，对齐官方 Skill 能力 | 待实测 uiautomator dump 解析稳定性
```

- [ ] **Step 5: Commit**

```bash
git add skills/test/scripts/android-run.cjs .cwork/refs/cwork-test/scripts/android-run.cjs skills/USAGE_NOTES.md
git commit -m "【cwork-test 安卓链路】<feat> 新增 android-run.cjs 执行器：ADB 驱动 BlueStacks5

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 3: SKILL.md 加安卓识别与链路入口

**Files:**
- Modify: `skills/test/SKILL.md`（识别表+识别脚本+链路入口）
- Modify: `.cwork/refs/cwork-test/SKILL.md`（双写）

- [ ] **Step 1: 改源 SKILL.md 概述表**

将 `skills/test/SKILL.md` 第 14–17 行的识别表：

```
| 项目类型 | 识别条件 | 驱动引擎 | 测试链路 |
|---------|---------|---------|---------|
| **微信小程序** | 存在 `project.config.json` 且含 `appid` | miniprogram-automator（直连） | 小程序链路 |
| **Web 应用** | 存在 `package.json`（无小程序配置） | ego-browser（web-run.cjs 执行器） | Web 链路 |
```

改为：

```
| 项目类型 | 识别条件 | 驱动引擎 | 测试链路 |
|---------|---------|---------|---------|
| **安卓应用** | 显式 `--android` / `*.apk` / adb 已连 BlueStacks | ADB 直连 BlueStacks 5 | 安卓链路 |
| **微信小程序** | 存在 `project.config.json` 且含 `appid` | miniprogram-automator（直连） | 小程序链路 |
| **Web 应用** | 存在 `package.json`（无小程序配置） | ego-browser（web-run.cjs 执行器） | Web 链路 |
```

- [ ] **Step 2: 改识别脚本**

将 `skills/test/SKILL.md` 第 48–56 行的识别脚本：

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

改为：

```bash
# ① 优先检测安卓（显式 --android / *.apk / adb 已连 BlueStacks）
if echo "$@" | grep -q -- '--android' || ls *.apk 2>/dev/null | grep -q . || adb devices 2>/dev/null | grep -q "device$"; then
    PROJECT_TYPE="android"
    echo "识别为安卓应用，走安卓测试链路（BlueStacks5+ADB）"
# ② 其次检测小程序
elif [ -f "project.config.json" ] && grep -q '"appid"' project.config.json; then
    PROJECT_TYPE="mini"
    echo "识别为微信小程序项目，走小程序测试链路"
else
    PROJECT_TYPE="web"
    echo "识别为 Web 项目，走 Web 测试链路"
fi
```

- [ ] **Step 3: 改识别输出与链路入口**

将识别输出模板 `→ 项目类型：{mini/web}` 改为 `→ 项目类型：{android/mini/web}`，`→ 驱动引擎` 增加 `adb + BlueStacks 5`。

在小程序链路章节后、通用阶段前，加安卓链路入口：

```markdown
---

# 安卓测试链路

> **按需加载**：PROJECT_TYPE=android 时 Read 同目录 `android-test.md`，不随本文件全量加载。

---
```

- [ ] **Step 4: HARD GATE 加安卓条目**

在 SKILL.md 的 HARD GATE 段，`小程序：` 条目后加：

```
- **安卓**：BlueStacks 5 未安装 / ADB 不可用 / `adb devices` 无在线设备 / 目标包未安装且无 APK 路径，禁止执行测试
```

- [ ] **Step 5: 双写并校验**

```bash
cp /Users/caomunian/Study/cwork/skills/test/SKILL.md /Users/caomunian/Study/cwork/.cwork/refs/cwork-test/SKILL.md
diff /Users/caomunian/Study/cwork/skills/test/SKILL.md /Users/caomunian/Study/cwork/.cwork/refs/cwork-test/SKILL.md && echo "✓ 双写一致"
```

- [ ] **Step 6: Commit**

```bash
git add skills/test/SKILL.md .cwork/refs/cwork-test/SKILL.md
git commit -m "【cwork-test 安卓链路】<feat> SKILL.md 加安卓识别+链路入口+HARD GATE

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## 阶段二：小程序执行器加速（A 线）

### Task 4: mini-run.cjs 快照批量化（去逐元素 RPC）

**Files:**
- Modify: `skills/test/scripts/mini-run.cjs:210-251`（snapshot 方法）
- Modify: `.cwork/refs/cwork-test/scripts/mini-run.cjs`（双写）

**问题**：当前 snapshot 对每个元素调 `el.tagName()/el.text()/el.attrs()` 三次 automator RPC，80 个元素 = 240 次 RPC，这是慢点根因。

- [ ] **Step 1: 改 snapshot 方法为批量 evaluate**

将 `skills/test/scripts/mini-run.cjs` 第 211–251 行的 `snapshot()` 方法替换为：

```javascript
  // 快照：当前页 path + data + 可交互元素清单（批量 evaluate，去逐元素 RPC）
  async snapshot() {
    const page = await this.currentPage();
    const pagePath = (page && page.path) ? await this.t(page.path, 'snapshot-path') : '';
    let pageData = {};
    try { pageData = await this.t(page.data(), 'snapshot-data'); } catch (_) { /* data 不可读不影响快照 */ }

    const interactiveSelector = [
      'button', 'input', 'textarea', 'navigator', 'picker',
      'switch', 'slider', 'radio', 'checkbox', 'label[for]',
      'image[data-src]', '[bindtap]', '[catchtap]', '[data-url]',
    ].join(',');

    let elements = [];
    try {
      // 一次 evaluate 拉全部元素的 tag/text/attrs，替代逐元素 3 次 RPC
      const raw = await this.t(this.mp.evaluate((sel) => {
        const qs = document.querySelectorAll(sel);
        const out = [];
        for (let i = 0; i < Math.min(qs.length, 80); i++) {
          const el = qs[i];
          const attrs = {};
          for (const a of el.attributes) attrs[a.name] = a.value;
          out.push({ tag: el.tagName, text: el.innerText || '', attrs });
        }
        return out;
      }, interactiveSelector), 'snapshot-elements-batch');
      if (Array.isArray(raw)) {
        for (const item of raw) {
          try {
            const tag = item.tag || '';
            const text = (item.text || '').trim().slice(0, 60);
            const attrs = item.attrs || {};
            const selector = this._buildSelector(tag, attrs, text);
            elements.push({
              tag, text, selector,
              placeholder: attrs.placeholder || '',
              type: attrs.type || '',
              id: attrs.id || '',
              className: attrs.class || '',
            });
          } catch (_) { /* 单个解析失败不影响整体 */ }
        }
      }
    } catch (_) {
      // evaluate 批量失败时回退逐元素（兼容旧 automator 版本）
      try {
        const els = await this.t(page.$$(interactiveSelector), 'snapshot-elements-fallback');
        if (els && els.length > 0) {
          const limit = Math.min(els.length, 80);
          for (let i = 0; i < limit; i++) {
            try {
              const el = els[i];
              const tag = (await this.t(el.tagName(), `snapshot-tag-${i}`)) || '';
              const text = (await this.t(el.text(), `snapshot-text-${i}`)) || '';
              const attrs = (await this.t(el.attrs(), `snapshot-attrs-${i}`)) || {};
              const selector = this._buildSelector(tag, attrs, text);
              elements.push({ tag, text: text.trim().slice(0, 60), selector, placeholder: attrs.placeholder || '', type: attrs.type || '', id: attrs.id || '', className: attrs.class || '' });
            } catch (_) {}
          }
        }
      } catch (_) { /* 元素查询失败不阻塞快照 */ }
    }

    return { path: pagePath, data: pageData, elements };
  }
```

- [ ] **Step 2: 双写并语法自检**

```bash
cp /Users/caomunian/Study/cwork/skills/test/scripts/mini-run.cjs /Users/caomunian/Study/cwork/.cwork/refs/cwork-test/scripts/mini-run.cjs
node --check /Users/caomunian/Study/cwork/skills/test/scripts/mini-run.cjs && echo "✓ 语法OK"
diff /Users/caomunian/Study/cwork/skills/test/scripts/mini-run.cjs /Users/caomunian/Study/cwork/.cwork/refs/cwork-test/scripts/mini-run.cjs && echo "✓ 双写一致"
```

- [ ] **Step 3: Commit**

```bash
git add skills/test/scripts/mini-run.cjs .cwork/refs/cwork-test/scripts/mini-run.cjs
git commit -m "【cwork-test 小程序加速】<perf> 快照批量化：一次 evaluate 取全部元素，去逐元素 3×N 次 RPC

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 5: mini-run.cjs 固定 sleep → 条件等待

**Files:**
- Modify: `skills/test/scripts/mini-run.cjs:100-118`（navigate 轮询）、`138-147`（click/input sleep）
- Modify: `.cwork/refs/cwork-test/scripts/mini-run.cjs`（双写）

- [ ] **Step 1: navigate 后轮询改自适应**

将第 110 行 `await sleep(300);` 的固定 300ms 轮询改为：首轮 100ms，后续 200ms，命中即提前返回（已有轮询逻辑，仅缩短首次等待与命中返回路径）。实际改动：把 `await sleep(300)` 改为 `await sleep(i === 0 ? 100 : 200)`。

- [ ] **Step 2: click 后条件等待**

将第 141 行 `await sleep(300); // 等 UI 反馈/页面切换` 改为条件等待函数调用：

```javascript
        case 'click': {
          const el = await this.findElement(step.selector, step.index);
          await this.t(el.tap(), `点击 ${step.selector}`);
          await this._waitForSettle(300, 1500);
          return { ok: true, detail: step.selector };
        }
```

并在 `findElement` 方法后新增 `_waitForSettle`：

```javascript
  // 等 UI 稳定：先等 minMs，再轮询页面 path 变化，命中或超 maxMs 返回
  async _waitForSettle(minMs, maxMs) {
    await sleep(minMs);
    const start = Date.now();
    let lastPath = '';
    try { const p = await this.currentPage(); lastPath = (p && p.path) ? await this.t(p.path, 'settle-path') : ''; } catch (_) {}
    while (Date.now() - start < maxMs - minMs) {
      await sleep(150);
      try {
        const p = await this.currentPage();
        const cur = (p && p.path) ? await this.t(p.path, 'settle-path') : '';
        if (cur && cur !== lastPath) return; // 页面已切换
      } catch (_) { /* 切换中，继续 */ }
    }
  }
```

- [ ] **Step 3: 双写并自检**

```bash
cp /Users/caomunian/Study/cwork/skills/test/scripts/mini-run.cjs /Users/caomunian/Study/cwork/.cwork/refs/cwork-test/scripts/mini-run.cjs
node --check /Users/caomunian/Study/cwork/skills/test/scripts/mini-run.cjs && echo "✓ 语法OK"
diff /Users/caomunian/Study/cwork/skills/test/scripts/mini-run.cjs /Users/caomunian/Study/cwork/.cwork/refs/cwork-test/scripts/mini-run.cjs && echo "✓ 双写一致"
```

- [ ] **Step 4: Commit**

```bash
git add skills/test/scripts/mini-run.cjs .cwork/refs/cwork-test/scripts/mini-run.cjs
git commit -m "【cwork-test 小程序加速】<perf> click 后条件等待替代固定 sleep，页面切换即提前返回

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 6: mini-run.cjs 多页快照合并 + 耗时埋点

**Files:**
- Modify: `skills/test/scripts/mini-run.cjs`（main 函数加 `--snapshot-pages` 模式 + 阶段耗时输出）
- Modify: `.cwork/refs/cwork-test/scripts/mini-run.cjs`（双写）

- [ ] **Step 1: main 加多页快照模式**

在 `main()` 的参数解析段（第 280 行附近）加：

```javascript
  const snapshotPagesArg = args.includes('--snapshot-pages') ? args[args.indexOf('--snapshot-pages') + 1] : null;
```

在 `snapshotMode` 分支后加：

```javascript
    if (snapshotPagesArg) {
      // 一次连接导航+多页快照，pages 形如 "pageA,pageB,pageC"
      const pages = snapshotPagesArg.split(',').map((s) => s.trim()).filter(Boolean);
      const runner = new Runner(mp, stepTimeoutMs);
      const snaps = [];
      for (const p of pages) {
        await runner.navigate({ url: '/' + p.replace(/^\/+/, '') });
        const s = await runner.snapshot();
        snaps.push(s);
      }
      if (outFile) fs.writeFileSync(outFile, JSON.stringify(snaps, null, 2), 'utf8');
      console.log(`✓ 多页快照完成：${pages.length} 页${outFile ? `，已存 ${outFile}` : ''}`);
      console.log('SNAPSHOT_JSON=' + JSON.stringify(snaps));
      return;
    }
```

- [ ] **Step 2: 阶段耗时埋点**

在 `main()` 连接成功后加计时：

```javascript
    const t0 = Date.now();
```

各模式结束前输出：

```javascript
      console.log(`⏱ 耗时：${Date.now() - t0}ms`);
```

- [ ] **Step 3: 双写并自检**

```bash
cp /Users/caomunian/Study/cwork/skills/test/scripts/mini-run.cjs /Users/caomunian/Study/cwork/.cwork/refs/cwork-test/scripts/mini-run.cjs
node --check /Users/caomunian/Study/cwork/skills/test/scripts/mini-run.cjs && echo "✓ 语法OK"
diff /Users/caomunian/Study/cwork/skills/test/scripts/mini-run.cjs /Users/caomunian/Study/cwork/.cwork/refs/cwork-test/scripts/mini-run.cjs && echo "✓ 双写一致"
```

- [ ] **Step 4: 更新 mini-test.md 文档**

在 `skills/test/mini-test.md` 的「多页面快照」段（第 304 行附近）加：

```markdown
**多页快照合并**（推荐）：一次连接导航+多页快照，替代反复起进程：

```bash
node mini-run.cjs --snapshot-pages "pages/login/login,pages/index/index" --out snaps.json
```
```

- [ ] **Step 5: 双写 mini-test.md**

```bash
cp /Users/caomunian/Study/cwork/skills/test/mini-test.md /Users/caomunian/Study/cwork/.cwork/refs/cwork-test/mini-test.md
diff /Users/caomunian/Study/cwork/skills/test/mini-test.md /Users/caomunian/Study/cwork/.cwork/refs/cwork-test/mini-test.md && echo "✓ 双写一致"
```

- [ ] **Step 6: 记 USAGE_NOTES 并 Commit**

```bash
# USAGE_NOTES 追加
cat >> /Users/caomunian/Study/cwork/skills/USAGE_NOTES.md <<'EOF'
- [2026-11-01] [test] 小程序快照批量化+条件等待+多页合并+耗时埋点 | 实测前后对比耗时
EOF
git add skills/test/scripts/mini-run.cjs .cwork/refs/cwork-test/scripts/mini-run.cjs skills/test/mini-test.md .cwork/refs/cwork-test/mini-test.md skills/USAGE_NOTES.md
git commit -m "【cwork-test 小程序加速】<perf> 多页快照合并+阶段耗时埋点+文档

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## 阶段三：借鉴 impeccable 增强 implement 前端设计（B 线）

### Task 7: design-guide.md 加品牌/产品分模式 + 反 AI slop 黑名单

**Files:**
- Modify: `skills/implement/design-guide.md`
- Modify: `.cwork/refs/cwork-implement/design-guide.md`（双写）

- [ ] **Step 1: 设计面试第一问加模式判定**

将 `skills/implement/design-guide.md` 第 42–48 行的 Q1：

```markdown
**Q1 — 产品类型**

> "这是什么类型的产品？"

选项：SaaS 应用 / 开发工具 / 消费级应用 / 营销官网 / 内部工具 / 组件库

追问："主要界面是数据看板，还是用户操作流程？"
```

改为：

```markdown
**Q1 — 产品类型与模式**

> "这是什么类型的产品？"

选项：SaaS 应用 / 开发工具 / 消费级应用 / 营销官网 / 内部工具 / 组件库

追问："主要界面是数据看板，还是用户操作流程？"

**模式判定（第一问就必须定，后续准则按模式走）**：

| 模式 | 适用 | 审美取向 |
|------|------|---------|
| **品牌模式** | 营销官网、着陆页、活动页 | 允许强视觉、大字号、动效、情感化文案 |
| **产品模式** | App、后台、仪表盘、内部工具 | 克制、信息密度、零装饰、功能优先 |

营销官网选品牌模式；其余默认产品模式。模式定下后，反 slop 清单与准则按模式差异化应用。
```

- [ ] **Step 2: 在「设计准则（编码时遵循）」段前新增反 slop 黑名单小节**

在第 245 行 `## 设计准则（编码时遵循）` 前插入：

```markdown
## 反 AI slop 黑名单（强约束，判定即拒）

> 借鉴 impeccable 的反 "AI slop" 思想。这些是 AI 生成 UI 的高发套路，**判定即拒，非建议**，不可商量。

### 产品模式禁用（出现即拒）

| 反例 | 判定 |
|------|------|
| 紫蓝渐变堆叠 | 背景或按钮用 `purple → blue` 渐变且无品牌依据 |
| 无节制玻璃拟态 | 多层 `backdrop-filter: blur` 叠加，遮盖内容 |
| 过曝白卡 | 大面积纯白卡片 + 重投影，无层次 |
| hover 缩放弹簧 | `transform: scale(1.05)` + `transition: cubic-bezier` 弹簧 |
| 装饰性阴影 | 非交互元素加 drop-shadow / glow |
| 荧光高亮 | 满屏 `box-shadow` 荧光描边 |

### 品牌模式慎用（允许但需有品牌依据）

- 渐变：必须有品牌色卡支撑，禁止随手紫蓝
- 动效：允许，但必须传达含义（进入/强调），禁止装饰性弹跳
- 大字号：允许 hero 标题，正文仍走产品字号体系
```

- [ ] **Step 3: 在「矛盾检测」段加支柱清单引用**

在第 174 行 `## 阶段二：矛盾检测` 后补一句：

```markdown
> 矛盾检测后，按「设计准则」段的 **7 支柱清单**（排版/色彩/空间/响应式/交互/动效/UX 文案）逐项过一遍，缺口补到 DESIGN-BRIEF.md。
```

- [ ] **Step 4: 双写并校验**

```bash
cp /Users/caomunian/Study/cwork/skills/implement/design-guide.md /Users/caomunian/Study/cwork/.cwork/refs/cwork-implement/design-guide.md
diff /Users/caomunian/Study/cwork/skills/implement/design-guide.md /Users/caomunian/Study/cwork/.cwork/refs/cwork-implement/design-guide.md && echo "✓ 双写一致"
```

- [ ] **Step 5: Commit**

```bash
git add skills/implement/design-guide.md .cwork/refs/cwork-implement/design-guide.md
git commit -m "【implement 前端设计增强】<feat> 借鉴 impeccable：品牌/产品分模式 + 反 AI slop 黑名单

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 8: review-checklist.md 前端设计检查升级为 7 支柱 + critique 评分

**Files:**
- Modify: `skills/implement/review-checklist.md:53-60`（前端设计检查段）
- Modify: `.cwork/refs/cwork-implement/review-checklist.md`（双写）

- [ ] **Step 1: 前端设计检查 4 项扩为 7 支柱**

将 `skills/implement/review-checklist.md` 第 53–60 行：

```markdown
## 前端设计检查（条件触发，仅前端新工程/新页面，4 项）

| 检查项 | 说明 |
|--------|------|
| 设计系统一致 | 色彩/字体/间距是否使用设计 token，无硬编码值 |
| 无障碍基线 | 对比度 ≥ 4.5:1、键盘导航可达、aria 属性完整 |
| 响应式基线 | 移动优先断点、无横向滚动、触控目标 ≥ 44×44px |
| 交互动效合理 | 动画时长 150-300ms、动效传达含义、支持 reduced-motion |
```

改为：

```markdown
## 前端设计检查（条件触发，仅前端新工程/新页面，7 支柱）

> 借鉴 impeccable 的 7 设计支柱思想，把"审美"拆成可逐项机械核对的维度。
> 每支柱给判定标准 + 反例。**任一支柱 0 分即判「审美未过」，列改进项再收敛。**

| 支柱 | 判定标准 | 反例（0 分） |
|------|---------|-------------|
| 排版 | 字号体系 ≤ 6 档，字重靠层级非膨胀 | 出现 18+ UI 字号、同一层级 3 种字重 |
| 色彩 | 全走 token，品牌色有依据 | 紫蓝渐变无品牌依据、硬编码色值 |
| 空间 | 间距 4 的倍数体系，无魔法数字 | 随手 `padding: 13px`、无 spacing token |
| 响应式 | 移动优先、无横向滚动、触控 ≥ 44px | 桌面断点先行、出现横向滚动 |
| 交互 | hover 只换色不换尺寸，focus 可见 | hover 缩放弹簧、focus 无样式 |
| 动效 | 150-300ms、传含义、支持 reduced-motion | 装饰性弹跳、无 reduced-motion 兜底 |
| UX 文案 | 暴露收益非动作、最强表述在前 | "点击这里"、营销腔 "Awesome/Welcome" |
```

- [ ] **Step 2: 在前端设计检查后加 critique 评分小节**

在 7 支柱表后追加：

```markdown
### critique 评分（推演收敛阶段对前端页面执行）

> 借鉴 impeccable 的 critique 思想，不引入其命令本身。

前端页面在推演收敛阶段，对 7 支柱逐项打分（0/1/2）：

| 分值 | 含义 |
|------|------|
| 0 | 反例命中或缺失，必须改 |
| 1 | 达标但有改进空间 |
| 2 | 优秀，可作为样板 |

**任一项 0 分即判「审美未过」**，列改进项再收敛，不放过。
输出格式：`支柱: 分值 — 一句理由`，例 `色彩: 0 — 按钮用了紫蓝渐变无品牌依据`。
```

- [ ] **Step 3: 双写并校验**

```bash
cp /Users/caomunian/Study/cwork/skills/implement/review-checklist.md /Users/caomunian/Study/cwork/.cwork/refs/cwork-implement/review-checklist.md
diff /Users/caomunian/Study/cwork/skills/implement/review-checklist.md /Users/caomunian/Study/cwork/.cwork/refs/cwork-implement/review-checklist.md && echo "✓ 双写一致"
```

- [ ] **Step 4: Commit**

```bash
git add skills/implement/review-checklist.md .cwork/refs/cwork-implement/review-checklist.md
git commit -m "【implement 前端设计增强】<feat> 前端检查升级 7 支柱 + critique 评分（借鉴 impeccable）

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 9: DESIGN-BRIEF 模板加产品意图头部

**Files:**
- Modify: `skills/implement/design-guide.md:187-198`（设计简报模板）
- Modify: `.cwork/refs/cwork-implement/design-guide.md`（双写）

- [ ] **Step 1: 简报模板加产品意图字段**

将 `skills/implement/design-guide.md` 第 192–198 行的简报模板头部：

```markdown
# 设计简报 — [产品名称]

## 产品上下文

## 品牌个性
```

改为：

```markdown
# 设计简报 — [产品名称]

## 产品意图（一句话，必填）

> 借鉴 impeccable 的 PRODUCT.md 思想。产品解决什么、给谁用，一句话锁定。意图未定禁止讨论视觉方向。

[产品] 给 [用户] 解决 [问题]，靠 [核心动作]。

## 模式

[ ] 品牌模式  [ ] 产品模式

## 产品上下文

## 品牌个性
```

- [ ] **Step 2: 双写并校验**

```bash
cp /Users/caomunian/Study/cwork/skills/implement/design-guide.md /Users/caomunian/Study/cwork/.cwork/refs/cwork-implement/design-guide.md
diff /Users/caomunian/Study/cwork/skills/implement/design-guide.md /Users/caomunian/Study/cwork/.cwork/refs/cwork-implement/design-guide.md && echo "✓ 双写一致"
```

- [ ] **Step 3: Commit**

```bash
git add skills/implement/design-guide.md .cwork/refs/cwork-implement/design-guide.md
git commit -m "【implement 前端设计增强】<feat> DESIGN-BRIEF 模板加产品意图头部（借鉴 impeccable PRODUCT.md）

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## 阶段四：借鉴 ponytail 增强 implement 编码思想（C 线）

### Task 10: phases.md 方案审查加 lazy senior 三问 + 意图优先硬门

**Files:**
- Modify: `skills/implement/phases.md:422-426`（方案审查目标段）
- Modify: `.cwork/refs/cwork-implement/phases.md`（双写）

- [ ] **Step 1: 方案审查目标段加意图优先硬门**

将 `skills/implement/phases.md` 第 424–428 行：

```markdown
**编写计划后，执行计划前，必须进行方案审查。**

### 审查目标

确保计划合理、完整、可行，避免执行过程中发现问题导致返工。
```

改为：

```markdown
**编写计划后，执行计划前，必须进行方案审查。**

### 意图优先硬门（审查入口，借鉴 ponytail）

> 进入审查前，先锁定一句「要解决什么」（意图），再允许讨论「怎么做」。
> 意图未定，禁止讨论实现选型——避免方案跑偏后才发觉答非所问。

锁定格式：`本方案解决 [问题]，验收标准是 [可判定条件]`。意图锁不住 → 回需求分析，不进审查。

### 审查目标

确保计划合理、完整、可行，避免执行过程中发现问题导致返工。
```

- [ ] **Step 2: 在审查维度后、过度工程审查前加 lazy senior 三问**

在第 480 行 `### 过度工程审查` 前插入：

```markdown
### lazy senior 三问（动手前硬门，借鉴 ponytail）

> 与下方「过度工程审查」正交：过度工程盯「能删什么」，三问盯「该不该动手」。
> 逐条自答，答不上来不准进执行阶段。

| 问 | 自答要求 |
|----|---------|
| 能不能**不写**？ | 需求是否已由现有功能/配置/中间件覆盖？若覆盖，直接复用，不写新代码 |
| 能不能**少写**？ | 能否用更小改动达成？少一个文件/少一个抽象层/少一个配置项 |
| 能不能**复用**？ | 现有组件/工具/接口是否可直接用？有则点名复用对象 |

三问结论记到 changes.md：`lazy senior: 不写/少写/复用 = [结论]`。无结论不准进执行。
```

- [ ] **Step 3: 双写并校验**

```bash
cp /Users/caomunian/Study/cwork/skills/implement/phases.md /Users/caomunian/Study/cwork/.cwork/refs/cwork-implement/phases.md
diff /Users/caomunian/Study/cwork/skills/implement/phases.md /Users/caomunian/Study/cwork/.cwork/refs/cwork-implement/phases.md && echo "✓ 双写一致"
```

- [ ] **Step 4: Commit**

```bash
git add skills/implement/phases.md .cwork/refs/cwork-implement/phases.md
git commit -m "【implement 编码增强】<feat> 方案审查加 lazy senior 三问 + 意图优先硬门（借鉴 ponytail）

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 11: core-os.md 编码方法论加最小改动准则

**Files:**
- Modify: `skills/implement/core-os.md:48-94`（编码思维方法论段）
- Modify: `.cwork/refs/cwork-implement/core-os.md`（双写）

- [ ] **Step 1: 在「方案质询」后新增最小改动准则小节**

在 `skills/implement/core-os.md` 第 87 行 `#### 方案质询` 段后、`#### 每次一个决策` 前插入：

```markdown
#### 最小改动准则（借鉴 ponytail）

老手不堆代码：改最少的代码达成目标，不重构无关部分。

- 动手前先问：能不能不写/少写/复用（见方案审查 lazy senior 三问）
- 发现相邻代码有问题：记到 review-checklist 的「相邻改进建议」，**不顺手改**
- 不为"看起来现代"重构：无关重构是噪音，review 时单独列，改了要用户确认
- 改动面与目标成正比：修一个 bug 只动相关文件，不顺手"清理"周边

```

- [ ] **Step 2: 双写并校验**

```bash
cp /Users/caomunian/Study/cwork/skills/implement/core-os.md /Users/caomunian/Study/cwork/.cwork/refs/cwork-implement/core-os.md
diff /Users/caomunian/Study/cwork/skills/implement/core-os.md /Users/caomunian/Study/cwork/.cwork/refs/cwork-implement/core-os.md && echo "✓ 双写一致"
```

- [ ] **Step 3: Commit**

```bash
git add skills/implement/core-os.md .cwork/refs/cwork-implement/core-os.md
git commit -m "【implement 编码增强】<feat> 编码方法论加最小改动准则（借鉴 ponytail）

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 12: review-checklist.md 过度工程段补「相邻改进建议」

**Files:**
- Modify: `skills/implement/review-checklist.md:62-77`（过度工程检查段）
- Modify: `.cwork/refs/cwork-implement/review-checklist.md`（双写）

- [ ] **Step 1: 在过度工程段后追加相邻改进建议小节**

在 `skills/implement/review-checklist.md` 第 77 行（过度工程段代码图谱辅助那行）后追加：

```markdown
### 相邻改进建议（来自 ponytail 最小改动准则）

> 审查时发现相邻代码有问题但不在本次目标内：**只列不改**，改了要用户确认。
> 与过度工程检查的区别：过度工程盯"能删的复杂度"，这里盯"发现但本次不该动的相邻问题"。

**输出格式**：每条一行 `L<行>: <问题>. 建议: <改法>. 本次不改动。`

例：`L42: 相邻函数命名与职责不符. 建议: 重命名为 queryXxx. 本次不改动.`
```

- [ ] **Step 2: 双写并校验**

```bash
cp /Users/caomunian/Study/cwork/skills/implement/review-checklist.md /Users/caomunian/Study/cwork/.cwork/refs/cwork-implement/review-checklist.md
diff /Users/caomunian/Study/cwork/skills/implement/review-checklist.md /Users/caomunian/Study/cwork/.cwork/refs/cwork-implement/review-checklist.md && echo "✓ 双写一致"
```

- [ ] **Step 3: Commit**

```bash
git add skills/implement/review-checklist.md .cwork/refs/cwork-implement/review-checklist.md
git commit -m "【implement 编码增强】<feat> 过度工程段补相邻改进建议（借鉴 ponytail 最小改动）

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## 阶段五：收尾

### Task 13: 全量双写校验 + CLAUDE.md 技能清单同步

**Files:**
- Verify: 全部双写路径
- Modify: `CLAUDE.md`（cwork-test 技能描述补安卓能力）

- [ ] **Step 1: 全量双写一致性校验**

```bash
cd /Users/caomunian/Study/cwork
for f in test/SKILL.md test/mini-test.md test/android-test.md test/scripts/mini-run.cjs test/scripts/android-run.cjs implement/design-guide.md implement/review-checklist.md implement/phases.md implement/core-os.md; do
  src="skills/$f"
  dst=".cwork/refs/cwork-$(echo $f | cut -d/ -f1)/$(echo $f | cut -d/ -f2-)"
  if diff -q "$src" "$dst" >/dev/null 2>&1; then echo "✓ $f"; else echo "✗ $f 不一致"; fi
done
```

- [ ] **Step 2: CLAUDE.md cwork-test 描述补安卓**

将 `CLAUDE.md` 中 cwork-test 那行：

```
- /cwork-test — 页面自动化测试，自动识别 Web/小程序项目，分别走 ego-browser 或 miniprogram-automator 链路
```

改为：

```
- /cwork-test — 页面自动化测试，自动识别 Web/小程序/安卓项目，分别走 ego-browser / miniprogram-automator / BlueStacks5+ADB 链路
```

> 注意：CLAUDE.md 在「技能清单」和「主流程技能」两处都提到 cwork-test，两处描述都要同步。

- [ ] **Step 3: 记 USAGE_NOTES 收尾条**

在 `skills/USAGE_NOTES.md`「未分析」区追加：

```
- [2026-11-01] [test] 新增安卓链路（android-test.md+android-run.cjs），BlueStacks5+ADB 对齐官方 Skill | 待真机实测 uiautomator dump 解析
- [2026-11-01] [implement] 借鉴 impeccable/ponytail 思想增强前端设计与编码（7支柱/反slop/分模式/critique/三问/意图优先/最小改动） | 实测验证审查流程是否被正确触发
```

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md skills/USAGE_NOTES.md
git commit -m "【cwork-test 安卓 + implement 增强】<chore> CLAUDE.md 同步安卓能力 + 全量双写校验

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## 验收标准对照

| 验收点 | 对应 Task |
|--------|-----------|
| `/cwork-test` 识别安卓并在 BlueStacks 5 跑通 1 条 P0 | Task 1, 2, 3 |
| 小程序多页快照 N→1 连接，单页快照不 O(n) RPC | Task 4, 6 |
| implement 前端设计 7 支柱 + 反 slop + 分模式 | Task 7, 8 |
| implement 推演收敛对前端页面 7 支柱评分 | Task 8 |
| implement 方案审查 lazy senior 三问 + 意图优先 + 最小改动 | Task 10, 11, 12 |
| 全部双写一致 + CLAUDE.md 同步 | Task 13 |

---

## Self-Review 结论

- **Spec 覆盖**：A 线（安卓链路 §2 + 小程序加速 §1）、B 线（impeccable 五点）、C 线（ponytail 三点）均有对应 Task，无遗漏。
- **占位符扫描**：无 TBD/TODO，每个代码步骤含完整代码。
- **类型一致性**：android-run.cjs 的 `Runner`/`locate`/`dumpNodes` 与 plan.json action 名一致；mini-run.cjs 改动复用现有 `_buildSelector`/`withTimeout`/`sleep`。
- **双写路径**：每个 Task 均含源→副本 cp + diff 校验步骤。
- **B/C 借鉴边界**：未引入 impeccable 命令体系/live overlay，未引入 ponytail 命令/人格包装，只吸收思想挂进现有文件。
