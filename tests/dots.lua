-- pfUI Octo: DoT Tracker (modules/dots.lua, dots-options.lua, dots-data.lua), run by tests\run.lua.
-- ClassicAPI reading (real end times, caster = "mine"), the icon groups and their order, the filters,
-- the multi-DoT pick, Cursive's macro arguments, profile export / import and the options pages.
local ok = octo_ok
local D = pfUI.dots
ok(D and D.Read and D.Shown and D.Pick and D.PaintRow, "DoT Tracker loaded (pfUI.dots)")
if not D then return end
local O = pfUI.octoui and pfUI.octoui.Options
for _, k in ipairs({ "dotgeneral", "dotraid", "dotclass", "dotdisplay", "dotfilter", "dotprofiles" }) do
  ok(O and O.BUILD and O.BUILD[k], "options page " .. k .. " registered")
end
local S = pfUI_config.dots
ok(S and S.showmine == "1" and S.order1 == "ownclass" and type(S.raid) == "table" and type(S.ignore) == "table", "defaults (C.dots)")
ok(table.getn(D.DATA.raid) > 40 and D.DATA.spells[172] and D.DATA.spells[172][1] == "Corruption", "spell data from Cursive (dots-data.lua)")
ok(D.RAIDID[7386] and D.RAIDID[7386].key == "sunderarmor" and D.Watched(D.RAIDKEY.sunderarmor), "Sunder Armor is a watched raid debuff")
ok(rawget(_G, "SLASH_PFDOTS1") == "/dot", "/dot")

local keep = {}
for _, k in ipairs({ "C_UnitAuras", "GetTime", "UnitExists", "UnitName", "UnitHealth", "UnitHealthMax", "UnitCanAttack",
                     "UnitIsEnemy", "UnitAffectingCombat", "UnitIsDead", "UnitIsPlayer", "GetRaidTargetIndex", "CastSpellByName" }) do
  keep[k] = rawget(_G, k)
end
local now = 500
_G.GetTime = function() return now end
local MOBS = { ["0xA"] = { name = "Ragnaros", hp = 90, mark = 8 }, ["0xB"] = { name = "Healer", hp = 50 }, ["0xC"] = { name = "Lava Spawn", hp = 20 } }
_G.UnitExists = function(u)
  if u == "player" then return 1, "0xME" end
  if u == "target" then return 1, "0xA" end
  if MOBS[u] then return 1, u end
end
_G.UnitName = function(u) return MOBS[u] and MOBS[u].name or "Me" end
_G.UnitHealth = function(u) return MOBS[u] and MOBS[u].hp or 100 end
_G.UnitHealthMax = function() return 100 end
_G.UnitCanAttack = function(_, u) return MOBS[u] and 1 end
_G.UnitIsEnemy = function(_, u) return MOBS[u] and 1 end
_G.UnitAffectingCombat = function() return 1 end
_G.UnitIsDead = function() return nil end
_G.UnitIsPlayer = function() return nil end
_G.GetRaidTargetIndex = function(u) return MOBS[u] and MOBS[u].mark end
local AURAS = {
  ["0xA"] = { { spellId = 172, name = "Corruption", icon = "c", applications = 0, expirationTime = 512, duration = 18, sourceGUID = "0xME" },
              { spellId = 7386, name = "Sunder Armor", icon = "s", applications = 5, expirationTime = 520, duration = 30, sourceGUID = "0xWAR" },
              { spellId = 980, name = "Curse of Agony", icon = "a", applications = 0, expirationTime = 503, duration = 24, sourceGUID = "0xME" } },
  ["0xB"] = { { spellId = 172, name = "Corruption", icon = "c", applications = 0, expirationTime = 510, duration = 18, sourceGUID = "0xME" } },
  ["0xC"] = {},
}
_G.C_UnitAuras = { GetUnitAuras = function(g, f) if f == "HARMFUL" then return AURAS[g] or {} end return {} end }
D.me = nil
D.Clear()
for g in pairs(MOBS) do D.Add(g) end
ok(D.n == 3, "three mobs tracked")

local u = D.units["0xA"]
D.Info(u)
D.Read(u, now)
ok(u.na == 3 and u.auras[1].kind == "mine" and u.auras[1].ends == 512 and u.auras[2].kind == "raid", "ClassicAPI: end times and casters read")
local main, other = D.Shown(u, {}, {})
ok(table.getn(main) == 3 and main[1].name == "Curse of Agony" and main[2].name == "Corruption" and main[3].name == "Sunder Armor",
  "icons: yours first, soonest ending first, then the raid's")
