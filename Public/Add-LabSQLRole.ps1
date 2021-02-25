Function Add-LabSQLRole {
    [cmdletBinding()]
    param(

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
        $VMDataPath = $Script:Base.VMDataPath
    )

    $VM = Get-VM -Name $VMName

    Get-VMDvdDrive -VMName $VMName
    Add-VMDvdDrive -VMName $VMName -ControllerNumber 0 -ControllerLocation 1
    Set-VMDvdDrive -Path $SQLISO -VMName $VMName -ControllerNumber 0 -ControllerLocation 1

    $SQLDisk = Invoke-LabCommand -ScriptBlock {(Get-PSDrive -PSProvider FileSystem | where-object {$_.name -ne "c"}).root} -VMID $VM.VMID -MessageText "GetPSDrive" 
    $ConfigMgrPath = "C:$VMDataPath\ConfigMgr"
    $SQLPath = "C:$VMDataPath\SQL"
    $SQLInstallINI = New-LabCMSQLSettingsINI

    #region Script Blocks
    $SBSQLINI = {
        param($ini,$SQLPath) 
        new-item -ItemType file -Path "$($SQLPath)\ConfigurationFile.INI" -Value $INI -Force
    }

    $SBSQLInstallCmd = {

        param($drive,$SQLPath)Start-Process -FilePath "$($drive)Setup.exe" -Wait -ArgumentList "/ConfigurationFile=$($SQLPath)\ConfigurationFile.INI /IACCEPTSQLSERVERLICENSETERMS"
        
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

    $SBInstallSQLNativeClient = {
        param($ConfigMgrPath)
        start-process -FilePath "C:\windows\system32\msiexec.exe" -ArgumentList "/I $($ConfigMgrPath)\Prereqs\sqlncli.msi /QN REBOOT=ReallySuppress /l*v $($ConfigMgrPath)\SQLLog.log" -Wait
    }
    #endregion
    Invoke-LabCommand -ScriptBlock $SBSQLINI -MessageText "SBSQLINI" -ArgumentList $SQLInstallINI,$SQLPath -VMID $VM.VMID | out-null
    Invoke-LabCommand -ScriptBlock $SBSQLInstallCmd -MessageText "SBSQLInstallCmd" -ArgumentList $SQLDisk,$SQLPath -VMID $VM.VMID | out-null
    Invoke-LabCommand -ScriptBlock $SBSQLMemory -MessageText "SBSQLMemory" -VMID $VM.VMID | out-null 
    Invoke-LabCommand -ScriptBlock $SBAddWSUS -MessageText "SBAddWSUS" -VMID $VM.VMID | out-null
    Invoke-LabCommand -scriptblock $SBWSUSPostInstall -MessageText "SBWSUSPostInstall" -VMID $VM.VMID | out-null
    Invoke-LabCommand -ScriptBlock $SBInstallSQLNativeClient -MessageText "SBInstallSQLNativeClient" -ArgumentList $ConfigMgrPath -VMID $VM.VMID | out-null
    Set-VMDvdDrive -VMName $VMName -Path $null

    #Checkpoint-VM -VM $VM -SnapshotName "SQL Configuration Complete"
        
}