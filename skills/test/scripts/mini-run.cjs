#!/usr/bin/env node
/**
 * cwork-test 小程序测试执行器（原生 miniprogram-automator 直连）
 *
 * 为什么存在：weixin-devtools-mcp 的网络监控会 mockWxMethod('request'/...) 劫持
 * wx.request 并把响应替换成占位符（stop 后也清不干净），污染业务请求导致页面
 * 行为异常；且 MCP 层除 connect 外无超时，命令挂起时整个测试会话卡死。
 * 本脚本直连 automator WebSocket，不 mock 任何 wx API，所有操作带超时看门狗。
 *
 * 用法：
 *   node mini-run.cjs --check                              # 探活：连接 + 当前页面
 *   node mini-run.cjs --snapshot [--out snap.json]          # 快照：当前页 path + data + 可交互元素清单（供 AI 写选择器）
 *   node mini-run.cjs --plan plan.json [--out result.json]  # 跑测试计划
 *
 * plan.json 结构（scenarios[].steps[] 按序执行）：
 * {
 *   "wsEndpoint": "ws://127.0.0.1:9420",
 *   "stepTimeoutMs": 15000,
 *   "scenarios": [{
 *     "name": "用户登录", "priority": "P0",
 *     "steps": [
 *       {"action": "navigate", "url": "/pages/login/login"},
 *       {"action": "input",  "selector": "input[placeholder*='手机号']", "text": "13800138000"},
 *       {"action": "click",  "selector": "button.login-btn"},
 *       {"action": "expectPage", "path": "pages/index/index"},
 *       {"action": "expectData", "key": "userInfo.level", "value": "NORMAL"}
 *     ]
 *   }]
 * }
 *
 * 支持的动作：
 *   navigate {url, type?}    type=navigateTo|switchTab|reLaunch|redirectTo（默认 navigateTo；TabBar 页必须 switchTab）
 *   back {}                  wx.navigateBack()
 *   click {selector, index?} 元素 tap（先 $$ 定位，找不到=失败）
 *   input {selector, text}   元素 input
 *   callMethod {method, args?}  页面方法
 *   setData {data}           页面 setData
 *   evaluate {script}        小程序上下文执行 JS（script 为函数体字符串，return 有值）
 *   wait {ms}                固定等待
 *   expectPage {path}        当前页面 path 包含预期
 *   expectData {key, value?|contains?}  页面 data 点路径断言（key 支持 a.b.c）
 *   expectText {selector, contains}     元素文本包含
 *   expectElement {selector}            元素存在
 */

'use strict';

const fs = require('fs');
const path = require('path');

// ── automator 多路径定位（全局独立包 → weixin-devtools-mcp 内嵌包）──
function loadAutomator() {
  const candidates = [];
  try { candidates.push(require.resolve('miniprogram-automator')); } catch (_) {}
  const npmRoots = [
    '/opt/homebrew/lib/node_modules',
    '/usr/local/lib/node_modules',
    path.join(require('os').homedir(), '.npm-global/lib/node_modules'),
  ];
  for (const root of npmRoots) {
    candidates.push(path.join(root, 'miniprogram-automator'));
    candidates.push(path.join(root, 'weixin-devtools-mcp/node_modules/miniprogram-automator'));
  }
  for (const c of candidates) {
    try { return require(c); } catch (_) { /* 试下一个 */ }
  }
  console.error('❌ 未找到 miniprogram-automator，安装方式：npm install -g miniprogram-automator（或 weixin-devtools-mcp 已内嵌）');
  process.exit(1);
}

// ── 每操作超时保护（automator Connection.send 无超时，挂起全靠这层）──
function withTimeout(promise, ms, label) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error(`${label} 超时(${ms}ms)——判定挂起，按 mini-test.md「挂起检测与恢复」处理`)), ms);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// 点路径取值：a.b.c → obj.a.b.c
function getPath(obj, key) {
  return String(key).split('.').reduce((o, k) => (o == null ? undefined : o[k]), obj);
}

class Runner {
  constructor(mp, stepTimeoutMs) {
    this.mp = mp;
    this.stepTimeoutMs = stepTimeoutMs;
  }

  t(p, label) { return withTimeout(p, this.stepTimeoutMs, label); }

