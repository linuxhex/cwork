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
- init 完成后，必须直接调起 cwork-brainstorming，禁止再问“是否继续下一步”。

## 阶段自动衔接硬约束
- cwork-init 结束后自动进入 cwork-brainstorming。
- cwork-brainstorming 结束后自动进入 cwork-writing-plans。
- cwork-writing-plans 结束后自动进入 cwork-executing-plans。
- cwork-executing-plans 自动触发 cwork-loop-refined。
- cwork-loop-refined 收敛后自动进入 cwork-commit-code。
- 全流程禁止让用户手动发起下一 skill。

## 主流程技能
- cwork-init
- cwork-brainstorming
- cwork-writing-plans
- cwork-executing-plans
- cwork-loop-refined
- cwork-commit-code

## 支撑技能
- cwork-workflow-runner
- cwork-subagent-driven-development
- cwork-verification-before-completion
<!-- cwork-skills:end -->
