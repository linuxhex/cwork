#!/usr/bin/env node
/**
 * 封面海报合成：ImageGen 底图 + 中文大字 + 上升趋势线，本地 Chrome 渲染成图。
 *
 * 为什么不用 ImageGen 直接出中文：图像模型写不对汉字。
 * 做法：底图内联为 base64 → HTML 叠字与 SVG 趋势线 → headless Chrome 截图。
 *
 * 用法:
 *   node make-cover-poster.cjs --dir <内容目录>/tech-express/20261119
 *   node make-cover-poster.cjs --dir ... --title 科技速递 --date 11月19日 --sub "..."
 *   node make-cover-poster.cjs --dir <内容目录>/tech-express/_shared --no-date   # 通用封面，跨期复用
 *
 * 产物: <dir>/images/00-cover.png（底图原件自动备份为 00-cover-bg.png，可重复执行）
 * 之后跑 make-cover.ps1 压成 1280 宽 jpg。
 */
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

function arg(name, def) {
  const i = process.argv.indexOf('--' + name);
  return i > 0 && process.argv[i + 1] ? process.argv[i + 1] : def;
}
const has = (name) => process.argv.includes('--' + name);

const dir = path.resolve(arg('dir', ''));
if (!dir || !fs.existsSync(dir)) {
  console.error('用法: node make-cover-poster.cjs --dir <期次目录> [--title 科技速递] [--date 11月19日] [--sub 副标题]');
  process.exit(1);
}

const imgDir = path.join(dir, 'images');
fs.mkdirSync(imgDir, { recursive: true });

const outPath = path.join(imgDir, '00-cover.png');
const bgPath = path.join(imgDir, '00-cover-bg.png');
if (!fs.existsSync(bgPath)) {
  if (!fs.existsSync(outPath)) {
    console.error('找不到底图: ' + outPath + '（先跑 ImageGen 生成 00-cover.png）');
    process.exit(1);
  }
  fs.copyFileSync(outPath, bgPath);
}

const stamp = path.basename(dir);
const md = /^(\d{4})(\d{2})(\d{2})$/.exec(stamp);
// --no-date 出通用封面（不随日期变，可跨期复用）：整条日期行不渲染，不是渲染成空字符串，
// 否则橙色竖条会孤零零挂着，且大字块要下移半个日期行的高度才保持原来的视觉重心。
const noDate = has('no-date');
const dateText = noDate ? '' : arg('date', md ? `${Number(md[2])}月${Number(md[3])}日` : '');
const copyTop = dateText ? 238 : 292;
const title = arg('title', '科技速递');
const sub = arg('sub', '每日 3 分钟 · 看完科技圈三天事');
const kicker = arg('kicker', 'TECH EXPRESS · DAILY BRIEF');
const W = Number(arg('width', 2560));
const H = Number(arg('height', 1080));

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const bg = fs.readFileSync(bgPath).toString('base64');

const pts = [
  [960, 1016], [1120, 962], [1240, 898], [1360, 916], [1480, 826], [1600, 842],
  [1720, 738], [1840, 700], [1960, 606], [2080, 636], [2200, 512],
  [2320, 466], [2440, 326],
];
const line = pts.map((p) => p.join(',')).join(' ');
const last = pts[pts.length - 1];
const area = `960,1046 ${line} ${last[0]},1046`;

