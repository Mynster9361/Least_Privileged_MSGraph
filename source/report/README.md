# LeastPrivilegedMSGraph Report

This folder contains the interactive HTML report template for the LeastPrivilegedMSGraph module.

It uses [vite-plugin-singlefile](https://github.com/richardtallent/vite-plugin-singlefile) to generate a single self-contained HTML file, which is then used by `Export-LPMSPermissionAnalysisReport` to generate reports.

- [@vitejs/plugin-react](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react/README.md) uses Babel for Fast Refresh
- [TanStack Table](https://tanstack.com/table) provides the sortable, paginated data table

## Developer Guide

### Pre-requisites

- [Node.js](https://nodejs.org/en/download/) version 18.0 or above

### First time setup

```bash
cd source/report
npm install
```

### Development

To start the development server with live reload:

```bash
npm run dev
```

Open `http://localhost:5173` in your browser. The report will show with empty data (the PowerShell placeholders are not valid JSON during dev). To test with real data, update the `parseAppData` function in `src/App.tsx` to return a hardcoded sample array.

### Build

To build and automatically update the template used by PowerShell:

```bash
npm run build
```

This will:
1. Build the Vite project → `dist/index.html` (single inlined HTML file, ~250KB)
2. Copy `dist/index.html` → `../data/base.html` (the PowerShell module template)

After building, run the PowerShell module build to package the updated template:

```powershell
# From the repository root:
.\build.ps1 -Tasks build
```

### How data injection works

The built `dist/index.html` contains these literal placeholder strings (preserved from `src/App.tsx` through the Vite build):

| Placeholder                              | Replaced with                           |
| ---------------------------------------- | --------------------------------------- |
| `{% block title %}{% endblock %}`        | Report title                            |
| `{% block tenant_id %}{% endblock %}`    | Azure AD tenant ID                      |
| `{% block tenant_name %}{% endblock %}`  | Azure AD tenant display name            |
| `{% block generated_on %}{% endblock %}` | Report generation timestamp             |
| `{% block app_data %}{% endblock %}`     | JSON array of application analysis data |

PowerShell's `Export-LPMSPermissionAnalysisReport` replaces these placeholders using `-replace` operations.

### Updating sample data for development

When you want to test the report with real data:

1. Run `Export-LPMSPermissionAnalysisReport` to generate a real report
2. Open the report HTML and find `const appDataJson = "`
3. Copy the JSON between the quotes
4. In `src/App.tsx`, update `parseAppData()` to return `JSON.parse('<pasted JSON>')`
5. Run `npm run dev` to view the report with real data

> **Important:** Do not commit real tenant data. Revert `src/App.tsx` before committing.
