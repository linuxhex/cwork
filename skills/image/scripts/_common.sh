#!/usr/bin/env bash
# _common.sh — Docker registry 认证 + 构建/推送/运行 封装（cwork-image 共享）

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# 使用 docker 完整路径，避免 source 时 PATH 问题
DOCKER="${DOCKER:-$(which docker 2>/dev/null || echo /usr/local/bin/docker)}"
KUBECTL="${KUBECTL:-$(which kubectl 2>/dev/null || echo /usr/local/bin/kubectl)}"
SSH_BIN="${SSH_BIN:-$(which ssh 2>/dev/null || echo /usr/bin/ssh)}"
GIT_BIN="${GIT_BIN:-$(which git 2>/dev/null || echo /usr/bin/git)}"

# ── 加载凭证 ──
load_config() {
  local cfg="$SCRIPT_DIR/.config.local.sh"
  if [[ -f "$cfg" ]]; then
    # shellcheck source=/dev/null
    source "$cfg"
  fi

  # CWORK_HOME 回源仓库读凭证（IDE 安装场景）
  if [[ -z "${IMAGE_REGISTRY:-}" || -z "${REGISTRY_USER:-}" ]] && [[ -n "${CWORK_HOME:-}" ]]; then
    local src_cfg="$CWORK_HOME/skills/image/scripts/.config.local.sh"
    if [[ -f "$src_cfg" ]]; then
      # shellcheck source=/dev/null
      source "$src_cfg"
    fi
  fi
}

# ── 确保 Docker 可用 ──
ensure_docker() {
  if ! command -v docker &>/dev/null; then
    echo "错误: Docker 未安装" >&2
    echo "  请先安装 Docker: https://docs.docker.com/get-docker/" >&2
    exit 1
  fi
  if ! docker info &>/dev/null; then
    echo "错误: Docker 未运行或无权限" >&2
    echo "  请启动 Docker Desktop 或确认当前用户在 docker 组" >&2
    exit 1
  fi
}

# ── 确保 registry 凭证就绪 ──
ensure_registry_config() {
  if [[ -z "${IMAGE_REGISTRY:-}" ]]; then
    echo "错误: registry 地址未配置" >&2
    echo "  cp $SCRIPT_DIR/config.example.sh $SCRIPT_DIR/.config.local.sh" >&2
    echo "  然后编辑 .config.local.sh 填入 IMAGE_REGISTRY / REGISTRY_USER / REGISTRY_PASS" >&2
    exit 1
  fi
}

# ── 颜色输出 ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail()  { echo -e "${RED}[FAIL]${NC} $*"; }

# ============================================================
# 镜像名 / tag 推导
# ============================================================

# ── 从工程路径推导镜像名（取目录名，去 .git 后缀） ──
# 用法: derive_image_name <工程路径>
derive_image_name() {
  local path="$1"
  local name
  name="$(basename "$path")"
  # 去掉 .git 后缀
  name="${name%.git}"
  # 下划线转连字符（镜像名不允许大写）
  name="$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr '_' '-')"
  echo "$name"
}

# ── 生成默认 tag：时间戳 + git 短 hash ──
# 用法: get_default_tag [工程路径]
get_default_tag() {
  local path="${1:-.}"
  local ts hash
  ts="$(date '+%Y%m%d%H%M%S')"
  if [[ -d "$path/.git" ]] || "$GIT_BIN" -C "$path" rev-parse --git-dir &>/dev/null; then
    hash="$("$GIT_BIN" -C "$path" rev-parse --short HEAD 2>/dev/null || echo 'nogit')"
  else
    hash="nogit"
  fi
  echo "${ts}-${hash}"
}

# ── 拼接完整镜像名 ──
# 用法: full_image_name <registry> <namespace> <name> <tag>
full_image_name() {
  local registry="$1"
  local namespace="$2"
  local name="$3"
  local tag="$4"
  if [[ -n "$namespace" ]]; then
    echo "${registry}/${namespace}/${name}:${tag}"
  else
    echo "${registry}/${name}:${tag}"
  fi
}

# ============================================================
# Docker 操作封装
# ============================================================

# ── 登录 registry ──
# 用法: docker_login [registry] [user] [pass]
docker_login() {
  local registry="${1:-${IMAGE_REGISTRY:-}}"
  local user="${2:-${REGISTRY_USER:-}}"
  local pass="${3:-${REGISTRY_PASS:-}}"

  ensure_registry_config

  if [[ -z "$user" || -z "$pass" ]]; then
    echo "错误: registry 凭证未配置（REGISTRY_USER / REGISTRY_PASS）" >&2
    exit 1
  fi

  info "登录 registry: $registry"
  if echo "$pass" | $DOCKER login "$registry" -u "$user" --password-stdin &>/dev/null; then
    ok "registry 登录成功"
    return 0
  else
    fail "registry 登录失败"
    echo "  检查: ① 凭证是否正确 ② registry 地址是否可达 ③ 是否有推送权限" >&2
    return 1
  fi
}

