#!/usr/bin/env bash
# =============================================================================
# cwork-config: Nacos 配置只读查询(多环境)
# ⚠️ 绝对只读: 仅 GET, 永不写。写 Nacos 请走 devops 工程受控写路径(带 JWT/审批)。
#   注: 仅查「配置」(/v1/cs/*)。服务实例(naming /v1/ns/*)鉴权独立, 不在本技能范围。
# 用法见下方 usage。
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
source "$SCRIPT_DIR/_common.sh"

usage() {
  cat <<'EOF'
cwork-config — Nacos 配置只读查询(多环境)

用法:
  nacos_query.sh <env> <命令> [参数]
  nacos_query.sh diff <dataId> <group> <env1> <env2>   # 多环境对比(无 env 前置)

  env: dev | test | uat | prod | opendev (或直接传 namespace)

命令:
  get <dataId> [group]                  取配置内容(group 默认 DEFAULT_GROUP)
  list [group]                          列命名空间下配置清单(可按 group 过滤加速)
  search <关键字>                        模糊搜(服务端 dataId=*kw* 通配, 快)
  diff <dataId> <group> <env1> <env2>   同一配置在两环境的差异

示例:
  nacos_query.sh test get order-service.yml DEFAULT_GROUP
  nacos_query.sh prod get order-service.yml        # 默认 DEFAULT_GROUP
  nacos_query.sh uat list
  nacos_query.sh test search order
  nacos_query.sh diff order-service.yml DEFAULT_GROUP test prod
EOF
}

[[ $# -ge 1 ]] || { usage; exit 1; }

# diff 无 env 前置(两个 env 在参数里), 其他命令 env 前置
if [[ "$1" == "diff" ]]; then
  CMD="diff"; shift
else
  [[ $# -ge 2 ]] || { usage; exit 1; }
  ENV="$1"; CMD="$2"; shift 2
  NS="$(env_to_namespace "$ENV")"
fi

case "$CMD" in
  get)
    [[ $# -ge 1 ]] || fail "get 需要 <dataId>"
    dataId="$1"; group="${2:-DEFAULT_GROUP}"
    nacos_call "$NS" "/v1/cs/configs" "dataId=$dataId" "group=$group" "tenant=$NS"
    ;;
  list)
    # /v2/cs/history/configs 全量(k8s-test 约 392 条, ~5s 服务端查全量; 支持 group 过滤加速)
    # 输出简表(dataId/group/type), 看配置内容用 get
    group="${1:-}"
    nacos_call "$NS" "/v2/cs/history/configs" "namespaceId=$NS" "tenant=$NS" "group=$group" "groupName=" \
      | python3 -c 'import sys,json
d=json.loads(sys.stdin.read())
arr=d.get("data") if isinstance(d,dict) and "data" in d else d
print("共 %d 条:" % len(arr))
for c in arr:
    print("  - %s  [%s]  type=%s" % (c.get("dataId"), c.get("group"), c.get("type") or "?"))'
    ;;
  search)
    [[ $# -ge 1 ]] || fail "search 需要 <关键字>"
    kw="$1"
    # /v1 search=blur 服务端模糊查(dataId=*kw* 通配), 比拉全量再过滤快 ~9 倍
    nacos_call "$NS" "/v1/cs/configs" "search=blur" "dataId=*$kw*" "group=*" "tenant=$NS" "pageNo=1" "pageSize=100" \
      | python3 -c 'import sys,json
d=json.loads(sys.stdin.read())
items=d.get("pageItems") or []
print("命中 %s 条:" % d.get("totalCount", len(items)))
for c in items:
    print("  - %s  [%s]  type=%s" % (c.get("dataId"), c.get("group"), c.get("type") or "?"))'
    ;;
  diff)
    [[ $# -ge 4 ]] || fail "diff 需要 <dataId> <group> <env1> <env2>"
    dataId="$1"; group="$2"; e1="$3"; e2="$4"
    ns1="$(env_to_namespace "$e1")"; ns2="$(env_to_namespace "$e2")"
    c1="$(nacos_call "$ns1" "/v1/cs/configs" "dataId=$dataId" "group=$group" "tenant=$ns1")"
    c2="$(nacos_call "$ns2" "/v1/cs/configs" "dataId=$dataId" "group=$group" "tenant=$ns2")"
    echo "=== $e1 ($ns1)  vs  $e2 ($ns2)  :  $dataId [$group] ==="
    diff <(printf '%s\n' "$c1") <(printf '%s\n' "$c2") || true
    ;;
  *)
    usage; exit 1
    ;;
esac
