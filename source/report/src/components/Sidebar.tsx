import React from 'react';

// ---------------------------------------------------------------------------
// ViewId — shared type for the current page/section
// ---------------------------------------------------------------------------

export type ViewId = 'overview' | 'apps' | 'recommendations' | 'export';

// ---------------------------------------------------------------------------
// Compact icon helper
// ---------------------------------------------------------------------------

function Icon({ d, className = 'w-4 h-4' }: { d: string; className?: string }) {
    return (
        <svg className={className} fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d={d} />
        </svg>
    );
}

const ICON_PATHS: Record<ViewId | 'shield', string> = {
    shield:
        'M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z',
    overview:
        'M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zm0 9.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zm9.75-9.75A2.25 2.25 0 0115.75 3.75H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zm0 9.75A2.25 2.25 0 0115.75 13.5H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z',
    apps:
        'M6 6.878V6a2.25 2.25 0 012.25-2.25h7.5A2.25 2.25 0 0118 6v.878m-12 0c.235-.083.487-.128.75-.128h10.5c.263 0 .515.045.75.128m-12 0A2.25 2.25 0 004.5 9v.878m13.5-3A2.25 2.25 0 0119.5 9v.878m0 0a2.246 2.246 0 00-.75-.128H5.25c-.263 0-.515.045-.75.128m15 0A2.25 2.25 0 0121 12v6a2.25 2.25 0 01-2.25 2.25H5.25A2.25 2.25 0 013 18v-6c0-.98.626-1.813 1.5-2.122',
    recommendations:
        'M12 18v-5.25m0 0a6.01 6.01 0 001.5-.189m-1.5.189a6.01 6.01 0 01-1.5-.189m3.75 7.478a12.06 12.06 0 01-4.5 0m3.75 2.383a14.406 14.406 0 01-3 0M14.25 18v-.192c0-.983.658-1.823 1.508-2.316a7.5 7.5 0 10-7.517 0c.85.493 1.509 1.333 1.509 2.316V18',
    export:
        'M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3',
};

// ---------------------------------------------------------------------------
// Props
// ---------------------------------------------------------------------------

interface Props {
    view: ViewId;
    onNavigate: (v: ViewId) => void;
    totalApps: number;
    findingsCount: number;
    onToggleTheme: () => void;
}

// ---------------------------------------------------------------------------
// Sidebar component
// ---------------------------------------------------------------------------

export function Sidebar({ view, onNavigate, totalApps, findingsCount, onToggleTheme }: Props) {
    const items: { id: ViewId; label: string; badge?: number }[] = [
        { id: 'overview', label: 'Overview' },
        { id: 'apps', label: 'Applications', badge: totalApps },
        { id: 'recommendations', label: 'Findings', badge: findingsCount > 0 ? findingsCount : undefined },
        { id: 'export', label: 'Export' },
    ];

    return (
        <aside className="hidden lg:flex flex-col fixed left-0 top-0 w-[220px] h-screen bg-slate-900 z-30 select-none">
            {/* Logo */}
            <div className="px-4 py-4 flex items-center gap-2.5 border-b border-slate-700/50">
                <div className="w-7 h-7 rounded-lg bg-indigo-600 flex items-center justify-center flex-shrink-0">
                    <Icon d={ICON_PATHS.shield} className="w-4 h-4 text-white" />
                </div>
                <div className="leading-tight">
                    <div className="text-[13px] font-bold text-white">LeastPriv</div>
                    <div className="text-[10px] text-slate-400">MSGraph Analyzer</div>
                </div>
            </div>

            {/* Nav */}
            <nav className="flex-1 py-3 px-2 space-y-0.5 overflow-y-auto">
                {items.map(({ id, label, badge }) => {
                    const active = view === id;
                    return (
                        <button
                            key={id}
                            onClick={() => onNavigate(id)}
                            className={`w-full flex items-center justify-between px-3 py-2 rounded-lg text-[13px] font-medium transition-colors ${active
                                    ? 'bg-indigo-600/20 text-indigo-300'
                                    : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800'
                                }`}
                        >
                            <div className="flex items-center gap-2.5">
                                <Icon
                                    d={ICON_PATHS[id]}
                                    className={`w-4 h-4 flex-shrink-0 ${active ? 'text-indigo-400' : ''}`}
                                />
                                {label}
                            </div>
                            {badge !== undefined && (
                                <span
                                    className={`text-[11px] rounded-full px-1.5 py-0.5 font-medium tabular-nums leading-none ${active
                                            ? 'bg-indigo-500/30 text-indigo-300'
                                            : id === 'recommendations' && badge > 0
                                                ? 'bg-red-500/20 text-red-400'
                                                : 'bg-slate-700 text-slate-400'
                                        }`}
                                >
                                    {badge}
                                </span>
                            )}
                        </button>
                    );
                })}
            </nav>

            {/* Footer: theme toggle + hint */}
            <div className="px-3 py-3 border-t border-slate-700/50 space-y-1">
                <button
                    onClick={onToggleTheme}
                    className="w-full flex items-center gap-2 px-3 py-2 rounded-lg text-[13px] text-slate-400 hover:text-slate-200 hover:bg-slate-800 transition-colors"
                    title="Toggle dark / light mode"
                >
                    {/* Sun icon */}
                    <svg className="w-4 h-4 flex-shrink-0 hidden dark:block text-yellow-400" fill="currentColor" viewBox="0 0 20 20">
                        <path d="M10 2a1 1 0 011 1v1a1 1 0 11-2 0V3a1 1 0 011-1zm4 8a4 4 0 11-8 0 4 4 0 018 0zm-.464 4.95l.707.707a1 1 0 001.414-1.414l-.707-.707a1 1 0 00-1.414 1.414zm2.12-10.607a1 1 0 010 1.414l-.706.707a1 1 0 11-1.414-1.414l.707-.707a1 1 0 011.414 0zM17 11a1 1 0 100-2h-1a1 1 0 100 2h1zm-7 4a1 1 0 011 1v1a1 1 0 11-2 0v-1a1 1 0 011-1zM5.05 6.464A1 1 0 106.465 5.05l-.708-.707a1 1 0 00-1.414 1.414l.707.707zm1.414 8.486l-.707.707a1 1 0 01-1.414-1.414l.707-.707a1 1 0 011.414 1.414zM4 11a1 1 0 100-2H3a1 1 0 000 2h1z" />
                    </svg>
                    {/* Moon icon */}
                    <svg className="w-4 h-4 flex-shrink-0 block dark:hidden" fill="currentColor" viewBox="0 0 20 20">
                        <path d="M17.293 13.293A8 8 0 016.707 2.707a8.001 8.001 0 1010.586 10.586z" />
                    </svg>
                    Toggle theme
                </button>
                <p className="text-[10px] text-slate-600 px-3 leading-relaxed">
                    Press <kbd className="text-slate-500 bg-slate-800 rounded px-1">/</kbd> to search
                    &ensp;·&ensp;<kbd className="text-slate-500 bg-slate-800 rounded px-1">Esc</kbd> to close
                </p>
            </div>
        </aside>
    );
}
