function Add-LabRoleRRAS {
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
        $VMName = $VMConfig.VMName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $InternetSwitchName = $LabEnvConfig.InternetSwitchName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $DomainFQDN = $LabEnvConfig.EnvFQDN,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [pscredential]
        $DomainAdminCreds = $BaseConfig.DomainAdminCreds,

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

    #region Standard Setup
    Write-Host "Starting $($MyInvocation.MyCommand)" -ForegroundColor Cyan
    $LabScriptPath = "$($LabPath)$($ScriptPath)\$($VMName)"
    $ClientScriptPath = "C:$($ScriptPath)"
    
    if (-not (Test-Path -Path "$($LabScriptPath)")) {
        New-Item -Path "$($LabScriptPath)" -ItemType Directory -ErrorAction SilentlyContinue
    }

    $LogPath = "C:$($LogPath)"
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
        Stop-Transcript
    }
    
    #endregion
        
    #region Script Blocks
    $SBInstallRRAS = {
        Install-WindowsFeature Routing,RSAT-RemoteAccess-Mgmt -IncludeManagementTools
        Get-NetAdapter -Physical -Name "Ethernet" | Rename-NetAdapter -newname "External"
        Install-RemoteAccess -VpnType RoutingOnly
        netsh routing ip nat install
        netsh routing ip nat add interface "External"
        netsh routing ip nat set interface "External" mode=full
        Set-LocalUser -Name "Administrator" -PasswordNeverExpires 1
        Set-ItemProperty -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ServerManager -Name DoNotOpenServerManagerAtLogon -Type DWord -Value 1 -Force
        Set-ItemProperty -Path Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\RemoteAccess\Parameters -Name ModernStackEnabled -Value 0 -Type DWord -Force
    }

    $InstallRRAS += $SBDefaultParams
    $InstallRRAS += $SBScriptTemplateBegin.ToString()
    $InstallRRAS += $SBInstallRRAS.ToString()
    $InstallRRAS += $SBScriptTemplateEnd.ToString()
    $InstallRRAS | Out-File "$($LabScriptPath)\InstallRRAS.ps1"
    
    $Scripts = Get-Item -Path "$($LabScriptPath)\*.*"

    #endregion

    $VM = Get-VM -VM $VMName
    $VM | Start-VM -WarningAction SilentlyContinue
    start-sleep 10

    while (-not (Invoke-Command -VMName $VMName -Credential $DomainAdminCreds {Get-Process "LogonUI" -ErrorAction SilentlyContinue;})) {Start-Sleep -seconds 5}
    
    foreach ($Script in $Scripts) {
        Copy-VMFile -VM $VM -SourcePath $Script.FullName -DestinationPath "$($ClientScriptPath)\$($Script.Name)" -CreateFullPath -FileSource Host -Force
    }

    $Adapter = Get-VMNetworkAdapter -VMName $VMName
    $Adapter | Connect-VMNetworkAdapter -SwitchName $InternetSwitchName
    $Adapter | Set-VMNetworkAdapter -DeviceNaming On
    $Adapter | Set-VMNetworkAdapterVlan -Untagged
    $Adapter | Rename-VMNetworkAdapter -NewName "Internet"

    Invoke-LabCommand -FilePath "$($LabScriptPath)\InstallRRAS.ps1" -MessageText "InstallRRAS" -SessionType Local -VMID $VM.VMId

    Write-Host "$($MyInvocation.MyCommand) Complete!" -ForegroundColor Cyan
}