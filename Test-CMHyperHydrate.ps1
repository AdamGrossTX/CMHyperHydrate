
cd .\CMHyperHydrate
Import-Module "$($PSScriptRoot)\CMHyperHydrate.psm1" -Force

#$ConfigFileName = ".\NewEnv.json"
#$ConfigFileName = ".\NewEnv.CMTP2.json"
#$ConfigFileName = ".\NewEnv.CMTP3.json"
$ConfigFileName = "$($PSScriptRoot)\NewEnv.CMCB2.json"

New-LabEnv -ConfigFileName $ConfigFileName