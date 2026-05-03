import { AppData } from './types';

// Anonymized sample data for development. Real names/IDs have been replaced.
// DO NOT commit real tenant data here.
const sampleData: AppData[] = [
    {
        PrincipalId: "aaaaaaaa-0001-0001-0001-aaaaaaaaaaaa",
        PrincipalName: "Contoso SSO App",
        AppRoleCount: 3,
        AppRoles: [
            { appRoleId: "64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0", FriendlyName: "email", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "Principal" },
            { appRoleId: "37f7f235-527c-4136-accd-4a02d197296e", FriendlyName: "openid", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "Principal" },
            { appRoleId: "14dad69e-099b-42c9-810b-d002981feec1", FriendlyName: "profile", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "Principal" }
        ],
        Activity: null,
        ThrottlingStats: { TotalRequests: 0, SuccessfulRequests: 0, Total429Errors: 0, TotalClientErrors: 0, TotalServerErrors: 0, ThrottleRate: 0, ErrorRate: 0, SuccessRate: 0, ThrottlingSeverity: 0, ThrottlingStatus: "No Activity", FirstOccurrence: null, LastOccurrence: null },
        ActivityPermissions: [],
        OptimalPermissions: [],
        UnmatchedActivities: [],
        CurrentPermissions: [
            { Permission: "email", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "openid", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "profile", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" }
        ],
        ExcessPermissions: [
            { Permission: "email", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "openid", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "profile", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" }
        ],
        RequiredPermissions: [],
        MatchedAllActivity: true
    },
    {
        PrincipalId: "aaaaaaaa-0002-0002-0002-aaaaaaaaaaaa",
        PrincipalName: "Contoso Directory Sync",
        AppRoleCount: 4,
        AppRoles: [
            { appRoleId: "7ab1d382-f21e-4acd-a863-ba3e13f7da61", FriendlyName: "Directory.Read.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null },
            { appRoleId: "df021288-bdef-4463-88db-98f22de89214", FriendlyName: "User.Read.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null },
            { appRoleId: "a154be20-db9c-4678-8ab7-66f6cc099a59", FriendlyName: "User.Read.All", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" },
            { appRoleId: "e1fe6dd8-ba31-4d61-89e7-88639da4683d", FriendlyName: "User.Read", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" }
        ],
        Activity: [
            { Method: "GET", Uri: "https://graph.microsoft.com/v1.0/applications/{id}", Scheme: "Application" },
            { Method: "GET", Uri: "https://graph.microsoft.com/v1.0/servicePrincipals/{id}", Scheme: "Application" },
            { Method: "GET", Uri: "https://graph.microsoft.com/v1.0/users", Scheme: "Application" }
        ],
        ThrottlingStats: { TotalRequests: 445, SuccessfulRequests: 183, Total429Errors: 0, TotalClientErrors: 262, TotalServerErrors: 0, ThrottleRate: 0, ErrorRate: 58.88, SuccessRate: 41.12, ThrottlingSeverity: 0, ThrottlingStatus: "Normal", FirstOccurrence: "2026-04-28T19:57:32Z", LastOccurrence: "2026-05-03T18:56:45Z" },
        ActivityPermissions: [
            { Method: "GET", Version: "v1.0", Path: "/applications/{id}", OriginalUri: "https://graph.microsoft.com/v1.0/applications/{id}", MatchedEndpoint: "/applications/{id}", LeastPrivilegedPermissions: { Permission: "Application.Read.All", ScopeType: "Application", IsLeastPrivilege: true }, IsMatched: true },
            { Method: "GET", Version: "v1.0", Path: "/servicePrincipals/{id}", OriginalUri: "https://graph.microsoft.com/v1.0/servicePrincipals/{id}", MatchedEndpoint: "/servicePrincipals/{id}", LeastPrivilegedPermissions: { Permission: "Application.Read.All", ScopeType: "Application", IsLeastPrivilege: true }, IsMatched: true },
            { Method: "GET", Version: "v1.0", Path: "/users", OriginalUri: "https://graph.microsoft.com/v1.0/users", MatchedEndpoint: "/users", LeastPrivilegedPermissions: { Permission: "User.ReadBasic.All", ScopeType: "Application", IsLeastPrivilege: true }, IsMatched: true }
        ],
        OptimalPermissions: [
            { Permission: "User.ReadBasic.All", ScopeType: "Application", PrivilegeLevel: 2, RiskLabel: "Medium", ActivitiesCovered: 1, Activities: [{ Method: "GET", Version: "v1.0", Path: "/users", Uri: "https://graph.microsoft.com/v1.0/users" }] },
            { Permission: "Application.Read.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High", ActivitiesCovered: 2, Activities: [{ Method: "GET", Version: "v1.0", Path: "/applications/{id}", Uri: "https://graph.microsoft.com/v1.0/applications/{id}" }, { Method: "GET", Version: "v1.0", Path: "/servicePrincipals/{id}", Uri: "https://graph.microsoft.com/v1.0/servicePrincipals/{id}" }] }
        ],
        UnmatchedActivities: null,
        CurrentPermissions: [
            { Permission: "Directory.Read.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High" },
            { Permission: "User.Read.All", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" },
            { Permission: "User.Read.All", ScopeType: "Delegated", PrivilegeLevel: 3, RiskLabel: "High" },
            { Permission: "User.Read", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" }
        ],
        ExcessPermissions: [
            { Permission: "Directory.Read.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High" },
            { Permission: "User.Read.All", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" },
            { Permission: "User.Read.All", ScopeType: "Delegated", PrivilegeLevel: 3, RiskLabel: "High" },
            { Permission: "User.Read", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" }
        ],
        RequiredPermissions: [{ Permission: "Application.Read.All", ScopeType: "Application" }],
        MatchedAllActivity: true
    },
    {
        PrincipalId: "aaaaaaaa-0003-0003-0003-aaaaaaaaaaaa",
        PrincipalName: "Contoso Identity Provider",
        AppRoleCount: 4,
        AppRoles: [
            { appRoleId: "64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0", FriendlyName: "email", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "Principal" },
            { appRoleId: "37f7f235-527c-4136-accd-4a02d197296e", FriendlyName: "openid", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "Principal" },
            { appRoleId: "14dad69e-099b-42c9-810b-d002981feec1", FriendlyName: "profile", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "Principal" },
            { appRoleId: "e1fe6dd8-ba31-4d61-89e7-88639da4683d", FriendlyName: "User.Read", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "Principal" }
        ],
        Activity: null,
        ThrottlingStats: { TotalRequests: 0, SuccessfulRequests: 0, Total429Errors: 0, TotalClientErrors: 0, TotalServerErrors: 0, ThrottleRate: 0, ErrorRate: 0, SuccessRate: 0, ThrottlingSeverity: 0, ThrottlingStatus: "No Activity", FirstOccurrence: null, LastOccurrence: null },
        ActivityPermissions: [],
        OptimalPermissions: [],
        UnmatchedActivities: [],
        CurrentPermissions: [
            { Permission: "email", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "openid", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "profile", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "User.Read", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" }
        ],
        ExcessPermissions: [
            { Permission: "email", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "openid", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "profile", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "User.Read", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" }
        ],
        RequiredPermissions: [],
        MatchedAllActivity: true
    },
    {
        PrincipalId: "aaaaaaaa-0004-0004-0004-aaaaaaaaaaaa",
        PrincipalName: "Contoso HR Portal",
        AppRoleCount: 5,
        AppRoles: [
            { appRoleId: "64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0", FriendlyName: "email", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" },
            { appRoleId: "7427e0e9-2fba-42fe-b0c0-848c9e6a8182", FriendlyName: "offline_access", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" },
            { appRoleId: "37f7f235-527c-4136-accd-4a02d197296e", FriendlyName: "openid", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" },
            { appRoleId: "14dad69e-099b-42c9-810b-d002981feec1", FriendlyName: "profile", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" },
            { appRoleId: "e1fe6dd8-ba31-4d61-89e7-88639da4683d", FriendlyName: "User.Read", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" }
        ],
        Activity: null,
        ThrottlingStats: { TotalRequests: 0, SuccessfulRequests: 0, Total429Errors: 0, TotalClientErrors: 0, TotalServerErrors: 0, ThrottleRate: 0, ErrorRate: 0, SuccessRate: 0, ThrottlingSeverity: 0, ThrottlingStatus: "No Activity", FirstOccurrence: null, LastOccurrence: null },
        ActivityPermissions: [],
        OptimalPermissions: [],
        UnmatchedActivities: [],
        CurrentPermissions: [
            { Permission: "email", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "offline_access", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "openid", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "profile", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "User.Read", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" }
        ],
        ExcessPermissions: [
            { Permission: "email", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "offline_access", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "openid", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "profile", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "User.Read", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" }
        ],
        RequiredPermissions: [],
        MatchedAllActivity: true
    },
    {
        PrincipalId: "aaaaaaaa-0005-0005-0005-aaaaaaaaaaaa",
        PrincipalName: "Contoso BI Connector",
        AppRoleCount: 5,
        AppRoles: [
            { appRoleId: "64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0", FriendlyName: "email", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" },
            { appRoleId: "7427e0e9-2fba-42fe-b0c0-848c9e6a8182", FriendlyName: "offline_access", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" },
            { appRoleId: "37f7f235-527c-4136-accd-4a02d197296e", FriendlyName: "openid", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" },
            { appRoleId: "14dad69e-099b-42c9-810b-d002981feec1", FriendlyName: "profile", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" },
            { appRoleId: "e1fe6dd8-ba31-4d61-89e7-88639da4683d", FriendlyName: "User.Read", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" }
        ],
        Activity: null,
        ThrottlingStats: { TotalRequests: 0, SuccessfulRequests: 0, Total429Errors: 0, TotalClientErrors: 0, TotalServerErrors: 0, ThrottleRate: 0, ErrorRate: 0, SuccessRate: 0, ThrottlingSeverity: 0, ThrottlingStatus: "No Activity", FirstOccurrence: null, LastOccurrence: null },
        ActivityPermissions: [],
        OptimalPermissions: [],
        UnmatchedActivities: [],
        CurrentPermissions: [
            { Permission: "email", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "offline_access", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "openid", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "profile", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "User.Read", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" }
        ],
        ExcessPermissions: [
            { Permission: "email", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "offline_access", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "openid", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "profile", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "User.Read", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" }
        ],
        RequiredPermissions: [],
        MatchedAllActivity: true
    },
    {
        PrincipalId: "aaaaaaaa-0006-0006-0006-aaaaaaaaaaaa",
        PrincipalName: "Contoso SharePoint Archiver",
        AppRoleCount: 6,
        AppRoles: [
            { appRoleId: "64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0", FriendlyName: "email", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" },
            { appRoleId: "7427e0e9-2fba-42fe-b0c0-848c9e6a8182", FriendlyName: "offline_access", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" },
            { appRoleId: "37f7f235-527c-4136-accd-4a02d197296e", FriendlyName: "openid", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" },
            { appRoleId: "14dad69e-099b-42c9-810b-d002981feec1", FriendlyName: "profile", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" },
            { appRoleId: "883ea226-0bf2-4a8f-9f9d-92c9162a727d", FriendlyName: "Sites.Selected", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null },
            { appRoleId: "e1fe6dd8-ba31-4d61-89e7-88639da4683d", FriendlyName: "User.Read", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" }
        ],
        Activity: [{ Method: "GET", Uri: "https://graph.microsoft.com/v1.0/sites/{id}/lists/{id}/items", Scheme: "Application" }],
        ThrottlingStats: { TotalRequests: 5, SuccessfulRequests: 5, Total429Errors: 0, TotalClientErrors: 0, TotalServerErrors: 0, ThrottleRate: 0, ErrorRate: 0, SuccessRate: 100, ThrottlingSeverity: 0, ThrottlingStatus: "Normal", FirstOccurrence: "2026-04-29T08:51:04Z", LastOccurrence: "2026-04-30T10:12:21Z" },
        ActivityPermissions: [
            { Method: "GET", Version: "v1.0", Path: "/sites/{id}/lists/{id}/items", OriginalUri: "https://graph.microsoft.com/v1.0/sites/{id}/lists/{id}/items", MatchedEndpoint: "/sites/{id}/lists/{id}/items", LeastPrivilegedPermissions: { Permission: "Sites.Read.All", ScopeType: "Application", IsLeastPrivilege: true }, IsMatched: true }
        ],
        OptimalPermissions: [
            { Permission: "Sites.Read.All", ScopeType: "Application", PrivilegeLevel: 2, RiskLabel: "Medium", ActivitiesCovered: 1, Activities: [{ Method: "GET", Version: "v1.0", Path: "/sites/{id}/lists/{id}/items", Uri: "https://graph.microsoft.com/v1.0/sites/{id}/lists/{id}/items" }] }
        ],
        UnmatchedActivities: null,
        CurrentPermissions: [
            { Permission: "email", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "offline_access", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "openid", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "profile", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "Sites.Selected", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" },
            { Permission: "User.Read", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" }
        ],
        ExcessPermissions: [
            { Permission: "email", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "offline_access", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "openid", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "profile", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "Sites.Selected", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" },
            { Permission: "User.Read", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" }
        ],
        RequiredPermissions: [{ Permission: "Sites.Read.All", ScopeType: "Application" }],
        MatchedAllActivity: true
    },
    {
        PrincipalId: "aaaaaaaa-0007-0007-0007-aaaaaaaaaaaa",
        PrincipalName: "Contoso User Automation",
        AppRoleCount: 6,
        AppRoles: [
            { appRoleId: "64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0", FriendlyName: "email", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" },
            { appRoleId: "7427e0e9-2fba-42fe-b0c0-848c9e6a8182", FriendlyName: "offline_access", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" },
            { appRoleId: "37f7f235-527c-4136-accd-4a02d197296e", FriendlyName: "openid", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" },
            { appRoleId: "14dad69e-099b-42c9-810b-d002981feec1", FriendlyName: "profile", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" },
            { appRoleId: "e1fe6dd8-ba31-4d61-89e7-88639da4683d", FriendlyName: "User.Read", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" },
            { appRoleId: "741f803b-c850-494e-b5df-cde7c675a1ca", FriendlyName: "User.ReadWrite.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null }
        ],
        Activity: [
            { Method: "GET", Uri: "https://graph.microsoft.com/v1.0/users", Scheme: "Application" },
            { Method: "PUT", Uri: "https://graph.microsoft.com/v1.0/users/{id}/photo", Scheme: "Application" }
        ],
        ThrottlingStats: { TotalRequests: 101, SuccessfulRequests: 87, Total429Errors: 0, TotalClientErrors: 1, TotalServerErrors: 0, ThrottleRate: 0, ErrorRate: 0.99, SuccessRate: 86.14, ThrottlingSeverity: 0, ThrottlingStatus: "Normal", FirstOccurrence: "2026-04-28T21:03:52Z", LastOccurrence: "2026-05-03T10:01:46Z" },
        ActivityPermissions: [
            { Method: "GET", Version: "v1.0", Path: "/users", OriginalUri: "https://graph.microsoft.com/v1.0/users", MatchedEndpoint: "/users", LeastPrivilegedPermissions: { Permission: "User.ReadBasic.All", ScopeType: "Application", IsLeastPrivilege: true }, IsMatched: true },
            { Method: "PUT", Version: "v1.0", Path: "/users/{id}/photo", OriginalUri: "https://graph.microsoft.com/v1.0/users/{id}/photo", MatchedEndpoint: "/users/{id}/photo", LeastPrivilegedPermissions: { Permission: "ProfilePhoto.ReadWrite.All", ScopeType: "Application", IsLeastPrivilege: true }, IsMatched: true }
        ],
        OptimalPermissions: [
            { Permission: "ProfilePhoto.ReadWrite.All", ScopeType: "Application", PrivilegeLevel: 2, RiskLabel: "Medium", ActivitiesCovered: 1, Activities: [{ Method: "PUT", Version: "v1.0", Path: "/users/{id}/photo", Uri: "https://graph.microsoft.com/v1.0/users/{id}/photo" }] },
            { Permission: "User.ReadBasic.All", ScopeType: "Application", PrivilegeLevel: 2, RiskLabel: "Medium", ActivitiesCovered: 1, Activities: [{ Method: "GET", Version: "v1.0", Path: "/users", Uri: "https://graph.microsoft.com/v1.0/users" }] }
        ],
        UnmatchedActivities: null,
        CurrentPermissions: [
            { Permission: "email", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "offline_access", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "openid", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "profile", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "User.Read", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" },
            { Permission: "User.ReadWrite.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High" }
        ],
        ExcessPermissions: [
            { Permission: "email", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "offline_access", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "openid", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "profile", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "User.ReadWrite.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High" }
        ],
        RequiredPermissions: [{ Permission: "User.Read", ScopeType: "Application" }],
        MatchedAllActivity: true
    },
    {
        PrincipalId: "aaaaaaaa-0008-0008-0008-aaaaaaaaaaaa",
        PrincipalName: "Contoso Governance Scanner",
        AppRoleCount: 2,
        AppRoles: [],
        Activity: [],
        ThrottlingStats: { TotalRequests: 312, SuccessfulRequests: 298, Total429Errors: 14, TotalClientErrors: 0, TotalServerErrors: 0, ThrottleRate: 4.49, ErrorRate: 4.49, SuccessRate: 95.51, ThrottlingSeverity: 2, ThrottlingStatus: "Low", FirstOccurrence: "2026-04-28T07:12:00Z", LastOccurrence: "2026-05-03T03:19:04Z" },
        ActivityPermissions: [],
        OptimalPermissions: [],
        UnmatchedActivities: null,
        CurrentPermissions: [],
        ExcessPermissions: [{ Permission: "RoleManagement.ReadWrite.Directory", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" }],
        RequiredPermissions: [{ Permission: "Directory.Read.All", ScopeType: "Application" }],
        MatchedAllActivity: true
    },
    {
        PrincipalId: "aaaaaaaa-0009-0009-0009-aaaaaaaaaaaa",
        PrincipalName: "Contoso Mail Service",
        AppRoleCount: 2,
        AppRoles: [],
        Activity: null,
        ThrottlingStats: { TotalRequests: 0, SuccessfulRequests: 0, Total429Errors: 0, TotalClientErrors: 0, TotalServerErrors: 0, ThrottleRate: 0, ErrorRate: 0, SuccessRate: 0, ThrottlingSeverity: 0, ThrottlingStatus: "No Activity", FirstOccurrence: null, LastOccurrence: null },
        ActivityPermissions: [],
        OptimalPermissions: [],
        UnmatchedActivities: [],
        CurrentPermissions: [],
        ExcessPermissions: [],
        RequiredPermissions: [],
        MatchedAllActivity: true
    },
    {
        PrincipalId: "aaaaaaaa-0010-0010-0010-aaaaaaaaaaaa",
        PrincipalName: "Contoso Azure Gov Viz",
        AppRoleCount: 3,
        AppRoles: [],
        Activity: null,
        ThrottlingStats: { TotalRequests: 0, SuccessfulRequests: 0, Total429Errors: 0, TotalClientErrors: 0, TotalServerErrors: 0, ThrottleRate: 0, ErrorRate: 0, SuccessRate: 0, ThrottlingSeverity: 0, ThrottlingStatus: "No Activity", FirstOccurrence: null, LastOccurrence: null },
        ActivityPermissions: [],
        OptimalPermissions: [],
        UnmatchedActivities: [],
        CurrentPermissions: [],
        ExcessPermissions: [],
        RequiredPermissions: [],
        MatchedAllActivity: true
    },
    {
        PrincipalId: "aaaaaaaa-0011-0011-0011-aaaaaaaaaaaa",
        PrincipalName: "Contoso PIT API Client",
        AppRoleCount: 1,
        AppRoles: [{ appRoleId: "9e3f62cf-ca93-4989-b6ce-bf83047a90c6", FriendlyName: "User.ReadWrite.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" }],
        Activity: null,
        ThrottlingStats: { TotalRequests: 0, SuccessfulRequests: 0, Total429Errors: 0, TotalClientErrors: 0, TotalServerErrors: 0, ThrottleRate: 0, ErrorRate: 0, SuccessRate: 0, ThrottlingSeverity: 0, ThrottlingStatus: "No Activity", FirstOccurrence: null, LastOccurrence: null },
        ActivityPermissions: [],
        OptimalPermissions: [],
        UnmatchedActivities: [],
        CurrentPermissions: [{ Permission: "User.ReadWrite.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High" }],
        ExcessPermissions: [{ Permission: "User.ReadWrite.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High" }],
        RequiredPermissions: [],
        MatchedAllActivity: true
    },
    {
        PrincipalId: "aaaaaaaa-0012-0012-0012-aaaaaaaaaaaa",
        PrincipalName: "Contoso Cloud Storage Sync",
        AppRoleCount: 5,
        AppRoles: [],
        Activity: null,
        ThrottlingStats: { TotalRequests: 0, SuccessfulRequests: 0, Total429Errors: 0, TotalClientErrors: 0, TotalServerErrors: 0, ThrottleRate: 0, ErrorRate: 0, SuccessRate: 0, ThrottlingSeverity: 0, ThrottlingStatus: "No Activity", FirstOccurrence: null, LastOccurrence: null },
        ActivityPermissions: [],
        OptimalPermissions: [],
        UnmatchedActivities: [],
        CurrentPermissions: [],
        ExcessPermissions: [],
        RequiredPermissions: [],
        MatchedAllActivity: true
    },
    {
        PrincipalId: "aaaaaaaa-0013-0013-0013-aaaaaaaaaaaa",
        PrincipalName: "Contoso v1-reg-f0ad894d",
        AppRoleCount: 4,
        AppRoles: [],
        Activity: [],
        ThrottlingStats: { TotalRequests: 1248, SuccessfulRequests: 1201, Total429Errors: 47, TotalClientErrors: 0, TotalServerErrors: 0, ThrottleRate: 3.77, ErrorRate: 3.77, SuccessRate: 96.23, ThrottlingSeverity: 2, ThrottlingStatus: "Low", FirstOccurrence: "2026-04-28T06:00:00Z", LastOccurrence: "2026-05-03T19:31:51Z" },
        ActivityPermissions: [],
        OptimalPermissions: [],
        UnmatchedActivities: null,
        CurrentPermissions: [],
        ExcessPermissions: [],
        RequiredPermissions: [{ Permission: "User.Read.All", ScopeType: "Application" }],
        MatchedAllActivity: true
    },
    {
        PrincipalId: "aaaaaaaa-0014-0014-0014-aaaaaaaaaaaa",
        PrincipalName: "Contoso Foundspot Integration",
        AppRoleCount: 1,
        AppRoles: [{ appRoleId: "64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0", FriendlyName: "email", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "Principal" }],
        Activity: null,
        ThrottlingStats: { TotalRequests: 0, SuccessfulRequests: 0, Total429Errors: 0, TotalClientErrors: 0, TotalServerErrors: 0, ThrottleRate: 0, ErrorRate: 0, SuccessRate: 0, ThrottlingSeverity: 0, ThrottlingStatus: "No Activity", FirstOccurrence: null, LastOccurrence: null },
        ActivityPermissions: [],
        OptimalPermissions: [],
        UnmatchedActivities: [],
        CurrentPermissions: [{ Permission: "User.ReadWrite.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High" }],
        ExcessPermissions: [{ Permission: "User.ReadWrite.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High" }],
        RequiredPermissions: [],
        MatchedAllActivity: true
    },
    {
        PrincipalId: "aaaaaaaa-0015-0015-0015-aaaaaaaaaaaa",
        PrincipalName: "Contoso Collaboration App",
        AppRoleCount: 4,
        AppRoles: [],
        Activity: null,
        ThrottlingStats: { TotalRequests: 0, SuccessfulRequests: 0, Total429Errors: 0, TotalClientErrors: 0, TotalServerErrors: 0, ThrottleRate: 0, ErrorRate: 0, SuccessRate: 0, ThrottlingSeverity: 0, ThrottlingStatus: "No Activity", FirstOccurrence: null, LastOccurrence: null },
        ActivityPermissions: [],
        OptimalPermissions: [],
        UnmatchedActivities: [],
        CurrentPermissions: [],
        ExcessPermissions: [],
        RequiredPermissions: [],
        MatchedAllActivity: true
    },
    {
        PrincipalId: "aaaaaaaa-0016-0016-0016-aaaaaaaaaaaa",
        PrincipalName: "Contoso v1-reg-83d8c15f",
        AppRoleCount: 4,
        AppRoles: [],
        Activity: [],
        ThrottlingStats: { TotalRequests: 892, SuccessfulRequests: 856, Total429Errors: 36, TotalClientErrors: 0, TotalServerErrors: 0, ThrottleRate: 4.04, ErrorRate: 4.04, SuccessRate: 95.96, ThrottlingSeverity: 2, ThrottlingStatus: "Low", FirstOccurrence: "2026-04-28T09:00:00Z", LastOccurrence: "2026-05-03T19:28:24Z" },
        ActivityPermissions: [],
        OptimalPermissions: [],
        UnmatchedActivities: null,
        CurrentPermissions: [],
        ExcessPermissions: [],
        RequiredPermissions: [{ Permission: "Group.Read.All", ScopeType: "Application" }],
        MatchedAllActivity: true
    },
    {
        PrincipalId: "aaaaaaaa-0017-0017-0017-aaaaaaaaaaaa",
        PrincipalName: "Contoso E-Commerce Integration",
        AppRoleCount: 5,
        AppRoles: [],
        Activity: null,
        ThrottlingStats: { TotalRequests: 0, SuccessfulRequests: 0, Total429Errors: 0, TotalClientErrors: 0, TotalServerErrors: 0, ThrottleRate: 0, ErrorRate: 0, SuccessRate: 0, ThrottlingSeverity: 0, ThrottlingStatus: "No Activity", FirstOccurrence: null, LastOccurrence: null },
        ActivityPermissions: [],
        OptimalPermissions: [],
        UnmatchedActivities: [],
        CurrentPermissions: [],
        ExcessPermissions: [],
        RequiredPermissions: [],
        MatchedAllActivity: true
    },
    {
        PrincipalId: "aaaaaaaa-0018-0018-0018-aaaaaaaaaaaa",
        PrincipalName: "Contoso Internal Tooling",
        AppRoleCount: 5,
        AppRoles: [],
        Activity: null,
        ThrottlingStats: { TotalRequests: 0, SuccessfulRequests: 0, Total429Errors: 0, TotalClientErrors: 0, TotalServerErrors: 0, ThrottleRate: 0, ErrorRate: 0, SuccessRate: 0, ThrottlingSeverity: 0, ThrottlingStatus: "No Activity", FirstOccurrence: null, LastOccurrence: null },
        ActivityPermissions: [],
        OptimalPermissions: [],
        UnmatchedActivities: [],
        CurrentPermissions: [],
        ExcessPermissions: [],
        RequiredPermissions: [],
        MatchedAllActivity: true
    },
    {
        PrincipalId: "aaaaaaaa-0019-0019-0019-aaaaaaaaaaaa",
        PrincipalName: "Contoso v1-reg-4a1e0ca0",
        AppRoleCount: 4,
        AppRoles: [],
        Activity: [],
        ThrottlingStats: { TotalRequests: 2187, SuccessfulRequests: 2100, Total429Errors: 87, TotalClientErrors: 0, TotalServerErrors: 0, ThrottleRate: 3.98, ErrorRate: 3.98, SuccessRate: 96.02, ThrottlingSeverity: 3, ThrottlingStatus: "Warning", FirstOccurrence: "2026-04-27T12:00:00Z", LastOccurrence: "2026-05-03T18:44:10Z" },
        ActivityPermissions: [],
        OptimalPermissions: [],
        UnmatchedActivities: null,
        CurrentPermissions: [],
        ExcessPermissions: [],
        RequiredPermissions: [{ Permission: "Mail.Read", ScopeType: "Application" }],
        MatchedAllActivity: true
    },
    // --- Extra entries (20-39) modelled on inventory.json patterns ---
    {
        // Simple SSO – only email/openid/profile – no activity, all excess
        PrincipalId: "bbbbbbbb-0020-0020-0020-bbbbbbbbbbbb",
        PrincipalName: "Contoso Planner SSO",
        AppRoleCount: 4,
        AppRoles: [
            { appRoleId: "64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0", FriendlyName: "email", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "Principal" },
            { appRoleId: "7427e0e9-2fba-42fe-b0c0-848c9e6a8182", FriendlyName: "offline_access", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "Principal" },
            { appRoleId: "37f7f235-527c-4136-accd-4a02d197296e", FriendlyName: "openid", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "Principal" },
            { appRoleId: "14dad69e-099b-42c9-810b-d002981feec1", FriendlyName: "profile", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "Principal" }
        ],
        Activity: null,
        ThrottlingStats: { TotalRequests: 0, SuccessfulRequests: 0, Total429Errors: 0, TotalClientErrors: 0, TotalServerErrors: 0, ThrottleRate: 0, ErrorRate: 0, SuccessRate: 0, ThrottlingSeverity: 0, ThrottlingStatus: "No Activity", FirstOccurrence: null, LastOccurrence: null },
        ActivityPermissions: [],
        OptimalPermissions: [],
        UnmatchedActivities: [],
        CurrentPermissions: [
            { Permission: "email", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "offline_access", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "openid", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "profile", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" }
        ],
        ExcessPermissions: [
            { Permission: "email", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "offline_access", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "openid", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "profile", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" }
        ],
        RequiredPermissions: [],
        MatchedAllActivity: true
    },
    {
        // File sync app – high-privilege files permissions, no activity
        PrincipalId: "bbbbbbbb-0021-0021-0021-bbbbbbbbbbbb",
        PrincipalName: "Contoso File Sync Client",
        AppRoleCount: 5,
        AppRoles: [
            { appRoleId: "df85f4d6-205c-4ac5-a5ea-6bf408dba283", FriendlyName: "Files.Read.All", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "Principal" },
            { appRoleId: "10465720-29dd-4523-a11a-6a75c743c9d9", FriendlyName: "Files.Read", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "Principal" },
            { appRoleId: "863451e7-0667-486c-a5d6-d135439485f0", FriendlyName: "Files.ReadWrite.All", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "Principal" },
            { appRoleId: "5c28f0bf-8a70-41f1-8ab2-9032436ddb65", FriendlyName: "Files.ReadWrite", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "Principal" },
            { appRoleId: "7427e0e9-2fba-42fe-b0c0-848c9e6a8182", FriendlyName: "offline_access", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "Principal" }
        ],
        Activity: null,
        ThrottlingStats: { TotalRequests: 0, SuccessfulRequests: 0, Total429Errors: 0, TotalClientErrors: 0, TotalServerErrors: 0, ThrottleRate: 0, ErrorRate: 0, SuccessRate: 0, ThrottlingSeverity: 0, ThrottlingStatus: "No Activity", FirstOccurrence: null, LastOccurrence: null },
        ActivityPermissions: [],
        OptimalPermissions: [],
        UnmatchedActivities: [],
        CurrentPermissions: [
            { Permission: "Files.Read.All", ScopeType: "Delegated", PrivilegeLevel: 3, RiskLabel: "High" },
            { Permission: "Files.Read", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" },
            { Permission: "Files.ReadWrite.All", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" },
            { Permission: "Files.ReadWrite", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" },
            { Permission: "offline_access", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" }
        ],
        ExcessPermissions: [
            { Permission: "Files.Read.All", ScopeType: "Delegated", PrivilegeLevel: 3, RiskLabel: "High" },
            { Permission: "Files.Read", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" },
            { Permission: "Files.ReadWrite.All", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" },
            { Permission: "Files.ReadWrite", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" },
            { Permission: "offline_access", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" }
        ],
        RequiredPermissions: [],
        MatchedAllActivity: true
    },
    {
        // Mail service – critical Mail.ReadWrite, no activity (high-risk idle)
        PrincipalId: "bbbbbbbb-0022-0022-0022-bbbbbbbbbbbb",
        PrincipalName: "Contoso Helpdesk Mail Reader",
        AppRoleCount: 2,
        AppRoles: [
            { appRoleId: "e2a3a72e-5f79-4c64-b1b1-878b674786c9", FriendlyName: "Mail.ReadWrite", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null },
            { appRoleId: "97235f07-e226-4f63-ace3-39588e11d3a1", FriendlyName: "User.ReadBasic.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null }
        ],
        Activity: null,
        ThrottlingStats: { TotalRequests: 0, SuccessfulRequests: 0, Total429Errors: 0, TotalClientErrors: 0, TotalServerErrors: 0, ThrottleRate: 0, ErrorRate: 0, SuccessRate: 0, ThrottlingSeverity: 0, ThrottlingStatus: "No Activity", FirstOccurrence: null, LastOccurrence: null },
        ActivityPermissions: [],
        OptimalPermissions: [],
        UnmatchedActivities: [],
        CurrentPermissions: [
            { Permission: "Mail.ReadWrite", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" },
            { Permission: "User.ReadBasic.All", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" }
        ],
        ExcessPermissions: [
            { Permission: "Mail.ReadWrite", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" },
            { Permission: "User.ReadBasic.All", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" }
        ],
        RequiredPermissions: [],
        MatchedAllActivity: true
    },
    {
        // Security SIEM – active, MatchedAllActivity false (unmatched endpoints)
        PrincipalId: "bbbbbbbb-0023-0023-0023-bbbbbbbbbbbb",
        PrincipalName: "Contoso SIEM Connector",
        AppRoleCount: 7,
        AppRoles: [
            { appRoleId: "b0afded3-3588-46d8-8b3d-9842eff778da", FriendlyName: "AuditLog.Read.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null },
            { appRoleId: "7ab1d382-f21e-4acd-a863-ba3e13f7da61", FriendlyName: "Directory.Read.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null },
            { appRoleId: "6e472fd1-ad78-48da-a0f0-97ab2c6b769e", FriendlyName: "IdentityRiskEvent.Read.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null },
            { appRoleId: "ed4fca05-be46-441f-9803-1873825f8fdb", FriendlyName: "SecurityAlert.ReadWrite.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null },
            { appRoleId: "34bf0e97-1971-4929-b999-9e2442d941d7", FriendlyName: "SecurityIncident.ReadWrite.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null },
            { appRoleId: "df021288-bdef-4463-88db-98f22de89214", FriendlyName: "User.Read.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null },
            { appRoleId: "e1fe6dd8-ba31-4d61-89e7-88639da4683d", FriendlyName: "User.Read", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" }
        ],
        Activity: [
            { Method: "GET", Uri: "https://graph.microsoft.com/v1.0/security/incidents", Scheme: "Application" },
            { Method: "PATCH", Uri: "https://graph.microsoft.com/v1.0/security/incidents/{id}", Scheme: "Application" },
            { Method: "GET", Uri: "https://graph.microsoft.com/v1.0/security/{id}", Scheme: "Application" },
            { Method: "PATCH", Uri: "https://graph.microsoft.com/v1.0/security/{id}/{id}", Scheme: "Application" }
        ],
        ThrottlingStats: { TotalRequests: 10058, SuccessfulRequests: 10044, Total429Errors: 0, TotalClientErrors: 14, TotalServerErrors: 0, ThrottleRate: 0, ErrorRate: 0.14, SuccessRate: 99.86, ThrottlingSeverity: 0, ThrottlingStatus: "Normal", FirstOccurrence: "2026-04-26T20:00:05Z", LastOccurrence: "2026-05-03T18:00:21Z" },
        ActivityPermissions: [
            { Method: "GET", Version: "v1.0", Path: "/security/incidents", OriginalUri: "https://graph.microsoft.com/v1.0/security/incidents", MatchedEndpoint: "/security/incidents", LeastPrivilegedPermissions: { Permission: "SecurityIncident.Read.All", ScopeType: "Application", IsLeastPrivilege: true }, IsMatched: true },
            { Method: "PATCH", Version: "v1.0", Path: "/security/incidents/{id}", OriginalUri: "https://graph.microsoft.com/v1.0/security/incidents/{id}", MatchedEndpoint: "/security/incidents/{id}", LeastPrivilegedPermissions: { Permission: "SecurityIncident.ReadWrite.All", ScopeType: "Application", IsLeastPrivilege: true }, IsMatched: true },
            { Method: "GET", Version: "v1.0", Path: "/security/{id}", OriginalUri: "https://graph.microsoft.com/v1.0/security/{id}", MatchedEndpoint: null, LeastPrivilegedPermissions: [], IsMatched: false },
            { Method: "PATCH", Version: "v1.0", Path: "/security/{id}/{id}", OriginalUri: "https://graph.microsoft.com/v1.0/security/{id}/{id}", MatchedEndpoint: null, LeastPrivilegedPermissions: [], IsMatched: false }
        ],
        OptimalPermissions: [
            { Permission: "SecurityIncident.ReadWrite.All", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical", ActivitiesCovered: 1, Activities: [{ Method: "PATCH", Version: "v1.0", Path: "/security/incidents/{id}", Uri: "https://graph.microsoft.com/v1.0/security/incidents/{id}" }] },
            { Permission: "SecurityIncident.Read.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High", ActivitiesCovered: 1, Activities: [{ Method: "GET", Version: "v1.0", Path: "/security/incidents", Uri: "https://graph.microsoft.com/v1.0/security/incidents" }] }
        ],
        UnmatchedActivities: [
            { Method: "GET", Version: "v1.0", Path: "/security/{id}", OriginalUri: "https://graph.microsoft.com/v1.0/security/{id}", MatchedEndpoint: null, LeastPrivilegedPermissions: [], IsMatched: false },
            { Method: "PATCH", Version: "v1.0", Path: "/security/{id}/{id}", OriginalUri: "https://graph.microsoft.com/v1.0/security/{id}/{id}", MatchedEndpoint: null, LeastPrivilegedPermissions: [], IsMatched: false }
        ],
        CurrentPermissions: [
            { Permission: "AuditLog.Read.All", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" },
            { Permission: "Directory.Read.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High" },
            { Permission: "IdentityRiskEvent.Read.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High" },
            { Permission: "SecurityAlert.ReadWrite.All", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" },
            { Permission: "SecurityIncident.ReadWrite.All", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" },
            { Permission: "User.Read.All", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" },
            { Permission: "User.Read", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" }
        ],
        ExcessPermissions: [
            { Permission: "AuditLog.Read.All", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" },
            { Permission: "Directory.Read.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High" },
            { Permission: "IdentityRiskEvent.Read.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High" },
            { Permission: "SecurityAlert.ReadWrite.All", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" },
            { Permission: "User.Read.All", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" },
            { Permission: "User.Read", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" }
        ],
        RequiredPermissions: null,
        MatchedAllActivity: false
    },
    {
        // Org sync – active, misaligned (1 excess, 1 missing), high volume
        PrincipalId: "bbbbbbbb-0024-0024-0024-bbbbbbbbbbbb",
        PrincipalName: "Contoso Org Directory Sync",
        AppRoleCount: 2,
        AppRoles: [
            { appRoleId: "498476ce-e0fe-48b0-b801-37ba7e2685c6", FriendlyName: "Organization.Read.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null },
            { appRoleId: "df021288-bdef-4463-88db-98f22de89214", FriendlyName: "User.Read.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null }
        ],
        Activity: [
            { Method: "GET", Uri: "https://graph.microsoft.com/v1.0/organization", Scheme: "Application" },
            { Method: "GET", Uri: "https://graph.microsoft.com/v1.0/users", Scheme: "Application" },
            { Method: "GET", Uri: "https://graph.microsoft.com/v1.0/users/{id}/manager", Scheme: "Application" }
        ],
        ThrottlingStats: { TotalRequests: 11922, SuccessfulRequests: 11910, Total429Errors: 0, TotalClientErrors: 12, TotalServerErrors: 0, ThrottleRate: 0, ErrorRate: 0.1, SuccessRate: 99.9, ThrottlingSeverity: 0, ThrottlingStatus: "Normal", FirstOccurrence: "2026-04-29T12:29:46Z", LastOccurrence: "2026-05-03T12:56:31Z" },
        ActivityPermissions: [
            { Method: "GET", Version: "v1.0", Path: "/organization", OriginalUri: "https://graph.microsoft.com/v1.0/organization", MatchedEndpoint: "/organization", LeastPrivilegedPermissions: { Permission: "DeviceManagementServiceConfig.Read.All", ScopeType: "Application", IsLeastPrivilege: true }, IsMatched: true },
            { Method: "GET", Version: "v1.0", Path: "/users", OriginalUri: "https://graph.microsoft.com/v1.0/users", MatchedEndpoint: "/users", LeastPrivilegedPermissions: { Permission: "User.ReadBasic.All", ScopeType: "Application", IsLeastPrivilege: true }, IsMatched: true },
            { Method: "GET", Version: "v1.0", Path: "/users/{id}/manager", OriginalUri: "https://graph.microsoft.com/v1.0/users/{id}/manager", MatchedEndpoint: "/users/{id}/manager", LeastPrivilegedPermissions: { Permission: "User.Read.All", ScopeType: "Application", IsLeastPrivilege: true }, IsMatched: true }
        ],
        OptimalPermissions: [
            { Permission: "DeviceManagementServiceConfig.Read.All", ScopeType: "Application", PrivilegeLevel: 2, RiskLabel: "Medium", ActivitiesCovered: 1, Activities: [{ Method: "GET", Version: "v1.0", Path: "/organization", Uri: "https://graph.microsoft.com/v1.0/organization" }] },
            { Permission: "User.ReadBasic.All", ScopeType: "Application", PrivilegeLevel: 2, RiskLabel: "Medium", ActivitiesCovered: 1, Activities: [{ Method: "GET", Version: "v1.0", Path: "/users", Uri: "https://graph.microsoft.com/v1.0/users" }] },
            { Permission: "User.Read.All", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical", ActivitiesCovered: 1, Activities: [{ Method: "GET", Version: "v1.0", Path: "/users/{id}/manager", Uri: "https://graph.microsoft.com/v1.0/users/{id}/manager" }] }
        ],
        UnmatchedActivities: null,
        CurrentPermissions: [
            { Permission: "Organization.Read.All", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" },
            { Permission: "User.Read.All", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" }
        ],
        ExcessPermissions: [{ Permission: "Organization.Read.All", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" }],
        RequiredPermissions: [{ Permission: "DeviceManagementServiceConfig.Read.All", ScopeType: "Application" }],
        MatchedAllActivity: true
    },
    {
        // SharePoint app – active, unmatched URLs (MatchedAllActivity false)
        PrincipalId: "bbbbbbbb-0025-0025-0025-bbbbbbbbbbbb",
        PrincipalName: "Contoso Intranet Portal",
        AppRoleCount: 3,
        AppRoles: [
            { appRoleId: "883ea226-0bf2-4a8f-9f9d-92c9162a727d", FriendlyName: "Sites.Selected", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null },
            { appRoleId: "e1fe6dd8-ba31-4d61-89e7-88639da4683d", FriendlyName: "User.Read", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" },
            { appRoleId: "97235f07-e226-4f63-ace3-39588e11d3a1", FriendlyName: "User.ReadBasic.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null }
        ],
        Activity: [
            { Method: "GET", Uri: "https://graph.microsoft.com/v1.0/sites/{id}/lists/Documents/items", Scheme: "Application" },
            { Method: "GET", Uri: "https://graph.microsoft.com/v1.0/sites/contoso.sharepoint.com:/sites/intranet", Scheme: "Application" },
            { Method: "GET", Uri: "https://graph.microsoft.com/v1.0/users/{id}", Scheme: "Application" }
        ],
        ThrottlingStats: { TotalRequests: 814, SuccessfulRequests: 799, Total429Errors: 0, TotalClientErrors: 15, TotalServerErrors: 0, ThrottleRate: 0, ErrorRate: 1.84, SuccessRate: 98.16, ThrottlingSeverity: 0, ThrottlingStatus: "Normal", FirstOccurrence: "2026-04-27T01:00:00Z", LastOccurrence: "2026-05-03T12:00:09Z" },
        ActivityPermissions: [
            { Method: "GET", Version: "v1.0", Path: "/sites/{id}/lists/Documents/items", OriginalUri: "https://graph.microsoft.com/v1.0/sites/{id}/lists/Documents/items", MatchedEndpoint: null, LeastPrivilegedPermissions: [], IsMatched: false },
            { Method: "GET", Version: "v1.0", Path: "/sites/contoso.sharepoint.com:/sites/intranet", OriginalUri: "https://graph.microsoft.com/v1.0/sites/contoso.sharepoint.com:/sites/intranet", MatchedEndpoint: null, LeastPrivilegedPermissions: [], IsMatched: false },
            { Method: "GET", Version: "v1.0", Path: "/users/{id}", OriginalUri: "https://graph.microsoft.com/v1.0/users/{id}", MatchedEndpoint: "/users/{id}", LeastPrivilegedPermissions: { Permission: "User.ReadBasic.All", ScopeType: "Application", IsLeastPrivilege: true }, IsMatched: true }
        ],
        OptimalPermissions: [
            { Permission: "User.ReadBasic.All", ScopeType: "Application", PrivilegeLevel: 2, RiskLabel: "Medium", ActivitiesCovered: 1, Activities: [{ Method: "GET", Version: "v1.0", Path: "/users/{id}", Uri: "https://graph.microsoft.com/v1.0/users/{id}" }] }
        ],
        UnmatchedActivities: [
            { Method: "GET", Version: "v1.0", Path: "/sites/{id}/lists/Documents/items", OriginalUri: "https://graph.microsoft.com/v1.0/sites/{id}/lists/Documents/items", MatchedEndpoint: null, LeastPrivilegedPermissions: [], IsMatched: false },
            { Method: "GET", Version: "v1.0", Path: "/sites/contoso.sharepoint.com:/sites/intranet", OriginalUri: "https://graph.microsoft.com/v1.0/sites/contoso.sharepoint.com:/sites/intranet", MatchedEndpoint: null, LeastPrivilegedPermissions: [], IsMatched: false }
        ],
        CurrentPermissions: [
            { Permission: "Sites.Selected", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" },
            { Permission: "User.Read", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" },
            { Permission: "User.ReadBasic.All", ScopeType: "Application", PrivilegeLevel: 2, RiskLabel: "Medium" }
        ],
        ExcessPermissions: [
            { Permission: "Sites.Selected", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" },
            { Permission: "User.Read", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" }
        ],
        RequiredPermissions: null,
        MatchedAllActivity: false
    },
    {
        // Optimal app – active, matches exactly, no excess, no missing
        PrincipalId: "bbbbbbbb-0026-0026-0026-bbbbbbbbbbbb",
        PrincipalName: "Contoso Calendar Notifier",
        AppRoleCount: 1,
        AppRoles: [
            { appRoleId: "798ee544-9d2d-430c-a058-570e29e34338", FriendlyName: "Calendars.Read", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null }
        ],
        Activity: [
            { Method: "GET", Uri: "https://graph.microsoft.com/v1.0/users/{id}/calendar/events", Scheme: "Application" }
        ],
        ThrottlingStats: { TotalRequests: 542, SuccessfulRequests: 542, Total429Errors: 0, TotalClientErrors: 0, TotalServerErrors: 0, ThrottleRate: 0, ErrorRate: 0, SuccessRate: 100, ThrottlingSeverity: 0, ThrottlingStatus: "Normal", FirstOccurrence: "2026-04-28T08:00:00Z", LastOccurrence: "2026-05-03T08:00:00Z" },
        ActivityPermissions: [
            { Method: "GET", Version: "v1.0", Path: "/users/{id}/calendar/events", OriginalUri: "https://graph.microsoft.com/v1.0/users/{id}/calendar/events", MatchedEndpoint: "/users/{id}/calendar/events", LeastPrivilegedPermissions: { Permission: "Calendars.Read", ScopeType: "Application", IsLeastPrivilege: true }, IsMatched: true }
        ],
        OptimalPermissions: [
            { Permission: "Calendars.Read", ScopeType: "Application", PrivilegeLevel: 2, RiskLabel: "Medium", ActivitiesCovered: 1, Activities: [{ Method: "GET", Version: "v1.0", Path: "/users/{id}/calendar/events", Uri: "https://graph.microsoft.com/v1.0/users/{id}/calendar/events" }] }
        ],
        UnmatchedActivities: null,
        CurrentPermissions: [
            { Permission: "Calendars.Read", ScopeType: "Application", PrivilegeLevel: 2, RiskLabel: "Medium" }
        ],
        ExcessPermissions: [],
        RequiredPermissions: [],
        MatchedAllActivity: true
    },
    {
        // Teams bot – active, multi-endpoint, under-privileged (missing perm)
        PrincipalId: "bbbbbbbb-0027-0027-0027-bbbbbbbbbbbb",
        PrincipalName: "Contoso Teams Meeting Bot",
        AppRoleCount: 3,
        AppRoles: [
            { appRoleId: "a7a681dc-756e-4909-b988-f160edc6655f", FriendlyName: "OnlineMeetings.Read.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null },
            { appRoleId: "b8bb2037-6e08-44ac-a4ea-4674e010e2a4", FriendlyName: "OnlineMeetings.ReadWrite.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null },
            { appRoleId: "e1fe6dd8-ba31-4d61-89e7-88639da4683d", FriendlyName: "User.Read", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" }
        ],
        Activity: [
            { Method: "GET", Uri: "https://graph.microsoft.com/v1.0/me/onlineMeetings", Scheme: "Delegated" },
            { Method: "POST", Uri: "https://graph.microsoft.com/v1.0/users/{id}/onlineMeetings", Scheme: "Application" },
            { Method: "GET", Uri: "https://graph.microsoft.com/v1.0/users/{id}/presence", Scheme: "Application" }
        ],
        ThrottlingStats: { TotalRequests: 3201, SuccessfulRequests: 3187, Total429Errors: 0, TotalClientErrors: 14, TotalServerErrors: 0, ThrottleRate: 0, ErrorRate: 0.44, SuccessRate: 99.56, ThrottlingSeverity: 0, ThrottlingStatus: "Normal", FirstOccurrence: "2026-04-27T09:00:00Z", LastOccurrence: "2026-05-03T17:00:00Z" },
        ActivityPermissions: [
            { Method: "GET", Version: "v1.0", Path: "/me/onlineMeetings", OriginalUri: "https://graph.microsoft.com/v1.0/me/onlineMeetings", MatchedEndpoint: "/me/onlineMeetings", LeastPrivilegedPermissions: { Permission: "OnlineMeetings.Read", ScopeType: "Delegated", IsLeastPrivilege: true }, IsMatched: true },
            { Method: "POST", Version: "v1.0", Path: "/users/{id}/onlineMeetings", OriginalUri: "https://graph.microsoft.com/v1.0/users/{id}/onlineMeetings", MatchedEndpoint: "/users/{id}/onlineMeetings", LeastPrivilegedPermissions: { Permission: "OnlineMeetings.ReadWrite.All", ScopeType: "Application", IsLeastPrivilege: true }, IsMatched: true },
            { Method: "GET", Version: "v1.0", Path: "/users/{id}/presence", OriginalUri: "https://graph.microsoft.com/v1.0/users/{id}/presence", MatchedEndpoint: "/users/{id}/presence", LeastPrivilegedPermissions: { Permission: "Presence.Read.All", ScopeType: "Application", IsLeastPrivilege: true }, IsMatched: true }
        ],
        OptimalPermissions: [
            { Permission: "OnlineMeetings.Read", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium", ActivitiesCovered: 1, Activities: [{ Method: "GET", Version: "v1.0", Path: "/me/onlineMeetings", Uri: "https://graph.microsoft.com/v1.0/me/onlineMeetings" }] },
            { Permission: "OnlineMeetings.ReadWrite.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High", ActivitiesCovered: 1, Activities: [{ Method: "POST", Version: "v1.0", Path: "/users/{id}/onlineMeetings", Uri: "https://graph.microsoft.com/v1.0/users/{id}/onlineMeetings" }] },
            { Permission: "Presence.Read.All", ScopeType: "Application", PrivilegeLevel: 2, RiskLabel: "Medium", ActivitiesCovered: 1, Activities: [{ Method: "GET", Version: "v1.0", Path: "/users/{id}/presence", Uri: "https://graph.microsoft.com/v1.0/users/{id}/presence" }] }
        ],
        UnmatchedActivities: null,
        CurrentPermissions: [
            { Permission: "OnlineMeetings.Read.All", ScopeType: "Application", PrivilegeLevel: 2, RiskLabel: "Medium" },
            { Permission: "OnlineMeetings.ReadWrite.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High" },
            { Permission: "User.Read", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" }
        ],
        ExcessPermissions: [
            { Permission: "OnlineMeetings.Read.All", ScopeType: "Application", PrivilegeLevel: 2, RiskLabel: "Medium" },
            { Permission: "User.Read", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" }
        ],
        RequiredPermissions: [{ Permission: "Presence.Read.All", ScopeType: "Application" }],
        MatchedAllActivity: true
    },
    {
        // High-volume active app – critical throttling (severity 4)
        PrincipalId: "bbbbbbbb-0028-0028-0028-bbbbbbbbbbbb",
        PrincipalName: "Contoso Identity Governance",
        AppRoleCount: 4,
        AppRoles: [
            { appRoleId: "7ab1d382-f21e-4acd-a863-ba3e13f7da61", FriendlyName: "Directory.Read.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null },
            { appRoleId: "df021288-bdef-4463-88db-98f22de89214", FriendlyName: "User.Read.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null },
            { appRoleId: "62a82d76-70ea-41e2-9197-370581804d09", FriendlyName: "Group.ReadWrite.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null },
            { appRoleId: "e1fe6dd8-ba31-4d61-89e7-88639da4683d", FriendlyName: "User.Read", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" }
        ],
        Activity: [
            { Method: "GET", Uri: "https://graph.microsoft.com/v1.0/users", Scheme: "Application" },
            { Method: "GET", Uri: "https://graph.microsoft.com/v1.0/groups", Scheme: "Application" },
            { Method: "PATCH", Uri: "https://graph.microsoft.com/v1.0/groups/{id}", Scheme: "Application" }
        ],
        ThrottlingStats: { TotalRequests: 98420, SuccessfulRequests: 93001, Total429Errors: 5419, TotalClientErrors: 0, TotalServerErrors: 0, ThrottleRate: 5.51, ErrorRate: 5.51, SuccessRate: 94.49, ThrottlingSeverity: 4, ThrottlingStatus: "Critical", FirstOccurrence: "2026-04-25T00:00:00Z", LastOccurrence: "2026-05-03T23:59:59Z" },
        ActivityPermissions: [
            { Method: "GET", Version: "v1.0", Path: "/users", OriginalUri: "https://graph.microsoft.com/v1.0/users", MatchedEndpoint: "/users", LeastPrivilegedPermissions: { Permission: "User.ReadBasic.All", ScopeType: "Application", IsLeastPrivilege: true }, IsMatched: true },
            { Method: "GET", Version: "v1.0", Path: "/groups", OriginalUri: "https://graph.microsoft.com/v1.0/groups", MatchedEndpoint: "/groups", LeastPrivilegedPermissions: { Permission: "GroupMember.Read.All", ScopeType: "Application", IsLeastPrivilege: true }, IsMatched: true },
            { Method: "PATCH", Version: "v1.0", Path: "/groups/{id}", OriginalUri: "https://graph.microsoft.com/v1.0/groups/{id}", MatchedEndpoint: "/groups/{id}", LeastPrivilegedPermissions: { Permission: "Group.ReadWrite.All", ScopeType: "Application", IsLeastPrivilege: true }, IsMatched: true }
        ],
        OptimalPermissions: [
            { Permission: "User.ReadBasic.All", ScopeType: "Application", PrivilegeLevel: 2, RiskLabel: "Medium", ActivitiesCovered: 1, Activities: [{ Method: "GET", Version: "v1.0", Path: "/users", Uri: "https://graph.microsoft.com/v1.0/users" }] },
            { Permission: "GroupMember.Read.All", ScopeType: "Application", PrivilegeLevel: 2, RiskLabel: "Medium", ActivitiesCovered: 1, Activities: [{ Method: "GET", Version: "v1.0", Path: "/groups", Uri: "https://graph.microsoft.com/v1.0/groups" }] },
            { Permission: "Group.ReadWrite.All", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical", ActivitiesCovered: 1, Activities: [{ Method: "PATCH", Version: "v1.0", Path: "/groups/{id}", Uri: "https://graph.microsoft.com/v1.0/groups/{id}" }] }
        ],
        UnmatchedActivities: null,
        CurrentPermissions: [
            { Permission: "Directory.Read.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High" },
            { Permission: "User.Read.All", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" },
            { Permission: "Group.ReadWrite.All", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" },
            { Permission: "User.Read", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" }
        ],
        ExcessPermissions: [
            { Permission: "Directory.Read.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High" },
            { Permission: "User.Read.All", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" },
            { Permission: "User.Read", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" }
        ],
        RequiredPermissions: [{ Permission: "GroupMember.Read.All", ScopeType: "Application" }],
        MatchedAllActivity: true
    },
    {
        // Audit / compliance app – active, high-risk, warning throttle (severity 3)
        PrincipalId: "bbbbbbbb-0029-0029-0029-bbbbbbbbbbbb",
        PrincipalName: "Contoso Compliance Auditor",
        AppRoleCount: 3,
        AppRoles: [
            { appRoleId: "b0afded3-3588-46d8-8b3d-9842eff778da", FriendlyName: "AuditLog.Read.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null },
            { appRoleId: "7ab1d382-f21e-4acd-a863-ba3e13f7da61", FriendlyName: "Directory.Read.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null },
            { appRoleId: "246dd0d5-5bd0-4def-940b-0421030a5b68", FriendlyName: "Policy.Read.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null }
        ],
        Activity: [
            { Method: "GET", Uri: "https://graph.microsoft.com/v1.0/auditLogs/signIns", Scheme: "Application" },
            { Method: "GET", Uri: "https://graph.microsoft.com/v1.0/auditLogs/directoryAudits", Scheme: "Application" }
        ],
        ThrottlingStats: { TotalRequests: 45310, SuccessfulRequests: 43500, Total429Errors: 1810, TotalClientErrors: 0, TotalServerErrors: 0, ThrottleRate: 3.99, ErrorRate: 3.99, SuccessRate: 96.01, ThrottlingSeverity: 3, ThrottlingStatus: "Warning", FirstOccurrence: "2026-04-26T00:00:00Z", LastOccurrence: "2026-05-03T23:00:00Z" },
        ActivityPermissions: [
            { Method: "GET", Version: "v1.0", Path: "/auditLogs/signIns", OriginalUri: "https://graph.microsoft.com/v1.0/auditLogs/signIns", MatchedEndpoint: "/auditLogs/signIns", LeastPrivilegedPermissions: { Permission: "AuditLog.Read.All", ScopeType: "Application", IsLeastPrivilege: true }, IsMatched: true },
            { Method: "GET", Version: "v1.0", Path: "/auditLogs/directoryAudits", OriginalUri: "https://graph.microsoft.com/v1.0/auditLogs/directoryAudits", MatchedEndpoint: "/auditLogs/directoryAudits", LeastPrivilegedPermissions: { Permission: "AuditLog.Read.All", ScopeType: "Application", IsLeastPrivilege: true }, IsMatched: true }
        ],
        OptimalPermissions: [
            { Permission: "AuditLog.Read.All", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical", ActivitiesCovered: 2, Activities: [{ Method: "GET", Version: "v1.0", Path: "/auditLogs/signIns", Uri: "https://graph.microsoft.com/v1.0/auditLogs/signIns" }, { Method: "GET", Version: "v1.0", Path: "/auditLogs/directoryAudits", Uri: "https://graph.microsoft.com/v1.0/auditLogs/directoryAudits" }] }
        ],
        UnmatchedActivities: null,
        CurrentPermissions: [
            { Permission: "AuditLog.Read.All", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" },
            { Permission: "Directory.Read.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High" },
            { Permission: "Policy.Read.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High" }
        ],
        ExcessPermissions: [
            { Permission: "Directory.Read.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High" },
            { Permission: "Policy.Read.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High" }
        ],
        RequiredPermissions: [],
        MatchedAllActivity: true
    },
    {
        // Single-role app – Delegated User.Read only, no activity (simple idle SSO)
        PrincipalId: "bbbbbbbb-0030-0030-0030-bbbbbbbbbbbb",
        PrincipalName: "Contoso Partner Connect",
        AppRoleCount: 1,
        AppRoles: [{ appRoleId: "e1fe6dd8-ba31-4d61-89e7-88639da4683d", FriendlyName: "User.Read", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" }],
        Activity: null,
        ThrottlingStats: { TotalRequests: 0, SuccessfulRequests: 0, Total429Errors: 0, TotalClientErrors: 0, TotalServerErrors: 0, ThrottleRate: 0, ErrorRate: 0, SuccessRate: 0, ThrottlingSeverity: 0, ThrottlingStatus: "No Activity", FirstOccurrence: null, LastOccurrence: null },
        ActivityPermissions: [],
        OptimalPermissions: [],
        UnmatchedActivities: [],
        CurrentPermissions: [{ Permission: "User.Read", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" }],
        ExcessPermissions: [{ Permission: "User.Read", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" }],
        RequiredPermissions: [],
        MatchedAllActivity: true
    },
    {
        // Device management app – active, misaligned
        PrincipalId: "bbbbbbbb-0031-0031-0031-bbbbbbbbbbbb",
        PrincipalName: "Contoso Device Manager",
        AppRoleCount: 3,
        AppRoles: [
            { appRoleId: "2f51be20-0bb4-4fed-bf7b-db946066c75e", FriendlyName: "DeviceManagementManagedDevices.Read.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null },
            { appRoleId: "dc377aa6-52d8-4e23-b271-2a7ae04cedf3", FriendlyName: "DeviceManagementConfiguration.Read.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null },
            { appRoleId: "df021288-bdef-4463-88db-98f22de89214", FriendlyName: "User.Read.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null }
        ],
        Activity: [
            { Method: "GET", Uri: "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices", Scheme: "Application" },
            { Method: "GET", Uri: "https://graph.microsoft.com/v1.0/deviceManagement/deviceConfigurations", Scheme: "Application" }
        ],
        ThrottlingStats: { TotalRequests: 1820, SuccessfulRequests: 1804, Total429Errors: 0, TotalClientErrors: 16, TotalServerErrors: 0, ThrottleRate: 0, ErrorRate: 0.88, SuccessRate: 99.12, ThrottlingSeverity: 0, ThrottlingStatus: "Normal", FirstOccurrence: "2026-04-28T05:00:00Z", LastOccurrence: "2026-05-03T05:00:00Z" },
        ActivityPermissions: [
            { Method: "GET", Version: "v1.0", Path: "/deviceManagement/managedDevices", OriginalUri: "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices", MatchedEndpoint: "/deviceManagement/managedDevices", LeastPrivilegedPermissions: { Permission: "DeviceManagementManagedDevices.Read.All", ScopeType: "Application", IsLeastPrivilege: true }, IsMatched: true },
            { Method: "GET", Version: "v1.0", Path: "/deviceManagement/deviceConfigurations", OriginalUri: "https://graph.microsoft.com/v1.0/deviceManagement/deviceConfigurations", MatchedEndpoint: "/deviceManagement/deviceConfigurations", LeastPrivilegedPermissions: { Permission: "DeviceManagementConfiguration.Read.All", ScopeType: "Application", IsLeastPrivilege: true }, IsMatched: true }
        ],
        OptimalPermissions: [
            { Permission: "DeviceManagementManagedDevices.Read.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High", ActivitiesCovered: 1, Activities: [{ Method: "GET", Version: "v1.0", Path: "/deviceManagement/managedDevices", Uri: "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices" }] },
            { Permission: "DeviceManagementConfiguration.Read.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High", ActivitiesCovered: 1, Activities: [{ Method: "GET", Version: "v1.0", Path: "/deviceManagement/deviceConfigurations", Uri: "https://graph.microsoft.com/v1.0/deviceManagement/deviceConfigurations" }] }
        ],
        UnmatchedActivities: null,
        CurrentPermissions: [
            { Permission: "DeviceManagementManagedDevices.Read.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High" },
            { Permission: "DeviceManagementConfiguration.Read.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High" },
            { Permission: "User.Read.All", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" }
        ],
        ExcessPermissions: [{ Permission: "User.Read.All", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" }],
        RequiredPermissions: [],
        MatchedAllActivity: true
    },
    {
        // Power Platform connector – no activity, critical Application permissions
        PrincipalId: "bbbbbbbb-0032-0032-0032-bbbbbbbbbbbb",
        PrincipalName: "Contoso Power Platform Connector",
        AppRoleCount: 4,
        AppRoles: [
            { appRoleId: "9e3f62cf-ca93-4989-b6ce-bf83047a90c6", FriendlyName: "User.ReadWrite.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null },
            { appRoleId: "62a82d76-70ea-41e2-9197-370581804d09", FriendlyName: "Group.ReadWrite.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null },
            { appRoleId: "741f803b-c850-494e-b5df-cde7c675a1ca", FriendlyName: "RoleManagement.ReadWrite.Directory", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null },
            { appRoleId: "e1fe6dd8-ba31-4d61-89e7-88639da4683d", FriendlyName: "User.Read", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" }
        ],
        Activity: null,
        ThrottlingStats: { TotalRequests: 0, SuccessfulRequests: 0, Total429Errors: 0, TotalClientErrors: 0, TotalServerErrors: 0, ThrottleRate: 0, ErrorRate: 0, SuccessRate: 0, ThrottlingSeverity: 0, ThrottlingStatus: "No Activity", FirstOccurrence: null, LastOccurrence: null },
        ActivityPermissions: [],
        OptimalPermissions: [],
        UnmatchedActivities: [],
        CurrentPermissions: [
            { Permission: "User.ReadWrite.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High" },
            { Permission: "Group.ReadWrite.All", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" },
            { Permission: "RoleManagement.ReadWrite.Directory", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" },
            { Permission: "User.Read", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" }
        ],
        ExcessPermissions: [
            { Permission: "User.ReadWrite.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High" },
            { Permission: "Group.ReadWrite.All", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" },
            { Permission: "RoleManagement.ReadWrite.Directory", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" },
            { Permission: "User.Read", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" }
        ],
        RequiredPermissions: [],
        MatchedAllActivity: true
    },
    {
        // v1 registration style – active, low throttle (severity 2)
        PrincipalId: "bbbbbbbb-0033-0033-0033-bbbbbbbbbbbb",
        PrincipalName: "Contoso v1-reg-7f2c1e88",
        AppRoleCount: 4,
        AppRoles: [
            { appRoleId: "7ab1d382-f21e-4acd-a863-ba3e13f7da61", FriendlyName: "Directory.Read.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null },
            { appRoleId: "df021288-bdef-4463-88db-98f22de89214", FriendlyName: "User.Read.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null },
            { appRoleId: "a154be20-db9c-4678-8ab7-66f6cc099a59", FriendlyName: "User.Read.All", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" },
            { appRoleId: "e1fe6dd8-ba31-4d61-89e7-88639da4683d", FriendlyName: "User.Read", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" }
        ],
        Activity: [
            { Method: "GET", Uri: "https://graph.microsoft.com/v1.0/applications/{id}", Scheme: "Application" },
            { Method: "GET", Uri: "https://graph.microsoft.com/v1.0/servicePrincipals/{id}", Scheme: "Application" },
            { Method: "GET", Uri: "https://graph.microsoft.com/v1.0/users", Scheme: "Application" }
        ],
        ThrottlingStats: { TotalRequests: 3102, SuccessfulRequests: 2984, Total429Errors: 118, TotalClientErrors: 0, TotalServerErrors: 0, ThrottleRate: 3.8, ErrorRate: 3.8, SuccessRate: 96.2, ThrottlingSeverity: 2, ThrottlingStatus: "Low", FirstOccurrence: "2026-04-26T20:41:12Z", LastOccurrence: "2026-05-03T19:31:51Z" },
        ActivityPermissions: [
            { Method: "GET", Version: "v1.0", Path: "/applications/{id}", OriginalUri: "https://graph.microsoft.com/v1.0/applications/{id}", MatchedEndpoint: "/applications/{id}", LeastPrivilegedPermissions: { Permission: "Application.Read.All", ScopeType: "Application", IsLeastPrivilege: true }, IsMatched: true },
            { Method: "GET", Version: "v1.0", Path: "/servicePrincipals/{id}", OriginalUri: "https://graph.microsoft.com/v1.0/servicePrincipals/{id}", MatchedEndpoint: "/servicePrincipals/{id}", LeastPrivilegedPermissions: { Permission: "Application.Read.All", ScopeType: "Application", IsLeastPrivilege: true }, IsMatched: true },
            { Method: "GET", Version: "v1.0", Path: "/users", OriginalUri: "https://graph.microsoft.com/v1.0/users", MatchedEndpoint: "/users", LeastPrivilegedPermissions: { Permission: "User.ReadBasic.All", ScopeType: "Application", IsLeastPrivilege: true }, IsMatched: true }
        ],
        OptimalPermissions: [
            { Permission: "Application.Read.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High", ActivitiesCovered: 2, Activities: [{ Method: "GET", Version: "v1.0", Path: "/applications/{id}", Uri: "https://graph.microsoft.com/v1.0/applications/{id}" }, { Method: "GET", Version: "v1.0", Path: "/servicePrincipals/{id}", Uri: "https://graph.microsoft.com/v1.0/servicePrincipals/{id}" }] },
            { Permission: "User.ReadBasic.All", ScopeType: "Application", PrivilegeLevel: 2, RiskLabel: "Medium", ActivitiesCovered: 1, Activities: [{ Method: "GET", Version: "v1.0", Path: "/users", Uri: "https://graph.microsoft.com/v1.0/users" }] }
        ],
        UnmatchedActivities: null,
        CurrentPermissions: [
            { Permission: "Directory.Read.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High" },
            { Permission: "User.Read.All", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" },
            { Permission: "User.Read.All", ScopeType: "Delegated", PrivilegeLevel: 3, RiskLabel: "High" },
            { Permission: "User.Read", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" }
        ],
        ExcessPermissions: [
            { Permission: "Directory.Read.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High" },
            { Permission: "User.Read.All", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" },
            { Permission: "User.Read.All", ScopeType: "Delegated", PrivilegeLevel: 3, RiskLabel: "High" },
            { Permission: "User.Read", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" }
        ],
        RequiredPermissions: [{ Permission: "Application.Read.All", ScopeType: "Application" }],
        MatchedAllActivity: true
    },
    {
        // Email marketing app – Mail.Send + User.Read, no activity
        PrincipalId: "bbbbbbbb-0034-0034-0034-bbbbbbbbbbbb",
        PrincipalName: "Contoso Email Campaign Tool",
        AppRoleCount: 3,
        AppRoles: [
            { appRoleId: "b633e1c5-b582-4058-a3f9-3d44700e7d87", FriendlyName: "Mail.Send", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null },
            { appRoleId: "570282fd-fa5c-430d-a7fd-fc8dc98a9dca", FriendlyName: "Mail.Read", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null },
            { appRoleId: "e1fe6dd8-ba31-4d61-89e7-88639da4683d", FriendlyName: "User.Read", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" }
        ],
        Activity: null,
        ThrottlingStats: { TotalRequests: 0, SuccessfulRequests: 0, Total429Errors: 0, TotalClientErrors: 0, TotalServerErrors: 0, ThrottleRate: 0, ErrorRate: 0, SuccessRate: 0, ThrottlingSeverity: 0, ThrottlingStatus: "No Activity", FirstOccurrence: null, LastOccurrence: null },
        ActivityPermissions: [],
        OptimalPermissions: [],
        UnmatchedActivities: [],
        CurrentPermissions: [
            { Permission: "Mail.Send", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" },
            { Permission: "Mail.Read", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" },
            { Permission: "User.Read", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" }
        ],
        ExcessPermissions: [
            { Permission: "Mail.Send", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" },
            { Permission: "Mail.Read", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" },
            { Permission: "User.Read", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" }
        ],
        RequiredPermissions: [],
        MatchedAllActivity: true
    },
    {
        // Reporting app – active, optimal (no excess, no missing)
        PrincipalId: "bbbbbbbb-0035-0035-0035-bbbbbbbbbbbb",
        PrincipalName: "Contoso Reporting Service",
        AppRoleCount: 2,
        AppRoles: [
            { appRoleId: "7ab1d382-f21e-4acd-a863-ba3e13f7da61", FriendlyName: "Directory.Read.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null },
            { appRoleId: "df021288-bdef-4463-88db-98f22de89214", FriendlyName: "User.Read.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null }
        ],
        Activity: [
            { Method: "GET", Uri: "https://graph.microsoft.com/v1.0/users", Scheme: "Application" },
            { Method: "GET", Uri: "https://graph.microsoft.com/v1.0/users/{id}/memberOf", Scheme: "Application" }
        ],
        ThrottlingStats: { TotalRequests: 7204, SuccessfulRequests: 7204, Total429Errors: 0, TotalClientErrors: 0, TotalServerErrors: 0, ThrottleRate: 0, ErrorRate: 0, SuccessRate: 100, ThrottlingSeverity: 0, ThrottlingStatus: "Normal", FirstOccurrence: "2026-04-28T00:00:00Z", LastOccurrence: "2026-05-03T00:00:00Z" },
        ActivityPermissions: [
            { Method: "GET", Version: "v1.0", Path: "/users", OriginalUri: "https://graph.microsoft.com/v1.0/users", MatchedEndpoint: "/users", LeastPrivilegedPermissions: { Permission: "User.ReadBasic.All", ScopeType: "Application", IsLeastPrivilege: true }, IsMatched: true },
            { Method: "GET", Version: "v1.0", Path: "/users/{id}/memberOf", OriginalUri: "https://graph.microsoft.com/v1.0/users/{id}/memberOf", MatchedEndpoint: "/users/{id}/memberOf", LeastPrivilegedPermissions: { Permission: "Directory.Read.All", ScopeType: "Application", IsLeastPrivilege: true }, IsMatched: true }
        ],
        OptimalPermissions: [
            { Permission: "User.ReadBasic.All", ScopeType: "Application", PrivilegeLevel: 2, RiskLabel: "Medium", ActivitiesCovered: 1, Activities: [{ Method: "GET", Version: "v1.0", Path: "/users", Uri: "https://graph.microsoft.com/v1.0/users" }] },
            { Permission: "Directory.Read.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High", ActivitiesCovered: 1, Activities: [{ Method: "GET", Version: "v1.0", Path: "/users/{id}/memberOf", Uri: "https://graph.microsoft.com/v1.0/users/{id}/memberOf" }] }
        ],
        UnmatchedActivities: null,
        CurrentPermissions: [
            { Permission: "Directory.Read.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High" },
            { Permission: "User.Read.All", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" }
        ],
        ExcessPermissions: [{ Permission: "User.Read.All", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" }],
        RequiredPermissions: [],
        MatchedAllActivity: true
    },
    {
        // Fully optimal – active, no excess, no missing (green row)
        PrincipalId: "bbbbbbbb-0036-0036-0036-bbbbbbbbbbbb",
        PrincipalName: "Contoso Subscription Monitor",
        AppRoleCount: 1,
        AppRoles: [
            { appRoleId: "7ab1d382-f21e-4acd-a863-ba3e13f7da61", FriendlyName: "Directory.Read.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null }
        ],
        Activity: [
            { Method: "GET", Uri: "https://graph.microsoft.com/v1.0/subscriptions", Scheme: "Application" }
        ],
        ThrottlingStats: { TotalRequests: 288, SuccessfulRequests: 288, Total429Errors: 0, TotalClientErrors: 0, TotalServerErrors: 0, ThrottleRate: 0, ErrorRate: 0, SuccessRate: 100, ThrottlingSeverity: 0, ThrottlingStatus: "Normal", FirstOccurrence: "2026-04-28T00:00:00Z", LastOccurrence: "2026-05-03T00:00:00Z" },
        ActivityPermissions: [
            { Method: "GET", Version: "v1.0", Path: "/subscriptions", OriginalUri: "https://graph.microsoft.com/v1.0/subscriptions", MatchedEndpoint: "/subscriptions", LeastPrivilegedPermissions: { Permission: "Directory.Read.All", ScopeType: "Application", IsLeastPrivilege: true }, IsMatched: true }
        ],
        OptimalPermissions: [
            { Permission: "Directory.Read.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High", ActivitiesCovered: 1, Activities: [{ Method: "GET", Version: "v1.0", Path: "/subscriptions", Uri: "https://graph.microsoft.com/v1.0/subscriptions" }] }
        ],
        UnmatchedActivities: null,
        CurrentPermissions: [{ Permission: "Directory.Read.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High" }],
        ExcessPermissions: [],
        RequiredPermissions: [],
        MatchedAllActivity: true
    },
    {
        // Unmatched activity – MatchedAllActivity false, identity risk app
        PrincipalId: "bbbbbbbb-0037-0037-0037-bbbbbbbbbbbb",
        PrincipalName: "Contoso Risk Assessment Engine",
        AppRoleCount: 5,
        AppRoles: [
            { appRoleId: "6e472fd1-ad78-48da-a0f0-97ab2c6b769e", FriendlyName: "IdentityRiskEvent.Read.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null },
            { appRoleId: "dc5007c0-2d7d-4c42-879c-2dab87571379", FriendlyName: "IdentityRiskyUser.Read.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null },
            { appRoleId: "df021288-bdef-4463-88db-98f22de89214", FriendlyName: "User.Read.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null },
            { appRoleId: "7ab1d382-f21e-4acd-a863-ba3e13f7da61", FriendlyName: "Directory.Read.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null },
            { appRoleId: "e1fe6dd8-ba31-4d61-89e7-88639da4683d", FriendlyName: "User.Read", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" }
        ],
        Activity: [
            { Method: "GET", Uri: "https://graph.microsoft.com/v1.0/identityProtection/riskyUsers", Scheme: "Application" },
            { Method: "GET", Uri: "https://graph.microsoft.com/v1.0/identityProtection/riskDetections", Scheme: "Application" },
            { Method: "POST", Uri: "https://graph.microsoft.com/v1.0/identityProtection/riskyUsers/dismiss", Scheme: "Application" },
            { Method: "GET", Uri: "https://graph.microsoft.com/v1.0/identityProtection/{unknownEndpoint}", Scheme: "Application" }
        ],
        ThrottlingStats: { TotalRequests: 5642, SuccessfulRequests: 5620, Total429Errors: 0, TotalClientErrors: 22, TotalServerErrors: 0, ThrottleRate: 0, ErrorRate: 0.39, SuccessRate: 99.61, ThrottlingSeverity: 0, ThrottlingStatus: "Normal", FirstOccurrence: "2026-04-26T15:00:00Z", LastOccurrence: "2026-05-03T15:00:00Z" },
        ActivityPermissions: [
            { Method: "GET", Version: "v1.0", Path: "/identityProtection/riskyUsers", OriginalUri: "https://graph.microsoft.com/v1.0/identityProtection/riskyUsers", MatchedEndpoint: "/identityProtection/riskyUsers", LeastPrivilegedPermissions: { Permission: "IdentityRiskyUser.Read.All", ScopeType: "Application", IsLeastPrivilege: true }, IsMatched: true },
            { Method: "GET", Version: "v1.0", Path: "/identityProtection/riskDetections", OriginalUri: "https://graph.microsoft.com/v1.0/identityProtection/riskDetections", MatchedEndpoint: "/identityProtection/riskDetections", LeastPrivilegedPermissions: { Permission: "IdentityRiskEvent.Read.All", ScopeType: "Application", IsLeastPrivilege: true }, IsMatched: true },
            { Method: "POST", Version: "v1.0", Path: "/identityProtection/riskyUsers/dismiss", OriginalUri: "https://graph.microsoft.com/v1.0/identityProtection/riskyUsers/dismiss", MatchedEndpoint: "/identityProtection/riskyUsers/dismiss", LeastPrivilegedPermissions: { Permission: "IdentityRiskyUser.ReadWrite.All", ScopeType: "Application", IsLeastPrivilege: true }, IsMatched: true },
            { Method: "GET", Version: "v1.0", Path: "/identityProtection/{unknownEndpoint}", OriginalUri: "https://graph.microsoft.com/v1.0/identityProtection/{unknownEndpoint}", MatchedEndpoint: null, LeastPrivilegedPermissions: [], IsMatched: false }
        ],
        OptimalPermissions: [
            { Permission: "IdentityRiskyUser.ReadWrite.All", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical", ActivitiesCovered: 2, Activities: [{ Method: "GET", Version: "v1.0", Path: "/identityProtection/riskyUsers", Uri: "https://graph.microsoft.com/v1.0/identityProtection/riskyUsers" }, { Method: "POST", Version: "v1.0", Path: "/identityProtection/riskyUsers/dismiss", Uri: "https://graph.microsoft.com/v1.0/identityProtection/riskyUsers/dismiss" }] },
            { Permission: "IdentityRiskEvent.Read.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High", ActivitiesCovered: 1, Activities: [{ Method: "GET", Version: "v1.0", Path: "/identityProtection/riskDetections", Uri: "https://graph.microsoft.com/v1.0/identityProtection/riskDetections" }] }
        ],
        UnmatchedActivities: [
            { Method: "GET", Version: "v1.0", Path: "/identityProtection/{unknownEndpoint}", OriginalUri: "https://graph.microsoft.com/v1.0/identityProtection/{unknownEndpoint}", MatchedEndpoint: null, LeastPrivilegedPermissions: [], IsMatched: false }
        ],
        CurrentPermissions: [
            { Permission: "IdentityRiskEvent.Read.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High" },
            { Permission: "IdentityRiskyUser.Read.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High" },
            { Permission: "User.Read.All", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" },
            { Permission: "Directory.Read.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High" },
            { Permission: "User.Read", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" }
        ],
        ExcessPermissions: [
            { Permission: "IdentityRiskyUser.Read.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High" },
            { Permission: "User.Read.All", ScopeType: "Application", PrivilegeLevel: 4, RiskLabel: "Critical" },
            { Permission: "Directory.Read.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High" },
            { Permission: "User.Read", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" }
        ],
        RequiredPermissions: [{ Permission: "IdentityRiskyUser.ReadWrite.All", ScopeType: "Application" }],
        MatchedAllActivity: false
    },
    {
        // Service account style – profile photo + user listing, low throttle
        PrincipalId: "bbbbbbbb-0038-0038-0038-bbbbbbbbbbbb",
        PrincipalName: "Contoso HR Photo Sync",
        AppRoleCount: 3,
        AppRoles: [
            { appRoleId: "9e3f62cf-ca93-4989-b6ce-bf83047a90c6", FriendlyName: "User.ReadWrite.All", PermissionType: "Application", resourceDisplayName: "Microsoft Graph", consentType: null },
            { appRoleId: "7427e0e9-2fba-42fe-b0c0-848c9e6a8182", FriendlyName: "offline_access", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" },
            { appRoleId: "e1fe6dd8-ba31-4d61-89e7-88639da4683d", FriendlyName: "User.Read", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" }
        ],
        Activity: [
            { Method: "GET", Uri: "https://graph.microsoft.com/v1.0/users", Scheme: "Application" },
            { Method: "GET", Uri: "https://graph.microsoft.com/v1.0/users/{id}", Scheme: "Application" },
            { Method: "PUT", Uri: "https://graph.microsoft.com/v1.0/users/{id}/photo", Scheme: "Application" }
        ],
        ThrottlingStats: { TotalRequests: 612, SuccessfulRequests: 588, Total429Errors: 24, TotalClientErrors: 0, TotalServerErrors: 0, ThrottleRate: 3.92, ErrorRate: 3.92, SuccessRate: 96.08, ThrottlingSeverity: 2, ThrottlingStatus: "Low", FirstOccurrence: "2026-04-28T22:04:08Z", LastOccurrence: "2026-05-03T10:01:26Z" },
        ActivityPermissions: [
            { Method: "GET", Version: "v1.0", Path: "/users", OriginalUri: "https://graph.microsoft.com/v1.0/users", MatchedEndpoint: "/users", LeastPrivilegedPermissions: { Permission: "User.ReadBasic.All", ScopeType: "Application", IsLeastPrivilege: true }, IsMatched: true },
            { Method: "GET", Version: "v1.0", Path: "/users/{id}", OriginalUri: "https://graph.microsoft.com/v1.0/users/{id}", MatchedEndpoint: "/users/{id}", LeastPrivilegedPermissions: { Permission: "User.ReadBasic.All", ScopeType: "Application", IsLeastPrivilege: true }, IsMatched: true },
            { Method: "PUT", Version: "v1.0", Path: "/users/{id}/photo", OriginalUri: "https://graph.microsoft.com/v1.0/users/{id}/photo", MatchedEndpoint: "/users/{id}/photo", LeastPrivilegedPermissions: { Permission: "ProfilePhoto.ReadWrite.All", ScopeType: "Application", IsLeastPrivilege: true }, IsMatched: true }
        ],
        OptimalPermissions: [
            { Permission: "User.ReadBasic.All", ScopeType: "Application", PrivilegeLevel: 2, RiskLabel: "Medium", ActivitiesCovered: 2, Activities: [{ Method: "GET", Version: "v1.0", Path: "/users", Uri: "https://graph.microsoft.com/v1.0/users" }, { Method: "GET", Version: "v1.0", Path: "/users/{id}", Uri: "https://graph.microsoft.com/v1.0/users/{id}" }] },
            { Permission: "ProfilePhoto.ReadWrite.All", ScopeType: "Application", PrivilegeLevel: 2, RiskLabel: "Medium", ActivitiesCovered: 1, Activities: [{ Method: "PUT", Version: "v1.0", Path: "/users/{id}/photo", Uri: "https://graph.microsoft.com/v1.0/users/{id}/photo" }] }
        ],
        UnmatchedActivities: null,
        CurrentPermissions: [
            { Permission: "User.ReadWrite.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High" },
            { Permission: "offline_access", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "User.Read", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" }
        ],
        ExcessPermissions: [
            { Permission: "User.ReadWrite.All", ScopeType: "Application", PrivilegeLevel: 3, RiskLabel: "High" },
            { Permission: "offline_access", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "User.Read", ScopeType: "Delegated", PrivilegeLevel: 2, RiskLabel: "Medium" }
        ],
        RequiredPermissions: [
            { Permission: "User.ReadBasic.All", ScopeType: "Application" },
            { Permission: "ProfilePhoto.ReadWrite.All", ScopeType: "Application" }
        ],
        MatchedAllActivity: true
    },
    {
        // Simple tenant app – 3 basic SSO perms, single consent, no activity
        PrincipalId: "bbbbbbbb-0039-0039-0039-bbbbbbbbbbbb",
        PrincipalName: "Contoso Vendor Portal SSO",
        AppRoleCount: 3,
        AppRoles: [
            { appRoleId: "64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0", FriendlyName: "email", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" },
            { appRoleId: "37f7f235-527c-4136-accd-4a02d197296e", FriendlyName: "openid", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" },
            { appRoleId: "14dad69e-099b-42c9-810b-d002981feec1", FriendlyName: "profile", PermissionType: "Delegated", resourceDisplayName: "Microsoft Graph", consentType: "AllPrincipals" }
        ],
        Activity: null,
        ThrottlingStats: { TotalRequests: 0, SuccessfulRequests: 0, Total429Errors: 0, TotalClientErrors: 0, TotalServerErrors: 0, ThrottleRate: 0, ErrorRate: 0, SuccessRate: 0, ThrottlingSeverity: 0, ThrottlingStatus: "No Activity", FirstOccurrence: null, LastOccurrence: null },
        ActivityPermissions: [],
        OptimalPermissions: [],
        UnmatchedActivities: [],
        CurrentPermissions: [
            { Permission: "email", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "openid", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "profile", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" }
        ],
        ExcessPermissions: [
            { Permission: "email", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "openid", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" },
            { Permission: "profile", ScopeType: "Delegated", PrivilegeLevel: 1, RiskLabel: "Low" }
        ],
        RequiredPermissions: [],
        MatchedAllActivity: true
    }
];

export default sampleData;
