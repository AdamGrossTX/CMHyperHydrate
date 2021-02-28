function Add-LabRoleRRAS {
    [cmdletbinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $VMName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $InternetSwitchName = $Script:labEnv.InternetSwitchName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $DomainFQDN = $Script:labEnv.EnvFQDN,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [pscredential]
        $DomainAdminCreds = $Script:base.DomainAdminCreds,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ScriptPath = $Script:Base.VMScriptPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $LogPath = $Script:Base.VMLogPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $LabPath = $Script:Base.LabPath

    )

    #region Standard Setup
    Write-Host "Starting Add-LabRoleRRAS" -ForegroundColor Cyan
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
        
        Start-Transcript $_LogFile -Append -NoClobber;
        Write-Host "Logging to $_LogFile";
        
        #region Do Stuff Here
    }
        
    $SCScriptTemplateEnd = {
        #endregion
        Stop-Transcript
    }
    
    #endregion
        
    #region Script Blocks
    $SBInstallRRAS = {
        Install-WindowsFeature Routing -IncludeManagementTools
        Get-NetAdapter -Physical -Name "Ethernet" | Rename-NetAdapter -newname "External"
        Install-RemoteAccess -VpnType VPN
        netsh routing ip nat install
        netsh routing ip nat add interface "External"
        netsh routing ip nat set interface "External" mode=full
        Set-LocalUser -Name "Administrator" -PasswordNeverExpires 1
        Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\ServerManager -Name DoNotOpenServerManagerAtLogon -Type DWord -value "1" -Force
    }

    $InstallRRAS += $SBDefaultParams
    $InstallRRAS += $SBScriptTemplateBegin.ToString()
    $InstallRRAS += $SBInstallRRAS.ToString()
    $InstallRRAS += $SCScriptTemplateEnd.ToString()
    $InstallRRAS | Out-File "$($LabScriptPath)\InstallRRAS.ps1"
    
    $Scripts = Get-Item -Path "$($LabScriptPath)\*.*"

    #endregion

    $VM = Get-VM -VM $VMName
    $VM | Start-VM
    start-sleep 10

    while (-not (Invoke-Command -VMName $VMName -Credential $DomainAdminCreds {Get-Process "LogonUI" -ErrorAction SilentlyContinue;})) {Start-Sleep -seconds 5}
    
    foreach ($Script in $Scripts) {
        Copy-VMFile -VM $VM -SourcePath $Script.FullName -DestinationPath "$($ClientScriptPath)\$($Script.Name)" -CreateFullPath -FileSource Host -Force
    }

    Get-VMNetworkAdapter -VMName $VMName | Connect-VMNetworkAdapter -SwitchName $InternetSwitchName | Set-VMNetworkAdapter -DeviceNaming On -Passthru | Rename-NetAdapter -NewName "Internet"
    Invoke-LabCommand -FilePath "$($LabScriptPath)\InstallRRAS.ps1" -MessageText "InstallRRAS" -SessionType Local -VMID $VM.VMId

    Write-Host "RRAS Configuration Complete!"

}