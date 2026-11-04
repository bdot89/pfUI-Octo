-- pfUI Octo: automatic area looting (modules/autoloot.lua, autoloot-log.lua), run by tests\run.lua.
-- The state machine with a made-up ClassicAPI: when a pass starts, what holds it back,
-- and the log fed from loot messages.
local ok = octo_ok
local AL = pfUI.autoloot
ok(AL and AL.Step and AL.Want and AL.Blocked, "autoloot loaded (pfUI.autoloot)")
if not AL then return end
local S = pfUI_config.autoloot
ok(S and S.enable == "0" and S.death == "1" and S.deathdist == "8", "autoloot defaults (off, death on, 8 yd)")
local O = pfUI.octoui and pfUI.octoui.Options
ok(O and O.BUILD and O.BUILD.autoloot, "options page Auto Loot registered")

local st = AL.state
local saved = { C_Loot = rawget(_G, "C_Loot"), GetUnitSpeed = rawget(_G, "GetUnitSpeed"), UnitIsDeadOrGhost = rawget(_G, "UnitIsDeadOrGhost"),
  UnitAffectingCombat = rawget(_G, "UnitAffectingCombat"), GetNetStats = rawget(_G, "GetNetStats") }
local calls, scanning = 0, false
_G.C_Loot = { LootAllCorpses = function() calls = calls + 1 scanning = true return true end, IsScanInProgress = function() return scanning end }
local speed, dead, combat = 0, false, false
_G.GetUnitSpeed = function() return speed end
_G.UnitIsDeadOrGhost = function() return dead end
_G.UnitAffectingCombat = function() return combat end
_G.GetNetStats = function() return 0, 0, 40, 40 end
local function reset() st.want, st.due, st.walking, st.manual, st.cast, st.settleUntil, st.wasMoving = nil, nil, nil, nil, nil, 0, nil end
local function T(t) Mock.now = t end

S.enable = "0"
reset() T(100)
AL.Want("death", 0) T(101) AL.Step(101, false)
ok(calls == 0 and AL.Blocked() == "off", "off: nothing is looted")

S.enable = "1"
reset() calls = 0 scanning = false T(200)
AL.Want("death", .25) AL.Step(200.1, false)
ok(calls == 0, "a death waits its delay")
AL.Step(200.4, false)
ok(calls == 1 and st.walking, "after the delay one pass starts")
AL.Step(200.5, false)
ok(calls == 1, "no second pass while the scan runs")
scanning = false T(201) AL.Step(201, false)
ok(not st.walking and st.settleUntil > 201, "a finished scan ends the walk and settles")
AL.Want("death", .1) AL.Step(201.2, false)
ok(calls == 1, "a new death waits for the settle time")
AL.Step(202.6, false)
ok(calls == 2, "...then gets its pass")

-- moving, casting, a held loot window, combat
reset() calls = 0 scanning = false T(300)
AL.Want("death", .1)
AL.Step(300.2, true)
ok(calls == 0 and st.due == nil, "moving cancels the start but keeps the request")
AL.Step(300.3, false) AL.Step(300.6, false)
ok(calls == 1, "after stopping the kept request is done")
reset() calls = 0 scanning = false T(400)
st.manual = true AL.Want("death", .1) AL.Step(400.5, false)
ok(calls == 0 and AL.Blocked() == "your loot window is open", "your own loot window holds it back")
st.manual = nil st.cast = 400 AL.Step(400.6, false)
ok(calls == 0 and AL.Blocked() == "casting", "a cast holds it back")
st.cast = nil combat = true S.combat = "0" AL.Step(400.7, false)
ok(calls == 0 and AL.Blocked() == "combat", "combat holds it back when switched off")
combat = false AL.Step(400.8, false)
ok(calls == 1, "combat over: the pass runs")
S.combat = "1"

-- stop trigger: coalesced in the same spot
reset() calls = 0 scanning = false st.stopAt = nil T(500)
S.stop = "1"
AL.Step(500, true) AL.Step(500.1, false)
ok(st.want == "retry" or st.want == "stop", "stopping asks for a pass")
AL.Step(500.4, false)
ok(calls == 1, "the stop pass runs after its delay")
scanning = false AL.Step(501, false)

-- death distance
reset() calls = 0 st.want = nil
_G.UnitDistanceSquared = function() return 400, true end
AL.OnDeath("0xabc")
ok(st.want == nil, "a death 20 yards away is ignored")
_G.UnitDistanceSquared = function() return 25, true end
AL.OnDeath("0xabc")
ok(st.want == "death", "a death 5 yards away counts")
_G.UnitDistanceSquared = nil

-- the log
AL.Clear()
local n = table.getn(st.events)
AL.OnLootMessage("You receive loot: |cffffffff|Hitem:2589:0:0:0|h[Linen Cloth]|h|r.")
AL.OnLootMessage("You receive loot: |cffffffff|Hitem:2589:0:0:0|h[Linen Cloth]|h|rx3.")
AL.OnLootMessage("Bob receives loot: |cffffffff|Hitem:2589:0:0:0|h[Linen Cloth]|h|r.")
ok(st.count == 4 and st.items["Linen Cloth"] and st.items["Linen Cloth"].count == 4, "the log counts your own loot only (1 + 3)")
AL.Sample()
ok(st.money == 1234 and table.getn(st.events) == 6, "sample rows land in the log")
AL.ShowLog(true) AL.RefreshLog()
ok(pfAutoLootLog and pfAutoLootLog:IsShown(), "the log window opens")
S.combine = "1" AL.RefreshLog() S.combine = "0"
AL.ShowLog(false) AL.Clear()
ok(st.count == 0 and st.money == 0, "clear empties the log")

for k, v in pairs(saved) do _G[k] = v end
reset()
