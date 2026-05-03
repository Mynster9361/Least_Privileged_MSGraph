import React, { useState } from 'react';
import { AppData, Activity, OptimalPermission, Permission, ThrottlingStats } from '../types';
import { toArray, getPermissionType, calculatePrivilegeMetrics } from '../utils/helpers';
import { PermissionTypeBadge, RiskBadge } from './Badges';

interface Props {
    app: AppData | null;
    onClose: () => void;
}

function AppInfo({ app }: { app: AppData }) {
    const metrics = calculatePrivilegeMetrics(app);
    const levelLabels: Record<number, string> = { 4: '4 - Critical', 3: '3 - High', 2: '2 - Medium', 1: '1 - Low', 0: 'None' };
    return (
        <div className="border-b dark:border-gray-600 pb-4">
            <h4 className="font-bold text-lg mb-2 dark:text-gray-100">Application Information</h4>
            <p className="dark:text-gray-300"><span className="font-semibold">Principal ID:</span> {app.PrincipalId}</p>
            <p className="dark:text-gray-300"><span className="font-semibold">Total App Roles:</span> {app.AppRoleCount}</p>
            <p className="dark:text-gray-300">
                <span className="font-semibold">Max Privilege Level:</span>{' '}
                {levelLabels[metrics.maxLevel] ?? metrics.maxLevel}
            </p>
            <p className="dark:text-gray-300"><span className="font-semibold">Privilege Score:</span> {metrics.score}</p>
            <p className="dark:text-gray-300">
                <span className="font-semibold">Matched All Activities:</span> {app.MatchedAllActivity ? 'Yes' : 'No'}
            </p>
        </div>
    );
}

function ThrottlingSection({ ts }: { ts: ThrottlingStats }) {
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
        <div className="border-b dark:border-gray-600 pb-4 bg-purple-50 dark:bg-purple-900/30 p-4 rounded">
            <h4 className="font-bold text-lg mb-2 text-purple-700 dark:text-purple-300">
                Throttling Statistics {severityBadges[ts.ThrottlingSeverity ?? 0]}
            </h4>
            <div className="grid grid-cols-2 gap-2 text-sm dark:text-gray-300">
                {stats.map(([label, value]) => (
                    <div key={label}>
                        <span className="font-semibold">{label}:</span> {value}
                    </div>
                ))}
            </div>
        </div>
    );
}

function PermissionList({
    title,
    perms,
    app,
    colorClass,
}: {
    title: string;
    perms: (Permission | string)[];
    app: AppData;
    colorClass?: string;
}) {
    if (!perms.length) return null;
    return (
        <div className="border-b dark:border-gray-600 pb-4">
            <h4 className={`font-bold text-lg mb-2 ${colorClass ?? 'dark:text-gray-100'}`}>
                {title} ({perms.length})
            </h4>
            <ul className={`list-disc list-inside text-sm space-y-1 ${colorClass ?? 'dark:text-gray-300'}`}>
                {perms.map((p, i) => {
                    const name = typeof p === 'string' ? p : p.Permission;
                    const scopeType = typeof p === 'string' ? getPermissionType(app, name) : (p.ScopeType ?? getPermissionType(app, name));
                    const perm = typeof p === 'string' ? undefined : p;
                    return (
                        <li key={i}>
                            {name}
                            <PermissionTypeBadge type={scopeType} />
                            <RiskBadge permission={perm} level={perm?.PrivilegeLevel} />
                        </li>
                    );
                })}
            </ul>
        </div>
    );
}

function OptimalPermissionsSection({ perms, app }: { perms: OptimalPermission[]; app: AppData }) {
    if (!perms.length) return null;
    return (
        <div className="border-b dark:border-gray-600 pb-4">
            <h4 className="font-bold text-lg mb-2 text-green-600 dark:text-green-400">Optimal Permissions ({perms.length})</h4>
            {perms.map((p, i) => {
                const scopeType = p.ScopeType ?? getPermissionType(app, p.Permission);
                const activities = toArray(p.Activities);
                return (
                    <OptimalPermEntry key={i} perm={p} scopeType={scopeType} activities={activities} />
                );
            })}
        </div>
    );
}

