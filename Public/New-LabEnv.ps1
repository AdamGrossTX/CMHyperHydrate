Function New-LabEnv {
    Param (
        [Parameter()]
        [String]
        $ConfigFileName
    )
    Get-LabConfig -ConfigFileName $ConfigFileName -CreateFolders
    New-LabSwitch
    New-LabUnattendXML
    New-LabRefVHDX -BuildType "Server"
  

    ForEach ($VM in $Script:SvrVMs)
    {
        $Script:VMConfig = @{}
        ($VM[0]).psobject.properties | ForEach-Object {$VMConfig[$_.Name] = $_.Value}
        $VMConfig["SvrVHDX"] = $script:base["SvrVHDX"]
        $VMConfig["VMIPAddress"] = "$($script:env["EnvIPSubnet"])$($script:VMConfig.VMIPLastOctet)"
        $VMConfig["VMName"] = "$($script:env.Env)-$($script:VMConfig.VMName)"
        $VMConfig["VMHDPath"] = "$($script:base.VMPath)\$($script:VMConfig.VMName)\Virtual Hard Disks"
        $VMConfig["VMHDName"] = "$($script:VMConfig.VMName)c.vhdx"
        $VMConfig["EnableSnapshot"] = If($Script:VMConfig.EnableSnapshot -eq 1) {$true} else {$false}
        $VMConfig["AutoStartup"] = If($Script:VMConfig.AutoStartup -eq 1) {$true} else {$false}
        $VMConfig["StartupMemory"] = $Script:VMConfig.StartupMemory -as [UInt64]

        Write-Host $VM.VMName
        #New-LabVM
        $Roles = $VM.VMRoles.Split(",")
        If($Roles.Contains("DC"))
        {
            Add-LabDCRole
        }
        If($Roles.Contains("SQL"))
        {
            Add-LabSQLRole
        }
        If($Roles.Contains("CM"))
        {
            $VMConfig["ConfigMgrMediaPath"] = Switch($Script:VMConfig.CMVersion) {"TP" {$base.PathConfigMgrTP; break;} "CB" {$base.PathConfigMgrCB; break;}}
            $VMConfig["ConfigMgrPrereqPath"] = "$($Script:VMConfig.ConfigMgrMediaPath)\Prereqs"
            Add-LabCMRole
        }
        If($Roles.Contains("AP"))
        {
            #Add-LabAPRole
        }
        If($Roles.Contains("RRAS"))
        {
            #Add-LabRRASRole
        }
    }
}