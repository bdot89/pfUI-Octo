<#
  pfUI Octo :: Sync-OctoShare.ps1 (27 Nov 2026)
  Reads the OctoShare collector log out of a character account's pfUI SavedVariables and appends it to CSV files a
  database can load (SQLite .import or Postgres COPY). Append-only with cross-run dedupe, so running it repeatedly
  (a scheduled task, say) never doubles a row even though the in-game log is a ring buffer that overlaps between runs.

  Turn the collector on in game first: Quality of Life > Data sharing > "Collect on this character".

    powershell -ExecutionPolicy Bypass -File tools\Sync-OctoShare.ps1
    powershell -ExecutionPolicy Bypass -File tools\Sync-OctoShare.ps1 -SV "C:\Games\OctoWoW\WTF\Account\ERRORBOT\SavedVariables\pfUI.lua"

  Output (default %LOCALAPPDATA%\pfUI-Octo\octoshare):
    prices.csv   realm,faction,day,itemkey,copper,sender,ts     (from the pfAP auction-price feed)
    bgq.csv      map,faction,seconds,sender,ts                  (battleground queue waits, pfOS bgq)
    bgr.csv      map,faction,win,sender,ts                      (battleground results 1/0, pfOS bgr)
    pop.csv      zone,faction,sender,ts                         (population pings, pfOS pop)
    events.csv   ts,kind,sender,channel,payload                 (every feed, raw - nothing is lost)
    seen.txt     hashes already ingested (the dedupe state)
  Load, e.g.:  sqlite3 boards.db ".mode csv" ".import prices.csv prices"
#>
param(
  [string]$SV = "",
  [string]$Out = (Join-Path $env:LOCALAPPDATA "pfUI-Octo\octoshare"),
  [string]$WTF = "C:\Games\OctoWoW\WTF\Account"
)
$ErrorActionPreference = "Stop"
if (-not (Test-Path $Out)) { New-Item -ItemType Directory -Path $Out -Force | Out-Null }

# which SavedVariables file(s) to read: the one given, else every account file that actually holds a collector log
$files = @()
if ($SV -ne "") {
  if (-not (Test-Path $SV)) { throw "SavedVariables file not found: $SV" }
  $files = @($SV)
} else {
  if (-not (Test-Path $WTF)) { throw "WTF account folder not found: $WTF (pass -SV with the path to the collector's pfUI.lua)" }
  $files = @(Get-ChildItem -Path $WTF -Recurse -Filter "pfUI.lua" -ErrorAction SilentlyContinue |
    Where-Object { Select-String -Path $_.FullName -Pattern '\["octoshare"\]' -Quiet -ErrorAction SilentlyContinue } |
    ForEach-Object { $_.FullName })
}
if ($files.Count -eq 0) { Write-Host "No collector log found. Turn the collector on in game, log out (so it saves), then run again."; return }

# the dedupe state
$seenPath = Join-Path $Out "seen.txt"
$seen = New-Object System.Collections.Generic.HashSet[string]
if (Test-Path $seenPath) { foreach ($h in [IO.File]::ReadAllLines($seenPath)) { if ($h) { [void]$seen.Add($h) } } }
$md5 = [Security.Cryptography.MD5]::Create()
function Hash([string]$s) { return [Convert]::ToBase64String($md5.ComputeHash([Text.Encoding]::UTF8.GetBytes($s))) }

# CSV writers (header only when the file is new)
$pricesPath = Join-Path $Out "prices.csv"
$eventsPath = Join-Path $Out "events.csv"
$bgqPath = Join-Path $Out "bgq.csv"
$bgrPath = Join-Path $Out "bgr.csv"
$popPath = Join-Path $Out "pop.csv"
$prices = New-Object System.Text.StringBuilder
$events = New-Object System.Text.StringBuilder
$bgq = New-Object System.Text.StringBuilder
$bgr = New-Object System.Text.StringBuilder
$pop = New-Object System.Text.StringBuilder
$newBgq = 0; $newBgr = 0; $newPop = 0
if (-not (Test-Path $pricesPath)) { [void]$prices.AppendLine("realm,faction,day,itemkey,copper,sender,ts") }
if (-not (Test-Path $eventsPath)) { [void]$events.AppendLine("ts,kind,sender,channel,payload") }
if (-not (Test-Path $bgqPath)) { [void]$bgq.AppendLine("map,faction,seconds,sender,ts") }
if (-not (Test-Path $bgrPath)) { [void]$bgr.AppendLine("map,faction,win,sender,ts") }
if (-not (Test-Path $popPath)) { [void]$pop.AppendLine("zone,faction,sender,ts") }
function Csv([string]$s) { if ($null -eq $s) { $s = "" }; if ($s -match '[,"\r\n]') { return '"' + ($s -replace '"', '""') + '"' } return $s }

