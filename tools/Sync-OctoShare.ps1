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
    events.csv   ts,kind,sender,channel,payload                 (every other feed, raw - nothing is lost)
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
$prices = New-Object System.Text.StringBuilder
$events = New-Object System.Text.StringBuilder
if (-not (Test-Path $pricesPath)) { [void]$prices.AppendLine("realm,faction,day,itemkey,copper,sender,ts") }
if (-not (Test-Path $eventsPath)) { [void]$events.AppendLine("ts,kind,sender,channel,payload") }
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
  [IO.File]::WriteAllLines($seenPath, $seen, $utf8)
}
Write-Host ("OctoShare: {0} file(s), {1} new record(s) ({2} price rows). Written to {3}" -f $files.Count, $newRows, $newPrices, $Out)
