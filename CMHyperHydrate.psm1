#Imports all PS1 files from the Public and Private folders to create the module.

$Public  = @( Get-ChildItem -Path .\Public\*.ps1 -Recurse )
$Private = @( Get-ChildItem -Path .\Private\*.ps1 -Recurse)
foreach ($import in @($Public + $Private)) {
    . $import.fullname
}