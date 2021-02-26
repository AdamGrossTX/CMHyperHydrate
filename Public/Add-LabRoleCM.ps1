function Add-LabRoleCM {
    [cmdletBinding()]
    param (

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $VMName = $Script:VMConfig.VMName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $VMWinName = $Script:VMConfig.VMWinName,

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
        $DomainNetBiosName = $Script:labEnv.EnvNetBios,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $DomainFQDN = $Script:labEnv.EnvFQDN,

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
        $DomainAdminCreds = $Script:base.DomainAdminCreds,

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

    #region Standard Setup
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
        
        Start-Transcript $_LogFile -Append -NoClobber;
        Write-Host "Logging to $_LogFile";
        
        #region Do Stuff Here
    }
        
    $SCScriptTemplateEnd = {
        #endregion
        Stop-Transcript
    }
    
    #endregion

    #region Copy media to VM
    $VM = Get-VM -Name $VMName
    if ((Get-VM -Name $VMName).State -eq "Running") {
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
    #endregion

    
    #region Script Blocks
    $SBInstallSQLNativeClientParams = @"
        param
        (
            `$_LogPath = "$($LogPath)",
            `$_ConfigMgrPath = "C:\Data\ConfigMgr"
        )
"@

    $SBInstallSQLNativeClient = {
        start-process -FilePath "C:\windows\system32\msiexec.exe" -ArgumentList "/I $($_ConfigMgrPath)\Prereqs\sqlncli.msi /QN REBOOT=ReallySuppress /l*v $($ConfigMgrPath)\SQLLog.log" -Wait
    }

    $SBGetSQLSettings = {
        [reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null
        (new-object ('Microsoft.SqlServer.Management.Smo.Server') $env:COMPUTERNAME).Settings | Select-Object DefaultFile, Defaultlog
    }

    $SBAddFeatures = {
        Add-WindowsFeature BITS, BITS-IIS-Ext, BITS-Compact-Server, Web-Server, Web-WebServer, Web-Common-Http, Web-Default-Doc, Web-Dir-Browsing, Web-Http-Errors, Web-Static-Content, Web-Http-Redirect, Web-App-Dev, Web-Net-Ext, Web-Net-Ext45, Web-ASP, Web-Asp-Net, Web-Asp-Net45, Web-CGI, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Health, Web-Http-Logging, Web-Custom-Logging, Web-Log-Libraries, Web-Request-Monitor, Web-Http-Tracing, Web-Performance, Web-Stat-Compression, Web-Security, Web-Filtering, Web-Basic-Auth, Web-IP-Security, Web-Url-Auth, Web-Windows-Auth, Web-Mgmt-Tools, Web-Mgmt-Console, Web-Mgmt-Compat, Web-Metabase, Web-Lgcy-Mgmt-Console, Web-Lgcy-Scripting, Web-WMI, Web-Scripting-Tools, Web-Mgmt-Service, RDC;
    }

    $SBADKParams = @"
        param
        (
            `$_LogPath = "$($LogPath)",
            `$_ADKPath = "C:\Data\ADK"
        )
"@
    $SBADK = {
        $_SetupSwitches = "/Features OptionId.DeploymentTools OptionId.ImagingAndConfigurationDesigner OptionId.ICDConfigurationDesigner OptionId.UserStateMigrationTool /norestart /quiet /ceip off"
        Start-Process -FilePath "$($_ADKPath)\adksetup.exe" -ArgumentList $_SetupSwitches -NoNewWindow -Wait
    }

    $SBWinPEADKParams = @"
        param
        (
            `$_LogPath = "$($LogPath)",
            `$_ADKWinPEPath = "C:\Data\ADKWinPE"
        )
"@
    $SBWinPEADK = {
        $_SetupSwitches = "/Features OptionId.WindowsPreinstallationEnvironment /norestart /quiet /ceip off"    
        Start-Process -FilePath "$($_ADKWinPEPath)\adkwinpesetup.exe" -ArgumentList $_SetupSwitches -NoNewWindow -Wait
        Restart-Computer -Force
    }

    $SBExtSchemaParams = @"
        param
        (
            `$_LogPath = "$($LogPath)",
            `$_ConfigMgrPath = "C:\Data\ConfigMgr"
        )
"@
    $SBExtSchema = {
        Start-Process -FilePath "$($_ConfigMgrPath)\SMSSETUP\bin\x64\extadsch.exe" -wait
    }

    $SBInstallCMParams = @"
        param
        (
            `$_LogPath = "$($LogPath)",
            `$_ConfigMgrPath = "C:\Data\ConfigMgr",
            `$_ClientScriptPath = "$($ClientScriptPath)"
        )
"@
    $SBInstallCM = {
        Start-Process -FilePath "$($_ConfigMgrPath)\SMSSETUP\bin\x64\setup.exe" -ArgumentList "/script $($_ClientScriptPath)\CMinstall.ini" -Wait
    }

    $SBCMExtrasParams = @"
        param
        (
            `$_LogPath = "$($LogPath)",
            `$_sitecode = "$($sitecode)",
            `$_DomainDN = "$($DomainDN)",
        )
"@
    $SBCMExtras = {
        import-module "$(($env:SMS_ADMIN_UI_PATH).remove(($env:SMS_ADMIN_UI_PATH).Length -4, 4))ConfigurationManager.psd1"; 
        if ($null -eq (Get-PSDrive -Name $_SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {New-PSDrive -Name $_SiteCode -PSProvider CMSite -Root $env:COMPUTERNAME}
        Set-Location "$((Get-PSDrive -PSProvider CMSite).name)`:"; 
        #New-CMBoundary -Type IPSubnet -Value "$($ipsub)/24" -name $Subnetname;
        New-CMBoundary -DisplayName "DefaultBoundary" -BoundaryType ADSite -Value "Default-First-Site-Name"
        New-CMBoundaryGroup -name "DefaultBoundary" -DefaultSiteCode "$((Get-PSDrive -PSProvider CMSite).name)";
        Add-CMBoundaryToGroup -BoundaryName "DefaultBoundary" -BoundaryGroupName "DefaultBoundary";
        $_Schedule = New-CMSchedule -RecurInterval Minutes -Start "2012/10/20 00:00:00" -End "2013/10/20 00:00:00" -RecurCount 10;
        Set-CMDiscoveryMethod -ActiveDirectorySystemDiscovery -SiteCode $_sitecode -Enabled $True -EnableDeltaDiscovery $True -PollingSchedule $_Schedule -AddActiveDirectoryContainer "LDAP://$_domaindn" -Recursive;
        Get-CMDevice | Where-Object {$_.ADSiteName -eq "Default-First-Site-Name"} | Install-CMClient -IncludeDomainController $true -AlwaysInstallClient $true -SiteCode $_sitecode;
    }
    

    $InstallSQLNativeClient += $SBInstallSQLNativeClientParams
    $InstallSQLNativeClient += $SBScriptTemplateBegin.ToString()
    $InstallSQLNativeClient += $SBInstallSQLNativeClient.ToString()
    $InstallSQLNativeClient += $SCScriptTemplateEnd.ToString()
    $InstallSQLNativeClient | Out-File "$($LabScriptPath)\InstallSQLNativeClient.ps1"

    $GetSQLSettings += $SBDefaultParams
    $GetSQLSettings += $SBScriptTemplateBegin.ToString()
    $GetSQLSettings += $SBGetSQLSettings.ToString()
    $GetSQLSettings += $SCScriptTemplateEnd.ToString()
    $GetSQLSettings | Out-File "$($LabScriptPath)\GetSQLSettings.ps1"

    $AddFeatures += $SBDefaultParams
    $AddFeatures += $SBScriptTemplateBegin.ToString()
    $AddFeatures += $SBAddFeatures.ToString()
    $AddFeatures += $SCScriptTemplateEnd.ToString()
    $AddFeatures | Out-File "$($LabScriptPath)\AddFeatures.ps1"

    $ADK += $SBADKParams
    $ADK += $SBScriptTemplateBegin.ToString()
    $ADK += $SBADK.ToString()
    $ADK += $SCScriptTemplateEnd.ToString()
    $ADK | Out-File "$($LabScriptPath)\ADK.ps1"

    $WinPEADK += $SBWinPEADKParams
    $WinPEADK += $SBScriptTemplateBegin.ToString()
    $WinPEADK += $SBWinPEADK.ToString()
    $WinPEADK += $SCScriptTemplateEnd.ToString()
    $WinPEADK | Out-File "$($LabScriptPath)\WinPEADK.ps1"

    $ExtSchema += $SBExtSchemaParams
    $ExtSchema += $SBScriptTemplateBegin.ToString()
    $ExtSchema += $SBExtSchema.ToString()
    $ExtSchema += $SCScriptTemplateEnd.ToString()
    $ExtSchema | Out-File "$($LabScriptPath)\ExtSchema.ps1"

    $InstallCM += $SBInstallCMParams
    $InstallCM += $SBScriptTemplateBegin.ToString()
    $InstallCM += $SBInstallCM.ToString()
    $InstallCM += $SCScriptTemplateEnd.ToString()
    $InstallCM | Out-File "$($LabScriptPath)\InstallCM.ps1"

    $CMExtras += $SBCMExtrasParams
    $CMExtras += $SBScriptTemplateBegin.ToString()
    $CMExtras += $SBCMExtras.ToString()
    $CMExtras += $SCScriptTemplateEnd.ToString()
    $CMExtras | Out-File "$($LabScriptPath)\CMExtras.ps1"
    
    $Scripts = Get-Item -Path "$($LabScriptPath)\*.*"

    #endregion

    $VM = Get-VM -Name $VMName
    $VM | Start-VM
    start-sleep 10

    while (-not (Invoke-Command -VMName $VMName -Credential $DomainAdminCreds {Get-Process "LogonUI" -ErrorAction SilentlyContinue;})) {Start-Sleep -seconds 5}

    foreach ($Script in $Scripts) {
        Copy-VMFile -VM $VM -SourcePath $Script.FullName -DestinationPath "$($ClientScriptPath)\$($Script.Name)" -CreateFullPath -FileSource Host -Force
    }

    Invoke-LabCommand -FilePath "$($LabScriptPath)\InstallSQLNativeClient.ps1" -MessageText "InstallSQLNativeClient" -SessionType Domain -VMID $VM.VMId
    $SQLSettings = Invoke-LabCommand -FilePath "$($LabScriptPath)\GetSQLSettings.ps1" -MessageText "GetSQLSettings" -SessionType Domain -VMID $VM.VMId

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
            'SDKServer' = "$($VMWinName).$($DomainFQDN)";
            'RoleCommunicationProtocol' = "HTTPorHTTPS";
            'ClientsUsePKICertificate' = "0";
            'PrerequisiteComp' = "$($ConfigMgrPrereqsPreDL)";
            'PrerequisitePath' = "$($ConfigMgrPath)\Prereqs";
            'ManagementPoint' = "$($VMWinName).$($DomainFQDN)";
            'ManagementPointProtocol' = "HTTP";
            'DistributionPoint' = "$($VMWinName).$($DomainFQDN)";
            'DistributionPointProtocol' = "HTTP";
            'DistributionPointInstallIIS' = "0";
            'AdminConsole' = "1";
            'JoinCEIP' = "0";
        }

        $hashSQL = @{
            'SQLServerName' = "$($VMWinName).$($DomainFQDN)";
            'SQLServerPort' = '1433';
            'DatabaseName' = "CM_$($ConfigMgrSiteCode)";
            'SQLSSBPort' = '4022'
            'SQLDataFilePath' = "$($sqlsettings.DefaultFile)";
            'SQLLogFilePath' = "$($sqlsettings.DefaultLog)"
        }

        $hashCloud = @{
            'CloudConnector' = "1";
            'CloudConnectorServer' = "$($VMWinName).$($DomainFQDN)"
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
        foreach ($i in $HASHCMInstallINI.keys) {
            $CMInstallINI += "[$i]`r`n"
            foreach ($j in $($HASHCMInstallINI[$i].keys | Sort-Object)) {
                $CMInstallINI += "$j=$($HASHCMInstallINI[$i][$j])`r`n"
            }
        $CMInstallINI += "`r`n"
    }
    #endregion

    $CreateINI += $CMInstallINI.ToString()
    $CreateINI | Out-File "$($LabScriptPath)\CMinstall.ini" -Force
    Copy-VMFile -VM $VM -SourcePath "$($LabScriptPath)\CMinstall.ini" -DestinationPath "$($ClientScriptPath)\CMinstall.ini" -CreateFullPath -FileSource Host -Force

    #TODO https://systemmanagement.ro/2018/08/13/install-windowsfeature-web-net-ext-failed-source-files-could-not-be-found/
    Invoke-LabCommand -FilePath "$($LabScriptPath)\AddFeatures.ps1" -MessageText "AddFeatures" -SessionType Domain -VMID $VM.VMId
    Read-Host -Prompt "Fix Features before Proceeding"

    Invoke-LabCommand -FilePath "$($LabScriptPath)\ADK.ps1" -MessageText "ADK" -SessionType Domain -VMID $VM.VMId
    Invoke-LabCommand -FilePath "$($LabScriptPath)\WinPEADK.ps1" -MessageText "WinPEADK" -SessionType Domain -VMID $VM.VMId
    Invoke-LabCommand -FilePath "$($LabScriptPath)\ExtSchema.ps1" -MessageText "ExtSchema" -SessionType Domain -VMID $VM.VMId
    Invoke-LabCommand -FilePath "$($LabScriptPath)\InstallCM.ps1" -MessageText "InstallCM" -SessionType Domain -VMID $VM.VMId
    Invoke-LabCommand -FilePath "$($LabScriptPath)\CMExtras.ps1" -MessageText "CMExtras" -SessionType Domain -VMID $VM.VMId

    #Checkpoint-VM -VM $VM -SnapshotName "ConfigMgr Configuration Complete"

    Write-Host "ConfigMgr Configuration Complete!"
        
}