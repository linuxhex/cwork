#!/usr/bin/env bash
# deploy.sh — cwork-deploy 主脚本（curl 封装 Jenkins + 云效 API）
#
# 用法:
#   deploy.sh deploy  <appName> <env> <branch>   # 构建+部署（最常用）
#   deploy.sh build   <appName> <branch>         # 仅触发构建
#   deploy.sh execute <appName> <env> <branch>   # 仅触发部署（需先构建）
#   deploy.sh status   <jobName> [buildNum]      # 查询构建状态（Jenkins）
#   deploy.sh list     [关键字]                   # 列出可用服务
#   deploy.sh jobs     <appName>                 # 查看服务的 Jenkins 作业名
#   deploy.sh console  <jobName> <buildNum>      # 查看构建控制台日志（Jenkins）
#   deploy.sh sync                               # 从 devops API 同步服务映射
#
# 平台路由:
#   service-map.json 中 platform=yunxiao 的服务走云效 AppStack API
#   其余走 Jenkins REST API（默认，向后兼容）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_common.sh"

load_config

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

# ── 命令: list ──
cmd_list() {
  local keyword="${1:-}"
  info "可用服务列表（来自 service-map.json）:"
  echo ""
  if [[ -z "$keyword" ]]; then
    list_service_names | column -t -s '  '
  else
    list_service_names | grep -i "$keyword" || warn "未找到匹配 '$keyword' 的服务"
  fi
  echo ""
  local count
  count=$(list_service_names | wc -l | tr -d ' ')
  ok "共 $count 个服务"
}

