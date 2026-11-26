# OctoLoot builder: the sections beyond dungeons and raids - World Events, Collections, Factions, PvP Rewards,
# Crafting - from Atlas-CFM's menus and pages as FACTS (atlas-tables.txt: which items under which heading of which
# page), every item checked against the OctoWoW database (items.tsv) and every recipe against its spell lists
# (recipes.tsv). Writes modules\octoloot-pages.lua and modules\octoloot-items.lua.
#   pages:  I^key^title^kind^^0^^where^^^^icon  and  B^^page title^p^0^tokens  (the same lines as the dungeon data)
#   tokens: "@heading" | item "id" "id:pct" "id~note" | recipe "s<spell>"
#   R^spell^name^skill^made item^skill levels^reagents      S^set^quality^name^pieces      X^item^swap,swap
#   items:  N^item^quality^name^icon^item level^required level^class^subclass^slot
param([string]$PagesOut, [string]$ItemsOut, [string]$LootData)
$ErrorActionPreference = "Stop"
$here = $(if ($env:OCTOLOOT_WORK) { $env:OCTOLOOT_WORK } else { Join-Path $env:TEMP "octoloot-work" })
$enc = New-Object Text.UTF8Encoding($false)

# ---- the database's items
$items = @{}; $byName = @{}
foreach ($l in [IO.File]::ReadAllLines((Join-Path $here "items.tsv"), $enc)) {
  $f = $l -split "`t"
  if ($f.Count -lt 9) { continue }
  $items[[int]$f[0]] = $f
  $k = $f[2].ToLower()
  if (-not $byName.ContainsKey($k) -or [int]$f[1] -gt [int]$byName[$k][1]) { $byName[$k] = $f }
}
# the dungeon builder's items (drops the lists missed)
if ($LootData -and (Test-Path $LootData)) {
  foreach ($l in [IO.File]::ReadAllLines($LootData, $enc)) {
    if (-not $l.StartsWith("N^")) { continue }
    $f = $l -split "\^"
    $id = [int]$f[1]
    if (-not $items.ContainsKey($id)) { $items[$id] = @($f[1], $f[2], $f[3], $f[4], $f[5], $f[6], $f[7], $f[8], "0") }
  }
}
"$($items.Count) items known"

# ---- recipes
$recipes = @{}
foreach ($l in [IO.File]::ReadAllLines((Join-Path $here "recipes.tsv"), $enc)) {
  $f = $l -split "`t"
  if ($f.Count -ge 3) { $recipes[[int]$f[0]] = $f }
}

# ---- Atlas-CFM's facts
$menus = [ordered]@{}; $pages = @{}; $swaps = @{}; $titles = @{}
$cur = $null
foreach ($l in [IO.File]::ReadAllLines((Join-Path $here "atlas-tables.txt"), $enc)) {
  $f = $l -split "\^"
  switch ($f[0]) {
    "M" { if (-not $menus.Contains($f[1])) { $menus[$f[1]] = New-Object System.Collections.ArrayList }; [void]$menus[$f[1]].Add($f) }
    "T" { $titles[$f[1]] = $f }
    "P" { $cur = New-Object System.Collections.ArrayList; $pages[$f[1]] = $cur }
    "H" { if ($null -ne $cur) { [void]$cur.Add($f) } }
    "E" { if ($null -ne $cur) { [void]$cur.Add($f) } }
    "S" { if ($null -ne $cur) { [void]$cur.Add($f) } }
    "C" { $swaps[[int]$f[1]] = $f[2] }
  }
}
# a server tag list this server takes: none, or anything but Vanilla Plus / Classic only
function Ok($tags) {
  if (-not $tags) { return $true }
  foreach ($t in ($tags -split ",")) { if ($t -and $t -ne "VANILLA_PLUS" -and $t -ne "CLASSIC" -and $t -ne "=VANILLA_PLUS") { return $true } }
  return $false
}
$used = @{}; $usedSpells = @{}
# one page's tokens (headings and items), split at its headings when asked
function Tokens($key) {
  $list = $pages[$key]
  if (-not $list) { return @() }
  $t = New-Object System.Collections.ArrayList
  foreach ($e in $list) {
    if ($e[0] -eq "H") {
      if (Ok $e[3]) { [void]$t.Add("@" + (($e[1] -replace ',', ' ').Trim())) }
    } elseif ($e[0] -eq "E") {
      if (-not (Ok $e[4])) { continue }
      $id = [int]$e[1]
      if ($e[5] -or ($recipes.ContainsKey($id) -and -not $items.ContainsKey($id))) {
        # a recipe (crafting pages): its spell
        if ($recipes.ContainsKey($id)) { [void]$t.Add("s$id"); $usedSpells[$id] = $e[5] }
        continue
      }
      if (-not $items.ContainsKey($id)) { continue }
      $used[$id] = $true
      $tok = "$id"
      if ($e[2] -and $e[2] -match '^[\d.]+$') { $tok = "${id}:$($e[2])" }
      $note = ($e[3] -replace '[,~@^]', ' ').Trim()
      if ($note) { $tok = "$tok~$note" }
      [void]$t.Add($tok)
    }
  }
  # headings with nothing under them go
  $out = New-Object System.Collections.ArrayList
  for ($i = 0; $i -lt $t.Count; $i++) {
    if ($t[$i].StartsWith("@") -and ($i + 1 -ge $t.Count -or $t[$i + 1].StartsWith("@"))) { continue }
    [void]$out.Add($t[$i])
  }
  return , $out
}
# a page split at its headings into sub-pages: { title, tokens }
function Split-Page($key, $title) {
  $toks = Tokens $key
  $parts = New-Object System.Collections.ArrayList
  $curT = $null; $curL = New-Object System.Collections.ArrayList
  foreach ($x in $toks) {
    if ($x.StartsWith("@")) {
      if ($curL.Count) { [void]$parts.Add(@($(if ($curT) { $curT } else { $title }), ($curL -join ","))) }
      $curT = $x.Substring(1); $curL = New-Object System.Collections.ArrayList
    } else { [void]$curL.Add($x) }
  }
  if ($curL.Count) { [void]$parts.Add(@($(if ($curT) { $curT } else { $title }), ($curL -join ","))) }
  return , $parts
}

