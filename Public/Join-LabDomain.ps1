function Join-LabDomain {
    [cmdletbinding()]
    param (
        
        [Parameter()]
        [PSCustomObject]
        $VMConfig,

        [Parameter()]
        [hashtable]
        $BaseConfig,

        [Parameter()]
        [hashtable]
        $LabEnvConfig,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $VMName = $VMConfig.VMName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $DomainFQDN = $LabEnvConfig.EnvFQDN,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [pscredential]
        $LocalAdminCreds = $BaseConfig.LocalAdminCreds,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ScriptPath = $BaseConfig.VMScriptPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $LogPath = $BaseConfig.VMLogPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $LabPath = $BaseConfig.LabPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $DomainAdminName = "$($LabEnvConfig.EnvNetBios)\Administrator",

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $DomainAdminPassword = $LabEnvConfig.EnvAdminPW

    )

    #region Standard Setup
    Write-Host "Starting $($MyInvocation.MyCommand)" -ForegroundColor Cyan
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
        
        Start-Transcript $_LogFile -NoClobber -IncludeInvocationHeader | Out-Null;
        Write-Output "Logging to $_LogFile";
        
        #region Do Stuff Here
    }
        
    $SCScriptTemplateEnd = {
        #endregion
        Stop-Transcript
    }
    
    #endregion

    #region Script Blocks
    $SBJoinDomainParams = @"
        param
        (
            `$_LogPath = "$($LogPath)",
            `$_FQDN = "$($DomainFQDN)",
            `$_DomainAdminName = "$($DomainAdminName)",
            `$_DomainAdminPassword = "$($DomainAdminPassword)"
        )
"@

    $SBJoinDomain = {
        $_Password = ConvertTo-SecureString -String $_DomainAdminPassword -AsPlainText -Force
        $_Creds = new-object -typename System.Management.Automation.PSCredential($_DomainAdminName,$_Password)
        Add-Computer -Credential $_Creds -DomainName $_FQDN -Restart
        $DomainJoined = (((Get-ComputerInfo).CsDomainRole -eq "PrimaryDomainController") -or (Test-ComputerSecureChannel -ErrorAction SilentlyContinue))
        Return $DomainJoined
    }

    $JoinDomain += $SBJoinDomainParams
    $JoinDomain += $SBScriptTemplateBegin.ToString()
    $JoinDomain += $SBJoinDomain.ToString()
    $JoinDomain += $SCScriptTemplateEnd.ToString()
    $JoinDomain | Out-File "$($LabScriptPath)\JoinDomain.ps1"

    $Scripts = Get-Item -Path "$($LabScriptPath)\*.*"

    #endregion

    $VM = Get-VM -VM $VMName
    $VM | Start-VM -WarningAction SilentlyContinue
    start-sleep 20

    $DomainJoined = $False
    while (-not (Invoke-Command -VMName $VMName -Credential $LocalAdminCreds {Get-Process "LogonUI" -ErrorAction SilentlyContinue;})) {Start-Sleep -seconds 5}
    do {
            foreach ($Script in $Scripts) {
                Copy-VMFile -VM $VM -SourcePath $Script.FullName -DestinationPath "C:$($ScriptPath)\$($Script.Name)" -CreateFullPath -FileSource Host -Force
            }
            $DomainJoined = Invoke-LabCommand -FilePath "$($LabScriptPath)\JoinDomain.ps1" -MessageText "JoinDomain" -SessionType Local -VMID $VM.VMId
    } until ($DomainJoined)

    Start-Sleep -Seconds 60
    Write-Host "$($MyInvocation.MyCommand) Complete!" -ForegroundColor Cyan
}