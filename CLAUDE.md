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
- cwork-tech-writer（由 article 内部调用：科技技术分享高手人格，技术布道者口吻）
- cwork-wuxia-writer（由 article 内部调用：金庸式武侠写作人格，章回体半文半白）
- cwork-common（共享规范文件目录，implement/bug 写代码时强制引用其中的 code-style.md 统一代码规范；**所有技能拉分支/推送时强制引用其中的 git-guard.md**：upstream 只能是 origin/<同名分支>、禁止裸 git push/pull、建分支后必须纠正并验证 upstream）

## 深度追问与自问自答机制说明
cwork 内置了决策树式追问机制，分两种模式：
- **对用户深度追问**：在 implement 需求分析和 bug 定位阶段，沿决策树逐层追问，每个问题带推荐答案，一次只问一个，事实自己查决策归用户，确认前不动手
- **自问自答质询**：在 implement 推演收敛、bug 推演验证和 test 阶段，扮演质疑者对自己追问，每个自问带论据，一次只质疑一个，事实自己查，得出共识再继续

## 阶段自动衔接硬约束
- cwork-init 结束后自动进入 cwork-implement。
- cwork-implement 结束后，评估是否需要 cwork-test（条件见下方），需要则进入，不需要则进入 cwork-commit。
- cwork-bug 结束后自动进入 cwork-commit（衔接时携带修复上下文，commit 不重复询问需求信息）。
- cwork-test 结束后自动进入 cwork-commit（P0 失败默认禁止提交，用户明确确认才能带失败提交）。
- 全流程禁止让用户手动发起下一 skill。
- **提交时机两条路径（有意设计）**：直接走 implement→commit 链时，编译/构建通过即可提交；走 cwork-do 自主工作流时，必须目标收敛（实测结果 + 理论评估双证据逼近验收标准）后才提交（do 多了部署验证与收敛评估环节）。

## cwork-test 触发条件（implement 结束后评估）
满足以下**全部**条件才进入 cwork-test，否则跳过直接进 commit：
1. 有前端代码改动（新增/修改 .vue/.jsx/.tsx/.svelte 等前端文件）
2. 改动涉及**新页面或核心交互流程**（非纯样式微调、非纯数据字段增删、非纯后端接口对接）
3. 用户确认需要跑测试（简短询问，回车跳过=不跑）


## 全局内容产物目录（contentDir，对所有 skill 生效）
- 所有**内容型产物**（公众号/头条文章档、科技速递期次档、正文 HTML、封面与配图、过程台账）统一写入外置目录，**不再落在仓库 `docs/` 下**；解析规则与目录结构见 `skills/common/output-dir.md`。
- 工程级配置：仓库根 `cwork.content.json` 的 `contentDir`（当前 = `D:/zzz/articles`）；临时改指向用环境变量 `CWORK_CONTENT_DIR`。优先级：用户当轮指定 > 环境变量 > 配置文件 > 兜底 `<repo>/docs/articles`（兜底必须告知用户）。
- 硬约束：**禁止在 skill 文档、脚本注释、命令示例里写死绝对路径**，一律用 `$CONTENT_DIR/...` 或 `<内容目录>/...` 占位；写入前回显一次实际落点；外置产物不入 git，不 `git add`、不提交。
- 例外（不动）：`docs/requirements/**` 是开发流程状态（需求目录、`workflow-state.json`、测试 `plan.json/result.json`、`tech-design.md`），仍留在仓库内走原有相对路径；`docs/cwork-introduction.md` 是仓库文档，同样不动。
- 历史迁移：`docs/articles/**` 已于 2026-11-13 整体迁至 `D:/zzz/articles/**` 并从 git 移除；任何旧文档、记忆、脚本注释里读到 `docs/articles/...` 都按新位置解析。

## 技能清单

- /cwork-article — article
  （按需加载：需要时 Read `.cwork/refs/cwork-article/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-bug — bug
  （按需加载：需要时 Read `.cwork/refs/cwork-bug/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-code — code
  （按需加载：需要时 Read `.cwork/refs/cwork-code/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-commit — commit
  （按需加载：需要时 Read `.cwork/refs/cwork-commit/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-config — config
  （按需加载：需要时 Read `.cwork/refs/cwork-config/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-data — data
  （按需加载：需要时 Read `.cwork/refs/cwork-data/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-deploy — deploy
  （按需加载：需要时 Read `.cwork/refs/cwork-deploy/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-do — do
  （按需加载：需要时 Read `.cwork/refs/cwork-do/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-doc — doc
  （按需加载：需要时 Read `.cwork/refs/cwork-doc/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-graf — graf
  （按需加载：需要时 Read `.cwork/refs/cwork-graf/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-image — image
  （按需加载：需要时 Read `.cwork/refs/cwork-image/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-implement — implement
  （按需加载：需要时 Read `.cwork/refs/cwork-implement/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-init — init
  （按需加载：需要时 Read `.cwork/refs/cwork-init/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-log — log
  （按需加载：需要时 Read `.cwork/refs/cwork-log/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-requirement — requirement
  （按需加载：需要时 Read `.cwork/refs/cwork-requirement/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-tech-express — tech-express
  （按需加载：需要时 Read `.cwork/refs/cwork-tech-express/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-tech-writer — tech-writer
  （按需加载：需要时 Read `.cwork/refs/cwork-tech-writer/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-test — test
  （按需加载：需要时 Read `.cwork/refs/cwork-test/SKILL.md` 获取完整指令，不常驻上下文）
- /cwork-wuxia-writer — wuxia-writer
  （按需加载：需要时 Read `.cwork/refs/cwork-wuxia-writer/SKILL.md` 获取完整指令，不常驻上下文）

## 技能文件位置

调用某个技能时，读取 `.cwork/refs/cwork-<name>/SKILL.md` 获取完整指令。
<!-- cwork-skills:end -->
