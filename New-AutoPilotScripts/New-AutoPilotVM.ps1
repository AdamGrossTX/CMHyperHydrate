<#

    .SYNOPSIS

    .DESCRIPTION
        
    .NOTES

        Author: Bruce Sa

        Twitter: @BruceSaaaa
		
		Created: 12/11/2018

    .LINK
	
        https://docs.microsoft.com/en-us/windows/deployment/windows-autopilot/existing-devices
		https://docs.microsoft.com/en-us/intune/enrollment-autopilot
		https://blogs.technet.microsoft.com/mniehaus/2018/10/25/speeding-up-windows-autopilot-for-existing-devices/
		
    .EXAMPLE
        
    .HISTORY  
		#Version 1.0 Added parameter $VMName MANDATORY
Version 1.1 Removed mandatory parameter and added support to create a VM by hard coding a name, or using the next number available.
		Create VM using the basename "Test-"  Will create "Test-1" or whatever number is next in line
		.\New-AutoPilotVM-GEN2.ps1 -BaseName Test-

		Create VM using using default "$BaseName" Will create "AutoPilot-1" or whatever number is next in line
		.\New-AutoPilotVM-GEN2.ps1
		Create VM with a specific name "AzureTst1"
		.\New-AutoPilotVM-GEN2.ps1 -VMName AzureTst1

Version 1.2 Disabled Automatic Checkpoints "-AutomaticCheckpointsEnabled $false"

Version 1.3 Added AutoPilot Json. No need to manually enroll computer AutoPilot
	All the variables are on lines 38-48
    
#>


Param
(
[String]$VMName,
[String]$BaseName = "AutoPilot-",
[String]$RefVHD = "C:\Setup\VHDs\1809PROGen2.vhdx",
[String]$VMNetwork = "BSALabNAT",
[switch]$Json,
[switch]$CopyAutoPilotFiles,
[switch]$ExposeVirtualization
)

#Get Existing VMs
if(!($VMName)){
[array]$CurrentVms = (Get-Vm).name
[array]$VMNames = 1..99 |%{"$BaseName{0}" -f $_}
$VMName = (compare $CurrentVms $VMNames |select -first 1 ).inputobject
}

# Set VM Variables ***Please change the variables to match your environment.***
$VMLocation = "D:\VMs\Test-VMs"
$VMMemory = 2GB
$DiffDisk = "$VMLocation\$VMName\$VMName-OSDisk.vhdx"
$scriptPath = $PSScriptRoot

#Copy Files Locations
if ($CopyAutoPilotFiles)
{
    $Unattend = "$scriptPath\ConfigFiles\UnattendAutoPilot.xml"
    $SetupComplete = "$scriptPath\ConfigFiles\SetupComplete.cmd"
    $AutopilotProfile = "$scriptPath\ConfigFiles\AutopilotConfigurationFile.json"
    $GetInfo = "$scriptPath\ConfigFiles\Get-AutopilotInfo.ps1"
    $AutoInfo = "$scriptPath\ConfigFiles\Auto-Info.cmd"
}

#AutopilotProfile If profile does not exist it will create it for you.
if ($Json)
{
    if (!(Test-path -path $AutopilotProfile -ErrorAction SilentlyContinue)) {
	    If(!(Get-Module -Name WindowsAutoPilotIntune)) {
        Install-Module -Name WindowsAutoPilotIntune -Scope AllUsers -Force
	    }
    
        else {
            update-module -name WindowsAutoPilotIntune
        }
        import-module -name WindowsAutoPilotIntune
        Connect-AutoPilotIntune
        Get-AutoPilotProfile | ConvertTo-AutoPilotConfigurationJSON | Out-File $AutopilotProfile -Encoding ascii
    }
}
# Cleanup existing VM (if it exist)
$VM = Get-VM $VMName -ErrorAction Ignore
If ($VM.State -eq "Running") {Stop-VM $VM -Force}
If ($VM) {$VM | Remove-VM -Force}
If (Test-Path "$VMLocation\$VMName") { Remove-Item -Recurse "$VMLocation\$VMName" -Force}

# Create a new VM
New-VHD -Path $DiffDisk -ParentPath $RefVHD -differencing
Mount-DiskImage -ImagePath $DiffDisk
$VHDXDisk = Get-DiskImage -ImagePath $DiffDisk | Get-Disk
$VHDXDiskNumber = [string]$VHDXDisk.Number
$VHDXDrive = Get-Partition -DiskNumber $VHDXDiskNumber 
$GetVHDXVolume = [string]$VHDXDrive.DriveLetter+":"
$VHDXVolume = ($GetVHDXVolume -replace ('[^a-z,A-z]', '')) +":"

# Copy Config files
if ($CopyAutoPilotFiles)
{
    Copy-Item $AutoInfo "$VHDXVolume\Windows\system32\"
    Copy-Item $GetInfo "$VHDXVolume\Windows\system32\"
    Copy-Item $Unattend "$VHDXVolume\Windows\system32\Sysprep"
    New-Item -Path "$VHDXVolume\Windows\Setup\Scripts" -ItemType Directory
    #Copy-Item $SetupComplete "$VHDXVolume\Windows\Setup\Scripts"
    If (!(Test-Path "$VHDXVolume\Windows\Provisioning\Autopilot")){ New-Item -ItemType Directory -Path "$VHDXVolume\Windows\Provisioning\Autopilot" }
    Copy-Item $AutopilotProfile "$VHDXVolume\Windows\Provisioning\Autopilot\AutopilotConfigurationFile.json"
}

# Dismount the differencing disk
Dismount-DiskImage -ImagePath $DiffDisk

# Create Virtual machine
New-VM -Name $VMName -BootDevice VHD -Generation 2 -MemoryStartupBytes $VMMemory -SwitchName $VMNetwork -Path $VMLocation -VHDPath $DiffDisk -Verbose
Set-VMProcessor -VMName $VMName -Count 2

#Disable AutoCheckpoint
Set-VM $VMName -AutomaticCheckpointsEnabled $false

# Enable TPM
Set-VMKeyProtector -VMName $VMName -NewLocalKeyProtector
Enable-VMTPM -VMName $VMName

# Expose Virtualization
if ($ExposeVirtualization)
{   
    Set-VMProcessor -VMName $VMName -ExposeVirtualizationExtensions $true
}
# Start Virtual Machine
Start-VM -VMName $VMName

# Open Virtual Machine Console
VMConnect localhost $VMName