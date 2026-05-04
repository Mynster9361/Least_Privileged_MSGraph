import React from 'react';
import { AppData } from '../types';
import { getAppStatus, calculatePrivilegeMetrics, toArray } from '../utils/helpers';
import { SeverityChip, SeverityLevel } from './SeverityChip';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface Finding {
    severity: SeverityLevel;
    title: string;
    description: string;
    appName: string;
    appId: string;
    action: string;
    portalUrl: string;
}

const SEVERITY_ORDER: Record<SeverityLevel, number> = {
    critical: 0, high: 1, medium: 2, low: 3, none: 4, info: 5,
};

const SEVERITY_LABEL: Record<SeverityLevel, string> = {
    critical: 'Critical', high: 'High', medium: 'Medium', low: 'Low', none: 'None', info: 'Info',
};

// ---------------------------------------------------------------------------
// Build findings list from app data
// ---------------------------------------------------------------------------

function buildFindings(appData: AppData[]): Finding[] {
    const findings: Finding[] = [];

    for (const app of appData) {
        const name = app.PrincipalName ?? 'Unknown';
        const id = app.PrincipalId ?? '';
        const status = getAppStatus(app);
        const metrics = calculatePrivilegeMetrics(app);
        const ts = app.ThrottlingStats;
        const portalUrl = id
            ? `https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Overview/appId/${encodeURIComponent(id)}`
            : '';

        // Unmatched activities → Critical
        if (status === 'danger') {
            const count = toArray(app.UnmatchedActivities).length;
            findings.push({
                severity: 'critical',
                title: 'Unmatched API activities',
                description: `${count} API call${count !== 1 ? 's' : ''} could not be mapped to any assigned permission.`,
                appName: name, appId: id, action: 'Investigate activities', portalUrl,
            });
        }

        // Critical throttling → Critical
        if (ts?.ThrottlingSeverity === 4) {
            findings.push({
                severity: 'critical',
                title: 'Critical API throttling',
                description: `${(ts.Total429Errors ?? 0).toLocaleString()} 429 errors at ${ts.ThrottleRate ?? 0}% throttle rate.`,
                appName: name, appId: id, action: 'Review request volume', portalUrl,
            });
        }

        // L4 privilege → High
        if (metrics.maxLevel === 4) {
            findings.push({
                severity: 'high',
                title: 'Critical-level permission assigned',
                description: `${metrics.highAssignments} permission${metrics.highAssignments !== 1 ? 's' : ''} at Level 4 (Critical). Privilege score: ${metrics.score}.`,
                appName: name, appId: id, action: 'Review permissions', portalUrl,
            });
        }

        // Excess / misaligned permissions → High or Medium
        if (status === 'warning' || status === 'misaligned') {
            const excessCount = toArray(app.ExcessPermissions).length;
            if (excessCount > 0) {
                findings.push({
                    severity: status === 'misaligned' ? 'high' : 'medium',
                    title: `${excessCount} excess permission${excessCount !== 1 ? 's' : ''}`,
                    description: `App holds ${excessCount} permission${excessCount !== 1 ? 's' : ''} beyond what its observed API activity requires.`,
                    appName: name, appId: id, action: 'Remove excess permissions', portalUrl,
                });
            }
        }

        // Warning throttling → Medium
        if (ts?.ThrottlingSeverity === 3) {
            findings.push({
                severity: 'medium',
                title: 'Elevated API throttling',
                description: `${(ts.Total429Errors ?? 0).toLocaleString()} 429 errors detected.`,
                appName: name, appId: id, action: 'Optimize request patterns', portalUrl,
            });
        }

        // L3 privilege → Medium
        if (metrics.maxLevel === 3) {
            findings.push({
                severity: 'medium',
                title: 'High-level permission assigned',
                description: `${metrics.highAssignments} permission${metrics.highAssignments !== 1 ? 's' : ''} at Level 3 (High). Privilege score: ${metrics.score}.`,
                appName: name, appId: id, action: 'Review if high permissions are needed', portalUrl,
            });
        }

        // No activity → Low
        if (toArray(app.Activity).length === 0 && status !== 'danger') {
            findings.push({
                severity: 'low',
                title: 'No recorded API activity',
                description: 'No API activity has been recorded for this application in the analysis period.',
                appName: name, appId: id, action: 'Verify app is still in use', portalUrl,
            });
        }

        // Under-privileged → Low
        if (status === 'missing') {
            const missingCount = toArray(app.RequiredPermissions).length;
            findings.push({
                severity: 'low',
                title: `${missingCount} missing permission${missingCount !== 1 ? 's' : ''}`,
                description: `App is under-privileged: ${missingCount} required permission${missingCount !== 1 ? 's' : ''} not yet assigned.`,
                appName: name, appId: id, action: 'Add required permissions', portalUrl,
            });
        }
    }

    return findings.sort((a, b) => SEVERITY_ORDER[a.severity] - SEVERITY_ORDER[b.severity]);
}

