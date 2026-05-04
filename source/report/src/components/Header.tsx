import React from 'react';
import { AppData } from '../types';
import { calculateStats, calculateStatusBreakdown, calculateThrottlingBreakdown } from '../utils/helpers';

// ---------------------------------------------------------------------------
// Horizontal stacked bar
// ---------------------------------------------------------------------------

interface BarSegment {
    key: string;
    count: number;
    color: string;
    label: string;
}

function StackedBar({ segments, total }: { segments: BarSegment[]; total: number }) {
    const safeTotal = total || 1;
    const active = segments.filter((s) => s.count > 0);
    if (active.length === 0) return null;
    return (
        <div className="mt-3">
            {/* Bar */}
            <div className="flex h-3.5 rounded-full overflow-hidden w-full">
                {active.map((seg) => (
                    <div
                        key={seg.key}
                        style={{ width: `${(seg.count / safeTotal) * 100}%`, backgroundColor: seg.color }}
                        title={`${seg.label}: ${seg.count} (${Math.round((seg.count / safeTotal) * 100)}%)`}
                        className="min-w-[3px] transition-all duration-500"
                    />
                ))}
            </div>
        </div>
    );
}

// ---------------------------------------------------------------------------
// Stat card
// ---------------------------------------------------------------------------

interface StatCardProps {
    bg: string;
    border: string;
    labelColor: string;
    valueColor: string;
    label: string;
    count: number | string;
    pct: string;
    onClick?: () => void;
    muted?: boolean;
}

function StatCard({ bg, border, labelColor, valueColor, label, count, pct, onClick, muted }: StatCardProps) {
    return (
        <div
            className={`${bg} rounded-lg p-3 sm:p-4 transition-all duration-200 ${onClick ? `cursor-pointer border border-transparent hover:border-slate-200 dark:hover:border-slate-700 hover:shadow-sm ${border}` : ''
                } ${muted ? 'opacity-80' : ''}`}
            onClick={onClick}
            title={onClick ? 'Click to filter' : undefined}
        >
            <div className={`${labelColor} text-xs sm:text-sm font-semibold`}>
                {label}
            </div>
            <div className={`text-xl sm:text-2xl font-bold mt-0.5 ${valueColor}`}>
                {count}
                {pct && <span className="text-sm font-normal ml-1 opacity-60">{pct}</span>}
            </div>
        </div>
    );
}


// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

interface Props {
    appData: AppData[];
    onFilterAll: () => void;
    onFilterOptimal: () => void;
    onFilterExcess: () => void;
    onFilterUnmatched: () => void;
    onFilterThrottled: () => void;
    onFilterCriticalThrottling: () => void;
}

