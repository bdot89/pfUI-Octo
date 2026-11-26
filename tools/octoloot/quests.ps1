# OctoLoot builder: each instance's quests (26 Nov 2026) as FACTS from Atlas-CFM's quest data (which quest ids belong to
# which instance for which side, and the item ids each rewards; "Pick One" = a choice). Its notes and descriptions are
# its own writing and are not taken: names, objectives, givers, places and chains come from pfQuest's database at run time.
# Writes quests.tsv in the work folder: instance key, side (A / H), quest id, pick (1 = choose one), reward ids.
$ErrorActionPreference = "Stop"
$here = $(if ($env:OCTOLOOT_WORK) { $env:OCTOLOOT_WORK } else { Join-Path $env:TEMP "octoloot-work" })
$src = Join-Path $PSScriptRoot "..\..\..\Atlas-CFM\Locales\enUS\QuestData.lua"
$t = [IO.File]::ReadAllText((Resolve-Path $src))
$out = New-Object System.Collections.ArrayList
$rx = [regex]'kQuestInstanceData\.(\w+)\.(Alliance|Horde)\[(\d+)\]\s*=\s*\{'
$ms = $rx.Matches($t)
for ($i = 0; $i -lt $ms.Count; $i++) {
  $m = $ms[$i]
  $end = $(if ($i + 1 -lt $ms.Count) { $ms[$i + 1].Index } else { $t.Length })
  $blk = $t.Substring($m.Index, $end - $m.Index)
  $id = [regex]::Match($blk, '\bId\s*=\s*(\d+)')
  if (-not $id.Success) { continue }
  $pick = $(if ($blk -match 'Text\s*=\s*"[^"]*Pick One') { 1 } else { 0 })
  $rw = ""
  $r = [regex]::Match($blk, 'Rewards\s*=\s*\{([\s\S]*?)\n\s*\}')
  if ($r.Success) { $rw = (([regex]::Matches($r.Groups[1].Value, '\bid\s*=\s*(\d+)') | % { $_.Groups[1].Value }) -join ",") }
  [void]$out.Add(("{0}`t{1}`t{2}`t{3}`t{4}" -f $m.Groups[1].Value, $m.Groups[2].Value.Substring(0, 1), $id.Groups[1].Value, $pick, $rw))
}
$out | Set-Content -Encoding utf8 (Join-Path $here "quests.tsv")
"$($out.Count) instance quests"
