# pfUI Octo :: build pfquest\ from the pfQuest add-ons (9 Nov 2026).
# User: "add the pf database into our addon ... no need for anything else to be
# installed other than our pfUI /db works the same as it should".
# Copies pfQuest (Shagu, MIT), pfQuest-turtle (its Turtle / OctoWoW database)
# and pfQuest-icons into pfUI\pfquest, English data only, and:
#   - puts a guard line on top of every Lua file, so when the standalone
#     pfQuest is still switched on (it loads before pfUI) our copy steps aside
#   - lets pfQuest's ADDON_LOADED handlers start on "pfUI" too
#   - gives pfQuest and pfQuest-icons their folder inside pfUI when the
#     standalone add-on is not there
#   - writes pfquest\pfquest.xml in pfQuest's own load order
# Run again after updating the pfQuest folders: .\tools\Sync-pfQuest.ps1
param(
  [string]$AddOns = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
)
$ErrorActionPreference = "Stop"
$pfui = Join-Path $AddOns "pfUI"
$src = Join-Path $AddOns "pfQuest"
$turtle = Join-Path $AddOns "pfQuest-turtle"
$icons = Join-Path $AddOns "pfQuest-icons"
$dst = Join-Path $pfui "pfquest"
foreach ($p in $src, $turtle, $icons) { if (-not (Test-Path $p)) { throw "missing $p" } }

if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
New-Item -ItemType Directory -Force $dst | Out-Null

$guard = [Text.Encoding]::ASCII.GetBytes("if pfQuestOctoSkip then return end -- pfUI Octo: the standalone pfQuest is loaded`r`n")
$utf8 = New-Object Text.UTF8Encoding($false)
$load = New-Object System.Collections.ArrayList

function Copy-Lua([string]$from, [string]$rel, [scriptblock]$patch) {
  $to = Join-Path $dst $rel
  New-Item -ItemType Directory -Force (Split-Path -Parent $to) | Out-Null
  $bytes = [IO.File]::ReadAllBytes($from)
  $start = 0
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $start = 3 }
  if ($patch) {
    $text = $utf8.GetString($bytes, $start, $bytes.Length - $start)
    $text = & $patch $text
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
function Must([string]$text, [string]$old, [string]$new) {
  if (-not $text.Contains($old)) { throw "pfQuest changed: '$old' not found" }
  return $text.Replace($old, $new)
}
$started = { param($t)
  Must $t 'if arg1 == "pfQuest" or arg1 == "pfQuest-tbc" or arg1 == "pfQuest-wotlk" then' 'if arg1 == "pfQuest" or arg1 == "pfQuest-tbc" or arg1 == "pfQuest-wotlk" or arg1 == "pfUI" then'
}

# pfQuest's load order (init\data.xml, init\enUS.xml, then init\addon.xml),
# with the Turtle add-on after it (init\data-turtle.xml, enUS-turtle.xml, then
# overwrites.lua and patchtable.lua), then the icons
foreach ($f in "init", "items", "units", "objects", "refloot", "quests-itemreq", "quests", "zones", "minimap", "areatrigger", "meta") {
  Copy-Lua (Join-Path $src "db\$f.lua") "db\$f.lua" $null
}
foreach ($f in "items", "units", "objects", "quests", "zones", "professions") {
  Copy-Lua (Join-Path $src "db\enUS\$f.lua") "db\enUS\$f.lua" $null
}
foreach ($f in "compat\pfUI", "compat\client", "overwrites", "locales") {
  Copy-Lua (Join-Path $src "$f.lua") "$f.lua" $null
}
Copy-Lua (Join-Path $src "config.lua") "config.lua" { param($t)
  $t = & $started $t
  Must $t 'pfQuestConfig.title = pfQuestConfig:CreateFontString' ("-- pfUI Octo: built into pfUI`r`nif not pfQuestConfig.path then`r`n  pfQuestConfig.path = `"Interface\\AddOns\\pfUI\\pfquest`"`r`n  pfQuestConfig.version = tostring(GetAddOnMetadata(`"pfUI`", `"X-pfQuest-Version`") or `"7.0.1`")`r`nend`r`n`r`npfQuestConfig.title = pfQuestConfig:CreateFontString")
}
foreach ($f in "slashcmd", "database", "icons", "map") { Copy-Lua (Join-Path $src "$f.lua") "$f.lua" $null }
Copy-Lua (Join-Path $src "quest.lua") "quest.lua" $started
foreach ($f in "route", "tracker", "browser", "journal", "menu") { Copy-Lua (Join-Path $src "$f.lua") "$f.lua" $null }
# built in, pfQuest's ADDON_LOADED never fires, so its version stays nil and another
# player's VERSION message compared against it (9 Nov 2026: endless chat errors)
Copy-Lua (Join-Path $src "updatenotify.lua") "updatenotify.lua" { param($t)
  Must $t 'if remote > version then' 'if version and remote > version then'
}

foreach ($f in "items", "units", "objects", "refloot", "quests-itemreq", "quests", "zones", "minimap", "areatrigger", "meta") {
  Copy-Lua (Join-Path $turtle "db\$f-turtle.lua") "db\$f-turtle.lua" $null
}
foreach ($f in "items", "units", "objects", "quests", "zones", "professions") {
  Copy-Lua (Join-Path $turtle "db\enUS\$f-turtle.lua") "db\enUS\$f-turtle.lua" $null
}
Copy-Lua (Join-Path $turtle "overwrites.lua") "turtle-overwrites.lua" $null
Copy-Lua (Join-Path $turtle "patchtable.lua") "turtle-patchtable.lua" $null

Copy-Lua (Join-Path $icons "pfQuest-icons.lua") "icons-nodes.lua" { param($t)
  Must $t "-- get the current localization from spawn id" "-- pfUI Octo: built into pfUI`r`naddonpath = addonpath or `"Interface\\AddOns\\pfUI\\pfquest\\icons`"`r`n`r`n-- get the current localization from spawn id"
}

# art, icons, licences
Copy-Item -Recurse (Join-Path $src "img") (Join-Path $dst "img")
New-Item -ItemType Directory -Force (Join-Path $dst "icons") | Out-Null
foreach ($d in "herbs", "mines", "chests") { Copy-Item -Recurse (Join-Path $icons $d) (Join-Path $dst "icons\$d") }
Copy-Item (Join-Path $src "LICENSE") (Join-Path $dst "LICENSE-pfQuest")
Copy-Item (Join-Path $turtle "LICENSE") (Join-Path $dst "LICENSE-pfQuest-turtle")
Copy-Item (Join-Path $icons "LICENSE") (Join-Path $dst "LICENSE-pfQuest-icons")

# where it came from
$rev = { param($p) try { (git -C $p log --oneline -1 2>$null) } catch { "" } }
$readme = @(
  "pfQuest built into pfUI Octo - made by tools\Sync-pfQuest.ps1, do not edit by hand.",
  "",
  "pfQuest, pfQuest-turtle and pfQuest-icons are by Shagu and contributors (MIT, see the LICENSE files).",
  "English data only. When the standalone pfQuest add-on is switched on it loads first and this copy steps aside.",
  "",
  ("pfQuest:        " + (& $rev $src)),
  ("pfQuest-turtle: " + (& $rev $turtle)),
  ("pfQuest-icons:  " + (& $rev $icons))
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
"pfquest\: {0} files, {1:N1} MB" -f (Get-ChildItem -Recurse -File $dst).Count, ($size / 1MB)