function OptimalPermEntry({
    perm,
    scopeType,
    activities,
}: {
    perm: OptimalPermission;
    scopeType: string;
    activities: Activity[];
}) {
    const [open, setOpen] = useState(false);
    return (
        <div className="mb-4 bg-green-50 dark:bg-green-900/20 p-3 rounded">
            <div className="font-medium text-green-700 dark:text-green-300">
                {perm.Permission}
                <PermissionTypeBadge type={scopeType} />
                <RiskBadge permission={perm} level={perm.PrivilegeLevel} />
                <span className="text-sm text-gray-600 dark:text-gray-400 ml-1">(Covers {perm.ActivitiesCovered} activities)</span>
            </div>
            {activities.length > 0 && (
                <div className="mt-2 ml-4">
                    <button
                        onClick={() => setOpen(!open)}
                        className="flex items-center gap-1 text-xs font-semibold text-gray-600 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200"
                    >
                        <span className={`inline-block transition-transform ${open ? 'rotate-90' : ''}`}>▶</span>
                        Covered Endpoints
                    </button>
                    {open && (
                        <ul className="text-xs space-y-1 text-gray-700 dark:text-gray-300 mt-2">
                            {activities.map((a, j) => {
                                const method = a.Method ?? 'GET';
                                const path = a.Path ?? a.Endpoint ?? a.Uri ?? '';
                                const version = a.Version ?? '';
                                const fullPath = version ? `https://graph.microsoft.com/${version}${path}` : path;
                                return (
                                    <li key={j} className="font-mono">
                                        <span className="font-semibold">{method}</span> {fullPath}
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

function ActivitySection({ activities }: { activities: Activity[] }) {
    if (!activities.length) return null;
    return (
        <div>
            <h4 className="font-bold text-lg mb-2 dark:text-gray-100">API Activities ({activities.length})</h4>
            <div className="max-h-64 overflow-y-auto">
                <table className="min-w-full text-sm dark:text-gray-300">
                    <thead className="bg-gray-50 dark:bg-gray-700 sticky top-0">
                        <tr>
                            <th className="px-2 py-2 text-left">Method</th>
                            <th className="px-2 py-2 text-left">Endpoint</th>
                        </tr>
                    </thead>
                    <tbody>
                        {activities.map((a, i) => (
                            <tr key={i} className="border-b dark:border-gray-600">
                                <td className="px-2 py-2 font-mono text-xs">{a.Method}</td>
                                <td className="px-2 py-2 font-mono text-xs break-all">{a.Uri}</td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>
        </div>
    );
}

function UnmatchedSection({ unmatched }: { unmatched: Activity[] }) {
    if (!unmatched.length) return null;
    return (
        <div className="bg-red-50 dark:bg-red-900/30 p-4 rounded">
            <h4 className="font-bold text-lg mb-2 text-red-600 dark:text-red-400">Unmatched Activities ({unmatched.length})</h4>
            <ul className="list-disc list-inside text-sm space-y-1 text-red-700 dark:text-red-400">
                {unmatched.map((a, i) => (
                    <li key={i}>{a.Method} {a.Path}</li>
                ))}
            </ul>
        </div>
    );
}

export function AppDetailModal({ app, onClose }: Props) {
    if (!app) return null;

    return (
        <div
            className="fixed inset-0 bg-gray-600 dark:bg-gray-900 bg-opacity-50 dark:bg-opacity-70 overflow-y-auto h-full w-full z-50 transition-colors duration-200"
            onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}
        >
            <div
                className="relative top-4 mx-auto p-5 border border-gray-300 dark:border-gray-600 w-11/12 max-w-[90%] shadow-lg rounded-lg bg-white dark:bg-gray-800 transition-colors duration-200"
                style={{ maxHeight: '92vh' }}
            >
                <div className="flex justify-between items-center mb-4">
                    <h3 className="text-2xl font-bold text-gray-900 dark:text-gray-100">{app.PrincipalName}</h3>
                    <button
                        onClick={onClose}
                        className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 text-3xl font-bold"
                    >
                        &times;
                    </button>
                </div>
                <div className="mt-4 overflow-y-auto dark:text-gray-200 space-y-4" style={{ maxHeight: 'calc(92vh - 120px)' }}>
                    <AppInfo app={app} />
                    {app.ThrottlingStats && <ThrottlingSection ts={app.ThrottlingStats} />}
                    <PermissionList title="Current Permissions" perms={toArray(app.CurrentPermissions)} app={app} />
                    <OptimalPermissionsSection perms={toArray(app.OptimalPermissions)} app={app} />
                    <PermissionList
                        title="Excess Permissions"
                        perms={toArray(app.ExcessPermissions)}
                        app={app}
                        colorClass="text-red-600 dark:text-red-400"
                    />
                    <PermissionList
                        title="Missing Permissions"
                        perms={toArray(app.RequiredPermissions)}
                        app={app}
                        colorClass="text-yellow-600 dark:text-yellow-400"
                    />
                    <ActivitySection activities={toArray(app.Activity)} />
                    <UnmatchedSection unmatched={toArray(app.UnmatchedActivities)} />
                </div>
            </div>
        </div>
    );
}
