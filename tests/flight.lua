-- pfUI Octo: flight timer (modules/flight.lua, flight-options.lua), run by tests\run.lua.
-- The route from ClassicAPI's flight paths and from the plain taxi map, where you are on
-- the path, taking off / landing / timing, a reload in the air, shared times, the bar.
local ok = octo_ok
local FL = pfUI.flight
ok(FL and FL.Plan and FL.Paint and FL.Tick, "flight timer loaded (pfUI.flight)")
if not FL then return end
local O = pfUI.octoui and pfUI.octoui.Options
ok(O and O.BUILD and O.BUILD.flight, "options page Flight timer registered")
local S = pfUI_config.flight
ok(S and S.enable == "1" and S.width == "420" and S.stops == "1", "defaults (C.flight)")
ok(getglobal("pfFlightBar") and rawget(_G, "SLASH_PFFLIGHT1") == "/flight", "the bar's frame and /flight")
ok(FL.Clock(63) == "1:03" and FL.Clock(0) == "0:00" and FL.Clock(600) == "10:00", "times as m:ss")

local keep = {}
for _, k in ipairs({ "C_TaxiMap", "UnitOnTaxi", "UnitPosition", "GetTime", "time", "NumTaxiNodes", "TaxiNodeName", "TaxiNodeGetType",
                     "TaxiNodePosition", "GetNumRoutes", "TaxiGetSrcX", "TaxiGetSrcY", "TaxiGetDestX", "TaxiGetDestY", "SendAddonMessage", "IsInGuild" }) do
  keep[k] = rawget(_G, k)
end
local cache = {}
for _, k in ipairs({ "flighttimes", "flightnow", "flightrate", "flightcut" }) do cache[k] = pfUI_cache[k] pfUI_cache[k] = nil end
local now, wall = 5000, 900000
_G.GetTime = function() return now end
_G.time = function() return wall end
local flying = false
_G.UnitOnTaxi = function() return flying end

-- ClassicAPI: Orgrimmar (23) -> Crossroads (25) -> Ratchet (80); two legs of 1600 and 960 yards
local px, py = 0, 0
_G.C_TaxiMap = {
  GetTaxiNodesForMap = function() return { { nodeID = 23, name = "Orgrimmar, Durotar" }, { nodeID = 25, name = "Crossroads, The Barrens" },
    { nodeID = 80, name = "Ratchet, The Barrens" } } end,
  GetTaxiPaths = function() return { { pathID = 1, fromNodeID = 23, toNodeID = 25, cost = 50 }, { pathID = 2, fromNodeID = 25, toNodeID = 80, cost = 50 } } end,
  GetTaxiPathWaypoints = function(id)
    if id == 1 then return { { x = 0, y = 0, z = 0 }, { x = 800, y = 0, z = 0 }, { x = 1600, y = 0, z = 0 } } end
    if id == 2 then return { { x = 1600, y = 0, z = 0 }, { x = 1600, y = 960, z = 0 } } end
  end,
  GetTaxiRoute = function(slot) if slot == 3 then return { 23, 25, 80 } end if slot == 2 then return { 23, 25 } end end,
}
_G.UnitPosition = function() return px, py, 0 end
FL.nodes, FL.paths = nil, nil
ok(FL.HasPaths(), "ClassicAPI's flight paths are seen")
local plan = FL.Plan(3)
ok(plan and table.getn(plan.names) == 3 and plan.names[2] == "Crossroads, The Barrens" and plan.key == "Orgrimmar, Durotar>Ratchet, The Barrens",
  "the route: three flight points by name")
-- (25 Nov 2026, Javelin: "Flight point 2 ... Flight point 82") a node the map list lacks gets its name from GetAllTaxiNodes
do
  local forMap = _G.C_TaxiMap.GetTaxiNodesForMap
  _G.C_TaxiMap.GetTaxiNodesForMap = function() return { { nodeID = 23, name = "Orgrimmar, Durotar" } } end
  _G.C_TaxiMap.GetAllTaxiNodes = function() return { { nodeID = 25, name = "Crossroads, The Barrens" }, { nodeID = 80, name = "Ratchet, The Barrens" } } end
  FL.nodes = nil
  local p2 = FL.Plan(3)
  ok(p2 and p2.names[2] == "Crossroads, The Barrens" and p2.names[3] == "Ratchet, The Barrens", "names from every node of the open flight map, not numbers")
  _G.C_TaxiMap.GetTaxiNodesForMap, _G.C_TaxiMap.GetAllTaxiNodes = forMap, nil
  FL.nodes = nil
