Function Join-LabDomain {

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
        $LocalAdminCreds = $Script:base.LocalAdminCreds,

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
    

$SBJoinDomainParams = @"
    param
    (
        `$_LogPath = "$($LogPath)",
        `$_FQDN = "$($DomainFQDN)",
        `$_DomainAdminName = "$($Script:Env.EnvNetBios)\Administrator",
        `$_DomainAdminPassword = "$($Script:Env.EnvAdminPW)"
    )
"@

$SBJoinDomain = {
    $_Password = ConvertTo-SecureString -String $_DomainAdminPassword -AsPlainText -Force
    $_Creds = new-object -typename System.Management.Automation.PSCredential($_DomainAdminName,$_Password)
    Add-Computer -Credential $_Creds -DomainName $_FQDN -Restart
}

$JoinDomain += $SBJoinDomainParams
$JoinDomain += $SBScriptTemplateBegin.ToString()
$JoinDomain += $SBJoinDomain.ToString()
$JoinDomain += $SCScriptTemplateEnd.ToString()
$JoinDomain | Out-File "$($LabScriptPath)\JoinDomain.ps1"

        #endregion

        $VM = Get-VM -VM $VMName
        $VM | Start-VM
        start-sleep 20
        $Scripts = Get-Item -Path "$($LabScriptPath)\*.*"
        $ClientScriptPath = "C:$($ScriptPath)\"
        Invoke-LabCommand -FilePath "$($LabScriptPath)\JoinDomain.ps1" -MessageText "JoinDomain" -SessionType Local -VMID $VM.VMId
        Write-Host "Domain Join Complete!"

}