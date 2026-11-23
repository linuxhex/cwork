---
name: cwork-article
lazy: true
description: 微信公众号与今日头条文章写作助手。自动识别文章类型，补充必要信息（开源地址/GitHub star/系统地址等），生成吸引人的标题，提供精美排版（含 CSS 样式模板），强制生成封面图（尺寸按形态区分：图文 2560x1080 横版、贴图与页面图同规格竖版；概念插画用 ImageGen，大字报 = ImageGen 无文字纸底 + HTML 叠中文大字 + 本地 Chrome 渲染），为文章生成配图（系统真实截图 或 设计图）并嵌入正文，直接写入公众号编辑器，支持同时发布到今日头条。每次执行先与用户确认发布形态：公众号侧 图文文章 或 贴图（多图图文贴，封面图排第一张，含图片上传/排序/换封面/标题描述/保存草稿）；头条侧 文章 或 微头条（无标题无封面字段，正文+最多 18 图，含扫码登录二维码续期、逐张上传后必须点面板「确定」、存草稿后重载验图、首发声明确认）。适用于：技术分享、开源项目介绍、产品推广、教程指南、行业观察、故事/小说（武侠）。内容创作按文章类型自动调用人格 skill（cwork-tech-writer 技术布道者 / cwork-wuxia-writer 金庸式武侠）。
---

# 微信公众号与今日头条文章写作助手

## 概述

`cwork-article` 是专门用于撰写微信公众号和今日头条文章的 skill，能够自动识别文章类型，补充必要信息，生成吸引人的标题，提供精美排版（含 CSS 样式模板），**为文章生成配图（系统真实截图 或 设计图）并嵌入正文**，并直接写入公众号编辑器，支持同时发布到今日头条。

**两种发布形态（每次执行必须先与用户确认，见阶段 1.5）**：
- **图文文章** — 正文 HTML + 封面 + 文中配图，写入公众号图文编辑器
- **贴图** — 内容渲染成多张页面图，按顺序上传到公众号「贴图」草稿（图片即内容，首图即封面）

**核心能力**：
1. **文章类型识别** — 自动识别技术分享/开源项目/产品推广/教程指南
2. **必要信息补充** — 根据文章类型自动补充缺失信息（开源地址、GitHub star、安装命令、系统地址等）
3. **标题生成** — 生成 3-5 个吸引人的标题供选择（30 字内，数字/悬念触发）
4. **精美排版** — 公众号友好的排版格式（含 CSS 样式模板、主题色方案、视觉元素）
5. **写作技巧** — 开头 3 秒抓注意力、每 300 字设钩子、结尾引导互动
6. **封面图生成（强制）** — 必须实际产出封面图，尺寸按发布形态区分（图文 2560x1080 横版 / 贴图与页面图同规格竖版）：概念插画用 ImageGen；大字报 = ImageGen 无文字纸底 + HTML 叠中文 + Chrome 渲染，禁止只用文字建议
7. **文中配图生成（强制）** — 有可访问系统则截取真实页面截图；无系统则生成设计图，禁止纯文字无图文章
8. **直接写入编辑器** — 通过内置浏览器直接写入公众号图文编辑器并保存草稿
9. **贴图草稿发布** — 成稿渲染为多张页面图，封面图排第一张，上传到公众号「贴图」草稿（封面 + 页面图排序 + 标题 + 描述）
10. **多平台发布** — 支持同时发布到微信公众号和今日头条（可选；头条侧再分「文章 / 微头条」两种形态）

**工作流程（图文文章）**：
```
发布形态确认（公众号：图文/贴图；头条：文章/微头条） → 文章类型识别 → 必要信息追问（含系统地址） → 标题生成 → 封面图生成（强制，先选风格） → 文中配图生成（系统截图 或 设计图） → 内容撰写（含排版+嵌入配图） → 写入编辑器 → 保存草稿 → [可选] 发布到头条
```

**工作流程（贴图）**：
```
发布形态确认 → 文章类型识别 → 必要信息追问 → 标题生成（≤20 字） → 封面图生成（排第一张） → 内容撰写（HTML+inline CSS） → 渲染成多张页面图（元素边界切页） → 写入贴图编辑器（封面+页面图按序上传 / 标题 / 描述） → 保存贴图草稿 → 校验草稿箱
```

## 语言约束（强制）

- **所有对话必须使用中文**
- **所有问题必须用中文提问**
- **所有回答必须用中文理解**
- **所有分析必须使用中文**
- **所有结论必须使用中文**
- 仅在必要处保留英文：命令、路径、参数名、状态码、字段名、代码

---

## 产物目录（全局 contentDir，强制）

本 skill 的所有内容产物（文章档、正文 HTML、封面与配图、台账）**不再落在仓库 `docs/` 下**，统一写入外置内容目录。解析规则与命令片段见共享规范 **`cwork-common/output-dir.md`**（仓库内源文件 `skills/common/output-dir.md`）：

1. **优先级**：用户当轮指定 > 环境变量 `CWORK_CONTENT_DIR` > 仓库根 `cwork.content.json` 的 `contentDir`（当前 = `D:/zzz/articles`）> 兜底 `<repo>/docs/articles`（兜底必须告知用户）。
2. **开工即解析一次**（阶段 1 识别完文章类型、尚未写文件前），把结果存为 `$CONTENT_DIR` 并**回显一行**（如「产物目录：D:/zzz/articles/<主题>」），全程复用，不得一半写外置一半写仓库。
3. **目录结构**：`<$CONTENT_DIR>/<文章主题或系列名>/[<子篇名>]/`，配图固定放其下 `images/`，正文引用相对路径 `images/xx.png`；目录已存在即视为更新同一篇草稿，不新建第二份。
4. **禁写死绝对路径**：本文档与命令示例一律用 `$CONTENT_DIR/...` 或 `<内容目录>/...` 占位，只在真正跑命令时展开。
5. **外置产物不入 git**：不 `git add`、不随代码提交；历史 `docs/articles/**` 已于 2026-11-13 迁至 `D:/zzz/articles/**`，读到旧路径改按新位置解析。

---

## 阶段 0：人格选择（内容创作基调）

根据文章类型自动加载对应「人格 skill」，**只决定「写什么、怎么组织、什么口吻」**——**不决定最终交付格式**。最终正文必须是公众号可写的 **HTML + inline CSS**（阶段 6 排版规范），封面图/配图/写入编辑器仍由本 skill 完成。**图文文章与贴图两种形态都适用本阶段**：贴图只是把同一份 HTML 渲染成页面图，人格口吻不打折。

| 文章类型 | 调用人格 skill | 人格定位 |
|----------|--------------|----------|
| 技术分享 / 开源项目 / 产品推广 / 教程指南 / 行业观察 | `cwork-tech-writer` | 资深技术布道者：痛点共情、类比具象、讲边界与 tradeoff、数据说话、绝不标题党 |
| 故事 / 小说 / 武侠 | `cwork-wuxia-writer` | 承金庸一脉武侠小说家：章回体、半文半白、侠义为核、群像立体、武学自洽 |

**加载方式**：进入内容撰写（阶段 6）前，先读取对应人格 skill 的 `SKILL.md`（路径：`.cwork/refs/cwork-tech-writer/SKILL.md` 或 `.cwork/refs/cwork-wuxia-writer/SKILL.md`），提取其「思维框架 + 语言风格 + 写作套路」，**只作为内容创作约束**。

**硬边界（防排版被人格挤掉）**：
- 人格 skill **不替代**排版：禁止只按人格写纯 Markdown / 纯文本 / 章回散文然后交付。
- 人格产出的结构（小标题、金句、章回）必须**套进**下方 CSS 模板，变成带 inline style 的 HTML（色块、卡片、分隔线、主题色左边框）。
- 排版、封面图、配图、写入编辑器的优先级与人格口吻**同等硬约束**，不可二选一。

> 注意：行业观察类文章若用户偏观点评论，仍走 `cwork-tech-writer`（评论视角）；若偏故事化叙事，可走 `cwork-wuxia-writer`。以内容基调为准，必要时问用户一句。

---

## 阶段 1：文章类型识别

**自动识别文章类型**：

```
根据用户提供的主题/内容，自动识别文章类型：

1. 技术分享 — 技术原理、架构设计、最佳实践
2. 开源项目介绍 — 项目功能、使用方法、贡献指南
3. 产品推广 — 产品功能、使用场景、客户案例
4. 教程指南 — 步骤教程、操作指南、常见问题
5. 行业观察 — 趋势分析、市场洞察、观点评论
6. 故事/小说 — 武侠、江湖叙事、章回体故事（调用 cwork-wuxia-writer 人格）

如果无法自动识别，询问用户：
```
这篇文章属于什么类型？
1. 技术分享
2. 开源项目介绍
3. 产品推广
4. 教程指南
5. 行业观察
6. 故事/小说（武侠）
```
```

---

## 阶段 1.5：发布形态确认（强制，每次执行必问）

**任何一次执行，在写文件、写编辑器之前，都必须先与用户确认这一篇发成什么形态。** 不得由内容类型自动推定，不得默认走图文文章。

```
这一篇发成什么形态？
1. 图文文章 — 正文 HTML + 封面 + 文中配图，写入公众号图文编辑器（可同步头条）
2. 贴图 — 内容渲染成多张页面图，发到公众号「贴图」草稿（图片即内容，首图即封面）
```

**判定与约束**：

| 情形 | 做法 |
|------|------|
| 用户当轮明确说了「发文章」或「发贴图」 | 复述一次确认，记录到本次任务上下文，跳过提问 |
| 用户没说形态 | **必须提问**，等回答后再动笔 |
| 用户先前发过文章、本轮说「再来一篇」 | 仍要问形态，历史形态不作为默认 |
| 同一篇既发了图文又要发贴图 | 视为两个交付物，分别走阶段 7/8（图文）与阶段 8B（贴图），各自校验 |

选定后把形态写进本次任务的执行说明（一句话，如「本次形态：贴图（5 张页面图）」），后续阶段据此分流：

- **形态 = 图文文章** → 走阶段 2~8（阶段 4 封面、文中配图、HTML 正文、图文编辑器）+ 可选阶段 9
- **形态 = 贴图** → 阶段 4 照常生成封面图（贴图形态下**同样强制**，封面 = 第一张图）；跳过阶段 7（正文插图）；阶段 6 照常产出 HTML + inline CSS，随后走阶段 8B（渲染页面图 → 贴图编辑器 → 逐张上传 → 保存草稿）
- **给已有贴图换/补封面** → 直接走 8B.4b（整表清空重传），首图没有就地替换入口

---

## 阶段 2：必要信息追问

**根据文章类型，追问必要信息**：

### 技术分享
```
- 核心技术点是什么？（一句话概括）
- 解决什么问题？（痛点）
- 有什么数据/案例支撑？（性能提升、效率提高等）
- 涉及哪些技术栈？（语言、框架、工具）
```

### 开源项目介绍
```
- 项目名称是什么？
- GitHub 地址是什么？（必须）
- GitHub star 数是多少？（可选，可自动查询）
- 核心功能是什么？（3-5 个亮点）
- 如何安装/使用？（快速开始命令）
- 有什么典型案例？（谁在用、怎么用）
- 如何贡献？（贡献指南链接）
- License 是什么？（MIT/Apache/GPL 等）
```

### 产品推广
```
- 产品名称是什么？
- 官网地址是什么？（必须）
- 核心功能是什么？（3-5 个亮点）
- 目标用户是谁？
- 有什么客户案例？（知名客户、使用效果）
- 价格/版本信息？（免费版/付费版）
- 如何开始使用？（注册链接、试用链接）
```

### 教程指南
```
- 教程主题是什么？
- 目标读者是谁？（初学者/进阶/专家）
- 需要准备什么？（环境、工具、前置知识）
- 有几个步骤？（大概）
- 有什么常见问题？（FAQ）
```

