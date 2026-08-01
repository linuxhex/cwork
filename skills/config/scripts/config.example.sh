# cwork-config 配置模板(Nacos 只读查询)
# 用法: cp config.example.sh .config.local.sh, 然后把 := 后面的占位符换成实际值
# .config.local.sh 已加入 .gitignore, 切勿提交真实 AK/SK
# 凭证来源: devops 工程 devops-server/src/main/java/com/ops/common/config/NacosConfig.java (L46-76)
# 使用 := 语法: 同名环境变量优先, 否则用此处的值

# ---- 集群: 非生产(dev/opendev/k8s-test/k8s-uat 共用一套凭证) ----
: "${NACOS_ADDR_NONPROD:=mse-906789d0-nacos-ans.mse.aliyuncs.com:8848}"
: "${NACOS_AK_NONPROD:=<your-nonprod-access-key>}"
: "${NACOS_SK_NONPROD:=<your-nonprod-secret-key>}"

# ---- 集群: 生产(k8s-prod, 配置查询专用 AK/SK, 与 prod 实例查询的凭证不同) ----
: "${NACOS_ADDR_PROD:=mse-008b5d80-nacos-ans.mse.aliyuncs.com:8848}"
: "${NACOS_AK_PROD:=<your-prod-access-key>}"
: "${NACOS_SK_PROD:=<your-prod-secret-key>}"

# ---- context path: 阿里云 MSE 暴露 /nacos 前缀; devops 工程裸地址无前缀。以 curl -v 实测为准 ----
: "${NACOS_CONTEXT_PATH:=/nacos}"
