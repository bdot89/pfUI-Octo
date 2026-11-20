# pfUI Octo :: build scrm\ from SuperCleveRoidMacros (20 Nov 2026).
# User: "Can we not just merge the SCRM into this version so it works across all it will fetch over any you had
# and just carry on working". SuperCleveRoidMacros (MIT, DWG / _brain / Torio / yani9o / Avitasia, kept as
# brues' octowow.st copy) is copied into pfUI\scrm, its LICENSE with it, and:
#   - a guard line on top of every Lua file: the copy steps aside when a separate SuperCleveRoidMacros is
#     switched on, or the client has no ClassicAPI 1.15.8+ (it cannot finish loading without it)
#   - its ADDON_LOADED start-ups also run on "pfUI"
#   - it never switches pfUI off (its "missing requirements" path disables its own add-on by name)
#   - no "rename your folder" warning about pfUI's macrotweak (ours stands aside for it)
#   - scrm\scrm.xml in its .toc's load order, its saved variables in pfUI.toc
# Run again to update: .\tools\Sync-SCRM.ps1 [-Src <SuperCleveRoidMacros folder>]
param(
  [string]$Src = "",
  [string]$Repo = "https://octowow.st/git/brues/SuperCleveRoidMacros.git"
)
$ErrorActionPreference = "Stop"
$pfui = Split-Path -Parent $PSScriptRoot
$dst = Join-Path $pfui "scrm"
$tmp = $null
if (-not $Src) {
  $tmp = Join-Path ([IO.Path]::GetTempPath()) ("scrm-" + [Guid]::NewGuid().ToString("N"))
  git clone -q --depth 1 $Repo $tmp
  if ($LASTEXITCODE -ne 0) { throw "git clone $Repo failed" }
  $Src = $tmp
}
$toc = Join-Path $Src "SuperCleveRoidMacros.toc"
if (-not (Test-Path $toc)) { throw "missing $toc" }
$commit = ""
if (Test-Path (Join-Path $Src ".git")) { $commit = (git -C $Src log -1 --format="%h %ad" --date=short) }

if (Test-Path $dst) {
  # keep guard.lua (ours), rebuild the rest
  Get-ChildItem $dst | Where-Object { $_.Name -ne "guard.lua" } | Remove-Item -Recurse -Force
} else {
  New-Item -ItemType Directory -Force $dst | Out-Null
}
$utf8 = New-Object Text.UTF8Encoding($false)
$guard = "if pfUIOctoSCRMSkip then return end -- pfUI Octo: built-in SuperCleveRoidMacros off (see scrm\guard.lua)`r`n"

function Must([string]$text, [string]$old, [string]$new, [string]$file) {
  if (-not $text.Contains($old)) { throw "SuperCleveRoidMacros changed: '$old' not found in $file" }
  return $text.Replace($old, $new)
}
$patches = @{
  "Core.lua" = @(
    @('if arg1 ~= "SuperCleveRoidMacros" then return end',
      'if arg1 ~= "SuperCleveRoidMacros" and not (pfUIOctoSCRM and arg1 == "pfUI") then return end -- pfUI Octo: built in'),
    @('pcall(DisableAddOn, addonName)',
      'if not pfUIOctoSCRM then pcall(DisableAddOn, addonName) end -- pfUI Octo: never switch pfUI off'),
    @('if addon == "CleveRoidMacros" or addon == "SuperCleveRoidMacros" then',
      'if addon == "CleveRoidMacros" or addon == "SuperCleveRoidMacros" or (pfUIOctoSCRM and addon == "pfUI") then -- pfUI Octo')
  );
  "Init.lua" = @(
    ,@('and not IsAddOnLoaded("SuperCleveRoidMacros") then',
      'and not IsAddOnLoaded("SuperCleveRoidMacros") and not pfUIOctoSCRM then -- pfUI Octo: built in, macrotweak stands aside')
  )
}

$load = New-Object System.Collections.ArrayList
foreach ($line in [IO.File]::ReadAllLines($toc)) {
  $l = $line.Trim()
  if ($l -eq "" -or $l.StartsWith("#")) { continue }
  $from = Join-Path $Src $l
  if (-not (Test-Path $from)) { throw "the .toc lists $l, not found" }
  $to = Join-Path $dst $l
  New-Item -ItemType Directory -Force (Split-Path -Parent $to) | Out-Null
  $t = [IO.File]::ReadAllText($from)
  if ($t.Length -gt 0 -and $t[0] -eq [char]0xFEFF) { $t = $t.Substring(1) }
  $name = Split-Path -Leaf $l
  if ($patches.ContainsKey($name) -and ($l -eq $name)) {
    foreach ($p in $patches[$name]) { $t = Must $t $p[0] $p[1] $l }
  }
  [IO.File]::WriteAllText($to, $guard + $t, $utf8)
  [void]$load.Add($l)
}
Copy-Item (Join-Path $Src "LICENSE") (Join-Path $dst "LICENSE-SuperCleveRoidMacros")

# scrm.xml: our guard, then its files in its own order
$xml = New-Object Text.StringBuilder
[void]$xml.Append("<Ui xmlns=`"http://www.blizzard.com/wow/ui/`">`r`n")
[void]$xml.Append("  <!-- pfUI Octo: SuperCleveRoidMacros built in, made by tools\Sync-SCRM.ps1" + $(if ($commit) { " from $commit" } else { "" }) + " -->`r`n")
[void]$xml.Append("  <Script file=`"guard.lua`"/>`r`n")
foreach ($l in $load) { [void]$xml.Append("  <Script file=`"$l`"/>`r`n") }
[void]$xml.Append("</Ui>`r`n")
[IO.File]::WriteAllText((Join-Path $dst "scrm.xml"), $xml.ToString(), $utf8)

# its saved variables in pfUI.toc (account-wide, as in its own .toc)
$sv = ""
foreach ($line in [IO.File]::ReadAllLines($toc)) {
  if ($line -match '^##\s*SavedVariables:\s*(.+)$') { $sv = $Matches[1].Trim() }
}
$ptoc = Join-Path $pfui "pfUI.toc"
$lines = [IO.File]::ReadAllLines($ptoc)
$out = New-Object System.Collections.ArrayList
$hasXml = $false
foreach ($line in $lines) {
  if ($line -match '^## SavedVariables:') {
    $have = ($line -replace '^## SavedVariables:\s*', '') -split '\s*,\s*'
    foreach ($v in ($sv -split '\s*,\s*')) { if ($v -and ($have -notcontains $v)) { $line += ", $v" } }
  }
  if ($line.Trim() -eq "scrm\scrm.xml") { $hasXml = $true }
  [void]$out.Add($line)
}
if (-not $hasXml) { [void]$out.Add("scrm\scrm.xml") }
[IO.File]::WriteAllText($ptoc, (($out -join "`r`n") + "`r`n"), $utf8)

if ($tmp) { Remove-Item -Recurse -Force $tmp }
"scrm\ built: " + $load.Count + " files" + $(if ($commit) { " ($commit)" } else { "" })
