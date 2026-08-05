# cwork-requirement 配置模板(云效需求只读查询)
# 用法: cp config.example.sh .config.local.sh, 然后把 := 后面的占位符换成实际值
# .config.local.sh 已加入 .gitignore, 切勿提交真实 AK/SK
# 使用 := 语法: 同名环境变量优先, 否则用此处的值

# ---- 阿里云 AK/SK(需要有云效 DevOps 读权限) ----
: "${ALIBABA_CLOUD_ACCESS_KEY_ID:=<your-access-key-id>}"
: "${ALIBABA_CLOUD_ACCESS_KEY_SECRET:=<your-access-key-secret>}"

# ---- 云效组织 ID(在云效 Web 控制台 URL 中可见, 形如 6685211c2f23b7ceb897299f) ----
: "${YUNXIAO_ORG_ID:=<your-organization-id>}"

# ---- 云效项目 ID(Projex 项目 ID, 在云效项目设置中可见, 形如 a938997aeeb9fa64f0237a3534) ----
: "${YUNXIAO_PROJECT_ID:=<your-project-id>}"

# ---- 云效 API 区域(默认 cn-hangzhou, 一般不需要改) ----
: "${YUNXIAO_REGION:=cn-hangzhou}"

# ---- 自定义字段 ID(在云效项目设置 > 工作项 > 自定义字段中查看字段 ID) ----
# 计划上线时间字段 ID(用于 by-date 命令)
: "${YUNXIAO_PLANNED_RELEASE_TIME_FIELD_ID:=<your-planned-release-time-field-id>}"
# 计划提测时间字段 ID(用于 by-test-date 命令)
: "${YUNXIAO_PLANNED_TEST_TIME_FIELD_ID:=<your-planned-test-time-field-id>}"