# ── 命令: jobs ──
cmd_jobs() {
  local appName="$1"
  local svc
  svc=$(lookup_service "$appName") || { fail "服务 '$appName' 未在映射中找到"; exit 1; }

  local buildJob executeJobs
  buildJob=$(echo "$svc" | python3 -c "import json,sys; print(json.load(sys.stdin).get('buildJob',''))")
  executeJobs=$(echo "$svc" | python3 -c "
import json,sys
s = json.load(sys.stdin)
ej = s.get('executeJob', {})
for env, job in sorted(ej.items()):
    print(f'  {env}: {job}')
")

  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo "  服务: $appName"
  echo "═══════════════════════════════════════════════════════════════"
  echo "  构建作业 (buildJob): $buildJob"
  echo "  部署作业 (executeJob):"
  echo "$executeJobs"
  echo "═══════════════════════════════════════════════════════════════"
}

# ── 获取最后构建号 ──
get_last_build_number() {
  local jobName="$1"
  local num
  num=$(jenkins_get "/job/${jobName}/lastBuild/buildNumber" 2>/dev/null || echo "")
  if [[ -z "$num" || ! "$num" =~ ^[0-9]+$ ]]; then
    echo ""
    return 1
  fi
  echo "$num"
}

# ── 触发构建作业 ──
# 对应 JenkinsController.buildJob: 参数 RELEASE=origin/{branch}, PATCH=default
trigger_build_job() {
  local jobName="$1"
  local branch="$2"

  local lastNum newNum
  lastNum=$(get_last_build_number "$jobName" 2>/dev/null || echo "0")

  # 触发构建（POST buildWithParameters）
  local resp
  resp=$(jenkins_post "/job/${jobName}/buildWithParameters" \
    --data-urlencode "RELEASE=origin/${branch}" \
    --data-urlencode "PATCH=default" 2>&1 || true)

  # 轮询等待新构建号出现
  local i=0
  local max_wait=60
  while [[ $i -lt $max_wait ]]; do
    newNum=$(get_last_build_number "$jobName" 2>/dev/null || echo "0")
    if [[ "$newNum" -gt "$lastNum" ]]; then
      echo "$newNum"
      return 0
    fi
    sleep 2
    i=$((i + 1))
  done

  # 超时但可能已触发，返回当前最新号
  newNum=$(get_last_build_number "$jobName" 2>/dev/null || echo "0")
  echo "$newNum"
  return 0
}

# ── 触发部署作业 ──
# 对应 JenkinsController.executeJob: 参数 IMAGE_VERSION={dateTime}----{branch}
trigger_execute_job() {
  local jobName="$1"
  local branch="$2"
  local dateTime="$3"

  local lastNum newNum
  lastNum=$(get_last_build_number "$jobName" 2>/dev/null || echo "0")

  local imageVersion="${dateTime}----${branch}"
  local resp
  resp=$(jenkins_post "/job/${jobName}/buildWithParameters" \
    --data-urlencode "IMAGE_VERSION=${imageVersion}" 2>&1 || true)

  # 轮询等待新构建号
  local i=0
  local max_wait=60
  while [[ $i -lt $max_wait ]]; do
    newNum=$(get_last_build_number "$jobName" 2>/dev/null || echo "0")
    if [[ "$newNum" -gt "$lastNum" ]]; then
      echo "$newNum"
      return 0
    fi
    sleep 2
    i=$((i + 1))
  done

  newNum=$(get_last_build_number "$jobName" 2>/dev/null || echo "0")
  echo "$newNum"
  return 0
}

# ── 触发部署（deploy job，带 MASTER_APPNAME/SUB_APPNAME/BRANCH 参数） ──
# 对应 JenkinsController.deploy
trigger_deploy_job() {
  local deployJob="$1"
  local appName="$2"
  local swim="$3"
  local branch="$4"

  local lastNum newNum
  lastNum=$(get_last_build_number "$deployJob" 2>/dev/null || echo "0")

  local resp
  if [[ -n "$swim" ]]; then
    resp=$(jenkins_post "/job/${deployJob}/buildWithParameters" \
      --data-urlencode "MASTER_APPNAME=${appName}" \
      --data-urlencode "SUB_APPNAME=${swim}" \
      --data-urlencode "BRANCH=${branch}" 2>&1 || true)
  else
    # 无泳道时不传 SUB_APPNAME（prod 环境 / 部署作业不需要泳道参数的场景）
    resp=$(jenkins_post "/job/${deployJob}/buildWithParameters" \
      --data-urlencode "MASTER_APPNAME=${appName}" \
      --data-urlencode "BRANCH=${branch}" 2>&1 || true)
  fi

  # 轮询等待新构建号
  local i=0
  local max_wait=60
  while [[ $i -lt $max_wait ]]; do
    newNum=$(get_last_build_number "$deployJob" 2>/dev/null || echo "0")
    if [[ "$newNum" -gt "$lastNum" ]]; then
      echo "$newNum"
      return 0
    fi
    sleep 2
    i=$((i + 1))
  done

  newNum=$(get_last_build_number "$deployJob" 2>/dev/null || echo "0")
  echo "$newNum"
  return 0
}

# ── 检查构建状态 ──
# 对应 JenkinsController.getJobStatus: 检查 consoleText 包含 "Finished: SUCCESS"/"Finished: FAILURE"
get_job_status() {
  local jobName="$1"
  local buildNum="$2"

  local console
  console=$(jenkins_get "/job/${jobName}/${buildNum}/consoleText" 2>/dev/null || echo "")

  if [[ -z "$console" ]]; then
    echo "unknown"
    return 0
  fi

  if echo "$console" | grep -q "Finished: FAILURE"; then
    echo "fail"
    return 0
  fi

  if echo "$console" | grep -q "Finished: SUCCESS"; then
    echo "success"
    return 0
  fi

  echo "running"
  return 0
}

# ── 轮询等待 Jenkins 作业完成 ──
# 用法: wait_jenkins_job_complete <jobName> <buildNum> [label]
# label: "构建" / "部署"（显示用，默认"作业"）
# 轮询 get_job_status 直到非 running 或超时，输出终态到 stdout
wait_jenkins_job_complete() {
  local jobName="$1"
  local buildNum="$2"
  local label="${3:-作业}"

  local status="running"
  local poll_interval="${DEPLOY_POLL_INTERVAL:-5}"
  local timeout="${DEPLOY_TIMEOUT:-1800}"
  local elapsed=0
  while [[ "$status" == "running" && $elapsed -lt $timeout ]]; do
    sleep "$poll_interval"
    elapsed=$((elapsed + poll_interval))
    status=$(get_job_status "$jobName" "$buildNum")
    local mins=$((elapsed / 60))
    local secs=$((elapsed % 60))
    echo -ne "\r  ${label}状态: $status (已等待 ${mins}m${secs}s)    "
  done
  echo ""
  echo "$status"
}

# ── 报告 Jenkins 作业结果并按需退出 ──
# 用法: report_jenkins_result <status> <jobName> <buildNum> <label>
# status 非 success 时 exit 1
report_jenkins_result() {
  local status="$1"
  local jobName="$2"
  local buildNum="$3"
  local label="$4"

  local consoleUrl="${JENKINS_URL:-http://172.16.98.169:18001}/job/${jobName}/${buildNum}/console"

  case "$status" in
    success)
      ok "${label}成功！构建号: #${buildNum}"
      echo ""
      info "${label}详情: ${consoleUrl}"
      ;;
    fail)
      fail "${label}失败！构建号: #${buildNum}"
      echo ""
      info "查看${label}日志:"
      echo "  deploy.sh console $jobName $buildNum"
      echo "  ${consoleUrl}"
      exit 1
      ;;
    running)
      warn "${label}超时（${DEPLOY_TIMEOUT:-1800}s），请手动检查状态:"
      echo "  deploy.sh status $jobName $buildNum"
      echo "  deploy.sh console $jobName $buildNum"
      ;;
    *)
      warn "${label}状态未知，请手动检查:"
      echo "  deploy.sh status $jobName $buildNum"
      ;;
  esac
}

