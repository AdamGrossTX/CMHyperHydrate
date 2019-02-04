Function Test-LabConnection {
    [cmdletbinding()]
    param (
        [parameter()]
        [ValidateSet('Local','Domain')]
        [string]
        $Type = 'Domain',
        
        [parameter()]
        [string]
        $VMName = $Script:VMConfig.VMName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [pscredential]
        $LocalAdminCreds = $Script:base.LocalAdminCreds,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [pscredential]
        $DomainAdminCreds = $Script:base.DomainAdminCreds
    )

    $Connected = $false
        $Creds = Switch($Type) {
            "Local" {$LocalAdminCreds; break;}
            "Domain" {$DomainAdminCreds; break;}
            default {break;
        }
    }

    Try {
    Do {
        $VMState = (Get-VM -Name $VMName).State
        if($VMState -eq "Off") {
            write-Host "VM Not Running. Starting VM."
            Start-VM -Name $VMName
        }
    }
    until ($VMState -eq "Running")

    Do {
        Write-Host "Testing $($Type) Connection."
        
        Try {

            $Result = Invoke-Command -VMName $VMName -Credential $Creds {Return "Connection Test Was Successful"} -ErrorAction Stop
        }
        Catch {
            $Result = $_.Exception.Message
        }

        Write-Host $Result

        If($Result -eq "Connection Test Was Successful")
        {
            $Result = Invoke-Command -VMName $VMName -Credential $Creds {Get-Process "LogonUI" -ErrorAction SilentlyContinue;} -ErrorAction Stop
            If($Result)
            {
                Write-Host $Result 
                $Connected = $True
            }
            else
            {
                $Connected = $false
            }
        }
        ElseIf($Result -eq "The credential is invalid.") {
            Write-Warning "Retying Credentials again."
            $Connected = $False
            Start-Sleep -Seconds 10
        } 
        ElseIf($Result -eq "The virtual machine $($VMName) is not in running state.") {
            $VMState = (Get-VM -Name $VMName).State
            if($VMState -eq "Off") {
                write-Host "VM Not Running. Starting VM."
                Start-VM -Name $VMName
            }
            else {
                Write-Host "Waiting for VM to fully start."
            }
            Start-Sleep -Seconds 5
        }
        Else {
            Write-Host "Retrying in 5 seconds."
            Start-Sleep -Seconds 5
        }
        Write-Host "Connected: $($Connected)"
    }
    until ($Connected)
}
Catch {
    Write-Warning $_.Exception.Message
    break;
}

    Return $Connected
}