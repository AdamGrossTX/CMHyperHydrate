Function New-LabUnattendXML {
[cmdletbinding()]
Param (
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $AdministratorPassword = $Script:Env.EnvAdminPW,
    
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $TimeZone = $Script:Env.EnvTimeZone,
    
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $InputLocale = $Script:Env.InputLocale,
    
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $SystemLocale = $Script:Env.SystemLocale,
    
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $UILanguage = $Script:Env.UILanguage,
    
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $UILanguageFallback = $Script:Env.UILanguageFB,
    
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $UserLocale = $Script:Env.UserLocale,
    
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $OutputFile = "Unattend.XML",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $OutputPath = "$($Script:Base.LabPath)\$($Script:Base.ENVToBuild)"

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