#!/usr/bin/env bash
# =============================================================================
# 重建 ARMS 应用 → pid + 专属库 索引 (ARMS_PID_CACHE.md)
# 闭环用: 索引过期/新增服务时一键刷新。
# - prod/test 应用按 prod logstore 匹配专属库; uat 应用按 uat logstore 匹配
# - 主库 all; 例外 device-* 应用协议日志常只在专属库 -> 主库标"专属库优先"
# 用法: bash scripts/rebuild_index.sh
# =============================================================================
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$DIR/../ARMS_PID_CACHE.md"
export OUT
echo ">>> 重建索引: 取 ARMS 应用 + prod/uat logstore ..."
export APPS=$(bash "$DIR/arms_apps.sh" cn-hangzhou 2>&1 | grep 'pid=' | sed -E 's/^ +//' | awk '{p=$2; sub("pid=","",p); print $1"|"p}')
export PROD_LOGS=$(bash "$DIR/sls_query.sh" prod list 2>&1 | grep '^{' | python3 -c 'import sys,json,re;print("\n".join(json.loads(re.search(r"\{.*",sys.stdin.read(),re.S).group(0))["logstores"]))')
export UAT_LOGS=$(bash "$DIR/sls_query.sh" uat list 2>&1 | grep '^{' | python3 -c 'import sys,json,re;print("\n".join(json.loads(re.search(r"\{.*",sys.stdin.read(),re.S).group(0))["logstores"]))')
python3 <<'PY'
import os,re
out=os.environ["OUT"]
apps=[l.split("|",1) for l in os.environ["APPS"].splitlines() if "|" in l]
prod=set(os.environ["PROD_LOGS"].split()); uat=set(os.environ["UAT_LOGS"].split())
rows=[]
for a,pid in apps:
    if a.startswith("VAR_"): continue
    base=a; env="prod"
    for suf,ename in (("-prod","prod"),("-uat","uat"),("-test","test"),("-gray","prod")):
        if base.endswith(suf): base=base[:-len(suf)]; env=ename; break
    logs = uat if env=="uat" else prod
    hits=sorted({l for l in logs if l==base or l.startswith(base+"-") or l.startswith(base+"3")})
    is_device = base.startswith("device-")
    rows.append((a,pid,env,hits,is_device))
with open(out,"w") as f:
    f.write("# ARMS 应用 → pid + 日志库索引（cn-hangzhou）\n\n")
    f.write("> 一键重建: `bash scripts/rebuild_index.sh`（重跑 arms_apps + sls list 两环境并匹配）。\n\n")
    f.write("> **主库 `all`**（业务结构化日志都在这）；**例外：`device-*` 应用协议日志常只在专属库、不在 all**，主库标 `专属库优先`，查不到去专属库。\n")
    f.write("> `专属库` 按应用名前缀匹配：prod 应用匹配 prod 库、uat 应用匹配 uat 库；流量低时专属库可能空，回退 all。\n")
    f.write("> pid 为重建时刻快照，应用重建后失效（信号：arms_traces/arms_trace 返回空或鉴权错 → 重跑本脚本）。\n\n")
    f.write("| 应用 | pid | 环境 | 专属库(可选) | 主库 |\n|---|---|---|---|---|\n")
    for a,pid,env,h,is_dev in sorted(rows):
        mainlib = "专属库优先" if (is_dev and h) else "all"
        if not h: lib="—"
        elif len(h)>6: lib="%s-* 等%d个"%(h[0].split("-")[0], len(h))
        else: lib=", ".join(h)
        f.write("| %s | %s | %s | %s | %s |\n" % (a,pid,env,lib,mainlib))
matched=[r for r in rows if r[3]]
dev=[r for r in rows if r[4] and r[3]]
print(">>> 重建完成: 共 %d 应用, %d 有专属库, %d 仅 all" % (len(rows), len(matched), len(rows)-len(matched)))
print(">>> device 应用(主库=专属库优先): %d 个" % len(dev))
print(">>> 写入: %s" % out)
PY