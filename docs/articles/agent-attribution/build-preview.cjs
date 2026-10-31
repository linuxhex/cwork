// 把 body 片段构建成可本地预览的完整 HTML（标记位替换为 img）
const fs = require('fs');
const path = require('path');

const dir = __dirname;
const body = fs.readFileSync(path.join(dir, 'agent-attribution-body.html'), 'utf8');

const figMap = {
  '［图1］': { src: 'images/01-four-layers.png', caption: '图 1｜一个 Agent 的四个可归因层' },
  '［插图 1｜四层归因示意图 → images/01-four-layers.png，插入后删掉本行］': { src: 'images/01-four-layers.png', caption: '图 1｜一个 Agent 的四个可归因层' },
  '［图2］': { src: 'images/02-experiment.png', caption: '图 2｜换模型 vs 换 harness 的对照' },
  '［插图 2｜2×2 对照实验图 → images/02-experiment.png，插入后删掉本行］': { src: 'images/02-experiment.png', caption: '图 2｜换模型 vs 换 harness 的对照' },
  '［图3］': { src: 'images/03-trace.png', caption: '图 3｜顺着运行轨迹往上查' },
  '［插图 3｜按运行轨迹排查图 → images/03-trace.png，插入后删掉本行］': { src: 'images/03-trace.png', caption: '图 3｜顺着运行轨迹往上查' },
};

let out = body;
for (const [marker, fig] of Object.entries(figMap)) {
  const html = `<p style="text-align: center; margin: 24px 0;">
  <img src="${fig.src}" style="max-width: 100%; border-radius: 8px; display: block; margin: 0 auto;" alt="${fig.caption}">
  <span style="display: inline-block; margin-top: 8px; font-size: 13px; color: #999;">${fig.caption}</span>
</p>`;
  out = out.split(marker).join(html);
}

const plain = out.replace(/<[^>]+>/g, '').replace(/&nbsp;/g, ' ').replace(/\s+/g, '');
const cjk = (plain.match(/[\u4e00-\u9fa5]/g) || []).length;

const html = `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>为什么同事的 Agent 好用，你的不好用？差别全在这四层</title>
<style>
  body { max-width: 750px; margin: 0 auto; padding: 24px 16px; background: #fff;
         font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Microsoft YaHei", sans-serif;
         font-size: 16px; line-height: 1.75; color: #333; letter-spacing: 0.5px; }
  img { max-width: 100%; }
</style>
</head>
<body>
${out}
</body>
</html>
`;
fs.writeFileSync(path.join(dir, 'agent-attribution.html'), html, 'utf8');
console.log('中文正文字数:', cjk, '| 总可见字符:', plain.length);
