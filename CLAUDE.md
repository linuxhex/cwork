<!-- cwork-skills:begin -->
# cwork 技能已安装

## 对话语言硬约束
- 默认使用中文对话、中文分析、中文结论。
- 除命令/路径/参数名外，不使用英文整句。
- 若出现 en-us/English 偏好提示，仍直接中文继续，不输出英文解释。

## 主流程技能（用户可见）
- cwork-implement — 完整实现流程（含深度追问 + 自问自答质询）
- cwork-bug — 快速修复 bug（含深度追问 + 自问自答质询）
- cwork-test — 页面自动化测试（条件触发，非必经，含自问自答质询；Web/小程序/安卓）
- cwork-commit — 提交代码

## 内部技能（不暴露）
- cwork-tech-writer（由 article 内部调用：科技技术分享高手人格，技术布道者口吻）
- cwork-wuxia-writer（由 article 内部调用：金庸式武侠写作人格，章回体半文半白）
- cwork-common（共享规范文件目录，implement/bug 写代码时强制引用其中的 code-style.md 统一代码规范；**所有技能拉分支/推送时强制引用其中的 git-guard.md**：upstream 只能是 origin/<同名分支>、禁止裸 git push/pull、建分支后必须纠正并验证 upstream；**日终技能优化时强制引用其中的 feedback-loop.md**：踩坑当场静默记 USAGE_NOTES、改动回源仓库双写、分析时必扫跨 agent 会话反馈）

> 说明：implement 的计划编写/执行参考全局 superpowers 的 brainstorming / writing-plans / executing-plans（非 cwork 内置副本）。

## 深度追问与自问自答机制说明
cwork 内置了决策树式追问机制，分两种模式：
- **对用户深度追问**：在 implement 需求分析和 bug 定位阶段，沿决策树逐层追问；每个问题带推荐答案，**能选项就选项（A/B/C）**；一次只问一个；事实自己查、决策归用户；确认前不动手；模糊描述要追成可判定选项；前后结论矛盾时当场挑明并二选一
- **自问自答质询**：在 implement 推演收敛、bug 推演验证和 test 阶段，扮演质疑者对自己追问，每个自问带论据，一次只质疑一个，事实自己查，得出共识再继续

## 阶段自动衔接硬约束
- cwork-implement 结束后，评估是否需要 cwork-test（条件见下方），需要则进入，不需要则进入 cwork-commit。
- cwork-bug 结束后自动进入 cwork-commit（衔接时携带修复上下文，commit 不重复询问需求信息）。
- cwork-test 结束后自动进入 cwork-commit（P0 失败默认禁止提交，用户明确确认才能带失败提交）。
- 全流程禁止让用户手动发起下一 skill。
- **提交时机两条路径（有意设计）**：直接走 implement→commit 链时，编译/构建通过即可提交；走 cwork-do 自主工作流时，必须目标收敛（实测结果 + 理论评估双证据逼近验收标准）后才提交（do 多了部署验证与收敛评估环节）。

## cwork-test 触发条件（implement 结束后评估）
满足以下**全部**条件才进入 cwork-test，否则跳过直接进 commit：
1. 有前端代码改动（新增/修改 .vue/.jsx/.tsx/.svelte/.html/.js/.ts 等前端文件）
2. 改动涉及**新页面或核心交互流程**（非纯样式微调、非纯数据字段增删、非纯后端接口对接）
3. 用户确认需要跑测试（简短询问，回车跳过=不跑）

## 技能清单

