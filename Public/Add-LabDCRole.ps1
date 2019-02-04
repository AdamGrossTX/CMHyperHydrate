Function Add-LabDCRole {

    [cmdletbinding()]
    Param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $VMName = $Script:VMConfig.VMName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $IPAddress = $Script:VMConfig.VMIPAddress,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $IPSubNet = $Script:Env.EnvIPSubnet,
       
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $DomainFQDN = $Script:Env.EnvFQDN,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [pscredential]
        $LocalAdminCreds = $Script:base.LocalAdminCreds,

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

    $LabScriptPath = "$($LabPath)$($Script:Base.VMScriptPath)"
    
    If(!(Test-Path -Path "$($LabScriptPath)" -ErrorAction SilentlyContinue))
    {
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
    If(!(Test-Path -Path $_LogPath -ErrorAction SilentlyContinue))
    {
        New-Item -Path $_LogPath -ItemType Directory -ErrorAction SilentlyContinue;
    }
    
    $_LogFile = "$($_LogPath)\Transcript.log";
    
    Start-Transcript $_LogFile;
    Write-Host "Logging to $_LogFile";
    
    #region Do Stuff Here
}
     
$SCScriptTemplateEnd = {
    #endregion

    Stop-Transcript
}
    

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
        `$_DomainAdminName = "$($Script:Env.EnvNetBios)\Administrator",
        `$_DomainAdminPassword = "$($Script:Env.EnvAdminPW)"
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
        [ipaddress]`$_ScopeID = "$($IPSubnet)0"
    )
"@

$SBConfigureDHCP = {
    & netsh dhcp add securitygroups;
    Restart-Service dhcpserver;
    Add-DhcpServerInDC -DnsName $_ServerName.$_DomainFQDN -IPAddress $_IPAddress;
    Set-ItemProperty -Path registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ServerManager\Roles\12 -Name ConfigurationState -Value 2;
    Add-DhcpServerv4Scope -name $_DomainFQDN -StartRange "$($_IPSubnet)100" -EndRange "$($_IPSubnet)150" -SubnetMask "255.255.255.0";
    Set-DhcpServerv4OptionValue -Router "$($_IPSubnet)`1" -DNSDomain $_DomainFQDN -DNSServer $_IPAddress -ScopeId $_ScopeID
}


$SBCreateDCLabDomain = {
    Import-Module ActiveDirectory; 
    $root = (Get-ADRootDSE).defaultNamingContext; 
    if (!([adsi]::Exists("LDAP://CN=System Management,CN=System,$root"))) 
        {
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

$SBInstallCA = {
    Add-WindowsFeature -Name Adcs-Cert-Authority -IncludeManagementTools;
    Install-AdcsCertificationAuthority -CAType EnterpriseRootCA -KeyLength 2048 -HashAlgorithm SHA1 -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" -ValidityPeriod Years -ValidityPeriodUnits 5 -Force -confirm:$false
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

        $InstallCA += $SBDefaultParams
        $InstallCA += $SBScriptTemplateBegin.ToString()
        $InstallCA += $SBInstallCA.ToString()
        $InstallCA += $SCScriptTemplateEnd.ToString()
        $InstallCA | Out-File "$($LabScriptPath)\InstallCA.ps1"

        #endregion

        #region Non-Domain Actions

        $VM = Get-VM -VM $VMName
        $VM | Start-VM
        $Scripts = Get-Item -Path "$($LabScriptPath)\*.*"
        Foreach($Script in $Scripts) {
            Copy-VMFile -VM $VM -SourcePath $Script.FullName -DestinationPath "C:$($ScriptPath)\$($Script.Name)" -CreateFullPath -FileSource Host -Force
        }

        $ClientScriptPath = "C:$($ScriptPath)\"

        Invoke-LabCommand -FilePath "$($LabScriptPath)\SetDCIP.ps1" -MessageText "SetDCIP" -SessionType Local -VMID $VM.VMId
        $VM | Stop-VM -Force
        Invoke-LabCommand -FilePath "$($LabScriptPath)\AddDCFeatures.ps1" -MessageText "AddDCFeatures" -SessionType Local -VMID $VM.VMId
        Invoke-LabCommand -FilePath "$($LabScriptPath)\DCPromo.ps1" -MessageText "DCPromo" -SessionType Local -VMID $VM.VMId
        #endregion

        #There's a reboot here that takes forever Trying to handle it with the sleep above.
        #I think that disconnecting the NIC before this may help as well. Need test.
        #Or just a pause until it's back online then manually proceed.
        #region Domain Actions
        
        Start-Sleep -seconds 120
        Do {
            Try { 

                $Session = New-PSSession -VMId $VM.VMid -Credential $Creds
                $Result = Invoke-Command -Session $Session -ScriptBlock {Get-Process "LogonUI" -ErrorAction SilentlyContinue}
                $Result
                }
                Catch{
                    Write-Warning "Not Connected. Retrying in 10 seconds."
                    Start-Sleep -Seconds 10
                }

        } until ($Connected -eq $True)

        Invoke-LabCommand -FilePath "$($LabScriptPath)\ConfigureDHCP.ps1" -MessageText "ConfigureDHCP" -SessionType Domain -VMID $VM.VMId
        Invoke-LabCommand -FilePath "$($LabScriptPath)\CreateDCLabDomain.ps1" -MessageText "CreateDCLabDomain" -SessionType Domain -VMID $VM.VMId
        Invoke-LabCommand -FilePath "$($LabScriptPath)\InstallCA.ps1" -MessageText "InstallCA" -SessionType Domain -VMID $VM.VMId
        $VM | Stop-VM -Force

        Write-Host "DC Configuration Complete!"

}