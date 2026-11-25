const puppeteer = require('puppeteer-core');

const CHROME = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const SRC = 'file:///D:/zzz/articles/ahu-pig-farm/cover-poster.html';
const OUT = 'D:\\zzz\\articles\\ahu-pig-farm\\images\\cover-poster.png';

(async () => {
  const browser = await puppeteer.launch({
    executablePath: CHROME,
    headless: true,
    args: ['--no-sandbox', '--hide-scrollbars', '--allow-file-access-from-files'],
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 2560, height: 1080, deviceScaleFactor: 1 });
  await page.goto(SRC, { waitUntil: 'networkidle0' });
  await page.evaluate(() => document.fonts.ready);
  await new Promise((r) => setTimeout(r, 300));
  await page.screenshot({ path: OUT, type: 'png' });
  const size = await page.evaluate(() => ({ w: document.body.scrollWidth, h: document.body.scrollHeight }));
  await browser.close();
  console.log('saved', OUT, size);
})();
