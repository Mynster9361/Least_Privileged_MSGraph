import React, { useState, useEffect } from 'react';
import { AppData, Activity, OptimalPermission, Permission } from '../types';
import { toArray, getPermissionType, calculatePrivilegeMetrics } from '../utils/helpers';
import { PermissionTypeBadge, RiskBadge } from './Badges';

interface Props {
    app: AppData | null;
    onClose: () => void;
}

// ---------------------------------------------------------------------------
// Method badge
// ---------------------------------------------------------------------------

const methodColors: Record<string, string> = {
    GET: 'bg-green-100 dark:bg-green-900/50 text-green-800 dark:text-green-300',
    POST: 'bg-blue-100 dark:bg-blue-900/50 text-blue-800 dark:text-blue-300',
    PATCH: 'bg-yellow-100 dark:bg-yellow-900/50 text-yellow-800 dark:text-yellow-300',
    PUT: 'bg-orange-100 dark:bg-orange-900/50 text-orange-800 dark:text-orange-300',
    DELETE: 'bg-red-100 dark:bg-red-900/50 text-red-800 dark:text-red-300',
};

function MethodBadge({ method }: { method: string }) {
    return (
        <span className={`inline-block px-1.5 py-0.5 text-xs font-bold rounded font-mono ${methodColors[method] ?? 'bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300'}`}>
            {method}
        </span>
    );
}

// ---------------------------------------------------------------------------
// 1. Summary banner
// ---------------------------------------------------------------------------

function SummaryBanner({ app }: { app: AppData }) {
    const excess = toArray(app.ExcessPermissions).length;
    const missing = toArray(app.RequiredPermissions).length;
    const unmatched = toArray(app.UnmatchedActivities).length;
    const throttleSev = app.ThrottlingStats?.ThrottlingSeverity ?? 0;

    const chips: { label: string; color: string }[] = [];

    if (excess > 0)
        chips.push({ label: `${excess} excess permission${excess > 1 ? 's' : ''}`, color: 'bg-red-100 dark:bg-red-900/40 text-red-700 dark:text-red-300 border border-red-300 dark:border-red-700' });
    else
        chips.push({ label: 'No excess permissions', color: 'bg-green-100 dark:bg-green-900/40 text-green-700 dark:text-green-300 border border-green-300 dark:border-green-700' });

    if (missing > 0)
        chips.push({ label: `${missing} missing permission${missing > 1 ? 's' : ''}`, color: 'bg-yellow-100 dark:bg-yellow-900/40 text-yellow-700 dark:text-yellow-300 border border-yellow-300 dark:border-yellow-700' });

    if (unmatched > 0)
        chips.push({ label: `${unmatched} unmatched activit${unmatched > 1 ? 'ies' : 'y'}`, color: 'bg-red-100 dark:bg-red-900/40 text-red-700 dark:text-red-300 border border-red-300 dark:border-red-700' });

    if (throttleSev >= 4)
        chips.push({ label: 'Throttling: Critical', color: 'bg-red-600 text-white border border-red-700' });
    else if (throttleSev === 3)
        chips.push({ label: 'Throttling: Warning', color: 'bg-orange-100 dark:bg-orange-900/40 text-orange-700 dark:text-orange-300 border border-orange-300 dark:border-orange-700' });
    else if (throttleSev === 2)
        chips.push({ label: 'Throttling: Low', color: 'bg-yellow-100 dark:bg-yellow-900/40 text-yellow-700 dark:text-yellow-300 border border-yellow-300 dark:border-yellow-700' });

    if (!app.MatchedAllActivity)
        chips.push({ label: 'Unresolved API calls', color: 'bg-orange-100 dark:bg-orange-900/40 text-orange-700 dark:text-orange-300 border border-orange-300 dark:border-orange-700' });

    return (
        <div className="flex flex-wrap gap-2 py-3 border-b dark:border-gray-600">
            {chips.map((c, i) => (
                <span key={i} className={`px-2.5 py-1 rounded-full text-xs font-semibold ${c.color}`}>{c.label}</span>
            ))}
        </div>
    );
}

// ---------------------------------------------------------------------------
// 2. AppInfo as stat cards
// ---------------------------------------------------------------------------

