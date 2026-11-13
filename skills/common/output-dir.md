# 全局内容产物目录（contentDir）

**适用范围**：本工程所有 skill 产出的**内容型产物**——公众号/头条文章目录、科技速递期次目录、正文 HTML、封面与配图、过程台账（`candidates.md`、`draft-report.json`、`inject*.js`）、技术方案之外的文档稿。

**不适用**（留在仓库内，路径不变）：
- `docs/requirements/**` —— 需求目录、`workflow-state.json`、测试 `plan.json/result.json`、`tech-design.md` 等**开发流程状态**（init/implement/test/commit/doc 依赖它，多工程同步逻辑也基于仓库相对路径）
- 源码、skill 自身文件、仓库文档（`README.md`、`AGENTS.md`、`docs/cwork-introduction.md`）

---

## 一、解析优先级（从高到低，命中即止）

| 级别 | 来源 | 说明 |
|------|------|------|
| ① | 用户当轮明确指定的路径 | 「放到 D:\zzz\xxx」「就写在当前目录」——最高，覆盖一切 |
| ② | 环境变量 `CWORK_CONTENT_DIR` | 换机器/临时改指向用这个，与 `CWORK_HOME` 同一套机制 |
| ③ | `cwork.content.json` 的 `contentDir` | 工程级默认（当前 = `D:/zzz/articles`）。先找**当前工作区根**，找不到再找 `$CWORK_HOME/cwork.content.json`（非 cwork 工作区但复用本套 skill 时靠它，与凭证回源同一机制） |
| ④ | `<repo>/docs/articles` | 历史兜底，仅当 ③ 缺失或目标盘不可写；**必须告知用户已回落** |

解析一次，全程复用：同一次任务里不要每步重新解析，也不要一半写外置一半写仓库。

## 二、解析片段（照抄，别手拼）

PowerShell（本机默认 shell，`&&` 不可用，用 `;`）：

```powershell
$CFG_FILE = if (Test-Path cwork.content.json) { 'cwork.content.json' } elseif ($env:CWORK_HOME -and (Test-Path "$env:CWORK_HOME\cwork.content.json")) { "$env:CWORK_HOME\cwork.content.json" } else { $null }
$CFG = if ($CFG_FILE) { (Get-Content $CFG_FILE -Raw -Encoding UTF8 | ConvertFrom-Json).contentDir } else { $null }
$CONTENT_DIR = if ($env:CWORK_CONTENT_DIR) { $env:CWORK_CONTENT_DIR } elseif ($CFG) { $CFG } else { "$PWD/docs/articles" }
New-Item -ItemType Directory -Force -Path "$CONTENT_DIR\<主题>\<期次>" | Out-Null
"产物目录：$CONTENT_DIR"
```

bash / Git Bash：

```bash
CONTENT_DIR="${CWORK_CONTENT_DIR:-$(node -e 'process.stdout.write(require("./cwork.content.json").contentDir)' 2>/dev)}"
: "${CONTENT_DIR:=$PWD/docs/articles}"
mkdir -p "$CONTENT_DIR/<主题>/<期次>"
```

## 三、目录结构

```
<$CONTENT_DIR>/
├── <文章主题或系列名>/          # 例：qianmen-bajiang、github-ai-series
│   ├── images/                  # 单篇直出时的配图
│   └── <子篇名>/                 # 系列下的每一篇，图放各自 images/
└── tech-express/<YYYYMMDD>/      # 科技速递按日期锚定
```

- 一篇一档、一期一档，配图固定放该档下的 `images/`，正文引用相对路径 `images/xx.png`。
- 目录已存在即视为**更新当期产物**，不新建第二份（速递沿用同一 `appmsgid`，文章沿用同一草稿）。

## 四、配置文件约束（踩过坑）

`cwork.content.json` **只能写 ASCII**（路径用 `/`，说明文字放本文件）。原因：Windows PowerShell 5.1 的 `Get-Content` 默认按 ANSI（本机 GBK）读文件，中文值会报 `ConvertFrom-Json : 传入的字符串未终止` 而静默回落到兜底路径；读它时必须加 `-Encoding UTF8` 作为第二重保险。改完配置**必须实际跑一次上面的解析片段**，看输出的 `产物目录：` 是否为预期值，不能只看文件内容。

---

## 五、铁律

1. **禁止把绝对路径写死**进 skill 文档、脚本注释或命令示例，一律写 `$CONTENT_DIR/...` 或 `<内容目录>/...`；真实跑命令时才展开成绝对路径。
2. 写入前先建目录并**回显一次实际落点**（一行即可，如「产物目录：D:/zzz/articles/tech-express/20261113」），避免产物散落到 C 盘。
3. 外置目录**不在 git 内**：产物不入库、不提交、不 `git add`；仓库里只留 skill 与工具脚本。需要长期留存的重要稿本，提醒用户另行备份。
4. 跨盘不可写（D 盘未挂载、沙箱限制、路径含非法字符）→ 如实报错并说明回落 ④，**不要**静默改成仓库路径后再当成功汇报。
5. 历史遗留：`docs/articles/**` 已于 2026-11-13 整体迁至 `D:/zzz/articles/**` 并从 git 移除。读到旧路径引用（含记忆、旧文档、旧脚本注释）一律改按新位置解析。
