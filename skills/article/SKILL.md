---
name: cwork-article
lazy: true
description: 微信公众号文章写作助手。自动识别文章类型，补充必要信息（开源地址/GitHub star/系统地址等），生成吸引人的标题，提供公众号安全 inline 片段集排版（只写微信能渲染的样式，禁用 flex/渐变/class），用 ImageGen 强制生成封面图，为文章生成真实配图（系统截图 或 设计图，禁止占位符）并嵌入正文，直接写入公众号编辑器。适用于：技术分享、开源项目介绍、产品推广、教程指南、行业观察、故事/小说（武侠）。内容创作按文章类型自动调用人格 skill（cwork-tech-writer 技术布道者 / cwork-wuxia-writer 金庸式武侠）。
---

# cwork-article


# 微信公众号文章写作助手

## 概述

`cwork-article` 是专门用于撰写微信公众号文章的 skill，能够自动识别文章类型，补充必要信息，生成吸引人的标题，提供公众号安全排版（inline 片段集），**为文章生成配图（系统真实截图 或 设计图）并上传嵌入正文**，并直接写入公众号编辑器。

**核心能力**：
1. **文章类型识别** — 自动识别技术分享/开源项目/产品推广/教程指南
2. **必要信息补充** — 根据文章类型自动补充缺失信息（开源地址、GitHub star、安装命令、系统地址等）
3. **标题生成** — 生成 3-5 个吸引人的标题供选择（30 字内，数字/悬念触发）
4. **精美排版** — 公众号安全排版（inline 片段集：主题色左边框、纯色卡片、引用块、对比表格、分隔线、emoji），只写微信能渲染的样式
5. **写作技巧** — 开头 3 秒抓注意力、每 300 字设钩子、结尾引导互动
6. **封面图生成（强制）** — 必须用 ImageGen 工具实际生成封面图（2560x1080），禁止只用文字建议
7. **文中配图生成（强制）** — 有可访问系统则截取真实页面截图；无系统则生成设计图，禁止纯文字无图文章
8. **直接写入编辑器** — 通过 ego-browser 直接写入公众号编辑器并保存草稿

**工作流程**：
```
阶段 0-2（串行）: 人格选择 → 类型识别 → 信息追问
阶段 3-5（并行）: 标题生成 | 封面图生成 | 文中配图生成  ← 同时执行
阶段 6-8（串行）: 内容撰写 → 配图嵌入 → 写入编辑器 → 保存草稿
```

**并行执行优化**：阶段 3（标题生成）、阶段 4（封面图生成）、阶段 5（文中配图生成）互不依赖，信息追问（阶段 2）完成后可**同时启动**，减少等待时间。

## 语言约束（强制）

- **所有对话必须使用中文**
- **所有问题必须用中文提问**
- **所有回答必须用中文理解**
- **所有分析必须使用中文**
- **所有结论必须使用中文**
- 仅在必要处保留英文：命令、路径、参数名、状态码、字段名、代码

---

## 阶段 0：人格选择（内容创作基调）

根据文章类型自动加载对应「人格 skill」，**只决定「写什么、怎么组织、什么口吻」**——**不决定最终交付格式**。最终正文必须是公众号可写的 **HTML + inline CSS**（阶段 6 排版规范），封面图/配图/写入编辑器仍由本 skill 完成。

| 文章类型 | 调用人格 skill | 人格定位 |
|----------|--------------|----------|
| 技术分享 / 开源项目 / 产品推广 / 教程指南 / 行业观察 | `cwork-tech-writer` | 资深技术布道者：痛点共情、类比具象、讲边界与 tradeoff、数据说话、绝不标题党 |
| 故事 / 小说 / 武侠 | `cwork-wuxia-writer` | 承金庸一脉武侠小说家：章回体、半文半白、侠义为核、群像立体、武学自洽 |

**加载方式**：进入内容撰写（阶段 6）前，先读取对应人格 skill 的 `SKILL.md`（路径：`.cwork/refs/cwork-tech-writer/SKILL.md` 或 `.cwork/refs/cwork-wuxia-writer/SKILL.md`），提取其「思维框架 + 语言风格 + 写作套路」，**只作为内容创作约束**。