# a SavedVariables Lua string: "..." with \" and \\ escapes. Our log entries never contain a quote, so a plain
# quoted-run regex is safe; we unescape backslashes for the payload. Fields are backtick-separated: ts`kind`sender`chan`payload
$rxEntry = [regex]'"(\d+`[^"\\]*(?:\\.[^"\\]*)*)"'
$newRows = 0; $newPrices = 0

foreach ($file in $files) {
  $text = [IO.File]::ReadAllText($file)
  # only the octoshare block, so an unrelated quoted string elsewhere is never mistaken for a log line
  $start = $text.IndexOf('["octoshare"]')
  if ($start -lt 0) { continue }
  $block = $text.Substring($start)
  foreach ($m in $rxEntry.Matches($block)) {
    $raw = $m.Groups[1].Value -replace '\\\\', '\' -replace '\\"', '"'
    $parts = $raw.Split([char]0x60, 5)   # backtick
    if ($parts.Count -lt 5) { continue }
    $h = Hash($raw)
    if ($seen.Contains($h)) { continue }
    [void]$seen.Add($h)
    $ts = $parts[0]; $kind = $parts[1]; $sender = $parts[2]; $chan = $parts[3]; $payload = $parts[4]
    $newRows++
    [void]$events.AppendLine((Csv $ts) + "," + (Csv $kind) + "," + (Csv $sender) + "," + (Csv $chan) + "," + (Csv $payload))
    # the auction-price feed: "Realm-Faction^day^key=copper,key=copper"
    if ($kind -eq "pfAP") {
      $ih = $payload.IndexOf('^'); if ($ih -lt 0) { continue }
      $rf = $payload.Substring(0, $ih)
      $rest = $payload.Substring($ih + 1)
      $jd = $rest.IndexOf('^'); if ($jd -lt 0) { continue }
      $day = $rest.Substring(0, $jd)
      $body = $rest.Substring($jd + 1)
      $dash = $rf.LastIndexOf('-')
      $realm = if ($dash -ge 0) { $rf.Substring(0, $dash) } else { $rf }
      $faction = if ($dash -ge 0) { $rf.Substring($dash + 1) } else { "" }
      foreach ($pair in $body.Split(',')) {
        $eq = $pair.IndexOf('='); if ($eq -lt 0) { continue }
        $key = $pair.Substring(0, $eq); $copper = $pair.Substring($eq + 1)
        if ($key -eq "" -or $copper -notmatch '^\d+$') { continue }
        [void]$prices.AppendLine((Csv $realm) + "," + (Csv $faction) + "," + (Csv $day) + "," + (Csv $key) + "," + $copper + "," + (Csv $sender) + "," + (Csv $ts))
        $newPrices++
      }
    }
    # the new OctoShare feeds (pfOS): payload is "subkind^field^field..."
    elseif ($kind -eq "pfOS") {
      $sh = $payload.IndexOf('^'); if ($sh -lt 0) { continue }
      $sub = $payload.Substring(0, $sh)
      $f = $payload.Substring($sh + 1).Split('^')
      if ($sub -eq "bgq" -and $f.Count -ge 3) {
        if ($f[2] -match '^\d+$') { [void]$bgq.AppendLine((Csv $f[0]) + "," + (Csv $f[1]) + "," + $f[2] + "," + (Csv $sender) + "," + (Csv $ts)); $newBgq++ }
      } elseif ($sub -eq "bgr" -and $f.Count -ge 3) {
        if ($f[2] -match '^[01]$') { [void]$bgr.AppendLine((Csv $f[0]) + "," + (Csv $f[1]) + "," + $f[2] + "," + (Csv $sender) + "," + (Csv $ts)); $newBgr++ }
      } elseif ($sub -eq "pop" -and $f.Count -ge 2) {
        [void]$pop.AppendLine((Csv $f[0]) + "," + (Csv $f[1]) + "," + (Csv $sender) + "," + (Csv $ts)); $newPop++
      }
    }
  }
}

$utf8 = New-Object System.Text.UTF8Encoding($false)   # no BOM: sqlite3 .import / Postgres COPY choke on one
function Append([string]$path, [string]$text) {
  if ($text -eq "") { return }
  [IO.File]::AppendAllText($path, $text.TrimEnd("`r", "`n") + "`n", $utf8)
}
if ($newRows -gt 0) {
  Append $eventsPath $events.ToString()
  if ($newPrices -gt 0) { Append $pricesPath $prices.ToString() }
  if ($newBgq -gt 0) { Append $bgqPath $bgq.ToString() }
  if ($newBgr -gt 0) { Append $bgrPath $bgr.ToString() }
  if ($newPop -gt 0) { Append $popPath $pop.ToString() }
  [IO.File]::WriteAllLines($seenPath, $seen, $utf8)
}
Write-Host ("OctoShare: {0} file(s), {1} new record(s) - {2} prices, {3} bg-queues, {4} bg-results, {5} pop. Written to {6}" -f $files.Count, $newRows, $newPrices, $newBgq, $newBgr, $newPop, $Out)
