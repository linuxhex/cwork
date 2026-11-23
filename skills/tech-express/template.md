# 科技速递 · 排版模板与封面 prompt

正文产出物必须是 **HTML + inline CSS 片段**（写入 `<目录>/body.html`），公众号编辑器不吃 `class`，所有样式一律 `style="..."`。下面骨架直接复制后替换 `{{...}}`，**不要改结构语义**。

主题色：科技蓝 `#1890FF`；往日徽标橙 `#FA8C16`；行情品红 `#C41D7F`（配浅底 `#FFF7FA` / `#FFF1F0`）；短评棕 `#6B5122`；正文灰 `#555555`；来源浅灰 `#AAAAAA`。

---

## 一、正文骨架

```html
<!-- 顶部日期条 -->
<section style="background:linear-gradient(135deg,#1890FF 0%,#0B5FBF 100%);border-radius:8px;padding:18px 16px;margin:0 0 24px;color:#ffffff;">
  <p style="margin:0 0 6px;font-size:20px;font-weight:bold;letter-spacing:1px;">科技速递 · {{M月D日}}</p>
  <p style="margin:0;font-size:13px;opacity:0.9;line-height:1.7;">当日：{{M月D日}}｜往日回顾：{{M月D-1日}}、{{M月D-2日}}｜{{N}} 条 + 三地行情</p>
  <p style="margin:8px 0 0;font-size:13px;opacity:0.9;line-height:1.7;">今日主线：{{一句话串起 2-3 条同向大事}}。</p>
  <p style="margin:6px 0 0;font-size:12px;opacity:0.85;line-height:1.7;">本文为公开报道的编辑整理与独立分析，事实均来自标注来源，观点为本号所有。文｜{{笔名}}</p>
</section>

<!-- ===== 市场同频（固定板块，行情口径见 SKILL.md 4.3） ===== -->
<h2 style="font-size:19px;font-weight:bold;color:#1A1A1A;border-left:4px solid #C41D7F;padding-left:12px;margin:0 0 14px;">市场同频</h2>
<section style="background:#FFF7FA;border-left:3px solid #C41D7F;border-radius:0 6px 6px 0;padding:12px;margin:0 0 22px;">
  <p style="margin:0 0 8px;font-size:14px;color:#555555;line-height:1.75;"><b style="color:#C41D7F;">A股｜{{M月D日}}</b>　{{指数}} {{收盘点位}} 跌/涨 {{x.xx%}}，{{盘中口径另标}}；{{与当期条目相关的板块涨跌}}</p>
  <p style="margin:0 0 8px;font-size:14px;color:#555555;line-height:1.75;"><b style="color:#C41D7F;">港股｜{{M月D日}}</b>　恒生指数 {{点位}} {{x.xx%}}，恒生科技指数 {{点位}} {{x.xx%}}</p>
  <p style="margin:0;font-size:14px;color:#555555;line-height:1.75;"><b style="color:#C41D7F;">美股｜美东{{M月D日}}</b>　道指 {{x.xx%}}、标普500 {{x.xx%}}、纳指 {{x.xx%}}，费城半导体指数 {{x.xx%}}；{{相关个股}}</p>
</section>

<!-- ===== 今日资讯 ===== -->
<h2 style="font-size:19px;font-weight:bold;color:#1A1A1A;border-left:4px solid #1890FF;padding-left:12px;margin:0 0 16px;">今日资讯</h2>

<section style="margin:0 0 20px;">
  <p style="margin:0 0 6px;font-size:17px;font-weight:bold;color:#1A1A1A;line-height:1.5;">
    <span style="display:inline-block;background:#1890FF;color:#ffffff;font-size:12px;padding:2px 8px;border-radius:3px;margin-right:8px;">{{领域标签}}</span>{{序号}}. {{≤20 字标题}}
  </p>
  <p style="margin:0 0 8px;font-size:15px;color:#555555;line-height:1.75;">{{60-110 字压缩正文：核心主题 + 谁做了什么 + 依据 + 直接影响谁}}</p>
  <p style="margin:0 0 8px;font-size:14px;color:#8C8C8C;line-height:1.7;background:#F5F7FA;border-left:3px solid #1890FF;padding:8px 10px;border-radius:0 4px 4px 0;">关系链：{{主体A → 动作 → 受影响方B}}</p>
  <!-- 「市场｜」行可选：只给真有对应行情的 2-4 条加；配色固定（#C41D7F / #FFF1F0），往日条目也照抄，不随条目主色变 -->
  <p style="margin:0 0 8px;font-size:14px;color:#A8071A;line-height:1.7;background:#FFF1F0;padding:8px 10px;border-radius:4px;"><b style="color:#C41D7F;">市场｜</b>{{一行：相关标的/板块当天怎么走，收盘口径，盘中数据要标「盘中」}}</p>
  <p style="margin:0 0 8px;font-size:14px;color:#6B5122;line-height:1.7;"><b style="color:#1890FF;">短评｜</b>{{≤45 字，趋势/发展眼光，指向最直接影响}}</p>
  <p style="margin:0;font-size:13px;color:#AAAAAA;line-height:1.7;">来源：{{媒体名}} · {{M月D日}} · {{URL 明文}}</p>
</section>
<!-- 重复上面的 <section>，今日 5-8 条 -->

<hr style="border:none;border-top:1px solid #E8E8E8;margin:26px 0;">

<!-- ===== 往日回顾 ===== -->
<h2 style="font-size:19px;font-weight:bold;color:#1A1A1A;border-left:4px solid #FA8C16;padding-left:12px;margin:0 0 16px;">往日回顾</h2>

<section style="margin:0 0 18px;">
  <p style="margin:0 0 6px;font-size:16px;font-weight:bold;color:#1A1A1A;line-height:1.5;">
    <span style="display:inline-block;background:#FA8C16;color:#ffffff;font-size:12px;padding:2px 8px;border-radius:3px;margin-right:8px;">{{M月D日}}</span>
    <span style="display:inline-block;background:#F0F0F0;color:#666666;font-size:12px;padding:2px 8px;border-radius:3px;margin-right:8px;">{{领域标签}}</span>{{序号}}. {{≤20 字标题}}
  </p>
  <p style="margin:0 0 8px;font-size:15px;color:#555555;line-height:1.75;">{{压缩正文}}</p>
  <p style="margin:0 0 8px;font-size:14px;color:#8C8C8C;line-height:1.7;background:#F5F7FA;border-left:3px solid #FA8C16;padding:8px 10px;border-radius:0 4px 4px 0;">关系链：{{主体A → 动作 → 受影响方B}}</p>
  <p style="margin:0 0 8px;font-size:14px;color:#6B5122;line-height:1.7;"><b style="color:#FA8C16;">短评｜</b>{{短评}}</p>
  <p style="margin:0;font-size:13px;color:#AAAAAA;line-height:1.7;">来源：{{媒体名}} · {{M月D日}} · {{URL 明文}}</p>
</section>
<!-- 重复上面的 <section>，往日 6-10 条 -->

<hr style="border:none;border-top:1px solid #E8E8E8;margin:26px 0;">

<!-- ===== 速递观察 ===== -->
<h2 style="font-size:19px;font-weight:bold;color:#1A1A1A;border-left:4px solid #722ED1;padding-left:12px;margin:0 0 16px;">速递观察</h2>

<section style="background:linear-gradient(135deg,#722ED1 0%,#4A1D96 100%);border-radius:8px;padding:16px 14px;margin:0 0 14px;color:#ffffff;">
  <p style="margin:0 0 8px;font-size:15px;font-weight:bold;">{{维度名（民生 / 市场 / 资本 / 进出口 / 经济层面 / 舆论层面）}}</p>
  <p style="margin:0;font-size:14px;line-height:1.8;opacity:0.95;">{{80-150 字，趋势与发展的眼光，结论能被上文事实支撑}}</p>
</section>
<!-- 2-4 张观察卡 -->

<!-- ===== 来源一览（防外链被清洗） ===== -->
<h2 style="font-size:19px;font-weight:bold;color:#1A1A1A;border-left:4px solid #BFBFBF;padding-left:12px;margin:26px 0 12px;">来源一览</h2>
<section style="background:#FAFAFA;border-radius:6px;padding:14px 12px;margin:0 0 20px;">
  <p style="margin:0 0 6px;font-size:13px;color:#8C8C8C;line-height:1.8;">1. {{媒体名}}｜{{文章标题}}｜{{URL}}</p>
  <!-- 每条来源一行，序号与上文条目对应；「市场同频」与「市场｜」行用到的行情源同样列进来（可多条合并成一行） -->
</section>

<!-- ===== 底部固定块 ===== -->
<hr style="border:none;border-top:1px solid #E8E8E8;margin:20px 0;">
<p style="margin:0 0 10px;font-size:13px;color:#AAAAAA;line-height:1.8;">本期消息检索窗口：{{D}}、{{D-1}}、{{D-2}}（北京时间），来源为公开科技与财经媒体报道，标注「据……报道」的条目未取得原文全文，仅有检索摘要。行情为公开收盘数据，{{盘中口径的部分在此点名}}。</p>
<p style="margin:0 0 10px;font-size:13px;color:#AAAAAA;line-height:1.8;">「速递观察」「市场同频」与条目短评为基于公开信息的趋势分析，<b>不构成任何投资建议</b>。</p>
<p style="margin:0;text-align:center;font-size:13px;color:#AAAAAA;line-height:1.9;">{{笔名}} · 每天 3 分钟看完科技圈三天事 · 点个「在看」</p>
```