  async currentPage() {
    return this.t(this.mp.currentPage(), '获取当前页面');
  }

  // 导航一律 evaluate 调 wx.*（automator 导航方法直调会挂起，实测结论）
  async navigate(step) {
    const type = step.type || 'navigateTo';
    const allowed = ['navigateTo', 'switchTab', 'reLaunch', 'redirectTo'];
    if (!allowed.includes(type)) throw new Error(`不支持的导航类型: ${type}（可选 ${allowed.join('/')}）`);
    await this.t(this.mp.evaluate((url, t) => { wx[t]({ url }); }, step.url, type), `navigate(${type})`);
    // 轮询等页面就位（currentPage 在稳定清单内）
    const target = step.url.split('?')[0].replace(/^\/+/, '');
    const deadline = Date.now() + Math.min(this.stepTimeoutMs, 8000);
    let current = '';
    while (Date.now() < deadline) {
      await sleep(300);
      try {
        const page = await this.currentPage();
        current = (page && page.path) ? await this.t(page.path, '读取页面path') : '';
        if (current.replace(/^\/+/, '').includes(target.split('/').pop())) return current;
      } catch (_) { /* 页面切换中，继续轮询 */ }
    }
    return current; // 未就位不立刻判死，交由后续断言判定
  }

  async findElement(selector, index) {
    const page = await this.currentPage();
    const elements = await this.t(page.$$(selector), `查找元素 ${selector}`);
    if (!elements || elements.length === 0) throw new Error(`元素未找到: ${selector}`);
    const el = elements[index || 0];
    if (!el) throw new Error(`元素索引 ${index || 0} 超出范围（共 ${elements.length} 个）: ${selector}`);
    return el;
  }

  async runStep(step, idx) {
    const label = `步骤${idx + 1} ${step.action}`;
    try {
      switch (step.action) {
        case 'navigate': return { ok: true, detail: await this.navigate(step) };
        case 'back':
          await this.t(this.mp.evaluate(() => { wx.navigateBack(); }), 'navigateBack');
          await sleep(500);
          return { ok: true, detail: '' };
        case 'click': {
          const el = await this.findElement(step.selector, step.index);
          await this.t(el.tap(), `点击 ${step.selector}`);
          await sleep(300); // 等 UI 反馈/页面切换
          return { ok: true, detail: step.selector };
        }
        case 'input': {
          const el = await this.findElement(step.selector, step.index);
          await this.t(el.input(step.text), `输入 ${step.selector}`);
          return { ok: true, detail: `${step.selector} ← "${step.text}"` };
        }
        case 'callMethod': {
          const page = await this.currentPage();
          const result = await this.t(page.callMethod(step.method, ...(step.args || [])), `callMethod ${step.method}`);
          return { ok: true, detail: JSON.stringify(result) };
        }
        case 'setData': {
          const page = await this.currentPage();
          await this.t(page.setData(step.data), 'setData');
          return { ok: true, detail: JSON.stringify(step.data) };
        }
        case 'evaluate': {
          const result = await this.t(this.mp.evaluate(new Function(`return (${step.script})`)()), 'evaluate');
          return { ok: true, detail: JSON.stringify(result) };
        }
        case 'wait':
          await sleep(Math.min(step.ms || 1000, 10000));
          return { ok: true, detail: `${step.ms || 1000}ms` };
        case 'expectPage': {
          const page = await this.currentPage();
          const current = (page && page.path) ? await this.t(page.path, '读取页面path') : '';
          const pass = current.replace(/^\/+/, '').includes(String(step.path).replace(/^\/+/, ''));
          if (!pass) throw new Error(`当前页面 ${current} 不含预期 ${step.path}`);
          return { ok: true, detail: current };
        }
        case 'expectData': {
          const page = await this.currentPage();
          const data = await this.t(page.data(), '读取页面data');
          const actual = getPath(data, step.key);
          if (step.value !== undefined) {
            if (JSON.stringify(actual) !== JSON.stringify(step.value)) {
              throw new Error(`data.${step.key} = ${JSON.stringify(actual)}，预期 ${JSON.stringify(step.value)}`);
            }
          } else if (step.contains !== undefined) {
            if (String(actual == null ? '' : actual).indexOf(String(step.contains)) < 0) {
              throw new Error(`data.${step.key} = ${JSON.stringify(actual)}，未包含 "${step.contains}"`);
            }
          } else if (actual == null) {
            throw new Error(`data.${step.key} 不存在（值为 null/undefined）`);
          }
          return { ok: true, detail: `data.${step.key} = ${JSON.stringify(actual)}` };
        }
        case 'expectText': {
          if (step.contains === undefined) throw new Error('expectText 需要 contains 字段（漏写会变成断言"包含 undefined"的静默假行为）');
          const el = await this.findElement(step.selector, step.index);
          const text = await this.t(el.text(), `读取文本 ${step.selector}`);
          if (String(text || '').indexOf(String(step.contains)) < 0) {
            throw new Error(`元素 ${step.selector} 文本 "${text}" 未包含 "${step.contains}"`);
          }
          return { ok: true, detail: text };
        }
        case 'expectElement': {
          await this.findElement(step.selector, step.index);
          return { ok: true, detail: step.selector };
        }
        default:
          throw new Error(`未知 action: ${step.action}`);
      }
    } catch (err) {
      return { ok: false, detail: `${label} 失败：${err.message}` };
    }
  }

