Checks that no service principal is experiencing Warning-level (10-25%) or Critical-level (>25%) Microsoft Graph API throttling during the analysis window.

Graph API throttling occurs when an application exceeds the per-tenant or per-app request rate limits enforced by Microsoft. When a service principal is throttled, the Microsoft Graph service returns HTTP 429 (Too Many Requests), which causes failures and degraded performance for users.

Persistent or high throttle rates may indicate:

- **Polling loops** — the application is continuously querying the same endpoint instead of using change notifications (delta queries or webhooks).
- **Missing batching** — the application makes individual API calls instead of using the `$batch` endpoint.
- **Missing retry logic** — the application retries immediately on 429 instead of honouring the `Retry-After` header.
- **Unintended runaway jobs** — a scheduled task or background worker that is executing more frequently than intended.

#### Remediation action:

For each throttled application listed below:

1. Review the application owner and determine whether the throttle rate is expected (e.g., an intentional bulk-data migration job).
2. If unexpected, inspect the application's Graph API call patterns using the Log Analytics `MicrosoftGraphActivityLogs` table.
3. Implement the following optimisations where applicable:
   - Use [delta queries](https://learn.microsoft.com/en-us/graph/delta-query-overview) or [change notifications](https://learn.microsoft.com/en-us/graph/change-notifications-overview) instead of polling.
   - Use the [`$batch` endpoint](https://learn.microsoft.com/en-us/graph/json-batching) to combine multiple requests.
   - Implement exponential back-off with `Retry-After` header support.
   - Cache frequently read data locally to reduce repeated Graph API calls.

#### Related links

* [Microsoft Graph — Throttling guidance](https://learn.microsoft.com/en-us/graph/throttling)
* [Microsoft Graph — Best practices](https://learn.microsoft.com/en-us/graph/best-practices-concept)
* [Microsoft Graph — Delta queries](https://learn.microsoft.com/en-us/graph/delta-query-overview)
* [Microsoft Graph — Change notifications](https://learn.microsoft.com/en-us/graph/change-notifications-overview) 
* [Microsoft Graph — JSON batching](https://learn.microsoft.com/en-us/graph/json-batching)

<!--- Results --->

%TestResult%
