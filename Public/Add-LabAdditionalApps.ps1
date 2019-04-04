Function Add-LabAdditionalApps {

    [cmdletbinding()]
    Param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $VMName = $Script:VMConfig.VMName,

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
    

#region Script Blocks
        
$SBInstallAdditionalApps = {
    Set-ExecutionPolicy Bypass -Scope Process -Force; 
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    choco upgrade chocolatey -y -f
    choco install sql-server-management-studio -y -f
    choco install vscode -y -f
    choco install snagit -y -f
    choco install postman -y -f
}

        $InstallAdditionalApps += $SBDefaultParams
        $InstallAdditionalApps += $SBScriptTemplateBegin.ToString()
        $InstallAdditionalApps += $SBInstallAdditionalApps.ToString()
        $InstallAdditionalApps += $SCScriptTemplateEnd.ToString()
        $InstallAdditionalApps | Out-File "$($LabScriptPath)\InstallAdditionalApps.ps1"

        #endregion

        $VM = Get-VM -VM $VMName
        $VM | Start-VM
        start-sleep 10
        $Scripts = Get-Item -Path "$($LabScriptPath)\*.*"

        While (!(Invoke-Command -VMName $VMName -Credential $DomainAdminCreds {Get-Process "LogonUI" -ErrorAction SilentlyContinue;})) {Start-Sleep -seconds 5}
        Foreach($Script in $Scripts) {
            Copy-VMFile -VM $VM -SourcePath $Script.FullName -DestinationPath "C:$($ScriptPath)\$($Script.Name)" -CreateFullPath -FileSource Host -Force
        }

        $ClientScriptPath = "C:$($ScriptPath)\"

        Invoke-LabCommand -FilePath "$($LabScriptPath)\InstallAdditionalApps.ps1" -MessageText "InstallAdditionalApps" -SessionType Domain -VMID $VM.VMId

        Write-Host "Install Additional Apps Complete!"

}