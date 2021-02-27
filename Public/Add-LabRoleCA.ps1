function Add-LabRoleCA {
    [cmdletbinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $VMName = $Script:VMConfig.VMName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $DomainFQDN = $Script:labEnv.EnvFQDN,

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

    #region Standard Setup
    Write-Host "Starting Add-LabRoleCA" -ForegroundColor Cyan
    $LabScriptPath = "$($LabPath)$($ScriptPath)\$($VMName)"
    $ClientScriptPath = "C:$($ScriptPath)"
    
    if (-not (Test-Path -Path "$($LabScriptPath)")) {
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
        if (-not (Test-Path -Path $_LogPath -ErrorAction SilentlyContinue)) {
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
    
    #endregion
        
    #region Script Blocks
    $SBInstallCA = {
        Add-WindowsFeature -Name Adcs-Cert-Authority -IncludeManagementTools;
        Install-AdcsCertificationAuthority -CAType EnterpriseRootCA -KeyLength 2048 -HashAlgorithm SHA1 -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" -ValidityPeriod Years -ValidityPeriodUnits 5 -Force -confirm:$false
    }

    $InstallCA += $SBDefaultParams
    $InstallCA += $SBScriptTemplateBegin.ToString()
    $InstallCA += $SBInstallCA.ToString()
    $InstallCA += $SCScriptTemplateEnd.ToString()
    $InstallCA | Out-File "$($LabScriptPath)\InstallCA.ps1"
    
    $Scripts = Get-Item -Path "$($LabScriptPath)\*.*"

    #endregion

    $VM = Get-VM -VM $VMName
    $VM | Start-VM
    start-sleep 10

    while (-not (Invoke-Command -VMName $VMName -Credential $DomainAdminCreds {Get-Process "LogonUI" -ErrorAction SilentlyContinue;})) {Start-Sleep -seconds 5}
    
    foreach ($Script in $Scripts) {
        Copy-VMFile -VM $VM -SourcePath $Script.FullName -DestinationPath "C:$($ScriptPath)\$($Script.Name)" -CreateFullPath -FileSource Host -Force
    }

    Invoke-LabCommand -FilePath "$($LabScriptPath)\InstallCA.ps1" -MessageText "InstallCA" -SessionType Domain -VMID $VM.VMId

    #TODO  Create-PKICertTemplate

    Write-Host "CA Configuration Complete!"

}