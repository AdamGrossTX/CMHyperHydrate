Function New-LabRefVHDX {
    [cmdletbinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("Server","Workstation")]
        [string]$BuildType="Server",

        [Parameter()]
        [Alias("WIM")]
        [string]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $(Resolve-Path $_) })]
        $SourcePath,

        [Parameter()]
        [switch]
        $CacheSource = $false,

        [Parameter()]
        [Alias("SKU")]
        [string[]]
        [ValidateNotNullOrEmpty()]
        $Edition,

        [Parameter()]
        [Alias("WorkDir")]
        [string]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $_ })]
        $WorkingDirectory = $pwd,

        [Parameter()]
        [Alias("TempDir")]
        [string]
        [ValidateNotNullOrEmpty()]
        $TempDirectory = $env:Temp,

        [Parameter()]
        [Alias("VHD")]
        [string]
        [ValidateNotNullOrEmpty()]
        $VHDPath,

        [Parameter()]
        [Alias("Size")]
        [UInt64]
        [ValidateNotNullOrEmpty()]
        [ValidateRange(512MB, 64TB)]
        $SizeBytes = 25GB,

        [Parameter()]
        [Alias("Format")]
        [string]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("VHD", "VHDX", "AUTO")]
        $VHDFormat = "VHDX",

        [Parameter()]
        [Alias("MergeFolder")]
        [string]
        [ValidateNotNullOrEmpty()]
        $MergeFolderPath = "",

        [Parameter()]
        [Alias("Layout")]
        [string]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("BIOS", "UEFI", "WindowsToGo")]
        $DiskLayout="UEFI",

        [Parameter()]
        [string]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("NativeBoot", "VirtualMachine")]
        $BCDinVHD = "VirtualMachine",

        [Parameter()]
        [Parameter(ParameterSetName="UI")]
        [string]
        $BCDBoot = "bcdboot.exe",

        [Parameter()]
        [Parameter(ParameterSetName="UI")]
        [string]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("None", "Serial", "1394", "USB", "Local", "Network")]
        $EnableDebugger = "None",

        [Parameter()]
        [string[]]
        [ValidateNotNullOrEmpty()]
        $Feature,

        [Parameter()]
        [string[]]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $(Resolve-Path $_) })]
        $Driver,

        [Parameter()]
        [string[]]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $(Resolve-Path $_) })]
        $Package,

        [Parameter()]
        [switch]
        $ExpandOnNativeBoot = $true,

        [Parameter()]
        [switch]
        $RemoteDesktopEnable = $false,

        [Parameter()]
        [Alias("Unattend")]
        [string]
        #[ValidateNotNullOrEmpty()]
        #[ValidateScript({ Test-Path $(Resolve-Path $_) })]
        $UnattendPath,

        [Parameter()]
        [Parameter(ParameterSetName="UI")]
        [switch]
        $Passthru,

        [Parameter()]
        [string]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $(Resolve-Path $_) })]
        $DismPath,

        [Parameter()]
        [switch]
        $ApplyEA = $false,

        [Parameter(ParameterSetName="UI")]
        [switch]
        $ShowUI
    )



    function Get-ParameterValues {
        <#
            .Synopsis
                Get the actual values of parameters which have manually set (non-null) default values or values passed in the call
            .Description
                Unlike $PSBoundParameters, the hashtable returned from Get-ParameterValues includes non-empty default parameter values.
                NOTE: Default values that are the same as the implied values are ignored (e.g.: empty strings, zero numbers, nulls).
            .Link
                https://gist.github.com/Jaykul/72f30dce2cca55e8cd73e97670db0b09/
            .Link
                https://gist.github.com/elovelan/d697882b99d24f1b637c7e7a97f721f2/
            .Example
                function Test-Parameters {
                    [CmdletBinding()]
                    param(
                        $Name = $Env:UserName,
                        $Age
                    )
                    $Parameters = Get-ParameterValues
                    # This WILL ALWAYS have a value... 
                    Write-Host $Parameters["Name"]
                    # But this will NOT always have a value... 
                    Write-Host $PSBoundParameters["Name"]
                }
        #>
        [CmdletBinding()]
        param()
        # The $MyInvocation for the caller
        $Invocation = Get-Variable -Scope 1 -Name MyInvocation -ValueOnly
        # The $PSBoundParameters for the caller
        $BoundParameters = Get-Variable -Scope 1 -Name PSBoundParameters -ValueOnly
        
        $ParameterValues = @{}
        foreach($parameter in $Invocation.MyCommand.Parameters.GetEnumerator()) {
            # gm -in $parameter.Value | Out-Default
            try {
                $key = $parameter.Key
                if($null -ne ($value = Get-Variable -Name $key -ValueOnly -ErrorAction Ignore)) {
                    if($value -ne ($null -as $parameter.Value.ParameterType)) {
                        $ParameterValues[$key] = $value
                    }
                }
                #if($BoundParameters.ContainsKey($key)) {
                #    $ParameterValues[$key] = $BoundParameters[$key]
                #}
            } finally {}
        }
        $ParameterValues
      }

        Switch($BuildType) {
            "Server" {
                switch($Script:SvrRef.RefSrcType)
                {
                    "ISO" {$SourcePath = $Script:base.SvrISO; break;}
                    "WIM" {$SourcePath = $Script:base.SvrWim;break;}
                    default {$SourcePath = $Script:base.SvrISO;break;}
                };
                $Edition = $Script:SvrRef.RefIndex;
                [UInt64]$SizeBytes = $Script:SvrRef.RefHVDSize -as [UInt64];
                If(!([string]::IsNullOrEmpty($Script:SvrRef.RefFeature))) {$Feature = $Script:SvrRef.RefFeature;}
                If(!([string]::IsNullOrEmpty($Script:SvrRef.RefDriver))) {$Driver = $Script:base.PathDrivers;}
                If(!([string]::IsNullOrEmpty($Script:SvrRef.RefPackage))) {$Package = $Script:base.PathPackages;}
                $DiskLayout = "UEFI";
                $VHDFormat = "VHDX";
                $VHDPath = "$($script:Base.SvrVHDX)"
                $UnattendPath = "$($script:base.LabPath)\$($Script:base.ENVToBuild)\Unattend.XML";
                break;
            }
            "Workstation" {
                switch($Script:WSRef.RefSrcType)
                {
                    "ISO" {$SourcePath = $Script:base.WinISO; break;}
                    "WIM" {$SourcePath = $Script:base.WinWIM;break;}
                    default {$SourcePath = $Script:base.WinISO;break;}
                };
                $Edition = $Script:SvrRef.RefIndex;
                [UInt64]$SizeBytes = $Script:WSRef.RefHVDSize -as [UInt64];
                If(!([string]::IsNullOrEmpty($Script:WksRef.RefFeature))) {$Feature = $Script:WSRef.RefFeature;}
                If(!([string]::IsNullOrEmpty($Script:WksRef.RefDriver))) {$Driver = $Script:base.PathDrivers;}
                If(!([string]::IsNullOrEmpty($Script:WksRef.RefPackage))) {$Package = $Script:base.PathPackages;}
                $DiskLayout = "UEFI";
                $VHDFormat = "VHDX";
                $VHDPath = "$($script:Base.WksVHDX)";
                $UnattendPath = $Null#"$($script:base.LabPath)\$($Script:base.ENVToBuild)\Unattend.XML";
                break;
            }
            default {$null; break;}
        }
        
        $CacheSource = $false
        $TempDirectory = $env:Temp
        $BCDinVHD = "VirtualMachine"
        $BCDBoot = "bcdboot.exe"
        $EnableDebugger = "None"
        $ExpandOnNativeBoot = $true
        $RemoteDesktopEnable = $true
        $Passthru
        $DismPath
        $ApplyEA = $false
        $ShowUI
    

    
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

        $Params = Get-ParameterValues
        $Params.Remove("BuildType")
        Convert-WindowsImage @Params
        
    }

}

