# =============================================================================
# cover.ps1 - grey out a private field (an email address, a path) on a screen capture before it is annotated
# =============================================================================
# Writes <capture> with each rectangle filled grey; the original is left as it was under its own name. Rectangles are X,Y,W,H in
# the capture's own pixels.
# Usage, from docs/guide:  powershell -File cover.ps1 -From <capture.png> -To <capture.png> -Rects "x,y,w,h" ["x,y,w,h" ...]
# =============================================================================
param([string]$From, [string]$To, [string[]]$Rects)
Add-Type -AssemblyName System.Drawing
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = [System.Drawing.Image]::FromFile((Join-Path $here "captures\$From"))
$bmp = New-Object System.Drawing.Bitmap $src; $src.Dispose()
$g = [System.Drawing.Graphics]::FromImage($bmp)
$brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(208, 208, 208))
foreach ($r in $Rects) { $v = $r.Split(',') | ForEach-Object { [int]$_ }; $g.FillRectangle($brush, $v[0], $v[1], $v[2], $v[3]) }
$g.Dispose(); $bmp.Save((Join-Path $here "captures\$To"), [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
Write-Host "captures\$To"
