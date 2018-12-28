Function New-LabVM {
[cmdletbinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $ENVName = $Script:Env.Env,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $VMName = $Script:VMConfig.VMName,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $ReferenceVHDX = $Script:base.SvrVHDX,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $VMPath = $script:base.VMPath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $VMHDPath = $Script:VMConfig.VMHDPath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $VMHDName = $Script:VMConfig.VMHDName,

    [Parameter()]
    [UInt64]
    [ValidateNotNullOrEmpty()]
    [ValidateRange(512MB, 64TB)]
    $StartupMemory = 4gb,
    #$Script:VMConfig.StartupMemory,

    [ValidateNotNullOrEmpty()]
    [int]
    $Generation = $Script:VMConfig.Generation,

    [Parameter()]
    [switch]
    $EnableSnapshot = $Script:VMConfig.EnableSnapshot,
    
    [Parameter()]
    [switch]
    $StartUp = $Script:VMConfig.AutoStartup,

    [Parameter()]
    [string]
    $DomainName = $Script:Env.EnvFQDN,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $IPAddress = $Script:VMConfig.IPAddress,
    
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $SwitchName = $Script:Env.EnvSwitchName,

    [Parameter()]
    [pscredential]
    $LocalAdminCreds = $Script:base.LocalAdminCreds
    
)

##TODO##
##Add logic to join to a domain if not the domain controller and if set to join the domain (wouldn't do it for AutoPilot testing and such.)

    If(!(Test-Path "$($VMHDPath)\$($VMHDName)" -ErrorAction SilentlyContinue)) {
        New-Item -Path $VMHDPath -ItemType Directory
        Copy-Item -Path $ReferenceVHDX -Destination "$($VMHDPath)\$($VMHDName)"
    }
    New-VM -Name $VMName -MemoryStartupBytes $StartupMemory -VHDPath "$($VMHDPath)\$($VMHDName)" -Generation $Generation -Path $VMPath
    Enable-VMIntegrationService -VMName $VMName -Name "Guest Service Interface"
    Set-VM -name $VMName -checkpointtype Disabled
    Get-VMNetworkAdapter -VMName $VMName | Connect-VMNetworkAdapter -SwitchName $SwitchName
    if($StartUp) {
        Start-VM $VMName
        
        $SBRenameComputer = {
            Param($Name)
            Rename-Computer -NewName $Name;
            Restart-Computer -Force;
        }

        while ((Invoke-Command -VMName $VMName -Credential $LocalAdminCreds {"Test"} -ErrorAction SilentlyContinue) -ne "Test") {Start-Sleep -Seconds 5}
        $PSSession = New-PSSession -VMName $VMName -Credential $LocalAdminCreds

        Invoke-Command -Session $PSSession -ScriptBlock $SBRenameComputer -ArgumentList $VMName

        $PSSession | Remove-PSSession

    }
<#

    $SBSetIPAndName = {
        param($InterfaceID, $SubNet, $Octet, $ServerName)
        New-NetIPAddress -InterfaceIndex $InterfaceID -AddressFamily IPv4 -IPAddress "$($SubNet)$($Octet)" -PrefixLength 24 -DefaultGateway "$($SubNet)1";
        Set-DnsClientServerAddress -ServerAddresses ('8.8.8.8') -InterfaceIndex $InterfaceID;
        Rename-Computer -Name $ServerName;
        Restart-Computer;
    }


    while ((Invoke-Command -VMName $VMName -Credential $LocalAdminCreds {"Test"} -ErrorAction SilentlyContinue) -ne "Test") {Start-Sleep -Seconds 5}
        $PSSession = New-PSSession -VMName $VMName -Credential $LocalAdminCreds
        #Write-LogEntry -Message "PowerShell Direct session for $($LocalAdminCreds.UserName) has been initated with DC Service named: $VMName" -Type Information
        $VMNics = Invoke-Command -VMName $VMName -Credential $LocalAdminCreds -ScriptBlock {Get-NetAdapter}
        #Write-LogEntry -Message "The following network adaptors $($VMNics -join ",") have been found on: $VMName" -Type Information
        #if (((Invoke-Pester -TestName "DC" -PassThru ).TestResult | Where-Object {$_.name -match "DC IP Address"}).result -notmatch "Passed") {
            Invoke-Command -Session $PSSession -ScriptBlock $SBSetIPAndName -ArgumentList $VMNics.InterfaceIndex, $IPSubNet, $IPLastOctet, $VMName | Out-Null

            
    if (((Invoke-Pester -TestName "CM" -PassThru -show None).TestResult | Where-Object {$_.name -match "CM has access to $DomainFQDN"}).result -match "Passed") {
        while ((Invoke-Command -VMName $cmname -Credential $cmsessionLA {param($i)(test-netconnection "$i.10").pingsucceeded} -ArgumentList $ipsub -ErrorAction SilentlyContinue) -ne $true -and $stop -ne (get-date)) {Start-Sleep -Seconds 5}
        Invoke-Command -session $cmsessionLA -ErrorAction SilentlyContinue -ScriptBlock {param($env, $domuser) Clear-DnsClientCache; Add-Computer -DomainName $env -domainCredential $domuser -Restart; Start-Sleep -Seconds 15; Restart-Computer -Force -Delay 0} -ArgumentList $DomainFQDN, $domuser
        write-logentry -message "Joined $cmname to domain $domainFQDN" -type information
        $stop = (get-date).AddMinutes(5)
        while ((Invoke-Command -VMName $cmname -Credential $domuser {"Test"} -ErrorAction SilentlyContinue) -ne "Test" -and $stop -ne (get-date)) {Start-Sleep -Seconds 5}
    }
    else {
        write-logentry -message "Couldn't find $domainFQDN" -type error
        throw "CM Server can't resolve $DomainFQDN"
    }
#>

}