# Agent 工坊 · 排版模板、封面与自检

正文产出物是 **HTML + inline CSS 片段**（写到 `<期次>/body.html`）。公众号编辑器不吃 `class`，所有样式一律 `style="..."`。复制骨架后替换 `{{...}}`，不改结构语义。

**文风**：口语化，像跟同事讲话；正文 CJK ≤2000。禁用词表与自检方法见 `SKILL.md` §3.6。

**配色**：工坊橙 `#E8590C`（主）、工坊青 `#0B7285`（辅）、石墨 `#1F2328`（标题）、正文灰 `#4A4F55`、浅底 `#FFF7F2`、分隔线 `#E8E1DC`。

**证据等级徽标**（全篇统一，不可自创）：

| 等级 | 底色 | 文字 |
|------|------|------|
| L3 | `#1E7B4F` | 白 |
| L2 | `#0B5FBF` | 白 |
| L1 | `#5A6B7B` | 白 |
| L0 | `#8C8C8C` | 白 |
| 作者自述 | `#E8590C` | 白 |
| 未验证 | `#B3A79F` | 白 |

---

## 一、正文骨架

```html
<!-- ===== 顶部栏目条 ===== -->
<section style="background:linear-gradient(135deg,#1F2328 0%,#0B3B4A 100%);border-radius:10px;padding:20px 18px;margin:0 0 26px;color:#ffffff;">
  <p style="margin:0 0 8px;font-size:13px;letter-spacing:3px;color:#FFB98A;">AGENT WORKSHOP · NO.{{期号}}</p>
  <p style="margin:0 0 10px;font-size:22px;font-weight:bold;line-height:1.4;">{{主对象名}}</p>
  <p style="margin:0 0 10px;font-size:14px;line-height:1.75;opacity:0.92;">{{一句话定位：作者原话的中文转述}}</p>
  <p style="margin:0;font-size:12px;line-height:1.7;opacity:0.75;">证据等级：L0 文档 / L1 源码 / L2 本地跑通 / L3 基准实测｜本期实践 {{最高等级}}<br>本文基于公开仓库、文档与自建小规模实验整理，观点为本号所有。文｜长风・Ethan</p>
</section>

<!-- ===== 钩子 ===== -->
<p style="margin:0 0 22px;font-size:16px;color:#4A4F55;line-height:1.85;">{{一个具体场景的痛点：谁在什么情况下被什么卡住，3-4 句，不讲宏大叙事}}</p>

<!-- ===== 一、先给结论 ===== -->
<h2 style="font-size:19px;font-weight:bold;color:#1F2328;border-left:4px solid #E8590C;padding-left:12px;margin:28px 0 14px;">一、先给结论</h2>

<section style="background:#FFF7F2;border:1px solid #F3D5C4;border-radius:8px;padding:16px 14px;margin:0 0 12px;">
  <p style="margin:0 0 8px;font-size:15px;font-weight:bold;color:#B8460A;">01｜{{结论一（一句）}}</p>
  <p style="margin:0;font-size:14px;color:#4A4F55;line-height:1.8;">{{支撑一句：证据等级 + 关键数字}}</p>
</section>
<section style="background:#FFF7F2;border:1px solid #F3D5C4;border-radius:8px;padding:16px 14px;margin:0 0 12px;">
  <p style="margin:0 0 8px;font-size:15px;font-weight:bold;color:#B8460A;">02｜{{结论二}}</p>
  <p style="margin:0;font-size:14px;color:#4A4F55;line-height:1.8;">{{支撑}}</p>
</section>
<section style="background:#FFF7F2;border:1px solid #F3D5C4;border-radius:8px;padding:16px 14px;margin:0 0 22px;">
  <p style="margin:0 0 8px;font-size:15px;font-weight:bold;color:#B8460A;">03｜{{结论三}}</p>
  <p style="margin:0;font-size:14px;color:#4A4F55;line-height:1.8;">{{支撑}}</p>
</section>

<!-- ===== 二、它是什么：拆解 ===== -->
<h2 style="font-size:19px;font-weight:bold;color:#1F2328;border-left:4px solid #E8590C;padding-left:12px;margin:28px 0 14px;">二、它到底在做什么</h2>

<p style="margin:0 0 14px;font-size:15px;color:#4A4F55;line-height:1.85;">{{拆解：输入是什么、中间经过哪些环节、输出是什么。用「A → B → C」把调用链讲直，每段 ≤3 句}}</p>

<!-- 调用链卡片（可重复 2-4 段） -->
<section style="background:#F6F9FA;border-left:3px solid #0B7285;border-radius:0 6px 6px 0;padding:12px 14px;margin:0 0 14px;">
  <p style="margin:0 0 6px;font-size:14px;font-weight:bold;color:#0B7285;">{{环节名}}</p>
  <p style="margin:0;font-size:14px;color:#4A4F55;line-height:1.8;">{{它接收什么 → 做了什么 → 交给谁}}　<span style="display:inline-block;background:#5A6B7B;color:#fff;font-size:11px;padding:1px 6px;border-radius:3px;">L1 源码</span></p>
</section>

<!-- 对照差异（可选，2-3 行） -->
<blockquote style="background:#F5F7FA;border-left:4px solid #0B7285;padding:14px 16px;margin:0 0 22px;color:#4A4F55;">
  <p style="margin:0 0 6px;font-size:14px;line-height:1.8;"><b>和 {{对照 A}} 的差别：</b>{{一行差异 + 一行代价}}</p>
  <p style="margin:0;font-size:14px;line-height:1.8;"><b>和 {{对照 B}} 的差别：</b>{{一行差异 + 一行代价}}</p>
</blockquote>

<!-- ===== 三、能力特性 → 场景价值（核心） ===== -->
<h2 style="font-size:19px;font-weight:bold;color:#1F2328;border-left:4px solid #E8590C;padding-left:12px;margin:28px 0 14px;">三、能力值钱在哪，代价是什么</h2>
<p style="margin:0 0 16px;font-size:14px;color:#8C7B70;line-height:1.75;">每一项都按「能力 → 机制 → 场景价值 → 代价」写全，缺任何一项都不成立。</p>

<!-- 能力卡：每个能力一张，重复 3-5 次 -->
<section style="border:1px solid #E8E1DC;border-radius:8px;padding:16px 14px;margin:0 0 16px;">
  <p style="margin:0 0 8px;font-size:16px;font-weight:bold;color:#1F2328;">{{能力名}}</p>
  <p style="margin:0 0 8px;font-size:14px;color:#4A4F55;line-height:1.8;"><b style="color:#0B7285;">机制｜</b>{{一句话说清它怎么实现}}</p>
  <p style="margin:0 0 8px;font-size:14px;color:#4A4F55;line-height:1.8;background:#FFF7F2;padding:8px 10px;border-radius:4px;"><b style="color:#B8460A;">场景价值｜</b>{{谁 + 原来怎么做 + 现在怎么做 + 省了什么}}</p>
  <p style="margin:0;font-size:14px;color:#6B5B52;line-height:1.8;background:#FAF7F4;padding:8px 10px;border-radius:4px;"><b style="color:#8C7B70;">代价｜</b>{{不适用场景 / 隐藏成本 / 风险}}</p>
</section>

<!-- ===== 四、案例实践 ===== -->
<h2 style="font-size:19px;font-weight:bold;color:#1F2328;border-left:4px solid #E8590C;padding-left:12px;margin:28px 0 14px;">四、我拿它跑了一次</h2>

<p style="margin:0 0 12px;font-size:15px;color:#4A4F55;line-height:1.85;">
  <span style="display:inline-block;background:#0B5FBF;color:#fff;font-size:12px;padding:2px 8px;border-radius:3px;margin-right:6px;">L2 本地跑通</span>
  {{环境：OS / 版本 / 模型 / 依赖，用一句半说清；费用与耗时也给}}
</p>

<pre style="background:#1F2328;color:#E6EDF3;font-size:13px;line-height:1.65;padding:14px 12px;border-radius:6px;overflow-x:auto;margin:0 0 12px;"><code>{{关键命令，≤20 行，只留必要步骤}}</code></pre>

<section style="background:#F6F9FA;border-left:3px solid #0B7285;border-radius:0 6px 6px 0;padding:12px 14px;margin:0 0 14px;">
  <p style="margin:0 0 6px;font-size:14px;font-weight:bold;color:#0B7285;">结果</p>
  <p style="margin:0;font-size:14px;color:#4A4F55;line-height:1.8;">{{输入 → 输出 + 耗时/请求数/费用，逐条带数字}}</p>
</section>

<!-- 失败点（有就写，没有就删掉整块） -->
<section style="background:#FFF4E6;border-left:3px solid #E8590C;border-radius:0 6px 6px 0;padding:12px 14px;margin:0 0 22px;">
  <p style="margin:0 0 6px;font-size:14px;font-weight:bold;color:#B8460A;">踩到的坑</p>
  <p style="margin:0;font-size:14px;color:#6B5B52;line-height:1.8;">{{文档与实现不一致 / 依赖冲突 / 触发条件，给版本号与现象，不下绝对结论}}</p>
</section>

<!-- ===== 五、场景价值（三类读者） ===== -->
<h2 style="font-size:19px;font-weight:bold;color:#1F2328;border-left:4px solid #E8590C;padding-left:12px;margin:28px 0 14px;">五、谁该用，用了会变成什么样</h2>
<p style="margin:0 0 14px;font-size:14px;color:#8C7B70;line-height:1.75;">至少写透两类读者；每类按「原来 → 现在 → 价值 / 新增负担」写。</p>

<section style="background:linear-gradient(135deg,#0B3B4A 0%,#0B7285 100%);border-radius:8px;padding:16px 14px;margin:0 0 12px;color:#ffffff;">
  <p style="margin:0 0 8px;font-size:16px;font-weight:bold;">个人开发者</p>
  <p style="margin:0 0 6px;font-size:14px;line-height:1.8;opacity:0.95;"><b>原来｜</b>{{重复劳动 / 学习成本}}</p>
  <p style="margin:0 0 6px;font-size:14px;line-height:1.8;opacity:0.95;"><b>现在｜</b>{{具体动作怎么变}}</p>
  <p style="margin:0;font-size:14px;line-height:1.8;opacity:0.95;"><b>值不值｜</b>{{省了什么 + 要花多少时间/钱}}</p>
</section>

<section style="background:#16202A;border-radius:8px;padding:16px 14px;margin:0 0 12px;color:#ffffff;">
  <p style="margin:0 0 8px;font-size:16px;font-weight:bold;">团队工程</p>
  <p style="margin:0 0 6px;font-size:14px;line-height:1.8;opacity:0.95;"><b>原来｜</b>{{协作与交付的痛点}}</p>
  <p style="margin:0 0 6px;font-size:14px;line-height:1.8;opacity:0.95;"><b>现在｜</b>{{流程哪里变了：评测、回归、权限、知识沉淀}}</p>
  <p style="margin:0;font-size:14px;line-height:1.8;opacity:0.95;"><b>值不值｜</b>{{收益 + 维护与治理成本}}</p>
</section>

<section style="background:#F6F9FA;border:1px solid #D8E4E8;border-radius:8px;padding:16px 14px;margin:0 0 22px;">
  <p style="margin:0 0 8px;font-size:16px;font-weight:bold;color:#0B3B4A;">业务方</p>
  <p style="margin:0 0 6px;font-size:14px;color:#4A4F55;line-height:1.8;"><b>原来｜</b>{{交付周期 / 质量 / 人力依赖}}</p>
  <p style="margin:0 0 6px;font-size:14px;color:#4A4F55;line-height:1.8;"><b>现在｜</b>{{哪个环节变了}}</p>
  <p style="margin:0;font-size:14px;color:#4A4F55;line-height:1.8;"><b>值不值｜</b>{{可量化变化 + 合规/安全边界}}</p>
</section>

<!-- ===== 六、冷静判断 ===== -->
<h2 style="font-size:19px;font-weight:bold;color:#1F2328;border-left:4px solid #E8590C;padding-left:12px;margin:28px 0 14px;">六、什么情况下先别上</h2>

<section style="background:#FFF4E6;border-left:4px solid #E8590C;padding:14px 16px;margin:0 0 12px;">
  <p style="margin:0 0 6px;font-size:14px;color:#6B5B52;line-height:1.85;">{{不适用场景 1：什么条件下收益小于成本}}</p>
  <p style="margin:0;font-size:14px;color:#6B5B52;line-height:1.85;">{{不适用场景 2：隐藏成本 / 合规风险 / 团队能力前置条件}}</p>
</section>

<p style="margin:0 0 22px;font-size:14px;color:#8C7B70;line-height:1.8;">本条判断的证据等级：<span style="display:inline-block;background:#B3A79F;color:#fff;font-size:11px;padding:1px 6px;border-radius:3px;">{{等级}}</span>　{{依据一句话}}</p>

<!-- ===== 七、最小行动 ===== -->
<h2 style="font-size:19px;font-weight:bold;color:#1F2328;border-left:4px solid #E8590C;padding-left:12px;margin:28px 0 14px;">七、30 分钟能验证的第一件事</h2>

<section style="background:#F6F9FA;border-radius:8px;padding:16px 14px;margin:0 0 22px;">
  <p style="margin:0 0 8px;font-size:14px;color:#4A4F55;line-height:1.85;">01　{{最小动作一（装什么/写什么/跑什么）}}</p>
  <p style="margin:0 0 8px;font-size:14px;color:#4A4F55;line-height:1.85;">02　{{验证判据：看到什么就算成立}}</p>
  <p style="margin:0;font-size:14px;color:#4A4F55;line-height:1.85;">03　{{不成立时下一步排查哪里}}</p>
</section>

<!-- ===== 来源一览 ===== -->
<h2 style="font-size:19px;font-weight:bold;color:#1F2328;border-left:4px solid #BFBFBF;padding-left:12px;margin:28px 0 12px;">来源</h2>
<section style="background:#FAFAFA;border-radius:6px;padding:14px 12px;margin:0 0 20px;">
  <p style="margin:0 0 6px;font-size:13px;color:#8C8C8C;line-height:1.85;">1. {{一手来源｜内容｜URL 明文｜日期}}</p>
  <p style="margin:0 0 6px;font-size:13px;color:#8C8C8C;line-height:1.85;">2. {{…}}</p>
  <p style="margin:0;font-size:13px;color:#8C8C8C;line-height:1.85;">{{实验记录：practice-log.md（本地）}}</p>
</section>

<!-- ===== 底部吸粉 ===== -->
<hr style="border:none;border-top:1px solid #E8E1DC;margin:28px 0 20px;">

<div style="background:#FFF7F2;border-radius:10px;padding:20px 18px;margin:0 0 16px;text-align:center;">
  <p style="margin:0 0 10px;font-size:16px;font-weight:bold;color:#B8460A;">关注「高低要看」· 每周拆一个 Agent 项目</p>
  <p style="margin:0 0 10px;font-size:14px;color:#6B5B52;line-height:1.8;">只讲拆得开、跑得通、能落地的部分。<br>下一个想拆的项目，留言告诉我们。</p>
  <p style="margin:0;font-size:13px;color:#8C7B70;line-height:1.8;">觉得有用，点个「在看」，转给正在选型的同事。</p>
</div>

<div style="text-align:center;margin:18px 0;">
  <img src="images/qr-code.jpg" alt="公众号二维码" style="width:180px;height:180px;">
</div>

<p style="margin:0;text-align:center;font-size:12px;color:#AAAAAA;line-height:1.9;">本文不构成任何厂商背书或投资建议。文中数据以标注来源与抓取时间为准。</p>
```

