Function Install-LabDHCP
{
[cmdletBinding()]
param(

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $LogPath = "C:$($Script:Base.VMDataPath)\Logs",

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
    [ipaddress]
    $ScopeID = "$($IPSubnet)0"
)

    If(!(Test-Path -Path $LogPath -ErrorAction SilentlyContinue))
    {
        New-Item -Path $LogPath -ItemType Directory -ErrorAction SilentlyContinue
    }

    $LogFile = "$($LogPath)\$($myInvocation.MyCommand).log" 

    Start-Transcript $LogFile 
    Write-Host "Logging to $LogFile" 

    #region Do Stuff Here
    & netsh dhcp add securitygroups;
    Restart-Service dhcpserver;
    Add-DhcpServerInDC -DnsName "$($VMName).$($DomainFQDN)" -IPAddress "$($IPAddress)";
    Set-ItemProperty -Path registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ServerManager\Roles\12 -Name ConfigurationState -Value 2;
    Add-DhcpServerv4Scope -name "$($DomainFQDN)" -StartRange "$($IPSubnet)100" -EndRange "$($IPSubnet)150" -SubnetMask "255.255.255.0";
    Set-DhcpServerv4OptionValue -Router "$($IPSubnet)`1" -DNSDomain "$($DomainFQDN)" -DNSServer "$($IPAddress)" -ScopeId "$($ScopeID)"
    #endregion

    Stop-Transcript

}