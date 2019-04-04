<#
    ************************************************************************************************************
    Copyright (c) Microsoft Corporation.  All rights reserved.
    Microsoft Consulting Services

    File:        SetupLab.ps1

    Version:     11

    Modified:   10/09/2015

    Purpose:    Processes the XML lab definition and configures Hyper-V or Azure IaaS to setup virtual machines 
                and networks.
                Prepares each VM to commence hydration of the operating system and roles.

    Pre-Reqs:   Windows Server 2012 R2
                Windows PowerShell 4.0
                Microsoft Azure PowerShell RM

    ************************************************************************************************************
#>



<#
  .SYNOPSIS
  Manages the provisioning of virtual machines and virtual networks in using a configuration file. 
  Copyright (c) Microsoft Corporation.  All rights reserved.
  Microsoft Consulting Services
  .DESCRIPTION
  The script operates in multiple modes:
    -Mode Purge
        Used to purge a specific lab configuration from a hyper-v host. All virtual devices and guest files are deleted. This is only for Hyper-V and does not apply to Azure provisionig.
    -Mode Clean
        Used to remove the hydration system from the guests in a hyper-v deployment only. THis does not apply to an Azure provisioning.
    -Mode Provision
        Used to implement a lab definition on a Windows Server 2012 R2 Hyper-V host.
    -Mode Azure
        Used to provision a lab definition in Azure IaaS.
    -LabConfigFile
        File path to the XML definition file for the lab being provisioned.
    -ExtendLab
        Switch used to augment an existing lab based on a lab definition file. If specified, additional virtual switches and guests are provisioned from the lab definition file. If not specified, the lab is not extended. Do not specify when provisioning a new lab environment. Does not apply to Azure provisioning.
    -GuestName
        Used to provide a comma separate list of guests to be purged and re-provisioned. Provide the guest name as displayed in the Hyper-V Manager. Domain controllers CANNOT be re-provisioned - purge the lab and re-provision in its entirety. Does not apply to Azure provisioning.
    -CopyVHD
        Switch used to specify that the OS Virtual Disk for the VM should be a copy of the ServerParent.VHDX. If omitted, the VM is provisioned with a differencing disk for the OS. Does not apply to Azure provisioning.
    -ProductKey
        Used to specify a product key to be used with virtual machines. This can be useful when you are using non-volume media. This is optional and is not require with volume media. Does not apply to Azure provisioning.
    -InternetSwitchOveride
        Name of external Hyper-V Network Switch used to bind lab environment to the internet (Optional)
    -StartLab
        Switch used to specify if machines are started after they are created. If specified, all server virtual machines will be started after they are created. Does not apply to Azure provisioning.
    -Gen2
        Switch used to specify the all CLIENT guests should be created as Generation 2 virtual machines. Used in conjunction with the Provision mode. Does not apply to Azure provisioning.
    -Force
        Switch to force the deletion of a lab scenario. Does not apply to Azure provisioning.
   .EXAMPLE
  Implement a lab from a specified definition file as Generation 2 virtual machines. Existing virtual hardware is unaffected. The -StartLab switch may be used to start each guest as it is provisioned.
  .\SetupLab.ps1 -Mode Provision -LabConfigFile .\LabDefinitions\BaseLabDefinition.xml
  .EXAMPLE
  Implement a lab from a specified definition file in Azure IaaS. Only server roels that are supported in Azure IaaS will be provisioned.
  .\SetupLab.ps1 -Mode Azure -LabConfigFile .\LabDefinitions\BaseLabDefinition.xml
  .EXAMPLE
  This command will iterate through the lab definition and provision the hardware that does not exist. Existing virtual hardware is unaffected.
  .\SetupLab.ps1 -Mode Provision -LabConfigFile .\LabDefinitions\AugmentedLabDefinition.xml -ExtendLab
  .EXAMPLE
  Re-provision specific hosts in an implemented lab. multiple hosts may be comma separated. Provide the guest name as displayed in the Hyper-V Manager. Existing virtual hardware is unaffected.
  .\SetupLab.ps1 -Mode Provision -LabConfigFile .\LabDefinitions\BaseLabDefinition.xml -GuestName Lab-SRV1,Lab-Srv2
  .EXAMPLE
  Prepare the system for handover to the customer. Remove the hydration VHD from each guest. Confirmation is requested before purging. Virtual hardware not in the configuration file is unaffected.
  .\SetupLab.ps1 -Mode Clean -LabConfigFile .\LabDefinitions\BaseLabDefinition.xml
  .EXAMPLE
  Purge a lab environment from the host. Confirmation is requested before purging. Virtual hardware not in the configuration file is unaffected. Use -Force to immediately force the deletion without confirmation.
  .\SetupLab.ps1 -Mode Purge -LabConfigFile .\LabDefinitions\BaseLabDefinition.xml
  .EXAMPLE
  Create a lab environment and apply a specified Product Key to all servers and start each server guest.
  .\SetupLab.ps1 -Mode Purge -LabConfigFile .\LabDefinitions\BaseLabDefinition.xml  -ProductKey="11111-22222-33333-44444-55555" -StartLab
  .EXAMPLE
  Create a lab environment and apply a specified external switch to the Lab.
  .\SetupLab.ps1 -Mode Purge -LabConfigFile .\LabDefinitions\BaseLabDefinition.xml -StartLab -InternetSwitchOveride "External Switch 2"

#>

<# Begin Script#>
# Script parameters
    [cmdletbinding()]
    Param(

        [ValidateSet("Purge","Clean","Provision","Azure")][Parameter(Mandatory=$false,ValueFromPipeline=$false)]$Mode,
        [Parameter(Mandatory=$True,ValueFromPipeline=$True)][string[]]$LabConfigFile,
        [Switch]$CopyVHD,
        [Switch]$StartLab,
        [Switch]$Gen2 = $true,
        [string] $Version,
        [PSCredential] $Cred,
        [Parameter(Mandatory=$False,ValueFromPipeline=$False)][string[]]$ProductKey,
        [Switch]$ExtendLab,
        [string] $isLabKit = 'false',
        [Parameter(Mandatory=$False,ValueFromPipeline=$False)][string[]]$GuestName,
        [Parameter(Mandatory=$False,ValueFromPipeline=$False)][string]$InternetSwitchOveride,
        [string] $AUOptions = '3',
        [Switch]$Force

    )
# End Script Parameters


# Global variables
    [xml]$LabDefinition=$NULL
    $LabStorePath=$NULL
    $GuestRoleStorePath=$NULL
    [string]$Comment=$NULL
    $ScriptPath=$NULL
    $HydrationVHD=$NULL
    $ServerOSVHD=$NULL
    $DiskType=$NULL
    $UnattendXML=$NULL
    $BOOTSTRAP=$NULL
    $DCINI=$NULL
    $MDTINI=$NULL
    $APPOSDELIVERYINI=$NULL
    $CORPAPPINI=$NULL
    $INTERNETINI=$NULL
    $REMOTEACCESSINI=$NULL
    $RDSHINI=$NULL
    $RDCBINI=$NULL
    $SCOM=$NULL
    $SCVMM=$NULL
    $ERRORFAIL=-1


