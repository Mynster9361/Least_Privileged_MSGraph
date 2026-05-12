import React, { useState } from 'react';
import { FilterState } from '../types';

interface Props {
    filters: FilterState;
    onChange: (filters: FilterState) => void;
    searchRef?: React.RefObject<HTMLInputElement>;
}

const EMPTY_FILTERS: FilterState = { status: '', activity: '', throttling: '', privilege: '', search: '' };

// Human-readable labels for active chips
const filterLabels: Partial<Record<keyof FilterState, Record<string, string>>> = {
    status: { good: 'Status: Optimal', warning: 'Status: Excess', missing: 'Status: Under-Privileged', misaligned: 'Status: Misaligned', danger: 'Status: Unmatched' },
    activity: { yes: 'Activity: Has Activity', no: 'Activity: No Activity' },
    throttling: { throttled: 'Throttling: All Throttled', '4': 'Throttling: Critical', '3': 'Throttling: Warning', '2': 'Throttling: Low', '1': 'Throttling: Minimal', '0': 'Throttling: Normal' },
    privilege: { '5': 'Privilege: L5 Maximum', '4': 'Privilege: L4 Critical', '3': 'Privilege: L3 High', '2': 'Privilege: L2 Medium', '1': 'Privilege: L1 Low' },
};

export function FiltersPanel({ filters, onChange, searchRef }: Props) {
    const [open, setOpen] = useState(true);

    function set(key: keyof FilterState) {
        return (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
            onChange({ ...filters, [key]: e.target.value });
        };
    }

    function clearOne(key: keyof FilterState) {
        onChange({ ...filters, [key]: '' });
    }

    const activeCount = Object.values(filters).filter(Boolean).length;
    const hasFilters = activeCount > 0;

    const selectClass =
        'w-full border border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-200 rounded-lg p-2 focus:ring-2 focus:ring-blue-400 focus:outline-none text-sm';

    // Collect active chip entries
    const chips: { key: keyof FilterState; label: string }[] = [];
    (Object.entries(filters) as [keyof FilterState, string][]).forEach(([key, value]) => {
        if (!value) return;
        if (key === 'search') {
            chips.push({ key, label: `Search: "${value}"` });
        } else {
            const label = filterLabels[key]?.[value] ?? `${key}: ${value}`;
            chips.push({ key, label });
        }
    });

    return (
        <div className="mb-4">
            {/* ── Header row ── */}
            <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                    <button
                        onClick={() => setOpen((o) => !o)}
                        className="flex items-center gap-1.5 font-semibold text-slate-600 dark:text-slate-300 text-sm hover:text-blue-600 dark:hover:text-blue-400 transition-colors"
                        aria-expanded={open}
                    >
                        <svg
                            className={`w-4 h-4 transition-transform duration-200 ${open ? 'rotate-90' : ''}`}
                            fill="none"
                            stroke="currentColor"
                            viewBox="0 0 24 24"
                        >
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                        </svg>
                        Filters
                    </button>
                    {activeCount > 0 && (
                        <span className="inline-flex items-center justify-center px-2 py-0.5 text-xs font-bold rounded-full bg-blue-500 text-white">
                            {activeCount}
                        </span>
                    )}
                </div>
                {hasFilters && (
                    <button
                        onClick={() => onChange(EMPTY_FILTERS)}
                        className="text-xs text-red-500 hover:text-red-700 dark:text-red-400 dark:hover:text-red-300 font-semibold px-2 py-1 rounded hover:bg-red-50 dark:hover:bg-red-900/30 transition-colors"
                    >
                        ✕ Clear all
                    </button>
                )}
            </div>

            {/* ── Active filter chips (always visible) ── */}
            {chips.length > 0 && (
                <div className="flex flex-wrap gap-1.5 mt-2">
                    {chips.map(({ key, label }) => (
                        <span
                            key={key}
                            className="inline-flex items-center gap-1 pl-2.5 pr-1.5 py-0.5 text-xs rounded-full bg-blue-100 dark:bg-blue-900/40 text-blue-700 dark:text-blue-300 border border-blue-300 dark:border-blue-700"
                        >
                            {label}
                            <button
                                onClick={() => clearOne(key)}
                                className="hover:text-blue-900 dark:hover:text-blue-100 ml-0.5 font-bold leading-none"
                                title={`Remove filter`}
                            >
                                ✕
                            </button>
                        </span>
                    ))}
                </div>
            )}

            {/* ── Collapsible filter inputs ── */}
            {open && (
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-2 sm:gap-3 mt-3 pt-3 border-t dark:border-gray-700">
                    <div>
                        <label className="block text-xs font-medium text-gray-500 dark:text-gray-400 mb-1">Status</label>
                        <select value={filters.status} onChange={set('status')} className={selectClass}>
                            <option value="">All</option>
                            <option value="good">Optimal</option>
                            <option value="warning">Has Excess</option>
                            <option value="missing">Under-Privileged</option>
                            <option value="misaligned">Misaligned</option>
                            <option value="danger">Unmatched</option>
                        </select>
                    </div>
                    <div>
                        <label className="block text-xs font-medium text-gray-500 dark:text-gray-400 mb-1">Activity</label>
                        <select value={filters.activity} onChange={set('activity')} className={selectClass}>
                            <option value="">All</option>
                            <option value="yes">Has Activity</option>
                            <option value="no">No Activity</option>
                        </select>
                    </div>
                    <div>
                        <label className="block text-xs font-medium text-gray-500 dark:text-gray-400 mb-1">Throttling</label>
                        <select value={filters.throttling} onChange={set('throttling')} className={selectClass}>
                            <option value="">All</option>
                            <option value="throttled">All Throttled</option>
                            <option value="4">Critical</option>
                            <option value="3">Warning</option>
                            <option value="2">Low</option>
                            <option value="1">Minimal</option>
                            <option value="0">Normal</option>
                        </select>
                    </div>
                    <div>
                        <label className="block text-xs font-medium text-gray-500 dark:text-gray-400 mb-1">Privilege</label>
                        <select value={filters.privilege} onChange={set('privilege')} className={selectClass}>
                            <option value="">All</option>
                            <option value="5">L5 – Maximum</option>
                            <option value="4">L4 – Critical</option>
                            <option value="3">L3 – High</option>
                            <option value="2">L2 – Medium</option>
                            <option value="1">L1 – Low</option>
                        </select>
                    </div>
                    <div>
                        <label className="block text-xs font-medium text-gray-500 dark:text-gray-400 mb-1">Search</label>
                        <input
                            ref={searchRef}
                            type="text"
                            value={filters.search}
                            onChange={set('search')}
                            className={selectClass}
                            placeholder="Apps, permissions, endpoints..."
                        />
                    </div>
                </div>
            )}
        </div>
    );
}
