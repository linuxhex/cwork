# 小红书主题库（theme-xhs）

> 小红书图文笔记专用。**正文不支持任何 HTML/CSS**——排版=纯文本 + emoji + 空行 + 符号小标题。读入本库后，阶段 6 的 HTML 组件库路线整体停用，改走本库。**公众号路线不受本库影响。**

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

### 正文结构（600-1000 字，禁止过短）
```
[钩子首句：一句话说清这篇解决什么问题，配 1 个 emoji]

[2-4 行痛点场景，口语化、第一人称]

【小标题一】或 1️⃣
[要点 + 具体做法 + 数据/例子，每条 3-5 行]

【小标题二】或 2️⃣
[要点 + 具体做法 + 数据/例子，每条 3-5 行]
...

【避坑提醒】⚠️
[1-2 条边界/坑，带具体场景]

[互动引导一句：你遇到过 xx 吗？评论区聊聊]

#标签1 #标签2 #标签3
```

**正文深度硬要求（治「写太简单」）**：
- **字数下限 600 字**（含 emoji 和标签）——小红书清单体 ≠ 三言两语，要点要展开到「具体怎么做 + 为什么 + 数据/例子」三层，不是只列结论
- **每个要点必须带「具体做法」**：不能只写「注意性能」要写「用 index 列查别用 code 列查，实测快 20 倍」
- **至少 1 处带数据/实测对比**：「从 2h → 10min」「快 20 倍」「踩了 3 次坑」——空泛总结不算
- **小标题 3-5 个**：太少=单薄，太多=碎片。每个小标题下展开 3-5 行实质内容
- 短句多分段依然成立，但「短」指句式不指内容深度——一段 3 行也要说清一个完整要点

### 语言风格
- **口语化、第一人称**：「我实测」「亲测有效」——不是公众号的布道者口吻
- 短句、多分段：每段 ≤3 行，段间空一行
- emoji 当视觉层级用：小节标题、要点前缀、避坑警告（⚠️💡✅❌🔥）
- 数据仍要具体：「排查从 2h → 10min」比「效率大幅提升」强
- 禁：长句套长句、黑话不解释、通篇 emoji 刷屏（每屏 ≤3 个）
- **禁内容空洞**：只列结论不展开做法、只说「很重要」不给数据、要点只写一句话就算——这些是「写太简单」的典型，必须展开

### 封面套路
- 3:4 竖版，大字标题直接印在封面上（与公众号「封面无字」相反）
- 命令：`python3 skills/article/scripts/gen_illustration.py cover "主题" --style block --subtitle "副标题" --width 1242 --height 1660 -o /tmp/xhs-covers/cover.png`
- style 建议：`block`（底部色块大字）> `bar` > `grid`

## 配图
- 与公众号同源：gen_illustration.py 五命令 / ego-browser 真实截图
- 数量：3-6 张，首图=封面，后续按「步骤图 → 数据图 → 对比图」排
- 数据图/对比图宽高比建议 4:3 或 1:1

## 发布红线（硬约束）

### ⚠️ Web 草稿 ≠ App 草稿（必须告知用户）

| 动作 | 存哪里 | 手机 App 能看到？ | 账号公域可见？ |
|------|--------|------------------|---------------|
| 「暂存离开」 | **当前浏览器本地** | ❌ 看不到 | ❌ |
| 「发布」 | 小红书账号云端 | ✅ 同步到 App | ✅ |

**硬规则（默认直接发布）**：
1. **默认走「发布」**：内容写完 → 右侧笔记预览自检一遍（标题/正文/图/标签）→ 无误后点「发布」，同步到账号/App/公域。
2. **仅当用户明确说「先存草稿 / 别发 / 暂存」时**才点「暂存离开」，并口头告知「App 看不到，只在电脑浏览器草稿箱」。
3. 禁止默认暂存再声称完成；禁止跳过自检直接发。
4. **发布成功判定**：URL 含 `publish/success`，或页面出现「发布成功」——二者之一即可结案；不要只看按钮有没有点到。
5. 草稿箱提示文案实测为：「草稿存储于当前使用的浏览器本地，在清除浏览器数据时会被删除」。