### 行业观察
```
- 观察的主题是什么？
- 核心观点是什么？（一句话）
- 有什么数据支撑？（市场数据、调研报告）
- 涉及哪些公司/产品？
- 未来趋势是什么？
```

### 故事/小说（武侠）
```
- 故事主题/核心立意是什么？（如少年复仇、门派兴衰、家国大义）
- 时代背景是什么？（朝代/架空，关键地理与风俗约束）
- 主要人物有哪些？（主角性格弧、关键配角动机、反派执念）
- 核心冲突是什么？（主线矛盾、恩怨纠葛）
- 篇幅与章回？（短篇单回 / 中篇数回 / 长篇连载，是否留悬念引下回）
```

**追问原则**：
- **问具体，不问泛**：问"GitHub 地址是什么"，不问"项目信息有哪些"
- **问验证，不问猜测**：问"star 数是 1k 对吗"，不问"star 数大概多少"
- **一次问透，不挤牙膏**：把相关问题一次问完，不要反复问
- **确认前不动手**：所有信息确认前，不开始撰写

### 涉及系统/产品时必问（关键）

```
如果文章涉及一个可以访问的系统/产品/平台，必须追问：
- 系统访问地址是什么？（必须，用于截取真实页面）
- 是否需要登录？（需要的话，提供测试账号或让用户先登录）
- 重点展示哪些页面？（首页/核心功能页/数据看板/操作流程页）
- 有没有推荐截图的页面顺序？（可选，默认按重要程度排列）
```

**截屏前置确认示例**：
```
这篇文章涉及 XX 系统，我需要截取真实页面截图放到文章里。
请提供：
1. 系统访问地址？
2. 是否需要登录？（需要的话请先在浏览器登录好，或提供测试账号）
3. 重点展示哪些页面？（推荐：首页概览、核心功能页、数据看板）
```

---

## 阶段 3：标题生成

**生成 3-5 个吸引人的标题**：

### 标题公式

| 公式 | 示例 | 适用场景 |
|------|------|----------|
| 痛点 + 解决方案 | "还在手动部署？这个工具让你 5 分钟上线" | 技术分享、开源项目 |
| 数字 + 结果 | "3 个技巧，让代码审查效率提升 80%" | 技术分享、教程指南 |
| 对比 + 悬念 | "用了这个工具后，我再也不用加班了" | 产品推广、开源项目 |
| 权威 + 背书 | "GitHub 10k star，这个开源项目凭什么" | 开源项目介绍 |
| 场景 + 共鸣 | "每次发版都提心吊胆？你可能需要这个" | 技术分享、产品推广 |
| 热点 + 解读 | "XX 发布后，我看到了这 3 个机会" | 行业观察 |

### 标题要求

- **长度**：20-30 字（公众号标题最佳长度）
- **包含关键词**：核心主题词必须出现
- **有吸引力**：让人想点击（数字、悬念、情感触发）
- **不标题党**：内容要能支撑标题

**输出格式**：
```
以下是 5 个候选标题，请选择一个（或提出修改意见）：

1. 【痛点 + 解决方案】还在手动部署？这个工具让你 5 分钟上线
2. 【数字 + 结果】3 个技巧，让代码审查效率提升 80%
3. 【对比 + 悬念】用了这个工具后，我再也不用加班了
4. 【权威 + 背书】GitHub 10k star，这个开源项目凭什么
5. 【场景 + 共鸣】每次发版都提心吊胆？你可能需要这个

请选择（1-5）：
```

---

## 阶段 4：封面图生成（强制，不可跳过）

**图文文章和贴图都必须有封面图，必须实际产出图片文件（ImageGen，大字报还要叠 HTML 渲染），禁止只用文字描述或建议。**

- **图文文章**：封面图上传到编辑器的封面位（阶段 8），横版 2560x1080，编辑器再裁成 2.35:1
- **贴图**：**封面图就是第一张图**，竖版、与页面图同宽同量级（尺寸规则见下表），位置必须是第 1 张（阶段 8B）
- 先按「阶段 1.5」确定的发布形态取尺寸，再定风格；两种形态的封面尺寸互不通用

### 封面图规格（尺寸按发布形态区分，不可混用）

| 形态 | 尺寸 | 版式 | 落盘 |
|------|------|------|------|
| 图文文章 | **2560x1080**（21:9，接近公众号封面 2.35:1） | 横版 | `$CONTENT_DIR/<主题>/images/cover.png` |
| 贴图 | **与页面图同规格**：宽 = 页面图宽（如 1500px），高 = 页面图同一量级但**不与任何一页相同**（如各页 2784/2740/2698 时取 2600 或 2900） | 竖版 | 同上（大字报则为 `images/cover-poster.png`） |

- **贴图封面绝不能按 2560x1080 出图**：首图与后续页面图并排展示，尺寸/比例不一致会被按 3:4 裁切，横版大字报两端文字直接被切掉。
- 图文与贴图两种形态同时要发时，**各出一版**（2560x1080 给图文、页面图同规格给贴图），不要一张通吃。
- 同一篇改封面时沿用该形态原本的规格，只换图不改尺寸规则。

### 封面风格选择（先定风格，再生成）

| 风格 | 视觉特征 | 适用 |
|------|----------|------|
| 概念插画（默认） | 抽象图形、渐变、网格、无文字 | 技术分享、开源项目、产品推广、教程指南 |
| 大字报 | 超大黑体标语占满版面 + 一个点题字用对比色加重 + 纸底与主题剪影 | 故事/小说、行业观察、观点评论；用户说「直击主题、凸出观点」「像大字报」时必选 |

判断优先级：**用户当轮指定 > 故事类/行业观察/观点评论默认大字报 > 其余默认概念插画**。两种风格都算完成阶段 4，但成品必须是实际图片文件，不接受文字建议。

### 封面图 prompt 模板（概念插画，按文章类型）

**开源项目介绍**：
```
A clean, modern tech illustration for an open-source project article cover.
Central element: [项目名称] logo or abstract representation of [核心功能].
Background: gradient from [主题色] to dark, with subtle grid/code pattern.
Style: flat design, minimal, professional, no text.
Mood: innovative, trustworthy, developer-friendly.
```

**技术分享**：
```
A sleek tech article cover illustration about [核心技术点].
Central element: abstract visualization of [技术概念], e.g. interconnected nodes, data flow, architecture diagram.
Background: dark gradient with [主题色] accent glow.
Style: futuristic, clean lines, geometric shapes, no text.
Mood: cutting-edge, authoritative, insightful.
```

**产品推广**：
```
A vibrant product article cover illustration for [产品名称].
Central element: abstract representation of [产品核心价值], e.g. dashboard, workflow, happy users.
Background: gradient with [主题色] as primary, warm and inviting.
Style: modern, approachable, professional, no text.
Mood: energetic, solution-oriented, trustworthy.
```

**教程指南**：
```
A clear, friendly tutorial article cover about [教程主题].
Central element: step-by-step visual metaphor, e.g. numbered blocks, roadmap, building blocks.
Background: light gradient with [主题色] accents.
Style: clean, educational, approachable, no text.
Mood: helpful, structured, encouraging.
```

**行业观察**：
```
A thought-provoking industry analysis cover about [主题].
Central element: abstract data visualization, trend arrows, connected entities.
Background: sophisticated dark gradient with [主题色] highlights.
Style: editorial, analytical, premium, no text.
Mood: insightful, forward-looking, authoritative.
```

### 大字报封面生成（三段式：底图 AI 出、文字 HTML 叠、截图出片）

**硬约束：ImageGen 直出中文必错字/变形，大字报的中文一个字都不能交给绘图模型。**

```
1. ImageGen 出「无文字纸底」
   - name: "{主题}-poster-bg"
   - size 按形态：图文文章 2560x1080（横版）；贴图选最接近页面图比例的竖版，
     如 1024x1792（9:16，页面图约 1:1.86 时用它），HTML 里 background-size: cover 铺满目标画布
   - prompt 要素：旧纸/宣纸纹理；主题相关剪影（横版压画面下方约 1/3、偏左下；竖版放画面底部）；
     一枚暗红圆章；文字区大面积留白；
     结尾写死 "no text, no letters, no chinese characters, no watermark"
   - 落盘 $CONTENT_DIR/<主题>/images/cover-bg.png（两种形态分别命名，如 cover-bg-portrait.png，避免互相覆盖）

2. 写 $CONTENT_DIR/<主题>/cover-poster.html —— 画布尺寸按发布形态取（见「封面图规格」），
   html/body 写死该宽高、margin:0、overflow:hidden
   · 图文文章画布：2560x1080（横版，文字块占左侧约 55%，右侧留给纸底剪影）
   · 贴图画布：与页面图同宽、竖版（如 1500x2600，高度避开各页已用尺寸），文字纵向分 4~5 段，从上到下读
   版式要素（自上而下）：
   · 栏目名：横版 30~36px / 竖版 34~40px，字距拉开、左侧竖色条
   · 主标语：font-weight 900，line-height 约 1.04，最多 3 行；
     横版 font-size 150~210px，竖版按每行 4~6 字反推（一般 font-size ≈ 画布宽/每行字数 × 0.8，如 1500 宽 → 200~260px）
   · 点题字：单独用对比色（如 #9E3D2F）并再放大 30~50px，全篇只有这一处重色
   · 粗横线：横版 8~10px、竖版 10~12px 实心，同点题色，压在标语下方
   · 副标：横版 40~50px / 竖版 44~54px 粗体，一句事实 + 一句结论/反讽
   · 注（方法/局/关键词，如「空手套白狼 → 借鸡生蛋」）：横版放右侧 1~3 行，竖版放标语下方 2~4 行
   · 角标水印词：小字、字距拉开（横版左下、竖版底部居中）
   · 字体：font-family: "Noto Sans SC","Source Han Sans SC","Microsoft YaHei",sans-serif
   文案要求：标语是一句主张（不是标题复读），读者三秒内知道文章要说什么

3. 本地无头 Chrome 截图成目标尺寸（脚本 .cjs 放临时目录，用完删；
   仓库 package.json 是 "type": "module"，用 .cjs 才认 require；
   setViewport 的宽高必须与画布一致，贴图形态还须按页面图规格取宽高）
```

```javascript
// render-cover.cjs
const puppeteer = require('puppeteer-core');
const CHROME = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe'; // macOS: /Applications/Google Chrome.app/Contents/MacOS/Google Chrome
(async () => {
  const b = await puppeteer.launch({
    executablePath: CHROME, headless: 'new',
    args: ['--allow-file-access-from-files']   // HTML 用 file:// 引 cover-bg.png
  });
  const p = await b.newPage();
  await p.setViewport({ width: 2560, height: 1080, deviceScaleFactor: 1 });   // 图文形态
  // 贴图形态改为页面图规格，如 { width: 1500, height: 2600, deviceScaleFactor: 1 }
  await p.goto('file:///<内容目录>/<主题>/cover-poster.html', { waitUntil: 'networkidle0' });
  await p.evaluate(() => document.fonts.ready);
  await new Promise(r => setTimeout(r, 300));
  await p.screenshot({ path: '<内容目录>/<主题>/images/cover-poster.png' });
  await b.close();
})();
```

4. 成品 `$CONTENT_DIR/<主题>/images/cover-poster.png`：图文文章用它上传封面位，贴图把它排第 1 张。
5. **出图后必须 Read 这张 PNG 肉眼复核**（中文有无错字/断字、是否被剪影遮挡、贴图形态是否真与页面图同规格），不合格回到第 2 步改字号或留白，不要直接上传。

### 封面图生成流程

