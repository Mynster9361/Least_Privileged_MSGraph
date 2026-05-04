import React, { useState, useEffect, useRef } from 'react';
import { AppData, FilterState } from './types';
import sampleData from './sampleData';
import { Header } from './components/Header';
import { FiltersPanel } from './components/FiltersPanel';
import { AppTable } from './components/AppTable';
import { AppDetailModal } from './components/AppDetailModal';
import { calculateStats, exportToCSV } from './utils/helpers';

// ---------------------------------------------------------------------------
// REPORT METADATA
// PowerShell replaces these placeholder strings in the built dist/index.html.
// During development, these fallback values are used.
// ---------------------------------------------------------------------------

// prettier-ignore
const reportTitle = "{% block title %}{% endblock %}";
// prettier-ignore
const tenantId = "{% block tenant_id %}{% endblock %}";
// prettier-ignore
const tenantName = "{% block tenant_name %}{% endblock %}";
// prettier-ignore
const generatedOn = "{% block generated_on %}{% endblock %}";

// ---------------------------------------------------------------------------
// APP DATA
// PowerShell replaces the JSON between the markers below.
// The variable name and surrounding structure must NOT be changed.
// ---------------------------------------------------------------------------

// prettier-ignore
// LPMSG_APPDATA_START
const appDataJson = "{% block app_data %}{% endblock %}";
// LPMSG_APPDATA_END

function parseAppData(): AppData[] {
    try {
        if (appDataJson.startsWith('{%')) return sampleData;
        const parsed = JSON.parse(appDataJson);
        // ConvertTo-Json emits an object (not array) for single-item input;
        // wrap it so the rest of the app can always call .map().
        return Array.isArray(parsed) ? parsed : [parsed];
    } catch {
        return sampleData;
    }
}

const INITIAL_FILTERS: FilterState = {
    status: '', activity: '', throttling: '', privilege: '', search: '',
};

// ---------------------------------------------------------------------------
// Executive summary banner
// ---------------------------------------------------------------------------

function ExecutiveSummary({ appData }: { appData: AppData[] }) {
    const stats = calculateStats(appData);

    const parts: string[] = [];
    if (stats.withUnmatched > 0)
        parts.push(`${stats.withUnmatched} app${stats.withUnmatched !== 1 ? 's' : ''} with unmatched activity`);
    if (stats.withExcess > 0)
        parts.push(`${stats.withExcess} app${stats.withExcess !== 1 ? 's' : ''} with excess permissions`);
    if (stats.criticalThrottling > 0)
        parts.push(`${stats.criticalThrottling} app${stats.criticalThrottling !== 1 ? 's' : ''} with critical throttling`);

    if (parts.length === 0) {
        return (
            <div className="mb-4 flex items-center gap-2 px-4 py-3 bg-emerald-50 dark:bg-emerald-950/30 border border-emerald-200 dark:border-emerald-800 rounded-lg">
                <svg className="w-4 h-4 text-emerald-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z" />
                </svg>
                <p className="text-sm font-medium text-emerald-700 dark:text-emerald-300">
                    All {stats.total} applications are optimally configured.
                </p>
            </div>
        );
    }

    return (
        <div className="mb-4 px-4 py-3 bg-amber-50 dark:bg-amber-950/30 border border-amber-200 dark:border-amber-800 rounded-lg flex items-start gap-2">
            <svg className="w-4 h-4 text-amber-500 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
            </svg>
            <p className="text-sm text-amber-800 dark:text-amber-200">
                <strong>{parts.length} finding type{parts.length !== 1 ? 's' : ''}</strong>
                {' — '}
                {parts.join(', ')}.
            </p>
        </div>
    );
}

// ---------------------------------------------------------------------------
// App component
// ---------------------------------------------------------------------------

