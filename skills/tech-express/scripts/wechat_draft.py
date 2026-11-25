# -*- coding: utf-8 -*-
"""微信公众号草稿写入（科技速递复用；持久化 profile，只扫码一次）

用法:
  python wechat_draft.py --dir <内容目录>/tech-express/20261111 --title "科技速递 · 11月11日" --digest "≤56字摘要"
  python wechat_draft.py --dir <内容目录>/tech-express/20261111 --title "<标题>" --digest "<首屏同一串>" --appmsgid 100000155

--dir 接受绝对路径：内容产物已外置，真值取 cwork.content.json 的 contentDir（或环境变量
CWORK_CONTENT_DIR），解析规则见 skills/common/output-dir.md；脚本本身仍在仓库内，不随产物外置。

流程: 打开后台(等扫码) -> 打开编辑器 -> 填标题 -> 填摘要(#js_description) -> 执行 inject.js -> 保存 -> fetch 服务端正文复验
复验会回读服务端 digest，为空即摘要没落库（转发卡片会抓正文开头）。

已知坑（已修）: 登录轮询扫全部标签页 + 定时重拉首页；appmsgid 保存后轮询取 URL/cgi_data。
若仍卡在 [1/6] 但已扫码：结束进程重跑即可，持久 profile 已存 cookie，不要让人重扫。
保存后**不要再重载编辑器复验**：二次加载会触发「恢复自动保存版本」合并，编辑器随后自动保存
会把新旧两份正文一起写回服务端（表现为正文重复一遍、h2 翻倍）。复验一律走同源 fetch。

依赖: python -m pip install playwright -i https://pypi.tuna.tsinghua.edu.cn/simple
      （本机已装 Chrome，用 channel="chrome"，无需下载浏览器内核）
"""
import argparse
import json
import os
import re
import sys
import time
from pathlib import Path

try:
    from playwright.sync_api import sync_playwright
except ImportError:
    print("缺少 playwright，请先执行：\n"
          "  python -m pip install playwright --quiet --disable-pip-version-check "
          "-i https://pypi.tuna.tsinghua.edu.cn/simple", flush=True)
    sys.exit(10)

HOME = "https://mp.weixin.qq.com/"
EDIT = ("https://mp.weixin.qq.com/cgi-bin/appmsg?t=media/appmsg_edit&action=edit"
        "&type=77&lang=zh_CN&token={token}&{extra}")
PROFILE = Path(os.environ.get("LOCALAPPDATA", str(Path.home()))) / "cwork-wechat-profile"

# 复验走「同源 fetch 编辑器页 + 解析服务端存下的 content」，不再重载编辑器。
# 重载会二次触发编辑器的「恢复自动保存版本」合并，随后自动保存把新旧两份正文一起写回服务端
# （20261120 实测：保存后 DOM 复验 h2=5/chars=6626 正常，48 秒后服务端 content 变成新旧双份）。
# fetch 不实例化编辑器、不跑页面 JS，既拿到服务端真值又不会二次污染。
SERVER_CHECK_JS = """async (arg) => {
  const r = await fetch(arg.url, { credentials: 'include' });
  const t = await r.text();
  const key = '"content":"';
  const i = t.indexOf(key);
  if (i < 0) return { ok: false, reason: 'no content field', status: r.status };
  let j = i + key.length, esc = false;
  while (j < t.length) {
    const ch = t[j];
    if (esc) { esc = false; }
    else if (ch === '\\\\') { esc = true; }
    else if (ch === '"') { break; }
    j++;
  }
  const raw = t.slice(i + key.length, j);
  const dec = raw.replace(/&lt;/g, '<').replace(/&gt;/g, '>')
                 .replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, '&');
  const text = dec.replace(/<[^>]*>/g, '');
  return {
    ok: true,
    status: r.status,
    storedLen: raw.length,
    h2: (dec.match(/<h2/g) || []).length,
    img: (dec.match(/<img/g) || []).length,
    gradient: (dec.match(/linear-gradient/g) || []).length,
    textChars: text.replace(/\\s/g, '').length,
    markers: (text.match(/［插图/g) || []).length,
    digest: (t.match(/"digest":"([^"]{0,200})/) || [])[1] || '',
    pageHasTitle: arg.title ? t.indexOf(arg.title) >= 0 : true,
    head: text.replace(/\\s+/g, ' ').slice(0, 40),
    headHtml: dec.slice(0, 150)
  };
}"""

