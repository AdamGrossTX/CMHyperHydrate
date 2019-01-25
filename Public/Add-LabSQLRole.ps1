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

        if((Get-VM -Name $VMName).State -eq "Off") {
            Start-VM -Name $VMName
        }

            #Region Install SQL
            #if (((Invoke-Pester -TestName "CM" -PassThru -show None).TestResult | Where-Object {$_.name -match "CM SQL Instance is installed"}).result -notmatch "Passed") {
            Get-VMDvdDrive -VMName $VMName
            Add-VMDvdDrive -VMName $VMName -ControllerNumber 0 -ControllerLocation 1
            Set-VMDvdDrive -Path $SQLISO -VMName $VMName -ControllerNumber 0 -ControllerLocation 1
            
            while ((Invoke-Command -VMName $VMName -Credential $DomainAdminCreds {"Test"} -ErrorAction SilentlyContinue) -ne "Test") {Start-Sleep -Seconds 5}
            $PSSessionDomain = New-PSSession -VMName $VMName -Credential $DomainAdminCreds

            $SQLDisk = Invoke-Command -session $PSSessionDomain -ScriptBlock {(Get-PSDrive -PSProvider FileSystem | where-object {$_.name -ne "c"}).root}
            #write-logentry -message "$($config.sqliso) mounted as $sqldisk to $cmname" -type information
            
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
                start-process -FilePath "C:\windows\system32\msiexec.exe" -ArgumentList "/I $($ConfigMgrPath)\Prereqs\sqlncli.msi /QN REBOOT=ReallySuppress /l*v $($ConfigMgrPath)\SQLLog.log"
            }


            #write-logentry -message "SQL Configuration for $cmname is: $sqlinstallini" -type information
            Invoke-Command -Session $PSSessionDomain -ScriptBlock $SBSQLINI -ArgumentList $SQLInstallINI,$SQLPath | out-null
            #write-logentry -message "SQL installation has started on $cmname this can take some time" -type information
            Invoke-Command -Session $PSSessionDomain -ScriptBlock $SBSQLInstallCmd -ArgumentList $SQLDisk,$SQLPath | out-null
            #write-logentry -message "SQL installation has completed on $cmname told you it would take some time" -type information
            #Invoke-Command -Session $cmsession -ScriptBlock {Import-Module sqlps;$wmi = new-object ('Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer');$Np = $wmi.GetSmoObject("ManagedComputer[@Name='$env:computername']/ ServerInstance[@Name='MSSQLSERVER']/ServerProtocol[@Name='Np']");$Np.IsEnabled = $true;$Np.Alter();Get-Service mssqlserver | Restart-Service}

            Invoke-Command -Session $PSSessionDomain -ScriptBlock $SBSQLMemory | out-null 
            Invoke-Command -Session $PSSessionDomain -ScriptBlock $SBAddWSUS | out-null
            Invoke-command -Session $PSSessionDomain -scriptblock $SBWSUSPostInstall | out-null
            Invoke-command -Session $PSSessionDomain -ScriptBlock $SBInstallSQLNativeClient -ArgumentList $ConfigMgrPath| out-null

            Set-VMDvdDrive -VMName $VMName -Path $null
            $PSSessionDomain | Remove-PSSession
            #write-logentry -message "SQL ISO dismounted from $cmname" -type information
        #}

        #end region    
}