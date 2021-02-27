function New-LabSwitch {
[cmdletbinding()]
Param
(
    [Parameter()]
    [String]
    $SwitchName = $Script:labEnv.EnvSwitchName,

    [Parameter()]
    [String]
    $IPSubnet = $Script:labEnv.EnvIPSubnet,

    [Parameter()]
    [String]
    $RRASName = $Script:labEnv.RRASName,
    
    [Parameter()]
    [Switch]
    $RemoveExisting

)

    Write-Host "Starting New-LabSwitch" -ForegroundColor Cyan
    
    $ExistingSwitch = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue
    if (-not $ExistingSwitch) {
        New-VMSwitch -Name $SwitchName -SwitchType Internal | Out-Null
    }
}