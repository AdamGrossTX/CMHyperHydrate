#TODO Add params to this function to allow customizing what we need. CreateVHDX, CreateFolders, ETC, ReUseSwitch
function New-LabEnv {
[cmdletbinding()]
    param (
        [Parameter()]
        [String]
        $ConfigFileName
    )
    
    Write-Host "Starting Lab Build" -ForegroundColor Yellow

    $ModulePath = $script:PSCommandPath
    $Config = Get-LabConfig -ConfigFileName $ConfigFileName -CreateFolders

    if ($Config.BaseConfig.ServerRef.RefVHDXName -and -not $Base.SvrVHDX) {
        New-LabUnattendXML -BaseConfig $Config.BaseConfig -LabEnvConfig $Config.LabEnvConfig
        New-LabRefVHDX -BuildType Server -BaseConfig $Config.BaseConfig
    }
    if ($Config.BaseConfig.WorkstationRef.RefVHDXName -and -not $Base.WksVHDX) {
        New-LabUnattendXML -BaseConfig $Config.BaseConfig -LabEnvConfig $Config.LabEnvConfig
        New-LabRefVHDX -BuildType Workstation -BaseConfig $Config.BaseConfig
    }

    New-LabSwitch -LabEnvConfig $Config.LabEnvConfig
    
    Write-Host "Starting Batch Job to Create VMs." -ForegroundColor Cyan
    Write-Host " - No status will be returned while VMs are being created. Please wait." -ForegroundColor Cyan
    $Job = $Config.LabEnvConfig.ServerVMs | ForEach-Object -AsJob -ThrottleLimit 5 -Parallel {
        Import-Module $using:ModulePath -Force
        $Config = $using:Config
        Write-Host "Creating New VM: $($_.VMName)" -ForegroundColor Cyan
        $ConfigSplat = @{
            VMConfig = $_ 
            BaseConfig = $Config.BaseConfig
            LabEnvConfig = $Config.LabEnvConfig
        }

        New-LabVM @ConfigSplat | Out-Null
    }

    $job | Wait-Job | Receive-Job

    foreach ($VM in $Config.LabEnvConfig.ServerVMs) {
        Write-Host "Installing Roles for: $($VM.VMName)" 
        $VMRoles = $VM.VMRoles.Split(",")
        foreach($role in $VMRoles) {
            $ConfigSplat = @{
                VMConfig = $VM 
                BaseConfig = $Config.BaseConfig 
                LabEnvConfig = $Config.LabEnvConfig
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
                    Add-LabAdditionalApps @ConfigSplat -AppList @("sql-server-management-studio")
                    Break
                }
                "CM" {
                    Join-LabDomain @ConfigSplat
                    Add-LabRoleCM @ConfigSplat
                    Add-LabAdditionalApps @ConfigSplat -AppList @("vscode","snagit")
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
        $VMConfig["WksVHDX"] = $Config.BaseConfig["WksVHDX"]
        $VMConfig["VMIPAddress"] = "$($Config.LabEnvConfig["EnvIPSubnet"])$($script:VMConfig.VMIPLastOctet)"
        $VMConfig["VMWinName"] = "$($script:VMConfig.VMName)"
        $VMConfig["VMName"] = "$($Config.LabEnvConfig.Env)-$($script:VMConfig.VMName)"
        $VMConfig["VMHDPath"] = "$($Config.BaseConfig.VMPath)\$($script:VMConfig.VMName)\Virtual Hard Disks"
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