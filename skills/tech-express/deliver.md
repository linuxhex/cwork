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
2. `evaluate_script { function: <inject-fn.js 全文> }`，**一字不改、不拼接、不重新转义**。注入体是 `async` 箭头函数（要 `await` 等编辑器异步粘贴落地），`evaluate_script` 会等它 resolve。
3. 看返回：`{ ok, mode, usedFallback, pasteHandled, expectedH2, h2, h2Ok, before, clearedChars, clearedShell, grad, targetIndex, targetClass, chars, head, info }`。
   - `ok=true` 且 `mode="paste"` 且 `h2 === expectedH2` → 进 A5。
   - `clearedShell` 非空 → 旧正文的第一个 `section` 没清掉，注入体会直接拒绝粘贴并返回 `ok=false`（粘了也是整篇被包进旧色块）。用真实按键清空后重来，见失败手册「正文被套在旧的深色外壳里」。
   - `grad` 大于 `body.html` 里的 `linear-gradient` 数（浅色排版恒为 0）→ 同上，别保存。
   - `mode` 不是 `paste`（退回 `execCommand`/`innerHTML`）→ **改已有草稿时这种注入不会落库**（见失败手册「注入成功但保存后仍是旧正文」），先别保存。
   - `targetClass` 不含 `ProseMirror` → 打错节点了（多半是原创推荐语/摘要位），别保存。
   - `ok=false` 或 `chars` 只有几十字 → 停，按「失败手册」处理，**禁止**改成手写 HTML 再试。

> 注入体自己会先清空正文（原生 `selectAll` + `delete`，最多 3 轮），再派发一次 `paste`，然后轮询等 `h2` 收敛到 `expectedH2`（最多 15 秒）。**不要**在外面再补一次注入——重复注入是正文成倍增长的主要来源。

### A5 保存草稿

```
take_snapshot → 找「保存为草稿」的 uid → click { uid }
evaluate_script { function: "() => ({ url: location.href, cgi: (window.cgiData && (window.cgiData.appmsgid || window.cgiData.appMsgId)) || '' })" }
```

从 `url` 里正则取 `appmsgid=(\d+)`，取不到再看 `cgi`。**没拿到 appmsgid 通常是有校验弹窗拦住**（标题超长、正文被判空、敏感词）——`take_snapshot` 读提示原文并如实汇报，不要反复点保存。

### A6 服务端复验（必做，用 fetch，**不要重载编辑器**）

⚠️ 保存后**严禁**再 `navigate_page` 打开这份草稿的编辑器来复验：编辑器一加载就可能弹「检测到自动保存的版本，是否恢复」，点错一下旧版本就被并进正文，接着编辑器自动保存回写服务端，正文变成新旧两三份（20261120 实测：h2 5→10、content 32K→69K）。改在**当前页**（后台首页等任意同域页面）同源 `fetch` 编辑器 URL，只拿服务端存下来的正文，不实例化编辑器、不跑页面 JS：

```js
async (arg) => {
  const r = await fetch(arg.url, { credentials: 'include' });
  const t = await r.text();
  const key = '"content":"';
  const i = t.indexOf(key);
  if (i < 0) return { ok: false, reason: 'no content field', status: r.status };
  let j = i + key.length, esc = false;
  while (j < t.length) {
    const ch = t[j];
    if (esc) { esc = false; }
    else if (ch === '\\') { esc = true; }
    else if (ch === '"') { break; }
    j++;
  }
  const raw = t.slice(i + key.length, j);
  const dec = raw.replace(/&lt;/g, '<').replace(/&gt;/g, '>')
                 .replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, '&');
  const text = dec.replace(/<[^>]*>/g, '');
  return { ok: true, status: r.status, storedLen: raw.length,
           h2: (dec.match(/<h2/g) || []).length,
           gradient: (dec.match(/linear-gradient/g) || []).length,
           textChars: text.replace(/\s/g, '').length,
           markers: (text.match(/［插图/g) || []).length,
           pageHasTitle: arg.title ? t.indexOf(arg.title) >= 0 : true,
           headHtml: dec.slice(0, 150) };
}
```

`arg.url` = 编辑器 URL 带 `appmsgid=<id>`，`arg.title` = 本期标题。

