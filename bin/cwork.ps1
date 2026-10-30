#Requires -Version 5.1
<#
.SYNOPSIS
  cwork Windows 启动器：定位 Git Bash、托管 CWORK_HOME、把 PowerShell 的参数安全地交给技能脚本。

.DESCRIPTION
  cwork 的技能脚本是 POSIX bash（依赖 curl/sed/cygpath/heredoc），Windows 上唯一可靠的
  运行宿主是 Git for Windows 自带的 bash。本脚本不重写任何技能逻辑，只做三件事：

    1. 找到 bash（环境变量 → 注册表 → 由 git.exe 反推 → 常见安装目录）
    2. 托管 CWORK_HOME（未设置时默认取本仓库根，供 _common.sh 回源读凭证）
    3. 把参数原样透传（PowerShell 会把 -Foo 当命名参数解析、丢弃内嵌双引号，必须绕开）

  子命令全部是「透传」语义：cwork.ps1 <skill> <script> [args...]

.EXAMPLE
  .\cwork.ps1 doctor

.EXAMPLE
  .\cwork.ps1 install --tool qoder

.EXAMPLE
  .\cwork.ps1 log sls_query logs all "order/service and ERROR" 50

.EXAMPLE
  .\cwork.ps1 config nacos_query get k8s-uat "application.yaml"

.EXAMPLE
  .\cwork.ps1 data mcp_client.py query --sql "select 1"

.EXAMPLE
  .\cwork.ps1 sh D:\work\my-script.sh arg1
#>

# ── 控制台编码 ────────────────────────────────────────────────────────────────
# Git Bash 输出 UTF-8，PowerShell 5.1 默认按 OEM 代码页解码 → 中文全是乱码
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch {
    Write-Verbose "无法切换控制台编码: $_"
}

$ErrorActionPreference = 'Continue'

# ── 全局上下文 ────────────────────────────────────────────────────────────────
$script:RepoRoot = Split-Path -Parent $PSScriptRoot
$script:BashExe  = $null
# 退出码单独存放：`& $Exe` 会把 stdout 收进管道，函数返回值会变成「输出行 + 退出码」数组，
# 用返回值传退出码会在有输出时崩掉，这里统一走 $script:LastExit
$script:LastExit = 0

if (-not $env:CWORK_HOME) {
    $env:CWORK_HOME = $script:RepoRoot
}

# 技能根目录：CWORK_HOME/skills → 本仓库 skills → ~/.qoder/skills
function Resolve-SkillsRoot {
    $candidates = @()
    if ($env:CWORK_HOME) { $candidates += (Join-Path $env:CWORK_HOME 'skills') }
    $candidates += (Join-Path $script:RepoRoot 'skills')
    $candidates += (Join-Path $HOME '.qoder\skills')
    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c -PathType Container)) { return $c }
    }
    return $null
}

$script:SkillsRoot = Resolve-SkillsRoot

# ── bash 定位 ─────────────────────────────────────────────────────────────────
function Resolve-Bash {
    $candidates = New-Object System.Collections.Generic.List[string]
    if ($env:CWORK_BASH) { $candidates.Add($env:CWORK_BASH) }

    # 1) 注册表：Git for Windows 安装时写入 InstallPath
    foreach ($key in @('HKLM:\SOFTWARE\GitForWindows',
                       'HKLM:\SOFTWARE\WOW6432Node\GitForWindows',
                       'HKCU:\SOFTWARE\GitForWindows')) {
        try {
            $installPath = (Get-ItemProperty -Path $key -Name InstallPath -ErrorAction Stop).InstallPath
            if ($installPath) {
                $candidates.Add((Join-Path $installPath 'bin\bash.exe'))
                $candidates.Add((Join-Path $installPath 'usr\bin\bash.exe'))
            }
        } catch { }
    }

    # 2) 由 PATH 上的 git.exe 反推（<root>\cmd\git.exe -> <root>\bin\bash.exe）
    $git = Get-Command git.exe -ErrorAction SilentlyContinue
    if ($git -and $git.Source) {
        $gitRoot = Split-Path -Parent (Split-Path -Parent $git.Source)
        if ($gitRoot) {
            $candidates.Add((Join-Path $gitRoot 'bin\bash.exe'))
            $candidates.Add((Join-Path $gitRoot 'usr\bin\bash.exe'))
        }
    }

    # 3) 常见安装目录
    $candidates.Add('C:\Program Files\Git\bin\bash.exe')
    $candidates.Add('C:\Program Files (x86)\Git\bin\bash.exe')
    if ($env:LOCALAPPDATA) {
        $candidates.Add((Join-Path $env:LOCALAPPDATA 'Programs\Git\bin\bash.exe'))
    }

    # 4) PATH 上的 bash.exe（可能是 WSL 的 System32\bash.exe，放最后）
    $onPath = Get-Command bash.exe -ErrorAction SilentlyContinue
    if ($onPath -and $onPath.Source) { $candidates.Add($onPath.Source) }

    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c -PathType Leaf)) { return $c }
    }
    return $null
}

