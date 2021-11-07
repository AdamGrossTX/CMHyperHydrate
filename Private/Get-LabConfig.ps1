function Get-LabConfig {
    [cmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $(Resolve-Path $_) })]    
        [string]
        $ConfigFileName,

        [Parameter()]
        [switch]
        $CreateFolders
    )
    
    Write-Host "Starting $($MyInvocation.MyCommand)" -ForegroundColor Cyan

    $RawConfig = Get-Content $ConfigFileName -Raw | ConvertFrom-Json
    $RawENVConfig = $RawConfig.ENVConfig | Where-Object {$_.ENV -eq $RawConfig.ENVToBuild}
    $RawSvrRefConfig = $RawConfig.ServerRef
    $RawWksRefConfig = $RawConfig.WorkstationRef
 
    $BaseConfig = @{}
    $LabEnvConfig = @{}
    $ServerRefConfig = @{}
    $WorkstationRefConfig = @{}

    ($RawConfig | Select-Object -Property * -ExcludeProperty "ENVConfig", "VMList", "ServerRef", "WorkstationRef").psobject.properties | foreach-Object {$BaseConfig[$_.Name] = $_.Value}
    ($RawENVConfig  | Select-Object -Property * -ExcludeProperty  "ServerVMList", "WorkstationVMList").psobject.properties | foreach-Object {$LabEnvConfig[$_.Name] = $_.Value}

    foreach ($Img in $RawSvrRefConfig) {
        ($Img).psobject.properties | foreach-Object {$ServerRefConfig[$_.Name] = $_.Value}
    }

    foreach ($Img in $RawWksRefConfig) {
        ($Img).psobject.properties | foreach-Object {$WorkstationRefConfig[$_.Name] = $_.Value}
    }

    $BaseConfig["ConfigMgrCBPrereqsPath"] = "$($BaseConfig.PathConfigMgr)\Prereqs"
    $BaseConfig["ConfigMgrTPPrereqsPath"] = "$($BaseConfig.PathConfigMgrTP)\Prereqs"

    foreach ($key in @($BaseConfig.keys)) {
        If ($key -like "Path*")
        {
            $BaseConfig[$key] = $BaseConfig.SourcePath + $BaseConfig[$key]
            if ($CreateFolders) {
                if (-not (Test-Path -path $BaseConfig[$key])) {New-Item -path $BaseConfig[$key] -ItemType Directory;}
            }
        }
    }

    $BaseConfig["VMPath"] = Join-Path -Path $BaseConfig.LabPath -ChildPath $BaseConfig.ENVToBuild
    $BaseConfig["SQLISO"] = Get-ChildItem -Path $BaseConfig.PathSQL -Filter "*.ISO" | Select-Object -First 1 -ExpandProperty FullName
    $BaseConfig["SvrISO"] = Get-ChildItem -Path $BaseConfig.PathSvr -Filter "*.ISO" | Select-Object -First 1 -ExpandProperty FullName
    $BaseConfig["WksISO"] = Get-ChildItem -Path $BaseConfig.PathWks -Filter "*.ISO" | Select-Object -First 1 -ExpandProperty FullName
    $BaseConfig["Packages"] = Get-ChildItem -Path $BaseConfig.PathPackages -Filter "*.CAB" | Select-Object -ExpandProperty FullName
    $BaseConfig["Drivers"] = Get-ChildItem -Path $BaseConfig.PathDrivers -Filter "*.*" | Select-Object -ExpandProperty FullName
    $BaseConfig["SvrVHDX"] = Get-ChildItem -Path $BaseConfig.PathRefImage | Where-Object {$_.Name -eq $ServerRefConfig.RefVHDXName} |  Select-Object -ExpandProperty FullName
    $BaseConfig["WksVHDX"] = Get-ChildItem -Path $BaseConfig.PathRefImage | Where-Object {$_.Name -eq $WorkstationRefConfig.RefVHDXName} |  Select-Object -ExpandProperty FullName

    $BaseConfig["LocalAdminName"] = ".\$($LabEnvConfig.EnvAdminName)"
    $BaseConfig["LocalAdminPassword"] = ConvertTo-SecureString -String $LabEnvConfig.EnvAdminPW -AsPlainText -Force
    $BaseConfig["LocalAdminCreds"] = new-object -typename System.Management.Automation.PSCredential($BaseConfig.LocalAdminName, $BaseConfig.LocalAdminPassword)

    $BaseConfig["DomainAdminName"] = "$($LabEnvConfig.EnvNetBios)\$($LabEnvConfig.EnvAdminName)"
    $BaseConfig["DomainAdminPassword"] = ConvertTo-SecureString -String $LabEnvConfig.EnvAdminPW -AsPlainText -Force
    $BaseConfig["DomainAdminCreds"] = new-object -typename System.Management.Automation.PSCredential($BaseConfig.DomainAdminName,$BaseConfig.DomainAdminPassword)

    $ServerVMs = $RawENVConfig.ServerVMList | ForEach-Object {
        $VMConfig = [PSCustomObject]@{}
        ($_[0]).psobject.properties | foreach-Object {$VMConfig | Add-Member -NotePropertyName $_.Name -NotePropertyValue $_.Value -ErrorAction SilentlyContinue}
        $VMConfig | Add-Member -NotePropertyName "VHDX" -NotePropertyValue $Null -ErrorAction SilentlyContinue
        $VMConfig | Add-Member -NotePropertyName "VMIPAddress" -NotePropertyValue $Null -ErrorAction SilentlyContinue
        $VMConfig | Add-Member -NotePropertyName "VMWinName" -NotePropertyValue $Null -ErrorAction SilentlyContinue
        $VMConfig | Add-Member -NotePropertyName "VMName" -NotePropertyValue $Null -ErrorAction SilentlyContinue
        $VMConfig | Add-Member -NotePropertyName "VMHDPath" -NotePropertyValue $Null -ErrorAction SilentlyContinue
        $VMConfig | Add-Member -NotePropertyName "VMHDName" -NotePropertyValue $Null -ErrorAction SilentlyContinue
        $VMConfig | Add-Member -NotePropertyName "EnableSnapshot" -NotePropertyValue $Null -ErrorAction SilentlyContinue
        $VMConfig | Add-Member -NotePropertyName "ProcessorCount" -NotePropertyValue $Null -ErrorAction SilentlyContinue
        $VMConfig | Add-Member -NotePropertyName "StartupMemory" -NotePropertyValue $Null -ErrorAction SilentlyContinue
        $VMConfig | Add-Member -NotePropertyName "UseUnattend" -NotePropertyValue $Null -ErrorAction SilentlyContinue

        $VMConfig.VHDX = $BaseConfig.SvrVHDX
        $VMConfig.VMIPAddress = "$($LabEnvConfig.EnvIPSubnet)$($_.VMIPLastOctet)"
        $VMConfig.VMWinName = "$($_.VMName)"
        $VMConfig.VMName = "$($LabEnvConfig.Env)-$($_.VMName)"
        $VMConfig.VMHDPath = "$($BaseConfig.VMPath)\$($VMConfig.VMName)\Virtual Hard Disks"
        $VMConfig.VMHDName = "$($VMConfig.VMName)c.vhdx"
        $VMConfig.EnableSnapshot = if ($_.EnableSnapshot -eq 1) {$true} else {$false}
        $VMConfig.AutoStartup = if ($_.AutoStartup -eq 1) {$true} else {$false}
        $VMConfig.ProcessorCount = "$($_.ProcessorCount)"
        $VMConfig.StartupMemory = [int64]$_.StartupMemory.Replace('gb','') * 1GB
        $VMConfig.UseUnattend = "$($_.UseUnattend)"
        $VMConfig
    }

    $WorkstationVMs = $RawENVConfig.WorkstationVMList | ForEach-Object {
        $VMConfig = [PSCustomObject]@{}
        ($_[0]).psobject.properties | foreach-Object {$VMConfig | Add-Member -NotePropertyName $_.Name -NotePropertyValue $_.Value -ErrorAction SilentlyContinue}
        $VMConfig | Add-Member -NotePropertyName "VHDX" -NotePropertyValue $Null -ErrorAction SilentlyContinue
        $VMConfig | Add-Member -NotePropertyName "VMWinName" -NotePropertyValue $Null -ErrorAction SilentlyContinue
        $VMConfig | Add-Member -NotePropertyName "VMName" -NotePropertyValue $Null -ErrorAction SilentlyContinue
        $VMConfig | Add-Member -NotePropertyName "VMHDPath" -NotePropertyValue $Null -ErrorAction SilentlyContinue
        $VMConfig | Add-Member -NotePropertyName "VMHDName" -NotePropertyValue $Null -ErrorAction SilentlyContinue
        $VMConfig | Add-Member -NotePropertyName "EnableSnapshot" -NotePropertyValue $Null -ErrorAction SilentlyContinue
        $VMConfig | Add-Member -NotePropertyName "AutoStartup" -NotePropertyValue $Null -ErrorAction SilentlyContinue
        $VMConfig | Add-Member -NotePropertyName "StartupMemory" -NotePropertyValue $Null -ErrorAction SilentlyContinue
        $VMConfig | Add-Member -NotePropertyName "UseUnattend" -NotePropertyValue $Null -ErrorAction SilentlyContinue

        $VMConfig.VHDX = $BaseConfig.WksVHDX
        $VMConfig.VMWinName = "$($_.VMName)"
        $VMConfig.VMName = "$($LabEnvConfig.Env)-$($_.VMName)"
        $VMConfig.VMHDPath = "$($BaseConfig.VMPath)\$($VMConfig.VMName)\Virtual Hard Disks"
        $VMConfig.VMHDName = "$($VMConfig.VMName)c.vhdx"
        $VMConfig.EnableSnapshot = if ($_.EnableSnapshot -eq 1) {$true} else {$false}
        $VMConfig.AutoStartup = if ($_.AutoStartup -eq 1) {$true} else {$false}
        $VMConfig.StartupMemory = [int64]$_.StartupMemory.Replace('gb','') * 1GB
        $VMConfig.UseUnattend = "$($_.UseUnattend)"
        $VMConfig
    }
    <#TODO
    $VMs = Get-VM
    $VLans = foreach ($VM in $VMs) {
        $VM | Get-VMNetworkAdapterVlan | Select -ExpandProperty AccessVlanId
    }

    $LabEnvConfig["VLanID"] =  if ($VLans) {
        ($VLans | Measure-Object -Maximum).Maximum + 1
    }
    else {
        1
    }
    #>
    
    #Setting these to avoiding needing to pass in creds with each lab connection test
    $Script:LocalAdminCreds = $BaseConfig.LocalAdminCreds
    $Script:DomainAdminCreds = $BaseConfig.DomainAdminCreds

    $Config = @{}
    $Config["BaseConfig"] = $BaseConfig
    $Config.BaseConfig["ServerRef"] = $ServerRefConfig
    $Config.BaseConfig["WorkstationRef"] = $WorkstationRefConfig

    $Config["LabEnvConfig"] = $LabEnvConfig
    $Config.LabEnvConfig["ServerVMs"] = $ServerVMs
    $Config.LabEnvConfig["WorkstationVMs"] = $WorkstationVMs
    return $Config
}