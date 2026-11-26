# OctoLoot builder: every item the OctoWoW database lists (name, quality, icon, item level, required level, class,
# subclass, slot), read from its item lists (?items=class[.subclass[.slot]], about 500 rows a list - split further
# when a list is full). Cached page by page in the work folder; writes items.tsv there.
$ErrorActionPreference = "Stop"
$here = $(if ($env:OCTOLOOT_WORK) { $env:OCTOLOOT_WORK } else { Join-Path $env:TEMP "octoloot-work" })
$cache = Join-Path $here "cache"
New-Item -ItemType Directory -Force $cache | Out-Null
function Get-List($q) {
  $file = Join-Path $cache ("items-" + ($q -replace '\.', '_') + ".html")
  if (Test-Path $file) { return Get-Content -Raw -Encoding utf8 $file }
  Start-Sleep -Milliseconds 350
  try { $c = (Invoke-WebRequest -UseBasicParsing -UserAgent "Mozilla/5.0 (data builder)" -TimeoutSec 60 "https://octowow.st/db/?items=$q").Content } catch { $c = "" }
  Set-Content -Encoding utf8 $file $c
  $c
}
$items = @{}
function Num($r, $f) { $m = [regex]::Match($r, "[,{ ]$($f): ?'?(-?\d+)"); if ($m.Success) { [int]$m.Groups[1].Value } else { 0 } }
function Read-List($html, $slot) {
  $icons = @{}
  foreach ($m in [regex]::Matches($html, "_\[(\d+)\]=\{icon: ?'([^']+)'")) { $icons[$m.Groups[1].Value] = $m.Groups[2].Value }
  $n = 0
  foreach ($r in [regex]::Split($html, "\{name: ?'") | Select-Object -Skip 1) {
    $nm = [regex]::Match($r, "^(\d)((?:[^'\\]|\\.)*)'")
    $id = [regex]::Match($r, "[,{ ]id: ?'?(\d+)")
    if (-not ($nm.Success -and $id.Success)) { continue }
    $n++
    $key = $id.Groups[1].Value
    $name = ($nm.Groups[2].Value -replace "\\'", "'" -replace '\\"', '"').Trim()
    $items[$key] = "{0}`t{1}`t{2}`t{3}`t{4}`t{5}`t{6}`t{7}`t{8}" -f $key, (6 - [int]$nm.Groups[1].Value), $name, $icons[$key],
      (Num $r "level"), (Num $r "reqlevel"), (Num $r "classs"), (Num $r "subclass"), $slot
  }
  $n
}
$FULL = 480
$SUBS = @{ 0 = 0..8; 1 = 0..6; 2 = 0..20; 4 = 0..9; 5 = 0..0; 6 = 0..4; 7 = 0..14; 9 = 0..10; 11 = 0..3; 12 = 0..0; 13 = 0..1; 15 = 0..5 }
$req = 0
foreach ($c in ($SUBS.Keys | Sort-Object)) {
  $n = Read-List (Get-List "$c") 0; $req++
  if ($n -lt $FULL) { continue }
  foreach ($s in $SUBS[$c]) {
    $n = Read-List (Get-List "$c.$s") 0; $req++
    if ($n -lt $FULL) { continue }
    foreach ($slot in 1..28) {
      $n = Read-List (Get-List "$c.$s.$slot") $slot; $req++
    }
  }
}
$items.Values | Sort-Object { [int](($_ -split "`t")[0]) } | Set-Content -Encoding utf8 (Join-Path $here "items.tsv")
"$($items.Count) items from $req lists"
