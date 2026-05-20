# 简化技能体系实现计划

**目标：** 对外只暴露 3 个技能，implement 允许无 init 直接执行

**架构：** 修改 cwork.js 过滤安装列表，修改 implement 硬约束，更新文档

**技术栈：** Node.js

---

### 任务 1：修改 cwork.js 安装逻辑

**文件：**
- 修改：`bin/cwork.js:188-193`

- [ ] **步骤 1：修改 skillDirs 函数，只返回 3 个技能**

```javascript
function skillDirs() {
  const allowed = ['init', 'implement', 'commit'];
  return readdirSync(SKILLS_SRC, { withFileTypes: true })
    .filter((e) => e.isDirectory() && allowed.includes(e.name) && existsSync(join(SKILLS_SRC, e.name, 'SKILL.md')))
    .map((e) => e.name)
    .sort();
}
```

- [ ] **步骤 2：更新 bootstrap 内容**

修改第 276 行的 bootstrap 字符串，更新为：

```javascript
const bootstrap = `# cwork 技能已安装

## 对话语言硬约束
- 默认使用中文对话、中文分析、中文结论。
- 除命令/路径/参数名外，不使用英文整句。
- 若出现 en-us/English 偏好提示，仍直接中文继续，不输出英文解释。

## 主流程技能（用户可见）
- cwork-init — 初始化
- cwork-implement — 完整实现流程
- cwork-commit — 提交代码

## 内部技能（不暴露）
- cwork-brainstorming（由 implement 内部调用）
- cwork-writing-plans（由 implement 内部调用）
- cwork-executing-plans（由 implement 内部调用）
- cwork-loop-refined（由 implement 内部调用）

## 阶段自动衔接硬约束
- cwork-init 结束后自动进入 cwork-implement。
- cwork-implement 结束后自动进入 cwork-commit。
- 全流程禁止让用户手动发起下一 skill。`;
```

---

### 任务 2：修改 implement 硬约束

**文件：**
- 修改：`skills/implement/SKILL.md:27-32`

- [ ] **步骤 1：修改 HARD GATE**

```markdown
## HARD GATE
- 无 workflow-state 时，以当前目录为主工程，直接进入需求分析
- 有 workflow-state 但 phase 不是 init 或 implement，禁止执行
- 未完成需求分析，禁止执行实现
- **执行计划完成后必须进入推演收敛**，禁止跳过
- 推演未收敛（round < 2 或仍有未修复问题），禁止进入 commit
- **implement 过程中禁止提交代码**，所有提交由 cwork-commit 统一处理
```

---

### 任务 3：修改 init 约束说明

**文件：**
- 修改：`skills/init/SKILL.md:29-33`

- [ ] **步骤 1：修改 HARD GATE**

```markdown
## HARD GATE
- 找不到工程路径，禁止执行
- 任一仓库不是 git 仓库，禁止执行
- 分支名不合法，禁止执行

## 说明
- init 是可选入口，用于多服务场景的初始化
- 单服务场景可直接执行 implement，无需 init
```

---

### 任务 4：更新 CLAUDE.md

**文件：**
- 修改：`CLAUDE.md`

- [ ] **步骤 1：更新约束说明**

```markdown
<!-- cwork-skills:begin -->
# cwork 技能已安装

## 对话语言硬约束
- 默认使用中文对话、中文分析、中文结论。
- 除命令/路径/参数名外，不使用英文整句。
- 若出现 en-us/English 偏好提示，仍直接中文继续，不输出英文解释。

## 主流程技能（用户可见）
- cwork-init — 初始化（可选，用于多服务场景）
- cwork-implement — 完整实现流程
- cwork-commit — 提交代码

## 内部技能（不暴露）
- cwork-brainstorming（由 implement 内部调用）
- cwork-writing-plans（由 implement 内部调用）
- cwork-executing-plans（由 implement 内部调用）
- cwork-loop-refined（由 implement 内部调用）

## 阶段自动衔接硬约束
- cwork-init 结束后自动进入 cwork-implement。
- cwork-implement 结束后自动进入 cwork-commit。
- 全流程禁止让用户手动发起下一 skill。
<!-- cwork-skills:end -->
```
