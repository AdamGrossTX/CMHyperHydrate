
Import-Module .\CMHyperHydrate.psm1 -Force

#$ConfigFileName = ".\NewEnv.json"
#$ConfigFileName = ".\NewEnv.CMTP2.json"
$ConfigFileName = ".\NewEnv.CMTP3.json"

New-LabEnv -ConfigFileName $ConfigFileName