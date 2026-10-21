#!/usr/bin/env node
/**
 * cwork-test 并行测试：plan.json 拆分器
 *
 * 用法：
 *   node split-plan.cjs --plan plan.json [--agents 3]
 *
 * 功能：
 *   1. 读取完整 plan.json
 *   2. 提取登录场景（第一个 P0 且名称含"登录/login"）
 *   3. 将业务场景均分到 N 组（N = min(agents, 场景数/3, 3)）
 *   4. 每组生成独立子 plan（含登录场景 + taskSpaceName 加后缀）
 *   5. 输出分组清单（供主 agent 解析）
 *
 * 输出：
 *   plan-ag1.json, plan-ag2.json, ... （子 plan 文件）
 *   标准输出：GROUPS=JSON（分组清单）
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
const planPath = args.plan;
const maxAgents = parseInt(args.agents || '3', 10);

if (!planPath) {
  console.error('用法: node split-plan.cjs --plan plan.json [--agents 3]');
  process.exit(1);
}

if (!fs.existsSync(planPath)) {
  console.error(`❌ plan 文件不存在: ${planPath}`);
  process.exit(1);
}

// ── 读取 plan ──
const plan = JSON.parse(fs.readFileSync(planPath, 'utf8'));
const scenarios = plan.scenarios || [];

if (scenarios.length === 0) {
  console.error('❌ plan.json 无场景');
  process.exit(1);
}

// ── 提取登录场景 ──
const loginIdx = scenarios.findIndex(s =>
  s.priority === 'P0' && /登录|login/i.test(s.name)
);
const loginScenario = loginIdx >= 0 ? scenarios[loginIdx] : null;
const businessScenarios = scenarios.filter((_, i) => i !== loginIdx);

console.log(`✓ 场景总数: ${scenarios.length}（登录: ${loginScenario ? '1' : '0'}, 业务: ${businessScenarios.length}）`);

// ── 计算分组数 ──
// 规则：最多 maxAgents 组，每组至少 3 个业务场景
const agentCount = Math.min(
  maxAgents,
  Math.max(1, Math.floor(businessScenarios.length / 3))
);

console.log(`✓ 分组数: ${agentCount}（最多 ${maxAgents} 组，每组至少 3 个业务场景）`);

// ── 均分业务场景 ──
const groups = [];
const chunkSize = Math.ceil(businessScenarios.length / agentCount);

for (let i = 0; i < agentCount; i++) {
  const start = i * chunkSize;
  const end = Math.min(start + chunkSize, businessScenarios.length);
  const groupScenarios = businessScenarios.slice(start, end);

  // 每组加登录场景（如果有）
  if (loginScenario) {
    groupScenarios.unshift(loginScenario);
  }

  groups.push({
    id: `ag${i + 1}`,
    scenarios: groupScenarios
  });
}

// ── 生成子 plan 文件 ──
const planDir = path.dirname(planPath);
const planBase = path.basename(planPath, '.json');

for (const group of groups) {
  const subPlan = {
    ...plan,
    taskSpaceName: `${plan.taskSpaceName || 'cwork-test'}-${group.id}`,
    scenarios: group.scenarios
  };

  const subPlanPath = path.join(planDir, `${planBase}-${group.id}.json`);
  fs.writeFileSync(subPlanPath, JSON.stringify(subPlan, null, 2));
  console.log(`✓ 生成子 plan: ${subPlanPath}（${group.scenarios.length} 个场景）`);
}

// ── 输出分组清单（供主 agent 解析）──
const groupManifest = groups.map(g => ({
  id: g.id,
  planFile: `${planBase}-${g.id}.json`,
  resultFile: `result-${g.id}.json`,
  scenarioCount: g.scenarios.length
}));

console.log('\nGROUPS=' + JSON.stringify(groupManifest, null, 2));
