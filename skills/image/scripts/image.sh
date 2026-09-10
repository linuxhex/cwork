#!/usr/bin/env bash
# image.sh — cwork-image 主脚本（Docker 镜像构建 + 推送 + 运行）
#
# 用法:
#   image.sh all           <工程路径> [选项]   构建+推送+运行（最常用）
#   image.sh build         <工程路径> [选项]   仅构建镜像
#   image.sh push          <镜像名>   [选项]   仅推送镜像
#   image.sh run           <镜像名>   [选项]   仅拉起运行
#   image.sh login                   [选项]   登录 registry
#   image.sh list          [--local|--remote]  列出镜像
#   image.sh clean         <镜像名>            清理本地镜像
#   image.sh gen-dockerfile <工程路径>         自动生成 Dockerfile（不构建）
#
# 选项:
#   --tag <tag>          镜像 tag（默认 时间戳-git短hash）
#   --registry <url>     registry 地址（默认配置文件）
#   --namespace <ns>     registry 命名空间（默认配置文件）
#   --target <target>    运行目标 k8s/docker/compose/none（默认 none）
#   --dockerfile <path>  Dockerfile 路径（默认 ./Dockerfile）
#   --name <镜像名>      覆盖自动推导的镜像名
#   --no-cache           docker build --no-cache
#   --port <端口>        容器端口映射（docker run 用，默认 8080:8080）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_common.sh"

load_config

# ── 解析通用选项 ──
# 用法: parse_opts "$@" → 剩余位置参数到 $POSITIONAL[]
parse_opts() {
  POSITIONAL=()
  OPT_TAG=""
  OPT_REGISTRY=""
  OPT_NAMESPACE=""
  OPT_TARGET="${IMAGE_TARGET:-none}"
  OPT_DOCKERFILE=""
  OPT_NAME=""
  OPT_NO_CACHE="false"
  OPT_PORT=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tag)          OPT_TAG="$2"; shift 2 ;;
      --registry)     OPT_REGISTRY="$2"; shift 2 ;;
      --namespace)    OPT_NAMESPACE="$2"; shift 2 ;;
      --target)       OPT_TARGET="$2"; shift 2 ;;
      --dockerfile)   OPT_DOCKERFILE="$2"; shift 2 ;;
      --name)         OPT_NAME="$2"; shift 2 ;;
      --no-cache)     OPT_NO_CACHE="true"; shift ;;
      --port)         OPT_PORT="$2"; shift 2 ;;
      --)             shift; break ;;
      -*|--)          warn "未知选项: $1"; shift ;;
      *)              POSITIONAL+=("$1"); shift ;;
    esac
  done
}

# ── 解析完整镜像名 ──
# 从工程路径 + 选项，推导出完整镜像名
# 输出: <registry>/<namespace>/<name>:<tag>
resolve_image() {
  local projectPath="$1"

  local registry namespace name tag

  registry="${OPT_REGISTRY:-${IMAGE_REGISTRY:-}}"
  namespace="${OPT_NAMESPACE:-${IMAGE_NAMESPACE:-}}"
  name="${OPT_NAME:-$(derive_image_name "$projectPath")}"
  tag="${OPT_TAG:-$(get_default_tag "$projectPath")}"

  if [[ -z "$registry" ]]; then
    fail "registry 地址未配置"
    echo "  用 --registry <url> 指定，或在 .config.local.sh 配 IMAGE_REGISTRY" >&2
    exit 1
  fi

  full_image_name "$registry" "$namespace" "$name" "$tag"
}

# ── 命令: gen-dockerfile ──
cmd_gen_dockerfile() {
  local projectPath="${POSITIONAL[0]:-}"
  if [[ -z "$projectPath" ]]; then
    fail "用法: image.sh gen-dockerfile <工程路径>"
    exit 1
  fi

  if [[ ! -d "$projectPath" && ! -f "$projectPath" ]]; then
    fail "工程路径不存在: $projectPath"
    exit 1
  fi

  local ptype
  ptype=$(detect_project_type "$projectPath") || {
    fail "无法识别工程类型，且已有 Dockerfile 不存在"
    echo "  支持的类型: 有 Dockerfile / pom.xml / package.json / *.jar" >&2
    exit 1
  }

  info "工程类型: $ptype"

  if [[ "$ptype" == "dockerfile" ]]; then
    ok "已存在 Dockerfile: $projectPath/Dockerfile"
    return 0
  fi

  local df
  df=$(generate_dockerfile "$projectPath" "$ptype") || {
    fail "无法为类型 $ptype 自动生成 Dockerfile"
    exit 1
  }
  ok "Dockerfile 已生成: $df"
  cat "$df"
}