// ---------------------------------------------------------------------------
// Finding card
// ---------------------------------------------------------------------------

function FindingCard({ finding }: { finding: Finding }) {
    return (
        <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-lg p-4 flex items-start gap-4 hover:border-slate-300 dark:hover:border-slate-700 transition-colors">
            <div className="flex-shrink-0 pt-0.5">
                <SeverityChip severity={finding.severity} label={SEVERITY_LABEL[finding.severity]} />
            </div>
            <div className="flex-1 min-w-0">
                <div className="flex items-start justify-between gap-4">
                    <div className="min-w-0">
                        <div className="font-semibold text-sm text-slate-800 dark:text-slate-100">
                            {finding.title}
                        </div>
                        <div className="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
                            {finding.description}
                        </div>
                    </div>
                    {finding.portalUrl && (
                        <a
                            href={finding.portalUrl}
                            target="_blank"
                            rel="noopener noreferrer"
                            onClick={(e) => e.stopPropagation()}
                            className="flex-shrink-0 flex items-center gap-1 text-xs text-indigo-500 hover:text-indigo-700 dark:text-indigo-400 dark:hover:text-indigo-300 whitespace-nowrap transition-colors"
                            title="Open in Entra Portal"
                        >
                            {finding.action}
                            <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                            </svg>
                        </a>
                    )}
                </div>
                <div className="mt-1.5 text-xs text-slate-500 dark:text-slate-500 font-medium">
                    {finding.appName}
                    {finding.appId && (
                        <span className="ml-1.5 font-mono text-slate-400 dark:text-slate-600 font-normal">
                            {finding.appId}
                        </span>
                    )}
                </div>
            </div>
        </div>
    );
}

// ---------------------------------------------------------------------------
// Recommendations view
// ---------------------------------------------------------------------------

interface Props {
    appData: AppData[];
}

export function Recommendations({ appData }: Props) {
    const findings = buildFindings(appData);
    const counts = { critical: 0, high: 0, medium: 0, low: 0 } as Record<string, number>;
    findings.forEach((f) => {
        if (f.severity !== 'none' && f.severity !== 'info') counts[f.severity]++;
    });

    if (findings.length === 0) {
        return (
            <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-lg p-12 text-center">
                <svg className="w-12 h-12 text-emerald-400 mx-auto mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z" />
                </svg>
                <p className="text-slate-500 dark:text-slate-400 font-medium">
                    No findings — all applications look healthy.
                </p>
            </div>
        );
    }

    return (
        <div className="space-y-5">
            <div>
                <h2 className="text-xl font-bold text-slate-800 dark:text-slate-100">Findings</h2>
                <p className="text-sm text-slate-500 dark:text-slate-400 mt-0.5">
                    {findings.length} finding{findings.length !== 1 ? 's' : ''} across {appData.length} application{appData.length !== 1 ? 's' : ''}
                </p>
            </div>

            {/* Severity summary chips */}
            <div className="flex flex-wrap gap-3">
                {(['critical', 'high', 'medium', 'low'] as SeverityLevel[]).map((sev) =>
                    counts[sev] > 0 ? (
                        <div
                            key={sev}
                            className="flex items-center gap-2.5 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-lg px-3 py-2"
                        >
                            <SeverityChip severity={sev} label={SEVERITY_LABEL[sev]} />
                            <span className="text-lg font-bold text-slate-800 dark:text-slate-200 tabular-nums">
                                {counts[sev]}
                            </span>
                        </div>
                    ) : null
                )}
            </div>

            {/* Findings list */}
            <div className="space-y-2">
                {findings.map((finding, i) => (
                    <FindingCard key={i} finding={finding} />
                ))}
            </div>
        </div>
    );
}
