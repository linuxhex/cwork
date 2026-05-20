# 需求分析

## 背景
cwork 技能体系对外暴露太多技能，用户只需关注 3 个主流程技能即可。

## 目标
1. 对外只暴露 3 个技能：init、implement、commit
2. implement 允许无 init 直接执行（单服务场景）

## 改动范围
- `bin/cwork.js`
- `skills/implement/SKILL.md`
- `skills/init/SKILL.md`

## 改动内容

### 1. 修改 cwork.js 安装逻辑
`skillDirs` 函数只返回 3 个技能：
```javascript
function skillDirs() {
  const allowed = ['init', 'implement', 'commit'];
  return readdirSync(SKILLS_SRC, { withFileTypes: true })
    .filter((e) => e.isDirectory() && allowed.includes(e.name) && existsSync(join(SKILLS_SRC, e.name, 'SKILL.md')))
    .map((e) => e.name)
    .sort();
}
```

### 2. 修改 implement 硬约束
允许无 workflow-state 时直接进入需求分析：
```markdown
## HARD GATE
- 无 workflow-state 时，以当前目录为主工程，直接进入需求分析
- 有 workflow-state 但 phase 不是 init 或 implement，禁止执行
- 未完成需求分析，禁止执行实现
- ...
```

### 3. 修改 init 约束说明
添加说明：init 是可选入口，单服务场景可直接执行 implement。

## 验收标准
- 安装后只暴露 3 个技能
- 无 init 时可直接执行 implement
- 文档说明清晰
