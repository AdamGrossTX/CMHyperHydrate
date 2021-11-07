#I borrowed this code from AutomatedLab and made a few changes to it for this lab build.

function Convert-LabISOToVHDX {
    [Cmdletbinding()]
    Param (
        #ISO of OS
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        #Path to reference VHD
        [Parameter(Mandatory = $true)]
        [string]$VhdPath,

        #Path to reference VHD
        [Parameter(Mandatory = $true)]
        [string]$Edition,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateRange(512MB, 64TB)]
        [UInt64]$SizeBytes = 25GB,

        [Parameter()]
        [string]$UnattendPath,

        [Parameter()]
        [string]$Feature
    )

    try {
        Write-Output (Get-Date)
        Mount-DiskImage -ImagePath $SourcePath
        $ISOImage = Get-DiskImage -ImagePath $SourcePath | Get-Volume
        $InstallWIMPath = Get-Item -Path "$($ISOImage.DriveLetter)`:\Sources\install.*" -ErrorAction SilentlyContinue | Where-Object Name -Match '.*\.(esd|wim)'
        $ImageInfo = Get-WindowsImage -ImagePath $InstallWIMPath

        $EditionIndex = 0;
        if ([Int32]::TryParse($Edition, [ref]$EditionIndex))
        {
            $Image = $ImageInfo | Where-Object { $_.ImageIndex -eq $Edition }
        }
        else
        {
            $Image = $ImageInfo | Where-Object { $_.ImageName -eq $Edition }
        }

        $ImageIndex = $image.ImageIndex

        $vmDisk = New-VHD -Path $VhdPath -SizeBytes $SizeBytes -ErrorAction Stop
        Mount-DiskImage -ImagePath $VhdPath
        $vhdDisk = Get-DiskImage -ImagePath $VhdPath | Get-Disk
        $vhdDiskNumber = [string]$vhdDisk.Number

        Initialize-Disk -Number $vhdDiskNumber -PartitionStyle 'GPT' | Out-Null
    
        $vhdRecoveryPartition = New-Partition -DiskNumber $vhdDiskNumber -GptType '{de94bba4-06d1-4d40-a16a-bfd50179d6ac}' -Size 300MB
        $vhdRecoveryDrive = $vhdRecoveryPartition | Format-Volume -FileSystem NTFS -NewFileSystemLabel 'Windows RE Tools' -Confirm:$false

        $recoveryPartitionNumber = (Get-Disk -Number $vhdDiskNumber | Get-Partition | Where-Object Type -eq Recovery).PartitionNumber
        $diskpartCmd = @"
select disk $vhdDiskNumber
select partition $recoveryPartitionNumber
gpt attributes=0x8000000000000001
exit
"@
        $diskpartCmd | diskpart.exe | Out-Null

        $systemPartition = New-Partition -DiskNumber $vhdDiskNumber -GptType '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}' -Size 100MB
        #does not work, seems to be a bug. Using diskpart as a workaround
        #$systemPartition | Format-Volume -FileSystem FAT32 -NewFileSystemLabel 'System' -Confirm:$false

        $diskpartCmd = @"
select disk $vhdDiskNumber
select partition $($systemPartition.PartitionNumber)
format quick fs=fat32 label=System
exit
"@
        $diskpartCmd | diskpart.exe | Out-Null

        $reservedPartition = New-Partition -DiskNumber $vhdDiskNumber -GptType '{e3c9e316-0b5c-4db8-817d-f92df00215ae}' -Size 128MB

        if ($FDVDenyWriteAccess) {
            Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Policies\Microsoft\FVE -Name FDVDenyWriteAccess -Value 0
        }
        $vhdWindowsDrive = New-Partition -DiskNumber $vhdDiskNumber -UseMaximumSize -AssignDriveLetter |
        Format-Volume -FileSystem NTFS -NewFileSystemLabel 'System' -Confirm:$false
        

        $vhdWindowsVolume = "$($vhdWindowsDrive.DriveLetter):"
        if (Test-Path -Path C:\Windows\System32\manage-bde.exe) {
            manage-bde.exe -off $vhdWindowsVolume | Out-Null #without this on some devices (for exmaple Surface 3) the VHD was auto-encrypted
        }

        Expand-WindowsImage -ImagePath $InstallWIMPath -Index $imageIndex -ApplyPath "$($vhdWindowsVolume)\"

        Write-Output 'Setting BCDBoot'
        $possibleDrives = [char[]](65..90)
        $drives = (Get-PSDrive -PSProvider FileSystem).Name
        $freeDrives = Compare-Object -ReferenceObject $possibleDrives -DifferenceObject $drives | Where-Object { $_.SideIndicator -eq '<=' }
        $freeDrive = ($freeDrives | Select-Object -First 1).InputObject

        $diskpartCmd = @"
select disk $vhdDiskNumber
select partition $($systemPartition.PartitionNumber)
assign letter=$freeDrive
exit
"@
        $diskpartCmd | diskpart.exe | Out-Null

        bcdboot.exe $vhdWindowsVolume\Windows /s "$($freeDrive):" /f UEFI | Out-Null

        $diskpartCmd = @"
select disk $vhdDiskNumber
select partition $($systemPartition.PartitionNumber)
remove letter=$freeDrive
exit
"@
        $diskpartCmd | diskpart.exe | Out-Null


        if($feature) {
            $FeatureSourcePath = Join-Path -Path "$($ISOImage.DriveLetter):" -ChildPath "sources\sxs"
            Enable-WindowsOptionalFeature -FeatureName $Feature -Source $FeatureSourcePath -Path $vhdWindowsVolume -All | Out-Null
        }

        if($UnattendPath) {
            if(Test-Path -Path $UnattendPath) {
                Copy-Item -Path $UnattendPath -Destination $vhdWindowsVolume -ErrorAction Continue
            }
            else {
                Write-Output "No Unattend File Found at $($UnattendPath)"
            }
        }
        [void] (Dismount-DiskImage -ImagePath $VhdPath)
        [void] (Dismount-DiskImage -ImagePath $SourcePath)
        if ($FDVDenyWriteAccess) {
            Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Policies\Microsoft\FVE -Name FDVDenyWriteAccess -Value $FDVDenyWriteAccess
        }
    }
    catch {
        throw $_
    }

    Write-Output (Get-Date)
}

#Convert-IsoToVHDX -SourcePath "C:\Labs\ISO\Server\en_windows_server_2019_updated_sept_2019_x64_dvd_199664ce.iso" -VhdPath "C:\Labs\ISO\Server\WinSvr2019Ref.VHDX" -Edition 2 -SizeBytes 25GB -UnattendPath "C:\Labs\ISO\Windows\unattend.xml" -Feature "NetFx3"