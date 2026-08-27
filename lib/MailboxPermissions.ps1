<#
.SYNOPSIS
    Grants FullAccess (+ optional SendAs) to a mailbox. Logs each action.
#>
function Add-DelegatedMailboxAccess {
    param(
        [Parameter(Mandatory)][string]$Grantee,
        [Parameter(Mandatory)][string]$Mailbox,
        [string]$StartDate,
        [string]$EndDate,
        [switch]$GrantSendAs
    )

    $rights  = @('FullAccess') + $(if ($GrantSendAs) { 'SendAs' })
    $results = @()

    foreach ($right in $rights) {
        try {
            if ($right -eq 'SendAs') {
                Add-ADPermission -Identity $Mailbox -User $Grantee -ExtendedRights 'Send As' -Confirm:$false | Out-Null
            } else {
                Add-MailboxPermission -Identity $Mailbox -User $Grantee -AccessRights $right -Confirm:$false | Out-Null
            }
            Write-AccessLog -Action "Grant $right" -Grantee $Grantee -Mailbox $Mailbox -StartDate $StartDate -EndDate $EndDate -Status "Success" -Details "OK"
            $results += [PSCustomObject]@{ Right = $right; Success = $true }
        } catch {
            Write-AccessLog -Action "Grant $right" -Grantee $Grantee -Mailbox $Mailbox -StartDate $StartDate -EndDate $EndDate -Status "Failed" -Details $_.Exception.Message
            Write-Warning "FAILED Grant $right for $Grantee -> $Mailbox : $($_.Exception.Message)"
            $results += [PSCustomObject]@{ Right = $right; Success = $false }
        }
    }

    return $results
}

<#
.SYNOPSIS
    Removes one or more mailbox permissions. Logs each action.
#>
function Remove-DelegatedMailboxAccess {
    param(
        [Parameter(Mandatory)][string]$Grantee,
        [Parameter(Mandatory)][string]$Mailbox,
        [string]$EndDate,
        [string[]]$Rights = @('FullAccess','SendAs')
    )

    $results = @()

    foreach ($right in $Rights) {
        try {
            if ($right -eq 'SendAs') {
                Remove-ADPermission -Identity $Mailbox -User $Grantee -ExtendedRights 'Send As' -Confirm:$false | Out-Null
            } else {
                Remove-MailboxPermission -Identity $Mailbox -User $Grantee -AccessRights $right -Confirm:$false | Out-Null
            }
            Write-AccessLog -Action "Remove $right" -Grantee $Grantee -Mailbox $Mailbox -EndDate $EndDate -Status "Success" -Details "OK"
            $results += [PSCustomObject]@{ Right = $right; Success = $true }
        } catch {
            Write-AccessLog -Action "Remove $right" -Grantee $Grantee -Mailbox $Mailbox -EndDate $EndDate -Status "Failed" -Details $_.Exception.Message
            Write-Warning "FAILED Remove $right for $Grantee -> $Mailbox : $($_.Exception.Message)"
            $results += [PSCustomObject]@{ Right = $right; Success = $false }
        }
    }

    return $results
}

<#
.SYNOPSIS
    Returns $true only if NONE of the given rights remain on the mailbox.
#>
function Test-DelegatedMailboxAccessRemoved {
    param(
        [Parameter(Mandatory)][string]$Grantee,
        [Parameter(Mandatory)][string]$Mailbox,
        [string[]]$Rights = @('FullAccess','SendAs')
    )

    foreach ($right in $Rights) {
        if ($right -eq 'SendAs') {
            $perm = Get-ADPermission -Identity $Mailbox -User $Grantee -ErrorAction SilentlyContinue |
                Where-Object { $_.ExtendedRights -contains 'Send As' }
        } else {
            $perm = Get-MailboxPermission -Identity $Mailbox -User $Grantee -ErrorAction SilentlyContinue |
                Where-Object { $_.AccessRights -contains $right }
        }
        if ($perm) { return $false }
    }

    return $true
}
