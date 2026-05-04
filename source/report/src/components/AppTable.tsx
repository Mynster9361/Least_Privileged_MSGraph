import React, { useState, useMemo, useRef, useEffect } from 'react';
import {
    useReactTable,
    getCoreRowModel,
    getSortedRowModel,
    getPaginationRowModel,
    ColumnDef,
    flexRender,
    SortingState,
    ColumnVisibilityState,
} from '@tanstack/react-table';
import { AppData, FilterState, Permission } from '../types';
import { calculatePrivilegeMetrics, getAppStatus, toArray, getPermissionName, exportToCSV } from '../utils/helpers';
import {
    SeverityChip,
    SEVERITY_COLORS,
    statusToSeverity,
    privilegeToSeverity,
    throttlingToSeverity,
} from './SeverityChip';

// ---------------------------------------------------------------------------
// Copy-to-clipboard button
// ---------------------------------------------------------------------------
function CopyButton({ text }: { text: string }) {
    const [copied, setCopied] = useState(false);
    return (
        <button
            onClick={(e) => {
                e.stopPropagation();
                navigator.clipboard.writeText(text).then(() => {
                    setCopied(true);
                    setTimeout(() => setCopied(false), 2000);
                });
            }}
            className="ml-1 text-gray-300 hover:text-gray-600 dark:hover:text-gray-200 transition-colors"
            title="Copy to clipboard"
        >
            {copied ? (
                <svg className="inline w-3.5 h-3.5 text-green-500" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                </svg>
            ) : (
                <svg className="inline w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                </svg>
            )}
        </button>
    );
}

interface TableRow {
    index: number;
    appName: string;
    appId: string;
    status: string;
    maxPrivilegeLevel: number;
    maxPrivilegeScore: number;
    highAssignments: number;
    activityCount: number;
    throttlingSeverity: number;
    throttlingStatus: string;
    total429: number;
    throttleRate: number;
    excessPerms: (Permission | string)[];
    missingPerms: (Permission | string)[];
    currentPerms: (Permission | string)[];
    optimalPerms: { Permission: string; ActivitiesCovered: number }[];
}

interface Props {
    appData: AppData[];
    filters: FilterState;
    onShowDetails: (index: number) => void;
    onClearFilters: () => void;
}

const statusLabels: Record<string, string> = {
    good: 'Optimal',
    warning: 'Excess',
    missing: 'Under-Privileged',
    misaligned: 'Misaligned',
    danger: 'Unmatched',
};

const recommendedActions: Record<string, string> = {
    good: 'No action needed',
    warning: 'Remove excess permissions',
    missing: 'Add required permissions',
    misaligned: 'Review permission alignment',
    danger: 'Investigate unmatched activities',
};

const privilegeLabels: Record<number, string> = {
    4: 'Critical', 3: 'High', 2: 'Medium', 1: 'Low', 0: 'None',
};

const throttlingSeverityLabel: Record<number, string> = {
    4: 'Critical', 3: 'Warning', 2: 'Low', 1: 'Minimal', 0: 'Normal',
};

// Tag chip style
const tagClass = 'inline-flex items-center px-1.5 py-0.5 text-[10px] font-medium rounded bg-slate-100 dark:bg-slate-800 text-slate-500 dark:text-slate-400 ring-1 ring-inset ring-slate-200 dark:ring-slate-700';

// Row background tinting by severity
function rowBgClass(status: string, i: number): string {
    if (status === 'danger') return 'bg-red-50/60 dark:bg-red-950/15 hover:bg-red-100/70 dark:hover:bg-red-900/25';
    if (status === 'warning') return 'bg-amber-50/50 dark:bg-amber-950/15 hover:bg-amber-100/60 dark:hover:bg-amber-900/20';
    if (status === 'missing') return 'bg-sky-50/50 dark:bg-sky-950/15 hover:bg-sky-100/60 dark:hover:bg-sky-900/20';
    if (status === 'misaligned') return 'bg-orange-50/40 dark:bg-orange-950/10 hover:bg-orange-100/50 dark:hover:bg-orange-900/15';
    return i % 2 === 0
        ? 'bg-white dark:bg-slate-900 hover:bg-slate-50 dark:hover:bg-slate-800'
        : 'bg-slate-50/50 dark:bg-slate-800/40 hover:bg-slate-100/60 dark:hover:bg-slate-700/50';
}

