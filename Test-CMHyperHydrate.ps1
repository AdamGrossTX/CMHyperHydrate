
Import-Module "$($PSScriptRoot)\CMHyperHydrate.psm1" -Force

$ConfigFileName = "$($PSScriptRoot)\NewEnv.CMCB06.json"

New-LabEnv -ConfigFileName $ConfigFileName

