# 科技速递 · 公众号草稿交付手册

默认走**工作台自带浏览器**（browser-use MCP），不需要另起 Chrome。自带浏览器不可用或注入连续失败时才走备用脚本。

下文命令里的 `$CONTENT_DIR` = 外置内容产物根（当前 `D:/zzz/articles`），解析优先级与片段见 `cwork-common/output-dir.md`（仓库内 `skills/common/output-dir.md`）；**开工时解析一次**，产物不落在仓库 `docs/` 下、不入 git。

---

## 路径 A（默认）：browser-use MCP

用到的工具：`list_pages`、`select_page`、`navigate_page`、`take_snapshot`、`click`、`evaluate_script`、`upload_file`、`wait_for`、`take_screenshot`。
首次调用某个工具前读一次它的 JSON schema（`mcps/browser-use/tools/<tool>.json`），别凭记忆传参。

> `evaluate_script` 的 `function` 参数要的是**函数声明**（`() => {...}`），不是立即执行表达式。所以正文注入传 `inject-fn.js`，**不要**传 `inject.js`（那份是 IIFE，给 Playwright 用的）。

### A0 能力探测（先做，30 秒）

```
list_pages {}
```

- 正常返回 → 进 A1。
- 报 `tool not found`（错误码 40404 / 51404）→ 最多再试一种命名形式（`mcp__browser-use__list_pages`），**不要穷举命名变体**；若同会话另一个无关 MCP（如 genui）也报同样错，即判定为**本会话 MCP 工具未注册**（上下文压缩后续接的新会话尤其常见，系统提示里的 MCP 清单仍会显示可用，不能凭清单判定可调用）。
- 该情况下如实告知用户（自带浏览器面板本身可以是好的，但本会话调不到工具），给两个选项：用户重载窗口/新开会话让 MCP 重新注册（产物已落盘，可从阶段 5 续跑），或直接转**路径 B**。

### A1 打开后台并判登录

```
navigate_page { type: "url", url: "https://mp.weixin.qq.com/" }
evaluate_script { function: "() => ({ url: location.href, hasToken: /token=\\d+/.test(location.href) })" }
```

- 有 `token=<数字>` → 记下 token，进 A2。
- 无 token（停在扫码/登录页）→ **不轮询死等**，直接一句话交接：「自带浏览器已打开公众号后台，请扫码登录，好了回我一句」，用户确认后重跑 A1。
- 页面不在前台 → `list_pages` 看有哪些页，`select_page` 选中 mp.weixin 那页再继续。

### A2 打开图文编辑器

```
navigate_page { type: "url",
  url: "https://mp.weixin.qq.com/cgi-bin/appmsg?t=media/appmsg_edit&action=edit&type=77&lang=zh_CN&token=<token>&isNew=1" }
```

- 修复已有草稿把 `isNew=1` 换成 `appmsgid=<id>`。
- `wait_for { text: "从这里开始写正文" }` 等编辑区出现。
- `take_snapshot` → 有「我知道了 / 确定 / 知道了」弹窗就 `click` 掉，没有就跳过。**uid 每次操作后可能变，upload/click 前重新 `take_snapshot`。**

### A3 填标题

`evaluate_script` 执行下面这段（标题串必须用 `JSON.stringify` 生成后嵌入，别手写转义）：

```js
() => {
  const title = <JSON.stringify(标题)>;
  const nodes = Array.from(document.querySelectorAll('[contenteditable="true"]'));
  const node = nodes.find(n => n.innerText.indexOf('从这里开始写正文') < 0);
  if (!node) return { ok: false, reason: 'no title node' };
  node.focus();
  const sel = window.getSelection();
  const range = document.createRange();
  range.selectNodeContents(node);
  sel.removeAllRanges();
  sel.addRange(range);
  document.execCommand('insertText', false, title);
  node.dispatchEvent(new InputEvent('input', { bubbles: true }));
  return { ok: true, title: node.innerText.trim() };
}
```

