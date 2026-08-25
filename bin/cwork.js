#!/usr/bin/env node

/**
 * cwork skills installer
 *
 * Usage:
 *   node bin/cwork.js --tool auto       # install to all detected IDEs
 *   node bin/cwork.js --tool cursor     # install to Cursor only
 *   node bin/cwork.js --tool qoder      # install to Qoder only
 *   node bin/cwork.js --tool claude     # install to Claude Code only
 *   node bin/cwork.js --tool trae       # install to Trae only
 *   node bin/cwork.js --uninstall --tool cursor
 */

import { readFileSync, writeFileSync, mkdirSync, cpSync, rmSync, existsSync, readdirSync, statSync } from 'fs';
import { join, resolve, dirname, basename } from 'path';
import { homedir } from 'os';

const ROOT = resolve(dirname(import.meta.url.replace('file://', '')), '..');
const SKILLS_DIR = join(ROOT, 'skills');
const HOME = homedir();
const PROJECT = process.cwd();

const TOOLS = ['cursor', 'qoder', 'claude', 'trae'];

// ── helpers ──────────────────────────────────────────────────────────

function log(msg) { console.log(`  ✓ ${msg}`); }
function warn(msg) { console.log(`  ⚠ ${msg}`); }
function skip(msg) { console.log(`  - ${msg}`); }

function parseArgs() {
  const args = process.argv.slice(2);
  const opts = { tool: null, uninstall: false };
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--tool') opts.tool = args[++i];
    if (args[i] === '--uninstall') opts.uninstall = true;
  }
  return opts;
}

function readSkillDirs() {
  return readdirSync(SKILLS_DIR)
    .filter(name => {
      const p = join(SKILLS_DIR, name);
      return statSync(p).isDirectory();
    })
    .sort();
}

function readSkillMd(skillName) {
  const mdPath = join(SKILLS_DIR, skillName, 'SKILL.md');
  return readFileSync(mdPath, 'utf-8');
}

function parseFrontmatter(content) {
  const match = content.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (!match) return { meta: {}, body: content };
  const meta = {};
  match[1].split('\n').forEach(line => {
    const idx = line.indexOf(':');
    if (idx > 0) meta[line.slice(0, idx).trim()] = line.slice(idx + 1).trim();
  });
  return { meta, body: match[2] };
}

function collectSkillFiles(skillName) {
  const skillDir = join(SKILLS_DIR, skillName);
  const files = [];
  function walk(dir, prefix = '') {
    for (const entry of readdirSync(dir)) {
      // 跳过备份文件，避免被打包进规则文件
      if (entry.endsWith('.bak') || entry.endsWith('.backup')) continue;
      const full = join(dir, entry);
      const stat = statSync(full);
      if (stat.isDirectory()) {
        walk(full, prefix + entry + '/');
      } else {
        files.push({ path: full, relPath: prefix + entry });
      }
    }
  }
  walk(skillDir);
  return files;
}

// ── Qoder installer ─────────────────────────────────────────────────

// 敏感文件/目录过滤：拷贝时跳过凭证、备份、本地配置
const SENSITIVE_PATTERNS = [
  /\.config\.local\.sh$/,
  /\.mcp_config\.json$/,
  /\.bak$/,
  /\.backup$/,
  /\.last_analysis_date$/,
];

function isSensitive(relPath) {
  return SENSITIVE_PATTERNS.some(re => re.test(relPath));
}

function copySkillFiltered(src, dest) {
  mkdirSync(dest, { recursive: true });
  function walk(dir, prefix = '') {
    for (const entry of readdirSync(dir)) {
      const full = join(dir, entry);
      const rel = prefix + entry;
      const stat = statSync(full);
      if (stat.isDirectory()) {
        walk(full, rel + '/');
      } else {
        if (isSensitive(rel)) continue;
        const destFile = join(dest, rel);
        mkdirSync(dirname(destFile), { recursive: true });
        writeFileSync(destFile, readFileSync(full));
      }
    }
  }
  walk(src);
}

function installQoder() {
  console.log('\n📦 Qoder (~/.qoder/skills/)');
  const target = join(HOME, '.qoder', 'skills');
  mkdirSync(target, { recursive: true });
  const skills = readSkillDirs();

  for (const skill of skills) {
    const skillName = `cwork-${skill}`;
    const src = join(SKILLS_DIR, skill);
    const dest = join(target, skillName);
    rmSync(dest, { recursive: true, force: true });
    copySkillFiltered(src, dest);
    log(skillName);
  }
}

