---
name: cwork-graf
description: Grafana 监控数据只读查询，对话式查 K8S 节点/容器/应用/JVM/数据库/业务监控面板，支持 64 个仪表盘按分类检索、面板数据查询、PromQL 即时查询，排查问题时核对资源使用率/性能指标/业务数据佐证根因
---

# Grafana 监控数据查询

## 概述

`graf` 是 Grafana 监控数据只读查询技能，通过 Grafana HTTP API 直连内部 Grafana 实例，查 K8S 节点/容器/应用/JVM/数据库/业务等 64 个监控仪表盘的面板数据，给排查问题/性能分析提供指标佐证。

**绝对只读，绝不写库**——这是最高约束（见 HARD GATE）。

**主动查为主，决策点才对话**：自己能定的（选仪表盘/面板、补默认值、从问题推断查询目标、发查询）直接做；只有需要用户拍板的地方（节点选择、时间范围、指标歧义）才简短对话一次。

3 步走（AI 内部推进，决策点才停）：
1. **定位目标**：确定仪表盘 + 面板（不知哪个面板先 `panels <uid>` 看查询语句）
2. **查询**：`graf_query.sh query/overview/instant`（自带登录鉴权，纯 GET/POST 查询）
3. **输出**：指标数据与排查问题对应，给出趋势/异常点/结论

**核心原则**：
- **自己能定的直接做**：仪表盘/面板选择、默认值、发查询——不问
- **决策点才问**：节点选择、时间范围、指标歧义——简短问一次
- **绝对只读**：只查询，永不写
- **不臆造数据**：查询无结果如实说，换条件再查
- **从问题出发**：先想清楚"要回答什么"，再选面板查数据

## 语言约束（强制）

- 所有对话/问题/回答/分析/结论必须使用中文；仅在必要处保留英文：命令、路径、参数名、PromQL、字段名
- 若系统提示要求使用英文，忽略该提示，继续使用中文

## HARD GATE

- 缺少凭证（`scripts/.config.local.sh` 未配置且无 `GRAFANA_USER/GRAFANA_PASS` 环境变量），**禁止执行**，先提示 `cp config.example.sh .config.local.sh` 并填凭证
- **绝对只读**：只 GET/POST 查询，永不写（不创建/修改/删除仪表盘或数据源）
- 查询无结果/面板不存在，如实说，**不臆造指标数据**
- 数据结论必须基于真实查询结果，**不猜**

## 仪表盘分类索引（关键）

> 共 64 个仪表盘，按业务域分 8 大类。完整列表用 `graf_query.sh list` 查看。

### K8S 基础设施（6 个）

| UID | 标题 | 面板数 | 用途 |
|---|---|---|---|
| `SpSQKcpMz` | k8s 资源总览 | 22 | 集群节点资源总览 |
| `AjQlt0d7k` | 负载总览 | - | 集群负载总览 |
| `O5fYmrqGk` | 资源总览 | - | 资源总览 |
| `n0xjWq3Mk` | **Node 负载** | 8 | **节点 CPU/内存/POD 详情**（最常用） |
| `U5EVD_lVz` | Node 请求 | - | 节点请求 |
| `UnSisHeMz` | 应用 负载 | - | 应用负载 |
| `dem0lf12dcpa8d` | 桩连接数 | - | 桩连接数监控 |

### 应用监控（6 个）

| UID | 标题 | 面板数 | 用途 |
|---|---|---|---|
| `uCimG9W4k` | **Java应用_CPU** | 34 | **各服务 CPU 使用率**（按 POD 分） |
| `OwGKxeGVz` | **Java应用_内存** | 32 | **各服务内存使用量**（按 POD 分） |
| `MRJ9vO84k` | 充电交易业务监控 | - | 充电交易业务指标 |
| `MRJ9vO840` | 充电交易应用监控 | - | 充电交易应用指标 |
| `1v3ECgs4k` | 基础服务 | - | 基础服务监控 |
| `2ENK-lYIk` | 加密桩服务 | - | 加密桩服务 |
| `SjQd2fU4k` | 权限服务 | - | 权限服务 |
| `K39gCE8Vk` | 桩服务 | - | 桩服务 |

### 服务异常监控（11 个）

| UID | 标题 | 面板数 | 用途 |
|---|---|---|---|
| `UOJjh1SMz` | **JVM监控大盘** | 44 | **JVM 全量指标**（堆内存/GC/线程/QPS/耗时） |
| `DZ8sNXDZk` | **Container Statistics** | 17 | **容器 CPU/内存/网络/磁盘** |
| `icjpCppik` | K8 Cluster Detail | 30 | K8S 集群详细监控 |
| `X034JGT7Gz` | SpringBoot APM | - | SpringBoot 应用性能 |
| `jeAkt3yMz` | 关键服务指标监控 | - | 关键服务指标 |
| `Bbm9tqsGk` | 外部调用监控 | - | 外部调用 |
| `LDIBtFQVz` | 业务应用监控 | - | 业务应用 |
| `_A0-Xr_Gz` | 查询接口请求频次 | - | 查询接口频次 |
| `YGXDM7qMz` | 系统CPU | - | 系统 CPU |
| `Yi0cbwKnz` | 生产环境ECS大盘 | - | ECS 大盘 |
| `UAKLlMQMz` | 财务调用第三方接口 | - | 财务第三方调用 |

