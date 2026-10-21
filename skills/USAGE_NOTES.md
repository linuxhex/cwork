# cwork 技能使用记录与优化闭环（所有 skill 共用）

> 适用全部 cwork skill。**只记值得优化或借鉴的**：能改进 skill/脚本/索引的问题、可复用的实战教训。
> 琐碎现象、一次性问题、无借鉴价值的流水账**不记**。

## 闭环流程

1. **记录（随时，克制）**：遇到值得优化/借鉴的问题才追加一行到「未分析」，格式 `- [YYYY-MM-DD] [skill] 现象 | 建议改法`。能当场修的直接修，修完记一句精炼结论（怎么修的 + 可借鉴的教训），不复述过程。
2. **分析（每天最多 1 次，通常收工时）**：读「未分析」区 → 逐条优化 skill → 处理完的条目**直接删除**（教训已吸收进 skill 文件，无需留档）；确有长期借鉴价值的一句线压缩进「经验沉淀」区。更新 `.last_analysis_date`。
3. **大小硬约束**：「未分析」≤ 10 条，「经验沉淀」≤ 20 条；超出时删最老/价值最低的，**追加覆盖，不无限增长**。
4. **触发判断**：每天首次接触 cwork skill 时，若 `.last_analysis_date` ≠ 今天 且「未分析」区有条目 → 做一次分析（一天只做一次）。

## 未分析

- [2026-10-20] [install] installer PROJECT=cwd 陷阱：从源仓库子目录跑安装会把产物写进子目录（已删误产物）| 待吸收：PROJECT 非仓库根时告警或自动定位 ROOT；`--help` 未短路，任意未识别参数静默触发全量安装
- [2026-10-16] [test] openDatePicker panel:0 调试输出在非 daterange 面板是误报 | 待修
- [2026-10-16] [test] 复杂场景（MySQL 造数+后端落库验证）plan.json 表达不了会退化为手写 heredoc | 待分析：复杂场景降级路径
- [2026-10-16] [test] 机制建议：实战会话凡手工 patch 安装副本，收工前必须回写源仓库，否则下次同步覆盖丢失（已发生多起）
- [2026-10-16] [test] OMP 列表查询 0 条时 .page-total 从 DOM 消失，0 条场景断言统一用 body contains 暂无数据 | 待并入 web-test.md 坑清单

## 经验沉淀（≤ 20 条，只留可长期借鉴的）

- [test] 登录/路由跳转判据必须确定性 URL 断言（waitForUrl/assertUrl），waitForNetworkIdle 永不作跳转完成判据；assertVisible 在登录页误判高发
- [test] 「断言必须可证伪」比「断言存在」更重要——凑数等待/凑数断言会盖住完整失败证据链产生假通过
- [test] 异步渲染组件（element-ui nextTick 面板等）禁止同步 count，必须轮询可见性；三个「瞬态失败」常共用一条根因链，机械校验收紧比文档约束可靠
- [test] 执行器改动必须回源仓库双写，安装副本 patch 会被下次分发冲掉（rmSync 整目录覆盖，源仓库为权威）
- [test] selector 含双引号时 JSON.stringify 嵌模板字符串会被二次解义，需 tmplSel() 转义；js() 对复杂 JSON 表达式返回 null，取复杂结构走 cdp returnByValue
- [test] ego 任务空间是隔离浏览上下文、进程结束会话销毁，「继承用户登录态」不成立，场景 1 必须真实登录
- [test] 小程序 MCP 网络监控劫持 wx.request 污染业务响应；automator Connection.send 无超时会永久挂起，导航统一 evaluate_script，MCP 配置强制 timeout
- [deploy] Jenkins POST 必须 crumb+cookie jar（CSRF），触发失败/轮询超时一律报错 return 1，禁止 `|| true` 吞错后误报旧构建号
- [deploy] 未收录服务探索直走 `GET /apps/{app}/releaseWorkflows`，禁走 apps:search（只支持 keyset 分页易撞参数错）；production 不收录
- [deploy] curl URL 含 `[]` 会被当 glob，需 -g 或 %5B%5D 编码
- [commit] CodeUp 钩子要求 `#OMJF-数字` 单独成行的两行格式，AI 手工提交必须 heredoc 按格式，禁自由发挥
- [install] frontmatter 操作必须锚定 name 行，replace('---\n') 会把内容插到 frontmatter 之前破坏全部元数据
- [install] 低频技能 lazy 按需加载根治常驻上下文超限（341KB→143KB）；installClaude/checkInstall 共用的构造函数传参必须一致，否则 --check 永远报不一致
- [log] prod 业务专属库大面积空，主链路 `all`+spring.name；查 all 库必须带关键字
- [log] 时间戳禁止心算，命令驱动；搜索关键字单号优先
- [data] Doris 跨 catalog JOIN 大表关联易 OOM（外表全量拉 coordinator），分别查小结果集本地关联；无 WHERE 全表扫描机械拦截
- [code] clone 禁 --single-branch（后续分支上游异常）
- [article] keyboard.paste 走 macOS 原生 cmd+v，浏览器非 OS 前台时静默失败，脚本前先 osascript 置前台；发表类按钮禁 JS click，按全文本精确匹配+坐标点击
- [通用] bash 变量名后紧跟全角字符被吞进变量名，一律 `${var}`；成功返回 list 的 API 对它调 .get 会崩
- [通用] 分发链四端（claude/qoder/cursor/trae）+ 全局副本各走各的命令，漏一端就分叉；改完源立即 commit 防工作区被外部恢复
