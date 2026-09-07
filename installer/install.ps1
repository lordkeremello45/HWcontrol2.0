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
$sha = $release.assets | Where-Object { $_.name -match '-Windows-x64-Setup\.sha256$' } | Select-Object -First 1
if (-not $setup) { throw "The latest Windows release ($($release.tag_name)) does not publish the HWControl Setup bootstrapper." }
if (-not $sha) { throw "The latest Windows release ($($release.tag_name)) has no Setup SHA-256 checksum. Installation is blocked." }

$temp = Join-Path $env:TEMP $setup.name
$shaTemp = Join-Path $env:TEMP $sha.name
Write-Host "Downloading $($setup.name)..."
Invoke-WebRequest -Uri $setup.browser_download_url -Headers $headers -OutFile $temp
Invoke-WebRequest -Uri $sha.browser_download_url -Headers $headers -OutFile $shaTemp

$expected = Get-Content $shaTemp | ForEach-Object {
  if ($_ -match '^([0-9a-fA-F]{64})\s+\*?(.+)$') {
    [PSCustomObject]@{ Hash = $matches[1].ToLower(); File = [IO.Path]::GetFileName($matches[2]) }
  }
} | Where-Object { $_.File -eq $setup.name } | Select-Object -First 1
if (-not $expected) { throw "No SHA-256 entry for $($setup.name) was found. Installation is blocked." }

$actual = (Get-FileHash $temp -Algorithm SHA256).Hash.ToLower()
if ($actual -ne $expected.Hash) { throw 'SHA-256 verification failed. The installer was not launched.' }
Write-Host 'SHA-256 verification: OK' -ForegroundColor Green

Write-Host "Starting HWControl $($release.tag_name) Setup..."
$process = Start-Process -FilePath $temp -Wait -PassThru
if ($process.ExitCode -ne 0) { throw "HWControl Setup failed with exit code $($process.ExitCode)." }
Write-Host 'HWControl installation finished.' -ForegroundColor Green
