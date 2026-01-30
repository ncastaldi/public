<#
.SYNOPSIS
    Generates a comprehensive report of AD group memberships by searching multiple domains and using fallback logic.

.DESCRIPTION
    This script reads users from an Excel file. For each user, it attempts to find them in a primary and secondary
    AD domain, first by UserPrincipalName, then by full name. It reports on how each user was found and
    logs their group memberships.

.VERSION
    2.0

.NOTES
    Author: cnathan (with Gemini assistance)
    Version History:
    2.0 - 2025-09-04: Major upgrade. Implemented cascading search logic to query a secondary AD domain (saturnusa.net)
                     and added a fallback to search by full name. Added enhanced status reporting.
    1.4 - 2025-09-04: Updated AD filter to use UserPrincipalName for better reliability.
    1.3 - 2025-09-04: Fixed "divide by zero" bug for single-row input files.
    1.2 - 2025-09-03: Hardened script against null/blank rows.
    1.1 - 2025-09-03: Switched to Import-Excel for .xlsx support.
    1.0 - 2025-09-03: Initial script creation.

.PARAMETER UPNColumn
    The name of the column in the Excel file containing the UserPrincipalName (e.g., "UserPrincipalName").

.PARAMETER FullNameColumn
    The name of the column in the Excel file containing the user's full name (e.g., "FullName").

.PARAMETER OutputCsvPath
    The file path where the final CSV report will be saved.

.EXAMPLE
    .\Get-UserGroupMembershipReport.ps1 -UPNColumn "UserPrincipalName" -FullNameColumn "FullName" -OutputCsvPath ".\AD_Report_$(Get-Date -Format 'yyyy-MM-dd').csv"
#>
param (
    [Parameter(Mandatory=$true)]
    [string]$UPNColumn,

    [Parameter(Mandatory=$true)]
    [string]$FullNameColumn,

    [Parameter(Mandatory=$true)]
    [string]$OutputCsvPath
)

# --- Configuration & Setup ---
$SecondaryDomain = "corp.contoso.com"

try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Import-Module ImportExcel -ErrorAction Stop
} catch {
    Write-Error "A required module is not installed. Please run 'Install-Module ImportExcel' and ensure the AD tools are installed."
    return
}

$scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
$InputExcelPath = Join-Path -Path $scriptPath -ChildPath "employees.xlsx"

# --- Pre-flight Safety Checks ---
if (Test-Path $OutputCsvPath) {
    Write-Error "Output file already exists: $OutputCsvPath"
    return
}
if (-not (Test-Path $InputExcelPath)) {
    Write-Error "Input Excel file not found: $InputExcelPath"
    return
}

# --- Main Processing ---
$usersFromExcel = @(Import-Excel -Path $InputExcelPath)
$reportData = [System.Collections.Generic.List[object]]::new()
Write-Host "Starting report generation for $($usersFromExcel.Count) users..." -ForegroundColor Green

