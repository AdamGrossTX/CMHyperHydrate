#TODO Add params to this function to allow customizing what we need. CreateVHDX, CreateFolders, ETC, ReUseSwitch
function New-LabEnv {
[cmdletbinding()]
    param (
        [Parameter()]
        [String]
        $ConfigFileName
    )
    
    $OriginalPref = $ProgressPreference # Default is 'Continue'
    $ProgressPreference = "SilentlyContinue"

    try {
    Write-Host "Starting Lab Build" -ForegroundColor Yellow

    $ModulePath = $script:PSCommandPath
    $Config = Get-LabConfig -ConfigFileName $ConfigFileName -CreateFolders

    if ($Config.BaseConfig.ServerRef.RefVHDXName -and -not $Config.BaseConfig.SvrVHDX) {
        New-LabUnattendXML -BaseConfig $Config.BaseConfig -LabEnvConfig $Config.LabEnvConfig
        $Config.BaseConfig.SvrVHDX = New-LabRefVHDX -BuildType Server -BaseConfig $Config.BaseConfig
    }
    if ($Config.BaseConfig.WorkstationRef.RefVHDXName -and -not $Config.BaseConfig.WksVHDX) {
        New-LabUnattendXML -BaseConfig $Config.BaseConfig -LabEnvConfig $Config.LabEnvConfig
        $Config.BaseConfig.WksVHDX = New-LabRefVHDX -BuildType Workstation -BaseConfig $Config.BaseConfig
    }

    <#New-LabSwitch -LabEnvConfig $Config.LabEnvConfig#>
    
    Write-Host "Starting Batch Job to Create VMs." -ForegroundColor Cyan
    Write-Host " - No status will be returned while VMs are being created. Please wait." -ForegroundColor Cyan
    Write-Host " - Logs can be viewed in $($BaseConfig.LabPath)$($BaseConfig.VMScriptPath)\<VMNAME>\<VMName>.log" -ForegroundColor Cyan
    $ServerJob = $Config.LabEnvConfig.ServerVMs | ForEach-Object -AsJob -ThrottleLimit 5 -Parallel {
        Import-Module $using:ModulePath -Force
        Write-Host "Creating New VM: $($_.VMName)" -ForegroundColor Cyan
        $ConfigSplat = @{
            VMConfig = $_ 
            BaseConfig = $Using:Config.BaseConfig
            LabEnvConfig = $Using:Config.LabEnvConfig
        }

        New-LabVM @ConfigSplat | Out-Null
    }

    $ServerJob | Wait-Job | Receive-Job

    $WorkstationJob = $Config.LabEnvConfig.WorkstationVMs | ForEach-Object -AsJob -ThrottleLimit 5 -Parallel {
        Import-Module $using:ModulePath -Force
        Write-Host "Creating New VM: $($_.VMName)" -ForegroundColor Cyan
        $ConfigSplat = @{
            VMConfig = $_ 
            BaseConfig = $Using:Config.BaseConfig
            LabEnvConfig = $Using:Config.LabEnvConfig
        }

        New-LabVM @ConfigSplat | Out-Null
    }

    $WorkstationJob | Wait-Job | Receive-Job


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
                    Add-LabAdditionalApps @ConfigSplat -AppList @("sql-server-management-studio","vscode","snagit")
                    Break
                 }
                 Default {Write-Host "No Role Found"; Break;}
            }
        }
    }

    Write-Host "New lab build Finished." -ForegroundColor Cyan
    (Get-date).DateTime

}
catch {
    throw $_

}
finally {
    $ProgressPreference = $OriginalPref
}

}