import React from 'react';
import { FilterState } from '../types';

interface Props {
    filters: FilterState;
    onChange: (filters: FilterState) => void;
}

export function FiltersPanel({ filters, onChange }: Props) {
    function set(key: keyof FilterState) {
        return (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
            onChange({ ...filters, [key]: e.target.value });
        };
    }

    const selectClass =
        'w-full border border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-200 rounded-lg p-2';

    return (
        <div className="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-3 sm:p-6 mb-4 sm:mb-6 transition-colors duration-200">
            <h2 className="text-lg sm:text-xl font-bold text-gray-800 dark:text-gray-100 mb-4">Filters</h2>
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-2 sm:gap-4">
                <div>
                    <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Permission Status</label>
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
                    <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Activity Status</label>
                    <select value={filters.activity} onChange={set('activity')} className={selectClass}>
                        <option value="">All</option>
                        <option value="yes">Has Activity</option>
                        <option value="no">No Activity</option>
                    </select>
                </div>
                <div>
                    <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Throttling Severity</label>
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
                    <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Max Privilege Level</label>
                    <select value={filters.privilege} onChange={set('privilege')} className={selectClass}>
                        <option value="">All</option>
                        <option value="4">Level 4 (Critical)</option>
                        <option value="3plus">Level 3+ (High/Critical)</option>
                        <option value="2plus">Level 2+ (Medium+)</option>
                        <option value="1">Level 1 (Low only)</option>
                        <option value="0">No Permissions</option>
                    </select>
                </div>
                <div>
                    <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Search All Data</label>
                    <input
                        type="text"
                        value={filters.search}
                        onChange={set('search')}
                        className={selectClass}
                        placeholder="Search apps, permissions, endpoints..."
                    />
                </div>
            </div>
        </div>
    );
}
