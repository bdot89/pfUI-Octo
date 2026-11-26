<#
  pfUI Octo :: Auto-Chronicle.ps1 (26 Nov 2026; user: "This should run itself and be synced")
  Run by the Windows task "pfUI Octo - Chronicle sync" (tools\Install-ChronicleTask.ps1) once a day:
    1. tools\Sync-Chronicle.ps1 - the last 7 days from Chronicle's public API (cached: only new raids are fetched)
    2. when modules\octoboards-data.lua changed: commits ONLY that file and pushes the octo branch to "bdot"
       (pfUI-Octo + the launcher's bdot89/pfUI), so everyone's launcher update brings the new boards.
  Log: %LOCALAPPDATA%\pfUI-Octo\chronicle\auto.log (the last 400 lines are kept).
#>
# (Continue: git and the child PowerShell write progress to stderr, which "Stop" would turn into a failure; exit codes
# are checked instead)
$ErrorActionPreference = "Continue"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$dir = Join-Path $env:LOCALAPPDATA "pfUI-Octo\chronicle"
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
$log = Join-Path $dir "auto.log"
function Say([string]$t) { Add-Content -Path $log -Value ((Get-Date).ToString("yyyy-MM-dd HH:mm:ss") + "  " + $t) -Encoding UTF8 }

Say "start"
try {
  $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "Sync-Chronicle.ps1") -Days 7 2>&1
  $last = @($out | ForEach-Object { "$_" })
  Say ("sync: " + ($last | Select-Object -Last 1))
  if ($LASTEXITCODE -ne 0) { throw "the sync failed: " + (($last | Select-Object -Last 3) -join " / ") }

  $file = "modules/octoboards-data.lua"
  Push-Location $repo
  try {
    $branch = (& git rev-parse --abbrev-ref HEAD).Trim()
    if ($branch -ne "octo") { Say ("not on the octo branch (" + $branch + "): nothing committed"); return }
    $changed = & git status --porcelain -- $file
    if (-not $changed) { Say "no change in the boards"; return }
    & git add -- $file
    # (only this file goes in the commit, whatever else is being worked on)
    & git commit -q -m ("OctoBoards: Chronicle boards " + (Get-Date).ToString("d MMM yyyy")) -- $file
    if ($LASTEXITCODE -ne 0) { throw "git commit failed" }
    & git push -q bdot octo 2>&1 | ForEach-Object { Say ("push: " + $_) }
    if ($LASTEXITCODE -ne 0) { throw "git push failed (the branch may be behind: pull first)" }
    Say ("pushed " + (& git rev-parse --short HEAD).Trim())
  } finally { Pop-Location }
} catch {
  Say ("ERROR: " + $_.Exception.Message)
} finally {
  $all = @(Get-Content $log -Encoding UTF8)
  if ($all.Count -gt 400) { $all | Select-Object -Last 400 | Set-Content $log -Encoding UTF8 }
}
