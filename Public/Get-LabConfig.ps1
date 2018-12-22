Function Get-LabConfig {
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

    $Config = Get-Content $ConfigFileName -Raw | ConvertFrom-Json
    $ENVConfig = $Config.ENVConfig | Where-Object {$_.ENV -eq $Config.ENVToBuild}
    $SvrRefConfig = $Config.ServerRef
    $WksRefConfig = $Config.WorkstationRef
    $Global:SvrVMs = $ENVConfig.ServerVMList
    $Global:WksVMs = $ENVConfig.WorkstationVMList
 
    $Script:base = @{}
    $Script:env = @{}
    ($Config | Select-Object -Property * -ExcludeProperty "ENVConfig", "VMList", "ServerRef", "WorkstationRef").psobject.properties | ForEach-Object {$Base[$_.Name] = $_.Value}
    ($ENVConfig  | Select-Object -Property * -ExcludeProperty  "ServerVMList", "WorkstationVMList").psobject.properties | ForEach-Object {$env[$_.Name] = $_.Value}

    $Script:SvrRef = @{}
    ForEach ($Img in $SvrRefConfig) {
        ($Img).psobject.properties | ForEach-Object {$SvrRef[$_.Name] = $_.Value}
    }

    $Script:WksRef = @{}
    ForEach ($Img in $WksRefConfig) {
        ($Img).psobject.properties | ForEach-Object {$WksRef[$_.Name] = $_.Value}
    }

    ForEach ($key in @($base.keys)) {
        If ($key -like "Path*")
        {
            $Base[$key] = $Base.LabPath + $Base[$key]
            If($CreateFolders) {
                If(!(Test-Path -path $Base[$key])) {New-Item -path $Base[$key] -ItemType Directory;}
            }
        }
    }

    $base["VMPath"] = "$($base.PathLab)\$($base.ENVToBuild)"
    $base["SQLISO"] = Get-ChildItem -Path $base.PathSQL -Filter "*.ISO" | Select-Object -First 1 -ExpandProperty FullName
    $base["SvrISO"] = Get-ChildItem -Path $base.PathSvr -Filter "*.ISO" | Select-Object -First 1 -ExpandProperty FullName
    $base["WinISO"] = Get-ChildItem -Path $base.PathWin10 -Filter "*.ISO" | Select-Object -First 1 -ExpandProperty FullName
    $base["Packages"] = Get-ChildItem -Path $base.Packages -Filter "*.CAB" | Select-Object -ExpandProperty FullName
    $base["Drivers"] = Get-ChildItem -Path $base.PathDrivers -Filter "*.*" | Select-Object -ExpandProperty FullName
    $base["SvrVHDX"] = "$($base.PathRefImage)\$($SvrRef.RefVHDXName)"
    $base["WksVHDX"] = "$($base.PathRefImage)\$($WksRef.RefVHDXName)"

    $base["LocalAdminName"] = "Administrator"
    $base["LocalAdminPassword"] = ConvertTo-SecureString -String $env.EnvAdminPW -AsPlainText -Force
    $base["LocalAdminCreds"] = new-object -typename System.Management.Automation.PSCredential($base.LocalAdminName, $base.LocalAdminPassword)

    $base["DomainAdminName"] = "$($Env.EnvNetBios)\Administrator"
    $base["DomainAdminPassword"] = ConvertTo-SecureString -String $env.EnvAdminPW -AsPlainText -Force
    $base["DomainAdminCreds"] = new-object -typename System.Management.Automation.PSCredential($base.DomainAdminName,$base.DomainAdminPassword)
}
