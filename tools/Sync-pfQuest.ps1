# pfUI Octo :: build pfquest\ from the pfQuest add-ons (9 Nov 2026).
# User: "add the pf database into our addon ... no need for anything else to be
# installed other than our pfUI /db works the same as it should".
# 11 Nov 2026: switched to the versions the OctoWoW launcher installs
# (lightblade's pfQuest 8.x and pfQuest-turtle, octowow.st/git/lightblade):
# world map pins, loot panel, nameplate icons, a bigger config window. They
# bring their own gathering icons, so pfQuest-icons is no longer used.
# Copies pfQuest and pfQuest-turtle into pfUI\pfquest, English data only, and:
#   - puts a guard line on top of every Lua file, so when the standalone
#     pfQuest is still switched on our copy steps aside
#   - lets pfQuest's ADDON_LOADED handlers start on "pfUI" too
#   - points pfQuest's folder, its pictures and its version numbers at pfUI
#   - writes pfquest\pfquest.xml in the add-ons' own load order (read from their
#     .toc and init\*.xml) and the versions / saved variables into pfUI.toc
# Run again after updating: .\tools\Sync-pfQuest.ps1 [-Src <pfQuest folder>] [-Turtle <pfQuest-turtle folder>]
param(
  [string]$AddOns = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
  [string]$Src = "",
  [string]$Turtle = ""
)
$ErrorActionPreference = "Stop"
$pfui = Join-Path $AddOns "pfUI"
$src = if ($Src) { $Src } else { Join-Path $AddOns "pfQuest" }
$turtle = if ($Turtle) { $Turtle } else { Join-Path $AddOns "pfQuest-turtle" }
$dst = Join-Path $pfui "pfquest"
foreach ($p in $src, $turtle) { if (-not (Test-Path $p)) { throw "missing $p" } }
$srcToc = Join-Path $src "pfQuest.toc"
$turtleToc = Join-Path $turtle "pfQuest-turtle.toc"
foreach ($p in $srcToc, $turtleToc) { if (-not (Test-Path $p)) { throw "missing $p" } }

if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
New-Item -ItemType Directory -Force $dst | Out-Null

$guard = [Text.Encoding]::ASCII.GetBytes("if pfQuestOctoSkip then return end -- pfUI Octo: the standalone pfQuest is loaded`r`n")
$utf8 = New-Object Text.UTF8Encoding($false)
$load = New-Object System.Collections.ArrayList

