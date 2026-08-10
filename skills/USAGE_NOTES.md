# cwork 技能使用记录与优化闭环（所有 skill 共用）

> 适用全部 cwork skill：`implement` / `bug` / `doc` / `log` / `commit` / `init` …
> 用技能时遇到的问题、不合理处、可优化点，记到下面「未分析」区；**一天最多分析一次**。

## 闭环流程

1. **记录（随时）**：用任一 cwork skill 时，发现不顺手 / 报错 / 结果不准 / 可省步骤 / 索引过期 → 追加一行到「未分析」。
   - 格式：`- [YYYY-MM-DD] [skill] 现象 | 建议改法`
   - 能当场修的小问题直接修（改 `skills/<skill>/SKILL.md` / 脚本 / 索引），修完也记一笔到「未分析」便于归档。
2. **分析（每天最多 1 次，通常收工时）**：读「未分析」区 → 逐条判断怎么优化 skill → 改对应文件 → 把该条移到「已归档」或删除 → 更新 `.last_analysis_date` 为今天。
3. **触发判断**：每天首次接触 cwork skill 时，若 `.last_analysis_date` ≠ 今天 且「未分析」区有条目 → 做一次分析（一天只做一次，避免反复打断）。

> 说明：分析由 Claude 读记录后做（判断怎么优化是 AI 活，不是脚本能定的）；定时自动触发受会话存活限制，所以靠「每天首次用时自查 + 手动说一声分析」两种方式。

## 未分析

- [2026-08-10] [log/bug] 定位问题时跑飞（找日志/服务找错方向）→ 已修正：新增"不确定时及时探讨"原则，列出跑飞高发场景，必须停下来跟用户探讨
- [2026-08-10] [code] clone 命令可能用了 --single-branch 参数（导致只跟踪默认分支，后续创建分支上游异常）→ 已修正：脚本明确禁止 --single-branch，SKILL.md 加约束说明
- [2026-08-10] [log] 域感知路由覆盖不全（只 4 域：车队/运维桩/订单/支付），device 域只覆盖运维桩（1/32），导致盛弘/华为/施恩/鲁能等设备日志、EMP/ZDL/DMP/OSP/IOP/银行/OMP 等域日志查不到 → 已补全：SKILL.md 域路由覆盖全部 16 域（CTP/Device/EMP/ZDL/DMP/OSP/IOP/银行/OMP/出站/MQ等），LOGSTORE_INDEX.md §2 决策树同步，memory/cwork-log-guide.md 加路由触发词清单；同步更新 bug/test 技能联动说明
- [2026-08-10] [log] 域感知路由未强制设置关键字，查 all 库返回海量无关日志 → 已修正：所有查 all 库的域都设置 KEYWORD（spring.name），专属库关键字可选，默认路由警告，查询前检查 all 库必须有关键字
- [2026-08-04] [log] prod 业务专属库大面积空（66 个 `*-server`/`*-out` 仅 ~14 有数据，finance/order/charge/base/poly/clearing 等核心服务专属库 90 天全空），原索引把空库当可用库列了误导 → 已修正：LOGSTORE_INDEX.md §1/§4 + ARMS_PID_CACHE.md 加「prod 专属库数据现状」清单，主链路改 `all`+spring.name，finance 四层表/ARMS 行标注全空；uat 侧基本准确未动
- [2026-08-04] [log] cwork-log 阶段 1 缺 codegraph（bug/implement/doc 都有，独 log 没有）→ 已补：阶段 1 第 2 步加 codegraph 优先探测（status→node/callees/callers/explore），核心原则+反模式呼应

## 已归档（最近一轮）

- [2026-07-23] [log] 查日志盲目找库、arms 每次遍历找 pid、查询语法不明 → 已建 `LOGSTORE_INDEX.md` + `ARMS_PID_CACHE.md` + `rebuild_index.sh`，SKILL.md 改为「先查索引」
- [2026-07-23] [log] 查询语法 `__tag__:_container_name_:` 报错、charge 对应标"或"、device-ykcoms 库归属错 → 已实测修正并写入索引
