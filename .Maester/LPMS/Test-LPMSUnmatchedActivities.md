Checks that all Graph API activity recorded for each service principal could be matched to a known Microsoft Graph endpoint for least-privilege permission analysis.

When a service principal makes a Graph API call that cannot be matched to a known endpoint pattern, the **LeastPrivilegedMSGraph** permission analysis is incomplete for that application. The tool cannot determine the minimum required permission for the unmatched call, which means:

- Its **ExcessPermissions** result may be understated — some permissions reported as excess might actually be required.
- Its **OptimalPermissions** result may be missing entries for the unmatched endpoints.
- Permission reduction recommendations for that application should not be applied without manual review.

Unmatched activities most commonly occur because:

1. The application is using an **undocumented or deprecated endpoint**.
2. The endpoint pattern involves an unusual path that the tokeniser did not normalise correctly.
3. The official documentation for the MSGraph api endpoints and least privileged permissions has not yet been updated.

#### Remediation action:

For each application listed below:

1. Review the unmatched endpoint(s) shown in the results table.
2. Check whether the endpoint corresponds to a known Graph API operation in the [Microsoft Graph API reference](https://learn.microsoft.com/en-us/graph/api/overview).
3. If the endpoint is a beta API, consider creating an issue for themapping to the [microsoft-graph-devx-content repo](https://github.com/microsoftgraph/microsoft-graph-devx-content).(Specifically using the **permissions.json** document here **/permissions/new/permissions.json**)
4. Until the endpoint is mapped, do **not** remove any permissions from this application without a manual permissions audit.

#### Related links

* [Microsoft Graph API reference](https://learn.microsoft.com/en-us/graph/api/overview)
* [microsoft-graph-devx-content repo](https://github.com/microsoftgraph/microsoft-graph-devx-content)
* [MSGraphPermissions module](https://github.com/mynster9361/MSGraphPermissions)
* [LeastPrivilegedMSGraph module](https://github.com/Mynster9361/LeastPrivilegedMSGraph)

<!--- Results --->

%TestResult%
