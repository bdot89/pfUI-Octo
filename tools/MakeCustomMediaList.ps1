param(
  [Parameter(Mandatory = $true)][string]$Source,           # the unpacked pfUI-CustomMedia folder
  [string]$Root = (Join-Path $PSScriptRoot "..")
)
# Writes env\custommedia.lua: the lists of pfUI-CustomMedia's pictures and fonts (MIT, Mr_Rosh,
# github.com/mr-rosh/pfUI-CustomMedia; the files are in pfUI\custommedia) in the order that add-on
# shows them, keeping only what is in pfUI\custommedia (fonts pfUI already has are left out).
#   powershell -ExecutionPolicy Bypass -File tools\MakeCustomMediaList.ps1 -Source <folder>

$cm = Join-Path $Root "custommedia"
$bars = Get-Content (Join-Path $Source "pfUI-CustomMedia-bars.lua") -Raw
$names = @()
foreach ($m in [regex]::Matches($bars, "\[\[\r?\n(.*?)\]\]", "Singleline")) {
  foreach ($line in ($m.Groups[1].Value -split "\r?\n")) {
    $n = $line.Trim()
    if ($n -ne "" -and (Test-Path (Join-Path $cm "statusbars\$n.tga"))) { $names += $n }
  }
}
$fontsSrc = Get-Content (Join-Path $Source "pfUI-CustomMedia-fonts.lua") -Raw
$fonts = @()
foreach ($m in [regex]::Matches($fontsSrc, '\{\s*"([^"]+\.ttf)"\s*,\s*"([^"]+)"\s*\}')) {
  if (Test-Path (Join-Path $cm ("fonts\" + $m.Groups[1].Value))) { $fonts += , @($m.Groups[1].Value, $m.Groups[2].Value) }
}
$grySrc = Get-Content (Join-Path $Source "pfUI-CustomMedia-gryphons.lua") -Raw
$gry = @()
foreach ($m in [regex]::Matches($grySrc, '\{name\s*=\s*"([^"]+)"\s*,\s*path\s*=\s*"([^"]+)"\s*\}')) {
  if (Test-Path (Join-Path $cm ("gryphons\" + $m.Groups[2].Value + ".tga"))) { $gry += , @($m.Groups[1].Value, $m.Groups[2].Value) }
}
$bgs = Get-ChildItem (Join-Path $cm "backgrounds") -Filter *.tga | ForEach-Object { $_.BaseName }

$o = New-Object System.Text.StringBuilder
[void]$o.AppendLine("-- pfUI Octo: the pictures and fonts of pfUI-CustomMedia (MIT, Mr_Rosh, github.com/mr-rosh/pfUI-CustomMedia),")
[void]$o.AppendLine("-- files in pfUI\custommedia (licence: custommedia\LICENSE-pfUI-CustomMedia.txt). Made by tools\MakeCustomMediaList.ps1.")
[void]$o.AppendLine("-- bars = statusbars\<name>.tga, fonts = { file, label }, gryphons = { label, file }, backgrounds = backgrounds\<name>.tga")
[void]$o.AppendLine("pfUI_customMediaList = {")
[void]$o.AppendLine("  bars = {")
for ($i = 0; $i -lt $names.Count; $i += 8) {
  $row = ($names[$i..([Math]::Min($i + 7, $names.Count - 1))] | ForEach-Object { '"' + $_ + '"' }) -join ", "
  [void]$o.AppendLine("    $row,")
}
[void]$o.AppendLine("  },")
[void]$o.AppendLine("  fonts = {")
foreach ($f in $fonts) { [void]$o.AppendLine('    { "' + $f[0] + '", "' + $f[1] + '" },') }
[void]$o.AppendLine("  },")
[void]$o.AppendLine("  gryphons = {")
foreach ($g in $gry) { [void]$o.AppendLine('    { "' + $g[0] + '", "' + $g[1] + '" },') }
[void]$o.AppendLine("  },")
[void]$o.AppendLine("  backgrounds = { " + (($bgs | ForEach-Object { '"' + $_ + '"' }) -join ", ") + " },")
[void]$o.AppendLine("}")
[IO.File]::WriteAllText((Join-Path $Root "env\custommedia.lua"), $o.ToString(), (New-Object System.Text.UTF8Encoding($false)))
"{0} bar textures, {1} fonts, {2} gryphons, {3} backgrounds" -f $names.Count, $fonts.Count, $gry.Count, $bgs.Count
