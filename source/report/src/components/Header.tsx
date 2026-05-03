import React from 'react';
import { AppData } from '../types';
import { calculateStats } from '../utils/helpers';

interface Props {
    appData: AppData[];
    title: string;
    tenantId: string;
    tenantName: string;
    generatedOn: string;
    onFilterAll: () => void;
    onFilterOptimal: () => void;
    onFilterExcess: () => void;
    onFilterUnmatched: () => void;
    onFilterThrottled: () => void;
    onFilterCriticalThrottling: () => void;
}

export function Header({
    appData,
    title,
    tenantId,
    tenantName,
    generatedOn,
    onFilterAll,
    onFilterOptimal,
    onFilterExcess,
    onFilterUnmatched,
    onFilterThrottled,
    onFilterCriticalThrottling,
}: Props) {
    const stats = calculateStats(appData);
    const pct = (n: number) => stats.total > 0 ? ` (${Math.round((n / stats.total) * 100)}%)` : '';

    function toggleTheme() {
        const isDark = document.documentElement.classList.toggle('dark');
        localStorage.theme = isDark ? 'dark' : 'light';
    }

    const statCards = [
        {
            bg: 'bg-blue-50 dark:bg-blue-900/30',
            border: 'hover:border-blue-300 dark:hover:border-blue-500',
            text: 'text-blue-600 dark:text-blue-400',
            value: 'text-blue-900 dark:text-blue-300',
            label: 'Total Applications',
            count: stats.total,
            pct: '',
            onClick: onFilterAll,
        },
        {
            bg: 'bg-green-50 dark:bg-green-900/30',
            border: 'hover:border-green-300 dark:hover:border-green-500',
            text: 'text-green-600 dark:text-green-400',
            value: 'text-green-900 dark:text-green-300',
            label: 'Optimal Permissions',
            count: stats.fullyMatched,
            pct: pct(stats.fullyMatched),
            onClick: onFilterOptimal,
        },
        {
            bg: 'bg-yellow-50 dark:bg-yellow-900/30',
            border: 'hover:border-yellow-300 dark:hover:border-yellow-500',
            text: 'text-yellow-600 dark:text-yellow-400',
            value: 'text-yellow-900 dark:text-yellow-300',
            label: 'Excessive Permissions',
            count: stats.withExcess,
            pct: pct(stats.withExcess),
            onClick: onFilterExcess,
        },
        {
            bg: 'bg-red-50 dark:bg-red-900/30',
            border: 'hover:border-red-300 dark:hover:border-red-500',
            text: 'text-red-600 dark:text-red-400',
            value: 'text-red-900 dark:text-red-300',
            label: 'Unmatched Activities',
            count: stats.withUnmatched,
            pct: pct(stats.withUnmatched),
            onClick: onFilterUnmatched,
        },
    ];

    const throttleCards = [
        {
            bg: 'bg-purple-50 dark:bg-purple-900/30',
            border: 'hover:border-purple-300 dark:hover:border-purple-500',
            text: 'text-purple-600 dark:text-purple-400',
            value: 'text-purple-900 dark:text-purple-300',
            label: 'Apps Throttled',
            count: stats.throttledApps,
            pct: pct(stats.throttledApps),
            onClick: onFilterThrottled,
            clickable: true,
        },
        {
            bg: 'bg-orange-50 dark:bg-orange-900/30',
            border: 'hover:border-orange-300 dark:hover:border-orange-500',
            text: 'text-orange-600 dark:text-orange-400',
            value: 'text-orange-900 dark:text-orange-300',
            label: 'Critical Throttling',
            count: stats.criticalThrottling,
            pct: pct(stats.criticalThrottling),
            onClick: onFilterCriticalThrottling,
            clickable: true,
        },
        {
            bg: 'bg-indigo-50 dark:bg-indigo-900/30',
            border: '',
            text: 'text-indigo-600 dark:text-indigo-400',
            value: 'text-indigo-900 dark:text-indigo-300',
            label: 'Total 429 Errors',
            count: stats.total429.toLocaleString(),
            pct: '',
            onClick: undefined,
        },
        {
            bg: 'bg-pink-50 dark:bg-pink-900/30',
            border: '',
            text: 'text-pink-600 dark:text-pink-400',
            value: 'text-pink-900 dark:text-pink-300',
            label: 'Avg Throttle Rate',
            count: `${stats.avgThrottleRate}%`,
            pct: '',
            onClick: undefined,
        },
    ];

    return (
        <div className="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-3 sm:p-6 mb-4 sm:mb-6 transition-colors duration-200">
            <div className="flex justify-between items-center mb-2">
                <h1 className="text-lg sm:text-2xl md:text-3xl font-bold text-gray-800 dark:text-gray-100">{title}</h1>
                <button
                    onClick={toggleTheme}
                    className="p-2 rounded-lg bg-gray-200 dark:bg-gray-700 hover:bg-gray-300 dark:hover:bg-gray-600 transition-colors duration-200"
                >
                    {/* Moon icon */}
                    <svg className="w-6 h-6 hidden dark:block text-yellow-400" fill="currentColor" viewBox="0 0 20 20">
                        <path d="M10 2a1 1 0 011 1v1a1 1 0 11-2 0V3a1 1 0 011-1zm4 8a4 4 0 11-8 0 4 4 0 018 0zm-.464 4.95l.707.707a1 1 0 001.414-1.414l-.707-.707a1 1 0 00-1.414 1.414zm2.12-10.607a1 1 0 010 1.414l-.706.707a1 1 0 11-1.414-1.414l.707-.707a1 1 0 011.414 0zM17 11a1 1 0 100-2h-1a1 1 0 100 2h1zm-7 4a1 1 0 011 1v1a1 1 0 11-2 0v-1a1 1 0 011-1zM5.05 6.464A1 1 0 106.465 5.05l-.708-.707a1 1 0 00-1.414 1.414l.707.707zm1.414 8.486l-.707.707a1 1 0 01-1.414-1.414l.707-.707a1 1 0 011.414 1.414zM4 11a1 1 0 100-2H3a1 1 0 000 2h1z" />
                    </svg>
                    {/* Sun icon */}
                    <svg className="w-6 h-6 block dark:hidden text-gray-700" fill="currentColor" viewBox="0 0 20 20">
                        <path d="M17.293 13.293A8 8 0 016.707 2.707a8.001 8.001 0 1010.586 10.586z" />
                    </svg>
                </button>
            </div>
            <p className="text-gray-600 dark:text-gray-400">Tenant ID: {tenantId}</p>
            <p className="text-gray-600 dark:text-gray-400">Tenant Name: {tenantName}</p>
            <p className="text-gray-600 dark:text-gray-400">Generated on: {generatedOn}</p>

            <div className="mt-4 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-2 sm:gap-4">
                {statCards.map((card) => (
                    <div
                        key={card.label}
                        className={`${card.bg} rounded-lg p-3 sm:p-4 transition-colors duration-200 cursor-pointer hover:shadow-md hover:border-2 ${card.border} border-2 border-transparent`}
                        onClick={card.onClick}
                        title="Click to filter"
                    >
                        <div className={`${card.text} text-xs sm:text-sm font-semibold`}>{card.label}</div>
                        <div className={`text-xl sm:text-2xl font-bold ${card.value}`}>
                            {card.count}
                            {card.pct && <span className="text-sm font-normal ml-1 opacity-70">{card.pct}</span>}
                        </div>
                    </div>
                ))}
            </div>

            <div className="mt-2 sm:mt-4 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-2 sm:gap-4">
                {throttleCards.map((card) => (
                    <div
                        key={card.label}
                        className={`${card.bg} rounded-lg p-3 sm:p-4 transition-colors duration-200 ${card.onClick ? 'cursor-pointer hover:shadow-md hover:border-2 ' + card.border + ' border-2 border-transparent' : ''}`}
                        onClick={card.onClick}
                        title={card.onClick ? 'Click to filter' : undefined}
                    >
                        <div className={`${card.text} text-xs sm:text-sm font-semibold`}>{card.label}</div>
                        <div className={`text-xl sm:text-2xl font-bold ${card.value}`}>
                            {card.count}
                            {card.pct && <span className="text-sm font-normal ml-1 opacity-70">{card.pct}</span>}
                        </div>
                    </div>
                ))}
            </div>
        </div>
    );
}
