Function New-LabSwitch {
[cmdletbinding()]
Param
(
    [Parameter()]
    [String]
    $SwitchName = $Script:Env.EnvSwitchName,

    [Parameter()]
    [String]
    $IPSubnet = $Script:Env.EnvIPSubnet

)
        Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue | Remove-VMSwitch -Confirm:$False -Force -ErrorAction SilentlyContinue
        New-VMSwitch -Name $SwitchName -SwitchType Internal | Out-Null
}