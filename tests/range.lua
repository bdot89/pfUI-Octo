-- pfUI Octo: target range (modules/range.lua), run by tests\run.lua: the colour bands, the distance
-- fallback, the arrow's direction with a reading of the position numbers, and the frame.
local ok = octo_ok
local RG = pfUI.range
ok(RG and RG.Colour and RG.Distance and RG.Bearing and RG.Calibrate, "range loaded (pfUI.range)")
if not RG then return end
local S = pfUI_config.range
ok(S and S.enable == "1" and S.melee == "5" and S.axis == "6" and S.source == "edge", "range defaults")
local O = pfUI.octoui and pfUI.octoui.Options
ok(O and O.BUILD and O.BUILD.ufrange, "options page Target range registered")
local good, e = pcall(function() O:Page("ufrange") end)
ok(good, "the Target range page builds" .. (good and "" or (": " .. tostring(e))))

-- colour by band
local function Col(d) local r, g, b = RG.Colour(d) return string.format("%.1f %.1f %.1f", r, g, b) end
ok(Col(3) == "0.3 1.0 0.3", "melee: green")
ok(Col(20) == "1.0 0.9 0.2", "spell range: yellow")
ok(Col(35) == "1.0 0.6 0.1" or Col(35) == "1.0 0.5 0.1", "far: orange")
ok(Col(50) == "1.0 0.2 0.2" or Col(50) == "1.0 0.3 0.3", "out of range: red")
ok(Col(nil) == Col(50), "a band without a number counts as out of range colour")

-- the bearing: positions, facing and the reading of the position numbers
local saved = { UnitPosition = rawget(_G, "UnitPosition"), UnitExists = rawget(_G, "UnitExists"), GetUnitSpeed = rawget(_G, "GetUnitSpeed") }
local facing = 0
local pos = { player = { 100, 100 }, target = { 110, 100 } }
_G.UnitExists = function(u) return pos[u] ~= nil end
_G.UnitPosition = function(u) local p = pos[u] return p[1], p[2], 0 end
local hadFacing = RG.Facing
RG.Facing = function() return facing end
S.axis = "1"
-- facing north (0): a target 10 north (x +10) is straight ahead
ok(math.abs(RG.Bearing() or 9) < .01, "ahead")
-- a target 10 to the west (y +10) is on the left: positive
pos.target = { 100, 110 }
ok(math.abs((RG.Bearing() or 0) - math.pi / 2) < .01, "left is positive")
pos.target = { 100, 90 }
ok(math.abs((RG.Bearing() or 0) + math.pi / 2) < .01, "right is negative")
pos.target = { 90, 100 }
ok(math.abs(math.abs(RG.Bearing() or 0) - math.pi) < .01, "behind")
-- calibrating: a client that reports (y, x) swapped is learnt from running forward
for k = 1, 8 do RG.votes[k] = 0 end
S.axis = "1"
_G.GetUnitSpeed = function() return 7 end
facing = math.atan2(1, 3)
local t = 100
pos.player = { 0, 0 }
for i = 1, 14 do
  t = t + .3
  pos.player = { pos.player[1] + 1, pos.player[2] + 3 }  -- running; read as (second, first) that is straight ahead
  RG.Calibrate(t)
end
ok(S.axis == "2", "running forward teaches that the numbers are swapped (reading " .. tostring(S.axis) .. ")")
RG.Facing = hadFacing
for k, v in pairs(saved) do _G[k] = v end
S.axis = "1"

-- "my target is straight ahead" picks the reading
do
  local sv = { UnitPosition = rawget(_G, "UnitPosition"), UnitExists = rawget(_G, "UnitExists") }
  local hf = RG.Facing
  local pos = { player = { 100, 100 }, target = { 110, 140 } }
  _G.UnitExists = function(u) return pos[u] ~= nil end
  _G.UnitPosition = function(u) local p = pos[u] return p[1], p[2], 0 end
  RG.Facing = function() return math.atan2(10, 40) end   -- read as (second, first) the target is straight ahead
  S.axis = "1"
  local good = RG.CalibrateToTarget()
  ok(good and S.axis == "2", "straight ahead teaches the swapped reading (axis " .. tostring(S.axis) .. ")")
  pos.target = { 101, 100.5 }
  ok(not RG.CalibrateToTarget(), "a target right next to you is refused")
  RG.Facing = hf
  for k, v in pairs(sv) do _G[k] = v end
  S.axis = "6"
end

-- the look: every part is a switch, the frame is as big as what is on
do
  local f = RG.frame
  S.box, S.arrow, S.trend, S.unit, S.scale, S.fontsize = "1", "1", "1", "1", "100", "16"
  RG.Layout()
  local fullW, fullH = f:GetWidth(), f:GetHeight()
  ok(f.backdrop == nil or f.backdrop:IsShown(), "the full box has its backdrop")
  S.box, S.arrow, S.trend, S.unit = "0", "0", "0", "0"
  RG.Layout()
  ok(f:GetWidth() < fullW and f:GetHeight() < fullH, "only the number: a much smaller frame (" .. f:GetWidth() .. " x " .. f:GetHeight() .. ")")
  ok(f.backdrop == nil or not f.backdrop:IsShown(), "no box: no backdrop")
  S.fontsize = "32"
  RG.Layout()
  ok(f:GetHeight() > 32, "a bigger font makes a bigger frame")
  S.box, S.arrow, S.trend, S.unit, S.fontsize = "1", "1", "1", "1", "16"
  RG.Layout()
  S.colormode, S.textcolor = "fixed", "0.50,0.60,0.70,1"
  local r, g, b = RG.Fixed()
  ok(math.abs(r - .5) < .01 and math.abs(g - .6) < .01 and math.abs(b - .7) < .01, "one colour read as numbers")
  S.colormode = "range"
end
