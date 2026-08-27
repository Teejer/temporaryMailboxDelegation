# Mailbox Delegated Access (Exchange Online)

Grant full delegated access (FullAccess + SendAs) to mailboxes from a CSV,
with start/end dates, detailed action logging, and scheduled cleanup of expired grants.

## Folder Structure

```
MailboxDelegation/
├── Grant-MailboxDelegatedAccess.ps1   # Main: grant access from CSV
├── Remove-ExpiredMailboxAccess.ps1    # Main: remove expired grants (schedule this)
├── MailboxAccessTracking.json         # Generated: tracks active grants for cleanup
├── AccessLog.csv                      # Generated: detailed action log
├── sample-Access.csv                  # Example CSV format
└── lib/
    ├── Load-Library.ps1               # Dot-sources all lib functions
    ├── Logging.ps1                    # Write-AccessLog
    ├── ExchangeConnection.ps1         # Connect / Disconnect
    ├── Tracking.ps1                   # Load/Save/Find/New tracking entries
    └── MailboxPermissions.ps1         # Grant/Remove/Verify permissions
```

## CSV Format

```csv
Grantee,Mailbox,StartDate,EndDate
jsmith@contoso.com,target@contoso.com,2025-01-01,2025-12-31
bob@contoso.com,finance@contoso.com,2025-02-01,2025-02-28
```

- **Grantee** = user who receives access (must have an Exchange Online license)
- **Mailbox** = target mailbox
- **StartDate** = access granted only from this date onward
- **EndDate** = access auto-removed after this date (via the removal script)

## Setup (one time)

```powershell
# Install the Exchange Online module
Install-Module ExchangeOnlineManagement -Scope CurrentUser

# (optional) Import the module now
Import-Module ExchangeOnlineManagement
```

### App-based auth with a certificate (recommended for automation)

These scripts run non-interactively (Task Scheduler / service accounts), so use app-based
auth with a certificate instead of an interactive login. If you omit the app auth
parameters, the scripts fall back to interactive login.

1. **Create an app registration** in the Microsoft Entra admin center
   (App registrations → New registration).
2. **Add the API permission** `Exchange.ManageAsApp` under
   *Microsoft Graph* / *Office 365 Exchange Online* (Application permission).
3. **Associate your certificate** with the app: App registrations → Certificates & secrets →
   Upload certificate. Note the thumbprint.
4. **Install the same certificate** into the machine that runs the scripts
   (Local Machine → Personal, or Current User → Personal). The thumbprint must match.
5. Copy the **Application (client) ID**, the **Tenant** domain (e.g. `contoso.onmicrosoft.com`),
   and the thumbprint for the command below.

## Usage

### 1. Grant access (run daily on a schedule, or manually)

```powershell
.\Grant-MailboxDelegatedAccess.ps1 -CsvPath .\Access.csv `
    -AppId "11111111-2222-3333-4444-555555555555" `
    -CertificateThumbprint "AB12CD34EF56AB12CD34EF56AB12CD34EF56AB12" `
    -Organization "contoso.onmicrosoft.com"
```

- Skips rows whose StartDate hasn't arrived yet
- Grants `FullAccess` and `SendAs` (use `-GrantSendAs:$false` for FullAccess only)
- Logs every action to `AccessLog.csv`

### 2. Remove expired access (schedule this daily)

```powershell
.\Remove-ExpiredMailboxAccess.ps1 `
    -AppId "11111111-2222-3333-4444-555555555555" `
    -CertificateThumbprint "AB12CD34EF56AB12CD34EF56AB12CD34EF56AB12" `
    -Organization "contoso.onmicrosoft.com"
```

Revokes grants whose EndDate has passed. Run it daily via Task Scheduler.

### Task Scheduler example (run daily)

```powershell
# Run both scripts daily at 6:00 AM using app auth with a certificate
$grantArgs = "-NoProfile -ExecutionPolicy Bypass -File `"C:\MailboxDelegation\Grant-MailboxDelegatedAccess.ps1`" " `
    "-CsvPath `"C:\MailboxDelegation\Access.csv`" " `
    "-AppId `"11111111-2222-3333-4444-555555555555`" " `
    "-CertificateThumbprint `"AB12CD34EF56AB12CD34EF56AB12CD34EF56AB12`" " `
    "-Organization `"contoso.onmicrosoft.com`""
$removeArgs = "-NoProfile -ExecutionPolicy Bypass -File `"C:\MailboxDelegation\Remove-ExpiredMailboxAccess.ps1`" " `
    "-AppId `"11111111-2222-3333-4444-555555555555`" " `
    "-CertificateThumbprint `"AB12CD34EF56AB12CD34EF56AB12CD34EF56AB12`" " `
    "-Organization `"contoso.onmicrosoft.com`""

$action1 = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $grantArgs
$action2 = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $removeArgs
$trigger = New-ScheduledTaskTrigger -Daily -At 6:00AM
$settings = New-ScheduledTaskSettingsSet -StartWhenOnBatteries -DontStopOnIdleEnd

Register-ScheduledTask -TaskName "Mailbox Delegated Access" `
    -Action $action1,$action2 -Trigger $trigger -Settings $settings
```

## Logging

All actions (connect, grant, remove, validation) are logged to `AccessLog.csv`:

```
Timestamp, Action, Grantee, Mailbox, StartDate, EndDate, Status, Details
2025-01-15 09:00:01, Connect, , , , , Success, Connected
2025-01-15 09:00:02, Grant FullAccess, jsmith@contoso.com, target@contoso.com, 2025-01-01, 2025-12-31, Success, OK
2025-01-15 09:00:03, Grant SendAs, jsmith@contoso.com, target@contoso.com, 2025-01-01, 2025-12-31, Success, OK
2026-01-01 09:00:01, Remove FullAccess, jsmith@contoso.com, target@contoso.com, 2025-01-01, 2025-12-31, Success, OK
2026-01-01 09:00:02, Remove SendAs, jsmith@contoso.com, target@contoso.com, 2025-01-01, 2025-12-31, Success, OK
2026-01-01 09:00:03, Remove Complete, jsmith@contoso.com, target@contoso.com, 2025-01-01, 2025-12-31, Success, All rights revoked
```

Status values: `Success`, `Failed`, `Skipped`. Details include error text on failures.

## Notes

- The removal script only revokes grants found in `MailboxAccessTracking.json` — don't delete that file.
- Grantees must have an Exchange Online license for the grant to succeed.
- If a grant fails (e.g. license missing), the tracking entry is still created only for rights that succeeded; retry by re-running the grant script.
- App auth requires the ExchangeOnlineManagement module version that supports `-AppId`/`-CertificateThumbprint` (2.0+). The certificate must be installed in the store of the account running the script, and the thumbprint must match the one uploaded to the app registration.
- If `-AppId`/`-CertificateThumbprint` are omitted, the scripts fall back to interactive login.