# ── 获取构建时间戳 ──
# 对应 JenkinsController.buildAndExecuteJob 中的时间格式转换
get_build_timestamp() {
  local jobName="$1"
  local buildNum="$2"

  # 从 Jenkins API 获取构建信息中的 timestamp（毫秒）
  local ts
  ts=$(jenkins_get "/job/${jobName}/${buildNum}/api/json" 2>/dev/null | \
    python3 -c "
import json,sys,datetime
try:
    d = json.load(sys.stdin)
    ts_ms = d.get('timestamp', 0)
    dt = datetime.datetime.fromtimestamp(ts_ms / 1000)
    print(dt.strftime('%m-%d-%H:%M:%S'))
except:
    print('')
" 2>/dev/null || echo "")
  echo "$ts"
}

# ============================================================
# 云效 AppStack 部署函数
# ============================================================

# ── 触发云效工作流执行 ──
# 对应 YXAppStackClient.executeWorkflow:
#   POST /apps/{appName}/releaseWorkflows/{workflowSn}/releaseStages/{stageSn}:execute
#   body: {"params":{"sourceId":"{branch}"}}
# 用法: yx_trigger_workflow <appName> <workflowSn> <stageSn> <branch>
yx_trigger_workflow() {
  local appName="$1"
  local workflowSn="$2"
  local stageSn="$3"
  local branch="$4"

  local path="/apps/${appName}/releaseWorkflows/${workflowSn}/releaseStages/${stageSn}:execute"
  local body="{\"params\":{\"sourceId\":\"${branch}\"}}"

  local resp
  resp=$(yx_post "$path" -d "$body" 2>&1 || true)

  # 云效返回 JSON，提取 result/id 字段
  local result
  result=$(echo "$resp" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    # 成功返回 {"result": {...}, "requestId": "..."}
    # 失败返回 {"errorCode": "...", "errorMessage": "..."}
    if 'errorCode' in d:
        print('ERROR: ' + d.get('errorMessage', '未知错误'))
    else:
        r = d.get('result', d)
        print('OK:' + json.dumps(r, ensure_ascii=False))
except:
    print('ERROR: 响应解析失败: ' + sys.stdin.read()[:200])
" 2>/dev/null || echo "ERROR: 请求失败")

  echo "$result"
}

# ── 查询云效工作流执行状态 ──
# GET /apps/{appName}/releaseWorkflows/{workflowSn}/releaseStages/{stageSn}/runs/{runSn}
# 简化: 通过搜索应用发布单状态判断
# 用法: yx_get_workflow_status <appName> <workflowSn> <stageSn>
yx_get_workflow_status() {
  local appName="$1"
  local workflowSn="$2"
  local stageSn="$3"

  # 查询最近的发布单
  local resp
  resp=$(yx_get "/apps/${appName}/releaseWorkflows/${workflowSn}/releaseStages/${stageSn}/runs?pageSize=1" 2>/dev/null || echo "")

  local status
  status=$(echo "$resp" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    runs = d.get('result', d.get('runs', []))
    if runs and len(runs) > 0:
        s = runs[0].get('status', runs[0].get('state', 'unknown'))
        print(s)
    else:
        print('unknown')
except:
    print('unknown')
" 2>/dev/null || echo "unknown")

  echo "$status"
}

# ── 判断云效工作流状态是否为终态 ──
# 终态: success/fail/超时由调用方判断
# 用法: yx_is_terminal <status>  → 输出 "success" / "fail" / "" (非终态)
yx_is_terminal() {
  local s="$1"
  # 归一化小写
  s=$(echo "$s" | tr '[:upper:]' '[:lower:]')
  case "$s" in
    success|succeed|succeeded|complete|completed|finish|finished|true)
      echo "success"
      ;;
    fail|failed|failure|error|cancel|cancelled|abort|aborted|false)
      echo "fail"
      ;;
    *)
      echo ""
      ;;
  esac
}

