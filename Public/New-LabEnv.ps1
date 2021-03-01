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

    New-LabSwitch -LabEnvConfig $Script:LabEnv
    
    $ModulePath = $script:PSCommandPath
    $BaseConfig = $Script:Base
    $LabEnvConfig = $Script:LabEnv

    Write-Host "Starting Batch Job to Create VMs." -ForegroundColor Cyan
    Write-Host " - No status will be returned while VMs are being created. Please wait." -ForegroundColor Cyan
    $Job = $Script:SvrVMs | ForEach-Object -AsJob -ThrottleLimit 5 -Parallel {
        Import-Module $Using:ModulePath -Force
        $Script:LabEnv = $using:LabEnvConfig
        $Script:Base = $using:BaseConfig
        Write-Host "Creating New VM: $($_.VMName)" -ForegroundColor Cyan
        $ConfigSplat = @{
            VMConfig = $_ 
            BaseConfig = $Using:BaseConfig
            LabEnvConfig = $Using:LabEnvConfig
        }

        New-LabVM @ConfigSplat
    }

    $job | Wait-Job | Receive-Job

    foreach ($VM in $Script:SvrVMs) {
        Write-Host "Installing Roles for: $($VM.VMName)" 
        foreach($role in $VM.VMRoles.Split(",")) {
            $ConfigSplat = @{
                VMConfig = $VM 
                BaseConfig = $Script:Base 
                LabEnvConfig = $Script:LabEnv
            }
    
            Write-Host "  - Found Role $($role) for $($VM.VMName)" -ForegroundColor Cyan
            Switch($role) {
                "RRAS" {
                    Add-LabRoleRRAS @ConfigSplat
                    break
                }
                "DC" {
                    Update-LabRRAS @ConfigSplat
                    Add-LabRoleDC @ConfigSplat
                    break
                }
                "CA" {
                    Join-LabDomain @ConfigSplat
                    Add-LabRoleCA @ConfigSplat
                    Break
                }
                "SQL" {
                    Join-LabDomain @ConfigSplat
                    Add-LabRoleSQL @ConfigSplat
                    #Add-LabAdditionalApps @ConfigSplat -AppList @("sql-server-management-studio")
                    Break
                }
                "CM" {
                    Join-LabDomain @ConfigSplat
                    Add-LabRoleCM @ConfigSplat
                    #Add-LabAdditionalApps @ConfigSplat -AppList @("vscode","snagit")
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


Write-Host "New lab build Finished." -ForegroundColor Cyan
Get-date

}