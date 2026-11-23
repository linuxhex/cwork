# Agent 工坊 · 情报源、检索式与证据分级

本文件是阶段 1 的执行清单。原则：**一手优先、数字带口径、链接必须能打开**。

---

## 一、三个主题域的源矩阵

### 1.1 架构（Agent architecture：编排 / 记忆 / 工具 / 多 Agent）

| 类别 | 入口 | 取什么 |
|------|------|--------|
| GitHub 趋势 | `github.com/trending`（daily / weekly）、`topic:ai-agents`、`topic:llm-agent`、`topic:multi-agent`、`topic:agent-framework` | 新项目与周增速；记录抓取日期 |
| 代表框架 | LangGraph、AutoGen / AG2、CrewAI、OpenAI Agents SDK、Google ADK、Microsoft Agent Framework、Dify、n8n、OpenHands、SWE-agent | 定位差异、编排模型、状态与记忆机制 |
| 终端 Agent | Claude Code、Codex CLI、Gemini CLI、Aider 等 | 工具调用、权限模型、上下文管理 |
| 协议与规范 | MCP（modelcontextprotocol.io）、A2A（Agent2Agent）、OpenAI Apps SDK | 能力边界、鉴权、生态现状 |
| 论文 | arXiv（cs.AI / cs.SE / cs.MA）、官方技术报告 | 方法、限制、实验设置 |

### 1.2 Harness（评测脚手架与基准）

| 类别 | 入口 | 取什么 |
|------|------|--------|
| 编码类基准 | SWE-bench / SWE-bench Verified、Terminal-Bench、MLE-bench、CORE-Bench | 任务构造、通过判据、当前榜单 |
| 通用 Agent 基准 | GAIA、AgentBench、τ-bench（tau-bench）、BrowseComp | 环境、工具、评分方式 |
| 计算机使用 | OSWorld、WebArena | 环境隔离、可复现性 |
| harness 工程 | inspect_ai（UK AISI）、lm-evaluation-harness（EleutherAI）、SWE-bench harness、OpenHands runtime、Terminal-Bench harness | 评测器实现、并发与成本、抗作弊设计 |
| 榜单页 | 各基准官方 leaderboard、论文附录表 | **分数必须带：榜单期次 + 模型 + 预算 + 指标定义** |

> harness 类选题的价值不在「谁第一」，而在「这个 harness 到底测什么、测不到什么、跑一次要多少钱」。

### 1.3 Skill（技能包规范与生态）

| 类别 | 入口 | 取什么 |
|------|------|--------|
| 规范 | Anthropic Agent Skills（`SKILL.md` + frontmatter + `references/` + `scripts/`）、各家 skills/rules 规范 | 渐进式披露、触发描述、资源边界、权限 |
| 生态 | `awesome-claude-skills`、`awesome-mcp-servers`、skills 市场（Qoder / Cursor / 社区） | 真实使用场景、质量分层、安装风险 |
| 工具与插件 | MCP server（文件、数据库、浏览器、IM）、function calling 方案 | 工具粒度、鉴权、失败模式 |
| 对比 | rules / prompt 模板 / RAG / skill 包的边界 | 什么时候该用 skill，什么时候不该 |

### 1.4 社区声音（只用来看争议，不当证据）

- Hacker News（`news.ycombinator.com`，搜项目名）
- Reddit `r/LocalLLaMA`、`r/MachineLearning`
- GitHub Issues / Discussions（找真实失败点，比 README 诚实）
- 作者 X / 博客 / 播客文字稿（标「作者自述」）

### 1.5 二手媒体

科技媒体与聚合号只做**线索**：看到报道后必须回到仓库/文档/论文核实，核实不到就降级表述。

---

## 二、检索式模板

同一批并行发出；年份/月份按当期写，禁止用「最新 / 今天」这类相对词。

```
# GitHub 项目发现
site:github.com "agent" stars:>1000 pushed:>2026-10-01
site:github.com topic:ai-agents
site:github.com "SKILL.md" agent skills

# 架构
"agent architecture" 2026 arxiv
"multi-agent" orchestration comparison 2026
"model context protocol" security 2026

# harness / 基准
"terminal-bench" leaderboard 2026
"swe-bench verified" results 2026
"agent harness" design evaluation 2026
"tau-bench" OR "gaia benchmark" 2026

# skill 生态
"agent skills" specification 2026
"progressive disclosure" skills agent
"awesome-mcp-servers" 2026

# 社区争议
site:news.ycombinator.com <项目名>
site:github.com <owner>/<repo> issues
```