标题用 `insertText` 稳定；正文才需要 base64。

### A4 注入正文

1. `Read` 出 `<目录>/inject-fn.js` **全文**（无插图占位残留、`build-inject.cjs` 自检已过）。
2. `evaluate_script { function: <inject-fn.js 全文> }`，**一字不改、不拼接、不重新转义**。
3. 看返回：`{ ok, usedFallback, h2, table, img, chars, head, info }`。
   - `ok=true` 且 `chars > 800` → 进 A5。
   - `ok=false` 或 `chars` 只有几十字 → 停，按「失败手册」处理，**禁止**改成手写 HTML 再试。

### A5 保存草稿

```
take_snapshot → 找「保存为草稿」的 uid → click { uid }
evaluate_script { function: "() => ({ url: location.href, cgi: (window.cgiData && (window.cgiData.appmsgid || window.cgiData.appMsgId)) || '' })" }
```

从 `url` 里正则取 `appmsgid=(\d+)`，取不到再看 `cgi`。**没拿到 appmsgid 通常是有校验弹窗拦住**（标题超长、正文被判空、敏感词）——`take_snapshot` 读提示原文并如实汇报，不要反复点保存。

### A6 重载复验（必做）

用 `appmsgid` 重新 `navigate_page` 打开编辑器（不是 `type: "reload"`，重开更干净），`wait_for` 正文占位符出现后执行：

```js
() => {
  const expect = <JSON.stringify(标题)>;
  const nodes = Array.from(document.querySelectorAll('[contenteditable="true"]'));
  if (!nodes.length) return { error: 'no editable' };
  const body = nodes.reduce((a, b) => a.innerText.length >= b.innerText.length ? a : b);
  const text = body.innerText;
  return {
    h2: body.querySelectorAll('h2').length,
    table: body.querySelectorAll('table').length,
    img: body.querySelectorAll('img').length,
    chars: text.length,
    markers: (text.match(/［插图/g) || []).length,
    pageHasTitle: document.body.innerText.indexOf(expect) >= 0,
    head: text.slice(0, 40)
  };
}
```

判定：`h2 ≥ 2` 且 `chars > 800` 且 `pageHasTitle=true`。计数只在正文根节点内数，否则会把编辑器 UI 的面板和工具栏表格算进来。

### A7 写回报告

`Write` 生成 `<目录>/draft-report.json`：`{ dir, title, appmsgid, inject, verify, ts }`。不达标就用**同一 appmsgid** 回 A2 修，绝不新建草稿。

### A8 封面图

编辑器封面槽位的文件选择需要真实手势。**先试一次**：`take_snapshot` 找封面上传区 uid → `upload_file { uid, filePath: <目录>/images/00-cover.jpg }` → 再 `take_snapshot` 看预览是否出现。
一次不成立刻停，转为交接：「请在封面区手动选 `images/00-cover.jpg`」。不反复重试——共享的 file input 不在真实手势下不会切到封面模式，塞进去的文件会落到正文。

---

## 失败手册

