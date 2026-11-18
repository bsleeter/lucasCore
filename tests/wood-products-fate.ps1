# =============================================================================
# wood-products-fate.ps1 - the Wood Products page's diagram model (ui/WoodProductsFate.cs) for the cases of a CSV, for
# tests/unit-wood-products-fate.R, which compares them with src/wood-products.R. With -Png it also draws the diagram of the first case.
# =============================================================================
# Usage: powershell -ExecutionPolicy Bypass -File tests/wood-products-fate.ps1 -Dll <lucasCoreUI.dll> -Dir <defaults/wood-products>
#          -Cases <in.csv> -Out <out.csv> [-Png <file.png>]
# Cases: Region, Wood, LogSize, Years, Long, Life, Energy, RecWood, RecPaper, DiscEnergy (blank = the default).
# Windows PowerShell (.NET Framework), as the DLL is built for it.
# =============================================================================
param([string]$Dll, [string]$Dir, [string]$Cases, [string]$Out, [string]$Png = "")
$ErrorActionPreference = "Stop"
$asm = [Reflection.Assembly]::LoadFrom((Resolve-Path $Dll))
$fate = $asm.GetType("lucasCoreUI.WoodProductsFate"); $lev = $asm.GetType("lucasCoreUI.WoodProductsFate+Levers")
$inv = [Globalization.CultureInfo]::InvariantCulture
function Levers($c) {
    $L = [Activator]::CreateInstance($lev)
    foreach ($k in "Long", "Life", "Energy", "RecWood", "RecPaper", "DiscEnergy") { if ("$($c.$k)" -ne "" -and "$($c.$k)" -ne "NA") { $lev.GetField($k).SetValue($L, [double]::Parse($c.$k, $inv)) } }
    return $L
}
$rows = @(); $first = $null
foreach ($c in (Import-Csv $Cases)) {
    $L = Levers $c
    $r = $fate.GetMethod("Make").Invoke($null, @([string]$Dir, [string]$c.Region, [string]$c.Wood, [string]$c.LogSize, [int]$c.Years, $L))
    if ($null -eq $first) { $first = @($c, $r) }
    $rows += [pscustomobject]@{ Case = $c.Case; InUse = $r.InUseTotal.ToString("R", $inv); Buildings = $r.InUse[0].ToString("R", $inv); Paper = $r.InUse[3].ToString("R", $inv)
        Recovered = $r.Recovered.ToString("R", $inv); Landfill = $r.Landfill.ToString("R", $inv); Dump = $r.Dump.ToString("R", $inv)
        EmitEnergy = $r.EmitEnergy.ToString("R", $inv); EmitNo = $r.EmitNo.ToString("R", $inv); AtHarvest = $r.AtHarvest.ToString("R", $inv)
        Made = ($r.Made | Measure-Object -Sum).Sum.ToString("R", $inv); Discarded = ($r.DiscTotal | Measure-Object -Sum).Sum.ToString("R", $inv) }
}
$rows | Export-Csv -NoTypeInformation -Path $Out
if ($Png -ne "") {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    $t = $asm.GetType("lucasCoreUI.WoodProductsDiagram"); $d = [Activator]::CreateInstance($t, $true)
    $c = $first[0]; $flags = [Reflection.BindingFlags]"Public,NonPublic,Instance"
    $base = $fate.GetMethod("Make").Invoke($null, @([string]$Dir, [string]$c.Region, [string]$c.Wood, [string]$c.LogSize, [int]$c.Years, $null))
    $t.GetField("Fate", $flags).SetValue($d, $first[1]); $t.GetField("Base", $flags).SetValue($d, $base)
    $d.Size = New-Object Drawing.Size 900, 386
    $bmp = New-Object Drawing.Bitmap 900, 386
    $d.DrawToBitmap($bmp, (New-Object Drawing.Rectangle 0, 0, 900, 386)); $bmp.Save($Png, [Drawing.Imaging.ImageFormat]::Png)
}
