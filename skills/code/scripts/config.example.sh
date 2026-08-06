# cwork-code 配置模板（代码仓库只读查询 + clone/pull）
# 用法: cp config.example.sh .config.local.sh，然后把 := 后面的占位符换成实际值
# .config.local.sh 已加入 .gitignore，切勿提交真实 token

# ---- GitLab 配置 ----
# GitLab 地址（不带尾部斜杠，如 http://172.16.98.176）
: "${GITLAB_URL:=http://172.16.98.176}"
# GitLab Private Token（在 GitLab 用户设置 > Access Tokens 生成）
: "${GITLAB_TOKEN:=<your-gitlab-private-token>}"
# 默认搜索的 namespace 列表（逗号分隔，getProjectId 按顺序查找）
: "${GITLAB_NAMESPACES:=omp,omp-device,zdl,center,omp-barrier,adp,mmp,omp-zdl,ctp}"

# ---- 代码本地存放目录（clone 目标根目录） ----
: "${CODE_WORKSPACE:=/Users/caomunian/Work/code-projects}"

# ---- CodeGraph 配置 ----
# codegraph CLI 路径（留空则自动 which codegraph）
: "${CODEGRAPH_BIN:=}"
# codegraph sync 的目标路径（通常与 CODE_WORKSPACE 一致）
: "${CODEGRAPH_PATH:=$CODE_WORKSPACE}"
