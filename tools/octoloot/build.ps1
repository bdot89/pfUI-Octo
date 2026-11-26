# Builds pfUI\modules\octoloot-data.lua from atlas.json (instance facts), resolved.json and the cached OctoWoW pages.
param([string]$Out = "C:\Games\OctoWoW\Interface\AddOns\pfUI\modules\octoloot-data.lua")
$ErrorActionPreference = "Stop"
$here = $(if ($env:OCTOLOOT_WORK) { $env:OCTOLOOT_WORK } else { Join-Path $env:TEMP "octoloot-work" })
$cache = Join-Path $here "cache"
$maps = "C:\Games\OctoWoW\Interface\AddOns\Atlas-CFM\Images\Maps"
$atlas = Get-Content -Raw (Join-Path $here "atlas.json") | ConvertFrom-Json
$resolved = @{}
(Get-Content -Raw (Join-Path $here "resolved.json") | ConvertFrom-Json).PSObject.Properties | % { $resolved[$_.Name] = $_.Value }

function Page($ref) {
  if (-not $ref) { return "" }
  $p = $ref -split ":"
  $f = Join-Path $cache ("{0}-{1}.html" -f $p[0], $p[1])
  if (Test-Path $f) { Get-Content -Raw -Encoding utf8 $f } else { "" }
}
# a listview's data rows, as text
function Rows($html, $marker) {
  $i = $html.IndexOf($marker)
  if ($i -lt 0) { return @() }
  $j = $html.IndexOf("new Listview", $i + 10)
  $k = $html.IndexOf("</script>", $i)
  if ($j -lt 0 -or ($k -ge 0 -and $k -lt $j)) { $j = $k }
  if ($j -lt 0) { $j = $html.Length }
  $s = $html.Substring($i, $j - $i)
  $d = $s.IndexOf("data:")
  if ($d -lt 0) { return @() }
  $s = $s.Substring($d)
  $parts = [regex]::Split($s, "\{name: ?'")
  if ($parts.Count -le 1) { return @() }
  $parts[1..($parts.Count - 1)]
}
function Unq($s) { ($s -replace "\\'", "'" -replace '\\"', '"' -replace '\\\\', '\').Trim() }

$names = @{}
$icons = @{}
function Num($r, $f) { $m = [regex]::Match($r, "[,{ ]$($f): ?'?(-?\d+)"); if ($m.Success) { [int]$m.Groups[1].Value } else { 0 } }
function Drops($html) {
  foreach ($m in [regex]::Matches($html, "_\[(\d+)\]=\{icon: ?'([^']+)'")) { $icons[[int]$m.Groups[1].Value] = $m.Groups[2].Value }
  $groups = [ordered]@{}
  $rows = @(Rows $html "id:'drop'"); if ($rows.Count -eq 0) { $rows = @(Rows $html "id:'contains'") }
  foreach ($r in $rows) {
    $nm = [regex]::Match($r, "^(\d)((?:[^'\\]|\\.)*)'")
    $pc = [regex]::Match($r, "percent: ?(-?[\d.]+)")
    $id = [regex]::Match($r, "[,{ ]id: ?'?(\d+)")
    if (-not ($nm.Success -and $pc.Success -and $id.Success)) { continue }
    $gr = [regex]::Match($r, "group: ?'([^']*)'")
    $g = $(if ($gr.Success) { $gr.Groups[1].Value } else { "" })
    if (-not $groups.Contains($g)) { $groups[$g] = New-Object System.Collections.ArrayList }
    # AoWoW's name digit counts down: 1 legendary, 2 epic, 3 rare, 4 uncommon, 5 common, 6 poor
    [void]$groups[$g].Add([pscustomobject]@{ id = [int]$id.Groups[1].Value; q = 6 - [int]$nm.Groups[1].Value; pct = [double]$pc.Groups[1].Value
      name = (Unq $nm.Groups[2].Value); il = (Num $r "level"); rl = (Num $r "reqlevel"); cl = (Num $r "classs"); sc = (Num $r "subclass") })
  }
  $parts = @()
  # the loose drops first: a "#" token starts a group, so loose ones after a group would join it
  $order = @(@($groups.Keys) | ? { $_ -eq "" }) + @(@($groups.Keys) | ? { $_ -ne "" })
  foreach ($g in $order) {
    $items = $groups[$g]
    # a group of many cheap rolls is the world's random drops (every mob of that level has it): left out
    if ($g -ne "" -and $items.Count -gt 30) { continue }
    # as Atlas lists them: green and better, and quest drops - never greys / whites
    $keep = @($items | ? { $_.q -ge 2 -or $_.pct -lt 0 })
    if ($keep.Count -eq 0) { continue }
    $chance = ""
    if ($g -ne "") { $m = [regex]::Match($g, "\[([\d.]+)%\]"); $chance = $(if ($m.Success) { $m.Groups[1].Value } else { "100" }) }
    $txt = @()
    if ($g -ne "") { $txt += "#$chance" }
    foreach ($it in ($keep | Sort-Object @{e = { $(if ($_.pct -lt 0) { 1000 } else { $_.pct }) }; Descending = $true }, @{e = { $_.q }; Descending = $true })) {
      $names[$it.id] = $it
      $p = [math]::Round($it.pct, 2)
      $txt += "$($it.id):$p"
    }
    $parts += ($txt -join ",")
  }
  $parts -join ","
}

# entrance pages fold into their instance
$FOLDINTO = @{ BlackfathomDeepsEnt = "BlackfathomDeeps"; BlackrockMountainEnt = "BlackrockDepths"; DireMaulEnt = "DireMaulEast";
  GnomereganEnt = "Gnomeregan"; MaraudonEnt = "Maraudon"; ScarletMonasteryEnt = "ScarletMonasteryGraveyard";
  TheDeadminesEnt = "TheDeadmines"; TheSunkenTempleEnt = "TheSunkenTemple"; UldamanEnt = "Uldaman"; WailingCavernsEnt = "WailingCaverns" }
$ENTRANCEMAP = @{ BlackrockDepths = "BlackrockMountainEnt"; BlackrockSpireLower = "BlackrockMountainEnt"; BlackrockSpireUpper = "BlackrockMountainEnt";
  MoltenCore = "BlackrockMountainEnt"; BlackwingLair = "BlackrockMountainEnt"; BlackfathomDeeps = "BlackfathomDeepsEnt";
  DireMaulEast = "DireMaulEnt"; DireMaulWest = "DireMaulEnt"; DireMaulNorth = "DireMaulEnt"; Gnomeregan = "GnomereganEnt";
  Maraudon = "MaraudonEnt"; ScarletMonasteryGraveyard = "ScarletMonasteryEnt"; ScarletMonasteryLibrary = "ScarletMonasteryEnt";
  ScarletMonasteryArmory = "ScarletMonasteryEnt"; ScarletMonasteryCathedral = "ScarletMonasteryEnt"; TheDeadmines = "TheDeadminesEnt";
  TheSunkenTemple = "TheSunkenTempleEnt"; Uldaman = "UldamanEnt"; WailingCaverns = "WailingCavernsEnt" }

# zone ids used by more than one instance: their zone page's extra bosses are not split by wing
$zoneUse = @{}
foreach ($inst in $atlas) { $z = $resolved["$($inst.key)|#zone"]; if ($z) { $zoneUse[$z] = 1 + [int]$zoneUse[$z] } }

$lines = New-Object System.Collections.ArrayList
$extra = @{}
foreach ($inst in $atlas) { if ($FOLDINTO.ContainsKey($inst.key)) { $extra[$FOLDINTO[$inst.key]] = $inst } }
$stats = @{ inst = 0; boss = 0; empty = 0 }
foreach ($inst in $atlas) {
  if ($FOLDINTO.ContainsKey($inst.key)) { continue }
  $kind = $(if ($inst.kind -eq "World") { "w" } elseif ([int]("0" + $inst.players) -ge 20) { "r" } else { "d" })
  $lv = ($inst.level -split ",\s*" | ? { $_ }) -join "-"
  $hasMap = $(if (Test-Path (Join-Path $maps "$($inst.key).blp")) { $inst.key } else { "" })
  $ent = $(if ($ENTRANCEMAP[$inst.key] -and (Test-Path (Join-Path $maps "$($ENTRANCEMAP[$inst.key]).blp"))) { $ENTRANCEMAP[$inst.key] } else { "" })
  $zref = $resolved["$($inst.key)|#zone"]
  $zid = $(if ($zref) { ($zref -split ":")[1] } else { "" })
  [void]$lines.Add(("I^{0}^{1}^{2}^{3}^{4}^{5}^{6}^{7}^{8}^{9}" -f $inst.key, $inst.name, $kind, $lv, $inst.players, $inst.acr, $inst.loc, $hasMap, $ent, $zid))
  $stats.inst++
  $seen = @{}
  $list = @($inst.bosses | % { [pscustomobject]@{ b = $_; inst = $inst.key; ent = $false } })
  if ($extra[$inst.key]) { $list += @($extra[$inst.key].bosses | % { [pscustomobject]@{ b = $_; inst = $extra[$inst.key].key; ent = $true } }) }
  foreach ($e in $list) {
    $ref = $resolved["$($e.inst)|$($e.b.id)"]
    if (-not $ref) { continue }
    if ($seen[$ref]) { continue }
    $seen[$ref] = $true
    # several NPCs / a chest for one boss (alias.ps1): their drops together, each group once
    $parts = @()
    foreach ($one in ($ref -split "\+")) {
      $seen[$one] = $true
      $d = Drops (Page $one)
      if ($d) { $parts += $d }
    }
    $loot = ($parts -join ",")
    if ($parts.Count -gt 1) {
      # split into loose drops and "#chance,..." groups; keep each loose drop and each group once
      $loose = New-Object System.Collections.ArrayList
      $groupsOut = New-Object System.Collections.ArrayList
      $have = @{}
      foreach ($part in $parts) {
        $chunks = [regex]::Split($part, ",(?=#)")
        foreach ($ch in $chunks) {
          if ($ch.StartsWith("#")) {
            if (-not $have[$ch]) { $have[$ch] = 1; [void]$groupsOut.Add($ch) }
          } else {
            foreach ($t in ($ch -split ",")) { if ($t -and -not $have[$t]) { $have[$t] = 1; [void]$loose.Add($t) } }
          }
        }
      }
      $loot = ((@($loose) + @($groupsOut)) | ? { $_ }) -join ","
    }
    $p = ($ref -split "\+")[0] -split ":"
    $pre = $e.b.prefix -replace '\^', ''
    if ($e.ent) { $pre = "E" + $pre }
    [void]$lines.Add(("B^{0}^{1}^{2}^{3}^{4}" -f $pre, $e.b.name, $p[0].Substring(0, 1), $p[1], $loot))
    $stats.boss++
    if (-not $loot) { $stats.empty++ }
  }
  # bosses the server lists in this zone that Atlas-CFM does not know
  if ($zref -and $zoneUse[$zref] -eq 1) {
    foreach ($r in (Rows (Page $zref) "template:'npc'")) {
      if ($r -notmatch "classification: ?3") { continue }
      $id = [regex]::Match($r, "[,{ ]id: ?'?(\d+)").Groups[1].Value
      $nm = Unq ([regex]::Match($r, "^((?:[^'\\]|\\.)*)'").Groups[1].Value)
      if (-not $id -or $seen["npc:$id"]) { continue }
      $file = Join-Path $cache "npc-$id.html"
      if (-not (Test-Path $file)) {
        Start-Sleep -Milliseconds 350
        try { $c = (Invoke-WebRequest -UseBasicParsing -UserAgent "Mozilla/5.0 (data builder)" -TimeoutSec 30 "https://octowow.st/db/?npc=$id").Content } catch { $c = "" }
        Set-Content -Encoding utf8 $file $c
      }
      $loot = Drops (Page "npc:$id")
      if (-not $loot) { continue }
      $seen["npc:$id"] = $true
      [void]$lines.Add(("B^^{0}^n^{1}^{2}" -f $nm, $id, $loot))
      $stats.boss++
    }
  }
}
# world map markers: entrances and world bosses (coordinates from Atlas-CFM's marker list, after ModernMapMarkers -
# facts); the Turtle-side entries where a server choice exists, never transports or battlegrounds (pfUI has its own)
$known = @{}
foreach ($l in $lines) { if ($l.StartsWith("I^")) { $known[($l -split "\^")[1]] = $true } }
$mk = Join-Path (Split-Path $maps -Parent | Split-Path -Parent) "CFMAtlas\AtlasMapMarkers.lua"
$marks = 0
if (Test-Path $mk) {
  foreach ($m in [regex]::Matches((Get-Content -Raw $mk), '\{\s*(\d),\s*"([^"]+)",\s*([\d.]+),\s*([\d.]+),\s*"(\w+)",\s*"(dungeon|raid|worldboss)",\s*([^\r\n]*)')) {
    $key = $m.Groups[5].Value
    if (-not $known[$key]) { continue }
    $rest = $m.Groups[7].Value
    $srv = [regex]::Match($rest, '\{\s*(AtlasCFM\.Server\.[\w, .]+)\}')
    if ($srv.Success -and $srv.Groups[1].Value -notmatch 'TURTLE') { continue }
    $note = ""
    if ($rest -match 'LMD\["Back"\]') { $note = "back" }
    $lb = [regex]::Match($rest, 'LB\["([^"]+)"\]')
    if ($lb.Success) { $note = $lb.Groups[1].Value }
    [void]$lines.Add(("M^{0}^{1}^{2}^{3}^{4}^{5}^{6}" -f $key, $m.Groups[1].Value, $m.Groups[2].Value, $m.Groups[3].Value, $m.Groups[4].Value, $m.Groups[6].Value.Substring(0, 1), $note))
    $marks++
  }
}
"$marks map markers"
foreach ($id in ($names.Keys | Sort-Object)) {
  $it = $names[$id]
  [void]$lines.Add(("N^{0}^{1}^{2}^{3}^{4}^{5}^{6}^{7}" -f $id, $it.q, ($it.name -replace '\^', ''), $icons[$id], $it.il, $it.rl, $it.cl, $it.sc))
}

$body = ($lines -join "`n")
if ($body.Contains("]]") -or $body.Contains("[[")) { throw "data holds [[ or ]] (Lua 5.0 long string)" }
$hdr = @"
-- pfUI Octo :: OctoLoot data (GENERATED by tools\Make-OctoLootData.ps1 - do not edit by hand).
-- Instances, bosses and drops as one text, read into tables only while the OctoLoot window is open
-- (pfUI.octoloot.Load / Unload), so it costs a few hundred KB of text and nothing in fights.
-- Drops and chances: the OctoWoW database (octowow.st/db, AoWoW), read $(Get-Date -Format "d MMM yyyy").
-- Which boss is in which instance and its number on the map: facts from Atlas-CFM's boss lists.
-- Lines: I^key^name^kind d|r|w^levels^players^short^where^map^entrance map^zone id
--        B^map number (E = at the entrance)^name^n|o (npc / object)^id^drops: "#chance" starts a group the
--          server rolls once (that % of kills), then item:percent (negative = only on the quest)
--        N^item^quality^name^icon^item level^required level^class^subclass
--        M^instance^continent^zone (English map name)^x^y (0-1)^d|r|w (dungeon / raid / world boss)^note (back | a boss)
pfUI.octolootData = [[
"@
[IO.File]::WriteAllText($Out, (($hdr + $body + "`n]]`n") -replace "`r`n", "`n"), (New-Object Text.UTF8Encoding($false)))
"{0} instances, {1} bosses ({2} without drops), {3} items, {4:N0} KB" -f $stats.inst, $stats.boss, $stats.empty, $names.Count, ((Get-Item $Out).Length / 1KB)
