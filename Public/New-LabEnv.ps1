#TODO Add params to this function to allow customizing what we need. CreateVHDX, CreateFolders, ETC, ReUseSwitch
function New-LabEnv {
[cmdletbinding()]
    param (
        [Parameter()]
        [String]
        $ConfigFileName
    )
    
    Get-LabConfig -ConfigFileName $ConfigFileName -CreateFolders
    if ($SvrRef.RefVHDXName -and -not $Base.SvrVHDX) {
        New-LabUnattendXML
        New-LabRefVHDX -BuildType Server
    }
    if ($wksRef.RefVHDXName -and -not $Base.wksVHDX) {
        New-LabUnattendXML
        New-LabRefVHDX -BuildType Workstation
    }

    New-LabSwitch -RemoveExisting

    foreach ($VM in $Script:SvrVMs) {
        $Script:VMConfig = @{}
        ($VM[0]).psobject.properties | foreach-Object {$VMConfig[$_.Name] = $_.Value}
        $VMConfig["SvrVHDX"] = $script:base["SvrVHDX"]
        $VMConfig["VMIPAddress"] = "$($Script:labEnv["EnvIPSubnet"])$($script:VMConfig.VMIPLastOctet)"
        $VMConfig["VMWinName"] = "$($script:VMConfig.VMName)"
        $VMConfig["VMName"] = "$($Script:labEnv.Env)-$($script:VMConfig.VMName)"
        $VMConfig["VMHDPath"] = "$($script:base.VMPath)\$($script:VMConfig.VMName)\Virtual Hard Disks"
        $VMConfig["VMHDName"] = "$($script:VMConfig.VMName)c.vhdx"
        $VMConfig["EnableSnapshot"] = if ($Script:VMConfig.EnableSnapshot -eq 1) {$true} else {$false}
        $VMConfig["AutoStartup"] = if ($Script:VMConfig.AutoStartup -eq 1) {$true} else {$false}
        $VMConfig["StartupMemory"] = [int64]$Script:VMConfig.StartupMemory.Replace('gb','') * 1GB

        Write-Host "Creating New VM: $($VM.VMName)"

        New-LabVM

        $Roles = $VM.VMRoles.Split(",")
        if ($Roles.Contains("DC")) {
            Add-LabRoleDC
        }
        
        if (-not $Roles.Contains("DC")) {
           Join-LabDomain
        }

        if ($Roles.Contains("CA")) {
            Add-LabRoleCA
        }

        if ($Roles.Contains("SQL")) {
            Add-LabRoleSQL
        }
        
        if ($Roles.Contains("CM")) {
           $VMConfig["ConfigMgrMediaPath"] = Switch($Script:VMConfig.CMVersion) {"TP" {$base.PathConfigMgrTP; break;} "Prod" {$base.PathConfigMgrCB; break;}}
           $VMConfig["ConfigMgrPrereqPath"] = "$($Script:VMConfig.ConfigMgrMediaPath)\Prereqs"
           Add-LabRoleCM
           Add-LabAdditionalApps
        }
        if ($Roles.Contains("AP"))
        {
            #Add-LabAPRole
        }
        if ($Roles.Contains("RRAS"))
        {
            #Add-LabRRASRole
        }

        
    }

    foreach ($VM in $Script:WksVMs) {
        $Script:VMConfig = @{}
        ($VM[0]).psobject.properties | foreach-Object {$VMConfig[$_.Name] = $_.Value}
        $VMConfig["WksVHDX"] = $script:base["WksVHDX"]
        $VMConfig["VMIPAddress"] = "$($Script:labEnv["EnvIPSubnet"])$($script:VMConfig.VMIPLastOctet)"
        $VMConfig["VMWinName"] = "$($script:VMConfig.VMName)"
        $VMConfig["VMName"] = "$($Script:labEnv.Env)-$($script:VMConfig.VMName)"
        $VMConfig["VMHDPath"] = "$($script:base.VMPath)\$($script:VMConfig.VMName)\Virtual Hard Disks"
        $VMConfig["VMHDName"] = "$($script:VMConfig.VMName)c.vhdx"
        $VMConfig["EnableSnapshot"] = if ($Script:VMConfig.EnableSnapshot -eq 1) {$true} else {$false}
        $VMConfig["AutoStartup"] = if ($Script:VMConfig.AutoStartup -eq 1) {$true} else {$false}
        $VMConfig["StartupMemory"] = [int64]$Script:VMConfig.StartupMemory.Replace('gb','') * 1GB

        Write-Host $VM.VMName
        New-LabVM
    }


}