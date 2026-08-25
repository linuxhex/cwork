#!/usr/bin/env bash
# graf_query.sh — Grafana 监控数据查询（cwork-graf 主脚本）
# 用法: bash graf_query.sh <command> [args...]
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
source "$SCRIPT_DIR/_common.sh"

# ═══════════════════════════════════════════════════════════════════
# 仪表盘索引（UID|分类|标题|面板数）
# ══════════════════════════════════════════════════════════════════
DASHBOARDS='
iPucATd4k|C端埋点|app大屏统计|11
DZ8sNXDZk|服务异常|Container Statistics|17
celbo7azdtz40e|平台服务|C端用户数据监控|4
Y6gogUmVk|系统运维|DB|20
xNEeA51Wk|系统运维|Druid 连接池监控|28
d1AmgTP4z|系统运维|Java应用_Arms|4
uCimG9W4k|系统运维|Java应用_CPU|34
OwGKxeGVz|系统运维|Java应用_内存|32
UOJjh1SMz|服务异常|JVM监控大盘|44
icjpCppik|服务异常|K8 Cluster Detail Dashboard|30
SpSQKcpMz|K8S|k8s 资源总览|22
gBqr54nHz|系统运维|Lindorm|0
bewf6kr4v50cgc|系统运维|Nacos修改记录|0
U5EVD_lVz|K8S|Node 请求|0
n0xjWq3Mk|K8S|Node 负载|8
nFq0sNLVt|应用监控|Sentinel 资源监控|0
83UAKyS4k|系统运维|SLB|0
X034JGT7Gz|服务异常|SpringBoot APM Dashboard|0
zDlxE5pIz|系统运维|业务|0
ae9y3h8x00lc0e|平台服务|业务巡检大盘|0
LDIBtFQVz|服务异常|业务应用监控|0
p4CsdXUnk|业务异常|业务异常监控-充值监控|0
d-aub-5nk|业务异常|业务异常监控-全部|0
0kLk1u8nk|业务异常|业务异常监控-其他流量方监控|0
FjszPgB7k|业务异常|业务异常监控-告警通知|0
10njj5bnz|业务异常|业务异常监控-客服|0
belmj2w29makga|营销|会员|0
akIt7Ic7k|业务异常|充值监控|0
MRJ9vO84k|应用监控|充电交易业务监控|0
MRJ9vO840|应用监控|充电交易应用监控|0
GesmYJxSz|系统运维|公网流量|0
Kw5q4Sc7k|业务异常|关单及结算监控|0
3prfffq7z|业务异常|关单监控-同比告警|0
jeAkt3yMz|服务异常|关键服务指标监控|0
Lg_QT9I4k|C端埋点|分类监控|0
2ENK-lYIk|应用监控|加密桩服务|0
daus2RZIk|系统运维|动态线程池监控|0
felpu5jp9ijggf|营销|卡券|0
afcfb5cof5czkf|系统运维|反爬|0
qg4nDIcnk|业务异常|启动监控|0
cf2066n0odh4wb|营销|商品卡|0
belc64enoaosgd|平台服务|基础数据监控|0
1v3ECgs4k|应用监控|基础服务|0
Bbm9tqsGk|服务异常|外部调用监控|0
BMXBKScnz|业务异常|实时订单监控|0
femmkoje2i48wc|营销|广告|0
UnSisHeMz|K8S|应用 负载|0
feg2odhfxkk5cb|财务监控|服务监控|0
aepaae893ojk0b|平台服务|本地缓存监控|0
SjQd2fU4k|应用监控|权限服务|0
_A0-Xr_Gz|服务异常|查询接口请求频次|0
degrzqu73yi9sf|财务监控|核心业务|0
eetct1tpr2whsd|系统运维|桩报文|0
K39gCE8Vk|应用监控|桩服务|0
dem0lf12dcpa8d|K8S|桩连接数|0
aeltid8iy9c74c|营销|活动|0
Yi0cbwKnz|服务异常|生产环境ECS大盘-20211021T173030|0
BOL2MoO4z|C端埋点|用户端产品监控|0
YGXDM7qMz|服务异常|系统CPU|0
AjQlt0d7k|K8S|负载总览|0
n87Ysz9Iz|财务监控|财务监控看板（待废弃）|0
UAKLlMQMz|服务异常|财务调用第三方接口服务监控|0
O5fYmrqGk|K8S|资源总览|0
deot5wrpi1jpca|平台服务|道闸业务监控|0
'

