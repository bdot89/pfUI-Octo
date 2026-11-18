# Rebuilds pfMapOverlayData in modules\turtle-wow.lua from the client's own WorldMapOverlay.dbc /
# WorldMapArea.dbc (the newest copy in the Data MPQs), so the map reveal draws every zone's pieces
# exactly where the game draws explored ones.
# (18 Nov 2026, Wolfahrt: Thalassian Highlands drawn in wrong / doubled pieces. A render of the
# zone from the game files showed the DBC boxes right and pfUI's old measured list wrong - it was
# made for another client's art.)
param([string]$Data = "C:\Games\OctoWoW\Data")
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$lua = Join-Path $root "modules\turtle-wow.lua"
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("pfui-overlays-" + [Guid]::NewGuid())
& (Join-Path $root "..\OctoBG\tools\MpqRead.ps1") -OutDir $tmp -Names @("DBFilesClient\WorldMapOverlay.dbc", "DBFilesClient\WorldMapArea.dbc") | Out-Null

# the copy the client uses: the MPQ loaded last (patch.MPQ, patch-2..9, then letters, as the client orders them)
function Newest([string]$file) {
  $hits = Get-ChildItem -Recurse $tmp -Filter "DBFilesClient_$file" | ForEach-Object {
    $m = $_.Directory.Name.ToLower()
    $rank = if ($m -eq "dbc") { "0" } elseif ($m -eq "patch") { "1" } else { "2" + $m.Substring(6) }
    [pscustomobject]@{ Rank = $rank; Path = $_.FullName }
  }
  ($hits | Sort-Object { [string]$_.Rank } -CaseSensitive | Select-Object -Last 1).Path
}
function Rows([string]$f, [int]$fields) {
  $b = [IO.File]::ReadAllBytes($f); $n = [BitConverter]::ToInt32($b, 4); $rs = [BitConverter]::ToInt32($b, 12); $sb = 20 + $n * $rs
  $out = @()
  for ($i = 0; $i -lt $n; $i++) {
    $r = 20 + $i * $rs; $v = @()
    for ($k = 0; $k -lt $fields; $k++) { $v += [BitConverter]::ToInt32($b, $r + 4 * $k) }
    $out += , @($v, $b, $sb)
  }
  return $out
}
function Str($b, $sb, $o) { $e = $o; while ($b[$sb + $e] -ne 0) { $e++ }; [Text.Encoding]::ASCII.GetString($b, $sb + $o, $e - $o) }

$areaFile = Newest "WorldMapArea.dbc"; $ovFile = Newest "WorldMapOverlay.dbc"
Write-Host "areas: $areaFile"; Write-Host "overlays: $ovFile"
$areas = @{}
foreach ($r in (Rows $areaFile 8)) { $areas[$r[0][0]] = Str $r[1] $r[2] $r[0][3] }
$zones = @{}
foreach ($r in (Rows $ovFile 17)) {
  $v = $r[0]; $zone = $areas[$v[1]]
  if (-not $zone -or $v[8] -eq 0) { continue }
  $name = Str $r[1] $r[2] $v[8]
  if (-not $name) { continue }
  if (-not $zones[$zone]) { $zones[$zone] = New-Object System.Collections.ArrayList }
  $e = "${name}:$($v[9]):$($v[10]):$($v[11]):$($v[12])"
  if ($v[6] -ne 0 -or $v[7] -ne 0) { $e += ":$($v[6]):$($v[7])" }
  [void]$zones[$zone].Add($e)
}
Remove-Item -Recurse -Force $tmp

$sb = New-Object Text.StringBuilder
[void]$sb.Append("  pfMapOverlayData = {`n")
foreach ($z in ($zones.Keys | Sort-Object)) {
  [void]$sb.Append("    [`"$z`"] = {`n")
  foreach ($e in $zones[$z]) { [void]$sb.Append("      `"$e`",`n") }
  [void]$sb.Append("    },`n")
}
[void]$sb.Append("  }`n")

$text = [IO.File]::ReadAllText($lua)
$start = $text.IndexOf("  pfMapOverlayData = {")
if ($start -lt 0) { throw "pfMapOverlayData not found in $lua" }
$end = $text.IndexOf("`n  }", $start)
if ($end -lt 0) { throw "end of pfMapOverlayData not found" }
$end = $text.IndexOf("`n", $end + 1) + 1
$nl = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
$new = $sb.ToString().Replace("`n", $nl)
$text = $text.Substring(0, $start) + $new + $text.Substring($end)
[IO.File]::WriteAllText($lua, $text, (New-Object Text.UTF8Encoding($false)))
Write-Host "wrote $($zones.Count) zones to $lua"
