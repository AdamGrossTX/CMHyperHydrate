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
        $DomainAdminCreds = $Script:base.DomainAdminCreds
    )

        if((Get-VM -Name $VMName).State -eq "Off") {
            Start-VM -Name $VMName
        }

            #Region Install SQL
            #if (((Invoke-Pester -TestName "CM" -PassThru -show None).TestResult | Where-Object {$_.name -match "CM SQL Instance is installed"}).result -notmatch "Passed") {
            #Get-VMDvdDrive -VMName $VMName
            Add-VMDvdDrive -VMName $VMName -ControllerNumber 0 -ControllerLocation 1
            Set-VMDvdDrive -Path $SQLISO -VMName $VMName -ControllerNumber 0 -ControllerLocation 1
            
            while ((Invoke-Command -VMName $VMName -Credential $DomainAdminCreds {"Test"} -ErrorAction SilentlyContinue) -ne "Test") {Start-Sleep -Seconds 5}
            $PSSessionDomain = New-PSSession -VMName $VMName -Credential $DomainAdminCreds

            $SQLDisk = Invoke-Command -session $PSSessionDomain -ScriptBlock {(Get-PSDrive -PSProvider FileSystem | where-object {$_.name -ne "c"}).root}
            #write-logentry -message "$($config.sqliso) mounted as $sqldisk to $cmname" -type information
            
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
                param($ini) 
                new-item -ItemType file -Path c:\data\SQL\ConfigurationFile.INI -Value $INI -Force
            }

            $SBSQLInstallCmd = {

                param($drive)
                Start-Process -FilePath "$($drive)Setup.exe" -Wait -ArgumentList "/ConfigurationFile=c:\data\SQL\ConfigurationFile.INI /IACCEPTSQLSERVERLICENSETERMS"
            }
            #write-logentry -message "SQL Configuration for $cmname is: $sqlinstallini" -type information
            Invoke-Command -Session $PSSessionDomain -ScriptBlock $SBSQLINI -ArgumentList $SQLInstallINI | out-null
            #write-logentry -message "SQL installation has started on $cmname this can take some time" -type information
            Invoke-Command -Session $PSSessionDomain -ScriptBlock $SBSQLInstallCmd -ArgumentList $SQLDisk
            #write-logentry -message "SQL installation has completed on $cmname told you it would take some time" -type information
            #Invoke-Command -Session $cmsession -ScriptBlock {Import-Module sqlps;$wmi = new-object ('Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer');$Np = $wmi.GetSmoObject("ManagedComputer[@Name='$env:computername']/ ServerInstance[@Name='MSSQLSERVER']/ServerProtocol[@Name='Np']");$Np.IsEnabled = $true;$Np.Alter();Get-Service mssqlserver | Restart-Service}
            Set-VMDvdDrive -VMName $VMName -Path $null
            #write-logentry -message "SQL ISO dismounted from $cmname" -type information
        #}

        #end region    
}