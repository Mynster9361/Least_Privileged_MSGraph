# LeastPrivilegedMSGraph — Maester Tests

Custom [Maester](https://maester.dev) security checks that verify every service principal in your tenant follows the **principle of least privilege**, backed by real Graph API activity captured in Log Analytics.

Each check expands into **one Pester test per service principal** so individual applications appear as separate Pass / Fail / Investigate rows in the Maester report.

---

## Tests

| ID           | Title                | Severity | Passes when…                                                                                       |
| ------------ | -------------------- | :------: | -------------------------------------------------------------------------------------------------- |
| **LPMS.001** | Excess permissions   |  🟠 High  | Every SP holds only the permissions its Graph activity actually required                           |
| **LPMS.002** | Unmatched activity   | 🟡 Medium | Every observed API call could be mapped to a known Graph endpoint (permission mapping is complete) |
| **LPMS.003** | Critical throttling  | 🟡 Medium | No SP is experiencing Warning (≥ 10 %) or Critical (≥ 25 %) throttle rates                         |
| **LPMS.004** | No recorded activity | 🟡 Medium | Every SP that holds permissions also shows Graph activity in the analysis window                   |

---

## Prerequisites

### 1 — PowerShell modules

```powershell
Install-Module LeastPrivilegedMSGraph -Scope CurrentUser
Install-Module Maester              -Scope CurrentUser
Install-Module Az.Accounts          -Scope CurrentUser   # required for Log Analytics auth
```

### 2 — Log Analytics workspace

The module queries the **MicrosoftGraphActivityLogs** table in an Azure Monitor Log Analytics workspace.  
Enable the diagnostic setting in Entra ID:

1. **Entra admin center** → *Monitoring & health* → *Diagnostic settings* → **Add diagnostic setting**
2. Select **MicrosoftGraphActivityLogs** under *Logs*
3. Destination: **Send to Log Analytics workspace** → pick or create your workspace
4. Save — logs start flowing within a few minutes

The identity running the tests needs the **Monitoring Reader** role on that workspace  
(or a broader role such as Contributor / Reader on the resource group).

### 3 — Required Graph scopes

The tests use the same delegated scopes that `Connect-Maester` requests.  
No additional Graph permissions are needed beyond a standard Maester run.

---

## Configuration

Settings are resolved in this priority order — first value found wins:

| Priority | Source                               | How to set                                          |
| :------: | ------------------------------------ | --------------------------------------------------- |
|    1     | `maester-config.json` GlobalSettings | Add a `Custom/maester-config.json` file (see below) |
|    2     | Environment variables                | Set `$env:LPMS_*` before running                    |
|    3     | Built-in defaults                    | Automatic — no action needed                        |

### Option A — maester-config.json (recommended for local runs)

Create or edit `./tests/Custom/maester-config.json`  
(**never** edit `./tests/maester-config.json` directly — it is overwritten by Maester on update):

```json
{
  "GlobalSettings": {
    "LPMSLogAnalyticsWorkspaceId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "LPMSDaysToQuery": 30,
    "LPMSMaxActivityEntries": 100000,
    "LPMSThrottleLimit": 10,
    "LPMSOnlyPrivilegXAndOver": 3
  }
}
```

Only `LPMSLogAnalyticsWorkspaceId` is required. The other four keys are optional overrides of the defaults.

### Option B — Environment variables (CI/CD pipelines)

```powershell
$env:LPMS_LOG_ANALYTICS_WORKSPACE_ID = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
$env:LPMS_DAYS_TO_QUERY              = '30'       # optional, default: 30
$env:LPMS_MAX_ACTIVITY_ENTRIES       = '100000'   # optional, default: 100000
$env:LPMS_THROTTLE_LIMIT             = '10'       # optional, default: 10
$env:LPMS_ONLY_PRIVILEGX_AND_OVER    = '1'        # optional, default: 1
```

| Variable                          | Description                                                                                                                                                                                                                                                                     |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `LPMS_LOG_ANALYTICS_WORKSPACE_ID` | Log Analytics workspace GUID — find it in the workspace's *Overview* blade                                                                                                                                                                                                      |
| `LPMS_DAYS_TO_QUERY`              | Days of history to analyse. More days = better coverage, slower pipeline.                                                                                                                                                                                                       |
| `LPMS_MAX_ACTIVITY_ENTRIES`       | Maximum Log Analytics rows fetched per service principal. Raise this only for very active SPs.                                                                                                                                                                                  |
| `LPMS_THROTTLE_LIMIT`             | Parallel workers when fetching activity. Reduce if you hit Log Analytics rate limits.                                                                                                                                                                                           |
| `LPMS_ONLY_PRIVILEGX_AND_OVER`    | Will allow you to limit the amounut of tests by only looking at higher level permissions based on microsofts own determination of privileged level see more [here](https://github.com/microsoftgraph/microsoft-graph-devx-content/blob/master/permissions/new/permissions.json) |

---

## Running the tests

### Interactive (local workstation)

```powershell
# 1. Connect to Microsoft Graph (Maester handles scope selection)
Connect-Maester

# 2. Authenticate to Azure — adds the Log Analytics resource scope to your token cache.
#    If your tenant enforces MFA for this resource, you will be prompted once per session.
Connect-AzAccount -AuthScope 'https://api.loganalytics.io'

# 3. Run only the LPMS checks
Invoke-Maester -Path .\maester-tests\Custom\LPMS

# — or run them alongside all other Maester tests —
Invoke-Maester
```

> **Why the extra `Connect-AzAccount` step?**  
> The module uses the existing Az session to obtain a Log Analytics bearer token via  
> `Connect-EntraService -AsAzAccount`. Azure caches tokens per resource, so the Log Analytics  
> scope must be authenticated at least once per PowerShell session. If your tenant's Conditional  
> Access policy requires MFA for `https://api.loganalytics.io`, you will be prompted interactively  
> the first time; subsequent calls within the session are silent.

### Automated / CI-CD (service principal)

For fully unattended runs, authenticate with a **service principal** or **managed identity** —  
neither is subject to interactive MFA requirements.

```powershell
# Service principal (client secret)
Connect-MgGraph -ClientId $clientId -TenantId $tenantId -ClientSecret $secret
Connect-EntraService -Service 'LogAnalytics' -ClientID $clientId -TenantID $tenantId -ClientSecret $clientSecretSecure

Invoke-Maester -Path .\maester-tests\Custom\LPMS

# Managed identity (Azure-hosted runner)
Connect-MgGraph -Identity
Connect-EntraService -Service 'LogAnalytics' -Identity

Invoke-Maester -Path .\maester-tests\Custom\LPMS
```

The service principal / managed identity needs:
- **Microsoft Graph** — same permissions as a standard Maester service principal  
  (see [Maester docs — Service principal](https://maester.dev/docs/installation/service-principal))
  > In reality LeastPrivilegedMSGraph only requires Application.Read.All along with the access to the log analytics workspace but since you are properly already running maester you do not need to configure extra permissions.
- **Monitoring Reader** role on the workspace (Azure RBAC)

---

## Files

| File                               | Purpose                                                                          |
| ---------------------------------- | -------------------------------------------------------------------------------- |
| `Get-LPMSCachedAppData.ps1`        | Runs the full pipeline once and caches results for the entire test run           |
| `LPMSGraph.Tests.ps1`              | Pester test file — expands each check into one test per SP via `BeforeDiscovery` |
| `Test-LPMSExcessPermissions.ps1`   | LPMS.001 helper — evaluates a single SP for excess permissions                   |
| `Test-LPMSUnmatchedActivities.ps1` | LPMS.002 helper — checks whether all activity could be mapped                    |
| `Test-LPMSCriticalThrottling.ps1`  | LPMS.003 helper — checks throttle rate for a single SP                           |
| `Test-LPMSNoActivity.ps1`          | LPMS.004 helper — flags SPs with permissions but zero activity                   |
| `Test-LPMS*.md`                    | Companion markdown — rendered as remediation guidance in the Maester report      |

---

## Troubleshooting

### `[LogAnalytics] Failed to connect` warning  

Your Az session doesn't yet have a cached token for `https://api.loganalytics.io`.

```powershell
Connect-AzAccount -AuthScope 'https://api.loganalytics.io'
```

If this fails due to Conditional Access / MFA, either:
- Complete the MFA challenge interactively (token is then cached for the session), or
- Switch to a service principal / managed identity authentication path (no MFA required).

### Tests skipped with "workspace ID is not configured"

The workspace ID was not found in either `Custom/maester-config.json` or the  
`LPMS_LOG_ANALYTICS_WORKSPACE_ID` environment variable.  
Follow the [Configuration](#configuration) section above.

### Tests skipped with "LeastPrivilegedMSGraph module is not loaded"

```powershell
Import-Module LeastPrivilegedMSGraph
```

### Pipeline returns no data / all tests investigate

Check that **MicrosoftGraphActivityLogs** is enabled in Entra ID Diagnostic Settings and that  
data has had time to flow into the workspace (allow 15 – 30 minutes after first enabling).

>NOTE i have seen it take up to 48 hours before logs get ingested so be patient  

Also confirm the identity running the tests has **Monitoring Reader** on the workspace.

### Result shows `[Pipeline Error]` as SP name

The `Get-LPMSCachedAppData` helper caught a terminating error. Run `Get-LPMSCachedAppData`  
manually in the same session to see the full error message:

```powershell
. .\maester-tests\Custom\LPMS\Get-LPMSCachedAppData.ps1
Get-LPMSCachedAppData
$script:_LPMSDataError   # detailed error if the above returned $null
```
