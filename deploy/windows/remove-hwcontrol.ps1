param(
    [switch]$DryRun,
    [switch]$PurgeSecret,
    [string]$InstallDir = "$env:ProgramFiles\HWControl"
)

$ErrorActionPreference = 'Stop'
$serviceName = 'HWControlBridge'
$paths = @(
    $InstallDir,
    "$env:ProgramData\HWControl",
    "$env:LOCALAPPDATA\HWControl",
    "$env:ProgramData\HWControl\hwcontrol.log"
)

if (-not $DryRun) {
    $answer = Read-Host 'Yalnizca HWControl dosyalari, servisi ve ayarlari kaldirilacak. Devam? (y/N)'
    if ($answer -notin @('y', 'Y')) { Write-Host 'Iptal edildi.'; exit 0 }
}

function Invoke-Safe([scriptblock]$Action, [string]$Description) {
    if ($DryRun) { Write-Host "+ $Description"; return }
    & $Action
}

$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($service) {
    Invoke-Safe { Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue } "Stop-Service $serviceName"
    Invoke-Safe { sc.exe delete $serviceName | Out-Null } "sc.exe delete $serviceName"
}

foreach ($path in $paths) {
    if (Test-Path -LiteralPath $path) {
        Invoke-Safe { Remove-Item -LiteralPath $path -Recurse -Force } "Remove $path"
    }
}

if ($PurgeSecret) {
    Write-Host 'Bridge secreti ProgramData\HWControl\bridge.key dosyasiyla birlikte kaldirildi.'
} else {
    Write-Host 'Bridge secreti kurulum dizinindeki ProgramData\HWControl\bridge.key dosyasiyla birlikte kaldirildi.'
}

Write-Host $(if ($DryRun) { 'Dry-run tamamlandi.' } else { 'HWControl kaldirildi.' })