### GitHub API（优先于网页抓取）

```bash
gh api repos/<owner>/<repo> --jq '{stars:.stargazers_count,forks:.forks_count,pushed:.pushed_at,license:.license.spdx_id,desc:.description}'
gh api repos/<owner>/<repo>/releases/latest --jq '{tag:.tag_name,date:.published_at}'
gh api repos/<owner>/<repo>/commits?per_page=1 --jq '.[0].commit.author.date'
```

未登录时 `gh` 有 60 次/小时限流；超限就 `WebFetch` 打开 `https://api.github.com/repos/<owner>/<repo>`，仍不行则打开仓库页人工读，并标注「人工读取，抓取于 <日期>」。

---

## 三、核实与降级规则

| 项 | 核实到 | 核实不到 |
|----|--------|----------|
| Star / Fork | 仓库页或 API，记录抓取日期 | 不写具体数字，写「star 量级约 x 千/万（未核实）」并尽量换材料 |
| 版本 / 日期 | Release、CHANGELOG、论文日期 | 写「未获取」，不得猜 |
| 许可证 | LICENSE 文件或仓库页标识 | **不得讨论商用可行性**，改写「需自行确认许可」 |
| 榜单分数 | 榜单页/论文表，带 harness、模型、预算、指标 | 只写「在该榜单有结果」或不写 |
| 架构描述 | 源码/官方架构文档 | 可用社区解读，但必须标「据 <来源> 解读」 |
| 性能收益 | 自己 L2/L3 实测，或论文同口径数据 | 标「作者自述 / 未验证」，不得换算成自己的结论 |

**冲突处理**：同一指标多版本 → 按「官方仓库/API > 官方文档 > 论文 > 社区 > 媒体」取舍，弃用项与理由记入 `research.md` 的「冲突与取舍」，不取平均、不折中。

---

## 四、证据等级（全 skill 统一，正文必须标注）

| 等级 | 定义 | 允许的表述 |
|------|------|------------|
| **L3** | 用固定 harness 在本地/自建环境跑出可复现结果（含版本、模型、预算、任务子集） | 「实测：…（harness 版本、模型、预算）」 |
| **L2** | 本地装起来跑通最小任务/demo，有真实输入输出 | 「本地跑通：…」 |
| **L1** | 读过源码/配置，能画调用链，但没运行 | 「从源码看：…」 |
| **L0** | 只读文档/README/论文/他人公开结果 | 「按其文档/公开结果：…」 |

- 一篇文章的**主案例**至少 L1/L2；只有 L0 时必须在汇报里说明原因。
- 证据等级写在正文对应段落的徽标里（样式见 template.md），并与 `research.md` / `practice-log.md` 的条目一致。
- 允许出现「作者自述」与「未验证」标签，禁止把 L0/L1 描述成「实测」。

---

## 五、选题热度判据（辅助拍板，不替代判断）

| 信号 | 看什么 | 风险 |
|------|--------|------|
| star 周/月增速 | 近 30 天是否明显跃升 | 刷星、发布会冲量 |
| Release 节奏 | 近 90 天是否有实质版本 | 只有版本号没有内容 |
| Issue 响应 | 维护者是否回、平均响应时长 | 社区单机、无人维护 |
| 讨论质量 | HN/Reddit 是否在讨论机制而非口号 | 营销文占多数 |
| 可实践性 | 能否在 1-2 小时内跑起来 | 需要 GPU/私有接口则降级到 L1 |

**一票否决**：找不到仓库或官方文档、许可证缺失且无法确认、最近一次提交超过 12 个月且无 release。

---

## 六、素材落盘要求

- 每条入选材料在 `research.md` 有一行：`一句话事实 | 类型(一手/二手) | 来源 | 日期 | 链接 | 可引用字段`
- 文章里出现的每个数字，必须能在 `research.md` 找到对应行。
- 截图/命令输出放 `$CONTENT_DIR/agent-workshop/20261121-<slug>/images/` 或 `practice-log.md` 的代码块，不往仓库放。