S.otherside = "otherraid"
main, other = D.Shown(u, {}, {})
ok(table.getn(main) == 2 and table.getn(other) == 1 and other[1].name == "Sunder Armor", "a group on the other side")
S.otherside = "none"
S.hide = "corruption"
D.ReadHide()
main = D.Shown(u, {}, {})
ok(table.getn(main) == 2, "never-show list hides a debuff")
S.hide = ""
D.ReadHide()

local list = D.Scan()
ok(table.getn(list) == 3 and list[1].guid == "0xA", "scan: all three, target first")
S.mineonly = "1"
S.alwaystarget = "0"
list = D.Scan()
ok(table.getn(list) == 2, "only mobs with my debuffs")
S.mineonly, S.alwaystarget = "0", "1"
S.ignore = { "Healer" }
list = D.Scan()
ok(table.getn(list) == 2, "ignore list")
S.ignore = {}

-- (user, 17 Nov 2026) the order is locked in combat: changing target or health never moves a row
do
  local function Order(l) local t = {} for i, x in ipairs(l) do t[i] = x.guid end return table.concat(t, ",") end
  local oldExists = _G.UnitExists
  S.lockorder = "1"
  list = D.Scan()
  local before = Order(list)
  local tg = "0xC"
  _G.UnitExists = function(u) if u == "target" then return 1, tg end return oldExists(u) end
  MOBS["0xC"].mark = 8
  MOBS["0xA"].mark = nil
  list = D.Scan()
  ok(Order(list) == before, "locked: a new target and new marks keep every row where it was")
  MOBS["0xD"] = { name = "Son of Flame", hp = 95, mark = 7 }
  D.Add("0xD")
  list = D.Scan()
  ok(Order(list) == before .. ",0xD", "locked: a new mob joins at the bottom")
  _G.UnitAffectingCombat = function() return nil end
  list = D.Scan()
  ok(list[1].guid == "0xC" and D.nextPlace == 0, "out of combat: sorted again (target on top)")
  S.lockorder = "0"
  _G.UnitAffectingCombat = function() return 1 end
  list = D.Scan()
  ok(list[1].guid == "0xC", "lock off: the target goes to the top in combat")
  D.Remove("0xD")
  MOBS["0xD"] = nil
  MOBS["0xC"].mark, MOBS["0xA"].mark = nil, 8
  _G.UnitExists = oldExists
  S.lockorder = "1"
end

-- (22 Nov 2026, user: "use classicAPI better for ... the dot tracker") the bars' mobs are registered for UNIT_AURA
-- by GUID; a mob is read again only when its auras changed (or every D.READ_EVERY s)
do
  local gev = D.auraEvents
  local registered, reads = {}, 0
  -- (no varargs: the test host is LuaJIT, the checker wants Lua 5.0)
  gev.RegisterGUIDEvent = function(_, e, g1, g2, g3, g4, g5, g6)
    local n = 0
    for _, g in ipairs({ g1, g2, g3, g4, g5, g6 }) do if g then n = n + 1 end end
    registered = { e = e, n = n }
    return true
  end
  gev.UnregisterGUIDEvent = function() end
  local keepRead = D.Read
  D.Read = function(u, t) reads = reads + 1 return keepRead(u, t) end
  D.Scan()
  ok(registered.e == "UNIT_AURA" and registered.n >= 1 and D.guidEvents, "the bars' mobs are registered for UNIT_AURA by GUID (" .. tostring(registered.n) .. ")")
  for _, uu in pairs(D.units) do uu.readAt = nil end
  D.Scan()
  reads = 0
  D.Scan()
  local quiet = reads
  _G.event, _G.arg1 = "UNIT_AURA", "0xB"
  gev:GetScript("OnEvent")()
  D.Scan()
  ok(reads == quiet + 1, "an aura change on one mob: only that one read again (" .. quiet .. " then " .. (reads - quiet) .. ")")
  now = now + D.READ_EVERY + .1
  reads = 0
  D.Scan()
  ok(reads >= 2, "after " .. D.READ_EVERY .. " s all are read again to be safe")
  D.Read = keepRead
  gev.RegisterGUIDEvent, gev.UnregisterGUIDEvent, D.guidEvents = nil, nil, nil
end