# ═══════════════════════════════════════════════════════════════════
# 命令: list — 列出仪表盘
# ═══════════════════════════════════════════════════════════════════
cmd_list() {
  local filter="${1:-}"
  printf "%-20s %-12s %-40s %s\n" "UID" "分类" "标题" "面板数"
  printf "%-20s %-12s %-40s %s\n" "--------------------" "------------" "----------------------------------------" "------"
  echo "$DASHBOARDS" | while IFS='|' read -r uid cat title panels; do
    [[ -z "$uid" ]] && continue
    if [[ -z "$filter" ]] || echo "$uid $cat $title" | grep -qi "$filter"; then
      printf "%-20s %-12s %-40s %s\n" "$uid" "$cat" "$title" "$panels"
    fi
  done
}

# ═══════════════════════════════════════════════════════════════════
# 命令: categories — 列出所有分类
# ═══════════════════════════════════════════════════════════════════
cmd_categories() {
  echo "$DASHBOARDS" | awk -F'|' '$1!="" {print $2}' | sort -u
}

# ═══════════════════════════════════════════════════════════════════
# 命令: panels — 列出仪表盘的面板
# ═══════════════════════════════════════════════════════════════════
cmd_panels() {
  local uid="$1"
  local data
  data=$(grafana_get "/api/dashboards/uid/$uid")

  local title
  title=$(echo "$data" | python3 -c "import sys,json; print(json.load(sys.stdin)['dashboard']['title'])" 2>/dev/null)
  echo "仪表盘: $title ($uid)"
  echo "────────────────────────────────────────────────────────"

  echo "$data" | python3 -c "
import json, sys
data = json.load(sys.stdin)
panels = data['dashboard'].get('panels', [])
for p in panels:
    pid = p.get('id', '?')
    pt = p.get('title', 'N/A')
    ptype = p.get('type', 'N/A')
    targets = p.get('targets', [])
    exprs = [t.get('expr','') for t in targets if t.get('expr')]
    print(f'  [{ptype:>12s}] ID={pid:<4d} {pt}')
    for e in exprs[:2]:
        # 截断过长的表达式
        short = e[:100] + '...' if len(e) > 100 else e
        print(f'    Q: {short}')
    if len(exprs) > 2:
        print(f'    ... 还有 {len(exprs)-2} 个查询')
"
}

