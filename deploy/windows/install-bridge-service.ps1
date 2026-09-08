param(
    [string]$HwControlKey,
    [string]$InstallDir = "$env:ProgramFiles\HWControl"
)

$ErrorActionPreference = 'Stop'
$bridgePath = Join-Path $InstallDir 'bridge-service.exe'
$keyDir = Join-Path $env:ProgramData 'HWControl'
$keyFile = Join-Path $keyDir 'bridge.key'
if (-not (Test-Path $bridgePath)) {
    throw "bridge-service.exe bulunamadi: $bridgePath"
}

if ([string]::IsNullOrWhiteSpace($HwControlKey) -or $HwControlKey -eq 'replace-me') {
    if (Test-Path $keyFile) {
        $HwControlKey = (Get-Content -Raw -Path $keyFile).Trim()
    }
}
if ([string]::IsNullOrWhiteSpace($HwControlKey) -or $HwControlKey -eq 'replace-me') {
    $HwControlKey = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32)).ToLowerInvariant()
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
New-Item -ItemType Directory -Force -Path $keyDir | Out-Null
Set-Content -Path $keyFile -Value $HwControlKey -NoNewline -Encoding ascii

& icacls.exe $keyDir /inheritance:r /grant:r 'SYSTEM:(OI)(CI)(F)' 'Administrators:(OI)(CI)(F)' | Out-Null
& icacls.exe $keyFile /inheritance:r /grant:r 'SYSTEM:(F)' 'Administrators:(F)' | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw 'bridge.key ACL ayarlanamadi.'
}

$existing = Get-Service -Name 'HWControlBridge' -ErrorAction SilentlyContinue
if ($existing) {
    Stop-Service -Name 'HWControlBridge' -ErrorAction SilentlyContinue
    sc.exe delete HWControlBridge | Out-Null
}
sc.exe create HWControlBridge binPath= "`"$bridgePath`"" start= auto DisplayName= "HWControl Bridge"
sc.exe description HWControlBridge "HWControl local authenticated bridge service"
sc.exe config HWControlBridge obj= LocalSystem | Out-Null
Start-Service -Name 'HWControlBridge'
Write-Host 'HWControl Bridge servisi kuruldu ve baslatildi.'
Write-Host "Bridge secret protected file olarak provision edildi: $keyFile"
