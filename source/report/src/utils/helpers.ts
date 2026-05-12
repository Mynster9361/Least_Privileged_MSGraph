import { AppData, AppStatus, Permission, PrivilegeMetrics } from '../types';

export function toArray<T>(val: T | T[] | null | undefined): T[] {
    if (!val) return [];
    return Array.isArray(val) ? val : [val];
}

export function getPermissionName(p: Permission | string): string {
    if (typeof p === 'string') return p;
    return p.Permission;
}

export function getAppStatus(app: AppData): AppStatus {
    if (!app.MatchedAllActivity) return 'danger';
    const excess = toArray(app.ExcessPermissions).length;
    const required = toArray(app.RequiredPermissions).length;
    if (excess > 0 && required > 0) return 'misaligned';
    if (excess > 0) return 'warning';
    if (required > 0) return 'missing';
    return 'good';
}

export function calculatePrivilegeMetrics(app: AppData): PrivilegeMetrics {
    const currentPerms = toArray(app.CurrentPermissions);
    if (!currentPerms.length) return { maxLevel: 0, score: 0, highAssignments: 0 };

    const levels = currentPerms.map((p) => {
        const level = Number((p as Permission)?.PrivilegeLevel ?? 1);
        return Number.isFinite(level) && level > 0 ? level : 1;
    });

    return {
        maxLevel: Math.max(...levels),
        score: levels.reduce((sum, level) => sum + level, 0),
        highAssignments: levels.filter((level) => level >= 3).length,
    };
}

export function getPermissionType(app: AppData, permissionName: string): string {
    const appRoles = toArray(app.AppRoles);
    const role = appRoles.find((r) => r.FriendlyName === permissionName || r.Permission === permissionName);
    return role ? role.PermissionType ?? 'Unknown' : 'Unknown';
}

export function getRiskBadgeClass(label: string): string {
    const map: Record<string, string> = {
        Maximum: 'bg-purple-100 dark:bg-purple-900/50 text-purple-700 dark:text-purple-300 border border-purple-300 dark:border-purple-700',
        Critical: 'bg-red-100 dark:bg-red-900/50 text-red-700 dark:text-red-300 border border-red-300 dark:border-red-700',
        High: 'bg-orange-100 dark:bg-orange-900/50 text-orange-700 dark:text-orange-300 border border-orange-300 dark:border-orange-700',
        Medium: 'bg-yellow-100 dark:bg-yellow-900/50 text-yellow-700 dark:text-yellow-300 border border-yellow-300 dark:border-yellow-700',
        Low: 'bg-green-100 dark:bg-green-900/50 text-green-700 dark:text-green-300 border border-green-300 dark:border-green-700',
    };
    return map[label] ?? map['Low'];
}

export function resolveRiskLabel(p: Permission | string | undefined, level?: number): string {
    if (!p || typeof p === 'string') {
        const labelMap: Record<number, string> = { 5: 'Maximum', 4: 'Critical', 3: 'High', 2: 'Medium', 1: 'Low' };
        return labelMap[level ?? 1] ?? 'Low';
    }
    if (p.RiskLabel) return p.RiskLabel;
    const labelMap: Record<number, string> = { 5: 'Maximum', 4: 'Critical', 3: 'High', 2: 'Medium', 1: 'Low' };
    return labelMap[p.PrivilegeLevel ?? 1] ?? 'Low';
}

export function calculateThrottlingBreakdown(data: AppData[]) {
    const counts = { critical: 0, warning: 0, low: 0, minimal: 0, normal: 0 };
    data.forEach((app) => {
        const sev = app.ThrottlingStats?.ThrottlingSeverity ?? 0;
        if (sev >= 4) counts.critical++;
        else if (sev === 3) counts.warning++;
        else if (sev === 2) counts.low++;
        else if (sev === 1) counts.minimal++;
        else counts.normal++;
    });
    return counts;
}

export function calculateStatusBreakdown(data: AppData[]) {
    const counts = { good: 0, warning: 0, missing: 0, misaligned: 0, danger: 0 };
    data.forEach((app) => {
        const s = getAppStatus(app);
        counts[s as keyof typeof counts]++;
    });
    return counts;
}

