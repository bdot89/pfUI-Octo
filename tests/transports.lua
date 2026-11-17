-- pfUI Octo: boats and zeppelins on the world map (modules/transports.lua), run by tests\run.lua.
local ok = octo_ok
local TR = pfUI.transports
ok(TR and TR.routes and TR.At and TR.Match, "transports loaded (pfUI.transports)")
if not TR or not TR.routes[72] then return end
ok(pfUI_config.appearance.worldmap.transports == "1", "transports default on")
local n = 0
for id, r in pairs(TR.routes) do
  n = n + 1
  ok(r.period > 120 and table.getn(r.stops) >= 2 and table.getn(r.legs) > 3, "route " .. id .. " has stops, legs and a loop time")
end
ok(n == 14, "14 transport routes (" .. n .. ")")
local r = TR.routes[72]
ok(r.docks[1] == "Ratchet" and r.docks[2] == "Booty Bay", "Ratchet - Booty Bay dock names")
-- at a stop for its delay, then moving
local s = r.stops[1]
local map, x, y, moving, stop = TR.At(r, s.t1 + 10)
ok(stop == s and not moving and map == 1, "docked at Ratchet during its stop")
map, x, y, moving = TR.At(r, s.t2 + 5)
ok(moving and map == 1, "moving after the stop")
local nx, wait = TR.Next(r, s.t2 + 5)
ok(nx == r.stops[2] and wait > 0 and wait < r.period, "next stop is Booty Bay")
-- the same spot seen again matches that loop time
local mr, mt = TR.Match(map, x, y)
ok(mr == r and math.abs(mt - (s.t2 + 5)) < 1, "a seen point matches its route and loop time")
-- a sighting fixes the loop; a share moves another player's map
pfUI_cache.transports = {}
TR.Fix(r, 100, 5000, nil, 0)
local t, e = TR.Now(r, 5010)
ok(e and math.abs(t - 110) < .01, "after a sighting the loop time follows the clock")
local msg = TR.Message(72, 5010)
ok(msg and string.find(msg, "^S%^72%^110%.0%^10%^"), "share message: route, loop time, age (" .. tostring(msg) .. ")")
pfUI_cache.transports = {}
TR.Receive(msg, "Friend", 6000)
t, e = TR.Now(r, 6000)
ok(e and e.from == "Friend" and math.abs(t - 110) < .01 and e.seen == 5990, "a shared sighting is taken")
TR.Receive("S^72^5.0^30000^30.00", "Old", 6000)
ok(pfUI_cache.transports[72].from == "Friend", "sightings older than 6 h are ignored")
TR.Receive("S^72^5.0^100^30.00", "Older", 6000)
ok(pfUI_cache.transports[72].from == "Friend", "an older sighting does not replace a newer one")
-- tooltip lines
local lines = TR.Lines(r, 6000)
ok(lines[1] == "Ratchet - Booty Bay" and table.getn(lines) >= 3, "tooltip lines")
-- map spots
local area
for _, a in ipairs(pfUI.transportData.areas) do if a[1] == "Kalimdor" then area = a end end
local u, v = TR.MapSpot(area, 1, s.x, s.y)
ok(u and v and u > .5 and u < 1 and v > .4 and v < .8, "Ratchet lies east-centre on the Kalimdor map")
ok(TR.MapSpot(area, 0, s.x, s.y) == nil, "no spot on the other continent")
-- seeing an object move fixes its route
pfUI_cache.transports = {}
TR.watch = {}
local l = r.legs[3]
TR.Seen(20808, l[2], l[3], 7000, 1)
TR.Seen(20808, l[2] + (l[4] - l[2]) * .1, l[3] + (l[5] - l[3]) * .1, 7001, 2)
ok(pfUI_cache.transports[72] and pfUI_cache.transports[72].t0, "a transport seen moving fixes its route")
pfUI_cache.transports = {}
TR.BuildAll()

