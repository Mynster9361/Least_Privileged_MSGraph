import React from 'react';

// ---------------------------------------------------------------------------
// Unified severity chip — single visual language across all severity scales
// ---------------------------------------------------------------------------

export type SeverityLevel = 'critical' | 'high' | 'medium' | 'low' | 'none' | 'info';

const CONFIG: Record<SeverityLevel, { dot: string; text: string; ring: string }> = {
    critical: {
        dot: 'bg-red-500',
        text: 'text-red-700 dark:text-red-300',
        ring: 'bg-red-50 dark:bg-red-950/50 ring-1 ring-inset ring-red-300 dark:ring-red-800',
    },
    high: {
        dot: 'bg-orange-500',
        text: 'text-orange-700 dark:text-orange-300',
        ring: 'bg-orange-50 dark:bg-orange-950/50 ring-1 ring-inset ring-orange-300 dark:ring-orange-800',
    },
    medium: {
        dot: 'bg-amber-500',
        text: 'text-amber-700 dark:text-amber-300',
        ring: 'bg-amber-50 dark:bg-amber-950/50 ring-1 ring-inset ring-amber-300 dark:ring-amber-800',
    },
    low: {
        dot: 'bg-sky-500',
        text: 'text-sky-700 dark:text-sky-300',
        ring: 'bg-sky-50 dark:bg-sky-950/50 ring-1 ring-inset ring-sky-300 dark:ring-sky-800',
    },
    none: {
        dot: 'bg-emerald-500',
        text: 'text-emerald-700 dark:text-emerald-300',
        ring: 'bg-emerald-50 dark:bg-emerald-950/50 ring-1 ring-inset ring-emerald-300 dark:ring-emerald-800',
    },
    info: {
        dot: 'bg-slate-400',
        text: 'text-slate-600 dark:text-slate-400',
        ring: 'bg-slate-100 dark:bg-slate-800/80 ring-1 ring-inset ring-slate-300 dark:ring-slate-700',
    },
};

export function SeverityChip({
    severity,
    label,
    className = '',
}: {
    severity: SeverityLevel;
    label: string;
    className?: string;
}) {
    const c = CONFIG[severity];
    return (
        <span
            className={`inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-[11px] font-semibold uppercase tracking-wide ${c.ring} ${c.text} ${className}`}
        >
            <span className={`w-1.5 h-1.5 rounded-full flex-shrink-0 ${c.dot}`} />
            {label}
        </span>
    );
}

// ---------------------------------------------------------------------------
// Hex colors for use in inline styles (e.g., SVG dots, stacked bars)
// ---------------------------------------------------------------------------

export const SEVERITY_COLORS: Record<SeverityLevel, string> = {
    critical: '#ef4444',
    high: '#f97316',
    medium: '#f59e0b',
    low: '#0ea5e9',
    none: '#10b981',
    info: '#94a3b8',
};

// ---------------------------------------------------------------------------
// Mapping helpers — convert domain values to SeverityLevel
// ---------------------------------------------------------------------------

export function statusToSeverity(status: string): SeverityLevel {
    const m: Record<string, SeverityLevel> = {
        good: 'none', warning: 'medium', missing: 'low', misaligned: 'high', danger: 'critical',
    };
    return m[status] ?? 'info';
}

export function privilegeToSeverity(level: number): SeverityLevel {
    const m: Record<number, SeverityLevel> = { 4: 'critical', 3: 'high', 2: 'medium', 1: 'low', 0: 'none' };
    return m[level] ?? 'none';
}

export function throttlingToSeverity(sev: number): SeverityLevel {
    const m: Record<number, SeverityLevel> = { 4: 'critical', 3: 'high', 2: 'medium', 1: 'low', 0: 'none' };
    return m[sev] ?? 'none';
}