const html = `<!doctype html>
<html><head><meta charset="utf-8">
<style>
  * { margin:0; padding:0; box-sizing:border-box; }
  html,body { width:${W}px; height:${H}px; overflow:hidden; background:#04122B; }
  .stage { position:relative; width:${W}px; height:${H}px; font-family:"Microsoft YaHei","Microsoft YaHei UI",system-ui,sans-serif; }
  .bg { position:absolute; inset:0; width:100%; height:100%; object-fit:cover; }
  .veil { position:absolute; inset:0;
    background:linear-gradient(90deg, rgba(4,14,36,.94) 0%, rgba(4,14,36,.80) 34%, rgba(4,14,36,.24) 58%, rgba(4,14,36,.10) 76%, rgba(4,14,36,.42) 100%); }
  .copy { position:absolute; left:150px; top:${copyTop}px; }
  .kicker { font-size:40px; letter-spacing:14px; color:#7FD0FF; font-weight:600; margin-bottom:26px; }
  .title { font-size:246px; line-height:1; font-weight:900; color:#ffffff; letter-spacing:8px;
    text-shadow:0 10px 44px rgba(0,0,0,.55), 0 0 72px rgba(24,144,255,.55); }
  .daterow { display:flex; align-items:center; margin-top:36px; }
  .bar { width:8px; height:66px; background:#FF9A2E; border-radius:4px; margin-right:22px; }
  .date { font-size:80px; font-weight:700; color:#ffffff; letter-spacing:4px; }
  .sub { margin-top:${dateText ? 22 : 44}px; font-size:38px; color:#A9C8EA; letter-spacing:3px; }
  .chart { position:absolute; inset:0; }
</style></head>
<body><div class="stage">
  <img class="bg" src="data:image/png;base64,${bg}" alt="">
  <div class="veil"></div>
  <svg class="chart" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" xmlns="http://www.w3.org/2000/svg">
    <defs>
      <linearGradient id="stroke" x1="0" y1="1" x2="1" y2="0">
        <stop offset="0%" stop-color="#4FC3FF" stop-opacity=".55"/>
        <stop offset="55%" stop-color="#7FE6FF"/>
        <stop offset="100%" stop-color="#FFC46B"/>
      </linearGradient>
      <linearGradient id="fill" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0%" stop-color="#63D8FF" stop-opacity=".30"/>
        <stop offset="100%" stop-color="#63D8FF" stop-opacity="0"/>
      </linearGradient>
      <filter id="glow" x="-20%" y="-40%" width="140%" height="200%">
        <feGaussianBlur stdDeviation="16" result="b"/>
        <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
      </filter>
    </defs>
    ${[380, 620, 860].map((y) => `<line x1="1040" y1="${y}" x2="2480" y2="${y}" stroke="#ffffff" stroke-opacity=".10" stroke-width="2" stroke-dasharray="14 18"/>`).join('')}
    <polygon points="${area}" fill="url(#fill)"/>
    <polyline points="${line}" fill="none" stroke="url(#stroke)" stroke-width="12"
      stroke-linecap="round" stroke-linejoin="round" filter="url(#glow)"/>
    <circle cx="${last[0]}" cy="${last[1]}" r="44" fill="#FFC46B" opacity=".18"/>
    <circle cx="${last[0]}" cy="${last[1]}" r="18" fill="#FFE2B4"/>
  </svg>
  <div class="copy">
    <div class="kicker">${esc(kicker)}</div>
    <div class="title">${esc(title)}</div>
    ${dateText ? `<div class="daterow"><div class="bar"></div><div class="date">${esc(dateText)}</div></div>` : ''}
    <div class="sub">${esc(sub)}</div>
  </div>
</div></body></html>`;

const tmpHtml = path.join(os.tmpdir(), `cwork-cover-${Date.now()}.html`);
fs.writeFileSync(tmpHtml, html, 'utf8');

const candidates = [
  process.env.CHROME_PATH,
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
  path.join(process.env.LOCALAPPDATA || '', 'Google/Chrome/Application/chrome.exe'),
].filter((p) => p && fs.existsSync(p));
if (!candidates.length) {
  console.error('找不到 Chrome，可设 CHROME_PATH 环境变量');
  process.exit(1);
}

const r = spawnSync(candidates[0], [
  '--headless=new', '--disable-gpu', '--hide-scrollbars', '--no-first-run',
  '--no-default-browser-check', '--force-device-scale-factor=1',
  '--user-data-dir=' + path.join(os.tmpdir(), 'cwork-cover-profile'),
  `--window-size=${W},${H}`,
  '--screenshot=' + outPath,
  'file:///' + tmpHtml.replace(/\\/g, '/'),
], { timeout: 90000, encoding: 'utf8' });

fs.rmSync(tmpHtml, { force: true });
if (!fs.existsSync(outPath)) {
  console.error('渲染失败', r.status, (r.stderr || '').slice(-800));
  process.exit(1);
}

const buf = fs.readFileSync(outPath);
const w = buf.readUInt32BE(16);
const h = buf.readUInt32BE(20);
console.log(`封面已更新: ${outPath} ${w}x${h} ${buf.length} bytes`);
console.log('下一步: powershell -ExecutionPolicy Bypass -File make-cover.ps1 -Dir <期次目录>');
