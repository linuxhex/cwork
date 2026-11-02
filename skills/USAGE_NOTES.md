# cwork 技能使用记录与优化闭环（所有 skill 共用）

> 适用全部 cwork skill。**只记值得优化或借鉴的**：能改进 skill/脚本/索引的问题、可复用的实战教训。
> 琐碎现象、一次性问题、无借鉴价值的流水账**不记**。

## 闭环流程

1. **记录（随时，克制）**：遇到值得优化/借鉴的问题才追加一行到「未分析」，格式 `- [YYYY-MM-DD] [skill] 现象 | 建议改法`。能当场修的直接修，修完记一句精炼结论（怎么修的 + 可借鉴的教训），不复述过程。
2. **分析（每天最多 1 次，通常收工时）**：读「未分析」区 → 逐条优化 skill → 处理完的条目**直接删除**（教训已吸收进 skill 文件，无需留档）；确有长期借鉴价值的一句线压缩进「经验沉淀」区。更新 `.last_analysis_date`。
3. **大小硬约束**：「未分析」≤ 10 条，「经验沉淀」≤ 20 条；超出时删最老/价值最低的，**追加覆盖，不无限增长**。
4. **触发判断**：每天首次接触 cwork skill 时，若 `.last_analysis_date` ≠ 今天 → 做一次分析（一天只做一次）。**「未分析」区为空也要做**：跨 agent 会话扫描（Qoder/Claude/Cursor 各项目 `.jsonl`，取上次分析日之后修改的，抽用户反馈句）是反馈回流的主通道——Qoder 实测踩的坑不会自己出现在这里，详见 `common/feedback-loop.md`。

## 未分析

- [2026-11-02] [test] exportApi 缺 filename 生成期硬抛打断探针 | 缺省自动生成 export-api-s{i}-i{j}.json + 水位线优先
- [2026-11-02] [test] assertApi 命中进页旧响应（反面竞态）+ heredoc `let __stepT0` 每场景重复声明炸 SyntaxError | 水位线只认动作后新响应；__stepT0 改顶层单次 let
- [2026-11-02] [log/deploy] SLS stdout 混入 >>> 致 json.loads 炸；裸 bash deploy.sh 任意 cwd 127 | >>> 改 stderr + deploy 强制绝对路径示例
- [2026-11-01] [test] 新增 android-run.cjs，BlueStacks5+ADB 驱动，对齐官方 Skill 能力 | 待实测 uiautomator dump 解析稳定性
- [2026-11-01] [test] 小程序快照批量化+条件等待+多页合并+耗时埋点 | 实测前后对比耗时
- [2026-11-01] [implement] 借鉴 impeccable/ponytail 思想增强前端设计与编码（7支柱/反slop/分模式/critique/三问/意图优先/最小改动） | 实测验证审查流程是否被正确触发

## 经验沉淀（≤ 20 条，只留可长期借鉴的）

- [test] ego 原生等待 timeout 对「条件永不满足」可能永不 resolve（waitForElement/click/fill）——执行器必须 withHardCap；assertApi 须短轮询等响应；表单元素断言读 .value 非 textContent
- [test] plan 性能：单场景 waitForNetworkIdle≤2、navigate 后禁紧跟断言、菜单/下线/回链消失用 assertText expectNotContains 替代 aiAssert（OMJF-19967）
- [test] 登录/路由跳转判据必须确定性 URL 断言（waitForUrl/assertUrl），waitForNetworkIdle 永不作跳转完成判据；assertVisible 在登录页误判高发
- [test] 「断言必须可证伪」比「断言存在」更重要——凑数等待/凑数断言会盖住完整失败证据链产生假通过
- [test] 异步渲染组件（element-ui nextTick 面板等）禁止同步 count，必须轮询可见性；三个「瞬态失败」常共用一条根因链，机械校验收紧比文档约束可靠
- [test] 执行器改动必须回源仓库双写，安装副本 patch 会被下次分发冲掉（rmSync 整目录覆盖，源仓库为权威）
- [test] selector 含双引号时 JSON.stringify 嵌模板字符串会被二次解义，需 tmplSel() 转义；js() 对复杂 JSON 表达式返回 null，取复杂结构走 cdp returnByValue
- [test] ego 任务空间是隔离浏览上下文、进程结束会话销毁，「继承用户登录态」不成立，场景 1 必须真实登录
- [test] 小程序 MCP 网络监控劫持 wx.request 污染业务响应；automator Connection.send 无超时会永久挂起，导航统一 evaluate_script，MCP 配置强制 timeout
- [test] waitForElement 无可见性过滤会命中 Element 全局隐藏容器（.el-message-box 假通过）；弹窗先 --snapshot+查源码验明真实容器再写选择器
- [test] 重跑必须换新 taskSpaceName（TaskStop 杀不干净 ego 子进程留脏记录）；--ctx-dir 必须绝对路径；aiAssert 判定可退回 URL/DOM/接口证据（截图临时文件会被 pid 复用覆盖）
- [deploy] Jenkins POST 必须 crumb+cookie jar（CSRF），触发失败/轮询超时一律报错 return 1，禁止 `|| true` 吞错后误报旧构建号
- [deploy] 未收录服务探索直走 `GET /apps/{app}/releaseWorkflows`，禁走 apps:search（只支持 keyset 分页易撞参数错）；production 不收录
- [deploy] curl URL 含 `[]` 会被当 glob，需 -g 或 %5B%5D 编码
- [commit] CodeUp 钩子要求 `#OMJF-数字` 单独成行的两行格式，AI 手工提交必须 heredoc 按格式，禁自由发挥
- [install] frontmatter 操作必须锚定 name 行，replace('---\n') 会把内容插到 frontmatter 之前破坏全部元数据
- [install] 低频技能 lazy 按需加载根治常驻上下文超限（341KB→143KB）；installClaude/checkInstall 共用的构造函数传参必须一致，否则 --check 永远报不一致
- [log] prod 业务专属库大面积空，主链路 `all`+spring.name；查 all 库必须带关键字
- [log] 时间戳禁止心算，命令驱动；搜索关键字单号优先
- [data] Doris 跨 catalog JOIN 大表关联易 OOM（外表全量拉 coordinator），分别查小结果集本地关联；无 WHERE 全表扫描机械拦截

- [未分析][2026-11-02] web-run.cjs：场景内每步 `let __stepT0` 重复声明导致 SyntaxError；改为场景级一次声明、步骤内重赋值（OMJF-19967 UAT 重跑）