**硬边界（防排版被人格挤掉）**：
- 人格 skill **不替代**排版：禁止只按人格写纯 Markdown / 纯文本 / 章回散文然后交付。
- 人格产出的结构（小标题、金句、章回）必须**套进**下方安全 inline 片段集，变成带 inline style 的 HTML（纯色卡片、引用块、对比表格、分隔线、主题色左边框），禁用 flex/渐变/class。
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

> **并行执行**：本阶段与阶段 4（封面图生成）、阶段 5（文中配图生成）可**同时启动**，无需等待。

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

> **并行执行**：本阶段与阶段 3（标题生成）、阶段 5（文中配图生成）可**同时启动**，无需等待。

**每篇文章必须有封面图，必须用 ImageGen 工具实际生成，禁止只用文字描述或建议。**

### 封面图规格

| 属性 | 值 |
|------|-----|
| 尺寸 | 2560x1080（21:9，最接近公众号封面 2.35:1） |
| 格式 | PNG |
| 保存路径 | /tmp/wechat-article-covers/{文章主题}-cover.png |
| 风格 | 科技感、简洁、专业，与文章主题色一致 |

### 封面图 prompt 模板（按文章类型）

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

### 封面图生成流程

```
1. 根据文章类型选择对应的 prompt 模板
2. 填入文章具体信息（项目名、技术点、产品名等）
3. 调用 ImageGen 工具生成封面图：
   - name: "{文章主题}-cover"
   - prompt: 按模板填充的完整 prompt
   - size: "2560x1080"
4. 确认生成成功，记录文件路径
5. 封面图文件路径后续写入编辑器时使用
```

### 封面图质量要求

- **无文字**：封面图不包含任何文字（标题由公众号编辑器单独设置）
- **主题明确**：一眼能看出文章主题方向
- **配色协调**：与文章主题色方案一致
- **专业感**：适合技术类公众号的审美
- **清晰度高**：2560x1080 保证在各种设备上清晰

---

## 阶段 5：文中配图生成（强制）

> **并行执行**：本阶段与阶段 3（标题生成）、阶段 4（封面图生成）可**同时启动**，无需等待。

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

### 配图生成校验点（不可跳过）

**封面图和文中配图必须真实生成，禁止用文字占位符糊弄。完成判定：**

- 封面图：必须**实际调用 ImageGen 工具**并回传文件路径（`/tmp/wechat-article-covers/{主题}-cover.png`），在阶段 8 步骤 4 真正上传到编辑器封面位置。**只写"建议生成封面图"或"封面图见 xxx.png"不算完成。**
- 文中配图：
  - 路径 A（系统截图）：必须**实际用 ego-browser 截到图**并保存到 `/tmp/wechat-article-screenshots/`，数量达到该类型最少要求。
  - 路径 B（设计图）：必须**实际生成图片文件**，不能是 `[此处插入图片]` 或 `【配图 x：xxx.png】` 这类文字。
- **正文里一律不留图片占位文字**——配图在编辑器内通过「插入图片」上传，HTML 正文只放文字 + 安全 inline 片段。

凡是配图缺失、未生成、或仅以占位文字出现 → 视为本阶段失败，不得进入阶段 6/8。

---

## 阶段 6：内容撰写与排版

**双重硬约束（缺一不可，不可二选一）**：
1. **口吻**：进入撰写前，已按「阶段 0：人格选择」加载 `cwork-tech-writer` 或 `cwork-wuxia-writer`。正文按该人格的「思维框架 + 语言风格 + 写作套路」组织——技术类布道者口吻（痛点开场、类比具象、讲边界），故事类金庸式武侠口吻（章回体、半文半白、侠义为核）。
2. **排版产出物**：最终**直接写进公众号编辑器的正文**，**必须是 HTML + inline CSS**（不是 Markdown、不是纯文本、不落地成本地 `.html` 文件）。必须套用下方「排版规范」：主题色左边框 h2、纯色信息卡片、浅黄提示框、双栏对比（table 嵌套）、分隔线、emoji 列表——每篇至少使用 3 种视觉元素。公众号编辑器**剥 class、剥 flex、剥渐变、剥伪类**，**所有样式写成 inline `style="..."`**，只写上方「安全 inline 片段集」里的属性，禁用清单里的写法一律不用。