```
1. 按发布形态取尺寸（图文 2560x1080 横版 / 贴图与页面图同规格竖版）
2. 按「封面风格选择」定风格
3. 概念插画：套对应文章类型的 prompt 模板 → ImageGen（图文用 2560x1080；
   贴图选竖版 size，如 1024x1792）→ 落 images/cover.png
4. 大字报：走上方三段式 → 落 images/cover-poster.png（底图与 HTML 一并留在主题目录，便于改版）
5. 记录成品尺寸，供阶段 8/8B 上传与 8B.5 顺序校验（贴图形态首图尺寸须等于页面图尺寸）
```

### 封面图质量要求

- **概念插画无文字**：不含任何文字（标题由编辑器单独设置）；**大字报例外**，但文字只能 HTML 叠字
- **尺寸对得上形态**：图文 2560x1080 横版；贴图与页面图同规格竖版，禁止把横版封面塞进贴图列表
- **主题明确**：一眼能看出文章主题方向
- **配色协调**：与文章主题色方案一致
- **专业感**：适合技术类公众号的审美
- **清晰度高**：按目标尺寸出图；贴图形态本身就是 2x 渲染规格
- **大字报不堆字**：主标语 ≤ 3 行、副标 1 行、注释 ≤ 3 行；文字总区域不超过画面 2/3

---

## 阶段 5：文中配图生成（强制）

**每篇文章必须配图，禁止纯文字无图文章。**

### 配图来源（二选一）

```
路径 A：系统真实截图（有可访问系统时）
  → 用 ego-browser 访问系统，截取真实页面

路径 B：设计图生成（无可访问系统时）
  → 用 AI 绘图工具生成架构图、流程图、对比图、示意图
  → 或用 draw.io / Excalidraw / Figma 设计
```

### 路径 A：系统真实截图

```
触发条件（满足任一即触发）：
- 文章类型为"产品推广"或"开源项目介绍"，且涉及可访问的系统
- 文章类型为"技术分享"，且涉及实际运行的系统/平台
- 用户在追问阶段提供了系统访问地址

截屏流程：
1. 用 ego-browser 打开系统地址
2. 如需登录，确认用户已登录或协助登录
3. 规划截屏清单（3-6 张）：
   - 首页/概览页（必截）
   - 核心功能页（1-3 个）
   - 数据看板/统计页（如有）
   - 操作流程页（教程类必截）
4. 逐页截图，保存到 /tmp/wechat-article-screenshots/
5. 质量要求：数据真实、页面完整、无干扰元素、分辨率清晰
```

### 路径 B：设计图生成

```
触发条件：
- 文章不涉及可访问的系统
- 或用户明确不需要系统截图

必须生成的设计图（至少 3 张）：
1. 封面图（900x500px）— 主题相关概念图
2. 架构图/流程图（800x600px）— 展示核心原理或工作流程
3. 对比图（800x600px）— 传统方式 vs 新方案的对比
4. 功能示意图（800x600px）— 展示核心功能界面概念
5. 数据可视化图（800x600px）— 用图表展示数据/效果

设计图生成方式：
- AI 绘图：Midjourney、DALL-E、Stable Diffusion
- 工具设计：draw.io、Excalidraw、Figma
- 代码生成：Python matplotlib、Mermaid
- 模板修改：Canva、稿定设计

设计图质量要求：
- 风格统一（同一篇文章的配图风格一致）
- 信息清晰（文字可读、逻辑清楚）
- 配色协调（与文章主题色方案一致）
- 分辨率足够（至少 2x，文字清晰）
```

### 配图与文章的对应关系

```
每张配图必须服务于文章内容，不能随意插入：

| 配图内容 | 文章位置 | 作用 |
|----------|----------|------|
| 封面图 | 文章开头 | 吸引点击，展示主题 |
| 系统首页/概念图 | 产品介绍后 | 让读者看到系统全貌或核心概念 |
| 核心功能页/功能示意图 | 功能介绍段落 | 佐证功能描述 |
| 数据看板/数据可视化 | 数据/效果段落 | 用数据支撑论点 |
| 架构图/流程图 | 原理/流程段落 | 解释技术原理或工作流程 |
| 对比图 | 对比/优势段落 | 突出差异化优势 |
| 操作流程页/步骤图 | 使用教程段落 | 让读者跟着操作 |
```

### 配图数量要求

| 文章类型 | 最少配图数 | 建议配图数 |
|----------|-----------|-----------|
| 开源项目介绍 | 4 张 | 5-6 张 |
| 产品推广 | 4 张 | 5-6 张 |
| 技术分享 | 3 张 | 4-5 张 |
| 教程指南 | 4 张 | 5-6 张 |
| 行业观察 | 3 张 | 4-5 张 |

---

## 阶段 6：内容撰写与排版

**双重硬约束（缺一不可，不可二选一）**：
1. **口吻**：进入撰写前，已按「阶段 0：人格选择」加载 `cwork-tech-writer` 或 `cwork-wuxia-writer`。正文按该人格的「思维框架 + 语言风格 + 写作套路」组织——技术类布道者口吻（痛点开场、类比具象、讲边界），故事类金庸式武侠口吻（章回体、半文半白、侠义为核）。
2. **排版产出物**：最终写入编辑器的正文**必须是 HTML + inline CSS**（不是 Markdown、不是纯文本）。必须套用下方「排版规范」：主题色左边框 h2、信息卡片、提示框、对比色块、分隔线、emoji 列表——每篇至少使用 3 种视觉元素。公众号编辑器不吃 class，**所有样式写成 `style="..."`**。

**禁止**：按人格写完 Markdown 再「建议用户自己排版」；禁止只交章回/散文而无色块卡片；禁止用 class 名代替 inline style。

### 写作技巧

#### 开头技巧（3 秒抓注意力）
- **痛点开场**：描述读者熟悉的痛苦场景
- **数据开场**：用震撼的数据吸引注意
- **故事开场**：讲一个简短的真实故事
- **提问开场**：问一个读者会思考的问题

#### 正文技巧（每 300 字设钩子）
- **小标题引导**：每 300-500 字一个小标题
- **重点标注**：关键信息用**加粗**或颜色标注
- **视觉分隔**：用分隔线、色块、emoji 分隔内容
- **互动提问**：适时问读者问题，保持 engagement

#### 结尾技巧（总结升华 + 引导互动）
- **总结要点**：回顾核心内容（3-5 点）
- **升华价值**：上升到更高维度（行业、趋势）
- **引导互动**：点赞、在看、转发、留言
- **行动号召**：点击阅读原文、扫码添加、立即试用

### 底部吸粉文案（强制，每篇必须）

**每篇文章末尾必须包含底部吸粉模块，用于引导用户关注和投稿。**

#### 文案模板

```html
<!-- 分隔线 -->
<hr style="border:none;border-top:1px solid #E5DED0;margin:30px 0;">

<!-- 吸粉卡片 -->
<div style="background:#F5F0E4;border-radius:8px;padding:24px 20px;margin:0 0 20px;text-align:center;">
  <p style="margin:0 0 14px;font-size:17px;font-weight:bold;color:#6B5122;letter-spacing:1px;">关注我，讲故事给你听！</p>
  <p style="margin:0 0 14px;font-size:15px;color:#6B6055;line-height:1.7;">待到时机成熟时，漫山遍野的粉丝福利！</p>
  <p style="margin:0 0 14px;font-size:16px;font-weight:bold;color:#8C6A2F;">我有酒，你有故事吗？</p>
  <p style="margin:0;font-size:14px;color:#6B6055;line-height:1.8;">欢迎投稿：<br>邮箱 1<br>邮箱 2</p>
</div>

<!-- 二维码（居中） -->
<div style="text-align:center;margin:20px 0;">
  <p style="font-size:14px;color:#888888;margin:0 0 10px;">扫码关注，听更多故事</p>
  <img src="公众号二维码图片路径" alt="公众号二维码" style="width:200px;height:200px;">
</div>

<!-- 在看引导 -->
<p style="margin:0;text-align:center;font-size:13px;color:#AAAAAA;line-height:1.9;">觉得有用，点个「在看」<br>转给那个正在做事的朋友</p>
```

#### 文案要素说明

| 要素 | 内容 | 作用 |
|------|------|------|
| 关注引导 | "关注我，讲故事给你听！" | 明确账号定位 |
| 福利预告 | "待到时机成熟时，漫山遍野的粉丝福利！" | 给用户关注理由 |
| 互动邀请 | "我有酒，你有故事吗？" | 激发用户参与感 |
| 投稿邮箱 | 2 个邮箱地址 | 接收用户投稿 |
| 二维码 | 公众号关注二维码 | 扫码直接关注 |
| 在看引导 | "点个「在看」转给那个正在做事的朋友" | 促进传播 |

#### 二维码获取方式

```
1. 用户提供二维码图片（推荐）
2. 从微信后台下载：
   - 登录 mp.weixin.qq.com
   - 设置与开发 → 公众号设置 → 账号详情
   - 下载二维码图片
3. 保存到文章目录：$CONTENT_DIR/{文章主题}/images/qr-code.jpg（contentDir 解析见「产物目录」节）
4. 写入编辑器时插入到吸粉文案下方
```

#### 文案位置

```
文章正文
  ↓
分隔线
  ↓
吸粉卡片（关注引导 + 福利预告 + 互动邀请 + 投稿邮箱）
  ↓
二维码（扫码关注）
  ↓
在看引导
```

### 文章结构模板

#### 通用结构（问题 - 方案 - 行动）
```
# [标题]

[封面图：系统首页真实截图 或 主题相关图]

## 开头（痛点/数据/故事/提问）
[3 秒抓注意力]

## 问题描述
[为什么需要这个？痛点是什么？]

## 解决方案
[核心功能/原理/方法]

[系统截图：核心功能页真实截图]

## 实践案例
[真实案例 + 数据支撑]

[系统截图：数据看板/效果页真实截图]

## 行动指南
[如何开始使用/操作]

[系统截图：操作流程页真实截图]

## 总结
[核心要点回顾 + 升华]

## 互动引导
[点赞/在看/转发/留言]

[结尾图]
```

#### 开源项目介绍模板
```
# [标题]

[封面图：系统首页真实截图 或 项目 logo + 架构图]

## 开头（痛点场景）
[描述多服务开发的痛苦场景]

## 我们开源了 [项目名称]
[一句话介绍 + GitHub 信息卡片]

## 核心功能
[功能表格，带 emoji 图标]

[系统截图：核心功能页真实截图，展示界面实际效果]

## 快速开始
[安装命令 + 使用示例，代码块]

## 典型案例
[谁在用，怎么用，效果如何]

[系统截图：案例相关页面真实截图，展示实际使用效果]

## 为什么开源？
[开源理念，3 个要点]

## 如何贡献
[Issue/PR 链接 + 贡献指南]

## 了解更多
[官网/文档/社区链接]

[结尾图：GitHub 二维码或公众号关注二维码]
```

#### 技术分享模板
```
# [标题]

[封面图：系统真实截图 或 技术架构图]

## 开头（数据/痛点）
[震撼数据或痛点描述]

## 背景
[问题描述，为什么需要这个技术]

## 核心原理
[技术原理，配架构图]

[系统截图：相关系统页面真实截图（如有系统） 或 架构图/流程图]

## 实践案例
[具体案例，配数据对比表]

[系统截图：监控/数据看板真实截图（如有系统） 或 数据对比图]

## 最佳实践
[3-5 个实践要点]

## 总结
[核心要点回顾]

## 互动引导
[点赞/在看/转发/留言]

[结尾图：二维码或关注引导]
```

### 排版规范（CSS 样式模板）

