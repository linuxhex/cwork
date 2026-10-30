# cwork 技能体系

多工程微服务开发工作流：对话式需求分析 → 计划与审查 → 推演收敛；排查优先用日志/数据/配置/监控证据。常规实现以逻辑推演为主，**bug 修复强制回归测试**。

---

## 一、技能一览

### 主流程

| 技能 | 作用 |
|------|------|
| `cwork-init` | 多服务工程定位、分支切换、服务地图 |
| `cwork-implement` | 需求分析 + 编写计划 + 方案审查 + 执行 + 推演收敛 |
| `cwork-test` | 页面自动化测试（Web / 小程序），**条件触发，非必经** |
| `cwork-commit` | 推演收敛后提交（关联模式不确认） |
| `cwork-do` | 目标驱动自主循环：实现/修复 → 部署 → 实测 → 双证据收敛后提交 |
| `cwork-bug` | 快速修 bug：定位（可联动 log/data/graf）→ 修复 → 推演验证 → 回归测试 |

### 排查与工程辅助

| 技能 | 作用 |
|------|------|
| `cwork-log` | SLS 日志 + ARMS 链路 |
| `cwork-data` | Doris 数仓只读 SQL |
| `cwork-config` | 多环境 Nacos 配置只读 |
| `cwork-graf` | Grafana 监控只读 |
| `cwork-code` | CodeUp 主平台 + GitLab fallback；codegraph 优先 |
| `cwork-requirement` | 云效需求只读 |
| `cwork-deploy` | Jenkins / 云效构建部署（服务映射见 `deploy/scripts/service-map.json`） |
| `cwork-doc` | 技术方案文档（ASCII 带框流程图 / 泳道交互图，**不用 mermaid**） |
| `cwork-image` | 本地打镜像 + push + 拉起 |
| `cwork-article` | 公众号 / 小红书写作与发布 |
| `cwork-tech-writer` / `cwork-wuxia-writer` | article 内部人格（不单独当主流程） |
| `cwork-common` | `code-style.md` + `git-guard.md` 共享规范 |

---

## 二、流程衔接（硬约束）

```
cwork-init → cwork-implement → cwork-test? → cwork-commit
                 ↑                    │
            （可选）            三条件全满足才进 test
                              否则直接 commit

cwork-bug → cwork-commit
cwork-do  ：目标确认 → 循环[执行→部署→实测→收敛评估] → 收敛后 commit
```

**test 触发（全部满足）**：
1. 有前端改动（`.vue/.jsx/.tsx/.svelte/.html/.js/.ts` 等）
2. 涉及新页面或核心交互（非纯样式/纯字段/纯接口对接）
3. 用户确认要跑（回车跳过=不跑）

**提交时机两条路径（有意区分）**：
- `implement → commit`：编译/构建通过即可提交
- `cwork-do`：必须实测 + 理论评估双证据逼近验收标准后才提交

禁止让用户手动发起下一 skill；阶段结束自动衔接。

---

## 三、核心机制

### 深度追问（对用户）

用于 `implement` 需求分析、`bug` 定位：

1. 一次只问一个  
2. 每个问题带推荐答案；**能选项就选项（A/B/C）**  
3. 事实自己查，决策归用户  
4. 确认前不动手 / 不定位  
5. **模糊→可判定**：禁止停在「请具体点」，追成可判定选项  
6. **矛盾当场挑明**：与已确认结论冲突时立刻二选一，不带着错共识继续  

### 自问自答质询（对己）

用于推演收敛、bug 推演验证、test：扮演质疑者，一次只质疑一个，事实自己查，形成共识再继续。

### 路径约定（隐私 + 本机可用）

- 服务地图等本机文件：先 Bash `printf '%s/.services-map.md\n' "$CWORK_HOME"` 展开，再 Read  
- Shell 默认值可用 `$HOME/...`（shell 会展开）  
- 禁止硬编码 `/Users/<username>/...` 入库  
- 凭证：`*.local.sh` / `.mcp_config.json` 已 gitignore；IDE 安装靠 `CWORK_HOME` 回源读凭证  

### 技术方案图（cwork-doc）

- **一律 ASCII 带框图**（服务框 + 生命线 + 箭头），适配 MdServer 等不渲染 mermaid 的平台  
- 禁止 mermaid；禁止 `[节点]--标签-->[节点]` 文字线式  
- 对齐硬规则：等宽框、全角按 2 格、箭头贴框、画完自查  

### 测试口径（有意区分）

- **implement**：逻辑推演为主；核心流程改动才跑单测  
- **bug**：修复必须写回归测试并跑通  

---

## 四、安装与同步

源仓库改完技能后，在仓库根执行：

```bash
node bin/cwork.js
```

会同步到：

- Claude Code：`CLAUDE.md` + `.cwork/refs/`（由 `AGENTS.md` 生成 CLAUDE 头）  
- Cursor / Qoder 等安装目录（见脚本输出）  

**注意**：改「对话语言 / 内部技能说明 / test 触发」等总述，改 **`AGENTS.md`**，不要只改 `CLAUDE.md`（下次同步会被覆盖）。

---

## 五、目录结构

```
skills/
  <skill>/SKILL.md          # 技能主文档
  <skill>/scripts/          # 可执行脚本（若有）
  common/                   # code-style / git-guard
  README.md                 # 本文件
AGENTS.md                   # Claude/Cursor 总述源
bin/cwork.js                # 安装与分发
```

按需加载参考文件（如 `implement/phases.md`、`doc/tech-design-template.md`）写在各 SKILL 内，不随主文档全量进上下文。

---

## 六、注意事项

1. 排查优先证据：log → data/config/graf，禁止空猜  
2. 拉分支/推送遵守 `common/git-guard.md`（禁止裸 push/pull，upstream 必须同名）  
3. `cwork-doc` 出图前自查对齐；内网预览以 MdServer 为准  
4. 凭证只落本机忽略文件，轮换后用环境变量或 `.config.local.sh` 注入  
5. 改技能后：`node bin/cwork.js` 再提交，避免 agent 副本过期  