function AppInfo({ app }: { app: AppData }) {
    const metrics = calculatePrivilegeMetrics(app);
    const levelLabels: Record<number, string> = { 4: 'Critical', 3: 'High', 2: 'Medium', 1: 'Low', 0: 'None' };
    const levelColors: Record<number, string> = {
        4: 'text-red-600 dark:text-red-400',
        3: 'text-orange-600 dark:text-orange-400',
        2: 'text-yellow-600 dark:text-yellow-500',
        1: 'text-blue-500 dark:text-blue-400',
        0: 'text-green-600 dark:text-green-400',
    };

    const cards = [
        { label: 'App Roles', value: app.AppRoleCount ?? 0, color: 'text-gray-800 dark:text-gray-100' },
        { label: 'Max Privilege', value: levelLabels[metrics.maxLevel] ?? String(metrics.maxLevel), color: levelColors[metrics.maxLevel] ?? 'text-gray-800 dark:text-gray-100' },
        { label: 'Privilege Score', value: metrics.score, color: 'text-gray-800 dark:text-gray-100' },
        { label: 'Activities Matched', value: app.MatchedAllActivity ? 'All' : 'Partial', color: app.MatchedAllActivity ? 'text-green-600 dark:text-green-400' : 'text-orange-600 dark:text-orange-400' },
    ];

    return (
        <div className="border-b dark:border-gray-600 pb-4">
            <h4 className="font-bold text-xs uppercase tracking-wider text-gray-500 dark:text-gray-400 mb-3">Application Overview</h4>
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mb-3">
                {cards.map((c) => (
                    <div key={c.label} className="bg-gray-50 dark:bg-gray-700/50 rounded-lg p-3 text-center">
                        <div className={`text-xl font-bold ${c.color}`}>{c.value}</div>
                        <div className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">{c.label}</div>
                    </div>
                ))}
            </div>
        </div>
    );
}

// ---------------------------------------------------------------------------
// Throttling section
// ---------------------------------------------------------------------------

function ThrottlingSection({ ts }: { ts: NonNullable<AppData['ThrottlingStats']> }) {
    const [open, setOpen] = useState(false);

    const severityBadges: Record<number, React.ReactNode> = {
        4: <span className="inline-block px-2 py-0.5 text-xs font-semibold rounded bg-red-600 text-white">Critical</span>,
        3: <span className="inline-block px-2 py-0.5 text-xs font-semibold rounded bg-orange-500 text-white">Warning</span>,
        2: <span className="inline-block px-2 py-0.5 text-xs font-semibold rounded bg-yellow-500 text-gray-800">Low</span>,
        1: <span className="inline-block px-2 py-0.5 text-xs font-semibold rounded bg-blue-500 text-white">Minimal</span>,
        0: <span className="inline-block px-2 py-0.5 text-xs font-semibold rounded bg-green-500 text-white">Normal</span>,
    };

    const statusColorMap: Record<string, string> = {
        Critical: 'text-red-600 dark:text-red-400 font-bold',
        Warning: 'text-orange-600 dark:text-orange-400 font-semibold',
        Low: 'text-yellow-600 dark:text-yellow-400',
        Minimal: 'text-blue-500 dark:text-blue-400',
    };

    const stats: [string, React.ReactNode][] = [
        ['Status', <span className={statusColorMap[ts.ThrottlingStatus ?? ''] ?? 'text-green-600 dark:text-green-400'}>{ts.ThrottlingStatus}</span>],
        ['Severity', `${ts.ThrottlingSeverity ?? 0}/4`],
        ['Total Requests', (ts.TotalRequests ?? 0).toLocaleString()],
        ['Successful Requests', (ts.SuccessfulRequests ?? 0).toLocaleString()],
        ['429 Errors', <span className="text-red-600 dark:text-red-400 font-bold">{(ts.Total429Errors ?? 0).toLocaleString()}</span>],
        ['Throttle Rate', <span className="text-red-600 dark:text-red-400 font-bold">{ts.ThrottleRate ?? 0}%</span>],
        ['Client Errors (4xx)', (ts.TotalClientErrors ?? 0).toLocaleString()],
        ['Server Errors (5xx)', (ts.TotalServerErrors ?? 0).toLocaleString()],
        ['Success Rate', <span className="text-green-600 dark:text-green-400">{ts.SuccessRate ?? 0}%</span>],
        ['Error Rate', `${ts.ErrorRate ?? 0}%`],
    ];

    if (ts.FirstOccurrence) stats.push(['First Seen', new Date(ts.FirstOccurrence).toLocaleString()]);
    if (ts.LastOccurrence) stats.push(['Last Seen', new Date(ts.LastOccurrence).toLocaleString()]);

    return (
        <div className="border-b dark:border-gray-600 pb-4 bg-purple-50 dark:bg-purple-900/30 p-4 rounded-lg">
            <button
                onClick={() => setOpen(!open)}
                className="flex items-center gap-2 w-full text-left"
            >
                <span className={`inline-block transition-transform text-purple-400 dark:text-purple-300 ${open ? 'rotate-90' : ''}`}>▶</span>
                <span className="font-bold text-xs uppercase tracking-wider text-purple-600 dark:text-purple-300">
                    Throttling Statistics
                </span>
                <span className="ml-1">{severityBadges[ts.ThrottlingSeverity ?? 0]}</span>
            </button>
            {open && (
                <div className="grid grid-cols-2 gap-2 text-sm dark:text-gray-300 mt-3">
                    {stats.map(([label, value]) => (
                        <div key={label}>
                            <span className="font-semibold">{label}:</span> {value}
                        </div>
                    ))}
                </div>
            )}
        </div>
    );
}

