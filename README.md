# cwork

面向多工程联动研发的自动化 workflow skills。

目标：让需求从初始化到最终提交形成闭环，并且全过程自动记录、自动拆分、自动推进状态。

## Skills
- `init`
  - 初始化主工程 + 依赖工程
  - 多仓统一分支切换/新建
  - 自动生成并拆分需求文档体系
- `brainstorming`
  - 需求澄清、边界划分、风险识别
  - 强制输出可执行验收标准
- `writing-plans`
  - 产出跨工程可执行计划
  - 明确任务顺序、DoD、回滚策略
- `executing-plans`
  - 按计划实施
  - 强制进入 `loop-refined` 多轮收敛
- `loop-refined`
  - 大范围逻辑推演 -> 修复 -> 再推演
  - 默认作为质量门禁替代新增单元测试
- `commit-code`
  - 多工程统一提交
  - 自动推进状态到 `done`

## 固定执行顺序
1. `init`
2. `brainstorming`
3. `writing-plans`
4. `executing-plans`
5. `loop-refined`（在 `executing-plans` 内多轮执行）
6. `commit-code`

## 关键规则
- `init` 是唯一起点，禁止跳过。
- 所有工程必须切换到同一 feature 分支。
- 所有阶段都通过 `phase_checkpoint.sh` 推进。
- 文档必须同时在主工程和依赖工程落地。
- 默认不要求新增单元测试，质量收敛由 `loop-refined` 承担。

## 初始化命令

```bash
bash skills/init/scripts/init_requirement_workspace.sh \
  --main-dir <主工程绝对路径> \
  --deps <逗号分隔依赖工程绝对路径> \
  --feature-branch <feature_...> \
  --requirement-key <lowercase_underscore_key> \
  --requirement-title "<需求标题>" \
  --force-discard true
```

## 分支命名约束
- 必须 `feature_` 开头
- 仅字母与下划线
- 禁止数字、中文、短横线
- 下划线后每段：`^[a-z][A-Za-z]*$`

## 文档结构
主工程：`docs/requirements/<key>/`
- `00-context.md`
- `01-analysis.md`
- `02-plan.md`
- `03-changes.md`
- `04-process-record.md`
- `05-split-actions.md`
- `dependencies/*`
- `process/*`

依赖工程：`docs/requirements/<key>/`
- `00-repo-context.md`
- `01-repo-analysis.md`
- `02-repo-plan.md`
- `03-repo-changes.md`
- `10-repo-perspective-custom.md`（人工视角，不覆盖）
- `11-repo-contract-custom.md`（人工视角，不覆盖）
- `98-main-doc-links.md`
- `99-dispatch-receipt.md`
- `commit-allowlist.txt`

每工程全局标记：
- `docs/requirements/ACTIVE_REQUIREMENT.md`
- `docs/requirements/ACTIVE_REQUIREMENT_HISTORY.md`

## 阶段检查点

```bash
bash skills/init/scripts/phase_checkpoint.sh \
  --main-dir <主工程绝对路径> \
  --deps <逗号分隔依赖工程绝对路径> \
  --requirement-key <需求key> \
  --phase <brainstorming|writing-plans|executing-plans|loop-refined|commit-code> \
  --owner <agent-id>
```

阶段检查点会自动完成：
- 多工程加锁
- 文档同步拆分
- 状态推进
- 已完成认领归档

## 自动化治理脚本
- `skills/init/scripts/workflow_state.sh`
  - 状态机与版本校验（CAS）
- `skills/init/scripts/workflow_lock.sh`
  - 并发锁与 TTL 续租
- `skills/init/scripts/agent_claims.sh`
  - 任务认领与归档
- `skills/init/scripts/sync_requirement_docs.sh`
  - 文档拆分与依赖工程同步
- `skills/init/scripts/phase_checkpoint.sh`
  - 检查点统一入口

## 提交命令

```bash
bash skills/commit-code/scripts/commit_all_related_repos.sh \
  --repos <逗号分隔绝对路径> \
  --requirement-short "<需求简称>" \
  --requirement-key <需求key> \
  --commit-type <add|del|modify|fix|refactor|docs> \
  --commit-detail "<详细说明>" \
  [--allowlist-file <路径>] \
  [--allow-all-changes]
```

提交信息格式：
- `【需求简称】<type> 详细说明`
- `type` 允许：`add|del|modify|fix|refactor|docs`
