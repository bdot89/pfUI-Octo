-- pfUI Octo: procs in the meters (modules/meters.lua M.Proc, 25 Nov 2026, Lobo: "how often my Blade of Eternal
-- Darkness procs the Engulfing Shadows ... would be cool if it also said from where it got procced off")
local ok = octo_ok
local M = pfUI.meters
ok(M and M.Proc and M.IsProc and M.ProcOrOwn, "meter procs loaded")
if not (M and M.Proc) then return end

local keep = { overall = M.overall, history = M.history, current = M.current, gsn = rawget(_G, "GetSpellName"),
  link = rawget(_G, "GetInventoryItemLink") }
local me = UnitName("player")
_G.GetSpellName = function(i) if i == 1 then return "Shadow Bolt" end end
_G.GetInventoryItemLink = function() return nil end
M.ForgetBook()
M.ForgetProcItems()
M.Reset()
local seg = M.StartFight()
local t = GetTime()

ok(M.IsProc(me, "Engulfing Shadows") and not M.IsProc(me, "Shadow Bolt") and not M.IsProc(me, "Melee"),
  "yours: a spell not in your spell book is a proc, your own spells and melee are not")
ok(M.IsProc("Someone", "Holy Strength") and not M.IsProc("Someone", "Sinister Strike"),
  "anyone's: the known procs only")

-- Shadow Bolt, then its proc twice on two targets at once (one proc), then again after another bolt
M.ProcOrOwn(me, "Shadow Bolt", t)
M.ProcOrOwn(me, "Engulfing Shadows", t + .1, 100)
M.ProcOrOwn(me, "Engulfing Shadows", t + .15, 100)
M.ProcOrOwn(me, "Shadow Bolt", t + 3)
M.ProcOrOwn(me, "Engulfing Shadows", t + 3.2, 100)
local a = seg.actors[me]
local label = "Engulfing Shadows <- Shadow Bolt"
ok(a and a.nprocs == 2 and a.procs[label] == 2, "two procs, both set off by Shadow Bolt (" .. tostring(a and a.nprocs) .. ")")
ok(a.procdmg["Engulfing Shadows"] == 300, "its damage adds up (" .. tostring(a.procdmg["Engulfing Shadows"]) .. ")")
-- a proc long after anything you did: from where is not known
M.ProcOrOwn(me, "Engulfing Shadows", t + 20, 100)
ok(a.procs["Engulfing Shadows <- " .. (pfUI.env and pfUI.env.T and pfUI.env.T["Unknown"] or "Unknown")] == 1, "nothing of yours just before: \"Unknown\"")
-- the window's display lists them
local mode
for _, m in ipairs(M.MODES or {}) do if m.key == "procs" then mode = m end end
ok(mode and mode.value(a) == 3 and mode.plain(a)[label] == 2, "a Procs display under Misc")
-- buffs: from their second time in a fight (a potion comes up once), never right after someone cast them
M.ProcAura(me, "Elixir of the Mongoose", t + 1)
ok(a.nprocs == 3, "a buff seen once in a fight is not a proc yet")
M.ProcAura(me, "Spirit Tap", t + 5)
M.ProcAura(me, "Spirit Tap", t + 9)
ok(a.procnames["Spirit Tap"] == 2, "the second time a buff comes up, both count")
M.Record({ kind = "cast", src = "Healbot", spl = "Power Word: Fortitude", tgt = me })
M.ProcAura(me, "Power Word: Fortitude", GetTime())
M.ProcAura(me, "Power Word: Fortitude", GetTime())
ok(not (a.procnames["Power Word: Fortitude"]), "a buff someone just cast on you is not a proc")
M.ProcAura("Someone", "Holy Strength", t + 2)
ok(seg.actors.Someone and seg.actors.Someone.nprocs == 1, "a known proc buff counts the first time")

M.EndFight()
M.overall, M.history, M.current = keep.overall, keep.history, keep.current
_G.GetSpellName, _G.GetInventoryItemLink = keep.gsn, keep.link
M.ForgetBook()
M.ForgetProcItems()
