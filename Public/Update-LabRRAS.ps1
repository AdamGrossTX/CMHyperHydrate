function Update-LabRRAS {
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
        $VMName = $LabEnvConfig.RRASName,

        [Parameter()]
        [String]
        $SwitchName = $LabEnvConfig.EnvSwitchName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $RRASName = $LabEnvConfig.RRASName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ENVName = $LabEnvConfig.Env,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [pscredential]
        $LocalAdminCreds = $BaseConfig.LocalAdminCreds,

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

    $VM = Get-VM -VM $VMName
    $VM | Get-VMNetworkAdapter | Where-Object {$_.SwitchName -eq $SwitchName} | Remove-VMNetworkAdapter
    $NewRRASAdapter = $VM | Add-VMNetworkAdapter -SwitchName $SwitchName -Name $ENVName -Passthru
    $NewRRASAdapter | Set-VMNetworkAdapterVlan -VlanId 4 -Access
    $NewRRASAdapter | Set-VMNetworkAdapter -DeviceNaming On -Passthru | Rename-VMNetworkAdapter -NewName $ENVName
    $LabEnvConfig["RRASMAC"] = $NewRRASAdapter.MACAddress
    $RRASMAC = $LabEnvConfig["RRASMAC"]
    
    #region Script Blocks

    $SBUpdateRRASParams = @"
    param
    (
        `$_LogPath = "$($LogPath)",
        `$_RRASMAC = "$($RRASMAC)",
        `$_ENVName = "$($ENVName)"
    )
"@
    
$SBUpdateRRAS = {
    $ExistingNIC = Get-ChildItem -Path "HKLM:SYSTEM\CurrentControlSet\Control\Network" -Recurse -ErrorAction 0 | Get-ItemProperty -Name "Name" -ErrorAction 0 | Where-Object {$_.Name -eq $_ENVName} | ForEach-Object { Get-ItemPropertyValue -Path $_.PSPath -Name PnPInstanceId}
    if($ExistingNIC) {
        $Dev = Get-PnpDevice -class net | Where-Object { $_.Status -eq "Unknown" -and $_.InstanceId -eq $ExistingNIC}
        $RemoveKey = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($Dev.InstanceId)"
        Get-Item $RemoveKey | Select-Object -ExpandProperty Property | ForEach-Object { Remove-ItemProperty -Path $RemoveKey -Name $_}
    }

    $NewNIC = Get-NetAdapter | Where-Object {$_.MACAddress.Replace("-","") -eq $_RRASMAC}
    $NewNIC | Rename-NetAdapter -NewName $_ENVName
    Get-Service -name "remoteaccess" | Restart-Service -WarningAction SilentlyContinue; 
    netsh routing ip nat add interface "$($_ENVName)"
    $NewNIC | Restart-NetAdapter
    Start-Sleep -Seconds 60
    Get-Service -name "remoteaccess" | Restart-Service -WarningAction SilentlyContinue;
}

    $UpdateRRAS += $SBUpdateRRASParams
    $UpdateRRAS += $SBScriptTemplateBegin.ToString()
    $UpdateRRAS += $SBUpdateRRAS.ToString()
    $UpdateRRAS += $SBScriptTemplateEnd.ToString()
    $UpdateRRAS | Out-File "$($LabScriptPath)\$($ENVName).ps1"

    $Scripts = Get-Item -Path "$($LabScriptPath)\*.*"

    #endregion

    $VM = Get-VM -VM $RRASName
    $VM | Start-VM -WarningAction SilentlyContinue
    start-sleep 10

    while (-not (Invoke-Command -VMName $VMName -Credential $LocalAdminCreds {Get-Process "LogonUI" -ErrorAction SilentlyContinue;})) {Start-Sleep -seconds 5}
    
    foreach ($Script in $Scripts) {
        Copy-VMFile -VM $VM -SourcePath $Script.FullName -DestinationPath "C:$($ScriptPath)\$($Script.Name)" -CreateFullPath -FileSource Host -Force
    }

    Invoke-LabCommand -FilePath "$($LabScriptPath)\$($ENVName).ps1" -MessageText "Update RRAS" -SessionType Local -VMID $VM.VMId

    Write-Host "$($MyInvocation.MyCommand) Complete!" -ForegroundColor Cyan
}