  // 快照：当前页 path + data + 可交互元素清单（供 AI 生成 plan.json 时写准确选择器）
  async snapshot() {
    const page = await this.currentPage();
    const pagePath = (page && page.path) ? await this.t(page.path, 'snapshot-path') : '';
    let pageData = {};
    try { pageData = await this.t(page.data(), 'snapshot-data'); } catch (_) { /* data 不可读不影响快照 */ }

    const interactiveSelector = [
      'button', 'input', 'textarea', 'navigator', 'picker',
      'switch', 'slider', 'radio', 'checkbox', 'label[for]',
      'image[data-src]', '[bindtap]', '[catchtap]', '[data-url]',
    ].join(',');

    let elements = [];
    try {
      const els = await this.t(page.$$(interactiveSelector), 'snapshot-elements');
      if (els && els.length > 0) {
        const limit = Math.min(els.length, 80);
        for (let i = 0; i < limit; i++) {
          try {
            const el = els[i];
            const tag = (await this.t(el.tagName(), `snapshot-tag-${i}`)) || '';
            const text = (await this.t(el.text(), `snapshot-text-${i}`)) || '';
            const attrs = (await this.t(el.attrs(), `snapshot-attrs-${i}`)) || {};
            const selector = this._buildSelector(tag, attrs, text);
            elements.push({
              tag,
              text: text.trim().slice(0, 60),
              selector,
              placeholder: attrs.placeholder || '',
              type: attrs.type || '',
              id: attrs.id || '',
              className: attrs.class || '',
            });
          } catch (_) { /* 单个元素读取失败不影响整体 */ }
        }
      }
    } catch (_) { /* 元素查询失败不阻塞快照 */ }

    return { path: pagePath, data: pageData, elements };
  }

  // 从标签+属性构造 CSS 选择器（优先用 id/class，兜底用属性组合）
  _buildSelector(tag, attrs, text) {
    if (attrs.id) return `#${attrs.id}`;
    if (attrs.class && typeof attrs.class === 'string') {
      const firstClass = attrs.class.trim().split(/\s+/)[0];
      if (firstClass && !/^\d/.test(firstClass)) return `${tag}.${firstClass}`;
    }
    if (attrs.placeholder) return `${tag}[placeholder*="${attrs.placeholder.slice(0, 10)}"]`;
    if (attrs['data-url']) return `${tag}[data-url]`;
    return tag;
  }

  // 失败取证：当前页面 path + data dump（不用 screenshot，会挂起）
  async evidence() {
    try {
      const page = await this.currentPage();
      const p = (page && page.path) ? await this.t(page.path, '取证-path') : '(未知)';
      let data = {};
      try { data = await this.t(page.data(), '取证-data'); } catch (_) { /* data 不可读就只给 path */ }
      return { page: p, data };
    } catch (err) {
      return { error: `取证失败: ${err.message}` };
    }
  }
}

