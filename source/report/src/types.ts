export interface Activity {
    Method: string;
    Uri: string;
    Path?: string;
    Endpoint?: string;
    Version?: string;
}

export interface Permission {
    Permission: string;
    ScopeType?: string;
    PrivilegeLevel?: number;
    RiskLabel?: string;
}

export interface OptimalPermission extends Permission {
    ActivitiesCovered: number;
    Activities?: Activity[];
}

export interface ThrottlingStats {
    TotalRequests?: number;
    SuccessfulRequests?: number;
    Total429Errors?: number;
    TotalClientErrors?: number;
    TotalServerErrors?: number;
    ThrottleRate?: number;
    SuccessRate?: number;
    ErrorRate?: number;
    ThrottlingStatus?: string;
    ThrottlingSeverity?: number;
    FirstOccurrence?: string;
    LastOccurrence?: string;
}

export interface AppRole {
    FriendlyName: string;
    Permission?: string;
    PermissionType?: string;
}

export interface AppData {
    PrincipalName: string;
    PrincipalId: string;
    AppRoleCount?: number;
    MatchedAllActivity?: boolean;
    CurrentPermissions?: Permission[] | string[];
    OptimalPermissions?: OptimalPermission[];
    ExcessPermissions?: Permission[] | string[];
    RequiredPermissions?: Permission[] | string[];
    Activity?: Activity[];
    UnmatchedActivities?: Activity[];
    ThrottlingStats?: ThrottlingStats;
    AppRoles?: AppRole[];
}

export interface PrivilegeMetrics {
    maxLevel: number;
    score: number;
    highAssignments: number;
}

export type AppStatus = 'good' | 'warning' | 'missing' | 'misaligned' | 'danger';

export type FilterState = {
    status: string;
    activity: string;
    throttling: string;
    privilege: string;
    search: string;
};

export interface ReportMetadata {
    title: string;
    tenantId: string;
    tenantName: string;
    generatedOn: string;
}
