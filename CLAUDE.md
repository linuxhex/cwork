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

## 技能清单

- /cwork-bug — 快速修复 bug。问题明确时直接修复，问题不明确时先沟通定位（可调用 cwork-log 查日志），然后修复 + 验证 + 提交。适用于：修复线上 bug、修复测试问题、修复代码缺陷。
- /cwork-code — 代码仓库只读查询 + clone/pull + codegraph 触发，支持 CodeUp（主平台）+ GitLab（前端 fallback），优先使用 codegraph 索引查找代码
- /cwork-commit — 推演收敛后自动提交所有服务工程，不确认
- /cwork-config — Nacos 配置只读查询，对话式查多环境(dev/test/uat/prod)的 Nacos 配置内容/清单/差异，排查问题时核对某服务某环境的配置真值（开关/阈值/地址/参数）
- /cwork-data — 数仓数据查询，对话式查 Doris 数仓（internal/hive/JDBC catalog）跑只读 SQL 查业务数据/表结构/指标/数据量，自带 SQL 前置校验，排查问题时核对订单/金额/库存/数据量佐证根因
- /cwork-doc — 根据代码改动生成技术方案文档（两种模式：已有需求文档 / 对话式需求分析）
- /cwork-implement — 需求分析（对话式）+ 编写计划 + 执行计划 + 推演收敛
- /cwork-init — 对话式初始化，自动查找工程路径，多服务分支切换
- /cwork-log — 找日志分析问题。查 SLS 日志 + ARMS 链路，定位问题根因。适用于：问题排查、性能分析、流量分析、链路追踪。
- /cwork-requirement — 云效需求只读查询，对话式查云效 Projex 项目需求列表/详情/按日期筛选，实现前核对需求范围、关联变更
- /cwork-test — 页面自动化测试，自动识别 Web/小程序项目，分别走 ego-browser 或 miniprogram-automator 链路

## 技能文件位置

调用某个技能时，读取 `.claude/rules/cwork-<name>.md` 获取完整指令。
<!-- cwork-skills:end -->