async function main() {
  const args = process.argv.slice(2);
  const planFile = args.includes('--plan') ? args[args.indexOf('--plan') + 1] : null;
  const outFile = args.includes('--out') ? args[args.indexOf('--out') + 1] : null;
  const checkOnly = args.includes('--check');
  const snapshotMode = args.includes('--snapshot');

  if (!planFile && !checkOnly && !snapshotMode) {
    console.error('用法：node mini-run.cjs --check | --snapshot [--out snap.json] | --plan plan.json [--out result.json]');
    process.exit(1);
  }

  const automator = loadAutomator();
  const plan = planFile ? JSON.parse(fs.readFileSync(planFile, 'utf8')) : {};
  const wsEndpoint = plan.wsEndpoint || 'ws://127.0.0.1:9420';
  const stepTimeoutMs = plan.stepTimeoutMs || 15000;

  // 全局看门狗：任何不可恢复的挂起最终由它兜底（默认 10 分钟）
  const budgetMs = plan.totalBudgetMs || 10 * 60 * 1000;
  setTimeout(() => { console.error(`❌ 全局看门狗触发（${budgetMs}ms 预算耗尽），强制退出——疑似挂起，跑 mini-recover.sh 恢复`); process.exit(2); }, budgetMs).unref();

  let mp = null;
  const summary = { scenarios: [], startedAt: new Date().toISOString() };
  try {
    console.log(`→ 连接 ${wsEndpoint}（原生 automator，无请求劫持）...`);
    mp = await withTimeout(automator.connect({ wsEndpoint }), 15000, '连接开发者工具');

    if (checkOnly) {
      const page = await withTimeout(mp.currentPage(), 10000, '获取当前页面');
      const p = (page && page.path) ? await withTimeout(page.path, 5000, '读取path') : '(空)';
      console.log(`✓ 探活成功：automator 可用，当前页面 ${p}`);
      return;
    }

    if (snapshotMode) {
      const runner = new Runner(mp, stepTimeoutMs);
      const snap = await runner.snapshot();
      if (outFile) fs.writeFileSync(outFile, JSON.stringify(snap, null, 2), 'utf8');
      console.log(`✓ 快照完成：${snap.path}，${snap.elements.length} 个可交互元素${outFile ? `，已存 ${outFile}` : ''}`);
      console.log('SNAPSHOT_JSON=' + JSON.stringify(snap));
      return;
    }

    const runner = new Runner(mp, stepTimeoutMs);
    const scenarios = plan.scenarios || [];
    // 空计划防护：静默跑 0 场景会输出「通过 0 失败 0」假绿，必须响亮失败
    if (!Array.isArray(scenarios) || scenarios.length === 0) {
      throw new Error('plan.json 无 scenarios（或为空数组）——拒绝执行空测试计划');
    }
    let failedScenarios = 0;

    for (const sc of scenarios) {
      console.log(`\n【场景】${sc.name}（${sc.priority || 'P1'}）`);
      const result = { name: sc.name, priority: sc.priority || 'P1', steps: [], ok: true };
      for (let i = 0; i < (sc.steps || []).length; i++) {
        const step = sc.steps[i];
        const r = await runner.runStep(step, i);
        result.steps.push({ action: step.action, ...r });
        console.log(`  ${r.ok ? '✓' : '✗'} ${r.detail}`);
        if (!r.ok) {
          result.ok = false;
          result.evidence = await runner.evidence();
          break; // 场景内首败即停（证据已取，继续点会放大异常）
        }
      }
      result.ok ? console.log(`  场景结果：✓ 通过`) : (failedScenarios++, console.log(`  场景结果：✗ 失败`));
      summary.scenarios.push(result);
    }

    summary.finishedAt = new Date().toISOString();
    summary.passed = summary.scenarios.length - failedScenarios;
    summary.failed = failedScenarios;

    if (outFile) fs.writeFileSync(outFile, JSON.stringify(summary, null, 2), 'utf8');
    console.log(`\n═══ 结果：通过 ${summary.passed} / 失败 ${summary.failed}（共 ${summary.scenarios.length} 场景）${outFile ? `，详情 ${outFile}` : ''} ═══`);
    console.log('RESULT_JSON=' + JSON.stringify(summary));
    process.exitCode = failedScenarios > 0 ? 1 : 0;
  } catch (err) {
    console.error(`❌ ${err.message}`);
    process.exitCode = 2;
  } finally {
    if (mp) { try { mp.disconnect(); } catch (_) { /* 断开失败不掩盖主流程结果 */ } }
  }
}

main();