function Must([string]$text, [string]$old, [string]$new) {
  if (-not $text.Contains($old)) { throw "pfQuest changed: '$old' not found" }
  return $text.Replace($old, $new)
}
# every code file (not the data): ask pfUI's toc for pfQuest's versions, and
# find pfQuest-turtle's pictures inside pfUI
function Octo([string]$t) {
  $t = $t.Replace("GetAddOnMetadata(", "pfQuestOctoMeta(")
  return $t.Replace('Interface\\AddOns\\pfQuest-turtle\\img', 'Interface\\AddOns\\pfUI\\pfquest\\turtle-img')
}
function Copy-Lua([string]$from, [string]$rel, [scriptblock]$patch, [bool]$code) {
  $to = Join-Path $dst $rel
  New-Item -ItemType Directory -Force (Split-Path -Parent $to) | Out-Null
  $bytes = [IO.File]::ReadAllBytes($from)
  $start = 0
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $start = 3 }
  if ($patch -or $code) {
    $text = $utf8.GetString($bytes, $start, $bytes.Length - $start)
    if ($patch) { $text = & $patch $text }
    if ($code) { $text = Octo $text }
    $body = $utf8.GetBytes($text)
  } else {
    $body = New-Object byte[] ($bytes.Length - $start)
    [Array]::Copy($bytes, $start, $body, 0, $body.Length)
  }
  $out = New-Object byte[] ($guard.Length + $body.Length)
  [Array]::Copy($guard, 0, $out, 0, $guard.Length)
  [Array]::Copy($body, 0, $out, $guard.Length, $body.Length)
  [IO.File]::WriteAllBytes($to, $out)
  [void]$load.Add($rel)
}
# the Lua files an init\*.xml includes, relative to the add-on's folder
function Xml-Files([string]$root, [string]$xml) {
  $path = Join-Path $root $xml
  if (-not (Test-Path $path)) { throw "missing $path" }
  $out = @()
  foreach ($m in [regex]::Matches([IO.File]::ReadAllText($path), '(?:Include|Script)\s+file="([^"]+)"')) {
    $f = $m.Groups[1].Value -replace '/', '\'
    if ($f.StartsWith("..\")) { $f = $f.Substring(3) } else { $f = (Join-Path (Split-Path -Parent $xml) $f) }
    $out += $f
  }
  return $out
}
# the files a .toc loads, init\*.xml expanded; other languages' data left out
function Toc-Files([string]$root, [string]$toc) {
  $out = @()
  foreach ($line in [IO.File]::ReadAllLines($toc)) {
    $l = $line.Trim()
    if ($l -eq "" -or $l.StartsWith("#")) { continue }
    $l = $l -replace '/', '\'
    if ($l -match '\\(koKR|frFR|deDE|zhCN|zhTW|esES|ruRU|ptBR)(-\w+)?\.xml$') { continue }
    if ($l.EndsWith(".xml")) { $out += Xml-Files $root $l } else { $out += $l }
  }
  return $out
}
function Toc-Field([string]$toc, [string]$field) {
  foreach ($line in [IO.File]::ReadAllLines($toc)) {
    if ($line -match ('^##\s*' + [regex]::Escape($field) + ':\s*(.+)$')) { return $Matches[1].Trim() }
  }
  return ""
}

$started = { param($t)
  Must $t 'if arg1 == "pfQuest" or arg1 == "pfQuest-tbc" or arg1 == "pfQuest-wotlk" then' 'if arg1 == "pfQuest" or arg1 == "pfQuest-tbc" or arg1 == "pfQuest-wotlk" or arg1 == "pfUI" then'
}
$patches = @{
  # its own folder and version, not a pfQuest folder that may still sit in AddOns
  "config.lua" = { param($t)
    $t = & $started $t
    Must $t 'local tocs = { "", "-master", "-tbc", "-wotlk", "-turtle" }' ("-- pfUI Octo: built into pfUI`r`npfQuestConfig.path = `"Interface\\AddOns\\pfUI\\pfquest`"`r`npfQuestConfig.version = tostring(pfQuestOctoMeta(`"pfQuest`", `"Version`") or `"0`")`r`nlocal tocs = {}")
  }
  "quest.lua" = $started
  # (12 Nov 2026, Wolfahrt: "pfquest\map.lua:50: attempt to index global 'pfMap'" twice a second) at load
  # map.lua looks through the world map's models for the player arrow; another add-on's model there with
  # no model file set gives GetModel() = nil, strlower errored, the file stopped before pfMap was made and
  # the control-key ticker made above it errored for good.
  "map.lua" = { param($t)
    Must $t 'strlower(v:GetModel())' 'strlower(v:GetModel() or "")'
  }
  # built in, its version comes from pfUI's toc; another player's VERSION message
  # before ours is known must not error (9 Nov 2026: endless chat errors)
  "updatenotify.lua" = { param($t)
    $t = & $started $t
    $t = Must $t 'GetAddOnMetadata(arg1, "Version")' 'pfQuestOctoMeta("pfQuest", "Version")'
    Must $t 'if remote > version then' 'if version and remote > version then'
  }
  # The chat hook keeps the game's AddMessage under its own name, not pfQuest's.
  # A standalone pfQuest (any folder name, loaded after pfUI) does
  # "pfQuestHookAddMessage = pfQuestHookAddMessage or AddMessage": finding ours
  # there, it went straight to the game's AddMessage past pfUI's chat - no times,
  # short channels or class colours (9 and 11 Nov 2026, Barbeque and dennis).
  # Questing > off finds the hook by pfQuestOctoParse, wherever pfUI's chat put it.
  "compat\client.lua" = { param($t)
    $t = Must $t "pfQuestHookAddMessage" "pfQuestOctoHookAddMessage"
    $t = $t.Replace("pfQuestHookAddMessage", "pfQuestOctoHookAddMessage")
    $re = '(?m)^(\s*)(_G\["ChatFrame"\s*\.\.\s*i\]\.AddMessage = ParseQuestLevels)\s*$'
    if (-not [regex]::IsMatch($t, $re)) { throw "pfQuest changed: chat hook line not found" }
    [regex]::Replace($t, $re, "`$1`$2`r`n`$1_G[`"ChatFrame`" .. i].pfQuestOctoParse = ParseQuestLevels")
  }
}

# pfQuest, then pfQuest-turtle, each in its own .toc order. Turtle's files go
# under db\ (data) or get a "turtle-" name where pfQuest has one the same.
foreach ($rel in (Toc-Files $src $srcToc)) {
  $code = -not $rel.StartsWith("db\")
  Copy-Lua (Join-Path $src $rel) $rel $patches[$rel] $code
}
foreach ($rel in (Toc-Files $turtle $turtleToc)) {
  if ($rel.StartsWith("db\")) { $to = $rel; $code = $false }
  else { $to = "turtle-" + ($rel -replace '\\', '-'); $code = $true }
  Copy-Lua (Join-Path $turtle $rel) $to $null $code
}

# art and licences
Copy-Item -Recurse (Join-Path $src "img") (Join-Path $dst "img")
if (Test-Path (Join-Path $src "compat")) {
  New-Item -ItemType Directory -Force (Join-Path $dst "compat") | Out-Null
  Get-ChildItem (Join-Path $src "compat") -File | Where-Object { $_.Extension -ne ".lua" } | ForEach-Object { Copy-Item $_.FullName (Join-Path $dst "compat") }
}
Copy-Item -Recurse (Join-Path $turtle "img") (Join-Path $dst "turtle-img")
Copy-Item (Join-Path $src "LICENSE") (Join-Path $dst "LICENSE-pfQuest")
Copy-Item (Join-Path $turtle "LICENSE") (Join-Path $dst "LICENSE-pfQuest-turtle")

# versions and saved variables into pfUI.toc
$qv = Toc-Field $srcToc "Version"
$tv = Toc-Field $turtleToc "Version"
$tocPath = Join-Path $pfui "pfUI.toc"
$toc = [IO.File]::ReadAllText($tocPath)
$toc = [regex]::Replace($toc, '(?m)^## X-pfQuest-Version:.*$', "## X-pfQuest-Version: $qv")
if ($toc -match '(?m)^## X-pfQuest-Turtle-Version:') {
  $toc = [regex]::Replace($toc, '(?m)^## X-pfQuest-Turtle-Version:.*$', "## X-pfQuest-Turtle-Version: $tv")
} else {
  $toc = [regex]::Replace($toc, '(?m)^(## X-pfQuest-Version:.*)$', "`$1`r`n## X-pfQuest-Turtle-Version: $tv")
}
foreach ($kind in "SavedVariables", "SavedVariablesPerCharacter") {
  $want = @()
  foreach ($t in $srcToc, $turtleToc) { $f = Toc-Field $t $kind; if ($f) { $want += ($f -split ',\s*') } }
  $m = [regex]::Match($toc, '(?m)^## ' + $kind + ': (.*?)\r?$')
  $have = $m.Groups[1].Value -split ',\s*'
  $add = $want | Where-Object { $_ -and ($have -notcontains $_) }
  if ($add) { $toc = $toc.Replace($m.Value.TrimEnd("`r"), ("## " + $kind + ": " + (($have + $add) -join ", "))) }
}
[IO.File]::WriteAllText($tocPath, $toc, $utf8)

# where it came from
$readme = @(
  "pfQuest built into pfUI Octo - made by tools\Sync-pfQuest.ps1, do not edit by hand.",
  "",
  "pfQuest and pfQuest-turtle as the OctoWoW launcher installs them (octowow.st/git/lightblade),",
  "by Shagu, Rivi, txtsd and contributors (MIT, see the LICENSE files).",
  "English data only. When the standalone pfQuest add-on is switched on this copy steps aside.",
  "",
  ("pfQuest:        " + $qv),
  ("pfQuest-turtle: " + $tv)
)
[IO.File]::WriteAllText((Join-Path $dst "README.txt"), ($readme -join "`r`n") + "`r`n", $utf8)

# the load list; the first file decides whether this copy runs
$skip = @"
-- pfUI Octo: when the standalone pfQuest add-on is on, every file of this copy
-- returns at its first line. pfQuest's toc says "OptionalDeps: pfUI", so the
-- standalone one loads AFTER pfUI and has not made pfDB yet: whether it is
-- switched on decides (9 Nov 2026: both ran, two of everything, and its chat
-- hook went straight to the game's, past pfUI's chat - no times, class colours
-- or links for anyone who still had pfQuest on).
-- (11 Nov 2026, dennis on Discord: two quest menus on the world map.) Any folder
-- name counts - a download unpacks as "pfQuest-master" - but not pfQuest's
-- add-ons (pfQuest-turtle, pfQuest-icons...), which need pfQuest to load.
local function pfQuestOctoMain(name, enabled, loadable, d1, d2, d3, d4)
  if not (name and enabled and loadable) then return false end
  local n = string.lower(name)
  if n == "pfui" or not string.find(n, "^pfquest") then return false end
  local d = { d1, d2, d3, d4 }
  for i = 1, 4 do
    if d[i] and string.find(string.lower(d[i]), "^pfquest") then return false end
  end
  return true
end
local function pfQuestOctoStandalone()
  if pfDB ~= nil then return true end
  if type(GetAddOnInfo) ~= "function" then return false end
  local ok, name, _, _, enabled, loadable = pcall(GetAddOnInfo, "pfQuest")
  if ok and name and enabled and loadable then return true end
  if type(GetNumAddOns) ~= "function" then return false end
  local count = GetNumAddOns()
  if type(count) ~= "number" then return false end
  for i = 1, count do
    local n, _, _, en, lo = GetAddOnInfo(i)
    local d1, d2, d3, d4
    if GetAddOnDependencies then d1, d2, d3, d4 = GetAddOnDependencies(i) end
    if pfQuestOctoMain(n, en, lo, d1, d2, d3, d4) then return true end
  end
  return false
end
pfQuestOctoSkip = pfQuestOctoStandalone()
-- Built in, pfQuest's own add-on names are not loaded (or are an old copy left
-- in AddOns): their versions come from pfUI's toc. Every GetAddOnMetadata in the
-- copied code calls this instead.
function pfQuestOctoMeta(addon, field)
  if field == "Version" then
    if addon == "pfQuest" or addon == "pfQuest-tbc" or addon == "pfQuest-wotlk" then
      return GetAddOnMetadata("pfUI", "X-pfQuest-Version")
    elseif addon == "pfQuest-turtle" then
      return GetAddOnMetadata("pfUI", "X-pfQuest-Turtle-Version")
    end
  end
  return GetAddOnMetadata(addon, field)
end
-- This copy loads after pfUI's files but before pfUI has its settings, so pfUI
-- is hidden while pfQuest's files run and put back after (restore.lua):
-- pfQuest starts exactly as it does next to the standalone pfUI.
if not pfQuestOctoSkip then
  pfQuestOctoHidden = { pfUI = pfUI, pfUI_config = pfUI_config }
  pfUI = nil
  pfUI_config = nil

  -- the off switch (Questing page, modules\questing.lua): what pfQuest's files
  -- change is noted here and in restore.lua - the game's functions they replace,
  -- the frames they make, their slash commands - so it can all be put back at
  -- login before anything else starts
  local env = getfenv(0)
  local before, slash, frames = {}, {}, {}
  for k, v in pairs(env) do if type(v) == "function" then before[k] = v end end
  for k in pairs(SlashCmdList or {}) do slash[k] = true end
  local make = CreateFrame
  pfQuestOcto = { before = before, slash = slash, frames = frames, make = make }
  CreateFrame = function(a1, a2, a3, a4)
    local f
    if a4 then f = make(a1, a2, a3, a4) elseif a3 then f = make(a1, a2, a3)
    elseif a2 then f = make(a1, a2) else f = make(a1) end
    table.insert(frames, f)
    return f
  end
end
"@
$restore = @"
-- pfUI Octo: pfQuest's files have run (guard.lua): pfUI back under its name
if pfQuestOctoHidden then
  -- (14 Nov 2026, Khijazi: "/db ... clicking on Objects/Items" = browser.lua:532 "attempt to call field
  -- SetButtonFontColor". pfQuest's files ran with a stand-in pfUI (compat\pfUI.lua); what they call later,
  -- on a click, is the real one. Every helper the stand-in has and the real pfUI lacks goes across.)
  local standin, real = pfUI, pfQuestOctoHidden.pfUI
  if type(standin) == "table" and type(standin.api) == "table" and real and type(real.api) == "table" then
    for k, v in pairs(standin.api) do
      if real.api[k] == nil and k ~= "emulated" then real.api[k] = v end
    end
    for _, k in ipairs({ "font_default", "backdrop", "backdrop_small", "backdrop_no_top" }) do
      if real[k] == nil and standin[k] ~= nil then real[k] = standin[k] end
    end
  end
  pfUI = pfQuestOctoHidden.pfUI
  pfUI_config = pfQuestOctoHidden.pfUI_config
  pfQuestOctoHidden = nil
end

-- what pfQuest's files changed, for the off switch (modules\questing.lua)
if pfQuestOcto and pfQuestOcto.make then
  local env = getfenv(0)
  CreateFrame = pfQuestOcto.make
  pfQuestOcto.make = nil
  local changed, newslash = {}, {}
  for k, v in pairs(pfQuestOcto.before) do
    if env[k] ~= v then changed[k] = v end
  end
  for k in pairs(SlashCmdList or {}) do
    if not pfQuestOcto.slash[k] then newslash[k] = true end
  end
  pfQuestOcto.changed, pfQuestOcto.slash, pfQuestOcto.before = changed, newslash, nil
end
"@
[IO.File]::WriteAllText((Join-Path $dst "guard.lua"), ($skip -replace "`r?`n", "`r`n"), $utf8)
[IO.File]::WriteAllText((Join-Path $dst "restore.lua"), ($restore -replace "`r?`n", "`r`n"), $utf8)
$xml = New-Object Text.StringBuilder
[void]$xml.Append("<Ui xmlns=`"http://www.blizzard.com/wow/ui/`">`r`n")
[void]$xml.Append("  <Script file=`"guard.lua`"/>`r`n")
foreach ($rel in $load) { [void]$xml.Append("  <Script file=`"$rel`"/>`r`n") }
[void]$xml.Append("  <Script file=`"restore.lua`"/>`r`n")
[void]$xml.Append("</Ui>`r`n")
[IO.File]::WriteAllText((Join-Path $dst "pfquest.xml"), $xml.ToString(), $utf8)

$size = (Get-ChildItem -Recurse $dst | Measure-Object -Sum Length).Sum
"pfquest\: {0} files, {1:N1} MB, pfQuest {2}, pfQuest-turtle {3}" -f (Get-ChildItem -Recurse -File $dst).Count, ($size / 1MB), $qv, $tv
