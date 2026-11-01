param(
  [string]$GameDir = "",
  [switch]$Check,
  [switch]$Force,
  # (29 Oct 2026: the official weirdutils.dll stopped this client at a quarter of the loading bar;
  # the installer takes weirdutils_noperf.dll - every module but weirdperformance - instead)
  [switch]$WeirdUtils   # (no longer needed: WeirdUtils installs by default again)
)
# pfUI Octo: puts the newest client DLLs pfUI Octo uses into the game folder
# (user, 26 Oct 2026: "an install bat that installs the newest version of
# everything this addon needs ... one button install like in dmorph").
#
#   ClassicAPI    better data everywhere (auras, casts, items, combat log...)
#   SuperWoW      GUIDs, cast events, the focus frame, mouseover casts
#   nampower      spell events for combat text and meters
#   UnitXP_SP3    distances and line of sight
#   WeirdUtils    world markers, minimap icons, transmog fix, bigger cursor... (Codeberg)
#   Interact      one key to right-click the nearest NPC, object, herb, vein or corpse
#
# Each comes from its author's GitHub (or Codeberg) releases (the newest one), is checked to
# be a Windows DLL, and is only copied when it differs from the one in the
# game folder - the old one is kept in <game>\DLL-backups first. A DLL that
# is not in dlls.txt yet is added (VanillaFixes, which OctoLauncher starts the
# game with, loads every DLL listed there). dlls.txt is backed up once, to
# dlls.txt.pfui-backup. pfUI Octo works without any of them - they only make
# it better.
#
# The easy way: close the game and double-click "Install pfUI Octo DLLs.bat"
# in the pfUI folder. Or:
#
#   powershell -ExecutionPolicy Bypass -File tools\install_dlls.ps1          (install / update)
#   powershell -ExecutionPolicy Bypass -File tools\install_dlls.ps1 -Check   (only say what would change)
#   powershell -ExecutionPolicy Bypass -File tools\install_dlls.ps1 -Force   (take the releases even over newer builds)
#
# A DLL you have that is newer than its release (OctoLauncher or the author
# hand some out) is kept. An antivirus that blocks a download (SuperWoW is
# often flagged, as it hooks into the game) is not worked around: that DLL
# is skipped and the others go on.
#
# The game folder is found by going up from this folder to the one with
# WoW.exe; elsewhere, add -GameDir C:\path\to\OctoWoW. To undo one DLL, copy
# its file back from DLL-backups (or take its line out of dlls.txt).

$ErrorActionPreference = "Stop"
trap {
  Write-Host ""
  Write-Host ("Not done: " + $_.Exception.Message) -ForegroundColor Red
  exit 1
}

