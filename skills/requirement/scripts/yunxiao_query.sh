#!/usr/bin/env bash
# =============================================================================
# cwork-requirement: 云效需求只读查询(Projex)
# 绝对只读: 仅 GET, 永不写。写云效请在 Web 控制台操作。
# 用法见下方 usage。
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
source "$SCRIPT_DIR/_common.sh"

usage() {
  cat <<'EOF'
cwork-requirement — 云效需求只读查询(Projex)

用法:
  yunxiao_query.sh <命令> [参数]

命令:
  list [maxResults]                     列出项目需求(默认 50 条)
  detail <workitemId>                   查看单个需求详情
  search <关键字>                        按关键字搜索需求标题
  by-date <日期> [fieldId]              按计划上线时间筛选(日期: yyyy-MM-dd)
  by-test-date <日期> [fieldId]         按计划提测时间筛选(日期: yyyy-MM-dd)

示例:
  yunxiao_query.sh list
  yunxiao_query.sh list 20
  yunxiao_query.sh detail REQ-1234
  yunxiao_query.sh search 订单
  yunxiao_query.sh by-date 2026-08-10
  yunxiao_query.sh by-test-date 2026-08-05
EOF
}

# 构建日期筛选条件 JSON
build_date_condition() {
  local date="$1" field_id="$2"
  [[ -n "$field_id" ]] || fail "未配置日期字段ID: 请在 scripts/.config.local.sh 设置对应字段ID, 或通过参数传入"
  python3 - "$date" "$field_id" <<'PY'
import sys, json
date, field_id = sys.argv[1:3]
condition = {
    "fieldIdentifier": field_id,
    "operator": "BETWEEN",
    "value": [f"{date} 00:00:00"],
    "toValue": f"{date} 23:59:59",
    "className": "date",
    "format": "input"
}
wrapper = {"conditionGroups": [[condition]]}
print(json.dumps(wrapper, ensure_ascii=False))
PY
}

# 格式化需求列表输出
format_workitems() {
  local input
  input=$(cat)
  INPUT_DATA="$input" python3 <<'PY'
import sys, os, json

data = json.loads(os.environ['INPUT_DATA'])

if not data.get("success", False):
    print("查询失败: success=false")
    print(f"错误信息: {data.get('errorMsg', data.get('message', '未知错误'))}")
    sys.exit(0)

workitems = data.get("workitems", [])
next_token = data.get("nextToken", "")

if not workitems:
    print("未找到任何需求")
    sys.exit(0)

print(f"共找到 {len(workitems)} 个需求:")
print()
for i, item in enumerate(workitems, 1):
    identifier = item.get("identifier", "N/A")
    subject = item.get("subject", "无标题")
    status = item.get("status", "N/A")
    assigned_to = item.get("assignedTo", "未分配")
    serial_number = item.get("serialNumber", "N/A")
    print(f"  {i}. [{identifier}] {subject}")
    print(f"     状态: {status} | 负责人: {assigned_to} | 编号: {serial_number}")
    print()

if next_token:
    print(f"(还有更多结果, nextToken={next_token})")
PY
}

# 格式化需求详情输出
format_workitem_detail() {
  local input
  input=$(cat)
  INPUT_DATA="$input" python3 <<'PY'
import sys, os, json

data = json.loads(os.environ['INPUT_DATA'])

if not data.get("success", False):
    print("查询失败: success=false")
    print(f"错误信息: {data.get('errorMsg', data.get('message', '未知错误'))}")
    sys.exit(0)

workitem = data.get("workitem", data)
if not workitem or workitem == data and "workitem" not in data:
    # 可能直接返回 workitem 对象
    if "identifier" not in data:
        print("未找到需求详情")
        print(f"响应: {json.dumps(data, ensure_ascii=False, indent=2)[:1000]}")
        sys.exit(0)
    workitem = data

print("=" * 60)
print("【需求详情】")
print("=" * 60)
print(f"需求ID:     {workitem.get('identifier', 'N/A')}")
print(f"编号:       {workitem.get('serialNumber', 'N/A')}")
print(f"标题:       {workitem.get('subject', '无标题')}")
print(f"状态:       {workitem.get('status', 'N/A')}")
print(f"负责人:     {workitem.get('assignedTo', '未分配')}")
print(f"创建人:     {workitem.get('createdBy', 'N/A')}")
print(f"创建时间:   {workitem.get('gmtCreate', 'N/A')}")
print(f"修改时间:   {workitem.get('gmtModified', 'N/A')}")
print(f"优先级:     {workitem.get('priority', 'N/A')}")
print(f"工作项类型: {workitem.get('workitemTypeIdentifier', 'N/A')}")
print(f"空间ID:     {workitem.get('spaceIdentifier', 'N/A')}")
print()

description = workitem.get("description", "")
if description:
    print("【描述】")
    print(description[:2000])
    if len(description) > 2000:
        print("... (描述过长, 已截断)")
    print()

custom_fields = workitem.get("customFields", [])
if custom_fields:
    print("【自定义字段】")
    for field in custom_fields:
        field_name = field.get("fieldIdentifier", "N/A")
        field_value = field.get("value", "N/A")
        print(f"  {field_name}: {field_value}")
    print()

print("=" * 60)
PY
}