// ---------------------------------------------------------------------------
// 6. Permission diff view
// ---------------------------------------------------------------------------

type PermDiff = { name: string; tag: 'keep' | 'remove' | 'add'; scopeType: string; perm?: Permission };

function PermissionDiff({ app }: { app: AppData }) {
    const current = toArray(app.CurrentPermissions) as (Permission | string)[];
    const excess = toArray(app.ExcessPermissions) as (Permission | string)[];
    const missing = toArray(app.RequiredPermissions) as (Permission | string)[];
    const optimal = toArray(app.OptimalPermissions);

    if (current.length === 0 && excess.length === 0 && missing.length === 0 && optimal.length === 0) return null;

    const toName = (p: Permission | string) => typeof p === 'string' ? p : p.Permission;
    const toPerm = (p: Permission | string): Permission | undefined => typeof p === 'string' ? undefined : p;

    // Keys include scope type so Delegated and Application grants of the same name are distinct
    const toKey = (name: string, scope: string) => `${name.toLowerCase()}|${scope.toLowerCase()}`;

    const excessNames = new Set(excess.map(toName));
    const currentKeys = new Set(
        current.map((p) => {
            const name = toName(p);
            const scope = toPerm(p)?.ScopeType ?? getPermissionType(app, name);
            return toKey(name, scope);
        })
    );
    const missingKeys = new Set(
        missing.map((p) => {
            const name = toName(p);
            const scope = toPerm(p)?.ScopeType ?? getPermissionType(app, name);
            return toKey(name, scope);
        })
    );

    const rows: PermDiff[] = [];

    current.forEach((p) => {
        const name = toName(p);
        const perm = toPerm(p);
        const scopeType = perm?.ScopeType ?? getPermissionType(app, name);
        rows.push({ name, tag: excessNames.has(name) ? 'remove' : 'keep', scopeType, perm });
    });

    missing.forEach((p) => {
        const name = toName(p);
        const perm = toPerm(p);
        const scopeType = perm?.ScopeType ?? getPermissionType(app, name);
        rows.push({ name, tag: 'add', scopeType, perm });
    });

    // Optimal permissions not already covered (matching both name and scope type)
    optimal.forEach((p) => {
        const name = p.Permission;
        const scopeType = p.ScopeType ?? getPermissionType(app, name);
        if (!currentKeys.has(toKey(name, scopeType)) && !missingKeys.has(toKey(name, scopeType))) {
            rows.push({ name, tag: 'add', scopeType, perm: p });
        }
    });

    const order = { remove: 0, keep: 1, add: 2 };
    rows.sort((a, b) => order[a.tag] - order[b.tag]);

    const tagStyle: Record<PermDiff['tag'], string> = {
        remove: 'bg-red-100 dark:bg-red-900/40 text-red-700 dark:text-red-300 border border-red-300 dark:border-red-700',
        keep: 'bg-gray-100 dark:bg-gray-700/60 text-gray-600 dark:text-gray-300 border border-gray-300 dark:border-gray-600',
        add: 'bg-yellow-100 dark:bg-yellow-900/40 text-yellow-700 dark:text-yellow-300 border border-yellow-300 dark:border-yellow-700',
    };
    const tagLabel: Record<PermDiff['tag'], string> = { remove: '− remove', keep: '✓ keep', add: '+ add' };
    const rowBg: Record<PermDiff['tag'], string> = {
        remove: 'bg-red-50 dark:bg-red-900/10',
        keep: '',
        add: 'bg-yellow-50 dark:bg-yellow-900/10',
    };

    const removeCount = rows.filter(r => r.tag === 'remove').length;
    const addCount = rows.filter(r => r.tag === 'add').length;
    const keepCount = rows.filter(r => r.tag === 'keep').length;

    return (
        <div className="border-b dark:border-gray-600 pb-4">
            <h4 className="font-bold text-xs uppercase tracking-wider text-gray-500 dark:text-gray-400 mb-1">
                Permission Changes
            </h4>
            <p className="text-xs text-gray-400 dark:text-gray-500 mb-3">
                {removeCount} to remove &middot; {addCount} to add &middot; {keepCount} to keep
            </p>
            <div className="rounded-lg border dark:border-gray-600 overflow-hidden text-sm">
                {rows.map((r, i) => (
                    <div key={i} className={`flex items-center gap-2 px-3 py-2 border-b last:border-b-0 dark:border-gray-600 ${rowBg[r.tag]}`}>
                        <span className={`shrink-0 px-1.5 py-0.5 rounded text-xs font-semibold ${tagStyle[r.tag]}`}>{tagLabel[r.tag]}</span>
                        <span className="font-mono text-xs flex-1 dark:text-gray-200">{r.name}</span>
                        <PermissionTypeBadge type={r.scopeType} />
                        <RiskBadge permission={r.perm} level={r.perm?.PrivilegeLevel} />
                    </div>
                ))}
            </div>
        </div>
    );
}