# ── 命令: build ──
cmd_build() {
  local projectPath="${POSITIONAL[0]:-}"
  if [[ -z "$projectPath" ]]; then
    fail "用法: image.sh build <工程路径> [选项]"
    exit 1
  fi

  if [[ ! -d "$projectPath" && ! -f "$projectPath" ]]; then
    fail "工程路径不存在: $projectPath"
    exit 1
  fi

  local ptype
  ptype=$(detect_project_type "$projectPath") || {
    fail "无法识别工程类型，且无 Dockerfile"
    echo "  支持的类型: 有 Dockerfile / pom.xml / package.json / *.jar" >&2
    echo "  或用 gen-dockerfile 命令手动生成" >&2
    exit 1
  }

  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo "  构建镜像"
  echo "═══════════════════════════════════════════════════════════════"
  echo "  工程:   $projectPath"
  echo "  类型:   $ptype"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""

  # 预构建（Java mvn package / 前端 npm build）
  if [[ "$ptype" == "java" || "$ptype" == "frontend" ]]; then
    pre_build "$projectPath" "$ptype" || exit 1
  fi

  # 无 Dockerfile 时自动生成
  local dockerfile="$OPT_DOCKERFILE"
  if [[ -z "$dockerfile" ]]; then
    if [[ "$ptype" == "dockerfile" ]]; then
      dockerfile="$projectPath/Dockerfile"
    else
      if [[ ! -f "$projectPath/Dockerfile" ]]; then
        info "无 Dockerfile，自动生成（类型: $ptype）"
        dockerfile=$(generate_dockerfile "$projectPath" "$ptype") || {
          fail "无法自动生成 Dockerfile"
          exit 1
        }
        ok "Dockerfile 已生成: $dockerfile"
      else
        dockerfile="$projectPath/Dockerfile"
      fi
    fi
  fi

  # 推导完整镜像名
  local image
  image=$(resolve_image "$projectPath")
  info "镜像名: $image"
  echo ""

  # 构建
  local context="$projectPath"
  if [[ "$ptype" == "jar" && ! -d "$projectPath" ]]; then
    # 裸 jar 文件，context 用其所在目录
    context="$(dirname "$projectPath")"
  fi

  docker_build "$context" "$image" "$dockerfile" "$OPT_NO_CACHE" || exit 1
  echo ""
  echo "$image"  # 输出完整镜像名供后续命令用
}

# ── 命令: push ──
cmd_push() {
  local image="${POSITIONAL[0]:-}"

  if [[ -z "$image" ]]; then
    fail "用法: image.sh push <镜像名> [选项]"
    exit 1
  fi

  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo "  推送镜像"
  echo "═══════════════════════════════════════════════════════════════"
  echo "  镜像: $image"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""

  # 先登录
  local registry="${OPT_REGISTRY:-${IMAGE_REGISTRY:-}}"
  docker_login "$registry" || exit 1
  echo ""

  # 推送
  docker_push "$image" || exit 1
}

# ── 命令: run（K8s） ──
run_k8s() {
  local image="$1"
  local name="${OPT_NAME:-$(echo "$image" | sed 's|.*/||; s|:.*||')}"
  local deployment="${K8S_DEPLOYMENT:-$name}"
  local container="${K8S_CONTAINER:-$name}"
  local namespace="${K8S_NAMESPACE:-default}"
  local kubeconfig="${KUBECONFIG_PATH:-$HOME/.kube/config}"

  if [[ ! -f "$kubeconfig" ]]; then
    fail "kubeconfig 不存在: $kubeconfig"
    echo "  配置 KUBECONFIG_PATH 或确保 ~/.kube/config 存在" >&2
    exit 1
  fi

  export KUBECONFIG="$kubeconfig"

  echo ""
  info "K8s 更新 deployment: $deployment (namespace=$namespace)"
  info "  container: $container → $image"

  if $KUBECTL set image "deployment/${deployment}" "${container}=${image}" -n "$namespace" 2>&1; then
    ok "deployment 镜像已更新"
  else
    fail "kubectl set image 失败"
    exit 1
  fi

  info "等待 rollout 完成..."
  if $KUBECTL rollout status "deployment/${deployment}" -n "$namespace" --timeout=300s 2>&1; then
    ok "K8s rollout 成功"
  else
    warn "rollout 状态未知，请手动检查: kubectl rollout status deployment/$deployment -n $namespace"
  fi
}

