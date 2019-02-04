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
        [string]
        $FilePath,

        [Parameter()]
        [Guid[]]
        $VMID,

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
        $Creds = Switch($SessionType) {
            "Local" {$LocalAdminCreds;break;}
            "Domain" {$DomainAdminCreds;break;}
            default {break;}
        }

        Write-Host "Invoking Remote Command" | out-null
        Try {
            if($ScriptBlock) {
                $Result = Invoke-Command -VMID $VMID -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList -Credential $Creds
            }
            else {
                $Result = Invoke-Command -VMId $VMID -Credential $Creds -FilePath $FilePath
            }
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
