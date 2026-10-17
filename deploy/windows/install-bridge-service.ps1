param(
    [string]$HwControlKey,
    [string]$InstallDir = "$env:ProgramFiles\HWControl"
)

$ErrorActionPreference = 'Stop'
$bridgeKeyDir = Join-Path $env:ProgramData 'HWControl'
$bridgeKeyPath = Join-Path $bridgeKeyDir 'bridge.key'
$securityRoot = Join-Path $bridgeKeyDir 'security'
$canaryDir = Join-Path $securityRoot 'canary'
$stateDir = Join-Path $securityRoot 'state'
$canaryPath = Join-Path $canaryDir 'bridger.key'
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

New-Item -ItemType Directory -Force -Path $bridgeKeyDir, $canaryDir, $stateDir | Out-Null

# Restrict the shared command key to the elevated installer user and LocalService.
# Do not inherit the broad default ProgramData ACL.
icacls $bridgeKeyDir /inheritance:r /grant:r 'SYSTEM:(OI)(CI)(F)' 'Administrators:(OI)(CI)(F)' 'NT AUTHORITY\LOCAL SERVICE:(OI)(CI)(M)' "$($currentUser):(OI)(CI)(RX)" | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Failed to secure HWControl bridge-key directory ACL.' }

if ([string]::IsNullOrWhiteSpace($HwControlKey) -or $HwControlKey -eq 'replace-me') {
    $HwControlKey = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32)).ToLowerInvariant()
}
if ($HwControlKey -notmatch '^[0-9a-fA-F]{64}$') {
    throw 'HwControlKey must be exactly 64 hexadecimal characters.'
}

if (Test-Path -LiteralPath $bridgeKeyPath) {
    $keyAttributes = [IO.File]::GetAttributes($bridgeKeyPath)
    if (($keyAttributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
        ($keyAttributes -band [IO.FileAttributes]::Directory) -ne 0) {
        throw 'Existing bridge.key must be a regular non-reparse-point file.'
    }
    $existingKey = ([IO.File]::ReadAllText($bridgeKeyPath)).Trim()
    if ($existingKey -notmatch '^[0-9a-fA-F]{64}$') {
        throw 'Existing bridge.key is invalid; refusing to overwrite it automatically.'
    }
} else {
    [IO.File]::WriteAllText($bridgeKeyPath, "$HwControlKey$([Environment]::NewLine)", [Text.Encoding]::ASCII)
}
icacls $bridgeKeyPath /inheritance:r /grant:r 'SYSTEM:(F)' 'Administrators:(F)' 'NT AUTHORITY\LOCAL SERVICE:(R)' "$($currentUser):(R)" | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Failed to secure HWControl bridge-key file ACL.' }

if (-not (Test-Path -LiteralPath $canaryPath -PathType Leaf)) {
    Set-Content -NoNewline -Path $canaryPath -Value '0526be8dc7adb18bc4e82119046c9a9fc8625571311060208a8d0744d71ff671'
}
icacls $canaryDir /inheritance:r | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Failed to protect security canary directory inheritance.' }
icacls $canaryDir /grant:r 'SYSTEM:(OI)(CI)(F)' 'Administrators:(OI)(CI)(F)' 'NT AUTHORITY\LOCAL SERVICE:(OI)(CI)(RX)' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Failed to set security canary directory ACL.' }
icacls $canaryPath /inheritance:r | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Failed to protect security canary file inheritance.' }
icacls $canaryPath /grant:r 'SYSTEM:(F)' 'Administrators:(F)' 'NT AUTHORITY\LOCAL SERVICE:(R)' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Failed to set security canary file ACL.' }
icacls $stateDir /inheritance:r | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Failed to protect security state directory inheritance.' }
icacls $stateDir /grant:r 'SYSTEM:(OI)(CI)(F)' 'Administrators:(OI)(CI)(F)' 'NT AUTHORITY\LOCAL SERVICE:(OI)(CI)(M)' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Failed to set security state directory ACL.' }

$bridgePath = Join-Path $InstallDir 'bridge-service.exe'
$guardianPath = Join-Path $InstallDir 'security-guardian.exe'
if (-not (Test-Path -LiteralPath $bridgePath -PathType Leaf)) {
    throw "bridge-service.exe bulunamadi: $bridgePath"
}
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

$quotedBridgePath = 'binPath= "' + $bridgePath + '"'
$existing = Get-Service -Name 'HWControlBridge' -ErrorAction SilentlyContinue
if ($existing) {
    Stop-Service -Name 'HWControlBridge' -ErrorAction SilentlyContinue
    sc.exe delete HWControlBridge | Out-Null
}
sc.exe create HWControlBridge $quotedBridgePath start= auto obj= 'NT AUTHORITY\LocalService' DisplayName= 'HWControl Bridge' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Failed to create HWControl Bridge service.' }
sc.exe description HWControlBridge 'HWControl local authenticated bridge service' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Failed to set HWControl Bridge service description.' }
sc.exe failure HWControlBridge reset= 86400 actions= restart/5000/restart/30000/none/0 | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Failed to configure HWControl Bridge service recovery.' }

if (Test-Path -LiteralPath $guardianPath -PathType Leaf) {
    $existingGuardian = Get-Service -Name 'HWControlSecurityGuardian' -ErrorAction SilentlyContinue
    if ($existingGuardian) {
        Stop-Service -Name 'HWControlSecurityGuardian' -ErrorAction SilentlyContinue
        sc.exe delete HWControlSecurityGuardian | Out-Null
    }
    $quotedGuardianPath = 'binPath= "' + $guardianPath + '"'
    sc.exe create HWControlSecurityGuardian $quotedGuardianPath start= auto obj= 'NT AUTHORITY\LocalService' DisplayName= 'HWControl Security Guardian' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Failed to create HWControl Security Guardian service.' }
    sc.exe description HWControlSecurityGuardian 'HWControl secondary security guardian and canary monitor' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Failed to set Security Guardian service description.' }
    sc.exe failure HWControlSecurityGuardian reset= 86400 actions= restart/5000/restart/30000/none/0 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Failed to configure Security Guardian service recovery.' }
    Start-Service -Name 'HWControlSecurityGuardian'
}
Start-Service -Name 'HWControlBridge'
Write-Host 'HWControl Bridge servisi kuruldu ve baslatildi.'
Write-Host 'Bridge anahtarı ProgramData\HWControl\bridge.key üzerinden yönetiliyor; anahtar içeriği günlüğe yazılmıyor.'
