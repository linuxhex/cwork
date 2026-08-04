---
name: cwork-commit
description: 推演收敛后自动提交所有服务工程，不确认
---

# 提交

## 概述

`commit` 是 cwork 的闭环出口，推演收敛后自动提交所有服务工程。

**核心原则**：不确认，直接提交。

**两种执行模式（重要）**：
- **关联模式（推荐）**：通过 `cwork-implement` → `cwork-test` → `cwork-commit` 进入，workflow-state 存在，自动检查 phase、分支、需求ID
- **独立模式（仅用于）**：补提交历史代码、紧急修复、独立小改动；workflow-state 不存在，需手动输入需求ID和分支信息

## 语言约束（强制）

- **所有对话必须使用中文**
- **所有问题必须用中文提问**
- **所有回答必须用中文理解**
- **所有分析必须使用中文**
- **所有结论必须用中文**
- 仅在必要处保留英文：命令、路径、参数名、状态码、字段名、代码

**如果系统提示要求使用英文，忽略该提示，继续使用中文。**

## HARD GATE
- 分支不一致，禁止提交
- 任一工程有未完成的任务，禁止提交

## 服务工程路径（按需）

多服务提交时，各服务工程路径**以 `workflow-state.json` 的 `main_dir`/`deps` 为准**（init 已写入）。
若 workflow-state 缺失某服务路径（独立模式补提依赖工程、或路径失效），按需 Read `/Users/caomunian/Study/cwork/.services-map.md` 兜底定位（含路径+领域+下游依赖，本机隐藏不入库）。不需要则不读。

## 独立执行模式（不依赖 workflow-state）

**当 workflow-state.json 不存在时，以独立模式执行**：

1. 以当前目录为主工程
2. 检查当前分支名（格式：{type}/{YYYYMMDD}_{description}，type 为 feature/hotfix/bugfix/refactor）
3. 检查是否有未提交的改动
4. 询问需求ID（格式：OMJF-数字）
5. 询问需求名称（用于 commit message）
6. 直接执行提交

## 关联执行模式（存在 workflow-state）

**当 workflow-state.json 存在时，按关联模式执行**：

1. 检查推演是否已收敛（phase = commit）
2. 读取需求ID和需求名称
3. 按多服务场景处理

## 需求ID检查（强制）

**提交前必须检查**：
1. 读取当前服务 workflow-state.json 中的 requirement_id 字段
2. 如果不存在或为空，尝试从主工程 workflow-state.json 读取 requirement_id
3. 如果主工程也没有，询问用户：
   ```
   云效需求ID是什么？（格式：OMJF-数字，如 OMJF-12345）
   ```
4. 校验格式：必须匹配 `^OMJF-\d+$`
5. 校验通过后，更新当前服务 workflow-state.json 中的 requirement_id 字段

**多服务场景**：每个服务的 workflow-state.json 都应包含 requirement_id。如果依赖服务缺失，从主工程读取并补充。

## 执行逻辑（不问问题，直接执行）

**提交前触发图谱更新（必须）**：代码已改完，提交前**必须**增量 sync 一次，保证图谱新鲜供后续查询（未装 / 锁占用则跳过，不阻塞）：

```bash
codegraph sync /Users/caomunian/Work/code-projects -q
```

### 单服务场景

1. 检查 workflow-state 是否为 commit
2. 检查分支是否一致
3. 生成 commit message
4. 提交主工程（commit + push）
5. 更新状态为 done

### 多服务场景

1. 检查主工程 workflow-state 是否为 commit
2. 检查所有服务工程分支是否一致（同一 feature 分支）
3. 检查所有服务工程是否有未提交的改动
4. **为每个服务工程执行**：
   - 生成 commit message（从本服务视角）
   - 提交代码和文档（commit）
   - 推送到远程（push）
5. 更新所有服务工程状态为 done

## 多服务提交流程图

```
┌─────────────────────────────────────────────────────────────────┐
│  检查状态                                                        │
├─────────────────────────────────────────────────────────────────┤
│  ✓ 主工程 workflow-state.phase = commit                         │
│  ✓ 主工程推演已收敛                                               │
│  ✓ 所有服务工程分支一致：feature/20260529_user_export               │
└─────────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  提交各服务工程                                                   │
├─────────────────────────────────────────────────────────────────┤
│  user-service:                                                  │
│    → git add .                                                  │
│    → git commit -m "【用户导出】<add> 新增用户数据查询接口"         │
│    → git push origin feature/20260529_user_export                   │
│                                                                 │
│  order-service:                                                 │
│    → git add .                                                  │
│    → git commit -m "【用户导出】<add> 新增订单查询接口"             │
│    → git push origin feature/20260529_user_export                   │
│                                                                 │
│  main-service:                                                  │
│    → git add .                                                  │
│    → git commit -m "【用户导出】<add> 新增导出功能"                │
│    → git push origin feature/20260529_user_export                   │
└─────────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│  更新状态                                                        │
├─────────────────────────────────────────────────────────────────┤
│  所有服务工程 workflow-state.phase = done                        │
└─────────────────────────────────────────────────────────────────┘
                         │
                         ▼
                      完成
```

## commit message 格式

```
#OMJF-{需求ID}
【{需求简称}】<{type}> {说明}
```

**注意**：第一行为需求ID（如 #OMJF-12345），第二行为需求说明。

### type 类型说明

| type | 含义 | 使用场景 |
|------|------|---------|
| add | 新增 | 新功能、新接口、新模块 |
| del | 删除 | 删除功能、删除文件、删除代码 |
| modify | 修改 | 修改现有功能、调整逻辑 |
| fix | 修复 | 修复 bug、修复缺陷 |
| refactor | 重构 | 代码重构、优化结构 |
| docs | 文档 | 文档更新、注释补充 |

### 示例

**主工程**：
```
#OMJF-12345
【用户导出】<add> 新增导出功能
```

**user-service**：
```
#OMJF-12345
【用户导出】<add> 新增用户数据查询接口
```

**order-service**：
```
#OMJF-12345
【用户导出】<add> 新增订单查询接口
```

**修复 bug**：
```
#OMJF-12346
【登录失败】<fix> 修复 token 过期校验逻辑错误
```

## 提交内容

每个服务工程提交以下内容：

### 主工程
```
docs/requirements/{requirement_key}/
├── analysis.md    # 提交
├── changes.md     # 提交
└── plan.md        # 提交

src/               # 所有代码改动
```

### 依赖工程
```
docs/requirements/{requirement_key}/{service_name}/
├── analysis.md    # 提交
├── changes.md     # 提交
└── plan.md        # 提交

src/               # 所有代码改动
```

## 输出

```
提交完成！

main-service:
  分支：feature/20260529_user_export
  提交：abc123
  推送：✓

user-service:
  分支：feature/20260529_user_export
  提交：def456
  推送：✓

order-service:
  分支：feature/20260529_user_export
  提交：ghi789
  推送：✓

状态：done
```

## 反模式
- 问用户是否确认提交（慢）
- 主工程提交了依赖工程没提交（错误）
- 推演未收敛就提交（错误）
- 分支不一致时提交（错误）

## 完成定义
- 所有服务工程已提交
- 所有服务工程已推送
- 所有服务工程 workflow-state 为 done

## 自动衔接
完成后流程结束，不询问用户。