判定：`h2` **等于** `body.html` 的 `<h2` 数（多了=旧版本被并进来，少了=没落库）、`textChars > 800`、`pageHasTitle=true`、`gradient` 等于 `body.html` 的 `linear-gradient` 数。等 6 秒问一次，**再等 12 秒复查一次**——编辑器还开着时可能又自动保存一遍，两次结果必须一致。不达标用同一 `appmsgid` 重跑，别被 `chars > 800` 骗过去（旧正文同样达标）。

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
| **注入返回正常，保存后重载仍是旧正文**（20261120 实跑踩到） | 正文区是 ProseMirror，只认自己的文档状态。`execCommand('insertHTML')` / `innerHTML` 只改了 DOM，编辑器内部 doc 没变，点保存时把**旧正文**序列化回服务端，全程无报错。识别：注入 `h2` 与复验 `h2` 不一致、复验 `chars` 等于改动前的值。处置：`build-inject.cjs` 已改为首选派发 `paste` 事件（`ClipboardEvent` + `DataTransfer.setData('text/html')`）让编辑器自己解析 HTML，返回 `mode="paste"` 才算成功；重跑注入即可，**不要新建草稿** |
| 注入打进了非正文的可编辑节点 | 页面有 3 个 `[contenteditable=true]`：标题镜像、**原创推荐语**（`js_reprint_recommend_content`，通常为空）、正文。用「最短的空节点」兜底会选中原创推荐语——内容写进去但保存时被服务端丢弃。定位规则：有占位符「从这里开始写正文」时用它；改已有草稿时占位符已消失，正文一定是**最长**的那个节点。核对返回的 `targetIndex` / `targetClass`（正文应为 `ProseMirror`） |
| **保存后正文变成新旧两三份**（20261120 实跑踩到，h2 5→10→20） | 两个成因，都要堵：① 保存后**重载编辑器复验**会弹「检测到自动保存的版本，是否恢复」，旧版本被并进来后编辑器又自动保存回写 → 复验一律走 A6 的同源 `fetch`，保存后不再打开编辑器；弹窗真出现了只点**取消/不恢复/放弃**，绝不点确定。② 公众号的 `paste` 是**异步**的（HTML 要过一遍服务端清洗），派发完立刻数 `h2` 数不到，若此时退回 `execCommand('insertHTML')`，两条路径各写一遍 → 注入体已改成 async：paste 被 `handled` 就只轮询等 `h2` 收敛（最多 15 秒），**绝不**退回改 DOM。识别：服务端 `h2` > `body.html` 的 `<h2` 数。处置：同一 `appmsgid` 重跑 |
| **正文被套在旧的深色外壳里**（整篇装进深蓝盒子、默认白字） | 清空没删干净，旧正文的第一个 `<section>`（渐变底 + `color:#fff`）留下来当外壳，粘进去的新正文整套在它里面。合成的 `execCommand('selectAll'/'delete')` 未必被 ProseMirror 采纳，且用 DOM Range 设选区它未必同步（于是 paste 变成「插入」而不是「替换」）。处置：清空只用**原生** `selectAll`+`delete`（注入体内已做，最多 3 轮），或路径 B 的**真实点击 + `Control+a` + `Delete`**；判据看 `grad`（浅色排版 `body.html` 的 `linear-gradient` 恒为 0，DOM/服务端多出就是残壳）与 `clearedShell`，清不掉就放弃保存 |
| 清空后 `chars` 恒为 20 多、`shell` 恒为空，外壳门禁形同虚设 | 按「最长 contenteditable」选节点，清空后正文比标题还短 → 选到了**标题**节点。处置：先给正文打标记（认占位符优先、排除原创推荐语框，认不到才退最长），计数一律取标记节点；路径 B 的 `MARK_BODY_JS`/`COUNT_JS` 已按此修 |
| 保存按钮点了但 URL 无 appmsgid | 有校验拦住（标题长度/正文空/敏感词），`take_snapshot` 读提示原文汇报，不盲试 |
| `upload_file` 报「元素无法直接接收文件/点击未触发文件选择」 | 该 uid 不是 file input，或未展开下拉 → 重新 `take_snapshot` 取新 uid；两次不成转手动 |
| 想传正文配图 | 走 marker-select：脚本选中 `［插图 N］` 占位文本 → 展开图片下拉 → 重新 `take_snapshot` 拿新 uid → `upload_file` → 复核 `img` 与 `markers` 计数；上传后删掉占位行 |
| 浏览器页面丢了/被关 | `list_pages` → `select_page`，或 `navigate_page` 直接重开；登录态在自带浏览器里，不用重扫 |
| 正文里 URL 被清洗成纯文本 | 正常（非白名单外链）。所以 A4 前必须确认每条来源都有 URL 明文 + 文末「来源一览」区块 |

---

## 路径 B（备用）：Playwright 脚本

