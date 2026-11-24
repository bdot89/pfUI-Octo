# pfUI Octo :: build octorank\ from the OctoRank add-on (24 Nov 2026).
# User: "merge this into our pfUI making it very light ... seamlessly work with WDI ... times are shared
# between both versions on the same chat channel so nothing is ever lost ... it will NEVER clash with WDI".
#
# OctoRank is WhoDidIt's ranking engine (5-man runs, raid times, the WDIBoard channel, the Chronicle
# logger) as a small add-on; its own tools\Sync-FromWhoDidIt.ps1 makes it. This copies it into pfUI
# with every name kept: the same OctoRank table, frames, slash command and saved variables
# (OctoRankDB, OctoRankChronDB, OctoRankChronCharDB). So:
#   - the separate OctoRank add-on and this copy are one save: with both on, the add-on runs and this
#     copy steps aside, and the times are in the same table either way
#   - WhoDidIt on: this copy steps aside too (WhoDidIt does all of it); modules\octorank.lua merges the
#     5-man runs between WhoDidItDB and OctoRankDB both ways, so nothing is lost when either goes
# Changed in the copy (and nothing else):
#   - Guard.lua: steps aside for WhoDidIt AND the OctoRank add-on (pfUI.toc OptionalDeps loads them first)
#   - pictures / fonts point at pfUI (Fira from pfUI\fonts, the rest in octorank\)
#   - ADDON_LOADED waits for "pfUI"; pfUI's OctoRanks switch (C.disabled.octorank) silences it
#   - the two minimap buttons start hidden (the sidebar entry and /orank open it)
# Fix engine bugs in WhoDidIt, sync OctoRank from it, then run this:
#   powershell -ExecutionPolicy Bypass -File tools\Sync-OctoRank.ps1 [-Src <OctoRank folder>]
param(
  [string]$AddOns = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
  [string]$Src = ""
)
$ErrorActionPreference = "Stop"
$pfui = Join-Path $AddOns "pfUI"
$src = if ($Src) { $Src } else { Join-Path $AddOns "OctoRank" }
$srcToc = Join-Path $src "OctoRank.toc"
if (-not (Test-Path $srcToc)) { throw "missing $srcToc" }
$dst = Join-Path $pfui "octorank"
$utf8 = New-Object Text.UTF8Encoding($false)

function Must([string]$text, [string]$old, [string]$new, [string]$file) {
  if (-not $text.Contains($old)) { throw "OctoRank changed: '$old' not found in $file" }
  return $text.Replace($old, $new)
}

if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
New-Item -ItemType Directory -Force $dst | Out-Null

# the files in the add-on's own load order
$load = New-Object System.Collections.ArrayList
$version = "1.0.0"
foreach ($line in [IO.File]::ReadAllLines($srcToc)) {
  $l = $line.Trim()
  if ($l -match '^##\s*Version:\s*(.+)$') { $version = $Matches[1].Trim() }
  if ($l -eq "" -or $l.StartsWith("#")) { continue }
  [void]$load.Add($l)
}

foreach ($rel in $load) {
  $from = Join-Path $src $rel
  $to = Join-Path $dst $rel
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $to) | Out-Null
  $t = [IO.File]::ReadAllText($from)
  if ($t.Length -gt 0 -and $t[0] -eq [char]0xFEFF) { $t = $t.Substring(1) }
  if ($rel -eq "Guard.lua") {
    $t = @"
--[[--------------------------------------------------------------------
	pfUI Octo: OctoRanks (made by tools\Sync-OctoRank.ps1 - do not edit)

	OctoRank built into pfUI. Every file here starts with
	"if ORANK_SKIP then return end": with WhoDidIt or the separate OctoRank
	add-on loaded (pfUI.toc's OptionalDeps load them first) this copy does
	nothing at all - no second channel, board or logger. They are one
	network (channel WDIBoard), and modules\octorank.lua keeps the times
	of all three in step.
----------------------------------------------------------------------]]

ORANK_SKIP = (IsAddOnLoaded("WhoDidIt") or IsAddOnLoaded("OctoRank")) and true or false
ORANK_PFUI = not ORANK_SKIP
"@
  } else {
    $t = $t.Replace("Interface\\AddOns\\OctoRank\\Fonts\\FiraSans", "Interface\\AddOns\\pfUI\\fonts\\FiraSans")
    $t = $t.Replace("Interface\\AddOns\\OctoRank\\", "Interface\\AddOns\\pfUI\\octorank\\")
    $t = [regex]::Replace($t, '\b(name|addonName) (~=|==) "OctoRank"', '$1 $2 "pfUI"')
    if ($rel -eq "Core.lua") {
      $t = Must $t 'W.version = GetAddOnMetadata("OctoRank", "Version") or "1.0.0"' ('W.version = "' + $version + '"') $rel
      $t = Must $t "local DEFAULTS = {" ("local DEFAULTS = {`r`n`tnoMinimap = true,         -- (pfUI Octo) the sidebar's OctoRanks entry and /orank open it") $rel
      # pfUI's OctoRanks switch: off = the event frame goes quiet (no channel, timer or logger)
      $t = Must $t "`tOctoRankDB.opts = OctoRankDB.opts or {}" ("`tOctoRankDB.opts = OctoRankDB.opts or {}`r`n" +
        "`tif pfUI_config and pfUI_config.disabled and pfUI_config.disabled.octorank == `"1`" then`r`n" +
        "`t`tW.off = true`r`n`t`tframe:SetScript(`"OnEvent`", nil)`r`n`t`tframe:SetScript(`"OnUpdate`", nil)`r`n" +
        "`t`tif ChronicleEventFrame then ChronicleEventFrame:UnregisterAllEvents() end`r`n`tend") $rel
    }
    if ($rel -eq "Chronicle\core.lua") {
      $t = Must $t 'ChronicleMinimapButton:SetShown(ChronicleLog:GetSetting("showMinimapIcon") ~= false)' 'ChronicleMinimapButton:SetShown(ChronicleLog:GetSetting("showMinimapIcon") == true)' $rel
    }
  }
  [IO.File]::WriteAllText($to, $t, $utf8)
}

