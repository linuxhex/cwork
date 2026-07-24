# SLS 日志库索引（cwork-log）

> **用途**：查某服务日志前，先按本索引定位 logstore，**不要在 200+ 个库里盲目 `list`/试探**。
> **生成依据**：prod 212 库 / uat 143 库实际 `list` + 命名规律 + 采样验证（2026-07-23）。
> **更新方法**：库变更时重跑 `bash scripts/sls_query.sh <env> list`，按下述前缀重新归类。

---

## 1. 采集模型（先理解，再选库）

- **`all` = 聚合库（默认入口）**：采集绝大多数业务服务的 `spring_app_logs`，且是**结构化 JSON**（含 `trace` / `logger` / `level` / `message` / `thread` / `line`）。排查业务运行日志、报错、慢调用、关联 traceId，**先查 `all`**。
- **专属库 = 按"域 / 厂商 / 接口"分库**：`<服务>-server`（运行日志补充）、`<服务>3-out`（对外接口出入站）、`device-<厂商>`（桩协议）、`ctp-*`（车队）等。`all` 查不到、或要专门维度时再用。
- **一个服务常散落多个库**：如 order 运行日志在 `all` / `order-server`，对外接口在 `order3-out`，MQ 消费在 `mq-consumer-order`。**不是"一服务一库"**。

---

## 2. 查询决策树（查什么 → 去哪个库）

| 要查的东西 | 首选 logstore | 备选 |
|---|---|---|
| 业务运行日志 / 报错 / 慢 / traceId | **`all`**（用 `_container_name_` 锁定服务） | `<服务>-server` / `<服务>-business` |
| 对外接口出入站（openapi / 网关转发） | `<服务>3-out` | `gateway-*` |
| 充电桩 / 设备协议 | `device-<厂商>` | `device-business` / `device-collection` / `device-post` |
| 运维桩（设备 coms） | `device-ykcoms`（prod 和 uat 均用此库） | |
| 车队链路 | `ctp-<服务>` | |
| 能源管理 | `emp-*` / `ems-*` | |
| 运维平台 OMP | `xuzhu-omp-*` / `omp-*` / `feomp-*` | |
| 开放服务 OSP | `osp-*` | |
| ZDL / DMP / IOP | `zdl-*` / `dmp-*` / `iop-*` | |
| 银行/支付通道 | `bank-*` / `bankpay3-out` | |
| 系统 / 审计 | `k8s-event` / `gc_log` / `sentinel-*` / `audit-*` / `internal-*` | |

---

## 3. 怎么精确锁定服务（实测验证过的查询语法，2026-07-23）

`all` 聚合多服务，要锁定某个**工程**——**用它的 spring.name 作关键字全文搜**（实测唯一可靠）：

✅ **能用**：spring.name 关键字（**不带引号**）。spring.name 出现在每条日志 `__path__` 里（`/opt/spring_app_logs/<spring.name>/logFile.log`），SLS 全文索引能命中：
- charge_server 工程：`DeviceBusinessServer`（实测30分钟命中1280万）
- order：`orderserver` / base：`BaseServer1` / poly：`PolyServer` / finance：`financeServer`
- 含连字符的也行：`payment-server`、`order-foundation`
- 组合：`DeviceBusinessServer and ERROR`

❌ **不能用**（SLS 报错或搜不到，别试）：
- `__tag__:_container_name_: xxx`、`__tag__:__path__: xxx`、`_container_name_: xxx` —— tag 字段查询语法 SLS **不接受**（实测报错）
- 带引号 `"xxx-yyy"` —— 报错
- 容器名当关键字（如 `charge-server`）—— 搜不到（容器名不在可搜索文本里；要定位容器对应的工程，用它的 spring.name）

⚠️ **device 协议日志常不在 all**（在 `device-*` 专属库）：如 `device-coms-server` 在 all 搜不到（0命中），要去 `device-ykcoms` 等专属库查。

> 日志里**能看到但不能直接 query** 的字段：`__tag__:_container_name_`(容器名)、`__tag__:_pod_name_`、`__tag__:__path__`(含spring.name)、`__tag__:_namespace_`、顶层 `trace`(=traceId，可直接喂 `arms_trace.sh`)。

---

## 4. logstore 按域分类（prod，212 库）

**聚合(默认入口)** · 1：`all`

**业务服务(运行日志)** · 27：`access-server activity-server adapter-open-server alarm-server barrier-server base-server charge-business charge-server clearing-server cloud-api-server external-server finance-server foundation foundation-c foundation2 invoice-server market-center-server new-base open-api-server order-server payment-server poly-server price-center-server push-server reconciliation-server station-site-server statistics-poly-server`

**接口出站(*-out)** · 37：`activity3-out barrierjs3-out barrierkt3-out basejur3-out charge3-out crm3-out data3-acc data3-out device3-out entryside3-out export3-out external3-out finance3-acc finance3-out flowside3-out gateway-op3-out gw3-other-out gw3-zdl-out ljc3-out maintenance3-out ngw3-out om-task3-out ombase3-out order3-out ots-base-out ots-finance-out ots-gw-out ots-order-out ots-task-out parking-lock3-out poly3-out reconciliation3-out safeguard3-out statistics3-out superwarehouse3-out task3-out ykc-admin3-out`

