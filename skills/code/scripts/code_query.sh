#!/usr/bin/env bash
# =============================================================================
# cwork-code: 代码仓库只读查询 + clone/pull + codegraph 触发
# 绝对只读: API 调用仅 GET, 永不写。clone/pull 仅本地操作。
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

usage() {
  cat <<'EOF'
cwork-code — 代码仓库只读查询 + clone/pull + codegraph 触发

用法:
  code_query.sh <命令> [参数]

命令:
  list [--page N] [--per-page N]      列出所有项目（默认第1页，每页50条）
  search <关键字>                       按名称搜索项目
  project <项目名>                     查看项目详情（ID/路径/clone URL）
  branches <项目名>                    列出项目所有分支
  clone <项目名> [分支] [目标目录]      clone 仓库（可选指定分支和目标目录）
  pull [项目名|all] [目录]              pull 最新代码（默认 all=全部子目录）
  sync [路径]                           触发 codegraph 增量同步

示例:
  code_query.sh list
  code_query.sh search order
  code_query.sh project flow-charge-server
  code_query.sh branches flow-charge-server
  code_query.sh clone flow-charge-server feature/xxx
  code_query.sh pull all
  code_query.sh sync
EOF
}

format_projects() {
  local input
  input=$(cat)
  INPUT_DATA="$input" python3 <<'PY'
import sys, os, json

data = json.loads(os.environ['INPUT_DATA'])
if isinstance(data, dict) and "message" in data:
    print(f"查询失败: {data['message']}")
    sys.exit(0)

if not isinstance(data, list):
    data = [data]

if not data:
    print("未找到任何项目")
    sys.exit(0)

print(f"共 {len(data)} 个项目:")
print()
for i, p in enumerate(data, 1):
    pid = p.get("id", "N/A")
    name = p.get("name", "N/A")
    path = p.get("path_with_namespace", "N/A")
    desc = p.get("description", "") or ""
    default_branch = p.get("default_branch", "master")
    http_url = p.get("http_url_to_repo", "")
    print(f"  {i}. [{pid}] {name}")
    print(f"     路径: {path}")
    print(f"     默认分支: {default_branch}")
    if desc:
        print(f"     描述: {desc}")
    if http_url:
        print(f"     Clone: {http_url}")
    print()
PY
}

format_branches() {
  local input
  input=$(cat)
  INPUT_DATA="$input" python3 <<'PY'
import sys, os, json

data = json.loads(os.environ['INPUT_DATA'])
if isinstance(data, dict) and "message" in data:
    print(f"查询失败: {data['message']}")
    sys.exit(0)

if not isinstance(data, list):
    data = [data]

if not data:
    print("未找到任何分支")
    sys.exit(0)

print(f"共 {len(data)} 个分支:")
print()
for i, b in enumerate(data, 1):
    name = b.get("name", "N/A")
    protected = b.get("protected", False)
    commit = b.get("commit", {})
    author = commit.get("author_name", "N/A") if isinstance(commit, dict) else "N/A"
    date = commit.get("committed_date", "")[:10] if isinstance(commit, dict) else ""
    msg = commit.get("message", "")[:60] if isinstance(commit, dict) else ""
    prot_tag = " [protected]" if protected else ""
    print(f"  {i}. {name}{prot_tag}")
    print(f"     作者: {author} | 日期: {date}")
    if msg:
        print(f"     提交: {msg}")
    print()
PY
}

format_project_detail() {
  local input
  input=$(cat)
  INPUT_DATA="$input" python3 <<'PY'
import sys, os, json

data = json.loads(os.environ['INPUT_DATA'])
if isinstance(data, dict) and "message" in data:
    print(f"查询失败: {data['message']}")
    sys.exit(0)

print("=" * 60)
print("【项目详情】")
print("=" * 60)
print(f"ID:           {data.get('id', 'N/A')}")
print(f"名称:         {data.get('name', 'N/A')}")
print(f"路径:         {data.get('path_with_namespace', 'N/A')}")
print(f"描述:         {data.get('description', '') or '无'}")
print(f"默认分支:     {data.get('default_branch', 'master')}")
print(f"HTTP Clone:   {data.get('http_url_to_repo', 'N/A')}")
print(f"SSH Clone:    {data.get('ssh_url_to_repo', 'N/A')}")
print(f"Web URL:      {data.get('web_url', 'N/A')}")
print(f"创建时间:     {data.get('created_at', 'N/A')}")
print(f"最后活动:     {data.get('last_activity_at', 'N/A')}")
print("=" * 60)
PY
}

