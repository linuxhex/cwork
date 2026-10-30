# 小红书主题库（theme-xhs）

> 小红书图文笔记专用。**正文不支持任何 HTML/CSS**——排版=纯文本 + emoji + 空行 + 符号小标题。读入本库后，阶段 6 的 HTML 组件库路线整体停用，改走本库。

## 硬限制（超了发不出去）

| 项 | 限制 |
|----|------|
| 标题 | **≤20 字**（含 emoji），必带 1-2 个 emoji |
| 正文 | **≤1000 字**（含 emoji 和标签） |
| 图片 | 首图即封面，最多 18 张 |
| 标签 | #话题 3-8 个，放正文末尾 |
| 封面比例 | **3:4 竖版 1242x1660** 优先（信息流展示最大） |

## 写作套路（小红书体）

### 标题公式（≤20 字）
- 数字清单：「3 个技巧」「5 分钟搞定」「7 天见效」
- 悬念/反差：「我删掉了 xx，效率翻倍」「别再 xx 了」
- 身份代入：「程序员必备」「打工人自救指南」
- emoji 点睛：标题开头或关键位置 1-2 个（💡🔥✅），不堆砌

### 正文结构（1000 字内）
```
[钩子首句：一句话说清这篇解决什么问题，配 1 个 emoji]

[2-4 行痛点场景，口语化、第一人称]

【小标题一】或 1️⃣
[要点 + 具体做法，每条 ≤2 行]

【小标题二】或 2️⃣
...

【避坑提醒】⚠️
[1-2 条边界/坑]

[互动引导一句：你遇到过 xx 吗？评论区聊聊]

#标签 1 #标签 2 #标签 3
```

### 语言风格
- **口语化、第一人称**：「我实测」「亲测有效」——不是公众号的布道者口吻
- 短句、多分段：每段 ≤3 行，段间空一行
- emoji 当视觉层级用：小节标题、要点前缀、避坑警告（⚠️💡✅❌🔥）
- 数据仍要具体：「排查从 2h → 10min」比「效率大幅提升」强——实战风不变，只是换壳
- 禁：长句套长句、黑话不解释、通篇 emoji 刷屏（每屏 ≤3 个）

### 封面套路
- 3:4 竖版，大字标题直接印在封面上（小红书封面字=点击率核心，与公众号「封面无字」相反）
- 生成命令：
  `python3 skills/article/scripts/gen_illustration.py cover "主题" --style block --subtitle "副标题" --width 1242 --height 1660 -o /tmp/xhs-covers/cover.png`
- style 建议：`block`（底部色块大字）> `bar` > `grid`

## 配图
- 与公众号同源：gen_illustration.py 五命令 / ego-browser 真实截图，套路不变
- 数量：3-6 张，首图=封面，后续按「步骤图 → 数据图 → 对比图」排
- 数据图/对比图宽高比建议 4:3 或 1:1（竖版信息流更协调）

## 发布红线

> 以下流程基于 ego-browser 实测（2026-10-30），操作前先确认浏览器已登录小红书（发布页若 302 到 `/login` 需先扫码登录，登录态存在浏览器 profile 不随会话丢失）。

### 发布入口
`https://creator.xiaohongshu.com/publish/publish?source=official`
- 页面**默认停在「上传视频」tab**，必须切到「上传图文」才能发图文笔记

### ego-browser 实操步骤（三轮实测校准，2026-10-30）
```
1. 导航：page.goto(发布页 URL, {timeout:30000})，waitForTimeout 6000 等登录态生效
2. 切图文：默认是视频 tab。JS 直接点击绕过 span 拦截：
     page.evaluate(() => {
       const s = [...document.querySelectorAll('span')].find(e => e.textContent.trim()==='上传图文'
                 && e.getBoundingClientRect().width>0);
       (s.closest('[role="tab"]') || s).click();
     });
   ⚠️ 不要用 page.click('@N')(被 span 拦截 pointer events)、不要 text="上传图文"(匹配 3 个重复元素)
3. 上传图：图文模式下 input[type=file][accept=".jpg,.jpeg,.png,.webp"][multiple=true]
     page.setInputFiles('input[type="file"]', [封面，对比图，数据图...])  // 一次传多张
   ⚠️ 页面有 3 个 file input（图片 multiple/图片单选/文档），setInputFiles 自动选第一个匹配；
      如传错，用 accept 含.jpg 且 multiple=true 的那个
   ⚠️ 上传后底部才会出现「暂存离开」和「发布」按钮
4. 填标题：⚠️ 普通 <input>，不是 contenteditable！
     selector: input[placeholder="填写标题会有更多赞哦"]
     page.fill('@ref', '标题文字')   // 拍快照取 ref，或 CSS 直选
5. 填正文：tiptap/ProseMirror 富文本（[contenteditable="true"].tiptap.ProseMirror）
     - 先 page.click('@正文 ref') 聚焦
     - 再 page.keyboard.insertText(正文)  ← 实测可用，不需要 dispatchEvent
     - placeholder 文案："输入正文描述，真诚有价值的分享予人温暖"
   ⚠️ 正文含#开头文字会触发话题下拉框（实测弹出话题选择列表）——
      输入后按 Escape 关闭，或标签放正文最后输入完再 Escape
6. 存草稿：⚠️ 按钮在自定义元素<xhs-publish-btn>里（shadow DOM closed，无法直接访问）
     - 按钮区域坐标：x≈339~1019, y≈661~751（宽 680，高 90）
     - 「暂存离开」在左 1/3：page.mouse.click(566, 706)
     - 「发布」在右 1/3：page.mouse.click(793, 706)
   ⚠️ 点击后弹出草稿箱确认「保存成功」，草稿存储于浏览器本地
7. 验证：发布页右侧有「笔记预览」实时预览（封面 + 标题 + 正文），
   截图对比确认内容完整后再交给用户
```

### 关键坑（三轮实测踩过）
- **默认视频 tab**：不切换永远只有视频上传，没有图片入口
- **切 tab 点击失败**：原生 click 被覆盖 span 拦截、`text=` 多元素歧义——只能用 JS `.click()`
- **标题是普通 input 不是 contenteditable**：`page.fill` 直接可用；旧文档误写为 contenteditable
- **正文是 tiptap 编辑器**：click 聚焦后 `keyboard.insertText` 即可，无需手动 dispatch input 事件
- **# 触发话题下拉**：正文里 # 开头文字会弹出话题选择框，遮住后续操作——输完后按 Escape
- **存草稿按钮在 shadow DOM 里**：`<xhs-publish-btn>` 是自定义元素，shadow DOM closed，无法用 ref/CSS 选择器访问——只能用坐标点击（左 1/3 暂存离开，右 1/3 发布）
- **ref 跨脚本过期**：快照 ref 只在本轮有效——**每轮脚本内先拍快照取新 ref 再操作**，不要复用上一轮的 ref（实测报 Unknown ref）
- **ego 会话生命周期**：`finish({keep:"all"})` 后用户标签可能脱管，下轮 `task.page()` 报 not found——用 `claimTaskSpace(id)` 后先 `task.tabs()` 看状态，managed 用 `task.page(label)`，untracked 才 `task.adopt()`；同一完整操作尽量一个脚本内完成

### 发布前自检
- 标题字数 ≤20（含 emoji），标题必带 1-2 emoji
- 正文字数 ≤1000（含 emoji 和标签）
- 图片已全部上传（首图=封面），数量 3-18 张
- #话题标签 3-8 个，放正文末尾
- 无敏感词自检能力——政治/医疗/金融诱导类措辞主动规避