function uninstallQoder() {
  console.log('\n📦 Qoder 卸载');
  const target = join(HOME, '.qoder', 'skills');
  const skills = readSkillDirs();
  for (const skill of skills) {
    const dest = join(target, `cwork-${skill}`);
    if (existsSync(dest)) {
      rmSync(dest, { recursive: true, force: true });
      log(`删除 cwork-${skill}`);
    }
  }
}

// ── Cursor installer ────────────────────────────────────────────────

function installCursor() {
  console.log('\n📦 Cursor (.cursor/rules/)');
  const target = join(PROJECT, '.cursor', 'rules');
  mkdirSync(target, { recursive: true });

  // remove old cwork rules
  if (existsSync(target)) {
    for (const f of readdirSync(target)) {
      if (f.startsWith('cwork-') && f.endsWith('.mdc')) {
        rmSync(join(target, f));
      }
    }
  }

  const skills = readSkillDirs();

  // 1) main entry rule — always applied
  const mainRule = buildCursorMainRule();
  writeFileSync(join(target, 'cwork.mdc'), mainRule);
  log('cwork.mdc (主入口)');

  // 2) per-skill rules
  for (const skill of skills) {
    const skillName = `cwork-${skill}`;
    const content = buildCursorSkillRule(skill, skillName);
    writeFileSync(join(target, `${skillName}.mdc`), content);
    log(`${skillName}.mdc`);
  }
}

function buildCursorMainRule() {
  const agentsMd = existsSync(join(ROOT, 'AGENTS.md'))
    ? readFileSync(join(ROOT, 'AGENTS.md'), 'utf-8')
    : '';
  // strip html comments
  const cleaned = agentsMd.replace(/<!--\s*cwork-skills:begin\s*-->/, '').replace(/<!--\s*cwork-skills:end\s*-->/, '').trim();

  return `---
description: cwork 工作流技能集主入口。当用户提到需求实现、bug修复、初始化、提交代码、查日志、查配置、查数仓、查代码仓库、查需求、生成文档、自动化测试、查监控指标时触发。
alwaysApply: true
---

${cleaned}

## 技能调用方式

每个技能以 \`/cwork-xxx\` 形式调用。可用技能：
- /cwork-init — 初始化（多服务场景）
- /cwork-implement — 完整实现流程
- /cwork-bug — 快速修复 bug
- /cwork-test — 页面自动化测试
- /cwork-commit — 提交代码
- /cwork-code — 代码仓库查询
- /cwork-log — 查日志分析
- /cwork-config — Nacos 配置查询
- /cwork-data — 数仓数据查询
- /cwork-doc — 技术方案生成
- /cwork-requirement — 云效需求查询
- /cwork-graf — Grafana 监控查询

调用某个技能时，读取对应的 cwork-xxx.mdc 规则文件获取完整指令。
`;
}

function buildCursorSkillRule(skillDir, skillName) {
  const md = readSkillMd(skillDir);
  const { meta, body } = parseFrontmatter(md);

  // 参考文件复制到 .cursor/rules/<skillName>/ 下，主规则不内联（避免超 40k 字符限制）
  const files = collectSkillFiles(skillDir);
  const refFiles = files.filter(f => f.relPath !== 'SKILL.md' && !f.relPath.startsWith('scripts/'));
  let refIndex = '';
  if (refFiles.length > 0) {
    const refDir = join(PROJECT, '.cursor', 'rules', skillName);
    rmSync(refDir, { recursive: true, force: true });
    mkdirSync(refDir, { recursive: true });
    for (const f of refFiles) {
      const dest = join(refDir, f.relPath);
      mkdirSync(dirname(dest), { recursive: true });
      writeFileSync(dest, readFileSync(f.path, 'utf-8'));
    }
    refIndex = `\n\n---\n## 参考文件位置\n\n本技能的参考文件位于 \`.cursor/rules/${skillName}/\` 目录下，按 SKILL.md 内引用路径读取。例如 "见 \`references/catalog-detail.md\`" 对应 \`.cursor/rules/${skillName}/references/catalog-detail.md\`，"Read 同目录 \`design-guide.md\`" 对应 \`.cursor/rules/${skillName}/design-guide.md\`。\n`;
  }

  return `---
description: ${meta.description || skillName}
alwaysApply: false
---

${body}${refIndex}
`;
}

function uninstallCursor() {
  console.log('\n📦 Cursor 卸载');
  const target = join(PROJECT, '.cursor', 'rules');
  if (!existsSync(target)) return skip('目录不存在');
  for (const f of readdirSync(target)) {
    if (f.startsWith('cwork') && f.endsWith('.mdc')) {
      rmSync(join(target, f));
      log(`删除 ${f}`);
    }
  }
}

