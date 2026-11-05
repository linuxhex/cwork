# Trino/Paimon 兜底：ego-lite 操作统一自助查询平台

## 背景（实战踩坑）

cwork-data 的 MCP（`mcp_client.py` → query-server）**写死走 Doris 引擎**。Doris 侧 `oss_paimon` catalog 已禁用，paimon 表只能 Trino 引擎查。query-server 后端只有 7 个 tool：

- `query_doris` / `get_query_count` — Doris，查不了 paimon
- `specific_query` — 预定义模板路由（`specific_key` + `where_map`/`in_map`），**只能跑后端预先配好的 SQL 模板，不能传任意 SQL**
- `export_*` — 导出类

**结论**：遇到 paimon 表（表名含 `paimon`、`oss_paimon.*`）或必须 Trino 引擎的查询，MCP 这条路不通，走本文件的 ego-lite 页面兜底。

## 何时走兜底（判定条件，命中即走）

1. 表全路径含 `oss_paimon` / `paimon`，或表名以 `_paimon` 结尾
2. query-server 返回「请使用 Trino 引擎」/ `Unknown catalog 'oss_paimon'` / `paimon 表请使用 Trino`
3. 用户明确说「这表是 paimon / 要 Trino」或给了 `https://uqp.ykccn.net/` 页面链接
4. **用户已提示「走 ego-lite / 去 uqp 页面查」** → 直接走本兜底，禁止回 MCP 探

**命中后 MCP 全部 7 个 tool 一律禁用**（`query_doris`/`get_query_count`/`specific_query`/`export_*`）。「探 specific_query 有没有 paimon 模板」「试 get_query_count 看能不能绕」「换 tool 再试」全是换皮重试——实测必失败，浪费轮次。判定 paimon/Trino 一次即定，不翻案。

**不要**：在 Doris MCP 上反复试 `oss_paimon.*`（实测必报 Unknown catalog，浪费轮次）。

## 兜底流程（ego-lite 操作 uqp.ykccn.net）

平台地址：`https://uqp.ykccn.net/`（统一自助查询平台）。

### 硬约束（浏览器操作一律遵守 cwork-article 的浏览器 HARD GATE）

- 唯一引擎 = ego-browser；动手前先 `Skill("ego-browser")` + `ego-browser skill`
- 检测：`command -v ego-browser`（不要搜 `ego`/`ego-lite`/`~/.qoder/bin`）
- 禁止 Playwright / Puppeteer / `playwright install` / 自装 Chromium
- 所有浏览器 JS 包在 `ego-browser nodejs <<'EOF' ... EOF` 内，禁止另存独立脚本用系统 Node 跑

### 钉钉登录 SOP（uqp 平台，强制采用）

> 实战确认的登录路径，**直接采用，不重新试错**：

1. 若页面是**账号密码登录页**（有登录按钮）→ **直接点页面登录按钮**（无需填账号密码，钉钉 SSO 会跳转授权）
2. 若页面是**二维码登录页**：
   - **点击二维码本身** → 弹出钉钉头像
   - **点击头像** → 完成登录
3. 登录成功判据：URL 离开 `/login` 回到平台主页/查询页（用 `waitForUrl notContains /login` 判定，与 cwork-test 登录判据一致）
4. 登录态在 ego profile 里，同 task space 内后续导航无需重登

**禁止**：瞎填账号密码、原地反复点、把登录页当卡死处理。点登录按钮 / 点二维码→点头像是确定性路径。

### 步骤

1. **进平台 + 选 Trino 引擎**：导航到 `https://uqp.ykccn.net/`；若已登录态（未跳 /login），进查询页后**把引擎切到 Trino**（默认可能是 Doris）。若 302 到钉钉登录页，按下方「钉钉登录 SOP」自动完成登录后再切引擎。
2. **贴 SQL + 执行**：把 SQL 填进编辑器，点执行/运行。
3. **取结果**：结果区出表后，用 `page.evaluate` 把表格 DOM 转成行（`textContent` 按 `\t` 或列拆分），或直接 `page.screenshot` 存 `/tmp/uqp-result-N.png` 后 `Read` 该路径。大结果集用平台的导出/翻页。
4. **回填到阶段 3 结果输出**：把页面跑出的数按本技能阶段 3 模板整理输出（查询目标/表/结果/结论），标注「数据来源：uqp 页面 Trino 引擎（MCP 不支持）」。

