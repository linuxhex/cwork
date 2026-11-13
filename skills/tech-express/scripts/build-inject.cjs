// 由 body.html 生成可在公众号编辑器页面直接执行的注入脚本（base64 规避 JS 字符串转义清洗）
// 用法: node build-inject.cjs <文章目录>        # 相对 cwd 或绝对路径均可
const fs = require('fs');
const path = require('path');

const arg = process.argv[2];
if (!arg) { console.error('缺少文章目录参数'); process.exit(1); }
const dir = path.resolve(arg);
const bodyFile = path.join(dir, 'body.html');
if (!fs.existsSync(bodyFile)) { console.error(`找不到 ${bodyFile}`); process.exit(1); }

// BOM 会跟着注进正文开头（PowerShell/记事本写出的 body.html 常带），先剔掉
const body = fs.readFileSync(bodyFile, 'utf8').replace(/^\uFEFF+/, '');
const b64 = Buffer.from(body, 'utf8').toString('base64');

// 页面内执行的正文注入主体（base64 解码后整块插入正文编辑区）
const CORE = `
    try {
      const bytes = Uint8Array.from(atob('${b64}'), c => c.charCodeAt(0));
      const html = new TextDecoder('utf-8').decode(bytes);
      const nodes = Array.from(document.querySelectorAll('[contenteditable="true"]'));
      const info = nodes.map(n => ({ tag: n.tagName, len: n.innerText.length, hasPlaceholder: n.innerText.indexOf('从这里开始写正文') >= 0 }));
      const target = nodes.find(n => n.innerText.indexOf('从这里开始写正文') >= 0)
        || nodes.filter(n => n.innerText.length < 200).pop()
        || nodes[nodes.length - 1];
      if (!target) return { ok: false, reason: 'no editable node', info };
      target.focus();
      const sel = window.getSelection();
      const range = document.createRange();
      range.selectNodeContents(target);
      sel.removeAllRanges();
      sel.addRange(range);
      document.execCommand('delete', false, null);
      const inserted = document.execCommand('insertHTML', false, html);
      if (!inserted) target.innerHTML = html;
      target.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText', data: null }));
      target.dispatchEvent(new Event('change', { bubbles: true }));
      return {
        ok: true,
        usedFallback: !inserted,
        h2: target.querySelectorAll('h2').length,
        table: target.querySelectorAll('table').length,
        img: target.querySelectorAll('img').length,
        chars: target.innerText.length,
        head: target.innerText.slice(0, 60),
        info
      };
    } catch (e) {
      return { ok: false, reason: String(e) };
    }
`;

// 两种形式同一份主体，分别给两条交付链路，勿手改内容
//   inject.js    IIFE —— Playwright page.evaluate(inject) 备用链路
//   inject-fn.js 箭头函数 —— 工作台自带浏览器 browser-use evaluate_script 的 function 参数（要的是函数声明）
fs.writeFileSync(path.join(dir, 'inject.js'), `(() => {${CORE}})()\n`, 'utf8');
fs.writeFileSync(path.join(dir, 'inject-fn.js'), `() => {${CORE}}\n`, 'utf8');
const fnLen = fs.statSync(path.join(dir, 'inject-fn.js')).size;

// 正文自检：CJK 字数（速递目标 1500-2200）+ 残留插图标记
const cjk = (body.match(/[\u4e00-\u9fa5]/g) || []).length;
const markers = (body.match(/［插图/g) || []).length;
const classes = (body.match(/\sclass\s*=/g) || []).length;
const tail = [
  `${dir}`,
  `  inject.js / inject-fn.js 已生成（fn ${fnLen} bytes）`,
  `  CJK ${cjk}（目标 1500-2200）`,
  `  残留插图标记 ${markers}`,
  `  class 属性 ${classes}（必须 0，公众号只认 inline style）`,
];
console.log(tail.join('\n'));
if (fnLen > 200000) console.warn('警告：注入体超 200KB，evaluate_script 传参可能被截，把当日正文拆短');
if (classes > 0) console.warn('警告：正文含 class 属性，样式会被丢弃');