### 发布入口
`https://creator.xiaohongshu.com/publish/publish?source=official`
- 页面**默认停在「上传视频」tab**，必须切到「上传图文」
- 登录态：若 302 到 `/login`，停下让用户扫码，登录态在浏览器 profile 里

### ego-browser 一轮脚本模板（禁止拆成多轮探索）

> **性能硬约束**：切 tab / 上传 / 填标题 / 填正文 / 点按钮 **必须在同一个 `ego-browser nodejs` 脚本内完成**。禁止「拍快照→finish→下一轮再操作」的探索循环（实测浪费 15+ 轮）。每轮脚本开头先 `snapshot` 取本轮 ref，末尾再 `finish`。
>
> **启动方式（强制）**：下面是 heredoc 正文，必须这样跑——`ego-browser nodejs <<'EOF' ... EOF`。禁止 Playwright / `python3 -m playwright install` / 另存独立脚本用系统 Node 跑。动手前 `Skill("ego-browser")`。检测：`command -v ego-browser`（不要搜 `ego`/`ego-lite`/`~/.qoder/bin`）。

```js
// 在 ego-browser nodejs heredoc 内执行（非 Playwright）
const task = await taskSpace("小红书写入");
const page = await task.newPage();
await page.goto("https://creator.xiaohongshu.com/publish/publish?source=official", { timeout: 30000 });
await page.waitForTimeout(6000);

// 若跳到 /login —— 停下让用户扫码，不要继续
if ((await page.url()).includes("/login")) {
  console.log("需要登录，请用户扫码");
  await task.finish({ keep: ["p1"] });
} else {
  // 1) 切「上传图文」（JS click，绕过 span 拦截）
  await page.evaluate(() => {
    const s = [...document.querySelectorAll("span")].find(
      (e) => e.textContent.trim() === "上传图文" && e.getBoundingClientRect().width > 0
    );
    if (s) (s.closest('[role="tab"]') || s).click();
  });
  await page.waitForTimeout(4000);

  // 2) 上传图（上传后底部才出现「暂存离开/发布」）
  await page.setInputFiles('input[type="file"]', [
    "/tmp/xhs-article/cover.png",
    "/tmp/xhs-article/compare.png",
    "/tmp/xhs-article/data.png",
  ]);
  await page.waitForTimeout(5000);

  // 3) 本轮快照取 ref
  const snap = await page.snapshot({ scope: "full_page" });
  const lines = snap.split("\n");
  const titleRef = lines.find((l) => /填写标题/.test(l) && /ref=/.test(l))?.match(/ref=(\d+)/)?.[1];
  const bodyRef = lines.find((l) => /输入正文|textfield/.test(l) && /ref=/.test(l))?.match(/ref=(\d+)/)?.[1];

  // 4) 填标题（普通 input）
  if (titleRef) await page.fill("@" + titleRef, "标题文字≤20字");

  // 5) 填正文（tiptap：click 聚焦 + insertText；# 标签放最后，输完 Escape）
  if (bodyRef) {
    await page.click("@" + bodyRef, { label: "点击正文" });
    await page.waitForTimeout(500);
    await page.keyboard.insertText("正文内容...");
    await page.keyboard.press("Escape"); // 关话题下拉
    await page.keyboard.insertText("\n#标签1 #标签2 #标签3");
    await page.keyboard.press("Escape");
  }

  // 6) 自检右侧预览后发布（默认）
  //    发布按钮宿主 <xhs-publish-btn> 是 Vue 自定义组件，标准 DOM click() 可能无效
  //    通道优先级：@ref 点 > btn._onPublish() 内部方法直调 > 坐标兜底（约 793,706）
  const snap2 = await page.snapshot({ scope: "full_page" });
  const ls = snap2.split("\n");
  let publishRef = null, draftRef = null;
  for (let i = 0; i < ls.length - 1; i++) {
    const m = ls[i].match(/button \[ref=(\d+)/);
    if (!m) continue;
    if (/text "发布"/.test(ls[i + 1])) publishRef = m[1];
    if (/text "暂存离开"/.test(ls[i + 1])) draftRef = m[1];
  }
  if (publishRef) {
    await page.click("@" + publishRef, { label: "发布@ref" });
  } else {
    // 兜底1：直调内部方法（标准 DOM click 对该组件无效时的关键突破）
    const ok = await page.evaluate(() => {
      const btn = document.querySelector('xhs-publish-btn');
      if (btn && typeof btn._onPublish === 'function') { btn._onPublish(); return true; }
      return false;
    });
    if (!ok) {
      // 兜底2：坐标点击
      await page.mouse.click(793, 706, { label: "发布兜底坐标" });
    }
  }
  await page.waitForTimeout(4000);
  // 7) 成功判定
  const ok = (await page.url()).includes("publish/success")
    || /发布成功/.test(await page.evaluate(() => document.body.innerText));
  console.log("发布结果:", ok);
  await page.screenshot({ path: "/tmp/xhs-article/result.png" });
  await task.finish({ keep: ["p1"] });
}
```

