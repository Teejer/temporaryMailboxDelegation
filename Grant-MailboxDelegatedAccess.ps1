<#
.SYNOPSIS
    Grants full delegated access (FullAccess + SendAs) from a CSV.
.DESCRIPTION
    CSV columns: Grantee, Mailbox, StartDate, EndDate

    Example rows:
    jsmith@contoso.com, target@contoso.com, 2025-01-01, 2025-12-31
    bob@contoso.com, finance@contoso.com, 2025-02-01, 2025-02-28

    Grants are only applied once StartDate has arrived.
    Pass -GrantSendAs:$false to grant FullAccess only.
#>
[CmdletBinding()]
param(
    [string]$CsvPath,

    [string]$LibPath,
    [string]$ConfigPath,
    [string]$TrackingFilePath,
    [string]$LogPath,
    [switch]$GrantSendAs      = $true,

    # App-based auth with a certificate (for non-interactive / scheduled runs)
    # If left blank, values are read from the JSON file at $ConfigPath.
    [string]$AppId,
    [string]$CertificateThumbprint,
    [string]$Organization
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# --- Print source line numbers on any uncaught error ---
trap {
    Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  at $($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    break
}

# --- Resolve script root + default paths ---
# $PSScriptRoot is empty when dot-sourced, so fall back to the invoking file's path.
$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $CsvPath)          { $CsvPath = Join-Path $ScriptRoot 'Access.csv' }
if (-not $LibPath)          { $LibPath = Join-Path $ScriptRoot 'lib' }
if (-not $ConfigPath)       { $ConfigPath = Join-Path $ScriptRoot 'AppConfig.json' }
if (-not $TrackingFilePath) { $TrackingFilePath = Join-Path $ScriptRoot 'MailboxAccessTracking.json' }
if (-not $LogPath)          { $LogPath = Join-Path $ScriptRoot 'AccessLog.csv' }
if (-not (Test-Path $CsvPath -PathType Leaf)) {
    Write-Error "CSV file not found at $CsvPath"
    return
}

# --- Load library + set shared log path ---
. (Join-Path $LibPath 'Load-Library.ps1')
$script:AccessLogPath = $LogPath
$script:ErrorLogPath  = Join-Path $ScriptRoot 'ErrorLog.csv'

# --- Module check + connect ---
if (-not (Get-Command Connect-ExchangeOnline -ErrorAction SilentlyContinue)) {
    Write-Error "ExchangeOnlineManagement module not installed. Run: Install-Module ExchangeOnlineManagement -Scope CurrentUser"
    return
}
$auth = Resolve-AppAuthParams -ConfigPath $ConfigPath -AppId $AppId -CertificateThumbprint $CertificateThumbprint -Organization $Organization
if (-not (Connect-ToExchangeOnline -AppId $auth.AppId -CertificateThumbprint $auth.CertificateThumbprint -Organization $auth.Organization)) { return }

$today = (Get-Date).Date
$grantedCount = 0
$tracking = Load-TrackingFile -Path $TrackingFilePath

foreach ($row in (Import-Csv -Path $CsvPath)) {
    $grantee   = $row.Grantee.Trim()
    $mailbox   = $row.Mailbox.Trim()
    $startDate = [datetime]::Parse($row.StartDate).Date
    $endDate   = [datetime]::Parse($row.EndDate).Date
    $startStr  = $startDate.ToString('yyyy-MM-dd')
    $endStr    = $endDate.ToString('yyyy-MM-dd')

    # --- Validation ---
    if (-not $grantee -or -not $mailbox) {
        Write-AccessLog -Action "Validate" -Status "Failed" -Details "Missing Grantee or Mailbox"
        Write-Warning "Skipping row with missing Grantee/Mailbox."
        continue
    }
    if ($endDate -lt $startDate) {
        Write-AccessLog -Action "Validate" -Grantee $grantee -Mailbox $mailbox -StartDate $startStr -EndDate $endStr -Status "Skipped" -Details "EndDate before StartDate"
        Write-Warning "Skipping $grantee -> $mailbox : EndDate before StartDate."
        continue
    }

    # --- Start date not reached ---
    if ($today -lt $startDate) {
        Write-AccessLog -Action "Grant" -Grantee $grantee -Mailbox $mailbox -StartDate $startStr -EndDate $endStr -Status "Skipped" -Details "Not yet active (starts $startStr)"
        Write-Host "Skipped (not yet active): $grantee -> $mailbox (starts $startStr)" -ForegroundColor Yellow
        continue
    }

    # --- Already granted ---
    if (Find-TrackingEntry -Entries $tracking -Grantee $grantee -Mailbox $mailbox -EndDate $endStr) {
        Write-AccessLog -Action "Grant" -Grantee $grantee -Mailbox $mailbox -StartDate $startStr -EndDate $endStr -Status "Skipped" -Details "Already granted"
        Write-Host "Already granted, skipping: $grantee -> $mailbox" -ForegroundColor Yellow
        continue
    }

    # --- Grant permissions ---
    Write-Host "Granting access: $grantee -> $mailbox" -ForegroundColor Cyan
    $results = Add-DelegatedMailboxAccess -Grantee $grantee -Mailbox $mailbox -StartDate $startStr -EndDate $endStr -GrantSendAs:$GrantSendAs

    $rightsGranted = ($results | Where-Object { $_.Success }).Right -join ','
    if ($rightsGranted) {
        $tracking += New-TrackingEntry -Grantee $grantee -Mailbox $mailbox -StartDate $startStr -EndDate $endStr -Rights $rightsGranted
        $grantedCount++
    }
}

Save-TrackingFile -Entries $tracking -Path $TrackingFilePath
Disconnect-FromExchangeOnline

Write-Host "`nDone. $grantedCount grant(s) added." -ForegroundColor Green