DIGEST_JS = """(digest) => {
  const el = document.getElementById('js_description');
  if (!el) return {ok: false, reason: 'no digest node'};
  el.focus();
  const setter = Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, 'value').set;
  setter.call(el, digest);
  el.dispatchEvent(new Event('input', {bubbles: true}));
  el.dispatchEvent(new Event('change', {bubbles: true}));
  el.blur();
  return {ok: true, chars: el.value.replace(/\\s/g, '').length};
}"""

TITLE_JS = """(title) => {
  const nodes = Array.from(document.querySelectorAll('[contenteditable="true"]'));
  const node = nodes.find(n => n.innerText.indexOf('从这里开始写正文') < 0);
  if (!node) return {ok: false, reason: 'no title node'};
  node.focus();
  const sel = window.getSelection();
  const range = document.createRange();
  range.selectNodeContents(node);
  sel.removeAllRanges(); sel.addRange(range);
  document.execCommand('insertText', false, title);
  node.dispatchEvent(new InputEvent('input', {bubbles: true}));
  return {ok: true, title: node.innerText.trim()};
}"""


def log(msg):
    print(msg, flush=True)


def save_report(article_dir, data):
    report = article_dir / "draft-report.json"
    old = []
    if report.exists():
        try:
            old = json.loads(report.read_text(encoding="utf-8"))
        except Exception:
            old = []
    if not isinstance(old, list):
        old = [old]
    old = [x for x in old if x.get("dir") != data.get("dir")]
    old.append(data)
    report.write_text(json.dumps(old, ensure_ascii=False, indent=2), encoding="utf-8")


def dismiss(page):
    # 「检测到自动保存的版本，是否恢复」这类弹窗必须点取消：点确定会把旧版本并进当前正文，
    # 保存后正文变成新旧两三份（20261120 实测踩过）。所以先判有没有这类弹窗，有就只找取消。
    try:
        if page.locator("text=自动保存").first.is_visible(timeout=1000):
            for cancel in ("取消", "不恢复", "放弃"):
                try:
                    btn = page.locator(f"text={cancel}").first
                    if btn.is_visible(timeout=600):
                        btn.click(timeout=1200)
                        time.sleep(0.8)
                        return
                except Exception:
                    pass
    except Exception:
        pass
    for text in ("我知道了", "确定", "知道了"):
        try:
            btn = page.locator(f"text={text}").first
            if btn.is_visible(timeout=800):
                btn.click(timeout=1500)
                time.sleep(0.5)
        except Exception:
            pass


# 注入后对账用：h2 多了=编辑器把旧版本并进来了；grad>0=正文被套在旧的渐变色块外壳里
# （浅色排版下 body.html 的 linear-gradient 恒为 0，DOM 里出现渐变只可能是清空时留下的残壳）
# 正文节点优先取 MARK_BODY_JS 打的标记：清空后正文比标题还短，按「最长节点」会选到标题，
# 于是 chars 恒为标题长度、shell 恒为空，门禁形同虚设（20261120 实测踩过）。
COUNT_JS = """() => {
  let body = document.querySelector('[data-cwork-body="1"]');
  if (!body) {
    const nodes = Array.from(document.querySelectorAll('[contenteditable="true"]'));
    if (!nodes.length) return { h2: -1, chars: -1 };
    body = nodes.reduce((a, b) => a.innerText.length >= b.innerText.length ? a : b);
  }
  const fe = body.firstElementChild;
  const grad = Array.from(body.querySelectorAll('*'))
    .filter(e => /linear-gradient/i.test(e.getAttribute('style') || '')).length;
  // 清空后首个子元素是 ProseMirror 的占位层（position:absolute），不能当外壳报，
  // 判据与注入体一致：SECTION 或带渐变的才是旧正文残壳
  const st = fe ? (fe.getAttribute('style') || '') : '';
  return {
    h2: body.querySelectorAll('h2').length,
    chars: body.innerText.length,
    kids: body.children.length,
    grad: grad,
    shell: (fe && (fe.tagName === 'SECTION' || /linear-gradient/i.test(st))) ? st.slice(0, 90) : ''
  };
}"""

