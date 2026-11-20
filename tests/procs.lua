-- pfUI Octo: OctoProcs (modules/procs.lua, 20 Nov 2026, user: "build procdoc in make our own version but 100x better
-- use dlls where needed ... easy to maintain and simple as it can possibly be"), run by tests\run.lua
local ok = octo_ok
local P = pfUI.procs
local O = pfUI.octoui and pfUI.octoui.Options
ok(P and P.LIST and P.Scan and P.Apply and P.Draw, "OctoProcs loaded (pfUI.procs)")
if not (P and P.LIST) then return end
ok(O and O:Select("o:procs") == nil and O.pages.procs, "its page is built")

-- every class's list: kind, name, icon, a place that exists, a colour
do
  local bad = {}
  local places = {}
  for _, pl in ipairs(P.PLACES) do places[pl.key] = true end
  for class, list in pairs(P.LIST) do
    for _, e in ipairs(list) do
      if not (({ buff = 1, spell = 1, ready = 1 })[e[1]] and type(e[2]) == "string" and type(e[3]) == "string" and places[e[4]]
        and P.Col(e[5])) then
        table.insert(bad, class .. ":" .. tostring(e[2]))
      end
    end
  end
  ok(table.getn(bad) == 0, "every built-in proc is complete (" .. table.concat(bad, ", ") .. ")")
end

local G = pfUI_config.procs
local keepCustom, keepUA, keepCS = G.custom, rawget(_G, "C_UnitAuras"), rawget(_G, "C_Spell")
local keepBook = P.book
G.custom = {
  { name = "Test Proc", kind = "buff", place = "sides" },
  { name = "Test Strike", kind = "spell", place = "top", dur = 5 },
}
P.book = { ["Test Strike"] = 1 }
P.Refresh()

-- ClassicAPI: buffs by name with their real time left, no tooltip
local buffs = {}
rawset(_G, "C_UnitAuras", { UnitAura = function(unit, i)
  local b = buffs[i]
  if not b then return nil end
  return b.name, "Interface\\Icons\\Spell_Shadow_ManaBurn", b.count or 0, nil, 10, GetTime() + b.left
end })
local usable = false
rawset(_G, "C_Spell", { IsSpellUsable = function() return usable end })

local t = GetTime()
local up = P.Scan(t)
ok(not up["Test Proc"] and not up["Test Strike"], "nothing up: nothing shows")
buffs = { { name = "Test Proc", left = 12, count = 3 } }
usable = true
up = P.Scan(t)
ok(up["Test Proc"] and math.abs((up["Test Proc"].left or 0) - 12) < .1 and up["Test Proc"].count == 3,
  "a buff proc comes up with its real time left and stacks")
ok(up["Test Strike"], "a reactive spell comes up when the game says it can be cast (not on any bar)")

P.Apply(up, t)
P.Tick(t, false)
local pics = P.frames["Test Proc"]
ok(pics and pics[1]:IsShown() and pics[2]:IsShown(), "\"both sides\" shows a mirrored pair")
local sp = P.frames["Test Strike"]
ok(sp and sp[1]:IsShown() and not sp[2]:IsShown(), "\"above\" shows one")
ok(pics[1].time:IsShown() and pics[1].time:GetText() == "12", "the countdown shows the seconds left (" .. tostring(pics[1].time:GetText()) .. ")")
ok(pics[1].count:GetText() == "3", "and the stacks")

-- a reactive window lasts its seconds, even while the spell stays usable
P.Tick(t + 6, false)
ok(not sp[1]:IsShown(), "Overpower-style windows end after their seconds")
-- the buff goes: its alert goes
buffs = {}
P.Apply(P.Scan(t + 1), t + 1)
ok(not P.active["Test Proc"] and not pics[1]:IsShown(), "the buff gone: the alert is gone")

-- switched off: never shows
G.custom[1].off = "1"
P.Refresh()
buffs = { { name = "Test Proc", left = 5 } }
ok(not P.Scan(t)["Test Proc"], "a proc switched off never shows")
G.custom[1].off = nil

-- the try: everything for 8 seconds, then gone
P.Refresh()
P.Test()
P.testStart = t
P.Tick(t, true)
ok(P.active["Test Proc"] and P.active["Test Strike"], "the try shows every proc")
P.Tick(t + 9, true)
ok(not P.testing and next(P.active) == nil, "and ends by itself")

G.custom = keepCustom
rawset(_G, "C_UnitAuras", keepUA)
rawset(_G, "C_Spell", keepCS)
P.book = keepBook
P.Refresh()