export function App() {
    const [appData] = useState<AppData[]>(parseAppData);
    const [filters, setFilters] = useState<FilterState>(INITIAL_FILTERS);
    const [selectedApp, setSelectedApp] = useState<AppData | null>(null);
    const searchRef = useRef<HTMLInputElement>(null);

    const resolvedTitle = reportTitle.startsWith('{%') ? 'Microsoft Graph Permission Analysis' : reportTitle;
    const resolvedTenant = tenantName.startsWith('{%') ? 'Development Tenant' : tenantName;
    const resolvedTenantId = tenantId.startsWith('{%') ? 'dev-tenant-id' : tenantId;
    const resolvedDate = generatedOn.startsWith('{%') ? new Date().toLocaleString() : generatedOn;

    document.title = resolvedTitle;

    // Keyboard shortcuts
    useEffect(() => {
        function onKey(e: KeyboardEvent) {
            if (e.key === 'Escape') {
                setSelectedApp(null);
                return;
            }
            const tag = (e.target as HTMLElement).tagName;
            if (e.key === '/' && tag !== 'INPUT' && tag !== 'TEXTAREA' && tag !== 'SELECT') {
                e.preventDefault();
                setTimeout(() => searchRef.current?.focus(), 30);
            }
        }
        document.addEventListener('keydown', onKey);
        return () => document.removeEventListener('keydown', onKey);
    }, []);

    function toggleTheme() {
        const isDark = document.documentElement.classList.toggle('dark');
        localStorage.theme = isDark ? 'dark' : 'light';
    }

    function setStatus(status: string) {
        setFilters({ ...INITIAL_FILTERS, status });
    }

    return (
        <div className="min-h-screen bg-slate-50 dark:bg-slate-950 transition-colors duration-200">

            {/* Top bar */}
            <header className="sticky top-0 z-20 flex items-center gap-3 px-4 py-2.5 bg-white/95 dark:bg-slate-900/95 backdrop-blur border-b border-slate-200 dark:border-slate-800">
                <div className="flex-1 min-w-0">
                    <h1 className="text-sm font-semibold text-slate-800 dark:text-slate-100 truncate">
                        {resolvedTitle}
                    </h1>
                    <p className="text-xs text-slate-400 dark:text-slate-500 truncate">
                        {resolvedTenant}
                        {' · '}
                        <span className="font-mono">{resolvedTenantId}</span>
                        {' · '}
                        {resolvedDate}
                    </p>
                </div>
                <div className="flex items-center gap-1">
                    <button
                        onClick={() => setTimeout(() => searchRef.current?.focus(), 30)}
                        className="p-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
                        title="Search (press /)"
                    >
                        <svg className="w-4 h-4 text-slate-500 dark:text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                        </svg>
                    </button>
                    <button
                        onClick={() => exportToCSV(appData)}
                        className="p-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
                        title="Export CSV"
                    >
                        <svg className="w-4 h-4 text-slate-500 dark:text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                        </svg>
                    </button>
                    <button
                        onClick={toggleTheme}
                        className="p-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
                        title="Toggle dark mode"
                    >
                        <svg className="w-4 h-4 hidden dark:block text-yellow-400" fill="currentColor" viewBox="0 0 20 20">
                            <path d="M10 2a1 1 0 011 1v1a1 1 0 11-2 0V3a1 1 0 011-1zm4 8a4 4 0 11-8 0 4 4 0 018 0zm-.464 4.95l.707.707a1 1 0 001.414-1.414l-.707-.707a1 1 0 00-1.414 1.414zm2.12-10.607a1 1 0 010 1.414l-.706.707a1 1 0 11-1.414-1.414l.707-.707a1 1 0 011.414 0zM17 11a1 1 0 100-2h-1a1 1 0 100 2h1zm-7 4a1 1 0 011 1v1a1 1 0 11-2 0v-1a1 1 0 011-1zM5.05 6.464A1 1 0 106.465 5.05l-.708-.707a1 1 0 00-1.414 1.414l.707.707zm1.414 8.486l-.707.707a1 1 0 01-1.414-1.414l.707-.707a1 1 0 011.414 1.414zM4 11a1 1 0 100-2H3a1 1 0 000 2h1z" />
                        </svg>
                        <svg className="w-4 h-4 block dark:hidden text-slate-500" fill="currentColor" viewBox="0 0 20 20">
                            <path d="M17.293 13.293A8 8 0 016.707 2.707a8.001 8.001 0 1010.586 10.586z" />
                        </svg>
                    </button>
                </div>
            </header>

            {/* Page content */}
            <main className="p-4 sm:p-6">
                <ExecutiveSummary appData={appData} />
                <Header
                    appData={appData}
                    onFilterAll={() => setFilters(INITIAL_FILTERS)}
                    onFilterOptimal={() => setStatus('good')}
                    onFilterExcess={() => setStatus('warning')}
                    onFilterUnmatched={() => setStatus('danger')}
                    onFilterThrottled={() => setFilters({ ...INITIAL_FILTERS, throttling: 'throttled' })}
                    onFilterCriticalThrottling={() => setFilters({ ...INITIAL_FILTERS, throttling: '4' })}
                />
                <FiltersPanel
                    filters={filters}
                    onChange={setFilters}
                    searchRef={searchRef}
                />
                <AppTable
                    appData={appData}
                    filters={filters}
                    onShowDetails={(index) => setSelectedApp(appData[index])}
                    onClearFilters={() => setFilters(INITIAL_FILTERS)}
                />
            </main>

            {/* Detail modal */}
            {selectedApp && (
                <AppDetailModal app={selectedApp} onClose={() => setSelectedApp(null)} />
            )}
        </div>
    );
}