-- Deeprun Tram: departures, the gap between them, sharing, map spot
ok(TR.TRAM and TR.TramNext and TR.TramLines, "tram functions")
pfUI_cache.transports = {}
ok(TR.TramNext("Ironforge", 1000) == nil, "tram not timed until a car is seen leaving")
TR.TramDeparted("Ironforge", 1000)
TR.TramDeparted("Ironforge", 1048)
local w2, gap = TR.TramNext("Ironforge", 1060)
ok(gap == 48 and w2 == 36, "tram gap learnt from two departures, next car in 36 s (" .. tostring(w2) .. ")")
local tl = TR.TramLines("Ironforge", 1050)
ok(tl[1] == "Deeprun Tram to Stormwind" and string.find(tl[2], "at the platform"), "tram tooltip says a car is waiting")
pfUI_cache.transports = {}
TR.Receive("T^Stormwind^10^47.5", "Friend", 2000)
local w3, g3, e3 = TR.TramNext("Stormwind", 2000)
ok(e3 and e3.from == "Friend" and g3 == 47.5 and math.abs(w3 - 37.5) < .01, "shared tram timing taken")
local u3 = TR.TramSpot("Ironforge")
ok(u3 and u3 > 0 and u3 < 1, "tram door spot on the Ironforge map")
pfUI_cache.transports = {}

-- a zeppelin standing at its tower puts the map in its wait there
pfUI_cache.transports = {}
TR.watch = {}
local zr = TR.routes[121]
local zs = zr.stops[1]
TR.Seen(164871, zs.x + 3, zs.y - 2, 8000, 10)
TR.Seen(164871, zs.x + 3, zs.y - 2, 8000.5, 10.5)
local zt, ze = TR.Now(zr, 8000.5)
local _, _, _, _, zstop = TR.At(zr, zt)
ok(ze and ze.docked and zstop == zs, "a transport seen standing at a dock is drawn there")
pfUI_cache.transports = {}
TR.watch = {}

-- riding a zeppelin: you moving along its line fast fixes it
pfUI_cache.transports = {}
local rr = TR.routes[121]
local leg
for _, lg in ipairs(rr.legs) do if (lg[9] - lg[8]) > 200 then leg = lg break end end
local savedPos = rawget(_G, "UnitPosition")
local f0 = 0
_G.UnitPosition = function() return leg[2] + (leg[4] - leg[2]) * f0, leg[3] + (leg[5] - leg[3]) * f0, 0 end
TR.ride = {}
for k = 0, 8 do
  f0 = k * 15 / (leg[9] - leg[8])
  TR.Ride(9000 + k * .5, 100 + k * .5)
end
ok(pfUI_cache.transports[121] and pfUI_cache.transports[121].t0, "riding the zeppelin fixes its route")
_G.UnitPosition = savedPos
pfUI_cache.transports = {}
TR.ride = {}

-- timing by hand (16 Nov 2026): arrived then left = the real wait; the same mark a trip later = the real loop
pfUI_cache.transports = {}
TR.BuildAll()
local hr = TR.routes[121]
local guess = hr.period
local learnt = TR.Mark(hr, 1, "arrive", 20000)
ok(learnt == nil, "first mark learns nothing yet")
local ht = TR.Now(hr, 20000)
local _, _, _, _, hs = TR.At(hr, ht)
ok(hs == hr.stops[1], "a mark puts it at that dock")
learnt, hr = TR.Mark(hr, 1, "leave", 20075)
ok(learnt == "wait" and math.abs(hr.stops[1].t2 - hr.stops[1].t1 - 75) < .01, "arrived then left: wait at the dock learnt (75 s)")
local real = guess * 1.2 + 15
learnt, hr = TR.Mark(hr, 1, "leave", 20075 + real)
ok(learnt == "loop" and math.abs(hr.period - real) < .01, "the same mark a trip later: round trip learnt (" .. string.format("%.1f", hr.period) .. ")")
ok(TR.Timed(121) and math.abs(TR.routes[121].stops[1].t2 - TR.routes[121].stops[1].t1 - 75) < .01, "the learnt wait is kept after retiming")
-- after the timing it stays in step trips later
local later = 20075 + real * 5
ht = TR.Now(hr, later)
ok(math.abs(math.mod(ht, hr.period) - hr.stops[1].t2) < .5, "five trips later it leaves the same dock on time")
-- a short speed watch may not undo it
local sp = hr.speed
TR.watch = {}
local hl = hr.legs[3]
TR.Seen(164871, hl[2], hl[3], 30000, 500)
TR.Seen(164871, hl[2] + (hl[4] - hl[2]) * .5, hl[3] + (hl[5] - hl[3]) * .5, 30009, 509)
ok(math.abs(TR.routes[121].speed - sp) < .01, "a timed route keeps its speed")
-- shared: another player takes it unless they timed it themselves
local pm = TR.PeriodMessage(121)
ok(pm and string.find(pm, "^P%^121%^") and string.find(pm, "1:75%.0") and not string.find(pm, "|", 1, true), "period message (" .. tostring(pm) .. ")")
pfUI_cache.transports = {}
TR.BuildAll()
TR.Receive(pm, "Friend", 31000)
ok(TR.Timed(121) and math.abs(TR.routes[121].period - real) < .2 and pfUI_cache.transports[121].periodFrom == "Friend", "a shared round trip is taken")
ok(TR.PeriodMessage(121) == nil, "a shared timing is not passed on")
TR.Receive("P^121^999.0^-", "Other", 31001)
ok(math.abs(TR.routes[121].period - 999) < .2, "a newer shared timing replaces a shared one")
TR.MenuPick(121, "forget")
ok(not TR.Timed(121) and math.abs(TR.routes[121].period - guess) < .01, "forget puts the guess back")
-- a watched object stopping then starting at a dock marks it
pfUI_cache.transports = {}
TR.BuildAll()
TR.watch = {}
local zs2 = TR.routes[121].stops[2]
TR.Seen(164871, zs2.x - 20, zs2.y, 40000, 900)
TR.Seen(164871, zs2.x - 2, zs2.y, 40001, 900.5)
TR.Seen(164871, zs2.x - 2, zs2.y, 40002, 901)
TR.Seen(164871, zs2.x - 2, zs2.y, 40062, 901.5)
TR.Seen(164871, zs2.x + 4, zs2.y, 40063, 902)
local me = pfUI_cache.transports[121]
ok(me and me.marks and me.marks.arrive2 == 40002 and me.marks.leave2 == 40063, "object watch marks arriving and leaving")
pfUI_cache.transports = {}
TR.watch = {}
TR.BuildAll()

