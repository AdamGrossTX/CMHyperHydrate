function New-LabVM {
[cmdletbinding()]
param (
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $ENVName,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $VMName,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $VMWinName,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $ReferenceVHDX,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $VMPath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $VMHDPath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $VMHDName,

    [Parameter()]
    [UInt64]
    [ValidateNotNullOrEmpty()]
    [ValidateRange(512MB, 64TB)]
    $StartupMemory,

    [Parameter()]
    [int]
    $ProcessorCount,

    [ValidateNotNullOrEmpty()]
    [int]
    $Generation,

    [Parameter()]
    [switch]
    $EnableSnapshot,
    
    [Parameter()]
    [switch]
    $StartUp,

    [Parameter()]
    [string]
    $DomainName,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $IPAddress,
    
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $SwitchName,
    
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [int]
    $VLanID,

    [Parameter()]
    [pscredential]
    $LocalAdminCreds
)

    Write-Host "Starting New-LabVM" -ForegroundColor Cyan
    
    If (Get-VM -Name $VMName -ErrorAction SilentlyContinue) {
        Write-Host "VM Already Exists. Skipping Creating VM."
    }
    else {
        $SBResizeRenameComputer = {
            param ($Name)
            $MaxSize = (Get-PartitionSupportedSize -DriveLetter c).sizeMax
            Resize-Partition -DriveLetter c -Size $MaxSize
            Rename-Computer -NewName "$($Name)";
            Restart-Computer -Force;
        }

        if (-not (Test-Path "$($VMHDPath)\$($VMHDName)" -ErrorAction SilentlyContinue)) {
            New-Item -Path $VMHDPath -ItemType Directory
            Copy-Item -Path $ReferenceVHDX -Destination "$($VMHDPath)\$($VMHDName)"
        }
        
        if (-not (Get-VM -Name $VMName -ErrorAction SilentlyContinue)) {
            $VM = New-VM -Name $VMName -MemoryStartupBytes $StartupMemory -VHDPath "$($VMHDPath)\$($VMHDName)" -Generation $Generation -Path $VMPath
            if ($EnableSnapshot) {
                Set-VM -VM $VM -checkpointtype Production
            }
        }

        Resize-VHD -Path "$($VMHDPath)\$($VMHDName)" -SizeBytes 150gb
        Enable-VMIntegrationService -VMName $VMName -Name "Guest Service Interface"
        Set-VM -name $VMName -checkpointtype Disabled -ProcessorCount $ProcessorCount
        $Adapter = Get-VMNetworkAdapter -VMName $VMName 
        $Adapter | Connect-VMNetworkAdapter -SwitchName $SwitchName
        $Adapter | Set-VMNetworkAdapterVlan -VlanId $VLanID -Access

        if ($VMState -eq "Off") {
            write-Host "VM Not Running. Starting VM."
            Start-VM -Name $VMName
            start-sleep -Seconds 30
        }

        $VM = Get-VM -Name $VMName
        Invoke-LabCommand -SessionType Local -ScriptBlock $SBResizeRenameComputer -MessageText "SBResizeRenameComputer" -ArgumentList $VMWinName -VMID $VM.VMID
        start-sleep -Seconds 60
    }
}