foreach ($userRecord in $usersFromExcel) {
    $upn = $userRecord.$UPNColumn
    $fullName = $userRecord.$FullNameColumn
    $adUser = $null
    $status = ""

    if ([string]::IsNullOrWhiteSpace($upn) -and [string]::IsNullOrWhiteSpace($fullName)) {
        Write-Warning "Skipping row with blank UPN and FullName."
        continue
    }

    # 1. Search UPN in Primary Domain
    if (-not [string]::IsNullOrWhiteSpace($upn)) {
        try {
            $adUser = Get-ADUser -Filter "UserPrincipalName -eq '$upn'" -Properties DisplayName, EmailAddress, Title, Manager, MemberOf -ErrorAction Stop
            if ($adUser) { $status = "Found_UPN_Primary" }
        } catch { }
    }

    # 2. Search UPN in Secondary Domain
    if (-not $adUser -and -not [string]::IsNullOrWhiteSpace($upn)) {
        try {
            $adUser = Get-ADUser -Filter "UserPrincipalName -eq '$upn'" -Server $SecondaryDomain -Properties DisplayName, EmailAddress, Title, Manager, MemberOf -ErrorAction Stop
            if ($adUser) { $status = "Found_UPN_Secondary" }
        } catch { }
    }

    # 3. Fallback to Full Name Search (Primary Domain)
    if (-not $adUser -and -not [string]::IsNullOrWhiteSpace($fullName)) {
        $nameParts = $fullName.Split(' ', 2)
        if ($nameParts.Count -eq 2) {
            $firstName = $nameParts[0]
            $lastName = $nameParts[1]
            $nameFilter = "(GivenName -eq '$firstName' -and Surname -eq '$lastName')"
            try {
                $nameMatches = @(Get-ADUser -Filter $nameFilter -Properties DisplayName, EmailAddress, Title, Manager, MemberOf)
                if ($nameMatches.Count -eq 1) {
                    $adUser = $nameMatches[0]
                    $status = "Found_Name_Primary"
                } elseif ($nameMatches.Count -gt 1) {
                    $status = "DUPLICATE_NAME_Primary"
                }
            } catch { }
        }
    }

    # 4. Fallback to Full Name Search (Secondary Domain)
    if (-not $adUser -and -not [string]::IsNullOrWhiteSpace($fullName) -and $status -notlike "DUPLICATE*") {
        $nameParts = $fullName.Split(' ', 2)
        if ($nameParts.Count -eq 2) {
            $firstName = $nameParts[0]
            $lastName = $nameParts[1]
            $nameFilter = "(GivenName -eq '$firstName' -and Surname -eq '$lastName')"
            try {
                $nameMatches = @(Get-ADUser -Filter $nameFilter -Server $SecondaryDomain -Properties DisplayName, EmailAddress, Title, Manager, MemberOf)
                if ($nameMatches.Count -eq 1) {
                    $adUser = $nameMatches[0]
                    $status = "Found_Name_Secondary"
                } elseif ($nameMatches.Count -gt 1) {
                    $status = "DUPLICATE_NAME_Secondary"
                }
            } catch { }
        }
    }

    # --- Compile Report Row ---
    if ($adUser) {
        $managerName = if ($adUser.Manager) { (Get-ADUser $adUser.Manager -Server $adUser.DistinguishedName.Split(',')[-3].Split('=')[1]).Name } else { "N/A" }
        $groupNames = ($adUser.memberOf | ForEach-Object { (Get-ADGroup $_).SamAccountName }) -join "; "
        $reportData.Add([PSCustomObject]@{
            InputUPN         = $upn
            InputFullName    = $fullName
            Status           = $status
            FoundSamAccountName = $adUser.SamAccountName
            FoundUserPrincipalName = $adUser.UserPrincipalName
            FoundDisplayName = $adUser.DisplayName
            JobTitle         = $adUser.Title
            Manager          = $managerName
            GroupMemberships = $groupNames
        })
        Write-Host "Successfully processed: $($adUser.SamAccountName) (Status: $status)"
    } else {
        # Log failure to find or duplicate status
        if (-not $status) { $status = "NOT_FOUND" }
        $reportData.Add([PSCustomObject]@{
            InputUPN         = $upn
            InputFullName    = $fullName
            Status           = $status
            FoundSamAccountName = ""
            FoundUserPrincipalName = ""
            FoundDisplayName = ""
            JobTitle         = ""
            Manager          = ""
            GroupMemberships = ""
        })
        Write-Warning "Could not process '$($upn)' or '$($fullName)'. Status: $status"
    }
}

# --- Final Output ---
if ($reportData.Count -gt 0) {
    $reportData | Export-Csv -Path $OutputCsvPath -NoTypeInformation
    Write-Host "Success! Report saved to $OutputCsvPath" -ForegroundColor Green
} else {
    Write-Warning "No users were processed. The output file was not created."
}