| 现象 | 判断与处置 |
|------|-----------|
| `list_pages` / `navigate_page` 报 `tool not found` | 见 A0：判定本会话 MCP 未注册，直接转路径 B，不反复试命名 |
| 路径 B 卡在 `[1/6]` 而用户已扫码 | 登录循环只读 tab0 URL → 结束进程重跑，profile cookie 复用，勿重复扫码 |
| 路径 B 日志 `appmsgid=` 为空 | 同行 url 已带 id → 从 `save_url` 回填报告，步骤 6 复验有效；**不要重跑注入** |
| `evaluate_script` 报解析/语法错 | 传错文件了：A4 必须用 `inject-fn.js`（箭头函数），`inject.js` 是 IIFE |
| 注入返回 `ok=false`，`info` 里无 placeholder 节点 | 编辑器还没渲染完 → 回 A2 重新 `wait_for` + `take_snapshot` |
| 注入后 `chars` 只有几十 | 别重复注入。先 `node build-inject.cjs <目录>` 看 class 数与 CJK 数是否异常（正文混了 Markdown/`class` 会样式尽失），重生成后再注入一次 |
| 保存按钮点了但 URL 无 appmsgid | 有校验拦住（标题长度/正文空/敏感词），`take_snapshot` 读提示原文汇报，不盲试 |
| `upload_file` 报「元素无法直接接收文件/点击未触发文件选择」 | 该 uid 不是 file input，或未展开下拉 → 重新 `take_snapshot` 取新 uid；两次不成转手动 |
| 想传正文配图 | 走 marker-select：脚本选中 `［插图 N］` 占位文本 → 展开图片下拉 → 重新 `take_snapshot` 拿新 uid → `upload_file` → 复核 `img` 与 `markers` 计数；上传后删掉占位行 |
| 浏览器页面丢了/被关 | `list_pages` → `select_page`，或 `navigate_page` 直接重开；登录态在自带浏览器里，不用重扫 |
| 正文里 URL 被清洗成纯文本 | 正常（非白名单外链）。所以 A4 前必须确认每条来源都有 URL 明文 + 文末「来源一览」区块 |

---

## 路径 B（备用）：Playwright 脚本

自带浏览器不可用（MCP 未挂载、页面被策略拦住）时才用。行为与路径 A 等价：扫码一次 → 填标题 → 注入 `inject.js` → 保存 → 重载复验 → 写 `draft-report.json`。

```bash
node skills/tech-express/scripts/build-inject.cjs "$CONTENT_DIR/tech-express/<YYYYMMDD>"

python skills/tech-express/scripts/wechat_draft.py \
  --dir "$CONTENT_DIR/tech-express/<YYYYMMDD>" \
  --title "科技速递 · <M月D日>" --login-wait 300
# 原地修复：--appmsgid 100000455
```

**路径 B 的两个已知时序坑（20261113 实跑踩到，已规约化）**：

1. **卡在 `[1/6]` 但用户已扫码**：登录循环只正则首个 tab 的 `page.url`，跳转发生在另一 tab 或旧二维码页未刷新时就一直空等。处置：结束脚本进程直接重跑一次——持久 profile（`%LOCALAPPDATA%\cwork-wechat-profile`）已存 cookie，重跑秒拿 token，**不要让用户重复扫码**。强杀 python 会连带关掉它拉起的 Chrome（先确认无 `*cwork-wechat-profile*` 残留 chrome 进程占 profile）。
2. **`appmsgid=` 打印为空但同一行 url 已带 id**：正则跑在保存后跳转完成前。处置：从日志 `save_url` 回填 `draft-report.json` 的 `appmsgid`，步骤 6 的复验本就在这个 appmsgid 的编辑器里做的，结果有效；**严禁当作失败重跑注入**（会新建草稿）。回填报错到 `draft-report.json` 的 `appmsgid_note` 里，不留无声修正。

脚本不代点的两样（都要在汇报里列为待手动）：封面图槽（需真实手势）、「声明原创」开关（发布口径决策，见 template.md 第五节）。

**环境自检**：
- `python -m pip show playwright` 缺失 → `python -m pip install playwright --quiet --disable-pip-version-check -i https://pypi.tuna.tsinghua.edu.cn/simple`（默认源在本机不通）。用本机 Chrome（`channel="chrome"`），无需下载内核。
- 启动即 `goto` 超时：先分**登录等待**还是**打不开**——自带浏览器/浏览器能打开 mp.weixin 就是没人扫码。
- profile 被残留实例占住：`Get-Process chrome | Where-Object {$_.MainWindowTitle -like '*公众号*'} | Stop-Process -Force`，等 2 秒重跑；同一 profile 同时只允许一个 Playwright 进程，别盲目加大超时或换方案。