**设备/充电桩** · 32：`device-1x device-1x-encryption device-2x device-2x-encryption device-3x1 device-3x1-out device-adapter-tool device-adapter-tool-encrypt18 device-business device-collection device-custom device-huawei device-ln3-out device-luneng device-maint device-monitoring device-msg device-new-th-out device-new3-out device-post device-server-jsc device-server-ykc-encryption device-sh-channel-out device-sh3-out device-shenghong device-shenrui device-shenrui2 device-th-one-out device-wm device-ykc1 device-ykcoms device-ykr3-out`
> 厂商对照：`device-shenghong`盛弘 / `device-shenrui`施恩 / `device-huawei`华为 / `device-luneng`鲁能 / `device-wm` / `device-ykc1`；`device-ykcoms`=运维桩

**车队 CTP** · 7：`ctp-activity-server ctp-base3-out ctp-finance-server ctp-finance3-out ctp-gateway3-out ctp-order-server ctp-order3-out`

**能源 EMP/EMS** · 11：`emp-business3-out emp-digital-business-server emp-digital-business-server-new emp-emulator-server emp-gateway3-out emp-strategy-server emp-task3-out emp-yems-business-server ems-device-yst3-out ems-device3-out ems-local-device-server`

**开放服务 OSP** · 4：`osp-backend osp-customer osp-front osp-server`

**运维 OMP** · 14：`feomp-base feomp-bigscreen feomp-main omp-poly-center omp-poly-center3-out omp-superwarehouse-server omp-superwarehouse3-out xuzhu-omp xuzhu-omp-device xuzhu-omp-poly xuzhu-omp-resource xuzhu-omp-statistics xuzhu-omp-trading xuzhu-omp-zdl`

**ZDL** · 11：`zdl-base-server zdl-external zdl-ploy zdl-portal zdl-push zdl-server zdl-task zdl-tomcat3-out zdl3-out zdlploy3-out zdlsupervise3-out`

**DMP** · 4：`dmp-admin dmp-query-server dmp-tag dmp-web` ｜ **IOP** · 4：`iop-base iop-gateway iop-poly iop-station-auth` ｜ **银行/支付通道** · 3：`bank-ability-center bank-front bankpay3-out`

**SLB/负载均衡** · 8：`slb_device slb_device3 slb_device_3 slb_geo2 slb_gw3 slb_level7 slb_level7_intranet slb_zdl_om`

**前端** · 5：`fe-devops feadmin feadmin-pro frontend m-web`

**系统/审计** · 13：`aliyun-prom-* audit-* config-operation-log event-trace event-tracing gc_log internal-alert-history internal-diagnostic_log internal-etl-log k8s-event mse-log sentinel-plus sentinel-token-server`

**其他业务** · 31：`access adapter-device-181 adapter-device-1x adapter-device-210 adapter-tool-2x adapter-tool-2x1-encryption agent-foundation etl-device-1x flow-charge gateway-app gateway-huawei gateway-maint gateway-omp-admin gateway-service-other gateway-zdl guan-zhong hangu message-push mq-consumer-order mq-consumer-order2 new-maint open-platform order-foundation order-foundation-new price-center-serve sso-inside station-site-algo trade-sync xuzhu-m-web ykc-admin yunbao-llm`

---

## 5. 从代码工程定位日志/pid（四层命名模型）

同一服务在四套命名里名字不同，按下表串起来：

**工程目录**（`code-projects/<域>/xxx`）→ **spring.application.name**（= 日志 `__path__` 里的目录名，如 `/opt/spring_app_logs/<spring.name>/logFile.log`）→ **ARMS 应用**（= 容器/部署名，加 `-prod/-uat`）→ **logstore**（采集分库）。

> **最实用的精确钥匙**：查 `all` 时用 `__tag__:__path__: <spring.name>` 过滤，能精准锁定某个工程的日志，**绕开容器名/应用名混乱**。`spring.name` 从工程 `bootstrap*.properties` 的 `spring.application.name` 拿（下表第2列）。

