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
        $NewVMSplat = @{
            ENVName = $Script:labEnv.Env
            VMName = $VM.VMName
            VMWinName =$VM.VMWinName
            ReferenceVHDX = $Script:base.SvrVHDX
            VMPath = $script:base.VMPath
            VMHDPath =$VM.VMHDPath
            VMHDName = $VM.VMHDName
            StartupMemory = $VM.StartupMemory
            ProcessorCount = $VM.ProcessorCount
            Generation = $VM.Generation
            EnableSnapshot = $VM.EnableSnapshot
            StartUp = $VM.AutoStartup
            DomainName = $Script:labEnv.EnvFQDN
            IPAddress = $VM.VMIPAddress
            SwitchName = $Script:labEnv.EnvSwitchName
            VLanID = $Script:labEnv.VLanID
            LocalAdminCreds = $Script:base.LocalAdminCreds
        }

        Write-Host "Creating New VM: $($VM.VMName)" -ForegroundColor Cyan
        New-LabVM @NewVMSplat
    }

    foreach ($VM in $Script:SvrVMs) {
        Write-Host "Installing Roles for: $($VM.VMName)" 
        foreach($role in $VM.VMRoles.Split(",")) {
            Write-Host "  - Found Role $($role) for $($VM.VMName)" -ForegroundColor Cyan
            Switch($role) {
                "RRAS" {
                    #Add-LabRoleRRAS -VMName $VM.VMName
                    break
                }
                "DC" {
                    #Update-LabRRAS
                    #Add-LabRoleDC -VMName $VM.VMName
                    break
                }
                "CA" {
                    #Join-LabDomain -VMName $VM.VMName
                    #Add-LabRoleCA -VMName $VM.VMName
                    Break
                }
                "SQL" {
                    #Join-LabDomain -VMName $VM.VMName
                    #Add-LabRoleSQL -VMName $VM.VMName
                    #Add-LabAdditionalApps -VMConfig $VM -BaseConfig $Script:Base -LabEnvConfig $Script:LabEnv -AppList @("sql-server-management-studio")
                    Break
                }
                "CM" {
                    #Join-LabDomain -VMName $VM.VMName
                    Add-LabRoleCM -VMConfig $VM -BaseConfig $Script:Base -LabEnvConfig $Script:LabEnv -verbose
                    #Add-LabAdditionalApps -VMConfig $VM -BaseConfig $Script:Base -LabEnvConfig $Script:LabEnv -AppList @("vscode","snagit")
                    Break
                 }
                 Default {Write-Host "No Role Found"; Break;}
            }
        }
    }

<#
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
#>

}