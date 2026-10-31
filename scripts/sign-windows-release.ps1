param(
    [Parameter(Mandatory = $true)]
    [string[]]$Path
)

$ErrorActionPreference = 'Stop'
$certificate = $env:WINDOWS_CERTIFICATE_B64
$password = $env:WINDOWS_CERTIFICATE_PASSWORD
$hasCertificate = -not [string]::IsNullOrWhiteSpace($certificate)
$hasPassword = -not [string]::IsNullOrWhiteSpace($password)

if ($hasCertificate -ne $hasPassword) {
    throw 'Both Windows Authenticode signing secrets must be configured together.'
}
if (-not $hasCertificate) {
    Write-Warning 'Windows Authenticode secrets are not configured; artifacts remain unsigned.'
    exit 0
}

$sdkRoot = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'
$signtool = Get-ChildItem -Path $sdkRoot -Filter signtool.exe -Recurse -File |
    Where-Object { $_.FullName -match '\\x64\\signtool\.exe$' } |
    Sort-Object -Property FullName -Descending |
    Select-Object -First 1 -ExpandProperty FullName
if (-not $signtool) {
    throw 'Windows SDK signtool.exe was not found.'
}

$pfxPath = Join-Path $env:RUNNER_TEMP 'hwcontrol-release-signing.pfx'
[IO.File]::WriteAllBytes($pfxPath, [Convert]::FromBase64String($certificate))
try {
    $files = @()
    foreach ($entry in $Path) {
        if (-not (Test-Path -LiteralPath $entry)) {
            throw "Signing input does not exist: $entry"
        }
        $item = Get-Item -LiteralPath $entry
        if ($item.PSIsContainer) {
            $files += Get-ChildItem -LiteralPath $entry -Recurse -File |
                Where-Object { $_.Extension -in @('.exe', '.dll', '.msi') }
        } else {
            $files += $item
        }
    }
    if ($files.Count -eq 0) {
        throw 'No Windows executable, DLL or installer files were selected for signing.'
    }

    foreach ($file in $files) {
        & $signtool sign /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 /f $pfxPath /p $password $file.FullName
        if ($LASTEXITCODE -ne 0) {
            throw "Authenticode signing failed: $($file.FullName)"
        }
        & $signtool verify /pa /all $file.FullName
        if ($LASTEXITCODE -ne 0) {
            throw "Authenticode verification failed: $($file.FullName)"
        }
    }
} finally {
    Remove-Item -LiteralPath $pfxPath -Force -ErrorAction SilentlyContinue
}