// ---------------------------------------------------------------------------
// Optimal permissions
// ---------------------------------------------------------------------------

function OptimalPermEntry({ perm, scopeType, activities }: { perm: OptimalPermission; scopeType: string; activities: Activity[] }) {
    const [open, setOpen] = useState(false);
    return (
        <div className="mb-3 bg-green-50 dark:bg-green-900/20 p-3 rounded-lg border border-green-200 dark:border-green-800">
            <div className="font-medium text-green-700 dark:text-green-300 text-sm">
                {perm.Permission}
                <PermissionTypeBadge type={scopeType} />
                <RiskBadge permission={perm} level={perm.PrivilegeLevel} />
                <span className="text-xs text-gray-500 dark:text-gray-400 ml-1">(covers {perm.ActivitiesCovered} activit{perm.ActivitiesCovered === 1 ? 'y' : 'ies'})</span>
            </div>
            {activities.length > 0 && (
                <div className="mt-2 ml-2">
                    <button
                        onClick={() => setOpen(!open)}
                        className="flex items-center gap-1 text-xs font-semibold text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200"
                    >
                        <span className={`inline-block transition-transform ${open ? 'rotate-90' : ''}`}>▶</span>
                        Covered Endpoints ({activities.length})
                    </button>
                    {open && (
                        <ul className="text-xs space-y-1 text-gray-600 dark:text-gray-300 mt-2 ml-3">
                            {activities.map((a, j) => {
                                const method = a.Method ?? 'GET';
                                const path = a.Path ?? a.Endpoint ?? a.Uri ?? '';
                                const version = a.Version ?? '';
                                const fullPath = version ? `https://graph.microsoft.com/${version}${path}` : path;
                                return (
                                    <li key={j} className="font-mono flex items-center gap-1.5">
                                        <MethodBadge method={method} />
                                        <span>{fullPath}</span>
                                    </li>
                                );
                            })}
                        </ul>
                    )}
                </div>
            )}
        </div>
    );
}

function OptimalPermissionsSection({ perms, app }: { perms: OptimalPermission[]; app: AppData }) {
    if (!perms.length) return null;
    return (
        <div className="border-b dark:border-gray-600 pb-4">
            <h4 className="font-bold text-xs uppercase tracking-wider text-green-600 dark:text-green-400 mb-3">
                Optimal Permissions <span className="text-gray-400 dark:text-gray-500 font-normal normal-case">({perms.length})</span>
            </h4>
            {perms.map((p, i) => (
                <OptimalPermEntry
                    key={i}
                    perm={p}
                    scopeType={p.ScopeType ?? getPermissionType(app, p.Permission)}
                    activities={toArray(p.Activities)}
                />
            ))}
        </div>
    );
}

// ---------------------------------------------------------------------------
// Activity section — no inner height cap
// ---------------------------------------------------------------------------

