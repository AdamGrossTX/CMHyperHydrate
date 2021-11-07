
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
        $ReferenceVHDX = $VMConfig.VHDX,
    
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
        $StartupMemory = ($VMConfig.StartupMemory /1),

        [Parameter()]
        [UInt64]
        $HDDSize = ($VMConfig.VMHDDSize / 1),
    
        [Parameter()]
        [int]
        $ProcessorCount = $VMConfig.ProcessorCount,
    
        [Parameter()]
        [switch]
        $EnableSnapshot = $VMConfig.EnableSnapshot,
        
        [Parameter()]
        [switch]
        $StartUp = $VMConfig.AutoStartup,
    
        [Parameter()]
        [int]
        $UseUnattend = $VMConfig.UseUnattend,

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
        $LocalAdminCreds = $BaseConfig.LocalAdminCreds,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ScriptPath = $BaseConfig.VMScriptPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $LogPath = $BaseConfig.VMLogPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $LabPath = $BaseConfig.LabPath
    
    )

    #Setting these to avoiding needing to pass in creds with each lab connection test
    $Script:LocalAdminCreds = $BaseConfig.LocalAdminCreds
    $Script:DomainAdminCreds = $BaseConfig.DomainAdminCreds
    
    #region Standard Setup
    $LabScriptPath = "$($LabPath)$($ScriptPath)\$($VMName)"
    $ClientScriptPath = "$($ClientDriveRoot)$($ScriptPath)"
    if (-not (Test-Path -Path "$($LabScriptPath)")) {
        New-Item -Path "$($LabScriptPath)" -ItemType Directory -ErrorAction SilentlyContinue
    }

    Start-Transcript -Path "$($LabScriptPath)\$($VMName).log" -Force -ErrorAction SilentlyContinue | Out-Null
    Write-Host "Starting $($MyInvocation.MyCommand)" -ForegroundColor Cyan
    Write-Host "BaseConfig: $($BaseConfig)"
    Write-Host "ReferenceVHDX: $($ReferenceVHDX)"

    $LogPath = "$($ClientDriveRoot)$($LogPath)"
    $SBDefaultParams = @"
    param
    (
        `$_LogPath = "$($LogPath)"
    )
"@

    $SBScriptTemplateBegin = {
        if (-not (Test-Path -Path $_LogPath -ErrorAction SilentlyContinue)) {
            New-Item -Path $_LogPath -ItemType Directory -ErrorAction SilentlyContinue;
        }
        
        $_LogFile = "$($_LogPath)\Transcript.log";
        
        Start-Transcript $_LogFile -Append -IncludeInvocationHeader | Out-Null;
        Write-Output "Logging to $_LogFile";
        
        #region Do Stuff Here
    }
        
    $SBScriptTemplateEnd = {
        #endregion
        Stop-Transcript | Out-Null
    }
    
    #endregion

    #$Password = ConvertTo-SecureString -String $LabEnvConfig.EnvAdminPW -AsPlainText -Force
    #$LocalAdminCreds = new-object -typename System.Management.Automation.PSCredential($BaseConfig.LocalAdminName, $Password)

    if (Get-VM -Name $VMName -ErrorAction SilentlyContinue) {
        Write-Host "VM Already Exists. Skipping Creating VM."
    }
    else {
    #region Script Blocks

    $SBResizeRenameComputerParams = @"
    param
    (
        `$_LogPath = "$($LogPath)",
        `$_VMWinName = "$($VMWinName)"
    )
"@
        $SBResizeRenameComputer = {
            #Disable IE Enhanced Security and UAC
            $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
            $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
            Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
            Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
            Stop-Process -Name Explorer -Erroraction SilentlyContinue
            Write-Host "IE Enhanced Security Configuration (ESC) has been disabled."
            Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 00000000
            Set-ItemProperty -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ServerManager -Name DoNotOpenServerManagerAtLogon -Type DWord -Value 1 -Force
            Write-Host "User Access Control (UAC) has been disabled."
            
            $MaxSize = (Get-PartitionSupportedSize -DriveLetter c).SizeMax
            $CurrentSize = (Get-Disk).AllocatedSize
            if($CurrentSize -lt $MaxSize) {
                Resize-Partition -DriveLetter c -Size $MaxSize
            }
            Rename-Computer -NewName "$($_VMWinName)";
        }

        $ResizeRenameComputer += $SBResizeRenameComputerParams
        $ResizeRenameComputer += $SBScriptTemplateBegin.ToString()
        $ResizeRenameComputer += $SBResizeRenameComputer.ToString()
        $ResizeRenameComputer += $SBScriptTemplateEnd.ToString()
        $ResizeRenameComputer | Out-File "$($LabScriptPath)\ResizeRenameComputer.ps1"
        $Scripts = Get-Item -Path "$($LabScriptPath)\*.*" -Exclude "*.log"
    #endregion

        if (-not (Test-Path "$($VMHDPath)\$($VMHDName)" -ErrorAction SilentlyContinue)) {
            New-Item -Path $VMHDPath -ItemType Directory
            Copy-Item -Path $ReferenceVHDX -Destination "$($VMHDPath)\$($VMHDName)"
            if($UseUnattend -eq 1) {
                $UnattendPath = "$($BaseConfig.VMPath)\unattend.xml"
                if($UnattendPath) {
                    if(Test-Path -Path $UnattendPath) {
                        $Disk = (Mount-VHD -Path "$($VMHDPath)\$($VMHDName)" -Passthru | Get-Disk | Get-Partition | Where-Object {$_.type -eq 'Basic'}).DriveLetter
                        Copy-Item -Path $UnattendPath -Destination "$($Disk):\Unattend.XML" -ErrorAction Continue
                        Dismount-VHD "$($VMHDPath)\$($VMHDName)"
                    }
                }
            }
        }

        $VM = Get-VM -Name $VMName -ErrorAction SilentlyContinue
        if (-not $VM) {
            $VM = New-VM -Name $VMName -MemoryStartupBytes $StartupMemory -VHDPath "$($VMHDPath)\$($VMHDName)" -Generation 2 -Path $VMPath
            if ($EnableSnapshot) {
                Set-VM -VM $VM -checkpointtype Production -AutomaticCheckpointsEnabled $False
            }
        }

        if(-not $HDDSize) {$HDDSize = 150gb /1 }
        if(($VM.VMId | Get-VHD).Size -lt $HDDSize ) {
            Resize-VHD -Path "$($VMHDPath)\$($VMHDName)" -SizeBytes $HDDSize
        }
        Enable-VMIntegrationService -VMName $VMName -Name "Guest Service Interface"
        Set-VM -name $VMName -checkpointtype Disabled -ProcessorCount $ProcessorCount
        $Adapter = Get-VMNetworkAdapter -VMName $VMName 
        $Adapter | Connect-VMNetworkAdapter -SwitchName $SwitchName
        $Adapter | Set-VMNetworkAdapterVlan -VlanId $VLanID -Access

        if ($VM.State -eq "Off") {
            write-Host "VM Not Running. Starting VM."
            Start-VM -Name $VMName  -WarningAction SilentlyContinue
            Start-Sleep -Seconds 120
        }

        Write-Host $LabEnvConfig.EnvAdminPW
        Write-Host $BaseConfig.LocalAdminName

        while (-not (Invoke-Command -VMName $VMName -Credential $LocalAdminCreds {Get-Process "LogonUI" -ErrorAction SilentlyContinue;})) {Start-Sleep -seconds 5}
        foreach ($Script in $Scripts) {
            Copy-VMFile -VM $VM -SourcePath $Script.FullName -DestinationPath "$($ClientScriptPath)\$($Script.Name)" -CreateFullPath -FileSource Host -Force
        }

        Invoke-LabCommand -FilePath "$($LabScriptPath)\ResizeRenameComputer.ps1" -MessageText "ResizeRenameComputer" -SessionType Local -VMID $VM.VMId
        $VMName | Restart-VM -Force -ErrorAction SilentlyContinue
        start-sleep -Seconds 120
    }
    Write-Host "$($MyInvocation.MyCommand) Complete!" -ForegroundColor Cyan
    
    Stop-Transcript | Out-Null
}