# cwork-graf 配置模板(Grafana 监控查询)
# 用法: cp config.example.sh .config.local.sh, 然后把 := 后面的占位符换成实际值
# .config.local.sh 已加入 .gitignore, 切勿提交真实密码
# 使用 := 语法: 同名环境变量优先, 否则用此处的值

# ---- Grafana 地址 ----
: "${GRAFANA_URL:=https://graf.ykccn.net}"

# ---- 登录凭证 ----
: "${GRAFANA_USER:=<your-username>}"
: "${GRAFANA_PASS:=<your-password>}"

# ---- Prometheus 数据源 UID（默认值，可在查询时覆盖） ----
: "${GRAFANA_DS_UID:=6A__NzsMk}"