**禁止**：按人格写完 Markdown 再「建议用户自己排版」；禁止只交章回/散文而无色块卡片；禁止用 class 名代替 inline style；禁止在正文里留 `【配图 x：xxx.png】` 这类文字占位符（配图一律在编辑器内上传）；禁止生成本地 `.html` 半成品文件。

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

### 排版规范（公众号安全 inline 片段集）

> **核心认知**：最终产物是**直接写进公众号编辑器的正文**，不落地成 html 文件（不在本地生成 `.html` 再塞进去）。微信编辑器吃 `innerHTML`、但**剥 class、剥 flex、剥渐变、剥伪类**。所以不给"CSS 模板"，只给一份**微信确实渲染的最小 inline 片段集** + 一份**禁用清单**——模型只产出微信能渲染的东西，排版不会再塌。

#### 必用：安全 inline 片段集（照抄，只改文字）

```html
<!-- 小标题：主题色左边框 -->
<h2 style="font-size:18px;font-weight:bold;color:#333;border-left:4px solid #07C160;padding-left:12px;margin:24px 0 16px;">章节标题</h2>

<!-- 正文段落 -->
<p style="line-height:1.75;color:#555;margin:12px 0;">正文内容，关键信息用 <strong>加粗</strong> 或 <strong style="color:#07C160;">主题色</strong> 强调。</p>

<!-- 引用 / 金句：灰底绿左条 -->
<div style="background:#f5f5f5;border-left:4px solid #07C160;padding:15px 20px;margin:20px 0;color:#666;">引用内容或核心观点</div>

<!-- 信息卡片：纯色背景（禁用渐变） -->
<div style="background:#07C160;color:#fff;padding:16px 20px;border-radius:8px;margin:20px 0;">卡片标题 / 关键信息</div>

<!-- 提示框：浅黄底 -->
<div style="background:#fff3cd;color:#856404;padding:15px 20px;border-radius:4px;margin:20px 0;">提示内容</div>

<!-- 分隔线 -->
<hr style="border:none;border-top:1px solid #eee;margin:30px 0;">

<!-- 表格：绿色表头，手动交替行背景（禁用 nth-child） -->
<table style="width:100%;border-collapse:collapse;margin:20px 0;">
  <tr><th style="background:#07C160;color:#fff;padding:12px;border:1px solid #ddd;">列1</th><th style="background:#07C160;color:#fff;padding:12px;border:1px solid #ddd;">列2</th></tr>
  <tr><td style="padding:12px;border:1px solid #ddd;">内容</td><td style="padding:12px;border:1px solid #ddd;">内容</td></tr>
  <tr style="background:#f9f9f9;"><td style="padding:12px;border:1px solid #ddd;">内容</td><td style="padding:12px;border:1px solid #ddd;">内容</td></tr>
</table>

<!-- 双栏对比：用 table 嵌套实现分栏（禁用 flex） -->
<table style="width:100%;border-collapse:collapse;margin:20px 0;">
  <tr>
    <td style="width:50%;padding:20px;border-radius:8px;background:#ffebee;vertical-align:top;">
      <p style="margin:0 0 8px;"><strong>😅 左侧</strong></p>
      <p style="margin:6px 0;color:#666;line-height:1.7;">要点一<br>要点二</p>
    </td>
    <td style="width:50%;padding:20px;border-radius:8px;background:#e8f5e9;vertical-align:top;">
      <p style="margin:0 0 8px;"><strong>😎 右侧</strong></p>
      <p style="margin:6px 0;color:#666;line-height:1.7;">要点一<br>要点二</p>
    </td>
  </tr>
</table>

<!-- 代码块：深色底 -->
<pre style="background:#2d2d2d;color:#f8f8f2;padding:20px;border-radius:8px;overflow-x:auto;margin:20px 0;font-size:14px;">代码内容</pre>
```

