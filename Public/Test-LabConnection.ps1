#https://blogs.technet.microsoft.com/virtualization/2016/10/11/waiting-for-vms-to-restart-in-a-complex-configuration-script-with-powershell-direct/
function Test-LabConnection {
    [cmdletbinding()]
    param (
        [parameter()]
        [ValidateSet('Local','Domain')]
        [string]
        $Type = 'Domain',
        
        [Parameter()]
        [Guid]
        $VMId,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [pscredential]
        $LocalAdminCreds = $Script:base.LocalAdminCreds,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [pscredential]
        $DomainAdminCreds = $Script:base.DomainAdminCreds
    )

    $VM = Get-VM -Id $VMId

    $Connected = $false
    $Creds = Switch($Type) {
        "Local" {$LocalAdminCreds; break;}
        "Domain" {$DomainAdminCreds; break;}
        default {break;}
    }

    try {
        if ($VM.State -eq "Off") {
            write-Host "VM Not Running. Starting VM."
            $VM | Start-VM
        }

        # Wait for the VM's heartbeat integration component to come up if it is enabled
        $heartbeatic  = (Get-VMIntegrationService -VM $VM | Where-Object Id -match "84EAAE65-2F2E-45F5-9BB5-0E857DC8EB47")
        if ($heartbeatic -and ($heartbeatic.Enabled -eq $true)) {
            $startTime = Get-Date
            do {
                $timeElapsed = $(Get-Date) - $startTime
                if ($($timeElapsed).TotalMinutes -ge 10) {
                    Write-Host "Integration components did not come up after 10 minutes" -MessageType Error
                    throw
                } 
                Start-Sleep -sec 1
            } 
            until ($heartbeatic.PrimaryStatusDescription -eq "OK")
            Write-Host "Heartbeat IC connected."
        }
        do {
            Write-Host "Testing $($Type) Connection."
        
            $timeElapsed = $(Get-Date) - $startTime
            if ($($timeElapsed).TotalMinutes -ge 10) {
                Write-Host "Could not connect to PS Direct after 10 minutes"
                throw
            } 
            Start-Sleep -sec 1
            $psReady = Invoke-Command -VMId $VM.VMId -Credential $Creds -ErrorAction SilentlyContinue -ScriptBlock { $True } 
            if ($Type -eq 'Domain') {
                 Invoke-Command -VMId $VM.VMId -Credential $Creds -ErrorAction SilentlyContinue -ScriptBlock {  
                    do {
                        Write-Host "." -NoNewline -ForegroundColor Gray
                        Start-Sleep -Seconds 5
                        # query AD for the local computer
                        #Get-ADComputer $env:COMPUTERNAME | Out-Null
                        Get-WMIObject Win32_ComputerSystem | Out-Null
                    } until ($?) # exits the loop if last call was successful
                    Write-Host "succeeded."
                }
            }        
        } 
        until ($psReady)
    }

    catch {
        Write-Warning $_.Exception.Message
        break;
    }

    return $psReady
}