import React, { useState, useMemo } from 'react';
import {
    useReactTable,
    getCoreRowModel,
    getSortedRowModel,
    getPaginationRowModel,
    ColumnDef,
    flexRender,
    SortingState,
} from '@tanstack/react-table';
import { AppData, FilterState, Permission } from '../types';
import { calculatePrivilegeMetrics, getAppStatus, toArray, getPermissionName, exportToCSV } from '../utils/helpers';

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
}

const statusBadges: Record<string, string> = {
    good: 'text-green-600 dark:text-green-400',
    warning: 'text-orange-600 dark:text-orange-400',
    missing: 'text-cyan-600 dark:text-cyan-400',
    misaligned: 'text-amber-600 dark:text-amber-400',
    danger: 'text-red-600 dark:text-red-400',
};

const statusLabels: Record<string, string> = {
    good: 'Optimal',
    warning: 'Excess',
    missing: 'Under-Privileged',
    misaligned: 'Misaligned',
    danger: 'Unmatched',
};

const levelStyles: Record<number, string> = {
    4: 'text-red-600 dark:text-red-400',
    3: 'text-orange-600 dark:text-orange-400',
    2: 'text-yellow-600 dark:text-yellow-400',
    1: 'text-green-600 dark:text-green-400',
    0: 'text-gray-500 dark:text-gray-400',
};

const levelLabels: Record<number, string> = {
    4: 'L4 - Critical',
    3: 'L3 - High',
    2: 'L2 - Medium',
    1: 'L1 - Low',
    0: 'None',
};

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

