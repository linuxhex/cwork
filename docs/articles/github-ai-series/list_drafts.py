# -*- coding: utf-8 -*-
"""读取公众号草稿列表，用于核对标题与 appmsgid"""
import json
import os
import re
import sys
import time
from pathlib import Path
from playwright.sync_api import sync_playwright

BASE = Path(__file__).resolve().parent
PROFILE = Path(os.environ.get("LOCALAPPDATA", str(BASE))) / "cwork-wechat-profile"

with sync_playwright() as p:
    ctx = p.chromium.launch_persistent_context(
        user_data_dir=str(PROFILE), channel="chrome", headless=False,
        viewport={"width": 1440, "height": 900},
        args=["--disable-blink-features=AutomationControlled"],
    )
    page = ctx.pages[0] if ctx.pages else ctx.new_page()
    page.goto("https://mp.weixin.qq.com/", wait_until="domcontentloaded", timeout=90000)
    token = ""
    for _ in range(40):
        m = re.search(r"token=(\d+)", page.url)
        if m:
            token = m.group(1)
            break
        time.sleep(3)
    if not token:
        print("未登录")
        ctx.close()
        sys.exit(2)
    page.goto(f"https://mp.weixin.qq.com/cgi-bin/draftbox?lang=zh_CN&token={token}",
              wait_until="domcontentloaded", timeout=90000)
    time.sleep(8)
    scraped = page.evaluate("""() => Array.from(document.querySelectorAll('a[href*="appmsgid="]'))
        .map(a => ({href: a.href, text: (a.innerText || '').trim().slice(0, 60)}))
        .filter(x => x.text)""")
    print("LINKS:", json.dumps(scraped, ensure_ascii=False).encode("gbk", "replace").decode("gbk"))
    (BASE / "draft-links.json").write_text(json.dumps(scraped, ensure_ascii=False, indent=2), encoding="utf-8")
    ctx.close()
    sys.exit(0)
    try:
        nick = page.evaluate("() => { const n = document.querySelector('.weui-desktop-account__nickname, .account_nickname, .weui-desktop-account__info'); return n ? n.innerText : document.body.innerText.slice(0,120); }")
        print("ACCOUNT:", str(nick).encode("gbk", "replace").decode("gbk"))
    except Exception as e:
        print("ACCOUNT 读取失败", str(e)[:120])
    resp = ctx.request.get(url)
    raw = resp.text()
    (BASE / "draft-raw.json").write_text(raw, encoding="utf-8")
    data = resp.json()
    print("KEYS:", list(data.keys()), "len:", len(raw))
    for key, val in data.items():
        if isinstance(val, dict):
            print(" ", key, "->", list(val.keys()))
    out = []
    items = data.get("app_msg_list") or data.get("draft_list") or []
    if not items and isinstance(data.get("draft_info"), dict):
        items = data["draft_info"].get("item", [])
    for item in items:
        out.append({
            "appmsgid": item.get("appmsgid"),
            "title": item.get("title"),
            "update_time": time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(item.get("update_time", 0))),
            "digest": (item.get("digest") or "")[:30],
        })
    (BASE / "draft-list.json").write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(out, ensure_ascii=False, indent=1).encode("gbk", "replace").decode("gbk"))
    ctx.close()