# ── 构建镜像 ──
# 用法: docker_build <context_dir> <full_image> [dockerfile] [no_cache]
docker_build() {
  local context="$1"
  local image="$2"
  local dockerfile="${3:-}"
  local noCache="${4:-false}"

  ensure_docker

  local buildArgs=()
  buildArgs+=("build" "-t" "$image")
  if [[ -n "$dockerfile" ]]; then
    buildArgs+=("-f" "$dockerfile")
  fi
  if [[ "$noCache" == "true" ]]; then
    buildArgs+=("--no-cache")
  fi
  buildArgs+=("$context")

  info "构建镜像: $image"
  info "  context: $context"
  [[ -n "$dockerfile" ]] && info "  dockerfile: $dockerfile"

  if $DOCKER "${buildArgs[@]}" 2>&1; then
    ok "镜像构建成功: $image"
    return 0
  else
    fail "镜像构建失败: $image"
    return 1
  fi
}

# ── 推送镜像 ──
# 用法: docker_push <full_image>
docker_push() {
  local image="$1"
  ensure_docker

  info "推送镜像: $image"
  if $DOCKER push "$image" 2>&1; then
    ok "镜像推送成功: $image"
    return 0
  else
    fail "镜像推送失败: $image"
    echo "  检查: ① 是否已登录 registry ② tag 是否正确 ③ 网络是否通" >&2
    return 1
  fi
}

# ============================================================
# SSH 远程执行封装
# ============================================================

# ── SSH 远程执行命令 ──
# 用法: ssh_exec <host> <command> [user] [port] [key]
ssh_exec() {
  local host="$1"
  local cmd="$2"
  local user="${3:-${SSH_USER:-root}}"
  local port="${4:-${SSH_PORT:-22}}"
  local key="${5:-${SSH_KEY:-$HOME/.ssh/id_rsa}}"

  if [[ -z "$host" ]]; then
    echo "错误: SSH_HOST 未配置" >&2
    return 1
  fi

  local sshArgs=(-o StrictHostKeyChecking=no -o ConnectTimeout=10 -p "$port")
  if [[ -n "$key" && -f "$key" ]]; then
    sshArgs+=(-i "$key")
  fi

  $SSH_BIN "${sshArgs[@]}" "${user}@${host}" "$cmd"
}

# ============================================================
# 工程类型探测
# ============================================================

# ── 探测工程类型 ──
# 用法: detect_project_type <工程路径>
# 输出: dockerfile / java / frontend / jar / unknown
detect_project_type() {
  local path="$1"

  if [[ -f "$path/Dockerfile" ]]; then
    echo "dockerfile"
    return 0
  fi

  if [[ -f "$path/pom.xml" ]]; then
    echo "java"
    return 0
  fi

  if [[ -f "$path/package.json" ]]; then
    echo "frontend"
    return 0
  fi

  # 裸 jar：路径本身是 .jar 文件，或目录下只有一个 .jar
  if [[ "$path" == *.jar ]] && [[ -f "$path" ]]; then
    echo "jar"
    return 0
  fi
  if [[ -d "$path" ]]; then
    local jarCount
    jarCount=$(find "$path" -maxdepth 1 -name "*.jar" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$jarCount" -eq 1 ]]; then
      echo "jar"
      return 0
    fi
  fi

  echo "unknown"
  return 1
}

# ── 自动生成 Dockerfile ──
# 用法: generate_dockerfile <工程路径> <类型>
# 在工程路径下生成 Dockerfile
generate_dockerfile() {
  local path="$1"
  local type="$2"
  local df="$path/Dockerfile"

  case "$type" in
    java)
      cat > "$df" << 'EOF'
# 自动生成 by cwork-image — Java/Spring Boot
FROM openjdk:8-jre-slim
COPY target/*.jar /app/app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
EOF
      ;;
    frontend)
      cat > "$df" << 'EOF'
# 自动生成 by cwork-image — 前端 nginx
FROM nginx:alpine
COPY dist/ /usr/share/nginx/html/
EXPOSE 80
EOF
      ;;
    jar)
      local jarFile
      jarFile=$(find "$path" -maxdepth 1 -name "*.jar" 2>/dev/null | head -1)
      if [[ -z "$jarFile" ]]; then
        jarFile="$(basename "$path")"
      fi
      cat > "$df" << EOF
# 自动生成 by cwork-image — 裸 jar
FROM openjdk:8-jre-slim
COPY ${jarFile##*/} /app/app.jar
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
EOF
      ;;
    *)
      return 1
      ;;
  esac

  echo "$df"
}

# ── 工程预构建（Java mvn package / 前端 npm build） ──
# 用法: pre_build <工程路径> <类型>
pre_build() {
  local path="$1"
  local type="$2"

  case "$type" in
    java)
      local cmd="${JAVA_BUILD_CMD:-mvn clean package -DskipTests}"
      info "Java 工程预构建: $cmd"
      (cd "$path" && eval "$cmd" 2>&1) || {
        fail "Java 预构建失败: $cmd"
        return 1
      }
      ok "Java 预构建完成"
      ;;
    frontend)
      local cmd="${FRONTEND_BUILD_CMD:-npm run build}"
      info "前端工程预构建: $cmd"
      (cd "$path" && eval "$cmd" 2>&1) || {
        fail "前端预构建失败: $cmd"
        return 1
      }
      ok "前端预构建完成"
      ;;
    *)
      # dockerfile / jar 不需要预构建
      ;;
  esac
  return 0
}
