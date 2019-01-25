Import-Module .\CMHyperHydrate.psm1 -Force

#$ConfigFileName = ".\NewEnv.json"
$ConfigFileName = ".\NewEnv.CMTP2.json"

New-LabEnv -ConfigFileName $ConfigFileName