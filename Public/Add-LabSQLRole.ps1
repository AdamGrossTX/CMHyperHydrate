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
        $DomainNetBiosName = $Script:Env.EnvNetBios,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [pscredential]
        $DomainAdminCreds = $Script:base.DomainAdminCreds,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $VMDataPath = $Script:Base.VMDataPath
    )

            Get-VMDvdDrive -VMName $VMName
            Add-VMDvdDrive -VMName $VMName -ControllerNumber 0 -ControllerLocation 1
            Set-VMDvdDrive -Path $SQLISO -VMName $VMName -ControllerNumber 0 -ControllerLocation 1

            $SQLDisk = Invoke-LabCommand -ScriptBlock {(Get-PSDrive -PSProvider FileSystem | where-object {$_.name -ne "c"}).root}
            $ConfigMgrPath = "C:$VMDataPath\ConfigMgr"
            $SQLPath = "C:$VMDataPath\SQL"

            $SQLHash = @{'ACTION' = '"Install"';
                'SUPPRESSPRIVACYSTATEMENTNOTICE' = '"TRUE"';
                'IACCEPTROPENLICENSETERMS' = '"TRUE"';
                'ENU' = '"TRUE"';
                'QUIET' = '"TRUE"';
                'UpdateEnabled' = '"TRUE"';
                'USEMICROSOFTUPDATE' = '"TRUE"';
                'FEATURES' = 'SQLENGINE,RS';
                'UpdateSource' = '"MU"';
                'HELP' = '"FALSE"';
                'INDICATEPROGRESS' = '"FALSE"';
                'X86' = '"FALSE"';
                'INSTANCENAME' = '"MSSQLSERVER"';
                'INSTALLSHAREDDIR' = '"C:\Program Files\Microsoft SQL Server"';
                'INSTALLSHAREDWOWDIR' = '"C:\Program Files (x86)\Microsoft SQL Server"';
                'INSTANCEID' = '"MSSQLSERVER"';
                'RSINSTALLMODE' = '"DefaultNativeMode"';
                'SQLTELSVCACCT' = '"NT Service\SQLTELEMETRY"';
                'SQLTELSVCSTARTUPTYPE' = '"Automatic"';
                'INSTANCEDIR' = '"C:\Program Files\Microsoft SQL Server"';
                'AGTSVCACCOUNT' = '"NT Service\SQLSERVERAGENT"';
                'AGTSVCSTARTUPTYPE' = '"Manual"';
                'COMMFABRICPORT' = '"0"';
                'COMMFABRICNETWORKLEVEL' = '"0"';
                'COMMFABRICENCRYPTION' = '"0"';
                'MATRIXCMBRICKCOMMPORT' = '"0"';
                'SQLSVCSTARTUPTYPE' = '"Automatic"';
                'FILESTREAMLEVEL' = '"0"';
                'ENABLERANU' = '"FALSE"';
                'SQLCOLLATION' = '"SQL_Latin1_General_CP1_CI_AS"';
                'SQLSVCACCOUNT' = """$($DomainAdminCreds.UserName)"""; 
                'SQLSVCPASSWORD' = """$($DomainAdminCreds.GetNetworkCredential().Password)""" ;
                'SQLSVCINSTANTFILEINIT' = '"FALSE"';
                'SQLSYSADMINACCOUNTS' = """$($DomainAdminCreds.UserName)"" ""$($DomainNetBiosName)\Domain Users"""; 
                'SQLTEMPDBFILECOUNT' = '"1"';
                'SQLTEMPDBFILESIZE' = '"8"';
                'SQLTEMPDBFILEGROWTH' = '"64"';
                'SQLTEMPDBLOGFILESIZE' = '"8"';
                'SQLTEMPDBLOGFILEGROWTH' = '"64"';
                'ADDCURRENTUSERASSQLADMIN' = '"FALSE"';
                'TCPENABLED' = '"1"';
                'NPENABLED' = '"1"';
                'BROWSERSVCSTARTUPTYPE' = '"Disabled"';
                'RSSVCACCOUNT' = '"NT Service\ReportServer"';
                'RSSVCSTARTUPTYPE' = '"Automatic"';
            }
            $SQLHASHINI = @{'OPTIONS' = $SQLHash}
            $SQLInstallINI = ""
            Foreach ($i in $SQLHASHINI.keys) {
                $SQLInstallINI += "[$i]`r`n"
                foreach ($j in $($SQLHASHINI[$i].keys | Sort-Object)) {
                    $SQLInstallINI += "$j=$($SQLHASHINI[$i][$j])`r`n"
                }
                $SQLInstallINI += "`r`n"
            }


            #region Script Blocks
            $SBSQLINI = {
                param($ini,$SQLPath) 
                new-item -ItemType file -Path "$($SQLPath)\ConfigurationFile.INI" -Value $INI -Force
            }

            $SBSQLInstallCmd = {

                param($drive,$SQLPath)
                Start-Process -FilePath "$($drive)Setup.exe" -Wait -ArgumentList "/ConfigurationFile=$($SQLPath)\ConfigurationFile.INI /IACCEPTSQLSERVERLICENSETERMS"
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
            Invoke-LabCommand -ScriptBlock $SBSQLINI -MessageText "SBSQLINI" -ArgumentList $SQLInstallINI,$SQLPath | out-null
            Invoke-LabCommand -ScriptBlock $SBSQLInstallCmd -MessageText "SBSQLInstallCmd" -ArgumentList $SQLDisk,$SQLPath | out-null
            Invoke-LabCommand -ScriptBlock $SBSQLMemory -MessageText "SBSQLMemory" | out-null 
            Invoke-LabCommand -ScriptBlock $SBAddWSUS -MessageText "SBAddWSUS" | out-null
            Invoke-LabCommand -scriptblock $SBWSUSPostInstall -MessageText "SBWSUSPostInstall" | out-null
            Invoke-LabCommand -ScriptBlock $SBInstallSQLNativeClient -MessageText "SBInstallSQLNativeClient" -ArgumentList $ConfigMgrPath| out-null
            Set-VMDvdDrive -VMName $VMName -Path $null
}