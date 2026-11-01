# 设计：cwork-test 安卓链路 + 小程序加速 + implement 前端设计/编码思想增强

- 日期：2026-11-01
- 状态：已通过，转实现

## 背景

- `cwork-test` 现支持 Web（ego-browser）与微信小程序（miniprogram-automator）两条链路，无安卓能力。
- 用户希望「测试安卓 App」时结合 BlueStacks。经核实：
  - 本机为 macOS + BlueStacks 5（5.21.755）。
  - BlueStacks 官方 AI Agent Skill 依赖 **BlueStacks Desktop（Android 16）**，目前仅 Windows，Mac 尚未发布。
  - 决策：Mac 上用 **ADB 自研驱动**，能力对齐官方 Skill，不依赖 Desktop/Windows。
- 小程序测试实测较慢，需在执行器层加速。
- 写页面/做设计时希望保证审美：借鉴 [impeccable](https://github.com/pbakaus/impeccable) 思想增强 implement 前端设计。
- 写代码时借鉴 [ponytail](https://github.com/dietrichgebert/ponytail) 的 lazy senior dev 思想增强 implement 编码。
- 借鉴边界：**只吸收思想，不搬运命令体系/插件/live overlay/人格包装**。

## 线 A：cwork-test 安卓链路 + 小程序加速

### A-1 总体架构

`cwork-test` 由双链路扩展为三链路，共用四阶段外壳（环境准备 → 测试规划 → 测试执行 → 结果报告）与自问自答/HARD GATE/自动衔接。

```
cwork-test
 ├─ 识别层（启动时只选一条）
 │    mini    → project.config.json + appid
 │    web     → package.json（无小程序配置）
 │    android → *.apk / --android / adb 已连 BlueStacks（新增）
 │
 ├─ Web      → web-test.md  + web-run.cjs
 ├─ 小程序   → mini-test.md + mini-run.cjs（本轮加速改造）
 └─ 安卓     → android-test.md + android-run.cjs（新增，ADB 对齐官方 Skill）
```

### A-2 安卓驱动能力边界（对齐官方 Skill，不依赖 Desktop）

| 官方 Skill 能力 | 本机实现 |
|----------------|----------|
| 打开/切换 App | `adb shell am start` / `monkey -p` |
| 点击/滑动 | `adb shell input tap/swipe` |
| 输入文本 | `adb shell input text`（特殊字符走广播/clipper 兜底） |
| 安装 APK | `adb install -r` |
| 截图 | `adb exec-out screencap -p` |
| 读界面结构 | `uiautomator dump` → 解析 resource-id/text/content-desc/bounds |

第一期不做：OCR 视觉点击、多设备并行、Appium、真机农场、Play Store 自动搜索安装。

### A-3 识别与 HARD GATE

识别顺序：

1. 显式 `--android` / 用户说测安卓 App → android
2. 否则有 `project.config.json`+appid → mini
3. 否则有 `*.apk` 且无前端强特征 → 询问是否走 android（默认否，避免误伤）
4. 否则 → web

HARD GATE（不满足禁止执行）：

- BlueStacks 5 已安装且进程可拉起
- ADB 可用（优先 `PATH` 的 `adb`，回退 BlueStacks 自带 `hd-adb`）
- `adb connect 127.0.0.1:<port>` 成功且 `adb devices` 出现 `device`
- 有待测 APK 路径，或设备上已安装目标 `packageName`
- BlueStacks 高级设置里 ADB 已开启（检测失败给修复话术）

### A-4 环境准备

1. 检测 BlueStacks / adb
2. 未运行则拉起 BlueStacks.app，轮询 adb devices（上限 ~60s）
3. `adb connect 127.0.0.1:<port>`（端口从 BlueStacks 配置或常见 5555/5556 探测）
4. 可选：`adb install -r <apk>`
5. `--check`：输出 deviceId / 安卓版本 / 已装包名是否存在
6. `--snapshot`：uiautomator dump → 解析可点击节点（resource-id/text/content-desc/bounds）

### A-5 plan.json（安卓）

与小程序同形，换 action 语义：

```json
{
  "deviceId": "127.0.0.1:5555",
  "packageName": "com.example.app",
  "stepTimeoutMs": 15000,
  "scenarios": [{
    "name": "打开并登录",
    "priority": "P0",
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

选择器优先级（禁止盲猜坐标为唯一手段）：

1. `resourceId`
2. `text` / `contentDesc`
3. `bounds` 中心点点击（仅当上二者不可用，且必须来自当次 snapshot）

### A-6 android-run.cjs 命令面

| 命令 | 作用 |
|------|------|
| `--check` | 设备探活 |
| `--snapshot [--out]` | 当前界面节点清单 |
| `--plan plan.json [--out]` | 一次连接跑完所有场景 |
| `--install <apk>` | 安装/覆盖安装 |

失败取证：自动截图 + 当前 window dump；接口类问题仍可衔 cwork-log。

### A-7 与官方 Skill 的关系（写进 android-test.md）

- Windows + BlueStacks Desktop：可选用官方 Skill 做人机探索；**结构化回归仍以 android-run 为准**（可复现、可出 result.json）
- Mac：只走 android-run
- 官方 Skill 能力表作为验收对照，不作为运行时依赖

### A-8 小程序加速（按收益排序）

1. **快照批量化**：元素 tag/text/attrs 改为一次 evaluate 拉取，去掉逐元素 RPC（当前 O(n) 次 automator 调用）
2. **多页快照合并**：`--snapshot-pages` 一次连接导航+多页快照，去掉反复起进程/重连
3. **固定 sleep → 条件等待**：click/navigate 后轮询 path/元素，替代盲等 300–500ms
4. **改动检测收紧**：只对影响运行的源文件触发 IDE 重启；热重载可复用时不重启
5. **耗时埋点**：--check/--snapshot/--plan 输出阶段耗时，方便后续继续压

验收：多页快照从「N 次连接」降为「1 次连接」；单页快照元素采集不再 O(n) 次 RPC。

## 线 B：借鉴 impeccable 增强 implement 前端设计

落点：`skills/implement/design-guide.md` + `review-checklist.md`，不新建技能、不搬命令体系。

### B-1 设计支柱清单化

现有 review-checklist 前端检查仅 4 项，扩成 **7 支柱逐项打勾**：排版 · 色彩 · 空间 · 响应式 · 交互 · 动效 · UX 文案。每支柱给 1 句判定标准 + 1 个反例，可机械核对。

### B-2 反 AI slop 黑名单

design-guide.md 新增小节，本地化反例清单：渐变堆叠、玻璃拟态无节制、荧光紫蓝、过曝白卡、hover 缩放弹簧、装饰性阴影。**判定即拒，非建议**，强约束不可商量。

### B-3 品牌模式 vs 产品模式分轨

design-guide.md 拆两套准则：
- 品牌模式（营销/着陆页）：允许强视觉、大字号、动效
- 产品模式（App/后台/仪表盘）：克制、信息密度、零装饰

设计面试第一问定模式，后续准则按模式走。

### B-4 critique 结构化评分

推演收敛阶段，前端页面额外加 **7 支柱评分（每项 0–2）**，任一项 0 分即判「审美未过」，列改进项再收敛。不引入 impeccable 的 critique 命令本身。

### B-5 PRODUCT 层补一句

DESIGN-BRIEF.md 头部加「产品意图一句话」字段（产品解决什么、给谁用），对应 impeccable 的 PRODUCT.md 思想，**不新建文件**。

借鉴边界：不引入 24 命令、live overlay、插件安装；只吸收「支柱清单 + 反 slop + 分模式 + 评分 + 产品意图」五条思想。

## 线 C：借鉴 ponytail 增强 implement 编码思想

落点：`skills/implement/phases.md`（方案审查段）+ `core-os.md`（编码思维方法论）+ `review-checklist.md`。

### C-1 lazy senior 三问（动手前硬门）

方案审查新增三问，逐条自答，答不上来不准进执行：
1. 能不能不写？（需求是否已由现有功能/配置覆盖）
2. 能不能少写？（能否用更小改动达成）
3. 能不能复用？（现有组件/工具/接口是否可直接用）

与现有「删法项」正交：删法项盯冗余，三问盯「该不该动手」。

### C-2 意图优先硬门

方案展示前先锁定一句「要解决什么」（意图），再允许讨论「怎么做」。把意图锁定前移到方案审查入口，意图未定禁止讨论实现选型。

### C-3 最小改动执行准则

phases.md 执行计划段显式加：改最少的代码达成目标，不重构无关部分；发现相邻代码有问题，记到 review-checklist 的「相邻改进建议」而非顺手改。

借鉴边界：不引入 ponytail 命令体系/lazy senior 人格包装；只吸收「三问 + 意图优先 + 最小改动」三条思想。

## 落点汇总

| 线 | 改的文件 | 新增文件 |
|----|---------|---------|
| A 安卓 | SKILL.md（识别+GATE）、android-test.md、scripts/android-run.cjs | android-test.md、android-run.cjs |
| A 小程序加速 | mini-test.md、scripts/mini-run.cjs | — |
| B impeccable | design-guide.md、review-checklist.md | — |
| C ponytail | phases.md、core-os.md、review-checklist.md | — |

## 工程约束

- 双写源仓库（`skills/`）+ 安装副本（`.cwork/refs/`）
- 改完记 `skills/USAGE_NOTES.md`「未分析」区
- 分支提交走 `common/git-guard.md`（upstream 只能是 origin/<同名分支>，禁止裸 push/pull）
- 代码规范走 `common/code-style.md`

## 验收标准

1. `/cwork-test` 能识别安卓并在 BlueStacks 5 上跑通至少 1 条 P0（安装→打开→点击→断言→截图）
2. 小程序同场景回归：多页快照从 N 次连接降为 1 次连接；单页快照元素采集不再 O(n) 次 RPC
3. implement 前端设计检查产出 7 支柱清单 + 反 slop 黑名单，分品牌/产品模式
4. implement 推演收敛对前端页面产出 7 支柱评分
5. implement 方案审查含 lazy senior 三问 + 意图优先硬门 + 最小改动准则
