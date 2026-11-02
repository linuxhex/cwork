#!/usr/bin/env node
/**
 * cwork-test 安卓测试执行器（ADB 直连 BlueStacks 5）
 *
 * 对齐 BlueStacks 官方 AI Agent Skill 能力，但不依赖 Desktop（仅 Windows）。
 * 所有操作经 adb shell，带超时看门狗，挂起即报错不卡死。
 *
 * 用法：
 *   node android-run.cjs --check                              # 探活：设备+版本+目标包
 *   node android-run.cjs --snapshot [--out snap.json]          # 当前界面可交互节点清单
 *   node android-run.cjs --plan plan.json [--out result.json]  # 跑测试计划
 *   node android-run.cjs --install <apk>                       # 安装/覆盖安装
 *
 * plan.json 结构：
 * {
 *   "deviceId": "127.0.0.1:5555",
 *   "packageName": "com.example.app",
 *   "stepTimeoutMs": 20000,
 *   "scenarios": [{
 *     "name": "登录", "priority": "P0",
 *     "steps": [
 *       {"action": "launch", "packageName": "com.example.app"},
 *       {"action": "tap", "selector": {"text": "登录"}},
 *       {"action": "input", "selector": {"resourceId": "com.example.app:id/phone"}, "text": "13800138000"},
 *       {"action": "assertText", "contains": "验证码"},
 *       {"action": "screenshot", "name": "login"}
 *     ]
 *   }]
 * }
 *
 * 支持的动作：
 *   launch {packageName}        am start 启动 App
 *   tap {selector}              按 resource-id/text/content-desc/bounds 定位点击
 *   input {selector, text}      先 tap 聚焦再 input text
 *   swipe {from, to, duration?} 滑动（坐标数组）
 *   back {}                     返回键
 *   wait {ms}                   固定等待
 *   assertText {contains}       当前界面含文本
 *   assertElement {selector}    元素存在
 *   screenshot {name}           截图取证
 */

'use strict';

const fs = require('fs');
const { execFileSync } = require('child_process');

// ── ADB 定位 ──
function findAdb() {
  const candidates = [
    process.env.ADB_PATH,
    '/opt/homebrew/bin/adb',
    '/usr/local/bin/adb',
    '/Applications/BlueStacks.app/Contents/MacOS/hd-adb',
  ].filter(Boolean);
  for (const c of candidates) {
    try { fs.accessSync(c, fs.constants.X_OK); return c; } catch (_) {}
  }
  // 兜底：PATH 里找
  try { return execFileSync('which', ['adb'], { encoding: 'utf8' }).trim(); } catch (_) {}
  console.error('❌ 未找到 adb，设置 ADB_PATH 环境变量或安装到 PATH');
  process.exit(1);
}

const ADB = findAdb();

// ── adb 命令封装（带超时，同步执行避免并发状态错乱）──
function adb(args, { timeoutMs = 20000 } = {}) {
  try {
    return execFileSync(ADB, args, { encoding: 'utf8', timeout: timeoutMs, maxBuffer: 10 * 1024 * 1024 });
  } catch (err) {
    const msg = err.stderr ? err.stderr.toString().trim() : err.message;
    throw new Error(`adb ${args.join(' ')} 失败：${msg}`);
  }
}

function adbShell(cmd, opts) { return adb(['shell', cmd], opts); }

// ── 超时 sleep ──
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ── uiautomator dump 解析 ──
function dumpNodes() {
  // dump 到设备文件再 pull，避免 stdout 编码问题
  adbShell('uiautomator dump /sdcard/ui.xml', { timeoutMs: 15000 });
  const xml = adb(['shell', 'cat', '/sdcard/ui.xml'], { timeoutMs: 10000 });
  const nodes = [];
  // 解析 <node .../> 的关键属性
  const re = /<node\b[^>]*?(?:\/>|><\/node>)/g;
  let m;
  while ((m = re.exec(xml)) !== null) {
    const tag = m[0];
    const get = (k) => {
      const r = new RegExp(`\\b${k}="([^"]*)"`, 'g');
      const rr = r.exec(tag);
      return rr ? rr[1] : '';
    };
    const bounds = get('bounds');
    // bounds=[x1,y1][x2,y2] → 中心点
    let center = null;
    const bm = /\[(\d+),(\d+)\]\[(\d+),(\d+)\]/.exec(bounds);
    if (bm) {
      center = [Math.round((+bm[1] + +bm[3]) / 2), Math.round((+bm[2] + +bm[4]) / 2)];
    }
    const resourceId = get('resource-id');
    const text = get('text');
    const contentDesc = get('content-desc');
    const clickable = get('clickable') === 'true';
    // 只收可交互或有标识的节点
    if (clickable || resourceId || text || contentDesc) {
      nodes.push({ resourceId, text, contentDesc, clickable, bounds, center });
    }
  }
  return nodes;
}