# where each DLL comes from: GitHub owner/repo, the file in the game folder,
# and the release file it is in (a .dll, or a .zip holding it)
$DLLS = @(
  @{ Name = "ClassicAPI";  Repo = "brues-code/ClassicAPI";    File = "ClassicAPI.dll" },
  @{ Name = "SuperWoW";    Repo = "balakethelock/SuperWoW";   File = "SuperWoWhook.dll" },
  @{ Name = "nampower";    Repo = "brues-code/nampower";      File = "nampower.dll" },
  @{ Name = "UnitXP_SP3";  Repo = "brues-code/UnitXP_SP3";    File = "UnitXP_SP3.dll" },
  # (on Codeberg, whose release API answers like GitHub's. The noperf build: the full one hung this
  # client at the loading bar. v0.7.1 has no interact module; our build of newer source crashed, 29 Oct)
  @{ Name = "WeirdUtils";  Repo = "MarcelineVQ/WeirdUtils";   File = "weirdutils_noperf.dll"; Api = "https://codeberg.org/api/v1/repos/"; Site = "codeberg.org/" }
  # (the interact key: InteractNearest(), as OctoBG's Interact key calls it - MIT, github.com/lookino/Interact.
  # It extends UnitXP like UnitXP_SP3 does, so it loads after it: new lines go at the end of dlls.txt)
  # (29 Oct 2026: v1.0.4 crashed the game, #132 inside Interact.dll, on every key press here - left out)
  # @{ Name = "Interact";    Repo = "lookino/Interact";         File = "Interact.dll"; Addon = "Interact" }
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$headers = @{ "User-Agent" = "pfUI-Octo-installer" }

# The game folder: the nearest folder above this one with WoW.exe in it.
if (-not $GameDir) {
  $dir = [IO.Path]::GetFullPath($PSScriptRoot)
  while ($dir -and -not (Test-Path (Join-Path $dir "WoW.exe"))) {
    $parent = [IO.Path]::GetDirectoryName($dir)
    if ($parent -eq $dir) { $dir = $null } else { $dir = $parent }
  }
  if (-not $dir) {
    throw "Couldn't find the game folder (the one with WoW.exe) above $PSScriptRoot. Put pfUI in <game>\Interface\AddOns, or run this with -GameDir C:\path\to\OctoWoW."
  }
  $GameDir = $dir
}
$list = Join-Path $GameDir "dlls.txt"
"Game folder: $GameDir"
if ($Check) { "(check only: nothing is changed)" }
""

if (-not $Check) {
  $running = @(Get-Process -Name "WoW" -ErrorAction SilentlyContinue | Where-Object {
    $path = $null
    try { $path = $_.Path } catch { }
    # (a game whose folder Windows won't say counts as running too)
    (-not $path) -or ([IO.Path]::GetDirectoryName($path) -ieq $GameDir)
  })
  if ($running.Count -gt 0) { throw "The game is running. Close it completely, then run this again." }
}
if (-not (Test-Path $list)) {
  throw "There's no dlls.txt in $GameDir. Start the game once from OctoLauncher with the vanillaHelpers mod ticked (that makes it), close it, then run this again."
}

# a real Windows DLL: starts with MZ and is not tiny
function Test-Dll([string]$path) {
  if (-not (Test-Path $path)) { return $false }
  $len = (Get-Item $path).Length
  if ($len -lt 10000) { return $false }
  $fs = [IO.File]::OpenRead($path)
  try { $a = $fs.ReadByte(); $b = $fs.ReadByte() } finally { $fs.Close() }
  return ($a -eq 0x4D -and $b -eq 0x5A)
}

# when a DLL was built: the link time in its PE header (UTC), or $null
function Get-BuildDate([string]$path) {
  try {
    $b = [IO.File]::ReadAllBytes($path)
    $pe = [BitConverter]::ToInt32($b, 60)
    if ($pe -lt 0 -or $pe + 12 -gt $b.Length) { return $null }
    $ts = [BitConverter]::ToUInt32($b, $pe + 8)
    if ($ts -eq 0) { return $null }
    return ([DateTime]'1970-01-01').AddSeconds($ts)
  } catch { return $null }
}

$temp = Join-Path ([IO.Path]::GetTempPath()) ("pfui-octo-dlls-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $temp | Out-Null
$backups = Join-Path $GameDir "DLL-backups"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$lines = New-Object System.Collections.ArrayList
foreach ($l in [IO.File]::ReadAllLines($list)) { [void]$lines.Add($l) }
$listChanged = $false
$changed = 0

try {
  foreach ($d in $DLLS) {
    $name, $file = $d.Name, $d.File
    if ($d.Optional -and -not $WeirdUtils -and @($lines | Where-Object { $_.Trim() -ieq $file }).Count -eq 0) {
      "  {0}: not installed (optional - add -WeirdUtils to install it)." -f $name
      continue
    }
    try {
      $api = if ($d.Api) { $d.Api } else { "https://api.github.com/repos/" }
      $rel = Invoke-RestMethod -Uri ($api + $d.Repo + "/releases/latest") -Headers $headers -TimeoutSec 30
    } catch {
      Write-Host ("  {0}: couldn't reach its download site ({1}) - left as it is." -f $name, $_.Exception.Message) -ForegroundColor Yellow
      continue
    }
    $tag = $rel.tag_name
    # (a release tagged "Release" says its version in its name: "SuperWoW 2.2")
    if ($tag -notmatch '\d' -and $rel.name) { $tag = ($rel.name -replace ("^" + $name + "\s*"), "") }
    # the DLL itself, else a zip with it inside
    $asset = $rel.assets | Where-Object { $_.name -ieq $file } | Select-Object -First 1
    $zip = $null
    if (-not $asset) { $zip = $rel.assets | Where-Object { $_.name -like "*.zip" -and $_.name -notlike "*Symbol*" } | Select-Object -First 1 }
    if (-not $asset -and -not $zip) {
      Write-Host ("  {0} {1}: no {2} in the release - left as it is." -f $name, $tag, $file) -ForegroundColor Yellow
      continue
    }
    $got = Join-Path $temp $file
    $inside = $true
    try {
      if ($asset) {
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $got -Headers $headers -UseBasicParsing -TimeoutSec 120
      } else {
        $zpath = Join-Path $temp ($name + ".zip")
        Invoke-WebRequest -Uri $zip.browser_download_url -OutFile $zpath -Headers $headers -UseBasicParsing -TimeoutSec 120
        $zdir = Join-Path $temp $name
        Expand-Archive -Path $zpath -DestinationPath $zdir -Force
        $inside = Get-ChildItem -Path $zdir -Recurse -Filter $file | Select-Object -First 1
        if ($inside) { Copy-Item $inside.FullName $got -Force }
        # (a release that brings its own addon - Interact: its key bindings - puts it in Interface\AddOns)
        if ($d.Addon -and -not $Check) {
          $adir = Get-ChildItem -Path $zdir -Recurse -Directory -Filter $d.Addon | Where-Object { $_.Parent.Name -ieq "AddOns" } | Select-Object -First 1
          if ($adir) { Copy-Item $adir.FullName (Join-Path $GameDir ("Interface\AddOns\" + $d.Addon)) -Recurse -Force }
        }
      }
    } catch {
      # (an antivirus that blocks it is not worked around: this one is skipped)
      $why = $_.Exception.Message
      $site = if ($d.Site) { $d.Site } else { "github.com/" }
      if ($why -match "virus|unwanted") { $why = "your antivirus blocked the download - allow it there to install it, or get it from " + $site + $d.Repo }
      Write-Host ("  {0} {1}: skipped - {2}." -f $name, $tag, $why.Trim()) -ForegroundColor Yellow
      continue
    }
    if (-not $inside) {
      Write-Host ("  {0} {1}: the download has no {2} - left as it is." -f $name, $tag, $file) -ForegroundColor Yellow
      continue
    }
    if (-not (Test-Dll $got)) {
      Write-Host ("  {0} {1}: the download is not a DLL - left as it is." -f $name, $tag) -ForegroundColor Yellow
      continue
    }
    $target = Join-Path $GameDir $file
    $same = (Test-Path $target) -and ((Get-FileHash $got).Hash -eq (Get-FileHash $target).Hash)
    $listed = @($lines | Where-Object { $_.Trim() -ieq $file }).Count -gt 0
    # never older than what you have: the file's version against the release's,
    # else the file's date against the release's (OctoLauncher and the authors
    # hand out builds newer than a release - those stay)
    $mine = ""
    if (-not $same -and -not $Force -and (Test-Path $target)) {
      $fv = (Get-Item $target).VersionInfo.FileVersion
      $rv = ($tag -replace '^[vV]', '')
      $a, $b = $null, $null
      if ([Version]::TryParse(($fv -replace ',', '.' -replace '\s', ''), [ref]$a) -and [Version]::TryParse($rv, [ref]$b)) {
        if ($a -ge $b) { $mine = "your $fv is the same or newer" }
      } else {
        # (1 Nov 2026: the file's date on disk is when it was copied, not built -
        # a June nampower was kept over the August release. The build date in
        # the DLL's own header is compared instead, against the downloaded one's.)
        $have, $new = (Get-BuildDate $target), (Get-BuildDate $got)
        if ($have -and $new -and $have -gt $new) {
          $mine = "yours is a newer build (" + $have.ToString("d MMM yyyy") + ")"
        }
      }
    }
    if ($mine -ne "") {
      "  {0} {1}: kept - {2}." -f $name, $tag, $mine
    } elseif ($same) {
      "  {0} {1}: already the newest." -f $name, $tag
    } elseif ($Check) {
      "  {0} {1}: would be {2}." -f $name, $tag, $(if (Test-Path $target) { "updated" } else { "installed" })
    } else {
      if (Test-Path $target) {
        if (-not (Test-Path $backups)) { New-Item -ItemType Directory -Path $backups | Out-Null }
        Copy-Item $target (Join-Path $backups ("{0}.{1}.bak" -f $file, $stamp)) -Force
      }
      try { Copy-Item $got $target -Force } catch { throw "Couldn't copy $file into $GameDir. Close the game first, then run this again." }
      try { Unblock-File $target } catch { }
      $changed++
      "  {0} {1}: {2}." -f $name, $tag, $(if (Test-Path (Join-Path $backups ("{0}.{1}.bak" -f $file, $stamp))) { "updated (old one in DLL-backups)" } else { "installed" })
    }
    if (-not $listed) {
      if ($Check) {
        "  {0}: would be added to dlls.txt." -f $file
      } else {
        [void]$lines.Add($file)
        $listChanged = $true
        "  {0}: added to dlls.txt." -f $file
      }
    }
  }

  # the full weirdutils.dll and our own (crashing) weirdutils_octo.dll never load beside the noperf build
  $old = @("weirdutils.dll", "weirdutils_octo.dll")
  $full = @($lines | Where-Object { $old -contains $_.Trim().ToLower() })
  if ($full.Count -gt 0) {
    if ($Check) {
      "  an old WeirdUtils DLL: would be taken out of dlls.txt (weirdutils_noperf.dll replaces it)."
    } else {
      $keep = New-Object System.Collections.ArrayList
      foreach ($l in $lines) { if ($old -notcontains $l.Trim().ToLower()) { [void]$keep.Add($l) } }
      $lines = $keep
      $listChanged = $true
      "  an old WeirdUtils DLL: taken out of dlls.txt (weirdutils_noperf.dll replaces it)."
    }
  }

  if ($listChanged) {
    $backup = "$list.pfui-backup"
    if (-not (Test-Path $backup)) { Copy-Item $list $backup }
    [IO.File]::WriteAllLines($list, [string[]]$lines.ToArray())
  }
} finally {
  Remove-Item -Recurse -Force $temp -ErrorAction SilentlyContinue
}

""
if ($Check) {
  "Check done: nothing was changed."
} elseif ($changed -gt 0 -or $listChanged) {
  "Done. Start the game from OctoLauncher as usual (if it's open, close it and start it again)."
  "If the game won't start: copy the old DLL back from DLL-backups, or restore dlls.txt from dlls.txt.pfui-backup."
} else {
  "Everything is already the newest - nothing to do."
}
