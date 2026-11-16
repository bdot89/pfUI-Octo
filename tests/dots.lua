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
