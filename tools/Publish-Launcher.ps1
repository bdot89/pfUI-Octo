<#
  pfUI Octo :: Publish-Launcher.ps1 (27 Nov 2026)
  bdot89/pfUI is the copy OctoLauncher installs ("Add custom git addon"). The launcher deletes the old pfUI folder,
  then clones the repo with a JavaScript git library; a friend's fresh install failed and left an empty folder (the
  full repo is 130 MB / 2,170 files). This publishes a GAME-FILES-ONLY commit there: the octo branch's files minus
  what only development uses (docs, tests, tools - except tools\install_dlls.ps1, which the DLL .bat runs - and the
  notes files). Nothing the game loads is left out.
  The launcher copy keeps its own straight history (each publish is a child of the last one), so players' existing
  launcher copies update with a normal pull.
  Run by .git\hooks\pre-push on every "git push bdot octo"; by hand:
    powershell -ExecutionPolicy Bypass -File tools\Publish-Launcher.ps1 [-DryRun]
#>
param([switch]$DryRun, [string]$Source = "HEAD")
$ErrorActionPreference = "Continue"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$url = "https://github.com/bdot89/pfUI.git"
# what the game never loads
$drop = @("docs", "tests", "tools", ".github", "CLAUDE.md", "TODO.md")
$keep = @("tools/install_dlls.ps1")

Push-Location $repo
try {
  $srcCommit = (& git rev-parse $Source).Trim()
  $index = Join-Path $env:TEMP ("pfui-launcher-index-" + [Guid]::NewGuid().ToString("N"))
  $env:GIT_INDEX_FILE = $index
  & git read-tree $srcCommit
  foreach ($d in $drop) { & git rm -r -q --cached --ignore-unmatch -- $d | Out-Null }
  foreach ($k in $keep) {
    $line = & git ls-tree $srcCommit -- $k
    if ($line -match '^(\d+) blob ([0-9a-f]+)\t') { & git update-index --add --cacheinfo ("{0},{1},{2}" -f $Matches[1], $Matches[2], $k) }
  }
  $tree = (& git write-tree).Trim()
  Remove-Item Env:\GIT_INDEX_FILE
  Remove-Item $index -Force -ErrorAction SilentlyContinue

  # the launcher copy's newest commit (its parent)
  & git fetch -q $url "+octo:refs/launcher/octo" 2>&1 | Out-Null
  $parent = (& git rev-parse -q --verify refs/launcher/octo 2>$null)
  if ($parent) { $parent = $parent.Trim() }
  if ($parent -and ((& git rev-parse "$parent^{tree}").Trim() -eq $tree)) { Write-Host "Launcher copy: already up to date."; return }

  $version = ""
  $toc = & git show "${srcCommit}:pfUI.toc"
  foreach ($l in $toc) { if ($l -match '^## X-Octo-Version:\s*(\S+)') { $version = $Matches[1] } }
  $short = $srcCommit.Substring(0, 8)
  $msg = "pfUI Octo $version (game files of $short)"
  $args2 = @("commit-tree", $tree, "-m", $msg)
  if ($parent) { $args2 = @("commit-tree", $tree, "-p", $parent, "-m", $msg) }
  $commit = (& git @args2).Trim()
  $count = @(& git ls-tree -r --name-only $tree).Count
  if ($DryRun) { Write-Host ("Launcher copy (dry run): {0} files, commit {1} on {2}" -f $count, $commit.Substring(0, 8), $(if ($parent) { $parent.Substring(0, 8) } else { "nothing" })); return }
  # (a URL, not the "bdot" remote: the pre-push hook only acts on "bdot")
  & git push -q $url ("{0}:refs/heads/octo" -f $commit) 2>&1 | ForEach-Object { Write-Host $_ }
  if ($LASTEXITCODE -ne 0) { Write-Host "Launcher copy: push FAILED"; exit 1 }
  & git update-ref refs/launcher/octo $commit
  Write-Host ("Launcher copy: published {0} ({1} files) - {2}" -f $commit.Substring(0, 8), $count, $msg)
} finally { Pop-Location }