[[ $# -ge 1 ]] || { usage; exit 1; }

CMD="$1"; shift

case "$CMD" in
  list)
    max_results="${1:-50}"
    org_id=$(get_org_id)
    project_id=$(get_project_id)
    echo ">>> 查询项目需求列表 (projectId=$project_id, maxResults=$max_results)"
    devops_call "/organization/${org_id}/listWorkitems" \
      "spaceType=Project" \
      "spaceIdentifier=$project_id" \
      "category=Req" \
      "maxResults=$max_results" \
      | format_workitems
    ;;

  detail)
    [[ $# -ge 1 ]] || fail "detail 需要 <workitemId>"
    workitem_id="$1"
    org_id=$(get_org_id)
    echo ">>> 查询需求详情 (workitemId=$workitem_id)"
    devops_call "/organization/${org_id}/workitems/${workitem_id}" \
      | format_workitem_detail
    ;;

  search)
    [[ $# -ge 1 ]] || fail "search 需要 <关键字>"
    keyword="$1"
    org_id=$(get_org_id)
    project_id=$(get_project_id)
    echo ">>> 搜索需求 (projectId=$project_id, keyword=$keyword)"
    search_input=$(devops_call "/organization/${org_id}/listWorkitems" \
      "spaceType=Project" \
      "spaceIdentifier=$project_id" \
      "category=Req" \
      "maxResults=200")
    INPUT_DATA="$search_input" KEYWORD="$keyword" python3 <<'PY'
import os, json

keyword = os.environ['KEYWORD']
data = json.loads(os.environ['INPUT_DATA'])

if not data.get("success", False):
    print(f"查询失败: {data.get('errorMsg', data.get('message', '未知错误'))}")
    sys.exit(0)

workitems = data.get("workitems", [])
matched = [w for w in workitems if keyword.lower() in (w.get("subject", "") or "").lower()]

if not matched:
    print(f"未找到标题包含「{keyword}」的需求 (共扫描 {len(workitems)} 条)")
    sys.exit(0)

print(f"找到 {len(matched)} 个标题包含「{keyword}」的需求:")
print()
for i, item in enumerate(matched, 1):
    identifier = item.get("identifier", "N/A")
    subject = item.get("subject", "无标题")
    status = item.get("status", "N/A")
    assigned_to = item.get("assignedTo", "未分配")
    print(f"  {i}. [{identifier}] {subject}")
    print(f"     状态: {status} | 负责人: {assigned_to}")
    print()
PY
    ;;

  by-date)
    [[ $# -ge 1 ]] || fail "by-date 需要 <日期> (yyyy-MM-dd)"
    date="$1"
    field_id="${2:-$(get_release_time_field_id)}"
    org_id=$(get_org_id)
    project_id=$(get_project_id)
    conditions=$(build_date_condition "$date" "$field_id")
    echo ">>> 按计划上线时间筛选需求 (projectId=$project_id, date=$date, fieldId=$field_id)"
    devops_call "/organization/${org_id}/listWorkitems" \
      "spaceType=Project" \
      "spaceIdentifier=$project_id" \
      "category=Req" \
      "conditions=$conditions" \
      "maxResults=100" \
      | format_workitems
    ;;

  by-test-date)
    [[ $# -ge 1 ]] || fail "by-test-date 需要 <日期> (yyyy-MM-dd)"
    date="$1"
    field_id="${2:-$(get_test_time_field_id)}"
    org_id=$(get_org_id)
    project_id=$(get_project_id)
    conditions=$(build_date_condition "$date" "$field_id")
    echo ">>> 按计划提测时间筛选需求 (projectId=$project_id, date=$date, fieldId=$field_id)"
    devops_call "/organization/${org_id}/listWorkitems" \
      "spaceType=Project" \
      "spaceIdentifier=$project_id" \
      "category=Req" \
      "conditions=$conditions" \
      "maxResults=100" \
      | format_workitems
    ;;

  *)
    usage; exit 1
    ;;
esac
