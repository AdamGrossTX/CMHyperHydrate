function new-RRASServer {
    param (
        [Parameter(ParameterSetName='RRASClass')]
        [RRAS]
        $RRASConfig,
        [Parameter(ParameterSetName='NoClass')]
        [string]
        $VHDXPath,
        [Parameter(ParameterSetName='NoClass')]
        [string]
        $RefVHDX,
        [Parameter(ParameterSetName='NoClass')]
        [pscredential]
        $localadmin,
        [parameter(ParameterSetName='NoClass',Mandatory=$false)]
        [switch]
        $vmSnapshotenabled,
        [Parameter(ParameterSetName='NoClass')]
        [string]
        $Name,
        [Parameter(ParameterSetName='NoClass')]
        [int]
        $cores,
        [Parameter(ParameterSetName='NoClass')]
        [int]
        $RAM,
        [Parameter(ParameterSetName='NoClass')]
        [string]
        $IPaddress,
        [Parameter(ParameterSetName='NoClass')]
        [string]
        $network
    )
    if (-not $PSBoundParameters.ContainsKey('RRASConfig'))
    {
        $RRASConfig = [RRAS]::new()
        $RRASConfig.Name = $name
        $RRASConfig.Cores = $cores
        $RRASConfig.Ram = $RAM
        $RRASConfig.ipaddress = $IPaddress
        $RRASConfig.Network = $network
        $RRASConfig.localadmin = $localadmin
        $RRASConfig.vmSnapshotenabled = $vmSnapshotenabled
        $RRASConfig.VHDXpath = $VHDXPath
        $RRASConfig.RefVHDX = $RefVHDX
    }
    
    
    if (((Invoke-Pester -TestName "RRAS" -PassThru -show None).TestResult | Where-Object {$_.name -match "RRAS Server Should exist"}).Result -notmatch "Passed") {
        
        if (((Invoke-Pester -TestName "RRAS" -PassThru -show None).TestResult | Where-Object {$_.name -match "VHDX Should exist"}).Result -match "Passed") {
            
            throw "RRAS VHDX Already Exists at path: $($RRASConfig.VHDXpath) Please clean up and Rerun."
        }
        else {
            Copy-Item -Path $RRASConfig.RefVHDX -Destination $RRASConfig.VHDXpath
            
        }
        if (((Invoke-Pester -TestName "RRAS" -PassThru -show None).TestResult | Where-Object {$_.name -match "VHDX Should exist"}).Result -notmatch "Passed") {
            
            throw "Error Creating the VHDX for RRAS"
        }
        else {
            
            $vm = new-vm -Name $RRASConfig.name -MemoryStartupBytes ($RRASConfig.RAM * 1Gb) -VHDPath $RRASConfig.VHDXpath -Generation 2 | out-null # | Set-VMMemory -DynamicMemoryEnabled:$false
            $vm | Set-VMProcessor -Count $RRASConfig.cores
            Enable-VMIntegrationService -VMName $RRASConfig.name -Name "Guest Service Interface"
            if (-not $RRASConfig.vmSnapshotenabled){
                set-vm -Name $RRASConfig.name -CheckpointType Disabled
            }
            
            
        }
        start-vm -Name $RRASConfig.name
        
        Get-VMNetworkAdapter -vmname $RRASConfig.name | Connect-VMNetworkAdapter -SwitchName 'Internet' | Set-VMNetworkAdapter -Name 'Internet' -DeviceNaming On
        
        while ((Invoke-Command -VMName $RRASConfig.name -Credential $RRASConfig.localadmin {"Test"} -ErrorAction SilentlyContinue) -ne "Test") {Start-Sleep -Seconds 5}
        $RRASConfigSession = New-PSSession -VMName $RRASConfig.name -Credential $RRASConfig.localadmin
        
        if (((Invoke-Pester -TestName "RRAS" -PassThru -show None).TestResult | Where-Object {$_.name -match "RRAS Routing Installed"}).Result -match "Passed") {
            Write-Verbose "RRAS Routing Already installed"
        }
        else {
            $null = Invoke-Command -Session $RRASConfigSession -ScriptBlock {Install-WindowsFeature Routing -IncludeManagementTools}
            
            
        }
        while ((Invoke-Command -VMName $RRASConfig.name -Credential $RRASConfig.localadmin {"Test"} -ErrorAction SilentlyContinue) -ne "Test") {Start-Sleep -Seconds 5}
        $RRASConfigSession = New-PSSession -VMName $RRASConfig.name -Credential $RRASConfig.localadmin
        
        if (((Invoke-Pester -TestName "RRAS" -PassThru -show None).TestResult | Where-Object {$_.name -match "RRAS External NIC Renamed"}).Result -match "Passed") {
            Write-Verbose "RRAS NIC Already Named external"
        }
        else {
            Invoke-Command -Session $RRASConfigSession -ScriptBlock {Get-NetAdapter -Physical -name Ethernet | rename-netadapter -newname "External" }
            
            
        }
        Invoke-Command -Session $RRASConfigSession -ScriptBlock {Install-RemoteAccess -VpnType Vpn; netsh routing ip nat install; netsh routing ip nat add interface "External"; netsh routing ip nat set interface "External" mode=full}
        
        $RRASConfigSession | Remove-PSSession
        
    }
    else {
        Start-VM $RRASConfig.name
        
        while ((Invoke-Command -VMName $RRASConfig.name -Credential $RRASConfig.localadmin {"Test"} -ErrorAction SilentlyContinue) -ne "Test") {Start-Sleep -Seconds 5}
    }

    if ((Get-VMNetworkAdapter -VMName $RRASConfig.name | Where-Object {$_.switchname -eq $RRASConfig.network}).count -eq 0) {
        if (((Invoke-Pester -TestName "RRAS" -PassThru -show None).TestResult | Where-Object {$_.name -match "RRAS Lab IP Address Set"}).Result -match "Passed") {
            Write-Verbose "RRAS NIC Already Named $($RRASConfig.Network)"
        }
        else {
            $RRASConfigSession = New-PSSession -VMName $RRASConfig.name -Credential $RRASConfig.localadmin
            
            $RRASConfignics = Invoke-Command -Session $RRASConfigSession -ScriptBlock {Get-NetAdapter}
            
            get-vm -Name $RRASConfig.name | Add-VMNetworkAdapter -SwitchName $RRASConfig.Network
            
            Start-Sleep -Seconds 10
            $RRASConfignewnics = Invoke-Command -Session $RRASConfigSession -ScriptBlock {Get-NetAdapter}
            
            $t = Compare-Object -ReferenceObject $RRASConfignics -DifferenceObject $RRASConfignewnics -PassThru
            $null = Invoke-Command -Session $RRASConfigSession -ScriptBlock {param ($t, $i) new-NetIPAddress -InterfaceIndex $t -AddressFamily IPv4 -IPAddress "$i" -PrefixLength 24} -ArgumentList $t.InterfaceIndex, $rrasconfig.IPaddress
            
            Invoke-Command -Session $RRASConfigSession -ScriptBlock {param ($n, $t)Get-NetAdapter -InterfaceIndex $n | rename-netadapter -newname $t } -ArgumentList $t.InterfaceIndex, $RRASConfig.Network
            Invoke-Command -Session $RRASConfigSession -ScriptBlock {param ($n)get-service -name "remoteaccess" | Restart-Service -WarningAction SilentlyContinue; netsh routing ip nat add interface $n} -ArgumentList $RRASConfig.Network
            
            
        }
        Invoke-Command -Session $RRASConfigSession -ScriptBlock {Set-LocalUser -Name "Administrator" -PasswordNeverExpires 1}
        
        Invoke-Command -Session $RRASConfigSession -ScriptBlock { Set-ItemProperty -path HKLM:\SOFTWARE\Microsoft\ServerManager -name DoNotOpenServerManagerAtLogon -Type DWord -value "1" -Force }
        $RRASConfigSession | Remove-PSSession
        
    }
    
    invoke-pester -name "RRAS"
}