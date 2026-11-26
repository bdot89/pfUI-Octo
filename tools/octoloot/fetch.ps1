# Resolves Atlas boss names to NPC / object ids (pfQuest names) and caches each one's OctoWoW database page.
$ErrorActionPreference = "Stop"
$here = $(if ($env:OCTOLOOT_WORK) { $env:OCTOLOOT_WORK } else { Join-Path $env:TEMP "octoloot-work" })
$db = "C:\Games\OctoWoW\Interface\AddOns\pfUI\pfquest\db"
$cache = Join-Path $here "cache"
New-Item -ItemType Directory -Force $cache | Out-Null

function ReadNames($files) {
  $map = @{}
  foreach ($f in $files) {
    $t = Get-Content -Raw (Join-Path $db $f)
    foreach ($m in [regex]::Matches($t, '\[(\d+)\]\s*=\s*"((?:[^"\\]|\\.)*)"')) {
      $n = $m.Groups[2].Value -replace '\\"', '"' -replace "\\'", "'"
      $k = $n.ToLower()
      if (-not $map.ContainsKey($k)) { $map[$k] = New-Object System.Collections.ArrayList }
      [void]$map[$k].Add([int]$m.Groups[1].Value)
    }
  }
  $map
}
$units = ReadNames @("enUS\units.lua", "enUS\units-turtle.lua")
$objects = ReadNames @("enUS\objects.lua", "enUS\objects-turtle.lua")
$zones = ReadNames @("enUS\zones.lua", "enUS\zones-turtle.lua")
"names: units {0}, objects {1}, zones {2}" -f $units.Count, $objects.Count, $zones.Count

function Get-Page($kind, $id) {
  $file = Join-Path $cache "$kind-$id.html"
  if (Test-Path $file) { return Get-Content -Raw $file }
  Start-Sleep -Milliseconds 350
  try {
    $r = Invoke-WebRequest -UseBasicParsing -UserAgent "Mozilla/5.0 (data builder)" -TimeoutSec 30 "https://octowow.st/db/?$kind=$id"
    $c = $r.Content
  } catch { $c = "" }
  Set-Content -Encoding utf8 $file $c
  $c
}

$atlas = Get-Content -Raw (Join-Path $here "atlas.json") | ConvertFrom-Json
$res = @{}
foreach ($inst in $atlas) {
  foreach ($b in $inst.bosses) {
    $k = $b.name.ToLower()
    $hit = $null
    foreach ($id in @($units[$k])) {
      if (-not $id) { continue }
      $p = Get-Page "npc" $id
      if ($p -and $p.Contains("id:'drop'")) { $hit = "npc:$id"; break }
      if (-not $hit -and $p -and $p.Length -gt 16000) { $hit = "npc:$id" }
    }
    if (-not $hit) {
      foreach ($id in @($objects[$k])) {
        if (-not $id) { continue }
        $p = Get-Page "object" $id
        if ($p -and $p.Contains("template:'item'")) { $hit = "object:$id"; break }
      }
    }
    $res["$($inst.key)|$($b.id)"] = $hit
  }
  # the instance's zone page: bosses the site lists that Atlas does not
  $zid = @($zones[$inst.name.ToLower()])[0]
  if (-not $zid) { $zid = @($zones[($inst.name -replace ' \(.*\)$', '').ToLower()])[0] }
  if ($zid) { [void](Get-Page "zone" $zid); $res["$($inst.key)|#zone"] = "zone:$zid" }
}
$res | ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $here "resolved.json")
$found = ($res.Values | ? { $_ -and $_ -notlike "zone:*" }).Count
"resolved $found of $(($res.Keys | ? { $_ -notlike '*#zone' }).Count)"