#### 主题色方案

| 主题名 | 主色 | 适用场景 |
|--------|------|----------|
| 摸鱼绿 | #07C160 | 技术分享、开源项目（默认） |
| 科技蓝 | #1890FF | 技术分享、行业观察 |
| 活力橙 | #FA8C16 | 产品推广、教程指南 |
| 优雅紫 | #722ED1 | 行业观察、深度分析 |

#### 禁用清单（写了就塌，必须规避）

| 禁用写法 | 原因 |
|----------|------|
| `display:flex` / `grid` | 公众号编辑器剥掉，分栏塌成竖排 |
| `linear-gradient(...)` | 不支持渐变背景，退化成白底 |
| `box-shadow` | 多数客户端不渲染 |
| `opacity` | 部分客户端不渲染 |
| `.class` / `<style>` 块 | 编辑器剥 class，只认 inline `style` |
| `:nth-child` / `:hover` 等伪类 | 不渲染；斑马纹用手动交替 `<tr style="background">` |
| `position` / 绝对定位 | 不支持，排版错乱 |

#### 视觉元素规范（每篇至少 3 种）

| 元素 | 写法 | 使用场景 |
|------|------|----------|
| emoji 图标 | 💬 ⚡ 🐛 📝 🚀 🤖 | 列表项、功能说明、小标题前缀 |
| 分隔线 | `<hr style="border:none;border-top:1px solid #eee;margin:30px 0;">` | 章节分隔 |
| 纯色色块 | `background:#07C160` 等纯色 + 圆角 | 重点信息、信息卡片 |
| 引用块 | 灰底绿左条 `div` | 引用、金句、关键观点 |
| 表格 | 绿色表头 + 手动交替行背景 | 功能对比、数据罗列 |
| 双栏对比 | `<table>` 嵌套分栏（非 flex） | 传统 vs 新方案 |

#### 人格内容 → 安全 inline 片段（强制）

人格决定「说什么」，安全片段决定「长什么样」。**全部 inline `style=`，无 class，不用 flex/渐变**。套用上方片段集即可，武侠章回也一样：回目进 `<h2 style="border-left:...">`，景物进灰底引用块，侠义金句进纯色卡片——**不是**纯散文。

> 注意：最终内容**直接写进公众号编辑器**，不生成本地 `.html` 文件。若需要本地预览，仅临时存一份纯片段 HTML，**绝不**在产物里留下 `【配图 x：xxx.png】` 这类文字占位符。

---

## 阶段 7：配图嵌入（强制）

**将阶段 4 的封面图和阶段 5 的文中配图，通过编辑器「插入图片」按钮从本地上传并嵌入对应位置。**

### 配图嵌入位置