#### 基础样式
```css
/* 全局样式 */
font-size: 16px;
line-height: 1.75;
color: #333333;
letter-spacing: 0.5px;
padding: 0 16px;

/* 标题样式 */
h1 { font-size: 22px; font-weight: bold; color: #333; margin: 20px 0; }
h2 { font-size: 18px; font-weight: bold; color: #333; border-left: 4px solid #07C160; padding-left: 12px; margin: 20px 0; }
h3 { font-size: 16px; font-weight: bold; color: #555; margin: 15px 0; }

/* 段落样式 */
p { line-height: 1.75; color: #555; margin: 12px 0; }

/* 引用块样式 */
blockquote {
  background: #f5f5f5;
  border-left: 4px solid #07C160;
  padding: 15px 20px;
  margin: 20px 0;
  color: #666;
}

/* 代码块样式 */
pre {
  background: #2d2d2d;
  color: #f8f8f2;
  padding: 20px;
  border-radius: 8px;
  overflow-x: auto;
  margin: 20px 0;
}

/* 表格样式 */
table {
  width: 100%;
  border-collapse: collapse;
  margin: 20px 0;
}
th {
  background: #07C160;
  color: white;
  padding: 12px;
  text-align: left;
  border: 1px solid #ddd;
}
td {
  padding: 12px;
  border: 1px solid #ddd;
}
tr:nth-child(even) { background: #f9f9f9; }

/* 信息卡片样式 */
.info-card {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  padding: 20px;
  border-radius: 8px;
  margin: 20px 0;
  color: white;
}

/* 提示框样式 */
.tip-box {
  background: #fff3cd;
  padding: 12px;
  border-radius: 4px;
  color: #856404;
  margin: 20px 0;
}

/* 对比布局样式 */
.comparison {
  display: flex;
  gap: 20px;
  margin: 20px 0;
}
.comparison-item {
  flex: 1;
  padding: 20px;
  border-radius: 8px;
}
.comparison-before {
  background: #ffebee;
}
.comparison-after {
  background: #e8f5e9;
}
```

#### 主题色方案

| 主题名 | 主色 | 适用场景 |
|--------|------|----------|
| 摸鱼绿 | #07C160 | 技术分享、开源项目（默认） |
| 科技蓝 | #1890FF | 技术分享、行业观察 |
| 活力橙 | #FA8C16 | 产品推广、教程指南 |
| 优雅紫 | #722ED1 | 行业观察、深度分析 |

#### 视觉元素规范

| 元素 | 样式 | 使用场景 |
|------|------|----------|
| emoji 图标 | 💬 ⚡  🐛 📝 🚀  🤖 | 列表项、功能说明 |
| 分隔线 | `<hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">` | 章节分隔 |
| 背景色块 | 渐变或纯色背景 + 圆角 | 重点信息、引用块 |
| 卡片布局 | flex 布局 + 阴影 + 圆角 | 对比展示、功能卡片 |
| 金句标注 | 居中 + 加粗 + 颜色 | 核心观点、总结句 |

#### 人格内容 → HTML 套版（强制示例）

人格决定「说什么」，套版决定「长什么样」。下面是**必须遵守**的产出形态（注意全部 `style=`，无 class）：

```html
<section style="margin-bottom: 30px;">
  <h2 style="font-size: 18px; font-weight: bold; color: #333; border-left: 4px solid #07C160; padding-left: 12px; margin: 20px 0;">章节标题（或武侠回目）</h2>
  <p style="line-height: 1.75; color: #555; margin: 12px 0;">正文段落……</p>
  <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 20px; border-radius: 8px; margin: 20px 0; color: white;">
    <p style="margin: 8px 0;">📦 信息卡片 / 金句 / 回目提要</p>
  </div>
  <blockquote style="background: #f5f5f5; border-left: 4px solid #07C160; padding: 15px 20px; margin: 20px 0; color: #666;">
    引用 / 景物留白 / 关键观点
  </blockquote>
  <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
</section>
```

武侠章回也一样：回目进 `<h2 style="border-left:...">`，景物进 `blockquote`，侠义金句进渐变色块——**不是**纯散文。

---

## 阶段 7：配图嵌入（强制）

**将阶段 4 的封面图和阶段 5 的文中配图上传到公众号编辑器并嵌入文章对应位置。**

### 配图上传流程

```
公众号编辑器图片上传机制：
- 编辑器有"插入图片"按钮，点击后弹出文件选择框
- 选择本地图片文件后，编辑器自动上传到微信服务器
- 上传完成后，图片以 <img> 标签形式插入到正文
- 图片 URL 由微信服务器生成

上传步骤：
1. 打开公众号编辑器
2. 输入标题
3. 输入正文（文字部分，不含图片）
4. 逐张上传配图：
   a. 定位到需要插入配图的位置
   b. 点击编辑器的"插入图片"按钮
   c. 选择本地配图文件上传
   d. 等待上传完成，确认图片已插入
   e. 调整图片大小和位置（如需要）
5. 保存草稿
```

### 配图嵌入位置

```
根据阶段 4 的封面图和阶段 5 的文中配图，将它们嵌入到文章对应位置：

| 配图 | 嵌入位置 |
|------|----------|
| 封面图（ImageGen 生成） | 公众号编辑器封面图位置（非正文内） |
| 系统首页/概念图 | 产品介绍段落后 |
| 核心功能页/功能示意图 | 功能介绍段落中 |
| 数据看板/数据可视化 | 数据/效果段落中 |
| 架构图/流程图 | 原理/流程段落中 |
| 对比图 | 对比/优势段落中 |
| 操作流程页/步骤图 | 使用教程段落中 |
```

### 配图质量检查

```
上传后检查：
- 图片是否清晰（文字可读）
- 图片位置是否正确（在对应段落中）
- 图片大小是否合适（不超过编辑器宽度）
- 所有配图是否都已上传（数量符合要求）
```

---

## 阶段 8：写入编辑器

### 写入流程

```
1. 打开公众号编辑器
   URL: https://mp.weixin.qq.com/cgi-bin/appmsg?t=media/appmsg_edit&action=edit&type=77&isNew=1&lang=zh_CN&token={token}

2. 输入标题
   - 找到标题输入框（第一个 contenteditable="true" 的 ProseMirror 元素）
   - 输入选定的标题

3. 输入作者（可选）
   - 找到作者输入框（input[name="author"]）
   - 输入作者名

4. 上传封面图（强制，必须执行）
   - 封面图是公众号文章在聊天列表、订阅号消息中展示的第一视觉元素
   - 公众号编辑器左侧或顶部有"封面图"上传区域（通常在标题输入框上方或文章设置面板中）
   - 上传流程：
     a. 找到封面图上传区域（选择器：.cover-wrap .upload-btn、.js_cover_area、或包含"封面"文字的上传按钮）
     b. 点击封面图上传按钮，触发文件选择框
     c. 将阶段 4 生成的封面图文件（$CONTENT_DIR/<主题>/images/cover.png 或大字报 cover-poster.png）通过 file input 上传
     d. 等待上传完成（图片预览出现）
     e. 如出现裁剪弹窗，确认裁剪（使用默认裁剪区域即可）
     f. 确认封面图已显示在编辑器中
   - 注意：封面图上传区域可能隐藏在折叠面板中，需要先展开"文章设置"或"更多设置"

5. 上传文中配图（如有真实截图）
   - 公众号编辑器不支持直接 innerHTML 插入本地图片
   - 需要通过编辑器的"插入图片"功能上传
   - 对每张截图：
     a. 定位到需要插入配图的位置
     b. 点击编辑器的"插入图片"按钮
     c. 选择本地截图文件上传
     d. 等待上传完成，确认图片已插入

6. 输入正文
   - 找到正文输入框（第二个 contenteditable="true" 的 ProseMirror 元素，包含"从这里开始写正文"）
   - 用 innerHTML 设置内容（保持 HTML 格式，含 inline CSS）
   - 文字内容中不包含图片（图片已通过步骤 5 上传）
   - 触发 input 事件

7. 保存草稿
   - 点击"保存为草稿"按钮
   - 等待保存完成
   - 确认保存成功（页面提示"已保存"）

8. 验证封面图
   - 保存草稿后，检查封面图是否已正确显示
   - 如果封面图为空，重新执行步骤 4
   - 确认草稿列表中封面图正常展示
```

### 截图上传说明

```
公众号编辑器图片上传机制：
- 编辑器有"插入图片"按钮，点击后弹出文件选择框
- 选择本地图片文件后，编辑器自动上传到微信服务器
- 上传完成后，图片以 <img> 标签形式插入到正文
- 图片 URL 由微信服务器生成，格式如：
  https://mmbiz.qpic.cn/mmbiz_xxx/xxx.png

上传策略：
- 如果截图数量 ≤ 3 张：逐张手动上传，控制插入位置
- 如果截图数量 > 3 张：先批量上传，再调整位置
- 上传后检查图片是否清晰、位置是否正确
```

### 写入代码示例

```javascript
const task = await taskSpace("公众号文章写作");
const page = task.page("p1");

// 导航到编辑器
await page.goto(`https://mp.weixin.qq.com/cgi-bin/appmsg?t=media/appmsg_edit&action=edit&type=77&isNew=1&lang=zh_CN&token=${token}`);
await page.waitForLoadState("load");
await new Promise(r => setTimeout(r, 3000));

// 关闭弹窗
try {
  await page.click("text=我知道了");
  await new Promise(r => setTimeout(r, 500));
} catch (e) {}

// 输入标题
await page.evaluate(() => {
  const editables = [...document.querySelectorAll('[contenteditable="true"]')];
  const titleArea = editables[0];
  if (titleArea) {
    titleArea.innerHTML = '<h1>文章标题</h1>';
    titleArea.dispatchEvent(new Event('input', { bubbles: true }));
  }
});

// ========== 上传封面图（强制） ==========
// 方式 1：通过封面图上传区域上传
// 找到封面图上传按钮并上传本地文件
const coverInput = await page.$('input[type="file"][accept*="image"]');
// 注意：公众号编辑器可能有多个 file input，封面图的通常是第一个或带有特定 class 的
// 如果找不到，尝试通过点击封面图区域触发 file input
if (!coverInput) {
  // 尝试点击封面图上传区域
  const coverArea = await page.$('.cover-wrap .upload-btn, .js_cover_area, [class*="cover"]');
  if (coverArea) {
    await coverArea.click();
    await new Promise(r => setTimeout(r, 1000));
  }
}
// 上传封面图文件
const coverFilePath = '<内容目录>/<主题>/images/cover.png'; // 大字报则为 cover-poster.png
const fileInput = await page.waitForSelector('input[type="file"][accept*="image"]', { timeout: 5000 });
await fileInput.setInputFiles(coverFilePath);
// 等待封面图上传完成
await new Promise(r => setTimeout(r, 3000));
// 如果出现裁剪弹窗，点击确认
try {
  await page.click('text=确定', { timeout: 3000 });
  await new Promise(r => setTimeout(r, 1000));
} catch (e) {}
// 验证封面图已上传
const coverPreview = await page.$('.cover-wrap img, .js_cover_preview img, [class*="cover"] img');
if (!coverPreview) {
  console.warn('封面图上传可能失败，需要手动检查');
}

// 输入正文
await page.evaluate(() => {
  const editables = [...document.querySelectorAll('[contenteditable="true"]')];
  // 正文区域（包含"从这里开始写正文"的 ProseMirror 元素）
  const contentArea = editables.find(el => el.textContent.includes('从这里开始写正文')) || editables[2];
  if (contentArea) {
    contentArea.innerHTML = `
      <section style="margin-bottom: 30px;">
        <h2 style="color: #333; border-left: 4px solid #07C160; padding-left: 12px; margin: 20px 0;">章节标题</h2>
        <p style="line-height: 1.75; color: #555;">正文内容</p>
        <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 20px; border-radius: 8px; margin: 20px 0; color: white;">
          <p style="margin: 8px 0;">📦 重点信息</p>
        </div>
      </section>
    `;
    contentArea.dispatchEvent(new Event('input', { bubbles: true }));
  }
});

// 保存草稿
await page.click("text=保存为草稿");
await new Promise(r => setTimeout(r, 3000));