| 工程目录 | spring.name(=日志`__path__`) | ARMS应用(prod) | pid | 主要 logstore |
|---|---|---|---|---|
| trade/order_server | `orderserver` | order-prod | 见 ARMS_PID_CACHE.md | all / order-server / order3-out |
| trade/charge_server | `DeviceBusinessServer` | charge-prod | 查表 | all（关键字 `DeviceBusinessServer`）/ charge-server |
| trade/charge-business-server | `CHARGEBUSINESSSERVER` | charge-business-prod | 查表 | all（关键字 `CHARGEBUSINESSSERVER`）/ charge-business |
| basic/base_server | `BaseServer1` | base-prod | 查表 | all / base-server |
| basic/poly_server | `PolyServer` | poly-prod | 查表 | all / poly-server / poly3-out |
| finance/finance_server | `financeServer` | finance-prod | 查表 | all / finance-server / finance3-out |
| finance/clearing_server | `clearingserver` | clearing-prod | 查表 | all / clearing-server |
| basic/cloud_api_server | `cloudApiServer` | cloud-api-prod | 查表 | all / cloud-api-server |
| basic/price_center_server | `priceCenterServer` | price-center-prod | 查表 | all / price-center-server |
| basic/activity_server | `activityServer` | activity-prod | 查表 | all / activity-server |
| trade/alarm_server | `alarmserver` | alarm-prod | 查表 | all / alarm-server |
| basic/message_push_server | `messagePushServer` | message-push-prod | 查表 | all / message-push |
| basic/event_tracing_server | `EventTracingServer` | — | 查表 | event-tracing / event-trace |
| basic/map-server | `mapServer` | map-prod | 查表 | all |
| device/device-ykcoms | （容器 `device-ykcoms`，日志路径目录却是 `device-coms-server`，历史遗留） | device-ykcoms-prod | 查表 | **device-ykcoms**（运维桩日志，**不在 all**，只能查此专属库） |
| device/device-coms-server | `device-coms-server` | （device 域，查表确认） | 查表 | device-ykcoms / device-* |
| device/device_business | `device-business` | device-business-prod | 查表 | all / device-business |
| support/ykc-osp | `ospServer` | osp-prod | 查表 | all / osp-server |
| basic/osp-backend | `ospBackend` | **无独立 ARMS 应用**（归 osp-prod 或未接入链路监控） | 查表 | osp-backend / all |

**换算规则**：
- **工程目录名 → ARMS 应用**：去 `_server` 后缀、下划线变连字符，加 `-prod/-uat`（`order_server`→`order-prod`，`cloud_api_server`→`cloud-api-prod`）。
- **ARMS 应用前缀 → logstore**：先 `all`，再 `<前缀>-server` / `<前缀>3-out`。
- **pid**：直接查 `ARMS_PID_CACHE.md`（全量 183 应用），**不用跑 `arms_apps.sh`**。
- **不确定时验证**：`arms_apps.sh cn-hangzhou "<关键字>"` 找应用；或查 `all` 看 `__tag__:_container_name_` / `__path__` 反推对应工程。

> 注：`zsh/` 域工程（`*_mos_server` 等）多为蓄柱 OMP fork，对应 `xuzhu-omp-*` 应用；部分工程 `spring.name` 在 Nacos（本地 bootstrap 提取不到），按目录名规则推导即可。

---

## 6. uat 差异要点

- uat 仅 143 库，**业务专属运行库只有 10 个**（clearing/cloud-api/external/foundation-c/new-base/payment/push/reconciliation/station-site-server）→ **查 uat 业务日志基本只查 `all`**。
- uat **设备测试库更多（40 个）**，多了 `device-ocpp` / `device-portal` / `device-xj` / 各 `*-tool` 调试库。
- uat 多 `unionpay-acquire` / `electric-meter` / `skill-hub` / `cloud-eyes`。

---

## 7. 高频服务 pid 速查（ARMS，prod，cn-hangzhou，2026-07-23 快照）

> pid 在应用重建后会变；失效时重跑 `bash scripts/arms_apps.sh cn-hangzhou "<关键字>"`。
> 完整 183 应用见该脚本输出。

| 应用 | pid |
|---|---|
| order-prod | `gb7wlo91dj@781a3e9ef739913` |
| charge-prod | `gb7wlo91dj@5586d3e4bc94dfb` |
| charge-business-prod | `gb7wlo91dj@87da7ca1c850966` |
| finance-prod | `gb7wlo91dj@607b3edaf26ed41` |
| device-prod | `gb7wlo91dj@38346ddc850c055` |
| device-business-prod | `gb7wlo91dj@50052396bbd9165` |
| device-ykcoms-prod | `gb7wlo91dj@f9a35ced77569e5` |
| poly-prod | `gb7wlo91dj@7e52d1bf0070532` |
| poly-center-prod | `gb7wlo91dj@f4d62429f6b4627` |
| payment-prod | `gb7wlo91dj@161067b42c78d5e` |
| gateway-app-prod | `gb7wlo91dj@10ac43d2a856d78` |
| osp-prod | `gb7wlo91dj@3f1a2bb7627f3e4` |
| price-center-prod | `gb7wlo91dj@b8700571e70921f` |
| statistics-prod | `gb7wlo91dj@16317daa9dc314f` |
| trade-order-prod | `gb7wlo91dj@22367e33091b16b` |
| trade-sync-prod | `gb7wlo91dj@6a929f449c55824` |
| flowside-prod | `gb7wlo91dj@6cf96bd24d3223a` |
| foundation-prod | `gb7wlo91dj@df9c0e8a72346d8` |
| clearing-prod | `gb7wlo91dj@ae83a08d280f369` |
| cloud-api-prod | `gb7wlo91dj@2dde8d90c331396` |
| mq-consumer-order-prod | `gb7wlo91dj@ef99265defb0042` |
| alarm-prod | `gb7wlo91dj@b1893987d820904` |