-- the game's battle map is kept shut (octo-context.lua, 16 Nov 2026)
local CX = pfUI.context
ok(CX and CX.ShutBattleMap and pfUI_config.appearance.worldmap.nobattlemap == "1", "battle map switch, on by default")
if CX and CX.ShutBattleMap then
  local savedBM = rawget(_G, "BattlefieldMinimap")
  local shown = true
  _G.BattlefieldMinimap = { IsShown = function() return shown end, Hide = function() shown = false end }
  _G.SHOW_BATTLEFIELD_MINIMAP = "1"
  CX.ShutBattleMap()
  ok(not shown and _G.SHOW_BATTLEFIELD_MINIMAP == "0", "battle map hidden and its saved flag cleared")
  pfUI_config.appearance.worldmap.nobattlemap = "0"
  shown = true
  CX.ShutBattleMap()
  ok(shown, "switch off: the battle map is left alone")
  pfUI_config.appearance.worldmap.nobattlemap = "1"
  _G.BattlefieldMinimap = savedBM
end

-- nothing shared may hold "|": the server rejects it ("Invalid escape code", 15 Nov 2026)
pfUI_cache.transports = {}
TR.Fix(TR.routes[72], 100, 5000, nil, 0)
ok(not string.find(TR.Message(72, 5010), "|", 1, true), "transport messages have no |")
pfUI_cache.transports = {}

-- a client that gives y, x: riding still works and the order is learnt
pfUI_cache.transports = {}
TR.swap = nil
local savedPos2 = rawget(_G, "UnitPosition")
local f1 = 0
_G.UnitPosition = function() return leg[3] + (leg[5] - leg[3]) * f1, leg[2] + (leg[4] - leg[2]) * f1, 0 end
TR.ride = {}
for k = 0, 8 do
  f1 = k * 15 / (leg[9] - leg[8])
  TR.Ride(9500 + k * .5, 200 + k * .5)
end
ok(TR.swap == true and pfUI_cache.transports[121] and pfUI_cache.transports[121].t0, "y, x positions: order learnt and the ride counted")
_G.UnitPosition = savedPos2
TR.swap = nil
pfUI_cache.transportswap = nil
pfUI_cache.transports = {}
TR.ride = {}

-- threat rows hold their order while players are close (meters-window M.SteadyOrder)
local MM = pfUI.meters
if MM and MM.SteadyOrder then
  MM.threatOrder = { "A", "B", "C" }
  local o = MM.SteadyOrder({ { name = "B", perc = 61 }, { name = "A", perc = 60 }, { name = "C", perc = 30 } }, 100)
  ok(o[1].name == "A" and o[2].name == "B", "threat: a 1% lead does not swap rows")
  o = MM.SteadyOrder({ { name = "B", perc = 70 }, { name = "A", perc = 60 }, { name = "C", perc = 30 } }, 100)
  ok(o[1].name == "B", "threat: a clear lead moves up")
  MM.threatOrder = {}
