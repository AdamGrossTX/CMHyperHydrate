function Add-LabRoleDC {
    [cmdletbinding()]
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
        $IPAddress = $VMConfig.VMIPAddress,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $IPSubNet = $LabEnvConfig.EnvIPSubnet,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $RRASMac = $LabEnvConfig.RRASMAC,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $RRASName = $LabEnvConfig.RRASName,
       
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $DomainFQDN = $LabEnvConfig.EnvFQDN,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [pscredential]
        $LocalAdminCreds = $BaseConfig.LocalAdminCreds,

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
    Write-Host "Starting Add-LabRoleDC" -ForegroundColor Cyan
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
    
    #region Script Blocks
    $SBSetDCIPParams = @"
        param
        (
            `$_LogPath = "$($LogPath)",
            `$_IPAddress = "$($IPAddress)",
            `$_DefaultGateway = "$($IPSubNet)1",
            `$_InterfaceID = (Get-NetAdapter).InterfaceIndex,
            `$_DNSAddress = ('127.0.0.1')
        )
"@
        
    $SBSetDCIP = {
        New-NetIPAddress -InterfaceIndex $_InterfaceID -AddressFamily IPv4 -IPAddress $_IPAddress -PrefixLength 24 -DefaultGateway $_DefaultGateway;
        Set-DnsClientServerAddress -ServerAddresses $_DNSAddress -InterfaceIndex $_InterfaceID;
        #Restart-Computer -Force;
    }

    $SBAddDCFeatures = {
        Install-WindowsFeature -Name DHCP, DNS, AD-Domain-Services -IncludeManagementTools;
    }

    $SBDCPromoParams = @"
        param
        (
            `$_LogPath = "$($LogPath)",
            `$_FQDN = "$($DomainFQDN)",
            `$_DomainAdminName = "$($LabEnvConfig.EnvNetBios)\Administrator",
            `$_DomainAdminPassword = "$($LabEnvConfig.EnvAdminPW)"
        )
"@

    $SBDCPromo = {
        $_Password = ConvertTo-SecureString -String $_DomainAdminPassword -AsPlainText -Force
        $_Creds = new-object -typename System.Management.Automation.PSCredential($_DomainAdminName,$_Password)
        Install-ADDSForest -DomainName $_FQDN -SafeModeAdministratorPassword $_Creds.Password -confirm:$false -WarningAction SilentlyContinue;
    }

    $SBConfigureDHCPParams = @"
        param
        (
            `$_LogPath = "$($LogPath)",
            `$_DomainFQDN = "$($DomainFQDN)",
            `$_ServerName = "$($VMName)", 
            `$_IPAddress = "$($IPAddress)", 
            `$_IPSubnet = "$($IPSubnet)",
            [ipaddress]`$_ScopeID = "$($IPSubnet)0",
            `$_RRASMAC = "$($RRASMAC)"
        )
"@

    $SBConfigureDHCP = {
        & netsh dhcp add securitygroups;
        Restart-Service dhcpserver;
        Restart-Service dhcpserver;
        start-sleep -seconds 60
        Add-DhcpServerInDC # -DnsName "$($_ServerName).$($_DomainFQDN)" -IPAddress $_IPAddress;
        Set-ItemProperty -Path registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ServerManager\Roles\12 -Name ConfigurationState -Value 2;
        Add-DhcpServerv4Scope -name $_DomainFQDN -StartRange "$($_IPSubnet)100" -EndRange "$($_IPSubnet)150" -SubnetMask "255.255.255.0";
        Set-DhcpServerv4OptionValue -Router "$($_IPSubnet)`1" -DNSDomain $_DomainFQDN -DNSServer $_IPAddress -ScopeId $_ScopeID
        Add-DhcpServerv4Reservation -IPAddress "$($_IPSubnet)`1" -ClientId $_RRASMAC -ScopeId "$($_IPSubnet)0" -Name "RRAS"
    }

    $SBCreateDCLabDomain = {
        Import-Module ActiveDirectory; 
        $root = (Get-ADRootDSE).defaultNamingContext; 
        if (-not ([adsi]::Exists("LDAP://CN=System Management,CN=System,$root"))) {
            $null = New-ADObject -Type Container -name "System Management" -Path "CN=System,$root" -Passthru
        }; 
        $acl = get-acl "ad:CN=System Management,CN=System,$root"; 
        New-ADGroup -name "SCCM Servers" -groupscope Global; 
        $objGroup = Get-ADGroup -filter {Name -eq "SCCM Servers"}; 
        $All = [System.DirectoryServices.ActiveDirectorySecurityInheritance]::SelfAndChildren; 
        $ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $objGroup.SID, "GenericAll", "Allow", $All; 
        $acl.AddAccessRule($ace); 
        Set-acl -aclobject $acl "ad:CN=System Management,CN=System,$root"
    }

    $SetDCIP += $SBSetDCIPParams
    $SetDCIP += $SBScriptTemplateBegin.ToString()
    $SetDCIP += $SBSetDCIP.ToString()
    $SetDCIP += $SCScriptTemplateEnd.ToString()
    $SetDCIP | Out-File "$($LabScriptPath)\SetDCIP.ps1"

    $AddDCFeatures += $SBDefaultParams
    $AddDCFeatures += $SBScriptTemplateBegin.ToString()
    $AddDCFeatures += $SBAddDCFeatures.ToString()
    $AddDCFeatures += $SCScriptTemplateEnd.ToString()
    $AddDCFeatures | Out-File "$($LabScriptPath)\AddDCFeatures.ps1"

    $DCPromo += $SBDCPromoParams
    $DCPromo += $SBScriptTemplateBegin.ToString()
    $DCPromo += $SBDCPromo.ToString()
    $DCPromo += $SCScriptTemplateEnd.ToString()
    $DCPromo | Out-File "$($LabScriptPath)\DCPromo.ps1"
    
    $ConfigureDHCP += $SBConfigureDHCPParams
    $ConfigureDHCP += $SBScriptTemplateBegin.ToString()
    $ConfigureDHCP += $SBConfigureDHCP.ToString()
    $ConfigureDHCP += $SCScriptTemplateEnd.ToString()
    $ConfigureDHCP | Out-File "$($LabScriptPath)\ConfigureDHCP.ps1"

    $CreateDCLabDomain += $SBDefaultParams
    $CreateDCLabDomain += $SBScriptTemplateBegin.ToString()
    $CreateDCLabDomain += $SBCreateDCLabDomain.ToString()
    $CreateDCLabDomain += $SCScriptTemplateEnd.ToString()
    $CreateDCLabDomain | Out-File "$($LabScriptPath)\CreateDCLabDomain.ps1"

    $Scripts = Get-Item -Path "$($LabScriptPath)\*.*"

    #endregion

    $VM = Get-VM -VM $VMName
    $VM | Start-VM
    start-sleep 10

    while (-not (Invoke-Command -VMName $VMName -Credential $LocalAdminCreds {Get-Process "LogonUI" -ErrorAction SilentlyContinue;})) {Start-Sleep -seconds 5}
    
    foreach ($Script in $Scripts) {
        Copy-VMFile -VM $VM -SourcePath $Script.FullName -DestinationPath "C:$($ScriptPath)\$($Script.Name)" -CreateFullPath -FileSource Host -Force
    }

    Invoke-LabCommand -FilePath "$($LabScriptPath)\SetDCIP.ps1" -MessageText "SetDCIP" -SessionType Local -VMID $VM.VMId
    $VM | Stop-VM -Force
    Invoke-LabCommand -FilePath "$($LabScriptPath)\AddDCFeatures.ps1" -MessageText "AddDCFeatures" -SessionType Local -VMID $VM.VMId
    Invoke-LabCommand -FilePath "$($LabScriptPath)\DCPromo.ps1" -MessageText "DCPromo" -SessionType Local -VMID $VM.VMId
    #Checkpoint-VM -VM $VM -SnapshotName "DC Promo Complete"
    #endregion
    start-sleep -seconds 360
    while (-not (Invoke-Command -VMName $VMName -Credential $DomainAdminCreds {Get-Process "LogonUI" -ErrorAction SilentlyContinue;})) {Start-Sleep -seconds 5}
    while ((Invoke-Command -VMName $VM.VMName -Credential $DomainAdminCreds {(get-command get-adgroup).count} -ErrorAction Continue) -ne 1) {Start-Sleep -Seconds 5}
    Invoke-LabCommand -FilePath "$($LabScriptPath)\ConfigureDHCP.ps1" -MessageText "ConfigureDHCP" -SessionType Domain -VMID $VM.VMId
    #Checkpoint-VM -VM $VM -SnapshotName "DHCP Configured"
    
    while ((Invoke-Command -VMName $VM.VMName -Credential $DomainAdminCreds {(get-command get-adgroup).count} -ErrorAction Continue) -ne 1) {Start-Sleep -Seconds 5}
    Invoke-LabCommand -FilePath "$($LabScriptPath)\CreateDCLabDomain.ps1" -MessageText "CreateDCLabDomain" -SessionType Domain -VMID $VM.VMId

    $VM | Stop-VM -Force
    Get-VM -VM $RRASName | Stop-VM -Force -Passthru | Start-VM
    $VM | Start-VM
    start-sleep 20
    
    Write-Host "DC Configuration Complete!"

    #Checkpoint-VM -VM $VM -SnapshotName "DC Configuration Complete"
        

}