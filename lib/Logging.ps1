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

<#
.SYNOPSIS
    Writes an error record to a CSV error log.
.DESCRIPTION
    Captures the originating function, source script, line number, and error message.
    Uses $script:ErrorLogPath (set by the main script).
#>
function Write-ErrorLog {
    param([System.Management.Automation.ErrorRecord]$ErrorRecord)

    $logPath = $script:ErrorLogPath
    if (-not $logPath) { $logPath = "$env:TEMP\ErrorLog.csv" }

    $function = ''
    $stack = Get-PSCallStack
    if ($stack.Count -gt 1) { $function = $stack[1].FunctionName }

    $script = $ErrorRecord.InvocationInfo.ScriptName
    $line   = $ErrorRecord.InvocationInfo.ScriptLineNumber
    $msg    = $ErrorRecord.Exception.Message -replace ',', ';' -replace '[\r\n]+', ' '

    $entry = "{0},{1},{2},{3},{4}" -f `
        (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $function, $script, $line, $msg

    $entry | Add-Content -Path $logPath -Encoding UTF8
}