# pictures, flags, the Chinese / Korean fonts (Fira comes from pfUI\fonts), notices
foreach ($d in "Flags", "Chronicle\textures") {
  $from = Join-Path $src $d
  if (Test-Path $from) {
    New-Item -ItemType Directory -Force -Path (Join-Path $dst $d) | Out-Null
    Copy-Item (Join-Path $from "*") (Join-Path $dst $d) -Recurse -Force
  }
}
New-Item -ItemType Directory -Force -Path (Join-Path $dst "Fonts") | Out-Null
Get-ChildItem (Join-Path $src "Fonts") -Filter "WDI-*" | ForEach-Object { Copy-Item $_.FullName (Join-Path $dst "Fonts") -Force }
foreach ($f in "LICENSE", "Chronicle\WDI_NOTICE.txt") {
  $from = Join-Path $src $f
  if (Test-Path $from) { Copy-Item $from (Join-Path $dst $f) -Force }
}
$engine = ""
$ef = Join-Path $src "tools\engine.txt"
if (Test-Path $ef) { $engine = ([IO.File]::ReadAllText($ef)).Trim() }
$readme = @(
  "OctoRank built into pfUI Octo - made by tools\Sync-OctoRank.ps1, do not edit by hand.",
  "",
  "OctoRank $version (engine: $engine): WhoDidIt's 5-man runs, raid rankings, the WDIBoard channel and",
  "the Chronicle logger (ChronicleCompanion by Emyrk, see Chronicle\WDI_NOTICE.txt). MIT, see LICENSE.",
  "Steps aside when WhoDidIt or the separate OctoRank add-on is loaded: one network, one save."
)
[IO.File]::WriteAllText((Join-Path $dst "README.txt"), ($readme -join "`r`n") + "`r`n", $utf8)

# the load list
$xml = New-Object Text.StringBuilder
[void]$xml.AppendLine('<Ui xmlns="http://www.blizzard.com/wow/ui/">')
[void]$xml.AppendLine('  <!-- made by tools\Sync-OctoRank.ps1: OctoRank in its own load order -->')
foreach ($rel in $load) { [void]$xml.AppendLine('  <Script file="' + $rel + '"/>') }
[void]$xml.AppendLine('</Ui>')
[IO.File]::WriteAllText((Join-Path $dst "octorank.xml"), $xml.ToString(), $utf8)

# pfUI.toc: the saved variables (the add-on's own names: one save), load WhoDidIt / OctoRank first, the xml
function Toc-Field([string]$path, [string]$name) {
  foreach ($line in [IO.File]::ReadAllLines($path)) {
    if ($line -match ('^##\s*' + $name + ':\s*(.+)$')) { return $Matches[1].Trim() }
  }
  return ""
}
$ptoc = Join-Path $pfui "pfUI.toc"
$lines = [IO.File]::ReadAllLines($ptoc)
$out = New-Object System.Collections.ArrayList
$hasXml = $false; $hasDeps = $false
$deps = @("WhoDidIt", "OctoRank", "ChronicleCompanion")
foreach ($line in $lines) {
  foreach ($kind in "SavedVariables", "SavedVariablesPerCharacter") {
    if ($line -match ('^## ' + $kind + ':')) {
      $have = ($line -replace ('^## ' + $kind + ':\s*'), '') -split '\s*,\s*'
      foreach ($v in ((Toc-Field $srcToc $kind) -split '\s*,\s*')) { if ($v -and ($have -notcontains $v)) { $line += ", $v" } }
    }
  }
  if ($line -match '^## OptionalDeps:') {
    $hasDeps = $true
    $have = ($line -replace '^## OptionalDeps:\s*', '') -split '\s*,\s*'
    foreach ($v in $deps) { if ($have -notcontains $v) { $line += ", $v" } }
  }
  if ($line.Trim() -eq "octorank\octorank.xml") { $hasXml = $true }
  [void]$out.Add($line)
}
if (-not $hasDeps) {
  $i = 0
  for ($j = 0; $j -lt $out.Count; $j++) { if ($out[$j] -match '^## SavedVariablesPerCharacter:') { $i = $j + 1 } }
  $out.Insert($i, "## OptionalDeps: " + ($deps -join ", "))
}
if (-not $hasXml) { [void]$out.Add("octorank\octorank.xml") }
[IO.File]::WriteAllText($ptoc, (($out -join "`r`n") + "`r`n"), $utf8)

"octorank\ built: " + $load.Count + " files, OctoRank $version ($engine)"