end
ok(plan and plan.length == 2560 and math.abs(plan.fracs[2] - 1600 / 2560) < .001 and plan.fracs[3] == 1, "the path's length, the stop at its real place")
ok(plan and plan.exact and math.abs(plan.est - 2560 / 32 * .97) < .01 and plan.total == plan.est, "its time before it was ever flown (32 yd/s, corners cut)")
local one = FL.Plan(2)
ok(one and one.cut == 1 and one.est == 50, "one hop: 1600 yd = 50 s")
ok(FL.Plan(9) == nil, "no route: no plan")

-- where you are on the path, whichever way round the client gives the two numbers
ok(FL.Along(plan, 400, 3) == 400, "a quarter down the first leg")
ok(math.abs(FL.Along(plan, 1605, 480) - 2080) < .01, "on the second leg")
ok(math.abs(FL.Along(plan, 1000, 0) - 2080) < .01, "never backwards")
local p2 = FL.Plan(3)
ok(math.abs(FL.Along(p2, 480, 1600) - 2080) < .01 and p2.swap == true, "x and y swapped by the client: found all the same")

-- taking off (TakeTaxiNode is wrapped), flying, landing
pfUI_cache.flighttimes = {}
FL.Capture(3)
ok(FL.pending and FL.pending.key == plan.key and not FL.now, "clicking a destination keeps its plan")
FL.Tick(now)
ok(not FL.now, "not started until you are in the air")
flying = true
now = now + 1
FL.Tick(now)
ok(FL.now and FL.now.start == now and pfUI_cache.flightnow and pfUI_cache.flightnow.key == plan.key, "in the air: the flight starts and is kept for a reload")
now = now + 20
px, py = 640, 0
local view = FL.View(now)
ok(view and math.abs(view.prog - .25) < .001 and math.abs(view.left - (1920 / 32 * .97)) < .01 and not view.guess, "20 s in: a quarter of the way, time left from the path")
local bar = FL.NewBar(UIParent)
FL.Paint(bar, view)
ok(bar.time:GetText() == "0:58" and bar.from:GetText() == "Orgrimmar, Durotar" and bar.to:GetText() == "Ratchet, The Barrens"
  and bar.ticks[1] and bar.ticks[1].text:GetText() == "Crossroads, The Barrens" and bar.you:IsShown(), "the bar: time, both ends, the stop, you (" .. tostring(bar.time:GetText()) .. ")")
local _, _, _, yx = bar.you:GetPoint(1)
ok(math.abs(yx - (50 + 420 * .25)) < .01, "the marker a quarter along the line (" .. tostring(yx) .. ")")
S.short, S.stops = "1", "0"
FL.Paint(bar, view)
ok(bar.to:GetText() == "Ratchet" and not bar.ticks[1].mark:IsShown(), "short names; stops off")
S.short, S.stops = "0", "1"

-- a /reload in the air: picked up from the wall clock
local startWas = FL.now.start
FL.now, FL.pending = nil, nil
wall = wall + 20
FL.Tick(now)
ok(FL.now and FL.now.partial and math.abs(FL.now.start - (now - 20)) < .01 and FL.now.plan.names[3] == "Ratchet, The Barrens", "after a reload the flight carries on")
view = FL.View(now)
ok(view and view.prog and view.prog > .2 and view.prog < .3 and view.left, "by the clock: " .. tostring(view and view.prog))

-- landing: timed and kept; the next flight uses it
local sent = {}
_G.SendAddonMessage = function(prefix, msg, chan) table.insert(sent, { prefix, msg, chan }) end
_G.IsInGuild = function() return 1 end
now = now + 56
flying = false
FL.Tick(now)
ok(not FL.now and pfUI_cache.flightnow == nil and pfUI_cache.flighttimes[plan.key] == 76, "landed: the flight took 76 s and is remembered (" .. tostring(pfUI_cache.flighttimes[plan.key]) .. ")")
ok(sent[1] and sent[1][1] == "pfFT" and sent[1][2] == plan.key .. "^76" and sent[1][3] == "GUILD", "and told to the guild")
local again = FL.Plan(3)
ok(again.learned == 76 and again.total == 76, "the timed flight beats the estimate")
ok(FL.Receive("Auberdine, Darkshore>Rut'theran Village, Teldrassil^94.5", "Khijazi") == true and pfUI_cache.flighttimes["Auberdine, Darkshore>Rut'theran Village, Teldrassil"] == 94.5,
  "another player's time is taken for a route you have not flown")