# 标出正文节点，供真实点击聚焦用。
# 新建草稿时正文是空的、比已填好的标题还短，按「最长」会标到标题上，随后 Ctrl+A + Delete
# 直接把标题删了；所以先认占位符，认不到才退最长，并排除原创推荐语框。
MARK_BODY_JS = """() => {
  const nodes = Array.from(document.querySelectorAll('[contenteditable="true"]'))
    .filter(n => !/original_primary_tips|js_reprint_recommend/.test(String(n.className || '')));
  if (!nodes.length) return { ok: false };
  const body = nodes.find(n => n.innerText.indexOf('从这里开始写正文') >= 0)
    || nodes.slice().sort((a, b) => b.innerText.length - a.innerText.length)[0];
  body.setAttribute('data-cwork-body', '1');
  return { ok: true, cls: String(body.className || '').slice(0, 40), len: body.innerText.length };
}"""


def clear_body(page):
    """真实按键清空正文。合成的 execCommand 未必被 ProseMirror 采纳，
    清空后会留下旧正文的第一个 section 当外壳，粘进去的新正文整套在色块里。"""
    log(f"    标记正文节点：{page.evaluate(MARK_BODY_JS)}")
    st = {}
    for rnd in range(1, 5):
        try:
            page.locator('[data-cwork-body="1"]').click(timeout=5000)
            page.keyboard.press("Control+a")
            page.keyboard.press("Delete")
            time.sleep(1.5)
        except Exception as e:
            log(f"    第 {rnd} 轮真实按键清空失败：{e}")
            return st
        st = page.evaluate(COUNT_JS)
        log(f"    第 {rnd} 轮清空后：{st}")
        if st.get("grad", 0) == 0 and st.get("chars", 0) < 20:
            break
    return st


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", required=True, help="文章目录（含 body.html 与 inject.js）")
    ap.add_argument("--title", required=True)
    ap.add_argument("--digest", default="", help="首屏摘要（≤56 字），同步填编辑器「摘要」字段；留空则转发卡片会抓正文开头")
    ap.add_argument("--appmsgid", default="", help="已有草稿 id，传入则原地修复")
    ap.add_argument("--min-h2", type=int, default=2)
    ap.add_argument("--min-chars", type=int, default=800)
    ap.add_argument("--login-wait", type=int, default=240)
    args = ap.parse_args()

    article_dir = Path(args.dir).resolve()
    inject_file = article_dir / "inject.js"
    if not inject_file.exists():
        log(f"缺少 {inject_file}，先跑 build-inject.cjs")
        sys.exit(11)
    inject = inject_file.read_text(encoding="utf-8")

    result = {"dir": str(article_dir), "title": args.title, "ok": False}
    PROFILE.mkdir(parents=True, exist_ok=True)
    log(f"profile: {PROFILE}")

    with sync_playwright() as p:
        try:
            ctx = p.chromium.launch_persistent_context(
                user_data_dir=str(PROFILE),
                channel="chrome",
                headless=False,
                viewport={"width": 1440, "height": 900},
                args=["--disable-blink-features=AutomationControlled"],
            )
        except Exception as e:
            log(f"启动失败: {e}\n"
                f"若之前有脚本残留 Chrome 实例占住 profile，"
                f"先结束带 '公众号' 标题的 chrome 进程再重跑：\n"
                f"  Get-Process chrome | Where-Object {{$_.MainWindowTitle -like '*公众号*'}} | Stop-Process -Force")
            sys.exit(12)

        page = ctx.pages[0] if ctx.pages else ctx.new_page()
        page.set_default_timeout(20000)

        log(f"[1/6] 打开公众号后台，如未登录请扫码（最多等 {args.login_wait} 秒）...")
        page.goto(HOME, wait_until="domcontentloaded")
        token = ""
        deadline = time.time() + args.login_wait
        last_reload = time.time()
        while time.time() < deadline:
            # 扫描所有标签页：扫码后跳转可能发生在另一 tab，只读 tab0 会空等到超时
            for cand in ctx.pages:
                m = re.search(r"token=(\d+)", cand.url or "")
                if m:
                    token, page = m.group(1), cand
                    break
            if token:
                break
            if time.time() - last_reload > 20:
                try:
                    page.goto(HOME, wait_until="domcontentloaded")
                except Exception:
                    pass
                last_reload = time.time()
            time.sleep(3)
        if not token:
            log("未拿到 token：登录超时（页面能打开就是没人扫码，不是网络问题）")
            ctx.close()
            sys.exit(2)
        log(f"    token={token}")

        extra = f"appmsgid={args.appmsgid}" if args.appmsgid else "isNew=1"
        log("[2/6] 打开编辑器...")
        page.goto(EDIT.format(token=token, extra=extra), wait_until="domcontentloaded")
        page.wait_for_selector('[contenteditable="true"]', timeout=40000)
        time.sleep(5)
        dismiss(page)

        log("[3/6] 填标题...")
        log(f"    {page.evaluate(TITLE_JS, args.title)}")
        if args.digest:
            dchars = len(re.sub(r"\s", "", args.digest))
            if dchars > 56:
                log(f"    摘要 {dchars} 字超 56，仍按要求填入（自行复核是否砍修饰）")
            log(f"    摘要 {page.evaluate(DIGEST_JS, args.digest)}")
        else:
            log("    未传 --digest：编辑器「摘要」字段留空，转发卡片会抓正文开头（建议填 ≤56 字摘要）")

        log("[4/6] 注入正文...")
        body_file = article_dir / "body.html"
        body_text = body_file.read_text(encoding="utf-8") if body_file.exists() else ""
        expected_h2 = len(re.findall(r"<h2", body_text, flags=re.I))
        # body.html 自己用了渐变时，grad 就不能当「残壳」判据
        expected_grad = len(re.findall(r"linear-gradient", body_text, flags=re.I))
        # 先用真实按键把旧正文彻底清空：注入体里的合成 execCommand 清不干净时会留下
        # 旧正文的第一个 section 当外壳，新正文整套被包在深色盒子里（20261120 实测踩过）
        cleared = clear_body(page)
        result["cleared_before_inject"] = cleared
        result["expected_grad"] = expected_grad
        if cleared.get("grad", 0) > expected_grad:
            result["error"] = (f"清空后仍残留渐变色块外壳 grad={cleared.get('grad')}"
                               f"（body.html 期望 {expected_grad}），继续注入会把整篇包进深色盒子；"
                               "本次已放弃保存，服务端正文未被改动")
            log(f"==> 失败：{result['error']}")
            save_report(article_dir, result)
            ctx.close()
            sys.exit(3)
        # 编辑器加载几秒后可能把旧的自动保存版本并进正文，所以注入后要等一会儿再对账，
        # h2 与 body.html 不一致就重注入（注入体会先清空正文），不达标绝不保存。
        stats, counted, attempt = None, {}, 0
        for attempt in range(1, 4):
            stats = page.evaluate(inject)
            log(f"    第 {attempt} 次注入：{stats}")
            time.sleep(6)
            counted = page.evaluate(COUNT_JS)
            log(f"    6 秒后正文 h2={counted.get('h2')} chars={counted.get('chars')}"
                f" grad={counted.get('grad')}"
                f"（body.html 期望 h2={expected_h2} grad={expected_grad}）")
            if counted.get("grad", 0) > expected_grad:
                clear_body(page)
            if (not expected_h2 or counted.get("h2") == expected_h2) \
                    and counted.get("grad", 0) <= expected_grad:
                break
        result["inject"] = stats
        result["inject_attempts"] = attempt
        result["dom_after_inject"] = counted
        result["expected_h2"] = expected_h2
        if not stats or not stats.get("ok") or (expected_h2 and counted.get("h2") != expected_h2) \
                or counted.get("grad", 0) > expected_grad:
            result["error"] = (f"注入未收敛：DOM h2={counted.get('h2')}（期望 {expected_h2}）、"
                               f"grad={counted.get('grad')}（期望 {expected_grad}）；"
                               "本次已放弃保存，服务端正文未被改动")
            log(f"==> 失败：{result['error']}")
            save_report(article_dir, result)
            ctx.close()
            sys.exit(3)

        log("[5/6] 保存草稿...")
        saved = False
        for selector in ('text=保存为草稿', 'button:has-text("保存为草稿")', 'text=保存'):
            try:
                page.locator(selector).first.click(timeout=4000)
                saved = True
                break
            except Exception:
                continue
        result["save_clicked"] = saved
        # 保存后的 URL 跳转可能晚于第一次读取：最多等 12 秒，并扫描所有标签页
        appmsgid = args.appmsgid
        if not appmsgid:
            for _ in range(12):
                time.sleep(1)
                for cand in ctx.pages:
                    m = re.search(r"appmsgid=(\d+)", cand.url or "")
                    if m:
                        appmsgid = m.group(1)
                        break
                if appmsgid:
                    break
        if not appmsgid:
            try:
                appmsgid = page.evaluate(
                    "() => { const c = window.cgiData || (window.wx && window.wx.cgiData) || {};"
                    " return c.appmsgid || c.appMsgId || ''; }") or ""
                appmsgid = str(appmsgid)
            except Exception:
                appmsgid = ""
        result["appmsgid"] = appmsgid
        log(f"    appmsgid={appmsgid} url={page.url}")

        log("[6/6] 服务端复验（fetch，不重载编辑器）...")
        time.sleep(6)
        check_url = EDIT.format(token=token, extra=f"appmsgid={appmsgid}") if appmsgid else page.url
        verify = page.evaluate(SERVER_CHECK_JS, {"url": check_url, "title": args.title})
        result["verify"] = verify
        # 期望 h2 以本地 body.html 为准：服务端多出来就是正文被重复写入（旧自动保存版本被并进来）
        duplicated = bool(expected_h2) and verify.get("h2", 0) > expected_h2
        h2_lost = bool(expected_h2) and verify.get("h2", 0) < expected_h2
        shell_left = verify.get("gradient", 0) > expected_grad
        result["ok"] = bool(verify and verify.get("ok")
                            and verify.get("h2", 0) >= args.min_h2
                            and verify.get("textChars", 0) > args.min_chars
                            and verify.get("pageHasTitle", False)
                            and not duplicated and not h2_lost and not shell_left)
        if duplicated:
            result["verify_note"] = (f"服务端 h2={verify.get('h2')} 多于 body.html 的 {expected_h2}："
                                     "正文被重复写入（编辑器把旧的自动保存版本并进来了），"
                                     "用同一 --appmsgid 重跑，勿新建草稿")
        elif h2_lost:
            result["verify_note"] = (f"服务端 h2={verify.get('h2')} 少于 body.html 的 {expected_h2}："
                                     "正文未完整落库，用同一 --appmsgid 重跑，勿新建草稿")
        elif shell_left:
            result["verify_note"] = (f"服务端正文残留 {verify.get('gradient')} 处渐变"
                                     f"（body.html 期望 {expected_grad}）：整篇被套在旧的深色外壳里，"
                                     "用同一 --appmsgid 重跑，勿新建草稿")
        result["token"] = token
        log(f"    {verify}")
        # 编辑器仍开着，几秒后可能又触发一次自动保存把旧版本并回来：等一会儿再问一次服务端
        time.sleep(12)
        recheck = page.evaluate(SERVER_CHECK_JS, {"url": check_url, "title": args.title})
        result["verify_recheck"] = recheck
        log(f"    12 秒后复查：h2={recheck.get('h2')} textChars={recheck.get('textChars')}"
            f" gradient={recheck.get('gradient')}")
        if recheck.get("h2", 0) != verify.get("h2", -1) \
                or recheck.get("gradient", -1) != verify.get("gradient", -2):
            result["ok"] = False
            result["verify_note"] = (f"保存后服务端 h2 从 {verify.get('h2')} 变成 {recheck.get('h2')}、"
                                     f"渐变从 {verify.get('gradient')} 变成 {recheck.get('gradient')}："
                                     "编辑器又自动保存了合并版本，重跑本脚本（勿新建草稿）")
        log(f"==> {'成功' if result['ok'] else '未达标，用 --appmsgid ' + (appmsgid or 'id') + ' 原地修复重跑，勿新建草稿'}")
        log("    待手动：1) 编辑器封面区选 images/00-cover.jpg（封面槽需真实手势）"
            "2) 下方「声明原创」开关本脚本不代点")
        log("    注意：脚本退出后不要再手动打开这份草稿的编辑器又放着不管——"
            "若弹出「恢复自动保存版本」，点取消，否则会把旧版本并进正文。")
        save_report(article_dir, result)
        ctx.close()


if __name__ == "__main__":
    main()
