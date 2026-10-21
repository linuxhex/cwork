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
 *   node bin/cwork.js --sync-global     # sync skills to ~/.claude/skills/ (Claude Code 全局技能)
 *   node bin/cwork.js --sync-global --uninstall
 */

import { readFileSync, writeFileSync, mkdirSync, cpSync, rmSync, existsSync, readdirSync, statSync, symlinkSync } from 'fs';
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
  const opts = { tool: null, uninstall: false, syncGlobal: false, check: false };
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--tool') opts.tool = args[++i];
    if (args[i] === '--uninstall') opts.uninstall = true;
    if (args[i] === '--sync-global') opts.syncGlobal = true;
    if (args[i] === '--check') opts.check = true;
  }
  return opts;
}

// 公共资源目录名（skills/common/）：跨技能共享的规范/参考文件，不是技能——
// 不生成技能规则文件、不进技能清单，只把文件分发到 <destDir>/cwork-common/ 下
const COMMON_DIR = 'common';

function readSkillDirs() {
  return readdirSync(SKILLS_DIR)
    .filter(name => {
      if (name === COMMON_DIR) return false;
      const p = join(SKILLS_DIR, name);
      return statSync(p).isDirectory();
    })
    .sort();
}

// 分发 skills/common/ 下的共享文件到目标规则目录（如 .claude/rules/cwork-common/、.cursor/rules/cwork-common/）
function installCommonFiles(target) {
  const commonSrc = join(SKILLS_DIR, COMMON_DIR);
  if (!existsSync(commonSrc)) return;
  const destDir = join(target, 'cwork-common');
  rmSync(destDir, { recursive: true, force: true });
  mkdirSync(destDir, { recursive: true });
  const files = [];
  (function walk(dir, prefix = '') {
    for (const entry of readdirSync(dir)) {
      if (entry.endsWith('.bak') || entry.endsWith('.backup')) continue;
      const full = join(dir, entry);
      const stat = statSync(full);
      if (stat.isDirectory()) {
        walk(full, prefix + entry + '/');
      } else {
        files.push({ path: full, relPath: prefix + entry });
      }
    }
  })(commonSrc);
  for (const f of files) {
    const dest = join(destDir, f.relPath);
    mkdirSync(dirname(dest), { recursive: true });
    writeFileSync(dest, readFileSync(f.path, 'utf-8'));
  }
  if (files.length > 0) log('cwork-common/ (共享规范文件)');
}

// Claude Code 产物尾注：解释参考文件位置（installClaude 生成与 checkInstall 校验共用同一份，避免双份字符串漂移）
function buildClaudeRefIndex(skillName) {
  return `\n\n---\n## 参考文件位置\n\n本技能的参考文件位于 \`.cwork/refs/${skillName}/\` 目录下（按需 Read，不常驻上下文），按 SKILL.md 内引用路径读取。例如 "见 \`references/catalog-detail.md\`" 对应 \`.cwork/refs/${skillName}/references/catalog-detail.md\`，"Read 同目录 \`design-guide.md\`" 对应 \`.cwork/refs/${skillName}/design-guide.md\`。\n`;
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
    // 凭证软链：CWORK_HOME 源仓库有凭证时，自动链到安装目录，避免每次安装后凭证丢失
    const cworkHome = process.env.CWORK_HOME;
    if (cworkHome) {
      const srcConfig = join(cworkHome, 'skills', skill, 'scripts', '.config.local.sh');
      const destConfig = join(dest, 'scripts', '.config.local.sh');
      if (existsSync(srcConfig) && !existsSync(destConfig)) {
        try {
          symlinkSync(srcConfig, destConfig);
        } catch (_) { /* 软链失败不阻塞安装 */ }
      }
    }
    log(skillName);
  }

  // USAGE_NOTES.md 单文件同步：它在 skills 根目录、不在技能目录遍历内，漏同步导致全局副本与源仓库分叉复发
  const usageSrcQ = join(SKILLS_DIR, 'USAGE_NOTES.md');
  if (existsSync(usageSrcQ)) writeFileSync(join(target, 'USAGE_NOTES.md'), readFileSync(usageSrcQ));

  // 分发共享规范文件（skills/common/ → ~/.qoder/skills/cwork-common/）
  installCommonFiles(target);
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
  const commonDest = join(target, 'cwork-common');
  if (existsSync(commonDest)) {
    rmSync(commonDest, { recursive: true, force: true });
    log('删除 cwork-common');
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

  // 3) 同步全局 ~/.cursor/rules/cwork-skills.md（Cursor 全局规则，任意项目可见）
  const globalTarget = join(HOME, '.cursor', 'rules');
  mkdirSync(globalTarget, { recursive: true });
  writeFileSync(join(globalTarget, 'cwork-skills.md'), mainRule);
  log('~/.cursor/rules/cwork-skills.md (全局主入口)');

  // 4) 分发共享规范文件（skills/common/ → .cursor/rules/cwork-common/）
  installCommonFiles(target);
}

