Function ScriptTemplate
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
    $DomainFQDN = $Script:Env.EnvFQDN,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [pscredential]
    $DomainAdminCreds = $Script:base.DomainAdminCreds
)

    If(!(Test-Path -Path $LogPath -ErrorAction SilentlyContinue))
    {
        New-Item -Path $LogPath -ItemType Directory -ErrorAction SilentlyContinue
    }

    $LogFile = "$($LogPath)\$($myInvocation.MyCommand).log" 

    Start-Transcript $LogFile 
    Write-Host "Logging to $LogFile" 

    #region Do Stuff Here
    Install-WindowsFeature -Name DHCP, DNS, AD-Domain-Services -IncludeManagementTools;
    Install-ADDSForest -DomainName $FQDN -SafeModeAdministratorPassword $DomainAdminCreds.Password -confirm:$false -WarningAction SilentlyContinue;
    #endregion

    Stop-Transcript
}