**底部二维码**：优先用用户提供的图，存 `<期次>/images/qr-code.jpg`；拿不到时**只删二维码那一块**（不要留破图），关注文案、「在看」引导与免责声明保留。

**结构要求**：

- `<h2>` 只用于七个一级章节 + 「来源」，便于注入后按 `<h2` 计数复验。
- 证据徽标与 `practice-log.md` / `research.md` 条目一一对应，不许临时升级。
- 代码块 ≤20 行；长输出改成「结果摘要」卡片，不放整段日志。
- 外链写 URL 明文；账号有白名单再加 `<a>`。

---

## 二、标题公式

一次给 3-5 个候选，用户选 1 个。约束：中文 ≤30 字，不用「震惊/吊打/必看/颠覆」。

| 形态 | 模板 | 例子 |
|------|------|------|
| 结论型 | `Agent 工坊｜<判断句>` | `Agent 工坊｜harness 才是 Agent 的胜负手` |
| 数字型 | `<N> 个 <对象>，正在改写 <场景>` | `3 类 Agent 架构，正在改写团队的分工方式` |
| 反差型 | `别急着 <流行做法>：先把 <被忽略的环节> 跑通` | `别急着上多 Agent：先把评测跑通` |
| 场景型 | `把 <能力> 装进 Agent，<具体收益>` | `把「技能」装进 Agent：一份 SKILL.md 省掉半本提示词` |
| 提问型 | `为什么 <现象>，<反直觉解释>` | `为什么跑分更高的 Agent，上线反而更难维护` |

