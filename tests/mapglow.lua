-- pfUI Octo: the minimap's own glow (modules/minimap-style.lua map.GLOWS, img\minimap\glow from
-- tools\MakeMinimapGlows.ps1), run by tests\run.lua. (23 Nov 2026, Javelin: the spell-art glow sat further from
-- the map at the top right than at the bottom left.)
local ok = octo_ok
local MAP = pfUI.minimap
ok(MAP and MAP.GLOWS and MAP.GlowColor and MAP.ApplyGlow, "map glow loaded")
if not (MAP and MAP.GLOWS and MAP.ApplyGlow) then return end
local S = pfUI_config.mapstyle
local keep = {}
for k, v in pairs(S) do keep[k] = v end

-- a TGA's size and the alpha of a pixel (x, y from the bottom left)
local function ReadTga(path)
  local rel = string.gsub(string.gsub(path, "^.-AddOns\\pfUI\\", ""), "\\", "/")
  local f = io.open(octo_dir .. "/" .. rel .. ".tga", "rb")
  if not f then return nil end
  local data = f:read("*a")
  f:close()
  local n = string.byte(data, 13) + 256 * string.byte(data, 14)
  return n, function(x, y) return string.byte(data, 18 + (y * n + x) * 4 + 4) end, string.byte(data, 17)
end

-- every style for every shape, and the sweep, exist as square 32-bit pictures
local SHAPES = { "round", "square", "rounded", "rounder", "squircle", "octagon", "diamond", "corner-tl", "corner-tr", "corner-bl", "corner-br" }
local missing = {}
for _, g in ipairs(MAP.GLOWS) do
  for _, sh in ipairs(SHAPES) do
    local n, _, bits = ReadTga(MAP.GlowTex(g[1], sh))
    if not n or bits ~= 32 then table.insert(missing, g[1] .. "-" .. sh) end
  end
end
ok(table.getn(missing) == 0, "every glow picture exists for every shape" .. (missing[1] and (" (missing " .. table.concat(missing, ", ") .. ")") or ""))
ok(ReadTga(pfUI.media[MAP.GLOWSWEEP.tex]) == 256, "the running light's arc exists")
ok(MAP.GlowTex("soft", "nothing") == MAP.GlowTex("soft", "square"), "an unknown shape falls back to the square's glow")

-- the point of it all: as strong at the top right as at the bottom left (and every other way round)
do
  local n, A = ReadTga(MAP.GlowTex("soft", "round"))
  local F = MAP.GlowSpec("soft")[3]
  local worst = 0
  for _, d in ipairs({ 1.03, 1.08, 1.15 }) do
    local vals = {}
    for q = 0, 3 do
      local ang = math.pi / 4 + q * math.pi / 2
      local x = math.floor((math.cos(ang) * d / F + 1) / 2 * n)
      local y = math.floor((math.sin(ang) * d / F + 1) / 2 * n)
      table.insert(vals, A(x, y))
    end
    worst = math.max(worst, math.max(vals[1], vals[2], vals[3], vals[4]) - math.min(vals[1], vals[2], vals[3], vals[4]))
  end
  ok(worst == 0, "soft round glow: the same strength in all four corners (" .. worst .. ")")
  ok(A(0, 0) == 0 and A(n - 1, n - 1) == 0, "nothing on the picture's outermost pixels (turning never smears)")
end

-- the sizes the code draws at are the generator's (else the glow's edge misses the map's)
do
  local f = io.open(octo_dir .. "/tools/MakeMinimapGlows.ps1", "rb")
  local src = f and f:read("*a") or ""
  if f then f:close() end
  local bad = {}
  for _, g in ipairs(MAP.GLOWS) do
    local _, _, num = string.find(src, g[1] .. " = ([%d%.]+)")
    if not num or math.abs(tonumber(num) - g[3]) > .0001 then table.insert(bad, g[1]) end
  end
  ok(src ~= "" and table.getn(bad) == 0, "map.GLOWS sizes match the generator" .. (bad[1] and (" (" .. table.concat(bad, ", ") .. ")") or ""))
end

-- on the real map: centred on the Minimap, map size * F, under or over it
S.shape, S.glow, S.glowabove, S.glowanim, S.glowcolormode = "round", "soft", "0", "none", "custom"
MAP.ApplyStyle()
local gl = MAP.glow
local w = Minimap:GetWidth()
local pt, rel = gl.down:GetPoint()
ok(gl.tex == gl.down and gl.down:IsShown() and not gl.up:IsShown(), "soft glow: under the map")
ok(math.abs(gl.down:GetWidth() - w * 1.24) < .01 and pt == "CENTER" and rel == Minimap, "drawn at the map's size x 1.24, centred on the map")
ok(not gl.sweep:IsShown(), "no running light without the animation")
ok(gl.ticker:GetScript("OnUpdate") == nil, "a still glow needs no ticker")
S.glowabove = "1"
MAP.ApplyStyle()
ok(gl.tex == gl.up and gl.up:IsShown() and not gl.down:IsShown(), "over the map when asked")
S.glowabove, S.glow = "0", "inner"
MAP.ApplyStyle()
ok(gl.tex == gl.up, "inner glow is always over the map")
S.glow = "none"
MAP.ApplyStyle()
ok(gl.tex == nil and not gl.up:IsShown() and not gl.down:IsShown(), "None: no glow")