#region Support functions

    Function Get-IsElevated
    {
         <#
            .SYNOPSIS
                .Function to determine whether or not the script has been run elevated.

            .DESCRIPTION
                Returns True if script is being run elevsted, False if not.

            .EXAMPLE
                PS C:\> Get-IsElevated
        #>
        process {
                $IsElevated = $null
                $WindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
                $WindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($WindowsID)
                $AdministratorRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator
                if ($WindowsPrincipal.IsInRole($AdministratorRole))
                {
                    $IsElevated = $true
                }
                else
                {
                    $IsElevated = $false
                }
                Return $IsElevated
            } #end Process
        } #end Get-IsElevated

    Function Fix-Elevation
    {
     if ($Invocation.ScriptName -ne "")
        {
            if (!(Get-IsElevated))
            {
                try
                {
                    $MyInvocation = (Get-Variable MyInvocation -Scope 1).Value
                    [string[]]$argList = @('-NoProfile', '-NoExit', '-File', $MyInvocation.MyCommand.Path)
                    $argList += $MyInvocation.BoundParameters.GetEnumerator() | Foreach {"-$($_.Key)", "$($_.Value)"}
                    $argList += $MyInvocation.UnboundArguments
                    if ($Script:LabConfigFile.startsWith("."))
                    {
                        $temp=$Script:LabConfigFile.substring(1,$Script:LabConfigFile.length-1)
                        $New="$pwd$temp"
                        $arglist = $arglist.Replace($Script:LabConfigFile,$new)
                    }

                    Start-Process "$psHome\PowerShell.exe" -Verb Runas -WorkingDirectory $pwd -ArgumentList $argList 

                }
                catch
                {
                    Write-LogEntry "Error - Failed to restart script with runas" -Level "error"
                    break
                }
                #exit # Quit this session of powershell
            }
        }
        else
        {
            Write-Warning "Error - Script must be saved as a .ps1 file first"
            break
        }

    } #end Fix-Elevated

    #    Determine where the script is executing from
    Function Get-ScriptPath
    {
        $Invocation = (Get-Variable MyInvocation -Scope 1).Value
        Split-Path $Invocation.MyCommand.Path
    }

    #   Create the lab store folder
    Function New-LabStore()
    {
        Write-LogEntry "Provisioning labstore..."
        if ((Test-Path $Script:LabStorePath) -ne $True)
        {
            Try
            {
                New-Item "$Script:LabStorePath" -type directory -ErrorAction Stop | out-null
                Write-LogEntry "`tLabstore created at $Script:LabStorePath" -level "info"
            }
            #else
            Catch
            {
               Write-LogEntry "`tError creating the labstore at $Script:LabStorePath. `nExiting script." -level "warning"
               Exit $ERRORFAIL
            }
        }
        else
        {
            If (($ExtendLab -eq $False) -or ($ExtendLab -eq $NULL))
            {
                Write-LogEntry "`tLabStore folder exists at $Script:LabStorePath. `nExiting script." -level "warning"
                Exit $ERRORFAIL
            }
            else
            {
                # Use existing lab store
            }
        }
    }

     #   Create the Guest lab store folder
    Function Set-GuestLabStore($FolderPath)
    {
        Write-LogEntry "Provisioning Guest labstore..."
        if ((Test-Path $FolderPath) -ne $True)
        {
            Try
            {
                New-Item "$FolderPath" -type directory -ErrorAction Stop | out-null
                Write-LogEntry "`tGuest Labstore created at $FolderPath" -level "info"
            }
            #else
            Catch
            {
               Write-LogEntry "`tError creating the Guest labstore at $FolderPath. `nExiting script." -level "warning"
               Exit $ERRORFAIL
            }
        }
    }

    #   Logging routine
    Function Write-LogEntry([string]$LogEntry,$level,$foregroundColor)
    {
        Write-Output "$(Get-Date) [$level] $LogEntry" | Out-File -FilePath $Script:ScriptPath"\LabSetup.log" -Append

        if($Level -eq "warning"){Write-warning $LogEntry}
        elseif($Level -eq "verbose"){Write-Verbose $LogEntry}
        elseif($Level -eq "error"){Write-error $LogEntry -erroraction Continue}
        elseif (-not $ForegroundColor ) { Write-Host $LogEntry }
        elseif( $Host.Name -eq "PowershellWizardHost" ) { Write-Host -ForegroundColor $ForeGroundColor -BackgroundColor White}
        else { Write-Host $LogEntry -ForegroundColor $ForeGroundColor }
    }

    #   Retrieve the content of the lab configuration XML file
    Function Get-LabXMLDefinition ($FilePath)
    {
        Try
        {
            $TempXML = Get-Content $FilePath -ErrorAction Stop
            $Script:LabDefinition = $TempXML.Replace("my:","")
        }
        catch
        {
            #Write-LogEntry "Unable to access configuration file at $FilePath. Ensure that you have provided the full path to the file. `nExiting script."
            Write-LogEntry "Unable to access configuration file at $FilePath. Ensure that you have provided the full path to the file. `nExiting script." -level "warning"
            Exit $ERRORFAIL
        }
    }

    #   Prepare the information to store in the virtual device comments
    Function Get-Comments
    {
        [string]$Comment = $Null
        $Comment = "Lab Owner: " + $LabDefinition.myFields.ENGAGEMENT.CUSTOMERLABOWNER.FULLNAME + "`n" + " `/ " + $LabDefinition.myFields.ENGAGEMENT.CUSTOMERLABOWNER.EMAILADDRESS + "`n"
        $Comment += "Consultant: " + $LabDefinition.myFields.ENGAGEMENT.DELIVERYCONSULTANT.FULLNAME + " `/ " + $LabDefinition.myFields.ENGAGEMENT.DELIVERYCONSULTANT.EMAILADDRESS + "`n"
        return $Comment
    }

    # Create all virtual switches
    Function New-LabNetwork
    {
        Write-LogEntry "Provisioning virtual network switches..."
        #Write-LogEntry "Provisioning virtual network switches..."
        # Process all Switches in the manifest
        $LABID=$Script:LabDefinition.myFields.HOSTENVIRONMENT.LABID
        $Sample = ($LabDefinition.myFields.HOSTENVIRONMENT.VirtualSwitches.VIRTUALSWITCH).count
        #If (($LabDefinition.myFields.HOSTENVIRONMENT.VirtualSwitches.VIRTUALSWITCH).count -gt 0)
        #{
            foreach ($Switch in $LabDefinition.myFields.HOSTENVIRONMENT.VirtualSwitches.VIRTUALSWITCH)
            {
                $SwitchName = $LabID+"-"+$Switch.SWITCHNAME
                # Try to find switch and create if not found
                $SwitchExists = Get-VMSwitch * | where {$_.Name -eq $SwitchName}
                if($SwitchExists -eq $Null)
                {
                    Write-LogEntry (" `t Creating virtual switch named " + $SwitchName + " of type " + $Switch.SWITCHTYPE)
                    try
                    {
                        New-VMSwitch -Name $SwitchName -SwitchType $Switch.SWITCHTYPE  -Notes $Script:COMMENT -ErrorAction Stop | Out-Null
                    }
                    catch
                    {
                        #Write-LogEntry "`tError creating"$SwitchName". `nExiting script."
                        $LastError = $Error[0]
                        Write-LogEntry "`tError creating $SwitchName Exiting script. $LastError" -level "warning"
                        Exit $ERRORFAIL
                    }
                    Write-LogEntry "`t$SwitchName created." -level "info"
                }
                else
                {
                    Write-LogEntry "`t$SwitchName exists. Skipping." -level "info"
                }

            }
            Write-LogEntry ("`tVirtual network switches successfully provisioned.") -level "info"
            #Write-LogEntry ("All switches successfully provisioned.")
        #}
        #else
        #{
        #    Write-LogEntry ("`tNoSwitches to provision.") -level "info"
        #    #Write-LogEntry ("No switches to provision.")
        #}
    }

    Function Process-VisioGuestRoles($GuestRoles)
    {
        ForEach ($GuestRole in $GuestRoles.GuestRole)
        {
            ForEach ($Role in $GuestRole.ChildNodes)
            {
                ForEach ($Item in $Role.ChildNodes){
                    if ($Role.Name -eq "NAME")
                    {
                        $RoleName = "INSTALL"+$Role.InnerText
                        Write-LogEntry $RoleName -ForegroundColor Cyan
                        Set-IniFile  -file $Script:GuestINI -category "Configuration" -key  "'//$RoleName" -value "will be installed"
                        Set-INIFile -file $Script:GuestINI -category "Configuration" -key $RoleName -value "YES"
                        Add-INIProperties $RoleName
                    }
                    else
                    {

                        Write-LogEntry "$($Role.Name)=$($Role.InnerText)" -ForegroundColor Magenta
                        Set-INIFile -file $Script:GuestINI -category "Configuration" -key $Role.Name -value $Role.InnerText
                        Add-INIProperties $Role.Name
                    }
                }
            }
        }
    }

    Function Process-GuestRoles($GuestRoles)
    {
        if ($Designer -eq "InfoPath")
        {
            ForEach ($GuestRole in $GuestRoles.GuestRole)
            {
                $TopLevelNode = $GuestRole.Sections.Section | ? { $_.Properties.Level -eq 1 }
                Process-Nodes $GuestRole.Sections.Section $TopLevelNode
            }
        }
        else
        {
            Process-VisioGuestRoles $GuestRoles
        }
    }

    Function Process-Nodes($AllNodes, $SelectedNodes)
    {
        ForEach($Item in $SelectedNodes)
        {
            if ($Item.Properties.ItemType -eq "Section")
            {
                 if($Item.Properties.Level -eq 1)
                 {
                    $InstallRole = "INSTALL"+$Item.Properties.Name
                    $Label = $Item.Properties.Label
                    Set-IniFile  -file $Script:GuestINI -category "Configuration" -key  "'//$InstallRole" -value "will be installed"
                    Set-INIFile -file $Script:GuestINI -category "Configuration" -key $InstallRole -value "YES"
                    Add-INIProperties $InstallRole
                    Write-LogEntry "`t`t`t`t`t`tRole=$Label"
                 }
                 else
                 {
                    Set-INIFile -file $Script:GuestINI -category "Configuration" -key "'//Option" -value $Item.Properties.Label
                    $InstallRole = "INSTALL"+$Item.Properties.Name
                    Set-IniFile  -file $Script:GuestINI -category "Configuration" -key  "'//$InstallRole" -value "will be configured"
                    Set-INIFile -file $Script:GuestINI -category "Configuration" -key $InstallRole -value "YES"
                    Add-INIProperties $InstallRole
                 }
                 $ChildItems = $AllNodes | ? { ($_.Properties.ParentId -eq $Item.Properties.Id) }
                 $ChildrenInGroup = $ChildItems | ? { ($_.Properties.InGroup -eq "") -or ($_.Properties.InGroup -eq $Item.Values.SelectedGroup) }
                 Process-Nodes $AllNodes $ChildrenInGroup
            }
            else
            {
                if ($Item.Values.Value -ne "")
                {
                    $key = $Item.Properties.Name
                    $value = $Item.Values.Value
                    Set-INIFile -file $Script:GuestINI -category "Configuration" -key $Item.Properties.Name -value $Item.Values.Value
                    Add-INIProperties $Item.Properties.Name
                    Write-LogEntry "`t`t`t`t`t`t$key=$Value"  -level "info"

                }
            }
        }
    }

    Function Add-INIProperties([string]$PropertyName)
    {
        if ($PropertyName.Length -gt 0)
        {
            if ($Script:GuestProperties -eq "*")
            {
                $Script:GuestProperties=$PropertyName
            }
            else
            {
                $Script:GuestProperties=$Script:GuestProperties+","+$PropertyName
            }
        }
    }

    Function Set-INIFileHeader
    {
        Write-Output "'//Ini file auto generate by MCS Client Hydration" | Out-File -FilePath $Script:GuestINI
        Set-INIFile -file $Script:GuestINI -category "Settings" -key "Priority" -value "Default, Configuration"
        Set-INIFile -file $Script:GuestINI -category "Default" -key "OSInstall" -value "Y"
        Set-INIFile -file $Script:GuestINI -category "Default" -key "SkipWizard" -value "YES"
        Set-INIFile -file $Script:GuestINI -category "Default" -key "DeploymentType" -value "CUSTOM"
        Set-INIFile -file $Script:GuestINI -category "Default" -key "TaskSequenceID" -value "HYDRATION"
        Set-INIFile -file $Script:GuestINI -category "Default" -key "DoNotCreateExtraPartition" -value "YES"
        Set-INIFile -file $Script:GuestINI -category "Default" -key "_SMSTSOrgName" -value "Hydration"


    }

    Function New-Guest($NewGuest )
    {

        $LABID=$Script:LabDefinition.myFields.HOSTENVIRONMENT.LABID
        $GuestName = $LABID+"-"+$Guest.GuestName
        # Skip the DC if -NoDomain is specified.
        If (($NoDomain -eq $True) -and ($Guest.GUESTROLE -eq "DC"))
        {
            # Skip the DC
            Write-LogEntry "Skipping $GuestName" -level "info"
        }
        else
        {
            # Does the guest exist
            # If it does not, provision the guest
            if (((get-vm * | where {$_.Name -eq ($LABID+"-"+$Guest.GuestName)}) -eq $Null))
            {
                $STARTMEM=[System.Int64]$Guest.HARDWARE.STARTMEM*1024*1024
                $MINMEM=[System.Int64]$Guest.HARDWARE.MINIMUMMEM*1024*1024
                $MAXMEM=[System.Int64]$Guest.HARDWARE.MAXMEM*1024*1024
                $CPUCount=[int]$Guest.HARDWARE.CPUCOUNT
                $MemPriority=[int]$Guest.HARDWARE.MemPriority
                $VHDSize=[System.Int64]$Guest.PRIMARYVHDSIZE*1024*1024*1024
                $colVMNetAdapters=@()
                $GuestRoleStorePath=$Guest.HARDWARE.GUESTROLESTOREPATH
                if ( [string]::IsNullOrEmpty($GuestRoleStorePath) )
                {
                    $GuestRoleStorePath = $Script:LabDefinition.myFields.HOSTENVIRONMENT.LABSTOREPATH
                }
                $PublicFQDN=$Script:LabDefinition.myFields.HostEnvironment.PublicFQDN

                $Generation = 1 
                if ( $Gen2 ) { $Generation = 2 }

                $detectInfoPath = Get-Content $Script:LabConfigFile | where { $_ -match "MY:" }
                if ($detectInfoPath.count -ge 1)
                {
                    Write-Host "Using an InfoPath Definition File"
                    $AdminPass=$Guest.HARDWARE.ADMINPASS
                    $AdminUserName="administrator"
                }
                else
                {
                    Write-Host "Using a Visio Definition File"
                    $AdminPass=$Guest.ADMINPASS
                    $AdminUserName=$Guest.ADMINUSERNAME
                }

                $GuestName=$Guest.GuestName

                if ( $Guest.ServerWIM -and $Guest.ServerParent ) {
                    write-verbose "Create a client vhdx file for use $($Guest.ServerParent)"

                    if ( -not (test-path ( join-path (split-path $Script:ServerOSVHD) $guest.ServerParent ) ) ) {
                        write-verbose "Create the CLient VHD(x)"

                        $HydrationLetter = $null
                        $HydrationDisk = $null

                        if ( Test-Path "$PSscriptRoot\ParentDisks\Install.wim" )
                        {
                            Write-LogEntry "`t`t`t`tUser placed the install.wim locally ready for use $($PSscriptRoot)\ParentDisks\Install.wim" -level "Info" 
                            $WIM2VHDArgs = @{
                                ImagePath = "$PSscriptRoot\ParentDisks\Install.wim"
                                VHDFile = ( join-path (split-path $Script:ServerOSVHD) $guest.ServerParent )
                                Index = 1  # Hard Coded for Enterprise Eval
                                SIzeBytes = 120GB
                                GPT = ($Gen2 -ne $null)
                            }

                        }
                        else
                        {

                            if ( $Guest.ServerWim.ToString().Contains( "$HydrationLetter" ) ) {

                                write-verbose "The install.wim file is within the HydrationParent.vhd file. Mount this VHD file..."

                                $HydrationDisk = Mount-vhd -ReadOnly -Path $PSscriptRoot\ParentDisks\HydrationParent.vhdx -Passthru
                                $HydrationDisk | Out-String | Write-Verbose
                                if ( -not $HydrationDisk ) { throw "Unable to Mount VHD File" }

                                $HydrationLetter = $HydrationDisk | get-disk | get-partition | get-volume | Select-object -first 1 -ExpandProperty DriveLetter
                                if ( -not ( test-path "$($HydrationLetter)`:\DS-Hydration" ) ) { throw "unable to mount HydrationParent.vhd" }

                            }

                            $WIM2VHDArgs = @{
                                ImagePath = invoke-expression ( """" + $Guest.ServerWIM + """" )
                                VHDFile = ( join-path (split-path $Script:ServerOSVHD) $guest.ServerParent )
                                Index = 1  # Hard Coded for Enterprise Eval
                                SIzeBytes = 120GB
                                GPT = ($Gen2 -ne $null)
                            }

                        }

                        ##############################

                        if ( Test-Path $WIM2VHDArgs.ImagePath )
                        {
                            & $PSScriptRoot\Convert-WIM2VHD.ps1 @WIm2VHDArgs

                        }

                        if ( $HydrationDisk ) {
                            dismount-vhd -Path $PSscriptRoot\ParentDisks\HydrationParent.vhdx 
                        }

                        if ( -not ( test-path $WIM2VHDArgs.VHDFile ) ) {
                            Write-LogEntry "`t`t`t`tProvisioning OS differencing vDisk not found $($WIM2VHDArgs.VHDFile)" -level "Warning" 
                            return                           
                        }

                    }
                }

                # Create Guest Lab Store
                Set-GuestLabStore $GuestRoleStorePath

                # Provision the disks and update the hydration INI file if we are processing a server
                if (($GUEST.GUESTTYPE) -in "SERVER","CLIENTQUICK")
                {
                    $VHDPath = $GuestRoleStorePath+"\"+$LABID+"-"+$Guest.GuestName+"\"+$LABID+"-"+$Guest.GuestName+"."+$DiskType
                    If (($CopyVHD -eq $False) -or ($CopyVHD -eq $NULL))
                    {
                        # Provision the ServerParent as a differencing disk for the server
                        Write-LogEntry "`t`t`t`tProvisioning OS differencing vDisk" -level "info"
                        try
                        {
                            if ( $Guest.ServerParent ) {
                                if ( test-path ( join-path (split-path $Script:ServerOSVHD) $guest.ServerParent ) )
                                {
                                    New-VHD -Path $VHdPath -ParentPath ( join-path (split-path $Script:ServerOSVHD) $guest.ServerParent ) -ErrorAction Stop| Out-Null
                                }
                                else {
                                    Write-LogEntry "`t`t`t`tProvisioning OS differencing not found $($guest.ServerParent) using default..." -level "info"
                                    New-VHD -Path $VHdPath -ParentPath ($Script:ServerOSVHD)  -ErrorAction Stop| Out-Null
                                }
                            }
                            else {
                                New-VHD -Path $VHdPath -ParentPath ($Script:ServerOSVHD)  -ErrorAction Stop| Out-Null
                            }
                        }
                        catch
                        {
                            Write-LogEntry "`t`t`t`t`tFailed to create the vDisk" -level "error"
                            Exit $ERRORFAIL
                        }
                    }
                    Else
                    {
                        # Provision the ServerParent disk for the server
                        Write-LogEntry "`t`t`t`tCopying OS vDisk" -level "info"
                        try
                        {
                            Copy-Item $Script:ServerOSVHD $VHDPath -Force  -ErrorAction Stop | Out-Null
                        }
                        catch
                        {
                            Write-LogEntry "`t`t`t`t`tFailed to copy the vDisk" -level "error"
                            Exit $ERRORFAIL
                        }

                    }

                    Write-LogEntry "`t`t`t`t`tMounting the vDisk" -level "info"
                    try
                    {
                        $DiskID = resolve-path $VHDPath | Select-Object -ExpandProperty path |
                            Mount-VHD -Passthru -ErrorAction Stop | Get-Disk
                        if ( $DiskID | Where-Object PartitionStyle -EQ "GPT" ) { $Generation = 2 } else { $Generation = 1 }

                    }
                    catch [Exception]
                    {
                        $ErrorMessage = $_.exception.message
                        Write-LogEntry $ErrorMessage
                    }

                    Write-LogEntry "`t`t`t`t`tFinished Mounting the vDisk" -level "info"

                }


                Write-LogEntry "`tProvisioning $LABID-$GuestName" -level "info"
                #Create VM with no network adapters
                $NewVMCommon = @{ }
                if ( $Version ) { 
                    Write-LogEntry -level "Info" -LogEntry "Version: $Version"
                    $NewVMCommon.Version = $Version 
                }
                If (($Guest.GUESTTYPE) -in "SERVER","CLIENTQUICK")
                {
                    try
                    {
                        Write-LogEntry "`t`tCreating Gen $Generation server guest with no VHD, and no switch connection    $Version" -level "info"
                        New-VM -Name ($LABID+"-"+$Guest.GuestName) -Path ($GuestRoleStorePath+"\"+$LABID+"-"+$Guest.GuestName) -NoVHD -Generation $Generation -ErrorAction Stop @NewVMCommon | Out-Null
                    }
                    catch
                    {
                        Write-LogEntry "`tError creating guest $LABID-$GuestName. `nExiting Script." -level "warning"
                        Exit $ERRORFAIL
                    }
                }
                else
                {
                    try
                    {
                        Write-LogEntry "`t`tCreating client guest with dynamic VHD, and no switch connection" -level "Info"
                        $DiskType = "VHDX"
                        New-VM -Name ($LABID+"-"+$Guest.GuestName) -Path ($GuestRoleStorePath+"\"+($LABID+"-"+$Guest.GuestName)) -NewVHDPath ($GuestRoleStorePath+"\"+($LABID+"-"+$Guest.GuestName)+"\"+($LABID+"-"+$Guest.GuestName)+"."+$DiskType) -NewVHDSizeBytes $VHDSize -Generation $Generation -ErrorAction Stop @NewVMCommon | Out-Null
                        get-vm -Name ($LABID+"-"+$Guest.GuestName) | Checkpoint-VM -SnapshotName "BASE"
                        Write-LogEntry "`t`t`tClient guests created with Generation 2 configuration at user's request. Ensure that a supported operating system is installed in the guest. Refer to http://technet.microsoft.com/en-us/library/dn282285.aspx for more information." -level "warning"

                    }
                    catch
                    {
                        Write-LogEntry "`tError creating client guest $LABID-$GuestName. Exiting Script." -level "error"
                        Exit $ERRORFAIL
                    }
                }

                try
                {
                    Write-LogEntry "`t`tRemoving default virtual network adapter"
                    Remove-VMNetworkAdapter -VMName ($LABID+"-"+$Guest.GuestName) -ErrorAction Stop | Out-Null
                }
                catch
                {
                    Write-LogEntry "`tError removing default network adapter on $LABID-$GuestName. `nExiting Script." -level "warning"
                    Exit $ERRORFAIL
                }
                $AdapterCount=0
                $NumAdapters=(($Guest.HARDWARE.NETWORKCARDS.NETWORKCARD).Count)
                Write-LogEntry "`t`t`t`tProcessing multi-nic guest" -level "info"
                foreach ($Adapter in $Guest.HARDWARE.NETWORKCARDS.NETWORKCARD)
                {
                    # Add network adapters to the host
                    if ( $Adapter.SWITCHNAME -eq "WWW" -and $InternetSwitchOveride ) { $SwitchName = $InternetSwitchOveride } else { $SwitchName = $LABID + "-" + $Adapter.SWITCHNAME }

                    Write-LogEntry "`t`t`t`t`tAdd vNIC to $LABID-$GuestName and connect to $Switchname" -level "warning"
                    try
                    {
                        if ($Generation -eq 2) { $isLegacyNIC = 0 } else { $isLegacyNIC = 1}
                        Add-VMNetworkAdapter -Name ($SwitchName + $AdapterCount) -VMName ($LABID+"-"+$Guest.GuestName) -IsLegacy $isLegacyNIC -SwitchName $SwitchName -ErrorAction Stop | Out-Null
                    }
                    catch
                    {
                        Write-LogEntry "`tError adding default network adapter on $LABID-$GuestName. `nExiting Script." -level "warning"
                        Exit $ERRORFAIL
                    }
                    Write-LogEntry "`t`t`t`t`t`tvNIC properties $($Adapter.NICIPADDRESS) -- $($Adapter.NICNETMASK) -- $($Adapter.NICGATEWAY) -- $($Adapter.NICDNSSERVER)"
                    Write-LogEntry "`t`t`t`t`t`tRetrieving MAC address for vNIC attached to $LABID-$GuestName"
                    $OSDAdapter="OSDAdapter$AdapterCount"
                    If (($Guest.HARDWARE.NETWORKCARDS.NETWORKCARD).Count -gt 1)
                    {
                        $OSDAdapterMACAddress= $OSDAdapter+"MACAddress="+(Get-MacAddress ($LABID+"-"+$Guest.GuestName) ($SwitchName+$AdapterCount))
                        $colVMNetAdapters = $colVMNetAdapters + $OSDAdapterMACAddress
                    }
                    $OSDAdapterIPAddress=$OSDAdapter+"IPAddressList="+($Adapter.NICIPADDRESS)
                    $colVMNetAdapters = $colVMNetAdapters + $OSDAdapterIPAddress
                    $OSDAdapterSubnetMask=$OSDAdapter+"SubnetMask="+($Adapter.NICNETMASK)
                    $colVMNetAdapters = $colVMNetAdapters + $OSDAdapterSubnetMask
                    $OSDAdapterGateway=$OSDAdapter+"Gateways="+($Adapter.NICGATEWAY)
                    $colVMNetAdapters = $colVMNetAdapters + $OSDAdapterGateway
                    $OSDAdapterDNS=$OSDAdapter+"DNSServerList="+($Adapter.NICDNSSERVER)
                    $colVMNetAdapters = $colVMNetAdapters + $OSDAdapterDNS
                    $AdapterCount++
                    Write-LogEntry "`t`t`t`t`t`tMAC address for vNIC attached to $LABID-$GuestName retrieved"
                }
                Write-LogEntry "`t`t`t`tNic processing complete" -level "info"


                # Provision the disks and update the hydration INI file if we are processing a server
                if (($GUEST.GUESTTYPE) -in "SERVER","CLIENTQUICK")
                {

                    Write-LogEntry "`t`t`t`t`tMounting the vDisk" -level "info"
                    try
                    {

                        $DriveLetter = $DiskID | Get-partition | 
                            Get-Volume | Where-Object FileSystem -EQ "NTFS" | 
                            Sort-Object -Property Size | 
                            Select-Object -ExpandProperty DriveLetter -Last 1
                        if ( -not $DriveLetter ) { write-error "Missing Drive letter for $VHdPath" -ErrorAction silentlycontinue ; exit }
                        Write-LogEntry "`t`t`t`t`t`tFound vDisk at $DriveLetter" -level "info"
                        if (!( test-path "$DriveLetter`:\Windows\Panther" ))
                        {
                            New-item -type directory "$DriveLetter`:\Windows\Panther" |out-null
                        }
                        Write-LogEntry "`t`t`t`t`t`tCreating unattend.xml file" -level "info"
                        $GuestName=$Guest.GuestName

@"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
<settings pass="windowsPE">
<component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
    <ImageInstall>
    <OSImage>
        <WillShowUI>OnError</WillShowUI>
        <InstallTo>
        <DiskID>0</DiskID>
        <PartitionID>1</PartitionID>
        </InstallTo>
        <InstallFrom>
        <Path>install.wim</Path>
        <MetaData>
            <Key>/IMAGE/INDEX</Key>
            <Value>1</Value>
        </MetaData>
        </InstallFrom>
    </OSImage>
    </ImageInstall>
    <Display>
        <ColorDepth>16</ColorDepth>
        <HorizontalResolution>1024</HorizontalResolution>
        <RefreshRate>60</RefreshRate>
        <VerticalResolution>768</VerticalResolution>
    </Display>
    <ComplianceCheck>
        <DisplayReport>OnError</DisplayReport>
    </ComplianceCheck>
    <UserData>
        <AcceptEula>true</AcceptEula>
    </UserData>
</component>
<component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <SetupUILanguage>
    <UILanguage>en-US</UILanguage>
    </SetupUILanguage>
    <InputLocale>0409:00000409</InputLocale>
    <SystemLocale>en-US</SystemLocale>
    <UILanguage>en-US</UILanguage>
    <UserLocale>en-US</UserLocale>
</component>
</settings>
<settings pass="generalize">
<component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <DoNotCleanTaskBar>true</DoNotCleanTaskBar>
</component>
</settings>
<settings pass="specialize">
<component name="Microsoft-Windows-UnattendedJoin" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
        <Identification>
            <JoinWorkgroup>Workgroup</JoinWorkgroup>
        </Identification>
</component>
<component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
    <ComputerName>$GuestName</ComputerName>
    $( if ($ProductKey ) { "<ProductKey>$ProductKey</ProductKey>" } )
    <RegisteredOrganization>Microsoft</RegisteredOrganization>
    <RegisteredOwner>Datacenter Services</RegisteredOwner>
    <DoNotCleanTaskBar>true</DoNotCleanTaskBar>
    <TimeZone>Pacific Standard Time</TimeZone>
</component>
<component name="Microsoft-Windows-IE-InternetExplorer" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <Home_Page>about:blank</Home_Page>
</component>
        <component name="Microsoft-Windows-IE-ESC" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <IEHardenAdmin>false</IEHardenAdmin>
            <IEHardenUser>false</IEHardenUser>
        </component>
<component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <RunSynchronous>
    <RunSynchronousCommand wcm:action="add">
        <Description>EnableAdmin</Description>
        <Order>1</Order>
        <Path>cmd /c net user Administrator /active:yes</Path>
    </RunSynchronousCommand>
    <RunSynchronousCommand wcm:action="add">
        <Description>UnfilterAdministratorToken</Description>
        <Order>2</Order>
        <Path>cmd /c reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v FilterAdministratorToken /t REG_DWORD /d 0 /f</Path>
    </RunSynchronousCommand>
    <RunSynchronousCommand wcm:action="add">
        <Description>disable user account page</Description>
        <Order>3</Order>
        <Path>reg add HKLM\Software\Microsoft\Windows\CurrentVersion\Setup\OOBE /v UnattendCreatedUser /t REG_DWORD /d 1 /f</Path>
    </RunSynchronousCommand>
    <RunSynchronousCommand wcm:action="add">
        <Description>Change Automatic Update</Description>
        <Order>4</Order>
        <Path>reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU /v AUOptions /t REG_DWORD /d $AUOptions /f</Path>
    </RunSynchronousCommand>
    </RunSynchronous>
</component>
<component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <InputLocale>0409:00000409</InputLocale>
    <SystemLocale>en-US</SystemLocale>
    <UILanguage>en-US</UILanguage>
    <UserLocale>en-US</UserLocale>
</component>
<component name="Microsoft-Windows-TapiSetup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <TapiConfigured>0</TapiConfigured>
    <TapiUnattendLocation>
    <AreaCode>""</AreaCode>
    <CountryOrRegion>1</CountryOrRegion>
    <LongDistanceAccess>9</LongDistanceAccess>
    <OutsideAccess>9</OutsideAccess>
    <PulseOrToneDialing>1</PulseOrToneDialing>
    <DisableCallWaiting>""</DisableCallWaiting>
    <InternationalCarrierCode>""</InternationalCarrierCode>
    <LongDistanceCarrierCode>""</LongDistanceCarrierCode>
    <Name>Default</Name>
    </TapiUnattendLocation>
</component>
<component name="Microsoft-Windows-SystemRestore-Main" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <DisableSR>1</DisableSR>
</component>

</settings>
<settings pass="oobeSystem">
<component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
    <UserAccounts>
    <AdministratorPassword>
        <Value>$AdminPass</Value>
        <PlainText>true</PlainText>
    </AdministratorPassword>
    </UserAccounts>
    <AutoLogon>
    <Enabled>true</Enabled>
    <Username>Administrator</Username>
    <Domain>.</Domain>
    <Password>
        <Value>$AdminPass</Value>
        <PlainText>true</PlainText>
    </Password>
    <LogonCount>999</LogonCount>
    </AutoLogon>
    <Display>
    <ColorDepth>32</ColorDepth>
    <HorizontalResolution>1024</HorizontalResolution>
    <RefreshRate>60</RefreshRate>
    <VerticalResolution>768</VerticalResolution>
    </Display>
        <FirstLogonCommands>
            <SynchronousCommand wcm:action="add">
                <CommandLine>cmd.exe /c c:\Windows\temp\bootstraphydration.bat</CommandLine>
                <Description>Start Hydration</Description>
                <Order>1</Order>
            </SynchronousCommand>
        </FirstLogonCommands>
    <OOBE>
    <HideEULAPage>true</HideEULAPage>
    <NetworkLocation>Work</NetworkLocation>
    <ProtectYourPC>1</ProtectYourPC>
    <HideLocalAccountScreen>true</HideLocalAccountScreen>
    <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
    <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
    </OOBE>
    <RegisteredOrganization>X</RegisteredOrganization>
    <RegisteredOwner>Windows User</RegisteredOwner>
    <TimeZone>Pacific Standard Time</TimeZone>
</component>
<component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <InputLocale>0409:00000409</InputLocale>
    <SystemLocale>en-US</SystemLocale>
    <UILanguage>en-US</UILanguage>
    <UserLocale>en-US</UserLocale>
</component>
</settings>
<settings pass="offlineServicing">
<component name="Microsoft-Windows-PnpCustomizationsNonWinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <DriverPaths>
    <PathAndCredentials wcm:keyValue="1" wcm:action="add">
        <Path>\Drivers</Path>
    </PathAndCredentials>
    </DriverPaths>
</component>
</settings>
</unattend>

"@ | Out-File $DriveLetter":\Windows\Panther\unattend.xml" -Append -Encoding ASCII


                        Write-LogEntry "`t`t`t`t`t`tCreated unattend.xml in \Windows\Panther" -info "info"


@"
diskpart /s C:\Windows\temp\HydrationDiskOnline.txt
timeout /t 3
move /y c:\hydration.ini d:\DS-hydration\control\customsettings.ini
cscript d:\DS-hydration\scripts\litetouch.wsf
"@ | Out-File $DriveLetter":\Windows\temp\BootStrapHydration.bat" -Append -Encoding ASCII
                     Write-LogEntry "`t`t`t`t`t`tCreated BootStrapHydration.bat in \Windows\temp" -info "info"

@"
Select Disk 1
Attributes Disk Clear Readonly
Online Disk
Select Partition 1
Assign Lettter=D
"@ | Out-File $DriveLetter":\Windows\temp\HydrationDiskOnline.txt" -Append -Encoding ASCII
                     Write-LogEntry "`t`t`t`t`t`tCreated HydrationDiskOnline.txt in \Windows\temp" -info "info"


                    }
                    catch [Exception]
                    {
                        $ErrorMessage = $_.exception.message
                        Write-LogEntry $ErrorMessage
                    }

                    # Update the hydration INI file
                    Write-LogEntry "`t`t`t`t`t`tUpdating hydration ini file configuration"
                    $Script:GuestINI=$DriveLetter+":\hydration.ini"
                    [string]$Script:GuestProperties="*"
                    Set-INIFileHeader

                    foreach ($Item in $colVMNetAdapters)
                    {
                        $arrTempString=$Item.Split("=")
                        $Key=$arrTempString[0]
                        if ($arrTempString.Count -gt 1)
                        {
                            $Value=$arrTempString[1]
                        }
                        else
                        {
                            $Value=""
                        }
                        Write-LogEntry "`t`t`t`t`t`t$Key=$Value"
                        Set-INIFile $DriveLetter":\hydration.ini" "CONFIGURATION" $Key $Value
                        # Get the current properties field and add the key to properties
                        $iniContent = Get-IniContent $DriveLetter":\hydration.ini"
                        $iniProperties = $iniContent["Settings"]["Properties"]
                        $Script:GuestProperties = $Script:GuestProperties+",$Key"
                    }

                    Process-GuestRoles $Guest.GuestRoles

                    # Add Public FQDN
                    if ($isLabKit -eq 'True')
                    {
                        $Script:GuestProperties=$Script:GuestProperties+",isLabKit"
                        Set-INIFile -file $Script:GuestINI -category "Default" -key "isLabKit" -value $isLabKit
                    }

                    # Add 
                    if ($PublicFQDN -ne $Null)
                    {
                        $Script:GuestProperties=$Script:GuestProperties+",PublicFQDN"
                        Set-INIFile -file $Script:GuestINI -category "Default" -key "PublicFQDN" -value $PublicFQDN
                    }

                    # Flush all properties to file
                    $Script:GuestProperties=$Script:GuestProperties+",Server_AdminAccount,Server_AdminPassword"
                    Set-INIFile -file $Script:GuestINI -category "Settings" -key "Properties" -value $Script:GuestProperties

                    # Add local administrator password to Inifile
                    Set-INIFile -file $Script:GuestINI -category "Default" -key "Server_AdminAccount" -value $AdminUserName
                    Set-INIFile -file $Script:GuestINI -category "Default" -key "Server_AdminPassword" -value $AdminPass



                    # Tidy up the file for documentation
                    Set-INIFile -file $Script:GuestINI -category "Default" -key "'//End Section" -value "*"
                    Set-INIFile -file $Script:GuestINI -category "Settings" -key "'//End Section" -value "*"
                    Set-INIFile -file $Script:GuestINI -category "Configuration" -key "'//End Section" -value "*"
                    Set-Content $Script:GuestINI -Encoding ASCII -Value (Get-Content $Script:GuestINI)


                    Write-LogEntry "`t`t`t`t`tHydration configuration updated"
                    Write-LogEntry "`t`t`t`t`tDismounting the vDisk"
                    try
                    {
                        Dismount-VHD -Path (($GuestRoleStorePath+"\"+$LABID+"-"+$Guest.GuestName)+"\"+$LABID+"-"+$Guest.GuestName+"."+$DiskType) -ErrorAction Stop
                        Add-VMHardDiskDrive -VMName ($LABID+"-"+$Guest.GuestName) -Path (($GuestRoleStorePath+"\"+$LABID+"-"+$Guest.GuestName)+"\"+$LABID+"-"+$Guest.GuestName+"."+$DiskType)  -ErrorAction Stop | Out-Null
                    }
                    catch
                    {
                        #TODO: Catch and log
                    }

                    Write-LogEntry "`t`t`t`tOS differencing vDisk provisioned" -level "info"
                    Write-LogEntry "`t`t`t`tProvisioning hydration differencing vDisk" -level "info"
                    try
                    {
                        $NewHydrationVHD = $HydrationVHD
                        if ($HydrationVHD -like "*.VHD" -and $Generation -eq 2)
                        {
                            $NewHydrationVHD = $HydrationVHD + "x"
                            Write-LogEntry "`t`t`t`t`tTest for $NewHydrationVHD" -level "info"
                            if ( -not ( Test-Path $NewHydrationVHD ))
                            {
                                Write-LogEntry "`t`t`t`t`tConvert $HydrationVHD to VHDx" -level "info"
                                Convert-VHD -Path $HydrationVHD -DestinationPath $NewHydrationVHD
                                Write-LogEntry "`t`t`t`t`tFinished Converting $HydrationVHD to VHD" -level "info"
                            }
                        }

                        if ($NewHydrationVHD -like "*.VHDX")
                        {
                            New-VHD -Path (($GuestRoleStorePath+"\"+$LABID+"-"+$Guest.GuestName+"\"+$LABID+"-"+$Guest.GuestName)+"-HydrationDiff.VHDX") -ParentPath $NewHydrationVHD -ErrorAction Stop | Out-Null
                            Add-VMHardDiskDrive -VMName ($LABID+"-"+$Guest.GuestName) -Path (($GuestRoleStorePath+"\"+$LABID+"-"+$Guest.GuestName+"\"+$LABID+"-"+$Guest.GuestName)+"-HydrationDiff.VHDX") -ErrorAction Stop  | Out-Null
                        }
                        else
                        {
                            New-VHD -Path (($GuestRoleStorePath+"\"+$LABID+"-"+$Guest.GuestName+"\"+$LABID+"-"+$Guest.GuestName)+"-HydrationDiff.VHD") -ParentPath $NewHydrationVHD -ErrorAction Stop | Out-Null
                            Add-VMHardDiskDrive -VMName ($LABID+"-"+$Guest.GuestName) -Path (($GuestRoleStorePath+"\"+$LABID+"-"+$Guest.GuestName+"\"+$LABID+"-"+$Guest.GuestName)+"-HydrationDiff.VHD") -ErrorAction Stop  | Out-Null
                        }

                        Write-LogEntry "`t`t`t`tHydration differencing vDisk provisioned" -level "info"
                    }
                    catch
                    {
                        Write-LogEntry "`t`t`t`tFailed to create HydrationParent Differencing disk." -level "error"
                        Exit $ERRORFAIL
                    }

                }
                #Else does not exist. Client guest already provisioned with a disk


                $colVMNetAdapters.Clear()
                # Configure other guest virtual hardware parameters
                try
                {
                    Write-LogEntry "`t`t`t`tConfiguring dynamic memory" -level "info"
                    if ( -not ( $MemPriority -gt 50 -and $MemPriority -lt 100 ) ) {  $MemPriority = 50 }
                    Set-VMMemory -vmname ($LABID+"-"+$Guest.GuestName) -DynamicMemoryEnabled 1 -MinimumBytes $MINMEM -MaximumBytes $MAXMEM -StartupBytes $STARTMEM -ErrorAction Stop -Priority $MemPriority | Out-Null
                    Write-LogEntry "`t`t`t`tConfiguring vCPU count" -level "info"
                    Set-VMProcessor -VMName ($LABID+"-"+$Guest.GuestName) -Count $CPUCount -ErrorAction Stop | Out-Null
                    Write-LogEntry "`t`t`t`tConfiguring guest notes" -level "info"
                    Set-VM -Name ($LABID+"-"+$Guest.GuestName) -Notes $Script:Comment
                }
                catch
                {
                    #TODO: Catch and log
                }
                #If server, configure Generation 2 Firmware to boot to disk instead of network

                if (($Generation -eq 2) -and ($Guest.GUESTTYPE -in "SERVER","CLIENTQUICK"))
                {
                    Write-LogEntry "`t`t`t`tConfiguring Gen2 Firmware boot device for $($LABID)-$($Guest.GuestName)" -level "info"
                    $G2VM = Get-VM -Name ($LABID+"-"+$Guest.GuestName)
                    $G2VMHDD = $G2VM.HardDrives | Where-Object {$_.ControllerLocation -eq 0}
                    Set-VMFirmware -VM $G2VM -FirstBootDevice $G2VMHDD 
                }

                # Start the servers system is requested
                If ($StartLab -eq $True)
                {
                    Try
                    {
                        Write-LogEntry "`t`t`t`tUser has requested guests to be autostarted. Only guest server systems will be started" -level "info"
                        if ($Guest.GUESTTYPE -in "SERVER","CLIENTQUICK")
                        {
                            Start-VM ($LABID+"-"+$Guest.GuestName) -ErrorAction Stop
                            Write-LogEntry "`tStarted $LABID-$GuestName" -level "info"
                        }
                    }
                    catch
                    {
                        Write-LogEntry "`tError starting $LABID-$GuestName. `nExiting Script." -level "warning"
                        Exit $ERRORFAIL
                    }
                }
                Write-LogEntry "`tCompleted processing for $LABID-$GuestName" -level "Info"
                Write-LogEntry "==========================================================================================="
            }
            else
            {
                # Guest exists, skip it
                Write-LogEntry "`t$GuestName exists. Skipping" -level "info"
            }
        }
    }

    # Provision and configure the virtual machines
    Function NewGuests
    {

        if ($GuestName)
        {
            Write-LogEntry "Provisioning listed guest systems "
            foreach($ReprovGuest in $GuestName)
            {
                foreach ($Guest in $Script:LabDefinition.myFields.LABGUESTS.LABGUEST)
                {
                    if (($LABID+"-"+ $Guest.GuestName) -eq $ReprovGuest)
                    {
                        Write-LogEntry "`tUser requested guest $($Guest.GuestName)"
                        New-Guest $Guest $False
                    }
                }
            }
        }
        Else
        {
            # Process all guests in the lab manifest
            Write-LogEntry "Provisioning all guests in lab manifests."
            foreach ($Guest in $Script:LabDefinition.myFields.LABGUESTS.LABGUEST)
            {
                Write-LogEntry "`tOS Version is: $Script:OSVersion."
                Write-LogEntry "`tProvisioning standard guests."
                New-Guest $Guest $False
            }
        }

        Write-LogEntry "Guest provisioning complete."
    }

    # Function to start a guest and retrieve the MAC address after dynamic assignment
    Function Get-MacAddress([string]$GuestName,[string]$AdapterName)
    {
        Write-LogEntry "`t`t`t`t`t`t`tStarting $($GuestName) to allow dynamic MAC assignment from Hyper-V"
        try
        {
            Start-VM -Name $GuestName
        }
        catch
        {
            #TODO: Catch and log
        }
        Write-LogEntry "`t`t`t`t`t`t`tWaiting for 2 seconds"
        Start-Sleep -Seconds 2
        Write-LogEntry "`t`t`t`t`t`t`tTurning off $GuestName"
        try
        {
            Stop-VM -Name $GuestName -Force -TurnOff
        }
        catch
        {
            #TODO: Catch and log
        }
        try
        {
            return (Format-MACAddress (Get-VMNetworkAdapter -VMName $GuestName -Name $AdapterName -ErrorAction Stop).MACADDRESS)
        }
        catch
        {
            #TODO: Catch and log
        }
    }

    # Function to provide a well-formatted MAC Address
    Function Format-MACAddress ([string]$MACAddress)
    {
        $Tmp = ""

        for($i=1;$i -le 12; $i++)
        {
            $Remainder=$null
            $Quotient=[system.math]::DivRem($i,2,[ref]$Remainder)
            if($Remainder -eq 0)
            {
                $Tmp+=$MACADDRESS.SubString(($i-2),2)+"-"
            }
        }
        $Tmp=$Tmp.SubString(0,($Tmp.Length-1))
        return $Tmp
    }

    ## Invoke a Win32 P/Invoke call.
    function Invoke-WindowsApi([string] $dllName, [Type] $returnType, [string] $methodName, [Type[]] $parameterTypes, [Object[]] $parameters)
    {
       $domain = [AppDomain]::CurrentDomain
       $name = New-Object Reflection.AssemblyName 'PInvokeAssembly'
       $assembly = $domain.DefineDynamicAssembly($name, 'Run')
       $module = $assembly.DefineDynamicModule('PInvokeModule')
       $type = $module.DefineType('PInvokeType', "Public,BeforeFieldInit")
       ## Go through all of the parameters passed to us.  As we do this,
       ## we clone the user's inputs into another array that we will use for
       ## the P/Invoke call.
       $inputParameters = @()
       $refParameters = @()
       for($counter = 1; $counter -le $parameterTypes.Length; $counter++)
       {
          ## If an item is a PSReference, then the user
          ## wants an [out] parameter.
          if($parameterTypes[$counter - 1] -eq [Ref])
          {
             ## Remember which parameters are used for [Out] parameters
             $refParameters += $counter
             ## On the cloned array, we replace the PSReference type with the
             ## .Net reference type that represents the value of the PSReference,
             ## and the value with the value held by the PSReference.
             $parameterTypes[$counter - 1] =
                $parameters[$counter - 1].Value.GetType().MakeByRefType()
             $inputParameters += $parameters[$counter - 1].Value
          }
          else
          {
             ## Otherwise, just add their actual parameter to the
             ## input array.
             $inputParameters += $parameters[$counter - 1]
          }
       }
       ## Define the actual P/Invoke method, adding the [Out]
       ## attribute for any parameters that were originally [Ref]
       ## parameters.
       $method = $type.DefineMethod($methodName, 'Public,HideBySig,Static,PinvokeImpl',
          $returnType, $parameterTypes)
       foreach($refParameter in $refParameters)
       {
          $method.DefineParameter($refParameter, "Out", $null)
       }
       ## Apply the P/Invoke constructor
       $ctor = [Runtime.InteropServices.DllImportAttribute].GetConstructor([string])
       $attr = New-Object Reflection.Emit.CustomAttributeBuilder $ctor, $dllName
       $method.SetCustomAttribute($attr)

       ## Create the temporary type, and invoke the method.
       $realType = $type.CreateType()
       $realType.InvokeMember($methodName, 'Public,Static,InvokeMethod', $null, $null,
          $inputParameters)

       ## Finally, go through all of the reference parameters, and update the
       ## values of the PSReference objects that the user passed in.
       foreach($refParameter in $refParameters)
       {
          $parameters[$refParameter - 1].Value = $inputParameters[$refParameter - 1]
       }
    }

    # Function to update INI files
    Function Set-INIFile ($file,$category, $key, $value )
    {
        ## Prepare the parameter types and parameter values for the Invoke-WindowsApi script
        $parameterTypes = [string], [string], [string], [string]
        $parameters = [string] $category, [string] $key, [string] $value, [string] $file

        ## Invoke the API
        [void] (Invoke-WindowsApi "kernel32.dll" ([UInt32]) "WritePrivateProfileString" $parameterTypes $parameters)
    }

    function Get-IniContent ($filePath)
    {
        $ini = @{}
        switch -regex -file $FilePath
        {
            "^\[(.+)\]" # Section
            {
                $section = $matches[1]
                $ini[$section] = @{}
                $CommentCount = 0
            }
            "^(;.*)$" # Comment
            {
                $value = $matches[1]
                $CommentCount = $CommentCount + 1
                $name = "Comment" + $CommentCount
                $ini[$section][$name] = $value
            }
            "(.+?)\s*=(.*)" # Key
            {
                $name,$value = $matches[1..2]
                $ini[$section][$name] = $value
            }
        }
        return $ini
    }

    function Out-IniFile($InputObject, $FilePath)
    {
        $outFile = New-Item -ItemType file -Path $Filepath
        foreach ($i in $InputObject.keys)
        {
            if (!($($InputObject[$i].GetType().Name) -eq "Hashtable"))
            {
                #No Sections
                Add-Content -Path $outFile -Value "$i=$($InputObject[$i])"
            } else {
                #Sections
                Add-Content -Path $outFile -Value "[$i]"
                Foreach ($j in ($InputObject[$i].keys | Sort-Object))
                {
                    if ($j -match "^Comment[\d]+") {
                        Add-Content -Path $outFile -Value "$($InputObject[$i][$j])"
                    } else {
                        Add-Content -Path $outFile -Value "$j=$($InputObject[$i][$j])"
                    }

                }
                Add-Content -Path $outFile -Value ""
            }
        }
    }

    #   Update variables
    Function Update-Variables
    {
        If (Test-Path (Join-Path -Path $ScriptPath -ChildPath "ParentDisks\HydrationParent.vhdx"))
        {
            $Script:HydrationVHD=$ScriptPath+"\ParentDisks\HydrationParent.vhdx"
        }
        Else
        {
            $Script:HydrationVHD=$ScriptPath+"\ParentDisks\HydrationParent.vhd"
        }

        # Determine if we are using a VHD or VHDX Server Parent.
        $TestFile = $ScriptPath+"\ParentDisks\ServerParent.vhdx"
        if ((Test-Path $TestFile) -eq $True)
        {
            $Script:ServerOSVHD=$ScriptPath+"\ParentDisks\ServerParent.vhdx"
            $Script:DiskType = "VHDX"
            Write-LogEntry "`tUsing VHDX ServerParent file." -level "info"
        }
        Else
        {
           $Script:ServerOSVHD=$ScriptPath+"\ParentDisks\ServerParent.vhd"
           $Script:DiskType = "VHD"
           Write-LogEntry "`tUsing VHD ServerParent file." -level "info"
        }

        $Script:UnattendXML=$ScriptPath+"\RoleConfigFiles\unattend.xml"
        $Script:Bootstrap=$ScriptPath+"\RoleConfigFiles\bootstrapHydration.bat"
    }

    # Get all the INI files in the RoleConfiguration folder
    Function Get-INIFiles
    {
        $Files = $Null
        $Files = Get-ChildItem $Script:ScriptPath"\RoleConfigFiles\*.*" -Include *.ini
        Return $Files
    }

    # Remove the Hydration disk
    Function CleanLab
    {
        $GuestName = $Null
        $GuestRoleStorePath = $Null
        Write-LogEntry "Preparing to clean guest systems for <insert lab id>"
        Write-LogEntry "Shutting down all guest systems in manifest"

        foreach ($Guest in $Script:LabDefinition.myFields.LABGUESTS.LABGUEST)
        {
            if ($Guest.GUESTTYPE -in "SERVER","CLIENTQUICK")
            {
                $GuestName = $Script:LabDefinition.myFields.HOSTENVIRONMENT.LABID+"-"+$Guest.GuestName
                $GuestRoleStorePath=$Guest.HARDWARE.GUESTROLESTOREPATH
                if ( [string]::IsNullOrEmpty($GuestRoleStorePath) )
                {
                    $GuestRoleStorePath = $Script:LabDefinition.myFields.HOSTENVIRONMENT.LABSTOREPATH
                }

                Try
                {
                    # Initiate shutdown here
                    if ((get-vm -Name $GuestName).State -eq "Running")
                    {
                        Write-LogEntry "`tInitiating shutdown on $Guestname"
                        Stop-VM -Name $GuestName -Force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
                        Write-LogEntry "`t`tWaiting 5 seconds for guest to shutdown" -level "warning"
                        Start-Sleep -Seconds 10
                        Write-LogEntry "`t`t$GuestName did not respond to shutdown. Turning $GuestName off" -level "warning"
                        Stop-VM -Name $GuestName -TurnOff -Force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
                    }
                    else
                    {
                        Write-LogEntry "`t`t$GuestName already off."
                    }
                }
                catch
                {
                    #Stop-VM -Name $GuestName -TurnOff -Force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
                    Write-LogEntry "`tFailed to shutdown $GuestName" -level "error"
                    Exit $ERRORFAIL
                }
                Write-LogEntry "`t`tRemoving hydration disk on $GuestName"
                try
                {
                    Get-VMHardDIskDrive -VMName $GuestName | Where-object Path -match 'HydrationDiff' | Remove-VMHardDiskDrive
                    get-vm -Name $GuestName | Checkpoint-VM -SnapshotName "BASE"
                }
                catch
                {
                    Write-LogEntry "`tFailed to unconfigure hydration disk on $GuestName" -level "error"
                }
                Write-LogEntry "`tCleaning complete" -level "info"
                #Delete the guest VHD
                try
                {
                    Remove-Item  -Path (($GuestRoleStorePath+"\"+$GuestName+"\"+$GuestName)+"-HydrationDiff"+"."+$DiskType) -Force -ErrorAction SilentlyContinue
                }
                catch
                {
                    Write-LogEntry "`tFailed to remove guest disk from filesystem" -level "error"
                }
            }
        }

        #Remove parent disk
        try
        {
            Remove-Item  -Path "$ScriptPath\ParentDisks\HydrationParent.vhdx","$ScriptPath\ParentDisks\HydrationParent.vhd" -Force -ErrorAction SilentlyContinue
        }
        catch
        {
            Write-LogEntry "`tFailed to remove parent VHD from filesystem" -level "error"
        }
    }

    #Function to delete a guest
    Function PurgeGuest ([string]$GuestName,[string]$GuestPath)
    {
        if (((get-vm).Name -contains $GuestName) -eq $True)
        {
            if ((Get-VM -Name $GuestName).State -ne "Off")
            {
                Stop-VM -Name $GuestName -TurnOff -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                Write-LogEntry "`t`t`tTurning off guest: $GuestName" -level "info"
            }

            Write-LogEntry "`t`t`tRemoving guest serverparent disk: $GuestName" -level "info"
            Remove-VMHardDiskDrive -VMName $GuestName -ControllerType IDE -ControllerNumber 0 -ControllerLocation 1 -ErrorAction SilentlyContinue

            Write-LogEntry "`t`t`tRemoving guest hydrationparent disk: $GuestName" -level "info"
            Remove-VMHardDiskDrive -VMName $GuestName -ControllerType IDE -ControllerNumber 0 -ControllerLocation 0 -ErrorAction SilentlyContinue

            Write-LogEntry "`t`t`tRemoving guest VM: $GuestName" -level "info"
            Remove-VM -Name $GuestName -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        }
        if (test-path $GuestPath)
        {
            Write-LogEntry "`t`t`tDeleting guest folder: $GuestPath" -level "info"
            Remove-Item -Path $GuestPath -Recurse -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue  -Confirm:$false
        }

        Write-LogEntry "`t`t`tRemoved guest: $GuestName" -level "info"

   }

    #Function to delete a switch
    Function PurgeSwitch ([string]$SwitchName)
    {
        try
        {
            Remove-VMSwitch -Name $SwitchName -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        }
        catch
        {
            #TODO:
        }
    }

    #Delete an entire lab configuration
    Function PurgeLab
    {
        # Remove all the guests
        foreach ($Guest in $Script:LabDefinition.myFields.LABGUESTS.LABGUEST)
        {
            $GuestName = $Script:LabDefinition.myFields.HOSTENVIRONMENT.LABID+"-"+$Guest.GuestName
            $GuestRoleStorePath=$Guest.HARDWARE.GUESTROLESTOREPATH
            if ( [string]::IsNullOrEmpty($GuestRoleStorePath) )
            {
                $GuestRoleStorePath = $Script:LabDefinition.myFields.HOSTENVIRONMENT.LABSTOREPATH
            }

            PurgeGuest -GuestName $GuestName -GuestPath $GuestRoleStorePath
        }

        #Remove Lab Store
        try
        {
            Remove-Item -Path $LabStorePath -Recurse -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue  -Confirm:$false
        }
        catch
        {
            #TODO:
        }
        #Remove all the switches
        foreach ($Switch in $LabDefinition.myFields.HOSTENVIRONMENT.VirtualSwitches.VIRTUALSWITCH)
        {
            $SwitchName = $LabID+"-"+$Switch.SWITCHNAME
            PurgeSwitch -SwitchName $SwitchName
        }
    }

#endregion

#region AzureRM Support

Function Initialize-HydrationAzureRMSystem {
    [cmdletbinding()]
    param( $HostEnvironment, [switch] $Force ) 


    foreach ( $Module in "AzureRM" ) {
        if ( -not ( get-installedmodule azurerm -ErrorAction SilentlyContinue -MinimumVersion 5.7.0 ) ) {
            Write-LogEntry "`r`n`r`n  $Module Module not found download now!  (please wait)" -level "info"
            Install-Module $Module -force -AllowClobber -verbose:$False
        }
        Import-Module $Module -force -Verbose:$False
    }

    if ( -not ( get-azurermlocation -ea SilentlyContinue ) ) {
        Write-LogEntry "`r`n`r`n Login to Azure"
        Connect-AzureRmAccount # | out-string | Write-verbose

        if ( -not ( get-azurermlocation -ea SilentlyContinue ) ) {
            throw "Unable to Login to Azure"
        }

        Write-LogEntry "`r`n`r`n Name $((get-azurermcontext).Name)  Subscription: $((Get-AzureRmContext).Subscription.Name)"

        # TBD - XXX - Select *which* subscription to use (if more than one)

    }

    # Verify Location
    $_Location = $HostEnvironment.AzureLocation
    if ( -not $_Location ) { Write-LogEntry "Missing Location from HostEnvironment XML" }
    if ( -not ( get-azurermlocation | Where-object DisplayName -eq $_Location ) ) {
        Write-LogEntry "Invalid Location $_Location, please ensure that the location is correct (see get-azurermlocation). Exiting Script." -level "error"
        Exit $ERRORFAIL
    }

    # Verify Resource Group
    $_ResourceGroup = $HostEnvironment.ResourceGroup
    if ( -not $_ResourceGroup ) { Write-LogEntry "Missing ResourceGroup from HostEnvironment XML" }

    if ( get-azurermresourcegroup -Name $_ResourceGroup -ErrorAction SilentlyContinue  ) {
        Write-LogEntry "Resoure Group $_ResourceGroup present, please ensure that this resource group is not already in use." -level "error"
        if ( -not $force ) { Exit $ERRORFAIL }
    }
    else {
        Write-LogEntry "Create Resource Group $_ResourceGroup   $_Location"
        New-AzureRmResourceGroup -Name $_ResourceGroup -Location $_Location # | out-string | Write-verbose
    }

}

function Get-MyStorageAccountName {
    [cmdletbinding()]
    param(
        $HostEnvironment,
        $PostFix = ''
        )

    if ( -not $script:MyStorageAccountName ) {
        $script:MyStorageAccountName = $HostEnvironment.StorageAccountName.ToLower() + [datetime]::now.tostring('yyMMddhhmm') + $PostFix
    }
    $script:MyStorageAccountName | Write-Output
}

function Initialize-StorageSystem {
    [cmdletbinding()]
    param(
        $HostEnvironment
        )

    $ResGrpLoc = @{ ResourceGroup = $HostEnvironment.ResourceGroup ; Location = $HostEnvironment.AzureLocation }

    $_StorageAccount = Get-AzureRmStorageAccount -name (Get-MyStorageAccountName $HostEnvironment) -ResourceGroupName $ResGrpLoc.ResourceGroup -EA SilentlyContinue
    if ( -not ( $_StorageAccount ) ) {
        Write-LogEntry "Create StorageAccount: $(Get-MyStorageAccountName $HostEnvironment) of type $($HostEnvironment.StorageAccountSKU)"
        $_StorageAccount = New-AzureRmStorageAccount @ResGrpLoc -Name (Get-MyStorageAccountName $HostEnvironment) -SkuName $HostEnvironment.StorageAccountSKU 
    }

    $_StorageAccount | Write-Output

}

Function Initialize-NetworkingSystem {
    [cmdletbinding()]
    param(
        $HostEnvironment
        )

    $ResGrpLoc = @{ ResourceGroup = $HostEnvironment.ResourceGroup ; Location = $HostEnvironment.AzureLocation }

    $SubNets = @()
    foreach ($Network in $HostEnvironment.VirtualSwitches.VirtualSwitch) {
        write-Logentry "Create Virtual Network SubNet $($Network.SwitchName)"
        $SubNets += New-AzureRmVirtualNetworkSubnetConfig -Name $Network.SwitchName -AddressPrefix $Network.AzureIPAddress
    }

    $VirtualNetworkArgs = @{
        Name          = $HostEnvironment.VirtualNetworkName
        AddressPrefix = $HostEnvironment.VirtualNetworkAddress
    }

     write-Logentry "Create Virtual Network"
    $Vnet = New-AzureRmVirtualNetwork @VirtualNetworkArgs @ResGrpLoc -Subnet $SubNets

    ##########################

    foreach ($Network in $HostEnvironment.VirtualSwitches.VirtualSwitch) {

        write-Logentry "Configure Virtual Network SubNet $($Network.SwitchName)"
        
        $SubNet = $vNet.Subnets | where-object Name -eq $Network.SwitchName

        $NetworkArgs = @{
            SwitchName = $SubNet.Name 
            PublicName = $Network.PublicIPName 
            NICArgs    = @{
                SubnetID = $SubNet.ID
            }
        }

        if ( $Network.EnableRDP -eq 'True' ) {

            $RDPCfg = @{
                Name = 'RDPRule'
                Description = 'Allow RDP'
                Access = 'Allow'
                Protocol = 'Tcp'
                Direction = 'Inbound'
                Priority = 110
                SourceAddressPrefix = 'Internet'
                SourcePortRange = '*'
                DestinationAddressPrefix = '*'
                DestinationPortRange = 3389
            }

            $rdpRule = New-AzureRmNetworkSecurityRuleConfig @RDPCfg
            $NSGroup = New-AzureRmNetworkSecurityGroup @ResGrpLoc -Name ($Network.PublicIPName + '_NSG') -SecurityRules $rdpRule

            $NetworkArgs.NICArgs.Add('NetworkSecurityGroupId', $NSGroup.id )
        }

        $NetWorkArgs | Write-Output
    }

}

function Get-AzureURLOfVHD {
    [cmdletbinding()]
    param ( $HostEnvironment, $Path, $VHDFile )

    if ( -not $Path ) { $Path = 'hydration' }
    'https://{0}.blob.core.windows.net/{1}/{2}' -f (Get-MyStorageAccountName $HostEnvironment),$Path,(split-path -leaf $VHDFile) | %{ $_.ToLower() } | Write-Output

}

function Publish-VHDToAzure {
    [cmdletbinding()]
    param(
        $StorageAccount,
        $HostEnvironment,
        $VHDFile
    )

    $ResGrpLoc = @{ ResourceGroup = $HostEnvironment.ResourceGroup ; Location = $HostEnvironment.AzureLocation }

    $SourceVHD = $StorageAccount | Get-AzureStorageContainer | Get-AzureStorageBlob | %{ $_.Context.BlobEndPoint + 'hydration/' + $_.Name }

    if ( -not ( $SourceVHD -and $SourceVHD.EndsWith('hydration.vhd') ) ) {

        $SourceVHD = Get-AzureURLOfVHD -HostEnvironment $hostEnvironment -VHDFile 'Hydration.vhd'
        write-LogEntry "Upload $VHDFIle to $SourceVHD"
        Add-AzureRmVhd -ResourceGroupName $ResGrpLoc.ResourceGroup -Destination $SourceVHD -LocalFilePath $VHDFile | out-string -Width 200 | write-verbose

    }

    $SourceVHD | write-output
}

$BootStrapScript = {
    # Command to 
    [cmdletbinding()] 
    param()

    Start-Transcript

    ###############################################
    Write-Verbose "Initalize System"

    get-disk | where-object OperationalStatus -eq offline | set-disk -isreadonly $False
    get-disk | where-object OperationalStatus -eq offline | set-disk -isoffline $False

    ###############################################
    Write-verbose "Test for Datafile"
    if ( -not ( test-path 'c:\azureData\CustomData.bin' ) ) {
        throw "missing c:\azureData\CustomData.bin"
    }

    ###############################################
    write-verbose "Write Datafile"

    $DeploymentShare = get-volume | 
        ForEach-Object { "$($_.DriveLetter)`:\ds-hydration" } | 
        Where-Object { Test-Path $_ } 

    if ( -not $DeploymentShare ) { 
        get-volume | Out-String -Width 200 | write-host
        throw "Deployment Share not found"
    }

    Copy-Item -Path 'c:\azureData\CustomData.bin' -Destination "$DeploymentShare\control\CustomSettings.ini" -Force

    start cscript.exe "$DeploymentShare\scripts\litetouch.vbs"

    write-verbose "Done!"

    Stop-Transcript
}

function Publish-FileBlobToAzure {
    [cmdletbinding()]
    param(        
        $HostEnvironment
    )

    $ResGrpLoc = @{ ResourceGroup = $HostEnvironment.ResourceGroup ; Location = $HostEnvironment.AzureLocation }

    write-verbose "Create Storage Account Blob"
    $_StorageAccount = New-AzureRmStorageAccount @ResGrpLoc -Name ((Get-MyStorageAccountName $HostEnvironment) + 'b') -SkuName Standard_LRS -Kind BlobStorage -AccessTier Cool 

    $_StorageAccount | Set-AzureRmCurrentStorageAccount | out-string | write-verbose
    while ( -not ( New-AzureStorageContainer -name 'bootstrap' -Permission Blob -ErrorAction SilentlyContinue ) ) {
        Write-LogEntry "Wait for Storage Container"
        sleep 10
    }

    $ScriptFile = "$env:temp\BootStrapHydration.ps1"
    $BootStrapScript | Set-Content $ScriptFile -Encoding Ascii

    write-LogEntry "Upload $ScriptFile"
    Set-AzureStorageBlobContent -Container 'bootstrap' -File $ScriptFile | write-verbose

    start-sleep 5

    remove-item $ScriptFile

    $_StorageAccount | Write-Output

}

function Get-CustomSettingsINI {
    [cmdletbinding()]
    param(
        $HostEnvironment,
        $VirtualMachine,
        $Cred
    )

    $Properties = @('Server_AdminAccount','Server_AdminPassword','TSMode','PublicFQDN')

    $Data = ""

    ForEach ($GuestRole in $VirtualMachine.GuestRoles.GuestRole) {
        ForEach ($Role in $GuestRole.ChildNodes) {
            ForEach ($Item in $Role.ChildNodes) {

                if ($Role.Name -eq "NAME") {
                    $Properties += "INSTALL$($Role.InnerText)"
                    $Data += "INSTALL$($Role.InnerText)=YES`r`n"
                }
                else {
                    $Properties += $Role.Name
                    $Data += "$($Role.Name)=$($Role.InnerText)`r`n"
                }
            }
        }
    }

@"
'//Ini file auto generate by MCS Client Hydration
[Settings]
Priority=Default, SecondPass, Configuration
Properties=$($Script:GuestProperties),$($Properties -join ',')

[Default]
OSInstall=Y
SkipWizard=YES
DeploymentType=CUSTOM
TaskSequenceID=HYDRATION
DoNotCreateExtraPartition=YES
_SMSTSOrgName=Hydration
TSMode=AZURE
Server_AdminAccount=$($Cred.UserName)
Server_AdminPassword=$($Cred.GetNetworkCredential().Password)

[secondpass]
DomainAdmin=%Server_AdminAccount%
DomainAdminPassword=%Server_AdminPassword%

[Configuration]
PublicFQDN=$($Script:LabDefinition.myFields.HostEnvironment.PublicFQDN)
$Data
"@ | Write-Output

}

<#

How to get a List of SKU's

Get-AzureRmVMImagePublisher -location 'Central US' | 
    ? publisherName -in "MicrosoftVisualStudio","MicrosoftWindowsServer" | 
    Get-AzureRmVMImageOffer | Get-AzureRmVMImageSku | 
    ? Skus -match '(10|2016)' | 
    out-gridview -passthru |    
    % { "@{ PublisherName='$($_.PublisherName)';Offer='$($_.Offer)';Skus='$($_.Skus)';Version='latest' }" }

#>

function Add-HydrationVM {
    [cmdletbinding()]
    param(
        $StorageAccount,
        $HostEnvironment,
        $VirtualMachine,
        $SourceVHD,
        $Networks,
        [PSCredential]$Cred 
    )

    $ResGrpLoc = @{ ResourceGroup = $HostEnvironment.ResourceGroup ; Location = $HostEnvironment.AzureLocation }

    Write-LogEntry "Add VirtualMachine $($VirtualMachine.GuestName)"

    $AzureImageArgs = invoke-Expression $VirtualMachine.AzureImageName

    ############################

    $elapsedTime = [system.diagnostics.stopwatch]::StartNew()  
    $diskConfig = New-AzureRmDiskConfig -AccountType Standard_LRS -Location $HostEnvironment.AzureLocation -CreateOption Import -SourceUri $SourceVHD -StorageAccountId $StorageAccount.ID
    while ( -not ( $AzureDisk = New-AzureRmDisk -Disk $diskConfig -ResourceGroupName $ResGrpLoc.ResourceGroup -DiskName "hydration_$($VirtualMachine.GuestName)" -ErrorAction SilentlyContinue ) ) {
        write-progress -activity "Wait for VHD to become available" -status "Elapsed Time: $($elapsedTime.Elapsed.tostring('hh\:mm\:ss'))"
        start-sleep 10
    }
    $elapsedTime = $null
    $AzureDisk | out-string | write-verbose

    ############################

    $CustomData = Get-CustomSettingsINI -HostEnvironment $HostEnvironment -VirtualMachine $VirtualMachine -Cred $Cred

    # Create a virtual machine configuration
    $vmConfig = New-AzureRmVMConfig -VMName $VirtualMachine.GuestName -VMSize $VirtualMachine.AzureVMSize |
        Set-AzureRmVMOperatingSystem -Windows -ComputerName $VirtualMachine.GuestName -Credential $cred -ProvisionVMAgent -WinRMHttp -CustomData $CustomData |
        Set-AzureRmVMSourceImage  @AzureImageArgs 
        
    ############################
    
    # Add Any network Interfaces
    ForEach ( $Network in $Networks | ? SwitchName -in $VirtualMachine.hardware.NetworkCards.NetworkCard.SwitchName ) {
        
        $NICargs = $Network.NICArgs

        $LocalNet = $VirtualMachine.hardware.NetworkCards.NetworkCard | ? SwitchName -eq $Network.SwitchName
        $PrvNetAddr  = @{ }
        if ( $LocalNet.NICIPAddress ) { $PrvNetAddr.add('PrivateIpAddress',$LocalNet.NICIPAddress) }

        if ( 'dcNew' -in $VirtualMachine.GuestRoles.GuestRole.name ) { 

        }
        $PrvNetAddr.add( 'DNSServer', @('10.0.0.6','168.63.129.16') );

        $pip = New-AzureRmPublicIpAddress  -Name ($Network.PublicName + '_' + $VirtualMachine.GuestName) @ResGrpLoc -AllocationMethod Dynamic
        $NIC = New-AzureRmNetworkInterface -Name ($Network.SwitchName + '_' + $VirtualMachine.GuestName) @ResGrpLoc @NICArgs -PublicIpAddressId $Pip.Id @PrvNetAddr 
        $VMConfig = $VMConfig | Add-AzureRmVMNetworkInterface -Id $nic.Id

    }

    ############################

    # Add data disks
    Add-AzureRmVMDataDisk -VM $vmConfig -Lun 1 -CreateOption Attach -ManagedDiskId $AzureDisk.ID | out-string | write-verbose

    Set-AzureRmVMBootDiagnostics -VM $vmConfig -Enable -ResourceGroupName $ResGrpLoc.ResourceGroup -StorageAccountName $StorageAccount.StorageAccountName

    $VMConfig | out-string | write-verbose
    New-AzureRmVM @ResGrpLoc -VM $vmConfig  -AsJob | write-output

}

function Invoke-BootStrap {
    [cmdletbinding()]
    param(
        $StorageAccount,
        $HostEnvironment,
        [string[]] $VMNames  
    )

    $ResGrpLoc = @{ ResourceGroup = $HostEnvironment.ResourceGroup ; Location = $HostEnvironment.AzureLocation }

    $StorageAccount | out-string -Width 200 | write-verbose

    $ScriptArgs = @{
        Name = 'bootstrapscript'.ToLower()
        StorageAccountName = ((Get-MyStorageAccountName $HostEnvironment) + 'b')
        ContainerName = 'bootstrap'.ToLower()
        FileName = 'BootStrapHydration.ps1'
        Run = 'BootStrapHydration.ps1'
    }

    $ScriptArgs | out-string -Width 200 | write-verbose

    Foreach ( $VMName in $VMNames ) { 
        write-verbose "Set Azure Custom Script Extension for $VMName"
        Set-AzureRmVMCustomScriptExtension @ResGrpLoc @ScriptArgs -VMName $VMName -ErrorAction Continue
        Start-Sleep 10
    }

}

#endregion

#region main

if (Get-IsElevated)

{

    Write-LogEntry "LabKit: $ISLabKit"

    (Get-Host).UI.RawUI.WindowTitle="$env:USERDOMAIN\$env:USERNAME (Elevated)"
    $Script:ScriptPath = (Get-ScriptPath)
    if ($Mode -ne "Azure") { Update-Variables }
    If ($NoElevate) { Write-LogEntry "`nBypassing elevation checks." -level "warning" }

    # Process each XML file that is in the pipeline
    ForEach ($XMLFile in $LabConfigFile)
    {
        Write-LogEntry "Processing $XMLFile." -level "warning"
        Get-LabXMLDefinition $XMLFile
        $Script:LabstorePath = $LabDefinition.myFields.HOSTENVIRONMENT.LABSTOREPATH
        $LABID=$Script:LabDefinition.myFields.HOSTENVIRONMENT.LABID
        switch ($Mode)
        {
            "Clean"
            {
                    if (!$Force)
                    {
                        if ((Read-Host -Prompt "Clean the lab for $LABID (Y/N)") -eq "Y")
                        {
                            CleanLab
                        }
                    }
                    else
                    {
                        CleanLab
                    }
                }
            "Purge"
            {
                    if (!$Force)
                    {

                        if ((Read-Host -Prompt "Completely remove the lab for $LABID (Y/N)") -eq "Y")
                        {
                            PurgeLab
                            Write-LogEntry "$LABID lab purged from host." -level "info"
                        }
                    }
                    else
                    {
                        PurgeLab
                        Write-LogEntry "$LABID lab purged from host. User invoked with -Force." -level "info"
                    }
                }
            "Provision"
            {

                    Write-LogEntry "Provision mode specified." -level "info"

                    $Comment = Get-Comments
                    # Code to support reprovisioning a specific guest
                    if ($GuestName -ne $Null)
                    {
                        $ExtendLab=$True
                        foreach($ReprovGuest in $GuestName)
                        {
                            # Find the storage location of the guest
                            Write-LogEntry "`tRequested to reprovision $ReprovGuest"
                            foreach ($Guest in  $Script:LabDefinition.myFields.LABGUESTS.LABGUEST)
                            {
                                if ($Guest.GUESTROLE -ne "DC")
                                {
                                    if (($LABID+"-"+ $Guest.GuestName) -eq $ReprovGuest)
                                    {
                                        $GuestRoleStorePath = $Guest.HARDWARE.GUESTROLESTOREPATH
                                        if ( [string]::IsNullOrEmpty($GuestRoleStorePath) )
                                        {
                                            $GuestRoleStorePath = $Script:LabDefinition.myFields.HOSTENVIRONMENT.LABSTOREPATH
                                        }
                                        $GuestStore = $GuestRoleStorePath +"\"+$LABID+"-"+$Guest.GuestName
                                        Write-LogEntry "`t`tFound guest configuration. Guest is stored at $GuestStore"
                                        Write-LogEntry "`t`tPurging guest"
                                        PurgeGuest -GuestName $ReprovGuest -GuestPath $GuestStore
                                        Write-LogEntry "`t`tGuest purged"
                                    }
                                }
                                elseif (($LABID+"-"+ $Guest.GuestName) -eq $ReprovGuest)
                                {
                                    Write-LogEntry "`t$GuestName is a domain controller. Reprovisioning a domain controller is not supported." -level "warning"
                                }
                            }

                        }
                    }
                    if (($ExtendLab -eq $False)-or ($ExtendLab -eq $NULL))
                    {
                        #Remove-Item -Path $LabDefinition.myFields.HOSTENVIRONMENT.LABSTOREPATH -Force -ErrorAction SilentlyContinue -Recurse
                        New-LabStore
                        Write-LogEntry "Processing $XMLFile." -level "info"
                    }
                    New-LabNetwork
                    NewGuests
                    Write-LogEntry "Lab setup complete." -level "info"
                }
            "Azure"
            {
                # Check if we are installing any roles that are not compatibile with Azure
                foreach ($Guest in $Script:LabDefinition.myFields.LABGUESTS.LABGUEST)
                {
                    ForEach ($Role in $Guest.GuestRoles.GuestRole)
                    {
                        $RoleName = ($Role.name).ToString()
                        Write-Host "Checking role $RoleName to see if it is compatible with Azure"
                        If (($Role.isAzure -ne $NULL) -and (($Role.isAzure).ToUpper() -eq "NO"))
                        {
                            Write-Host "$RoleName is incompatible with Azure exiting Hydration"
                            Exit
                        }
                    }
                }

                ##########################

                # Connect to Azure subscription
                write-verbose "Initialize-HydrationAzureRMSystem"
                Initialize-HydrationAzureRMSystem -HostEnvironment $Script:LabDefinition.myFields.HostEnvironment -force
                $StorageAccount = Initialize-StorageSystem -HostEnvironment $Script:LabDefinition.myFields.HostEnvironment

                ###############

                if ( -not (Get-AzureRmNetworkInterface -ResourceGroupName $Script:LabDefinition.myFields.HostEnvironment.ResourceGroup -ea SilentlyContinue ) ) { 
                    write-verbose "Initialize-NetworkingSystem"
                    $Networks = Initialize-NetworkingSystem -HostEnvironment  $Script:LabDefinition.myFields.HostEnvironment
                }

                ###############

                write-verbose "Upload-VHD $PSScriptRoot\parentdisks\hydrationparent.vhd"
                $SourceVHD = Publish-VHDToAzure -HostEnvironment $Script:LabDefinition.myFields.HostEnvironment -VHDFile "$PSScriptRoot\parentdisks\hydrationparent.vhd" -StorageAccount $StorageAccount
                $SourceVHD | out-string | write-verbose

                $ScriptStorageAccount = Publish-FileBlobToAzure -HostEnvironment $Script:LabDefinition.myFields.HostEnvironment

                ###############

                $jobs = @()
                Foreach ( $VirtualMachine in $Script:LabDefinition.MyFields.LabGuests.LabGuest ) {
                    Write-LogEntry "Add VirtualMachine $($VirtualMachine.GuestName)"
                    $jobs += Add-HydrationVM -HostEnvironment $Script:LabDefinition.myFields.HostEnvironment -VirtualMachine $VirtualMachine -Cred $cred -SourceVHD $SourceVHD -Networks $Networks -StorageAccount $StorageAccount
                }

                $count = 0
                while ( ( $jobs | ? State -ne Completed ) -and ( $Count -lt 100 ) ) {
                    Write-Progress -Activity "In Progress [$count/100]" -PercentComplete $Count
                    Start-Sleep 10
                    $Count += 1
                }
                write-progress -Completed -Activity "Done"

                Invoke-BootStrap -HostEnvironment $Script:LabDefinition.myFields.HostEnvironment -StorageAccount $ScriptStorageAccount -VMNames $Script:LabDefinition.MyFields.LabGuests.LabGuest.GuestName 

                Write-LogEntry "Lab setup complete." -level "info"

            }
            Default
            {
                Write-LogEntry "Please provide mode of operation using the -mode parameter" -level "info"
            }
        }
    }
}
else
{
    # Non-elevated execution
    (Get-Host).UI.RawUI.WindowTitle="$env:USERDOMAIN\$env:USERNAME (Not Elevated)"
    Try
    {
        Fix-Elevation
    }
    Catch
    {
        Write-LogEntry "Please start the script from an elevated PowerShell host." -level "warning"
        Exit $ERRORFAIL
    }

}

#endregion
