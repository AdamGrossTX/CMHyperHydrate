Function Add-LabSQLRole {
    [cmdletBinding()]
    param (

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $VMName = $Script:VMConfig.VMName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $SQLISO = $Script:Base.SQLISO,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $VMDataPath = $Script:Base.VMDataPath,

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

    $LabScriptPath = "$($LabPath)$($ScriptPath)\$($VMName)"
    
    if(!(Test-Path -Path "$($LabScriptPath)" -ErrorAction SilentlyContinue)){
        New-Item -Path "$($LabScriptPath)" -ItemType Directory -ErrorAction SilentlyContinue
    }


    Get-VMDvdDrive -VMName $VMName
    Add-VMDvdDrive -VMName $VMName -ControllerNumber 0 -ControllerLocation 1
    Set-VMDvdDrive -Path $SQLISO -VMName $VMName -ControllerNumber 0 -ControllerLocation 1
    
    $SQLDisk = Invoke-LabCommand -ScriptBlock {(Get-PSDrive -PSProvider FileSystem | where-object {$_.name -ne "c"}).root} -VMID $VM.VMID -MessageText "GetPSDrive" 
    $SQLPath = "C:$($VMDataPath)\SQL"
    $SQLInstallINI = New-LabCMSQLSettingsINI


$LogPath = "C:$($LogPath)"
$SBDefaultParams = @"
    param
    (
        `$_LogPath = "$($LogPath)"
    )
"@

$SBScriptTemplateBegin = {
    If(!(Test-Path -Path $_LogPath -ErrorAction SilentlyContinue))
    {
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
    
    #region Script Blocks
$SBSQLIniParams = @"
    param(
        `$_LogPath = "$($LogPath)",
        `$_SQLInstallINI = "$($SQLInstallINI)",
        `$_SQLPath = "$($SQLPath)"
    )
"@

$SBSQLIni = {
    New-Item -ItemType file -Path "$($_SQLPath)\ConfigurationFile.INI" -Value $_SQLInstallINI -Force
}

$SBSQLInstallCmdParams = @"
    param(
        `$_LogPath = "$($LogPath)",
        `$_drive = "$($drive)",
        `$_SQLPath = "$($SQLPath)"
    )
"@

$SBSQLInstallCmd = {
    param($drive,$SQLPath)
    Start-Process -FilePath "$($_drive)Setup.exe" -Wait -ArgumentList "/ConfigurationFile=$($_SQLPath)\ConfigurationFile.INI /IACCEPTSQLSERVERLICENSETERMS"
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


$SQLIni += $SBSQLIniParams
$SQLIni += $SBScriptTemplateBegin.ToString()
$SQLIni += $SBSQLIni.ToString()
$SQLIni += $SCScriptTemplateEnd.ToString()
$SQLIni | Out-File "$($LabScriptPath)\SQLIni.ps1"

$SQLInstallCmd += $SBSQLInstallCmdParams
$SQLInstallCmd += $SBScriptTemplateBegin.ToString()
$SQLInstallCmd += $SBSQLInstallCmd.ToString()
$SQLInstallCmd += $SCScriptTemplateEnd.ToString()
$SQLInstallCmd | Out-File "$($LabScriptPath)\SQLInstallCmd.ps1"

$SQLMemory += $SBDefaultParams
$SQLMemory += $SBScriptTemplateBegin.ToString()
$SQLMemory += $SBSQLMemory.ToString()
$SQLMemory += $SCScriptTemplateEnd.ToString()
$SQLMemory | Out-File "$($LabScriptPath)\SQLMemory.ps1"

$AddWSUS += $SBDefaultParams
$AddWSUS += $SBScriptTemplateBegin.ToString()
$AddWSUS += $SBAddWSUS.ToString()
$AddWSUS += $SCScriptTemplateEnd.ToString()
$AddWSUS | Out-File "$($LabScriptPath)\AddWSUS.ps1"

$WSUSPostInstall += $SBDefaultParams
$WSUSPostInstall += $SBScriptTemplateBegin.ToString()
$WSUSPostInstall += $SBWSUSPostInstall.ToString()
$WSUSPostInstall += $SCScriptTemplateEnd.ToString()
$WSUSPostInstall | Out-File "$($LabScriptPath)\WSUSPostInstall.ps1"
#endregion

$VM = Get-VM -Name $VMName
$VM | Start-VM

start-sleep 10
$Scripts = Get-Item -Path "$($LabScriptPath)\*.*"

While (!(Invoke-Command -VMName $VMName -Credential $LocalAdminCreds {Get-Process "LogonUI" -ErrorAction SilentlyContinue;})) {Start-Sleep -seconds 5}

Foreach($Script in $Scripts) {
    Copy-VMFile -VM $VM -SourcePath $Script.FullName -DestinationPath "C:$($ScriptPath)\$($Script.Name)" -CreateFullPath -FileSource Host -Force
}

$ClientScriptPath = "C:$($ScriptPath)\"

Invoke-LabCommand -FilePath "$($LabScriptPath)\SQLIni.ps1" -MessageText "SQLIni" -SessionType Local -VMID $VM.VMId
Invoke-LabCommand -FilePath "$($LabScriptPath)\SQLInstallCmd.ps1" -MessageText "SQLInstallCmd" -SessionType Local -VMID $VM.VMId
Invoke-LabCommand -FilePath "$($LabScriptPath)\SQLMemory.ps1" -MessageText "SQLMemory" -SessionType Local -VMID $VM.VMId
Invoke-LabCommand -FilePath "$($LabScriptPath)\AddWSUS.ps1" -MessageText "AddWSUS" -SessionType Local -VMID $VM.VMId
Invoke-LabCommand -FilePath "$($LabScriptPath)\WSUSPostInstall.ps1" -MessageText "WSUSPostInstall" -SessionType Local -VMID $VM.VMId

Set-VMDvdDrive -VMName $VMName -Path $null

#Checkpoint-VM -VM $VM -SnapshotName "SQL Configuration Complete"
        
}