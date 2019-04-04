
#requires -version 4.0
#requires -runasadministrator

<#
.SYNOPSIS
Convert a WIM file to VHD(x)

.DESCRIPTION
Given a source WIM image will auto Create the VHD(x) file.

.LINK
http://ps2wiz.codeplex.com

.NOTES
Copyright Microsoft, all rights resevered.
Portions copyright Keith Garner (PS2Wiz.codeplex.com)

#>

[CmdletBinding()]
Param(
    [parameter(Mandatory=$true)]
    [string] $ImagePath,
    [parameter(Mandatory=$true)]
    [string] $VHDFile,
    [parameter(Mandatory=$true,ParameterSetName="Index")]
    [int]    $Index,
    [switch] $GPT,
    [uint64]  $SizeBytes = 120GB
)

#region Support Routines
######################################################################

Function start-CommandHidden  {

<# 
.SYNOPSIS
Run a Console program Hidden and capture the output.

.PARAMETER
FilePath - Program Executable

.PARAMETER
ArgumentList - Array of arguments

.PARAMETER
RedirectStandardInput - text file for StdIn

.NOTES
Will output StdOut to Verbose.
#>

    param
    (
        [string] $FilePath,
        [string[]] $ArgumentList,
        [string] $RedirectStandardInput
    )

    $StartArg = @{
        RedirectStandardError = [System.IO.Path]::GetTempFileName()
        RedirectStandardOutput = [System.IO.Path]::GetTempFileName()
        PassThru = $True
    }

    $StartArg | out-string |  write-verbose
    $ArgumentList | out-string |write-verbose

    $prog = start-process -WindowStyle Hidden @StartArg @PSBoundParameters

    $Prog.WaitForExit()

    get-content $StartArg.RedirectStandardOutput | Write-Output
    get-content $StartArg.RedirectStandardError  | Write-Error

    $StartArg.RedirectStandardError, $StartArg.RedirectStandardOutput, $RedirectStandardInput | Remove-Item -ErrorAction SilentlyContinue

}

function Invoke-DiskPart
{
    <#
    Invoke diskpart commands ( passed as a string array )
    #>
    
    param( [string[]] $Commands )

    $Commands | out-string | write-verbose
    $DiskPartCmd = [System.IO.Path]::GetTempFileName()
    $Commands | out-file -encoding ascii -FilePath $DiskPartCmd
    start-CommandHidden -FilePath "DiskPart.exe" -RedirectStandardInput $DiskPartCmd
}


function Format-NewDisk {
    <# 
    Foramt a disk for Windows 10.
    Windows 10 does not use Recovery Partitions, just WinRE
    #>

    param
    (
        [parameter(Mandatory=$true)]
        [ValidateRange(1,20)]
        [int] $DiskID,

        [switch] $GPT,
        [switch] $System = $True,
        [switch] $WinRE = $True
    )

    ################
    write-verbose "Clear the disk($DiskID)"
    Get-Disk -Number $DiskID | where-object PartitionStyle -ne 'RAW' | Clear-Disk -RemoveData -RemoveOEM -Confirm:$False

    if ( get-Disk -Number $DiskID | where-object PartitionStyle -eq 'RAW' ) {
        write-verbose "Initialize the disk($DiskID)"
        if ($GPT) {
            initialize-disk -Number $DiskID -PartitionStyle GPT -Confirm:$true
        }
        else {
            initialize-disk -Number $DiskID -PartitionStyle MBR -Confirm:$true
        }
    }

    ################
    $WinREPartition = $null
    if ( $WinRE ) {
        write-verbose "Create Windows RE tools partition of 350MB"
        $WinREPartition = New-Partition -DiskNumber $DiskID -Size 350MB -AssignDriveLetter:$False | 
            Format-Volume -FileSystem NTFS -NewFileSystemLabel 'Windows RE Tools' -Confirm:$False |
            Get-Partition 
        if ( $GPT ) {
            Invoke-DiskPart -Commands @("list disk","Select Disk $($WinREPartition.diskNumber)","Select Partition $($WinREPartition.PartitionNumber)","set ID=de94bba4-06d1-4d40-a16a-bfd50179d6ac","Detail Part","Exit" ) | write-verbose
            # $WinREPartition | Set-Partition -GptType '{de94bba4-06d1-4d40-a16a-bfd50179d6ac}' -ErrorAction SilentlyContinue
        }
    }

    ################
    $SystemPartition = $null
    if ( $GPT -or $System ) {
        write-verbose "Create System Partition of 350MB"
        $SystemPartition = New-Partition -DiskNumber $DiskID -Size 350MB -AssignDriveLetter:$false | 
            Format-Volume -FileSystem FAT32 -NewFileSystemLabel 'System' -Confirm:$False | 
            Get-Partition | 
            Add-PartitionAccessPath -AssignDriveLetter -PassThru
    }

    ################
    if ( $GPT ) {
        write-Verbose "Create MSR partition of 128MB"
        New-Partition -DiskNumber $DiskID -GptType '{e3c9e316-0b5c-4db8-817d-f92df00215ae}' -Size 128MB -ErrorAction SilentlyContinue | Out-Null
    }

    ################
    write-verbose "Create Windows Partition (MAX)"
    $WindowsPartition = New-Partition -DiskNumber $DiskID -UseMaximumSize -AssignDriveLetter:$False |
        Format-Volume -FileSystem NTFS -NewFileSystemLabel 'Windows' -Confirm:$False |
        Get-Partition |
        Add-PartitionAccessPath -AssignDriveLetter -PassThru

    ################
    if ( -not $SystemPartition ) {
        write-verbose "Let System Partition be the Windows Partition"
        $SystemPartition = $WindowsPartition
    }
    if ( -not $GPT ) {
        write-verbose "Set the System partition active"
        $SystemPartition | Set-Partition -IsActive:$true
    }

    @{
        SystemPartition = $SystemPartition 
        WindowsPartition = $WindowsPartition 
        WinREPartition = $WinREPartition
    } | Write-Output

}

