# Contributing to LeastPrivilegedMSGraph

We welcome contributions to LeastPrivilegedMSGraph! This document provides guidelines for contributing to this project.

## Table of Contents

- [How to Contribute](#how-to-contribute)
- [Getting Started](#getting-started)
- [Development Guidelines](#development-guidelines)
- [Submitting Issues](#submitting-issues)
- [Submitting Pull Requests](#submitting-pull-requests)
- [Coding Standards](#coding-standards)
- [Testing Requirements](#testing-requirements)
- [Documentation Requirements](#documentation-requirements)
- [Release Process](#release-process)

## How to Contribute

There are several ways you can contribute to this project:

- **Report bugs** - Submit detailed bug reports
- **Request features** - Suggest new functionality
- **Submit pull requests** - Fix bugs or implement new features
- **Improve documentation** - Help make our docs better
- **Review pull requests** - Help review and test changes

## Getting Started

### Prerequisites

Before contributing, ensure you have:

- **PowerShell 5.1 or later**
- **Git** for version control
- **Visual Studio Code** (recommended) with PowerShell extension
- **.NET SDK** (for certain build tasks)

### Setting Up Your Development Environment

1. **Fork the Repository**

   ```bash
   # Fork the repo on GitHub, then clone your fork
   git clone https://github.com/YOUR-USERNAME/Least_Privileged_MSGraph.git
   cd LeastPrivilegedMSGraph
   ```

2. **Add Upstream Remote**

   ```bash
   git remote add upstream https://github.com/Mynster9361/Least_Privileged_MSGraph.git
   ```

3. **Bootstrap Development Dependencies**

   ```powershell
   # Install all required modules for development
   ./build.ps1 -ResolveDependency -Tasks noop
   ```

4. **Verify Setup**

   ```powershell
   # Run a test build to ensure everything works
   ./build.ps1 -Tasks clean, build, test
   ```

## Development Guidelines

### Branch Strategy

- **main** - Production ready code
- **feature/*** - New features
- **hotfix/*** - Critical bug fixes
- **docs/*** - Documentation updates

### Version Management

This project uses [GitVersion](GitVersion.yml) for automatic versioning:

- **Breaking changes**: Use commit message with `(breaking change|breaking|major)`
- **New features**: Use commit message with `(adds?|features?|minor)`
- **Bug fixes**: Use commit message with `(fix|patch)`
- **No version bump**: Use `+semver: none` or `+semver: skip`

## Submitting Issues

### Bug Reports

When reporting bugs, please use the [bug report template](.github/ISSUE_TEMPLATE/Bug_report.md) and include:

- **Environment details** (PowerShell version, OS, module version)
- **Steps to reproduce** the issue
- **Expected behavior**
- **Actual behavior**
- **Error messages** (if any)
- **Screenshots** (if applicable)

### Feature Requests

For feature requests, use the [feature request template](.github/ISSUE_TEMPLATE/Feature_request.md) and include:

- **Use case description**
- **Proposed solution**
- **Alternative solutions considered**
- **Impact assessment**

### General Questions

For general questions, use the [general template](.github/ISSUE_TEMPLATE/General.md).

## Submitting Pull Requests

### Quick Contribution Steps

1. **Fork the repository**
2. **Create a feature branch**:

   ```bash
   git checkout -b feature/amazing-feature
   ```

3. **Make your changes** following our guidelines
4. **Add tests** for your changes
5. **Ensure all tests pass**:

   ```powershell
   ./build.ps1 -Tasks test
   ```

6. **Update documentation** as needed
7. **Commit your changes**:

   ```bash
   git commit -m 'Add amazing feature'
   ```

8. **Push to your branch**:

   ```bash
   git push origin feature/amazing-feature
   ```

9. **Submit a pull request**

### Pull Request Guidelines

When submitting a PR, please:

1. **Use the [PR template](.github/PULL_REQUEST_TEMPLATE.md)**
2. **Provide a clear description** of what your PR does
3. **Link related issues** using keywords (e.g., "fixes #123")
4. **Update the [CHANGELOG.md](CHANGELOG.md)** following [Keep a Changelog](https://keepachangelog.com/) format
5. **Ensure GitHub Actions CI passes** on all platforms
6. **Request review** from maintainers

### PR Checklist

Before submitting, ensure your PR meets these requirements:

- [ ] The PR represents a single logical change
- [ ] Added an entry under the Unreleased section in [CHANGELOG.md](CHANGELOG.md)
- [ ] Local clean build passes: `./build.ps1 -ResolveDependency`
- [ ] All tests pass with adequate coverage
- [ ] Code follows our style guidelines
- [ ] Documentation has been updated
- [ ] Comment-based help is complete and accurate
- [ ] Examples have been added/updated where appropriate

## Coding Standards

### PowerShell Style Guidelines

Follow these coding standards:

#### Function Structure

```powershell
function Verb-Noun {
    <#
    .SYNOPSIS
    Brief description of what the function does.

    .DESCRIPTION
    Detailed description of the function's purpose and behavior.

    .PARAMETER ParameterName
    Description of the parameter.

    .EXAMPLE
    Verb-Noun -ParameterName "Value"
    
    Description of what this example does.

    .NOTES
    Additional notes about the function.

    .LINK
    https://github.com/Mynster9361/Least_Privileged_MSGraph
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$ParameterName
    )

    begin {
        Write-Verbose "Starting $($MyInvocation.MyCommand)"
    }

    process {
        if ($PSCmdlet.ShouldProcess($ParameterName, 'Process Item')) {
            try {
                # Implementation here
                Write-Verbose "Processing: $ParameterName"
                
                # Return result
                [PSCustomObject]@{
                    Name = $ParameterName
                    Processed = Get-Date
                }
            }
            catch {
                Write-Error "Failed to process '$ParameterName': $_"
                throw
            }
        }
    }

    end {
        Write-Verbose "Completed $($MyInvocation.MyCommand)"
    }
}
```

#### Naming Conventions

- **Functions**: Use approved PowerShell verbs (`Get-Verb` to see list)
- **Parameters**: Use PascalCase
- **Variables**: Use camelCase for local variables
- **Classes**: Use PascalCase
- **Files**: Match the function name exactly

#### Code Quality

- **Use explicit parameter types**
- **Include parameter validation** where appropriate
- **Support pipeline input** when logical
- **Use `ShouldProcess`** for functions that modify state
- **Include proper error handling**
- **Write descriptive variable names**
- **Add comments for complex logic**

#### PSScriptAnalyzer

All code must pass PSScriptAnalyzer rules configured in [.vscode/analyzersettings.psd1](.vscode/analyzersettings.psd1).

Run analysis locally:

```powershell
Invoke-ScriptAnalyzer -Path ./source -Recurse
```

## Testing Requirements

### Test Coverage

- **Minimum 80% code coverage** required
- **All public functions** must have comprehensive tests
- **Critical private functions** should have tests
- **Edge cases and error conditions** must be tested

### Test Structure

Tests should be organized as follows:

```
tests/
├── Unit/                    # Unit tests (required)
│   ├── Public/             # Tests for public functions
│   ├── Private/            # Tests for private functions
│   └── Classes/            # Tests for classes
├── Integration/            # Integration tests (recommended)
└── QA/                     # Quality assurance tests
```

### Writing Tests

Use this template for unit tests:

```powershell
BeforeAll {
    $script:moduleName = 'LeastPrivilegedMSGraph'
    
    # Remove any existing module
    Get-Module -Name $script:moduleName -All | Remove-Module -Force
    
    # Import the module being tested
    Import-Module -Name $script:moduleName -Force
}

AfterAll {
    # Clean up
    Get-Module -Name $script:moduleName -All | Remove-Module -Force
}

Describe 'Function-Name' {
    BeforeEach {
        # Setup for each test
    }

    Context 'When provided with valid input' {
        It 'Should return expected result' {
            # Arrange
            $inputValue = 'TestValue'
            
            # Act
            $result = Function-Name -Parameter $inputValue
            
            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Property | Should -Be $inputValue
        }
    }

    Context 'When provided with invalid input' {
        It 'Should throw when parameter is invalid' {
            { Function-Name -Parameter $null } | Should -Throw
        }
    }

    Context 'When using WhatIf' {
        It 'Should support WhatIf parameter' {
            { Function-Name -Parameter 'Test' -WhatIf } | Should -Not -Throw
        }
    }
}
```

### Running Tests

```powershell
# Run all tests
./build.ps1 -Tasks test

# Run specific test file
Invoke-Pester ./tests/Unit/Public/Get-Something.tests.ps1

# Run tests with code coverage
./build.ps1 -Tasks test -CodeCoverageThreshold 80

# Run tests in VS Code
# Use Ctrl+Shift+P -> "PowerShell: Run Pester Tests"
```

For more details, see the [Testing Guidelines](https://dsccommunity.org/guidelines/testing-guidelines/#running-tests).

## Documentation Requirements

### Function Documentation

All public functions must include:

- **Complete comment-based help** with synopsis, description, parameters, examples
- **Parameter descriptions** for all parameters
- **At least one example** showing typical usage
- **Additional examples** for complex scenarios

### README Updates

When adding new functionality:

- Update the main [README.md](README.md) if the change affects users
- Add examples to demonstrate new features
- Update the Table of Contents if needed

### Changelog

All changes must be documented in [CHANGELOG.md](CHANGELOG.md) following [Keep a Changelog](https://keepachangelog.com/) format:

```markdown
## [Unreleased]

### Added
- New feature description [#123]

### Changed
- Changed functionality description [#124]

### Fixed
- Bug fix description [#125]

### Removed
- Removed feature description [#126]
```

## Release Process

This project uses automated releases:

1. **Merge to main** - Changes are merged via pull request
2. **Version calculation** - GitVersion automatically determines version based on commit messages
3. **CI/CD pipeline** - [GitHub Actions](.github/workflows/ci-cd.yml) builds, tests, and packages
4. **Automatic release** - On successful build, creates GitHub release and publishes to PowerShell Gallery

### Manual Release Steps (if needed)

1. **Update version** in [GitVersion.yml](GitVersion.yml) if needed
2. **Update changelog** with release notes
3. **Create release tag** following semantic versioning
4. **GitHub Actions pipeline** will handle the rest

## Getting Help

If you need help:

1. **Check existing issues** - Your question might already be answered
2. **Search documentation** - Look through README and wiki
3. **Ask in discussions** - Use GitHub Discussions for questions
4. **Contact maintainers** - For sensitive issues

---

*This contributing guide is part of the LeastPrivilegedMSGraph project*