---

## 二、外链处理（重要）

公众号正文 `<a>` 只在**账号有外链白名单**时可点击，非白名单域名发布时可能被清洗成纯文本。因此：

1. 每条来源行写 **URL 明文**（不只写「原文链接」），保证清洗后仍可读、可复制。
2. 另设文末「**来源一览**」区块集中列全部链接（上方骨架已内置），这是 requirement「明确消息来源与链接」的兜底落点。
3. 若账号确已开通外链白名单，可在来源行把 URL 再包一层 `<a href="..." style="color:#1890FF;text-decoration:underline;">`；两种写法都以明文 URL 存在为前提。

---

## 三、标题公式

| 形态 | 模板 | 用法 |
|------|------|------|
| 常规 | `科技速递 · 11月11日` | 默认，稳妥 |
| 主线 | `科技速递 · 11月11日｜AI 芯片与跨境关税同日收紧` | 当日有两条以上同向大事 |
| 提问 | `科技速递 · 11月11日｜谁在替这轮降价买单` | 当日有价格/补贴类强冲突 |
| 数字 | `科技速递 · 11月11日｜3 个 800 亿量级的决定` | 资本/并购集中日 |

一次给 2-3 个候选让用户挑，长度 ≤64 字，不标题党。

---

## 四、封面图 prompt（ImageGen，强制实际生成）