# ── 参数归一 ──────────────────────────────────────────────────────────────────
# 盘符路径反斜杠转正斜杠：Git Bash 与 node 都吃 C:/a/b，吃不下 C:\a\b（会把 \a 当转义）
function ConvertTo-ToolPath {
    param([string]$Value)
    if ([string]::IsNullOrEmpty($Value)) { return $Value }
    if ($Value -match '^[A-Za-z]:[\\/]') { return ($Value -replace '\\', '/') }
    if ($Value -match '^\\\\') { return ($Value -replace '\\', '/') }
    return $Value
}

function Normalize-Arguments {
    param([string[]]$Arguments)
    if (-not $Arguments) { return @() }
    return @($Arguments | ForEach-Object { ConvertTo-ToolPath ([string]$_) })
}

# ── 外部程序调用 ──────────────────────────────────────────────────────────────
# stdout 保留在管道上（便于 `cwork.ps1 log ... | Set-Content`），退出码写 $script:LastExit
function Invoke-External {
    param(
        [string]$Exe,
        [string[]]$Prefix = @(),
        [string[]]$Arguments = @()
    )
    if (-not $Exe) {
        Write-Host "❌ 找不到可执行程序" -ForegroundColor Red
        $script:LastExit = 1
        return
    }
    & $Exe @Prefix @Arguments
    $script:LastExit = $LASTEXITCODE
}

function Get-PythonExe {
    foreach ($name in @($env:CWORK_PYTHON, 'python', 'python3', 'py')) {
        if (-not $name) { continue }
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if (-not $cmd -or -not $cmd.Source) { continue }
        # WindowsApps 下是 Store 应用执行别名（0 字节 reparse point），执行会弹商店
        if ($cmd.Source -match 'WindowsApps') { continue }
        return $cmd.Source
    }
    return $null
}

function Get-NodeExe {
    $cmd = Get-Command node.exe -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return $cmd.Source }
    return $null
}

