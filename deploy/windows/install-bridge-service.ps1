param(
    [string]$HwControlKey,
    [string]$InstallDir = "$env:ProgramFiles\HWControl"
)

$ErrorActionPreference = 'Stop'
$securityRoot = Join-Path $env:ProgramData 'HWControl\security'
$canaryDir = Join-Path $securityRoot 'canary'
$stateDir = Join-Path $securityRoot 'state'
$canaryPath = Join-Path $canaryDir 'bridger.key'
New-Item -ItemType Directory -Force -Path $canaryDir, $stateDir | Out-Null
if (-not (Test-Path $canaryPath)) {
    Set-Content -NoNewline -Path $canaryPath -Value '0526be8dc7adb18bc4e82119046c9a9fc8625571311060208a8d0744d71ff671'
}
icacls $canaryDir /inheritance:r | Out-Null
icacls $canaryDir /grant:r 'SYSTEM:(OI)(CI)(F)' 'Administrators:(OI)(CI)(F)' 'NT AUTHORITY\LOCAL SERVICE:(OI)(CI)(RX)' | Out-Null
icacls $canaryPath /inheritance:r | Out-Null
icacls $canaryPath /grant:r 'SYSTEM:(F)' 'Administrators:(F)' 'NT AUTHORITY\LOCAL SERVICE:(R)' | Out-Null
icacls $stateDir /inheritance:r | Out-Null
icacls $stateDir /grant:r 'SYSTEM:(OI)(CI)(F)' 'Administrators:(OI)(CI)(F)' 'NT AUTHORITY\LOCAL SERVICE:(OI)(CI)(M)' | Out-Null

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
sc.exe failure HWControlBridge reset= 86400 actions= restart/5000/restart/30000/none/0 | Out-Null
if (Test-Path $guardianPath) {
    $existingGuardian = Get-Service -Name 'HWControlSecurityGuardian' -ErrorAction SilentlyContinue
    if ($existingGuardian) { Stop-Service -Name 'HWControlSecurityGuardian' -ErrorAction SilentlyContinue; sc.exe delete HWControlSecurityGuardian | Out-Null }
    sc.exe create HWControlSecurityGuardian binPath= "`"$guardianPath`"" start= auto obj= "NT AUTHORITY\LocalService" DisplayName= "HWControl Security Guardian"
    sc.exe description HWControlSecurityGuardian "HWControl secondary security guardian and canary monitor"
sc.exe failure HWControlSecurityGuardian reset= 86400 actions= restart/5000/restart/30000/none/0 | Out-Null
    Start-Service -Name 'HWControlSecurityGuardian'
}
Start-Service -Name 'HWControlBridge'
Write-Host 'HWControl Bridge servisi kuruldu ve baslatildi.'
Write-Host 'Bridge anahtarı ProgramData\HWControl\bridge.key üzerinden yönetiliyor; makine ortam değişkenine yazılmıyor.'
