Function Create-ScriptFromText {

[cmdletbinding()]
param(
    #$ScriptPath = "L:\Scripts\"
)

$ConfigFileName = ".\NewEnv.CMTP2.json"
Get-LabConfig -ConfigFileName $ConfigFileName -CreateFolders:$false

$LogPath = "C:$($Script:Base.VMLogPath)"

$SBScriptTemplateBegin = @"
    `$LogPath = "$($LogPath)"
    If(!(Test-Path -Path `$LogPath -ErrorAction SilentlyContinue))
    {
        New-Item -Path `$LogPath -ItemType Directory -ErrorAction SilentlyContinue
    }
    
    `$LogFile = "`$(`$LogPath)\`$(`$myInvocation.MyCommand).log" 
    
    Start-Transcript `$LogFile 
    Write-Host "Logging to `$LogFile" 
    
    #region Do Stuff Here
"@


$SCScriptTemplateEnd = @"
    #endregion

    Stop-Transcript
"@



$SBScriptTemplateBegin + $SCScriptTemplateEnd

$SBScriptTemplateBegin + $SCScriptTemplateEnd | Out-File "$($ScriptPath)Script-Template.ps1"

}