// 验证封面图是否保存成功
// 返回草稿列表页检查封面图是否正常显示
```

---

## 阶段 8B：贴图草稿写入（发布形态 = 贴图时执行）

**贴图 = 图片即内容**：正文不出现在编辑器里，编辑器中只有图片、标题、描述。**第一张图就是封面**，因此第 1 张必须是阶段 4 生成的封面图，后续才是正文页面图（page-01、page-02……）。上限 20 张，标题 ≤ 20 字，描述 ≤ 1000 字。

### 贴图 vs 图文文章

| 项 | 图文文章 | 贴图 |
|----|----------|------|
| 编辑器入口 | `t=media/appmsg_edit&action=edit&type=77` | `t=media/appmsg_edit_v2&action=edit&type=77&createType=8` |
| 内容载体 | 正文 HTML（inline CSS） | 多张页面图 |
| 封面 | 单独上传/裁剪为 2.35:1，横版 2560x1080 | **第一张图即封面**，竖版且**与页面图同规格**（排第 1 位） |
| 标题长度 | 30 字以内为佳 | **≤ 20 字**（硬限制） |
| 附加文案 | 正文 + 吸粉卡片 | 描述 ≤ 1000 字 |
| 图片上限 | 无此限制 | 20 张（1 封面 + 至多 19 页） |
| 头条同步 | 支持 | 不支持 |

### 8B.1 前置：封面图 + 成稿渲染为页面图

贴图形态的封面**不用阶段 4 的横版成品**，必须按页面图规格重出一版竖图，落到 `$CONTENT_DIR/<主题>/images/cover.png`（大字报则为 `images/cover-poster.png`），它就是贴图的第 1 张。阶段 7（正文插图）跳过，阶段 6 照常产出 `article.html`（750px 宽 + inline CSS），再渲染切页：

```
0. 封面图（贴图形态）：与页面图同规格重新出图，不复用图文草稿的 2560x1080
   - 宽度 = 页面图宽度（如 1500px）；高度取页面图同一量级，但**不与任何一页完全相同**
     （便于 8B.5 用尺寸指纹确认首图，如 page 为 2784/2740/2698 时封面取 2600 或 2900）
   - 概念插画：ImageGen 选竖版 size（如 1024x1792），再按目标尺寸裁放
   - 大字报：按竖版画布重写 cover-poster.html（见阶段 4 大字报三段式），
     与页面图共用同一套 750 CSS 宽 + deviceScaleFactor 2 的渲染参数
   - 图文与贴图两种形态同时发 → 各出一版，互不覆盖（可命名 cover.png / cover-portrait.png）
1. 本地无头 Chrome + puppeteer-core，viewport 750 宽、deviceScaleFactor 2
   - 仓库 package.json 是 "type": "module"，脚本必须用 .cjs 扩展名
2. 取文章根容器及其直接子元素的边界，按子元素装页，单页 CSS 高度上限约 1400px，
   绝不切在元素中间（文字被切断是硬伤）
3. 逐页 clip 截图（captureBeyondViewport: true），输出
   $CONTENT_DIR/<主题>/images/page-01.png ~ page-NN.png
4. 记录封面与每页的实际尺寸，供阶段 8B.5 顺序校验（首图尺寸应与页面图同宽同档高）
```

**发布顺序固定为**：`cover.png`（大字报为 `cover-poster.png`）→ `page-01` → `page-02` → …… → `page-NN`（共 N+1 张，≤ 20）。

> 页面图是内容产物，落在 `$CONTENT_DIR` 下，不入 git。渲染脚本可放临时目录，用完删除。

### 8B.2 打开贴图编辑器

```javascript
// 新建（首页「新的创作 → 贴图」等价于这个 URL）
`https://mp.weixin.qq.com/cgi-bin/appmsg?t=media/appmsg_edit_v2&action=edit&isNew=1&type=77&createType=8&token=${token}&lang=zh_CN`
```

首页「新的创作」中的「贴图」是 `.new-creation__menu-item`（文本节点不可点击），用 JS `el.click()` 触发。

**编辑已有贴图草稿：不要拼 URL**（`appmsg_edit_v2&...&appmsgid=` 与 `appmsg_edit&reprint_confirm=0&appmsgid=` 都会报「系统错误(320003)」）。走草稿箱列表点进去：

```javascript
// 1) 草稿箱列表（切「贴图」Tab 后 URL 带 item_show_type=8）
// 2) 卡片标题 <a> 的 click 在本环境不跳转，要点卡片动作区的铅笔（第 2 个图标 = 编辑）
const btn = [...document.querySelectorAll('.weui-desktop-card__action .weui-desktop-icon-btn')][1];
btn.click();   // 跳转后 URL 形如 appmsg_edit&action=edit&type=77&appmsgid=xxx&isMul=1
```

动作区图标顺序为「删除 / 编辑 / 其他」；该按钮只在卡片可视区渲染，点前先 `window.scrollTo(0,0)`，否则 rect 为负导致点击无效。

### 8B.3 编辑器结构

| 元素 | 选择器 / 特征 |
|------|--------------|
| 图片区 | `.image-selector` |
| 已加图片列表 | `.image-selector__bottom-list`（子元素数 = 图片张数） |
| 追加图片按钮 | `.image-selector__bottom-add`（0 张时是 `.image-selector__add`） |
| 首图预览 | `.image-selector__preview-center-img` |
| 标题 | 第 1 个 `[contenteditable="true"]` ProseMirror，≤ 20 字 |
| 描述 | 第 2 个 `[contenteditable="true"]` ProseMirror，≤ 1000 字 |
| 保存 | `button` 文本「保存为草稿」 |

### 8B.4 上传图片（默认走本地上传，逐张）

**贴图增/换图只有这一条可靠路径**：从 `.image-selector__bottom-add`（0 张时是空态「选择或拖拽图片」区）打开的「从图片库选择」弹窗是**单选 + 「下一步」**模式（`.weui-desktop-img-picker__item` 同一次只能选中 1 张，底部没有「已选择 N/M」和「确定」），批量选图不可用。要一次排好顺序，就逐张本地上传。

```
1. 找到 `.js_upload_btn_container input[type=file]`（默认隐藏，父级浮层 display:none）
2. 就地改成可见（display/尺寸/opacity/position），必要时给隐藏祖先临时加可见样式；
   不要把它移出父级，更不要删除节点 —— 组件后续重建会依赖原始节点
3. take_snapshot 取 uid → upload_file 上传单张 → 等 4~5s
4. 每上传一张都要重新执行 1~3（含重新 take_snapshot 取新 uid）：组件会重建 input，
   复用旧 uid 会「上传成功但图片不增加」（静默失败，必须靠数量校验发现）
5. 每步校验 `.image-selector__bottom-list` 子元素数是否 +1，没涨就重做 1~3
```

**新图入库（可选，便于人工辨认）**：图片库弹窗内也有隐藏 `input[type=file]`，露出后 upload_file，
上传后按时间倒序排在第一位；但选它仍需逐张走「下一步」，所以只在需要留档时用。

**顺序 = 加入顺序**：列表没有「插入到第 0 位」，新图一律追加到末尾。所以**封面图必须第一个上传**，再按 page-01、page-02…… 依次上传。

### 8B.4b 已有草稿加/换封面（清空 → 按序重传）

贴图列表项只有「编辑」（裁剪）和「删除」（`.comm_del`）两个按钮，**没有替换某一张图的入口**；
拖拽排序在自动化里不可控。所以换首图只能整表重建：

```
1. 进编辑器（见 8B.2 的草稿箱铅笔入口）
2. 从末尾开始逐项点 `.weui-desktop-drag-list__item` 内的 `.comm_del`，每张之间留 300~400ms；
   删到 0 张时 `.image-selector__bottom-list` 节点会整体消失（属正常，用「找不到 list」当完成信号），
   添加区恢复为空态「选择或拖拽图片」
3. 按 8B.4 逐张上传：cover(-poster) → page-01 → …… → page-NN
4. 按 8B.5 校验张数与首图尺寸，按 8B.6 复核标题/描述未丢，再按 8B.7 保存
   （同一 appmsgid 覆盖更新，不新建第二份草稿）
```

> 清空前确认所有目标图仍在 `$CONTENT_DIR/<主题>/images/` 下，重建只是重新上传；
> 若只想换封面且页面图未变，仍必须整表重建（首图无法就地替换）。

### 8B.5 顺序校验（必做）

列表顺序 = 发布顺序，顺序错了整篇乱。用图片实际尺寸比对源图：

```javascript
// 逐项取背景图 URL，new Image() 读取 naturalWidth/naturalHeight
// 第 1 项必须等于「贴图封面成品」的实际尺寸（与页面图同宽、竖版、高度自成一档）
// 第 2 项起依次对应 page-01..NN 的 2 倍 CSS 高度
```

页面图高度各不相同（切页按内容长度），因此尺寸是可靠指纹；若尺寸相同，按文件内容/文件名顺序人工核对。

**贴图封面与页面图同宽后，靠高度区分**：出封面时把高度定成与所有 page 都不相等的值（例如同为 1500 宽，page 为 2784/2740/2698/2642/1372，封面取 2700 之外的另一个整数，如 2600 或 2900），否则首图指纹会和某页撞车、无法判断顺序。上传本身是严格按序逐张校验的（计数 +1 才传下一张），尺寸校验只做兜底。

### 8B.6 填写标题与描述

```javascript
const eds = [...document.querySelectorAll('[contenteditable="true"]')];
const title = eds[0];            // ≤ 20 字，超长会被截断
title.querySelector('p').textContent = '标题';
title.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText' }));

const desc = eds[1];             // ≤ 1000 字，建议 60~120 字钩子
desc.querySelector('p').textContent = '描述';
desc.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText' }));
```

### 8B.7 保存与校验

```
1. 点「保存为草稿」：MCP click 常返回成功但不发保存请求
   → 用 JS 取到该 button 后 .click() 兜底
2. 成功判据：
   - 新建：location.href 出现 appmsgid=<新 id>
   - 编辑已有草稿（URL 本来就带 appmsgid）：看编辑器「历史版本」表新增一行（更新时间 + 手动保存），
     或页面出现「已保存」文案；不要只看 URL
3. 复核：重新读取标题、描述、.image-selector__bottom-list 子元素数与首图尺寸
4. 草稿箱核对：/cgi-bin/appmsg?begin=0&count=10&type=77&action=list_card
   → 切「贴图」Tab（切后 URL 带 item_show_type=8）→ 卡片标题、更新时间正确；
     换封面场景还要核对卡片缩略图 URL 是否已变（旧图 URL 仍在 = 没保存成功）
