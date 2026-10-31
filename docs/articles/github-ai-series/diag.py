# -*- coding: utf-8 -*-
"""诊断：本机 Chrome 能否打开公众号后台，卡在哪一步"""
import os
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
    try:
        page.goto("https://mp.weixin.qq.com/", wait_until="domcontentloaded", timeout=45000)
    except Exception as e:
        print("GOTO 异常:", type(e).__name__, str(e)[:300], flush=True)
    time.sleep(12)
    print("URL:", page.url, flush=True)
    try:
        print("TITLE:", page.title(), flush=True)
        txt = page.evaluate("() => document.body ? document.body.innerText.slice(0, 400) : 'no body'")
        print("BODY:", txt, flush=True)
        html = page.evaluate("() => document.documentElement.outerHTML.length")
        print("HTML长度:", html, flush=True)
    except Exception as e:
        print("读取页面失败:", str(e)[:300], flush=True)
    shot = BASE / "diag-home.png"
    try:
        page.screenshot(path=str(shot), full_page=False)
        print("截图:", shot, flush=True)
    except Exception as e:
        print("截图失败:", str(e)[:200], flush=True)
    ctx.close()
