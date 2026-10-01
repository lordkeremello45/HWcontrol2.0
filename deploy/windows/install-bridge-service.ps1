param(
    [string]$HwControlKey,
    [string]$InstallDir = "$env:ProgramFiles\HWControl"
)

$ErrorActionPreference = 'Stop'
$bridgePath = Join-Path $InstallDir 'bridge-service.exe'
$guardianPath = Join-Path $InstallDir 'security-guardian.exe'
if (-not (Test-Path $bridgePath)) {
    throw "bridge-service.exe bulunamadi: $bridgePath"
}

if ([string]::IsNullOrWhiteSpace($HwControlKey) -or $HwControlKey -eq 'replace-me') {
    $HwControlKey = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32)).ToLowerInvariant()
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
$existing = Get-Service -Name 'HWControlBridge' -ErrorAction SilentlyContinue
if ($existing) {
    Stop-Service -Name 'HWControlBridge' -ErrorAction SilentlyContinue
    sc.exe delete HWControlBridge | Out-Null
}
sc.exe create HWControlBridge binPath= "`"$bridgePath`"" start= auto obj= "NT AUTHORITY\LocalService" DisplayName= "HWControl Bridge"
sc.exe description HWControlBridge "HWControl local authenticated bridge service"
if (Test-Path $guardianPath) {
    $existingGuardian = Get-Service -Name 'HWControlSecurityGuardian' -ErrorAction SilentlyContinue
    if ($existingGuardian) { Stop-Service -Name 'HWControlSecurityGuardian' -ErrorAction SilentlyContinue; sc.exe delete HWControlSecurityGuardian | Out-Null }
    sc.exe create HWControlSecurityGuardian binPath= "`"$guardianPath`"" start= auto obj= "NT AUTHORITY\LocalService" DisplayName= "HWControl Security Guardian"
    sc.exe description HWControlSecurityGuardian "HWControl secondary security guardian and canary monitor"
    Start-Service -Name 'HWControlSecurityGuardian'
}
Start-Service -Name 'HWControlBridge'
Write-Host 'HWControl Bridge servisi kuruldu ve baslatildi.'
Write-Host 'Bridge anahtarı ProgramData\HWControl\bridge.key üzerinden yönetiliyor; makine ortam değişkenine yazılmıyor.'
