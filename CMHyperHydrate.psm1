#Imports all PS1 files from the Public and Private folders to create the module.

$Public  = @( Get-ChildItem -Path C:\Lab\CMHyperHydrate\Public\*.ps1 -Recurse )
$Private = @( Get-ChildItem -Path C:\Lab\CMHyperHydrate\Private\*.ps1 -Recurse)
Foreach($import in @($Public + $Private)) {
    . $import.fullname
}