# ── 命令: run（裸机 Docker） ──
run_docker() {
  local image="$1"
  local name="${OPT_NAME:-$(echo "$image" | sed 's|.*/||; s|:.*||')}"
  local containerName="${CONTAINER_NAME:-$name}"
  local ports="${OPT_PORT:-${CONTAINER_PORTS:-8080:8080}}"
  local host="${SSH_HOST:-}"
  local user="${SSH_USER:-root}"
  local port="${SSH_PORT:-22}"
  local key="${SSH_KEY:-$HOME/.ssh/id_rsa}"

  if [[ -z "$host" ]]; then
    fail "SSH_HOST 未配置（target=docker 需要 SSH 到目标机）"
    exit 1
  fi

  # 构造端口映射参数
  local portArgs=""
  for p in $ports; do
    portArgs="$portArgs -p $p"
  done

  # 构造环境变量参数
  local envArgs=""
  for e in ${CONTAINER_ENVS:-}; do
    envArgs="$envArgs -e $e"
  done

  local cmd="docker pull $image"
  cmd="$cmd && (docker stop $containerName 2>/dev/null || true)"
  cmd="$cmd && (docker rm $containerName 2>/dev/null || true)"
  cmd="$cmd && docker run -d --name $containerName $portArgs $envArgs $image"

  echo ""
  info "SSH 到 $host:$port 拉起容器: $containerName"
  info "  镜像: $image"
  info "  端口: $ports"

  ssh_exec "$host" "$cmd" "$user" "$port" "$key" || {
    fail "远程 docker run 失败"
    exit 1
  }
  ok "容器已启动: $containerName @ $host"
}

# ── 命令: run（docker-compose） ──
run_compose() {
  local image="$1"
  local host="${SSH_HOST:-}"
  local user="${SSH_USER:-root}"
  local port="${SSH_PORT:-22}"
  local key="${SSH_KEY:-$HOME/.ssh/id_rsa}"
  local composeFile="${COMPOSE_FILE:-docker-compose.yml}"
  local service="${COMPOSE_SERVICE:-}"

  if [[ -z "$host" ]]; then
    fail "SSH_HOST 未配置（target=compose 需要 SSH 到目标机）"
    exit 1
  fi

  local cmd="docker pull $image"
  if [[ -n "$service" ]]; then
    cmd="$cmd && docker-compose -f $composeFile up -d $service"
  else
    cmd="$cmd && docker-compose -f $composeFile up -d"
  fi

  echo ""
  info "SSH 到 $host:$port 执行 docker-compose"
  info "  compose: $composeFile"
  info "  service: ${service:-全部}"
  info "  镜像: $image"

  ssh_exec "$host" "$cmd" "$user" "$port" "$key" || {
    fail "远程 docker-compose 失败"
    exit 1
  }
  ok "docker-compose 已启动 @ $host"
}

# ── 命令: run ──
cmd_run() {
  local image="${POSITIONAL[0]:-}"
  if [[ -z "$image" ]]; then
    fail "用法: image.sh run <镜像名> [选项]"
    exit 1
  fi

  local target="$OPT_TARGET"

  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo "  拉起运行"
  echo "═══════════════════════════════════════════════════════════════"
  echo "  镜像:   $image"
  echo "  target: $target"
  echo "═══════════════════════════════════════════════════════════════"

  case "$target" in
    k8s)     run_k8s "$image" ;;
    docker)  run_docker "$image" ;;
    compose) run_compose "$image" ;;
    none)    info "target=none，不运行（仅 build + push）" ;;
    *)       fail "未知 target: $target（可选: k8s/docker/compose/none）"; exit 1 ;;
  esac
}

# ── 命令: all（build + push + run） ──
cmd_all() {
  local projectPath="${POSITIONAL[0]:-}"
  if [[ -z "$projectPath" ]]; then
    fail "用法: image.sh all <工程路径> [选项]"
    exit 1
  fi

  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo "  完整流程（构建 → 推送 → 运行）"
  echo "═══════════════════════════════════════════════════════════════"
  echo "  工程:   $projectPath"
  echo "  target: $OPT_TARGET"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""

  # 步骤 1: 构建
  info "[1/3] 构建镜像..."
  local image
  image=$(cmd_build "$projectPath" | tail -1) || exit 1
  echo ""

  # 步骤 2: 推送
  info "[2/3] 推送镜像..."
  cmd_push "$image" || exit 1
  echo ""

  # 步骤 3: 运行
  info "[3/3] 拉起运行..."
  cmd_run "$image"
}

# ── 命令: login ──
cmd_login() {
  local registry="${OPT_REGISTRY:-${IMAGE_REGISTRY:-}}"
  docker_login "$registry"
}

