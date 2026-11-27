<#
  pfUI Octo :: Sync-Chronicle.ps1 (26 Nov 2026)
  Fetches the last week of uploaded raids from Chronicle's public developer API
  (https://octo.chronicleclassic.com/developers/api, no key: 60 requests a minute per PC) and writes the
  community boards OctoBoards shows on its Community tab: modules\octoboards-data.lua (then /reload in game).

  Per raid ONE request (its boss kills: /raidlogs/instances/{id}/ranking-records), cached in
  %LOCALAPPDATA%\pfUI-Octo\chronicle, so a second run only fetches new raids. The same raid uploaded by
  several people is counted once (same player, boss and kill minute).

    powershell -ExecutionPolicy Bypass -File tools\Sync-Chronicle.ps1            # last 7 days, all realms
    powershell -ExecutionPolicy Bypass -File tools\Sync-Chronicle.ps1 -Days 3
#>
param(
  [int]$Days = 7,
  [string]$Out = (Join-Path $PSScriptRoot "..\modules\octoboards-data.lua"),
  [string]$Cache = (Join-Path $env:LOCALAPPDATA "pfUI-Octo\chronicle"),
  [int]$MaxRaids = 2000
)
$ErrorActionPreference = "Stop"
$Base = "https://octo.chronicleclassic.com/api/external/v1"
$Headers = @{ "User-Agent" = "pfUI-Octo-OctoBoards/1.0 (+https://github.com/bdot89/pfUI)" }
if (-not (Test-Path $Cache)) { New-Item -ItemType Directory -Path $Cache -Force | Out-Null }
# (26 Nov 2026, user: "make sure data doesn't pile up") raids older than the window + a week, and weekly averages older
# than 5 weeks, leave the cache
$keepRaids = [DateTime]::UtcNow.AddDays(-($Days + 7))
Get-ChildItem $Cache -Filter "*.json" | Where-Object {
  ($_.Name -like "avg-*" -and $_.LastWriteTimeUtc -lt [DateTime]::UtcNow.AddDays(-35)) -or
  ($_.Name -notlike "avg-*" -and $_.LastWriteTimeUtc -lt $keepRaids)
} | Remove-Item -Force -ErrorAction SilentlyContinue
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$script:calls = 0
$script:lastCall = [DateTime]::MinValue
function Get-Api([string]$path) {
  # one request a second at most (the bucket refills one a second); 429 = wait as told
  for ($try = 1; $try -le 5; $try++) {
    $wait = 1050 - ([DateTime]::UtcNow - $script:lastCall).TotalMilliseconds
    if ($wait -gt 0) { Start-Sleep -Milliseconds ([int]$wait) }
    $script:lastCall = [DateTime]::UtcNow
    $script:calls++
    try {
      $r = Invoke-WebRequest -Uri ($Base + $path) -Headers $Headers -UseBasicParsing -TimeoutSec 60
      $bytes = $r.RawContentStream.ToArray()
      return ([Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json)
    } catch {
      $resp = $_.Exception.Response
      if ($resp -and [int]$resp.StatusCode -eq 429) {
        $ra = 5
        try { $ra = [int]$resp.Headers["Retry-After"] } catch { }
        Write-Host ("  rate limit: waiting {0} s" -f $ra)
        Start-Sleep -Seconds ([Math]::Max(1, $ra))
        continue
      }
      if ($resp -and [int]$resp.StatusCode -eq 404) { return $null }
      if ($try -ge 3) { throw }
      Start-Sleep -Seconds 3
    }
  }
  return $null
}

# ---------------------------------------------------------------- the raids of the last $Days days
$since = [DateTime]::UtcNow.AddDays(-$Days)
$sinceText = $since.ToString("yyyy-MM-ddT00:00:00Z")
Write-Host ("Chronicle: raids since {0} ..." -f $sinceText)
$raids = New-Object System.Collections.ArrayList
$page = 1
while ($true) {
  $j = Get-Api ("/raidlogs/recent?after_date={0}&page_size=50&page={1}" -f $sinceText, $page)
  if (-not $j) { break }
  foreach ($a in @($j.activities)) { if ($a) { [void]$raids.Add($a) } }
  if (-not $j.pagination.has_more -or $raids.Count -ge $MaxRaids) { break }
  $page++
}
Write-Host ("  {0} uploads" -f $raids.Count)

# the same raid uploaded twice: one guild, one zone, starting the same minute
$seenRaid = @{}
$unique = New-Object System.Collections.ArrayList
foreach ($r in $raids) {
  $k = "{0}|{1}|{2}|{3}" -f $r.realm.name, $r.guild.name, $r.name, ([string]$r.started_at).Substring(0, [Math]::Min(16, ([string]$r.started_at).Length))
  if (-not $seenRaid.ContainsKey($k)) { $seenRaid[$k] = $true; [void]$unique.Add($r) }
}
Write-Host ("  {0} different raids" -f $unique.Count)

# ---------------------------------------------------------------- each raid's boss kills (cached)
$records = New-Object System.Collections.ArrayList
$n = 0; $fetched = 0
foreach ($r in $unique) {
  $n++
  $file = Join-Path $Cache ($r.id + ".json")
  $rec = $null
  # (27 Nov 2026) a cached raid from before hps / duration were kept is read again once
  if ((Test-Path $file) -and ((Get-Content $file -TotalCount 1 -Encoding UTF8) -match '"hps"')) {
    $rec = Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json
  } else {
    $rec = Get-Api ("/raidlogs/instances/{0}/ranking-records" -f $r.id)
    if ($null -eq $rec) { $rec = @() }
    # keep only what the boards use (the cache stays small)
    $slim = @($rec | Where-Object { $_ } | ForEach-Object {
      [pscustomobject]@{ e = $_.encounter_name; g = $_.player_guid; n = $_.player_name; c = $_.player_class; s = $_.player_spec
        ro = $_.player_role; dm = $_.damage_done; hl = $_.healing_done; ab = $_.absorbed_done; al = $_.alive_percentage
        de = $_.player_deaths; dps = $_.dps; hps = $_.hps; du = $_.duration_secs; t = $_.killed_at
        dp = $(if ($_.dps_parse) { $_.dps_parse.display_score } else { $null })
        hp = $(if ($_.hps_parse) { $_.hps_parse.display_score } else { $null }) }
    })
    ConvertTo-Json -InputObject $slim -Depth 3 -Compress | Set-Content -Path $file -Encoding UTF8
    $rec = $slim
    $fetched++
    if ($fetched % 25 -eq 0) { Write-Host ("  {0} / {1} raids read ({2} new)" -f $n, $unique.Count, $fetched) }
  }
  foreach ($x in @($rec)) { if ($x) { [void]$records.Add(@{ raid = $r; x = $x }) } }
}
Write-Host ("  {0} boss kill rows ({1} raids fetched now, the rest from the cache)" -f $records.Count, $fetched)

# ---------------------------------------------------------------- the boards
$realms = @($unique | ForEach-Object { $_.realm.name } | Sort-Object -Unique)
function New-Scopes { $s = @{ "all" = @{} }; foreach ($rn in $realms) { $s[$rn] = @{} }; return $s }
function Add-To($scopes, [string]$realm, [string]$key, $row, [string]$field, [double]$v) {
  foreach ($sc in @("all", $realm)) {
    if (-not $scopes.ContainsKey($sc)) { continue }
    $t = $scopes[$sc]
    if (-not $t.ContainsKey($key)) { $t[$key] = @{ row = $row; v = 0.0; n = 0; x = 0.0 } }
    $t[$key].v += $v
    $t[$key].n += 1
  }
}

# players: one row per player per boss kill (duplicates of the same kill counted once)
# (PowerShell names ignore case: $p and $P are ONE variable - the tables are $PL / $GU / $Boards)
$PL = @{}
$seenKill = @{}
$bossDeaths = New-Scopes
foreach ($item in $records) {
  $x = $item.x; $r = $item.raid
  if (-not $x.g -or $x.e -eq "Trash") { continue }
  $realm = $r.realm.name
  $kk = "{0}|{1}|{2}" -f $x.g, $x.e, ([string]$x.t).Substring(0, [Math]::Min(16, ([string]$x.t).Length))
  if ($seenKill.ContainsKey($kk)) { continue }
  $seenKill[$kk] = $true
  $pk = $realm + "/" + $x.n
  if (-not $PL.ContainsKey($pk)) {
    $PL[$pk] = @{ n = $x.n; c = $x.c; g = $r.guild.name; r = $realm; kills = 0; bestDps = 0.0; bestDpsOn = ""; bestHps = 0.0; bestHpsOn = ""; dsum = 0.0; dn = 0; hsum = 0.0; hn = 0; perfect = 0
      alive = 0; ab = 0.0; hl = 0.0; dm = 0.0; de = 0; raids = @{}; role = $x.ro }
  }
  $p = $PL[$pk]
  $p.kills++
  if ($null -ne $x.dp -and $x.ro -ne "heal") { $p.dsum += [double]$x.dp; $p.dn++ ; if ([double]$x.dp -ge 99) { $p.perfect++ } }
  if ($null -ne $x.hp -and $x.ro -eq "heal") { $p.hsum += [double]$x.hp; $p.hn++ ; if ([double]$x.hp -ge 99) { $p.perfect++ } }
  if ([double]$x.al -ge 100) { $p.alive++ }
  $p.ab += [double]$x.ab; $p.hl += [double]$x.hl; $p.dm += [double]$x.dm; $p.de += [int]$x.de
  $p.raids[$r.id] = $true
  if ([double]$x.dps -gt $p.bestDps -and $x.ro -ne "heal") { $p.bestDps = [double]$x.dps; $p.bestDpsOn = $x.e }
  if ([double]$x.hps -gt $p.bestHps) { $p.bestHps = [double]$x.hps; $p.bestHpsOn = $x.e }
  if ($x.ro) { $p.role = $x.ro }
  if ([int]$x.de -gt 0) { Add-To $bossDeaths $realm $x.e @{ n = $x.e } "de" ([int]$x.de) }
}
$players = @($PL.Values)
Write-Host ("  {0} players" -f $players.Count)

function Top($list, [scriptblock]$value, [scriptblock]$extra, [int]$take = 10) {
  # -> per scope: rows { n, c, g, r, v, x } best first
  $out = @{}
  foreach ($sc in @("all") + $realms) {
    $rows = @($list | Where-Object { $sc -eq "all" -or $_.r -eq $sc } | ForEach-Object {
      $v = & $value $_
      if ($null -ne $v -and $v -gt 0) { [pscustomobject]@{ n = $_.n; c = $_.c; g = $_.g; r = $_.r; v = [double]$v; x = $(if ($extra) { & $extra $_ } else { "" }) } }
    } | Sort-Object -Property v -Descending | Select-Object -First $take)
    $out[$sc] = $rows
  }
  return $out
}
$Boards = [ordered]@{}
$avgD = { param($p) if ($p.dn -ge 4) { [Math]::Round($p.dsum / $p.dn, 1) } }
$avgH = { param($p) if ($p.hn -ge 4) { [Math]::Round($p.hsum / $p.hn, 1) } }
$Boards["topparse"] = Top $players { param($p) $av = & $avgD $p; $hv = & $avgH $p; if ($av -or $hv) { [Math]::Max([double]$av, [double]$hv) } } { param($p) "{0} boss kills" -f $p.kills }
$Boards["perfect"] = Top $players { param($p) $p.perfect } { param($p) "of {0} kills" -f $p.kills }
$Boards["alive"] = Top $players { param($p) $p.alive } { param($p) "of {0} kills" -f $p.kills }
$Boards["absorbs"] = Top $players { param($p) $p.ab } $null
$Boards["pacifist"] = Top @($players | Where-Object { $_.role -eq "heal" -and $_.dm -lt $_.hl * 0.02 }) { param($p) $p.hl } { param($p) "{0:N0} damage" -f $p.dm }
$Boards["floor"] = Top $players { param($p) $p.de } { param($p) "in {0} kills" -f $p.kills }
$Boards["glass"] = Top @($players | Where-Object { (& $avgD $_) -ge 75 }) { param($p) $p.de } { param($p) "avg parse {0}" -f (& $avgD $p) }
$Boards["loyal"] = Top $players { param($p) $p.raids.Count } { param($p) "{0} boss kills" -f $p.kills }
# (27 Nov 2026, user: "First page should be top DPS this week etc top parser") best single boss kill this week
$Boards["topdps"] = Top $players { param($p) [Math]::Round($p.bestDps) } { param($p) "on " + $p.bestDpsOn }
$Boards["tophps"] = Top $players { param($p) [Math]::Round($p.bestHps) } { param($p) "on " + $p.bestHpsOn }
# best of each class
$classTop = @{}
foreach ($sc in @("all") + $realms) {
  $rows = @()
  foreach ($cls in @($players | ForEach-Object { $_.c } | Sort-Object -Unique)) {
    $best = $players | Where-Object { $_.c -eq $cls -and ($sc -eq "all" -or $_.r -eq $sc) } | ForEach-Object {
      $av = & $avgD $_; $hv = & $avgH $_; $v = [Math]::Max([double]$av, [double]$hv)
      if ($v -gt 0) { [pscustomobject]@{ n = $_.n; c = $_.c; g = $_.g; r = $_.r; v = $v; x = ("{0} boss kills" -f $_.kills) } }
    } | Sort-Object -Property v -Descending | Select-Object -First 1
    if ($best) { $rows += $best }
  }
  $classTop[$sc] = @($rows | Sort-Object -Property v -Descending)
}
$Boards["classtop"] = $classTop

# raids and guilds
$G = @{}
$raidRows = @()
foreach ($r in $unique) {
  $gk = $r.realm.name + "/" + $r.guild.name
  if (-not $r.guild.name) { continue }
  if (-not $G.ContainsKey($gk)) { $G[$gk] = @{ n = $r.guild.name; c = ""; g = ""; r = $r.realm.name; kills = 0; open = 0; raids = 0 } }
  $G[$gk].kills += [int]$r.boss_kills
  $G[$gk].open += [Math]::Max(0, [int]$r.boss_count - [int]$r.boss_kills)
  $G[$gk].raids++
  $st = [DateTime]::Parse([string]$r.started_at).ToUniversalTime()
  $en = $(if ($r.ended_at) { [DateTime]::Parse([string]$r.ended_at).ToUniversalTime() } else { $st })
  $late = ($st.Hour + $(if ($st.Hour -lt 6) { 24 } else { 0 })) * 60 + $st.Minute
  $raidRows += [pscustomobject]@{ n = $r.guild.name; c = ""; g = $r.name; r = $r.realm.name; players = [int]$r.player_count
    mins = [Math]::Round(($en - $st).TotalMinutes); late = $late; start = $st.ToString("HH:mm") }
}
$guilds = @($G.Values)
$Boards["guildweek"] = Top $guilds { param($g) $g.kills } { param($g) "{0} raids" -f $g.raids }
$Boards["unfinished"] = Top $guilds { param($g) $g.open } { param($g) "{0} bosses killed" -f $g.kills }
$Boards["turnout"] = Top $raidRows { param($x) $x.players } { param($x) $x.g }
$Boards["marathon"] = Top $raidRows { param($x) $x.mins } { param($x) $x.g }
$Boards["nightowl"] = Top @($raidRows | Where-Object { $_.late -ge 21 * 60 }) { param($x) $x.late } { param($x) "{0}, started {1} server time" -f $x.g, $x.start }
# the realms against each other
$war = @()
foreach ($rn in $realms) {
  $k = 0
  foreach ($gg in $guilds) { if ($gg.r -eq $rn) { $k += $gg.kills } }
  $war += [pscustomobject]@{ n = $rn; c = ""; g = ""; r = $rn; v = [double]$k; x = ("{0} raids" -f @($unique | Where-Object { $_.realm.name -eq $rn }).Count) }
}
$Boards["realmwar"] = @{ "all" = @($war | Sort-Object -Property v -Descending) }
# (27 Nov 2026) the fastest full clear of each raid this week: Chronicle's own speedrun list (one request a raid)
$speed = @()
foreach ($inst in @("Molten Core", "Blackwing Lair", "Onyxia's Lair", "Zul'Gurub", "Ruins of Ahn'Qiraj", "Temple of Ahn'Qiraj", "Naxxramas", "Lower Tower of Karazhan")) {
  $j = Get-Api ("/leaderboards/speedruns?instance_name={0}&timing=full&since_days={1}&page_size=5" -f [Uri]::EscapeDataString($inst), $Days)
  $best = @($j.entries | Where-Object { $_ -and $_.canonical }) | Sort-Object { [double]$_.canonical.duration_ms } | Select-Object -First 1
  if ($best) {
    $speed += [pscustomobject]@{ n = $inst; c = ""; g = $best.guild_name; r = $best.realm_name
      v = [Math]::Round([double]$best.canonical.duration_ms / 60000, 1); x = ("{0} players" -f $best.player_count) }
  }
}
$Boards["speed"] = @{ "all" = @($speed) }
foreach ($rn in $realms) { $Boards["speed"][$rn] = @($speed | Where-Object { $_.r -eq $rn }) }
# the boss that killed the most raiders
$bb = @{}
foreach ($sc in $bossDeaths.Keys) {
  $bb[$sc] = @($bossDeaths[$sc].Values | ForEach-Object { [pscustomobject]@{ n = $_.row.n; c = ""; g = ""; r = ""; v = $_.v; x = "" } } |
    Sort-Object -Property v -Descending | Select-Object -First 10)
}
$Boards["bossbully"] = $bb
# rising star: this week's average parse against last week's (kept from the previous run)
$weekFile = Join-Path $Cache ("avg-" + [DateTime]::UtcNow.ToString("yyyy-MM-dd") + ".json")
$avgNow = @{}
foreach ($p in $players) { $av = & $avgD $p; $hv = & $avgH $p; $v = [Math]::Max([double]$av, [double]$hv); if ($v -gt 0) { $avgNow[$p.r + "/" + $p.n] = $v } }
ConvertTo-Json -InputObject $avgNow -Compress | Set-Content -Path $weekFile -Encoding UTF8
$old = Get-ChildItem $Cache -Filter "avg-*.json" | Where-Object { $_.LastWriteTimeUtc -lt [DateTime]::UtcNow.AddDays(-6) } | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
$rise = @()
if ($old) {
  $prev = Get-Content $old.FullName -Raw | ConvertFrom-Json
  foreach ($p in $players) {
    $k = $p.r + "/" + $p.n
    $was = $prev.$k
    if ($was -and $avgNow.ContainsKey($k)) { $p.rise = $avgNow[$k] - [double]$was } else { $p.rise = 0 }
  }
  $Boards["rising"] = Top $players { param($p) $p.rise } { param($p) "now {0}" -f $avgNow[$p.r + "/" + $p.n] }
}

# ---------------------------------------------------------------- the Lua file
function Q([string]$s) { if ($null -eq $s) { $s = "" }; return '"' + ($s -replace '\\', '\\' -replace '"', '\"' -replace "`r|`n", " ") + '"' }
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("-- GENERATED by tools\Sync-Chronicle.ps1 from Chronicle's public API (octo.chronicleclassic.com) - do not edit")
[void]$sb.AppendLine("pfUI.boardsChronicle = {")
[void]$sb.AppendLine("  updated = " + (Q ([DateTime]::Now.ToString("d MMM yyyy HH:mm"))) + ", days = $Days, raids = $($unique.Count), players = $($players.Count),")
[void]$sb.AppendLine("  realms = { " + (($realms | ForEach-Object { Q $_ }) -join ", ") + " },")
[void]$sb.AppendLine("  boards = {")
foreach ($key in $Boards.Keys) {
  [void]$sb.AppendLine("    " + $key + " = {")
  $scopes = $Boards[$key]
  foreach ($sc in $scopes.Keys) {
    [void]$sb.Append("      [" + (Q $sc) + "] = { ")
    foreach ($row in @($scopes[$sc])) {
      if (-not $row) { continue }
      $v = [Math]::Round([double]$row.v, 1)
      [void]$sb.Append("{ " + (Q $row.n) + ", " + (Q $row.c) + ", " + (Q $row.g) + ", " + (Q $row.r) + ", " +
        $v.ToString([Globalization.CultureInfo]::InvariantCulture) + ", " + (Q ([string]$row.x)) + " }, ")
    }
    [void]$sb.AppendLine("},")
  }
  [void]$sb.AppendLine("    },")
}
[void]$sb.AppendLine("  },")
[void]$sb.AppendLine("}")
$utf8 = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Resolve-Path (Split-Path $Out)).Path + "\" + (Split-Path $Out -Leaf), $sb.ToString(), $utf8)
Write-Host ("Done: {0} raids, {1} players, {2} requests. Wrote {3} - /reload in game." -f $unique.Count, $players.Count, $script:calls, $Out)
