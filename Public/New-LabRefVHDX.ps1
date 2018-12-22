
Function New-LabRefVHDX {
    [cmdletbinding(DefaultParameterSetName="Config")]
    param(
        [Parameter(ParameterSetName="Config")]
        [ValidateNotNullOrEmpty()]
        [switch]$UseConfig,

        [Parameter(ParameterSetName="Config")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("Server","Workstation")]
        [string]$RefConfig,

        [Parameter(ParameterSetName="SRC", Mandatory=$true, ValueFromPipeline=$true)]
        [Alias("WIM")]
        [string]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $(Resolve-Path $_) })]
        $SourcePath,

        [Parameter(ParameterSetName="SRC")]
        [switch]
        $CacheSource = $false,

        [Parameter(ParameterSetName="SRC")]
        [Alias("SKU")]
        [string[]]
        [ValidateNotNullOrEmpty()]
        $Edition,

        [Parameter(ParameterSetName="SRC")]
        [Alias("WorkDir")]
        [string]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $_ })]
        $WorkingDirectory = $pwd,

        [Parameter(ParameterSetName="SRC")]
        [Alias("TempDir")]
        [string]
        [ValidateNotNullOrEmpty()]
        $TempDirectory = $env:Temp,

        [Parameter(ParameterSetName="SRC")]
        [Alias("VHD")]
        [string]
        [ValidateNotNullOrEmpty()]
        $VHDPath,

        [Parameter(ParameterSetName="SRC")]
        [Alias("Size")]
        [UInt64]
        [ValidateNotNullOrEmpty()]
        [ValidateRange(512MB, 64TB)]
        $SizeBytes = 25GB,

        [Parameter(ParameterSetName="SRC")]
        [Alias("Format")]
        [string]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("VHD", "VHDX", "AUTO")]
        $VHDFormat = "VHDX",

        [Parameter(ParameterSetName="SRC")]
        [Alias("MergeFolder")]
        [string]
        [ValidateNotNullOrEmpty()]
        $MergeFolderPath = "",

        [Parameter(ParameterSetName="SRC", Mandatory=$true)]
        [Alias("Layout")]
        [string]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("BIOS", "UEFI", "WindowsToGo")]
        $DiskLayout,

        [Parameter(ParameterSetName="SRC")]
        [string]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("NativeBoot", "VirtualMachine")]
        $BCDinVHD = "VirtualMachine",

        [Parameter(ParameterSetName="SRC")]
        [Parameter(ParameterSetName="UI")]
        [string]
        $BCDBoot = "bcdboot.exe",

        [Parameter(ParameterSetName="SRC")]
        [Parameter(ParameterSetName="UI")]
        [string]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("None", "Serial", "1394", "USB", "Local", "Network")]
        $EnableDebugger = "None",

        [Parameter(ParameterSetName="SRC")]
        [string[]]
        [ValidateNotNullOrEmpty()]
        $Feature,

        [Parameter(ParameterSetName="SRC")]
        [string[]]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $(Resolve-Path $_) })]
        $Driver,

        [Parameter(ParameterSetName="SRC")]
        [string[]]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $(Resolve-Path $_) })]
        $Package,

        [Parameter(ParameterSetName="SRC")]
        [switch]
        $ExpandOnNativeBoot = $true,

        [Parameter(ParameterSetName="SRC")]
        [switch]
        $RemoteDesktopEnable = $false,

        [Parameter(ParameterSetName="SRC")]
        [Alias("Unattend")]
        [string]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $(Resolve-Path $_) })]
        $UnattendPath,

        [Parameter(ParameterSetName="SRC")]
        [Parameter(ParameterSetName="UI")]
        [switch]
        $Passthru,

        [Parameter(ParameterSetName="SRC")]
        [string]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $(Resolve-Path $_) })]
        $DismPath,

        [Parameter(ParameterSetName="SRC")]
        [switch]
        $ApplyEA = $false,

        [Parameter(ParameterSetName="UI")]
        [switch]
        $ShowUI
    )
    If($UseConfig) {
        Switch($RefConfig) {
            "Server" {
                switch($Script:SvrRef.RefSrcType)
                {
                    "ISO" {$SourcePath = "$($Script:base.PathRefImage)\$($Script:base.Server2016ISO)"; break;}
                    "WIM" {$SourcePath = "$($Script:base.PathRefImage)\$($Script:base.Server2016WIM)";break;}
                    default {$SourcePath = "$($Script:base.PathRefImage)\$($Script:base.Server2016ISO)";break;}
                };
                $Edition = $Script:SvrRef.RefIndex;
                [UInt64]$SizeBytes = $Script:SvrRef.RefHVDSize -as [UInt64];
                $Feature = $Script:SvrRef.RefFeature;
                $Driver = $Script:SvrRef.RefDriver;
                $Package = $Script:SvrRef.RefPackage;
                $DiskLayout = "UEFI";
                $VHDFormat = "VHDX";
                $VHDPath = "$($script:PathRefImage)\$($Script:SvrRef.RefVHDXName)"
                $UnattendPath = "$($script:base.LabPath)\$($Script:base.ENVToBuild)";
                break;
            }
            "Worksation" {
                switch($Script:WSRef.RefSrcType)
                {
                    "ISO" {$SourcePath = "$($Script:base.PathRefImage)\$($Script:base.Windows10ISO)"; break;}
                    "WIM" {$SourcePath = "$($Script:base.PathRefImage)\$($Script:base.Windows10WIM)";break;}
                    default {$SourcePath = "$($Script:base.PathRefImage)\$($Script:base.Windows10ISO)";break;}
                };
                $Edition = $Script:SvrRef.RefIndex;
                [UInt64]$SizeBytes = $Script:WSRef.RefHVDSize -as [UInt64];
                $Feature = $Script:WSRef.RefFeature;
                $Driver = $Script:WSRef.RefDriver;
                $Package = $Script:WSRef.RefPackage;
                $DiskLayout = "UEFI";
                $VHDFormat = "VHDX";
                $VHDPath = "$($script:PathRefImage)\$($Script:WSRef.RefVHDXName)";
                $UnattendPath;
                break;
            }
            default {$null; break;}
        }
        
        $CacheSource = $false
        $WorkingDirectory = $pwd
        $TempDirectory = $env:Temp
        $MergeFolderPath = ""
        $BCDinVHD = "VirtualMachine"
        $BCDBoot = "bcdboot.exe"
        $EnableDebugger = "None"
        $ExpandOnNativeBoot = $true
        $RemoteDesktopEnable = $true
        $Passthru
        $DismPath
        $ApplyEA = $false
        $ShowUI
    }

    
    if(!(Test-Path -Path $VHDPath)) {
        #region Import Convert-WindowsImage Module
        if ((Get-Module -ListAvailable -Name 'Convert-WindowsImage').count -ne 1) {
            Install-Module -name 'Convert-WindowsImage' -Scope AllUsers
        }
        else {
            Update-Module -Name 'Convert-WindowsImage'    
        }
        Import-module -name 'Convert-Windowsimage'
        #end region


        try {
            Convert-WindowsImage @PSBoundParameters
        }
        Catch {
            #Throw $Error[0]
        }
        

        
    }

}