// ── 按 selector 定位节点 → 坐标 ──
function locate(selector, nodes) {
  if (selector.resourceId) {
    const n = nodes.find((n) => n.resourceId === selector.resourceId);
    if (n && n.center) return n.center;
  }
  if (selector.text) {
    const n = nodes.find((n) => n.text === selector.text || (n.text && n.text.includes(selector.text)));
    if (n && n.center) return n.center;
  }
  if (selector.contentDesc) {
    const n = nodes.find((n) => n.contentDesc === selector.contentDesc || (n.contentDesc && n.contentDesc.includes(selector.contentDesc)));
    if (n && n.center) return n.center;
  }
  if (selector.bounds) {
    const bm = /\[(\d+),(\d+)\]\[(\d+),(\d+)\]/.exec(selector.bounds);
    if (bm) return [Math.round((+bm[1] + +bm[3]) / 2), Math.round((+bm[2] + +bm[4]) / 2)];
  }
  if (selector.center) return selector.center;
  return null;
}

class Runner {
  constructor(plan) {
    this.packageName = plan.packageName;
    this.deviceId = plan.deviceId;
    this.stepTimeoutMs = plan.stepTimeoutMs || 20000;
  }

  async runStep(step) {
    try {
      switch (step.action) {
        case 'launch': {
          const pkg = step.packageName || this.packageName;
          adbShell(`monkey -p ${pkg} -c android.intent.category.LAUNCHER 1`, { timeoutMs: this.stepTimeoutMs });
          await sleep(1500); // 等启动
          return { ok: true, detail: `launch ${pkg}` };
        }
        case 'tap': {
          const nodes = dumpNodes();
          const coord = locate(step.selector, nodes);
          if (!coord) throw new Error(`定位失败：${JSON.stringify(step.selector)}`);
          adbShell(`input tap ${coord[0]} ${coord[1]}`, { timeoutMs: this.stepTimeoutMs });
          await sleep(500);
          return { ok: true, detail: `tap (${coord[0]},${coord[1]})` };
        }
        case 'input': {
          const nodes = dumpNodes();
          const coord = locate(step.selector, nodes);
          if (!coord) throw new Error(`定位失败：${JSON.stringify(step.selector)}`);
          adbShell(`input tap ${coord[0]} ${coord[1]}`, { timeoutMs: this.stepTimeoutMs });
          await sleep(300);
          // input text 不支持中文/特殊字符，仅 ASCII；中文场景后续接广播兜底
          adbShell(`input text "${String(step.text).replace(/["\\]/g, '\\$&')}"`, { timeoutMs: this.stepTimeoutMs });
          return { ok: true, detail: `input ${step.text}` };
        }
        case 'swipe': {
          const [x1, y1] = step.from;
          const [x2, y2] = step.to;
          const dur = step.duration || 300;
          adbShell(`input swipe ${x1} ${y1} ${x2} ${y2} ${dur}`, { timeoutMs: this.stepTimeoutMs });
          await sleep(300);
          return { ok: true, detail: `swipe` };
        }
        case 'back':
          adbShell('input keyevent 4', { timeoutMs: this.stepTimeoutMs });
          await sleep(300);
          return { ok: true, detail: 'back' };
        case 'wait':
          await sleep(Math.min(step.ms || 1000, 10000));
          return { ok: true, detail: `${step.ms || 1000}ms` };
        case 'assertText': {
          const nodes = dumpNodes();
          const hit = nodes.some((n) => n.text && n.text.includes(String(step.contains)));
          if (!hit) throw new Error(`当前界面未含文本 "${step.contains}"`);
          return { ok: true, detail: `assertText "${step.contains}"` };
        }
        case 'assertElement': {
          const nodes = dumpNodes();
          const coord = locate(step.selector, nodes);
          if (!coord) throw new Error(`元素不存在：${JSON.stringify(step.selector)}`);
          return { ok: true, detail: `assertElement` };
        }
        case 'screenshot': {
          const name = step.name || `s${Date.now()}`;
          const outPath = `screenshots/${name}.png`;
          fs.mkdirSync('screenshots', { recursive: true });
          const buf = execFileSync(ADB, ['exec-out', 'screencap', '-p'], { timeout: 15000, maxBuffer: 20 * 1024 * 1024 });
          fs.writeFileSync(outPath, buf);
          return { ok: true, detail: outPath };
        }
        default:
          throw new Error(`未知 action: ${step.action}`);
      }
    } catch (err) {
      return { ok: false, detail: `${step.action} 失败：${err.message}` };
    }
  }

