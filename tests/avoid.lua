-- pfUI Octo: avoidable damage taken (modules/meters.lua M.Avoidable, the "avoid" display), run by tests\run.lua.
local ok = octo_ok
local M = pfUI.meters
ok(M and M.Avoidable and M.AVOID_DEFAULT, "avoidable damage loaded")
if not M then return end
local S = pfUI_config.meters
local saved = S.avoidlist
S.avoidlist = nil
S.avoidenv = "1"
ok(M.Avoidable({ src = "Onyxia", spl = "Deep Breath", amt = 100 }), "a listed spell is avoidable")
ok(M.Avoidable({ src = "Onyxia", spl = "deep breath", amt = 100 }), "the name's case does not matter")
ok(not M.Avoidable({ src = "Onyxia", spl = "Flame Breath", amt = 100 }), "a spell not on the list is not")
ok(not M.Avoidable({ src = "Onyxia", amt = 100 }), "a melee hit (no spell) is not")
ok(M.Avoidable({ spl = "Lava", amt = 100 }), "the environment counts (no source, a spell name)")
S.avoidenv = "0"
ok(not M.Avoidable({ spl = "Lava", amt = 100 }), "environment off")
S.avoidenv = "1"
S.avoidlist = "  Cleave ;Whirlwind; "
ok(M.Avoidable({ src = "Boss", spl = "Cleave" }) and M.Avoidable({ src = "Boss", spl = "whirlwind" }), "your own list replaces the built-in one")
ok(not M.Avoidable({ src = "Onyxia", spl = "Deep Breath" }), "...and the built-in names no longer count")
S.avoidlist = saved
-- merged fights add their avoidable damage
local a, b = { avtotal = 100, avspells = { ["Deep Breath - Onyxia"] = { total = 100, hits = 1, max = 100 } } },
  { avtotal = 50, avspells = { ["Deep Breath - Onyxia"] = { total = 50, hits = 1, max = 50 } } }
M.Merge(a, b)
ok(a.avtotal == 150 and a.avspells["Deep Breath - Onyxia"].total == 150 and a.avspells["Deep Breath - Onyxia"].hits == 2, "merged fights add up")
