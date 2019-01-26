Function Invoke-LabCommand {
    [cmdletbinding()]
    Param (

        [Parameter()]
        [string]
        $MessageText,
        
        [Parameter()]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [System.Object[]]
        $ArgumentList,

        [parameter()]
        [ValidateSet('Local','Domain')]
        [string]
        $SessionType = 'Domain',

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

    Write-Host "##########################" | out-null
    Write-Host "Started - $($MessageText)" | out-null
    $Result = $Null

    If(Test-LabConnection -Type $SessionType -VMName $VMName) {
        Switch($SessionType) {
            "Local" {
                $Session = New-PSSession -VMName $VMName -Credential $LocalAdminCreds;
                break;
            }
            "Domain" {
                $Session = New-PSSession -VMName $VMName -Credential $DomainAdminCreds; 
                break;
            }
            default {break;}
        }

        Write-Host "Invoking Remote Command" | out-null
        Try {
            $Result = Invoke-Command -Session $Session -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
            $Session | Remove-PSSession
        }
        Catch {
            Write-Warning $_.Exception.Message | out-null
            break;
        }

        Write-Host "Remote Command Completed" | out-null
    }
    Else {
        $Result = "Error"
    }
    Write-Host "Completed - $($MessageText)" | out-null
    Return $Result
    
}
