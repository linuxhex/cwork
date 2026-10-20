#!/usr/bin/env node
/**
 * cwork-test Web 测试执行器（ego-browser 驱动）
 *
 * 设计思路：
 *   AI 生成 plan.json（声明式测试计划）→ web-run.cjs 生成 heredoc → ego-browser 执行
 *   基础断言（数据/布局/样式/接口）在执行器内确定性完成
 *   AI 断言（视觉/语义）走两阶段：收集上下文 → AI 判断 → 带结果重跑
 *
 * 用法：
 *   node web-run.cjs --plan plan.json [--ctx-dir DIR] [--out result.json]
 *     → 完整流程：plan 无 aiAssert 时单遍直通；有 aiAssert 时 collect → AI 判断 → run
 *
 *   node web-run.cjs --collect --plan plan.json --ctx-dir DIR
 *     → 只执行到 aiAssert 点，收集上下文（截图+DOM+接口响应），输出 AI_ASSERT_PENDING
 *
 *   node web-run.cjs --run --plan plan.json --ctx-dir DIR
 *     → 带预判断结果执行（读 CTX_DIR/s{i}_i{j}.result.json，缺失 = 该步失败，不跳过）
 *
 *   node web-run.cjs --snapshot --url <baseUrl> [--out snap.json]
 *     → 标准化采集：打开页面 + 注入接口拦截器 + snapshotText + pageInfo + 截图
 *       供 AI 生成 plan.json 选择器 / 手工诊断（观察类操作，不属于测试执行）
 *
 * 输出文件：
 *   result.json  → --out 指定；未指定时写 plan.json 同目录
 *   ai-contexts  → --ctx-dir（默认 /tmp/cwork-web-test-ctx），文件名 s{场景}_i{步骤}.json
 *   失败截图     → result.json 同目录 screenshots/fail-s{场景}-i{步骤}.png
 *
 * plan.json 结构（唯一 schema，顶层 scenarios 扁平数组；不识别 uiTests/apiTests/e2eTests）：
 * {
 *   "baseUrl": "http://localhost:3000",
 *   "taskSpaceName": "cwork-test-xxx",
 *   "totalBudgetMs": 600000,
 *   "scenarios": [{
 *     "name": "订单列表",
 *     "priority": "P0",
 *     "steps": [
 *       {"action": "navigate", "url": "/orders"},
 *       {"action": "waitForNetworkIdle"},
 *       {"action": "assertVisible", "selector": ".order-list", "desc": "订单列表可见"},
 *       {"action": "assertText", "selector": ".title", "expectContains": "订单管理", "desc": "标题正确"},
 *       {"action": "assertCount", "selector": ".order-item", "min": 1, "desc": "至少1条订单"},
 *       {"action": "assertStyle", "selector": ".title", "property": "color", "expect": "rgb(51, 51, 51)"},
 *       {"action": "assertLayout", "selector": ".order-item", "expectGrid": {"columns": 3}},
 *       {"action": "assertApi", "urlPattern": "/api/orders", "expectStatus": 200, "expectBodyCode": 0},
 *       {"action": "assertDataConsistency", "selector": ".order-no", "urlPattern": "/api/orders", "apiField": "orders[0].orderNo"},
 *       {"action": "click", "selector": ".order-item:first-child"},
 *       {"action": "fill", "selector": "input.search", "value": "ORD001"},
 *       {"action": "aiAssert", "prompt": "检查订单列表布局是否美观", "capture": ["screenshot", "dom"]},
 *       {"action": "responsive", "viewport": {"width": 375, "height": 812}, "steps": [...]}
 *     ]
 *   }]
 * }
 */

'use strict';