```
配图一律通过编辑器「插入图片」按钮从本地上传（微信服务器生成 <img> URL），
不在正文 HTML 里写 <img src="本地路径">，更不留 【配图 x：xxx.png】 文字占位符。

| 配图 | 嵌入位置 |
|------|----------|
| 封面图（ImageGen 生成） | 编辑器封面图位置（非正文内），阶段 8 步骤 4 处理 |
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
0. 检查现有草稿（强制，先于新建）
   - 打开公众号草稿箱：
     URL: https://mp.weixin.qq.com/cgi-bin/appmsg?t=media/appmsg_list&action=list_card&token={token}
   - 搜索是否有相同主题/标题的草稿（按标题关键词搜索，如文章主题含"cwork"则搜"cwork"）
   - 如有匹配的草稿：
     a. 询问用户："发现已有草稿：[标题]，是否继续编辑？"
     b. 若用户选择继续编辑：
        - 打开该草稿：URL: https://mp.weixin.qq.com/cgi-bin/appmsg?t=media/appmsg_edit&action=edit&id={draft_id}&token={token}
        - 跳过步骤 1-6，直接进入步骤 7（保存草稿）
        - 在现有内容基础上修改，不要覆盖
     c. 若用户选择新建，走正常流程（步骤 1-8）
   - 如无匹配草稿，走正常新建流程（步骤 1-8）

1. 打开公众号编辑器（新建）
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
     c. 将阶段 4 生成的封面图文件（/tmp/wechat-article-covers/{主题}-cover.png）通过 file input 上传
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
const coverFilePath = '/tmp/wechat-article-covers/{文章主题}-cover.png';
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
        <div style="background: #07C160; color: #fff; padding: 16px 20px; border-radius: 8px; margin: 20px 0;">
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

- **不识别类型就写**：必须先识别文章类型
- **不问必要信息就写**：开源项目必须有 GitHub 地址
- **不问系统地址就写**：涉及系统时必须追问系统地址
- **不生成标题就写**：必须提供 3-5 个候选标题
- **不排版就直接写**：必须按照排版规范（安全 inline 片段集）
- **人格口吻挤掉排版**：加载 tech-writer/wuxia-writer 后只交 Markdown/纯散文/章回文本，无色块/卡片/分隔线/inline CSS —— 等同于「不排版就直接写」
- **用 class 代替 inline style**：公众号编辑器不吃 `.info-card` 这类 class，必须写成 `style="..."`
- **写微信不渲染的样式**：禁用 `flex`/`grid`、`linear-gradient`、`box-shadow`、`opacity`、`:nth-child`/`:hover` 伪类、`position` 绝对定位——这些进了编辑器就塌
- **不生成封面图就写**：必须用 ImageGen 实际生成封面图（2560x1080），禁止只用文字描述或建议
- **文章无配图**：每篇文章必须配图（系统截图 或 设计图），禁止纯文字无图文章
- **配图数量不足**：必须达到该文章类型的最少配图数要求
- **用占位图代替真实配图**：禁止用"[此处插入图片]"、`【配图 x：xxx.png】` 占位，必须生成真实配图并在编辑器内上传
- **生成本地 html 半成品**：最终内容直接写进公众号编辑器，不生成本地 `.html` 文件（本地预览仅临时、不入库）
- **不上传封面图到编辑器**：封面图生成了但没有上传到编辑器的封面图位置，草稿里没有封面图，等于白做
- **不确认就写入**：必须用户确认后才写入编辑器
- **不用视觉元素**：必须使用 emoji、色块、分隔线等视觉元素（每篇至少 3 种）

---

## 完成定义

**成功完成**：
- 文章类型已识别
- 必要信息已收集（开源地址、GitHub star、系统地址等）
- 标题已生成并确认（3-5 个候选）
- 封面图已用 ImageGen 实际生成（2560x1080，无文字，主题明确）
- 文中配图已生成（系统真实截图 或 设计图，数量达到该类型最少要求）
- 内容已按照模板撰写（含开头技巧、正文钩子、结尾引导）
- 排版已优化（安全 inline 片段集、主题色、视觉元素）——最终正文是 **HTML + inline CSS**，每篇至少 3 种视觉元素（色块/卡片/分隔线/emoji/引用块等），不是 Markdown/纯文本，且只用微信可渲染的样式（无 flex/渐变/class/伪类）
- 人格口吻与排版同时满足（口吻≠交付格式）
- 正文**直接写进公众号编辑器**，无本地 `.html` 半成品文件
- 封面图已上传到公众号编辑器封面图位置
- 文中配图已在编辑器内上传并嵌入对应位置（非占位标记、非本地路径）
- 文章已写入公众号编辑器
- 文章已保存为草稿

**失败停止**：
- 必要信息缺失（如开源项目没有 GitHub 地址）
- 封面图未生成（未调用 ImageGen 或生成失败）
- 文章无配图或配图数量不足，或配图仅以占位文字出现
- 正文使用了微信不渲染的样式（flex/渐变/class/伪类）
- 生成本地 `.html` 半成品文件而非直接写编辑器
- 用户未确认标题
- 写入编辑器失败

---