# ═══════════════════════════════════════════════════════════════════
# 命令: query — 查询面板数据
#   graf_query.sh query <uid> <panel_id> [time_range] [node] [namespace]
#   time_range: 1h, 3h, 6h, 12h, 24h, 7d (默认 3h)
# ═══════════════════════════════════════════════════════════════════
cmd_query() {
  local uid="$1"
  local panel_id="$2"
  local time_range="${3:-3h}"
  local node="${4:-}"
  local namespace="${5:-default}"

  # 获取仪表盘数据
  local data
  data=$(grafana_get "/api/dashboards/uid/$uid")

  # 提取面板信息和查询（替换 Grafana 变量）
  local panel_info
  panel_info=$(echo "$data" | python3 -c "
import json, sys

node = '$node' if '$node' else 'k8s-prod-201005-prod'
namespace = '$namespace' if '$namespace' else 'default'

data = json.load(sys.stdin)
panels = data['dashboard'].get('panels', [])
for p in panels:
    if str(p.get('id')) == '$panel_id':
        ds = p.get('datasource', {})
        ds_uid = ds.get('uid', '${GRAFANA_DS_UID:-6A__NzsMk}')
        targets = p.get('targets', [])
        queries = []
        for t in targets:
            expr = t.get('expr', '')
            if expr:
                # 替换 Grafana 模板变量
                expr = expr.replace('\$node', node)
                expr = expr.replace('\$namespace', namespace)
                expr = expr.replace('\$Node', node)
                expr = expr.replace('\$Namespace', namespace)
                instant = t.get('instant', False)
                queries.append({'expr': expr, 'instant': instant, 'refId': t.get('refId', 'A')})
        print(json.dumps({
            'title': p.get('title', 'N/A'),
            'type': p.get('type', 'N/A'),
            'datasource_uid': ds_uid,
            'queries': queries
        }))
        break
else:
    print(json.dumps({'error': f'Panel $panel_id not found'}))
" 2>/dev/null)

  if echo "$panel_info" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if 'error' in d else 1)" 2>/dev/null; then
    echo "错误: $panel_info" >&2
    return 1
  fi

  local title ptype ds_uid queries_json
  title=$(echo "$panel_info" | python3 -c "import sys,json; print(json.load(sys.stdin)['title'])")
  ptype=$(echo "$panel_info" | python3 -c "import sys,json; print(json.load(sys.stdin)['type'])")
  ds_uid=$(echo "$panel_info" | python3 -c "import sys,json; print(json.load(sys.stdin)['datasource_uid'])")
  queries_json=$(echo "$panel_info" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin)['queries']))")

  echo "面板: $title [$ptype]"
  echo "时间范围: $time_range"
  [[ -n "$node" ]] && echo "节点: $node"
  echo "────────────────────────────────────────────────────────"

  # 构造查询请求
  local queries
  queries=$(echo "$queries_json" | python3 -c "
import json, sys
qs = json.loads(sys.stdin.read())
result = []
for i, q in enumerate(qs):
    result.append({
        'refId': chr(65 + i),  # A, B, C...
        'datasource': {'type': 'prometheus', 'uid': '$ds_uid'},
        'expr': q['expr'],
        'instant': q['instant'],
        'range': not q['instant']
    })
print(json.dumps(result))
")

  # 发送查询
  local resp
  resp=$(grafana_post "/api/ds/query" \
    -d "{
      \"queries\": $queries,
      \"from\": \"now-$time_range\",
      \"to\": \"now\"
    }")

  # 解析并展示结果
  echo "$resp" | python3 -c "
import json, sys
from datetime import datetime

def format_value(v, config=None):
    '''智能格式化数值，根据量级和配置选择合适单位'''
    if not isinstance(v, (int, float)):
        return str(v)

    # 检查 Grafana 配置的单位提示
    unit = ''
    if config:
        unit = config.get('unit', '')

    # 根据单位字段直接格式化
    if unit == 'percentunit':
        return f'{v*100:.2f}%'
    elif unit == 'percent':
        return f'{v:.2f}%'
    elif unit in ('bytes', 'bytesIEC'):
        if v > 1024**3:
            return f'{v/1024**3:.2f} GB'
        elif v > 1024**2:
            return f'{v/1024**2:.1f} MB'
        elif v > 1024:
            return f'{v/1024:.1f} KB'
        return f'{v:.0f} B'
    elif unit in ('kbytes', 'deckbytes'):
        if v > 1024**2:
            return f'{v/1024**2:.2f} GB'
        elif v > 1024:
            return f'{v/1024:.1f} MB'
        return f'{v:.0f} KB'
    elif unit == 'short':
        if v >= 1e9:
            return f'{v/1e9:.2f}B'
        elif v >= 1e6:
            return f'{v/1e6:.2f}M'
        elif v >= 1e3:
            return f'{v/1e3:.2f}K'
        return f'{v:.0f}'

    # 无单位时的智能推断
    if 0 < v < 1 and v != 0:
        # 小数值可能是百分比或比率
        if v < 0.01:
            return f'{v*100:.4f}%'
        return f'{v*100:.2f}%'
    elif v > 10**9:
        # 原始字节值
        return f'{v/1024**3:.2f} GB'
    elif v > 10**6:
        # 可能是 MB 或 KB
        return f'{v/1024**2:.1f} MB'
    elif v > 100:
        # 大数值，保留两位小数（可能是 GB 或其他单位）
        return f'{v:.2f}'
    elif v > 10**3 and v != int(v):
        return f'{v:.2f}'
    elif isinstance(v, float) and v == int(v):
        return str(int(v))
    return f'{v}'

data = json.load(sys.stdin)
results = data.get('results', {})

for ref in sorted(results.keys()):
    res = results[ref]
    frames = res.get('frames', [])
    for f in frames:
        name = f.get('name', '')
        schema_fields = f.get('schema', {}).get('fields', [])

        # 获取字段配置（单位等）
        field_configs = {}
        for sf in schema_fields:
            field_configs[sf.get('name', '')] = sf.get('config', {})

        labels = {}
        for sf in schema_fields:
            if sf.get('labels'):
                labels.update(sf['labels'])

        fields = f.get('data', {}).get('values', [])
        if not fields:
            continue

        label_str = ', '.join(f'{k}={v}' for k, v in labels.items()) if labels else name
        value_config = field_configs.get('Value', field_configs.get('value', {}))

        # 判断是时间序列还是即时值
        if len(fields) >= 2 and isinstance(fields[0], list) and fields[0] and isinstance(fields[0][0], (int, float)):
            # 时间序列数据
            times = fields[0]
            values = fields[1]

            # 显示最后 10 个数据点
            n = min(10, len(times))
            print(f'  {label_str} (最近{n}个点):')
            for i in range(-n, 0):
                ts = datetime.fromtimestamp(times[i] / 1000).strftime('%H:%M:%S')
                v = values[i]
                print(f'    {ts}: {format_value(v, value_config)}')
        else:
            # 即时值
            vals = fields[-1] if len(fields) > 1 else fields[0]
            if isinstance(vals, list) and vals:
                v = vals[-1] if isinstance(vals[-1], (int, float)) else vals[0]
            else:
                v = vals
            print(f'  {label_str}: {format_value(v, value_config)}')
"
}

