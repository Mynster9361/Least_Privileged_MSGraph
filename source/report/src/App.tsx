import React, { useState } from 'react';
import { AppData, FilterState } from './types';
import sampleData from './sampleData';
import { Header } from './components/Header';
import { FiltersPanel } from './components/FiltersPanel';
import { AppTable } from './components/AppTable';
import { AppDetailModal } from './components/AppDetailModal';

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
        // During development the placeholder is not valid JSON — return sample data
        if (appDataJson.startsWith('{%')) return sampleData;
        return JSON.parse(appDataJson) as AppData[];
    } catch {
        return sampleData;
    }
}

const INITIAL_FILTERS: FilterState = {
    status: '',
    activity: '',
    throttling: '',
    privilege: '',
    search: '',
};

export function App() {
    const [appData] = useState<AppData[]>(parseAppData);
    const [filters, setFilters] = useState<FilterState>(INITIAL_FILTERS);
    const [selectedApp, setSelectedApp] = useState<AppData | null>(null);

    function setStatus(status: string) {
        setFilters({ ...INITIAL_FILTERS, status });
    }

    return (
        <div className="bg-gray-100 dark:bg-gray-900 min-h-screen transition-colors duration-200">
            <div className="w-full sm:w-[95%] md:w-[90%] lg:w-[85%] xl:w-[80%] 2xl:max-w-[70%] mx-auto px-2 sm:px-4 py-4 sm:py-8">
                <Header
                    appData={appData}
                    title={reportTitle.startsWith('{%') ? 'Microsoft Graph Permission Analysis Report' : reportTitle}
                    tenantId={tenantId.startsWith('{%') ? 'dev-tenant-id' : tenantId}
                    tenantName={tenantName.startsWith('{%') ? 'Development' : tenantName}
                    generatedOn={generatedOn.startsWith('{%') ? new Date().toLocaleString() : generatedOn}
                    onFilterAll={() => setFilters(INITIAL_FILTERS)}
                    onFilterOptimal={() => setStatus('good')}
                    onFilterExcess={() => setStatus('warning')}
                    onFilterUnmatched={() => setStatus('danger')}
                    onFilterThrottled={() => setFilters({ ...INITIAL_FILTERS, throttling: 'throttled' })}
                    onFilterCriticalThrottling={() => setFilters({ ...INITIAL_FILTERS, throttling: '4' })}
                />
                <FiltersPanel filters={filters} onChange={setFilters} />
                <AppTable
                    appData={appData}
                    filters={filters}
                    onShowDetails={(index) => setSelectedApp(appData[index])}
                />
            </div>

            {selectedApp && (
                <AppDetailModal app={selectedApp} onClose={() => setSelectedApp(null)} />
            )}
        </div>
    );
}
