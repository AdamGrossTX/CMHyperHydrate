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
    $WSRefConfig = $Config.WorkstationRef
    $Script:VMList = $ENVConfig.VMList

    $Script:base = @{}
    $Script:env = @{}
    ($Config | Select-Object -Property * -ExcludeProperty "ENVConfig", "VMList", "ServerRef", "WorkstationRef").psobject.properties | ForEach-Object {$Base[$_.Name] = $_.Value}
    ($ENVConfig  | Select-Object -Property * -ExcludeProperty  "VMList").psobject.properties | ForEach-Object {$env[$_.Name] = $_.Value}

    ForEach ($key in @($base.keys)) {
        If ($key -like "Path*")
        {
            $Base[$key] = $Base.LabPath + $Base[$key]
            If($CreateFolders) {
                If(!(Test-Path -path $Base[$key])) {New-Item -path $Base[$key] -ItemType Directory;}
            }
        }
    }

    $Script:SvrRef = @{}
    ForEach ($Img in $SvrRefConfig) {
        ($Img).psobject.properties | ForEach-Object {$SvrRef[$_.Name] = $_.Value}
    }

    $Script:WSRef = @{}
    ForEach ($Img in $WSRefConfig) {
        ($Img).psobject.properties | ForEach-Object {$WSRef[$_.Name] = $_.Value}
    }

    $base["VMPath"] = "$($base.PathLab)\$($base.ENVToBuild)"
    $base["SQLISO"] = Get-ChildItem -Path $base.PathSQL -Filter "*.ISO" | Select-Object -First 1 -ExpandProperty FullName
    $base["Server2016ISO"] = Get-ChildItem -Path $base.PathSvr2K16 -Filter "*.ISO" | Select-Object -First 1 -ExpandProperty FullName
    $base["Windows10ISO"] = Get-ChildItem -Path $base.PathWin10 -Filter "*.ISO" | Select-Object -First 1 -ExpandProperty FullName
    $base["NET35CAB"] = Get-ChildItem -Path $base.PathDotNET35 -Filter "*.CAB" | Select-Object -First 1 -ExpandProperty FullName
    $base["Svr2016VHDX"] = "$($PathRefImage)\$($ServerRef.RefVHDXName)"
    $base["Win10VHDX"] = "$($RefPath)\$($WorkstationRef.RefVHDXName)"

    $base["LocalAdminName"] = "Administrator"
    $base["LocalAdminPassword"] = ConvertTo-SecureString -String $env.EnvAdminPW -AsPlainText -Force
    $base["LocalAdminCreds"] = new-object -typename System.Management.Automation.PSCredential($base.LocalAdminName, $base.LocalAdminPassword)

    $base["DomainAdminName"] = "$($Env.EnvNetBios)\Administrator"
    $base["DomainAdminPassword"] = ConvertTo-SecureString -String $env.EnvAdminPW -AsPlainText -Force
    $base["DomainAdminCreds"] = new-object -typename System.Management.Automation.PSCredential($base.DomainAdminName,$base.DomainAdminPassword)
}
