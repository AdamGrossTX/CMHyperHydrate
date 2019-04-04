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

    $VM = Get-VM -Name $VMName


    if((Get-VM -Name $VMName).State -eq "Running") {
        Stop-VM -Name $VMName
    }

    $Disk = (Mount-VHD -Path $VMPath -Passthru | Get-Disk | Get-Partition | Where-Object {$_.type -eq 'Basic'}).DriveLetter
    $ConfigMgrPath = "$($disk):$VMDataPath\ConfigMgr"
    $ADKPath = "$($disk):$VMDataPath\adk"
    $ADKWinPEPath = "$($disk):$VMDataPath\adkwinpe"

    Copy-Item -Path $ConfigMgrMedia -Destination $ConfigMgrPath -Recurse -ErrorAction SilentlyContinue
    Copy-Item -Path $ADKMedia -Destination $ADKPath -Recurse -ErrorAction SilentlyContinue
    Copy-Item -Path $ADKWinPEMedia -Destination $ADKWinPEPath -Recurse -ErrorAction SilentlyContinue
    Dismount-VHD $VMPath

    $ConfigMgrPath = "C:$VMDataPath\ConfigMgr"
    $ADKPath = "C:$VMDataPath\adk"
    $ADKWinPEPath = "C:$VMDataPath\adkwinpe"
    

    #region INIFile
    if ($ConfigMgrVersion -eq "Prod") {
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
            'SiteCode' = "$($ConfigMgrSiteCode)";
            'SiteName' = "$($SiteName)";
            'SMSInstallDir' = 'C:\Program Files\Microsoft Configuration Manager';
            'SDKServer' = "$($VMName).$($DomainFQDN)";
            'RoleCommunicationProtocol' = "HTTPorHTTPS";
            'ClientsUsePKICertificate' = "0";
            'PrerequisiteComp' = "$($ConfigMgrPrereqsPreDL)";
            'PrerequisitePath' = "$($ConfigMgrPath)\Prereqs";
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
            'SQLServerPort' = '1433';
            'DatabaseName' = "CM_$($ConfigMgrSiteCode)";
            'SQLSSBPort' = '4022'
            'SQLDataFilePath' = "$($sqlsettings.DefaultFile)";
            'SQLLogFilePath' = "$($sqlsettings.DefaultLog)"
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
    #endregion

    #region ScriptBlocks

    $SBSQLSettings = {
        [reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null
        (new-object ('Microsoft.SqlServer.Management.Smo.Server') $env:COMPUTERNAME).Settings | Select-Object DefaultFile, Defaultlog
    }

    $SBAddFeatures = {
        Add-WindowsFeature BITS, BITS-IIS-Ext, BITS-Compact-Server, Web-Server, Web-WebServer, Web-Common-Http, Web-Default-Doc, Web-Dir-Browsing, Web-Http-Errors, Web-Static-Content, Web-Http-Redirect, Web-App-Dev, Web-Net-Ext, Web-Net-Ext45, Web-ASP, Web-Asp-Net, Web-Asp-Net45, Web-CGI, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Health, Web-Http-Logging, Web-Custom-Logging, Web-Log-Libraries, Web-Request-Monitor, Web-Http-Tracing, Web-Performance, Web-Stat-Compression, Web-Security, Web-Filtering, Web-Basic-Auth, Web-IP-Security, Web-Url-Auth, Web-Windows-Auth, Web-Mgmt-Tools, Web-Mgmt-Console, Web-Mgmt-Compat, Web-Metabase, Web-Lgcy-Mgmt-Console, Web-Lgcy-Scripting, Web-WMI, Web-Scripting-Tools, Web-Mgmt-Service, RDC;
    }
    $SBADK = {
        param($path)
        $SetupSwitches = "/Features OptionId.DeploymentTools OptionId.ImagingAndConfigurationDesigner OptionId.ICDConfigurationDesigner OptionId.UserStateMigrationTool /norestart /quiet /ceip off"
        Start-Process -FilePath "$($path)\adksetup.exe" -ArgumentList $SetupSwitches -NoNewWindow -Wait
    }

    $SBWinPEADK = {
        param($path)
        $SetupSwitches = "/Features OptionId.WindowsPreinstallationEnvironment /norestart /quiet /ceip off"    
        Start-Process -FilePath "$($path)\adkwinpesetup.exe" -ArgumentList $SetupSwitches -NoNewWindow -Wait
        Restart-Computer -Force
    }

    $SBCreateINI = {
        param($INI,$CMMedia) 
        New-Item -ItemType File -Path "$($CMMedia)\CMinstall.ini" -Value $INI -Force
    }

    $SBExtSchema = {
        param($CMMedia)
        Start-Process -FilePath "$($CMMedia)\SMSSETUP\bin\x64\extadsch.exe" -wait
    }

    $SBInstallCM = {
        param($CMMedia)
        Start-Process -FilePath "$($CMMedia)\SMSSETUP\bin\x64\setup.exe" -ArgumentList "/script $($CMMedia)\CMinstall.ini" -Wait
    }

    $SBCMExtras = {
        param($sitecode, $DomainDN)
        import-module "$(($env:SMS_ADMIN_UI_PATH).remove(($env:SMS_ADMIN_UI_PATH).Length -4, 4))ConfigurationManager.psd1"; 
        if($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $env:COMPUTERNAME}
        Set-Location "$((Get-PSDrive -PSProvider CMSite).name)`:"; 
        #New-CMBoundary -Type IPSubnet -Value "$($ipsub)/24" -name $Subnetname;
        New-CMBoundary -DisplayName "DefaultBoundary" -BoundaryType ADSite -Value "Default-First-Site-Name"
        New-CMBoundaryGroup -name "DefaultBoundary" -DefaultSiteCode "$((Get-PSDrive -PSProvider CMSite).name)";
        Add-CMBoundaryToGroup -BoundaryName "DefaultBoundary" -BoundaryGroupName "DefaultBoundary";
        $Schedule = New-CMSchedule -RecurInterval Minutes -Start "2012/10/20 00:00:00" -End "2013/10/20 00:00:00" -RecurCount 10;
        Set-CMDiscoveryMethod -ActiveDirectorySystemDiscovery -SiteCode $sitecode -Enabled $True -EnableDeltaDiscovery $True -PollingSchedule $Schedule -AddActiveDirectoryContainer "LDAP://$domaindn" -Recursive;
        Get-CMDevice | Where-Object {$_.ADSiteName -eq "Default-First-Site-Name"} | Install-CMClient -IncludeDomainController $true -AlwaysInstallClient $true -SiteCode $sitecode;
    }
    #EndRegion
    
    $SQLSettings = Invoke-LabCommand -ScriptBlock $SBSQLSettings -MessageText "SBSQLSettings" -VMID $VM.VMID | Out-Null
    Invoke-LabCommand -ScriptBlock $SBAddFeatures -MessageText "SBAddFeatures" -VMID $VM.VMID | Out-Null
    Invoke-LabCommand -ScriptBlock $SBADK -ArgumentList $ADKPath -MessageText "SBADK" -VMID $VM.VMID
    Invoke-LabCommand -ScriptBlock $SBWinPEADK -ArgumentList $ADKWinPEPath -MessageText "SBWinPEADK" -VMID $VM.VMID
    Invoke-LabCommand -ScriptBlock $SBCreateINI -ArgumentList $CMInstallINI,$ConfigMgrPath -MessageText "SBCreateINI" -VMID $VM.VMID | Out-Null
    Invoke-LabCommand -ScriptBlock $SBExtSchema -ArgumentList $ConfigMgrPath -MessageText "SBExtSchema" -VMID $VM.VMID | Out-Null
    Invoke-LabCommand -ScriptBlock $SBInstallCM -ArgumentList $ConfigMgrPath -MessageText "SBInstallCM" -VMID $VM.VMID | out-Null
    Invoke-LabCommand -ScriptBlock $SBCMExtras -ArgumentList $ConfigMgrSiteCode, ("dc=" + ($DomainFQDN.Split('.') -join ",dc="))  -MessageText "SBCMExtras" -VMID $VM.VMID | Out-Null

    #Checkpoint-VM -VM $VM -SnapshotName "ConfigMgr Configuration Complete"
        
}