ok(FL.Receive(plan.key .. "^10", "Khijazi") == false and pfUI_cache.flighttimes[plan.key] == 76 and FL.Receive("rubbish", "Khijazi") == false
  and FL.Receive("A>B^99999", "Khijazi") == false, "not over your own, and nothing malformed")
-- a wrong-looking flight (logged out half way) is not kept
FL.Capture(2)
flying = true
FL.Tick(now)
now = now + 9
flying = false
FL.Tick(now)
ok(pfUI_cache.flighttimes["Orgrimmar, Durotar>Crossroads, The Barrens"] == nil, "a flight far off its expected time is not remembered")

-- without ClassicAPI: the taxi map's own lines
_G.C_TaxiMap = nil
_G.UnitPosition = nil
FL.nodes, FL.paths = nil, nil
local NODES = { { "Orgrimmar, Durotar", "CURRENT", .6, .7 }, { "Crossroads, The Barrens", "REACHABLE", .5, .5 }, { "Ratchet, The Barrens", "REACHABLE", .6, .4 } }
_G.NumTaxiNodes = function() return 3 end
_G.TaxiNodeName = function(i) return NODES[i] and NODES[i][1] end
_G.TaxiNodeGetType = function(i) return NODES[i] and NODES[i][2] end
_G.TaxiNodePosition = function(i) return NODES[i][3], NODES[i][4] end
_G.GetNumRoutes = function(slot) return slot == 3 and 2 or 1 end
local LEGS = { { 1, 2 }, { 2, 3 } }
_G.TaxiGetSrcX = function(slot, r) return NODES[slot == 3 and LEGS[r][1] or 1][3] end
_G.TaxiGetSrcY = function(slot, r) return NODES[slot == 3 and LEGS[r][1] or 1][4] end
_G.TaxiGetDestX = function(slot, r) return NODES[slot == 3 and LEGS[r][2] or slot][3] end
_G.TaxiGetDestY = function(slot, r) return NODES[slot == 3 and LEGS[r][2] or slot][4] end
pfUI_cache.flighttimes = {}
local plain = FL.Plan(3)
ok(plain and not plain.exact and table.getn(plain.names) == 3 and plain.names[2] == "Crossroads, The Barrens" and plain.fracs[2] > .5 and plain.fracs[2] < .7,
  "plain client: the stops from the flight map's route lines")
ok(plain and plain.total == nil, "no time yet for a route never flown")
FL.Capture(3)
flying = true
FL.Tick(now)
view = FL.View(now + 5)
FL.Paint(bar, view)
ok(view.prog == nil and bar.time:GetText() == "0:05" and not bar.you:IsShown(), "unknown length: the time flown so far, no marker")
now = now + 80
flying = false
FL.Tick(now)
ok(pfUI_cache.flighttimes[plain.key] == 80 and pfUI_cache.flightrate and pfUI_cache.flightrate > 0, "flown once: remembered, and the map's scale learnt")
local guess = FL.Plan(2)
ok(guess and guess.est and guess.est > 20 and guess.est < 60, "another route: a guess from the map distance (" .. tostring(guess and guess.est) .. ")")

-- the made-up flight for the preview and layout mode
view = FL.Sample(1000)
ok(view.prog > 0 and view.prog < 1 and table.getn(view.names) == 3, "a sample flight for the preview")
local good, err = pcall(FL.Update, now)
ok(good, "the on-screen bar updates " .. tostring(err or ""))

FL.now, FL.pending, FL.nodes, FL.paths = nil, nil, nil, nil
for _, k in ipairs({ "flighttimes", "flightnow", "flightrate", "flightcut" }) do pfUI_cache[k] = cache[k] end
for k, v in pairs(keep) do _G[k] = v end
for _, k in ipairs({ "C_TaxiMap", "UnitPosition" }) do if keep[k] == nil then _G[k] = nil end end
bar:Hide()
