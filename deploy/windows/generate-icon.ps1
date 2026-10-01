$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function New-RoundedRectanglePath([float]$x, [float]$y, [float]$width, [float]$height, [float]$radius) {
  $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
  $diameter = $radius * 2
  $path.AddArc($x, $y, $diameter, $diameter, 180, 90)
  $path.AddArc($x + $width - $diameter, $y, $diameter, $diameter, 270, 90)
  $path.AddArc($x + $width - $diameter, $y + $height - $diameter, $diameter, $diameter, 0, 90)
  $path.AddArc($x, $y + $height - $diameter, $diameter, $diameter, 90, 90)
  $path.CloseFigure()
  return $path
}

# Official website palette: ink #17202A, teal #176B63, dark teal #0E4F4A,
# and mint #EEF7F5. Keep the silhouette simple and readable at small sizes.
$iconPath = Join-Path $PSScriptRoot 'HWControl.ico'
$bitmap = [System.Drawing.Bitmap]::new(256, 256)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.Clear([System.Drawing.Color]::Transparent)

$ink = [System.Drawing.Color]::FromArgb(255, 23, 32, 42)
$teal = [System.Drawing.Color]::FromArgb(255, 23, 107, 99)
$mint = [System.Drawing.Color]::FromArgb(255, 238, 247, 245)
$backgroundBrush = [System.Drawing.SolidBrush]::new($ink)
$framePen = [System.Drawing.Pen]::new($teal, 7)
$framePen.Alignment = [System.Drawing.Drawing2D.PenAlignment]::Inset
$framePath = New-RoundedRectanglePath 12 12 232 232 42
$graphics.FillPath($backgroundBrush, $framePath)
$graphics.DrawPath($framePen, $framePath)

# A single geometric H monogram: no gradients, effects, labels, or extra symbols.
$monogramPen = [System.Drawing.Pen]::new($mint, 23)
$monogramPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Square
$monogramPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Square
$graphics.DrawLine($monogramPen, 86, 76, 86, 180)
$graphics.DrawLine($monogramPen, 170, 76, 170, 180)
$graphics.DrawLine($monogramPen, 86, 128, 170, 128)

$handle = $bitmap.GetHicon()
try {
  $icon = [System.Drawing.Icon]::FromHandle($handle)
  $stream = [System.IO.File]::Create($iconPath)
  try { $icon.Save($stream) } finally { $stream.Dispose(); $icon.Dispose() }
} finally {
  Add-Type -Namespace Native -Name IconMethods -MemberDefinition '[System.Runtime.InteropServices.DllImport("user32.dll")] public static extern bool DestroyIcon(System.IntPtr hIcon);'
  [Native.IconMethods]::DestroyIcon($handle) | Out-Null
  $graphics.Dispose()
  $framePath.Dispose()
  $backgroundBrush.Dispose()
  $framePen.Dispose()
  $monogramPen.Dispose()
  $bitmap.Dispose()
}
if (-not (Test-Path $iconPath) -or (Get-Item $iconPath).Length -lt 1000) { throw 'HWControl.ico generation failed.' }
Write-Host "Generated $iconPath"
