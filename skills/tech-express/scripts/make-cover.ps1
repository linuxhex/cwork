# 封面 png -> jpg（1280 宽、质量 88），清掉微信封面 ~2MB 限制
# 用法: powershell -ExecutionPolicy Bypass -File make-cover.ps1 -Dir <内容目录>/tech-express/20261111
# 注意: 参数名不能叫 $Path，会和 PowerShell 自动变量 Path 冲突，导致路径静默变空
param([Parameter(Mandatory=$true)][string]$Dir)
Add-Type -AssemblyName System.Drawing

if ([System.IO.Path]::IsPathRooted($Dir)) { $root = $Dir } else { $root = Join-Path (Get-Location).Path $Dir }
$CoverPath = Join-Path $root 'images\00-cover.png'
if (-not (Test-Path $CoverPath)) { Write-Error "找不到封面: $CoverPath"; exit 1 }

$src = [System.Drawing.Image]::FromFile($CoverPath)
$w = 1280
$h = [int]($src.Height * $w / $src.Width)
$bmp = New-Object System.Drawing.Bitmap($w, $h)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = 'HighQualityBicubic'
$g.DrawImage($src, 0, 0, $w, $h)
$out = $CoverPath -replace '\.png$', '.jpg'
$enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$p = New-Object System.Drawing.Imaging.EncoderParameters(1)
$p.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]88)
$bmp.Save($out, $enc, $p)
$g.Dispose(); $bmp.Dispose(); $src.Dispose()

$size = (Get-Item $out).Length
Write-Output "$out $size bytes"
if ($size -gt 2MB) { Write-Output "警告：仍超 2MB，把宽度和质量再降一档（$w -> 1080 / 88 -> 80）" }
