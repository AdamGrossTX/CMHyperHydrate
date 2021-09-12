$Manifest = @{
    Path = '.\CMHyperHydrate.psd1'
    RootModule = 'CMHyperHydrate.psm1'
    Author = 'Adam Gross (@AdamGrossTX) & Steven Hosking (@OnPremCloudGuy)'
    CompanyName = 'A Square Dozen'
    ModuleVersion = '2.0'
    functionsToExport = @()
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    DscResourcesToExport = @()
}

New-ModuleManifest @Manifest