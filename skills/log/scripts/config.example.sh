# cwork-log 配置模板
# 用法: cp config.example.sh config.local.sh, 然后把 := 后面的占位符换成实际值
# config.local.sh 已加入 .gitignore, 切勿提交真实密钥
# 使用 := 语法: 同名环境变量优先, 否则用此处的值

: "${ALIBABA_CLOUD_ACCESS_KEY_ID:=<your-access-key-id>}"
: "${ALIBABA_CLOUD_ACCESS_KEY_SECRET:=<your-access-key-secret>}"
: "${SLS_ENDPOINT:=cn-hangzhou.log.aliyuncs.com}"
: "${SLS_PROJECT_PROD:=<prod-sls-project>}"   # 例: k8s-log-xxxxxxxx
: "${SLS_PROJECT_UAT:=<uat-sls-project>}"
: "${SLS_PROJECT_TEST:=<test-sls-project>}"
: "${ARMS_REGION:=cn-hangzhou}"
