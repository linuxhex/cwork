#!/usr/bin/env node

import { cpSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, statSync, symlinkSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { homedir } from 'node:os';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, '..');
const SKILLS_SRC = resolve(ROOT, 'skills');

const SENTINEL_BEGIN = '<!-- cwork-skills:begin -->';
const SENTINEL_END = '<!-- cwork-skills:end -->';

const TOOL_MAP = {
  codex: {
    name: 'Codex',
    detect: ['.codex'],
    skillsDir: '.codex/skills',
    bootstrap: 'AGENTS.md'
  },
  claude: {
    name: 'Claude Code',
    detect: ['.claude', 'CLAUDE.md'],
    skillsDir: '.claude/skills',
    bootstrap: 'CLAUDE.md'
  },
  cursor: {
    name: 'Cursor',
    detect: ['.cursor', '.cursorrules'],
    skillsDir: '.cursor/skills',
    bootstrap: '.cursor/rules/cwork-skills.md'
  },
  gemini: {
    name: 'Gemini CLI',
    detect: ['.gemini', 'GEMINI.md'],
    skillsDir: '.gemini/skills',
    bootstrap: 'GEMINI.md'
  },

  qoder: {
    name: 'Qoder',
    detect: ['.qoder'],
    skillsDir: '.qoder/skills',
    bootstrap: '.qoder/rules/cwork-skills.md'
  },
  windsurf: {
    name: 'Windsurf',
    detect: ['.windsurf'],
    skillsDir: '.windsurf/skills',
    bootstrap: '.windsurf/rules/cwork-skills.md'
  },
  aider: {
    name: 'Aider',
    detect: ['.aider'],
    skillsDir: '.aider/skills',
    bootstrap: 'CONVENTIONS.md'
  },
  opencode: {
    name: 'OpenCode',
    detect: ['.opencode'],
    skillsDir: '.opencode/skills',
    bootstrap: '.opencode/rules/cwork-skills.md'
  },
  qwen: {
    name: 'Qwen Code',
    detect: ['.qwen'],
    skillsDir: '.qwen/skills',
    bootstrap: '.qwen/rules/cwork-skills.md'
  },
  antigravity: {
    name: 'Antigravity',
    detect: ['.antigravity'],
    skillsDir: '.antigravity/skills',
    bootstrap: '.antigravity/rules.md'
  },
  hermes: {
    name: 'Hermes Agent',
    detect: ['.hermes', 'HERMES.md', '.hermes.md'],
    skillsDir: '.hermes/skills',
    bootstrap: 'HERMES.md'
  },
  trae: {
    name: 'Trae',
    detect: ['.trae'],
    skillsDir: '.trae/skills',
    bootstrap: '.trae/rules/cwork-skills.md'
  },
  kiro: {
    name: 'Kiro',
    detect: ['.kiro'],
    skillsDir: '.kiro/steering',
    bootstrap: '.kiro/steering/cwork-skills.md'
  },
  openclaw: {
    name: 'OpenClaw',
    detect: ['.openclaw'],
    skillsDir: 'skills',
    bootstrap: 'AGENTS.md'
  },
  cline: {
    name: 'Cline',
    detect: ['.cline'],
    skillsDir: '.cline/skills',
    bootstrap: '.cline/rules/cwork-skills.md'
  },
  copilot: {
    name: 'GitHub Copilot',
    detect: ['.github/copilot-instructions.md'],
    skillsDir: '.github/skills',
    bootstrap: '.github/copilot-instructions.md'
  },
};

function parseArgs(argv) {
  const out = {
    project: process.cwd(),
    tool: 'auto',
    uninstall: false,
    dryRun: false,
    mode: 'copy',
    allowHome: false
  };

  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    switch (a) {
      case '--project':
        out.project = argv[++i];
        break;
      case '--tool':
        out.tool = argv[++i];
        break;
      case '--uninstall':
        out.uninstall = true;
        break;
      case '--dry-run':
        out.dryRun = true;
        break;
      case '--mode':
        out.mode = argv[++i];
        break;
      case '--allow-home':
        out.allowHome = true;
        break;
      case '-h':
      case '--help':
        helpAndExit(0);
        break;
      default:
        throw new Error(`unknown arg: ${a}`);
    }
  }

  if (!['copy', 'link'].includes(out.mode)) {
    throw new Error(`invalid --mode: ${out.mode}`);
  }

  return out;
}

