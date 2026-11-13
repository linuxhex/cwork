# -*- coding: utf-8 -*-
"""微信公众号草稿写入（科技速递复用；持久化 profile，只扫码一次）

用法:
  python wechat_draft.py --dir <内容目录>/tech-express/20261111 --title "科技速递 · 11月11日"
  python wechat_draft.py --dir <内容目录>/tech-express/20261111 --title "<标题>" --appmsgid 100000155

--dir 接受绝对路径：内容产物已外置，真值取 cwork.content.json 的 contentDir（或环境变量
CWORK_CONTENT_DIR），解析规则见 skills/common/output-dir.md；脚本本身仍在仓库内，不随产物外置。

流程: 打开后台(等扫码) -> 打开编辑器 -> 填标题 -> 执行 inject.js -> 保存 -> 重载复验

已知坑（已修）: 登录轮询扫全部标签页 + 定时重拉首页；appmsgid 保存后轮询取 URL/cgi_data。
若仍卡在 [1/6] 但已扫码：结束进程重跑即可，持久 profile 已存 cookie，不要让人重扫。

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

# 复验只数正文编辑区根节点内的元素，避免把编辑器 UI 的表格/历史面板算进来
VERIFY_JS = """() => {
  const nodes = Array.from(document.querySelectorAll('[contenteditable="true"]'));
  if (!nodes.length) return {error: 'no editable'};
  const body = nodes.reduce((a, b) => a.innerText.length >= b.innerText.length ? a : b);
  const titleNode = nodes.reduce((a, b) => a.innerText.length <= b.innerText.length ? a : b);
  const text = body.innerText;
  return {
    h2: body.querySelectorAll('h2').length,
    table: body.querySelectorAll('table').length,
    img: body.querySelectorAll('img').length,
    chars: text.length,
    markers: (text.match(/［插图/g) || []).length,
    pageHasTitle: document.body.innerText.indexOf(window.__expectTitle || '') >= 0,
    title: titleNode.innerText.trim().slice(0, 80),
    head: text.slice(0, 40)
  };
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
    for text in ("我知道了", "确定", "知道了"):
        try:
            btn = page.locator(f"text={text}").first
            if btn.is_visible(timeout=800):
                btn.click(timeout=1500)
                time.sleep(0.5)
        except Exception:
            pass


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", required=True, help="文章目录（含 body.html 与 inject.js）")
    ap.add_argument("--title", required=True)
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

        log("[4/6] 注入正文...")
        stats = page.evaluate(inject)
        log(f"    {stats}")
        result["inject"] = stats
        if not stats or not stats.get("ok"):
            result["error"] = "inject failed"
            save_report(article_dir, result)
            ctx.close()
            sys.exit(3)
        time.sleep(2)

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

        log("[6/6] 重载复验...")
        if appmsgid:
            page.goto(EDIT.format(token=token, extra=f"appmsgid={appmsgid}"),
                      wait_until="domcontentloaded")
        else:
            page.reload(wait_until="domcontentloaded")
        page.wait_for_selector('[contenteditable="true"]', timeout=40000)
        time.sleep(5)
        page.evaluate(f"() => {{ window.__expectTitle = {json.dumps(args.title, ensure_ascii=False)}; }}")
        verify = page.evaluate(VERIFY_JS)
        result["verify"] = verify
        result["ok"] = bool(verify and verify.get("h2", 0) >= args.min_h2
                            and verify.get("chars", 0) > args.min_chars
                            and verify.get("pageHasTitle", False))
        result["token"] = token
        log(f"    {verify}")
        log(f"==> {'成功' if result['ok'] else '未达标，用 --appmsgid ' + (appmsgid or 'id') + ' 原地修复重跑，勿新建草稿'}")
        log("    待手动：1) 编辑器封面区选 images/00-cover.jpg（封面槽需真实手势）"
            "2) 下方「声明原创」开关本脚本不代点")
        save_report(article_dir, result)
        ctx.close()


if __name__ == "__main__":
    main()
