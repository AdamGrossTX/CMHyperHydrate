function New-LabUnattendXML {
    [cmdletbinding()]
    param (
        [Parameter()]
        [hashtable]
        $BaseConfig,

        [Parameter()]
        [hashtable]
        $LabEnvConfig,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $AdministratorPassword = $LabEnvConfig.EnvAdminPW,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $TimeZone = $LabEnvConfig.EnvTimeZone,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $InputLocale = $LabEnvConfig.InputLocale,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $SystemLocale = $LabEnvConfig.SystemLocale,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $UILanguage = $LabEnvConfig.UILanguage,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $UILanguageFallback = $LabEnvConfig.UILanguageFB,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $UserLocale = $LabEnvConfig.UserLocale,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $OutputFile = "Unattend.XML",

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $OutputPath = $BaseConfig.VMPath

    )

New-Item -Path $OutputPath -ItemType Directory -Force

$unattendTemplate = [xml]@" 
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <UserAccounts>
                <AdministratorPassword>
                    <Value>$($AdministratorPassword)</Value>
                    <PlainText>True</PlainText>
                    <Username>Administrator</Username>
                    <Enabled>true</Enabled>
                    <LogonCount>5</LogonCount>
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
    $unattendTemplate.Save("$($OutputPath)\$($OutputFile)")
}