// ── Claude Code installer ───────────────────────────────────────────

function installClaude() {
  console.log('\n📦 Claude Code (CLAUDE.md + .claude/rules/)');

  const agentsMd = existsSync(join(ROOT, 'AGENTS.md'))
    ? readFileSync(join(ROOT, 'AGENTS.md'), 'utf-8')
    : '';
  const cleaned = agentsMd.replace(/<!--\s*cwork-skills:begin\s*-->/, '').replace(/<!--\s*cwork-skills:end\s*-->/, '').trim();

  const skills = readSkillDirs();
  let skillList = '';
  for (const skill of skills) {
    const md = readSkillMd(skill);
    const { meta } = parseFrontmatter(md);
    skillList += `- /cwork-${skill} — ${meta.description || skill}\n`;
  }

  const content = `<!-- cwork-skills:begin -->
${cleaned}

## 技能清单

${skillList}
## 技能文件位置

调用某个技能时，读取 \`.claude/rules/cwork-<name>.md\` 获取完整指令。
<!-- cwork-skills:end -->
`;

  writeFileSync(join(PROJECT, 'CLAUDE.md'), content);
  log('CLAUDE.md 已更新');

  // per-skill rules
  const target = join(PROJECT, '.claude', 'rules');
  mkdirSync(target, { recursive: true });

  // remove old cwork rules（主规则文件 + 拆分的参考文件目录）
  if (existsSync(target)) {
    for (const f of readdirSync(target)) {
      if (!f.startsWith('cwork-')) continue;
      const p = join(target, f);
      const stat = statSync(p);
      if (stat.isFile() && f.endsWith('.md')) {
        rmSync(p);
      } else if (stat.isDirectory()) {
        rmSync(p, { recursive: true, force: true });
      }
    }
  }

  for (const skill of skills) {
    const skillName = `cwork-${skill}`;
    const md = readSkillMd(skill);
    const { body } = parseFrontmatter(md);

    // 参考文件按原结构复制到 .claude/rules/<skillName>/ 下，主规则文件不内联（避免超 40k 字符限制）
    const files = collectSkillFiles(skill);
    const refFiles = files.filter(f => f.relPath !== 'SKILL.md' && !f.relPath.startsWith('scripts/'));
    let refIndex = '';
    if (refFiles.length > 0) {
      const refDir = join(target, skillName);
      mkdirSync(refDir, { recursive: true });
      for (const f of refFiles) {
        const dest = join(refDir, f.relPath);
        mkdirSync(dirname(dest), { recursive: true });
        writeFileSync(dest, readFileSync(f.path, 'utf-8'));
      }
      refIndex = `\n\n---\n## 参考文件位置\n\n本技能的参考文件位于 \`.claude/rules/${skillName}/\` 目录下，按 SKILL.md 内引用路径读取。例如 "见 \`references/catalog-detail.md\`" 对应 \`.claude/rules/${skillName}/references/catalog-detail.md\`，"Read 同目录 \`design-guide.md\`" 对应 \`.claude/rules/${skillName}/design-guide.md\`。\n`;
    }

    writeFileSync(join(target, `${skillName}.md`), `# ${skillName}\n\n${body}${refIndex}\n`);
    log(`${skillName}.md`);
  }
}

function uninstallClaude() {
  console.log('\n📦 Claude Code 卸载');
  const file = join(PROJECT, 'CLAUDE.md');
  if (existsSync(file)) {
    let content = readFileSync(file, 'utf-8');
    content = content.replace(/<!-- cwork-skills:begin -->[\s\S]*?<!-- cwork-skills:end -->\n?/g, '');
    writeFileSync(file, content.trim() + '\n');
    log('CLAUDE.md 已清理');
  }

  const target = join(PROJECT, '.claude', 'rules');
  if (existsSync(target)) {
    for (const f of readdirSync(target)) {
      if (f.startsWith('cwork-') && f.endsWith('.md')) {
        rmSync(join(target, f));
        log(`删除 ${f}`);
      }
    }
  }
}

// ── Trae installer ──────────────────────────────────────────────────

