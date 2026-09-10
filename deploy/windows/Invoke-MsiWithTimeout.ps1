[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$MsiPath,

    [Parameter(Mandatory = $true)]
    [ValidateSet('Install', 'Uninstall')]
    [string]$Action,

    [Parameter(Mandatory = $true)]
    [string]$LogPath,

    [int]$TimeoutSeconds = 120
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $MsiPath -PathType Leaf)) {
    throw "MSI not found: $MsiPath"
}

$msiexec = Join-Path $env:SystemRoot 'System32\msiexec.exe'
$arguments = if ($Action -eq 'Install') {
    @('/i', $MsiPath, '/qn', '/norestart', '/L*V', $LogPath)
} else {
    @('/x', $MsiPath, '/qn', '/norestart', '/L*V', $LogPath)
}

$process = Start-Process -FilePath $msiexec -ArgumentList $arguments -PassThru
try {
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        Write-Host "MSI $Action exceeded ${TimeoutSeconds}s; terminating msiexec and collecting diagnostics."
        try { $process.Kill($true) } catch { Write-Warning "Could not terminate msiexec: $($_.Exception.Message)" }
        Start-Sleep -Seconds 2
        if (Test-Path -LiteralPath $LogPath) {
            Write-Host '===== MSI TIMEOUT LOG TAIL ====='
            Get-Content -LiteralPath $LogPath -Tail 250
            Write-Host '===== END MSI TIMEOUT LOG TAIL ====='
        }
        throw "MSI $Action timed out after $TimeoutSeconds seconds"
    }

    if ($process.ExitCode -ne 0) {
        if (Test-Path -LiteralPath $LogPath) {
            Write-Host '===== MSI FAILURE LOG TAIL ====='
            Get-Content -LiteralPath $LogPath -Tail 250
            Write-Host '===== END MSI FAILURE LOG TAIL ====='
        }
        throw "MSI $Action failed with exit code $($process.ExitCode)"
    }
} finally {
    $process.Dispose()
}