# ══════════════════════════════════════════════════════════════════
# 命令: instant — 查询即时值（单条 PromQL）
#   graf_query.sh instant "<promql>"
# ═══════════════════════════════════════════════════════════════════
cmd_instant() {
  local expr="$1"
  local ds_uid="${2:-${GRAFANA_DS_UID:-6A__NzsMk}}"

  local resp
  resp=$(grafana_post "/api/ds/query" \
    -d "{
      \"queries\": [{
        \"refId\": \"A\",
        \"datasource\": {\"type\": \"prometheus\", \"uid\": \"$ds_uid\"},
        \"expr\": $(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$expr"),
        \"instant\": true
      }],
      \"from\": \"now-1h\",
      \"to\": \"now\"
    }")

  echo "$resp" | python3 -c "
import json, sys

def format_value(v, config=None):
    if not isinstance(v, (int, float)):
        return str(v)
    unit = config.get('unit', '') if config else ''
    if unit == 'percentunit':
        return f'{v*100:.2f}%'
    elif unit == 'percent':
        return f'{v:.2f}%'
    elif unit in ('bytes', 'bytesIEC'):
        if v > 1024**3: return f'{v/1024**3:.2f} GB'
        elif v > 1024**2: return f'{v/1024**2:.1f} MB'
        elif v > 1024: return f'{v/1024:.1f} KB'
        return f'{v:.0f} B'
    if 0 < v < 1 and v != 0:
        return f'{v*100:.2f}%' if v >= 0.01 else f'{v*100:.4f}%'
    elif v > 10**9:
        return f'{v/1024**3:.2f} GB'
    elif v > 10**6:
        return f'{v/1024**2:.1f} MB'
    elif v > 100:
        return f'{v:.2f}'
    elif isinstance(v, float) and v == int(v):
        return str(int(v))
    return f'{v}'

