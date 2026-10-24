# =============================================================================
# annotate.ps1 - draw the guide's step marks on screen captures: a red outline around each control and a numbered red badge
# =============================================================================
# Reads annotations.csv (File, Step, X, Y, W, H in the capture's own pixels; Step blank = outline only) and writes each annotated
# capture to figures/ under the same name, cropped to crops.csv (File, X, Y, W, H) when the file is listed there. Captures stay
# untouched in captures/, so a mark or a crop can be moved and the figure redrawn.
# Usage, from docs/guide:  powershell -File annotate.ps1
# =============================================================================
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$out = Join-Path $here "figures"; New-Item -ItemType Directory -Force $out | Out-Null
$red = [System.Drawing.Color]::FromArgb(204, 32, 39)
$pen = New-Object System.Drawing.Pen($red, 3)
$fill = New-Object System.Drawing.SolidBrush($red)
$white = [System.Drawing.Brushes]::White
$font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$fmt = New-Object System.Drawing.StringFormat; $fmt.Alignment = "Center"; $fmt.LineAlignment = "Center"
$r = 11   # badge radius
$cf = Join-Path $here "crops.csv"
$crops = if (Test-Path $cf) { Import-Csv $cf } else { @() }

foreach ($g in (Import-Csv (Join-Path $here "annotations.csv") | Group-Object File)) {
    $src = Join-Path $here "captures\$($g.Name)"
    $img = [System.Drawing.Bitmap]::FromFile($src)
    $bmp = New-Object System.Drawing.Bitmap($img.Width, $img.Height)
    $gr = [System.Drawing.Graphics]::FromImage($bmp)
    $gr.SmoothingMode = "AntiAlias"; $gr.TextRenderingHint = "AntiAliasGridFit"
    $gr.DrawImage($img, 0, 0, $img.Width, $img.Height); $img.Dispose()
    foreach ($a in $g.Group) {
        $x = [int]$a.X; $y = [int]$a.Y; $w = [int]$a.W; $h = [int]$a.H
        $gr.DrawRectangle($pen, $x, $y, $w, $h)
        if ($a.Step) {
            # the badge sits on the outline's top-left corner, pulled inside the image when the corner is at an edge
            $cx = [Math]::Max($r + 2, $x); $cy = [Math]::Max($r + 2, $y)
            $gr.FillEllipse($fill, $cx - $r, $cy - $r, 2 * $r, 2 * $r)
            $gr.DrawString($a.Step, $font, $white, (New-Object System.Drawing.RectangleF(($cx - $r), ($cy - $r), (2 * $r), (2 * $r))), $fmt)
        }
    }
    $gr.Dispose()
    # crop to the part that matters, so the text stays readable when the doc scales the figure to its column width
    $c = $crops | Where-Object { $_.File -eq $g.Name } | Select-Object -First 1
    if ($c) {
        $rect = New-Object System.Drawing.Rectangle([int]$c.X, [int]$c.Y, [Math]::Min([int]$c.W, $bmp.Width - [int]$c.X), [Math]::Min([int]$c.H, $bmp.Height - [int]$c.Y))
        $cut = $bmp.Clone($rect, $bmp.PixelFormat); $bmp.Dispose(); $bmp = $cut
    }
    $bmp.Save((Join-Path $out $g.Name), [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    Write-Host "figures\$($g.Name)"
}
