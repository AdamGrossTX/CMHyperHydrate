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

    Write-Host "Starting Get-LabConfig" -ForegroundColor Cyan

    $Config = Get-Content $ConfigFileName -Raw | ConvertFrom-Json
    $ENVConfig = $Config.ENVConfig | Where-Object {$_.ENV -eq $Config.ENVToBuild}
    $SvrRefConfig = $Config.ServerRef
    $WksRefConfig = $Config.WorkstationRef
    $Script:SvrVMs = $ENVConfig.ServerVMList
    $Script:WksVMs = $ENVConfig.WorkstationVMList
 
    $Script:base = @{}
    $Script:labEnv = @{}
    ($Config | Select-Object -Property * -ExcludeProperty "ENVConfig", "VMList", "ServerRef", "WorkstationRef").psobject.properties | foreach-Object {$Base[$_.Name] = $_.Value}
    ($ENVConfig  | Select-Object -Property * -ExcludeProperty  "ServerVMList", "WorkstationVMList").psobject.properties | foreach-Object {$Script:labEnv[$_.Name] = $_.Value}

    $Script:SvrRef = @{}
    foreach ($Img in $SvrRefConfig) {
        ($Img).psobject.properties | foreach-Object {$SvrRef[$_.Name] = $_.Value}
    }

    $Script:WksRef = @{}
    foreach ($Img in $WksRefConfig) {
        ($Img).psobject.properties | foreach-Object {$WksRef[$_.Name] = $_.Value}
    }

    $base["ConfigMgrCBPrereqsPath"] = "$($base.PathConfigMgr)\Prereqs"
    $base["ConfigMgrTPPrereqsPath"] = "$($base.PathConfigMgrTP)\Prereqs"

    foreach ($key in @($base.keys)) {
        If ($key -like "Path*")
        {
            $Base[$key] = $Base.SourcePath + $Base[$key]
            if ($CreateFolders) {
                if (-not (Test-Path -path $Base[$key])) {New-Item -path $Base[$key] -ItemType Directory;}
            }
        }
    }

    $base["VMPath"] = "$($base.LabPath)\$($script:labEnv.Env)"
    $base["SQLISO"] = Get-ChildItem -Path $base.PathSQL -Filter "*.ISO" | Select-Object -First 1 -ExpandProperty FullName
    $base["SvrISO"] = Get-ChildItem -Path $base.PathSvr -Filter "*.ISO" | Select-Object -First 1 -ExpandProperty FullName
    $base["WinISO"] = Get-ChildItem -Path $base.PathWin10 -Filter "*.ISO" | Select-Object -First 1 -ExpandProperty FullName
    $base["Packages"] = Get-ChildItem -Path $base.PathPackages -Filter "*.CAB" | Select-Object -ExpandProperty FullName
    $base["Drivers"] = Get-ChildItem -Path $base.PathDrivers -Filter "*.*" | Select-Object -ExpandProperty FullName
    $base["SvrVHDX"] = Get-ChildItem -Path $base.PathRefImage | Where-Object {$_.Name -eq $SvrRef.RefVHDXName} |  Select-Object -ExpandProperty FullName
    $base["WksVHDX"] = Get-ChildItem -Path $base.PathRefImage | Where-Object {$_.Name -eq $WksRef.RefVHDXName} |  Select-Object -ExpandProperty FullName

    $base["LocalAdminName"] = "Administrator"
    $base["LocalAdminPassword"] = ConvertTo-SecureString -String $script:labEnv.EnvAdminPW -AsPlainText -Force
    $base["LocalAdminCreds"] = new-object -typename System.Management.Automation.PSCredential($base.LocalAdminName, $base.LocalAdminPassword)

    $base["DomainAdminName"] = "$($script:labEnv.EnvNetBios)\$($script:labEnv.EnvAdminName)"
    $base["DomainAdminPassword"] = ConvertTo-SecureString -String $script:labEnv.EnvAdminPW -AsPlainText -Force
    $base["DomainAdminCreds"] = new-object -typename System.Management.Automation.PSCredential($base.DomainAdminName,$base.DomainAdminPassword)

    $VMs = Get-VM
    $VLans = foreach ($VM in $VMs) {
        $VM | Get-VMNetworkAdapterVlan | Select -ExpandProperty AccessVlanId
    }

    $Script:labEnv["VLanID"] =  if ($VLans) {
        ($VLans | Measure-Object -Maximum).Maximum + 1
    }
    else {
        1
    }
}
