@{
    PSDependTarget              = './output/RequiredModules'
    Scope                       = 'CurrentUser'
    Gallery                     = 'PSGallery'
    AllowOldPowerShellGetModule = $true
    AllowPrerelease             = $false
    WithYAML                    = $true

    # Use stable PowerShellGet for CI/CD reliability
    UsePSResourceGet            = $false
    UseModuleFast               = $false
}
