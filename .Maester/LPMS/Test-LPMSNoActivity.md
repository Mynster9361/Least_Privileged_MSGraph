Checks that every service principal with assigned Microsoft Graph API permissions recorded at least one API call during the analysis window.

A service principal that holds permissions but has not exercised them in the analysis period may be **stale, abandoned, or incorrectly configured**. Stale app registrations with active permissions represent an unnecessary attack surface: if the credentials are compromised or the registration is taken over, an attacker gains access to all assigned permissions with no legitimate business justification.

This check is reported as **Investigate** rather than an automatic failure because zero activity has several legitimate explanations:

- The application is **seasonal** and only runs at certain times of year (consider widening `LPMS_DAYS_TO_QUERY`).
- The application relies solely on **delegated user flows** and no users signed in during the period.
- The application was **recently registered** and is not yet in production.
- The application uses a **non-Graph service** and the Graph permissions are reserved for a future feature.

#### Remediation action:

For each application listed below:

1. Contact the application owner and confirm whether the application is still in use.
2. If the application is no longer needed:
   - Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com) as at least an **Application Administrator**.
   - Browse to **Identity** > **Applications** > **App registrations** > select the application.
   - Select **Delete** to remove the registration entirely, or navigate to **API permissions** and remove all permissions.
3. If the application is seasonal or infrequent, widen the analysis window by increasing `LPMS_DAYS_TO_QUERY` (e.g., `90`) and re-run the check. **NOTE: that this will increase memory usage on run so you need to have available ressources to successfully increase the amount of days**
4. If the application only makes delegated calls driven by end-user sign-ins, consider whether it still needs its current permission scope.

#### Related links

* [Entra admin center — App registrations](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/~/RegisteredApps)
* [Microsoft — Remove unused app registrations](https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/delete-application-portal)
* [LeastPrivilegedMSGraph module](https://github.com/Mynster9361/LeastPrivilegedMSGraph)

<!--- Results --->

%TestResult%
