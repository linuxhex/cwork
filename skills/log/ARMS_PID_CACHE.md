# ARMS 应用 → pid + 日志库索引（cn-hangzhou）

> 一键重建: `bash scripts/rebuild_index.sh`（重跑 arms_apps + sls list 两环境并匹配）。

> **主库 `all`**（业务结构化日志都在这）；**例外：`device-*` 应用协议日志常只在专属库、不在 all**，主库标 `专属库优先`，查不到去专属库；**`ctp-*` 车队日志也不在 all**，只能查 `ctp-*` 专属库。
> `专属库` 按应用名前缀匹配：prod 应用匹配 prod 库、uat 应用匹配 uat 库；流量低时专属库可能空，回退 all。
> pid 为重建时刻快照，应用重建后失效（信号：arms_traces/arms_trace 返回空或鉴权错 → 重跑本脚本）。

| 应用 | pid | 环境 | 专属库(可选) | 主库 |
|---|---|---|---|---|
| access-prod | gb7wlo91dj@bdc0f55797ba851 | prod | access, access-server | all |
| access-uat | gb7wlo91dj@abcc13e4799af8f | uat | — | all |
| activity-prod | gb7wlo91dj@ec1d510cd3af141 | prod | activity-server, activity3-out | all |
| activity-tob-prod | gb7wlo91dj@19ba44e3167c4c2 | prod | — | all |
| activity-tob-uat | gb7wlo91dj@ec05aa2480e134d | uat | — | all |
| activity-uat | gb7wlo91dj@ef02140e981e5d3 | uat | — | all |
| agent-demo | gb7wlo91dj@6b9749a9426834a | prod | — | all |
| agentrun-9fac7c43-22c2-4692- | gb7wlo91dj@8298a26ed7804c4 | prod | — | all |
| agentrun-agent-test | gb7wlo91dj@33735453d5d81e6 | test | — | all |
| agentrun-proxy-LKDykK | gb7wlo91dj@c105f4391681abc | prod | — | all |
| alarm-prod | gb7wlo91dj@b1893987d820904 | prod | alarm-server | all |
| alarm-uat | gb7wlo91dj@f40e01f568be3a9 | uat | — | all |
| bank-ability-prod | gb7wlo91dj@5c9c580f7d239bc | prod | bank-ability-center | all |
| bank-ability-uat | gb7wlo91dj@0625568bdcc7481 | uat | bank-ability-center | all |
| barrier-js-prod | gb7wlo91dj@8e69c75209565e9 | prod | — | all |
| barrier-kt-prod | gb7wlo91dj@9a03e891dff86ea | prod | — | all |
| barrier-prod | gb7wlo91dj@6eb8dcaa63f18ed | prod | barrier-server | all |
| barrier-uat | gb7wlo91dj@f984081137b7aa5 | uat | — | all |
| base-prod | gb7wlo91dj@39da3fe3a9bafed | prod | base-server | all |
| base-tob-prod | gb7wlo91dj@8468ce3e33d4404 | prod | — | all |
| base-tob-uat | gb7wlo91dj@9b9090dae3bc67c | uat | — | all |
| base-uat | gb7wlo91dj@8c547bd0fc543ed | uat | — | all |
| basejur-prod | gb7wlo91dj@b7260627ab343f6 | prod | basejur3-out | all |
| basejur-uat | gb7wlo91dj@b718c108f62bf1b | uat | — | all |
| charge-business-prod | gb7wlo91dj@87da7ca1c850966 | prod | charge-business | all |
| charge-prod | gb7wlo91dj@5586d3e4bc94dfb | prod | charge-business, charge-server, charge3-out | all |
| charge-uat | gb7wlo91dj@05909ff6e313c69 | uat | — | all |
| clearing-prod | gb7wlo91dj@ae83a08d280f369 | prod | clearing-server | all |
| clearing-uat | gb7wlo91dj@14522024b2a8d97 | uat | clearing-server | all |
| cloud-api-prod | gb7wlo91dj@2dde8d90c331396 | prod | cloud-api-server | all |
| cloud-api-uat | gb7wlo91dj@4e31d916273252b | uat | cloud-api-server | all |
| cncb-emanager-prod | gb7wlo91dj@11020b46fb57c9a | prod | — | all |
| cncb-emanager-uat | gb7wlo91dj@fbffb55d2a77fbf | uat | — | all |
| crop-order-prod | gb7wlo91dj@4fdfdd04122d07b | prod | — | all |
| crop-order-uat | gb7wlo91dj@6cbd234c8b8fbcb | uat | — | all |
| datacenter-prod | gb7wlo91dj@d766befeba3f6b2 | prod | — | all |
| datacenter-uat | gb7wlo91dj@779dbc623774c7c | uat | — | all |
| device-1x-encryption-prod | gb7wlo91dj@31fc1bd03c58d27 | prod | device-1x-encryption | 专属库优先 |
| device-1x-encryption-uat | gb7wlo91dj@ba5eb6944995dba | uat | device-1x-encryption, device-1x-encryption-tool | 专属库优先 |
| device-business-prod | gb7wlo91dj@50052396bbd9165 | prod | device-business | 专属库优先 |
| device-business-uat | gb7wlo91dj@731806656bc8a1d | uat | device-business | 专属库优先 |
| device-collection-host-prod | gb7wlo91dj@7f95703761a75e2 | prod | — | all |
| device-collection-host-uat | gb7wlo91dj@5abd2d1ec590cef | uat | — | all |
| device-collection-uat | gb7wlo91dj@ecc0f7e4b682884 | uat | device-collection | 专属库优先 |
| device-custom-prod | gb7wlo91dj@75aa3272ac759a5 | prod | device-custom | 专属库优先 |
| device-custom-uat | gb7wlo91dj@a4a35ceae2ce17a | uat | device-custom | 专属库优先 |
| device-hubble-prod | gb7wlo91dj@9ee71caefefb960 | prod | device-ykcoms | 专属库优先 |
| device-hubble-uat | gb7wlo91dj@2e00a766f0e6afc | uat | device-ykcoms | 专属库优先 |
| device-monitoring-prod | gb7wlo91dj@0b7f6597db4dd28 | prod | device-monitoring | 专属库优先 |
| device-monitoring-uat | gb7wlo91dj@3dc80b62aef146c | uat | device-monitoring | 专属库优先 |
| device-post-prod | gb7wlo91dj@7a7289b183a0983 | prod | device-post | 专属库优先 |
| device-post-uat | gb7wlo91dj@b11622b060d0f15 | uat | device-post | 专属库优先 |
| device-prod | gb7wlo91dj@38346ddc850c055 | prod | device-* 等33个 | all |
| device-status-prod | gb7wlo91dj@64ea29dae6e9fcc | prod | — | all |
| device-status-uat | gb7wlo91dj@9deb3236b7b5fae | uat | — | all |
| device-uat | gb7wlo91dj@2a903b8072a2800 | uat | device-* 等40个 | all |
| device-ykcoms-prod | gb7wlo91dj@f9a35ced77569e5 | prod | device-ykcoms | 专属库优先 |
| device-ykcoms-uat | gb7wlo91dj@c5e45a863f137e3 | uat | device-ykcoms | 专属库优先 |
| dmp-query-prod | gb7wlo91dj@5f5f9f1511bc759 | prod | dmp-query-server | all |
| dmp-query-uat | gb7wlo91dj@65c4e6a3a39712a | uat | dmp-query-server | all |
| dmp-tag-prod | gb7wlo91dj@3cc0c1896766844 | prod | dmp-tag | all |
| dmp-tag-uat | gb7wlo91dj@c5f215fe2346dcd | uat | dmp-tag | all |
| dts-server-prod | gb7wlo91dj@8548d54bc79367e | prod | — | all |
| dts-server-uat | gb7wlo91dj@8cb622e64ec491f | uat | — | all |
| electric-meter-uat | gb7wlo91dj@c9367568274672f | uat | electric-meter | all |
| experiment-server-prod | gb7wlo91dj@2c6eed39c0fe981 | prod | — | all |
| experiment-server-uat | gb7wlo91dj@0a8a37f05ef9380 | uat | — | all |
| export-cache-prod | gb7wlo91dj@b6610bff191370e | prod | — | all |
| export-cache-uat | gb7wlo91dj@77233b2a2b24ec1 | uat | — | all |
| external-prod | gb7wlo91dj@23d86c4d63f6d39 | prod | external-server, external3-out | all |
| external-uat | gb7wlo91dj@7f72f8fdd47ee72 | uat | external-server, external3-out | all |
| finance-prod | gb7wlo91dj@607b3edaf26ed41 | prod | finance-server, finance3-acc, finance3-out | all |
| finance-server-uat | gb7wlo91dj@b7b4948c6ce28a8 | uat | — | all |
| finance-tob-prod | gb7wlo91dj@16d340bb17c309e | prod | — | all |
| finance-tob-uat | gb7wlo91dj@354ba8975b96ea6 | uat | — | all |
| finance-uat | gb7wlo91dj@20280a105902472 | uat | — | all |
| flow-charge-prod | gb7wlo91dj@38f10b4faf3e2a8 | prod | flow-charge | all |
| flow-charge-uat | gb7wlo91dj@59a21c8e9371978 | uat | flow-charge | all |
| flowside-prod | gb7wlo91dj@6cf96bd24d3223a | prod | flowside3-out | all |
| flowside-uat | gb7wlo91dj@c14d64e8aaa72be | uat | flowside3-out | all |
| foundation-c-prod | gb7wlo91dj@d67d4fbb3bddc77 | prod | foundation-c | all |
| foundation-c-uat | gb7wlo91dj@add516d6c392f4c | uat | foundation-c | all |
| foundation-prod | gb7wlo91dj@df9c0e8a72346d8 | prod | foundation, foundation-c | all |
| foundation-uat | gb7wlo91dj@c6061e218c156e2 | uat | foundation-c | all |
| funagent-app-f2f6bbe427e626f | ed6db11e-47e2-49d0-a263-e7bb5a2d0d72 | prod | — | all |
| gateway-app-gray-prod | gb7wlo91dj@fe6a06a82966939 | prod | — | all |
| gateway-app-prod | gb7wlo91dj@10ac43d2a856d78 | prod | gateway-app | all |
| gateway-app-uat | gb7wlo91dj@cf67c8c0417e717 | uat | — | all |
| gateway-omp-admin-prod | gb7wlo91dj@143397b754c5dd8 | prod | gateway-omp-admin | all |
| gateway-omp-admin-uat | gb7wlo91dj@a0c9c44508fdadc | uat | — | all |
| gateway-other-uat | gb7wlo91dj@7f663738718a9bd | uat | — | all |
| gateway-zdl-prod | gb7wlo91dj@a6edffbab32e0e2 | prod | gateway-zdl | all |
| gateway-zdl-uat | gb7wlo91dj@422781bfe0abf36 | uat | gateway-zdl | all |
| guan-zhong-prod | gb7wlo91dj@b0725a60153481d | prod | guan-zhong | all |
| guan-zhong-uat | gb7wlo91dj@c5b539b6f705f8f | uat | — | all |
| hangu-prod | gb7wlo91dj@b0e3cefeb7adc6a | prod | hangu | all |
| hangu-uat | gb7wlo91dj@b3e0565ed579757 | uat | — | all |
| invoice-prod | gb7wlo91dj@265b23d4fbcc8cb | prod | invoice-server | all |
| invoice-uat | gb7wlo91dj@33f2687462d5f7f | uat | — | all |
| iop-base-prod | gb7wlo91dj@ad8e97d0d34db4e | prod | iop-base | all |
| iop-poly-prod | gb7wlo91dj@2c49e893c000ef4 | prod | iop-poly | all |
| iop-poly-uat | gb7wlo91dj@8fd63e313e6cddf | uat | iop-poly | all |
| iop-station-auth-prod | gb7wlo91dj@a0e1b660b646785 | prod | iop-station-auth | all |
| iop-station-auth-uat | gb7wlo91dj@1d395432b03405a | uat | iop-station-auth | all |
| link-prod | gb7wlo91dj@399aacec1b52e5f | prod | — | all |
| link-uat | gb7wlo91dj@6b7f0afe9b46718 | uat | — | all |
| load-control-prod | gb7wlo91dj@45f78ed0b3d5128 | prod | — | all |
| load-control-uat | gb7wlo91dj@5ebe217058310c2 | uat | — | all |
| map-prod | gb7wlo91dj@65d120a52389377 | prod | — | all |
| map-uat | gb7wlo91dj@b8c672dd74798c2 | uat | — | all |
| message-push-prod | gb7wlo91dj@81cf34285f61d43 | prod | message-push | all |
| message-push-uat | gb7wlo91dj@46c2364fa76d59d | uat | — | all |
| mq-consumer-order-prod | gb7wlo91dj@ef99265defb0042 | prod | mq-consumer-order | all |
| mq-consumer-order-uat | gb7wlo91dj@ea32eae4e9db916 | uat | — | all |
| open-platform-aggregate-prod | gb7wlo91dj@a8c76a6fa2cc51d | prod | — | all |
| open-platform-aggregate-uat | gb7wlo91dj@e02f3634bee6d9c | uat | — | all |
| open-platform-gateway-prod | gb7wlo91dj@4aec0bd945c25c0 | prod | — | all |
| open-platform-gateway-uat | gb7wlo91dj@61feee3acf496db | uat | — | all |
| order-foundation-prod | gb7wlo91dj@fe80d5ca7d2918e | prod | order-foundation, order-foundation-new | all |
| order-foundation-uat | gb7wlo91dj@61fdf889c142676 | uat | — | all |
| order-prod | gb7wlo91dj@781a3e9ef739913 | prod | order-foundation, order-foundation-new, order-server, order3-out | all |
| order-tob-prod | gb7wlo91dj@13a6cf7168f883c | prod | — | all |
| order-tob-uat | gb7wlo91dj@ab310a342fe3272 | uat | — | all |
| order-uat | gb7wlo91dj@0231d7e05609ff6 | uat | — | all |
| osp-agent-prod | gb7wlo91dj@83389be56e7e70c | prod | — | all |
| osp-agent-uat | gb7wlo91dj@130020a1b42e66e | uat | — | all |
| osp-customer-prod | gb7wlo91dj@7e91a0579a7826a | prod | osp-customer | all |
| osp-customer-uat | gb7wlo91dj@0bc7c0cd9115cd5 | uat | osp-customer | all |
| osp-mcp-prod | gb7wlo91dj@db7311ee53b121f | prod | — | all |
| osp-mcp-uat | gb7wlo91dj@84860c9192ce058 | uat | — | all |
| osp-prod | gb7wlo91dj@3f1a2bb7627f3e4 | prod | osp-backend, osp-customer, osp-front, osp-server | all |
| osp-risk-prod | gb7wlo91dj@63603fa2c64b1bb | prod | — | all |
| osp-risk-uat | gb7wlo91dj@8fddaf8e3ea99e1 | uat | — | all |
| osp-uat | gb7wlo91dj@dbbe06dcf94a256 | uat | osp-backend, osp-customer, osp-front, osp-server | all |
| parking-lock-prod | gb7wlo91dj@b936565c50d77c8 | prod | parking-lock3-out | all |
| payment-prod | gb7wlo91dj@161067b42c78d5e | prod | payment-server | all |
| payment-uat | gb7wlo91dj@808b74882a7440e | uat | payment-server | all |
| poly-center-prod | gb7wlo91dj@f4d62429f6b4627 | prod | — | all |
| poly-center-tob-prod | gb7wlo91dj@f29df4c13611809 | prod | — | all |
| poly-center-tob-uat | gb7wlo91dj@951f718623f9d00 | uat | — | all |
| poly-center-uat | gb7wlo91dj@13009ff8aa1aa8b | uat | — | all |
| poly-prod | gb7wlo91dj@7e52d1bf0070532 | prod | poly-server, poly3-out | all |
| poly-server-uat | gb7wlo91dj@b5efe3c42ae97a8 | uat | — | all |
| poly-uat | gb7wlo91dj@635b3edcb7f9b19 | uat | — | all |
| price-center-prod | gb7wlo91dj@b8700571e70921f | prod | price-center-serve, price-center-server | all |
| price-center-tob-prod | gb7wlo91dj@684fce65dbe6653 | prod | — | all |
| price-center-tob-uat | gb7wlo91dj@93ba0daa43ac3b2 | uat | — | all |
| price-center-uat | gb7wlo91dj@1c7481611ed45b2 | uat | — | all |
| station-site-algo | gb7wlo91dj@78f50bdcef8d286 | prod | station-site-algo | all |
| station-site-algo-prod | gb7wlo91dj@d6cc4a75d4b9941 | prod | station-site-algo | all |
| station-site-algo-test | gb7wlo91dj@162292b56fd79d7 | test | station-site-algo | all |
| statistics-poly-prod | gb7wlo91dj@7732d986635d5fb | prod | statistics-poly-server | all |
| statistics-poly-uat | gb7wlo91dj@3ef36d203feb15f | uat | — | all |
| statistics-prod | gb7wlo91dj@16317daa9dc314f | prod | statistics-poly-server, statistics3-out | all |
| statistics-tob-prod | gb7wlo91dj@d08bd2f217122dc | prod | — | all |
| statistics-tob-uat | gb7wlo91dj@fdfc7aaa8ec5a9b | uat | — | all |
| statistics-uat | gb7wlo91dj@65ad03d5d81ae85 | uat | statistics3-out | all |
| trade-order-prod | gb7wlo91dj@22367e33091b16b | prod | — | all |
| trade-order-uat | gb7wlo91dj@ae634aa68477694 | uat | — | all |
| trade-sync-prod | gb7wlo91dj@6a929f449c55824 | prod | trade-sync | all |
| trade-sync-uat | gb7wlo91dj@e74be073614ae8c | uat | trade-sync | all |
| unionpay-acquire-prod | gb7wlo91dj@c219b089605d952 | prod | — | all |
| unionpay-acquire-uat | gb7wlo91dj@db074b588615deb | uat | unionpay-acquire | all |
| xuzhu-omp-device-prod | gb7wlo91dj@f3fc3db43898adc | prod | xuzhu-omp-device | all |
| xuzhu-omp-device-test | gb7wlo91dj@a16271a8a6e61bd | test | xuzhu-omp-device | all |
| xuzhu-omp-poly-prod | gb7wlo91dj@da399fa4c6624b7 | prod | xuzhu-omp-poly | all |
| xuzhu-omp-poly-test | gb7wlo91dj@b61a5d6acab3e1b | test | xuzhu-omp-poly | all |
| xuzhu-omp-resource-prod | gb7wlo91dj@837ab615eba58c9 | prod | xuzhu-omp-resource | all |
| xuzhu-omp-resource-test | gb7wlo91dj@8879b7f96fd679d | test | xuzhu-omp-resource | all |
| xuzhu-omp-statistics-prod | gb7wlo91dj@242ae6e6f52f17a | prod | xuzhu-omp-statistics | all |
| xuzhu-omp-statistics-test | gb7wlo91dj@8e5f9f71bbca074 | test | xuzhu-omp-statistics | all |
| xuzhu-omp-trading-prod | gb7wlo91dj@e6df9edc811ba05 | prod | xuzhu-omp-trading | all |
| xuzhu-omp-trading-test | gb7wlo91dj@594d9e23160e416 | test | xuzhu-omp-trading | all |
| xuzhu-omp-zdl-prod | gb7wlo91dj@a973ef9fdea7119 | prod | xuzhu-omp-zdl | all |
| xuzhu-omp-zdl-test | gb7wlo91dj@045b295d543d86d | test | xuzhu-omp-zdl | all |
| zdl-base-server-prod | gb7wlo91dj@93ddf38455679c4 | prod | zdl-base-server | all |
| zdl-external-prod | gb7wlo91dj@06b5f13b12d5ead | prod | zdl-external | all |
| zdl-external-uat | gb7wlo91dj@d835a3791dfda2c | uat | zdl-external | all |
| zdl-ploy | gb7wlo91dj@8af7458612799a2 | prod | zdl-ploy | all |
| zdl-prod | gb7wlo91dj@06cc0f93aefa51a | prod | zdl-* 等9个 | all |
| zdlsupervise-prod | gb7wlo91dj@6e083710258858c | prod | zdlsupervise3-out | all |
| zdlsupervise-uat | gb7wlo91dj@e2a114d438ff727 | uat | zdlsupervise3-out | all |
