
    Function Add-LabDCRole {
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
            #Write-LogEntry -Message "DC Server Started: $(Get-Date)" -Type Information
    
            ####TODO####
            ##Add custom default Gateway for DC when used with and without a RAAS Server
            $SBSetIPAndName = {
                param($InterfaceID, $SubNet, $Octet, $ServerName)
                New-NetIPAddress -InterfaceIndex $InterfaceID -AddressFamily IPv4 -IPAddress $IPAddress -PrefixLength 24 -DefaultGateway "$($IPSubNet)1";
                Set-DnsClientServerAddress -ServerAddresses ('8.8.8.8') -InterfaceIndex $InterfaceID;
                Restart-Computer;
            }
    
            $SBAddFeatures = {
                Install-WindowsFeature -Name DHCP, DNS, AD-Domain-Services -IncludeManagementTools;
            }
    
            $SBDCPromo = {
                param($FQDN, $Password)
                Install-ADDSForest -DomainName $FQDN -SafeModeAdministratorPassword $LocalAdminCreds.Password -confirm:$false -WarningAction SilentlyContinue;
            }
    
            $SBConfigureDHCP = {
                param($ServerName, $DomainFQDN, $IPAddress) 
                "netsh dhcp add securitygroups;"
                Restart-Service dhcpserver;
                Add-DhcpServerInDC -DnsName "$($ServerName).$($DomainFQDN)" -IPAddress $IPAddress;
                Set-ItemProperty -Path registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ServerManager\Roles\12 -Name ConfigurationState -Value 2;
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
    
            if((Get-VM -Name $VMName).State -eq "Off") {
                Start-VM -Name $VMName
            }
    
            
                while ((Invoke-Command -VMName $VMName -Credential $LocalAdminCreds {"Test"} -ErrorAction SilentlyContinue) -ne "Test") {Start-Sleep -Seconds 5}
                $PSSession = New-PSSession -VMName $VMName -Credential $LocalAdminCreds
                #Write-LogEntry -Message "PowerShell Direct session for $($LocalAdminCreds.UserName) has been initated with DC Service named: $VMName" -Type Information
                $VMNics = Invoke-Command -VMName $VMName -Credential $LocalAdminCreds -ScriptBlock {Get-NetAdapter}
                #Write-LogEntry -Message "The following network adaptors $($VMNics -join ",") have been found on: $VMName" -Type Information
                #if (((Invoke-Pester -TestName "DC" -PassThru ).TestResult | Where-Object {$_.name -match "DC IP Address"}).result -notmatch "Passed") {
                    Invoke-Command -Session $PSSession -ScriptBlock $SBSetIPAndName -ArgumentList $VMNics.InterfaceIndex, $IPSubNet, $IPLastOctet, $VMName | Out-Null
                #    Write-LogEntry -Message "IP Address $ipsub`.10 has been assigned to $VMName" -Type Information
                #}
                #if (((Invoke-Pester -TestName "DC" -PassThru ).TestResult | Where-Object {$_.name -match "DC Domain Services Installed"}).result -notmatch "Passed") {
                while ((Invoke-Command -VMName $VMName -Credential $LocalAdminCreds {"Test"} -ErrorAction SilentlyContinue) -ne "Test") {Start-Sleep -Seconds 5}
                $PSSession = New-PSSession -VMName $VMName -Credential $LocalAdminCreds
                    Invoke-Command -Session $PSSession -ScriptBlock $SBAddFeatures  | Out-Null
                #    Write-LogEntry -Message "Domain Services roles have been enabled on $VMName" -Type Information
                #}
                #if (((Invoke-Pester -TestName "DC" -PassThru ).TestResult | Where-Object {$_.name -match "DC Promoted"}).result -notmatch "Passed") {
                    Invoke-Command -Session $PSSession -ScriptBlock $SBDCPromo -ArgumentList $DomainFQDN, $AdministratorPassword | Out-Null
                #    Write-LogEntry -Message "Forrest $DomainFQDN has been promoted on $VMName" -Type Information
                #}
                $PSSession | Remove-PSSession
                #Write-LogEntry -Type Information -Message "PowerShell Direct Session for $VMName has been disconnected"
                while ((Invoke-Command -VMName $VMName -Credential $DomainAdminCreds {"Test"} -ErrorAction SilentlyContinue) -ne "Test") {Start-Sleep -Seconds 5}
                $PSSessionDomain = New-PSSession -VMName $VMName -Credential $DomainAdminCreds
                #Write-LogEntry -Message "PowerShell Direct session for $($DomainAdminCreds.UserName) has been initated with DC Service named: $VMName" -Type Information
                
                Invoke-Command -Session $PSSessionDomain -ScriptBlock $SBConfigureDHCP -ArgumentList $VMName, $DomainFQDN, $IPAddress
                
                Invoke-Command -Session $PSSessionDomain -ScriptBlock $SBCreateLabDomain
                #Write-LogEntry -Message "System Management Container created in $DomainFQDN forrest on $VMName" -type Information
                $PSSessionDomain | Remove-PSSession
            
            #Write-LogEntry -Message "DC Server Completed: $(Get-Date)" -Type Information
            #invoke-pester -TestName "DC"
        }