export function AppTable({ appData, filters, onShowDetails }: Props) {
    const [sorting, setSorting] = useState<SortingState>([
        { id: 'maxPrivilegeLevel', desc: true },
        { id: 'throttlingSeverity', desc: true },
    ]);
    const [pageSize, setPageSize] = useState(25);
    const [pageIndex, setPageIndex] = useState(0);

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
            id: 'details',
            header: 'Details',
            cell: ({ row }) => (
                <button
                    onClick={() => onShowDetails(row.original.index)}
                    className="bg-blue-500 hover:bg-blue-600 dark:bg-blue-600 dark:hover:bg-blue-700 text-white font-semibold py-1 px-3 rounded text-xs transition-colors duration-200"
                >
                    View Details
                </button>
            ),
            enableSorting: false,
        },
        {
            id: 'appName',
            accessorKey: 'appName',
            header: 'Application Name',
            cell: ({ row }) => (
                <div>
                    <div className="font-medium text-gray-900 dark:text-gray-100">{row.original.appName}</div>
                    <div className="text-xs text-gray-500 dark:text-gray-400">{row.original.appId}</div>
                </div>
            ),
        },
        {
            id: 'status',
            accessorKey: 'status',
            header: 'Status',
            cell: ({ getValue }) => {
                const val = getValue<string>();
                return (
                    <div className={`font-semibold text-xs ${statusBadges[val] ?? ''}`}>{statusLabels[val] ?? val}</div>
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
                return (
                    <div>
                        <div className={`font-semibold ${levelStyles[level] ?? levelStyles[0]}`}>
                            {levelLabels[level] ?? 'None'}
                        </div>
                        <div className="text-xs text-gray-600 dark:text-gray-400">Score: {row.original.maxPrivilegeScore}</div>
                        <div className="text-xs text-gray-500">High perms: {row.original.highAssignments}</div>
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
                        <span className="font-semibold">{count}</span>
                        {count > 0 ? (
                            <span className="text-xs text-gray-500 dark:text-gray-400"><br />endpoints</span>
                        ) : (
                            <span className="text-xs text-gray-400 dark:text-gray-500"><br />No activity</span>
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
                    return <span className="text-xs text-gray-400 dark:text-gray-500">No data</span>;
                const statusColors: Record<number, string> = {
                    4: 'text-red-600 dark:text-red-400 font-bold',
                    3: 'text-orange-600 dark:text-orange-400 font-semibold',
                    2: 'text-yellow-600 dark:text-yellow-400',
                    1: 'text-blue-500 dark:text-blue-400',
                    0: 'text-green-600 dark:text-green-400',
                };
                return (
                    <div>
                        <div className={`font-semibold text-xs ${statusColors[sev] ?? statusColors[0]}`}>
                            {row.original.throttlingStatus}
                        </div>
                        {row.original.total429 > 0 && (
                            <div className="text-xs text-gray-600 dark:text-gray-400">
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
        state: { sorting, pagination: { pageIndex, pageSize } },
        onSortingChange: setSorting,
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

    const thClass = 'px-4 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider cursor-pointer select-none hover:bg-gray-100 dark:hover:bg-gray-600';

    return (
        <div className="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-3 sm:p-6 transition-colors duration-200">
            <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center mb-4 gap-2 sm:gap-0">
                <h2 className="text-lg sm:text-xl font-bold text-gray-800 dark:text-gray-100">Application Permission Analysis</h2>
                <div className="flex items-center gap-2">
                    <select
                        value={pageSize}
                        onChange={(e) => { setPageSize(Number(e.target.value)); setPageIndex(0); }}
                        className="cursor-pointer border border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-200 rounded p-1 text-sm"
                    >
                        {[10, 25, 50, 100].map((n) => <option key={n} value={n}>{n}</option>)}
                    </select>
                    <label className="text-sm text-gray-700 dark:text-gray-300">entries per page</label>
                </div>
                <button
                    onClick={() => exportToCSV(appData)}
                    className="bg-blue-500 hover:bg-blue-600 dark:bg-blue-600 dark:hover:bg-blue-700 text-white font-semibold py-2 px-4 rounded-lg transition-colors duration-200"
                >
                    Export to CSV
                </button>
            </div>

            <div className="overflow-x-auto">
                <table className="min-w-full">
                    <thead className="bg-gray-50 dark:bg-gray-700">
                        {table.getHeaderGroups().map((hg) => (
                            <tr key={hg.id}>
                                {hg.headers.map((header) => (
                                    <th
                                        key={header.id}
                                        className={`${thClass} ${header.column.id === 'status' ? 'hidden sm:table-cell' : ''} ${header.column.id === 'maxPrivilegeLevel' ? 'hidden md:table-cell' : ''} ${header.column.id === 'activityCount' ? 'hidden lg:table-cell' : ''} ${header.column.id === 'throttlingSeverity' ? 'hidden xl:table-cell' : ''} ${header.column.id === 'excessPerms' ? 'hidden 2xl:table-cell' : ''} ${header.column.id === 'missingPerms' ? 'hidden 3xl:table-cell' : ''} ${header.column.id === 'currentPerms' ? 'hidden 4xl:table-cell' : ''} ${header.column.id === 'optimalPerms' ? 'hidden 5xl:table-cell' : ''}`}
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
                                className={`border-b dark:border-gray-600 ${i % 2 === 0 ? 'bg-white dark:bg-gray-800' : 'bg-gray-50 dark:bg-gray-700'} hover:bg-gray-100 dark:hover:bg-gray-600`}
                            >
                                {row.getVisibleCells().map((cell) => (
                                    <td
                                        key={cell.id}
                                        className={`px-4 py-3 text-sm text-gray-700 dark:text-gray-300 ${cell.column.id === 'status' ? 'hidden sm:table-cell' : ''} ${cell.column.id === 'maxPrivilegeLevel' ? 'hidden md:table-cell' : ''} ${cell.column.id === 'activityCount' ? 'hidden lg:table-cell' : ''} ${cell.column.id === 'throttlingSeverity' ? 'hidden xl:table-cell' : ''} ${cell.column.id === 'excessPerms' ? 'hidden 2xl:table-cell' : ''} ${cell.column.id === 'missingPerms' ? 'hidden 3xl:table-cell' : ''} ${cell.column.id === 'currentPerms' ? 'hidden 4xl:table-cell' : ''} ${cell.column.id === 'optimalPerms' ? 'hidden 5xl:table-cell' : ''}`}
                                    >
                                        {flexRender(cell.column.columnDef.cell, cell.getContext())}
                                    </td>
                                ))}
                            </tr>
                        ))}
                        {filteredRows.length === 0 && (
                            <tr>
                                <td colSpan={columns.length} className="px-4 py-8 text-center text-gray-500 dark:text-gray-400">
                                    No applications match the current filters.
                                </td>
                            </tr>
                        )}
                    </tbody>
                </table>
            </div>

            {/* Pagination */}
            <div className="flex items-center justify-between mt-4 text-sm text-gray-700 dark:text-gray-300">
                <span>
                    Showing {pageIndex * pageSize + 1}–{Math.min((pageIndex + 1) * pageSize, filteredRows.length)} of {filteredRows.length} entries
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
