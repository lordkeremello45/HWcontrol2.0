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

function Get-ManifestHash([string]$Manifest, [string]$Name, [int]$Length) {
  if (-not (Test-Path -LiteralPath $Manifest -PathType Leaf)) { return $null }
  foreach ($line in Get-Content -LiteralPath $Manifest) {
    if ($line -match "^([0-9A-Fa-f]{$Length})\s+\*?(.+)$" -and [IO.Path]::GetFileName($Matches[2].Trim()) -eq $Name) {
      return $Matches[1].ToLowerInvariant()
    }
  }
  return $null
}

$expected = Get-ManifestHash $shaTemp $artifact.name 64
if (-not $expected) { throw "No SHA-256 entry for $($artifact.name) was found. Installation is blocked." }
$actual = (Get-FileHash $temp -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actual -ne $expected) { throw 'SHA-256 verification failed. The installer was not launched.' }
Write-Host 'SHA-256 verification: OK' -ForegroundColor Green

# SHA-512 is an optional compatibility check. Older releases may not publish it.
$sha512 = $release.assets | Where-Object { $_.name -eq 'SHA512SUMS.txt' -or $_.name -match '-Windows-x64-Setup\.sha512$' -or $_.name -match '-Windows-x64\.sha512$' } | Select-Object -First 1
if ($sha512) {
  $sha512Temp = Join-Path $env:TEMP $sha512.name
  Invoke-WebRequest -Uri $sha512.browser_download_url -Headers $headers -OutFile $sha512Temp
  $expected512 = Get-ManifestHash $sha512Temp $artifact.name 128
  if ($expected512) {
    $actual512 = (Get-FileHash $temp -Algorithm SHA512).Hash.ToLowerInvariant()
    if ($actual512 -ne $expected512) { throw 'SHA-512 verification failed. The installer was not launched.' }
    Write-Host 'SHA-512 verification: OK' -ForegroundColor Green
  } else { Write-Host 'SHA-512 entry unavailable; continuing with SHA-256.' }
} else { Write-Host 'SHA-512 manifest unavailable; continuing with SHA-256.' }

# SHA3-512 is optional and uses OpenSSL when available on Windows.
$sha3 = $release.assets | Where-Object { $_.name -eq 'SHA3-512SUMS.txt' } | Select-Object -First 1
$openssl = Get-Command openssl -ErrorAction SilentlyContinue
if ($sha3 -and $openssl) {
  $sha3Temp = Join-Path $env:TEMP $sha3.name
  Invoke-WebRequest -Uri $sha3.browser_download_url -Headers $headers -OutFile $sha3Temp
  $expected3 = Get-ManifestHash $sha3Temp $artifact.name 128
  if ($expected3) {
    $actual3 = ((& $openssl.Source dgst -sha3-512 -r -- $temp) -split '\s+')[0].ToLowerInvariant()
    if ($actual3 -ne $expected3) { throw 'SHA3-512 verification failed. The installer was not launched.' }
    Write-Host 'SHA3-512 verification: OK' -ForegroundColor Green
  } else { Write-Host 'SHA3-512 entry unavailable; continuing with previous checks.' }
} elseif ($sha3) { Write-Host 'OpenSSL unavailable for SHA3-512; continuing with previous checks.' }
else { Write-Host 'SHA3-512 manifest unavailable; continuing with previous checks.' }

if ($kind -eq 'Setup') {
  Write-Host "Starting HWControl $($release.tag_name) Setup..."
  $process = Start-Process -FilePath $temp -Wait -PassThru
} else {
  Write-Host "Starting HWControl $($release.tag_name) MSI installer..."
  $process = Start-Process msiexec.exe -ArgumentList '/i', "`"$temp`"" -Wait -PassThru
}
if ($process.ExitCode -ne 0) { throw "HWControl installation failed with exit code $($process.ExitCode)." }
Write-Host 'HWControl installation finished.' -ForegroundColor Green
