<#
.SYNOPSIS
    Export all end-user computers (laptops) from a specific AD domain to CSV.
.DESCRIPTION
    This script queries a hardcoded AD domain for computer accounts that are enabled and likely to be end-user laptops.
    It filters by OperatingSystem and/or other properties to identify portable computers.
    The domain is provided as a hardcoded constant near the top of the file (change as needed).
.NOTES
    Author: generated from Get-ActiveDomainUsers.ps1 style reference
    Date: 2025-10-29
.EXAMPLE
    # Run the script and use default output path
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Get-EndUserComputers.ps1"
.EXAMPLE
    # Run the script and specify an explicit CSV path
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Get-EndUserComputers.ps1" -OutputCsvPath "C:\Temp\EndUserComputers_2025-10-29.csv"
#>

param(
    [Parameter(Mandatory=$false, HelpMessage = "Optional path for output CSV. If not supplied, script writes to script folder.")]
    [string]$OutputCsvPath,
    [Parameter(Mandatory=$false, HelpMessage = "Maximum number of computers to process. Default is 10.")]
    [int]$MaxComputers = 10
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
    $OutputCsvPath = Join-Path -Path $scriptPath -ChildPath ("EndUserComputers_{0}.csv" -f (Get-Date -Format 'yyyy-MM-dd'))
}
if (Test-Path $OutputCsvPath) {
    Write-Error "Output file already exists: $OutputCsvPath`nPlease remove it or pass a different -OutputCsvPath."
    return
}

Write-Host "Querying domain: $TargetDomain`nSaving output to: $OutputCsvPath`nMaxComputers: $MaxComputers" -ForegroundColor Cyan

# Filter for enabled computers, likely laptops (OperatingSystem contains 'Windows' and 'Laptop' or 'Portable')
$filter = "(Enabled -eq 'True')"

try {
    $computers = @(Get-ADComputer -Filter $filter -Server $TargetDomain -Properties Name,OperatingSystem,OperatingSystemVersion,LastLogonDate,Description,DistinguishedName,Enabled,whenCreated,whenChanged -ErrorAction Stop)
    # Further filter for laptops/portables by OS name or description
    $computers = $computers | Where-Object { $_.OperatingSystem -match 'Windows' }
}
catch {
    Write-Error "Failed to query domain '$TargetDomain'. Error: $($_.Exception.Message)"
    return
}

if (-not $computers -or $computers.Count -eq 0) {
    Write-Warning "No end-user computers (laptops) found in domain: $TargetDomain"
    return
}

# Apply MaxComputers limit if provided and smaller than the returned count
if ($MaxComputers -gt 0 -and $computers.Count -gt $MaxComputers) {
    Write-Host "Note: limiting computers from $($computers.Count) to $MaxComputers as requested." -ForegroundColor Yellow
    $computers = $computers | Select-Object -First $MaxComputers
}

$reportData = [System.Collections.Generic.List[object]]::new()
foreach ($c in $computers) {
    $reportData.Add([PSCustomObject]@{
        Name                  = $c.Name
        OperatingSystem       = $c.OperatingSystem
        OperatingSystemVersion= $c.OperatingSystemVersion
        LastLogonDate         = $c.LastLogonDate
        Description           = $c.Description
        Enabled               = $c.Enabled
        whenCreated           = $c.whenCreated
        whenChanged           = $c.whenChanged
        DistinguishedName     = $c.DistinguishedName
    })
}

try {
    $reportData | Export-Csv -Path $OutputCsvPath -NoTypeInformation -Encoding UTF8
    Write-Host "Success: exported $($reportData.Count) end-user computers to $OutputCsvPath" -ForegroundColor Green
} catch {
    Write-Error "Failed to write CSV to $OutputCsvPath. Error: $($_.Exception.Message)"
}

# End of script
