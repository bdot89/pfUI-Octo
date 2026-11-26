# Reads instance facts (name, level, size, boss names and map numbers) from Atlas-CFM's data files.
$ErrorActionPreference = "Stop"
$root = "C:\Games\OctoWoW\Interface\AddOns\Atlas-CFM\CFMLoot\Data"
$out = @()
foreach ($dir in "Instances", "World") {
  foreach ($f in Get-ChildItem (Join-Path $root $dir) -Filter *.lua) {
    $t = Get-Content -Raw $f.FullName
    $ms = [regex]::Matches($t, 'InstanceData\.(\w+)\s*=\s*\{')
    for ($k = 0; $k -lt $ms.Count; $k++) {
      $m = $ms[$k]
      $end = $(if ($k + 1 -lt $ms.Count) { $ms[$k + 1].Index } else { $t.Length })
      $blk = $t.Substring($m.Index, $end - $m.Index)
      $bi = $blk.IndexOf("Bosses = {")
      $head = $(if ($bi -gt 0) { $blk.Substring(0, $bi) } else { $blk.Substring(0, [Math]::Min(1500, $blk.Length)) })
      function Field($rx) { $x = [regex]::Match($head, $rx); if ($x.Success) { $x.Groups[1].Value } else { "" } }
      $inst = [ordered]@{
        key = $m.Groups[1].Value; file = $f.BaseName; kind = $dir
        name = Field 'Name\s*=\s*\w+\["([^"]+)"\]'
        loc = Field 'Location\s*=\s*\w+\["([^"]+)"\]'
        level = (Field 'Level\s*=\s*\{?\s*([\d, ]+)').Trim().TrimEnd(',').Trim()
        players = Field 'MaxPlayers\s*=\s*(\d+)'
        acr = Field 'Acronym\s*=\s*"([^"]*)"'
        bosses = @()
      }
      if ($bi -gt 0) {
        $body = $blk.Substring($bi)
        foreach ($e in [regex]::Matches($body, '\{\s*id\s*=\s*"([^"]+)",([\s\S]*?)(loot\s*=|\n\s*\},)')) {
          $chunk = $e.Groups[2].Value
          $nm = [regex]::Match($chunk, 'name\s*=\s*(\w+)\["([^"]+)"\]')
          $pre = [regex]::Match($chunk, 'prefix\s*=\s*"([^"]*)"')
          $srv = [regex]::Match($chunk, 'servers\s*=\s*\{([^}]*)\}')
          $inst.bosses += [ordered]@{
            id = $e.Groups[1].Value
            name = $(if ($nm.Success) { $nm.Groups[2].Value } else { $e.Groups[1].Value })
            table = $(if ($nm.Success) { $nm.Groups[1].Value } else { "" })
            prefix = $(if ($pre.Success) { $pre.Groups[1].Value.Trim() } else { "" })
            servers = $(if ($srv.Success) { ($srv.Groups[1].Value -replace 'AtlasCFM\.Server\.', '').Trim() } else { "" })
          }
        }
      }
      $out += $inst
    }
  }
}
$out | ConvertTo-Json -Depth 5 | Set-Content -Encoding utf8 (Join-Path $(if ($env:OCTOLOOT_WORK) { $env:OCTOLOOT_WORK } else { Join-Path $env:TEMP "octoloot-work" }) "atlas.json")
"{0} instances, {1} bosses" -f $out.Count, ($out | % { $_.bosses.Count } | Measure -Sum).Sum
