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
 *   node web-run.cjs --collect --plan plan.json --ctx-dir /tmp/ctx
 *     → 跑测试，aiAssert 处截图+取DOM+存接口响应，不判断，输出上下文文件
 *
 *   node web-run.cjs --run --plan plan.json --ctx-dir /tmp/ctx
 *     → 跑测试，aiAssert 处读 AI 预判断结果，确定性完成全部断言
 *
 *   node web-run.cjs --plan plan.json --ctx-dir /tmp/ctx --out result.json
 *     → 完整流程：collect → 输出 AI_ASSERT_PENDING → 等 result.json 同目录的 .result.json → run
 *     （供调用方 AI 在 collect 后介入判断）
 *
 * plan.json 结构：
 * {
 *   "baseUrl": "http://localhost:3000",
 *   "taskName": "cwork-test-xxx",
 *   "stepTimeoutMs": 15000,
 *   "totalBudgetMs": 600000,
 *   "scenarios": [{
 *     "name": "订单列表",
 *     "priority": "P0",
 *     "steps": [
 *       {"action": "navigate", "url": "/orders"},
 *       {"action": "waitForNetworkIdle"},
 *       {"action": "assertVisible", "selector": ".order-list", "desc": "订单列表可见"},
 *       {"action": "assertText", "selector": ".title", "expect": "订单管理", "desc": "标题正确"},
 *       {"action": "assertCount", "selector": ".order-item", "expect": 10, "desc": "10条订单"},
 *       {"action": "assertStyle", "selector": ".title", "property": "color", "expect": "rgb(51, 51, 51)"},
 *       {"action": "assertLayout", "selector": ".order-item", "expectAlign": "horizontal"},
 *       {"action": "assertApi", "urlPattern": "/api/orders", "expectStatus": 200, "expectBodyCode": 0},
 *       {"action": "assertDataConsistency", "selector": ".order-no", "apiField": "orders[0].orderNo"},
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

// ── heredoc 代码生成 ──

function generateHeredoc(plan, mode, ctxDir, keep = false) {
  const lines = [];
  const L = (s) => lines.push(s);

  const baseUrl = plan.baseUrl || 'http://localhost:3000';
  const taskName = plan.taskSpaceName || plan.taskName || 'cwork-test';
  const stepTimeout = plan.stepTimeoutMs || 15000;
  const collectMode = mode === 'collect';

  // 基础设施（ESM import：ego nodejs 运行时存在顶层 await，require 混用会报模块格式歧义）
  L(`'use strict';`);
  L(`import fs from 'node:fs';`);
  L(`import path from 'node:path';`);
  L(``);
  L(`const CTX_DIR = ${JSON.stringify(ctxDir)};`);
  L(`const MODE = ${JSON.stringify(mode)};`);
  L(`const STEP_TIMEOUT = ${stepTimeout};`);
  L(``);
  L(`if (MODE === 'run' || MODE === 'collect') {`);
  L(`  fs.mkdirSync(CTX_DIR, { recursive: true });`);
  L(`}`);
  L(``);

  // 接口拦截（在浏览器里注入 fetch/XHR 拦截）
  L(`// ── 接口响应拦截 ──`);
  L(`const __capturedResponses = [];`);
  L(`const __interceptorCode = String.raw\``);
  L(`(() => {`);
  L(`  window.__capturedResponses = [];`);
  L(`  const origFetch = window.fetch;`);
  L(`  window.fetch = async function(...args) {`);
  L(`    const resp = await origFetch.apply(this, args);`);
  L(`    const clone = resp.clone();`);
  L(`    clone.text().then(text => {`);
  L(`      let __body = null;`);
  L(`      try { __body = JSON.parse(text); } catch(e) { __body = null; }`);
  L(`      window.__capturedResponses.push({`);
  L(`        url: typeof args[0] === 'string' ? args[0] : args[0].url,`);
  L(`        method: (args[1] && args[1].method) || 'GET',`);
  L(`        status: resp.status,`);
  L(`        body: __body,`);
  L(`        reqBody: (args[1] && typeof args[1].body === 'string') ? args[1].body : null`);
  L(`      });`);
  L(`    }).catch(() => {});`);
  L(`    return resp;`);
  L(`  };`);
  L(`  const origXHR = XMLHttpRequest.prototype.open;`);
  L(`  const origSend = XMLHttpRequest.prototype.send;`);
  L(`  XMLHttpRequest.prototype.open = function(method, url) {`);
  L(`    this.__method = method; this.__url = url;`);
  L(`    return origXHR.apply(this, arguments);`);
  L(`  };`);
  L(`  XMLHttpRequest.prototype.send = function() {`);
  L(`    const __reqBody = (typeof arguments[0] === 'string') ? arguments[0] : null;`);
  L(`    this.addEventListener('load', function() {`);
  L(`      let __body = null;`);
  L(`      try { __body = JSON.parse(this.responseText); } catch(e) { __body = null; }`);
  L(`      window.__capturedResponses.push({`);
  L(`        url: this.__url, method: this.__method,`);
  L(`        status: this.status, body: __body, reqBody: __reqBody`);
  L(`      });`);
  L(`    });`);
  L(`    return origSend.apply(this, arguments);`);
  L(`  };`);
  L(`})()`);
  L(`\`;`);
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
  L(`async function withTimeout(promise, ms, label) {`);
  L(`  let timer;`);
  L(`  const timeout = new Promise((_, reject) => {`);
  L(`    timer = setTimeout(() => reject(new Error(label + ' 超时(' + ms + 'ms)')), ms);`);
  L(`  });`);
  L(`  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));`);
  L(`}`);
  L(``);

  // 获取拦截的接口响应
  L(`async function getCapturedResponses() {`);
  L(`  const raw = await js('JSON.stringify(window.__capturedResponses || [])');`);
  L(`  return JSON.parse(raw);`);
  L(`}`);
  L(``);
  L(`function findResponse(urlPattern) {`);
  L(`  return __lastResponses.find(r => r.url && r.url.includes(urlPattern));`);
  L(`}`);
  L(``);
  L(`let __lastResponses = [];`);
  L(`async function refreshResponses() {`);
  L(`  __lastResponses = await getCapturedResponses();`);
  L(`}`);
  L(``);

  // 断言函数
  L(`function assert(actual, expected, desc) {`);
  L(`  if (actual !== expected) {`);
  L(`    throw new Error(desc + ': 期望 ' + JSON.stringify(expected) + ', 实际 ' + JSON.stringify(actual));`);
  L(`  }`);
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
  L(``);

  // 全局看门狗
  const budgetMs = plan.totalBudgetMs || 10 * 60 * 1000;
  L(`const __budgetTimer = setTimeout(() => {`);
  L(`  log('❌ 全局看门狗触发（${budgetMs}ms 预算耗尽）');`);
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
      generateStepCode(L, step, stepLabel, collectMode, si, i);
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
        // 失败截图
        L(`  try {`);
        L(`    const __failShot = await captureScreenshot();`);
        L(`    log('  失败截图: ' + __failShot);`);
        L(`    __result_${si}.screenshot = __failShot;`);
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
  if (keep) {
    L(`await handOffTaskSpace(task.id);`);
    L(`log('✓ 任务空间已移交浏览器保持登录态（人工核验用）');`);
  } else {
    L(`await completeTaskSpace(task.id, { keep: false });`);
  }
  L(``);
  L(`const __summary = {`);
  L(`  scenarios: __results,`);
  L(`  passed: __results.filter(r => r.ok).length,`);
  L(`  failed: __results.filter(r => !r.ok).length,`);
  L(`  total: __results.length,`);
  L(`  finishedAt: new Date().toISOString()`);
  L(`};`);
  L(``);
  L(`const __outFile = path.join(CTX_DIR, '..', 'result.json');`);
  L(`fs.writeFileSync(__outFile, JSON.stringify(__summary, null, 2));`);
  L(`log('');`);
  L(`log('═══ 结果: 通过 ' + __summary.passed + ' / 失败 ' + __summary.failed + ' (共 ' + __summary.total + ' 场景) ═══');`);
  L(`log('RESULT_JSON=' + JSON.stringify(__summary));`);

  const code = lines.join('\n');
  return code;
}

// 生成单个步骤的执行代码
function generateStepCode(L, step, label, collectMode, si, i) {
  const action = step.action || step.type;

  switch (action) {
    case 'navigate':
      L(`  await gotoAndWait(${JSON.stringify(step.url)});`);
      L(`  await waitForLoad();`);
      L(`  await refreshResponses();`);
      break;

    case 'waitForNetworkIdle':
      L(`  await waitForNetworkIdle();`);
      L(`  await refreshResponses();`);
      break;

    case 'waitForLoad':
      L(`  await waitForLoad();`);
      break;

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
      L(`    const __expr = "(function(){ var el = document.querySelectorAll(" + ${JSON.stringify(JSON.stringify(step.selector))} + ")[" + ${step.index || 0} + "]; if (!el) return JSON.stringify({ok:false, err:'el null'}); el.dispatchEvent(new MouseEvent('mousedown', {bubbles:true, cancelable:true})); el.dispatchEvent(new FocusEvent('focus')); el.dispatchEvent(new MouseEvent('mouseup', {bubbles:true, cancelable:true})); el.dispatchEvent(new MouseEvent('click', {bubbles:true, cancelable:true})); var n = document.querySelectorAll('.el-picker-panel,.el-date-picker').length; return JSON.stringify({ok:true, panel:n}); })()";`);
      L(`    const __ev = await cdp('Runtime.evaluate', { expression: __expr, returnByValue: true });`);
      L(`    const __raw = (__ev && __ev.result && typeof __ev.result.value !== 'undefined') ? __ev.result.value : null;`);
      L(`    let __r = null; if (typeof __raw === 'string') { try { __r = JSON.parse(__raw); } catch (e) {} }`);
      L(`    if (!__r || !__r.ok) throw new Error('openDatePicker 失败: ' + JSON.stringify(__ev));`);
      L(`    cliLog('openDatePicker[dbg] ' + JSON.stringify(__r));`);
      L(`  }`);
      L(`  await sleep(800);`);
      L(`  await refreshResponses();`);
      break;

    case 'click':
      L(`  await click(${JSON.stringify(step.selector)}, { label: ${JSON.stringify(step.desc || '点击')} });`);
      L(`  await sleep(500);`);
      L(`  await refreshResponses();`);
      break;

    case 'fill':
      L(`  await fillInput(${JSON.stringify(step.selector)}, ${JSON.stringify(step.value)});`);
      break;

    case 'assertVisible':
      L(`  {`);
      L(`    const __el = await js(\`document.querySelector(${JSON.stringify(step.selector)}) !== null\`);`);
      L(`    if (!__el) throw new Error(${JSON.stringify(step.desc || '元素不可见')} + ': ' + ${JSON.stringify(step.selector)});`);
      L(`  }`);
      break;

    case 'assertText':
      L(`  {`);
      L(`    const __text = await js(\`(document.querySelector(${JSON.stringify(step.selector)}) || {}).textContent\`) || '';`);
      if (step.expectContains) {
        L(`    if (!__text.includes(${JSON.stringify(step.expectContains)})) throw new Error(${JSON.stringify(step.desc || '文本不匹配')} + ': "' + __text.trim() + '" 不包含 "' + ${JSON.stringify(step.expectContains)} + '"');`);
      } else {
        L(`    const __trimmed = __text.trim();`);
        L(`    if (__trimmed !== ${JSON.stringify(step.expect)}) throw new Error(${JSON.stringify(step.desc || '文本不匹配')} + ': 期望 "' + ${JSON.stringify(step.expect)} + '", 实际 "' + __trimmed + '"');`);
      }
      L(`  }`);
      break;

    case 'assertCount':
      L(`  {`);
      L(`    const __count = await js(\`document.querySelectorAll(${JSON.stringify(step.selector)}).length\`);`);
      L(`    if (__count !== ${step.expect}) throw new Error(${JSON.stringify(step.desc || '数量不匹配')} + ': 期望 ' + ${step.expect} + ', 实际 ' + __count);`);
      L(`  }`);
      break;

    case 'assertStyle': {
      const prop = step.property;
      L(`  {`);
      L(`    const __style = await js(\`getComputedStyle(document.querySelector(${JSON.stringify(step.selector)})).${prop}\`);`);
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
      L(`    const __rects = await js(\`JSON.stringify([...document.querySelectorAll(${JSON.stringify(step.selector)})].map(el => { const r = el.getBoundingClientRect(); return { x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height) }; }))\`);`);
      L(`    const __boxes = JSON.parse(__rects);`);
      if (step.expectAlign === 'center') {
        L(`    if (__boxes.length > 0) {`);
        L(`      const __parent = await js(\`(() => { const p = document.querySelector(${JSON.stringify(step.selector)}).parentElement; const r = p.getBoundingClientRect(); return JSON.stringify({x: Math.round(r.x), w: Math.round(r.width)}); })()\`);`);
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
        L(`      if (__cols !== ${step.expectGrid.columns}) throw new Error(${JSON.stringify(step.desc || '网格列数不匹配')} + ': 期望 ' + ${step.expectGrid.columns} + ' 列, 实际 ' + __cols + ' 列');`);
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
        L(`    if (__resp.status !== ${step.expectStatus}) throw new Error(${JSON.stringify(step.desc || '接口状态码错误')} + ': 期望 ' + ${step.expectStatus} + ', 实际 ' + __resp.status);`);
      }
      if (step.expectBodyCode !== undefined) {
        L(`    if (__resp.body && __resp.body.code !== ${step.expectBodyCode}) throw new Error(${JSON.stringify(step.desc || '业务码错误')} + ': 期望 ' + ${step.expectBodyCode} + ', 实际 ' + __resp.body.code);`);
      }
      L(`  }`);
      break;

    case 'assertDataConsistency':
      L(`  {`);
      L(`    const __pageValues = await js(\`JSON.stringify([...document.querySelectorAll(${JSON.stringify(step.selector)})].map(el => el.textContent.trim()))\`);`);
      L(`    const __vals = JSON.parse(__pageValues);`);
      L(`    await refreshResponses();`);
      L(`    const __apiResp = findResponse(${JSON.stringify(step.urlPattern || '')});`);
      L(`    if (__apiResp && __apiResp.body && ${JSON.stringify(step.apiField || '')}) {`);
      // 解析 apiField 路径，支持 orders[0].orderNo 语法
      L(`      const __path = ${JSON.stringify(step.apiField)};`);
      L(`      const __parts = __path.replace(/\\[(\\d+)\\]/g, '.$1').split('.');`);
      L(`      let __v = __apiResp.body;`);
      L(`      for (const __p of __parts) { if (__v == null) break; __v = __v[__p]; }`);
      L(`      const __apiValues = Array.isArray(__v) ? __v.map(String) : [String(__v)];`);
      L(`      for (let __i = 0; __i < Math.min(__vals.length, __apiValues.length); __i++) {`);
      L(`        if (__vals[__i] !== String(__apiValues[__i])) throw new Error(${JSON.stringify(step.desc || '数据不一致')} + ': 页面["' + __vals[__i] + '"] vs 接口["' + __apiValues[__i] + '"]');`);
      L(`      }`);
      L(`    }`);
      L(`  }`);
      break;

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
        // run 模式：读取 AI 预判断结果
        L(`    if (fs.existsSync(__resultFile)) {`);
        L(`      const __aiResult = JSON.parse(fs.readFileSync(__resultFile, 'utf8'));`);
        L(`      if (!__aiResult.pass) throw new Error('AI断言失败[' + ${JSON.stringify(step.desc || '')} + ']: ' + __aiResult.reason);`);
        L(`      log('  [AI] ' + ${JSON.stringify(step.desc || 'AI断言')} + ': ✓ ' + (__aiResult.reason || ''));`);
        L(`    } else {`);
        L(`      log('  [AI] 结果文件不存在: ' + __resultFile + '，跳过');`);
        L(`    }`);
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
        generateStepCode(L, sub, `${label} responsive.${j}`, collectMode, si, `${i}_r${j}`);
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
      L(`  log('  [跳过] 未知 action: ${action}');`);
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

async function runFullFlow(plan, ctxDir, outFile, egoPath, keep = false) {
  fs.mkdirSync(ctxDir, { recursive: true });

  // Pass 1: collect
  console.log('═══ Pass 1: 收集 AI 断言上下文 ═══');
  const collectCode = generateHeredoc(plan, 'collect', ctxDir);
  const collectResult = await executeHeredoc(collectCode, egoPath);

  if (collectResult.aiMarkers.length === 0) {
    console.log('无 AI 断言，直接完成');
    if (outFile && fs.existsSync(path.join(path.dirname(ctxDir), 'result.json'))) {
      const r = fs.readFileSync(path.join(path.dirname(ctxDir), 'result.json'), 'utf8');
      fs.writeFileSync(outFile, r);
    }
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
  const runCode = generateHeredoc(plan, 'run', ctxDir, keep);
  const runResult = await executeHeredoc(runCode, egoPath);

  // 复制结果到 outFile
  const resultFile = path.join(path.dirname(ctxDir), 'result.json');
  if (outFile && fs.existsSync(resultFile)) {
    fs.copyFileSync(resultFile, outFile);
  }

  return runResult.code;
}

// ── main ──

async function main() {
  const args = process.argv.slice(2);
  const planFile = getArg(args, '--plan');
  const ctxDir = getArg(args, '--ctx-dir') || '/tmp/cwork-web-test-ctx';
  const outFile = getArg(args, '--out');
  const collectOnly = args.includes('--collect');
  const runOnly = args.includes('--run');
  const keep = args.includes('--keep');

  if (!planFile) {
    console.error('用法: node web-run.cjs --plan plan.json [--ctx-dir /tmp/ctx] [--out result.json] [--collect | --run]');
    process.exit(1);
  }

  const egoPath = findEgoBrowser();
  if (!egoPath) {
    console.error('❌ 未找到 ego-browser，请先安装 ego lite 浏览器');
    process.exit(1);
  }

  const plan = JSON.parse(fs.readFileSync(planFile, 'utf8'));

  if (collectOnly) {
    fs.mkdirSync(ctxDir, { recursive: true });
    const code = generateHeredoc(plan, 'collect', ctxDir);
    const result = await executeHeredoc(code, egoPath);
    if (result.aiMarkers.length > 0) {
      console.log('AI_ASSERT_PENDING:' + JSON.stringify({ contexts: result.aiMarkers, ctxDir }));
    }
    process.exitCode = result.code;
  } else if (runOnly) {
    fs.mkdirSync(ctxDir, { recursive: true });
    const code = generateHeredoc(plan, 'run', ctxDir, keep);
    const result = await executeHeredoc(code, egoPath);
    if (outFile) {
      const resultFile = path.join(path.dirname(ctxDir), 'result.json');
      if (fs.existsSync(resultFile)) fs.copyFileSync(resultFile, outFile);
    }
    process.exitCode = result.code;
  } else {
    // 完整流程
    const exitCode = await runFullFlow(plan, ctxDir, outFile, egoPath, keep);
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