# ── 技能脚本定位 ──────────────────────────────────────────────────────────────
# 按 basename 在 skills/<skill>/scripts/ 下递归找，扩展名可省略
function Resolve-SkillScript {
    param([string]$Skill, [string]$Name)
    if (-not $script:SkillsRoot) { return $null }
    $scriptsDir = Join-Path (Join-Path $script:SkillsRoot $Skill) 'scripts'
    if (-not (Test-Path -LiteralPath $scriptsDir -PathType Container)) { return $null }

    $base = $Name
    foreach ($ext in @('.sh', '.py', '.cjs', '.js')) {
        if ($base.ToLowerInvariant().EndsWith($ext)) {
            $base = $base.Substring(0, $base.Length - $ext.Length)
            break
        }
    }
    foreach ($ext in @('.sh', '.py', '.cjs', '.js')) {
        $hit = Get-ChildItem -LiteralPath $scriptsDir -Recurse -File -Filter ($base + $ext) -ErrorAction SilentlyContinue |
               Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}

function Invoke-ScriptFile {
    param([string]$Path, [string[]]$Arguments = @())
    $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    $norm = Normalize-Arguments $Arguments
    $toolPath = ConvertTo-ToolPath $Path

    switch ($ext) {
        '.sh' {
            if (-not $script:BashExe) {
                Write-Host "❌ 未找到 Git Bash，请安装 https://git-scm.com/download/win 或设置 CWORK_BASH" -ForegroundColor Red
                $script:LastExit = 1
                return
            }
            Invoke-External -Exe $script:BashExe -Arguments (@($toolPath) + $norm)
        }
        { $_ -in @('.py', '.pyw') } {
            $py = Get-PythonExe
            if (-not $py) {
                Write-Host "❌ 未找到 Python 3（安装 https://www.python.org/downloads/ 或设置 CWORK_PYTHON）" -ForegroundColor Red
                $script:LastExit = 1
                return
            }
            Invoke-External -Exe $py -Arguments (@($toolPath) + $norm)
        }
        default {
            $node = Get-NodeExe
            if (-not $node) {
                Write-Host "❌ 未找到 node.exe" -ForegroundColor Red
                $script:LastExit = 1
                return
            }
            Invoke-External -Exe $node -Arguments (@($toolPath) + $norm)
        }
    }
}

# ── 子命令 ────────────────────────────────────────────────────────────────────
$skills = @('init', 'implement', 'bug', 'test', 'commit', 'do', 'doc',
            'log', 'data', 'config', 'graf', 'code', 'requirement', 'deploy', 'image',
            'article', 'tech-writer', 'wuxia-writer')

function Show-Help {
    Write-Host @"
cwork Windows 启动器

用法:
  cwork.ps1 <命令> [参数...]

安装 / 自检（转发到 node bin/cwork.js）:
  install [--tool auto|<工具名>]                    安装技能到 IDE（工具列表见 README）
  uninstall [--tool ...]                           卸载
  sync    [--tool ...]                             同 install
  check                                            校验源与产物一致性
  doctor                                           环境诊断（bash/python/node/凭证）

运行技能脚本（按 skills/<技能>/scripts/ 下文件名定位，扩展名可省略）:
  sh <script> [args]                  直接运行任意 .sh/.py/.cjs
  <技能> <脚本> [args...]             例: log sls_query logs all "关键字" 50

可用技能:
  $($skills -join ', ')

环境变量:
  CWORK_HOME       cwork 源仓库根（未设置时默认本仓库；技能脚本凭它回源读凭证）
  CWORK_BASH       指定 bash.exe（默认自动探测 Git for Windows）
  CWORK_PYTHON     指定 Python 3 解释器（默认 python / python3 / py）
  CWORK_SKIP_PY_SHIM  设为 1 可关闭 python3 接管（默认开启）

说明:
  参数原样透传，不做 shell 展开；含空格的值请用双引号包住。
  盘符路径会自动把 \\ 转成 /（Git Bash 与 node 都能识别）。
"@
}

function Show-Doctor {
    Write-Host "`ncwork 环境诊断" -ForegroundColor Cyan
    Write-Host ("  {0,-14}{1}" -f 'PowerShell', $PSVersionTable.PSVersion)
    Write-Host ("  {0,-14}{1}" -f 'OS', [Environment]::OSVersion.VersionString)
    Write-Host ("  {0,-14}{1}" -f 'CWORK_HOME', $env:CWORK_HOME)

    if ($script:SkillsRoot) {
        Write-Host ("  {0,-14}{1}" -f '技能根目录', $script:SkillsRoot)
    } else {
        Write-Host ("  {0,-14}{1}" -f '技能根目录', '<未找到>') -ForegroundColor Red
    }

    if ($script:BashExe) {
        Write-Host ("  {0,-14}{1}" -f 'bash', $script:BashExe)
    } else {
        Write-Host ("  {0,-14}{1}" -f 'bash', '<未找到 Git Bash>') -ForegroundColor Red
    }

    $py = Get-PythonExe
    if ($py) {
        Write-Host ("  {0,-14}{1}" -f 'python', $py)
    } else {
        Write-Host ("  {0,-14}{1}" -f 'python', '<未找到>') -ForegroundColor Yellow
    }

    $node = Get-NodeExe
    if ($node) {
        Write-Host ("  {0,-14}{1}" -f 'node', $node)
    } else {
        Write-Host ("  {0,-14}{1}" -f 'node', '<未找到>') -ForegroundColor Red
    }

    foreach ($c in @('git.exe', 'curl.exe', 'docker.exe', 'kubectl.exe', 'ego-browser')) {
        $found = Get-Command $c -ErrorAction SilentlyContinue
        $where = if ($found -and $found.Source) { $found.Source } else { '<未安装>' }
        Write-Host ("  {0,-14}{1}" -f $c, $where)
    }

    $probe = $null
    if ($script:SkillsRoot) { $probe = Join-Path $script:SkillsRoot 'common/win-compat.sh' }

    if ($script:BashExe -and $probe -and (Test-Path -LiteralPath $probe)) {
        Write-Host "`nbash 侧兼容层（python3 接管 / 临时目录 / 服务地图）:" -ForegroundColor Cyan
        # win-compat.sh 支持直接执行，执行即打印诊断（避开 PS 5.1 传 -c 字符串时丢引号的问题）
        & $script:BashExe (ConvertTo-ToolPath $probe) 2>&1 | ForEach-Object { Write-Host "  $_" }
    } elseif (-not $script:BashExe) {
        Write-Host "`n请先安装 Git for Windows: https://git-scm.com/download/win" -ForegroundColor Yellow
        Write-Host "或设置 CWORK_BASH 指向 bash.exe" -ForegroundColor Yellow
    } else {
        Write-Host "`n<未找到 common/win-compat.sh>" -ForegroundColor Yellow
    }
    Write-Host ""
}

function Invoke-CworkJs {
    param([string[]]$Arguments)
    $node = Get-NodeExe
    if (-not $node) {
        Write-Host "❌ 未找到 node.exe，无法执行 bin/cwork.js" -ForegroundColor Red
        $script:LastExit = 1
        return
    }
    $entry = Join-Path $script:RepoRoot 'bin\cwork.js'
    if (-not (Test-Path -LiteralPath $entry)) {
        Write-Host "❌ 未找到 $entry" -ForegroundColor Red
        $script:LastExit = 1
        return
    }
    Invoke-External -Exe $node -Arguments (@((ConvertTo-ToolPath $entry)) + $Arguments)
}

# ── 主流程 ────────────────────────────────────────────────────────────────────
# 刻意不声明 param()：声明后 PowerShell 会把 -Foo 当命名参数解析并报错，
# 而技能脚本大量使用 - 开头的选项，必须走 $args 原样透传。
$argv = @($args | ForEach-Object { [string]$_ })
if ($argv.Count -eq 0) { Show-Help; exit 0 }

$Command = $argv[0].ToLowerInvariant()
$Rest = @()
if ($argv.Count -gt 1) { $Rest = @($argv[1..($argv.Count - 1)]) }

switch -Regex ($Command) {

    '^(-h|--help|help)$' {
        Show-Help
        exit 0
    }

    '^doctor$' {
        $script:BashExe = Resolve-Bash
        Show-Doctor
        if (-not $script:BashExe) { exit 1 }
        exit 0
    }

    '^(install|sync|uninstall)$' {
        if ($Command -eq 'uninstall') { $Rest = @('--uninstall') + $Rest }
        Invoke-CworkJs $Rest
        exit $script:LastExit
    }

    '^check$' {
        Invoke-CworkJs @('--check')
        exit $script:LastExit
    }

    '^env$' {
        Write-Host "# 在 bash 里 eval 以下内容即可复用本仓库配置"
        Write-Host ("export CWORK_HOME='{0}'" -f (ConvertTo-ToolPath $env:CWORK_HOME))
        Write-Host ("export CWORK_PYTHON='{0}'" -f (ConvertTo-ToolPath (Get-PythonExe)))
        exit 0
    }

    '^sh$' {
        $script:BashExe = Resolve-Bash
        if ($Rest.Count -eq 0) {
            Write-Host "用法: cwork.ps1 sh <script> [args...]" -ForegroundColor Yellow
            exit 1
        }
        $raw = $Rest[0]
        if (-not (Test-Path -LiteralPath $raw)) {
            Write-Host "❌ 脚本不存在: $raw" -ForegroundColor Red
            exit 1
        }
        $scriptArgs = @()
        if ($Rest.Count -gt 1) { $scriptArgs = @($Rest[1..($Rest.Count - 1)]) }
        Invoke-ScriptFile -Path (Resolve-Path -LiteralPath $raw).Path -Arguments $scriptArgs
        exit $script:LastExit
    }

    default {
        if ($skills -notcontains $Command) {
            Write-Host "❌ 未知命令: $Command" -ForegroundColor Red
            Write-Host "   运行 cwork.ps1 help 查看用法" -ForegroundColor Yellow
            exit 1
        }
        if ($Rest.Count -eq 0) {
            Write-Host "用法: cwork.ps1 $Command <脚本名> [args...]" -ForegroundColor Yellow
            Write-Host "可用脚本:" -ForegroundColor Yellow
            if ($script:SkillsRoot) {
                $dir = Join-Path (Join-Path $script:SkillsRoot $Command) 'scripts'
                if (Test-Path -LiteralPath $dir) {
                    # 只列可直接运行的入口脚本：排除 _common.sh 等内部库与 *.example.* 模板
                    Get-ChildItem -LiteralPath $dir -Recurse -File |
                        Where-Object { $_.Extension -in @('.sh', '.py', '.cjs') -and
                                       $_.Name -notlike '_*' -and
                                       $_.Name -notlike '*.example.*' } |
                        ForEach-Object { Write-Host ("  " + $_.Name) }
                }
            }
            exit 1
        }

        $script:BashExe = Resolve-Bash
        $target = Resolve-SkillScript -Skill $Command -Name $Rest[0]
        if (-not $target) {
            Write-Host "❌ 在 skills/$Command/scripts/ 下找不到脚本: $($Rest[0])" -ForegroundColor Red
            exit 1
        }
        $scriptArgs = @()
        if ($Rest.Count -gt 1) { $scriptArgs = @($Rest[1..($Rest.Count - 1)]) }
        Invoke-ScriptFile -Path $target -Arguments $scriptArgs
        exit $script:LastExit
    }
}
