
Import-Module "$($PSScriptRoot)\CMHyperHydrate.psm1" -Force

$ConfigFileName = "$($PSScriptRoot)\NewEnv.ASDLabTP1.json"

New-LabEnv -ConfigFileName $ConfigFileName -verbose