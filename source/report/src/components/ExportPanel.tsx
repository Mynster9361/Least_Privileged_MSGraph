import React, { useState } from 'react';
import { AppData } from '../types';
import { exportToCSV, calculateStats } from '../utils/helpers';

// ---------------------------------------------------------------------------
// Props
// ---------------------------------------------------------------------------

interface Props {
    appData: AppData[];
    title: string;
    tenantName: string;
    generatedOn: string;
}

// ---------------------------------------------------------------------------
// Action card tile
// ---------------------------------------------------------------------------

function ActionCard({
    title,
    description,
    buttonLabel,
    icon,
    onClick,
    done,
}: {
    title: string;
    description: string;
    buttonLabel: string;
    icon: React.ReactNode;
    onClick: () => void;
    done?: boolean;
}) {
    return (
        <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-lg p-5 flex flex-col gap-4">
            <div className="w-10 h-10 rounded-lg bg-indigo-50 dark:bg-indigo-950/50 flex items-center justify-center text-indigo-600 dark:text-indigo-400 flex-shrink-0">
                {icon}
            </div>
            <div className="flex-1">
                <div className="font-semibold text-slate-800 dark:text-slate-100">{title}</div>
                <p className="text-sm text-slate-500 dark:text-slate-400 mt-1 leading-relaxed">{description}</p>
            </div>
            <button
                onClick={onClick}
                className={`inline-flex items-center justify-center gap-2 px-4 py-2 text-sm font-semibold rounded-lg transition-colors ${done
                        ? 'bg-emerald-600 text-white'
                        : 'bg-indigo-600 hover:bg-indigo-700 text-white'
                    }`}
            >
                {done ? (
                    <>
                        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                        </svg>
                        Copied!
                    </>
                ) : (
                    buttonLabel
                )}
            </button>
        </div>
    );
}

// ---------------------------------------------------------------------------
// ExportPanel view
// ---------------------------------------------------------------------------

export function ExportPanel({ appData, title, tenantName, generatedOn }: Props) {
    const stats = calculateStats(appData);
    const [copied, setCopied] = useState(false);

    function copySummary() {
        const lines = [
            `# ${title}`,
            `Tenant: ${tenantName}`,
            `Generated: ${generatedOn}`,
            '',
            '## Summary',
            `Total Applications : ${stats.total}`,
            `Optimal            : ${stats.fullyMatched}`,
            `Excess Permissions : ${stats.withExcess}`,
            `Unmatched Activity : ${stats.withUnmatched}`,
            `Throttled Apps     : ${stats.throttledApps}`,
            `Critical Throttling: ${stats.criticalThrottling}`,
            `Total 429 Errors   : ${stats.total429.toLocaleString()}`,
        ];
        navigator.clipboard.writeText(lines.join('\n')).then(() => {
            setCopied(true);
            setTimeout(() => setCopied(false), 2500);
        });
    }

    const summaryItems = [
        { label: 'Total Applications', value: stats.total },
        { label: 'Optimal', value: stats.fullyMatched },
        { label: 'Excess Permissions', value: stats.withExcess },
        { label: 'Unmatched Activity', value: stats.withUnmatched },
        { label: 'Throttled Apps', value: stats.throttledApps },
        { label: 'Critical Throttling', value: stats.criticalThrottling },
    ];

    return (
        <div className="space-y-6">
            <div>
                <h2 className="text-xl font-bold text-slate-800 dark:text-slate-100">Export</h2>
                <p className="text-sm text-slate-500 dark:text-slate-400 mt-0.5">
                    Download or share this analysis.
                </p>
            </div>

            {/* Export actions */}
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                <ActionCard
                    title="CSV Spreadsheet"
                    description="All application data as a semicolon-delimited file. Import into Excel, Power BI, or a SIEM."
                    buttonLabel="Download CSV"
                    icon={
                        <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3" />
                        </svg>
                    }
                    onClick={() => exportToCSV(appData)}
                />

                <ActionCard
                    title="Print / Save as PDF"
                    description="Opens the browser print dialog. Select 'Save as PDF' to create a shareable document for leadership."
                    buttonLabel="Print"
                    icon={
                        <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M6.72 13.829c-.24.03-.48.062-.72.096m.72-.096a42.415 42.415 0 0110.56 0m-10.56 0L6.34 18m10.94-4.171c.24.03.48.062.72.096m-.72-.096L17.66 18m0 0l.229 2.523a1.125 1.125 0 01-1.12 1.227H7.231c-.662 0-1.18-.568-1.12-1.227L6.34 18m11.318 0h1.091A2.25 2.25 0 0021 15.75V9.456c0-1.081-.768-2.015-1.837-2.175a48.055 48.055 0 00-1.913-.247M6.34 18H5.25A2.25 2.25 0 013 15.75V9.456c0-1.081.768-2.015 1.837-2.175a48.056 48.056 0 011.913-.247m10.5 0a48.536 48.536 0 00-10.5 0m10.5 0V3.375c0-.621-.504-1.125-1.125-1.125h-8.25c-.621 0-1.125.504-1.125 1.125v3.659M18 10.5h.008v.008H18V10.5zm-3 0h.008v.008H15V10.5z" />
                        </svg>
                    }
                    onClick={() => window.print()}
                />

                <ActionCard
                    title="Copy Summary"
                    description="Copy a Markdown-formatted summary to clipboard. Paste directly into Teams, Slack, or a ticket."
                    buttonLabel="Copy Markdown"
                    done={copied}
                    icon={
                        <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M15.666 3.888A2.25 2.25 0 0013.5 2.25h-3c-1.03 0-1.9.693-2.166 1.638m7.332 0c.055.194.084.4.084.612v0a.75.75 0 01-.75.75H9a.75.75 0 01-.75-.75v0c0-.212.03-.418.084-.612m7.332 0c.646.049 1.288.11 1.927.184 1.1.128 1.907 1.077 1.907 2.185V19.5a2.25 2.25 0 01-2.25 2.25H6.75A2.25 2.25 0 014.5 19.5V6.257c0-1.108.806-2.057 1.907-2.185a48.208 48.208 0 011.927-.184" />
                        </svg>
                    }
                    onClick={copySummary}
                />
            </div>

            {/* Stats summary card */}
            <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-lg p-5">
                <h3 className="text-sm font-semibold text-slate-700 dark:text-slate-300 mb-3 uppercase tracking-wider text-xs">
                    Report Summary
                </h3>
                <dl className="grid grid-cols-2 sm:grid-cols-3 gap-3">
                    {summaryItems.map(({ label, value }) => (
                        <div key={label} className="bg-slate-50 dark:bg-slate-800/50 rounded-lg p-3">
                            <dt className="text-xs text-slate-500 dark:text-slate-400 leading-tight">{label}</dt>
                            <dd className="text-2xl font-bold text-slate-800 dark:text-slate-100 mt-0.5 tabular-nums">
                                {value}
                            </dd>
                        </div>
                    ))}
                </dl>
            </div>
        </div>
    );
}
