# -*- coding: utf-8 -*-
"""微信公众号草稿写入工具（固定浏览器配置，只扫码一次）

用法:
  python wechat_draft.py --dir a2-git-for-agents --title "标题"
  python wechat_draft.py --dir a1-skills-supply-chain --title "标题" --appmsgid 100000149

流程: 打开编辑器 -> 填标题 -> 执行 inject.js -> 保存 -> 重载复验
"""
import argparse
import json
import os
import re
import sys
import time
from pathlib import Path

from playwright.sync_api import sync_playwright

BASE = Path(__file__).resolve().parent
PROFILE = Path(os.environ.get("LOCALAPPDATA", str(BASE))) / "cwork-wechat-profile"
REPORT = BASE / "draft-report.json"
HOME = "https://mp.weixin.qq.com/"
EDIT = ("https://mp.weixin.qq.com/cgi-bin/appmsg?t=media/appmsg_edit&action=edit"
        "&type=77&lang=zh_CN&token={token}&{extra}")

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


def save_report(data):
    old = []
    if REPORT.exists():
        try:
            old = json.loads(REPORT.read_text(encoding="utf-8"))
        except Exception:
            old = []
    old = [x for x in old if x.get("dir") != data.get("dir")]
    old.append(data)
    REPORT.write_text(json.dumps(old, ensure_ascii=False, indent=2), encoding="utf-8")


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
    ap.add_argument("--dir", required=True)
    ap.add_argument("--title", required=True)
    ap.add_argument("--appmsgid", default="")
    args = ap.parse_args()

    article_dir = BASE / args.dir
    inject = (article_dir / "inject.js").read_text(encoding="utf-8")
    result = {"dir": args.dir, "title": args.title, "ok": False}

    with sync_playwright() as p:
        ctx = p.chromium.launch_persistent_context(
            user_data_dir=str(PROFILE),
            channel="chrome",
            headless=False,
            viewport={"width": 1440, "height": 900},
            args=["--disable-blink-features=AutomationControlled"],
        )
        page = ctx.pages[0] if ctx.pages else ctx.new_page()
        page.set_default_timeout(20000)

        log("[1/6] 打开公众号后台，如未登录请扫码（最多等 240 秒）...")
        page.goto(HOME, wait_until="domcontentloaded")
        token = ""
        deadline = time.time() + 240
        while time.time() < deadline:
            m = re.search(r"token=(\d+)", page.url)
            if m:
                token = m.group(1)
                break
            time.sleep(3)
        if not token:
            log("未拿到 token，登录超时")
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
            save_report(result)
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
        time.sleep(4)
        m = re.search(r"appmsgid=(\d+)", page.url)
        appmsgid = args.appmsgid or (m.group(1) if m else "")
        if not appmsgid:
            try:
                appmsgid = str(page.evaluate(
                    "() => { const c = window.cgiData || (window.wx && window.wx.cgiData) || {};"
                    " return c.appmsgid || c.appMsgId || ''; }") or "")
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
        result["ok"] = bool(verify and verify.get("h2", 0) >= 3 and verify.get("chars", 0) > 1000)
        result["token"] = token
        log(f"    {verify}")
        log(f"==> {'成功' if result['ok'] else '未达标，需人工检查'}")
        save_report(result)
        ctx.close()


if __name__ == "__main__":
    main()
