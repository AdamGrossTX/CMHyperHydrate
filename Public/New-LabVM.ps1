Function New-LabVM {
[cmdletbinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $ENVName = $Script:Env.Env,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $VMName = $Script:VMConfig.VMName,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $ReferenceVHDX = $Script:base.SvrVHDX,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $VMPath = $script:base.VMPath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $VMHDPath = $Script:VMConfig.VMHDPath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $VMHDName = $Script:VMConfig.VMHDName,

    [Parameter()]
    [UInt64]
    [ValidateNotNullOrEmpty()]
    [ValidateRange(512MB, 64TB)]
    $StartupMemory = 16gb,
    #$Script:VMConfig.StartupMemory,

    [Parameter()]
    [int]
    $ProcessorCount = $Script:VMConfig.ProcessorCount,

    [ValidateNotNullOrEmpty()]
    [int]
    $Generation = $Script:VMConfig.Generation,

    [Parameter()]
    [switch]
    $EnableSnapshot = $Script:VMConfig.EnableSnapshot,
    
    [Parameter()]
    [switch]
    $StartUp = $Script:VMConfig.AutoStartup,

    [Parameter()]
    [string]
    $DomainName = $Script:Env.EnvFQDN,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $IPAddress = $Script:VMConfig.IPAddress,
    
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $SwitchName = $Script:Env.EnvSwitchName,

    [Parameter()]
    [pscredential]
    $LocalAdminCreds = $Script:base.LocalAdminCreds
    
)

##TODO##
##Add logic to join to a domain if not the domain controller and if set to join the domain (wouldn't do it for AutoPilot testing and such.)


    $SBResizeRenameComputer = {
        Param($Name)
        $MaxSize = (Get-PartitionSupportedSize -DriveLetter c).sizeMax
        Resize-Partition -DriveLetter c -Size $MaxSize
        Rename-Computer -NewName "$($Name)";
        Restart-Computer -Force;
    }

    If(!(Test-Path "$($VMHDPath)\$($VMHDName)" -ErrorAction SilentlyContinue)) {
        New-Item -Path $VMHDPath -ItemType Directory
        Copy-Item -Path $ReferenceVHDX -Destination "$($VMHDPath)\$($VMHDName)"
    }
    
    If(!(Get-VM -Name $VMName -ErrorAction SilentlyContinue)) {
        $VM = New-VM -Name $VMName -MemoryStartupBytes $StartupMemory -VHDPath "$($VMHDPath)\$($VMHDName)" -Generation $Generation -Path $VMPath
        If($EnableSnapshot) {
            Set-VM -VM $VM -checkpointtype Production
        }
    }
        Resize-VHD -Path "$($VMHDPath)\$($VMHDName)" -SizeBytes 150gb
        Enable-VMIntegrationService -VMName $VMName -Name "Guest Service Interface"
        Set-VM -name $VMName -checkpointtype Disabled -ProcessorCount $ProcessorCount
        Get-VMNetworkAdapter -VMName $VMName | Connect-VMNetworkAdapter -SwitchName $SwitchName
        if($VMState -eq "Off") {
            write-Host "VM Not Running. Starting VM."
            Start-VM -Name $VMName
            start-sleep -Seconds 30
        }

        $VM = Get-VM -Name $VMName
        Invoke-LabCommand -SessionType Local -ScriptBlock $SBResizeRenameComputer -MessageText "SBResizeRenameComputer" -ArgumentList $VMName -VMID $VM.VMID

        #Checkpoint-VM -VM $VM -SnapshotName "New VM Created"
}