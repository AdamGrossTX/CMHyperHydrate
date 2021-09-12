
function New-LabVM {
    [cmdletbinding()]
    param (

        [Parameter()]
        [PSCustomObject]
        $VMConfig,

        [Parameter()]
        [hashtable]
        $BaseConfig,

        [Parameter()]
        [hashtable]
        $LabEnvConfig,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ENVName = $LabEnvConfig.Env,
    
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $VMName = $VMConfig.VMName,
    
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $VMWinName = $VMConfig.VMWinName,
    
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ReferenceVHDX = $BaseConfig.SvrVHDX,
    
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $VMPath = $BaseConfig.VMPath,
    
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $VMHDPath = $VMConfig.VMHDPath,
    
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $VMHDName = $VMConfig.VMHDName,
    
        [Parameter()]
        [UInt64]
        [ValidateNotNullOrEmpty()]
        [ValidateRange(512MB, 64TB)]
        $StartupMemory = $VMConfig.StartupMemory,
    
        [Parameter()]
        [int]
        $ProcessorCount = $VMConfig.ProcessorCount,
    
        [ValidateNotNullOrEmpty()]
        [int]
        $Generation = $VMConfig.Generation,
    
        [Parameter()]
        [switch]
        $EnableSnapshot = $VMConfig.EnableSnapshot,
        
        [Parameter()]
        [switch]
        $StartUp = $VMConfig.AutoStartup,
    
        [Parameter()]
        [string]
        $DomainName = $LabEnvConfig.EnvFQDN,
    
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $IPAddress = $VMConfig.IPAddress,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $SwitchName = $LabEnvConfig.EnvSwitchName,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [int]
        $VLanID = $LabEnvConfig.VLanID,
    
        [Parameter()]
        [pscredential]
        $LocalAdminCreds = $BaseConfig.LocalAdminCreds
    
    )

    Write-Host "Starting $($MyInvocation.MyCommand)" -ForegroundColor Cyan

    $Password = ConvertTo-SecureString -String $LabEnvConfig.EnvAdminPW -AsPlainText -Force
    $LocalAdminCreds = new-object -typename System.Management.Automation.PSCredential($BaseConfig.LocalAdminName, $Password)

    if (Get-VM -Name $VMName -ErrorAction SilentlyContinue) {
        Write-Host "VM Already Exists. Skipping Creating VM."
    }
    else {
        $SBResizeRenameComputer = {
            param ($Name)
            #Disable IE Enhanced Security and UAC
            $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
            $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
            Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
            Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
            Stop-Process -Name Explorer -Erroraction SilentlyContinue
            Write-Output "IE Enhanced Security Configuration (ESC) has been disabled." -ForegroundColor Green
            Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 00000000
            Write-Output "User Access Control (UAC) has been disabled." -ForegroundColor Green    

            $MaxSize = (Get-PartitionSupportedSize -DriveLetter c).sizeMax
            Resize-Partition -DriveLetter c -Size $MaxSize
            Rename-Computer -NewName "$($Name)";
        }


        if (-not (Test-Path "$($VMHDPath)\$($VMHDName)" -ErrorAction SilentlyContinue)) {
            New-Item -Path $VMHDPath -ItemType Directory
            Copy-Item -Path $ReferenceVHDX -Destination "$($VMHDPath)\$($VMHDName)"
        }
        
        if (-not (Get-VM -Name $VMName -ErrorAction SilentlyContinue)) {
            $VM = New-VM -Name $VMName -MemoryStartupBytes $StartupMemory -VHDPath "$($VMHDPath)\$($VMHDName)" -Generation $Generation -Path $VMPath
            if ($EnableSnapshot) {
                Set-VM -VM $VM -checkpointtype Production -AutomaticCheckpointsEnabled $False
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
            Start-VM -Name $VMName  -WarningAction SilentlyContinue
            start-sleep -Seconds 120
        }

        $VM = Get-VM -Name $VMName
        Invoke-LabCommand -SessionType Local -ScriptBlock $SBResizeRenameComputer -MessageText "SBResizeRenameComputer" -ArgumentList $VMWinName -VMID $VM.VMID -LocalAdminCreds $LocalAdminCreds
        $VMName | Restart-VM -Force -WarningAction SilentlyContinue
        start-sleep -Seconds 120
    }
    Write-Host "$($MyInvocation.MyCommand) Complete!" -ForegroundColor Cyan
}