自带浏览器不可用（MCP 未挂载、页面被策略拦住）时才用。行为与路径 A 等价：扫码一次 → 填标题 → **真实按键清空旧正文** → 注入 `inject.js` → 保存 → **同源 fetch 复验服务端正文**（不重载编辑器）→ 写 `draft-report.json`。

```bash
node skills/tech-express/scripts/build-inject.cjs "$CONTENT_DIR/tech-express/<YYYYMMDD>"

python skills/tech-express/scripts/wechat_draft.py \
  --dir "$CONTENT_DIR/tech-express/<YYYYMMDD>" \
  --title "科技速递 · <M月D日>" --login-wait 300
# 原地修复：--appmsgid 100000455
```

脚本自带三道硬门禁，任一不过就**不保存**（服务端正文不被改动）并以退出码 3 结束：清空后仍残留渐变外壳、注入后 DOM `h2`/`grad` 与 `body.html` 不一致、保存后 fetch 复验 `h2` 多/少或 12 秒复查发生变化。看到 `==> 失败` 就是门禁生效，按提示用**同一 `--appmsgid`** 重跑，不要新建草稿。

**路径 B 的已知坑（20261113、20261120 实跑踩到，已规约化）**：

1. **卡在 `[1/6]` 但用户已扫码**：登录循环只正则首个 tab 的 `page.url`，跳转发生在另一 tab 或旧二维码页未刷新时就一直空等。处置：结束脚本进程直接重跑一次——持久 profile（`%LOCALAPPDATA%\cwork-wechat-profile`）已存 cookie，重跑秒拿 token，**不要让用户重复扫码**。强杀 python 会连带关掉它拉起的 Chrome（先确认无 `*cwork-wechat-profile*` 残留 chrome 进程占 profile）。
2. **`appmsgid=` 打印为空但同一行 url 已带 id**：正则跑在保存后跳转完成前。处置：从日志 `save_url` 回填 `draft-report.json` 的 `appmsgid`，步骤 6 的复验本就按这个 appmsgid 做的，结果有效；**严禁当作失败重跑注入**（会新建草稿）。回填报错到 `draft-report.json` 的 `appmsgid_note` 里，不留无声修正。
3. **`--appmsgid` 原地改稿时注入「成功」但正文没换**：`[4/6]` 打印 `h2=5`、`chars` 正常，`[6/6]` 复验却是旧值（`h2=4`）。根因是 ProseMirror 内部 doc 未采纳 DOM 改动 + 目标节点选中了空的原创推荐语位，两者都会静默失败。已修：注入改走 `paste` 事件、目标节点取最长节点，复验加「注入 h2 与复验 h2 必须一致」的一致性判定（不一致直接判未达标）。处置：确认 `mode=paste`、`targetClass` 含 `ProseMirror` 后，用同一 `--appmsgid` 重跑。
4. **保存后正文变双份/三份**：见失败手册同名条目。脚本侧已做三件事——删掉重载复验改成同源 `fetch`、`dismiss()` 见到「自动保存」字样只点取消类按钮、保存后 6 秒 + 12 秒各查一次服务端并要求两次一致。
5. **粘贴异步导致两条写入路径各写一遍**：注入体已改 async，`pasteHandled=true` 就只轮询等 `h2` 收敛（最多 15 秒），绝不退回 `execCommand`。
6. **旧正文外壳残留**：`[4/6]` 注入前先用真实点击 + `Control+a` + `Delete` 清空（最多 4 轮，判据 `grad=0` 且 `chars<20`），清不干净直接退出码 3、不保存。
7. **脚本退出后不要手动打开这份草稿的编辑器又放着不管**：弹「恢复自动保存版本」必须点取消，否则旧版本被并回正文。汇报里要把这句写给用户。

脚本不代点的两样（都要在汇报里列为待手动）：封面图槽（需真实手势）、「声明原创」开关（发布口径决策，见 template.md 第五节）。

**环境自检**：
- `python -m pip show playwright` 缺失 → `python -m pip install playwright --quiet --disable-pip-version-check -i https://pypi.tuna.tsinghua.edu.cn/simple`（默认源在本机不通）。用本机 Chrome（`channel="chrome"`），无需下载内核。
- 启动即 `goto` 超时：先分**登录等待**还是**打不开**——自带浏览器/浏览器能打开 mp.weixin 就是没人扫码。
- profile 被残留实例占住：`Get-Process chrome | Where-Object {$_.MainWindowTitle -like '*公众号*'} | Stop-Process -Force`，等 2 秒重跑；同一 profile 同时只允许一个 Playwright 进程，别盲目加大超时或换方案。
