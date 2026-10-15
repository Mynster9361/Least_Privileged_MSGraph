# LeastPrivilegedMSGraph — Maester Tests

Custom [Maester](https://maester.dev) security checks that verify every service principal in your tenant follows the **principle of least privilege**, backed by real Graph API activity captured in Log Analytics.

These are **Maester 3.0 native tests** (`Test.<ID>.ps1` + `Test.<ID>.md` with a `[MaesterTest]` attribute). Each check is a **family**: it expands into one result row per service principal (`LPMS.001.<PrincipalId>`), so individual applications appear as separate Pass / Fail / Investigate rows in the Maester report.

> Requires **Maester 3.0 or later** and **PowerShell 7.4 or later**. Pester is not needed.

---

## Tests

| ID           | Title                | Severity | Passes when…                                                                                       |
| ------------ | -------------------- | :------: | -------------------------------------------------------------------------------------------------- |
| **LPMS.001** | Excess permissions   | 🟡 Medium | The SP holds only the permissions its Graph activity actually required                             |
| **LPMS.002** | Unmatched activity   |  🟢 Low   | Every observed API call could be mapped to a known Graph endpoint (permission mapping is complete) |
| **LPMS.003** | Critical throttling  |  🟢 Low   | The SP is not experiencing Warning (≥ 10 %) or Critical (≥ 25 %) throttle rates                    |
| **LPMS.004** | No recorded activity | 🟡 Medium | The SP holds permissions and also shows Graph activity in the analysis window                      |

All four declare `Service = 'Azure'`, so Maester skips them with `ServiceNotConnected` when there is no Az session. They are classified as `Product = 'entra'`, `Feature = 'app-consent'` (001, 002) or `'applications'` (003, 004), `ResourceType = 'ServicePrincipal'` and belong to the `LPMS` suite (`suite.json`).

---

## Prerequisites

### 1 — PowerShell modules

```powershell
Install-Module Maester                -Scope CurrentUser   # 3.0 or later
Install-Module LeastPrivilegedMSGraph -Scope CurrentUser
Install-Module Az.Accounts            -Scope CurrentUser   # required for Log Analytics auth
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

### 3 — Required Graph permissions

LeastPrivilegedMSGraph only needs `Application.Read.All` in Microsoft Graph, plus read access to the Log Analytics workspace. If you already run Maester, you do not need to configure extra Graph permissions. Also requires `Directory.Read.All` if you want to audit the Delegated permission grants

---

## Installation

Copy this folder into the `custom` folder of your Maester tests folder (the one `Install-MaesterTests` created):

```text
maester-tests/
  maester-config.json
  custom/
    LPMS/
      suite.json
      helpers/Get-LPMSCachedAppData.ps1
      Test.LPMS.001.ps1 / .md
      ...
```

---

## Configuration

Settings are resolved in this priority order — first value found wins:

| Priority | Source                               | How to set                                 |
| :------: | ------------------------------------ | ------------------------------------------ |
|    1     | `maester-config.json` GlobalSettings | Add the keys to your `maester-config.json` |
|    2     | Environment variables                | Set `$env:LPMS_*` before running           |
|    3     | Built-in defaults                    | Automatic — no action needed               |

### Option A — maester-config.json (recommended for local runs)

Add the keys to `GlobalSettings` in `maester-config.json` in your Maester tests folder (or in `custom/maester-config.json`, or a tenant file `maester-config.<tenantId>.json`; Maester 3.0 merges them). See [maester-config.example.json](maester-config.example.json):

```json
{
  "GlobalSettings": {
    "LPMSLogAnalyticsWorkspaceId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "LPMSDaysToQuery": 30,
    "LPMSMaxActivityEntries": 100000,
    "LPMSThrottleLimit": 10,
    "LPMSOnlyPrivilegXAndOver": 1,
    "LPMSCacheMinutes": 60
  }
}
```

Only `LPMSLogAnalyticsWorkspaceId` is required. The other keys are optional overrides of the defaults.

### Option B — Environment variables (CI/CD pipelines)

```powershell
$env:LPMS_LOG_ANALYTICS_WORKSPACE_ID = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
$env:LPMS_DAYS_TO_QUERY              = '30'       # optional, default: 30
$env:LPMS_MAX_ACTIVITY_ENTRIES       = '100000'   # optional, default: 100000
$env:LPMS_THROTTLE_LIMIT             = '10'       # optional, default: 10
$env:LPMS_ONLY_PRIVILEGX_AND_OVER    = '1'        # optional, default: 1
$env:LPMS_CACHE_MINUTES              = '60'       # optional, default: 60
```

| Variable                          | Description                                                                                                                                                                                                                                                                     |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `LPMS_LOG_ANALYTICS_WORKSPACE_ID` | Log Analytics workspace GUID — find it in the workspace's *Overview* blade                                                                                                                                                                                                      |
| `LPMS_DAYS_TO_QUERY`              | Days of history to analyse. More days = better coverage, slower pipeline.                                                                                                                                                                                                       |
| `LPMS_MAX_ACTIVITY_ENTRIES`       | Maximum Log Analytics rows fetched per service principal. Raise this only for very active SPs.                                                                                                                                                                                  |
| `LPMS_THROTTLE_LIMIT`             | Parallel workers when fetching activity. Reduce if you hit Log Analytics rate limits.                                                                                                                                                                                           |
| `LPMS_ONLY_PRIVILEGX_AND_OVER`    | Will allow you to limit the amount of tests by only looking at higher level permissions based on Microsoft's own determination of privileged level see more [here](https://github.com/microsoftgraph/microsoft-graph-devx-content/blob/master/permissions/new/permissions.json) |
| `LPMS_CACHE_MINUTES`              | Minutes the pipeline result is reused across the four checks and across runs in the same PowerShell session.                                                                                                                                                                    |

### Severity and disabling checks

Each test carries its own severity. Override it, or disable a check, in `TestSettings`. A row can target the whole family or a single service principal:

```json
{
  "TestSettings": [
    { "Id": "LPMS.003", "Severity": "Low" },
    { "Id": "LPMS.004.00000000-0000-0000-0000-000000000000", "Enabled": false, "Reason": "Seasonal job, reviewed" }
  ]
}
```

---

## Running the tests

### Interactive (local workstation)

```powershell
# 1. Connect to Microsoft Graph (for the built-in checks)
Connect-Maester

# 2. Authenticate to Azure — adds the Log Analytics resource scope to your token cache.
#    If your tenant enforces MFA for this resource, you will be prompted once per session.
Connect-AzAccount -AuthScope 'https://api.loganalytics.io'

# 3. Run only the LPMS checks
Invoke-Maester -Path .\maester-tests -TestId 'LPMS.*'

# — or only the custom tests under the folder —
Invoke-Maester -Path .\maester-tests -SkipBuiltIn

# — or run them alongside all built-in Maester tests —
Invoke-Maester -Path .\maester-tests

# Run a single check from a script
Invoke-MtTest -Path .\maester-tests\custom\LPMS\Test.LPMS.001.ps1
```

Use `-DryRun -PassThru` to see what would run without calling the tenant.

> **Why the extra `Connect-AzAccount` step?**  
> The module uses the existing Az session to obtain a Log Analytics bearer token via  
> `Connect-EntraService -AsAzAccount`. Azure caches tokens per resource, so the Log Analytics  
> scope must be authenticated at least once per PowerShell session. If your tenant's Conditional  
> Access policy requires MFA for `https://api.loganalytics.io`, you will be prompted interactively  
> the first time; subsequent calls within the session are silent.

### Automated / CI-CD (service principal)

For fully unattended runs, authenticate with a **service principal** or **managed identity** —  
neither is subject to interactive MFA requirements. The checks need an Az session (`Service = 'Azure'`).

```powershell
# Service principal (certificate)
Connect-AzAccount -ServicePrincipal -ApplicationId $clientId -TenantId $tenantId -CertificatePath ./cert.pfx
Connect-MgGraph -AppId $clientId -Certificate $cert -TenantId $tenantId -NoWelcome

Invoke-Maester -Path .\maester-tests -SkipGraphConnect -NonInteractive

# Managed identity (Azure-hosted runner)
Connect-AzAccount -Identity
Connect-MgGraph -Identity -NoWelcome

Invoke-Maester -Path .\maester-tests -SkipGraphConnect -NonInteractive
```

The service principal / managed identity needs:
- **Microsoft Graph** — same permissions as a standard Maester service principal  
  (see [Maester docs — Connect-Maester Advanced](https://maester.dev/docs/connect-maester/connect-maester-advanced))
  > In reality LeastPrivilegedMSGraph only requires Application.Read.All along with the access to the log analytics workspace but since you are probably already running maester you do not need to configure extra permissions.

> BONUS NOTE: If you want Oauth permissiongrants included in the tests aswell for apps running in a delegated scope it will also need Directory.Read.All
- **Monitoring Reader** role on the workspace (Azure RBAC)

---

## Files

| File                                | Purpose                                                                            |
| ----------------------------------- | ---------------------------------------------------------------------------------- |
| `suite.json`                        | Names the `LPMS` suite so the rows show `Suite = LPMS`                             |
| `helpers/Get-LPMSCachedAppData.ps1` | Runs the full pipeline once and caches the result for all four checks (not a test) |
| `Test.LPMS.001.ps1`                 | Excess permissions — family, one row per SP with permissions                       |
| `Test.LPMS.002.ps1`                 | Unmatched activity — family, one row per SP with recorded activity                 |
| `Test.LPMS.003.ps1`                 | Critical throttling — family, one row per SP with throttling statistics            |
| `Test.LPMS.004.ps1`                 | No recorded activity — family, one row per SP with permissions                     |
| `Test.LPMS.00x.md`                  | Description and remediation guidance shown in the Maester report                   |
| `maester-config.example.json`       | Example `GlobalSettings` block                                                     |

Each `Test.LPMS.*.ps1` has an *instance source* function (`Get-LPMS*Instance`) that Maester calls at run time to list the service principals, and the test function that Maester runs once per service principal.

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

### Tests skipped with `ServiceNotConnected`

There is no Az session. Run `Connect-AzAccount` (see above) before `Invoke-Maester`.

### Error row `InstanceSourceFailed`: "workspace ID is not configured"

The workspace ID was not found in `maester-config.json` `GlobalSettings` or the  
`LPMS_LOG_ANALYTICS_WORKSPACE_ID` environment variable.  
Follow the [Configuration](#configuration) section above.

### Error row `InstanceSourceFailed`: other messages

The pipeline threw. The row's message is the error. Run it by hand to see the full error:

```powershell
. .\maester-tests\custom\LPMS\helpers\Get-LPMSCachedAppData.ps1
Get-LPMSCachedAppData
```

### Skipped row `NoInstances`

The pipeline returned no service principals for that check — for example no SP has throttling statistics, or `LPMSOnlyPrivilegXAndOver` filters them all out.

### Pipeline returns no data / all tests investigate

Check that **MicrosoftGraphActivityLogs** is enabled in Entra ID Diagnostic Settings and that  
data has had time to flow into the workspace (allow 15 – 30 minutes after first enabling).

>NOTE i have seen it take up to 48 hours before logs get ingested so be patient  

Also confirm the identity running the tests has **Monitoring Reader** on the workspace.

### Results look stale

The pipeline result is cached for `LPMSCacheMinutes` (default 60) in the PowerShell session. Clear it to force a refresh:

```powershell
Remove-Variable -Name LPMSMaesterCache -Scope Global
```