Function Format-NewDiskFinalize {
    <# 
    Finalize partitions for Windows 10

    Powershell will remove all drive letters from a disk if you hide *any* partition
    Powershell will remove all drive letters from a disk if you mark the system partition 

    #>
    [cmdletbinding()]
    param
    (
        $SystemPartition,
        $WindowsPartition,
        $WinREPartition
    )

    ################

    if ($WinREPartition) {
        $WinREPartition | 
            where-object MBRType -eq 7 |
            Set-Partition -IsHidden:$True
    }

    if ( $SystemPartition ) {
        $SystemPartition | 
            where-object GPTType -eq '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}' |
            ForEach-Object { 
                Invoke-DiskPart -Commands @("list disk","Select Disk $($_.diskNumber)","Select Partition $($_.PartitionNumber)","set ID=c12a7328-f81f-11d2-ba4b-00a0c93ec93b","Detail Part","Exit" ) | write-verbose
            }
    }

}

#endregion

#region Main

$ErrorActionPreference = 'stop'

Write-Verbose "WIM [$ImagePath]  to VHD [$VHDFile]"
Write-Verbose "SizeBytes=$SIzeBytes  Generation:$Generation Force: $Force Index: $Index"

New-VHD -Path $VHDFile -SizeBytes $SizeBytes | out-null

$NewDisk = Mount-VHD -Passthru -Path $VHDFile
$NewDisk | Out-String | Write-Verbose
$NewDiskNumber = Get-VHD $VhdFile | Select-Object -ExpandProperty DiskNumber
if ( -not  $NewDiskNumber ) { throw "Unable to Mount VHD File" }

Write-Verbose "Initialize Disk  $NewDiskNumber"

$ReadyDisk = Format-NewDisk -DiskID $NEwDiskNumber -GPT:$GPT
$ApplyPath = $ReadyDisk.WindowsPartition | get-Volume | Foreach-object { $_.DriveLetter + ":" }
$ApplySys = $ReadyDisk.SystemPartition | Get-Volume | Foreach-object { $_.DriveLetter + ":" }

write-verbose "Expand-WindowsImage Path [$ApplyPath] and System: [$ApplySys]"

write-verbose "Get WIM image information for $ImagePath"
get-windowsimage -ImagePath $ImagePath | out-string | write-verbose
Get-WindowsImage -ImagePath $ImagePath | %{ Get-WindowsImage -ImagePath $ImagePath -index $_.ImageIndex } | write-verbose

$ApplyArgs = @{
    LogPath = [System.IO.Path]::GetTempFileName()
    ImagePath = $ImagePath
    Index = $Index
    ApplyPath = "$ApplyPath\"
    }

$ApplyArgs | Out-String | Write-verbose
write-Host "Expand-WindowsImage Path [$ApplyPath]"
Expand-WindowsImage @ApplyArgs | Out-String | Write-Verbose

########################################################

Write-Verbose "$ApplyPath\Windows\System32\bcdboot.exe $ApplyPath\Windows /s $ApplySys /v"

if ( -not $GPT ) {
    $BCDBootArgs = "$ApplyPath\Windows","/s","$ApplySys","/v","/F","BIOS"
}
else {
    $BCDBootArgs = "$ApplyPath\Windows","/s","$ApplySys","/v","/F","UEFI"
}

# http://www.codeease.com/create-a-windows-to-go-usb-drive-without-running-windows-8.html
Copy-Item $ApplyPath\Windows\System32\bcdboot.exe $env:temp\BCDBoot.exe

start-CommandHidden -FilePath $env:temp\BCDBoot.exe -ArgumentList $BCDBootArgs | write-verbose

Write-Verbose "Finalize Disk"
Format-NewDiskFinalize @ReadyDisk

write-verbose "Convert-WIMtoVHD FInished"

Dismount-VHD -Path $VhdFile

#endregion