# ── 轮询等待云效工作流完成 ──
# 用法: wait_yx_workflow_complete <appName> <workflowSn> <stageSn> [label]
# 轮询 yx_get_workflow_status 直到终态或超时，输出终态到 stdout
wait_yx_workflow_complete() {
  local appName="$1"
  local workflowSn="$2"
  local stageSn="$3"
  local label="${4:-部署}"

  local poll_interval="${DEPLOY_POLL_INTERVAL:-5}"
  local timeout="${DEPLOY_TIMEOUT:-1800}"
  local elapsed=0
  local status="running"
  local terminal=""

  while [[ -z "$terminal" && $elapsed -lt $timeout ]]; do
    sleep "$poll_interval"
    elapsed=$((elapsed + poll_interval))
    status=$(yx_get_workflow_status "$appName" "$workflowSn" "$stageSn")
    terminal=$(yx_is_terminal "$status")
    local mins=$((elapsed / 60))
    local secs=$((elapsed % 60))
    echo -ne "\r  ${label}状态: $status (已等待 ${mins}m${secs}s)    "
  done
  echo ""

  if [[ -n "$terminal" ]]; then
    echo "$terminal"
  else
    echo "running"
  fi
}

# ── 报告云效工作流结果并按需退出 ──
# 用法: report_yx_result <status> <appName> <env> <branch>
report_yx_result() {
  local status="$1"
  local appName="$2"
  local env="$3"
  local branch="$4"

  case "$status" in
    success)
      ok "云效部署成功！"
      echo ""
      echo "  服务: $appName | 环境: $env | 分支: $branch"
      echo "  可用 cwork-log 查 $appName $env 环境日志确认服务启动"
      ;;
    fail)
      fail "云效部署失败！"
      echo ""
      echo "  服务: $appName | 环境: $env | 分支: $branch"
      echo "  请到云效 AppStack 控制台查看流水线执行详情"
      exit 1
      ;;
    running)
      warn "云效部署超时（${DEPLOY_TIMEOUT:-1800}s），请到云效 AppStack 控制台手动检查状态"
      echo "  服务: $appName | 环境: $env | 分支: $branch"
      ;;
    *)
      warn "云效部署状态未知，请到云效 AppStack 控制台确认"
      echo "  服务: $appName | 环境: $env | 分支: $branch"
      ;;
  esac
}

