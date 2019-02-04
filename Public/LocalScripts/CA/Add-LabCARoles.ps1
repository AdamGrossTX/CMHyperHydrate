Function Add-LabCARoles
{
[cmdletBinding()]
param(

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $LogPath = "C:$($Script:Base.VMDataPath)\Logs"
)

    If(!(Test-Path -Path $LogPath -ErrorAction SilentlyContinue))
    {
        New-Item -Path $LogPath -ItemType Directory -ErrorAction SilentlyContinue
    }

    $LogFile = "$($LogPath)\$($myInvocation.MyCommand).log" 

    Start-Transcript $LogFile 
    Write-Host "Logging to $LogFile" 

    #region Do Stuff Here
    Add-WindowsFeature -Name Adcs-Cert-Authority -IncludeManagementTools
    Install-AdcsCertificationAuthority –CAType EnterpriseRootCA –KeyLength 2048 –HashAlgorithm SHA1 –CryptoProviderName "RSA#Microsoft Software Key Storage Provider" -ValidityPeriod Years -ValidityPeriodUnits 5 -Force -confirm:$false
    #endregion

    Stop-Transcript

}