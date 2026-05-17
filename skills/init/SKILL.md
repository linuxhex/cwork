---
name: init
description: 对话式初始化，自动查找工程路径
---

# 初始化

## 概述

`init` 是 cwork 的唯一入口，对话式收集信息，自动查找工程路径。

**核心原则**：
- 对话式，快速（2 个问题）
- 用户只需给目录名，自动向上查找完整路径
- 收集完直接执行，不确认

## 语言约束
- 对话、分析、结论、提示默认使用中文
- 仅在必要处保留英文：命令、路径、参数名、状态码、字段名

## HARD GATE
- 找不到工程路径，禁止执行
- 任一仓库不是 git 仓库，禁止执行
- 分支名不合法，禁止执行

## 对话流程（逐个提问，回答完再问下一个）

**主工程**：当前目录，不需要问。

### 问题 1
```
需求名称是什么？
```
等待用户回答后，再问问题 2。

### 问题 2
```
分支名称是什么？（以 feature_ 开头，如 feature_userExport）
```
等待用户回答后，再问问题 3。

### 问题 3
```
依赖工程目录名有哪些？（多个用逗号分隔，没有则回车跳过）
```
等待用户回答后，直接执行，不确认。

### 执行（收集完直接执行，不确认）

1. 从当前目录向上查找工程完整路径
2. 校验所有工程
3. 切换分支
4. 写 workflow-state.json
5. 自动进入 implement

## 路径查找逻辑

用户输入目录名，脚本自动向上查找：

```
当前目录: /Users/dev/project/main/src/service

用户输入: user-service

查找顺序:
1. 同级目录: ./user-service
2. 上级目录: ../user-service
3. 上上级目录: ../../user-service
4. 上上上级目录: ../../../user-service
5. 找到 git 仓库则返回，找不到则报错
```

## 分支命名规则
- 必须以 `feature_` 开头
- 仅允许字母和下划线
- 示例：`feature_userExport`、`feature_chargeFlow`

## 产物

主工程 `docs/requirements/{key}/`：
- `workflow-state.json` — 内部状态，不提交
- `analysis.md` — 需求分析文档，提交
- `changes.md` — 改动简述，提交

依赖工程 `docs/requirements/{key}/`：
- `workflow-state.json` — 内部状态，不提交
- `analysis.md` — 需求分析文档（从本工程视角），提交
- `changes.md` — 改动简述，提交

**.gitignore 配置**：
```
docs/requirements/*/workflow-state.json
```

## 反模式
- 让用户输入完整路径（麻烦）
- 逐条确认每个信息（慢）
- 输出大量中间文档（慢）

## 完成定义
- 所有工程在同名 feature 分支
- workflow-state.json 已写入
- 自动进入 implement

## 自动衔接
完成后自动调起 `implement`，不询问用户。
