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

        Get-NetNat -Name $SwitchName | Remove-NetNat -Confirm:$false -ErrorAction SilentlyContinue
        Get-VMSwitch -Name $SwitchName | Remove-VMSwitch -Confirm:$False -Force -ErrorAction SilentlyContinue
        New-VMSwitch -Name $SwitchName -SwitchType Internal | Out-Null
        New-NetIPAddress -IPAddress "$($IPSubnet)`1" -PrefixLength 24 -InterfaceAlias "vEthernet ($($SwitchName))"
        New-NetNAT -Name $SwitchName -InternalIPInterfaceAddressPrefix "$($IPSubnet)0`/24"
}
