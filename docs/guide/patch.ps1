# =============================================================================
# patch.ps1 - mend a capture's damaged rows (the white bands some screen grabs carry) with the same rows of another grab of
# the same window, taken with nothing moved
# =============================================================================
# Writes <To> = <From> with rows Y to Y+H-1 copied from <Donor>; the captures themselves are left as they were.
# Usage, from docs/guide:  powershell -File patch.ps1 -From <capture.png> -Donor <capture.png> -To <capture.png> -Y <row> -H <rows>
# =============================================================================
param([string]$From, [string]$Donor, [string]$To, [int]$Y, [int]$H)
Add-Type -AssemblyName System.Drawing
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$a = [System.Drawing.Image]::FromFile((Join-Path $here "captures\$From")); $bmp = New-Object System.Drawing.Bitmap $a; $a.Dispose()
$d = [System.Drawing.Image]::FromFile((Join-Path $here "captures\$Donor"))
if ($d.Width -ne $bmp.Width -or $d.Height -ne $bmp.Height) { throw "the two grabs differ in size" }
$g = [System.Drawing.Graphics]::FromImage($bmp)
$r = New-Object System.Drawing.Rectangle 0, $Y, $bmp.Width, $H
$g.DrawImage($d, $r, $r, [System.Drawing.GraphicsUnit]::Pixel); $g.Dispose(); $d.Dispose()
$bmp.Save((Join-Path $here "captures\$To"), [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
Write-Host "captures\$To"
