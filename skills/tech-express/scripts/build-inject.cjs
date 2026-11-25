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
// 期望的 h2 数：注入后拿它对账，多了=编辑器把旧自动保存版本并进来了，少了=没落库
const expectedH2 = (body.match(/<h2/gi) || []).length;

// 页面内执行的正文注入主体（base64 解码后整块插入正文编辑区）
const CORE = `
    const sleep = (ms) => new Promise(r => setTimeout(r, ms));
    try {
      const expectedH2 = ${expectedH2};
      const bytes = Uint8Array.from(atob('${b64}'), c => c.charCodeAt(0));
      const html = new TextDecoder('utf-8').decode(bytes);
      const nodes = Array.from(document.querySelectorAll('[contenteditable="true"]'));
      const info = nodes.map(n => ({ tag: n.tagName, cls: String(n.className || '').slice(0, 40), len: n.innerText.length, hasPlaceholder: n.innerText.indexOf('从这里开始写正文') >= 0 }));
      // 新建草稿靠占位符定位正文；改已有草稿时占位符已消失，正文一定是可编辑节点里最长的那个。
      // 切勿用「最短的空节点」兜底：那是原创推荐语/摘要位，写进去不进正文，保存后静默丢弃。
      const target = nodes.find(n => n.innerText.indexOf('从这里开始写正文') >= 0)
        || nodes.slice().sort((a, b) => b.innerText.length - a.innerText.length)[0];
      if (!target) return { ok: false, reason: 'no editable node', info };
      const countH2 = () => target.querySelectorAll('h2').length;
      const before = { h2: countH2(), chars: target.innerText.length };
      // 清空后正文只该剩一个空段落。还留着带样式的 section 或任何渐变，就是旧正文的外壳：
      // 粘进去的新正文会整套被包在这个色块里（20261120 实测踩过，整篇被装进深蓝盒子）。
      const shell = () => {
        const fe = target.firstElementChild;
        if (!fe) return '';
        const st = fe.getAttribute('style') || '';
        return (fe.tagName === 'SECTION' || /linear-gradient/i.test(st)) ? st.slice(0, 90) : '';
      };
      const clear = () => {
        // 必须用原生 selectAll：ProseMirror 只认自己的选区，直接设 DOM Range 它未必同步，
        // 结果 paste 变成「插入」而不是「替换」，正文成了新旧两份（20261120 实测踩过）。
        for (let i = 0; i < 3; i++) {
          target.focus();
          document.execCommand('selectAll', false, null);
          document.execCommand('delete', false, null);
          if (target.innerText.replace(/\\s/g, '').length <= 20 && !shell()) break;
          const sel = window.getSelection();
          const range = document.createRange();
          range.selectNodeContents(target);
          sel.removeAllRanges();
          sel.addRange(range);
          document.execCommand('delete', false, null);
        }
        return { chars: target.innerText.replace(/\\s/g, '').length, shell: shell() };
      };
      const cleared = clear();
      // 外壳清不掉就别粘了：粘进去也是整篇被包在旧色块里，返回失败让调用方放弃保存
      if (cleared.shell) {
        return {
          ok: false,
          reason: '清空后仍残留旧正文外壳，继续粘贴会把整篇包进该色块：' + cleared.shell,
          mode: 'none', expectedH2: expectedH2, h2: countH2(),
          before: before, clearedChars: cleared.chars, clearedShell: cleared.shell, info
        };
      }
      // 正文区是 ProseMirror，只认自己的文档状态：直接改 DOM（execCommand / innerHTML）在
      // 「已有正文的草稿」上不会被内部状态采纳，点保存时会把旧正文序列化回服务端（静默失败）。
      // 所以只走 paste：把 HTML 交给编辑器自己解析。
      let mode = 'none';
      let handled = false;
      try {
        const dt = new DataTransfer();
        dt.setData('text/html', html);
        dt.setData('text/plain', 'tech-express');
        const ev = new ClipboardEvent('paste', { clipboardData: dt, bubbles: true, cancelable: true });
        handled = target.dispatchEvent(ev) === false;
      } catch (e) { handled = false; }
      if (handled) {
        // 公众号编辑器的粘贴是异步的（HTML 要过一遍服务端清洗），派发完立刻数 h2 一定数不到。
        // 此时若退回改 DOM，两条路径各写一遍，正文会成倍增长（20261120 实测：5 → 10 → 20）。
        // 所以派发成功就只轮询等结果，最多 15 秒。
        mode = 'paste';
        for (let i = 0; i < 30; i++) {
          if (countH2() === expectedH2) break;
          await sleep(500);
        }
      } else {
        clear();
        const inserted = document.execCommand('insertHTML', false, html);
        if (inserted) mode = 'execCommand';
        else { target.innerHTML = html; mode = 'innerHTML'; }
        target.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText', data: null }));
        target.dispatchEvent(new Event('change', { bubbles: true }));
      }
      const h2 = countH2();
      const h2Ok = h2 === expectedH2;
      return {
        ok: h2Ok,
        reason: h2Ok ? '' : 'h2 与 body.html 期望值不一致：正文被编辑器合并了旧版本，或粘贴未落地',
        mode: mode,
        usedFallback: mode !== 'paste',
        pasteHandled: handled,
        expectedH2: expectedH2,
        h2: h2,
        h2Ok: h2Ok,
        before: before,
        clearedChars: cleared.chars,
        clearedShell: cleared.shell,
        grad: Array.from(target.querySelectorAll('*'))
          .filter(e => /linear-gradient/i.test(e.getAttribute('style') || '')).length,
        targetIndex: nodes.indexOf(target),
        targetClass: String(target.className || '').slice(0, 40),
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
//   inject.js    async IIFE —— Playwright page.evaluate(inject) 备用链路
//   inject-fn.js async 箭头函数 —— 工作台自带浏览器 browser-use evaluate_script 的 function 参数
// 主体含 await（等编辑器异步粘贴落地），两边都必须是 async 形式，否则语法错。
fs.writeFileSync(path.join(dir, 'inject.js'), `(async () => {${CORE}})()\n`, 'utf8');
fs.writeFileSync(path.join(dir, 'inject-fn.js'), `async () => {${CORE}}\n`, 'utf8');
const fnLen = fs.statSync(path.join(dir, 'inject-fn.js')).size;

// 正文自检：CJK 字数（不设上限，仅报实测值）+ 首屏摘要长度（≤56）+ 残留插图标记
const cjk = (body.match(/[\u4e00-\u9fa5]/g) || []).length;
const markers = (body.match(/［插图/g) || []).length;
const classes = (body.match(/\sclass\s*=/g) || []).length;
const gradients = (body.match(/linear-gradient/gi) || []).length;
const dm = body.match(/<b>摘要[:：]<\/b>([^<]+)/) || body.match(/摘要[:：]\s*([^<\n]{0,160})/);
const digest = dm ? dm[1].replace(/&nbsp;/g, ' ').trim() : '';
const digestChars = digest.replace(/\s/g, '').length;
const tail = [
  `${dir}`,
  `  inject.js / inject-fn.js 已生成（fn ${fnLen} bytes）`,
  `  CJK ${cjk}（字数不设上限，此值仅报实测；编辑器「正文字数」另计英数标点）`,
  `  摘要 ${digestChars} 字（≤56）${digest ? '：' + digest.slice(0, 30) + (digest.length > 30 ? '…' : '') : '（首屏没找到摘要行）'}`,
  `  期望 h2 ${expectedH2}（注入后按此对账，多了=被合并旧版本，少了=没落库）`,
  `  期望渐变 ${gradients}（浅色排版应为 0；落库后多出=正文被套在旧的深色外壳里）`,
  `  残留插图标记 ${markers}`,
  `  class 属性 ${classes}（必须 0，公众号只认 inline style）`,
];
console.log(tail.join('\n'));
if (fnLen > 200000) console.warn('警告：注入体超 200KB，evaluate_script 传参可能被截，改走 deliver.md A4b 的 gzip + window.name 通道');
if (classes > 0) console.warn('警告：正文含 class 属性，样式会被丢弃');
if (!digest) console.warn('警告：首屏缺「摘要：</b>」行 —— 摘要既要有正文首屏那一行，也要填编辑器 #js_description 字段');
else if (digestChars > 56) console.warn(`警告：摘要 ${digestChars} 字超 56 字上限，砍修饰词，别砍数字`);
