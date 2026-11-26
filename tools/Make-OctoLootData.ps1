# pfUI Octo :: makes modules\octoloot-data.lua (OctoLoot, 26 Nov 2026).
#   1. octoloot\parse-atlas.ps1  instance facts from Atlas-CFM's boss lists (names, levels, size, map numbers) - facts
#                                only, nothing of its code or art goes into pfUI (it is GPL-2)
#   2. octoloot\fetch.ps1        each boss name -> NPC / object id (pfQuest's names), its page on the OctoWoW database
#                                (https://octowow.st/db, AoWoW) cached; 350 ms between requests
#   3. octoloot\alias.ps1        bosses whose loot sits on a chest or on several NPCs
#   4. octoloot\build.ps1        the drops (green and better, quest drops), groups, icons -> modules\octoloot-data.lua
# Needs ..\Atlas-CFM next to pfUI. The work folder (cache of pages) is $env:OCTOLOOT_WORK or %TEMP%\octoloot-work:
# delete it to read the server's database fresh.
#   powershell -ExecutionPolicy Bypass -File tools\Make-OctoLootData.ps1
$ErrorActionPreference = "Stop"
$work = $(if ($env:OCTOLOOT_WORK) { $env:OCTOLOOT_WORK } else { Join-Path $env:TEMP "octoloot-work" })
New-Item -ItemType Directory -Force $work | Out-Null
$env:OCTOLOOT_WORK = $work
$dir = Join-Path $PSScriptRoot "octoloot"
& (Join-Path $dir "parse-atlas.ps1")
& (Join-Path $dir "fetch.ps1")
& (Join-Path $dir "alias.ps1")
& (Join-Path $dir "build.ps1") -Out (Join-Path $PSScriptRoot "..\modules\octoloot-data.lua")
