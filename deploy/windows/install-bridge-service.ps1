param(
    [Parameter(Mandatory = $true)]
    [string]$HwControlKey,
    [string]$InstallDir = "$env:ProgramFiles\HWControl"
)

$ErrorActionPreference = 'Stop'
$bridgePath = Join-Path $InstallDir 'bridge-service.exe'
if (-not (Test-Path $bridgePath)) {
    throw "bridge-service.exe bulunamadi: $bridgePath"
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
[Environment]::SetEnvironmentVariable('HWCONTROL_KEY', $HwControlKey, 'Machine')
$existing = Get-Service -Name 'HWControlBridge' -ErrorAction SilentlyContinue
if ($existing) {
    Stop-Service -Name 'HWControlBridge' -ErrorAction SilentlyContinue
    sc.exe delete HWControlBridge | Out-Null
}
sc.exe create HWControlBridge binPath= "`"$bridgePath`"" start= auto DisplayName= "HWControl Bridge"
sc.exe description HWControlBridge "HWControl local authenticated bridge service"
Start-Service -Name 'HWControlBridge'
Write-Host 'HWControl Bridge servisi kuruldu ve baslatildi.'
