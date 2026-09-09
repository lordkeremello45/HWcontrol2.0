param(
    [string]$HwControlKey,
    [string]$InstallDir = "$env:ProgramFiles\HWControl"
)

$ErrorActionPreference = 'Stop'
$bridgePath = Join-Path $InstallDir 'bridge-service.exe'
$keyDir = Join-Path $env:ProgramData 'HWControl'
$keyPath = Join-Path $keyDir 'bridge.key'

if (-not (Test-Path -LiteralPath $bridgePath -PathType Leaf)) {
    throw "bridge-service.exe bulunamadi: $bridgePath"
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
New-Item -ItemType Directory -Force -Path $keyDir | Out-Null

if ([string]::IsNullOrWhiteSpace($HwControlKey) -or $HwControlKey -eq 'replace-me') {
    if (Test-Path -LiteralPath $keyPath -PathType Leaf) {
        $HwControlKey = (Get-Content -LiteralPath $keyPath -Raw).Trim()
    }
}

if ([string]::IsNullOrWhiteSpace($HwControlKey) -or $HwControlKey -eq 'replace-me') {
    $HwControlKey = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32)).ToLowerInvariant()
}

[IO.File]::WriteAllText($keyPath, "$HwControlKey`r`n", [Text.UTF8Encoding]::new($false))

& icacls.exe $keyDir /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)(F)' '*S-1-5-32-544:(OI)(CI)(F)' /c | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Failed to secure bridge key directory: $keyDir" }
& icacls.exe $keyPath /inheritance:r /grant:r '*S-1-5-18:(F)' '*S-1-5-32-544:(F)' /c | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Failed to secure bridge key file: $keyPath" }

$existing = Get-Service -Name 'HWControlBridge' -ErrorAction SilentlyContinue
if ($existing) {
    Stop-Service -Name 'HWControlBridge' -ErrorAction SilentlyContinue
    sc.exe delete HWControlBridge | Out-Null
}

sc.exe create HWControlBridge binPath= "`"$bridgePath`"" start= auto DisplayName= "HWControl Bridge"
if ($LASTEXITCODE -ne 0) { throw 'Failed to create HWControlBridge service.' }
sc.exe description HWControlBridge "HWControl local authenticated bridge service"
if ($LASTEXITCODE -ne 0) { throw 'Failed to describe HWControlBridge service.' }
Start-Service -Name 'HWControlBridge'
Write-Host 'HWControl Bridge servisi kuruldu ve baslatildi.'
Write-Host "Bridge secret protected at $keyPath"