function helpAndExit(code) {
  const txt = `\nUsage:\n  cwork-skills [--project <dir>] [--tool auto|codex|claude|cursor|gemini|qoder|windsurf|aider|opencode|qwen|antigravity|hermes|trae|kiro|openclaw|cline|copilot|all] [--mode copy|link] [--allow-home]\n  cwork-skills --uninstall [--project <dir>] [--tool auto|codex|claude|cursor|gemini|qoder|windsurf|aider|opencode|qwen|antigravity|hermes|trae|kiro|openclaw|cline|copilot|all] [--allow-home]\n\nOptions:\n  --project    target project directory (default: cwd)\n  --tool       install target tool (default: auto)\n  --mode       copy or link skills (default: copy)\n  --uninstall  uninstall cwork skills from target\n  --dry-run    print operations only\n  --allow-home allow using HOME as project (needed for ~/.qoder global install)\n`;
  process.stdout.write(txt);
  process.exit(code);
}

function assertProjectDir(projectDir, allowHome = false) {
  if (!existsSync(projectDir) || !statSync(projectDir).isDirectory()) {
    throw new Error(`project dir not found: ${projectDir}`);
  }
  const home = resolve(homedir());
  const proj = resolve(projectDir);
  if (!allowHome && proj === home) {
    throw new Error('refuse to run in HOME directory; use --allow-home if this is intentional');
  }
}

function detectTools(projectDir) {
  const selected = [];
  for (const [key, cfg] of Object.entries(TOOL_MAP)) {
    const hit = cfg.detect.some((marker) => existsSync(resolve(projectDir, marker)));
    if (hit) selected.push(key);
  }
  return selected;
}

function skillDirs() {
  return readdirSync(SKILLS_SRC, { withFileTypes: true })
    .filter((e) => e.isDirectory() && existsSync(join(SKILLS_SRC, e.name, 'SKILL.md')))
    .map((e) => e.name)
    .sort();
}

function patchSkillName(skillMdText, prefixedName) {
  return skillMdText.replace(/^name:\s*.+$/m, `name: ${prefixedName}`);
}

function appendOrCreateBootstrap(filePath, content, dryRun) {
  const wrapped = `${SENTINEL_BEGIN}\n${content.trim()}\n${SENTINEL_END}\n`;
  if (dryRun) return;

  const dir = dirname(filePath);
  mkdirSync(dir, { recursive: true });

  if (!existsSync(filePath)) {
    writeFileSync(filePath, wrapped, 'utf8');
    return;
  }

  const existing = readFileSync(filePath, 'utf8');
  if (existing.includes(SENTINEL_BEGIN) && existing.includes(SENTINEL_END)) {
    const begin = existing.indexOf(SENTINEL_BEGIN);
    const end = existing.indexOf(SENTINEL_END);
    if (begin >= 0 && end >= begin) {
      const after = end + SENTINEL_END.length;
      const merged = (existing.slice(0, begin).replace(/\s+$/, '') + '\n\n' + wrapped + '\n' + existing.slice(after).replace(/^\s+/, '')).replace(/\n{3,}/g, '\n\n');
      writeFileSync(filePath, merged.trim() + '\n', 'utf8');
      return;
    }
  }

  const merged = existing.replace(/\s+$/, '') + '\n\n' + wrapped;
  writeFileSync(filePath, merged, 'utf8');
}

function removeBootstrapSection(filePath, dryRun) {
  if (!existsSync(filePath)) return;
  const existing = readFileSync(filePath, 'utf8');
  const begin = existing.indexOf(SENTINEL_BEGIN);
  const end = existing.indexOf(SENTINEL_END);
  if (begin < 0 || end < 0 || end < begin) return;

  const after = end + SENTINEL_END.length;
  const cleaned = (existing.slice(0, begin) + existing.slice(after)).replace(/\n{3,}/g, '\n\n').trim();
  if (dryRun) return;
  if (cleaned.length === 0) {
    rmSync(filePath, { force: true });
  } else {
    writeFileSync(filePath, cleaned + '\n', 'utf8');
  }
}