function permListPreview(perms: (Permission | string)[], colorClass: string, countClass?: string) {
    const cn = countClass ?? '';
    if (!perms.length)
        return <span className={`font-semibold ${cn}`}>0</span>;
    const names = perms.map(getPermissionName);
    const preview = names.slice(0, 2);
    const remaining = names.length - 2;
    return (
        <div>
            <span className={`font-semibold ${cn}`}>{perms.length}</span>
            <div className={`text-xs mt-1 text-right ${colorClass}`}>
                {preview.map((n) => (
                    <div key={n} className="truncate text-right" title={n}>
                        {n}
                    </div>
                ))}
                {remaining > 0 && (
                    <div className="cursor-help text-right" title={names.slice(2).join('\n')}>
                        +{remaining} more...
                    </div>
                )}
            </div>
        </div>
    );
}

export function AppTable({ appData, filters, onShowDetails, onClearFilters }: Props) {
    const [sorting, setSorting] = useState<SortingState>([
        { id: 'maxPrivilegeLevel', desc: true },
        { id: 'throttlingSeverity', desc: true },
    ]);
    const [pageSize, setPageSize] = useState(25);
    const [pageIndex, setPageIndex] = useState(0);
    const [columnVisibility, setColumnVisibility] = useState<ColumnVisibilityState>({
        missingPerms: false,
        currentPerms: false,
        optimalPerms: false,
    });
    const [showColMenu, setShowColMenu] = useState(false);
    const colMenuRef = useRef<HTMLDivElement>(null);

    // Close column menu on outside click
    useEffect(() => {
        function handleClick(e: MouseEvent) {
            if (colMenuRef.current && !colMenuRef.current.contains(e.target as Node)) {
                setShowColMenu(false);
            }
        }
        if (showColMenu) document.addEventListener('mousedown', handleClick);
        return () => document.removeEventListener('mousedown', handleClick);
    }, [showColMenu]);

    const columnFriendlyNames: Record<string, string> = {
        appName: 'App Name',
        status: 'Status',
        maxPrivilegeLevel: 'Max Privilege',
        activityCount: 'Activities',
        throttlingSeverity: 'Throttling',
        excessPerms: 'Excess Perms',
        missingPerms: 'Missing Perms',
        currentPerms: 'Current Perms',
        optimalPerms: 'Optimal Perms',
    };

    const rows = useMemo<TableRow[]>(() => {
        return appData.map((app, index) => {
            const metrics = calculatePrivilegeMetrics(app);
            const status = getAppStatus(app);
            const ts = app.ThrottlingStats;
            return {
                index,
                appName: app.PrincipalName ?? 'N/A',
                appId: app.PrincipalId ?? 'N/A',
                status,
                maxPrivilegeLevel: metrics.maxLevel,
                maxPrivilegeScore: metrics.score,
                highAssignments: metrics.highAssignments,
                activityCount: toArray(app.Activity).length,
                throttlingSeverity: ts?.ThrottlingSeverity ?? 0,
                throttlingStatus: ts?.ThrottlingStatus ?? 'Normal',
                total429: ts?.Total429Errors ?? 0,
                throttleRate: ts?.ThrottleRate ?? 0,
                excessPerms: toArray(app.ExcessPermissions),
                missingPerms: toArray(app.RequiredPermissions),
                currentPerms: toArray(app.CurrentPermissions),
                optimalPerms: toArray(app.OptimalPermissions),
            };
        });
    }, [appData]);

    const filteredRows = useMemo(() => {
        return rows.filter((row) => {
            // Status filter
            if (filters.status && row.status !== filters.status) return false;

            // Activity filter
            if (filters.activity === 'yes' && row.activityCount === 0) return false;
            if (filters.activity === 'no' && row.activityCount > 0) return false;

            // Throttling filter
            if (filters.throttling) {
                if (filters.throttling === 'throttled' && row.throttlingSeverity === 0) return false;
                else if (filters.throttling !== 'throttled' && row.throttlingSeverity !== Number(filters.throttling)) return false;
            }

            // Privilege filter
            if (filters.privilege) {
                if (filters.privilege === '4' && row.maxPrivilegeLevel !== 4) return false;
                else if (filters.privilege === '3plus' && row.maxPrivilegeLevel < 3) return false;
                else if (filters.privilege === '2plus' && row.maxPrivilegeLevel < 2) return false;
                else if (filters.privilege === '1' && row.maxPrivilegeLevel !== 1) return false;
                else if (filters.privilege === '0' && row.maxPrivilegeLevel !== 0) return false;
            }

            // Search filter
            if (filters.search) {
                const q = filters.search.toLowerCase();
                const app = appData[row.index];
                if (row.appName.toLowerCase().includes(q)) return true;
                if (row.appId.toLowerCase().includes(q)) return true;
                if (row.currentPerms.some((p) => getPermissionName(p).toLowerCase().includes(q))) return true;
                if (row.optimalPerms.some((p) => p.Permission.toLowerCase().includes(q))) return true;
                if (row.excessPerms.some((p) => getPermissionName(p).toLowerCase().includes(q))) return true;
                if (row.missingPerms.some((p) => getPermissionName(p).toLowerCase().includes(q))) return true;
                if (row.throttlingStatus.toLowerCase().includes(q)) return true;
                if (toArray(app.Activity).some((a) => (a.Uri ?? '').toLowerCase().includes(q) || (a.Method ?? '').toLowerCase().includes(q))) return true;
                if (toArray(app.UnmatchedActivities).some((a) => ((a.Path ?? a.Uri) ?? '').toLowerCase().includes(q))) return true;
                return false;
            }

            return true;
        });
    }, [rows, filters, appData]);

    const columns = useMemo<ColumnDef<TableRow>[]>(() => [
        {
            id: 'appName',
            accessorKey: 'appName',
            header: 'Application Name',
            cell: ({ row }) => {
                const app = appData[row.original.index];
                const hasUnmatched = app && toArray(app.UnmatchedActivities).length > 0;
                const status = row.original.status;
                const severityColor = SEVERITY_COLORS[statusToSeverity(status)];

                // Tag chips
                const appRoles = toArray(app?.AppRoles);
                const hasApp = appRoles.some((r) => r.PermissionType === 'Application');
                const hasDelegated = appRoles.some((r) => r.PermissionType === 'Delegated');
                const noActivity = row.original.activityCount === 0;

                return (
                    <div className="flex items-start gap-2">
                        {/* Severity dot */}
                        <span
                            className="mt-1.5 w-2 h-2 rounded-full flex-shrink-0"
                            style={{ backgroundColor: severityColor }}
                            title={`Status: ${statusLabels[status] ?? status}`}
                        />
                        <div className="min-w-0">
                            <div className="flex items-center gap-1 font-medium text-slate-900 dark:text-slate-100">
                                <span>{row.original.appName}</span>
                                {hasUnmatched && (
                                    <svg className="w-3.5 h-3.5 text-red-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" />
                                    </svg>
                                )}
                            </div>
                            <div className="text-xs text-slate-500 dark:text-slate-400 flex items-center">
                                <span className="font-mono truncate max-w-[140px]" title={row.original.appId}>
                                    {row.original.appId}
                                </span>
                                <CopyButton text={row.original.appId} />
                            </div>
                            {(hasApp || hasDelegated || noActivity) && (
                                <div className="flex flex-wrap gap-1 mt-1">
                                    {hasApp && <span className={tagClass}>App</span>}
                                    {hasDelegated && <span className={tagClass}>Delegated</span>}
                                    {noActivity && <span className={tagClass}>No activity</span>}
                                </div>
                            )}
                        </div>
                    </div>
                );
            },
        },
        {
            id: 'status',
            accessorKey: 'status',
            header: 'Status',
            cell: ({ getValue }) => {
                const val = getValue<string>();
                return (
                    <div>
                        <SeverityChip severity={statusToSeverity(val)} label={statusLabels[val] ?? val} />
                        <div className="text-xs text-slate-400 dark:text-slate-500 mt-1 leading-tight">
                            {recommendedActions[val]}
                        </div>
                    </div>
                );
            },
        },
        {
            id: 'maxPrivilegeLevel',
            accessorKey: 'maxPrivilegeLevel',
            header: 'Max Privilege',
            sortingFn: (a, b) => {
                const aVal = a.original.maxPrivilegeLevel * 1000 + a.original.maxPrivilegeScore;
                const bVal = b.original.maxPrivilegeLevel * 1000 + b.original.maxPrivilegeScore;
                return aVal - bVal;
            },
            cell: ({ row }) => {
                const level = row.original.maxPrivilegeLevel;
                const tooltip = `Score: ${row.original.maxPrivilegeScore} | High-risk perms: ${row.original.highAssignments}`;
                return (
                    <div title={tooltip}>
                        <SeverityChip severity={privilegeToSeverity(level)} label={privilegeLabels[level] ?? 'None'} />
                    </div>
                );
            },
        },
        {
            id: 'activityCount',
            accessorKey: 'activityCount',
            header: 'Activities',
            cell: ({ getValue }) => {
                const count = getValue<number>();
                return (
                    <div>
                        <span className="font-semibold text-slate-800 dark:text-slate-200">{count}</span>
                        {count > 0 ? (
                            <span className="text-xs text-slate-500 dark:text-slate-400"><br />endpoints</span>
                        ) : (
                            <span className="text-xs text-slate-400 dark:text-slate-500"><br />No activity</span>
                        )}
                    </div>
                );
            },
        },
        {
            id: 'throttlingSeverity',
            accessorKey: 'throttlingSeverity',
            header: 'Throttling',
            cell: ({ row }) => {
                const sev = row.original.throttlingSeverity;
                if (!row.original.total429 && sev === 0)
                    return <span className="text-xs text-slate-400 dark:text-slate-500">—</span>;
                const label = throttlingSeverityLabel[sev] ?? 'Normal';
                return (
                    <div>
                        <SeverityChip severity={throttlingToSeverity(sev)} label={label} />
                        {row.original.total429 > 0 && (
                            <div className="text-xs text-slate-500 dark:text-slate-400 mt-1">
                                {row.original.total429.toLocaleString()} errors ({row.original.throttleRate}%)
                            </div>
                        )}
                    </div>
                );
            },
        },
        {
            id: 'excessPerms',
            accessorKey: 'excessPerms',
            header: 'Excess Permissions',
            sortingFn: (a, b) => a.original.excessPerms.length - b.original.excessPerms.length,
            cell: ({ row }) => permListPreview(row.original.excessPerms, 'text-red-500 dark:text-red-400', row.original.excessPerms.length > 0 ? 'text-red-600 dark:text-red-400' : 'text-green-600 dark:text-green-400'),
        },
        {
            id: 'missingPerms',
            accessorKey: 'missingPerms',
            header: 'Missing Permissions',
            sortingFn: (a, b) => a.original.missingPerms.length - b.original.missingPerms.length,
            cell: ({ row }) => permListPreview(row.original.missingPerms, 'text-yellow-600 dark:text-yellow-400', row.original.missingPerms.length > 0 ? 'text-yellow-600 dark:text-yellow-400' : 'text-green-600 dark:text-green-400'),
        },
        {
            id: 'currentPerms',
            accessorKey: 'currentPerms',
            header: 'Current Permissions',
            sortingFn: (a, b) => a.original.currentPerms.length - b.original.currentPerms.length,
            cell: ({ row }) => permListPreview(row.original.currentPerms, 'text-gray-500 dark:text-gray-400'),
        },
        {
            id: 'optimalPerms',
            accessorKey: 'optimalPerms',
            header: 'Optimal Permissions',
            sortingFn: (a, b) => a.original.optimalPerms.length - b.original.optimalPerms.length,
            cell: ({ row }) => permListPreview(row.original.optimalPerms, 'text-green-600 dark:text-green-400', 'text-green-600 dark:text-green-400'),
        },
    ], [onShowDetails]);

    const table = useReactTable({
        data: filteredRows,
        columns,
        state: { sorting, pagination: { pageIndex, pageSize }, columnVisibility },
        onSortingChange: setSorting,
        onColumnVisibilityChange: setColumnVisibility,
        onPaginationChange: (updater) => {
            if (typeof updater === 'function') {
                const next = updater({ pageIndex, pageSize });
                setPageIndex(next.pageIndex);
                setPageSize(next.pageSize);
            }
        },
        getCoreRowModel: getCoreRowModel(),
        getSortedRowModel: getSortedRowModel(),
        getPaginationRowModel: getPaginationRowModel(),
        manualPagination: false,
    });

    const thClass = 'px-4 py-3 text-left text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider cursor-pointer select-none hover:bg-slate-100 dark:hover:bg-slate-700/50 bg-slate-50 dark:bg-slate-800/60 transition-colors';

    return (
        <div className="bg-white dark:bg-slate-900 rounded-lg border border-slate-200 dark:border-slate-800 p-3 sm:p-5 transition-colors duration-200">
            <div className="flex flex-wrap justify-between items-center mb-4 gap-2">
                <h2 className="text-lg sm:text-xl font-bold text-gray-800 dark:text-gray-100">Application Permission Analysis</h2>
                <div className="flex flex-wrap items-center gap-2 ml-auto">
                    <div className="flex items-center gap-1">
                        <select
                            value={pageSize}
                            onChange={(e) => { setPageSize(Number(e.target.value)); setPageIndex(0); }}
                            className="cursor-pointer border border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-200 rounded p-1 text-sm"
                        >
                            {[10, 25, 50, 100].map((n) => <option key={n} value={n}>{n}</option>)}
                        </select>
                        <label className="text-sm text-gray-700 dark:text-gray-300">/ page</label>
                    </div>
                    {/* Columns toggle */}
                    <div className="relative" ref={colMenuRef}>
                        <button
                            onClick={() => setShowColMenu((v) => !v)}
                            className="flex items-center gap-1.5 border border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-200 text-gray-700 rounded px-2.5 py-1 text-sm hover:bg-gray-50 dark:hover:bg-gray-600 transition-colors"
                        >
                            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 10h18M3 14h18M10 6h4M10 18h4" />
                            </svg>
                            Columns
                        </button>
                        {showColMenu && (
                            <div className="absolute right-0 top-full mt-1 z-30 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-600 rounded-lg shadow-xl p-3 min-w-[170px]">
                                {table.getAllLeafColumns().map((col) => (
                                    <label key={col.id} className="flex items-center gap-2 py-1 text-sm cursor-pointer hover:text-blue-600 dark:hover:text-blue-400">
                                        <input
                                            type="checkbox"
                                            checked={col.getIsVisible()}
                                            onChange={col.getToggleVisibilityHandler()}
                                            className="rounded"
                                        />
                                        {columnFriendlyNames[col.id] ?? col.id}
                                    </label>
                                ))}
                            </div>
                        )}
                    </div>
                    <button
                        onClick={() => exportToCSV(appData)}
                        className="bg-blue-500 hover:bg-blue-600 dark:bg-blue-600 dark:hover:bg-blue-700 text-white font-semibold py-1.5 px-3 rounded-lg transition-colors duration-200 text-sm"
                    >
                        Export CSV
                    </button>
                </div>
            </div>

            <div className="overflow-x-auto">
                <table className="min-w-full">
                    <thead className="bg-gray-50 dark:bg-gray-700 sticky top-0 z-10">
                        {table.getHeaderGroups().map((hg) => (
                            <tr key={hg.id}>
                                {hg.headers.map((header) => (
                                    <th
                                        key={header.id}
                                        className={thClass}
                                        onClick={header.column.getToggleSortingHandler()}
                                    >
                                        {flexRender(header.column.columnDef.header, header.getContext())}
                                        {header.column.getIsSorted() === 'asc' ? ' ↑' : header.column.getIsSorted() === 'desc' ? ' ↓' : ''}
                                    </th>
                                ))}
                            </tr>
                        ))}
                    </thead>
                    <tbody>
                        {table.getRowModel().rows.map((row, i) => (
                            <tr
                                key={row.id}
                                onClick={() => onShowDetails(row.original.index)}
                                className={`border-b dark:border-gray-600 cursor-pointer transition-colors duration-100 ${rowBgClass(row.original.status, i)}`}
                            >
                                {row.getVisibleCells().map((cell) => (
                                    <td
                                        key={cell.id}
                                        className="px-4 py-3 text-sm text-gray-700 dark:text-gray-300"
                                    >
                                        {flexRender(cell.column.columnDef.cell, cell.getContext())}
                                    </td>
                                ))}
                            </tr>
                        ))}
                        {filteredRows.length === 0 && (
                            <tr>
                                <td colSpan={columns.length} className="px-4 py-12 text-center">
                                    <div className="flex flex-col items-center gap-3">
                                        <svg className="w-10 h-10 text-gray-300 dark:text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                                        </svg>
                                        <p className="text-gray-500 dark:text-gray-400 font-medium">No applications match the current filters.</p>
                                        <button
                                            onClick={onClearFilters}
                                            className="text-sm text-blue-500 hover:text-blue-700 dark:text-blue-400 dark:hover:text-blue-300 underline"
                                        >
                                            Clear all filters
                                        </button>
                                    </div>
                                </td>
                            </tr>
                        )}
                    </tbody>
                </table>
            </div>

            {/* Pagination */}
            <div className="flex items-center justify-between mt-4 text-sm text-gray-700 dark:text-gray-300">
                <span>
                    Showing {filteredRows.length === 0 ? 0 : pageIndex * pageSize + 1}–{Math.min((pageIndex + 1) * pageSize, filteredRows.length)} of {filteredRows.length} entries
                    {table.getPageCount() > 1 && (
                        <span className="ml-2 text-gray-400 dark:text-gray-500">
                            (Page {pageIndex + 1} of {table.getPageCount()})
                        </span>
                    )}
                </span>
                <div className="flex gap-1">
                    <button
                        onClick={() => setPageIndex(0)}
                        disabled={!table.getCanPreviousPage()}
                        className="px-2 py-1 rounded border dark:border-gray-600 disabled:opacity-40"
                    >
                        «
                    </button>
                    <button
                        onClick={() => setPageIndex((i) => i - 1)}
                        disabled={!table.getCanPreviousPage()}
                        className="px-2 py-1 rounded border dark:border-gray-600 disabled:opacity-40"
                    >
                        ‹
                    </button>
                    {Array.from({ length: Math.min(5, table.getPageCount()) }, (_, i) => {
                        const start = Math.max(0, Math.min(pageIndex - 2, table.getPageCount() - 5));
                        const page = start + i;
                        return (
                            <button
                                key={page}
                                onClick={() => setPageIndex(page)}
                                className={`px-2 py-1 rounded border dark:border-gray-600 ${page === pageIndex ? 'bg-blue-500 text-white border-blue-500' : ''}`}
                            >
                                {page + 1}
                            </button>
                        );
                    })}
                    <button
                        onClick={() => setPageIndex((i) => i + 1)}
                        disabled={!table.getCanNextPage()}
                        className="px-2 py-1 rounded border dark:border-gray-600 disabled:opacity-40"
                    >
                        ›
                    </button>
                    <button
                        onClick={() => setPageIndex(table.getPageCount() - 1)}
                        disabled={!table.getCanNextPage()}
                        className="px-2 py-1 rounded border dark:border-gray-600 disabled:opacity-40"
                    >
                        »
                    </button>
                </div>
            </div>
        </div>
    );
}