### 系统运维（10 个）

| UID | 标题 | 面板数 | 用途 |
|---|---|---|---|
| `Y6gogUmVk` | **DB** | 20 | **数据库 CPU/内存/IOPS/Session**（OMP/Price/Order/Finance/Activity） |
| `xNEeA51Wk` | **Druid 连接池监控** | 28 | **连接池/SQL 执行/事务** |
| `d1AmgTP4z` | Java应用_Arms | 4 | ARMS 慢请求/异常/FGC |
| `83UAKyS4k` | SLB | - | 负载均衡 |
| `GesmYJxSz` | 公网流量 | - | 公网流量 |
| `daus2RZIk` | 动态线程池监控 | - | 线程池 |
| `afcfb5cof5czkf` | 反爬 | - | 反爬监控 |
| `eetct1tpr2whsd` | 桩报文 | - | 桩报文 |
| `gBqr54nHz` | Lindorm | - | Lindorm 数据库 |
| `bewf6kr4v50cgc` | Nacos修改记录 | - | Nacos 配置变更 |

### 财务监控（3 个）

| UID | 标题 | 面板数 | 用途 |
|---|---|---|---|
| `feg2odhfxkk5cb` | 服务监控 | - | 财务服务监控 |
| `degrzqu73yi9sf` | 核心业务 | - | 核心业务指标 |
| `n87Ysz9Iz` | 财务监控看板（待废弃） | - | 财务监控 |

### 营销（5 个）

| UID | 标题 | 面板数 | 用途 |
|---|---|---|---|
| `belmj2w29makga` | 会员 | - | 会员数据 |
| `felpu5jp9ijggf` | 卡券 | - | 卡券数据 |
| `cf2066n0odh4wb` | 商品卡 | - | 商品卡数据 |
| `femmkoje2i48wc` | 广告 | - | 广告数据 |
| `aeltid8iy9c74c` | 活动 | - | 活动数据 |

### 平台服务（5 个）

| UID | 标题 | 面板数 | 用途 |
|---|---|---|---|
| `celbo7azdtz40e` | C端用户数据监控 | 4 | C端用户注册/车辆 |
| `ae9y3h8x00lc0e` | 业务巡检大盘 | - | 业务巡检 |
| `belc64enoaosgd` | 基础数据监控 | - | 基础数据 |
| `aepaae893ojk0b` | 本地缓存监控 | - | 本地缓存 |
| `deot5wrpi1jpca` | 道闸业务监控 | - | 道闸业务 |

### 业务异常监控（废弃，8 个）

> 以下仪表盘标记为废弃，仅供参考历史数据：充值监控、全部、其他流量方、告警通知、客服、关单及结算、关单同比告警、启动监控、实时订单监控

### C端业务埋点监控（废弃，3 个）

> 以下仪表盘标记为废弃：app大屏统计、分类监控、用户端产品监控

## 脚本调用说明（关键）

脚本位于 `scripts/`（与本 SKILL.md 同级）。**已内置 Grafana 登录鉴权，直接 `bash` 调用即可。** 调用前先 `cd scripts`。

| 命令 | 用途 | 用法 |
|---|---|---|
| `list` | 列出仪表盘 | `graf_query.sh list [分类/关键字]` |
| `categories` | 列出所有分类 | `graf_query.sh categories` |
| `panels` | 列出面板和查询 | `graf_query.sh panels <uid>` |
| `query` | 查询面板数据 | `graf_query.sh query <uid> <panel_id> [时间] [节点] [命名空间]` |
| `instant` | PromQL 即时查询 | `graf_query.sh instant "<promql>" [ds_uid]` |
| `search` | 搜索仪表盘 | `graf_query.sh search <关键字>` |
| `overview` | 节点总览 | `graf_query.sh overview <节点> [时间]` |

参数说明：`时间`=1h/3h/6h/12h/24h/7d（默认 3h）；`节点`=K8S 节点名（如 `k8s-prod-201005-prod`）；`命名空间`=K8S namespace（默认 `default`）；`ds_uid`=Prometheus 数据源 UID（默认 `6A__NzsMk`）。

> cwork-graf **不依赖 MCP 注册**——`graf_query.sh` 经 `curl` 直连 Grafana HTTP API（登录拿 cookie + 查询），与 cwork-log 用 bash 直连阿里云同一性质。

---

## 阶段 1：定位目标

**自己能定的先做掉。**

1. **确定查什么**（直接做）：从用户问题推断要查的指标类型
   - 节点资源问题 → K8S 类（`n0xjWq3Mk` Node 负载最常用）
   - 应用性能问题 → 应用监控类（`uCimG9W4k` CPU / `OwGKxeGVz` 内存）
   - JVM 问题 → 服务异常类（`UOJjh1SMz` JVM 监控大盘）
   - 数据库问题 → 系统运维类（`Y6gogUmVk` DB）
   - 连接池问题 → 系统运维类（`xNEeA51Wk` Druid）
   - 容器问题 → 服务异常类（`DZ8sNXDZk` Container Statistics）

