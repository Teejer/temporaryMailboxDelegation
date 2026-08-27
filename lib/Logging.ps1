<#
.SYNOPSIS
    Writes a single CSV action-log line.
.DESCRIPTION
    Uses $script:AccessLogPath (set by the main script). Fields:
    Timestamp, Action, Grantee, Mailbox, StartDate, EndDate, Status, Details
#>
function Write-AccessLog {
    param(
        [string]$Action,
        [string]$Grantee   = '',
        [string]$Mailbox   = '',
        [string]$StartDate = '',
        [string]$EndDate   = '',
        [string]$Status,
        [string]$Details
    )

    $logPath = $script:AccessLogPath
    if (-not $logPath) { $logPath = "$env:TEMP\AccessLog.csv" }

    $clean = $Details -replace ',', ';' -replace '[\r\n]+', ' '
    $line  = "{0},{1},{2},{3},{4},{5},{6},{7}" -f `
        (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Action, $Grantee, $Mailbox, $StartDate, $EndDate, $Status, $clean

    $line | Add-Content -Path $logPath -Encoding UTF8
}
