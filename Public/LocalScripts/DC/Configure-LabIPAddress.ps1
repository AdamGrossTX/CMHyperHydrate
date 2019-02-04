Function Configure-LabIPAddress
{
[cmdletBinding()]
param(

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $LogPath = $Script:Base.ClientLogPath,
    
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $InterfaceID, 
    
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $IPSubNet, 
    
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $IPAddress,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $DefaultGateway = "$($IPSubNet)1",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $DNSServerIP = "127.0.0.1"


)
    If(!(Test-Path -Path $LogPath -ErrorAction SilentlyContinue))
    {
        New-Item -Path $LogPath -ItemType Directory -ErrorAction SilentlyContinue
    }

    $LogFile = "$($LogPath)\$($myInvocation.MyCommand).log" 

    Start-Transcript $LogFile 
    Write-Host "Logging to $LogFile" 

    #region Do Stuff Here
    New-NetIPAddress -InterfaceIndex $InterfaceID -AddressFamily IPv4 -IPAddress $IPAddress -PrefixLength 24 -DefaultGateway $DefaultGateway;
    Set-DnsClientServerAddress -ServerAddresses ($DNSServerIP) -InterfaceIndex $InterfaceID;
    Restart-Computer -Force;
    #endregion

    Stop-Transcript

}