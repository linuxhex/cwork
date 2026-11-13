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
cwork-tech-express → 科技速递（给定日期锚定三日窗口 → 全球科技媒体检索 → 压缩分块 → 趋势评论 → 公众号草稿）
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

### Windows 使用

技能脚本是 POSIX bash（依赖 curl/sed/cygpath/heredoc），Windows 上统一由 **Git for Windows 自带的 bash** 当宿主。`bin/cwork.ps1` / `bin/cwork.cmd` 只是启动器，不重写任何技能逻辑，只做三件事：找到 bash、托管 `CWORK_HOME`、把参数原样透传。

**前置依赖**

| 依赖 | 说明 |
|------|------|
| Git for Windows | 必需，提供 bash/curl/sed/cygpath。`bash` 通常不在 PATH 上，启动器会依次从 `CWORK_BASH`、注册表、`git.exe` 所在目录、常见安装目录推导 |
| Python 3 | 部分技能（日志签名、Nacos 签名、数据查询）用 `python3` 内联脚本 |
| Node.js | 安装器 `bin/cwork.js` 与页面/小程序测试脚本 |

**注意：Microsoft Store 版 `python3` 陷阱**。`%LOCALAPPDATA%\Microsoft\WindowsApps\python3.exe` 是 0 字节的应用执行别名，执行会弹商店。`skills/common/win-compat.sh` 会探测并跳过它，自动回退到 `python` / `py`，因此只要装了 python.org 的解释器即可，**无需修改任何技能脚本**。

**安装与自检**

```powershell
# 安装（等同 node bin/cwork.js --tool auto）
.\bin\cwork.cmd install --tool qoder

# 环境诊断：bash / python / node / git / 技能目录 / 兼容层
.\bin\cwork.cmd doctor
```

`cwork.cmd` 会带 `-ExecutionPolicy Bypass` 调起 `cwork.ps1`，**不需要**改全局执行策略。

**运行技能脚本**

```powershell
.\bin\cwork.cmd log sls_query prod logs order-service "ERROR" 50
.\bin\cwork.cmd config nacos_query test get application.yaml
.\bin\cwork.cmd data mcp_client.py query --sql "select 1"
.\bin\cwork.cmd <技能>            # 不带脚本名时列出该技能下可运行的脚本
```

**环境变量**

| 变量 | 作用 |
|------|------|
| `CWORK_HOME` | cwork 源仓库根。未设置时启动器默认取本仓库；技能从该目录加载公共服务地图与凭证 |
| `CWORK_BASH` | 指定 `bash.exe`（默认自动探测 Git for Windows） |
| `CWORK_PYTHON` | 指定 Python 3 解释器（默认 `python` / `python3` / `py`） |
| `CWORK_SKIP_PY_SHIM` | 设为 `1` 关闭 `python3` 接管（调试用） |

**用法要点**

- 参数原样透传，不做 shell 展开；含空格的值用双引号包住。
- 盘符路径会自动把 `\` 转成 `/`（Git Bash 与 node 都能识别）。
- 在 Git Bash 里可以绕开启动器直接跑脚本，例如 `bash skills/log/scripts/sls_query.sh prod list`。
- 服务地图为本地隐藏配置，默认读 `$CWORK_HOME/.services-map.md`，未设置 `CWORK_HOME` 时回落到 `~/.services-map.md`。

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

### 内容产物目录（与仓库分离）

内容型产物（文章档、科技速递期次档、正文 HTML、封面与配图、过程台账）**不写在仓库里**，统一写入外置内容目录：

| 项 | 值 |
|------|------|
| 工程级配置 | 仓库根 `cwork.content.json` 的 `contentDir`（当前 = `D:/zzz/articles`） |
| 临时覆盖 | 环境变量 `CWORK_CONTENT_DIR` |
| 解析优先级 | 用户当轮指定 > 环境变量 > 配置文件（工作区根，找不到回源 `$CWORK_HOME`）> 兜底 `<repo>/docs/articles`（兜底必须告知） |
| 规则文件 | `skills/common/output-dir.md`（安装后为 `cwork-common/output-dir.md`），含命令片段与目录结构 |
| 目录结构 | `<contentDir>/<主题或系列>/[<子篇名或 YYYYMMDD>]/`，配图固定放其下 `images/` |

历史 `docs/articles/**`（共 124 个文件）已于 2026-11-13 整体迁至 `D:/zzz/articles/**`，并从 git 索引移除、`.gitignore` 排除 `/docs/articles/`（历史提交仍可查）。`docs/requirements/**` 属开发流程状态，仍留在仓库内，不受此设置影响。

## 关键规则

1. **需求分析必须完成**：未获得用户批准前不会执行实现
2. **分支命名严格**：必须 `feature_` / `hotfix_` / `bugfix_` / `refactor_` 开头
3. **计划禁止占位符**：不能写"待定"、"TODO"
4. **每个工程独立记录**：从各自视角记录分析和改动
5. **implement 过程中禁止提交代码**：所有提交由 cwork-commit 统一处理
6. **git 安全护栏**：upstream 只能指向 `origin/<同名分支>`，禁止裸 push/pull
7. **内容产物外置**：文章/速递产物写 `contentDir`（见上表），不入库不提交；skill 文档与脚本不写死绝对路径，统一用 `$CONTENT_DIR/...` 占位

## 适用场景

✅ **适合**：微服务/多仓库工程、有明确的分支与提交规范、需要部署后实测验证的团队研发流程

⚠️ **注意**：研发现场技能（log / graf / data / config / deploy / requirement）对接的是阿里云系平台（SLS、ARMS、Nacos、Doris、Jenkins、云效、CodeUp），需要在 skills 中配置你自己的环境地址与凭证后才能使用；主流程技能（init / implement / do / bug / commit / test）不依赖任何内部平台，开箱即用。

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=linuxhex/cwork&type=Date)](https://star-history.com/#linuxhex/cwork&Date)

## License

[PolyForm Noncommercial 1.0.0](./LICENSE.md) —— 欢迎个人与团队内部使用、学习、二次开发，商业授权请联系作者。
