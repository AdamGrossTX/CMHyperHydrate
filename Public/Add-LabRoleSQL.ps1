function Add-LabRoleSQL {
    [cmdletBinding()]
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
        $SQLISO = $BaseConfig.SQLISO,

        [Parameter()]
        [string]
        $AddWSUS = $VMConfig.AddWSUS,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $VMDataPath = $BaseConfig.VMDataPath,

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

    Get-VMDvdDrive -VMName $VMName
    Add-VMDvdDrive -VMName $VMName -ControllerNumber 0 -ControllerLocation 1
    Set-VMDvdDrive -Path $SQLISO -VMName $VMName -ControllerNumber 0 -ControllerLocation 1
    
    $SQLInstallINI = New-LabCMSQLSettingsINI -DomainNetBiosName $LabEnvConfig.EnvFQDN -UserName $BaseConfig.DomainAdminName -Password $LabEnvConfig.EnvAdminPW
    
    #region Script Blocks
    $SBSQLInstallCmdParams = @"
        param (
            `$_LogPath = "$($LogPath)",
            `$_ClientScriptPath = "$($ClientScriptPath)"
        )
"@

    $SBSQLInstallCmd = {
        $_SQLDisk = (Get-PSDrive -PSProvider FileSystem | where-object {$_.name -ne "c"}).root
        Start-Process -FilePath "$($_SQLDisk)Setup.exe" -Wait -ArgumentList "/ConfigurationFile=$($_ClientScriptPath)\ConfigurationFile.INI /IACCEPTSQLSERVERLICENSETERMS"
    }

    $SBSQLMemory = {
        [reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null
        $srv = New-Object Microsoft.SQLServer.Management.Smo.Server($env:COMPUTERNAME)
        if ($srv.status) {
            $srv.Configuration.MaxServerMemory.ConfigValue = 8kb
            $srv.Configuration.MinServerMemory.ConfigValue = 4kb   
            $srv.Configuration.Alter()
        }
    }

    $SBAddWSUS = {
        Add-WindowsFeature UpdateServices-Services, UpdateServices-db
    }

    $SBWSUSPostInstall = {
        Start-Process -filepath "C:\Program Files\Update Services\Tools\WsusUtil.exe" -ArgumentList "postinstall CONTENT_DIR=C:\WSUS SQL_INSTANCE_NAME=$env:COMPUTERNAME" -Wait
    }

    $SQLIni += $SQLInstallINI.ToString()
    $SQLIni | Out-File "$($LabScriptPath)\ConfigurationFile.INI" -Force

    $SQLInstallCmd += $SBSQLInstallCmdParams
    $SQLInstallCmd += $SBScriptTemplateBegin.ToString()
    $SQLInstallCmd += $SBSQLInstallCmd.ToString()
    $SQLInstallCmd += $SBScriptTemplateEnd.ToString()
    $SQLInstallCmd | Out-File "$($LabScriptPath)\SQLInstallCmd.ps1"

    $SQLMemory += $SBDefaultParams
    $SQLMemory += $SBScriptTemplateBegin.ToString()
    $SQLMemory += $SBSQLMemory.ToString()
    $SQLMemory += $SBScriptTemplateEnd.ToString()
    $SQLMemory | Out-File "$($LabScriptPath)\SQLMemory.ps1"

    $AddWSUS += $SBDefaultParams
    $AddWSUS += $SBScriptTemplateBegin.ToString()
    $AddWSUS += $SBAddWSUS.ToString()
    $AddWSUS += $SBScriptTemplateEnd.ToString()
    $AddWSUS | Out-File "$($LabScriptPath)\AddWSUS.ps1"

    $WSUSPostInstall += $SBDefaultParams
    $WSUSPostInstall += $SBScriptTemplateBegin.ToString()
    $WSUSPostInstall += $SBWSUSPostInstall.ToString()
    $WSUSPostInstall += $SBScriptTemplateEnd.ToString()
    $WSUSPostInstall | Out-File "$($LabScriptPath)\WSUSPostInstall.ps1"
    
    $Scripts = Get-Item -Path "$($LabScriptPath)\*.*"

    #endregion

    $VM = Get-VM -Name $VMName
    $VM | Start-VM -WarningAction SilentlyContinue
    start-sleep 10

    while (-not (Invoke-Command -VMName $VMName -Credential $DomainAdminCreds {Get-Process "LogonUI" -ErrorAction SilentlyContinue;})) {Start-Sleep -seconds 5}

    foreach ($Script in $Scripts) {
        Copy-VMFile -VM $VM -SourcePath $Script.FullName -DestinationPath "$($ClientScriptPath)\$($Script.Name)" -CreateFullPath -FileSource Host -Force
    }

    #Invoke-LabCommand -FilePath "$($LabScriptPath)\SQLIni.ps1" -MessageText "SQLIni" -SessionType Domain -VMID $VM.VMId
    Invoke-LabCommand -FilePath "$($LabScriptPath)\SQLInstallCmd.ps1" -MessageText "SQLInstallCmd" -SessionType Domain -VMID $VM.VMId
    Invoke-LabCommand -FilePath "$($LabScriptPath)\SQLMemory.ps1" -MessageText "SQLMemory" -SessionType Domain -VMID $VM.VMId
    if($AddWSUS = 1) {
        Invoke-LabCommand -FilePath "$($LabScriptPath)\AddWSUS.ps1" -MessageText "AddWSUS" -SessionType Domain -VMID $VM.VMId
        Invoke-LabCommand -FilePath "$($LabScriptPath)\WSUSPostInstall.ps1" -MessageText "WSUSPostInstall" -SessionType Domain -VMID $VM.VMId
    }
    Set-VMDvdDrive -VMName $VMName -Path $null

    Write-Host "$($MyInvocation.MyCommand) Complete!" -ForegroundColor Cyan
}