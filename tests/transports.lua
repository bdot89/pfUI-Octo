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
