-- pfUI Octo: target range (modules/range.lua, range-options.lua), run by tests\run.lua: the colour bands,
-- the look switches, and that the frame is always wide enough for its text.
local ok = octo_ok
local RG = pfUI.range
ok(RG and RG.Colour and RG.Distance and RG.Layout and RG.Widest, "range loaded (pfUI.range)")
if not RG then return end
local S = pfUI_config.range
ok(S and S.enable == "1" and S.melee == "5" and S.source == "edge" and S.arrow == nil, "range defaults (no arrow any more)")
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
ok(Col(nil) == Col(50), "a band without a number counts as the out of range colour")

-- the look: every part is a switch, the frame is as big as what is on
local f = RG.frame
S.box, S.trend, S.unit, S.scale, S.fontsize, S.decimals = "1", "1", "1", "100", "16", "1"
RG.Layout()
local fullW, fullH = f:GetWidth(), f:GetHeight()
ok(f.backdrop == nil or f.backdrop:IsShown(), "the full box has its backdrop")
S.box, S.trend, S.unit = "0", "0", "0"
RG.Layout()
ok(f:GetWidth() < fullW and f:GetHeight() < fullH, "only the number: a smaller frame (" .. f:GetWidth() .. " x " .. f:GetHeight() .. ")")
ok(f.backdrop == nil or not f.backdrop:IsShown(), "no box: no backdrop")
S.fontsize = "32"
RG.Layout()
ok(f:GetHeight() > 32, "a bigger font makes a bigger frame")

-- the text always fits: the frame is at least as wide as the widest text it can show
S.box, S.trend, S.unit, S.fontsize = "1", "1", "1", "16"
for _, dec in ipairs({ "0", "1", "2" }) do
  S.decimals = dec
  RG.Layout()
  local w = RG.Widest()
  ok(f:GetWidth() >= w + 16, "decimals " .. dec .. ": the frame (" .. f:GetWidth() .. ") holds the widest text (" .. w .. ")")
end
S.decimals = "1"
RG.Layout()

-- the one colour read as numbers
S.colormode, S.textcolor = "fixed", "0.50,0.60,0.70,1"
local r, g, b = RG.Fixed()
ok(math.abs(r - .5) < .01 and math.abs(g - .6) < .01 and math.abs(b - .7) < .01, "one colour read as numbers")
S.colormode = "range"
S.box, S.trend, S.unit, S.fontsize = "1", "1", "1", "16"
RG.Layout()
