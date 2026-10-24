# cwork-deploy 配置模板（Jenkins + 云效构建部署）
# 用法: cp config.example.sh .config.local.sh, 然后把 := 后面的占位符换成实际值
# .config.local.sh 已加入 .gitignore, 切勿提交真实密码/token
# 使用 := 语法: 同名环境变量优先, 否则用此处的值

# ---- 默认部署平台 ----
# yunxiao = 走云效 AppStack OpenAPI（默认，大部分服务）
# jenkins = 走 Jenkins REST API（platform=jenkins 明确标记的服务，如 device-hubble-server）
: "${DEPLOY_DEFAULT_PLATFORM:=yunxiao}"

# ---- Jenkins 地址 ----
: "${JENKINS_URL:=http://<JENKINS_HOST>:18001}"

# ---- Jenkins 基本认证（user:pass） ----
: "${JENKINS_USER:=<your-username>}"
: "${JENKINS_PASS:=<your-password>}"

# ---- 独立 Jenkins 实例（可选，服务级覆盖） ----
# service-map.json 中条目配 jenkinsCred=JENKINS_OMP 时，读取以下变量覆盖默认实例
# 变量前缀与 jenkinsCred 值一致（如 JENKINS_PRODWEB_* 对应 jenkinsCred=JENKINS_PRODWEB）
: "${JENKINS_OMP_URL:=http://<JENKINS_OMP_HOST>:8078}"
: "${JENKINS_OMP_USER:=<your-username>}"
: "${JENKINS_OMP_PASS:=<your-password>}"

# ---- devops 中间服务地址（仅用于 sync 命令更新服务映射） ----
: "${DEVOPS_URL:=http://<DEVOPS_HOST>:81}"

# ---- 云效 AppStack OpenAPI ----
# API base: https://{YX_DOMAIN}/oapi/v1/appstack/organizations/{YX_ORG_ID}
# 认证方式: x-yunxiao-token 请求头（非 AK/SK 签名）
# token 来源: 云效个人设置 > 个人访问令牌（需 AppStack 读写权限）
: "${YX_DOMAIN:=openapi-rdc.aliyuncs.com}"
: "${YX_ORG_ID:=<your-yunxiao-org-id>}"
: "${YX_TOKEN:=<your-yunxiao-token>}"

# ---- 构建轮询间隔（秒） ----
: "${DEPLOY_POLL_INTERVAL:=5}"

# ---- 构建/部署超时（秒，默认 30 分钟） ----
# 构建和部署共用此超时；deploy 命令最坏情况等待 2×timeout（构建+部署各一轮）
: "${DEPLOY_TIMEOUT:=1800}"
