import React from 'react';
import { Permission } from '../types';
import { getRiskBadgeClass, resolveRiskLabel } from '../utils/helpers';

interface Props {
    type: string;
}

export function PermissionTypeBadge({ type }: Props) {
    const classes: Record<string, string> = {
        Delegated: 'bg-blue-100 dark:bg-blue-900 text-blue-800 dark:text-blue-200',
        Application: 'bg-purple-100 dark:bg-purple-900 text-purple-800 dark:text-purple-200',
        Unknown: 'bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-400',
    };
    return (
        <span className={`inline-block ml-2 px-2 py-0.5 text-xs font-semibold rounded ${classes[type] ?? classes.Unknown}`}>
            {type}
        </span>
    );
}

interface RiskBadgeProps {
    permission: Permission | string | undefined;
    level?: number;
}

export function RiskBadge({ permission, level }: RiskBadgeProps) {
    const label = resolveRiskLabel(permission, level);
    return (
        <span className={`inline-block ml-1 px-1.5 py-0.5 text-xs font-bold rounded ${getRiskBadgeClass(label)}`}>
            {label}
        </span>
    );
}
