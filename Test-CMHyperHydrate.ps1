Import-Module .\CMHyperHydrate.psm1 -Force

$ConfigFileName = ".\NewEnv.json"

Get-LabConfig -ConfigFileName $ConfigFileName -CreateFolders
#New-LabEnv -SwitchName $Base.ENVToBuild
#New-LabUnattendXML -UseEnvConfig
New-LabRefVHDX -UseConfig -RefConfig "Server"

#ForEach ($VM in $VMList)
#{
#    $VMConfig = @{}
#    ($VM).psobject.properties | ForEach-Object {$VMConfig[$_.Name] = $_.Value}
#}

#}

#.\Private\New-Folders
#.\Private\New-LabUnattendXML.ps1 -OutputFile "$($Global:VMPath)\unattend.xml"
#.\Private\New-LabRefVHDX.ps1 -SourcePath $Global:Server2016ISO -Edition $Config.Server2016Index -VhdPath $Global:Svr2016VHDX -UnattendPath "$($VMPath)\unattend.xml" -DiskLayout "UEFI" -Feature "NetFx3" -Package $NET35CABPath -VHDFormat "VHDX"
#New-LabRefVHDX -SourceVHDX $Global:Svr2016VHDX -CoreNumber $Config.Server2016Index -ISOPath $Global:Server2016ISO
#New-LabRefVHDX -SourceVHDX $Global:Win10VHDX -CoreNumber $Config.Windows1809Index -ISOPath $Global:Windows10ISO
#LabRefVHDX -VHDXPath $Win10VHDX -CoreNumber $Config.Windows1809Index -WinISO $Global:Windows10ISO
#.\Private\New-LabENV.ps1 -SwitchName $Config.ENV
#.\Private\New-LabVM.ps1 -EnvName $Config.ENV -VMName $envConfig.Server1.ServerName -ReferenceVHDX $Svr2016VHDX -VMPath $VMPath -StartupMemory 4gb -Generation 2 -EnableSnapshot:$False -StartUp:$False -SwitchName $Config.ENV
#.\Private\Add-LabDCRole.ps1 -VMName "$($Config.ENV)$($envConfig.Server1.ServerName)" -DomainFQDN $envConfig.DomainFQDN -DomainAdminCreds $DomainAdminCreds -LocalAdminCreds $LocalAdminCreds -IPLastOctet $envConfig.Server1.IPLastOctet -IPSubnet $envConfig.IPSubnet
#.\Private\Add-LabConfigMgrRole.ps1 -VMName "$($Config.ENV)$($envConfig.Server1.ServerName)" -DomainNetBIOSName $envConfig.DomainNetBiosName -SQLServiceAccount $DomainAdminName -SQLServiceAccountPassword $envConfig.AdminPW -ConfigMgrMedia $Global:SCCMTPPath -ADKMedia $Global:ADKPath -ADKWinPEMedia $Global:ADKWinPEPath -SQLISO $Global:SQLISO

#-DomainAdminCreds $DomainAdminCreds -LocalAdminCreds $LocalAdminCreds

#>