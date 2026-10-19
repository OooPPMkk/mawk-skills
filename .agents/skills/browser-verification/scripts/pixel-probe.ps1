# Patch-average pixel sampler for screenshots taken at a known CSS viewport width ("programmatic vision").
# Page.captureScreenshot returns PHYSICAL resolution; this script derives DPR = PngWidth / CssWidth and converts.
# Usage:
#   powershell -ExecutionPolicy Bypass -File pixel-probe.ps1 -Png <png> -CssWidth <css viewport width> -PatchesFile <patches>
# PatchesFile: one patch per line, format: label,x0,x1,y0,y1  (CSS px coordinates)
# Notes: ASCII only. Single-pixel color checks are unreliable (backdrop white 250 vs panel white 254);
#        patch averages are stable. Avoid text / buttons inside patches (a primary button skews the average).
param(
  [Parameter(Mandatory = $true)][string]$Png,
  [Parameter(Mandatory = $true)][double]$CssWidth,
  [Parameter(Mandatory = $true)][string]$PatchesFile
)

Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile($Png)
$bmp = New-Object System.Drawing.Bitmap($img)
$w = $bmp.Width
$h = $bmp.Height
$dpr = $w / $CssWidth
Write-Output ("SIZE={0}x{1} DPR={2:N3}" -f $w, $h, $dpr)
foreach ($line in Get-Content $PatchesFile) {
  $t = $line -split ','
  if ($t.Count -lt 5) { continue }
  $label = $t[0].Trim()
  $x0 = [int]([double]$t[1] * $dpr)
  $x1 = [int]([double]$t[2] * $dpr)
  $y0 = [int]([double]$t[3] * $dpr)
  $y1 = [int]([double]$t[4] * $dpr)
  if ($x0 -lt 0 -or $x1 -gt $w -or $y0 -lt 0 -or $y1 -gt $h) {
    Write-Output ("{0}: OUT_OF_RANGE" -f $label)
    continue
  }
  $sr = 0.0
  $sg = 0.0
  $sb = 0.0
  $n = 0
  for ($x = $x0; $x -lt $x1; $x += 3) {
    for ($y = $y0; $y -lt $y1; $y += 3) {
      $c = $bmp.GetPixel($x, $y)
      $sr += $c.R
      $sg += $c.G
      $sb += $c.B
      $n++
    }
  }
  if ($n -eq 0) {
    Write-Output ("{0}: EMPTY_PATCH" -f $label)
    continue
  }
  Write-Output ("{0}: css({1},{2})-({3},{4}) avgR={5:N1} avgG={6:N1} avgB={7:N1} n={8}" -f $label, $t[1], $t[3], $t[2], $t[4], ($sr / $n), ($sg / $n), ($sb / $n), $n)
}
$bmp.Dispose()
$img.Dispose()