```

### 8B.8 贴图自动化踩坑清单

| 现象 | 原因 | 处理 |
|------|------|------|
| 「上传成功」但图片数不变 | 组件重建了 file input，旧节点已脱离 | 每张上传前重新定位 input；原始节点不要移走或删除 |
| 点「本地上传」按钮报「被遮挡」 | 上方有透明 `<label>` 覆盖 | 直接给 `input[type=file]` 及隐藏祖先加可见样式后 upload_file，别点按钮 |
| 图片库勾了 6 张只进去 1 张 | 贴图编辑器的图片库弹窗是**单选 + 「下一步」** | 逐张「下一步」，或干脆走 8B.4 本地上传逐张 |
| 点「从图片库选择」后无弹窗 | 链接需真实点击 | 用 MCP click 点该 anchor，不用合成事件 |
| 「确定」按钮尺寸为 0 | 选中了同名隐藏弹窗的按钮 | 按 `getBoundingClientRect().width > 0` 过滤后点击 |
| 想换某一张图找不到入口 | 列表项只有「编辑(裁剪)/删除」，没有替换 | 按 8B.4b 整表清空重传 |
| 删图时点几下就报「找不到列表」 | 删到 0 张时 `.image-selector__bottom-list` 节点整体消失 | 当作删除完成的正常信号，不是失败 |
| 拼 appmsgid 的编辑 URL 报「系统错误(320003)」 | 贴图草稿不支持直接 URL 进入 | 从草稿箱卡片动作区铅笔（第 2 个 `.weui-desktop-icon-btn`）JS click 进入 |
| 点卡片标题不跳转 | 该 `<a>` 的 click 在本环境无效，或图标 rect 为负 | `scrollTo(0,0)` 后点铅笔图标 |
| 保存无反应 | 保存按钮事件需真实点击 | JS `.click()` 兜底，再按 8B.7 的历史版本/「已保存」判定 |
| 截图工具报 `NATIVE_BROWSER_VIEWPORT_UNAVAILABLE` | 内嵌浏览器无可视表面 | 全程改用 `evaluate_script` 读 DOM 与图片尺寸校验 |

---

## 阶段 9：发布到头条（可选）

**当用户要求同时发布到今日头条时，执行此阶段。**

### 9.0 先确认头条发布形态（必问，不可默认）

| 形态 | 页面 | 结构 | 本 skill 对应 |
|------|------|------|--------------|
| **文章** | `/profile_v4/graphic/publish` | 标题（2-30 字）+ 长正文 + 强制封面图 | 下方 9.1~9.5 |
| **微头条** | `/profile_v4/weitoutiao/publish` | 无标题、无封面字段，正文 + 最多 18 张图 | 见「9B 微头条发布」 |

- 用户说「发微头条 / 发头条动态」→ 走 9B；说「发文章 / 发文」→ 走 9.1~9.5；只说「发头条」→ 问一句形态。
- 与公众号侧同理：**每轮开工先确认形态，两侧的形态选择是独立的两问**（公众号图文/贴图、头条文章/微头条）。
- 内容压缩口径：微头条没有独立标题位，文章标题要并进正文第一行；长文压到 500-800 字，保留主线冲突、复盘要点与免责说明。

### 9.1 登录（两种形态共用）

```
URL: https://mp.toutiao.com/auth/page/login?redirect_url=<编码后的目标路径>
未登录访问 publish 页会自动跳转此处，登录方式：今日头条 App 扫码。

⚠️ 二维码约 60 秒过期，必须做续期，否则用户每次点开都是废码：
- 过期标志：<p class="web-login-scan-desc"> 文本变成「二维码已失效点击刷新」
- 刷新入口：同级的 span.web-login-scan-desc__btn（cursor:pointer）
- 有效手法：对该 span 依次派发 mousedown / mouseup / click 三个 MouseEvent
  （点 <p> 本身、点父容器都无效；实测点 span 后 img[src^=data:] 的 base64 会变）
- 常驻续期：在页面里 setInterval 每 3 秒执行一次上面的检测+刷新，
  因为 evaluate_script 单次调用 15 秒超时，写自轮询 await 循环等不到跳转
- 登录成功判据：URL 不再是 auth/page/login，且 publish 页出现编辑器
```

### 9.2 头条文章发布流程

```
1. 登录头条创作者后台
   URL: https://mp.toutiao.com/profile_v4/graphic/publish
   登录方式：扫码登录（用今日头条 App 扫码）
   
2. 填写标题
   - 标题输入框：textarea[placeholder="请输入文章标题（2～30个字）"]
   - 标题长度：2-30 字（比公众号标题短）
   - 设置值后需触发 input 事件：
     ```javascript
     const nativeInputValueSetter = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, 'value').set;
     nativeInputValueSetter.call(titleInput, '标题内容');
     titleInput.dispatchEvent(new Event('input', { bubbles: true }));
     ```

3. 填写正文
   - 正文编辑器：contenteditable=true 的 div
   - 支持 HTML 格式（与公众号相同的 inline CSS）
   - 设置 innerHTML 后触发 input 事件

4. 上传封面图（强制）
   - 头条要求必须上传封面图才能发布
   - 封面图选项：单图 / 三图 / 无封面
   - 推荐选择"单图"
   - 上传区域：.article-cover-add 按钮
   - 上传手法：**先按 9B.3 的本地上传循环试自动上传**（点「图片/封面」入口 → take_snapshot 取
     input[type=file] 的 uid → upload_file）。微头条侧已实测自动化可行，文章侧不必一上来就甩给用户手动。
   - 仅在弹窗为原生文件选择器、拿不到 input[type=file] 节点时，才降级为提示用户手动选文件

5. 发布
   - 点击"预览并发布"按钮
   - 确认发布成功（页面跳转到文章详情页）
```

### 头条与公众号的差异

| 项目 | 公众号 | 头条文章 | 头条微头条 |
|------|--------|---------|-----------|
| 标题长度 | 最多 64 字 | 最多 30 字 | **无标题字段**（标题并到正文首行） |
| 封面图 | 可选（建议上传） | 强制（必须上传） | **无封面字段**，大字报封面排第一张图 |
| 正文格式 | HTML + inline CSS | HTML + inline CSS（相同） | 纯文本 + 换行（不吃 inline CSS） |
| 编辑器 | ProseMirror | contenteditable div | ProseMirror（`.ProseMirror` 单框） |
| 配图 | 正文内嵌 | 正文内嵌 | 最多 18 张附图，单图 ≤20MB |
| 发布方式 | 保存草稿 / 群发 | 预览并发布 | 存草稿 / 发布（发布后默认「审核中」） |
| 错别字检测 | 无 | 有（自动检测） | 有（自动检测） |
| 首发声明 | 无 | 有（头条首发，72小时独占） | 有，**且默认已勾选** |
| 广告投放 | 无 | 有（投放广告赚收益） | 默认联动「同时发布文章和微头条」，不可取消 |
| 赞赏功能 | 无 | 有（每日限额） | 有（每日限额） |

### 头条特有设置

```
1. 投放广告
   - 投放广告赚收益（推荐开启）
   - 不投放广告

2. 声明首发
   - 头条首发：72小时内仅在头条发布，可享额外激励分成
   - 授权平台自动维权

3. 合集
   - 可添加至已有合集

4. 发文特权
   - 允许赞赏（每日限额）
   - 同时发布微头条（发布得更多收益）

5. 作品声明
   - 取材网络
   - 引用站内
   - 个人观点，仅供参考
   - 引用AI
   - 虚构演绎，故事经历
   - 投资观点，仅供参考
   - 健康医疗分享，仅供参考
```

### 头条封面图规格

| 属性 | 值 |
|------|-----|
| 尺寸 | 16:9（推荐 1280x720 或 1920x1080） |
| 格式 | JPEG / PNG |
| 大小 | 不超过 5MB |
| 风格 | 与公众号封面图相同（可复用） |

### 头条发布代码示例

```javascript
// 导航到头条创作者后台
await page.goto('https://mp.toutiao.com/profile_v4/graphic/publish');
await page.waitForLoadState('load');

// 填写标题
await page.evaluate(() => {
  const titleInput = document.querySelector('textarea[placeholder="请输入文章标题（2～30个字）"]');
  if (!titleInput) return { error: 'no title input' };
  const nativeInputValueSetter = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, 'value').set;
  nativeInputValueSetter.call(titleInput, '文章标题');
  titleInput.dispatchEvent(new Event('input', { bubbles: true }));
  titleInput.dispatchEvent(new Event('change', { bubbles: true }));
});

// 填写正文
await page.evaluate(() => {
  const editor = [...document.querySelectorAll('[contenteditable=true]')].find(el => el.textContent.includes('请输入正文'));
  if (!editor) return { error: 'no editor' };
  editor.focus();
  editor.innerHTML = '<p>正文内容...</p>';
  editor.dispatchEvent(new Event('input', { bubbles: true }));
});

// ⚠️ 封面图上传需用户手动操作
// 提示用户：
// 1. 点击"单图"选项
// 2. 点击上传按钮
// 3. 选择本地封面图文件

// 发布
await page.evaluate(() => {
  const publishBtn = [...document.querySelectorAll('button')].find(el => el.textContent.trim() === '预览并发布');
  if (!publishBtn) return { error: 'no publish button' };
  publishBtn.click();
});
```

### 头条发布注意事项

```
1. 登录态保持
   - 头条登录态有效期较短，建议每次发布前重新登录
   - 扫码登录后立即发布，避免登录过期

2. 封面图强制要求
   - 头条必须上传封面图才能发布
   - 浏览器安全限制无法自动上传，需用户手动操作
   - 可复用公众号封面图（调整尺寸为 16:9）

3. 错别字检测
   - 头条有自动错别字检测功能
   - 发布前检查并修正检测到的错别字
   - 常见错别字：即是→既是、还走→还有 等

4. 首发声明
   - 如选择"头条首发"，72小时内不能在其他平台发布
   - 如需多平台同步发布，不要选择首发声明

5. 发布时间
   - 头条推荐算法对发布时间敏感
   - 推荐发布时间：早 7-9 点、午 12-14 点、晚 18-22 点
```

### 9B 微头条发布（2026-11-19 实测流程）

**用户要求发微头条时走这一节，与上面的文章流程互斥（除「同时发布文章和微头条」默认联动，见 9B.4）。**

#### 9B.1 页面与结构

```
URL: https://mp.toutiao.com/profile_v4/weitoutiao/publish
未登录会跳 9.1 的登录页；登好自动回跳。

| 元素 | 选择器 / 说明 |
|------|--------------|
| 正文编辑器 | `.ProseMirror`（contenteditable，占位「有什么新鲜事想告诉大家？」）**无标题字段** |
| 工具栏 | `button.syl-toolbar-button`，文本依次为 图片 / 表情 / 话题 / 文档导入 |
| 图片上传面板 | 点「图片」后出现 `.upload-image-panel`，含两个 `input[type=file][multiple][accept="image/*"]`；底部按钮 保存到我的素材 / 取消 / **确定** |
| 已选图片区 | 点「确定」后才出现：`.img-form-wrap`（文本「共 N 张，还能上传 M 张」）> `.img-box-item > span.item`，缩略图走 `background-image` |
| 作品声明 | 每个选项是一个 `label.byte-checkbox`，文本如「虚构演绎，故事经历」 |
| 首发声明 | `.exclusive-checkbox-wraper` 内的 `label.byte-checkbox`（文本「头条首发」） |
| 按钮 | `button` 文本「存草稿」/「发布」 |
| 字数校验 | 页面文本「正文字数：N」 |

- 图片上限 18 张（面板文案「共 N 张，还能上传 M 张」可直接读余量），单图 ≤20MB，支持 jpg/jpeg/png。
- **图片集选什么（用户已明确过一次口径）**：故事/贴图类发微头条，默认发**故事内容的页面图**（就是渲染切出来的 page-01…N），
  不要把大字报封面混进去当第一张——大字报是贴图草稿的封面位，微头条侧的载体是内容截图本身。
  只有用户点名要封面图时才加，且加在第 1 张。
- 正文因此是**短导语**（约 150-250 字）：标题句 + 一句钩子 + 「全文 N 张图」的指代 + 化名/推测免责；
  不要把整篇正文再抄一遍，图和字重复会被判低质，也白占字数。
```

#### 9B.2 填正文

```javascript
// execCommand 会把 \n 直接切成多个 <p>，占位文字不会混进正文，最省事
const lines = [
  '养猪场养的不是猪，是人（江湖故事集）',   // 标题并到第一行，微头条没有标题位
  '',                                        // 空行做段落间距
  '……',
];
const pm = document.querySelector('.ProseMirror');
pm.focus();
document.execCommand('insertText', false, lines.join('\n'));
// 校验：pm.children.length 应等于段落数；document.body.innerText 里的「正文字数：N」
```

- 写完必须回读 `pm.children` 逐段确认，别只信 execCommand 的返回值。
- 空格占位的空行会渲染成「 」段落，可接受；要更干净就留空字符串段落。

#### 9B.3 上传图片（逐张，同一 uid 可复用）

```
1. JS click 工具栏「图片」按钮（button.syl-toolbar-button，文本匹配「图片」）
2. take_snapshot，取「本地上传」下的 选择文件 input uid
   （.btn-upload-handle 里那个；.upload-handler-drag 里的是拖拽区，别用）