export function calculateStats(data: AppData[]) {
    const appsWithThrottling = data.filter((app) => app.ThrottlingStats?.ThrottleRate);
    return {
        total: data.length,
        fullyMatched: data.filter((app) => getAppStatus(app) === 'good').length,
        withExcess: data.filter((app) => toArray(app.ExcessPermissions).length > 0).length,
        withUnmatched: data.filter((app) => !app.MatchedAllActivity).length,
        throttledApps: data.filter((app) => (app.ThrottlingStats?.Total429Errors ?? 0) > 0).length,
        criticalThrottling: data.filter((app) => app.ThrottlingStats?.ThrottlingSeverity === 4).length,
        total429: data.reduce((sum, app) => sum + (app.ThrottlingStats?.Total429Errors ?? 0), 0),
        avgThrottleRate:
            appsWithThrottling.length > 0
                ? (
                    appsWithThrottling.reduce((sum, app) => sum + (app.ThrottlingStats!.ThrottleRate ?? 0), 0) /
                    appsWithThrottling.length
                ).toFixed(2)
                : '0',
    };
}

export function flattenObject(obj: Record<string, unknown>, prefix = ''): Record<string, string | number> {
    const flattened: Record<string, string | number> = {};
    for (const key in obj) {
        if (!Object.prototype.hasOwnProperty.call(obj, key)) continue;
        const value = obj[key];
        const newKey = prefix ? `${prefix}.${key}` : key;

        if (value === null || value === undefined) {
            flattened[newKey] = '';
        } else if (Array.isArray(value)) {
            if (value.length === 0) {
                flattened[newKey] = '';
            } else if (typeof value[0] === 'object') {
                flattened[newKey] = (value as Record<string, unknown>[])
                    .map((item) => {
                        if (item.Permission) return item.Permission as string;
                        if (item.Method && item.Uri) return `${item.Method} ${item.Uri}`;
                        if (item.Method && item.Path) return `${item.Method} ${item.Path}`;
                        return JSON.stringify(item);
                    })
                    .join(', ');
                if ((value[0] as Record<string, unknown>).Permission && (value[0] as Record<string, unknown>).ScopeType) {
                    flattened[`${newKey}.ScopeTypes`] = (value as Record<string, unknown>[])
                        .map((item) => (item.ScopeType as string) || 'Unknown')
                        .join(', ');
                }
            } else {
                flattened[newKey] = (value as string[]).join(', ');
            }
            flattened[`${newKey}.Count`] = value.length;
        } else if (typeof value === 'object') {
            Object.assign(flattened, flattenObject(value as Record<string, unknown>, newKey));
        } else {
            flattened[newKey] = value as string | number;
        }
    }
    return flattened;
}

export function exportToCSV(appData: AppData[]) {
    if (!appData.length) {
        alert('No data to export');
        return;
    }

    const flattenedData = appData.map((app) => flattenObject(app as unknown as Record<string, unknown>));
    const allKeys = new Set<string>();
    flattenedData.forEach((row) => Object.keys(row).forEach((key) => allKeys.add(key)));

    const priority: Record<string, number> = {
        PrincipalName: 1,
        PrincipalId: 2,
        AppRoleCount: 3,
        MatchedAllActivity: 4,
    };

    const headers = Array.from(allKeys).sort((a, b) => {
        const aPriority = priority[a] ?? 999;
        const bPriority = priority[b] ?? 999;
        if (aPriority !== bPriority) return aPriority - bPriority;
        return a.localeCompare(b);
    });

    const escape = (v: string | number | undefined) => {
        const s = String(v ?? '');
        if (s.includes(',') || s.includes(';') || s.includes('\n') || s.includes('"')) {
            return `"${s.replace(/"/g, '""')}"`;
        }
        return s;
    };

    let csv = headers.map(escape).join(';') + '\n';
    flattenedData.forEach((row) => {
        csv += headers.map((h) => escape(row[h])).join(';') + '\n';
    });

    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = `permission_analysis_${Date.now()}.csv`;
    link.click();
}
