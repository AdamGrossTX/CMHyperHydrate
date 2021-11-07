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
        $BuildType

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
                VhdPath      =  Join-Path -Path $BaseConfig.PathRefImage -ChildPath $BaseConfig.WorkstationRef.RefVHDXName
                SizeBytes    = [uint64]($BaseConfig.WorkstationRef.RefHVDSize/1)
                UnattendPath = Join-Path -Path $BaseConfig.VMPath -ChildPath "Unattend.xml"
                Feature = if (-not ([string]::IsNullOrEmpty($BaseConfig.WorkstationRef.RefFeature))) {$BaseConfig.WorkstationRef.RefFeature} else {$null}
            }
        }
        default {$null; break;}
    }

    if (-not (Test-Path -Path $params.VhdPath -ErrorAction SilentlyContinue)) {
        Convert-LabISOToVHDX @Params
    }

    if(Test-Path $params.VhdPath) {
        Write-Host "$($MyInvocation.MyCommand) Complete!" -ForegroundColor Cyan
        Return $params.VhdPath
    }
    else {
        Throw "Failed to create VHDX."
    }
}