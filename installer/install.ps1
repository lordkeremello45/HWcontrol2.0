$ErrorActionPreference = 'Stop'

$repo = 'lordkeremello45/HWcontrol2.0'
$api = "https://api.github.com/repos/$repo/releases?per_page=100"
$headers = @{ 'Accept' = 'application/vnd.github+json'; 'User-Agent' = 'HWControl-Installer' }

Write-Host 'HWControl Windows Installer' -ForegroundColor Cyan
Write-Host 'Resolving the latest stable Windows release...'

$releases = Invoke-RestMethod -Uri $api -Headers $headers
$release = $releases | Where-Object { $_.tag_name -match '-windows$' -and -not $_.draft -and -not $_.prerelease } | Sort-Object { [datetime]$_.published_at } -Descending | Select-Object -First 1
if (-not $release) { throw 'No stable Windows release is currently available.' }

$setup = $release.assets | Where-Object { $_.name -match '-Windows-x64-Setup\.exe$' } | Select-Object -First 1
$msi = $release.assets | Where-Object { $_.name -match '\.msi$' } | Select-Object -First 1
if ($setup) {
  $artifact = $setup
  $sha = $release.assets | Where-Object { $_.name -match '-Windows-x64-Setup\.sha256$' } | Select-Object -First 1
  $kind = 'Setup'
} else {
  $artifact = $msi
  $sha = $release.assets | Where-Object { $_.name -match '-Windows-x64\.sha256$' } | Select-Object -First 1
  $kind = 'MSI fallback'
}

if (-not $artifact) { throw "The latest Windows release ($($release.tag_name)) does not publish a Windows installer." }
if (-not $sha) { throw "The latest Windows release ($($release.tag_name)) has no matching SHA-256 checksum. Installation is blocked." }

$temp = Join-Path $env:TEMP $artifact.name
$shaTemp = Join-Path $env:TEMP $sha.name
Write-Host "Downloading $($artifact.name) ($kind)..."
Invoke-WebRequest -Uri $artifact.browser_download_url -Headers $headers -OutFile $temp
Invoke-WebRequest -Uri $sha.browser_download_url -Headers $headers -OutFile $shaTemp

$expected = Get-Content $shaTemp | ForEach-Object {
  if ($_ -match '^([0-9a-fA-F]{64})\s+\*?(.+)$') {
    [PSCustomObject]@{ Hash = $matches[1].ToLower(); File = [IO.Path]::GetFileName($matches[2]) }
  }
} | Where-Object { $_.File -eq $artifact.name } | Select-Object -First 1
if (-not $expected) { throw "No SHA-256 entry for $($artifact.name) was found. Installation is blocked." }

$actual = (Get-FileHash $temp -Algorithm SHA256).Hash.ToLower()
if ($actual -ne $expected.Hash) { throw 'SHA-256 verification failed. The installer was not launched.' }
Write-Host 'SHA-256 verification: OK' -ForegroundColor Green

if ($kind -eq 'Setup') {
  Write-Host "Starting HWControl $($release.tag_name) Setup..."
  $process = Start-Process -FilePath $temp -Wait -PassThru
} else {
  Write-Host "Starting HWControl $($release.tag_name) MSI installer..."
  $process = Start-Process msiexec.exe -ArgumentList '/i', "`"$temp`"" -Wait -PassThru
}
if ($process.ExitCode -ne 0) { throw "HWControl installation failed with exit code $($process.ExitCode)." }
Write-Host 'HWControl installation finished.' -ForegroundColor Green
