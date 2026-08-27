<#
.SYNOPSIS
    Loads the JSON tracking array (empty array if file missing).
#>
function Load-TrackingFile {
    param([string]$Path)
    if (Test-Path $Path) {
        $content = Get-Content $Path -Raw
        if ([string]::IsNullOrWhiteSpace($content)) { return @() }
        $data = $content | ConvertFrom-Json
        if ($null -eq $data) { return @() }
        return @($data)
    }
    return @()
}

<#
.SYNOPSIS
    Saves the JSON tracking array to disk.
#>
function Save-TrackingFile {
    param([object[]]$Entries, [string]$Path)
    $json = if ($Entries.Count -gt 0) { $Entries | ConvertTo-Json -Depth 3 } else { '[]' }
    Set-Content -Path $Path -Value $json -Encoding UTF8
}

<#
.SYNOPSIS
    Finds an existing tracking entry for a grant.
#>
function Find-TrackingEntry {
    param([object[]]$Entries, [string]$Grantee, [string]$Mailbox, [string]$EndDate)
    return $Entries | Where-Object {
        $_ -and $_.Grantee -eq $Grantee -and $_.Mailbox -eq $Mailbox -and $_.EndDate -eq $EndDate
    }
}

<#
.SYNOPSIS
    Creates a new tracking entry object.
#>
function New-TrackingEntry {
    param([string]$Grantee, [string]$Mailbox, [string]$StartDate, [string]$EndDate, [string]$Rights)
    [PSCustomObject]@{
        Grantee   = $Grantee
        Mailbox   = $Mailbox
        StartDate = $StartDate
        EndDate   = $EndDate
        Rights    = $Rights
        GrantedOn = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    }
}