[[ $# -ge 1 ]] || { usage; exit 1; }

CMD="$1"; shift

case "$CMD" in
  list)
    page="1"
    per_page="50"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --page) page="$2"; shift 2 ;;
        --per-page) per_page="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    echo ">>> 列出项目 (page=$page, per_page=$per_page)"
    gitlab_call "/api/v4/projects" "page=$page" "per_page=$per_page" "order_by=name" "sort=asc" | format_projects
    ;;

  search)
    [[ $# -ge 1 ]] || fail "search 需要 <关键字>"
    keyword="$1"
    echo ">>> 搜索项目 (keyword=$keyword)"
    gitlab_call "/api/v4/projects" "search=$keyword" "per_page=50" | format_projects
    ;;

  project)
    [[ $# -ge 1 ]] || fail "project 需要 <项目名>"
    project_name="$1"
    pid=$(find_project_id "$project_name") || fail "未找到项目: $project_name（在已知 namespace 中均未匹配）"
    echo ">>> 项目详情 (id=$pid)"
    gitlab_call "/api/v4/projects/$pid" | format_project_detail
    ;;

  branches)
    [[ $# -ge 1 ]] || fail "branches 需要 <项目名>"
    project_name="$1"
    pid=$(find_project_id "$project_name") || fail "未找到项目: $project_name"
    echo ">>> 列出分支 (project=$project_name, id=$pid)"
    gitlab_call "/api/v4/projects/$pid/repository/branches" "per_page=100" | format_branches
    ;;

  clone)
    [[ $# -ge 1 ]] || fail "clone 需要 <项目名>"
    project_name="$1"
    branch="${2:-master}"
    target_dir="${3:-$CODE_WORKSPACE}"

    clone_url=$(get_clone_url "$project_name")
    [[ -n "$clone_url" ]] || fail "未找到项目: $project_name 或无法获取 clone URL"

    repo_dir="${target_dir}/${project_name}"

    if [[ -d "$repo_dir/.git" ]]; then
      echo ">>> 仓库已存在: $repo_dir，执行 pull"
      cd "$repo_dir"
      git pull origin "$branch" --ff-only 2>&1 || git pull origin "$branch"
    else
      echo ">>> Clone: $clone_url -> $repo_dir (branch=$branch)"
      mkdir -p "$target_dir"
      git clone -b "$branch" "$clone_url" "$repo_dir" 2>&1
    fi

    echo ""
    echo "仓库就绪: $repo_dir"
    echo ">>> 触发 codegraph 同步..."
    trigger_codegraph_sync "$CODEGRAPH_PATH"
    ;;

  pull)
    target="${1:-all}"
    base_dir="${2:-$CODE_WORKSPACE}"

    if [[ "$target" == "all" ]]; then
      echo ">>> Pull 所有仓库: $base_dir"
      for dir in "$base_dir"/*/; do
        if [[ -d "$dir/.git" ]]; then
          repo_name=$(basename "$dir")
          echo ""
          echo "--- $repo_name ---"
          cd "$dir"
          current_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
          echo "当前分支: $current_branch"
          git pull --ff-only 2>&1 || git pull 2>&1 || echo "pull 失败，跳过"
        fi
      done
    else
      repo_dir="${base_dir}/${target}"
      [[ -d "$repo_dir/.git" ]] || fail "仓库不存在: $repo_dir（请先 clone）"
      echo ">>> Pull: $target"
      cd "$repo_dir"
      git pull --ff-only 2>&1 || git pull 2>&1
    fi

    echo ""
    echo ">>> 触发 codegraph 同步..."
    trigger_codegraph_sync "$CODEGRAPH_PATH"
    ;;

  sync)
    sync_path="${1:-$CODEGRAPH_PATH}"
    echo ">>> 触发 codegraph 同步: $sync_path"
    trigger_codegraph_sync "$sync_path"
    ;;

  *)
    usage; exit 1
    ;;
esac
