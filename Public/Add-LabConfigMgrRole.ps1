Function Add-LabConfigMgrRole {
    [cmdletBinding()]
    param(

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $VMPath,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $VMName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ConfigMgrMedia,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ADKMedia,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ADKWinPEMedia,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $SQLISO,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $SQLServiceAccount,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $SQLServiceAccountPassword,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $DomainNetBiosName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $DomainFQDN,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ConfigMgrSiteCode,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("Prod","TP")]
        [string]
        $ConfigMgrVersion,

        [Parameter()]
        [int]
        $ConfigMgrPrereqsPreDL = 1,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ConfigMgrPrereqsPath = "\Prereqs"
        

    )

    $VHDX = (Get-VMHardDiskDrive -VMName CMTPCM1 | Where-Object Path -like "*$($VMName)c.vhdx").Path

        $ConfigMgrPath = "\data\ConfigMgr"
        $ADKPath = "\data\adk"
        $ADKWinPEPath = "\data\adkwinpe"

        $Disk = (Mount-VHD -Path $VHDX -Passthru | Get-Disk | Get-Partition | Where-Object {$_.type -eq 'Basic'}).DriveLetter
        #write-logentry -message "$cmvhdx has been mounted to allow for file copy to $disk" -type information
        Copy-Item -Path $ConfigMgrMedia -Destination "$($disk):$($ConfigMgrPath)" -Recurse
        #write-logentry -message "SCCM Media copied to $disk`:\data\SCCM" -type information
        Copy-Item -Path $ADKMedia -Destination "$($disk):$($ADKPath)" -Recurse
        #write-logentry -message "ADK Media copied to $disk`:\data\adk" -type information
        Copy-Item -Path $ADKADKWinPEMedia -Destination "$($disk):$($ADKWinPEPath)" -Recurse
        #write-logentry -message "ADK Media copied to $disk`:\data\adk" -type information
        #Copy-Item -Path $SQLMedia -Destination "$($disk):\data\SQL" -Recurse
        #write-logentry -message "ADK Media copied to $disk`:\data\adk" -type information
        Dismount-VHD $cmvhdx

        if((Get-VM -Name $VMName).State -eq "Off") {
            Start-VM -Name $VMName
        }

            $SBAddFeatures = {
                Add-WindowsFeature BITS, BITS-IIS-Ext, BITS-Compact-Server, Web-Server, Web-WebServer, Web-Common-Http, Web-Default-Doc, Web-Dir-Browsing, Web-Http-Errors, Web-Static-Content, Web-Http-Redirect, Web-App-Dev, Web-Net-Ext, Web-Net-Ext45, Web-ASP, Web-Asp-Net, Web-Asp-Net45, Web-CGI, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Health, Web-Http-Logging, Web-Custom-Logging, Web-Log-Libraries, Web-Request-Monitor, Web-Http-Tracing, Web-Performance, Web-Stat-Compression, Web-Security, Web-Filtering, Web-Basic-Auth, Web-IP-Security, Web-Url-Auth, Web-Windows-Auth, Web-Mgmt-Tools, Web-Mgmt-Console, Web-Mgmt-Compat, Web-Metabase, Web-Lgcy-Mgmt-Console, Web-Lgcy-Scripting, Web-WMI, Web-Scripting-Tools, Web-Mgmt-Service, RDC;
            }
            Invoke-Command -session $cmsession -ScriptBlock $SBAddFeatures | Out-Null

            #Region Install SQL
            #if (((Invoke-Pester -TestName "CM" -PassThru -show None).TestResult | Where-Object {$_.name -match "CM SQL Instance is installed"}).result -notmatch "Passed") {
            Add-VMDvdDrive -VMName $VMName -ControllerNumber 0 -ControllerLocation 1
            Set-VMDvdDrive -Path $SQLISO -VMName $VMName -ControllerNumber 0 -ControllerLocation 1
            $SQLDisk = Invoke-Command -session $cmsession -ScriptBlock {(Get-PSDrive -PSProvider FileSystem | where-object {$_.name -ne "c"}).root}
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
                'SQLSVCACCOUNT' = """$($SQLServiceAccount)"""; 
                'SQLSVCPASSWORD' = """$($SQLServiceAccountPassword)""" ;
                'SQLSVCINSTANTFILEINIT' = '"FALSE"';
                'SQLSYSADMINACCOUNTS' = """$($SQLServiceAccount)"" ""$($DomainNetBiosName)\Domain Users"""; 
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
                Start-Process -FilePath "$($drive)Setup.exe" -Wait -ArgumentList "/ConfigurationFile=c:\ConfigurationFile.INI /IACCEPTSQLSERVERLICENSETERMS"
            }
            #write-logentry -message "SQL Configuration for $cmname is: $sqlinstallini" -type information
            Invoke-Command -Session $cmsession -ScriptBlock $SBSQLINI -ArgumentList $SQLInstallINI | out-null
            #write-logentry -message "SQL installation has started on $cmname this can take some time" -type information
            Invoke-Command -Session $cmsession -ScriptBlock $SBSQLInstallCmd -ArgumentList $SQLDisk
            #write-logentry -message "SQL installation has completed on $cmname told you it would take some time" -type information
            #Invoke-Command -Session $cmsession -ScriptBlock {Import-Module sqlps;$wmi = new-object ('Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer');$Np = $wmi.GetSmoObject("ManagedComputer[@Name='$env:computername']/ ServerInstance[@Name='MSSQLSERVER']/ServerProtocol[@Name='Np']");$Np.IsEnabled = $true;$Np.Alter();Get-Service mssqlserver | Restart-Service}
            Set-VMDvdDrive -VMName $VMName -Path $null
            #write-logentry -message "SQL ISO dismounted from $cmname" -type information
        #}

        #end region

        #region Install ADK
        #if (((Invoke-Pester -TestName "CM" -PassThru -show None).TestResult | Where-Object {$_.name -match "CM ADK installed"}).result -notmatch "Passed") {
        #    write-logentry -message "ADK is installing on $cmname" -type information
            
        $SBADK = {
            param($path)
            $SetupSwitches = "/Features OptionId.DeploymentTools OptionId.ImagingAndConfigurationDesigner OptionId.ICDConfigurationDesigner OptionId.UserStateMigrationTool /norestart /quiet /ceip off"
            Start-Process -FilePath "$($path)\adksetup.exe" -ArgumentList $SetupSwitches -NoNewWindow -Wait
        }
        Invoke-Command -Session $cmsession -ScriptBlock $SBADK

        $SBWinPEADK = {
            param($path)
            $SetupSwitches = "/Features OptionId.WindowsPreinstallationEnvironment /norestart /quiet /ceip off"    
            Start-Process -FilePath "$($path)\adkwinpesetup.exe" -ArgumentList $SetupSwitches -NoNewWindow -Wait
        }

        Invoke-Command -Session $cmsession -ScriptBlock $SBADK -ArgumentList "C:\$($ADKPath)"
        Invoke-Command -Session $cmsession -ScriptBlock $SBADK -ArgumentList "C:\$($ADKWinPEPath)"
        Invoke-Command -Session $cmsession -ScriptBlock {Restart-Computer -Force}
        
        #EndRegion
        

        #Install ConfigMgr
        #    write-logentry -message "ADK is installed on $cmname" -type information
        #}
        #if (((Invoke-Pester -TestName "CM" -PassThru -show None).TestResult | Where-Object {$_.name -match "CM SCCM Installed"}).result -notmatch "Passed") {
        #    $cmOSName = Invoke-Command -Session $cmsession -ScriptBlock {$env:COMPUTERNAME}
        #    write-logentry -message "Host name for $cmname is: $cmosname"
            
            if ($ConfigMgrVersion -eq "Prod") {
                $HashIdent = @{'action' = 'InstallPrimarySite'
                }
            }
            else {
                $HashIdent = @{
                    'action' = 'InstallPrimarySite';
                    'Preview' = "1"
                }
            }
            $HashOptions = @{
                'ProductID' = 'EVAL';
                'SiteCode' = $($ConfigMgrSiteCode);
                'SiteName' = "Tech Preview $($ConfigMgrSiteCode)";
                'SMSInstallDir' = 'C:\Program Files\Microsoft Configuration Manager';
                'SDKServer' = "$($VMName).$($DomainFQDN)";
                'RoleCommunicationProtocol' = "HTTPorHTTPS";
                'ClientsUsePKICertificate' = "0";
                'PrerequisiteComp' = "$($ConfigMgrPrereqsPreDL)";
                'PrerequisitePath' = "$($ConfigmgrPath)\$($ConfigMgrPrereqsPath)";
                'ManagementPoint' = "$($VMName).$($DomainFQDN)";
                'ManagementPointProtocol' = "HTTP";
                'DistributionPoint' = "$($VMName).$($DomainFQDN)";
                'DistributionPointProtocol' = "HTTP";
                'DistributionPointInstallIIS' = "0";
                'AdminConsole' = "1";
                'JoinCEIP' = "0";
            }
            $hashSQL = @{
                'SQLServerName' = "$($VMName).$($DomainFQDN)";
                'DatabaseName' = "CM_$($ConfigMgrSiteCode)";
                'SQLSSBPort' = '1433'
            }
            $hashCloud = @{
                'CloudConnector' = "1";
                'CloudConnectorServer' = "$($VMName).$($DomainFQDN)"
            }
            $hashSCOpts = @{
            }
            $hashHierarchy = @{
    
            }
            $HASHCMInstallINI = @{
                'Identification' = $hashident;
                'Options' = $hashoptions;
                'SQLConfigOptions' = $hashSQL;
                'CloudConnectorOptions' = $hashCloud;
                'SystemCenterOptions' = $hashSCOpts;
                'HierarchyExpansionOption' = $hashHierarchy
            }
            $CMInstallINI = ""
            Foreach ($i in $HASHCMInstallINI.keys) {
                $CMInstallINI += "[$i]`r`n"
                foreach ($j in $($HASHCMInstallINI[$i].keys | Sort-Object)) {
                    $CMInstallINI += "$j=$($HASHCMInstallINI[$i][$j])`r`n"
                }
                $CMInstallINI += "`r`n"
            }
            
            write-logentry -message "CM install ini for $cmname is: $cminstallini" -type information
            Invoke-Command -Session $cmsession -ScriptBlock {param($ini) new-item -ItemType file -Path c:\CMinstall.ini -Value $INI -Force} -ArgumentList $CMInstallINI | out-null
            invoke-command -Session $cmsession -scriptblock {start-process -filepath "c:\data\sccm\smssetup\bin\x64\extadsch.exe" -wait}
            write-logentry -message "AD Schema has been exteded for SCCM on $domainfqdn"
            write-logentry -message "SCCM installation process has started on $cmname this will take some time so grab a coffee" -type information
            Invoke-Command -Session $cmsession -ScriptBlock {Start-Process -FilePath "C:\DATA\SCCM\SMSSETUP\bin\x64\setup.exe" -ArgumentList "/script c:\CMinstall.ini"}
            while ((invoke-command -Session $cmsession -ScriptBlock {get-content C:\ConfigMgrSetup.log | Select-Object -last 1 | Where-Object {$_ -like 'ERROR: Failed to ExecuteConfigureServiceBrokerSp*'}}).count -eq 0) {
                start-sleep -seconds 15
            }
            Start-Sleep -Seconds 30
            while ((invoke-command -Session $cmsession -ScriptBlock {get-content C:\ConfigMgrSetup.log | Select-Object -last 1 | Where-Object {$_ -like 'ERROR: Failed to ExecuteConfigureServiceBrokerSp*'}}).count -eq 0) {
                start-sleep -seconds 15
            }
            Invoke-Command -Session $cmsession -ScriptBlock {Get-Process setupwpf | Stop-Process -Force}
            write-logentry -message "SCCM has been installed on $cmname" -type information
            $cmsession | remove-PSSession
            write-logentry -message "Powershell Direct session for $($domuser.username) on $cmname has been disposed" -type information

    
    Invoke-Pester -TestName "CM"
    Write-Output "CM Server Completed: $(Get-Date)"
    write-logentry -message "SCCM Server installation has completed on $cmname" -type information
    
}