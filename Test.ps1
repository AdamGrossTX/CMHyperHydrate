
$ScriptPath = "L:\Scripts\"
$LogPath = "$($ScriptPath)Logs"

If(!(Test-Path -Path $ScriptPath -ErrorAction SilentlyContinue))
{
    New-Item -Path $ScriptPath -ItemType Directory -ErrorAction SilentlyContinue
}


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