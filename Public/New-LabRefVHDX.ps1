function New-LabRefVHDX {
    [cmdletbinding()]
    param (

        [Parameter()]
        [hashtable]
        $BaseConfig,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("Server","Workstation")]
        [string]
        $BuildType="Server"

    )

    Write-Host "Starting $($MyInvocation.MyCommand)" -ForegroundColor Cyan

    $params = Switch($BuildType) {
        "Server" {
            @{
                SourcePath  =  switch($BaseConfig.ServerRef.RefSrcType)
                                {
                                    "ISO" {$BaseConfig.SvrISO; break;}
                                    "WIM" {$BaseConfig.SvrWim;break;}
                                    default {$BaseConfig.SvrISO;break;}
                                }
                Edition      = $BaseConfig.ServerRef.RefIndex
                VhdPath      = Join-Path -Path $BaseConfig.PathRefImage -ChildPath $BaseConfig.ServerRef.RefVHDXName
                SizeBytes    = [uint64]($BaseConfig.ServerRef.RefHVDSize/1)
                UnattendPath = Join-Path -Path $BaseConfig.VMPath -ChildPath "Unattend.xml"
                VhdType      = "Dynamic"
                VhdFormat    = "VHDX"
                DiskLayout   = "UEFI"
                Feature = if (-not ([string]::IsNullOrEmpty($BaseConfig.ServerRef.RefFeature))) {$BaseConfig.ServerRef.RefFeature} else {$null}
            }
        }
        "Workstation" {
            @{
                SourcePath  =  switch($BaseConfig.WorkstationRef.RefSrcType)
                                {
                                    "ISO" {$BaseConfig.WksISO; break;}
                                    "WIM" {$BaseConfig.WksWim;break;}
                                    default {$BaseConfig.WksISO;break;}
                                }
                Edition      = $BaseConfig.WorkstationRef.RefIndex
                VhdPath      =  Join-Path -Path $BaseConfig.PathRefImage -ChildPath $BaseConfig.ServerRef.RefVHDXName
                SizeBytes    = [uint64]($BaseConfig.WorkstationRef.RefHVDSize/1)
                UnattendPath = Join-Path -Path $BaseConfig.VMPath -ChildPath "Unattend.xml"
                VhdType      = "Dynamic"
                VhdFormat    = "VHDX"
                DiskLayout   = "UEFI"
                Feature = if (-not ([string]::IsNullOrEmpty($BaseConfig.WorkstationRef.RefFeature))) {$BaseConfig.WorkstationRef.RefFeature} else {$null}
            }
        }
        default {$null; break;}
    }

    if (-not (Test-Path -Path $params.VhdPath -ErrorAction SilentlyContinue)) {
        $module = Get-Module -ListAvailable -Name 'Hyper-ConvertImage'
        if ($module.count -lt 1) {
            Install-Module -Name 'Hyper-ConvertImage'
            $module = Get-Module -ListAvailable -Name 'Hyper-ConvertImage'
        }
        #Hyper-ConvertImage doesn't play nice with PowerShell 7 so we need to force it to use Powershell 5 with the -UseWindowsPowerShell parameter
        if ($PSVersionTable.PSVersion.Major -eq 7) {
            Import-Module -Name (Split-Path $module.ModuleBase -Parent) -UseWindowsPowerShell -ErrorAction SilentlyContinue 3>$null
        }
        else {
            Import-Module -Name 'Hyper-ConvertImage'
        }
        Convert-WindowsImage @Params
    }

    if(Test-Path $params.VhdPath) {
        Write-Host "$($MyInvocation.MyCommand) Complete!" -ForegroundColor Cyan
        Return $params.VhdPath
    }
    else {
        Throw "Failed to create VHDX."
    }
}

