param([Parameter(Mandatory=$true)][string]$Dir)
Add-Type -AssemblyName System.Drawing
$CoverPath = Join-Path (Get-Location).Path (Join-Path $Dir 'images\00-cover.png')
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
Write-Output "$out $((Get-Item $out).Length) bytes"