function buildCursorMainRule() {
  const agentsMd = existsSync(join(ROOT, 'AGENTS.md'))
    ? readFileSync(join(ROOT, 'AGENTS.md'), 'utf-8')
    : '';
  // strip html comments
  const cleaned = agentsMd.replace(/<!--\s*cwork-skills:begin\s*-->/, '').replace(/<!--\s*cwork-skills:end\s*-->/, '').trim();

  return `---
description: cwork 工作流技能集主入口。当用户提到需求实现、bug修复、初始化、提交代码、查日志、查配置、查数仓、查代码仓库、查需求、生成文档、自动化测试、查监控指标、构建部署时触发。
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
- /cwork-deploy — Jenkins + 云效构建部署触发
- /cwork-image — 本地工程/jar 打包镜像 + push registry + 服务端拉起运行

调用某个技能时，读取对应的 cwork-xxx.mdc 规则文件获取完整指令。
`;
}

function buildCursorSkillRule(skillDir, skillName) {
  const md = readSkillMd(skillDir);
  const { meta, body: rawBody } = parseFrontmatter(md);
  // 共享规范引用路径按 IDE 替换：源里写 .claude/rules/cwork-common/，Cursor 装到 .cursor/rules/cwork-common/
  const body = rawBody.replaceAll('.claude/rules/cwork-common/', '.cursor/rules/cwork-common/');

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
    const p = join(target, f);
    const stat = statSync(p);
    if (f.startsWith('cwork') && f.endsWith('.mdc') && stat.isFile()) {
      rmSync(p);
      log(`删除 ${f}`);
    } else if (f.startsWith('cwork-') && stat.isDirectory()) {
      // 参考文件目录（cwork-<skill>/）与共享规范目录（cwork-common/）
      rmSync(p, { recursive: true, force: true });
      log(`删除 ${f}/`);
    }
  }

  // 清理全局 ~/.cursor/rules/cwork-skills.md
  const globalFile = join(HOME, '.cursor', 'rules', 'cwork-skills.md');
  if (existsSync(globalFile)) {
    rmSync(globalFile);
    log('删除 ~/.cursor/rules/cwork-skills.md (全局)');
  }
}

// ── Claude Code installer ───────────────────────────────────────────

