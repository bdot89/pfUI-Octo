# OctoLoot builder: every profession's recipes from the OctoWoW database (?spells=11.<skill>, ?spells=9.<skill> for
# secondary skills): spell id, name, reagents, skill colours. Writes recipes.tsv and sets.tsv (every item set's
# pieces, ?itemsets) in the work folder.
$ErrorActionPreference = "Stop"
$here = $(if ($env:OCTOLOOT_WORK) { $env:OCTOLOOT_WORK } else { Join-Path $env:TEMP "octoloot-work" })
$cache = Join-Path $here "cache"
New-Item -ItemType Directory -Force $cache | Out-Null
function Get-Page($q, $name) {
  $file = Join-Path $cache "$name.html"
  if (Test-Path $file) { return Get-Content -Raw -Encoding utf8 $file }
  Start-Sleep -Milliseconds 350
  try { $c = (Invoke-WebRequest -UseBasicParsing -UserAgent "Mozilla/5.0 (data builder)" -TimeoutSec 60 "https://octowow.st/db/$q").Content } catch { $c = "" }
  Set-Content -Encoding utf8 $file $c
  $c
}
# primary professions (11.x) and secondary skills (9.x); Jewelcrafting (755) is the server's own
$SKILLS = @{ 164 = "11"; 165 = "11"; 171 = "11"; 197 = "11"; 202 = "11"; 333 = "11"; 186 = "11"; 182 = "11"; 393 = "11"; 755 = "11";
  185 = "9"; 129 = "9"; 356 = "9"; 40 = "7" }
$out = New-Object System.Collections.ArrayList
foreach ($sk in $SKILLS.Keys) {
  foreach ($cat in @($SKILLS[$sk], "11", "9", "7") | Select-Object -Unique) {
    $c = Get-Page "?spells=$cat.$sk" "spells-$cat-$sk"
    $n = 0
    foreach ($r in [regex]::Split($c, "\{name: ?'") | Select-Object -Skip 1) {
      $nm = [regex]::Match($r, "^@?((?:[^'\\]|\\.)*)'")
      $id = [regex]::Match($r, "[,{ ]id: ?(\d+)")
      if (-not ($nm.Success -and $id.Success)) { continue }
      $rg = [regex]::Match($r, "reagents: ?\[((?:\[\d+,\d+\],?)*)\]")
      $reag = ""
      if ($rg.Success) { $reag = (([regex]::Matches($rg.Groups[1].Value, "\[(\d+),(\d+)\]") | % { "$($_.Groups[1].Value)x$($_.Groups[2].Value)" }) -join ",") }
      $col = [regex]::Match($r, "colors: ?\[([\d, ]*)\]")
      $colors = $(if ($col.Success) { ($col.Groups[1].Value -replace '\s', '').Trim(',') } else { "" })
      $name = ($nm.Groups[1].Value -replace "\\'", "'").Trim()
      [void]$out.Add(("{0}`t{1}`t{2}`t{3}`t{4}" -f $id.Groups[1].Value, $sk, $name, $reag, $colors))
      $n++
    }
    if ($n -gt 0) { break }
  }
}
$out | Sort-Object -Unique | Set-Content -Encoding utf8 (Join-Path $here "recipes.tsv")
"$($out.Count) recipes"
# item sets
$c = Get-Page "?itemsets" "itemsets"
$sets = New-Object System.Collections.ArrayList
foreach ($m in [regex]::Matches($c, "\{name: ?'(\d)((?:[^'\\]|\\.)*)',pieces: ?\[([\d,]*)\][^}]*?id: ?(\d+)\}")) {
  [void]$sets.Add(("{0}`t{1}`t{2}`t{3}" -f $m.Groups[4].Value, (6 - [int]$m.Groups[1].Value), ($m.Groups[2].Value -replace "\\'", "'"), $m.Groups[3].Value))
}
$sets | Set-Content -Encoding utf8 (Join-Path $here "sets.tsv")
"$($sets.Count) item sets"
