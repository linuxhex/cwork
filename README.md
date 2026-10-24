<div align="center">

# cwork

**让 AI 编程助手像一支研发团队一样交付微服务需求**

多工程并行 · 对话式需求分析 · 推演收敛替代测试 · 全流程自动衔接

[![License](https://img.shields.io/badge/license-PolyForm%20NC--1.0-blue)](./LICENSE.md)
[![Node](https://img.shields.io/badge/node-%E2%89%A520-green)](./package.json)
[![Tools](https://img.shields.io/badge/support-16%20AI%20tools-orange)](#安装)
[![Skills](https://img.shields.io/badge/skills-18-8A2BE2)](#技能清单)

*An agentic workflow skill suite that turns AI coding assistants into a microservice delivery team — multi-repo parallel agents, dialogue-driven requirement analysis, and logic-deduction convergence instead of unit tests.*

</div>

---

## 为什么需要 cwork？

现在的 AI 编程工具很擅长"改一个文件"，但真实业务需求往往是这样的：

```
一个需求 → 牵扯 3 个微服务 → 每个服务要切分支、独立分析、契约对齐
        → 改完要部署验证 → 查日志、查监控、查数仓佐证 → 最后统一提交
```

手动驱动 AI 一步步做，上下文会断、服务间会漏、验证会糊弄。**cwork 把这套工程交付流程固化成技能体系**，让 Claude Code / Codex / Cursor 等 16 种 AI 工具按标准流水线自动跑完全程。

<div align="center">
  <img src="vibe_images/cwork-comparison_1789294615170_5aea7d02.png" alt="cwork 对比" width="720">
</div>

## 核心特点

| 特点 | 说明 |
|------|------|
| 🗣️ 对话式需求分析 | 决策树式深度追问，每次一个问题、带推荐答案，获得批准后才动手 |
| 🔀 多工程并行处理 | 每个依赖工程开独立 agent 并行执行，各服务从自己的视角独立分析、独立记录 |
| 🧠 推演收敛替代测试 | 逻辑推演多轮自查（主路径/异常/契约/边界/并发/一致性），发现问题自动修复 |
| 🎯 目标驱动自主闭环 | cwork-do 迭代循环「实现→部署→实测→收敛评估」，双证据收敛后才提交 |
| 🔗 阶段自动衔接 | init → implement → (test) → commit 全链路自动流转，无需手动触发 |
| 🇨🇳 全中文对话 | 分析、提问、结论全中文 |

## 整体架构

<div align="center">
  <img src="vibe_images/cwork-architecture_1789294630606_2de8ab7f.png" alt="cwork 架构" width="720">
</div>

### 技能全景

<div align="center">
  <img src="vibe_images/cwork-tools_1789294657008_41de2f2f.png" alt="cwork 工具集" width="720">
</div>

**主流程技能（用户可见）**

```
cwork-init      → 对话式初始化（多服务场景：查路径、校验、切分支）
cwork-implement → 需求分析 + 编写计划 + 执行计划 + 推演收敛
cwork-do        → 目标驱动自主工作流（迭代循环直到收敛，双证据验收）
cwork-bug       → 快速修复 bug（定位 → 修复 → 验证 → 提交）
cwork-test      → 页面自动化测试（Web / 小程序自动识别，条件触发）
cwork-commit    → 统一提交所有工程（分支一致性校验 + commit + push）
cwork-article   → 微信公众号文章写作（排版/封面/配图/直写编辑器）
```

**研发现场技能（排查与佐证）**

```
cwork-log         → SLS 日志 + ARMS 链路查询，定位根因
cwork-graf        → Grafana 监控查询（64 个仪表盘 + PromQL 即时查询）
cwork-data        → Doris 数仓只读 SQL，核对业务数据佐证根因
cwork-config      → Nacos 多环境配置查询与差异对比
cwork-deploy      → Jenkins / 云效构建部署触发（dev/test/uat/prod）
cwork-code        → 代码仓库只读查询（CodeUp + GitLab，优先 codegraph 索引）
cwork-requirement → 云效 Projex 需求查询，实现前核对需求范围
cwork-image       → 本地工程打 Docker 镜像 + push registry + 拉起运行
cwork-doc         → 根据代码改动生成技术方案文档
```

## 快速开始

```bash
# 1. 安装（自动识别已装的 AI 工具）
node /path/to/cwork/bin/cwork.js --tool auto

# 2. 在你的工程里启动
/cwork-do        # 一站式：从需求到部署验证全流程
# 或
/cwork-implement # 标准实现流程
```

**支持工具**：`claude` / `codex` / `cursor` / `gemini` / `qoder` / `windsurf` / `aider` / `opencode` / `qwen` / `antigravity` / `hermes` / `trae` / `kiro` / `openclaw` / `cline` / `copilot`

安装后技能名会加 `cwork-` 前缀，避免与已有 skills 冲突。卸载：`node bin/cwork.js --uninstall --tool <tool>`。

## 它是怎么工作的

### 自主工作流（cwork-do）—— 核心亮点

```
阶段 1  目标确认      深度追问：工作类型 / 内容 / 环境 / 涉及服务
                      → 固化验收标准（收敛锚点，用户确认）
        ↓
阶段 2  迭代循环 ×N   执行（implement/bug）→ 部署（deploy + log）
                      → 实测（test / log / data 分层验证）
                      → 收敛评估（测试结果 + 理论评估 双证据对照验收标准）
                        ├─ 收敛 → 阶段 3
                        └─ 未收敛 → 差距分析 → 下一轮修正
        ↓
阶段 3  收敛收口      cwork-commit 统一提交
阶段 4  结果输出      目标达成度 + 迭代演进

⚠️ 停止条件：收敛是唯一正常出口；10 轮保底 + 发散检测提前停止
```

### 多服务需求拆分

cwork 会站在每个服务的定位角度，独立理解需求、独立规划改动：

```
主服务视角：      我提供导出入口，调用 user-service 取用户数据、order-service 取订单
user-service 视角：主服务需要用户数据，我新增 /user/data 接口
order-service 视角：主服务需要订单数据，我新增 /order/list 接口
```

所有服务切同一 feature 分支、各写各的 analysis/plan/changes 文档、契约字段强制对齐，最后由 commit 统一校验提交。

### 推演收敛覆盖面

| 检查项 | 说明 |
|--------|------|
| 主路径闭环 | 正常流程是否完整执行 |
| 异常处理 | 超时、失败、重试是否处理 |
| 契约一致 | 跨工程接口字段是否匹配 |
| 边界条件 | 空数据、大数据量、特殊字符等 |
| 并发防重 | 重复请求是否防重 |
| 数据一致性 | 跨工程数据是否一致 |

## 使用示例

```
用户: /cwork-init

Claude: 需求名称是什么？
用户: 用户导出

Claude: 分支名称是什么？（以 feature_ 开头，如 feature_userExport）
用户: feature_userExport

Claude: 依赖工程目录名有哪些？（多个用逗号分隔，没有则回车跳过）
用户: user-service,order-service

Claude: [自动初始化 3 个工程路径 + 切分支 ✓ → 进入 implement]

Claude: 这个导出功能的核心目的是什么？
A. 导出用户个人数据（合规要求）
B. 导出用户消费记录（运营需求）
C. 导出用户订单数据（用户自助）
用户: A

...（逐步追问 → 方案确认 → 多 agent 并行实现 → 推演收敛 → 自动提交）

提交完成！
main-service:  feature_userExport  abc123 【用户导出】<add> 新增导出功能     push ✓
user-service:  feature_userExport  def456 【用户导出】<add> 用户数据查询接口 push ✓
order-service: feature_userExport  ghi789 【用户导出】<add> 订单查询接口    push ✓
```

## 安装详情

```bash
# 自动识别已安装工具
node /path/to/cwork/bin/cwork.js --tool auto

# 指定工具
node bin/cwork.js --tool codex

# 校验安装
node bin/cwork.js --check
```

## 文档结构

主工程 `docs/requirements/{requirement_key}/`：

| 文件 | 说明 | 是否提交 |
|------|------|----------|
| `workflow-state.json` | 内部状态 | ❌ |
| `analysis.md` | 需求分析文档 | ✅ |
| `plan.md` | 实现计划 | ✅ |
| `changes.md` | 改动简述 | ✅ |

依赖工程在 `docs/requirements/{requirement_key}/{service_name}/` 下有各自独立的一份。

## 关键规则

1. **需求分析必须完成**：未获得用户批准前不会执行实现
2. **分支命名严格**：必须 `feature_` / `hotfix_` / `bugfix_` / `refactor_` 开头
3. **计划禁止占位符**：不能写"待定"、"TODO"
4. **每个工程独立记录**：从各自视角记录分析和改动
5. **implement 过程中禁止提交代码**：所有提交由 cwork-commit 统一处理
6. **git 安全护栏**：upstream 只能指向 `origin/<同名分支>`，禁止裸 push/pull

## 适用场景

✅ **适合**：微服务/多仓库工程、有明确的分支与提交规范、需要部署后实测验证的团队研发流程

⚠️ **注意**：研发现场技能（log / graf / data / config / deploy / requirement）对接的是阿里云系平台（SLS、ARMS、Nacos、Doris、Jenkins、云效、CodeUp），需要在 skills 中配置你自己的环境地址与凭证后才能使用；主流程技能（init / implement / do / bug / commit / test）不依赖任何内部平台，开箱即用。

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=linuxhex/cwork&type=Date)](https://star-history.com/#linuxhex/cwork&Date)

## License

[PolyForm Noncommercial 1.0.0](./LICENSE.md) —— 欢迎个人与团队内部使用、学习、二次开发，商业授权请联系作者。