export function Header({
    appData,
    onFilterAll,
    onFilterOptimal,
    onFilterExcess,
    onFilterUnmatched,
    onFilterThrottled,
    onFilterCriticalThrottling,
}: Props) {
    const stats = calculateStats(appData);
    const breakdown = calculateStatusBreakdown(appData);
    const throttling = calculateThrottlingBreakdown(appData);
    const pct = (n: number) => (stats.total > 0 ? Math.round((n / stats.total) * 100) : 0);

    const postureSegments: BarSegment[] = [
        { key: 'good', count: breakdown.good, color: '#22c55e', label: 'Optimal' },
        { key: 'warning', count: breakdown.warning, color: '#f59e0b', label: 'Excess' },
        { key: 'missing', count: breakdown.missing, color: '#06b6d4', label: 'Under-Priv.' },
        { key: 'misaligned', count: breakdown.misaligned, color: '#f97316', label: 'Misaligned' },
        { key: 'danger', count: breakdown.danger, color: '#ef4444', label: 'Unmatched' },
    ];

    const throttlingSegments: BarSegment[] = [
        { key: 'critical', count: throttling.critical, color: '#dc2626', label: 'Critical' },
        { key: 'warning', count: throttling.warning, color: '#f97316', label: 'Warning' },
        { key: 'low', count: throttling.low, color: '#eab308', label: 'Low' },
        { key: 'minimal', count: throttling.minimal, color: '#3b82f6', label: 'Minimal' },
        { key: 'normal', count: throttling.normal, color: '#22c55e', label: 'Normal' },
    ];

    const healthScore = pct(stats.fullyMatched);
    const healthLabel = healthScore >= 80 ? 'Healthy' : healthScore >= 60 ? 'Fair' : 'Critical';
    const healthColor =
        healthScore >= 80
            ? 'text-green-600 dark:text-green-400'
            : healthScore >= 60
                ? 'text-amber-600 dark:text-amber-400'
                : 'text-red-600 dark:text-red-400';
    const healthDotColor = healthScore >= 80 ? '#22c55e' : healthScore >= 60 ? '#f59e0b' : '#ef4444';
    const throttlingStatus = throttling.critical > 0
        ? { color: '#ef4444', label: 'Critical' }
        : throttling.warning > 0
            ? { color: '#f97316', label: 'Warning' }
            : throttling.low > 0
                ? { color: '#eab308', label: 'Low' }
                : { color: '#22c55e', label: 'Normal' };

    return (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 mb-4">
            {/* ── Permission Posture ─────────────────────────────────── */}
            <div className="bg-white dark:bg-slate-900 rounded-lg border border-slate-200 dark:border-slate-800 p-3 sm:p-5 transition-colors duration-200">
                <div className="flex items-center justify-between mb-2">
                    <h3 className="text-xs font-semibold uppercase tracking-wider text-gray-500 dark:text-gray-400">
                        Permission Posture
                    </h3>
                    <div className="flex items-center gap-1.5">
                        <span className="w-2 h-2 rounded-full" style={{ backgroundColor: healthDotColor }} />
                        <span className={`text-xs font-semibold ${healthColor}`}>{healthLabel}</span>
                    </div>
                </div>
                <div className="grid grid-cols-2 lg:grid-cols-4 gap-2 sm:gap-3">
                    <StatCard
                        bg="bg-gray-50 dark:bg-gray-700/40"
                        border="hover:border-gray-300 dark:hover:border-gray-500"
                        labelColor="text-gray-500 dark:text-gray-400"
                        valueColor="text-gray-800 dark:text-gray-200"
                        label="Total apps"
                        count={stats.total}
                        pct=""
                        onClick={onFilterAll}
                    />
                    <StatCard
                        bg="bg-green-50 dark:bg-green-900/30"
                        border="hover:border-green-300 dark:hover:border-green-500"
                        labelColor="text-green-600 dark:text-green-400"
                        valueColor="text-green-800 dark:text-green-300"
                        label="Optimal"
                        count={stats.fullyMatched}
                        pct={`/ ${pct(stats.fullyMatched)}%`}
                        onClick={onFilterOptimal}
                    />
                    <StatCard
                        bg="bg-amber-50 dark:bg-amber-900/30"
                        border="hover:border-amber-300 dark:hover:border-amber-500"
                        labelColor="text-amber-600 dark:text-amber-400"
                        valueColor="text-amber-800 dark:text-amber-300"
                        label="Needs review"
                        count={stats.withExcess}
                        pct={`/ ${pct(stats.withExcess)}%`}
                        onClick={onFilterExcess}
                    />
                    <StatCard
                        bg="bg-red-50 dark:bg-red-900/30"
                        border="hover:border-red-300 dark:hover:border-red-500"
                        labelColor="text-red-600 dark:text-red-400"
                        valueColor="text-red-800 dark:text-red-300"
                        label="Unmatched"
                        count={stats.withUnmatched}
                        pct={`/ ${pct(stats.withUnmatched)}%`}
                        onClick={onFilterUnmatched}
                    />
                </div>
                <StackedBar segments={postureSegments} total={stats.total} />
            </div>

            {/* ── API Throttling ─────────────────────────────────────── */}
            <div className="bg-white dark:bg-slate-900 rounded-lg border border-slate-200 dark:border-slate-800 p-3 sm:p-5 transition-colors duration-200">
                <div className="flex items-center justify-between mb-2">
                    <h3 className="text-xs font-semibold uppercase tracking-wider text-gray-400 dark:text-gray-500">
                        API Throttling
                    </h3>
                    <div className="flex items-center gap-1.5">
                        <span className="w-2 h-2 rounded-full" style={{ backgroundColor: throttlingStatus.color }} />
                        <span className="text-xs font-semibold text-gray-500 dark:text-gray-400">{throttlingStatus.label}</span>
                    </div>
                </div>
                <div className="grid grid-cols-2 lg:grid-cols-4 gap-2 sm:gap-3">
                    <StatCard
                        bg="bg-amber-50 dark:bg-amber-900/20"
                        border="hover:border-amber-300 dark:hover:border-amber-600"
                        labelColor="text-amber-600 dark:text-amber-500"
                        valueColor="text-amber-800 dark:text-amber-400"
                        label="Apps throttled"
                        count={stats.throttledApps}
                        pct={`/ ${pct(stats.throttledApps)}%`}
                        onClick={onFilterThrottled}
                        muted
                    />
                    <StatCard
                        bg="bg-red-50 dark:bg-red-900/20"
                        border="hover:border-red-300 dark:hover:border-red-600"
                        labelColor="text-red-600 dark:text-red-500"
                        valueColor="text-red-800 dark:text-red-400"
                        label="Critical"
                        count={stats.criticalThrottling}
                        pct={`/ ${pct(stats.criticalThrottling)}%`}
                        onClick={onFilterCriticalThrottling}
                        muted
                    />
                    <StatCard
                        bg="bg-gray-50 dark:bg-gray-700/30"
                        border=""
                        labelColor="text-gray-500 dark:text-gray-400"
                        valueColor="text-gray-700 dark:text-gray-300"
                        label="429 errors"
                        count={stats.total429.toLocaleString()}
                        pct=""
                        muted
                    />
                    <StatCard
                        bg="bg-gray-50 dark:bg-gray-700/30"
                        border=""
                        labelColor="text-gray-500 dark:text-gray-400"
                        valueColor="text-gray-700 dark:text-gray-300"
                        label="Avg rate"
                        count={`${stats.avgThrottleRate}%`}
                        pct=""
                        muted
                    />
                </div>
                <StackedBar segments={throttlingSegments} total={stats.total} />
            </div>
        </div>
    );
}
