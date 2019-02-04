Function New-LabDomain
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
    #endregion

    Stop-Transcript

}