function New-LabVHDX {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [pscredential]
        $DomainUserName,
        [Parameter(Mandatory)]
        [string]
        $VMPath,
        [Parameter(Mandatory)]
        [string]
        $ReferenceVHDXName,
        [Parameter(Mandatory)]
        [psobject]
        $ConfigSettings,
        [Parameter(Mandatory)]
        [string]
        $SwitchName,
        [Parameter(Mandatory)]
        [string]
        $DefaultPassword,
        [Parameter(Mandatory)]
        [string]
        $SourceISO,
        [Parameter(Mandatory)]
        [string]
        $SourceWIM,
        [Parameter(Mandatory)]
        [string]
        $NET35CAB
    )
    $TNetwork = Invoke-Pester -TestName "vSwitch" -PassThru 
    if (($TNetwork.TestResult | Where-Object {$_.name -eq 'Internet VSwitch should exist'}).result -eq 'Failed') {
        Write-LogEntry -Type Information -Message "vSwitch named Internet does not exist"
        $nic = Get-NetAdapter -Physical
        Write-LogEntry -Type Information -Message "Following physical network adaptors found: $($nic.Name -join ",")"
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
            $oOptions | Out-Host
            $selection = Read-Host -Prompt "Please make a selection"
            Write-LogEntry -Type Information -Message "The following physical network adaptor has been selected for Internet access: $selection"
            $Selected = $oOptions | Where-Object {$_.Item -eq $selection}
            New-VMSwitch -Name 'Internet' -NetAdapterName $selected.name -AllowManagementOS:$true | Out-Null
            Write-LogEntry -Type Information -Message "Internet vSwitch has been created."
        }
    }
    if (($TNetwork.TestResult | Where-Object {$_.name -eq 'Lab VMSwitch Should exist'}).result -eq 'Failed') {
        Write-LogEntry -Type Information -Message "Private vSwitch named $swname does not exist"
        New-VMSwitch -Name $swname -SwitchType Private | Out-Null
        Write-LogEntry -Type Information -Message "Private vSwitch named $swname has been created."
    }
    Write-LogEntry -Type Information -Message "Base requirements for Lab Environment has been met"
}