$SECTIONS = [ordered]@{ WorldEvents = "e"; Sets = "c"; Factions = "f"; PVP = "p"; Crafting = "x" }
$lines = New-Object System.Collections.ArrayList
$stat = @{}
function Clean($s) { (($s -replace '[\^\r\n]', ' ') -replace '\s+', ' ').Trim() }
foreach ($sec in $SECTIONS.Keys) {
  $kind = $SECTIONS[$sec]
  foreach ($m in $menus[$sec]) {
    if ($m.Count -lt 5 -or $m[2] -eq "-" -or -not (Ok $m[6])) { continue }
    $title = Clean $m[2]; $icon = ($m[3] -replace '^Interface\\Icons\\', '' -replace '^Interface\\\\Icons\\\\', ''); $page = $m[4]; $extra = Clean $m[5]
    $sub = New-Object System.Collections.ArrayList
    if ($titles.ContainsKey($page) -or $menus.Contains($page)) {
      # a menu of pages: each its own page (a page in a deeper menu is named after both)
      foreach ($s in $menus[$page]) {
        if ($s.Count -lt 5 -or $s[2] -eq "-" -or -not (Ok $s[6])) { continue }
        $sname = Clean $s[2]
        if ($menus.Contains($s[4])) {
          foreach ($s2 in $menus[$s[4]]) {
            if ($s2.Count -lt 5 -or $s2[2] -eq "-" -or -not (Ok $s2[6])) { continue }
            $tk = Tokens $s2[4]
            if ($tk.Count) { [void]$sub.Add(@("$sname - $(Clean $s2[2])", ($tk -join ","))) }
          }
        } else {
          $tk = Tokens $s[4]
          if ($tk.Count) { [void]$sub.Add(@($sname, ($tk -join ","))) }
        }
      }
    } else {
      foreach ($p in (Split-Page $page $title)) { [void]$sub.Add($p) }
    }
    if ($sub.Count -eq 0) { continue }
    $gkey = "$kind-$page"
    [void]$lines.Add(("I^{0}^{1}^{2}^^0^^{3}^^^^{4}" -f $gkey, $title, $kind, $extra, $icon))
    foreach ($s in $sub) {
      $name = ($s[0] -replace '\^', ' ')
      # an item list's title from its menu, keeping only the class or slot after the group's own name
      if ($name.StartsWith("$title - ")) { $name = $name.Substring($title.Length + 3) }
      [void]$lines.Add(("B^^{0}^p^0^{1}" -f $name, $s[1]))
    }
    $stat[$kind] = 1 + [int]$stat[$kind]
  }
}
"groups: " + (($stat.Keys | % { "$_=$($stat[$_])" }) -join " ")

