[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Artifact,

    [Parameter(Mandatory = $true)]
    [string]$ChecksumFile
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Artifact -PathType Leaf)) {
    throw "Artifact not found: $Artifact"
}
if (-not (Test-Path -LiteralPath $ChecksumFile -PathType Leaf)) {
    throw "Checksum manifest not found: $ChecksumFile"
}

$artifactPath = (Resolve-Path -LiteralPath $Artifact).Path
$artifactName = [IO.Path]::GetFileName($artifactPath)
$expected = $null

foreach ($line in Get-Content -LiteralPath $ChecksumFile) {
    if ($line -match '^([0-9A-Fa-f]{64})\s+\*?(.+)$') {
        if ([IO.Path]::GetFileName($Matches[2].Trim()) -eq $artifactName) {
            $expected = $Matches[1].ToLowerInvariant()
            break
        }
    }
}

if (-not $expected) {
    throw "No SHA-256 entry for $artifactName was found in $ChecksumFile"
}

$actual = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actual -ne $expected) {
    throw "SHA-256 verification FAILED for $artifactName. Expected $expected, got $actual"
}

Write-Host "SHA-256 verification PASSED: $artifactName"
Write-Host "SHA-256: $actual"
