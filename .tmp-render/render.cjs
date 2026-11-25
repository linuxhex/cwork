const puppeteer = require('puppeteer-core');
const fs = require('fs');
const path = require('path');

const CHROME = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const SRC = 'file:///D:/zzz/articles/ahu-pig-farm/article.html';
const OUT = 'D:\\zzz\\articles\\ahu-pig-farm\\images';
const COVER_SRC = path.resolve(__dirname, '..', 'vibe_images', 'pig-farm-cover_1794967467634_d9265bbd.png');
const MAX_H = 1400; // CSS px per slice

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await puppeteer.launch({
    executablePath: CHROME,
    headless: true,
    args: ['--no-sandbox', '--hide-scrollbars', '--force-device-scale-factor=2'],
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 750, height: 1200, deviceScaleFactor: 2 });
  await page.goto(SRC, { waitUntil: 'networkidle0' });
  await page.evaluate(() => document.fonts.ready);

  const info = await page.evaluate(() => {
    const art = document.getElementById('article');
    const artTop = art.getBoundingClientRect().top + window.scrollY;
    const artLeft = art.getBoundingClientRect().left;
    const children = [...art.children].map((el) => {
      const r = el.getBoundingClientRect();
      return { top: r.top + window.scrollY, bottom: r.bottom + window.scrollY };
    });
    return {
      artTop,
      artLeft,
      artWidth: art.getBoundingClientRect().width,
      artHeight: art.getBoundingClientRect().height,
      children,
    };
  });

  // pack children into slices <= MAX_H, never splitting an element
  const slices = [];
  let curTop = info.artTop;
  let curBottom = info.artTop;
  for (const c of info.children) {
    if (curBottom > curTop && c.bottom - curTop > MAX_H) {
      slices.push({ top: curTop, bottom: curBottom });
      curTop = curBottom;
    }
    curBottom = c.bottom;
  }
  if (curBottom > curTop) slices.push({ top: curTop, bottom: curBottom });

  // bottom padding / tail
  const totalBottom = info.artTop + info.artHeight;
  if (slices.length && slices[slices.length - 1].bottom < totalBottom) {
    slices[slices.length - 1].bottom = totalBottom;
  }

  const files = [];
  for (let i = 0; i < slices.length; i++) {
    const s = slices[i];
    const clip = {
      x: info.artLeft,
      y: s.top,
      width: info.artWidth,
      height: s.bottom - s.top,
    };
    const file = path.join(OUT, `page-${String(i + 1).padStart(2, '0')}.png`);
    await page.screenshot({ path: file, clip, captureBeyondViewport: true });
    files.push({ file, heightCss: Math.round(clip.height) });
  }

  fs.copyFileSync(COVER_SRC, path.join(OUT, 'cover.png'));
  console.log(JSON.stringify({ totalHeightCss: Math.round(info.artHeight), slices: files }, null, 2));
  await browser.close();
})().catch((e) => {
  console.error('RENDER FAILED:', e);
  process.exit(1);
});
