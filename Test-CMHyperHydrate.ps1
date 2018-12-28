Import-Module .\CMHyperHydrate.psm1 -Force

$ConfigFileName = ".\NewEnv.json"

New-LabEnv -ConfigFileName $ConfigFileName