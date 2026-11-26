# pfUI Octo :: makes OctoLoot's data (26 Nov 2026): modules\octoloot-data.lua (dungeons, raids, world bosses, map
# markers), modules\octoloot-pages.lua (events, collections, factions, PvP, crafting, sets, swaps, recipes) and
# modules\octoloot-items.lua (every item shown).
#   1. octoloot\parse-atlas.ps1  instance facts from Atlas-CFM's boss lists (names, levels, size, map numbers)
#   2. octoloot\fetch.ps1        each boss -> NPC / object id (pfQuest's names), its OctoWoW database page cached
#   3. octoloot\alias.ps1        bosses whose loot sits on a chest or on several NPCs
#   4. octoloot\build.ps1        the drops (green and better, quest drops), groups, icons, map markers
#   5. octoloot\dump-atlas.lua   (on DmorphOcto's LuaHost) Atlas-CFM's section menus / pages / exchange lists as facts
#   6. octoloot\items.ps1        every item of the OctoWoW database's item lists (name, quality, icon, levels, slot)
#   7. octoloot\recipes.ps1      every profession's recipes (reagents, skill colours) and every item set
#   8. octoloot\pages.ps1        the sections, items checked against the database; the items file
# Atlas-CFM is GPL-2: only facts are taken (which boss / item where), none of its code or art. The work folder (page
# cache) is $env:OCTOLOOT_WORK or %TEMP%\octoloot-work: delete it to read the server's database fresh (350 ms a page).
#   powershell -ExecutionPolicy Bypass -File tools\Make-OctoLootData.ps1
$ErrorActionPreference = "Stop"
$work = $(if ($env:OCTOLOOT_WORK) { $env:OCTOLOOT_WORK } else { Join-Path $env:TEMP "octoloot-work" })
New-Item -ItemType Directory -Force $work | Out-Null
$env:OCTOLOOT_WORK = $work
$dir = Join-Path $PSScriptRoot "octoloot"
$mods = Resolve-Path (Join-Path $PSScriptRoot "..\modules")
$atlasData = Resolve-Path (Join-Path $PSScriptRoot "..\..\Atlas-CFM\CFMLoot\Data")
$lua = Resolve-Path (Join-Path $PSScriptRoot "..\..\DmorphOcto\tools\LuaHost\bin\LuaHost.exe")
& (Join-Path $dir "parse-atlas.ps1")
& (Join-Path $dir "fetch.ps1")
& (Join-Path $dir "alias.ps1")
& (Join-Path $dir "build.ps1") -Out (Join-Path $mods "octoloot-data.lua")
$run = Join-Path $work "dump-run.lua"
$fwd = { param($p) ($p -replace '\\', '/') }
[IO.File]::WriteAllText($run, ("OCTOLOOT_DATA=[[{0}]] OCTOLOOT_OUT=[[{1}/atlas-tables.txt]] dofile([[{2}]])" -f (& $fwd $atlasData), (& $fwd $work), (& $fwd (Join-Path $dir "dump-atlas.lua"))))
# (Atlas-CFM's world / PvP / instance files stop at their own helper calls after their data is read: those lines are expected)
$ErrorActionPreference = "Continue"
& $lua $run 2>$null
if ($LASTEXITCODE -ne 0) { throw "dump-atlas.lua failed" }
$ErrorActionPreference = "Stop"
& (Join-Path $dir "items.ps1")
& (Join-Path $dir "recipes.ps1")
& (Join-Path $dir "quests.ps1")
& (Join-Path $dir "pages.ps1") -PagesOut (Join-Path $mods "octoloot-pages.lua") -ItemsOut (Join-Path $mods "octoloot-items.lua") -LootData (Join-Path $mods "octoloot-data.lua")
