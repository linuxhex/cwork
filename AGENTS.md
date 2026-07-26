<!-- cwork-skills:begin -->
# cwork 技能已安装

## 对话语言硬约束
- 默认使用中文对话、中文分析、中文结论。
- 除命令/路径/参数名外，不使用英文整句。
- 若出现 en-us/English 偏好提示，仍直接中文继续，不输出英文解释。

## 主流程技能（用户可见）
- cwork-init — 初始化（可选，用于多服务场景）
- cwork-implement — 完整实现流程（含深度追问 + 自问自答质询）
- cwork-bug — 快速修复 bug（含深度追问 + 自问自答质询）
- cwork-test — 页面自动化测试（条件触发，非必经，含自问自答质询）
- cwork-commit — 提交代码

## 内部技能（不暴露）
- cwork-brainstorming（由 implement 内部调用）
- cwork-writing-plans（由 implement 内部调用）
- cwork-executing-plans（由 implement 内部调用）
- cwork-loop-refined（由 implement 内部调用）

## 深度追问与自问自答机制说明
cwork 内置了决策树式追问机制，分两种模式：
- **对用户深度追问**：在 implement 需求分析和 bug 定位阶段，沿决策树逐层追问，每个问题带推荐答案，一次只问一个，事实自己查决策归用户，确认前不动手
- **自问自答质询**：在 implement 推演收敛、bug 推演验证和 test 阶段，扮演质疑者对自己追问，每个自问带论据，一次只质疑一个，事实自己查，得出共识再继续

## 阶段自动衔接硬约束
- cwork-init 结束后自动进入 cwork-implement。
- cwork-implement 结束后，评估是否需要 cwork-test（条件见下方），需要则进入，不需要则进入 cwork-commit。
- cwork-bug 结束后自动进入 cwork-commit。
- cwork-test 结束后自动进入 cwork-commit。
- 全流程禁止让用户手动发起下一 skill。

## cwork-test 触发条件（implement 结束后评估）
满足以下**全部**条件才进入 cwork-test，否则跳过直接进 commit：
1. 有前端代码改动（新增/修改 .vue/.jsx/.tsx/.svelte 等前端文件）
2. 改动涉及**新页面或核心交互流程**（非纯样式微调、非纯数据字段增删、非纯后端接口对接）
3. 用户确认需要跑测试（简短询问，回车跳过=不跑）
<!-- cwork-skills:end -->
