<#
  pfUI Octo :: Install-ChronicleTask.ps1 (26 Nov 2026)
  Makes (or replaces) the Windows task "pfUI Octo - Chronicle sync": tools\Auto-Chronicle.ps1 every day at 06:00,
  hidden, as you, only while you are signed in; a day the PC was off runs as soon as it is on again.
    powershell -ExecutionPolicy Bypass -File tools\Install-ChronicleTask.ps1            # install / update
    powershell -ExecutionPolicy Bypass -File tools\Install-ChronicleTask.ps1 -Remove    # take it away
#>
param([switch]$Remove, [string]$At = "06:00")
$name = "pfUI Octo - Chronicle sync"
if ($Remove) {
  Unregister-ScheduledTask -TaskName $name -Confirm:$false -ErrorAction SilentlyContinue
  Write-Host "Removed the task '$name'."
  return
}
$script = Join-Path $PSScriptRoot "Auto-Chronicle.ps1"
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument ("-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"" + $script + "`"")
$trigger = New-ScheduledTaskTrigger -Daily -At $At
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 1)
Register-ScheduledTask -TaskName $name -Action $action -Trigger $trigger -Settings $settings -Description "Fetches Chronicle's raid boards for OctoBoards and pushes them with pfUI Octo." -Force | Out-Null
Write-Host "Installed '$name': every day at $At (or when the PC is next on). Log: %LOCALAPPDATA%\pfUI-Octo\chronicle\auto.log"