# ── 命令: list ──
cmd_list() {
  local scope="${POSITIONAL[0]:-local}"

  ensure_docker

  case "$scope" in
    --local|-l|local)
      info "本地镜像:"
      $DOCKER images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}" 2>/dev/null
      ;;
    --remote|-r|remote)
      local registry="${OPT_REGISTRY:-${IMAGE_REGISTRY:-}}"
      info "远程 registry 镜像（$registry）:"
      echo "  提示: 部分 registry 不支持 list API，需到控制台查看"
      $DOCKER search "$registry" 2>/dev/null || warn "无法列出远程镜像（registry 可能不支持 search）"
      ;;
    *)
      info "本地镜像:"
      $DOCKER images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}" 2>/dev/null
      ;;
  esac
}

# ── 命令: clean ──
cmd_clean() {
  local image="${POSITIONAL[0]:-}"
  if [[ -z "$image" ]]; then
    fail "用法: image.sh clean <镜像名>"
    exit 1
  fi

  ensure_docker

  info "清理本地镜像: $image"
  $DOCKER rmi "$image" 2>/dev/null && ok "已清理: $image" || warn "镜像不存在或清理失败: $image"
}

# ── 主入口 ──
usage() {
  cat << 'EOF'
cwork-image — 本地工程/jar 打包 Docker 镜像 + push registry + 服务端拉起运行

用法:
  image.sh all            <工程路径> [选项]   构建+推送+运行（最常用）
  image.sh build          <工程路径> [选项]   仅构建镜像
  image.sh push           <镜像名>   [选项]   仅推送镜像
  image.sh run            <镜像名>   [选项]   仅拉起运行
  image.sh login                    [选项]   登录 registry
  image.sh list           [--local|--remote]  列出镜像
  image.sh clean          <镜像名>            清理本地镜像
  image.sh gen-dockerfile <工程路径>         自动生成 Dockerfile（不构建）

选项:
  --tag <tag>          镜像 tag（默认 时间戳-git短hash）
  --registry <url>     registry 地址（默认配置文件）
  --namespace <ns>     registry 命名空间（默认配置文件）
  --target <target>    运行目标 k8s/docker/compose/none（默认 none）
  --dockerfile <path>  Dockerfile 路径（默认 ./Dockerfile）
  --name <镜像名>      覆盖自动推导的镜像名
  --no-cache           docker build --no-cache
  --port <端口>        容器端口映射（docker run 用，默认 8080:8080）

工程类型自动探测:
  有 Dockerfile → 直接用
  有 pom.xml    → Java 工程（mvn package + 自动生成 Dockerfile）
  有 package.json → 前端工程（npm build + 自动生成 nginx Dockerfile）
  *.jar 文件   → 裸 jar（自动生成 JRE Dockerfile）

示例:
  image.sh all /path/to/project --target k8s
  image.sh all /path/to/project --target none --tag v1.0.0
  image.sh build /path/to/java-project --no-cache
  image.sh push registry.cn-hangzhou.aliyuncs.com/ns/app:v1.0.0
  image.sh run registry.cn-hangzhou.aliyuncs.com/ns/app:v1.0.0 --target docker
  image.sh gen-dockerfile /path/to/java-project
  image.sh login
  image.sh list --local
  image.sh clean registry.cn-hangzhou.aliyuncs.com/ns/app:v1.0.0
EOF
}

main() {
  local cmd="${1:-}"
  shift || true

  parse_opts "$@"

  case "$cmd" in
    all)
      [[ ${#POSITIONAL[@]} -lt 1 ]] && { fail "用法: image.sh all <工程路径> [选项]"; exit 1; }
      cmd_all
      ;;
    build)
      [[ ${#POSITIONAL[@]} -lt 1 ]] && { fail "用法: image.sh build <工程路径> [选项]"; exit 1; }
      cmd_build "${POSITIONAL[0]}"
      ;;
    push)
      [[ ${#POSITIONAL[@]} -lt 1 ]] && { fail "用法: image.sh push <镜像名> [选项]"; exit 1; }
      cmd_push "${POSITIONAL[0]}"
      ;;
    run)
      [[ ${#POSITIONAL[@]} -lt 1 ]] && { fail "用法: image.sh run <镜像名> [选项]"; exit 1; }
      cmd_run "${POSITIONAL[0]}"
      ;;
    login)
      cmd_login
      ;;
    list)
      cmd_list "${POSITIONAL[0]:-}"
      ;;
    clean)
      [[ ${#POSITIONAL[@]} -lt 1 ]] && { fail "用法: image.sh clean <镜像名>"; exit 1; }
      cmd_clean "${POSITIONAL[0]}"
      ;;
    gen-dockerfile|gen)
      [[ ${#POSITIONAL[@]} -lt 1 ]] && { fail "用法: image.sh gen-dockerfile <工程路径>"; exit 1; }
      cmd_gen_dockerfile
      ;;
    ""|-h|--help|help)
      usage
      ;;
    *)
      fail "未知命令: $cmd"
      usage
      exit 1
      ;;
  esac
}

main "$@"