副标题可选：`｜<主对象> + <证据等级>`。

---

## 三、封面（强制，两段式）

### 3.1 ImageGen 底图（无文字）

`size="2560x1080"`，`name="agent-workshop-<YYYYMMDD>-cover"`，画面**不含任何文字**。

```
A wide editorial banner for a deep-dive series about AI agent engineering.
Central motif: a stylised workshop bench / assembly line where abstract glowing modules
(tool crates, memory discs, gear-shaped harness clamps, small robotic arms) are being
assembled into a single translucent agent core.
Background: deep graphite (#16202A) with warm workshop light, blueprint grid lines,
sparks of orange (#E8590C) and teal (#0B7285) accent light.
Style: flat modern industrial illustration, clean geometry, high contrast, premium editorial,
absolutely no text, no letters, no numbers, no logos, no watermark.
Mood: hands-on, precise, quietly ambitious.
```

想体现具体主题时替换中央元素（例：harness 选题 → `a calibration rig measuring a small agent core against a scoreboard of blank gauges`；skill 选题 → `a wall of neatly labelled tool drawers, one drawer pulled open emitting warm light`）。用构图表达，不写字。

### 3.2 叠中文大字（禁止 ImageGen 直出中文）

```bash
ISSUE=20261121-claude-skills   # 本期目录名，按实际替换
node skills/tech-express/scripts/make-cover-poster.cjs \
  --dir "$CONTENT_DIR/agent-workshop/$ISSUE" \
  --title "Agent 工坊" \
  --date "11月21日" \
  --sub "本期主题一句话" \
  --kicker "AGENT WORKSHOP · DEEP DIVE"

powershell -ExecutionPolicy Bypass -File skills/tech-express/scripts/make-cover.ps1 -Dir "$CONTENT_DIR/agent-workshop/$ISSUE"
```

