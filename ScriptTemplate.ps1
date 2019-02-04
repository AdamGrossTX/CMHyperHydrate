$LogPath = "C:$($Script:Base.VMDataPath)\Logs"
If(!(Test-Path -Path $LogPath -ErrorAction SilentlyContinue))
{
    New-Item -Path $LogPath -ItemType Directory -ErrorAction SilentlyContinue
}

$LogFile = "$($LogPath)\$($myInvocation.MyCommand).log" 

Start-Transcript $LogFile 
Write-Host "Logging to $LogFile" 

#region Do Stuff Here

#endregion

Stop-Transcript