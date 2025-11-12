function New-PermissionAnalysisReport {
    param(
        [Parameter(Mandatory = $true)]
        [array]$AppData,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath = ".\PermissionAnalysisReport.html",

        [Parameter(Mandatory = $false)]
        [string]$ReportTitle = "Microsoft Graph Permission Analysis Report"
    )

    # Convert data to JSON for embedding
    $jsonData = $AppData | ConvertTo-Json -Depth 10 -Compress

    # Properly escape for JavaScript - need to escape backslashes and quotes
    $jsonData = $jsonData.Replace('\', '\\').Replace('"', '\"').Replace([Environment]::NewLine, '\n')

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$ReportTitle</title>
    <link href="https://cdn.jsdelivr.net/npm/tailwindcss@2.2.19/dist/tailwind.min.css" rel="stylesheet">
    <link href="https://cdn.datatables.net/1.11.5/css/jquery.dataTables.min.css" rel="stylesheet">
    <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.5.1/jquery.min.js"></script>
    <script src="https://cdn.datatables.net/1.11.5/js/jquery.dataTables.min.js"></script>
    <script src="https://cdn.datatables.net/buttons/2.2.2/js/dataTables.buttons.min.js"></script>
    <script src="https://cdn.datatables.net/buttons/2.2.2/js/buttons.html5.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.1.3/jszip.min.js"></script>
    <link href="https://cdn.datatables.net/buttons/2.2.2/css/buttons.dataTables.min.css" rel="stylesheet">
    <style>
        .status-badge {
            display: inline-block;
            padding: 0.25rem 0.75rem;
            border-radius: 9999px;
            font-size: 0.75rem;
            font-weight: 600;
        }
        .status-good { background-color: #D1FAE5; color: #065F46; }
        .status-warning { background-color: #FEF3C7; color: #92400E; }
        .status-danger { background-color: #FEE2E2; color: #991B1B; }
    </style>
</head>
<body class="bg-gray-100 min-h-screen">
    <div class="container mx-auto px-4 py-8">
        <!-- Header -->
        <div class="bg-white rounded-lg shadow-lg p-6 mb-6">
            <h1 class="text-3xl font-bold text-gray-800 mb-2">$ReportTitle</h1>
            <p class="text-gray-600">Generated on: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
            <div class="mt-4 grid grid-cols-1 md:grid-cols-4 gap-4">
                <div class="bg-blue-50 rounded-lg p-4">
                    <div class="text-blue-600 text-sm font-semibold">Total Applications</div>
                    <div class="text-2xl font-bold text-blue-900" id="totalApps">0</div>
                </div>
                <div class="bg-green-50 rounded-lg p-4">
                    <div class="text-green-600 text-sm font-semibold">Fully Matched All Activity To Permissions</div>
                    <div class="text-2xl font-bold text-green-900" id="fullyMatched">0</div>
                </div>
                <div class="bg-yellow-50 rounded-lg p-4">
                    <div class="text-yellow-600 text-sm font-semibold">With Excessive Permissions</div>
                    <div class="text-2xl font-bold text-yellow-900" id="withExcess">0</div>
                </div>
                <div class="bg-red-50 rounded-lg p-4">
                    <div class="text-red-600 text-sm font-semibold">Unmatched Activities</div>
                    <div class="text-2xl font-bold text-red-900" id="withUnmatched">0</div>
                </div>
            </div>
        </div>

        <!-- Filters -->
        <div class="bg-white rounded-lg shadow-lg p-6 mb-6">
            <h2 class="text-xl font-bold text-gray-800 mb-4">Filters</h2>
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">Status</label>
                    <select id="statusFilter" class="w-full border border-gray-300 rounded-lg p-2">
                        <option value="">All</option>
                        <option value="good">Optimal (No Excess)</option>
                        <option value="warning">Has Excess Permissions</option>
                        <option value="danger">Unmatched Activities</option>
                    </select>
                </div>
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">Activity Status</label>
                    <select id="activityFilter" class="w-full border border-gray-300 rounded-lg p-2">
                        <option value="">All</option>
                        <option value="yes">Has Activity</option>
                        <option value="no">No Activity</option>
                    </select>
                </div>
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">Search</label>
                    <input type="text" id="searchBox" class="w-full border border-gray-300 rounded-lg p-2" placeholder="Search by app name...">
                </div>
            </div>
        </div>

        <!-- Results Table -->
        <div class="bg-white rounded-lg shadow-lg p-6">
            <div class="flex justify-between items-center mb-4">
                <h2 class="text-xl font-bold text-gray-800">Application Permission Analysis</h2>
                <button id="exportBtn" class="bg-blue-500 hover:bg-blue-600 text-white font-semibold py-2 px-4 rounded-lg">
                    Export to CSV
                </button>
            </div>
            <div class="overflow-x-auto">
                <table id="resultsTable" class="min-w-full bg-white display stripe hover">
                    <thead class="bg-gray-50">
                        <tr>
                            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Application Name</th>
                            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Current Permissions</th>
                            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Optimal Permissions</th>
                            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Excess Permissions</th>
                            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Missing Permissions</th>
                            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Activities</th>
                            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Details</th>
                        </tr>
                    </thead>
                    <tbody id="tableBody">
                        <!-- Data will be populated here -->
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <!-- Details Modal -->
    <div id="detailsModal" class="hidden fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
        <div class="relative top-20 mx-auto p-5 border w-11/12 max-w-4xl shadow-lg rounded-lg bg-white">
            <div class="flex justify-between items-center mb-4">
                <h3 class="text-2xl font-bold text-gray-900" id="modalTitle">Application Details</h3>
                <button id="closeModal" class="text-gray-400 hover:text-gray-600 text-3xl font-bold">&times;</button>
            </div>
            <div id="modalContent" class="mt-4 max-h-96 overflow-y-auto">
                <!-- Modal content will be populated here -->
            </div>
        </div>
    </div>

    <script>
        const appData = JSON.parse("$jsonData");
        let dataTable;
        let originalData = [];

        jQuery(document).ready(function() {
            console.log('Loaded', appData.length, 'applications');

            // Calculate statistics
            const stats = {
                total: appData.length,
                fullyMatched: appData.filter(app => app.MatchedAllActivity && (!app.ExcessPermissions || app.ExcessPermissions.length === 0)).length,
                withExcess: appData.filter(app => app.ExcessPermissions && app.ExcessPermissions.length > 0).length,
                withUnmatched: appData.filter(app => !app.MatchedAllActivity).length
            };

            jQuery('#totalApps').text(stats.total);
            jQuery('#fullyMatched').text(stats.fullyMatched);
            jQuery('#withExcess').text(stats.withExcess);
            jQuery('#withUnmatched').text(stats.withUnmatched);

            // Prepare data for DataTables
            originalData = prepareTableData(appData);

            // Initialize DataTable with proper column definitions
            dataTable = jQuery('#resultsTable').DataTable({
                data: originalData,
                pageLength: 25,
                order: [[0, 'asc']],
                columns: [
                    {
                        data: 'appName',
                        render: function(data, type, row) {
                            if (type === 'display') {
                                return '<div class="font-medium text-gray-900">' + data + '</div><div class="text-xs text-gray-500">' + row.appId + '</div>';
                            }
                            return data;
                        }
                    },
                    {
                        data: 'status',
                        render: function(data, type, row) {
                            if (type === 'display') {
                                return getStatusBadge(data);
                            }
                            return data;
                        }
                    },
                    {
                        data: 'currentPerms',
                        render: function(data, type, row) {
                            if (type === 'display') {
                                let html = '<span class="font-semibold">' + data.length + '</span>';
                                if (data.length > 0) {
                                    html += '<br><span class="text-xs text-gray-500">' + data.slice(0, 2).join(', ') + (data.length > 2 ? '...' : '') + '</span>';
                                }
                                return html;
                            }
                            return data.length;
                        }
                    },
                    {
                        data: 'optimalPerms',
                        render: function(data, type, row) {
                            if (type === 'display') {
                                let html = '<span class="font-semibold text-green-600">' + data.length + '</span>';
                                if (data.length > 0) {
                                    const names = data.map(p => p.Permission);
                                    html += '<br><span class="text-xs text-gray-500">' + names.slice(0, 2).join(', ') + (names.length > 2 ? '...' : '') + '</span>';
                                }
                                return html;
                            }
                            return data.length;
                        }
                    },
                    {
                        data: 'excessPerms',
                        render: function(data, type, row) {
                            if (type === 'display') {
                                let html = '<span class="font-semibold ' + (data.length > 0 ? 'text-red-600' : 'text-green-600') + '">' + data.length + '</span>';
                                if (data.length > 0) {
                                    html += '<br><span class="text-xs text-red-500">' + data.slice(0, 2).join(', ') + (data.length > 2 ? '...' : '') + '</span>';
                                }
                                return html;
                            }
                            return data.length;
                        }
                    },
                    {
                        data: 'missingPerms',
                        render: function(data, type, row) {
                            if (type === 'display') {
                                let html = '<span class="font-semibold ' + (data.length > 0 ? 'text-yellow-600' : 'text-green-600') + '">' + data.length + '</span>';
                                if (data.length > 0) {
                                    html += '<br><span class="text-xs text-yellow-600">' + data.slice(0, 2).join(', ') + (data.length > 2 ? '...' : '') + '</span>';
                                }
                                return html;
                            }
                            return data.length;
                        }
                    },
                    {
                        data: 'activityCount',
                        render: function(data, type, row) {
                            if (type === 'display') {
                                let html = '<span class="font-semibold">' + data + '</span>';
                                html += data > 0 ? '<span class="text-xs text-gray-500"><br>endpoints</span>' : '<span class="text-xs text-gray-400"><br>No activity</span>';
                                return html;
                            }
                            return data;
                        }
                    },
                    {
                        data: 'index',
                        orderable: false,
                        render: function(data, type, row) {
                            return '<button onclick="showDetails(' + data + ')" class="bg-blue-500 hover:bg-blue-600 text-white font-semibold py-1 px-3 rounded text-xs">View Details</button>';
                        }
                    }
                ]
            });

            // Filters with custom implementation
            jQuery('#statusFilter').change(function() {
                const value = jQuery(this).val();
                dataTable.column(1).search(value, false, false).draw();
            });

            jQuery('#activityFilter').change(function() {
                const value = jQuery(this).val();
                if (value === 'yes') {
                    dataTable.column(6).search('^[1-9]', true, false).draw();
                } else if (value === 'no') {
                    dataTable.column(6).search('^0$', true, false).draw();
                } else {
                    dataTable.column(6).search('').draw();
                }
            });

            jQuery('#searchBox').keyup(function() {
                dataTable.search(jQuery(this).val()).draw();
            });

            // Export button
            jQuery('#exportBtn').click(function() {
                exportToCSV();
            });

            // Modal handlers
            jQuery('#closeModal').click(function() {
                jQuery('#detailsModal').addClass('hidden');
            });

            jQuery(window).click(function(event) {
                if (jQuery(event.target).is('#detailsModal')) {
                    jQuery('#detailsModal').addClass('hidden');
                }
            });
        });

        function prepareTableData(data) {
            return data.map((app, index) => {
                const currentPerms = Array.isArray(app.CurrentPermissions) ? app.CurrentPermissions : (app.CurrentPermissions ? [app.CurrentPermissions] : []);
                const optimalPerms = Array.isArray(app.OptimalPermissions) ? app.OptimalPermissions : (app.OptimalPermissions ? [app.OptimalPermissions] : []);
                const excessPerms = Array.isArray(app.ExcessPermissions) ? app.ExcessPermissions : (app.ExcessPermissions ? [app.ExcessPermissions] : []);
                const missingPerms = Array.isArray(app.MissingPermissions) ? app.MissingPermissions : (app.MissingPermissions ? [app.MissingPermissions] : []);
                const activityCount = app.Activity ? (Array.isArray(app.Activity) ? app.Activity.length : 1) : 0;

                return {
                    appName: app.PrincipalName || 'N/A',
                    appId: app.PrincipalId || 'N/A',
                    status: getStatus(app),
                    currentPerms: currentPerms,
                    optimalPerms: optimalPerms,
                    excessPerms: excessPerms,
                    missingPerms: missingPerms,
                    activityCount: activityCount,
                    index: index
                };
            });
        }

        function getStatus(app) {
            if (!app.MatchedAllActivity) return 'danger';
            if (app.ExcessPermissions && ((Array.isArray(app.ExcessPermissions) && app.ExcessPermissions.length > 0) || (!Array.isArray(app.ExcessPermissions) && app.ExcessPermissions))) return 'warning';
            return 'good';
        }

        function getStatusBadge(status) {
            const badges = {
                good: '<span class="status-badge status-good">&#10003; Optimal</span>',
                warning: '<span class="status-badge status-warning">&#9888; Has Excess</span>',
                danger: '<span class="status-badge status-danger">&#10007; Unmatched</span>'
            };
            return badges[status] || '';
        }

        function showDetails(index) {
            const app = appData[index];
            jQuery('#modalTitle').text(app.PrincipalName || 'Application Details');

            let content = '<div class="space-y-4"><div class="border-b pb-4"><h4 class="font-bold text-lg mb-2">Application Information</h4>';
            content += '<p><span class="font-semibold">Principal ID:</span> ' + app.PrincipalId + '</p>';
            content += '<p><span class="font-semibold">Total App Roles:</span> ' + app.AppRoleCount + '</p>';
            content += '<p><span class="font-semibold">Matched All Activities:</span> ' + (app.MatchedAllActivity ? '&#10003; Yes' : '&#10007; No') + '</p></div>';

            const currentPerms = Array.isArray(app.CurrentPermissions) ? app.CurrentPermissions : (app.CurrentPermissions ? [app.CurrentPermissions] : []);
            if (currentPerms.length > 0) {
                content += '<div class="border-b pb-4"><h4 class="font-bold text-lg mb-2">Current Permissions (' + currentPerms.length + ')</h4><ul class="list-disc list-inside text-sm space-y-1">';
                currentPerms.forEach(p => { content += '<li>' + p + '</li>'; });
                content += '</ul></div>';
            }

            const optimalPerms = Array.isArray(app.OptimalPermissions) ? app.OptimalPermissions : [];
            if (optimalPerms.length > 0) {
                content += '<div class="border-b pb-4"><h4 class="font-bold text-lg mb-2 text-green-600">Optimal Permissions (' + optimalPerms.length + ')</h4><ul class="list-disc list-inside text-sm space-y-1">';
                optimalPerms.forEach(p => { content += '<li><span class="font-medium">' + p.Permission + '</span> (Covers ' + p.ActivitiesCovered + ' activities)</li>'; });
                content += '</ul></div>';
            }

            const excessPerms = Array.isArray(app.ExcessPermissions) ? app.ExcessPermissions : (app.ExcessPermissions ? [app.ExcessPermissions] : []);
            if (excessPerms.length > 0) {
                content += '<div class="border-b pb-4"><h4 class="font-bold text-lg mb-2 text-red-600">Excess Permissions (' + excessPerms.length + ')</h4><ul class="list-disc list-inside text-sm space-y-1 text-red-600">';
                excessPerms.forEach(p => { content += '<li>' + p + '</li>'; });
                content += '</ul></div>';
            }

            const missingPerms = Array.isArray(app.MissingPermissions) ? app.MissingPermissions : (app.MissingPermissions ? [app.MissingPermissions] : []);
            if (missingPerms.length > 0) {
                content += '<div class="border-b pb-4"><h4 class="font-bold text-lg mb-2 text-yellow-600">Missing Permissions (' + missingPerms.length + ')</h4><ul class="list-disc list-inside text-sm space-y-1 text-yellow-600">';
                missingPerms.forEach(p => { content += '<li>' + p + '</li>'; });
                content += '</ul></div>';
            }

            const activities = Array.isArray(app.Activity) ? app.Activity : (app.Activity ? [app.Activity] : []);
            if (activities.length > 0) {
                content += '<div><h4 class="font-bold text-lg mb-2">API Activities (' + activities.length + ')</h4><div class="max-h-64 overflow-y-auto"><table class="min-w-full text-sm"><thead class="bg-gray-50 sticky top-0"><tr><th class="px-2 py-2 text-left">Method</th><th class="px-2 py-2 text-left">Endpoint</th></tr></thead><tbody>';
                activities.forEach(a => { content += '<tr class="border-b"><td class="px-2 py-2 font-mono text-xs">' + a.Method + '</td><td class="px-2 py-2 font-mono text-xs break-all">' + a.Uri + '</td></tr>'; });
                content += '</tbody></table></div></div>';
            }

            const unmatched = Array.isArray(app.UnmatchedActivities) ? app.UnmatchedActivities : [];
            if (unmatched.length > 0) {
                content += '<div class="bg-red-50 p-4 rounded"><h4 class="font-bold text-lg mb-2 text-red-600">Unmatched Activities (' + unmatched.length + ')</h4><ul class="list-disc list-inside text-sm space-y-1 text-red-700">';
                unmatched.forEach(a => { content += '<li>' + a.Method + ' ' + a.Path + '</li>'; });
                content += '</ul></div>';
            }

            content += '</div>';
            jQuery('#modalContent').html(content);
            jQuery('#detailsModal').removeClass('hidden');
        }

                function exportToCSV() {
                    let csv = 'Application Name;Principal ID;Status;Current Permissions;Current Permission Count;Optimal Permissions;Optimal Permission Count;Excess Permissions;Excess Permission Count;Missing Permissions;Missing Permission Count;Activity Count;Matched All Activities\n';

                    appData.forEach(app => {
                        const status = getStatus(app);
                        const currentPerms = Array.isArray(app.CurrentPermissions) ? app.CurrentPermissions : (app.CurrentPermissions ? [app.CurrentPermissions] : []);
                        const optimalPerms = Array.isArray(app.OptimalPermissions) ? app.OptimalPermissions : [];
                        const excessPerms = Array.isArray(app.ExcessPermissions) ? app.ExcessPermissions : (app.ExcessPermissions ? [app.ExcessPermissions] : []);
                        const missingPerms = Array.isArray(app.MissingPermissions) ? app.MissingPermissions : (app.MissingPermissions ? [app.MissingPermissions] : []);
                        const activities = Array.isArray(app.Activity) ? app.Activity : (app.Activity ? [app.Activity] : []);

                        const row = [
                            '"' + (app.PrincipalName || '').replace(/"/g, '""') + '"',
                            '"' + (app.PrincipalId || '').replace(/"/g, '""') + '"',
                            status,
                            '"' + currentPerms.join(', ').replace(/"/g, '""') + '"',
                            currentPerms.length,
                            '"' + optimalPerms.map(p => p.Permission).join(', ').replace(/"/g, '""') + '"',
                            optimalPerms.length,
                            '"' + excessPerms.join(', ').replace(/"/g, '""') + '"',
                            excessPerms.length,
                            '"' + missingPerms.join(', ').replace(/"/g, '""') + '"',
                            missingPerms.length,
                            activities.length,
                            app.MatchedAllActivity ? 'Yes' : 'No'
                        ];
                        csv += row.join(';') + '\n';
                    });

                    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
                    const link = document.createElement('a');
                    const url = URL.createObjectURL(blob);
                    link.setAttribute('href', url);
                    link.setAttribute('download', 'permission_analysis_' + new Date().getTime() + '.csv');
                    link.style.visibility = 'hidden';
                    document.body.appendChild(link);
                    link.click();
                    document.body.removeChild(link);
                }
    </script>
</body>
</html>
"@

    # Write the HTML to file
    $html | Out-File -FilePath $OutputPath -Encoding UTF8

    Write-Host "Report generated successfully: $OutputPath" -ForegroundColor Green
}