function installClaude() {
  console.log('\n📦 Claude Code (CLAUDE.md + .cwork/refs/)');

  const agentsMd = existsSync(join(ROOT, 'AGENTS.md'))
    ? readFileSync(join(ROOT, 'AGENTS.md'), 'utf-8')
    : '';
  const cleaned = agentsMd.replace(/<!--\s*cwork-skills:begin\s*-->/, '').replace(/<!--\s*cwork-skills:end\s*-->/, '').trim();

  const skills = readSkillDirs();
  let skillList = '';
  for (const skill of skills) {
    const md = readSkillMd(skill);
    const { meta } = parseFrontmatter(md);
    // 所有技能都按需加载（控制上下文占用）
    skillList += `- /cwork-${skill} — ${meta.description || skill}\n  （按需加载：需要时 Read \`.cwork/refs/cwork-${skill}/SKILL.md\` 获取完整指令，不常驻上下文）\n`;
  }

  const content = `<!-- cwork-skills:begin -->
${cleaned}

## 技能清单

${skillList}
## 技能文件位置

调用某个技能时，读取 \`.cwork/refs/cwork-<name>/SKILL.md\` 获取完整指令。
<!-- cwork-skills:end -->
`;

  writeFileSync(join(PROJECT, 'CLAUDE.md'), content);
  log('CLAUDE.md 已更新');

  // 整体重建 .cwork/refs/（所有技能按需加载，不再生成 .claude/rules/ 常驻文件）
  const refsRoot = join(PROJECT, '.cwork', 'refs');
  if (existsSync(refsRoot)) {
    rmSync(refsRoot, { recursive: true, force: true });
  }
  mkdirSync(refsRoot, { recursive: true });

  for (const skill of skills) {
    const skillName = `cwork-${skill}`;
    const md = readSkillMd(skill);
    const { meta, body } = parseFrontmatter(md);

    // 收集所有文件（含 SKILL.md 和参考文件）
    const files = collectSkillFiles(skill);
    const refFiles = files.filter(f => f.relPath !== 'SKILL.md' && !f.relPath.startsWith('scripts/'));
    let refIndex = '';
    if (refFiles.length > 0) {
      refIndex = buildClaudeRefIndex(skillName);
    }

    // 所有技能都放到 .cwork/refs/<skillName>/ 下按需加载
    const refDir = join(PROJECT, '.cwork', 'refs', skillName);
    mkdirSync(refDir, { recursive: true });

    // 写 SKILL.md（主指令文件）
    writeFileSync(join(refDir, 'SKILL.md'), `# ${skillName}\n\n${body}${refIndex}\n`);

    // 复制参考文件
    for (const f of refFiles) {
      const dest = join(refDir, f.relPath);
      mkdirSync(dirname(dest), { recursive: true });
      writeFileSync(dest, readFileSync(f.path, 'utf-8'));
    }

    log(`${skillName}（按需加载 → .cwork/refs/${skillName}/SKILL.md）`);
  }

  // 分发共享规范文件（skills/common/ → .cwork/refs/cwork-common/，也按需加载）
  const commonRefsDir = join(PROJECT, '.cwork', 'refs', 'cwork-common');
  if (existsSync(commonRefsDir)) {
    rmSync(commonRefsDir, { recursive: true, force: true });
  }
  mkdirSync(commonRefsDir, { recursive: true });
  const commonSrc = join(SKILLS_DIR, COMMON_DIR);
  if (existsSync(commonSrc)) {
    (function walkCommon(dir, prefix = '') {
      for (const entry of readdirSync(dir)) {
        if (entry.endsWith('.bak') || entry.endsWith('.backup')) continue;
        const full = join(dir, entry);
        const stat = statSync(full);
        if (stat.isDirectory()) {
          walkCommon(full, prefix + entry + '/');
        } else {
          const destFile = join(commonRefsDir, prefix + entry);
          mkdirSync(dirname(destFile), { recursive: true });
          writeFileSync(destFile, readFileSync(full, 'utf-8'));
        }
      }
    })(commonSrc);
    log('cwork-common（共享规范 → .cwork/refs/cwork-common/ 按需加载）');
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
      if (!f.startsWith('cwork-')) continue;
      const p = join(target, f);
      if (statSync(p).isFile() && f.endsWith('.md')) {
        rmSync(p);
        log(`删除 ${f}`);
      } else if (statSync(p).isDirectory()) {
        rmSync(p, { recursive: true, force: true });
        log(`删除 ${f}/`);
      }
    }
  }

  // 清理按需参考文件目录
  const refsRoot = join(PROJECT, '.cwork', 'refs');
  if (existsSync(refsRoot)) {
    rmSync(refsRoot, { recursive: true, force: true });
    log('删除 .cwork/refs/');
  }
}

// ── 安装一致性校验（--check） ─────────────────────────────────────────

