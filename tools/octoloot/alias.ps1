# Bosses whose loot is on a chest or on several NPCs: names to look up instead (joined with "+").
$ErrorActionPreference = "Stop"
$here = $(if ($env:OCTOLOOT_WORK) { $env:OCTOLOOT_WORK } else { Join-Path $env:TEMP "octoloot-work" })
$db = "C:\Games\OctoWoW\Interface\AddOns\pfUI\pfquest\db"
$cache = Join-Path $here "cache"
$ALIAS = [ordered]@{
  "MoltenCore|Majordomo Executus" = @("o:Cache of the Firelord")
  "Naxxramas|The Four Horsemen" = @("o:Four Horsemen Chest")
  "TheTempleofAhnQiraj|The Bug Family" = @("n:Lord Kri", "n:Vem", "n:Princess Yauj")
  "TheTempleofAhnQiraj|The Twin Emperors" = @("n:Emperor Vek'lor", "n:Emperor Vek'nilash")
  "Naxxramas|Master Craftsman Omarion" = @("n:Master Craftsman Omarion")
  "BlackwingLair|Ezzel Darkbrewer" = @("n:Ezzel Darkbrewer")
  "WailingCaverns|Naralex" = @("n:Naralex")
}
function ReadNames($files) {
  $map = @{}
  foreach ($f in $files) {
    $t = Get-Content -Raw (Join-Path $db $f)
    foreach ($m in [regex]::Matches($t, '\[(\d+)\]\s*=\s*"((?:[^"\\]|\\.)*)"')) {
      $k = ($m.Groups[2].Value -replace "\\'", "'").ToLower()
      if (-not $map.ContainsKey($k)) { $map[$k] = New-Object System.Collections.ArrayList }
      [void]$map[$k].Add([int]$m.Groups[1].Value)
    }
  }
  $map
}
$units = ReadNames @("enUS\units.lua", "enUS\units-turtle.lua")
$objects = ReadNames @("enUS\objects.lua", "enUS\objects-turtle.lua")
function Get-Page($kind, $id) {
  $file = Join-Path $cache "$kind-$id.html"
  if (Test-Path $file) { return Get-Content -Raw $file }
  Start-Sleep -Milliseconds 350
  try { $c = (Invoke-WebRequest -UseBasicParsing -UserAgent "Mozilla/5.0 (data builder)" -TimeoutSec 30 "https://octowow.st/db/?$kind=$id").Content } catch { $c = "" }
  Set-Content -Encoding utf8 $file $c
  $c
}
$resFile = Join-Path $here "resolved.json"
$res = @{}
(Get-Content -Raw $resFile | ConvertFrom-Json).PSObject.Properties | % { $res[$_.Name] = $_.Value }
$atlas = Get-Content -Raw (Join-Path $here "atlas.json") | ConvertFrom-Json
foreach ($key in $ALIAS.Keys) {
  $ik, $bn = $key -split "\|", 2
  $inst = $atlas | ? { $_.key -eq $ik } | select -First 1
  $boss = $inst.bosses | ? { $_.name -eq $bn } | select -First 1
  if (-not $boss) { "no boss $key"; continue }
  $refs = @()
  foreach ($a in $ALIAS[$key]) {
    $kind, $nm = $a -split ":", 2
    $ids = $(if ($kind -eq "o") { $objects[$nm.ToLower()] } else { $units[$nm.ToLower()] })
    $page = $(if ($kind -eq "o") { "object" } else { "npc" })
    foreach ($id in @($ids)) {
      if (-not $id) { continue }
      $p = Get-Page $page $id
      if ($p -and ($p.Contains("id:'drop'") -or $p.Contains("id:'contains'"))) { $refs += "${page}:$id"; break }
    }
  }
  if ($refs.Count) { $res["$ik|$($boss.id)"] = ($refs -join "+"); "$key -> $($refs -join '+')" } else { "${key}: nothing" }
}
$res | ConvertTo-Json | Set-Content -Encoding utf8 $resFile
