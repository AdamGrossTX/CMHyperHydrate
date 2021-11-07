# CMHyperHydrate
A PowerShell module designed to rapidly hydrate a ConfigMgr lab on Hyper-V.

THIS IS A WORK IN PROGRESS. SEVERAL KNOWN ISSUES. USE AT YOUR OWN RISK!

## Create Folders for Media

- Media
  - ADK
  - ADKWinPE
  - Apps
  - ConfigMgrCB
    - Prereqs
  - ConfigMgrTP
    - Prereqs
  - Drivers
  - ISO
  - Server
    - SQL
    - Windows10
    - Windows11
  - Packages

## Required Media

Download the following:

- [Windows ADK](https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install)
- [Windows ADK WinPE AddOn](https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install)
- ConfigMgr Current Branch (MSDN or MVLS Download)
- [ConfigMgr Tech Preview](https://www.microsoft.com/en-us/evalcenter/evaluate-microsoft-endpoint-configuration-manager-technical-preview/)
- Windows Server ISO - Save to `Media\ISO\Server`
- Windows 10 ISO - Save to `Media\ISO\Windows10`
- Windows 11 ISO - Save to `Media\ISO\Windows11`

## Prepare Source Media

### ADK

- Download ADK Offline. Store in `Media\ADK` Folder.
- Download ADK WinPE Offline. Store in `Media\ADKWinPE` Folders

### ConfigMgr CB

- Mount ConfigMgr CB ISO and Copy Contents to `Media\ConfigMgrCB`
- Launch `Media\ConfigMgrCB\splash.hta` and select Download required prerequisite files. Download files to `Media\ConfigMgrCB\Prereqs`.

### ConfigMgr TP

- Launch `Config_TechPreviewXXXX.exe` to extract contents to `Media\ConfigMgrTP`
- Launch Media\ConfigMgrTP\splash.hta and select Download required prerequisite files. Download files to `Media\ConfigMgrTP\Prereqs`.