const fs = require('fs');
const path = require('path');
const { execSync, spawn } = require('child_process');

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// selector 字面量嵌入 js(`...`) 嵌套模板字符串：JSON.stringify 产出的 \" 会在模板字符串层被二次解义吃掉，
// 导致浏览器侧表达式语法崩（例 a[href*="x"] → querySelector("a[href*="x"]")），需再转义一层
function tmplSel(selector) {
  return JSON.stringify(selector).replace(/\\/g, '\\\\').replace(/`/g, '\\`').replace(/\$\{/g, '\\${');
}

// ── ego-browser 定位 ──
function findEgoBrowser() {
  try {
    const which = execSync('command -v ego-browser', { encoding: 'utf8' }).trim();
    if (which) return which;
  } catch (_) {}
  const candidates = [
    path.join(require('os').homedir(), '.local/bin/ego-browser'),
    '/usr/local/bin/ego-browser',
  ];
  for (const c of candidates) {
    if (fs.existsSync(c)) return c;
  }
  return null;
}

// 浏览器端元素定位辅助函数（支持 fallback 策略）
const ELEMENT_LOCATOR_JS = `
  window.__locateElement = function(selector, fallback) {
    // 1. 先尝试主选择器
    let el = document.querySelector(selector);
    if (el) return el;

    // 2. 失败 → 尝试 fallback 策略
    if (fallback) {
      // 文本匹配
      if (fallback.text) {
        const all = Array.from(document.querySelectorAll('*'));
        el = all.find(e => e.textContent.trim() === fallback.text && (e.tagName === 'BUTTON' || e.tagName === 'A' || e.onclick));
        if (el) return el;
      }
      // 属性包含
      if (fallback.classContains) {
        el = Array.from(document.querySelectorAll('*')).find(e => e.className && e.className.includes(fallback.classContains));
        if (el) return el;
      }
      // 容器内查找
      if (fallback.containerAndIndex) {
        const container = document.querySelector(fallback.containerAndIndex.container);
        if (container) {
          const candidates = container.querySelectorAll(fallback.containerAndIndex.tag || 'button');
          if (candidates[fallback.containerAndIndex.index]) return candidates[fallback.containerAndIndex.index];
        }
      }
    }
    return null;
  };
`;

// 浏览器端 fetch/XHR 拦截器（注入页面，捕获接口响应到 window.__capturedResponses；测试与 --snapshot 共用）
const INTERCEPTOR_JS = `(() => {
  window.__capturedResponses = [];
  const origFetch = window.fetch;
  window.fetch = async function(...args) {
    const resp = await origFetch.apply(this, args);
    const clone = resp.clone();
    clone.text().then(text => {
      let __body = null;
      try { __body = JSON.parse(text); } catch(e) { __body = null; }
      window.__capturedResponses.push({
        url: typeof args[0] === 'string' ? args[0] : args[0].url,
        method: (args[1] && args[1].method) || 'GET',
        status: resp.status,
        body: __body,
        reqBody: (args[1] && typeof args[1].body === 'string') ? args[1].body : null
      });
    }).catch(() => {});
    return resp;
  };
  const origXHR = XMLHttpRequest.prototype.open;
  const origSend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function(method, url) {
    this.__method = method; this.__url = url;
    return origXHR.apply(this, arguments);
  };
  XMLHttpRequest.prototype.send = function() {
    const __reqBody = (typeof arguments[0] === 'string') ? arguments[0] : null;
    this.addEventListener('load', function() {
      let __body = null;
      try { __body = JSON.parse(this.responseText); } catch(e) { __body = null; }
      window.__capturedResponses.push({
        url: this.__url, method: this.__method,
        status: this.status, body: __body, reqBody: __reqBody
      });
    });
    return origSend.apply(this, arguments);
  };
})()`;

// ── heredoc 代码生成 ──

function generateHeredoc(plan, mode, ctxDir, keep = false, resultPath = null) {
  const lines = [];
  const L = (s) => lines.push(s);

  const baseUrl = plan.baseUrl || 'http://localhost:3000';
  const taskName = plan.taskSpaceName || plan.taskName || 'cwork-test';
  const collectMode = mode === 'collect';
  const rp = resultPath || path.resolve(process.cwd(), 'result.json');

  // 基础设施（ESM import：ego nodejs 运行时存在顶层 await，require 混用会报模块格式歧义）
  L(`'use strict';`);
  L(`import fs from 'node:fs';`);
  L(`import path from 'node:path';`);
  L(``);
  L(`const CTX_DIR = ${JSON.stringify(ctxDir)};`);
  L(`const MODE = ${JSON.stringify(mode)};`);
  L(`const RESULT_PATH = ${JSON.stringify(rp)};`);
  L(`const RESULT_DIR = path.dirname(RESULT_PATH);`);
  L(`const SHOT_DIR = path.join(RESULT_DIR, 'screenshots');`);
  L(`fs.mkdirSync(CTX_DIR, { recursive: true });`);
  L(`fs.mkdirSync(SHOT_DIR, { recursive: true });`);
  L(``);

  // 接口拦截（在浏览器里注入 fetch/XHR 拦截；拦截器代码常量 INTERCEPTOR_JS 与 --snapshot 模式共用）
  L(`// ── 接口响应拦截 ──`);
  L(`const __capturedResponses = [];`);
  L(`const __interceptorCode = ${JSON.stringify(INTERCEPTOR_JS)};`);
  L(`const __locatorCode = ${JSON.stringify(ELEMENT_LOCATOR_JS)};`);
  L(``);

  // 辅助函数
  L(`// ── 辅助函数 ──`);
  L(`let __stepIdx = 0;`);
  L(`let __scenarioIdx = 0;`);
  L(`const __results = [];`);
  L(`let __currentScenario = null;`);
  L(``);
  L(`function log(msg) { cliLog(msg); }`);
  L(``);
  L(`function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }`);
  L(``);

  // 获取拦截的接口响应
  L(`async function getCapturedResponses() {`);
  L(`  const raw = await js('JSON.stringify(window.__capturedResponses || [])');`);
  L(`  return JSON.parse(raw);`);
  L(`}`);
  L(``);
  // 取最新一条匹配响应——同一接口可能被多次调用，取旧的会断言到过期数据
  L(`function findResponse(urlPattern) {`);
  L(`  for (let __i = __lastResponses.length - 1; __i >= 0; __i--) {`);
  L(`    const __r = __lastResponses[__i];`);
  L(`    if (__r.url && __r.url.includes(urlPattern)) return __r;`);
  L(`  }`);
  L(`  return null;`);
  L(`}`);
  L(``);
  L(`let __lastResponses = [];`);
  L(`async function refreshResponses() {`);
  L(`  __lastResponses = await getCapturedResponses();`);
  L(`}`);
  L(``);

  // 结果落盘（汇总与看门狗共用：中断时已执行场景的结果不丢）
  L(`function __flushResults(extra) {`);
  L(`  const __summary = Object.assign({`);
  L(`    scenarios: __results,`);
  L(`    passed: __results.filter(r => r.ok).length,`);
  L(`    failed: __results.filter(r => !r.ok).length,`);
  L(`    total: __results.length,`);
  L(`    finishedAt: new Date().toISOString()`);
  L(`  }, extra || {});`);
  L(`  fs.mkdirSync(RESULT_DIR, { recursive: true });`);
  L(`  fs.writeFileSync(RESULT_PATH, JSON.stringify(__summary, null, 2));`);
  L(`  return __summary;`);
  L(`}`);
  L(``);

  // 任务空间 + 打开页面 + 注入拦截器
  L(`// ── 初始化 ──`);
  L(`const task = await useOrCreateTaskSpace(${JSON.stringify(taskName)});`);
  L(`await openOrReuseTab(${JSON.stringify(baseUrl)}, { wait: true, timeout: 20 });`);
  L(`log('✓ 浏览器已打开: ' + ${JSON.stringify(baseUrl)});`);
  // 拦截器必须在任务空间选定后注入：CDP 注册保证 SPA 后续 navigate 后自动重装，js() 立即注入覆盖首屏
  L(`await cdp('Page.addScriptToEvaluateOnNewDocument', { source: __interceptorCode });`);
  L(`await js(__interceptorCode);`);
  // 注入元素定位辅助函数（支持 fallback 策略）
  L(`await cdp('Page.addScriptToEvaluateOnNewDocument', { source: __locatorCode });`);
  L(`await js(__locatorCode);`);
  L(``);

  // 全局看门狗（到点先落盘部分结果再退出，超时不再丢已执行场景的证据）
  const budgetMs = plan.totalBudgetMs || 10 * 60 * 1000;
  L(`const __budgetTimer = setTimeout(() => {`);
  L(`  log('❌ 全局看门狗触发（${budgetMs}ms 预算耗尽）');`);
  L(`  try {`);
  L(`    const __partial = __flushResults({ watchdog: true });`);
  L(`    log('  部分结果已落盘: ' + RESULT_PATH + '（通过 ' + __partial.passed + ' / 失败 ' + __partial.failed + ' / 共 ' + __partial.total + '）');`);
  L(`  } catch (e) {`);
  L(`    log('  部分结果落盘失败: ' + e.message);`);
  L(`  }`);
  L(`  process.exit(2);`);
  L(`}, ${budgetMs});`);
  L(`__budgetTimer.unref();`);
  L(``);

  // 生成各场景代码
  const scenarios = plan.scenarios || [];
  for (let si = 0; si < scenarios.length; si++) {
    const sc = scenarios[si];
    L(`// ══════ 场景 ${si + 1}: ${sc.name} ══════`);
    L(`__scene_${si}: {`);
    L(`__scenarioIdx = ${si};`);
    L(`__currentScenario = ${JSON.stringify(sc.name)};`);
    L(`log('');`);
    L(`log('【场景】' + __currentScenario + '（${sc.priority || 'P1'}）');`);
    L(`const __result_${si} = { name: __currentScenario, priority: ${JSON.stringify(sc.priority || 'P1')}, steps: [], ok: true };`);
    L(`__results.push(__result_${si});`);
    L(``);

    const steps = sc.steps || [];
    for (let i = 0; i < steps.length; i++) {
      const step = steps[i];
      const stepLabel = `场景${si + 1} 步骤${i + 1}`;
      L(`try {`);
      L(`  __stepIdx = ${i};`);
      generateStepCode(L, step, stepLabel, collectMode, si, i, baseUrl);
      L(`  __result_${si}.steps.push({ action: ${JSON.stringify(step.action)}, ok: true, desc: ${JSON.stringify(step.desc || step.action)} });`);
      L(`  log('  ✓ ' + ${JSON.stringify(step.desc || step.action)});`);
      L(`} catch (err) {`);
      L(`  __result_${si}.steps.push({ action: ${JSON.stringify(step.action)}, ok: false, desc: ${JSON.stringify(step.desc || step.action)}, error: err.message });`);
      L(`  log('  ✗ ' + ${JSON.stringify(step.desc || step.action)} + ': ' + err.message);`);
      L(`  __result_${si}.ok = false;`);
      if (collectMode) {
        L(`  // collect 模式：失败也继续（尽量多收集上下文）`);
      } else {
        L(`  // run 模式：首败即停`);
        // 失败截图归档到 result.json 同目录 screenshots/（ego 临时目录被清理后仍可回溯证据）
        L(`  try {`);
        L(`    const __failShot = await captureScreenshot();`);
        L(`    if (__failShot && fs.existsSync(__failShot)) {`);
        L(`      const __shotPath = path.join(SHOT_DIR, 'fail-s' + __scenarioIdx + '-i' + __stepIdx + '.png');`);
        L(`      fs.copyFileSync(__failShot, __shotPath);`);
        L(`      __result_${si}.screenshot = __shotPath;`);
        L(`      log('  失败截图: ' + __shotPath);`);
        L(`    } else {`);
        L(`      __result_${si}.screenshot = __failShot;`);
        L(`      log('  失败截图: ' + __failShot);`);
        L(`    }`);
        // 失败瞬间语义快照摘录（选择器为什么没命中/页面实际长什么样，免得诊断时再跑一轮观察）
        L(`    try {`);
        L(`      __result_${si}.failSnapshot = String(await snapshotText() || '').slice(0, 3000);`);
        L(`    } catch (_) {}`);
        L(`  } catch(e) {}`);
        L(`  break __scene_${si};`);
      }
      L(`}`);
      L(``);
    }

    L(`log('  场景结果: ' + (__result_${si}.ok ? '✓ 通过' : '✗ 失败'));`);
    L(`}`);
    L(``);
  }

  // 输出结果
  L(`// ── 汇总 ──`);
  L(`const __summary = __flushResults();`);
  if (keep) {
    L(`await handOffTaskSpace(task.id);`);
    L(`log('✓ 任务空间已移交浏览器保持登录态（人工核验用）');`);
  } else {
    L(`await completeTaskSpace(task.id, { keep: false });`);
  }
  L(``);
  L(`log('');`);
  L(`log('结果已写入: ' + RESULT_PATH);`);
  L(`log('═══ 结果: 通过 ' + __summary.passed + ' / 失败 ' + __summary.failed + ' (共 ' + __summary.total + ' 场景) ═══');`);
  L(`log('RESULT_JSON=' + JSON.stringify(__summary));`);

  const code = lines.join('\n');
  return code;
}

// 生成单个步骤的执行代码
function generateStepCode(L, step, label, collectMode, si, i, baseUrl) {
  const action = step.action || step.type;

  switch (action) {
    case 'navigate': {
      // 相对路径按 baseUrl 解析，绝对 URL 原样使用
      const navUrl = /^https?:\/\//i.test(step.url || '') ? step.url : (baseUrl || '') + (step.url || '');
      L(`  await gotoAndWait(${JSON.stringify(navUrl)});`);
      L(`  await waitForLoad();`);
      L(`  await refreshResponses();`);
      break;
    }

    case 'waitForNetworkIdle':
      L(`  await waitForNetworkIdle();`);
      L(`  await refreshResponses();`);
      break;

    case 'waitForLoad':
    case 'waitForNavigation':
      L(`  await waitForLoad();`);
      break;

    case 'waitForElement': {
      // 等待元素出现再采集——根治动态渲染导致的选择器乱跑
      // 超时后标记 BLOCKED 继续后续步骤，不报错（避免一个元素卡死整个场景）
      const timeout = Number(step.timeout || 10) * 1000;
      L(`  {`);
      L(`    const __timeout = ${timeout};`);
      L(`    const __start = Date.now();`);
      L(`    let __found = false;`);
      L(`    while (Date.now() - __start < __timeout) {`);
      L(`      const __el = await js(\`(() => { return !!window.__locateElement(${tmplSel(step.selector)}, ${JSON.stringify(step.fallback || null)}); })()\`);`);
      L(`      if (__el === 'true' || __el === true) { __found = true; break; }`);
      L(`      await sleep(200);`);
      L(`    }`);
      L(`    if (!__found) {`);
      L(`      log('  ⚠ waitForElement 超时（${step.timeout || 10}s）: ' + ${JSON.stringify(step.selector)} + ' → 标记 BLOCKED 继续后续步骤');`);
      L(`    }`);
      L(`  }`);
      break;
    }

    case 'clickCdp':
      // CDP 真实鼠标事件（mousedown/focus/click 全链），用于依赖 focus 打开的组件如 el-date-picker 面板
      // 坐标求值走 cdp('Runtime.evaluate') returnByValue，绕开 js() 对复杂表达式返回 null 的坑
      // step.index 支持 querySelectorAll 按索引取元素（默认 0）
      L(`  {`);
      L(`    const __expr = "(function(){ var el = document.querySelectorAll(" + ${JSON.stringify(JSON.stringify(step.selector))} + ")[" + ${step.index || 0} + "]; if (!el) return 'null'; var r = el.getBoundingClientRect(); return JSON.stringify({ x: Math.round(r.x + r.width / 2), y: Math.round(r.y + r.height / 2) }); })()";`);
      L(`    const __ev = await cdp('Runtime.evaluate', { expression: __expr, returnByValue: true });`);
      L(`    const __raw = (__ev && __ev.result && typeof __ev.result.value !== 'undefined') ? __ev.result.value : null;`);
      L(`    let __pos = null;`);
      L(`    if (typeof __raw === 'string') { try { __pos = JSON.parse(__raw); } catch (e) { __pos = null; } }`);
      L(`    else if (typeof __raw === 'object' && __raw !== null) { __pos = __raw; }`);
      L(`    if (!__pos || typeof __pos.x !== 'number' || typeof __pos.y !== 'number') throw new Error('无法获取元素坐标: ${step.selector.replace(/'/g, "\\'")} idx=${step.index || 0} raw=' + JSON.stringify(__ev));`);
      L(`    await cdp('Input.dispatchMouseEvent', { type: 'mousePressed', x: __pos.x, y: __pos.y, button: 'left', clickCount: 1 });`);
      L(`    await sleep(80);`);
      L(`    await cdp('Input.dispatchMouseEvent', { type: 'mouseReleased', x: __pos.x, y: __pos.y, button: 'left', clickCount: 1 });`);
      L(`  }`);
      L(`  await sleep(600);`);
      L(`  await refreshResponses();`);
      break;

    case 'openDatePicker':
      // JS 合成事件通道打开 el-date-picker 面板：对输入框派发 mousedown/focus/mouseup/click 事件序列
      // step.index 支持 querySelectorAll 按索引取元素（默认 0）
      L(`  {`);
      L(`    const __expr = "(function(){ var el = document.querySelectorAll(" + ${JSON.stringify(JSON.stringify(step.selector))} + ")[" + ${step.index || 0} + "]; if (!el) return JSON.stringify({ok:false, err:'el null'}); el.dispatchEvent(new MouseEvent('mousedown', {bubbles:true, cancelable:true})); el.dispatchEvent(new FocusEvent('focus')); el.dispatchEvent(new MouseEvent('mouseup', {bubbles:true, cancelable:true})); el.dispatchEvent(new MouseEvent('click', {bubbles:true, cancelable:true})); var n = document.querySelectorAll('.el-picker-panel,.el-date-picker,.el-date-range-picker').length; return JSON.stringify({ok:true, panel:n}); })()";`);
      L(`    const __ev = await cdp('Runtime.evaluate', { expression: __expr, returnByValue: true });`);
      L(`    const __raw = (__ev && __ev.result && typeof __ev.result.value !== 'undefined') ? __ev.result.value : null;`);
      L(`    let __r = null; if (typeof __raw === 'string') { try { __r = JSON.parse(__raw); } catch (e) {} }`);
      L(`    if (!__r || !__r.ok) throw new Error('openDatePicker 失败: ' + JSON.stringify(__ev));`);
      L(`    cliLog('openDatePicker[dbg] ' + JSON.stringify(__r));`);
      L(`  }`);
      L(`  await sleep(800);`);
      L(`  await refreshResponses();`);
      break;

    case 'dispatchClick':
      // JS 合成 click 事件通道：用于被悬浮横幅遮挡、常规坐标点击无法命中的按钮
      // （如 OMP 异常订单页 top-tip 横幅盖住筛选按钮整行，且主滚动在内部容器无法滚开）
      // step.index 支持 querySelectorAll 按索引取元素（默认 0）
      L(`  {`);
      L(`    const __expr = "(function(){ var el = document.querySelectorAll(" + ${JSON.stringify(JSON.stringify(step.selector))} + ")[" + ${step.index || 0} + "]; if (!el) return JSON.stringify({ok:false, err:'el null'}); el.scrollIntoView({block:'center'}); el.dispatchEvent(new MouseEvent('click', {bubbles: true, cancelable: true})); return JSON.stringify({ok:true}); })()";`);
      L(`    const __ev = await cdp('Runtime.evaluate', { expression: __expr, returnByValue: true });`);
      L(`    const __raw = (__ev && __ev.result && typeof __ev.result.value !== 'undefined') ? __ev.result.value : null;`);
      L(`    let __r = null; if (typeof __raw === 'string') { try { __r = JSON.parse(__raw); } catch (e) {} }`);
      L(`    if (!__r || !__r.ok) throw new Error('dispatchClick 失败: ' + JSON.stringify(__ev));`);
      L(`  }`);
      L(`  await sleep(500);`);
      L(`  await refreshResponses();`);
      break;

    case 'click':
      // 支持 fallback 策略：主选择器失败时自动尝试备选定位策略
      if (step.fallback) {
        L(`  {`);
        L(`    const __el = await js(\`(() => { const el = window.__locateElement(${tmplSel(step.selector)}, ${JSON.stringify(step.fallback)}); return el ? 'found' : 'not-found'; })()\`);`);
        L(`    if (__el === 'not-found') throw new Error('元素未找到: ' + ${JSON.stringify(step.selector)} + '（含 fallback）');`);
        L(`    await click(${JSON.stringify(step.selector)}, { label: ${JSON.stringify(step.desc || '点击')} });`);
        L(`  }`);
      } else {
        L(`  await click(${JSON.stringify(step.selector)}, { label: ${JSON.stringify(step.desc || '点击')} });`);
      }
      L(`  await sleep(500);`);
      L(`  await refreshResponses();`);
      break;

    case 'fill':
      // 支持 fallback 策略：主选择器失败时自动尝试备选定位策略
      if (step.fallback) {
        L(`  {`);
        L(`    const __el = await js(\`(() => { const el = window.__locateElement(${tmplSel(step.selector)}, ${JSON.stringify(step.fallback)}); return el ? 'found' : 'not-found'; })()\`);`);
        L(`    if (__el === 'not-found') throw new Error('元素未找到: ' + ${JSON.stringify(step.selector)} + '（含 fallback）');`);
        L(`    await fillInput(${JSON.stringify(step.selector)}, ${JSON.stringify(step.value)});`);
        L(`  }`);
      } else {
        L(`  await fillInput(${JSON.stringify(step.selector)}, ${JSON.stringify(step.value)});`);
      }
      L(`  await sleep(200);`);
      L(`  await refreshResponses();`);
      break;

    case 'assertVisible':
      // 真实可见性：存在且占位（宽高>0）且未被 display:none/visibility:hidden 隐藏，而非仅判存在
      // 支持 fallback 策略：主选择器失败时自动尝试备选定位策略
      L(`  {`);
      if (step.fallback) {
        L(`    const __vis = await js(\`(() => { const el = window.__locateElement(${tmplSel(step.selector)}, ${JSON.stringify(step.fallback)}); if (!el) return 'missing'; const r = el.getBoundingClientRect(); if (r.width <= 0 || r.height <= 0) return 'zero-size'; const s = getComputedStyle(el); if (s.display === 'none' || s.visibility === 'hidden') return 'css-hidden'; return 'visible'; })()\`);`);
      } else {
        L(`    const __vis = await js(\`(() => { const el = document.querySelector(${tmplSel(step.selector)}); if (!el) return 'missing'; const r = el.getBoundingClientRect(); if (r.width <= 0 || r.height <= 0) return 'zero-size'; const s = getComputedStyle(el); if (s.display === 'none' || s.visibility === 'hidden') return 'css-hidden'; return 'visible'; })()\`);`);
      }
      L(`    if (__vis !== 'visible') throw new Error(${JSON.stringify(step.desc || '元素不可见')} + ': ' + ${JSON.stringify(step.selector)} + ' (状态: ' + __vis + ')');`);
      L(`  }`);
      break;

    case 'assertText':
      L(`  {`);
      L(`    const __text = await js(\`(document.querySelector(${tmplSel(step.selector)}) || {}).textContent\`) || '';`);
      if (step.expectContains) {
        L(`    if (!__text.includes(${JSON.stringify(step.expectContains)})) throw new Error(${JSON.stringify(step.desc || '文本不匹配')} + ': "' + __text.trim() + '" 不包含 "' + ${JSON.stringify(step.expectContains)} + '"');`);
      } else {
        L(`    const __trimmed = __text.trim();`);
        L(`    if (__trimmed !== ${JSON.stringify(step.expect)}) throw new Error(${JSON.stringify(step.desc || '文本不匹配')} + ': 期望 "' + ${JSON.stringify(step.expect)} + '", 实际 "' + __trimmed + '"');`);
      }
      L(`  }`);
      break;

    case 'assertCount': {
      if (step.expect === undefined && step.min === undefined && step.max === undefined) {
        throw new Error('assertCount 缺少断言条件（expect/min/max 至少其一）: ' + JSON.stringify(step.desc || step.selector));
      }
      L(`  {`);
      L(`    const __count = await js(\`document.querySelectorAll(${tmplSel(step.selector)}).length\`);`);
      if (step.expect !== undefined) {
        // 数字字段 Node 侧强转：AI 生成 plan 可能产出字符串 "3"，直接插值会与数字做严格比较恒 false
        L(`    if (__count !== ${Number(step.expect)}) throw new Error(${JSON.stringify(step.desc || '数量不匹配')} + ': 期望 ' + ${Number(step.expect)} + ', 实际 ' + __count);`);
      }
      if (step.min !== undefined) {
        L(`    if (__count < ${Number(step.min)}) throw new Error(${JSON.stringify(step.desc || '数量不足')} + ': 最少 ' + ${Number(step.min)} + ', 实际 ' + __count);`);
      }
      if (step.max !== undefined) {
        L(`    if (__count > ${Number(step.max)}) throw new Error(${JSON.stringify(step.desc || '数量超限')} + ': 最多 ' + ${Number(step.max)} + ', 实际 ' + __count);`);
      }
      L(`  }`);
      break;
    }

    case 'assertStyle': {
      // CSS 属性名走 bracket 访问：连字符属性（background-color）点号访问会生成 `el.background-color`
      // 被浏览器解析为减法表达式直接 ReferenceError
      const prop = step.property;
      L(`  {`);
      L(`    const __style = await js(\`getComputedStyle(document.querySelector(${tmplSel(step.selector)}))[${JSON.stringify(prop)}]\`);`);
      if (step.expectPattern) {
        L(`    if (!new RegExp(${JSON.stringify(step.expectPattern)}).test(__style)) throw new Error(${JSON.stringify(step.desc || '样式不匹配')} + ': ' + __style + ' 不匹配 /' + ${JSON.stringify(step.expectPattern)} + '/');`);
      } else {
        L(`    if (__style !== ${JSON.stringify(step.expect)}) throw new Error(${JSON.stringify(step.desc || '样式不匹配')} + ': 期望 "' + ${JSON.stringify(step.expect)} + '", 实际 "' + __style + '"');`);
      }
      L(`  }`);
      break;
    }

    case 'assertLayout':
      L(`  {`);
      // 布局坐标求值走 cdp Runtime.evaluate returnByValue：js() 对复杂 JSON 表达式返回 null（clickCdp 已踩过的坑），
      // JSON.parse(null) 得 null 再展开会报 "__boxes is not iterable" 这种不知所云的错误
      L(`    const __expr = "(function(){ var els = document.querySelectorAll(" + ${JSON.stringify(JSON.stringify(step.selector))} + "); var arr = []; for (var i = 0; i < els.length; i++) { var r = els[i].getBoundingClientRect(); arr.push({ x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height) }); } return JSON.stringify(arr); })()";`);
      L(`    const __ev = await cdp('Runtime.evaluate', { expression: __expr, returnByValue: true });`);
      L(`    const __raw = (__ev && __ev.result && typeof __ev.result.value !== 'undefined') ? __ev.result.value : null;`);
      L(`    let __boxes = null; if (typeof __raw === 'string') { try { __boxes = JSON.parse(__raw); } catch (e) {} }`);
      L(`    if (!Array.isArray(__boxes)) throw new Error('无法读取元素布局: ' + JSON.stringify(__ev));`);
      if (step.expectAlign === 'center') {
        L(`    if (__boxes.length > 0) {`);
        L(`      const __parent = await js(\`(() => { const p = document.querySelector(${tmplSel(step.selector)}).parentElement; const r = p.getBoundingClientRect(); return JSON.stringify({x: Math.round(r.x), w: Math.round(r.width)}); })()\`);`);
        L(`      const __pr = JSON.parse(__parent);`);
        L(`      const __parentCenter = __pr.x + __pr.w / 2;`);
        L(`      const __elemCenter = __boxes[0].x + __boxes[0].w / 2;`);
        L(`      if (Math.abs(__parentCenter - __elemCenter) > 10) throw new Error(${JSON.stringify(step.desc || '未居中')} + ': 偏差 ' + Math.abs(__parentCenter - __elemCenter) + 'px');`);
        L(`    }`);
      }
      if (step.expectGrid) {
        L(`    {`);
        L(`      const __rows = [];`);
        L(`      let __curRow = [];`);
        L(`      for (const __b of __boxes) {`);
        L(`        if (__curRow.length > 0 && Math.abs(__b.y - __curRow[0].y) > 20) { __rows.push(__curRow); __curRow = []; }`);
        L(`        __curRow.push(__b);`);
        L(`      }`);
        L(`      if (__curRow.length > 0) __rows.push(__curRow);`);
        L(`      const __cols = __rows[0] ? __rows[0].length : 0;`);
        L(`      if (__cols !== ${Number(step.expectGrid.columns)}) throw new Error(${JSON.stringify(step.desc || '网格列数不匹配')} + ': 期望 ' + ${Number(step.expectGrid.columns)} + ' 列, 实际 ' + __cols + ' 列');`);
        L(`    }`);
      }
      L(`  }`);
      break;

    case 'assertApi':
      L(`  {`);
      L(`    await refreshResponses();`);
      L(`    const __resp = findResponse(${JSON.stringify(step.urlPattern)});`);
      L(`    if (!__resp) throw new Error(${JSON.stringify(step.desc || '接口未调用')} + ': ' + ${JSON.stringify(step.urlPattern)});`);
      if (step.expectStatus !== undefined) {
        L(`    if (__resp.status !== ${Number(step.expectStatus)}) throw new Error(${JSON.stringify(step.desc || '接口状态码错误')} + ': 期望 ' + ${Number(step.expectStatus)} + ', 实际 ' + __resp.status);`);
      }
      if (step.expectBodyCode !== undefined) {
        L(`    if (__resp.body && __resp.body.code !== ${Number(step.expectBodyCode)}) throw new Error(${JSON.stringify(step.desc || '业务码错误')} + ': 期望 ' + ${Number(step.expectBodyCode)} + ', 实际 ' + __resp.body.code);`);
      }
      L(`  }`);
      break;

    case 'assertDataConsistency': {
      if (!step.urlPattern || !step.apiField) {
        throw new Error('assertDataConsistency 需要 urlPattern + apiField: ' + JSON.stringify(step.desc || step.selector));
      }
      L(`  {`);
      // 页面值求值走 cdp Runtime.evaluate returnByValue：js() 对复杂 JSON 表达式返回 null（同 assertLayout 坑）
      L(`    const __expr = "(function(){ var els = document.querySelectorAll(" + ${JSON.stringify(JSON.stringify(step.selector))} + "); var arr = []; for (var i = 0; i < els.length; i++) { arr.push(String(els[i].textContent || '').trim()); } return JSON.stringify(arr); })()";`);
      L(`    const __ev = await cdp('Runtime.evaluate', { expression: __expr, returnByValue: true });`);
      L(`    const __raw = (__ev && __ev.result && typeof __ev.result.value !== 'undefined') ? __ev.result.value : null;`);
      L(`    let __vals = null; if (typeof __raw === 'string') { try { __vals = JSON.parse(__raw); } catch (e) {} }`);
      L(`    if (!Array.isArray(__vals)) throw new Error('无法读取页面元素值: ' + JSON.stringify(__ev));`);
      L(`    await refreshResponses();`);
      L(`    const __apiResp = findResponse(${JSON.stringify(step.urlPattern)});`);
      L(`    if (!__apiResp) throw new Error(${JSON.stringify(step.desc || '数据一致性')} + ': 接口未捕获 ' + ${JSON.stringify(step.urlPattern)});`);
      // 解析 apiField 路径，支持 orders[0].orderNo 语法
      L(`    const __path = ${JSON.stringify(step.apiField)};`);
      L(`    const __parts = __path.replace(/\\[(\\d+)\\]/g, '.$1').split('.');`);
      L(`    let __v = __apiResp.body;`);
      L(`    for (const __p of __parts) { if (__v == null) break; __v = __v[__p]; }`);
      L(`    if (__v == null) throw new Error(${JSON.stringify(step.desc || '数据一致性')} + ': 接口字段 ' + ${JSON.stringify(step.apiField)} + ' 不存在');`);
      L(`    if (!__vals.length) throw new Error(${JSON.stringify(step.desc || '数据一致性')} + ': 页面无匹配元素 ' + ${JSON.stringify(step.selector)});`);
      L(`    const __apiValues = Array.isArray(__v) ? __v.map(String) : [String(__v)];`);
      L(`    for (let __i = 0; __i < Math.min(__vals.length, __apiValues.length); __i++) {`);
      L(`      if (__vals[__i] !== String(__apiValues[__i])) throw new Error(${JSON.stringify(step.desc || '数据不一致')} + ': 页面["' + __vals[__i] + '"] vs 接口["' + __apiValues[__i] + '"]');`);
      L(`    }`);
      L(`  }`);
      break;
    }

    case 'exportApi': {
      // 导出完整 API 响应到文件（供 Doris vs ES 数据比对等场景）
      // 支持单接口（urlPattern 字符串）或多接口批量导出（urlPatterns 数组）
      if (!step.filename) {
        throw new Error('exportApi 需要 filename: ' + JSON.stringify(step.desc || step.action));
      }
      const patterns = step.urlPatterns || (step.urlPattern ? [step.urlPattern] : []);
      if (patterns.length === 0) {
        throw new Error('exportApi 需要 urlPattern 或 urlPatterns: ' + JSON.stringify(step.desc || step.action));
      }
      L(`  {`);
      L(`    await refreshResponses();`);
      L(`    const __patterns = ${JSON.stringify(patterns)};`);
      L(`    const __exported = [];`);
      L(`    for (const __p of __patterns) {`);
      L(`      const __resp = findResponse(__p);`);
      L(`      if (__resp) {`);
      L(`        __exported.push({ urlPattern: __p, response: __resp });`);
      L(`      } else {`);
      L(`        log('  ⚠ exportApi: 未捕获接口 ' + __p);`);
      L(`      }`);
      L(`    }`);
      L(`    if (__exported.length === 0) {`);
      L(`      throw new Error(${JSON.stringify(step.desc || 'exportApi')} + ': 未捕获任何接口响应');`);
      L(`    }`);
      L(`    const __outFile = path.join(RESULT_DIR, ${JSON.stringify(step.filename)});`);
      L(`    fs.writeFileSync(__outFile, JSON.stringify(__exported.length === 1 ? __exported[0].response : __exported, null, 2));`);
      L(`    log('  ✓ exportApi: 导出 ' + __exported.length + ' 个接口响应到 ' + __outFile);`);
      L(`  }`);
      break;
    }

    case 'aiAssert': {
      const captures = step.capture || ['screenshot'];
      L(`  {`);
      L(`    const __aiId = 's' + __scenarioIdx + '_i' + __stepIdx;`);
      L(`    const __ctxFile = path.join(CTX_DIR, __aiId + '.json');`);
      L(`    const __resultFile = path.join(CTX_DIR, __aiId + '.result.json');`);
      L(`    const __ctx = { id: __aiId, desc: ${JSON.stringify(step.desc || 'AI断言')}, prompt: ${JSON.stringify(step.prompt)} };`);

      // 截图
      if (captures.includes('screenshot')) {
        L(`    try { __ctx.screenshot = await captureScreenshot(); } catch(e) { __ctx.screenshotError = e.message; }`);
      }
      // DOM 快照
      if (captures.includes('dom')) {
        L(`    try { __ctx.dom = await snapshotText(); } catch(e) { __ctx.domError = e.message; }`);
      }
      // 接口响应
      if (captures.includes('apiResponses')) {
        L(`    __ctx.apiResponses = __lastResponses;`);
      }
      // 页面信息
      L(`    try { __ctx.pageInfo = await pageInfo(); } catch(e) {}`);

      L(`    fs.writeFileSync(__ctxFile, JSON.stringify(__ctx, null, 2));`);

      if (collectMode) {
        // collect 模式：只收集上下文，不判断
        L(`    log('  [AI_ASSERT] 上下文已收集: ' + __ctxFile);`);
        L(`    log('AI_ASSERT_COLLECTED:' + __ctxFile);`);
      } else {
        // run 模式：读取 AI 预判断结果；缺失 = 该步失败（静默跳过会让 AI 断言形同虚设）
        L(`    if (!fs.existsSync(__resultFile)) throw new Error('AI断言结果缺失: ' + __resultFile + '（collect 后必须由 AI 写入判断结果再 --run）');`);
        L(`    const __aiResult = JSON.parse(fs.readFileSync(__resultFile, 'utf8'));`);
        L(`    if (!__aiResult.pass) throw new Error('AI断言失败[' + ${JSON.stringify(step.desc || '')} + ']: ' + __aiResult.reason);`);
        L(`    log('  [AI] ' + ${JSON.stringify(step.desc || 'AI断言')} + ': ✓ ' + (__aiResult.reason || ''));`);
      }

      L(`  }`);
      break;
    }

    case 'responsive': {
      const vp = step.viewport || { width: 375, height: 812 };
      L(`  {`);
      L(`    // 切换视口`);
      L(`    await cdp('Emulation.setDeviceMetricsOverride', { width: ${vp.width}, height: ${vp.height}, deviceScaleFactor: 2, mobile: true });`);
      L(`    await wait(1);`);
      L(`    log('  [响应式] 视口: ${vp.width}x${vp.height}');`);

      // 跑子步骤
      const subSteps = step.steps || [];
      for (let j = 0; j < subSteps.length; j++) {
        const sub = subSteps[j];
        L(`  try {`);
        generateStepCode(L, sub, `${label} responsive.${j}`, collectMode, si, `${i}_r${j}`, baseUrl);
        L(`    log('    ✓ ' + ${JSON.stringify(sub.desc || sub.action)});`);
        L(`  } catch(err) {`);
        L(`    log('    ✗ ' + ${JSON.stringify(sub.desc || sub.action)} + ': ' + err.message);`);
        L(`    throw err;`);
        L(`  }`);
      }

      L(`    // 恢复视口`);
      L(`    await cdp('Emulation.clearDeviceMetricsOverride');`);
      L(`    await wait(0.5);`);
      L(`  }`);
      break;
    }

    default:
      // 未知 action 生成期报错——静默跳过会让 plan 错误伪装成"测试通过"
      throw new Error('未知 action: ' + action + '（step: ' + JSON.stringify(step.desc || step.action) + '）');
  }
}

// ── 执行 heredoc ──

function executeHeredoc(code, egoPath) {
  return new Promise((resolve, reject) => {
    const child = spawn(egoPath, ['nodejs'], {
      stdio: ['pipe', 'pipe', 'pipe'],
    });

    let stdout = '';
    let stderr = '';
    const aiMarkers = [];

    child.stdout.on('data', (chunk) => {
      const text = chunk.toString();
      stdout += text;
      // 实时检测 AI_ASSERT 标记
      const lines = text.split('\n');
      for (const line of lines) {
        if (line.startsWith('AI_ASSERT_COLLECTED:')) {
          aiMarkers.push(line.replace('AI_ASSERT_COLLECTED:', '').trim());
        }
      }
      process.stdout.write(text); // 透传输出
    });

    child.stderr.on('data', (chunk) => {
      stderr += chunk.toString();
      process.stderr.write(chunk); // 透传错误
    });

    child.on('close', (code) => {
      resolve({ code, stdout, stderr, aiMarkers });
    });

    child.on('error', reject);

    // 写入 heredoc 代码
    child.stdin.write(code);
    child.stdin.end();
  });
}

// ── 完整流程（collect → 等 AI → run）──

async function runFullFlow(plan, ctxDir, resultPath, egoPath, keep = false) {
  fs.mkdirSync(ctxDir, { recursive: true });

  // Pass 1: collect（plan 无 aiAssert 时即单遍直通，result.json 已由执行器写入 resultPath）
  console.log('═══ Pass 1: 执行测试并收集 AI 断言上下文 ═══');
  const collectCode = generateHeredoc(plan, 'collect', ctxDir, keep, resultPath);
  const collectResult = await executeHeredoc(collectCode, egoPath);

  if (collectResult.aiMarkers.length === 0) {
    console.log('无 AI 断言，单遍直通完成，结果: ' + resultPath);
    return collectResult.code;
  }

  // 输出 AI 待处理标记
  console.log('');
  console.log('AI_ASSERT_PENDING:' + JSON.stringify({
    contexts: collectResult.aiMarkers,
    ctxDir,
  }));
  console.log('');

  // 等待 AI 结果文件（轮询，最长 5 分钟）
  console.log('等待 AI 判断结果...');
  const deadline = Date.now() + 5 * 60 * 1000;
  for (const ctxFile of collectResult.aiMarkers) {
    const resultFile = ctxFile.replace('.json', '.result.json');
    while (!fs.existsSync(resultFile) && Date.now() < deadline) {
      await sleep(2000);
    }
    if (!fs.existsSync(resultFile)) {
      console.error(`❌ AI 判断超时: ${resultFile}`);
      return 2;
    }
  }

  // Pass 2: run with AI results
  console.log('');
  console.log('═══ Pass 2: 带 AI 结果执行完整测试 ═══');
  const runCode = generateHeredoc(plan, 'run', ctxDir, keep, resultPath);
  const runResult = await executeHeredoc(runCode, egoPath);
  console.log('结果: ' + resultPath);

  return runResult.code;
}

// ── 标准化采集 heredoc（观察类操作：供 AI 写 plan 选择器 / 手工诊断，不属于测试执行）──

function generateSnapshotHeredoc(url, outPath, shotPath) {
  const lines = [];
  const L = (s) => lines.push(s);

  L(`'use strict';`);
  L(`import fs from 'node:fs';`);
  L(`import path from 'node:path';`);
  L(``);
  L(`const OUT = ${JSON.stringify(path.resolve(outPath))};`);
  L(`const SHOT = ${JSON.stringify(shotPath ? path.resolve(shotPath) : null)};`);
  L(`const __interceptorCode = ${JSON.stringify(INTERCEPTOR_JS)};`);
  L(``);
  L(`const task = await useOrCreateTaskSpace('cwork-web-snapshot');`);
  L(`await openOrReuseTab(${JSON.stringify(url)}, { wait: true, timeout: 20 });`);
  L(`await cdp('Page.addScriptToEvaluateOnNewDocument', { source: __interceptorCode });`);
  L(`await js(__interceptorCode);`);
  L(`await waitForLoad();`);
  L(`await waitForNetworkIdle().catch(() => {});`);
  L(`await new Promise(r => setTimeout(r, 1000));`);
  L(``);
  L(`const snap = { url: ${JSON.stringify(url)}, collectedAt: new Date().toISOString() };`);
  L(`try { snap.pageInfo = await pageInfo(); } catch (e) { snap.pageInfoError = e.message; }`);
  L(`try { snap.snapshotText = await snapshotText(); } catch (e) { snap.snapshotError = e.message; }`);
  L(`try { snap.apiResponses = JSON.parse(await js('JSON.stringify(window.__capturedResponses || [])')); } catch (e) {}`);
  L(`try { snap.screenshot = await captureScreenshot(); } catch (e) { snap.screenshotError = e.message; }`);
  L(``);
  L(`fs.mkdirSync(path.dirname(OUT), { recursive: true });`);
  L(`fs.writeFileSync(OUT, JSON.stringify(snap, null, 2));`);
  L(`if (SHOT && snap.screenshot && fs.existsSync(snap.screenshot)) {`);
  L(`  fs.copyFileSync(snap.screenshot, SHOT);`);
  L(`  snap.screenshot = SHOT;`);
  L(`  fs.writeFileSync(OUT, JSON.stringify(snap, null, 2));`);
  L(`}`);
  L(``);
  L(`cliLog('');`);
  L(`cliLog('── 快照采集完成 ──');`);
  L(`cliLog('URL: ' + ${JSON.stringify(url)});`);
  L(`cliLog('标题: ' + ((snap.pageInfo && snap.pageInfo.title) || '(未知)'));`);
  L(`cliLog('接口响应: ' + ((snap.apiResponses && snap.apiResponses.length) || 0) + ' 条');`);
  L(`cliLog('页面快照: ' + (snap.snapshotText ? String(snap.snapshotText).length + ' 字符' : '获取失败(' + (snap.snapshotError || '?') + ')'));`);
  L(`cliLog('截图: ' + (snap.screenshot || '(失败)'));`);
  L(`cliLog('SNAPSHOT_OUT=' + OUT);`);
  L(`await completeTaskSpace(task.id, { keep: false });`);

  return lines.join('\n');
}

// ── main ──

async function main() {
  const args = process.argv.slice(2);
  const planFile = getArg(args, '--plan');
  const ctxDir = getArg(args, '--ctx-dir') || '/tmp/cwork-web-test-ctx';
  const outFile = getArg(args, '--out');
  const collectOnly = args.includes('--collect');
  const runOnly = args.includes('--run');
  const snapshotMode = args.includes('--snapshot');
  const snapshotUrl = getArg(args, '--url');
  const keep = args.includes('--keep');

  const egoPath = findEgoBrowser();
  if (!egoPath) {
    console.error('❌ 未找到 ego-browser，请先安装 ego lite 浏览器');
    process.exit(1);
  }

  // --snapshot：标准化采集（观察类操作，供 AI 写 plan 选择器 / 手工诊断）
  if (snapshotMode) {
    if (!snapshotUrl) {
      console.error('用法: node web-run.cjs --snapshot --url <页面地址> [--out snap.json]');
      process.exit(1);
    }
    const snapOut = outFile || path.join(ctxDir, 'snapshot.json');
    const shotOut = snapOut.replace(/\.json$/i, '.png');
    const code = generateSnapshotHeredoc(snapshotUrl, snapOut, shotOut);
    const result = await executeHeredoc(code, egoPath);
    process.exitCode = result.code;
    return;
  }

  if (!planFile) {
    console.error('用法: node web-run.cjs --plan plan.json [--ctx-dir DIR] [--out result.json] [--collect | --run]');
    console.error('      node web-run.cjs --snapshot --url <页面地址> [--out snap.json]');
    process.exit(1);
  }

  const plan = JSON.parse(fs.readFileSync(planFile, 'utf8'));

  // 0 场景响亮失败——空计划静默"通过"会伪装成测试成功
  if (!Array.isArray(plan.scenarios) || plan.scenarios.length === 0) {
    console.error('❌ plan.json 无 scenarios（或为空数组）——拒绝执行空测试计划');
    process.exit(1);
  }

  // result.json 落点：--out 优先，否则 plan.json 同目录（此前写 ctxDir 父目录，plan 与结果分离难回溯）
  const resultPath = outFile
    ? path.resolve(outFile)
    : path.join(path.dirname(path.resolve(planFile)), 'result.json');

  if (collectOnly) {
    fs.mkdirSync(ctxDir, { recursive: true });
    const code = generateHeredoc(plan, 'collect', ctxDir, keep, resultPath);
    const result = await executeHeredoc(code, egoPath);
    if (result.aiMarkers.length > 0) {
      console.log('AI_ASSERT_PENDING:' + JSON.stringify({ contexts: result.aiMarkers, ctxDir }));
    }
    process.exitCode = result.code;
  } else if (runOnly) {
    fs.mkdirSync(ctxDir, { recursive: true });
    const code = generateHeredoc(plan, 'run', ctxDir, keep, resultPath);
    const result = await executeHeredoc(code, egoPath);
    process.exitCode = result.code;
  } else {
    // 完整流程
    const exitCode = await runFullFlow(plan, ctxDir, resultPath, egoPath, keep);
    process.exitCode = exitCode;
  }
}

function getArg(args, name) {
  const idx = args.indexOf(name);
  return idx >= 0 && idx + 1 < args.length ? args[idx + 1] : null;
}

main().catch((err) => {
  console.error('❌ ' + err.message);
  process.exitCode = 2;
});
