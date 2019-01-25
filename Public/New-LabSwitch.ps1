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
#$TNetwork = Invoke-Pester -TestName "vSwitch" -PassThru 
#if (($TNetwork.TestResult | Where-Object {$_.name -eq 'Internet VSwitch should exist'}).result -eq 'Failed') {
    #Write-LogEntry -Type Information -Message "vSwitch named Internet does not exist"
    $nic = Get-NetAdapter -Physical
    #Write-LogEntry -Type Information -Message "Following physical network adaptors found: $($nic.Name -join ",")"
    if ($nic.count -gt 1) {
        Write-Verbose "Multiple Network Adptors found. "
        $i = 1
        $oOptions = @()
        $nic | ForEach-Object {
            $oOptions += [pscustomobject]@{
                Item = $i
                Name = $_.Name
            }
            $i++
        }
        #$oOptions | Out-Host
        #$selection = Read-Host -Prompt "Please make a selection"
        #Write-LogEntry -Type Information -Message "The following physical network adaptor has been selected for Internet access: $selection"
        #$Selected = $oOptions | Where-Object {$_.Item -eq $selection}

        #New-VMSwitch -Name $SwitchName -SwitchType Internal -NetAdapterName $Selected.Name | Out-Null
        New-VMSwitch -Name $SwitchName -SwitchType Internal | Out-Null
        New-NetIPAddress -IPAddress "$($IPSubnet)`1" -PrefixLength 24 -InterfaceAlias "vEthernet ($($SwitchName))"
        New-NetNAT -Name $SwitchName -InternalIPInterfaceAddressPrefix "$($IPSubnet)0`/24"

    
        #New-VMSwitch -Name 'Internet' -NetAdapterName $selected.name -AllowManagementOS:$true | Out-Null
        #Write-LogEntry -Type Information -Message "Internet vSwitch has been created."
    }
#}
#if (($TNetwork.TestResult | Where-Object {$_.name -eq 'Lab VMSwitch Should exist'}).result -eq 'Failed') {
    #rite-LogEntry -Type Information -Message "Private vSwitch named $SwitchName does not exist"
    
    
    #Write-LogEntry -Type Information -Message "Private vSwitch named $SwitchName has been created."
#}
#Write-LogEntry -Type Information -Message "Base requirements for Lab Environment has been met"
}