# ── 云效完整部署流程 ──
# 云效的 executeWorkflow 一步完成构建+部署（流水线内含构建和部署阶段）
# 用法: yx_deploy <appName> <env> <branch> <svcJson>
yx_deploy() {
  local appName="$1"
  local env="$2"
  local branch="$3"
  local svcJson="$4"

  # 从服务映射中提取云效工作流信息
  # 支持两种配置方式:
  #   1. yxDeploy: {"test": "workflowSn|stageSn", "uat": "...", "prod": "..."}
  #   2. executeJob 复用: {"test": "workflowSn|stageSn", ...}（platform=yunxiao 时）
  local workflowSn stageSn
  local yxConfig
  yxConfig=$(echo "$svcJson" | python3 -c "
import json, sys
s = json.load(sys.stdin)
yx = s.get('yxDeploy', {})
ej = s.get('executeJob', {})
# 优先 yxDeploy，其次 executeJob（platform=yunxiao 时复用）
val = yx.get('$env', '') or ej.get('$env', '')
if '|' in val:
    wf, st = val.split('|', 1)
    print(f'{wf}|{st}')
else:
    print('')
" 2>/dev/null || echo "")

  if [[ -z "$yxConfig" ]]; then
    fail "服务 '$appName' 没有配置 $env 环境的云效工作流（yxDeploy 或 executeJob 需含 'workflowSn|stageSn' 格式）"
    exit 1
  fi

  workflowSn="${yxConfig%%|*}"
  stageSn="${yxConfig#*|}"

  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo "  云效部署（AppStack 流水线）"
  echo "═══════════════════════════════════════════════════════════════"
  echo "  服务:       $appName"
  echo "  环境:       $env"
  echo "  分支:       $branch"
  echo "  工作流:     $workflowSn"
  echo "  阶段:       $stageSn"
  echo "  平台:       云效 (yunxiao)"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""

  info "触发云效工作流: $workflowSn / 阶段: $stageSn (分支: $branch)"
  local result
  result=$(yx_trigger_workflow "$appName" "$workflowSn" "$stageSn" "$branch")

  if [[ "$result" == ERROR:* ]]; then
    fail "云效工作流触发失败: ${result#ERROR: }"
    exit 1
  fi

  ok "云效工作流已触发"
  echo ""
  info "执行结果: ${result#OK:}"
  echo ""

  # 轮询等待工作流执行完成
  info "等待云效工作流执行完成..."
  local finalStatus
  finalStatus=$(wait_yx_workflow_complete "$appName" "$workflowSn" "$stageSn" "部署")

  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  report_yx_result "$finalStatus" "$appName" "$env" "$branch"
  echo "═══════════════════════════════════════════════════════════════"
}

# ── 云效仅构建（触发构建阶段的工作流） ──
# 用法: yx_build <appName> <branch> <svcJson>
yx_build() {
  local appName="$1"
  local branch="$2"
  local svcJson="$3"

  # 云效中构建通常是一个独立的工作流阶段
  # 从 yxBuild 字段获取构建工作流信息
  local yxBuildConfig
  yxBuildConfig=$(echo "$svcJson" | python3 -c "
import json, sys
s = json.load(sys.stdin)
yx = s.get('yxBuild', s.get('yxDeploy', {}))
# yxBuild 格式: 'workflowSn|stageSn' 或 {'default': 'workflowSn|stageSn'}
if isinstance(yx, str) and '|' in yx:
    print(yx)
elif isinstance(yx, dict):
    val = yx.get('default', yx.get('build', ''))
    if '|' in val:
        print(val)
" 2>/dev/null || echo "")

  if [[ -z "$yxBuildConfig" ]]; then
    warn "服务 '$appName' 未配置云效构建工作流（yxBuild）"
    echo "  云效平台中构建和部署通常在同一条流水线中"
    echo "  建议直接使用 deploy 命令: deploy.sh deploy $appName <env> $branch"
    return 1
  fi

  local workflowSn stageSn
  workflowSn="${yxBuildConfig%%|*}"
  stageSn="${yxBuildConfig#*|}"

  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo "  云效构建（AppStack 流水线）"
  echo "═══════════════════════════════════════════════════════════════"
  echo "  服务:       $appName"
  echo "  分支:       $branch"
  echo "  工作流:     $workflowSn"
  echo "  阶段:       $stageSn"
  echo "  平台:       云效 (yunxiao)"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""

  info "触发云效构建工作流: $workflowSn / 阶段: $stageSn (分支: $branch)"
  local result
  result=$(yx_trigger_workflow "$appName" "$workflowSn" "$stageSn" "$branch")

  if [[ "$result" == ERROR:* ]]; then
    fail "云效构建触发失败: ${result#ERROR: }"
    exit 1
  fi

  ok "云效构建已触发"
  echo ""
  info "执行结果: ${result#OK:}"
}

# ── 命令: build ──
cmd_build() {
  local appName="$1"
  local branch="$2"

  local svc
  svc=$(lookup_service "$appName") || { fail "服务 '$appName' 未在映射中找到"; exit 1; }

  # 平台分发
  local platform
  platform=$(get_platform "$svc")
  if [[ "$platform" == "yunxiao" ]]; then
    yx_build "$appName" "$branch" "$svc"
    return
  fi

  # 默认走 Jenkins
  local buildJob
  buildJob=$(echo "$svc" | python3 -c "import json,sys; print(json.load(sys.stdin).get('buildJob',''))")

  if [[ -z "$buildJob" ]]; then
    fail "服务 '$appName' 没有配置 buildJob"
    exit 1
  fi

  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo "  触发构建"
  echo "═══════════════════════════════════════════════════════════════"
  echo "  服务: $appName"
  echo "  构建作业: $buildJob"
  echo "  分支: $branch"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""

  info "触发构建作业: $buildJob (分支: $branch)"
  local buildNum
  buildNum=$(trigger_build_job "$buildJob" "$branch")
  ok "构建已触发，构建号: #$buildNum"
  echo ""

  # 等待构建完成并报告结果
  info "等待构建完成..."
  local buildStatus
  buildStatus=$(wait_jenkins_job_complete "$buildJob" "$buildNum" "构建")
  echo ""
  report_jenkins_result "$buildStatus" "$buildJob" "$buildNum" "构建"
}

# ── 命令: execute ──
cmd_execute() {
  local appName="$1"
  local env="$2"
  local branch="$3"

  local svc
  svc=$(lookup_service "$appName") || { fail "服务 '$appName' 未在映射中找到"; exit 1; }

  # 平台分发
  local platform
  platform=$(get_platform "$svc")
  if [[ "$platform" == "yunxiao" ]]; then
    yx_deploy "$appName" "$env" "$branch" "$svc"
    return
  fi

  # 默认走 Jenkins
  local executeJob
  executeJob=$(echo "$svc" | python3 -c "
import json,sys
s = json.load(sys.stdin)
ej = s.get('executeJob', {})
print(ej.get('$env', ''))
")

  if [[ -z "$executeJob" ]]; then
    fail "服务 '$appName' 没有配置 $env 环境的 executeJob"
    exit 1
  fi

  # 获取最新构建的时间戳作为 IMAGE_VERSION
  local buildJob buildNum dateTime
  buildJob=$(echo "$svc" | python3 -c "import json,sys; print(json.load(sys.stdin).get('buildJob',''))")
  buildNum=$(get_last_build_number "$buildJob" 2>/dev/null || echo "")
  dateTime=$(get_build_timestamp "$buildJob" "$buildNum")

  if [[ -z "$dateTime" ]]; then
    warn "无法获取构建时间戳，使用当前时间"
    dateTime=$(date '+%m-%d-%H:%M:%S')
  fi

  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo "  触发部署"
  echo "═══════════════════════════════════════════════════════════════"
  echo "  服务: $appName"
  echo "  环境: $env"
  echo "  部署作业: $executeJob"
  echo "  分支: $branch"
  echo "  镜像版本: ${dateTime}----${branch}"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""

  info "触发部署作业: $executeJob"
  local deployNum
  deployNum=$(trigger_execute_job "$executeJob" "$branch" "$dateTime")
  ok "部署已触发，构建号: #$deployNum"
  echo ""

  # 等待部署完成并报告结果
  info "等待部署完成..."
  local deployStatus
  deployStatus=$(wait_jenkins_job_complete "$executeJob" "$deployNum" "部署")
  echo ""
  report_jenkins_result "$deployStatus" "$executeJob" "$deployNum" "部署"
}

# ── 命令: deploy（构建 + 等待 + 部署，完整流程） ──
cmd_deploy() {
  local appName="$1"
  local env="$2"
  local branch="$3"

  local svc
  svc=$(lookup_service "$appName") || { fail "服务 '$appName' 未在映射中找到"; exit 1; }

  # 平台分发
  local platform
  platform=$(get_platform "$svc")
  if [[ "$platform" == "yunxiao" ]]; then
    yx_deploy "$appName" "$env" "$branch" "$svc"
    return
  fi

  # 默认走 Jenkins
  local buildJob executeJob
  buildJob=$(echo "$svc" | python3 -c "import json,sys; print(json.load(sys.stdin).get('buildJob',''))")
  executeJob=$(echo "$svc" | python3 -c "
import json,sys
s = json.load(sys.stdin)
ej = s.get('executeJob', {})
print(ej.get('$env', ''))
")

  if [[ -z "$buildJob" ]]; then
    fail "服务 '$appName' 没有配置 buildJob"
    exit 1
  fi
  if [[ -z "$executeJob" ]]; then
    fail "服务 '$appName' 没有配置 $env 环境的 executeJob"
    exit 1
  fi

  local swim
  swim=$(lookup_swim "$env" 2>/dev/null || echo "")
  if [[ -z "$swim" ]]; then
    warn "未配置 $env 环境的 swimDeploy，部署时不传 SUB_APPNAME（prod/云效平台通常无泳道）"
  fi

  local deployName
  deployName=$(echo "$svc" | python3 -c "import json,sys; print(json.load(sys.stdin).get('deployName', ''))")
  # 如果没有 deployName，用 appName
  if [[ -z "$deployName" ]]; then
    deployName="$appName"
  fi

  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo "  完整部署流程（构建 → 等待 → 部署）"
  echo "═══════════════════════════════════════════════════════════════"
  echo "  服务:       $appName"
  echo "  环境:       $env"
  echo "  分支:       $branch"
  echo "  构建作业:   $buildJob"
  echo "  部署作业:   $executeJob"
  echo "  swim:       $swim"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""

  # ── 步骤 1: 触发构建 ──
  info "[1/3] 触发构建作业: $buildJob (分支: $branch)"
  local buildNum
  buildNum=$(trigger_build_job "$buildJob" "$branch")
  ok "构建已触发，构建号: #$buildNum"
  echo ""

  # ── 步骤 2: 等待构建完成 ──
  info "[2/3] 等待构建完成..."
  local buildStatus
  buildStatus=$(wait_jenkins_job_complete "$buildJob" "$buildNum" "构建")
  echo ""

  if [[ "$buildStatus" == "fail" ]]; then
    fail "构建失败！构建号: #$buildNum"
    echo ""
    info "查看构建日志:"
    echo "  deploy.sh console $buildJob $buildNum"
    echo "  ${JENKINS_URL:-http://172.16.98.169:18001}/job/${buildJob}/${buildNum}/console"
    exit 1
  fi

  if [[ "$buildStatus" == "running" ]]; then
    warn "构建超时（${DEPLOY_TIMEOUT:-1800}s），请手动检查状态:"
    echo "  deploy.sh status $buildJob $buildNum"
    exit 1
  fi

  ok "构建成功！构建号: #$buildNum"
  echo ""

  # ── 步骤 3: 触发部署 ──
  local dateTime
  dateTime=$(get_build_timestamp "$buildJob" "$buildNum")
  if [[ -z "$dateTime" ]]; then
    dateTime=$(date '+%m-%d-%H:%M:%S')
  fi

  info "[3/3] 触发部署作业: $executeJob"
  local deployNum
  deployNum=$(trigger_execute_job "$executeJob" "$branch" "$dateTime")
  ok "部署已触发，构建号: #$deployNum"
  echo ""

  # 等待部署完成
  info "等待部署完成..."
  local deployStatus
  deployStatus=$(wait_jenkins_job_complete "$executeJob" "$deployNum" "部署")
  echo ""

  echo "═══════════════════════════════════════════════════════════════"
  echo "  部署结果"
  echo "═══════════════════════════════════════════════════════════════"
  echo "  构建号:   #$buildNum (SUCCESS)"
  echo "  部署号:   #$deployNum"
  echo "  镜像版本: ${dateTime}----${branch}"
  echo ""
  report_jenkins_result "$deployStatus" "$executeJob" "$deployNum" "部署"
  echo "═══════════════════════════════════════════════════════════════"
}

# ── 命令: status ──
cmd_status() {
  local jobName="$1"
  local buildNum="${2:-}"

  if [[ -z "$buildNum" ]]; then
    buildNum=$(get_last_build_number "$jobName" 2>/dev/null || echo "")
    if [[ -z "$buildNum" ]]; then
      fail "无法获取 $jobName 的构建号，作业可能不存在或从未构建"
      exit 1
    fi
    info "使用最新构建号: #$buildNum"
  fi

  local status
  status=$(get_job_status "$jobName" "$buildNum")

  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo "  构建状态"
  echo "═══════════════════════════════════════════════════════════════"
  echo "  作业:     $jobName"
  echo "  构建号:   #$buildNum"
  echo -n "  状态:     "
  case "$status" in
    success)  echo -e "${GREEN}SUCCESS${NC}" ;;
    fail)     echo -e "${RED}FAILURE${NC}" ;;
    running)  echo -e "${YELLOW}RUNNING${NC}" ;;
    unknown)  echo -e "${YELLOW}UNKNOWN${NC}" ;;
  esac
  echo "═══════════════════════════════════════════════════════════════"

  if [[ "$status" == "running" ]]; then
    echo ""
    info "构建仍在进行中，可用以下命令持续查看:"
    echo "  deploy.sh status $jobName $buildNum"
  fi
}

