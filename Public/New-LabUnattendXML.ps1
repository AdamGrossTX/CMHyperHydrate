Function New-LabUnattendXML {
[cmdletbinding(DefaultParameterSetName="Config")]
Param (
    [Parameter(ParameterSetName="Config")]
    [ValidateNotNullOrEmpty()]
    [switch]$UseConfig,

    [Parameter(ParameterSetName="CustomValues")]
    [ValidateNotNullOrEmpty()]
    [string]
    $AdministratorPassword = "P@ssw0rd",
    
    [Parameter(ParameterSetName="CustomValues")]
    [ValidateNotNullOrEmpty()]
    [string]
    $TimeZone = "Central Standard Time",
    
    [Parameter(ParameterSetName="CustomValues")]
    [ValidateNotNullOrEmpty()]
    [string]
    $InputLocale = "0409:00000409",
    
    [Parameter(ParameterSetName="CustomValues")]
    [ValidateNotNullOrEmpty()]
    [string]
    $SystemLocale = "en-us",
    
    [Parameter(ParameterSetName="CustomValues")]
    [ValidateNotNullOrEmpty()]
    [string]
    $UILanguage = "en-us",
    
    [Parameter(ParameterSetName="CustomValues")]
    [ValidateNotNullOrEmpty()]
    [string]
    $UILanguageFallback = "en-us",
    
    [Parameter(ParameterSetName="CustomValues")]
    [ValidateNotNullOrEmpty()]
    [string]
    $UserLocale = "en-us",
    
    [Parameter(ParameterSetName="CustomValues")]
    [ValidateNotNullOrEmpty()]
    [string]
    $OutputFile
)

If($UseEnvConfig) {
    $AdministratorPassword = $Script:Env.EnvAdminPW
    $TimeZone = $Script:Env.EnvTimeZone
    $InputLocale = $Script:Env.InputLocale
    $SystemLocale = $Script:Env.SystemLocale
    $UILanguage = $Script:Env.UILanguage
    $UILanguageFallback = $Script:Env.UILanguageFB
    $UserLocale = $Script:Env.UserLocale
    $OutputFile = "$($Script:Base.LabPath)\$($Script:Base.ENVToBuild)\Unattend.XML"
}

$unattendTemplate = [xml]@" 
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <UserAccounts>
                <AdministratorPassword>
                    <Value>$($AdministratorPassword)</Value> 
                    <PlainText>True</PlainText> 
                </AdministratorPassword>
            </UserAccounts>
            <OOBE>
                <VMModeOptimizations>
                    <SkipNotifyUILanguageChange>true</SkipNotifyUILanguageChange>
                    <SkipWinREInitialization>true</SkipWinREInitialization>
                </VMModeOptimizations>
                <SkipMachineOOBE>true</SkipMachineOOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideLocalAccountScreen>true</HideLocalAccountScreen>
                <ProtectYourPC>3</ProtectYourPC>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <NetworkLocation>Work</NetworkLocation>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
            </OOBE>
            <Timezone>$($TimeZone)</Timezone>
        </component>
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>$($InputLocale)</InputLocale>
            <SystemLocale>$($SystemLocale)</SystemLocale>
            <UILanguage>$($UILanguage)</UILanguage>
            <UILanguageFallback>$($UILanguageFallback)</UILanguageFallback>
            <UserLocale>$($UserLocale)</UserLocale>
        </component>
    </settings>
</unattend>
"@
    $unattendTemplate.Save($OutputFile)
}