# 改动简述

## 改动文件
- `skills/init/scripts/init.sh`
- `skills/init/scripts/init_requirement_workspace.sh`

## 改动内容

### init.sh
- 删除 `get_base_branch` 函数
- 修改 `switch_branch` 函数：
  - 新增暂存逻辑（git stash）
  - 记录暂存信息到 `.git/logs/cwork-stash`
  - 限制基础分支为 master/main
  - 移除强制丢弃逻辑（reset --hard, clean -fd）

### init_requirement_workspace.sh
- 删除 `force_discard_local_changes` 函数
- 删除 `default_base_branch` 函数
- 删除 `--force-discard` 参数
- 修改 `checkout_feature_from_latest_base` 函数：
  - 新增暂存逻辑
  - 限制基础分支为 master/main
  - 移除强制丢弃逻辑
- 修改 `preflight_repo` 函数：移除 fetch（移到 checkout 函数内）
- 简化主循环逻辑

## 恢复方式
用户需要恢复暂存时：
- `git stash list` 查看暂存列表
- `git stash pop` 恢复最近一次暂存

## 推演结论
- 轮次：2
- 发现问题：0 个
- 结论：收敛
