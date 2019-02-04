    Function Add-LabDCRole_orig {
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
            $DomainAdminCreds = $Script:base.DomainAdminCreds
        )
            ####TODO####
            ##Add custom default Gateway for DC when used with and without a RAAS Server

            #region Script Blocks
            $SBSetIPAndName = {
                param($InterfaceID, $IPSubNet, $IPAddress)
                New-NetIPAddress -InterfaceIndex "$($InterfaceID)" -AddressFamily IPv4 -IPAddress "$($IPAddress)" -PrefixLength 24 -DefaultGateway "$($IPSubNet)1";
                Set-DnsClientServerAddress -ServerAddresses ('127.0.0.1') -InterfaceIndex "$($InterfaceID)";
                Restart-Computer -Force;
            }
    
            $SBAddFeatures = {
                Install-WindowsFeature -Name DHCP, DNS, AD-Domain-Services -IncludeManagementTools;
            }
    
            $SBDCPromo = {
                param($FQDN, $Password)
                Install-ADDSForest -DomainName $FQDN -SafeModeAdministratorPassword $Password -confirm:$false -WarningAction SilentlyContinue;
            }
    
            $SBConfigureDHCP = {
                param($ServerName, $DomainFQDN, $IPAddress, $IPSubnet,[ipaddress]$ScopeID) 
                "netsh dhcp add securitygroups;"
                Restart-Service dhcpserver;
                Add-DhcpServerInDC -DnsName "$($ServerName).$($DomainFQDN)" -IPAddress "$($IPAddress)";
                Set-ItemProperty -Path registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ServerManager\Roles\12 -Name ConfigurationState -Value 2;
                Add-DhcpServerv4Scope -name "$($DomainFQDN)" -StartRange "$($IPSubnet)100" -EndRange "$($IPSubnet)150" -SubnetMask "255.255.255.0";
                Set-DhcpServerv4OptionValue -Router "$($IPSubnet)`1" -DNSDomain "$($DomainFQDN)" -DNSServer "$($IPAddress)" -ScopeId "$($ScopeID)"
            }

            $SBCreateLabDomain = {
                
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

            #endregion
   
            #region Non-Domain Actions
            $VMNics = Invoke-LabCommand -SessionType Local -ScriptBlock {Get-NetAdapter} -MessageText "VMNics"
            Invoke-LabCommand -SessionType Local -ScriptBlock $SBSetIPAndName -MessageText "SBSetIPAndName" -ArgumentList $VMNics.InterfaceIndex, $IPSubNet, $IPAddress | Out-Null
            Start-Sleep -seconds 10
            Invoke-LabCommand -SessionType Local -ScriptBlock $SBAddFeatures -MessageText "SBAddFeatures" | Out-Null
            Invoke-LabCommand -SessionType Local -ScriptBlock $SBDCPromo -MessageText "SBDCPromo" -ArgumentList $DomainFQDN, $DomainAdminCreds.Password | Out-Null
            Start-Sleep -seconds 300
            #endregion

            #There's a reboot here that takes forever Trying to handle it with the sleep above.
            #I think that disconnecting the NIC before this may help as well. Need test.
            #Or just a pause until it's back online then manually proceed.
            #region Domain Actions
            Invoke-LabCommand -ScriptBlock $SBConfigureDHCP -MessageText "SBConfigureDHCP" -ArgumentList $VMName, $DomainFQDN, $IPAddress, $IPSubNet, "$($IPSubnet)0" | Out-Null
            Invoke-LabCommand -ScriptBlock $SBCreateLabDomain -MessageText "SBCreateLabDomain"
            Start-Sleep -Seconds 60
            Invoke-LabCommand -ScriptBlock {Add-WindowsFeature -Name Adcs-Cert-Authority -IncludeManagementTools} -MessageText "Add-WindowsFeature"
            Invoke-LabCommand -ScriptBlock {Install-AdcsCertificationAuthority –CAType EnterpriseRootCA –KeyLength 2048 –HashAlgorithm SHA1 –CryptoProviderName "RSA#Microsoft Software Key Storage Provider" -ValidityPeriod Years -ValidityPeriodUnits 5 -Force -confirm:$false} -MessageText "Install-AdcsCertificationAuthority"
            #Invoke-LabCommand -ScriptBlock {Install-AdcsCertificationAuthority -CAType EnterpriseRootCa -CryptoProviderName "ECDSA_P256#Microsoft Software Key Storage Provider" -KeyLength 256 -HashAlgorithmName SHA256 -confirm:$false} -MessageText "Install-AdcsCertificationAuthority"
            #https://www.youtube.com/watch?time_continue=367&v=nChKKM9APAQ

            
            #endregion

            
        }        