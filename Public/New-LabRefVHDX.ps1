
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


    If($UseConfig) {
        Switch($RefConfig) {
            "Server" {
                switch($Script:SvrRef.RefSrcType)
                {
                    "ISO" {$SourcePath = $Script:base.Server2016ISO; break;}
                    "WIM" {$SourcePath = $Script:base.Server2016WIM;break;}
                    default {$SourcePath = $Script:base.Server2016ISO;break;}
                };
                $Edition = $Script:SvrRef.RefIndex;
                [UInt64]$SizeBytes = $Script:SvrRef.RefHVDSize -as [UInt64];
                If(!([string]::IsNullOrEmpty($Script:SvrRef.RefFeature))) {$Feature = $Script:SvrRef.RefFeature;}
                If(!([string]::IsNullOrEmpty($Script:base.PathDrivers))) {$Driver = $Script:base.PathDrivers;}
                If(!([string]::IsNullOrEmpty($Script:base.PathPackages))) {$Package = $Script:base.PathPackages;}
                $DiskLayout = "UEFI";
                $VHDFormat = "VHDX";
                $VHDPath = "$($script:Base.Svr2016VHDX)"
                $UnattendPath = "$($script:base.LabPath)\$($Script:base.ENVToBuild)\Unattend.XML";
                break;
            }
            "Worksation" {
                switch($Script:WSRef.RefSrcType)
                {
                    "ISO" {$SourcePath = $Script:base.Windows10ISO; break;}
                    "WIM" {$SourcePath = $Script:base.Windows10WIM;break;}
                    default {$SourcePath = $Script:base.Windows10ISO;break;}
                };
                $Edition = $Script:SvrRef.RefIndex;
                [UInt64]$SizeBytes = $Script:WSRef.RefHVDSize -as [UInt64];
                If(!([string]::IsNullOrEmpty($Script:WSRef.RefFeature))) {$Feature = $Script:WSRef.RefFeature;}
                If(!([string]::IsNullOrEmpty($Script:base.PathDrivers))) {$Driver = $Script:base.PathDrivers;}
                If(!([string]::IsNullOrEmpty($Script:base.PathPackages))) {$Package = $Script:base.PathPackages;}
                $DiskLayout = "UEFI";
                $VHDFormat = "VHDX";
                $VHDPath = "$($script:Base.Win10VHDX)";
                $UnattendPath = "$($script:base.LabPath)\$($Script:base.ENVToBuild)\Unattend.XML";
                break;
            }
            default {$null; break;}
        }
        
        $CacheSource = $false
        $WorkingDirectory = $pwd
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


        #try {
            $SourcePath

            $Params = Get-ParameterValues
            
            $Params

            #$PSBoundParameters
            $Params.Remove('UseConfig')
            $Params.Remove('RefConfig')

            $Params

            $SourcePath

            Convert-WindowsImage @Params
        #}
        #Catch {
            #Throw $Error[0]
        #}
        

        
    }

}

