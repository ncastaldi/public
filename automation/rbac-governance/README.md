# 🔐 Post-Merger Identity & RBAC Governance

> **Automated Discovery and Normalization for Stalled Merger Integrations.**

## 🏗️ The Challenge: The 3-Year Stall

Following a major corporate merger, the Role-Based Access Control (RBAC) integration had been stalled for approximately three years. Legacy systems lacked uniformity, and manual "click-and-export" processes from fragmented portals created a high-toil environment for the Service Desk.

I was tasked with identifying the "source of truth" to allow the migration to proceed. By locating a critical pivot-point in the legacy dataset and normalizing it against **Workday exports**, I developed these utilities to bridge the gap between legacy chaos and modern governance.

## 🛠️ The Solution: "Digital Archeology" via PowerShell

These scripts serve as the technical engine for identity discovery and permission auditing.

- **[Get-UserGroupMembershipReport.ps1](./Get-UserGroupMembershipReport.ps1):** Leverages **Microsoft Graph API** to extract normalized group data, bypassing the inconsistencies of "ancient" legacy applications.
- **[Get-ActiveDomainUsers.ps1](./Get-ActiveDomainUsers.ps1):** Audits on-prem Active Directory to cross-reference legacy accounts against current Workday employee records.
- **[Get-EndUserComputers.ps1](./Get-EndUserComputers.ps1):** Facilitates asset-to-identity mapping, critical for ensuring security policies are applied to the correct physical endpoints.

## 📈 Operational Impact

- **Unblocked Integration**: Successfully moved a project forward that had failed multiple attempts over a 3-year period.
- **Data Integrity**: Normalized fragmented legacy data into a single, actionable format for stakeholders.
- **Strategic Support**: Provided the leadership team with the visibility required to execute the final stages of the merger's identity migration.