3. upload_file 一次一张（工具不支持一次多张），每张之间等 2.5-3.5 秒
4. 面板文本会显示「已上传 N 张图片，支持拖拽调整图片顺序」，
   缩略图在 .upload-image-panel img，src 变为 https://image-tt-private.toutiao.com/...（私有域，审核后才转公开域），
   用 naturalWidth/naturalHeight 与本地文件尺寸指纹逐项比对，确认张数与顺序
5. 关键差异（与公众号贴图相反）：**面板节点不会重建，同一 uid 连续上传会累加**，
   不需要每张重新 take_snapshot
6. ⚠️ **必须点面板底部的「确定」，否则图片全部作废**（面板按钮是「保存到我的素材 / 取消 / 确定」）：
   只 upload 不点确定 → 存草稿成功、正文也在，但服务端 `images` 是 `null`，草稿等于没配图。
   点完确定的判据是面板关闭 + 正文区下方出现 `.img-form-wrap`，文本「共 N 张，还能上传 M 张」。
7. 「确定」之后面板会关闭，此时再核一次张数与尺寸指纹（`.img-box-item` 个数），才算图片真正挂上这条内容。
```

- 确认后图片**不在 `.ProseMirror` 里**（那里查 img 永远是 0），而是独立的 `.img-box-item` 容器，
  缩略图用 `background-image` 渲染（`p3-sign/p11-sign.toutiaoimg.com/...`）。
  所以「正文无 img 节点」不等于没图，**核验一律看 `.img-form-wrap` 的张数文案，或直接查服务端 `images` 字段**。

#### 9B.4 发布前必查的三个勾（默认值有坑）

| 选项 | 默认 | 可否改 | 处理 |
|------|------|--------|------|
| 头条首发 | **已勾** | 可取消 | 若同一内容还要发公众号/多平台，**必须问用户后取消**（等于承诺 72 小时仅在头条） |
| 同时发布文章和微头条（发布得更多收益） | 已勾 | `byte-checkbox-disabled`，取消不了 | 告知用户：发布会额外生成一篇文章，不是只做微头条 |
| 作品声明 | 全不勾 | 可勾 | 故事/虚构类勾「虚构演绎，故事经历」；实测勾这类声明不会拦发布，但不勾更容易被限流 |

```javascript
// 通用勾选：定位 label 后合成三个事件，用 classList 是否含 byte-checkbox-checked 判定
const cb = [...document.querySelectorAll('.byte-checkbox')]
  .find(e => /头条首发/.test(e.innerText));
['mousedown','mouseup','click'].forEach(t =>
  cb.dispatchEvent(new MouseEvent(t, { bubbles: true, cancelable: true, view: window })));
// 复核：列回所有含 byte-checkbox-checked 的 label 文本，确认最终勾选集合符合预期
```

#### 9B.5 存草稿（默认终点）与发布（需用户明确指令）

```
硬约束：微头条的自动化终点是「存草稿」，不是「发布」。
默认只点 `button` 文本严格等于「存草稿」；「发布」按钮由用户自己点。
只有用户当轮明说「直接发布 / 你发出去」时，才可以点「发布」。
（用户原话：发布到草稿后，我来确认，之后我手动发布。）

核验方法论（本轮真实教训：我曾据此向用户误报「草稿已带 5 图」）：
判据只认**最终载体**——落库字段，或重新载入后的页面回显；
不认上传面板缩略图、不认 `draft_count`、不认「按钮点下去了」。
面板里有图 ≠ 表单里有图，中间还隔着一个「确定」。

存草稿后的校验（**不能只看页面反应，也不能只看 draft_count——count 不变也可能是覆盖同一条**）：
1. 页面不跳转、无 toast —— 不能靠跳转判定，静默失败长得一模一样。
2. **终局判据 = 重新载入这条草稿**（`reload` 当前 `publish?draft_id=<gid>`），然后查：
   - 正文：`.ProseMirror` 字数回显一致；
   - 图片：`.img-form-wrap` 文本「共 N 张」且 `.img-box-item` 个数 == N（缩略图是 background-image，`img[src*=toutiaoimg]` 可能抓不到）。
   重载后没图 = 这次保存里图片就是空的（十有八九是漏点面板「确定」，见 9B.3 第 6 步）。
3. 服务端真值接口（页内 fetch，带 cookie）：
   - 单条草稿：`/mp/agw/draft/get_ugc_draft?draft_type=1&gid=<draft_id>&app_id=1231`，
     `draft.origin_draft` 是 JSON 字符串，`content` / `images` 就是落库真值；`images: null` 即无图。
   - 计数：`/mp/agw/creator_center/draft_count?type=0&app_id=1231` 的 `count`；
   - 列表：`/mp/agw/creator_center/draft_list/?type=0&offset=0&count=5&app_id=1231&draft_type=1`
     （**必须带 `draft_type=1`**，不带时返回空数组，别误判成没草稿）。
4. 成功时 localStorage 键 `wtt-mpformdraft` 会被**清空**（保存成功后清本地缓存）；
   若该键还在且 `form.nowPicList=[]`、`form.content=''`，说明这次没存进去。
5. 内容管理页 tab 显示「草稿箱 (N)」，点击跳 `profile_v4/manage/draft`，
   行元素 `.weitoutiao-draft-item`，行内有「编辑 / 删除」；草稿行同样不渲染图片缩略图。
6. ⚠️ **纯图无正文存不了草稿**：正文字数为 0 时点「存草稿」静默失败，
   且会把上一个草稿槽顶空（旧草稿随之消失）。图片-only 需求要先落地一行最小正文（标题句即可）。
7. ⚠️ **作品声明不随草稿保存**：存完草稿重新打开，「虚构演绎，故事经历」等声明回到全不勾，
   「头条首发」也会回到默认勾选。发布前必须再核一遍这三个勾（见 9B.4）。

若真要发布（用户明确指令）：
1. JS click 文本严格等于「发布」的可见 button（顶部「开始创作」也是 primary，别点错）。
2. 成功判据：URL 跳到 https://mp.toutiao.com/profile_v4/weitoutiao，列表首条 `.post-item`
   状态标签「审核中」、「修改」置灰。
3. ⚠️ 该列表行**不渲染任何图片节点**（更早的已发布条目也一样）——
   不能据此判定图片没传上。
4. 审核期无法从后台核验图，等状态转「已发布」后再回列表/公开页复核。
```

#### 9B.7 加话题（#xx#，实测 2026-11-19）

话题**必须走面板选**，它是富文本节点；直接 `insertText('#人性#')` 只是普通字符，不生成话题、不带曝光。

```
1. 先定光标（话题插在 caret 处，不定就往文首跑）：
   const last = pm.querySelectorAll('p'); 取目标段落，Range.selectNodeContents(p) + collapse(false)，
   pm.focus() 后 sel.removeAllRanges()/addRange(r)
2. JS click 工具栏「话题」（button 文本严格等于「话题」）
   → 出现 section.mention-selector-modal.forum + input[placeholder="搜索话题"]
   → 默认 tab 是「最近使用 / 热门话题」，条目结构：
     section.forum-list-item > div > span.forum-list-item-text（话题名叶子） + div（「25万讨论」）
3. 搜索：native value setter 写 input + dispatchEvent('input')，等 1.6-2 秒出结果
4. ⚠️ 点击只打在**叶子 span.forum-list-item-text**（或 section.forum-list-item）上，
   事件序列用 pointerdown/mousedown/pointerup/mouseup/click（带 clientX/clientY 中心坐标）。
   打错到上层列表容器 → 平台会把整段推荐列表当纯文本灌进正文，
   生成 `#骗局#@跑路@义气` 这种半截脏碎片（实测踩过，且这种碎片会跟着草稿一起落库）。
   Enter / ArrowDown 键在搜索框里无效，别指望键盘选择。
5. 校验：每个话题在 DOM 里是 2 个节点（<templ> 和 <mask> 各一份），计数要去重：
   [...new Set([...document.querySelectorAll('a.tteditor-forum')].map(a => a.dataset.name))]
   节点形如 <a class="tteditor-forum" data-name="人性" data-concern-id="1607…">#人性#</a>
```

- **搜不到时条目会变「创建新话题」**（讨论量 0）。新话题没有存量流量，除非用户点名，
  优先选带讨论量的现成话题（实测同名词常有多个候选，取讨论量最高那个）。
- 话题选几个属于内容判断（未实测上限）：给故事/内容类默认 1-3 个贴主题的词，多了像堆词。
- **落库判据看 `content_rich_span.links`**，不是数页面上的 `a` 标签：
  话题会以 `{start, length, text:"#人性#", type:2, id, id_type:8, link:"sslocal://concern?cid=…"}` 进 links，
  同时 `content` 文本里出现 `#人性#`。重载草稿后正文回显成 `#人性#` 真节点，脏碎片则回显成 `@xxx` 纯文本 —— 一眼可辨。

#### 9B.8 存草稿会被服务端静默拒绝（实测 code 1065）

```
点「存草稿」后：页面不跳转、不报错、字数与图片区照旧，但服务端没收。
抓真值要 hook 请求（XHR 通道，不是 fetch）：

window.__cap = [];
const oo = XMLHttpRequest.prototype.open, os = XMLHttpRequest.prototype.send;
XMLHttpRequest.prototype.open = function(m,u){ this.__u=u; return oo.apply(this,arguments); };
XMLHttpRequest.prototype.send = function(b){
  this.addEventListener('load', () => { if (/save_ugc_draft/.test(this.__u)) window.__cap.push({url:this.__u, body:this.responseText.slice(0,200)}); });
  return os.apply(this,arguments);
};

失败响应：{"code":1065,"gid":"","message":"保存草稿错误"}
```

- **签名相关性（本轮观察到的规律，机制未证）**：成功的两次请求 URL 带 `msToken=…&a_bogus=…`；
  之后连续 5 次全部**不带签名且一律 1065**。期间唯一变化是页面从可见变成 `document.visibilityState === 'hidden'`
  （内嵌浏览器面板被关掉，同期 `take_screenshot` / 真实 `click` 也一起报 surface 不可用）。
  → 处置顺序：先 `if (document.hidden) 请用户把内置浏览器面板打开/置于前台`，再重试存草稿；
    别在 hidden 状态下反复点，它只会静默失败，还会让你误以为已经保存。
- 存草稿后必须做 9B.5 的**重载回显核验**，`code 1065` 时重载看到的就是旧内容。



#### 9B.9 微头条踩坑清单

