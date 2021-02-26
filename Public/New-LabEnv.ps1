#TODO Add params to this function to allow customizing what we need. CreateVHDX, CreateFolders, ETC, ReUseSwitch
Function New-LabEnv {
[cmdletbinding()]
    Param (
        [Parameter()]
        [String]
        $ConfigFileName
    )
    Get-LabConfig -ConfigFileName $ConfigFileName -CreateFolders
   
    $Script:Base.ClientLogPath
    
    #Uncomment for first run
    #New-LabUnattendXML
    
    
    #New-LabRefVHDX -BuildType Server
    #New-LabRefVHDX -BuildType Workstation

    New-LabSwitch
    ForEach ($VM in $Script:SvrVMs) {
        $Script:VMConfig = @{}
        ($VM[0]).psobject.properties | ForEach-Object {$VMConfig[$_.Name] = $_.Value}
        $VMConfig["SvrVHDX"] = $script:base["SvrVHDX"]
        $VMConfig["VMIPAddress"] = "$($script:env["EnvIPSubnet"])$($script:VMConfig.VMIPLastOctet)"
        $VMConfig["VMWinName"] = "$($script:VMConfig.VMName)"
        $VMConfig["VMName"] = "$($script:env.Env)-$($script:VMConfig.VMName)"
        $VMConfig["VMHDPath"] = "$($script:base.VMPath)\$($script:VMConfig.VMName)\Virtual Hard Disks"
        $VMConfig["VMHDName"] = "$($script:VMConfig.VMName)c.vhdx"
        $VMConfig["EnableSnapshot"] = If($Script:VMConfig.EnableSnapshot -eq 1) {$true} else {$false}
        $VMConfig["AutoStartup"] = If($Script:VMConfig.AutoStartup -eq 1) {$true} else {$false}
        $VMConfig["StartupMemory"] = [int64]$Script:VMConfig.StartupMemory.Replace('gb','') * 1GB

        Write-Host "Creating New VM: $($VM.VMName)"
        
        $Roles = $VM.VMRoles.Split(",")
        If($Roles.Contains("DC")) {
            New-LabVM
            Add-LabDCRole
        }
        
        If(!$Roles.Contains("DC")) {
           Join-LabDomain
        }

        If($Roles.Contains("CA")) {
            Add-LabCARole
        }

        If($Roles.Contains("SQL")) {
            Add-LabSQLRole
        }
        
        If($Roles.Contains("CM")) {
           $VMConfig["ConfigMgrMediaPath"] = Switch($Script:VMConfig.CMVersion) {"TP" {$base.PathConfigMgrTP; break;} "Prod" {$base.PathConfigMgrCB; break;}}
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

        #Add-LabAdditionalApps
    }

    ForEach ($VM in $Script:WksVMs) {
        $Script:VMConfig = @{}
        ($VM[0]).psobject.properties | ForEach-Object {$VMConfig[$_.Name] = $_.Value}
        $VMConfig["WksVHDX"] = $script:base["WksVHDX"]
        $VMConfig["VMIPAddress"] = "$($script:env["EnvIPSubnet"])$($script:VMConfig.VMIPLastOctet)"
        $VMConfig["VMWinName"] = "$($script:VMConfig.VMName)"
        $VMConfig["VMName"] = "$($script:env.Env)-$($script:VMConfig.VMName)"
        $VMConfig["VMHDPath"] = "$($script:base.VMPath)\$($script:VMConfig.VMName)\Virtual Hard Disks"
        $VMConfig["VMHDName"] = "$($script:VMConfig.VMName)c.vhdx"
        $VMConfig["EnableSnapshot"] = If($Script:VMConfig.EnableSnapshot -eq 1) {$true} else {$false}
        $VMConfig["AutoStartup"] = If($Script:VMConfig.AutoStartup -eq 1) {$true} else {$false}
        $VMConfig["StartupMemory"] = [int64]$Script:VMConfig.StartupMemory.Replace('gb','') * 1GB

        Write-Host $VM.VMName
        New-LabVM
    }


}