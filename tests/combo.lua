-- pfUI Octo: combo points (modules/combo.lua, combo-options.lua), run by tests\run.lua.
local ok = octo_ok
local CB = pfUI.combo
local P = pfUI.plates
ok(CB and CB.Draw and CB.Track and CB.STYLES and P and P.Combo, "combo points loaded (pfUI.combo)")
if not CB then return end
local S = pfUI_config.plates
ok(S.cpplate == "1" and S.cpgain == "pop" and S.cpanim5 == "glow" and S.cpspend == "fade" and S.cpbar == "0",
  "defaults: on the plate, pop in, glow at five, fade when spent, no screen bar")

-- every style's picture exists
local function exists(rel)
  local f = io.open(octo_dir .. "/img/plates/" .. rel .. ".tga", "rb")
  if f then f:close() end
  return f ~= nil
end
local missing = {}
for _, st in ipairs(CB.STYLES) do if st[3] and not exists(st[3]) then table.insert(missing, st[3]) end end
ok(table.getn(missing) == 0 and table.getn(CB.STYLES) >= 16, "every style's picture exists (" .. table.concat(missing, ", ") .. ")")
ok(P.CPSTYLE.skull == "cp-skull", "plates.lua knows the new shapes")

-- colours
S.cpcolor, S.cpc3 = "points", "0,1,0,1"
local r, g, b = CB.Color(3, 3)
ok(r == 0 and g == 1 and b == 0, "a colour for each point")
S.cpfull, S.cpfullcolor = "1", "0,0,1,1"
r, g, b = CB.Color(2, 5)
ok(r == 0 and g == 0 and b == 1, "all one colour at five")
S.cpfull, S.cpcolor = "0", "gradient"

-- what changed: new points, five, spent
local o = {}
CB.Track(o, 2, 10)
ok(o.cpgain[1] == 10 and o.cpgain[2] == 10 and not o.cpfullAt, "two new points noted")
CB.Track(o, 5, 11)
ok(o.cpgain[5] == 11 and o.cpfullAt == 11, "five noted")
CB.Track(o, 0, 12)
ok(o.cpspendAt == 12 and o.cpspendN == 5, "spent noted")
-- animations
local sc = CB.Anim({ cpgain = { 10 } }, 1, 10.17, 1)
ok(sc > 1.3, "a new point pops (" .. sc .. ")")
ok(CB.Moving({ cpgain = { 10 } }, 10.1, 1) and not CB.Moving({ cpgain = { 10 } }, 12, 1), "moving only while it animates")
-- the arc lifts the middle
local pl = CB.Places(5, 10, 2, "arc")
ok(pl[3][2] > pl[1][2] and pl[1][2] == pl[5][2], "arc: the middle point highest")

-- drawing on a stand-in plate (every style, gain, five, spend)
local holder = CreateFrame("Frame", nil, UIParent)
local hb = CreateFrame("StatusBar", nil, holder)
hb:SetWidth(120) hb:SetHeight(10)
local d = {}
CB.Build(holder, d, 5)
local bad
for _, st in ipairs(CB.STYLES) do
  S.cpstyle = st[1]
  for _, n in ipairs({ 0, 3, 5, 0 }) do
    CB.Track(d, n, 20 + n)
    local good, err = pcall(CB.Draw, d, n, 20.1 + n, hb, "BOTTOM", 0, -8, 12, 3, 20)
    if not good then bad = st[1] .. ": " .. tostring(err) end
  end
end
ok(not bad, "every style draws at 0, 3, 5 and spent" .. (bad and (" (" .. bad .. ")") or ""))
S.cpstyle = "numbers"
CB.Track(d, 4, 30)
CB.Draw(d, 4, 30.5, hb, "BOTTOM", 0, -8, 12, 3, 20)
ok(d.cpnum:IsShown() and d.cpnum:GetText() == "4" and not d.cp[1]:IsShown(), "Big number: only the number")
S.cpstyle = "orbs"
S.cptext = "1"
CB.Draw(d, 3, 31, hb, "BOTTOM", 0, -8, 12, 3, 20)
ok(d.cpnum:IsShown() and d.cpnum:GetText() == "3" and d.cp[1]:IsShown(), "the count beside the points")
S.cptext = "0"

-- the screen bar follows its switch
ok(getglobal("pfComboBar") == CB.bar, "the screen bar exists (a layout mode box)")
S.cpbar = "0"
ok(not CB.BarWanted(), "screen bar off by default")
S.cpbar = "1"
S.cpbarshow = "always"
ok(CB.BarWanted(), "on and set to always: it shows")
S.cpbar, S.cpbarshow = "0", "target"

-- the options tab
local O = pfUI.octoui and pfUI.octoui.Options
ok(O and O.BUILD and O.BUILD.npcombo, "Nameplates > Combo points tab registered")
local good, err = pcall(function() O:Page("npcombo") end)
ok(good, "the Combo points tab builds" .. (good and "" or (": " .. tostring(err))))
