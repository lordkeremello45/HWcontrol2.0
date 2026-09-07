[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Artifact,

    [Parameter(Mandatory = $true)]
    [string]$ChecksumFile,

    [string]$Sha512File = '',
    [string]$Sha3File = ''
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

function Get-ManifestHash([string]$Manifest, [string]$Name, [int]$Length) {
    if (-not (Test-Path -LiteralPath $Manifest -PathType Leaf)) { return $null }
    foreach ($line in Get-Content -LiteralPath $Manifest) {
        if ($line -match "^([0-9A-Fa-f]{$Length})\s+\*?(.+)$") {
            if ([IO.Path]::GetFileName($Matches[2].Trim()) -eq $Name) {
                return $Matches[1].ToLowerInvariant()
            }
        }
    }
    return $null
}

$expected = Get-ManifestHash $ChecksumFile $artifactName 64
if (-not $expected) {
    throw "No SHA-256 entry for $artifactName was found in $ChecksumFile"
}

$actual = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actual -ne $expected) {
    throw "SHA-256 verification FAILED for $artifactName. Expected $expected, got $actual"
}
Write-Host "SHA-256 verification PASSED: $artifactName"
Write-Host "SHA-256: $actual"

# Optional compatibility verification: SHA-512 is checked when a manifest is supplied.
if ($Sha512File -and (Test-Path -LiteralPath $Sha512File -PathType Leaf)) {
    $expected512 = Get-ManifestHash $Sha512File $artifactName 128
    if ($expected512) {
        $actual512 = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA512).Hash.ToLowerInvariant()
        if ($actual512 -ne $expected512) { throw "SHA-512 verification FAILED for $artifactName" }
        Write-Host "SHA-512 verification PASSED: $artifactName"
    } else { Write-Host "SHA-512 manifest has no entry for $artifactName; continuing with SHA-256." }
} else {
    Write-Host 'SHA-512 manifest not available; continuing with SHA-256.'
}

# Optional SHA3-512 verification. PowerShell/.NET does not expose SHA3 uniformly,
# so use OpenSSL when installed; otherwise retain SHA-256/SHA-512 compatibility.
if ($Sha3File -and (Test-Path -LiteralPath $Sha3File -PathType Leaf)) {
    $expected3 = Get-ManifestHash $Sha3File $artifactName 128
    $openssl = Get-Command openssl -ErrorAction SilentlyContinue
    if ($expected3 -and $openssl) {
        $actual3 = ((& $openssl.Source dgst -sha3-512 -r -- $artifactPath) -split '\s+')[0].ToLowerInvariant()
        if ($actual3 -ne $expected3) { throw "SHA3-512 verification FAILED for $artifactName" }
        Write-Host "SHA3-512 verification PASSED: $artifactName"
    } elseif (-not $expected3) {
        Write-Host 'SHA3-512 manifest has no entry; continuing with previous checks.'
    } else {
        Write-Host 'OpenSSL is not available for SHA3-512; continuing with previous checks.'
    }
} else {
    Write-Host 'SHA3-512 manifest not available; continuing with previous checks.'
}
