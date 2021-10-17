function New-LabSwitch {
[cmdletbinding()]
Param
(

    [Parameter()]
    [hashtable]
    $LabEnvConfig,
    
    [Parameter()]
    [String]
    $SwitchName = $LabEnvConfig.EnvSwitchName,

    [Parameter()]
    [String]
    $IPSubnet = $LabEnvConfig.EnvIPSubnet,

    [Parameter()]
    [String]
    $RRASName = $LabEnvConfig.RRASName,
    
    [Parameter()]
    [Switch]
    $RemoveExisting

)

    Write-Host "Starting $($MyInvocation.MyCommand)" -ForegroundColor Cyan

    $ExistingSwitch = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue
    if (-not $ExistingSwitch) {
        New-VMSwitch -Name $SwitchName -SwitchType Internal | Out-Null
    }

    Write-Host "$($MyInvocation.MyCommand) Complete!" -ForegroundColor Cyan
}