  async evidence() {
    try {
      const name = `fail-${Date.now()}`;
      const outPath = `screenshots/${name}.png`;
      fs.mkdirSync('screenshots', { recursive: true });
      const buf = execFileSync(ADB, ['exec-out', 'screencap', '-p'], { timeout: 15000, maxBuffer: 20 * 1024 * 1024 });
      fs.writeFileSync(outPath, buf);
      let dump = '';
      try { dump = dumpNodes().slice(0, 20).map((n) => `${n.resourceId || n.text} @ ${n.bounds}`).join('\n'); } catch (_) {}
      return { screenshot: outPath, dump };
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
  const installApk = args.includes('--install') ? args[args.indexOf('--install') + 1] : null;

  if (!planFile && !checkOnly && !snapshotMode && !installApk) {
    console.error('用法：node android-run.cjs --check | --snapshot [--out] | --plan plan.json [--out] | --install <apk>');
    process.exit(1);
  }

  // 指定 deviceId 时先 connect
  if (planFile) {
    const plan = JSON.parse(fs.readFileSync(planFile, 'utf8'));
    if (plan.deviceId) { try { adb(['connect', plan.deviceId]); } catch (_) {} }
  }

  // 全局看门狗
  const budgetMs = 15 * 60 * 1000;
  setTimeout(() => { console.error(`❌ 全局看门狗触发（${budgetMs}ms），强制退出——疑似 ADB 挂起`); process.exit(2); }, budgetMs).unref();

  try {
    if (installApk) {
      console.log(`→ 安装 ${installApk}...`);
      const out = adb(['install', '-r', installApk], { timeoutMs: 120000 });
      console.log(`✓ 安装完成：${out.split('\n').pop().trim()}`);
      return;
    }

    if (checkOnly) {
      const device = adb(['get-state'], { timeoutMs: 5000 }).trim();
      const version = adbShell('getprop ro.build.version.release', { timeoutMs: 5000 }).trim();
      console.log(`✓ 探活成功：设备 ${device}，Android ${version}`);
      return;
    }

    if (snapshotMode) {
      const nodes = dumpNodes();
      const snap = { elements: nodes.slice(0, 80).map((n) => ({
        resourceId: n.resourceId, text: n.text, contentDesc: n.contentDesc,
        clickable: n.clickable, bounds: n.bounds, center: n.center,
      })) };
      if (outFile) fs.writeFileSync(outFile, JSON.stringify(snap, null, 2), 'utf8');
      console.log(`✓ 快照完成：${snap.elements.length} 个可交互节点${outFile ? `，已存 ${outFile}` : ''}`);
      console.log('SNAPSHOT_JSON=' + JSON.stringify(snap));
      return;
    }

    const plan = JSON.parse(fs.readFileSync(planFile, 'utf8'));
    const runner = new Runner(plan);
    const scenarios = plan.scenarios || [];
    if (!Array.isArray(scenarios) || scenarios.length === 0) {
      throw new Error('plan.json 无 scenarios——拒绝执行空测试计划');
    }
    const summary = { scenarios: [], startedAt: new Date().toISOString() };
    let failed = 0;

    for (const sc of scenarios) {
      console.log(`\n【场景】${sc.name}（${sc.priority || 'P1'}）`);
      const result = { name: sc.name, priority: sc.priority || 'P1', steps: [], ok: true };
      for (let i = 0; i < (sc.steps || []).length; i++) {
        const step = sc.steps[i];
        const r = await runner.runStep(step);
        result.steps.push({ action: step.action, ...r });
        console.log(`  ${r.ok ? '✓' : '✗'} ${r.detail}`);
        if (!r.ok) {
          result.ok = false;
          result.evidence = await runner.evidence();
          break;
        }
      }
      result.ok ? console.log(`  场景结果：✓ 通过`) : (failed++, console.log(`  场景结果：✗ 失败`));
      summary.scenarios.push(result);
    }

    summary.finishedAt = new Date().toISOString();
    summary.passed = summary.scenarios.length - failed;
    summary.failed = failed;
    if (outFile) fs.writeFileSync(outFile, JSON.stringify(summary, null, 2), 'utf8');
    console.log(`\n═══ 结果：通过 ${summary.passed} / 失败 ${summary.failed}（共 ${summary.scenarios.length} 场景）${outFile ? `，详情 ${outFile}` : ''} ═══`);
    console.log('RESULT_JSON=' + JSON.stringify(summary));
    process.exitCode = failed > 0 ? 1 : 0;
  } catch (err) {
    console.error(`❌ ${err.message}`);
    process.exitCode = 2;
  }
}

main();