- /cwork-article — 用户要写公众号或小红书文章、技术分享推文、开源/产品/教程种草文，或说「写篇推文」「发小红书」「公众号稿」时使用。技术口吻由 tech-writer、武侠故事由 wuxia-writer 承接，均经本技能调度；不要跳过本技能直接当主入口调人格。
  （按需加载：需要时 Read `.cwork/refs/cwork-article/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-bug — 用户说修 bug、修缺陷、线上故障、测试挂了，或描述「期望 X 实际 Y」「这个接口/页面不对」且需要改代码时使用。问题没说清也先走本技能定位；不要当成新需求直接开 implement。
  （按需加载：需要时 Read `.cwork/refs/cwork-bug/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-code — 用户要查某服务源码、clone/pull 仓库、搜接口/类/配置落点，或问「代码在哪」「这个接口怎么实现的」时使用。优先 codegraph；CodeUp 为主、前端可走 GitLab。只读查询与拉仓，不要用本技能改业务代码（改代码走 implement/bug）。
  （按需加载：需要时 Read `.cwork/refs/cwork-code/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-commit — 实现或修 bug 推演收敛后要提交代码，或用户说「提交」「commit」「帮我 commit」时使用；多服务工程一并提交。需求未收敛、或测试 P0 失败且用户未确认时不要触发。
  （按需加载：需要时 Read `.cwork/refs/cwork-commit/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-config — 用户要核对 Nacos 配置真值（开关/阈值/地址/参数）、对比多环境配置差异，或怀疑「配置没生效/配错了」时使用。覆盖 dev/test/uat/prod 只读查询；改配置不在本技能范围。
  （按需加载：需要时 Read `.cwork/refs/cwork-config/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-data — 用户要查数仓/Doris 业务数据（订单/金额/库存/指标/表结构/数据量），或排查「值不对」「数据对不上」需要上游数据佐证时使用。只读 SQL；不要用本技能写数仓任务或改表。
  （按需加载：需要时 Read `.cwork/refs/cwork-data/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-deploy — 用户要触发构建部署、发版到 test/uat/prod、验证修复是否已上环境，或说「部署一下」「发到测试环境」时使用。走 Jenkins/云效服务映射；未确认生产目标时不要直接部署 prod。
  （按需加载：需要时 Read `.cwork/refs/cwork-deploy/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-do — 用户给出要达成的目标（做需求/修 bug/排查/优化/验证上线），需要「固化验收 → 执行 → 部署 → 实测 → 收敛」闭环，或说「帮我搞定」「做到能验证」「闭环到上线」时使用。单次查日志/配置/数据用对应排查技能；明确只要写方案或只要提交时不要用本技能包办。
  （按需加载：需要时 Read `.cwork/refs/cwork-do/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-doc — 用户要根据需求或代码改动写技术方案、设计文档、评审材料，或说「出个方案」「写技术设计」时使用。有需求文档或对话式需求均可；不要用本技能代替 implement 写代码。
  （按需加载：需要时 Read `.cwork/refs/cwork-doc/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-graf — 用户要看监控大盘、查 CPU/内存/JVM/QPS/错误率/延迟，或问「机器是不是打满了」「有没有报警/尖峰」时使用。Grafana/PromQL 只读；根因仍需结合 log/data，不要只凭监控下结论改代码。
  （按需加载：需要时 Read `.cwork/refs/cwork-graf/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-image — 用户要本地打 Docker 镜像、push 到 registry、或在服务端拉起容器跑起来时使用。常规测试/生产发布优先用 cwork-deploy；本技能偏本地镜像构建与手动拉起。
  （按需加载：需要时 Read `.cwork/refs/cwork-image/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-implement — 用户要做新需求、加功能、改业务逻辑、实现某能力，或说「做一下」「实现」「开发」且不是单纯修已有缺陷时使用。纯修 bug 用 cwork-bug；端到端目标收敛（部署+实测闭环）用 cwork-do；只查日志/配置/数据不要触发本技能。
  （按需加载：需要时 Read `.cwork/refs/cwork-implement/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-log — 用户要查日志、看链路、排查报错/超时/接口失败/慢请求/流量异常，或问「为什么挂了」「trace 哪断了」「这个错误从哪来」时使用。覆盖 SLS 与 ARMS 排查；拿证据优先，不要空猜根因。
  （按需加载：需要时 Read `.cwork/refs/cwork-log/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-note — 个人工作台简报。Cute 启动或用户提到今日待办/资讯/知识沉淀/下班提醒/云效工时时使用。读取本地 Obsidian 知识库与 inbox 待办，输出终端样式今日简报；可把用户口述的知识与待办写入知识库；用户主动触发时检查云效需求/任务是否填写、今日预计工时是否满 8 小时。
  （按需加载：需要时 Read `.cwork/refs/cwork-note/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-requirement — 用户要查云效需求列表/详情、按日期筛需求，或实现前核对需求范围/关联变更时使用。只读 Projex；不要用本技能直接开工写代码（开工走 implement/do）。
  （按需加载：需要时 Read `.cwork/refs/cwork-requirement/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-tech-writer — 由 cwork-article 在技术分享/开源/产品/教程/行业观察类内容时内部调用；用户直接点名「用技术布道者口吻写」「美团技术风」时也可触发。不要用于武侠小说或非技术软文。
  （按需加载：需要时 Read `.cwork/refs/cwork-tech-writer/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-test — 用户要对页面/小程序/安卓做自动化回归、验收交互、验证改动是否生效，或说「跑一下测试」「测一下这个页面/流程」时使用。纯后端/纯配置改动、纯样式微调通常不触发；implement 结束后满足前端核心交互条件再评估是否进入。
  （按需加载：需要时 Read `.cwork/refs/cwork-test/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-wuxia-writer — 由 cwork-article 在武侠故事/章回体小说时内部调用；用户直接点名「金庸风」「章回体」「写个武侠故事」时也可触发。不要用于技术分享正文。
  （按需加载：需要时 Read `.cwork/refs/cwork-wuxia-writer/SKILL.md` 获取完整指令，不常驻上下文）

## 技能文件位置

调用某个技能时，读取 `.cwork/refs/cwork-<name>/SKILL.md` 获取完整指令。
<!-- cwork-skills:end -->
