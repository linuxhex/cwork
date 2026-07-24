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

（暂无）

## 已归档（最近一轮）

- [2026-07-23] [log] 查日志盲目找库、arms 每次遍历找 pid、查询语法不明 → 已建 `LOGSTORE_INDEX.md` + `ARMS_PID_CACHE.md` + `rebuild_index.sh`，SKILL.md 改为「先查索引」
- [2026-07-23] [log] 查询语法 `__tag__:_container_name_:` 报错、charge 对应标"或"、device-ykcoms 库归属错 → 已实测修正并写入索引