end

-- battleground nameplate filters (plates.lua P.Filtered)
local PL = pfUI.plates
if PL and PL.Filtered then
  local function Plate(r, g, b, name, player)
    local col = { r, g, b }
    return { original = { healthbar = { GetStatusBarColor = function() return col[1], col[2], col[3] end } },
      cache = { name = name, player = player }, parent = {} }
  end
  local oldZone = pfUI.context.Zone
  pfUI.context.Zone = function() return "bg" end
  ok(PL.Filtered(Plate(1, 0, 0, "Guard", "NPC")) == true, "bg: enemy NPC hidden")
  ok(PL.Filtered(Plate(1, 0, 0, "Bob", "PLAYER")) == false, "bg: enemy player kept")
  ok(PL.Filtered(Plate(0, 0, 1, "Ally")) == false, "bg: friendly players kept by default")
  ok(PL.Filtered(Plate(0, 1, 0, "Herald")) == true, "bg: friendly NPC hidden")
  local tp = Plate(1, 0, 0, "Guard", "NPC") tp.istarget = true
  ok(PL.Filtered(tp) == false, "bg: your target is kept")
  -- pets (17 Nov 2026): a friendly pet's bar is blue like a player's; enemy pets known by name without SuperWoW
  local SP = pfUI_config.plates
  local keep = { SP.bg_friendpet, SP.bg_friendplayer, SP.bg_enemypet, SP.bg_enemynpc }
  SP.bg_friendpet, SP.bg_friendplayer, SP.bg_enemypet, SP.bg_enemynpc = "1", "0", "1", "0"
  PL.groupPets = { Wolfie = true } PL.petsAt = GetTime() + 60
  ok(PL.FilterKind(Plate(0, 0, 1, "Wolfie")) == "friendpet", "bg: blue plate of a group pet is a friendly pet")
  ok(PL.Filtered(Plate(0, 0, 1, "Wolfie")) == true, "bg: friendly pet hidden with Friendly pets on")
  ok(PL.Filtered(Plate(0, 0, 1, "Ally")) == false, "bg: friendly player still kept")
  PL.petNames["Felguard Bob"] = true
  ok(PL.FilterKind(Plate(1, 0, 0, "Felguard Bob")) == "enemypet", "bg: enemy pet known by name")
  ok(PL.Filtered(Plate(1, 0, 0, "Felguard Bob")) == true, "bg: enemy pet hidden with only Enemy pets on")
  ok(PL.Filtered(Plate(1, 0, 0, "Guard", "NPC")) == false, "bg: enemy NPC kept with Enemy NPCs off")
  -- other add-ons' frames on a hidden plate go to alpha 0 and come back
  local function Kid(a) local k = { a = a } function k:GetAlpha() return self.a end function k:SetAlpha(v) self.a = v end return k end
  local other, mine = Kid(.8), Kid(1)
  local gp = { GetChildren = function() return mine, other end, EnableMouse = function() end }
  local pp = Plate(0, 0, 1, "Wolfie") pp.parent = gp
  function pp:SetAlpha(v) mine.a = v end
  function pp:GetAlpha() return mine.a end
  gp.nameplate = pp
  -- the plate itself is a child: it must not be noted as someone else's
  local real = gp.GetChildren
  gp.GetChildren = function() return pp, other end
  PL.ApplyFilter(gp, pp)
  ok(other.a == 0 and pp.octoFiltered, "bg filter: another add-on's frame on the plate hidden")
  PL.groupPets = {}
  PL.ApplyFilter(gp, pp)
  ok(other.a == .8 and not pp.octoFiltered, "bg filter: its alpha put back when the plate shows again")
  gp.GetChildren = real
  PL.groupPets = {} PL.petsAt = 0 PL.petNames["Felguard Bob"] = nil
  SP.bg_friendpet, SP.bg_friendplayer, SP.bg_enemypet, SP.bg_enemynpc = keep[1], keep[2], keep[3], keep[4]
  pfUI.context.Zone = function() return "world" end
  ok(PL.Filtered(Plate(1, 0, 0, "Guard", "NPC")) == false, "world: no filtering by default")
  pfUI.context.Zone = oldZone
  local O2 = pfUI.octoui and pfUI.octoui.Options
  ok(O2 and O2.BUILD and O2.BUILD.npbg, "Battlegrounds nameplate page registered")
end
