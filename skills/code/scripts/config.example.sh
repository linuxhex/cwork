# cwork-code 配置模板（代码仓库只读查询 + clone/pull）
# 用法: cp config.example.sh .config.local.sh，然后把 := 后面的占位符换成实际值
# .config.local.sh 已加入 .gitignore，切勿提交真实 token

# ---- 平台优先级 ----
# 大部分代码在 CodeUp，前端在 GitLab
# 查找顺序: CodeUp 优先，GitLab 作为 fallback
: "${CODEUP_ENABLED:=true}"
: "${GITLAB_ENABLED:=true}"

# ---- CodeUp 配置（云效代码托管，主平台）----
# API 文档: https://help.aliyun.com/document_detail/153776.html
# API Base: https://openapi-rdc.aliyuncs.com/oapi/v1/codeup/organizations/{orgId}
: "${CODEUP_DOMAIN:=openapi-rdc.aliyuncs.com}"
: "${CODEUP_ORG_ID:=<your-codeup-org-id>}"
: "${CODEUP_TOKEN:=<your-codeup-token>}"

# ---- GitLab 配置（前端项目，fallback 平台）----
# GitLab 地址（不带尾部斜杠，如 http://172.16.98.176）
: "${GITLAB_URL:=http://172.16.98.176}"
# GitLab Private Token（在 GitLab 用户设置 > Access Tokens 生成）
: "${GITLAB_TOKEN:=<your-gitlab-private-token>}"
# 默认搜索的 namespace 列表（逗号分隔，前端项目通常在这些 namespace）
: "${GITLAB_NAMESPACES:=omp,omp-device,zdl,center,omp-barrier,adp,mmp,omp-zdl,ctp}"

# ---- 代码本地存放目录（clone 目标根目录） ----
: "${CODE_WORKSPACE:=/Users/caomunian/Work/code-projects}"

# ---- CodeGraph 配置（优先使用索引查找代码） ----
# codegraph CLI 路径（留空则自动 which codegraph）
: "${CODEGRAPH_BIN:=}"
# codegraph sync 的目标路径（通常与 CODE_WORKSPACE 一致）
: "${CODEGRAPH_PATH:=$CODE_WORKSPACE}"
