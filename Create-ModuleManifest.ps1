$Manifest = @{
    Path = '.\CMHyperHydrate.psd1'
    RootModule = 'CMHyperHydrate.psm1'
    Author = 'Adam Gross (@AdamGrossTX) & Steven Hosking (@OnPremCloudGuy)'
    ModuleVersion = '1.0'
    FunctionsToExport = @()
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    DscResourcesToExport = @()
}

New-ModuleManifest @Manifest