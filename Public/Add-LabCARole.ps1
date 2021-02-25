Function Add-LabCARole {

    [cmdletbinding()]
    Param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $VMName = $Script:VMConfig.VMName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $DomainFQDN = $Script:Env.EnvFQDN,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [pscredential]
        $DomainAdminCreds = $Script:base.DomainAdminCreds,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ScriptPath = $Script:Base.VMScriptPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $LogPath = $Script:Base.VMLogPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $LabPath = $Script:Base.LabPath

    )

    $LabScriptPath = "$($LabPath)$($Script:Base.VMScriptPath)"
    
    If(!(Test-Path -Path "$($LabScriptPath)" -ErrorAction SilentlyContinue))
    {
        New-Item -Path "$($LabScriptPath)" -ItemType Directory -ErrorAction SilentlyContinue
    }


$LogPath = "C:$($LogPath)"
$SBDefaultParams = @"
    param
    (
        `$_LogPath = "$($LogPath)"
    )
"@

$SBScriptTemplateBegin = {
    If(!(Test-Path -Path $_LogPath -ErrorAction SilentlyContinue))
    {
        New-Item -Path $_LogPath -ItemType Directory -ErrorAction SilentlyContinue;
    }
    
    $_LogFile = "$($_LogPath)\Transcript.log";
    
    Start-Transcript $_LogFile -Append -NoClobber;
    Write-Host "Logging to $_LogFile";
    
    #region Do Stuff Here
}
     
$SCScriptTemplateEnd = {
    #endregion

    Stop-Transcript
}
    

$SBInstallCA = {
    Add-WindowsFeature -Name Adcs-Cert-Authority -IncludeManagementTools;
    Install-AdcsCertificationAuthority -CAType EnterpriseRootCA -KeyLength 2048 -HashAlgorithm SHA1 -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" -ValidityPeriod Years -ValidityPeriodUnits 5 -Force -confirm:$false
}
        $InstallCA += $SBDefaultParams
        $InstallCA += $SBScriptTemplateBegin.ToString()
        $InstallCA += $SBInstallCA.ToString()
        $InstallCA += $SCScriptTemplateEnd.ToString()
        $InstallCA | Out-File "$($LabScriptPath)\InstallCA.ps1"

        $VM = Get-VM -VM $VMName
        $VM | Start-VM
        start-sleep 10
        $Scripts = Get-Item -Path "$($LabScriptPath)\*.*"

        Foreach($Script in $Scripts) {
            Copy-VMFile -VM $VM -SourcePath $Script.FullName -DestinationPath "C:$($ScriptPath)\$($Script.Name)" -CreateFullPath -FileSource Host -Force
        }
        $ClientScriptPath = "C:$($ScriptPath)\"
        Invoke-LabCommand -FilePath "$($LabScriptPath)\InstallCA.ps1" -MessageText "InstallCA" -SessionType Domain -VMID $VM.VMId
        Write-Host "CA Configuration Complete!"


}