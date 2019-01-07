Function Add-LabCMRole {
    [cmdletBinding()]
    param(

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $VMName = $Script:VMConfig.VMName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $VMPath = ("$($Script:VMConfig.VMHDPath)\$($Script:VMConfig.VMHDName)"),
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ConfigMgrMedia = $Script:VMConfig.ConfigMgrMediaPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ADKMedia = $Script:Base.PathADK,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ADKWinPEMedia = $Script:Base.PathADKWinPE,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $DomainNetBiosName = $Script:Env.EnvNetBios,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $DomainFQDN = $Script:Env.EnvFQDN,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ConfigMgrSiteCode = $Script:VMConfig.CMSiteCode,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("Prod","TP")]
        [string]
        $ConfigMgrVersion = $Script:VMConfig.CMVersion,

        [Parameter()]
        [int]
        $ConfigMgrPrereqsPreDL = $Script:VMConfig.CMPreReqPreDL,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ConfigMgrPrereqsPath = $Script:VMConfig.ConfigMgrPrereqPath,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $VMDataPath = $Script:Base.VMDataPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [pscredential]
        $DomainAdminCreds = $Script:base.DomainAdminCreds  
    )

        if((Get-VM -Name $VMName).State -eq "Running") {
            Stop-VM -Name $VMName
        }


       
        $Disk = (Mount-VHD -Path $VMPath -Passthru | Get-Disk | Get-Partition | Where-Object {$_.type -eq 'Basic'}).DriveLetter
        $ConfigMgrPath = "$($disk):$VMDataPath\ConfigMgr"
        $ADKPath = "$($disk):$VMDataPath\adk"
        $ADKWinPEPath = "$($disk):$VMDataPath\adkwinpe"


        #write-logentry -message "$cmvhdx has been mounted to allow for file copy to $disk" -type information
        Copy-Item -Path $ConfigMgrMedia -Destination $ConfigMgrPath -Recurse
        #write-logentry -message "SCCM Media copied to $disk`:\data\SCCM" -type information
        Copy-Item -Path $ADKMedia -Destination $ADKPath -Recurse
        #write-logentry -message "ADK Media copied to $disk`:\data\adk" -type information
        Copy-Item -Path $ADKWinPEMedia -Destination $ADKWinPEPath -Recurse
        #write-logentry -message "ADK Media copied to $disk`:\data\adk" -type information
        #Copy-Item -Path $SQLMedia -Destination "$($disk):\data\SQL" -Recurse
        #write-logentry -message "ADK Media copied to $disk`:\data\adk" -type information
        Dismount-VHD $VMPath

        if((Get-VM -Name $VMName).State -eq "Off") {
            Start-VM -Name $VMName
        }

        while ((Invoke-Command -VMName $VMName -Credential $DomainAdminCreds {"Test"} -ErrorAction SilentlyContinue) -ne "Test") {Start-Sleep -Seconds 5}
        $PSSessionDomain = New-PSSession -VMName $VMName -Credential $DomainAdminCreds

        $SBAddFeatures = {
            Add-WindowsFeature BITS, BITS-IIS-Ext, BITS-Compact-Server, Web-Server, Web-WebServer, Web-Common-Http, Web-Default-Doc, Web-Dir-Browsing, Web-Http-Errors, Web-Static-Content, Web-Http-Redirect, Web-App-Dev, Web-Net-Ext, Web-Net-Ext45, Web-ASP, Web-Asp-Net, Web-Asp-Net45, Web-CGI, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Health, Web-Http-Logging, Web-Custom-Logging, Web-Log-Libraries, Web-Request-Monitor, Web-Http-Tracing, Web-Performance, Web-Stat-Compression, Web-Security, Web-Filtering, Web-Basic-Auth, Web-IP-Security, Web-Url-Auth, Web-Windows-Auth, Web-Mgmt-Tools, Web-Mgmt-Console, Web-Mgmt-Compat, Web-Metabase, Web-Lgcy-Mgmt-Console, Web-Lgcy-Scripting, Web-WMI, Web-Scripting-Tools, Web-Mgmt-Service, RDC;
        }
        Invoke-Command -session $PSSessionDomain -ScriptBlock $SBAddFeatures | Out-Null

        #region Install ADK
        #if (((Invoke-Pester -TestName "CM" -PassThru -show None).TestResult | Where-Object {$_.name -match "CM ADK installed"}).result -notmatch "Passed") {
        #    write-logentry -message "ADK is installing on $cmname" -type information

       
        $ConfigMgrPath = "C:$VMDataPath\ConfigMgr"
        $ADKPath = "C:$VMDataPath\adk"
        $ADKWinPEPath = "C:$VMDataPath\adkwinpe"

        $SBADK = {
            param($path)
            $SetupSwitches = "/Features OptionId.DeploymentTools OptionId.ImagingAndConfigurationDesigner OptionId.ICDConfigurationDesigner OptionId.UserStateMigrationTool /norestart /quiet /ceip off"
            Start-Process -FilePath "$($path)\adksetup.exe" -ArgumentList $SetupSwitches -NoNewWindow -Wait
        }

        $SBWinPEADK = {
            param($path)
            $SetupSwitches = "/Features OptionId.WindowsPreinstallationEnvironment /norestart /quiet /ceip off"    
            Start-Process -FilePath "$($path)\adkwinpesetup.exe" -ArgumentList $SetupSwitches -NoNewWindow -Wait
        }

        Invoke-Command -Session $PSSessionDomain -ScriptBlock $SBADK -ArgumentList $ADKPath
        Invoke-Command -Session $PSSessionDomain -ScriptBlock $SBWinPEADK -ArgumentList $ADKWinPEPath
        Invoke-Command -Session $PSSessionDomain -ScriptBlock {Restart-Computer -Force}
        
        #EndRegion
        
        

        #Install ConfigMgr
        #    write-logentry -message "ADK is installed on $cmname" -type information
        #}
        #if (((Invoke-Pester -TestName "CM" -PassThru -show None).TestResult | Where-Object {$_.name -match "CM SCCM Installed"}).result -notmatch "Passed") {
        #    $cmOSName = Invoke-Command -Session $PSSessionDomain -ScriptBlock {$env:COMPUTERNAME}
        #    write-logentry -message "Host name for $cmname is: $cmosname"
            
            if ($ConfigMgrVersion -eq "CB") {
                $HashIdent = @{'action' = 'InstallPrimarySite'
                }
                $SiteName = "Current Branch $($ConfigMgrSiteCode)"
            }
            else {
                $HashIdent = @{
                    'action' = 'InstallPrimarySite';
                    'Preview' = "1"
                }
                $SiteName = "Tech Preview $($ConfigMgrSiteCode)"
            }
            $HashOptions = @{
                'ProductID' = 'EVAL';
                'SiteCode' = $($ConfigMgrSiteCode);
                'SiteName' = "$($SiteName)";
                'SMSInstallDir' = 'C:\Program Files\Microsoft Configuration Manager';
                'SDKServer' = "$($VMName).$($DomainFQDN)";
                'RoleCommunicationProtocol' = "HTTPorHTTPS";
                'ClientsUsePKICertificate' = "0";
                'PrerequisiteComp' = "$($ConfigMgrPrereqsPreDL)";
                'PrerequisitePath' = "$($ConfigMgrPrereqsPath)";
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
            

            $SBCreateINI = {
                param($INI) 
                New-Item -ItemType File -Path "$($CMMedia)\CMinstall.ini" -Value $INI -Force
            }

            $SBExtSchema = {
                param($CMMedia)
                Start-Process -FilePath "$($CMMedia)\SMSSETUP\bin\x64\extadsch.exe" -wait
            }

            $SBInstallCM = {
                param($CMMedia)
                Start-Process -FilePath "$($CMMedia)\SMSSETUP\bin\x64\setup.exe" -ArgumentList "/script $($CMMedia)\CMinstall.ini"
            }

            #write-logentry -message "CM install ini for $cmname is: $cminstallini" -type information
            Invoke-Command -Session $PSSessionDomain -ScriptBlock $SBCreateINI -ArgumentList $CMInstallINI | Out-Null
            Invoke-Command -Session $PSSessionDomain -ScriptBlock $SBExtSchema -ArgumentList $ConfigMgrMedia | Out-Null
            #write-logentry -message "AD Schema has been exteded for SCCM on $domainfqdn"
            #write-logentry -message "SCCM installation process has started on $cmname this will take some time so grab a coffee" -type information
            Invoke-Command -Session $PSSessionDomain -ScriptBlock $SBInstallCM -ArgumentList $ConfigMgrMedia | Out-Null
            while ((invoke-command -Session $PSSessionDomain -ScriptBlock {get-content C:\ConfigMgrSetup.log | Select-Object -last 1 | Where-Object {$_ -like 'ERROR: Failed to ExecuteConfigureServiceBrokerSp*'}}).count -eq 0) {
                start-sleep -seconds 15
            }
            Start-Sleep -Seconds 30
            while ((invoke-command -Session $PSSessionDomain -ScriptBlock {get-content C:\ConfigMgrSetup.log | Select-Object -last 1 | Where-Object {$_ -like 'ERROR: Failed to ExecuteConfigureServiceBrokerSp*'}}).count -eq 0) {
                start-sleep -seconds 15
            }
            Invoke-Command -Session $PSSessionDomain -ScriptBlock {Get-Process setupwpf | Stop-Process -Force}
            #write-logentry -message "SCCM has been installed on $cmname" -type information
            $PSSessionDomain | Remove-PSSession
            #write-logentry -message "Powershell Direct session for $($domuser.username) on $cmname has been disposed" -type information

    
    #Invoke-Pester -TestName "CM"
    #Write-Output "CM Server Completed: $(Get-Date)"
    #write-logentry -message "SCCM Server installation has completed on $cmname" -type information
    
}