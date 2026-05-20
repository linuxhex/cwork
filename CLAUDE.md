<!-- cwork-skills:begin -->
# cwork 技能已安装

## 对话语言硬约束
- 默认使用中文对话、中文分析、中文结论。
- 除命令/路径/参数名外，不使用英文整句。
- 若出现 en-us/English 偏好提示，仍直接中文继续，不输出英文解释。

## init 阶段硬约束
- 必须先执行 cwork-init。
- 必须逐步中文引导并按顺序提问：
  1) 需求名称是什么
  2) 涉及哪些工程服务目录（绝对路径）
  3) 统一创建/切换的分支名称是什么
  4) 以上信息确认后，是否执行初始化与分支切换（是/否）
- 分支切换与强制回退只允许一次最终确认，不做二次确认。
- 以上未完成前，不得进入后续技能。
- init 完成后，必须直接调起 cwork-implement，禁止再问"是否继续下一步"。

## 阶段自动衔接硬约束
- cwork-init 结束后自动进入 cwork-implement。
- cwork-implement 结束后自动进入 cwork-commit。
- 全流程禁止让用户手动发起下一 skill。

## 主流程技能（对外暴露）
- cwork-init：初始化工作区，对话式收集信息，自动查找工程路径
- cwork-implement：需求分析 + 编写计划 + 执行计划 + 推演收敛（内部包含 brainstorming、writing-plans、executing-plans、loop-refined）
- cwork-commit：推演收敛后自动提交，不确认

## 分支命名规则
- 必须以 `feature_`、`hotfix_`、`bugfix_`、`refactor_` 开头
- 允许字母、数字和下划线
- 示例：`feature_userExport`、`hotfix_loginError`

## 内部技能（不对外暴露）
- cwork-brainstorming：需求分析（cwork-implement 内部调用）
- cwork-writing-plans：编写计划（cwork-implement 内部调用）
- cwork-executing-plans：执行计划（cwork-implement 内部调用）
- cwork-loop-refined：推演收敛（cwork-implement 内部调用）
- cwork-subagent-driven-development：多工程并行执行
- cwork-verification-before-completion：完成前验证

## 状态机
详见 `skills/workflow-state-machine.md`
<!-- cwork-skills:end -->