function installTrae() {
  console.log('\n📦 Trae (.trae/rules/)');
  const target = join(PROJECT, '.trae', 'rules');
  mkdirSync(target, { recursive: true });

  // remove old cwork rules
  if (existsSync(target)) {
    for (const f of readdirSync(target)) {
      if (f.startsWith('cwork-') && f.endsWith('.md')) {
        rmSync(join(target, f));
      }
    }
  }

  const skills = readSkillDirs();

  // main entry rule
  const agentsMd = existsSync(join(ROOT, 'AGENTS.md'))
    ? readFileSync(join(ROOT, 'AGENTS.md'), 'utf-8')
    : '';
  const cleaned = agentsMd.replace(/<!--\s*cwork-skills:begin\s*-->/, '').replace(/<!--\s*cwork-skills:end\s*-->/, '').trim();

  const mainContent = `# cwork 工作流技能集

${cleaned}

## 技能调用方式

每个技能以 \`/cwork-xxx\` 形式调用。调用某个技能时，读取 \`.trae/rules/cwork-xxx.md\` 获取完整指令。

可用技能：
- /cwork-init — 初始化
- /cwork-implement — 完整实现流程
- /cwork-bug — 快速修复 bug
- /cwork-test — 页面自动化测试
- /cwork-commit — 提交代码
- /cwork-code — 代码仓库查询
- /cwork-log — 查日志分析
- /cwork-config — Nacos 配置查询
- /cwork-data — 数仓数据查询
- /cwork-doc — 技术方案生成
- /cwork-requirement — 云效需求查询
- /cwork-graf — Grafana 监控查询
`;
  writeFileSync(join(target, 'cwork.md'), mainContent);
  log('cwork.md (主入口)');

  // per-skill rules
  for (const skill of skills) {
    const skillName = `cwork-${skill}`;
    const md = readSkillMd(skill);
    const { body } = parseFrontmatter(md);

    // 参考文件复制到 .trae/rules/<skillName>/ 下，主规则不内联（避免超 40k 字符限制）
    const files = collectSkillFiles(skill);
    const refFiles = files.filter(f => f.relPath !== 'SKILL.md' && !f.relPath.startsWith('scripts/'));
    let refIndex = '';
    if (refFiles.length > 0) {
      const refDir = join(target, skillName);
      rmSync(refDir, { recursive: true, force: true });
      mkdirSync(refDir, { recursive: true });
      for (const f of refFiles) {
        const dest = join(refDir, f.relPath);
        mkdirSync(dirname(dest), { recursive: true });
        writeFileSync(dest, readFileSync(f.path, 'utf-8'));
      }
      refIndex = `\n\n---\n## 参考文件位置\n\n本技能的参考文件位于 \`.trae/rules/${skillName}/\` 目录下，按 SKILL.md 内引用路径读取。例如 "见 \`references/catalog-detail.md\`" 对应 \`.trae/rules/${skillName}/references/catalog-detail.md\`，"Read 同目录 \`design-guide.md\`" 对应 \`.trae/rules/${skillName}/design-guide.md\`。\n`;
    }

    writeFileSync(join(target, `${skillName}.md`), `# ${skillName}\n\n${body}${refIndex}\n`);
    log(`${skillName}.md`);
  }
}

function uninstallTrae() {
  console.log('\n📦 Trae 卸载');
  const target = join(PROJECT, '.trae', 'rules');
  if (!existsSync(target)) return skip('目录不存在');
  for (const f of readdirSync(target)) {
    if (f.startsWith('cwork') && f.endsWith('.md')) {
      rmSync(join(target, f));
      log(`删除 ${f}`);
    }
  }
}

// ── main ────────────────────────────────────────────────────────────

const installers = { qoder: installQoder, cursor: installCursor, claude: installClaude, trae: installTrae };
const uninstallers = { qoder: uninstallQoder, cursor: uninstallCursor, claude: uninstallClaude, trae: uninstallTrae };

const opts = parseArgs();

if (opts.tool && opts.tool !== 'auto') {
  if (!TOOLS.includes(opts.tool)) {
    console.error(`未知工具: ${opts.tool}，支持: ${TOOLS.join(', ')}, auto`);
    process.exit(1);
  }
  opts.uninstall ? uninstallers[opts.tool]() : installers[opts.tool]();
} else {
  // auto: install to all
  for (const tool of TOOLS) {
    opts.uninstall ? uninstallers[tool]() : installers[tool]();
  }
}

// 装完提示设 CWORK_HOME（IDE 安装场景下 cwork-log/config/data 的凭证 fallback 依赖它）
if (!opts.uninstall && !process.env.CWORK_HOME) {
  console.log('\n💡 凭证复用提示：');
  console.log('   cwork-log / cwork-config / cwork-data 在 IDE 安装目录里没有凭证（敏感文件已过滤）。');
  console.log('   在 shell profile（~/.zshrc 或 ~/.bashrc）加一行，让所有 IDE 复用源仓库凭证，无需重复配置：');
  console.log(`     export CWORK_HOME="${ROOT}"`);
}

console.log('\n✅ 完成！');
