# cwork 安装说明

## 1. 安装
在你的目标项目根目录执行：

```bash
node /path/to/cwork/bin/cwork.js --tool auto
```

脚本会自动识别工具并安装到对应路径：
- Codex: `.codex/skills/`
- Claude Code: `.claude/skills/`
- Cursor: `.cursor/skills/`
- Gemini CLI: `.gemini/skills/`
- Qoder: `.qoder/skills/`（全局安装建议用 `--project "$HOME" --allow-home`）

安装后的 skill 名称带 `cwork-` 前缀，避免冲突。

## 2. 卸载

```bash
node /path/to/cwork/bin/cwork.js --uninstall --tool auto
```

## 3. 常见参数
- `--project <dir>`：指定项目目录
- `--tool auto|codex|claude|cursor|gemini|qoder|all`
- `--mode copy|link`（`link` 使用符号链接）
- `--dry-run`
