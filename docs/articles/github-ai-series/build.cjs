// 通用构建：把某篇文章的 body.html 渲染成可本地预览的 article.html
// 用法: node build.cjs <文章目录名> "<标题>"
const fs = require('fs');
const path = require('path');

const dirName = process.argv[2];
const title = process.argv[3] || '未命名';
if (!dirName) {
  console.error('缺少文章目录名');
  process.exit(1);
}

const dir = path.join(__dirname, dirName);
const bodyPath = path.join(dir, 'body.html');
const body = fs.readFileSync(bodyPath, 'utf8');

// 占位行: <p ...>［插图 1｜说明 → images/xx.png，插入后删掉本行］</p>
const markerRe = /<p[^>]*>［插图[^<]*?→\s*(images\/[^\s，,]+)[^<]*?］<\/p>/g;
let count = 0;
const rendered = body.replace(markerRe, (_m, src) => {
  count += 1;
  return `<p style="text-align: center; margin: 24px 0;">
  <img src="${src}" style="max-width: 100%; border-radius: 8px; display: block; margin: 0 auto;" alt="">
</p>`;
});

const plain = rendered.replace(/<[^>]+>/g, '').replace(/\s+/g, '');
const cjk = (plain.match(/[\u4e00-\u9fa5]/g) || []).length;

const html = `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${title}</title>
<style>
  body { max-width: 750px; margin: 0 auto; padding: 24px 16px; background: #fff;
         font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Microsoft YaHei", sans-serif;
         font-size: 16px; line-height: 1.75; color: #333; letter-spacing: 0.5px; }
  img { max-width: 100%; }
</style>
</head>
<body>
${rendered}
</body>
</html>
`;
fs.writeFileSync(path.join(dir, 'article.html'), html, 'utf8');
console.log(`${dirName}: 中文 ${cjk} 字 | 占位图 ${count} 张`);
