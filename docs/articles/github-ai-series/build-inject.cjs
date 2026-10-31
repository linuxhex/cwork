// 生成可在公众号编辑器页面直接执行的注入脚本（base64 规避转义问题）
// 用法: node build-inject.cjs <文章目录名>
const fs = require('fs');
const path = require('path');

const dirName = process.argv[2];
if (!dirName) { console.error('缺少文章目录名'); process.exit(1); }
const dir = path.join(__dirname, dirName);
const body = fs.readFileSync(path.join(dir, 'body.html'), 'utf8');
const b64 = Buffer.from(body, 'utf8').toString('base64');

const js = `(() => {
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
})()
`;
fs.writeFileSync(path.join(dir, 'inject.js'), js, 'utf8');
console.log(`${dirName}: inject.js ${js.length} bytes`);