data = json.load(sys.stdin)
for ref in data.get('results', {}):
    for f in data['results'][ref].get('frames', []):
        fields = f.get('data', {}).get('values', [])
        schema = f.get('schema', {}).get('fields', [])
        labels = {}
        field_configs = {}
        for s in schema:
            if s.get('labels'):
                labels.update(s['labels'])
            field_configs[s.get('name', '')] = s.get('config', {})
        vals = fields[-1] if len(fields) > 1 else fields[0]
        if isinstance(vals, list) and vals:
            v = vals[-1] if isinstance(vals[-1], (int, float)) else vals[0]
        else:
            v = vals
        label_str = ', '.join(f'{k}={v2}' for k, v2 in labels.items()) if labels else 'value'
        value_config = field_configs.get('Value', field_configs.get('value', {}))
        print(f'{label_str}: {format_value(v, value_config)}')
"
}

# ═══════════════════════════════════════════════════════════════════
# 命令: search — 按关键字搜索仪表盘
# ═══════════════════════════════════════════════════════════════════
cmd_search() {
  local keyword="$1"
  echo "搜索: $keyword"
  echo "────────────────────────────────────────────────────────"
  cmd_list "$keyword"
}

# ═══════════════════════════════════════════════════════════════════
# 命令: overview — 节点总览（CPU/内存/POD）
#   graf_query.sh overview <node> [time_range]
# ═══════════════════════════════════════════════════════════════════
cmd_overview() {
  local node="$1"
  local time_range="${2:-3h}"

  echo "节点总览: $node (最近 $time_range)"
  echo "════════════════════════════════════════════════════════"

  # 1. CPU/内存使用率时间序列
  echo ""
  echo "【CPU / 内存使用率趋势】"
  cmd_query "n0xjWq3Mk" "6" "$time_range" "$node"

  # 2. CPU 分配
  echo ""
  echo "【CPU 分配（核）】"
  cmd_query "n0xjWq3Mk" "8" "$time_range" "$node"

  # 3. POD 数
  echo ""
  echo "【POD 数】"
  cmd_query "n0xjWq3Mk" "12" "$time_range" "$node"

  # 4. 内存分配
  echo ""
  echo "【内存分配（GB）】"
  cmd_query "n0xjWq3Mk" "10" "$time_range" "$node"

  # 5. POD CPU 使用量
  echo ""
  echo "【POD CPU 使用量 Top】"
  cmd_query "n0xjWq3Mk" "4" "$time_range" "$node"

  # 6. POD 内存使用量
  echo ""
  echo "【POD 内存使用量 Top】"
  cmd_query "n0xjWq3Mk" "18" "$time_range" "$node"
}

# ══════════════════════════════════════════════════════════════════
# 主入口
# ═══════════════════════════════════════════════════════════════════
usage() {
  cat <<'EOF'
用法: bash graf_query.sh <command> [args...]

命令:
  list [关键字]          列出仪表盘（可按分类/标题/UID 过滤）
  categories             列出所有分类
  panels <uid>           列出仪表盘的面板和查询语句
  query <uid> <id> [时间] [节点] [命名空间]  查询面板数据
  instant "<promql>"     查询单条 PromQL 即时值
  search <关键字>        按关键字搜索仪表盘
  overview <节点> [时间] 节点总览（CPU/内存/POD 全量）

时间范围: 1h, 3h, 6h, 12h, 24h, 7d（默认 3h）

示例:
  bash graf_query.sh list K8S
  bash graf_query.sh panels n0xjWq3Mk
  bash graf_query.sh query n0xjWq3Mk 6 3h k8s-prod-201005-prod
  bash graf_query.sh overview k8s-prod-201005-prod 6h
  bash graf_query.sh instant 'sum(rate(container_cpu_usage_seconds_total[1m]))'
EOF
}

main() {
  local cmd="${1:-help}"
  shift || true

  case "$cmd" in
    list)       cmd_list "$@" ;;
    categories) cmd_categories ;;
    panels)     cmd_panels "$@" ;;
    query)      cmd_query "$@" ;;
    instant)    cmd_instant "$@" ;;
    search)     cmd_search "$@" ;;
    overview)   cmd_overview "$@" ;;
    help|-h|--help) usage ;;
    *)          echo "未知命令: $cmd" >&2; usage >&2; exit 1 ;;
  esac
}

main "$@"