| 现象 | 真因 | 处理 |
|------|------|------|
| 二维码一直「已失效」，用户扫不上 | 码约 60 秒过期 | 点 `span.web-login-scan-desc__btn` 刷新；页面内 setInterval 常驻续期 |
| 页面里写 await 轮询登录，工具报 15 秒超时 | `evaluate_script` 单次上限 15s | 改装常驻 `setInterval`，主线程只做轻量轮询 |
| `wait_for(['头条'])` 秒过但其实没登录 | 登录页营销文案也含这些词 | 用 URL 判定（是否仍是 `auth/page/login`），别用正文关键词 |
| 想要「只做微头条、不生成文章」 | 该项 `disabled` 且默认勾 | 平台强制，只能告知用户，别反复点 |
| 内容/草稿列表看不到图，以为失败 | 列表行本来就不渲染图，草稿页缩略图还是 background-image | 判据只有两条：编辑页 `.img-form-wrap` 的「共 N 张」，或服务端 `get_ugc_draft` 的 `images` |
| 正文里出现「有什么新鲜事想告诉大家？」 | innerHTML 直改导致的错觉 | 用 `execCommand('insertText')`，占位符不会进正文 |
| 正文 `.ProseMirror` 里查不到 img | 微头条图片不在富文本节点，是 `.img-box-item` 的 background-image | 数 `.img-form-wrap` 的「共 N 张」，或查 `get_ugc_draft` 的 `images` |
| **图片传上了、草稿却没图** | 上传面板没点「确定」就存草稿，图片不入 form | 每张传完 → 点面板「确定」→ 见到「共 N 张」再存草稿（9B.3 第 6 步） |
| 正文尾部出现 `#骗局#@跑路@义气` 之类半截话题碎片 | 话题面板 JS 点击打到了列表容器，把推荐列表当纯文本灌进正文 | 只点叶子 `span.forum-list-item-text`；出现碎片就删掉那段重插（9B.7 第 4 步） |
| 页面有 `#话题#`，落库 links 里没有 | 直接 insertText 写的假话题 | 话题必须走「话题」面板，核验看 `content_rich_span.links` |
| 点了存草稿、什么都没报错，重载却回到旧内容 | 服务端 `save_ugc_draft` 返回 `code 1065 保存草稿错误`（页面不提示） | hook XHR 看响应码；页面 `hidden` 时请求缺 `a_bogus` 签名易触发，先让用户把内置浏览器面板打开再存（9B.8） |
| 作品声明发布前又变回没勾 | 声明不随草稿保存，重载后重置（首发同时回到默认勾选） | 存草稿只做内容校验；三个勾留到发布前那一刻复核 |
| `draft_list` 返回空数组，以为草稿没了 | 少带参数 | 必须 `type=0&...&draft_type=1`；覆盖同一条草稿时 `draft_count` 也**不会自增**，别拿它当唯一判据 |
| 存草稿后页面不跳转，以为没保存 | 存草稿本来就不跳转、无 toast | 终局判据是**重新载入这条草稿**看 `.img-box-item` 张数 + 正文字数（见 9B.5） |
| 空正文点存草稿后，旧草稿凭空消失 | 正文字数为 0 静默失败，且把单草稿槽顶空 | 图片-only 需求先落地一行最小正文（标题句即可）；一旦顶掉需重建并核验 |
| 手快点「发布」造成同篇重复 | 越界：默认终点是存草稿 | 见 9B.5；要发也由用户点，重复条目需用户确认后才删 |

---

## 完整示例

### 示例 1：开源项目介绍

```
用户：/cwork-article 写一篇文章介绍 cwork

AI：识别为"开源项目介绍"类型

AI：请提供以下信息：
    - GitHub 地址是什么？
    - 核心功能是什么？（3-5 个亮点）
    - 如何安装？（快速开始命令）
    - 有什么典型案例？
    - 系统访问地址是什么？（用于截取真实页面截图）

用户：GitHub: https://github.com/linuxhex/cwork
      核心功能：对话式需求分析、多工程并行、逻辑推演、自动衔接
      安装：node cwork.js --tool auto
      案例：我们团队用 cwork 完成了 10+ 个多服务需求
      系统地址：https://cwork.example.com（测试环境，无需登录）

AI：收到，我会先截取系统真实页面截图，再撰写文章。
    计划截取以下页面：
    1. 首页概览
    2. 需求分析页面
    3. 执行计划页面
    4. 部署结果页面
    
    确认截取这些页面？(y/n)

用户：y

AI：[用 ego-browser 打开系统，逐页截取 4 张截图]
    [截图保存到 /tmp/wechat-article-screenshots/]

AI：以下是 5 个候选标题：
    1. 【痛点 + 解决方案】还在手动协调多服务？这个工具让需求交付效率提升 3 倍
    2. 【数字 + 结果】对话式需求分析 + 自动部署，这个开源项目帮团队省了 80% 协调时间
    3. 【权威 + 背书】MIT 开源 | 支持 16 种 AI 工具的多服务开发工作流
    4. 【对比 + 悬念】用了这个工具后，我们再也不用开跨服务对齐会了
    5. 【场景 + 共鸣】每次多服务需求都提心吊胆？这个工具帮你自动化全流程
    
    请选择（1-5）：

用户：1

AI：[自动生成文章，含精美排版 CSS]
    [将 4 张真实截图嵌入文章对应位置]
    [建议封面图和结尾图]
    [直接写入公众号编辑器，上传截图]
    [保存为草稿]
```

### 示例 2：技术分享

```
用户：/cwork-article 写一篇关于微服务架构优化的技术分享

AI：识别为"技术分享"类型

AI：请提供以下信息：
    - 核心技术点是什么？
    - 解决什么问题？
    - 有什么数据支撑？
    - 涉及哪些技术栈？
    - 涉及可访问的系统吗？（如有，提供地址用于截取真实页面）

用户：核心点：服务网格 + 链路追踪
      问题：微服务调用链复杂，排查困难
      数据：排查时间从 2 小时降到 10 分钟
      技术栈：Istio、Jaeger、K8S
      系统地址：https://grafana.example.com（监控平台，需要登录）

AI：收到，监控平台需要登录，请先在浏览器登录好，登录完成后告诉我。

用户：已登录

AI：[用 ego-browser 打开 Grafana，截取以下页面：]
    1. 服务拓扑图
    2. 链路追踪详情页
    3. 性能指标看板
    
    [截图保存到 /tmp/wechat-article-screenshots/]

AI：以下是 5 个候选标题：
    1. 微服务排查从 2 小时到 10 分钟，我们做了这 3 件事
    2. 服务网格 + 链路追踪，微服务排查不再难
    3. 微服务调用链太复杂？这个方案帮你搞定
    4. 实战：如何用 Istio + Jaeger 优化微服务架构
    5. 微服务架构优化实践：排查效率提升 12 倍
    
    请选择（1-5）：

用户：5

AI：[自动生成文章，含精美排版 CSS]
    [将 3 张 Grafana 真实截图嵌入文章对应位置]
    [建议架构图和结尾图]
    [直接写入公众号编辑器，上传截图]
    [保存为草稿]
```

---

## 反模式

- **不确认发布形态就动手**：每次执行必须先问「发图文文章还是贴图」，不得默认、不得用历史形态推定
- **不识别类型就写**：必须先识别文章类型
- **不问必要信息就写**：开源项目必须有 GitHub 地址
- **不问系统地址就写**：涉及系统时必须追问系统地址
- **不生成标题就写**：必须提供 3-5 个候选标题
- **不排版就直接写**：必须按照排版规范（含 CSS 样式）
- **人格口吻挤掉排版**：加载 tech-writer/wuxia-writer 后只交 Markdown/纯散文/章回文本，无色块/卡片/分隔线/inline CSS —— 等同于「不排版就直接写」
- **用 class 代替 inline style**：公众号编辑器不吃 `.info-card` 这类 class，必须写成 `style="..."`
- **不生成封面图就写**：必须实际产出封面图片（尺寸按发布形态：图文 2560x1080 / 贴图同页面图规格），禁止只用文字描述或建议
- **两种形态封面尺寸混用**：把 2560x1080 横版封面直接塞进贴图列表（贴图首图必须与页面图同宽竖版），或反过来把竖图当图文封面（封面位按比例裁切会丢内容）
- **大字报封面让 ImageGen 直写中文**：绘图模型出中文必错字/变形；大字报只能「AI 出无文字纸底 + HTML 叠中文 + 截图出片」
- **封面渲染完不肉眼复核就上传**：必须 Read 成品 PNG 检查错字、遮挡、留白，不合格回到 HTML 改字号/版式
- **文章无配图**：每篇文章必须配图（系统截图 或 设计图），禁止纯文字无图文章
- **配图数量不足**：必须达到该文章类型的最少配图数要求
- **用占位图代替真实配图**：禁止用"[此处插入图片]"占位，必须生成真实配图
- **不上传封面图到编辑器**：封面图生成了但没有上传到编辑器的封面图位置，草稿里没有封面图，等于白做
- **不确认就写入**：必须用户确认后才写入编辑器
- **不用视觉元素**：必须使用 emoji、色块、分隔线等视觉元素（每篇至少 3 种）
- **贴图切页切在元素中间**：页面图必须按元素边界切分，切断正文、标题、卡片属于硬伤
- **贴图没有封面 / 封面没排第一张**：贴图第一张图就是封面，必须是阶段 4 生成的封面图
- **贴图不校验图片数量与顺序**：上传「成功」不等于入列，必须以列表子元素数和图片尺寸逐张核对
- **贴图复用已失效的上传 input**：组件每次上传后重建 input，复用旧节点会静默失败

---

## 完成定义

**成功完成（通用）**：
- 发布形态已与用户确认（图文文章 / 贴图）并记录在本次任务上下文
- 文章类型已识别
- 必要信息已收集（开源地址、GitHub star、系统地址等）
- 标题已生成并确认（3-5 个候选）

**成功完成（形态 = 图文文章，阶段 2~8）**：
- 封面风格已确定（概念插画 / 大字报），成品 PNG 已 Read 肉眼复核
- 封面图已生成（2560x1080；概念插画无文字，大字报中文由 HTML 叠字）
- 文中配图已生成（系统真实截图 或 设计图，数量达到该类型最少要求）
- 内容已按照模板撰写（含开头技巧、正文钩子、结尾引导）
- 排版已优化（含 CSS 样式、主题色、视觉元素）——最终正文是 **HTML + inline CSS**，每篇至少 3 种视觉元素（色块/卡片/分隔线/emoji/引用块等），不是 Markdown/纯文本
- 人格口吻与排版同时满足（口吻≠交付格式）
- 封面图已上传到公众号编辑器封面图位置
- 文中配图已嵌入文章对应位置（非占位标记）
- **底部吸粉文案已插入**（关注引导 + 福利预告 + 互动邀请 + 投稿邮箱 + 二维码 + 在看引导）
- 文章已写入公众号编辑器
- 文章已保存为草稿
- **头条发布（如用户要求）**：标题/正文已填写、封面图已上传（用户手动）、文章已发布

**成功完成（形态 = 贴图，阶段 8B）**：
- 内容已按阶段 6 产出 HTML + inline CSS（贴图同样不允许纯 Markdown）
- 封面图已按**贴图规格**重新出图（与页面图同宽、竖版、高度避开各页尺寸；`images/cover.png` 或大字报 `images/cover-poster.png`），并作为**第一张**加入贴图列表
- 换封面场景：走 8B.4b 整表清空重传（首图无就地替换），重建后张数与顺序全部复核
- 已渲染为多张页面图，按元素边界切页，未切断任何元素
- 标题 ≤ 20 字，描述 ≤ 1000 字，均已写入
- 图片已全部上传，`.image-selector__bottom-list` 张数 = 1（封面）+ 页面图张数
- 图片顺序已按源图尺寸逐张核对，首图为封面，无串页
- 已保存贴图草稿（URL 带新 `appmsgid`）
- 草稿箱「贴图」Tab 能看到该草稿卡片，标题与更新时间正确

**失败停止**：
- 未确认发布形态就动手
- 必要信息缺失（如开源项目没有 GitHub 地址）
- 封面图未生成（未调用 ImageGen 或生成失败）
- 文章无配图或配图数量不足（仅限图文文章形态）
- 用户未确认标题
- **底部吸粉文案未插入**（关注引导 + 福利预告 + 互动邀请 + 投稿邮箱 + 二维码 + 在看引导缺失；仅限图文文章形态）
- 写入编辑器失败
- **贴图缺封面或封面不在第一张**
- **贴图封面沿用图文的 2560x1080 横版**（与页面图尺寸不一致，展示被裁、大字丢边）
- **贴图图片数量与页面图不符**（上传静默失败未发现）
- **贴图顺序错乱**（尺寸核对不通过仍继续保存）
- **头条发布失败（如用户要求）**：登录失败、封面图未上传、发布按钮点击无响应

---

