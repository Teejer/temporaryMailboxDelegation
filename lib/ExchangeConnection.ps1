<#
.SYNOPSIS
    Connects to Exchange Online using app-based auth with a certificate and logs the result.
.DESCRIPTION
    Uses Connect-ExchangeOnline with an app registration + certificate thumbprint so the
    scripts can run non-interactively (Task Scheduler / service accounts).
    If no app auth params are supplied, falls back to interactive login.
.PARAMETER AppId
    Application (client) ID of the Entra (Azure AD) app registration.
.PARAMETER CertificateThumbprint
    Thumbprint of the installed certificate associated with the app.
.PARAMETER Organization
    Tenant domain (e.g. contoso.onmicrosoft.com) or tenant ID.
#>
function Connect-ToExchangeOnline {
    [CmdletBinding()]
    param(
        [string]$AppId,
        [string]$CertificateThumbprint,
        [string]$Organization
    )

    try {
        if ($AppId -and $CertificateThumbprint) {
            Connect-ExchangeOnline -AppId $AppId -CertificateThumbprint $CertificateThumbprint `
                -Organization $Organization -ErrorAction Stop | Out-Null
            Write-AccessLog -Action "Connect" -Status "Success" -Details "Connected (app auth, cert)"
        } else {
            Connect-ExchangeOnline -ErrorAction Stop | Out-Null
            Write-AccessLog -Action "Connect" -Status "Success" -Details "Connected (interactive)"
        }
        return $true
    } catch {
        Write-ErrorLog $_ | Out-Null
        Write-AccessLog -Action "Connect" -Status "Failed" -Details $_.Exception.Message
        Write-Error "Connection failed: $($_.Exception.Message)"
        return $false
    }
}

<#
.SYNOPSIS
    Disconnects from Exchange Online and logs the result.
#>
function Disconnect-FromExchangeOnline {
    [CmdletBinding()]
    param()

    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    Write-AccessLog -Action "Disconnect" -Status "Success" -Details "Disconnected"
}
