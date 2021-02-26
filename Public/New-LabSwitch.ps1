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
    [Switch]
    $RemoveExisting

)
    if ($RemoveExisting.IsPresent) {
        Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue | Remove-VMSwitch -Confirm:$False -Force -ErrorAction SilentlyContinue
    }
    New-VMSwitch -Name $SwitchName -SwitchType Internal | Out-Null
}