function ActivitySection({ activities, unmatched }: { activities: Activity[]; unmatched: Activity[] }) {
    const unmatchedPaths = new Set(unmatched.map(u => u.Path ?? u.Uri ?? ''));
    return (
        <div className="space-y-4">
            {activities.length > 0 && (
                <div>
                    <h4 className="font-bold text-xs uppercase tracking-wider text-gray-500 dark:text-gray-400 mb-3">
                        API Activities <span className="font-normal normal-case">({activities.length})</span>
                    </h4>
                    <div className="rounded-lg border dark:border-gray-600 overflow-hidden">
                        <table className="min-w-full text-sm dark:text-gray-300">
                            <thead className="bg-gray-50 dark:bg-gray-700 sticky top-0">
                                <tr>
                                    <th className="px-3 py-2 text-left text-xs font-semibold uppercase tracking-wider w-24">Method</th>
                                    <th className="px-3 py-2 text-left text-xs font-semibold uppercase tracking-wider">Endpoint</th>
                                </tr>
                            </thead>
                            <tbody>
                                {activities.map((a, i) => {
                                    const isUnmatched = unmatchedPaths.has(a.Path ?? a.Uri ?? '');
                                    return (
                                        <tr key={i} className={`border-b dark:border-gray-600 last:border-b-0 ${isUnmatched ? 'bg-red-50 dark:bg-red-900/20' : i % 2 !== 0 ? 'bg-gray-50/50 dark:bg-gray-700/20' : ''}`}>
                                            <td className="px-3 py-2"><MethodBadge method={a.Method ?? 'GET'} /></td>
                                            <td className="px-3 py-2 font-mono text-xs break-all">
                                                {a.Uri}
                                                {isUnmatched && <span className="ml-2 text-red-500 font-semibold text-xs">⚠ unmatched</span>}
                                            </td>
                                        </tr>
                                    );
                                })}
                            </tbody>
                        </table>
                    </div>
                </div>
            )}
            {unmatched.length > 0 && (
                <div className="bg-red-50 dark:bg-red-900/30 p-4 rounded-lg border border-red-200 dark:border-red-800">
                    <h4 className="font-bold text-xs uppercase tracking-wider text-red-600 dark:text-red-400 mb-2">
                        Unmatched Activities <span className="font-normal normal-case">({unmatched.length})</span>
                    </h4>
                    <p className="text-xs text-red-500 dark:text-red-400 mb-3">These endpoints could not be mapped to known Graph API paths — the least-privilege permissions cannot be determined.</p>
                    <ul className="space-y-1.5">
                        {unmatched.map((a, i) => (
                            <li key={i} className="flex items-center gap-2 text-sm text-red-700 dark:text-red-400">
                                <MethodBadge method={a.Method ?? 'GET'} />
                                <span className="font-mono text-xs break-all">{a.Path ?? a.Uri}</span>
                            </li>
                        ))}
                    </ul>
                </div>
            )}
            {activities.length === 0 && unmatched.length === 0 && (
                <p className="text-sm text-gray-500 dark:text-gray-400">No activity recorded in the analysis period.</p>
            )}
        </div>
    );
}

// ---------------------------------------------------------------------------
// Modal
// ---------------------------------------------------------------------------

export function AppDetailModal({ app, onClose }: Props) {
    useEffect(() => {
        document.body.style.overflow = 'hidden';
        function onKey(e: KeyboardEvent) { if (e.key === 'Escape') onClose(); }
        document.addEventListener('keydown', onKey);
        return () => {
            document.body.style.overflow = '';
            document.removeEventListener('keydown', onKey);
        };
    }, [onClose]);

    if (!app) return null;

    const activities = toArray(app.Activity);
    const unmatched = toArray(app.UnmatchedActivities);
    const optimal = toArray(app.OptimalPermissions);

    return (
        <div
            className="fixed inset-0 bg-gray-600 dark:bg-gray-900 bg-opacity-50 dark:bg-opacity-70 overflow-y-auto h-full w-full z-50 transition-colors duration-200"
            onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}
        >
            <div
                className="relative top-4 mx-auto p-5 border border-gray-300 dark:border-gray-600 w-11/12 max-w-[90%] shadow-lg rounded-lg bg-white dark:bg-gray-800 transition-colors duration-200"
                style={{ maxHeight: '92vh' }}
            >
                <div className="flex justify-between items-start mb-2">
                    <div>
                        <h3 className="text-2xl font-bold text-gray-900 dark:text-gray-100">{app.PrincipalName}</h3>
                        <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">{app.PrincipalId}</p>
                    </div>
                    <button
                        onClick={onClose}
                        className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 text-3xl font-bold leading-none ml-4 shrink-0"
                        title="Close (Esc)"
                    >
                        &times;
                    </button>
                </div>

                <SummaryBanner app={app} />

                <div className="overflow-y-auto dark:text-gray-200 space-y-5 pt-4" style={{ maxHeight: 'calc(92vh - 140px)' }}>
                    <AppInfo app={app} />
                    {app.ThrottlingStats && <ThrottlingSection ts={app.ThrottlingStats} />}
                    <PermissionDiff app={app} />
                    <OptimalPermissionsSection perms={optimal} app={app} />
                    {(activities.length > 0 || unmatched.length > 0) && (
                        <ActivitySection activities={activities} unmatched={unmatched} />
                    )}
                </div>
            </div>
        </div>
    );
}
