$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function New-RoundedRectanglePath([float]$x, [float]$y, [float]$width, [float]$height, [float]$radius) {
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $diameter = $radius * 2
  $path.AddArc($x, $y, $diameter, $diameter, 180, 90)
  $path.AddArc($x + $width - $diameter, $y, $diameter, $diameter, 270, 90)
  $path.AddArc($x + $width - $diameter, $y + $height - $diameter, $diameter, $diameter, 0, 90)
  $path.AddArc($x, $y + $height - $diameter, $diameter, $diameter, 90, 90)
  $path.CloseFigure()
  return $path
}

$iconPath = Join-Path $PSScriptRoot 'HWControl.ico'
$bitmap = New-Object System.Drawing.Bitmap 256, 256
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.Clear([System.Drawing.Color]::Transparent)

$background = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
  (New-Object System.Drawing.Rectangle 0, 0, 256, 256),
  ([System.Drawing.Color]::FromArgb(255, 15, 23, 42)),
  ([System.Drawing.Color]::FromArgb(255, 30, 64, 85)),
  45
)
$backgroundPath = New-RoundedRectanglePath 12 12 232 232 46`n$graphics.FillPath($background, $backgroundPath)

$accent = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 64, 220, 190)), 12
$accent.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$accent.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$chipPath = New-RoundedRectanglePath 58 58 140 140 24`n$graphics.DrawPath($accent, $chipPath)

$graphics.DrawLine($accent, 88, 42, 88, 58)
$graphics.DrawLine($accent, 128, 42, 128, 58)
$graphics.DrawLine($accent, 168, 42, 168, 58)
$graphics.DrawLine($accent, 88, 198, 88, 214)
$graphics.DrawLine($accent, 128, 198, 128, 214)
$graphics.DrawLine($accent, 168, 198, 168, 214)
$graphics.DrawLine($accent, 42, 88, 58, 88)
$graphics.DrawLine($accent, 42, 128, 58, 128)
$graphics.DrawLine($accent, 42, 168, 58, 168)
$graphics.DrawLine($accent, 198, 88, 214, 88)
$graphics.DrawLine($accent, 198, 128, 214, 128)
$graphics.DrawLine($accent, 198, 168, 214, 168)

$center = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 64, 220, 190))
$graphics.FillEllipse($center, 102, 102, 52, 52)
$inner = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 15, 23, 42))
$graphics.FillEllipse($inner, 117, 117, 22, 22)

$hFont = New-Object System.Drawing.Font('Segoe UI', 25, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
$graphics.DrawString('H', $hFont, $white, 111, 164)

$handle = $bitmap.GetHicon()
try {
  $icon = [System.Drawing.Icon]::FromHandle($handle)
  $stream = [System.IO.File]::Create($iconPath)
  try { $icon.Save($stream) } finally { $stream.Dispose(); $icon.Dispose() }
} finally {
  Add-Type -Namespace Native -Name IconMethods -MemberDefinition '[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern bool DestroyIcon(System.IntPtr hIcon);'
  [Native.IconMethods]::DestroyIcon($handle) | Out-Null
  $graphics.Dispose()
  $backgroundPath.Dispose()
  $chipPath.Dispose()
  $background.Dispose()
  $accent.Dispose()
  $center.Dispose()
  $inner.Dispose()
  $hFont.Dispose()
  $white.Dispose()
  $bitmap.Dispose()
}
if (-not (Test-Path $iconPath) -or (Get-Item $iconPath).Length -lt 1000) { throw 'HWControl.ico generation failed.' }
Write-Host "Generated $iconPath"