function installToTool(projectDir, toolKey, opts) {
  const cfg = TOOL_MAP[toolKey];
  const targetSkillsRoot = resolve(projectDir, cfg.skillsDir);
  const skills = skillDirs();

  const installed = [];

  for (const s of skills) {
    const src = resolve(SKILLS_SRC, s);
    const prefixed = `cwork-${s}`;
    const dest = resolve(targetSkillsRoot, prefixed);

    installed.push(dest);
    console.log(`  + ${cfg.name}: ${prefixed}`);
    if (opts.dryRun) continue;

    mkdirSync(targetSkillsRoot, { recursive: true });
    rmSync(dest, { recursive: true, force: true });

    if (opts.mode === 'link') {
      const linkType = process.platform === 'win32' ? 'junction' : 'dir';
      symlinkSync(src, dest, linkType);
    } else {
      cpSync(src, dest, { recursive: true, force: true });
    }

    const skillMd = resolve(dest, 'SKILL.md');
    const txt = readFileSync(skillMd, 'utf8');
    writeFileSync(skillMd, patchSkillName(txt, prefixed), 'utf8');
  }

  const bootstrapPath = resolve(projectDir, cfg.bootstrap);
  const bootstrap = `# cwork 技能已安装\n\n## 对话语言硬约束\n- 默认使用中文对话、中文分析、中文结论。\n- 除命令/路径/参数名外，不使用英文整句。\n\n## init 阶段硬约束\n- 必须先执行 cwork-init。\n- 必须逐步中文引导并按顺序提问：\n  1) 需求名称是什么\n  2) 涉及哪些工程服务目录（绝对路径）\n  3) 统一创建/切换的分支名称是什么\n  4) 是否允许强制回退未提交改动（是/否）\n- 以上未完成前，不得进入后续技能。\n\n## 主流程技能\n- cwork-init\n- cwork-brainstorming\n- cwork-writing-plans\n- cwork-executing-plans\n- cwork-loop-refined\n- cwork-commit-code\n\n## 支撑技能\n- cwork-workflow-runner\n- cwork-subagent-driven-development\n- cwork-verification-before-completion`;

  appendOrCreateBootstrap(bootstrapPath, bootstrap, opts.dryRun);

  const manifestPath = resolve(projectDir, '.cwork', `installed-${toolKey}.json`);
  const manifest = {
    tool: toolKey,
    installedAt: new Date().toISOString(),
    skills: installed,
    bootstrap: bootstrapPath
  };

  if (!opts.dryRun) {
    mkdirSync(dirname(manifestPath), { recursive: true });
    writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + '\n', 'utf8');
  }
}

function uninstallFromTool(projectDir, toolKey, opts) {
  const cfg = TOOL_MAP[toolKey];
  const targetSkillsRoot = resolve(projectDir, cfg.skillsDir);
  if (existsSync(targetSkillsRoot)) {
    for (const e of readdirSync(targetSkillsRoot, { withFileTypes: true })) {
      if (!e.isDirectory()) continue;
      if (!e.name.startsWith('cwork-')) continue;
      const p = resolve(targetSkillsRoot, e.name);
      console.log(`  - ${cfg.name}: ${e.name}`);
      if (!opts.dryRun) rmSync(p, { recursive: true, force: true });
    }
  }

  const bootstrapPath = resolve(projectDir, cfg.bootstrap);
  removeBootstrapSection(bootstrapPath, opts.dryRun);

  const manifestPath = resolve(projectDir, '.cwork', `installed-${toolKey}.json`);
  if (!opts.dryRun) rmSync(manifestPath, { force: true });
}

function main() {
  try {
    const args = parseArgs(process.argv.slice(2));
    const projectDir = resolve(args.project);
    assertProjectDir(projectDir, args.allowHome);

    let tools = [];
    if (args.tool === 'all') {
      tools = Object.keys(TOOL_MAP);
    } else if (args.tool === 'auto') {
      tools = detectTools(projectDir);
      if (tools.length === 0) tools = ['codex'];
    } else {
      if (!TOOL_MAP[args.tool]) throw new Error(`unsupported tool: ${args.tool}`);
      tools = [args.tool];
    }

    console.log(`cwork-skills ${args.uninstall ? 'uninstall' : 'install'} -> ${projectDir}`);
    console.log(`tools: ${tools.join(', ')}`);

    for (const t of tools) {
      if (args.uninstall) {
        uninstallFromTool(projectDir, t, args);
      } else {
        installToTool(projectDir, t, args);
      }
    }

    console.log(args.uninstall ? 'UNINSTALL_DONE' : 'INSTALL_DONE');
  } catch (err) {
    console.error(`ERROR: ${err.message || err}`);
    process.exit(1);
  }
}

main();
