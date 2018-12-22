Function Set-LabFolders {
    [CmdLetBinding()]
    Param (
    [Parameter()]
    [Alias("cfg")]
    [hashtable]
    $VMConfig
    )


$VMPath = "\$($cfg.ENV)"



#region setup up paths
$SQLPath         = "$($VMConfig.SourceFolderPath)\Media\ISO\SQL"
$Server2016Path  = "$($VMConfig.SourceFolderPath)\Media\ISO\Server2016"
$Windows10Path   = "$($VMConfig.SourceFolderPath)\Media\ISO\Windows10"
$ADKPath         = "$($VMConfig.SourceFolderPath)\Media\ADK"
$ADKWinPEPath    = "$($VMConfig.SourceFolderPath)\Media\ADKWinPE"
$SCCMTPPath      = "$($VMConfig.SourceFolderPath)\Media\SCCMTP"
$SCCMPath        = "$($VMConfig.SourceFolderPath)\Media\SCCM"
$NET35CABPath    = "$($VMConfig.SourceFolderPath)\Media\DotNET35"
$RefPath         = "$($VMConfig.SourceFolderPath)\ReferenceImage"
$VMPath          = "$($VMConfig.DestinationFolderPath)\$($VMConfig.ENV)"
$VMDataPath      = "\Data"

$FolderList = @()
$FolderList += $SQLPath
$FolderList += $Server2016Path
$FolderList += $Windows10Path
$FolderList += $ADKPath
$FolderList += $ADKWinPEPath
$FolderList += $SCCMTPPath
$FolderList += $SCCMPath
$FolderList += $NET35CABPath
$FolderList += $RefPath
$FolderList += $VMPath

ForEach($Folder in $FolderList) {
    If(!(Test-Path -path $Folder)) {New-Item -path $Folder -ItemType Directory;}
}

$SQLISO = Get-ChildItem -Path $SQLPath -Filter "*.ISO" | Select-Object -First -ExpandProperty FullName
$Server2016ISO = Get-ChildItem -Path $Server2016Path -Filter "*.ISO" | Select-Object -First -ExpandProperty FullName
$Windows10ISO = Get-ChildItem -Path $Win10Path -Filter "*.ISO" | Select-Object -First -ExpandProperty FullName
$NET35CAB = Get-ChildItem -Path $NET35CABPath -Filter "*.CAB" | Select-Object -First -ExpandProperty FullName
$Svr2016VHDX = "$($RefPath)\$($VMConfig.Server2016RefVHDX)"
$Win10VHDX = "$($RefPath)\$($VMConfig.Windows1809RefVHDX)"

$LocalAdminName = "Administrator"
$LocalAdminPassword = ConvertTo-SecureString -String $envVMConfig.AdminPW -AsPlainText -Force
$LocalAdminCreds = new-object -typename System.Management.Automation.PSCredential($LocalAdminName, $LocalAdminPassword)

$DomainAdminName = "$($EnvVMConfig.DomainNetBiosName)\Administrator"
$DomainAdminPassword = ConvertTo-SecureString -String $envVMConfig.AdminPW -AsPlainText -Force
$DomainAdminCreds = new-object -typename System.Management.Automation.PSCredential($DomainAdminName,$DomainAdminPassword)

}
