# cwork-deploy 配置模板（Jenkins + 云效构建部署）
# 用法: cp config.example.sh .config.local.sh, 然后把 := 后面的占位符换成实际值
# .config.local.sh 已加入 .gitignore, 切勿提交真实密码/token
# 使用 := 语法: 同名环境变量优先, 否则用此处的值

# ---- 默认部署平台 ----
# jenkins = 走 Jenkins REST API（默认，向后兼容）
# yunxiao = 走云效 AppStack OpenAPI（代码托管在云效的服务）
: "${DEPLOY_DEFAULT_PLATFORM:=jenkins}"

# ---- Jenkins 地址 ----
: "${JENKINS_URL:=http://172.16.98.169:18001}"

# ---- Jenkins 基本认证（user:pass） ----
: "${JENKINS_USER:=<your-username>}"
: "${JENKINS_PASS:=<your-password>}"

# ---- devops 中间服务地址（仅用于 sync 命令更新服务映射） ----
: "${DEVOPS_URL:=http://172.16.149.95:81}"

# ---- 云效 AppStack OpenAPI ----
# API base: https://{YX_DOMAIN}/oapi/v1/appstack/organizations/{YX_ORG_ID}
# 认证方式: x-yunxiao-token 请求头（非 AK/SK 签名）
# token 来源: 云效个人设置 > 个人访问令牌（需 AppStack 读写权限）
: "${YX_DOMAIN:=openapi-rdc.aliyuncs.com}"
: "${YX_ORG_ID:=<your-yunxiao-org-id>}"
: "${YX_TOKEN:=<your-yunxiao-token>}"

# ---- 构建轮询间隔（秒） ----
: "${DEPLOY_POLL_INTERVAL:=5}"

# ---- 构建超时（秒，默认 30 分钟） ----
: "${DEPLOY_TIMEOUT:=1800}"
