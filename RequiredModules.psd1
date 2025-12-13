@{
    <#
        This is only required if you need to use the method PowerShellGet & PSDepend
        It is not required for PSResourceGet or ModuleFast (and will be ignored).
        See Resolve-Dependency.psd1 on how to enable methods.
    #>
    PSDependOptions     = @{
        AddToPath  = $true
        Target     = 'output/RequiredModules'  # Match the PSDependTarget
        Parameters = @{
            Repository = 'PSGallery'
        }
    }

    InvokeBuild         = 'latest'
    PSScriptAnalyzer    = 'latest'
    Pester              = 'latest'
    ModuleBuilder       = 'latest'
    ChangelogManagement = 'latest'
    Sampler             = 'latest'
    PlatyPS             = 'latest'
    EntraAuth           = 'latest'
    PSFramework         = 'latest'
}
