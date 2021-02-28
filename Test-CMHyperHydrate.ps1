
Import-Module "$($PSScriptRoot)\CMHyperHydrate.psm1" -Force

$ConfigFileName = "$($PSScriptRoot)\NewEnv.CMCB_CPC.json"

New-LabEnv -ConfigFileName $ConfigFileName -verbose