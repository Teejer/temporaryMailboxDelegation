<#
.SYNOPSIS
    Removes expired delegated mailbox access (FullAccess + SendAs).
.DESCRIPTION
    Reads the tracking JSON, revokes grants whose EndDate has passed,
    logs each action, and updates the tracking file.

    Run this on a schedule (Task Scheduler) to clean up expired grants.
#>
[CmdletBinding()]
param(
    [string]$LibPath,
    [string]$ConfigPath,
    [string]$TrackingFilePath,
    [string]$LogPath,

    # App-based auth with a certificate (for non-interactive / scheduled runs)
    # If left blank, values are read from the JSON file at $ConfigPath.
    [string]$AppId,
    [string]$CertificateThumbprint,
    [string]$Organization
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# --- Resolve script root + default paths ---
# $PSScriptRoot is empty when dot-sourced, so fall back to the invoking file's path.
$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $LibPath)          { $LibPath = Join-Path $ScriptRoot 'lib' }
if (-not $ConfigPath)       { $ConfigPath = Join-Path $ScriptRoot 'AppConfig.json' }
if (-not $TrackingFilePath) { $TrackingFilePath = Join-Path $ScriptRoot 'MailboxAccessTracking.json' }
if (-not $LogPath)          { $LogPath = Join-Path $ScriptRoot 'AccessLog.csv' }

# --- Load library + set shared log path ---
. (Join-Path $LibPath 'Load-Library.ps1')
$script:AccessLogPath = $LogPath

if (-not (Test-Path $TrackingFilePath)) {
    Write-Warning "No tracking file found at $TrackingFilePath. Nothing to do."
    return
}
$auth = Resolve-AppAuthParams -ConfigPath $ConfigPath -AppId $AppId -CertificateThumbprint $CertificateThumbprint -Organization $Organization
if (-not (Connect-ToExchangeOnline -AppId $auth.AppId -CertificateThumbprint $auth.CertificateThumbprint -Organization $auth.Organization)) { return }

$today = (Get-Date).Date
$tracking     = Load-TrackingFile -Path $TrackingFilePath
$stillActive  = @()
$removedCount = 0

foreach ($entry in $tracking) {
    $endDate = [datetime]::Parse($entry.EndDate).Date

    if ($today -le $endDate) {
        $stillActive += $entry   # still valid
        continue
    }

    Write-Host "Removing expired access: $($entry.Grantee) -> $($entry.Mailbox) (ended $endDate)" -ForegroundColor Cyan

    $rights = @('FullAccess')
    if ($entry.Rights -match 'SendAs') { $rights += 'SendAs' }

    $results = Remove-DelegatedMailboxAccess -Grantee $entry.Grantee -Mailbox $entry.Mailbox -EndDate $entry.EndDate -Rights $rights

    if (Test-DelegatedMailboxAccessRemoved -Grantee $entry.Grantee -Mailbox $entry.Mailbox -Rights $rights) {
        $removedCount++
        Write-AccessLog -Action "Remove Complete" -Grantee $entry.Grantee -Mailbox $entry.Mailbox -EndDate $entry.EndDate -Status "Success" -Details "All rights revoked"
        # entry NOT added back -> dropped from tracking
    } else {
        $stillActive += $entry
        Write-AccessLog -Action "Remove Complete" -Grantee $entry.Grantee -Mailbox $entry.Mailbox -EndDate $entry.EndDate -Status "Failed" -Details "Some rights still present - will retry"
    }
}

Save-TrackingFile -Entries $stillActive -Path $TrackingFilePath
Disconnect-FromExchangeOnline

Write-Host "`nDone. $removedCount expired grant(s) removed." -ForegroundColor Green