`size="2560x1080"`，`name="tech-express-<YYYYMMDD>-cover"`，画面**不含任何文字**。

```
A wide editorial banner for a daily tech news brief.
Central motif: a stylised horizontal data stream / news ticker ribbon of abstract light
carrying small geometric icons — a chip die, a neural network node, a satellite,
an EV silhouette, a shipping container, a stock candlestick chart.
Background: deep navy to electric blue gradient (#0B1B3A → #1890FF), faint grid lines,
soft bokeh highlights, subtle orange accent glow on the right side.
Style: flat modern vector-infused tech illustration, clean geometry, high contrast,
premium editorial, professional, absolutely no text, no letters, no numbers, no logos.
Mood: fast, authoritative, forward-looking.
```

要体现当日主线时，替换中央元素（例：出口管制日 → `a stylised customs checkpoint gate with abstract semiconductor crates passing through a scanning beam`）；想把主线情绪带进去，用构图而非文字（例：`one large chip node drifting away from the ribbon while two smaller nodes slide into its place`）。

⚠️ **ImageGen 实际返回尺寸常小于请求尺寸**（20261113 请求 2560×1080，实得 1584×672）。比例对即可直接用，**不要为凑尺寸反复重生成**——`make-cover-poster.cjs` 会把底图 `object-fit:cover` 铺到 2560×1080 画布上，最终 PNG 一定是请求尺寸；`make-cover.ps1` 再按 1280 宽等比缩放，微信封面 2.35:1 够用。交付汇报里的封面尺寸仍要**实测**（PNG 头 / `System.Drawing`），别把请求值当真值。

### 4.1 默认形态：大字海报（叠字 + 上升趋势线）

ImageGen 只负责**底图**（无文字）。中文大字一律用 HTML 叠字 + 本地 Chrome 渲染，不让图像模型写汉字：

```bash
# 底图 00-cover.png 会被自动备份为 00-cover-bg.png，可重复执行
node skills/tech-express/scripts/make-cover-poster.cjs --dir "$CONTENT_DIR/tech-express/<YYYYMMDD>"
```

默认版式（2560×1080）：

| 元素 | 规格 |
|------|------|
| 左侧大字 | 「科技速递」246px、字重 900、白色、字距 8px，下方橙色竖条 + 「M月D日」80px（`--no-date` 时整条日期行不渲染） |
| 上下小字 | kicker `TECH EXPRESS · DAILY BRIEF`（40px 蓝色字距 14px）；副标「每日 3 分钟 · 看完科技圈三天事」 |
| 上升趋势线 | 右半幅 13 点折线，青→橙渐变、圆角、发光滤镜，末端橙色圆点 + 光晕，线下渐变填充，配三条淡虚线基准 |
| 压暗层 | 左深右浅的横向渐变遮罩，保证大字可读、不遮右侧主体 |

可覆盖参数：`--title`、`--date`、`--sub`、`--kicker`、`--width`、`--height`、`--no-date`。要换情绪就换底图（步骤 3 的 prompt），版式不动。