- `--title` 4-8 个字；主对象名过长放 `--sub`。
- 脚本会把底图备份为 `00-cover-bg.png`，输出 `00-cover.png`（2560×1080），再压成 `00-cover.jpg`（1280 宽、质量 88）。
- 出图后 **Read 一次 PNG** 复核：无错字、未被遮挡、尺寸正确。
- ImageGen 实得尺寸偏小没关系，脚本 `object-fit:cover` 会铺满画布。

---

## 四、原创与署名口径

- 署名固定：**文｜长风・Ethan**（首页栏目条与 footer 一致）。
- 首屏声明：`本文基于公开仓库、文档与自建小规模实验整理，实测与引用已标注证据等级，观点为本号所有。`
- 原创判定：正文为自主拆解 + 自建实验 + 独立判断，且来源逐条标注 → 可点原创；纯翻译/纯转述不可点。
- **「声明原创」开关不代点**，写入草稿后列为待手动项。
- 免责：文末保留「不构成厂商背书或投资建议；数据以标注来源与抓取时间为准」。

---

## 五、写入草稿前自检清单

| # | 检查项 | 判据 |
|---|--------|------|
| 1 | 单一主对象 | 全文只有一个主角，对照对象不展开成第二篇 |
| 2 | 数字可溯 | 每个数字能在 `research.md` 找到行，带口径与抓取日期 |
| 3 | 一手材料 | 至少 3 类一手来源（仓库/文档/源码/论文/Release） |
| 4 | 案例实践 | 有 L1 或 L2 记录，且 `practice-log.md` 有环境与结果 |
| 5 | 证据标注 | 正文徽标与台账一致，无 L1 冒充实测 |
| 6 | 能力表完整 | 每项能力都有「机制 + 场景价值 + 代价」三段 |
| 7 | 场景读者 | 个人/团队/业务至少写透两类 |
| 8 | 不吹不黑 | 每个优势配了代价或边界 |
| 9 | 冷静判断 | 有明确的「先别上」条件 |
| 10 | 最小行动 | 30 分钟内可执行，有验证判据 |
| 11 | 篇幅 | CJK ≤2000（`body.html` 去标签汉字数；编辑器「正文字数」不作判据）；压字不砍代价/边界/来源 |
| 12 | 排版 | 全 inline style，无 class；`<h2>` 数与注入期望一致 |
| 13 | 封面 | ImageGen 底图 + 脚本叠字，Read 复核，2560×1080 |
| 14 | 声明署名 | 首屏声明与「文｜长风・Ethan」齐全，文末免责保留 |
| 15 | 待手动项 | 「声明原创」、封面（自动失败时）已列入汇报 |
| 16 | 口语化 | 开场是具体场景；无 AI 腔词（赋能/闭环/底层逻辑/综上所述）；术语有句人话解释；挑三段念过 |