# ---- recipes used, with the item each makes (by name)
foreach ($id in ($usedSpells.Keys | Sort-Object)) {
  $r = $recipes[$id]
  $made = ""
  $hit = $byName[$r[2].ToLower()]
  if ($hit) { $made = $hit[0]; $used[[int]$made] = $true }
  $levels = $(if ($usedSpells[$id]) { $usedSpells[$id] } else { $r[4] })
  foreach ($rg in ($r[3] -split ",")) { if ($rg -match '^(\d+)x') { if ($items.ContainsKey([int]$matches[1])) { $used[[int]$matches[1]] = $true } } }
  [void]$lines.Add(("R^{0}^{1}^{2}^{3}^{4}^{5}" -f $id, ($r[2] -replace '\^', ' '), $r[1], $made, $levels, $r[3]))
}
"$($usedSpells.Count) recipes"

# ---- item sets (the database's) and swaps (Atlas-CFM's exchange lists), for items we know
$setCount = 0
foreach ($l in [IO.File]::ReadAllLines((Join-Path $here "sets.tsv"), $enc)) {
  $f = $l -split "`t"
  if ($f.Count -lt 4) { continue }
  $pcs = @($f[3] -split "," | ? { $_ -and $items.ContainsKey([int]$_) })
  if ($pcs.Count -lt 2) { continue }
  foreach ($p in $pcs) { $used[[int]$p] = $true }
  [void]$lines.Add(("S^{0}^{1}^{2}^{3}" -f $f[0], $f[1], ($f[2] -replace '\^', ' '), ($pcs -join ",")))
  $setCount++
}
$swapCount = 0
foreach ($id in ($swaps.Keys | Sort-Object)) {
  if (-not $items.ContainsKey($id)) { continue }
  $to = @($swaps[$id] -split "," | ? { $_ -and $items.ContainsKey([int]$_) })
  if ($to.Count -eq 0) { continue }
  $used[$id] = $true
  foreach ($x in $to) { $used[[int]$x] = $true }
  [void]$lines.Add(("X^{0}^{1}" -f $id, ($to -join ",")))
  $swapCount++
}
"$setCount sets, $swapCount items with swaps"

# ---- the dungeon data's drops are items too
if ($LootData -and (Test-Path $LootData)) {
  foreach ($l in [IO.File]::ReadAllLines($LootData, $enc)) {
    if ($l.StartsWith("N^")) { $used[[int](($l -split "\^")[1])] = $true }
  }
}
$body = ($lines -join "`n")
if ($body.Contains("]]") -or $body.Contains("[[")) { throw "pages hold [[ or ]]" }
$hdr = "-- pfUI Octo :: OctoLoot's sections beyond dungeons (GENERATED by tools\Make-OctoLootData.ps1 - do not edit by hand).`n" +
  "-- World Events, Collections, Factions, PvP Rewards and Crafting: pages and their items as facts from Atlas-CFM's lists,`n" +
  "-- every item checked against the OctoWoW database, recipes with the database's reagents. Read only when a tab opens.`n" +
  "pfUI.octolootPages = [[`n"
[IO.File]::WriteAllText($PagesOut, $hdr + $body + "`n]]`n", $enc)
$nl = New-Object System.Collections.ArrayList
foreach ($id in ($used.Keys | Sort-Object)) {
  $f = $items[[int]$id]
  if (-not $f) { continue }
  [void]$nl.Add(("N^{0}^{1}^{2}^{3}^{4}^{5}^{6}^{7}^{8}" -f $f[0], $f[1], ($f[2] -replace '\^', ' '), $f[3], $f[4], $f[5], $f[6], $f[7], $f[8]))
}
$ib = ($nl -join "`n")
if ($ib.Contains("]]") -or $ib.Contains("[[")) { throw "items hold [[ or ]]" }
$ih = "-- pfUI Octo :: OctoLoot's items (GENERATED by tools\Make-OctoLootData.ps1 - do not edit by hand): name, quality, icon,`n" +
  "-- item level, required level, class, subclass and slot of every item OctoLoot shows, from the OctoWoW database.`n" +
  "-- N^item^quality^name^icon^item level^required level^class^subclass^slot - indexed the first time an item is needed.`n" +
  "pfUI.octolootItems = [[`n"
[IO.File]::WriteAllText($ItemsOut, $ih + $ib + "`n]]`n", $enc)
# the dungeon data's own item lines now live in the items file: dropped from it
if ($LootData -and (Test-Path $LootData)) {
  $keep = @([IO.File]::ReadAllLines($LootData, $enc) | ? { -not $_.StartsWith("N^") })
  [IO.File]::WriteAllText($LootData, (($keep -join "`n") + "`n"), $enc)
}
"{0} items written; pages {1:N0} KB, items {2:N0} KB" -f $nl.Count, ((Get-Item $PagesOut).Length / 1KB), ((Get-Item $ItemsOut).Length / 1KB)
