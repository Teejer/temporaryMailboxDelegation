<#
.SYNOPSIS
    Loads app-based auth settings from a JSON config file.
.DESCRIPTION
    Reads AppId, CertificateThumbprint, and Organization from the
    given JSON file and returns a single PSCustomObject. Missing keys become ''.
    Returns $null if the file doesn't exist.
#>
function Load-AppAuthConfig {
    param([string]$Path)

    if (-not (Test-Path $Path)) { return $null }

    $cfg = Get-Content $Path -Raw | ConvertFrom-Json

    [PSCustomObject]@{
        AppId                = $cfg.AppId
        CertificateThumbprint = $cfg.CertificateThumbprint
        Organization         = $cfg.Organization
    }
}

<#
.SYNOPSIS
    Merges app auth params from config JSON into any blank script parameters.
.DESCRIPTION
    Any blank (empty/null) values in $AppId/$CertificateThumbprint/$Organization
    are filled from the config file at $ConfigPath. Command-line
    parameters always win over config values.
#>
function Resolve-AppAuthParams {
    param(
        [string]$ConfigPath,
        [string]$AppId,
        [string]$CertificateThumbprint,
        [string]$Organization
    )

    $cfg = Load-AppAuthConfig -Path $ConfigPath
    if (-not $cfg) { return }

    if (-not $AppId)                { $AppId = $cfg.AppId }
    if (-not $CertificateThumbprint) { $CertificateThumbprint = $cfg.CertificateThumbprint }
    if (-not $Organization)         { $Organization = $cfg.Organization }

    [PSCustomObject]@{
        AppId                = $AppId
        CertificateThumbprint = $CertificateThumbprint
        Organization         = $Organization
    }
}