**通用封面（不随日期变，跨期复用）**：`--no-date` 跑在共享目录上，产物落在 `$CONTENT_DIR/tech-express/_shared/images/00-cover.png` / `00-cover.jpg`，任何一期的封面槽都能直接选这个 jpg；当期想带日期就照旧在期次目录跑默认命令，两条产物互不覆盖。底图 prompt 用第四节默认版（不写当日主线元素），保证哪一天用都不违和。

```bash
node skills/tech-express/scripts/make-cover-poster.cjs --dir "$CONTENT_DIR/tech-express/_shared" --no-date
powershell -ExecutionPolicy Bypass -File skills/tech-express/scripts/make-cover.ps1 -Dir "$CONTENT_DIR/tech-express/_shared"
```

### 4.2 压成微信可用 jpg

```bash
powershell -ExecutionPolicy Bypass -File skills/tech-express/scripts/make-cover.ps1 -Dir "$CONTENT_DIR/tech-express/<YYYYMMDD>"
```

产出 `images/00-cover.jpg`（1280 宽、质量 88）。封面图上传走工作台自带浏览器：先试一次 `upload_file`（`take_snapshot` 取封面区新 uid），不成立即转交用户手动选该文件（封面槽位共用一个 file input，不在真实手势下不会切到封面模式）。

---

## 五、原创声明与署名口径

日更简报的法律性质是「**事实 + 自主压缩表述 + 独立评论**」的编辑整理作品：事实本身不受著作权保护，受保护的是我们的压缩表达、条目选择与编排，以及短评和速递观察的观点。因此：

| 项 | 口径 |
|----|------|
| 能否点「声明原创」 | 能，但须同时满足：正文全部自主压缩（非整段搬运）、每条标媒体+日期+URL、首屏有性质声明行、有独立评论段落 |
| 首屏声明行 | 「本文为公开报道的编辑整理与独立分析，事实均来自标注来源，观点为本号所有。」——既是原创的正当性依据，也挡「冒充一手新闻」的质疑 |
| 署名 | 固定笔名 **日新**（进取、向日更新的调性），首屏「文｜日新」+ footer「日新 · …」；署名行同时是「观点为本号所有」的落款 |
| 举证材料 | `candidates.md` 台账（每条链接 + 核实状态 + 定稿口径）是被投诉洗稿时的唯一凭据，**必须落盘** |
| 谨慎项 | 含「政策·监管」条目 + 宏观数据 + 经济评论的日更，落在互联网新闻信息采编发布的边界上；**开原创 + 开留言/赞赏**等于以本号名义发布，主体为公司账号时先确认账号资质，个人号风险较低 |
| 固定免责 | 文末「不构成任何投资建议」不可删；短评与「市场同频」「市场｜」行都不得预测股价涨跌、不荐股 |

「声明原创」开关在编辑器下方详情区，**两条交付链路都不代点**（属发布口径决策），一律交用户手动开启并在汇报里提示。

---

## 六、自检清单（写入草稿前）

- 每个条目都有：领域标签 / 标题 / 压缩正文 / 关系链 / 短评 / 来源三件套（媒体名+日期+URL）
- 往日条目全部带日期徽标，且日期确为 D-1 或 D-2
- 今日条目发布日期确为 D（核实过原文页）
- 速递观察 2-4 张卡，每张都有上文事实可依
- 「市场同频」卡三地三行齐全（A股 / 港股 / 美股），美股行标明场次（北京 D 日通常对应**美东 D-1**收盘）；每个指数都是**收盘值 + 涨跌幅**，盘中数据必须写「盘中」二字
- 行情数字全部有源且经多源互证（口径见 `sources.md` 五），冲突取舍已记进 `candidates.md`；条目「市场｜」行只挂在**真有对应板块/个股行情**的条目上，无对应就不硬挂
- 行情段不预测涨跌、不荐股；footer 免责声明已覆盖「市场同频」与条目「市场｜」行
- 视觉元素 ≥3 种；全文 inline style，无 `class`，无 Markdown 残留
- CJK 字数 1500-2200（`build-inject.cjs` 打印值，**行情块与「市场｜」行计入预算，约 +300 字**），`inject-fn.js` 已由脚本生成；**确需超出上限时，要用户明确豁免，并把打印值与豁免理由记进 `candidates.md` 的「定稿口径」**，不得静默超标
- 首屏两行齐全：今日主线一句话 + 性质声明与署名行（文｜日新）；footer 笔名与三段固定块齐全
- 海外占比：今日块 ≥ 2-3 条；往日块若因时区换算（D-1 美东下午发布换算到 D 日）导致海外明显少于一半，**不塞旧闻凑占比**，改在 `candidates.md` 记「已知偏差」并说明成因
- 底部检索窗口说明 + 免责 + 关注引导三段齐全
