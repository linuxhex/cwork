# cwork-image 配置模板（Docker 镜像构建推送运行）
# 用法: cp config.example.sh .config.local.sh, 然后把 := 后面的占位符换成实际值
# .config.local.sh 已加入 .gitignore, 切勿提交真实密码
# 使用 := 语法: 同名环境变量优先, 否则用此处的值

# ---- Docker registry ----
# 阿里云 ACR: registry.cn-hangzhou.aliyuncs.com
# Harbor:     172.16.x.x:5000
# 任意 registry: <host>:<port>
: "${IMAGE_REGISTRY:=registry.cn-hangzhou.aliyuncs.com}"

# registry 命名空间（ACR 的 namespace / Harbor 的 project / 留空则不使用）
: "${IMAGE_NAMESPACE:=default}"

# registry 认证（用户名密码）
: "${REGISTRY_USER:=<your-registry-username>}"
: "${REGISTRY_PASS:=<your-registry-password>}"

# ---- 运行目标 ----
# k8s    = 通过 kubectl 更新 K8s deployment
# docker = SSH 到目标机 docker run
# compose= SSH 到目标机 docker-compose up
# none   = 只 build + push，不运行
: "${IMAGE_TARGET:=none}"

# ---- K8s 配置（target=k8s 时需要） ----
: "${KUBECONFIG_PATH:=$HOME/.kube/config}"
: "${K8S_NAMESPACE:=default}"
# deployment 名（默认与镜像名相同，可覆盖）
: "${K8S_DEPLOYMENT:=}"
# container 名（默认与镜像名相同，可覆盖）
: "${K8S_CONTAINER:=}"

# ---- SSH 配置（target=docker/compose 时需要） ----
: "${SSH_HOST:=}"
: "${SSH_USER:=root}"
: "${SSH_PORT:=22}"
: "${SSH_KEY:=$HOME/.ssh/id_rsa}"

# ---- docker run 配置（target=docker 时需要） ----
# 容器名（默认与镜像名相同）
: "${CONTAINER_NAME:=}"
# 端口映射（host:container，多个用空格分隔）
: "${CONTAINER_PORTS:=8080:8080}"
# 环境变量（key=value，多个用空格分隔）
: "${CONTAINER_ENVS:=}"

# ---- docker-compose 配置（target=compose 时需要） ----
: "${COMPOSE_FILE:=docker-compose.yml}"
: "${COMPOSE_SERVICE:=}"

# ---- 构建配置 ----
# 构建超时（秒）
: "${IMAGE_BUILD_TIMEOUT:=600}"
# Java 构建命令
: "${JAVA_BUILD_CMD:=mvn clean package -DskipTests}"
# 前端构建命令
: "${FRONTEND_BUILD_CMD:=npm run build}"