-- multi-DoT: Corruption goes to the mob that lacks it
local cast
_G.CastSpellByName = function(s, g) cast = { s, g } end
local picked = D.Cast("Corruption")
ok(picked and picked.guid == "0xC" and cast and cast[2] == "0xC", "/dot cast Corruption: the mob without it")
picked = D.Pick("Corruption")
ok(not picked, "just cast at: not picked again while pending")
picked = D.Pick("Curse of Agony", nil, 5)
ok(picked and picked.guid == "0xA", "refresh=5: Ragnaros' Curse of Agony (3 s left) is due")
local spell, order, refresh, opts = D.ParseArgs("Curse of Agony|HIGHEST_HP|minhp=5000,refreshtime=3,allowooc")
ok(spell == "Curse of Agony" and order == "HIGHEST_HP" and refresh == 3 and opts.minhp == 5000 and opts.ooc, "Cursive's macro form read")

-- drawing a real row
local row = D.rows[1]
local okp = pcall(D.PaintRow, row, u, now)
ok(okp and row.icons[1]:IsShown(), "a row paints")
local fake = D.FakeUnits(now)
D.FakeTick(fake, now)
ok(table.getn(fake) == 5 and pcall(D.PaintRow, row, fake[1], now), "made-up mobs paint")

-- profiles: export -> import round trip
local P = D.Profiles
S.width = "222"
S.raid.sunderarmor = "0"
local text = P.Export()
S.width = "100"
S.raid.sunderarmor = "1"
ok(P.Import(text) and S.width == "222" and S.raid.sunderarmor == "0", "export / import round trip")
ok(not string.find(text, "|", 1, true), "exported text has no |")
ok(not P.Import("return os.exit()"), "foreign text refused")
S.raid.sunderarmor = nil
S.width = "120"
ok(P.Save("t1") and P.Load("t1"), "profile saved and loaded")
P.Delete("t1")
ok(P.Preset("raid") and S.showmine == "0" and S.missing == "1", "ready-made look")
P.Preset("default")

for k, v in pairs(keep) do rawset(_G, k, v) end
D.Clear()

-- (16 Nov 2026) the macro maker: the /dot line for the picks, made or updated
local SO = pfUI.dotsoptions
ok(SO and SO.MacroBody and SO.MakeMacro, "macro maker loaded")
if SO and SO.MacroBody then
  local m = { spell = "Corruption", mode = "cast", order = "marks", refresh = "0", minhp = "0", range = "0" }
  ok(SO.MacroBody(m) == "/dot cast Corruption", "plain: /dot cast Corruption")
  m.order = "lowhp"
  ok(SO.MacroBody(m) == "/dot cast Corruption|lowhp", "an order")
  m.order, m.refresh, m.minhp, m.ooc = "marks", "3", "5000", true
  ok(SO.MacroBody(m) == "/dot cast Corruption|marks|refresh=3,minhp=5000,ooc", "options after the order (" .. SO.MacroBody(m) .. ")")
  m.mode = "target"
  ok(string.find(SO.MacroBody(m), "^/dot target Corruption") ~= nil, "target mode")
  local D2 = pfUI.dots
  if D2 and D2.ParseArgs then
    local sp, ord, ref, o = D2.ParseArgs("Corruption|marks|refresh=3,minhp=5000,ooc")
    ok(sp == "Corruption" and ord == "marks" and ref == 3 and o.minhp == 5000 and o.ooc, "and /dot reads it back")
  end
  ok(SO.MacroName({ spell = "Curse of Agony and more" }) == "Curse of Agony a" and SO.MacroName({ spell = "x", name = "My DoT" }) == "My DoT", "macro names: 16 letters, own name")
  local made, edited = {}, {}
  local k1, k2, k3 = rawget(_G, "CreateMacro"), rawget(_G, "EditMacro"), rawget(_G, "GetMacroIndexByName")
  _G.CreateMacro = function(n, i, b) table.insert(made, { n, b }) end
  _G.EditMacro = function(idx, n, i, b) table.insert(edited, { idx, b }) end
  _G.GetMacroIndexByName = function(n) return n == "Old" and 7 or 0 end
  SO.MakeMacro("Corruption", "/dot cast Corruption")
  SO.MakeMacro("Old", "/dot cast Immolate")
  ok(made[1] and made[1][1] == "Corruption" and edited[1] and edited[1][1] == 7 and edited[1][2] == "/dot cast Immolate", "new macros made, one of the same name updated")
  _G.CreateMacro, _G.EditMacro, _G.GetMacroIndexByName = k1, k2, k3
end