-- colours
S.glow, S.glowcolor, S.glowcolor2 = "soft", "1,0,0,0.8", "0,0,1,0.8"
local r, g, b, a = MAP.GlowColor(S, 10, false)
ok(r == 1 and g == 0 and b == 0 and math.abs(a - .8) < .001, "your colour, with its strength")
S.glowcolormode = "shift"
S.glowspeed = "4"
local r0, _, b0 = MAP.GlowColor(S, 0, false)
local r2, _, b2 = MAP.GlowColor(S, 2, false)
ok(r0 > .99 and b0 < .01 and r2 < .01 and b2 > .99, "shifting: the first colour, half a cycle later the second")
S.glowcolormode = "rainbow"
local ra, ga, ba = MAP.GlowColor(S, 0, false)
local rb, gb, bb = MAP.GlowColor(S, 5, false)
ok(ra ~= rb or ga ~= gb or ba ~= bb, "rainbow: the colour moves on")
S.glowcolormode = "custom"
S.glowcombat, S.glowcombatcolor = "1", "0,1,0,1"
local cr, cg = MAP.GlowColor(S, 0, true)
ok(cr == 0 and cg == 1, "its own colour in combat")
S.glowcombat = "0"
-- animations: pulse goes down to the dimmest %, never below
S.glowanim, S.glowmin, S.glowspeed = "pulse", "40", "2"
local lo, hi = 1, 0
for i = 0, 40 do
  local _, _, _, x = MAP.GlowColor(S, i * .05, false)
  if x < lo then lo = x end
  if x > hi then hi = x end
end
ok(lo > .8 * .4 - .01 and lo < .8 * .4 + .03 and hi > .79, "pulse: from the dimmest (40%) to full (" .. lo .. " - " .. hi .. ")")
for _, an in ipairs({ "breathe", "heartbeat", "flicker" }) do
  S.glowanim = an
  local bad
  for i = 0, 60 do
    local _, _, _, x = MAP.GlowColor(S, i * .07, false)
    if x < .8 * .4 - .001 or x > .8 + .001 then bad = x end
  end
  ok(not bad, an .. ": stays between the dimmest and full")
end
MAP.ApplyStyle()
ok(gl.ticker:GetScript("OnUpdate") ~= nil, "a moving glow gets its ticker")
-- shown only in / out of combat
S.glowanim, S.glowwhen = "none", "combat"
ok(not MAP.GlowWanted(S, false) and MAP.GlowWanted(S, true), "only in combat")
local va
local probe = { SetVertexColor = function(_, _, _, _, x) va = x end }
MAP.GlowPaint(probe, nil, S, 0, false, 0)
ok(va == 0, "out of combat it is out")
MAP.GlowPaint(probe, nil, S, 0, true, 0)
ok(va and va > .79, "in combat it shows")
S.glowwhen = "always"
-- a ping flashes it brighter
local _, _, _, fa = MAP.GlowColor(S, 0, false, 1)
S.glowanim, S.glowmin = "pulse", "0"
local _, _, _, pa = MAP.GlowColor(S, 1.5, false, 0)
local _, _, _, pf = MAP.GlowColor(S, 1.5, false, 1)
ok(fa > .79 and pf > pa, "a ping flash brightens it")
-- the running light: round maps only
S.glowanim = "sweep"
MAP.ApplyStyle()
ok(gl.sweep:IsShown() and math.abs(gl.sweep:GetWidth() - w * MAP.GLOWSWEEP.F) < .01, "running light on the round map")
S.shape = "square"
MAP.ApplyStyle()
ok(not gl.sweep:IsShown(), "no running light on a square map")

-- looks: the glow ones set it, every other look switches it off
for _, pr in ipairs(MAP.PRESETS) do ok(pr[3].glow ~= nil, "look " .. pr[1] .. " says what the glow does") end
MAP.ApplyPreset("softglow")
ok(S.glow == "soft" and S.shape == "round" and S.art1 == "none", "Soft glow look")
MAP.ApplyPreset("solid")
ok(S.glow == "none", "a plain look takes the glow away")

for k in pairs(S) do S[k] = nil end
for k, v in pairs(keep) do S[k] = v end
MAP.ApplyStyle()
