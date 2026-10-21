#!/usr/bin/env node
/**
 * cwork-test 并行测试：结果合并器
 *
 * 用法：
 *   node merge-results.cjs --dir docs/requirements/xxx [--prefix result-ag]
 *
 * 功能：
 *   1. 查找目录下所有 result-ag*.json 文件
 *   2. 合并场景列表（按场景名去重）
 *   3. 累加统计数据（passed/failed/blocked/aiPending/total）
 *   4. 合并 aiPending 上下文列表
 *   5. 输出合并后的 result.json
 *
 * 输出：
 *   result.json（合并后的完整结果）
 *   标准输出：合并统计摘要
 */

'use strict';

const fs = require('fs');
const path = require('path');

// ── 参数解析 ──
function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i++) {
    if (argv[i].startsWith('--')) {
      const key = argv[i].replace(/^--/, '');
      args[key] = argv[i + 1] || 'true';
      i++;
    }
  }
  return args;
}

const args = parseArgs(process.argv.slice(2));
const dir = args.dir || '.';
const prefix = args.prefix || 'result-ag';
const output = args.out || 'result.json';

// ── 查找子结果文件 ──
const files = fs.readdirSync(dir)
  .filter(f => f.startsWith(prefix) && f.endsWith('.json'))
  .sort();

if (files.length === 0) {
  console.error(`❌ 未找到任何子结果文件（${dir}/${prefix}*.json）`);
  process.exit(1);
}

console.log(`合并 ${files.length} 个子结果文件...`);

// ── 合并 ──
const merged = {
  scenarios: [],
  passed: 0,
  failed: 0,
  blocked: 0,
  aiPending: [],
  hasPendingAI: false,
  total: 0,
  finishedAt: new Date().toISOString(),
  parallel: {
    agentCount: files.length,
    agentFiles: files,
    mergedAt: new Date().toISOString()
  }
};

const seenNames = new Set();

for (const file of files) {
  const filePath = path.join(dir, file);
  const raw = fs.readFileSync(filePath, 'utf8');
  const result = JSON.parse(raw);

  // 合并场景（按场景名去重）
  for (const sc of result.scenarios || []) {
    if (!seenNames.has(sc.name)) {
      seenNames.add(sc.name);
      merged.scenarios.push(sc);
    } else {
      console.warn(`⚠️  重复场景名: ${sc.name}（来自 ${file}），跳过`);
    }
  }

  // 累加统计
  merged.passed += result.passed || 0;
  merged.failed += result.failed || 0;
  merged.blocked += result.blocked || 0;
  merged.total += result.total || 0;

  // 合并 aiPending
  if (Array.isArray(result.aiPending)) {
    merged.aiPending.push(...result.aiPending);
  }
  if (result.hasPendingAI) {
    merged.hasPendingAI = true;
  }
}

// ── 写合并结果 ──
const outputPath = path.join(dir, output);
fs.writeFileSync(outputPath, JSON.stringify(merged, null, 2));

console.log(`✓ 合并结果已写入: ${outputPath}`);
console.log(`  通过: ${merged.passed} / 失败: ${merged.failed} / 阻塞: ${merged.blocked} / AI待判: ${merged.aiPending.length} / 总计: ${merged.total}`);
console.log(`  来源: ${files.join(', ')}`);