# ── 命令: console ──
cmd_console() {
  local jobName="$1"
  local buildNum="$2"

  local console
  console=$(jenkins_get "/job/${jobName}/${buildNum}/consoleText" 2>/dev/null || echo "")

  if [[ -z "$console" ]]; then
    fail "无法获取构建日志，检查作业名和构建号是否正确"
    exit 1
  fi

  echo "$console"
}

# ── 命令: sync ──
cmd_sync() {
  local devopsUrl="${DEVOPS_URL:-http://172.16.149.95:81}"
  info "从 devops 服务同步服务映射: $devopsUrl"

  # 尝试从 devops API 获取应用列表
  local resp
  resp=$($CURL -s "${devopsUrl}/api/application/list" 2>&1 || echo "")

  if [[ -z "$resp" ]] || echo "$resp" | grep -q "error\|Error\|无法" 2>/dev/null; then
    warn "无法从 devops API 获取应用列表（$devopsUrl 可能不可达）"
    echo ""
    info "当前使用本地 service-map.json（从 DeployData.js 提取，包含 68 个服务）"
    echo "  如需手动更新，编辑: $SCRIPT_DIR/service-map.json"
    return 0
  fi

  # 尝试解析并更新映射
  local count
  count=$(echo "$resp" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    apps = data if isinstance(data, list) else data.get('data', data.get('list', []))
    print(len(apps))
except:
    print(0)
" 2>/dev/null || echo "0")

  if [[ "$count" -gt 0 ]]; then
    info "从 API 获取到 $count 个应用"
    # TODO: 根据 API 返回结构更新 service-map.json
    ok "服务映射已更新"
  else
    warn "API 返回数据格式无法解析，保持本地映射不变"
    info "当前本地映射: $SCRIPT_DIR/service-map.json"
  fi
}

# ── 主入口 ──
usage() {
  cat << 'EOF'
cwork-deploy — Jenkins + 云效 构建部署工具（curl 封装）

用法:
  deploy.sh deploy  <appName> <env> <branch>   构建+部署（最常用）
  deploy.sh build   <appName> <branch>         仅触发构建
  deploy.sh execute <appName> <env> <branch>   仅触发部署（需先构建）
  deploy.sh status   <jobName> [buildNum]      查询构建状态（Jenkins）
  deploy.sh list     [关键字]                   列出可用服务
  deploy.sh jobs     <appName>                 查看服务的 Jenkins 作业名
  deploy.sh console  <jobName> <buildNum>      查看构建控制台日志（Jenkins）
  deploy.sh sync                               从 devops API 同步服务映射

平台路由:
  service-map.json 中 platform=yunxiao 的服务走云效 AppStack API
  其余走 Jenkins REST API（默认，向后兼容）
  也可设置环境变量 DEPLOY_DEFAULT_PLATFORM=yunxiao 全局切换

参数:
  appName   服务名（如 order-server, charge-server）
  env       环境（dev / test / uat / prod）
  branch    代码分支（如 feature/20260901_xxx, master）
  jobName   Jenkins 作业名（如 order-server_3.0_dev）
  buildNum  构建号（如 123）

示例:
  deploy.sh deploy order-server test feature/20260901_add_export
  deploy.sh build charge-server feature/20260901_fix_bug
  deploy.sh status order-server_k8s-test 456
  deploy.sh list order
  deploy.sh jobs finance-server
  deploy.sh console order-server_3.0_dev 123
EOF
}

main() {
  local cmd="${1:-}"
  shift || true

  case "$cmd" in
    deploy)
      [[ $# -lt 3 ]] && { fail "用法: deploy.sh deploy <appName> <env> <branch>"; exit 1; }
      cmd_deploy "$1" "$2" "$3"
      ;;
    build)
      [[ $# -lt 2 ]] && { fail "用法: deploy.sh build <appName> <branch>"; exit 1; }
      cmd_build "$1" "$2"
      ;;
    execute)
      [[ $# -lt 3 ]] && { fail "用法: deploy.sh execute <appName> <env> <branch>"; exit 1; }
      cmd_execute "$1" "$2" "$3"
      ;;
    status)
      [[ $# -lt 1 ]] && { fail "用法: deploy.sh status <jobName> [buildNum]"; exit 1; }
      cmd_status "$1" "${2:-}"
      ;;
    list)
      cmd_list "${1:-}"
      ;;
    jobs)
      [[ $# -lt 1 ]] && { fail "用法: deploy.sh jobs <appName>"; exit 1; }
      cmd_jobs "$1"
      ;;
    console)
      [[ $# -lt 2 ]] && { fail "用法: deploy.sh console <jobName> <buildNum>"; exit 1; }
      cmd_console "$1" "$2"
      ;;
    sync)
      cmd_sync
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