// 校验当前目录（PROJECT）的 Claude 安装是否与源一致，防止直接改产物导致重装静默丢失：
// ① frontmatter 完整性（name/description）② 按需产物一致性（.cwork/refs/<skill>/SKILL.md）
// ③ 源文件里引用的 .cwork/refs/* 路径真实存在（防断链）④ common 分发一致性
function checkInstall() {
  console.log('🔍 cwork 安装一致性校验（Claude Code）');
  const problems = [];

  const skills = readSkillDirs();

  // ① frontmatter 完整性
  for (const skill of skills) {
    const md = readSkillMd(skill);
    const { meta } = parseFrontmatter(md);
    if (!meta.name) problems.push(`skills/${skill}/SKILL.md 缺少 frontmatter name`);
    if (!meta.description) problems.push(`skills/${skill}/SKILL.md 缺少 frontmatter description`);
  }

  // ② 按需产物一致性（所有技能都按需加载到 .cwork/refs/）
  for (const skill of skills) {
    const skillName = `cwork-${skill}`;
    const md = readSkillMd(skill);
    const { body } = parseFrontmatter(md);
    const files = collectSkillFiles(skill);
    const refFiles = files.filter(f => f.relPath !== 'SKILL.md' && !f.relPath.startsWith('scripts/'));
    let refIndex = '';
    if (refFiles.length > 0) {
      refIndex = buildClaudeRefIndex(skillName);
    }
    const expected = `# ${skillName}\n\n${body}${refIndex}\n`;
    const dest = join(PROJECT, '.cwork', 'refs', skillName, 'SKILL.md');
    if (!existsSync(dest)) {
      problems.push(`按需产物缺失: .cwork/refs/${skillName}/SKILL.md（重装: node bin/cwork.js --tool claude）`);
    } else if (readFileSync(dest, 'utf-8') !== expected) {
      problems.push(`按需产物与源不一致: .cwork/refs/${skillName}/SKILL.md（可能被直接修改，重装会丢失该修改）`);
    }
  }

  // ③ 源文件引用路径存在性（.cwork/refs/...）
  const refPattern = /(\.cwork\/refs\/[\w/-]+?\.md)/g;
  for (const skill of skills) {
    for (const f of collectSkillFiles(skill)) {
      if (f.relPath.startsWith('scripts/')) continue;
      const content = readFileSync(f.path, 'utf-8');
      for (const m of content.matchAll(refPattern)) {
        const refPath = m[1];
        if (!existsSync(join(PROJECT, refPath))) {
          problems.push(`引用断链: skills/${skill}/${f.relPath} 引用 ${refPath} 不存在`);
        }
      }
    }
  }

  // ④ common 分发一致性（现在也按需加载到 .cwork/refs/cwork-common/）
  const commonSrc = join(SKILLS_DIR, COMMON_DIR);
  if (existsSync(commonSrc)) {
    const commonDest = join(PROJECT, '.cwork', 'refs', 'cwork-common');
    for (const entry of readdirSync(commonSrc)) {
      if (entry.endsWith('.bak') || entry.endsWith('.backup')) continue;
      const dest = join(commonDest, entry);
      if (!existsSync(dest)) {
        problems.push(`common 分发缺失: .cwork/refs/cwork-common/${entry}`);
      } else if (readFileSync(dest, 'utf-8') !== readFileSync(join(commonSrc, entry), 'utf-8')) {
        problems.push(`common 分发不一致: .cwork/refs/cwork-common/${entry}`);
      }
    }
  }

  if (problems.length > 0) {
    console.log(`\n❌ 发现 ${problems.length} 个问题：`);
    for (const p of problems) console.log(`  - ${p}`);
    console.log('\n修复：改 skills/ 源文件后重装（node bin/cwork.js --tool claude），不要直接改产物。');
    process.exit(1);
  }
  console.log('✅ 源与产物一致，引用无断链');
  process.exit(0);
}

// ── Claude Code global skills sync ──────────────────────────────────

// ~/.claude/skills/cwork-* 是 Claude Code 全局技能目录（任意项目/窗口可见）。
// 历史上靠手动拷贝维护，会随源仓库更新而漂移（脚本新旧版本混装）。
// 此命令用源仓库整目录覆盖同步：① 凭证等敏感文件照常过滤（与 IDE 安装同一套规则）
// ② 源仓库有凭证时自动软链过去，全局技能同目录即可读到凭证（不依赖 CWORK_HOME fallback）。

let globalSyncCredLinks = 0;