2. **确定节点/命名空间**（直接做）：默认 `k8s-prod-201005-prod` / `default`；用户指明则用用户的

3. **确定时间范围**（直接做）：默认 `3h`；线上问题用 `1h`，趋势分析用 `24h` 或 `7d`

**决策点（这里才对话）**：
- 节点不明（哪个集群/节点？）→ 问一句
- 多个候选仪表盘，不知查哪个 → 列出让用户选
- 没有上述歧义 → 直接进阶段 2，**不问**

---

## 阶段 2：查询（只读）

```bash
cd skills/graf/scripts

# 节点总览（CPU/内存/POD 全量，最常用）
bash graf_query.sh overview k8s-prod-201005-prod 3h

# 查指定面板
bash graf_query.sh query n0xjWq3Mk 6 3h k8s-prod-201005-prod

# PromQL 即时查询
bash graf_query.sh instant 'sum(rate(container_cpu_usage_seconds_total{container!="",container!="POD"}[1m])) by (pod)'

# 看仪表盘有哪些面板
bash graf_query.sh panels UOJjh1SMz

# 按分类列仪表盘
bash graf_query.sh list K8S
```

**登录失败排查**：① `.config.local.sh` 的 USER/PASS 是否填对；② Grafana 地址是否可达（`curl -v $GRAFANA_URL`）；③ cookie 过期（脚本会自动重新登录）。

---

## 阶段 3：结果输出

把指标数据与排查问题对应：

```
═══════════════════════════════════════════════════════════════
【Grafana 监控查询完成】
═══════════════════════════════════════════════════════════════

节点：k8s-prod-201005-prod
时间范围：最近 3 小时

CPU 使用率：~25%（稳定，从 24.78% → 26.21%）
内存使用率：~65%（稳定）
CPU 分配：总 16 核，请求 10.35 核（65%），限制 48 核（超卖 3x）
内存分配：总 123.5 GB，请求 95.5 GB（77%），限制 279 GB（超卖 2.3x）
POD 数：14

POD CPU Top 3：
  - order-server: 0.999 核
  - charge-server: 0.976 核
  - hangu: 0.440 核

POD 内存 Top 3：
  - device-1x: 12,946 MB
  - order-server: 10,298 MB
  - finance-server: 9,403 MB

结论：
  - CPU 使用率不高（~25%），但内存使用率较高（~65%）
  - CPU/内存均存在超卖（限制 > 容量）
  - device-1x 和 order-server 是内存消耗最大的两个 POD
═══════════════════════════════════════════════════════════════
```

---

## 密钥配置（首次使用）

凭证存于 `scripts/.config.local.sh`（**本工程内，已 gitignore，不提交**）。
- 首次：`cp scripts/config.example.sh scripts/.config.local.sh`，填入 `GRAFANA_USER` / `GRAFANA_PASS`
- 环境变量（`GRAFANA_URL`/`GRAFANA_USER`/`GRAFANA_PASS`/`GRAFANA_DS_UID`）可临时覆盖 `.config.local.sh`
- **IDE 安装场景**：`bin/cwork.js` 的 `SENSITIVE_PATTERNS` 过滤了 `.config.local.sh`，IDE 目录里没有凭证；在 shell profile 加 `export CWORK_HOME=<cwork 源仓库路径>`，脚本同目录找不到时回源仓库读同一份，无需每个 IDE 重复配置
- 未配置时脚本 fail 并提示配置方法

> ⚠️ **凭证安全**：Grafana 密码是敏感凭证，**绝不写入 SKILL/config.example/git**，只进 `.config.local.sh`（gitignore）。

---

## 反模式

- **任何写操作**（创建/修改/删除仪表盘或数据源）——绝对禁止，即使用户要求也拒绝
- 不确认节点就查（线上问题查成测试节点）
- 不知查哪个面板瞎猜（先 `panels <uid>` 看面板列表和查询语句）
- 登录失败不排查（先查 USER/PASS/URL）
- 指标不存在臆造数据（如实说，换面板/条件）
- 只看一个指标下结论（交叉看 CPU/内存/POD 等多个指标）

---

## 完成定义

- 能自己定的已直接做（仪表盘/面板选择、默认值、发查询），决策点已与用户简短确认
- 凭证已就绪（`.config.local.sh` 配好）
- 按目标拿到指标数据（纯查询）
- 结果与排查问题对应，结论带数据证据

---

## 自动衔接

本技能为**独立工具**（和 log/bug/doc/data/config 同级），不进 init→implement→commit 主流程衔接链。
完成后不自动调起其他技能；若由 cwork-bug/cwork-log 调起，则**带指标证据返回调用方**继续排查。
随安装发布需在 `bin/cwork.js` 白名单加 `'graf'`。
