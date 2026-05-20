# 状态机定义

## 状态列表

| 状态 | 说明 | 允许的下一步 |
|------|------|-------------|
| `init` | 初始化阶段 | `brainstorming` |
| `brainstorming` | 需求分析阶段 | `writing-plans` |
| `writing-plans` | 编写计划阶段 | `executing-plans` |
| `executing-plans` | 执行计划阶段 | `loop-refined` |
| `loop-refined` | 推演收敛阶段 | `commit` |
| `commit` | 提交阶段 | `done` |
| `done` | 完成 | - |
| `failed` | 失败 | 任意状态（恢复） |
| `blocked` | 阻塞 | 当前状态（解除阻塞后） |

## 状态转换条件

```
init → brainstorming:
  - 所有工程路径已确认
  - 分支已切换
  - workflow-state.json 已写入

brainstorming → writing-plans:
  - 需求分析文档已写入
  - 用户已批准设计

writing-plans → executing-plans:
  - 实现计划已写入
  - 所有工程计划已自检

executing-plans → loop-refined:
  - 所有任务已执行
  - 所有工程 changes.md 已更新

loop-refined → commit:
  - 推演已收敛（连续 2 轮无问题）
  - 推演结论已记录

commit → done:
  - 所有工程已提交
  - 所有工程已推送（如配置）
```

## 异常状态

### failed

触发条件：
- 某个步骤执行失败
- 计划无法继续执行

处理方式：
1. 记录失败原因到 workflow-state.json
2. 通知用户
3. 等待用户决定：重试 / 跳过 / 终止

### blocked

触发条件：
- 依赖缺失
- 需要用户输入
- 外部服务不可用

处理方式：
1. 记录阻塞原因到 workflow-state.json
2. 通知用户
3. 等待解除阻塞后继续

## workflow-state.json 结构

```json
{
  "phase": "executing-plans",
  "requirement_key": "用户导出",
  "feature_branch": "feature_userExport",
  "main_dir": "/path/to/main-service",
  "deps": [
    {
      "name": "user-service",
      "path": "/path/to/user-service"
    },
    {
      "name": "order-service",
      "path": "/path/to/order-service"
    }
  ],
  "phase_history": [
    {
      "phase": "init",
      "started_at": "2026-05-20 10:00:00",
      "completed_at": "2026-05-20 10:01:00"
    },
    {
      "phase": "brainstorming",
      "started_at": "2026-05-20 10:01:00",
      "completed_at": "2026-05-20 10:15:00"
    }
  ],
  "current_phase_started_at": "2026-05-20 10:30:00",
  "updated_at": "2026-05-20 10:35:00",
  "status": "in_progress",
  "error": null,
  "blocked_reason": null
}
```

## 恢复机制

如果 workflow-state.json 存在且 phase 不是 done：

1. 读取 workflow-state.json
2. 检查当前 phase
3. 询问用户是否继续：
   - 继续：从当前 phase 继续
   - 重新开始：删除 workflow-state.json，重新 init
   - 查看：显示当前状态和历史
