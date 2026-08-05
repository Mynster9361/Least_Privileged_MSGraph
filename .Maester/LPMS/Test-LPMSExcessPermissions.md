Checks that no service principal holds Microsoft Graph API permissions beyond those actively used during the analysis window.

Excess permissions violate the **principle of least privilege**. If a service principal is compromised, an attacker can abuse every permission assigned to it — even permissions the application never actually uses. Removing unused permissions directly reduces the blast radius of a credential or token compromise.

#### Remediation action:

For each application listed below:

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com) as at least an **Application Administrator** or **Cloud Application Administrator**.
2. Browse to **Identity** > **Applications** > **Enterprise applications**, then open the affected application.
3. Select **Permissions** > **Admin consent** (or **User consent** as applicable).
4. Review the permissions flagged as excess and remove any that are not required for the application's intended function. Refer to the application owner to confirm which permissions are genuinely needed.
5. If the application has application-type permissions (app roles), revoke them via **App registrations** > select the app > **API permissions** > remove the excess entries > **Save**.

#### Related links

* [Entra admin center — Enterprise applications](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/StartboardApplicationsMenuBlade/~/AppAppsPreview)
* [Microsoft Graph — Least privilege best practices](https://learn.microsoft.com/en-us/graph/permissions-overview#best-practices-for-using-microsoft-graph-permissions)
* [LeastPrivilegedMSGraph module](https://github.com/Mynster9361/LeastPrivilegedMSGraph)

<!--- Results --->

%TestResult%