### 关键选择器速查

| 元素 | 真实形态 | 怎么操作 |
|------|---------|---------|
| 上传图文 tab | 多个重复 span | JS `evaluate` 找可见 span 再 `.click()` |
| 图片上传 | `input[type=file][accept*=jpg][multiple]` | `setInputFiles`（一次多张） |
| 标题 | `input[placeholder="填写标题会有更多赞哦"]` | `page.fill` |
| 正文 | tiptap `contenteditable` / snapshot `textfield` | click 聚焦 + `keyboard.insertText` |
| 暂存离开 / 发布 | snapshot 里 `button [ref=N]` + 下一行 `text "发布"`/`"暂存离开"`；宿主是 `<xhs-publish-btn>`（Vue 自定义组件，标准 DOM click 无效） | **优先 `@ref` 点击**；ref 拿不到 → 直调 `btn._onPublish()` 内部方法 → 坐标兜底（发布约 793,706 / 暂存约 566,706） |
| 草稿箱入口 | 顶部「草稿箱(N)」 | 暂存后会自动弹出；也可从此入口回看 |

### 关键坑（三轮实测）
- **默认视频 tab**：不切换永远只有视频上传
- **切 tab**：`page.click('@N')` 被 span 拦截；`text="上传图文"` 匹配 3 个元素——只能 JS `.click()`
- **标题是普通 input**：`page.fill` 可用；旧文档误写 contenteditable
- **正文是 tiptap**：click + `insertText`，无需 dispatch input
- **# 触发话题下拉**：输完按 Escape，否则遮住底部按钮
- **发布按钮**：宿主 `<xhs-publish-btn>` 是 **Vue 自定义组件**，标准 DOM `click()` 可能无效。三层通道：`@ref` 点 > **直调 `btn._onPublish()` 内部方法**（`document.querySelector('xhs-publish-btn')._onPublish()`）> 坐标兜底。成功看 URL `publish/success` 或文案「发布成功」
- **标题超 20 字静默阻止发布**：标题 >20 字时前端校验**静默阻止**（不报错、按钮点了没反应）。发布前必须确认标题 ≤20 字（含 emoji），否则发布按钮点不动且无提示，会被误判为按钮失效
- **上传后按钮才出现**：没上传图时底部没有「暂存离开/发布」
- **ref 跨脚本过期**：每轮脚本内先 snapshot 取新 ref
- **ego 会话**：同一写入动作一个脚本做完；跨进程用 `claimTaskSpace` + `tabs()`，managed 用 `task.page(label)`，untracked 才 `adopt`
- **Web 草稿不同步 App**：见上方硬规则表——这是产品机制，不是 bug

### 发布前自检
- 标题 ≤20 字（含 emoji），必带 1-2 emoji——**超 20 字会静默阻止发布**（按钮点不动无提示），发布前必须确认字数
- 正文 **600-1000 字**（含 emoji 和标签）——过短（<600）说明要点没展开，回去补「具体做法 + 数据/例子」
- 图片已上传（首图=封面），3-18 张
- #话题 3-8 个
- 已按用户选择点「发布」或「暂存离开」，且已向用户说明 App 可见性
- 右侧「笔记预览」截图确认内容完整
