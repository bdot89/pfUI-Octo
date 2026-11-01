# Runs tests\run.lua through DmorphOcto's LuaHost (LuaJIT from OBS Studio with
# Lua 5.0 shims). LuaJIT accepts #, % and ... that 5.0 does not: run
# OctoBG\tools\LuaCheck.ps1 as well.
#   powershell -ExecutionPolicy Bypass -File tests\run.ps1
$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$exe = Join-Path $root "..\DmorphOcto\tools\LuaHost\bin\LuaHost.exe"
if (-not (Test-Path $exe)) { throw "LuaHost not built: run DmorphOcto\tools\run_tests.ps1 once" }
Push-Location $root
try {
  & $exe "tests/run.lua"
  $main = $LASTEXITCODE
  # the character stats (charstats\, EvenBetterCharacterStats merged in) run on their own mock
  & $exe "tests/charstats.lua" | Select-Object -Last 1
  $stats = $LASTEXITCODE
  if ($main -ne 0) { exit $main } else { exit $stats }
} finally { Pop-Location }
