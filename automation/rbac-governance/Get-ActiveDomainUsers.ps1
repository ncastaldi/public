<#
.SYNOPSIS
    Export all active (Enabled) user accounts from a specific AD domain to CSV.

.DESCRIPTION
    This script queries a single, hardcoded AD domain for user accounts where Enabled -eq True.
    For each user the script collects common properties and resolves manager and group names.
    The domain is provided as a hardcoded constant near the top of the file (change as needed).

.NOTES
    Author: generated from `Get-UserGroupMembershipReport.ps1` style reference
    Date: 2025-10-29

.EXAMPLE
    # Run the script and use default output path
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Get-ActiveDomainUsers.ps1"

.EXAMPLE
    # Run the script and specify an explicit CSV path
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Get-ActiveDomainUsers.ps1" -OutputCsvPath "C:\Temp\ActiveUsers_2025-10-29.csv"
#>

param(
    [Parameter(Mandatory=$false, HelpMessage = "Optional path for output CSV. If not supplied, script writes to script folder.")]
    [string]$OutputCsvPath,

    [Parameter(Mandatory=$false, HelpMessage = "Maximum number of users to process. Default is 5.")]
    [int]$MaxUsers = 5
)

### === Edit this constant to the domain you want to query ===
$TargetDomain = "corp.contoso.com"   # <- HARD-CODED target domain (change to your domain)
### =========================================================

try {
    Import-Module ActiveDirectory -ErrorAction Stop
} catch {
    Write-Error "ActiveDirectory module is required but not installed/available. Please install RSAT or run on a domain-joined machine with the AD module."
    return
}

$scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
if (-not $OutputCsvPath) {
    $OutputCsvPath = Join-Path -Path $scriptPath -ChildPath ("ActiveUsers_{0}.csv" -f (Get-Date -Format 'yyyy-MM-dd'))
}

if (Test-Path $OutputCsvPath) {
    Write-Error "Output file already exists: $OutputCsvPath`nPlease remove it or pass a different -OutputCsvPath." 
    return
}

Write-Host "Querying domain: $TargetDomain`nSaving output to: $OutputCsvPath`nMaxUsers: $MaxUsers" -ForegroundColor Cyan

$filter = "Enabled -eq 'True'"

try {
    $users = @(Get-ADUser -Filter $filter -Server $TargetDomain -Properties DisplayName, UserPrincipalName, SamAccountName, Enabled, LastLogonDate, Title, Department, EmailAddress, Manager, memberOf, msExchRecipientTypeDetails -ErrorAction Stop)
    # Exclude all non-user mailboxes (shared, room, equipment, etc.)
    $users = $users | Where-Object { $_.msExchRecipientTypeDetails -eq 1 -or -not $_.msExchRecipientTypeDetails }
} catch {
    Write-Error "Failed to query domain '$TargetDomain'. Error: $($_.Exception.Message)"
    return
}

if (-not $users -or $users.Count -eq 0) {
    Write-Warning "No active users found in domain: $TargetDomain"
    return
}

# Apply MaxUsers limit if provided and smaller than the returned count
if ($MaxUsers -gt 0 -and $users.Count -gt $MaxUsers) {
    Write-Host "Note: limiting users from $($users.Count) to $MaxUsers as requested." -ForegroundColor Yellow
    $users = $users | Select-Object -First $MaxUsers
}

$reportData = [System.Collections.Generic.List[object]]::new()

foreach ($u in $users) {
    # Resolve friendly manager name when present
    $managerName = "N/A"
    if ($u.Manager) {
        try {
            $mgr = Get-ADUser -Identity $u.Manager -Server $TargetDomain -Properties Name -ErrorAction Stop
            if ($mgr) { $managerName = $mgr.Name }
        } catch {
            # Fall back to raw DN if lookup fails
            $managerName = $u.Manager
        }
    }

    # Resolve groups to SamAccountName where possible
    # $groupNames = ""
    # if ($u.MemberOf) {
    #     try {
    #         $groupNames = ($u.MemberOf | ForEach-Object {
    #             try { (Get-ADGroup -Identity $_ -Server $TargetDomain -Properties SamAccountName).SamAccountName } catch { $_ }
    #         }) -join "; "
    #     } catch { $groupNames = ($u.MemberOf -join "; ") }
    # }

    $reportData.Add([PSCustomObject]@{
        SamAccountName      = $u.SamAccountName
        UserPrincipalName   = $u.UserPrincipalName
        DisplayName         = $u.DisplayName
        Enabled             = $u.Enabled
        LastLogonDate       = $u.LastLogonDate
        Title               = $u.Title
        Department          = $u.Department
        EmailAddress        = $u.EmailAddress
        Manager             = $managerName
        # GroupMemberships    = $groupNames
        DistinguishedName   = $u.DistinguishedName
    })
}

try {
    $reportData | Export-Csv -Path $OutputCsvPath -NoTypeInformation -Encoding UTF8
    Write-Host "Success: exported $($reportData.Count) active users to $OutputCsvPath" -ForegroundColor Green
} catch {
    Write-Error "Failed to write CSV to $OutputCsvPath. Error: $($_.Exception.Message)"
}

# End of script