### 一轮脚本模板（单 heredoc 内完成）

```js
// 在 ego-browser nodejs heredoc 内执行（非 Playwright）
const task = await taskSpace("uqp trino query");
const page = task.page("p1");
await page.goto("https://uqp.ykccn.net/", { timeout: 30000 });
await page.waitForTimeout(3000);

// 登录态检查 + 钉钉登录 SOP
if ((await page.url()).includes("/login")) {
  // 钉钉登录：先试点页面登录按钮（账号密码页）→ 或点二维码→点头像
  // 选择器按实际页面调整，先 snapshot 定位真实元素
  const snap = await page.snapshot({ scope: "full_page" });
  // 路径1：账号密码页有「登录」按钮 → 直接点
  // 路径2：二维码页 → 点二维码 → 等头像出现 → 点头像
  // 用 waitForUrl notContains /login 判登录成功
  try {
    await page.click('text=登录', { label: '钉钉登录按钮' });
  } catch (e) {
    // 二维码路径：点二维码 → 点弹出头像
    await page.click('.qrcode, [class*="qr"]', { label: '点二维码' });
    await page.waitForElement('img[class*="avatar"], [class*="avatar"]', { timeout: 8000 });
    await page.click('img[class*="avatar"], [class*="avatar"]', { label: '点头像' });
  }
  await page.waitForUrl({ notContains: "/login" }, { timeout: 15000 });
}
// 到此已登录，切引擎到 Trino
{
  const snap = await page.snapshot({ scope: "full_page" });
  // 找引擎下拉/Tab，点 Trino
  // await page.click('text=Trino');
  // 填 SQL（编辑器可能是 textarea 或 contenteditable）
  const sql = `SELECT event_date, mod_id, event_type, count(*) AS cnt
FROM oss_paimon.oss_paimon_db.dwd_omp_point_log_new_detail_distributed_paimon
WHERE event_date BETWEEN '2026-10-29' AND '2026-11-05'
  AND mod_id = 'toAcOverview'
GROUP BY event_date, mod_id, event_type
ORDER BY event_date, event_type`;
  await page.fill('textarea', sql);  // 选择器按实际改
  // 执行
  await page.click('text=运行');  // 按实际按钮文案改
  await page.waitForTimeout(4000);
  // 取结果：优先 DOM 文本，兜底截图
  const rows = await page.evaluate(() => {
    const t = document.querySelector('.result-table, table');
    if (!t) return null;
    return [...t.querySelectorAll('tr')].map(tr =>
      [...tr.querySelectorAll('td,th')].map(td => td.textContent.trim()));
  });
  if (rows) console.log(JSON.stringify(rows));
  await page.screenshot({ path: "/tmp/uqp-result-1.png" });
  await task.finish({ keep: ["p1"] });
}
```

> 选择器（`textarea`/`text=运行`/`.result-table`）是占位，首次跑先用 `snapshot` 定位真实元素再替换。**禁止**拆成多轮探索循环（cwork-article 性能硬约束：一轮 heredoc 做完切引擎/填/跑/取）。

## 已知限制

- uqp 页面选择器会变，首次用必须先 `snapshot` 探一遍再写操作
- paimon 表的 `event_date` 是分区字段，SQL **必须带 `event_date` 过滤**（与本技能分区规则一致）
- 页面跑出的数不在 MCP 链路里，无法走 `count` 分级/异步导出；大结果集用页面自带导出

## 与 MCP 路径的优先级

```
用户给的目标表
  ├─ 非 paimon / Doris 能查 → 走 mcp_client.py（首选，自带 precheck）
  └─ paimon / 必须 Trino → 走本文 ego-lite 兜底
```

MCP 能查时**不要**绕去页面操作（MCP 有 precheck、可 count 分级、可异步导出，页面操作无这些保护）。