function syncClaudeGlobal() {
  console.log('\n📦 Claude Code 全局技能同步 (~/.claude/skills/)');
  const target = join(HOME, '.claude', 'skills');
  mkdirSync(target, { recursive: true });
  // 凭证软链源优先 CWORK_HOME，缺省回退安装器所在的源仓库（两者同一份凭证）
  const credHome = process.env.CWORK_HOME || ROOT;
  const skills = readSkillDirs();
  for (const skill of skills) {
    const skillName = `cwork-${skill}`;
    const src = join(SKILLS_DIR, skill);
    const dest = join(target, skillName);
    rmSync(dest, { recursive: true, force: true });
    copySkillFiltered(src, dest);
    // 凭证软链：log/config/code/requirement/graf 用 .config.local.sh，data 用 .mcp_config.json
    for (const credRel of ['scripts/.config.local.sh', 'scripts/mcp-client/.mcp_config.json']) {
      const srcCred = join(credHome, 'skills', skill, credRel);
      const destCred = join(dest, credRel);
      if (existsSync(srcCred) && !existsSync(destCred)) {
        try {
          symlinkSync(srcCred, destCred);
          globalSyncCredLinks++;
        } catch (_) { /* 软链失败不阻塞，仍可走 CWORK_HOME fallback */ }
      }
    }
    log(skillName);
  }
  // USAGE_NOTES.md 单文件同步（同 installQoder：skills 根目录文件不在技能目录遍历内）
  const usageSrcC = join(SKILLS_DIR, 'USAGE_NOTES.md');
  if (existsSync(usageSrcC)) writeFileSync(join(target, 'USAGE_NOTES.md'), readFileSync(usageSrcC));
  // 分发共享规范文件（skills/common/ → ~/.claude/skills/cwork-common/，含 git-guard.md 分支防护规范）
  installCommonFiles(target);
}

function unsyncClaudeGlobal() {
  console.log('\n📦 Claude Code 全局技能卸载');
  const target = join(HOME, '.claude', 'skills');
  if (!existsSync(target)) return skip('目录不存在');
  for (const f of readdirSync(target)) {
    if (f.startsWith('cwork-')) {
      rmSync(join(target, f), { recursive: true, force: true });
      log(`删除 ${f}`);
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
- /cwork-deploy — Jenkins + 云效构建部署触发
- /cwork-image — 本地工程/jar 打包镜像 + push registry + 服务端拉起运行
`;
  writeFileSync(join(target, 'cwork.md'), mainContent);
  log('cwork.md (主入口)');

  // per-skill rules
  for (const skill of skills) {
    const skillName = `cwork-${skill}`;
    const md = readSkillMd(skill);
    // 共享规范引用路径按 IDE 替换：源里写 .claude/rules/cwork-common/，Trae 装到 .trae/rules/cwork-common/
    const { body: rawBody } = parseFrontmatter(md);
    const body = rawBody.replaceAll('.claude/rules/cwork-common/', '.trae/rules/cwork-common/');

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

  // 分发共享规范文件（skills/common/ → <rules>/cwork-common/）
  installCommonFiles(target);
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

if (opts.check) {
  // 一致性校验是独立命令，执行完直接退出（不走安装流程）
  checkInstall();
} else if (opts.syncGlobal) {
  // 全局技能同步是独立命令（作用于 ~/.claude/skills/，与项目内安装的 --tool 无关）
  opts.uninstall ? unsyncClaudeGlobal() : syncClaudeGlobal();
} else if (opts.tool && opts.tool !== 'auto') {
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
// --sync-global 已软链凭证时无需提示（软链成功数 > 0 即凭证已就位）
if (!opts.uninstall && !process.env.CWORK_HOME && !(opts.syncGlobal && globalSyncCredLinks > 0)) {
  console.log('\n💡 凭证复用提示：');
  console.log('   cwork-log / cwork-config / cwork-data 在 IDE 安装目录里没有凭证（敏感文件已过滤）。');
  console.log('   在 shell profile（~/.zshrc 或 ~/.bashrc）加一行，让所有 IDE 复用源仓库凭证，无需重复配置：');
  console.log(`     export CWORK_HOME="${ROOT}"`);
}

console.log('\n✅ 完成！');
