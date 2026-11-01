-- pfUI Octo :: combat text (engine) - moved here from the OctoBG addon
-- (modules/SCT.lua there) on 19 Oct 2026; it runs on sct-core.lua's stand-in
-- for OctoBG's core. pfUI changes: frame names, the five areas are pfUI
-- movers (BuildPanels / PlaceArea / Moved), nothing else.
--
-- Scrolling combat text the way SCT, SCT - Damage, Mik's Scrolling Battle
-- Text, NameplateSCT and ClassicNumbers did it over the years, on one engine:
--   * five screen areas (Incoming, Outgoing, Healing and power, Notifications,
--     Extra), each with its own place, movement, direction, side, size, crit
--     style, speed, height, width, alignment, icon side, font and opacity;
--     placed with Arrange panels or by X / Y
--   * "On the nameplate": the text rises from the other unit's nameplate -
--     damage you deal from your target's (or any enemy's) plate, damage you
--     take from the attacker's. Target / off-target size and opacity, a limit
--     per plate, and a screen area to fall back to when no plate is showing
--   * movements: SCT's Vertical, Rainbow, Horizontal, Angled down / up,
--     Sprinkler, HUD curved / angled; MSBT's Parabola and Static; NameplateSCT's
--     Fountain, Rainfall and Fireworks; ClassicNumbers' Sway, Wave, Zigzag,
--     Spiral, Bounce, Shockwave, Comet and Random
--   * crits: Sticky (SCT: stays in the middle, bigger), Pow (MSBT: slams in),
--     Shake (BlizzSCT's epic crit), Flash (SCT: shrinks from double size into
--     the normal movement) or Normal (just bigger)
-- What to show and where comes from SCTEvents.lua; options are SCTOptions.lua.
--
-- Eviction: at most MAX_LIVE texts on screen (the oldest goes), at most
-- plates.max per nameplate, six stacked messages per static area; texts end
-- after their area's time. The nameplate cache is rebuilt every 0.25 s.

local B = pfUI.sctB
local U = B.U
local CT = { pool = {}, live = {}, nlive = 0, panels = {}, plateOf = {}, plateScanAt = 0, sticky = {}, spr = 18, alt = 1 }
B.SCT = CT

local PI = U.PI
local sin, cos, abs, sqrt, floor, random = math.sin, math.cos, math.abs, math.sqrt, math.floor, math.random
local MAX_LIVE = 90
local EDGE = 10   -- px a clamped nameplate text keeps from the screen edge
local STRAIGHT = { vertical = true, parabola = true, sway = true, wave = true, zigzag = true }

-- ---------------------------------------------------------------- settings

CT.AREA_ORDER = { "inc", "out", "heal", "note", "extra" }
CT.AREA_LABEL = { inc = "Incoming", out = "Outgoing", heal = "Healing and power", note = "Notifications",
                  extra = "Extra", plate = "Nameplate" }

local function Area(x, y, anim, more)
  local a = { enabled = true, x = x, y = y, anim = anim, dir = "up", side = "alt", align = "CENTER", size = 20,
              crit = "sticky", critScale = 1.5, alpha = 1, time = 2.4, height = 180, width = 140, icon = "LEFT",
              font = "", outline = "" }
  for k, v in pairs(more or {}) do a[k] = v end
  return a
end

B.DEFAULTS.sct = {
  enabled = true,
  font = "Fonts\\FRIZQT__.TTF", outline = "OUTLINE", shadow = true,
  -- "octo": as set up here; "blizzard": the game's own damage-number look (its
  -- font, plain numbers, white melee / yellow spells, straight up, crits pop)
  -- on OctoBG's rules (areas, nameplates, filters, sounds)
  style = "octo",
  -- how crits stand out, everywhere: own font / outline / colour, a flash behind
  -- them, a mark ("2468!"), longer on screen
  critLook = { font = "", outline = "THICKOUTLINE", tint = false, r = 1, g = 0.82, b = 0.1,
               glow = true, glowSize = 1, mark = "none", hold = 1.25, numberOnly = false },
  bigScale = 1.4, bigGlow = true,   -- messages ticked "big" on the Messages page
  speed = 1,                       -- all texts: 0.5 = twice as long on screen, 2 = half
  scale = 1,                       -- (pfUI Octo) every text's size times this
  fade = 0.25,                     -- (pfUI Octo) the last part of a text's time it fades out over
  maxLive = 90,                    -- (pfUI Octo) most texts on screen at once
  icons = true, iconScale = 1,
  spellNames = true, schoolNames = false, schoolColors = true, names = false, truncate = "off", truncateLen = 18,
  showResist = true, showGlance = true, overheal = false, healerNames = true, critMark = false, selfHeals = true,
  abbreviate = false, commas = false,
  targetOnly = false, smallScale = 0.75, smallBelow = 0, smallHide = false,
  minDamage = 0, minHeal = 0, minPower = 0,
  lowHp = 40, lowMana = 40,
  merge = true, mergeTime = 0.4, throttlePower = 0, regen = false, fullPower = false,
  cdReadyMin = 8, cdExclude = "", hideAuras = "",
  procs = "Clearcasting, Shadow Trance, Enrage, Flurry, Nightfall, Elemental Focus, Stormstrike, Vengeance, Blood Craze",
  critSound = 0, hugeCrit = 0, killSound = "none", critSoundKey = "TellMessage", hugeCritKey = "RaidWarning",
  plates = { yOffset = 20, xVariance = 0, width = 130, height = 80, size = 18, critScale = 1.6, time = 1.5,
             hit = "fountain", crit = "pow", critMove = "vertical", miss = "vertical", heal = "vertical",
             targetScale = 1.15, offScale = 0.8, offAlpha = 0.6, offTarget = true, max = 8,
             fallback = "out", autoShow = false,
             stack = true,     -- straight movements keep a line apart (AnySCT's line tower)
             merge = true,     -- identical hits on one plate add up in the text already there
             clamp = true },   -- texts of plates at the screen edge stay on screen
  -- teammates' damage on the nameplate of whoever they hit (AnySCT's targetSCTs)
  team = { on = true, who = "party", names = "", pets = true, misses = false, dots = false, onlyTarget = false,
           scale = 0.75, alpha = 0.85, x = 46, classColor = true, r = 1, g = 0.6, b = 0.2, sourceName = false },
  areas = {
    inc = Area(-200, 60, "vertical"),
    out = Area(200, 60, "vertical"),
    heal = Area(0, -150, "vertical", { dir = "down", size = 18 }),
    note = Area(0, 210, "static", { size = 22, time = 3, height = 100, width = 300, crit = "normal", critScale = 1.25 }),
    extra = Area(0, 120, "rainbow", { enabled = false }),
  },
  events = {},                     -- per event: on, r, g, b, area, crit, sound, fmt (SCTEvents.lua)
  imported = nil,
}

-- ---------------------------------------------------------------- movements

-- Each returns the offset (x, y) from the area's origin at progress t (0..1).
-- o.H / o.W: travel height / width, o.s: side (-1 left, 1 right), o.d: 1 up,
-- -1 down, o.r1..o.r3: random numbers 0..1 drawn when the text appears.
local MOVE = {}
CT.MOVE = MOVE

MOVE.vertical = function(o, t) return 0, o.d * t * o.H end
MOVE.static = function(o, t) return 0, o.d * (o.slot or 0) * (o.size + 4) end
MOVE.rainbow = function(o, t)
  return o.s * (20 + t * o.W * 0.6), o.d * (sin(PI * t) * o.H * (0.35 + 0.25 * o.r1) - t * o.H * 0.25)
end
MOVE.horizontal = function(o, t) return o.s * (30 + t * o.W), o.flat and 0 or (o.r1 - 0.5) * o.H * 0.6 end
-- SCT's angled types: out fast, shake, hold, drift away
local function Angled(o, t, up)
  local ax, ay = o.s * o.W * (0.35 + 0.15 * o.r1), (up and 1 or -1) * o.H * (0.25 + 0.1 * o.r2)
  if t < 0.15 then
    local p = t / 0.15
    return ax * p, ay * p
  elseif t < 0.45 then
    return ax + (random() - 0.5) * 3, ay + (random() - 0.5) * 3
  elseif t < 0.65 then
    return ax, ay
  end
  local q = (t - 0.65) / 0.35
  if up then return ax, ay + q * o.H * 0.3 end
  return ax + o.s * q * o.W * 0.25, ay + q * o.H * 0.2
end
MOVE.angledDown = function(o, t) return Angled(o, t, false) end
MOVE.angledUp = function(o, t) return Angled(o, t, true) end
-- SCT's sprinkler: each new text leaves at the next angle of a fan
MOVE.sprinkler = function(o, t)
  local k = o.spr / 18
  local ax, ay = k * o.W * 0.5, o.d * sqrt(1 - k * k) * o.H * 0.5
  local e = (t < 0.3) and (1 - (1 - t / 0.3) * (1 - t / 0.3)) or 1
  if t > 0.75 then e = e + (t - 0.75) * 0.4 end
  return ax * e, ay * e
end
-- SCT's HUD types: up the side of a circle / a slanted line beside the centre
MOVE.hudCurved = function(o, t)
  local half = o.H / 2
  local y = o.d * (t - 0.5) * o.H
  local cx = sqrt(math.max(0, half * half - y * y))
  return -o.s * (cx + o.W * 0.25), y
end
MOVE.hudAngled = function(o, t)
  local y = o.d * (t - 0.5) * o.H
  return -o.s * (o.W * 0.25 + (o.H * 0.5 - y * o.d) * 0.3), y
end
-- MSBT's parabola: bulges out half way up
MOVE.parabola = function(o, t)
  local c = 2 * t - 1
  return o.s * o.W * 0.5 * (1 - c * c), o.d * t * o.H
end
-- NameplateSCT's fountain: an arc out to the side, up then down
MOVE.fountain = function(o, t)
  local peak, low = o.H * (0.2 + 0.5 * o.r2), -o.H * (0.15 + 0.4 * o.r3)
  return o.s * o.W * (0.35 + 0.65 * o.r1) * t, o.d * (4 * peak * t * (1 - t) + low * t * t)
end
MOVE.rainfall = function(o, t)
  return (o.r1 - 0.5) * o.W, -o.H * (0.05 + 0.1 * o.r2) - t * t * o.H * (0.5 + 0.5 * o.r3)
end
MOVE.fireworks = function(o, t)
  local a = o.r1 * 2 * PI
  local dist = o.W * 0.3 + o.H * 0.7 * (1 - (1 - t) * (1 - t))
  return cos(a) * dist, sin(a) * dist
end
-- ClassicNumbers' styles
MOVE.sway = function(o, t) return sin(t * 2 * PI) * o.W * 0.15 * o.s, o.d * t * o.H end
MOVE.wave = function(o, t) return sin(t * 4 * PI) * o.W * 0.2 * o.s, o.d * t * o.H end
MOVE.zigzag = function(o, t)
  local z = abs(math.mod(t * 4, 2) - 1) * 2 - 1
  return z * o.W * 0.18 * o.s, o.d * t * o.H
end
MOVE.spiral = function(o, t)
  local r = o.W * 0.25 * (1 - t * 0.5)
  local a = t * 4 * PI + o.r1 * 2 * PI
  return cos(a) * r, o.d * t * o.H + sin(a) * r * 0.35
end
MOVE.bounce = function(o, t)
  return o.s * t * o.W * 0.25, o.d * (t * o.H * 0.6 + abs(sin(t * 3 * PI)) * o.H * 0.25 * (1 - t))
end
MOVE.shockwave = function(o, t)
  local a = (o.s > 0 and 0 or PI) + (o.flat and 0 or (o.r1 - 0.5) * PI / 1.5)
  local dist = o.W * 0.6 * (1 - (1 - t) * (1 - t) * (1 - t))
  return cos(a) * dist, sin(a) * dist * 0.6
end
MOVE.comet = function(o, t)
  local e = 1 - (1 - t) * (1 - t)
  return o.s * e * o.W * 0.8, o.d * (t * o.H * 0.25 + e * o.H * 0.2)
end

CT.MOVES = {
  { key = "vertical", label = "Vertical (SCT)", tip = "Straight up (or down) the area, one line after another." },
  { key = "rainbow", label = "Rainbow arc (SCT)", tip = "Arcs out to the side and drops, like a rainbow." },
  { key = "horizontal", label = "Horizontal (SCT)", tip = "Slides out sideways at a random height." },
  { key = "angledDown", label = "Angled down (SCT)", tip = "Shoots out and down, shakes, holds, then drifts away." },
  { key = "angledUp", label = "Angled up (SCT)", tip = "Shoots out and up, shakes, holds, then drifts up." },
  { key = "sprinkler", label = "Sprinkler (SCT)", tip = "Each new text leaves at the next angle of a fan." },
  { key = "hudCurved", label = "HUD curved (SCT)", tip = "Runs up the side of a circle round the middle of the screen." },
  { key = "hudAngled", label = "HUD angled (SCT)", tip = "Runs up a slanted line beside the middle of the screen." },
  { key = "parabola", label = "Parabola (MSBT)", tip = "Rises and bulges out half way up, MSBT style." },
  { key = "static", label = "Static (MSBT / messages)", tip = "Stays put; new lines push the older ones along. Good for messages." },
  { key = "fountain", label = "Fountain (NameplateSCT)", tip = "Flies up out to the side and falls, like a fountain." },
  { key = "rainfall", label = "Rainfall (NameplateSCT)", tip = "Falls down from a random spot." },
  { key = "fireworks", label = "Fireworks (NameplateSCT)", tip = "Bursts out in a random direction." },
  { key = "sway", label = "Sway", tip = "Rises with a slow sway from side to side." },
  { key = "wave", label = "Wave", tip = "Rises in a quicker wave." },
  { key = "zigzag", label = "Zigzag", tip = "Rises zigzagging left and right." },
  { key = "spiral", label = "Spiral", tip = "Rises turning in a spiral." },
  { key = "bounce", label = "Bounce", tip = "Bounces up and out to the side." },
  { key = "shockwave", label = "Shockwave", tip = "Blasts out to the side fast, then slows." },
  { key = "comet", label = "Comet", tip = "Streaks out to the side in a curve." },
  { key = "random", label = "Random mix", tip = "A different movement each time, picked at random." },
}
local RANDOM_POOL = { "vertical", "rainbow", "horizontal", "sprinkler", "parabola", "fountain", "rainfall", "sway",
                      "wave", "zigzag", "spiral", "bounce", "comet" }
-- (pfUI Octo, 26 Oct 2026, user: "give crits options for movement same as hits ... it's hard to understand what
-- does what"): a crit's entrance (crit) and how it moves (critPath) are now two settings. Each entry has a tip
-- shown when the mouse is over it in the menu.
CT.CRITS = { { key = "sticky", label = "Pop (SCT Sticky)", tip = "Pops a little bigger for a moment as it appears." },
             { key = "pow", label = "Slam in (MSBT Pow)", tip = "Starts twice as big and slams down to size." },
             { key = "shake", label = "Slam and shake", tip = "Slams in like Pow, then shakes for half a second." },
             { key = "flash", label = "Shrink in from big (SCT Flash)", tip = "Starts twice as big and shrinks to size over a third of a second." },
             { key = "blizzard", label = "Swell and settle (Blizzard)", tip = "The game's own crit: swells fast, then settles a little bigger than a hit." },
             { key = "zoom", label = "Grow from small (Zoom)", tip = "Starts small and grows to size, with a little overshoot." },
             { key = "normal", label = "None, just bigger", tip = "No entrance: the crit is simply bigger than a hit." } }
-- How a crit moves: as the hits of that place, stays put, or any movement.
CT.CRIT_PATHS = { { key = "same", label = "Same as the hits here", tip = "Crits take the hits' movement of this area or nameplate." },
                  { key = "still", label = "Stay in place (SCT Sticky)", tip = "Crits stay where they appear, stacked above and below the middle, then fade." } }
for _, m in ipairs(CT.MOVES) do table.insert(CT.CRIT_PATHS, m) end
-- Settings from before 26 Oct 2026 keep their look: Sticky, Pow and Shake
-- crits stayed in place; a nameplate's crits moved by plates.critMove.
local PINNED = { sticky = true, pow = true, shake = true }
function CT.CritPath(t, plate)
  if not t then return "same" end
  if t.critPath then return t.critPath end
  if PINNED[t.crit] then return "still" end
  if plate then return t.critMove or "same" end
  return "same"
end
CT.MARKS = { { key = "none", label = "No mark" }, { key = "bang", label = "2468!" }, { key = "word", label = "CRIT! 2468" },
             { key = "stars", label = "*2468*" }, { key = "arrows", label = ">> 2468 <<" } }
CT.STYLES = { { key = "octo", label = "pfUI Octo (as set up on these pages)" },
              { key = "blizzard", label = "Blizzard numbers (the game's look, these rules)" } }
-- The game's damage-number font (pfUI may set its own; that is what you see now).
local function GameDamageFont() return DAMAGE_TEXT_FONT or "Fonts\\FRIZQT__.TTF" end
CT.GameDamageFont = GameDamageFont

-- A crit's mark around its text.
function CT.Mark(mark, text)
  if mark == "bang" then return text .. "!" end
  if mark == "word" then return "CRIT! " .. text end
  if mark == "stars" then return "*" .. text .. "*" end
  if mark == "arrows" then return ">> " .. text .. " <<" end
  return text
end
CT.SIDES = { { key = "alt", label = "Alternate left and right", tip = "Each new text goes to the other side." },
             { key = "left", label = "Left", tip = "Every text goes left." },
             { key = "right", label = "Right", tip = "Every text goes right." },
             { key = "random", label = "Random side", tip = "Left or right, picked at random each time." },
             { key = "dmgLeft", label = "Damage left, heals right", tip = "Damage goes left, heals go right." },
             { key = "dmgRight", label = "Damage right, heals left", tip = "Damage goes right, heals go left." } }
CT.ALIGNS = { { key = "LEFT", label = "Left" }, { key = "CENTER", label = "Centre" }, { key = "RIGHT", label = "Right" } }
CT.ICONS = { { key = "LEFT", label = "Left of the text" }, { key = "RIGHT", label = "Right of the text" },
             { key = "NONE", label = "No icon here" } }
CT.DIRS = { { key = "up", label = "Up", tip = "Texts travel upwards." }, { key = "down", label = "Down", tip = "Texts travel downwards." },
            { key = "alt", label = "Up and down, taking turns", tip = "Each new text goes the other way, starting from the middle." } }

-- (26 Oct 2026, user: "horizontal should show left and right ... vertical up and down ... diagonal etc")
-- Which ways each movement can be turned. dir = up / down matters, side = left / right matters (true always,
-- "lean" only when it leans to the side set), flow = "lean" for movements that rise or fall (they can go
-- diagonally) or "drift" for movements that go sideways (they can rise or fall as they go).
CT.AIM = {
  vertical = { dir = true, flow = "lean", side = "lean" }, rainbow = { dir = true, side = true },
  horizontal = { side = true, flow = "drift" }, angledDown = { side = true }, angledUp = { side = true },
  sprinkler = { dir = true }, hudCurved = { dir = true, side = true }, hudAngled = { dir = true, side = true },
  parabola = { dir = true, side = true }, static = { dir = true },
  fountain = { dir = true, side = true }, rainfall = { flow = "lean", side = "lean" }, fireworks = {},
  sway = { dir = true, flow = "lean", side = "lean" }, wave = { dir = true, flow = "lean", side = "lean" },
  zigzag = { dir = true, flow = "lean", side = "lean" }, spiral = { dir = true, flow = "lean", side = "lean" },
  bounce = { dir = true, side = true }, shockwave = { side = true, flow = "drift" }, comet = { dir = true, side = true },
  random = { dir = true, side = true }, still = {}, same = {},
}
CT.LEANS = { { key = "none", label = "Straight", tip = "Straight up or down." },
             { key = "left", label = "Diagonal left", tip = "Slants to the left as it travels." },
             { key = "right", label = "Diagonal right", tip = "Slants to the right as it travels." },
             { key = "side", label = "Diagonal to the side", tip = "Slants to the side picked under Side (alternate, random, damage left...)." } }
CT.DRIFTS = { { key = "random", label = "At a random height", tip = "Each text starts a little higher or lower at random." },
              { key = "level", label = "Level", tip = "Straight across, all at the same height." },
              { key = "rise", label = "Rising (diagonal up)", tip = "Climbs as it goes sideways." },
              { key = "fall", label = "Falling (diagonal down)", tip = "Drops as it goes sideways." } }
CT.ANGLES = { { key = 0.27, label = "Slight (15 degrees)" }, { key = 0.58, label = "Medium (30 degrees)" },
              { key = 1, label = "Steep (45 degrees)" }, { key = 1.73, label = "Very steep (60 degrees)" } }
local function InList(list, k)
  for _, e in ipairs(list) do if e.key == k then return true end end
  return false
end

-- The choices a movement offers, in order: { key = setting, label, options, value, tip }.
-- t = the settings table, crit = read / write its crit keys (critDir...).
function CT.AimControls(move, t, crit)
  local aim = CT.AIM[move] or {}
  local pre = crit and "crit" or ""
  local function K(k) return crit and (pre .. string.upper(string.sub(k, 1, 1)) .. string.sub(k, 2)) or k end
  local function V(k) return crit and (t[K(k)] or t[k]) or t[k] end
  local out = {}
  if aim.dir then
    table.insert(out, { key = K("dir"), label = "Direction", options = CT.DIRS, value = V("dir") or "up",
      tip = "Up, down, or taking turns." })
  end
  local lean = V("lean")
  if aim.flow == "lean" then
    if not InList(CT.LEANS, lean) then lean = "none" end
    table.insert(out, { key = K("lean"), label = "Straight or diagonal", options = CT.LEANS, value = lean,
      tip = "Straight, or slanting left / right as it travels." })
  elseif aim.flow == "drift" then
    if not InList(CT.DRIFTS, lean) then lean = "random" end
    table.insert(out, { key = K("lean"), label = "Height as it goes", options = CT.DRIFTS, value = lean,
      tip = "A random height, level, or rising / falling diagonally." })
  end
  if aim.side == true or (aim.side == "lean" and lean == "side") then
    table.insert(out, { key = K("side"), label = "Side", options = CT.SIDES, value = V("side") or "alt",
      tip = "Left, right, alternate, random, or by damage and heals." })
  end
  if (aim.flow == "lean" and lean ~= "none") or (aim.flow == "drift" and (lean == "rise" or lean == "fall")) then
    local amt = V("leanAmt") or 0.58
    table.insert(out, { key = K("leanAmt"), label = "Angle", options = CT.ANGLES, value = amt,
      tip = "How steep the diagonal is." })
  end
  return out
end
CT.OUTLINES = { { key = "", label = "None" }, { key = "OUTLINE", label = "Outline" }, { key = "THICKOUTLINE", label = "Thick outline" } }

-- ---------------------------------------------------------------- area panels

local container = CreateFrame("Frame", "pfCombatTextContainer", UIParent)
container:SetAllPoints(UIParent)
container:SetFrameStrata("HIGH")
container:EnableMouse(false)

function CT:AreaDB(key)
  return B.db.sct.areas[key]
end

-- Area panels are placed by their centre against the screen centre (x, y);
-- dragging one in Arrange panels writes x / y back.
-- pfUI: the drop position comes from pfUI's saved mover position (anchor +
-- offsets), not from GetCenter: the client may report a moved frame's edges
-- only on the next screen update.
local function Moved(f)
  local a = CT:AreaDB(f.area)
  local pos = pfUI_config.position and pfUI_config.position[f:GetName()]
  if pos and pos.xpos then
    local W, H = GetScreenWidth(), GetScreenHeight()
    local w, h = f:GetWidth(), f:GetHeight()
    local p = pos.anchor or "TOPLEFT"
    local px = strfind(p, "LEFT") and 0 or strfind(p, "RIGHT") and W or W / 2
    local py = strfind(p, "BOTTOM") and 0 or strfind(p, "TOP") and H or H / 2
    local dx = strfind(p, "LEFT") and -w / 2 or strfind(p, "RIGHT") and w / 2 or 0
    local dy = strfind(p, "BOTTOM") and -h / 2 or strfind(p, "TOP") and h / 2 or 0
    a.x = floor(px + pos.xpos - dx - W / 2 + 0.5)
    a.y = floor(py + pos.ypos - dy - H / 2 + 0.5)
  else
    local cx, cy = f:GetCenter()
    local ux, uy = UIParent:GetCenter()
    local s = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if cx and ux then
      a.x, a.y = floor(cx * s - ux + 0.5), floor(cy * s - uy + 0.5)
    end
  end
  CT:PlaceArea(f.area)
  if B.Options then B.Options:Refresh() end
end

function CT:PlaceArea(key)
  local f = self.panels[key]
  if not f then return end
  local a = self:AreaDB(key)
  f:SetWidth(math.max(40, a.width))
  f:SetHeight(math.max(20, a.anim == "static" and (a.size + 8) or a.height))
  f.defPoint, f.defX, f.defY = "CENTER", a.x, a.y
  f:ClearAllPoints()
  f:SetPoint("CENTER", UIParent, "CENTER", a.x, a.y)
  -- pfUI mover: x / y are the truth, so drop the mover's saved place and
  -- take this one as its default
  if pfUI_config.position then pfUI_config.position[f:GetName()] = nil end
  if pfUI.api and pfUI.api.UpdateMovable then pfUI.api.UpdateMovable(f, true) end
end

local MOVER_NAME = { inc = "Incoming", out = "Outgoing", heal = "Healing", note = "Notes", extra = "Extra" }

function CT:BuildPanels()
  for i = 1, table.getn(self.AREA_ORDER) do
    local key = self.AREA_ORDER[i]
    local a = self:AreaDB(key)
    local f = U.Panel("pfCombatText" .. (MOVER_NAME[key] or key), "sct_" .. key, "Combat text: " .. self.AREA_LABEL[key], a.width, a.height, "CENTER", a.x, a.y)
    f.area = key
    f.afterMove = Moved
    f.noScale = true
    f:SetScale(1)
    B.db.pos["sct_" .. key] = nil
    self.panels[key] = f
    self:PlaceArea(key)
  end
end

-- Where texts start inside an area: the bottom for upward movement, the top
-- for downward, else the middle.
-- (anim / dir: the text's own, a crit's can differ from its area's)
local function Origin(a, anim, dir)
  anim, dir = anim or a.anim, dir or a.dir
  if anim == "vertical" or anim == "parabola" or anim == "sway" or anim == "wave"
     or anim == "zigzag" or anim == "spiral" then
    if dir == "alt" then return "CENTER" end
    return (dir == "down") and "TOP" or "BOTTOM"
  end
  return "CENTER"
end
CT.Origin = Origin

-- ---------------------------------------------------------------- nameplates

-- GUID -> nameplate frame: ClassicAPI's lookup, else the plates' nampower
-- GUIDs (frame:GetName(1)), rebuilt at most every 0.25 s.
function CT:Plate(guid)
  if not guid then return nil end
  if C_NamePlate and C_NamePlate.GetNamePlateForGUID then
    local ok, p = pcall(C_NamePlate.GetNamePlateForGUID, guid)
    if ok and p and p.IsVisible and p:IsVisible() then return p end
  end
  local p = self.plateOf[guid]
  if p and p:IsVisible() and self:PlateGuid(p) == guid then return p end
  local now = GetTime()
  if now - self.plateScanAt < 0.25 then return nil end
  self.plateScanAt = now
  local map = {}
  local kids = { WorldFrame:GetChildren() }
  for i = 1, table.getn(kids) do
    local k = kids[i]
    if k:IsVisible() then
      local g = self:PlateGuid(k)
      if g then map[g] = k end
    end
  end
  self.plateOf = map
  p = map[guid]
  if p then return p end
  return nil
end

function CT:PlateGuid(f)
  local ok, g = pcall(f.GetName, f, 1)
  if ok and type(g) == "string" and string.sub(g, 1, 2) == "0x" then return g end
  return nil
end

-- ---------------------------------------------------------------- texts

local function Acquire()
  local o = table.remove(CT.pool)
  if o then return o end
  o = {}
  o.fs = container:CreateFontString(nil, "OVERLAY")
  o.icon = container:CreateTexture(nil, "OVERLAY")
  o.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  -- the flash behind crits and "big" messages (burst.tga, tinted, added light)
  o.glow = container:CreateTexture(nil, "ARTWORK")
  o.glow:SetTexture(U.MEDIA .. "burst")
  o.glow:SetBlendMode("ADD")
  o.glow:SetPoint("CENTER", o.fs, "CENTER", 0, 0)
  o.glow:Hide()
  return o
end

local function Release(i)
  local o = CT.live[i]
  o.fs:Hide()
  o.icon:Hide()
  o.glow:Hide()
  if o.stickySlot then CT.sticky[o.stickyKey][o.stickySlot] = nil end
  o.plate, o.guid, o.stickySlot, o.stickyKey = nil, nil, nil, nil
  o.mergeKey, o.rebuild, o.team, o.lane, o.mark, o.hasGlow = nil, nil, nil, nil, nil, nil
  table.remove(CT.live, i)
  CT.nlive = CT.nlive - 1
  table.insert(CT.pool, o)
end

-- A free sticky-crit slot of an area: 0, then alternately above and below.
local function StickySlot(key)
  local s = CT.sticky[key]
  if not s then
    s = {}
    CT.sticky[key] = s
  end
  for i = 0, 7 do
    if not s[i] then return i end
  end
  return random(0, 7)
end

local function Side(sideType, isHeal)
  if sideType == "left" then return -1 end
  if sideType == "right" then return 1 end
  if sideType == "dmgLeft" then return isHeal and 1 or -1 end
  if sideType == "dmgRight" then return isHeal and -1 or 1 end
  if sideType == "random" then return (random() < 0.5) and -1 or 1 end
  CT.alt = -CT.alt
  return CT.alt
end

-- Turns a text the way its settings say (t: area or plate settings, crit: read
-- its own crit keys first): o.d up / down, o.s side, o.lean / o.tilt / o.flat
-- for diagonals. Returns the direction for Origin.
function CT.Aim(o, t, crit, move, isHeal)
  t = t or {}
  local function V(k, ck) return crit and t[ck] or t[k] end
  local dir, side = V("dir", "critDir") or t.dir, V("side", "critSide") or t.side
  local lean, amt = V("lean", "critLean") or t.lean, V("leanAmt", "critLeanAmt") or t.leanAmt or 0.58
  if dir == "alt" then
    CT.altD = -(CT.altD or -1)
    o.d = CT.altD
  else
    o.d = (dir == "down") and -1 or 1
  end
  o.side = Side(side or "alt", isHeal)
  o.s = o.side
  o.lean, o.tilt, o.flat = nil, nil, nil
  local aim = CT.AIM[move]
  if aim and aim.flow == "lean" then
    local L = (lean == "left" and -1) or (lean == "right" and 1) or (lean == "side" and o.s) or nil
    if L then o.lean = L * amt end
  elseif aim and aim.flow == "drift" and (lean == "level" or lean == "rise" or lean == "fall") then
    o.flat = true
    if lean == "rise" then o.tilt = amt elseif lean == "fall" then o.tilt = -amt end
  end
  return dir
end

-- A diagonal on top of a movement's path.
function CT.Bend(o, x, y)
  if o.lean then x = x + o.lean * abs(y) end
  if o.tilt then y = y + o.tilt * abs(x) end
  return x, y
end

-- Older messages of a static area move one line along; more than six: the oldest goes.
local function StackStatic(key)
  local n = 0
  for i = CT.nlive, 1, -1 do
    local o = CT.live[i]
    if o.areaKey == key and o.move == "static" then
      o.slot = (o.slot or 0) + 1
      n = n + 1
      if n >= 6 then Release(i) end
    end
  end
end

-- Straight movements in one lane keep a line's height apart: the ones on
-- screen are pushed on when a new one appears too soon (SCT's MinPoint,
-- AnySCT's line tower on nameplates). Lanes: an area and side, or a plate
-- (your texts and teammates' texts apart).
local function Push(lane, move, gap)
  local newest
  for i = 1, CT.nlive do
    local o = CT.live[i]
    if o.lane == lane and not o.crit then
      if not newest or o.start > newest.start then newest = o end
    end
  end
  if not newest then return end
  local now = GetTime()
  local moved = (now - newest.start) / newest.dur * newest.H
  if moved >= gap then return end
  local shift = (gap - moved) / newest.H * newest.dur
  for i = 1, CT.nlive do
    local o = CT.live[i]
    if o.lane == lane and not o.crit and o.move ~= "pin" and o.move ~= "static" then
      o.start = o.start - shift
    end
  end
end

-- An identical hit on the same plate within mergeTime: added to the text
-- already there (opts.mergeKey, opts.amount, opts.rebuild(total, count)).
local function MergeInto(plate, opts)
  local now = GetTime()
  local window = B.db.sct.mergeTime
  for i = CT.nlive, 1, -1 do
    local o = CT.live[i]
    if o.mergeKey == opts.mergeKey and o.plate == plate and now - o.start <= window then
      o.mtotal, o.mcount = o.mtotal + (opts.amount or 0), o.mcount + 1
      o.fs:SetText(CT.Mark(o.mark, o.rebuild(o.mtotal, o.mcount)))
      return true
    end
  end
  return false
end

-- Shows a text. where: an area key or "plate" (then opts.guid names the unit).
-- opts: crit, icon, guid, kind ("hit" | "crit" | "miss" | "heal"), heal, small, target,
-- team (a teammate's hit: smaller, beside yours, never on a screen area),
-- mergeKey + amount + rebuild(total, count) (identical hits add up on a plate).
function CT:Show(text, r, g, b, where, opts)
  local db = B.db.sct
  if not db.enabled or not text or text == "" then return end
  opts = opts or {}
  local plate, a, areaKey
  if where == "plate" then
    plate = self:Plate(opts.guid)
    if not plate then
      if opts.team then return end
      where = db.plates.fallback
      if where == "hide" then return end
    end
  end
  if plate and opts.mergeKey and db.plates.merge and MergeInto(plate, opts) then return end
  if not plate then
    a = db.areas[where] or db.areas.out
    if not a.enabled then return end
    areaKey = where
  end
  if self.nlive >= (db.maxLive or MAX_LIVE) then Release(1) end
  local team = opts.team and true or nil
  if plate then
    -- at most plates.max texts per plate (yours and teammates' counted apart)
    local n, oldest = 0, nil
    for i = 1, self.nlive do
      local o = self.live[i]
      if o.plate == plate and o.team == team then
        n = n + 1
        if not oldest then oldest = i end
      end
    end
    if n >= db.plates.max and oldest then Release(oldest) end
  end
  local o = Acquire()
  local P = db.plates
  local crit = opts.crit and true or false
  local size, alpha, move, critStyle, dur
  if plate and team then
    -- teammates: a straight column beside yours, smaller and dimmer; crits just bigger
    local T = db.team
    move, critStyle = "vertical", nil
    size = P.size * T.scale * (crit and 1.3 or 1)
    alpha = T.alpha
    dur = P.time
    o.H, o.W = P.height, P.width
    o.areaKey = "plate"
  elseif plate then
    local kind = opts.kind or (crit and "crit" or "hit")
    if kind == "crit" then move = P.hit else move = P[kind] or P.hit end
    critStyle = crit and P.crit or nil
    size = P.size * (crit and P.critScale or 1)
    alpha = 1
    dur = P.time
    if opts.guid and opts.target == false then
      size, alpha = size * P.offScale, P.offAlpha
    elseif opts.target then
      size = size * P.targetScale
    end
    o.H, o.W = P.height, P.width
    o.areaKey = "plate"
  else
    move, critStyle = a.anim, crit and a.crit or nil
    size = a.size * (crit and a.critScale or 1)
    alpha = a.alpha
    dur = a.time
    o.H, o.W = a.height, a.width
    o.areaKey = areaKey
  end
  -- (26 Oct 2026) a crit moves its own way: same as the hits, stays put, or
  -- any movement; with critOwn its own time, travel and direction
  local critT = crit and not team and (plate and P or a) or nil
  local critAim   -- crits with a movement of their own turn their own way
  if critT then
    local path = CT.CritPath(critT, plate and true)
    critAim = critT.critOwn or path ~= "same"
    if path == "still" then move = "pin" elseif path ~= "same" then move = path end
    -- (a notification-style area: crits and big messages take its lines too, or a
    -- killing blow and the XP line under it sat on each other - GratisNinja, 1 Nov 2026)
    if not plate and a and a.anim == "static" and (move == "pin" or move == "static") then move = "static" end
    if critT.critOwn then
      dur = critT.critTime or dur
      o.H, o.W = critT.critHeight or o.H, critT.critWidth or o.W
    end
  end
  if opts.small then size = size * db.smallScale end
  size = size * (db.scale or 1)
  -- Blizzard numbers: straight up from the plate, crits pop and move on
  local blizz = db.style == "blizzard"
  if blizz and plate and not team then
    move = "vertical"
    if crit then critStyle = "blizzard" end
  end
  local L = db.critLook
  local critLook = crit and not team
  if critLook then dur = dur * (L.hold or 1) end
  if opts.big then size = size * (db.bigScale or 1.4) end
  if move == "random" then move = RANDOM_POOL[random(1, table.getn(RANDOM_POOL))] end
  o.move, o.crit, o.critStyle = move, crit, critStyle
  o.size, o.alpha = math.max(6, floor(size + 0.5)), alpha
  o.dur = dur / math.max(0.25, db.speed or 1)
  -- which way: the area's (or plate's) direction, side and diagonal; a crit with its own travel uses its own
  local dir = CT.Aim(o, (not team) and (plate and P or a) or nil, critAim, move, opts.heal)
  o.r1, o.r2, o.r3 = random(), random(), random()
  o.spr = self.spr
  if move == "sprinkler" then
    self.spr = self.spr - 3
    if self.spr < -18 then self.spr = 18 end
  end
  o.plate, o.guid = plate, plate and opts.guid or nil
  o.team = team
  -- (one lane per screen area, not per side: a straight movement puts both sides
  -- on one line, so two texts on different sides overlapped - user, 1 Nov 2026)
  -- (and areas that start at the same spot share one: the mana gain and the heal of one
  -- Vampiric Touch tick went to two areas placed on each other - user, 1 Nov 2026)
  local spot = a and a.x and a.y and (floor(a.x / 24) .. ":" .. floor(a.y / 24)) or areaKey
  o.lane = plate and (tostring(plate) .. (team and ":team" or ":you")) or spot
  o.mergeKey, o.rebuild, o.mtotal, o.mcount = opts.mergeKey, opts.rebuild, opts.amount or 0, 1
  o.clamp = plate and P.clamp
  o.xv = (plate and not team and P.xVariance > 0) and (random() - 0.5) * 2 * P.xVariance or 0
  o.px = team and db.team.x or 0
  -- the anchor point inside the area / above the plate
  o.anchor = plate or self.panels[areaKey]
  o.point = plate and "TOP" or Origin(a, move, dir)
  o.py = plate and P.yOffset or 0
  local fs = o.fs
  local font = (a and a.font ~= "" and a.font) or db.font
  local outline = (a and a.outline ~= "" and a.outline) or db.outline
  if blizz then font, outline = GameDamageFont(), "OUTLINE" end
  o.mark = nil
  if critLook then
    if L.font ~= "" then font = L.font end
    if L.outline ~= "same" then outline = L.outline end
    if L.tint then r, g, b = L.r, L.g, L.b end
    o.mark = L.mark
    if (not o.mark or o.mark == "none") and db.critMark then o.mark = "stars" end
    text = CT.Mark(o.mark, text)
  end
  fs:SetFont(B.SpyData.Font(font, db.font), o.size, outline)
  if db.shadow then
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(1, -1)
  else
    fs:SetShadowOffset(0, 0)
  end
  fs:SetText(text)
  fs:SetTextColor(r or 1, g or 1, b or 1)
  -- the flash behind crits / big messages, sized to the text
  if (critLook and L.glow) or (opts.big and db.bigGlow) then
    local gs = L.glowSize or 1
    o.glowW = math.max((fs:GetStringWidth() or 0) * 1.35, o.size * 2.5) * gs
    o.glowH = o.size * 2.4 * gs
    o.gr, o.gg, o.gb = r or 1, g or 1, b or 1
    o.hasGlow = true
  else
    o.hasGlow = nil
  end
  o.fsPoint = (a and (a.align == "LEFT" or a.align == "RIGHT")) and a.align or "CENTER"
  local iconSide = a and a.icon or "LEFT"
  if db.icons and opts.icon and iconSide ~= "NONE" then
    o.icon:SetTexture(opts.icon)
    local is = o.size * db.iconScale
    o.icon:SetWidth(is)
    o.icon:SetHeight(is)
    o.icon:ClearAllPoints()
    if iconSide == "RIGHT" then o.icon:SetPoint("LEFT", fs, "RIGHT", 3, 0) else o.icon:SetPoint("RIGHT", fs, "LEFT", -3, 0) end
    o.hasIcon = true
  else
    o.hasIcon = false
    o.icon:Hide()
  end
  if move == "pin" then
    o.stickyKey = plate and tostring(plate) or areaKey
    o.stickySlot = StickySlot(o.stickyKey)
    self.sticky[o.stickyKey][o.stickySlot] = true
    local row = math.ceil(o.stickySlot / 2)
    if math.mod(o.stickySlot, 2) == 0 then row = -row end
    o.pinY = row * (o.size + 6)
    if not plate then o.point = "CENTER" end
  elseif move == "static" then
    StackStatic(areaKey)
    o.slot = 0
  -- (1 Nov 2026, GratisNinja: "multiple messages in one area at the same time ... all
  -- lying on top of each other ... like MSBT": every moving style keeps them a line
  -- apart now, not only the straight ones)
  elseif (STRAIGHT[move] or (o.H or 0) > 0) and (not plate or P.stack ~= false) then
    Push(o.lane, move, o.size + (plate and 2 or 4))
  end
  o.start = GetTime()
  table.insert(self.live, o)
  self.nlive = self.nlive + 1
  self:Step(o, o.start)
  fs:Show()
  if o.hasIcon then o.icon:Show() end
  if o.hasGlow then o.glow:Show() else o.glow:Hide() end
  container:SetScript("OnUpdate", CT.OnUpdate)
end

-- Places one text for the time now; false when it is over.
function CT:Step(o, now)
  local e = now - o.start
  if e >= o.dur then return false end
  local t = e / o.dur
  local x, y
  local cs = o.critStyle
  if o.move == "pin" then
    x, y = 0, o.pinY or 0
    if cs == "shake" and e < 0.5 then x = sin(e * 60) * 6 * (1 - e / 0.5) end
  else
    local f = MOVE[o.move] or MOVE.vertical
    x, y = CT.Bend(o, f(o, t))
  end
  -- size: pow / shake slam in from double size, flash shrinks from double, sticky pops a little
  local scale = 1
  if cs == "pow" or cs == "shake" then
    if e < 0.12 then scale = 2 - e / 0.12 end
  elseif cs == "flash" then
    if e < 0.3 then scale = 2 - e / 0.3 end
  elseif cs == "sticky" then
    if e < 0.1 then scale = 1.3 - e * 3 end
  elseif cs == "blizzard" then
    -- the game's crit: swells fast, settles a little bigger than a hit
    if e < 0.08 then scale = 1 + e / 0.08 * 0.7 elseif e < 0.22 then scale = 1.7 - (e - 0.08) / 0.14 * 0.5 else scale = 1.2 end
  elseif cs == "zoom" then
    if e < 0.15 then scale = 0.3 + e / 0.15 * 0.9 elseif e < 0.25 then scale = 1.2 - (e - 0.15) / 0.1 * 0.2 end
  end
  if scale ~= o.scale then
    o.fs:SetTextHeight(o.size * scale)
    o.scale = scale
  end
  -- fade in quickly, hold, fade out over the last part (a quarter unless set)
  local a = o.alpha
  local fo = math.max(0.05, math.min(0.9, B.db.sct.fade or 0.25))
  if e < 0.06 then a = a * e / 0.06 elseif t > 1 - fo then a = a * (1 - t) / fo end
  if o.hasGlow then
    -- a bright flash for half a second, then a soft glow until the text fades
    local ga = a * ((e < 0.5) and (0.95 - e * 0.9) or 0.5)
    o.glow:SetWidth(o.glowW * scale)
    o.glow:SetHeight(o.glowH * scale)
    o.glow:SetVertexColor(o.gr, o.gg, o.gb, ga)
  end
  if o.plate then
    -- plates are pooled: gone, or showing someone else now, ends the text
    if not o.plate:IsVisible() then return false end
    local pg = o.guid and self:PlateGuid(o.plate)
    if pg and pg ~= o.guid then return false end
  end
  o.fs:SetAlpha(a)
  if o.hasIcon then o.icon:SetVertexColor(1, 1, 1, a) end
  x, y = x + (o.xv or 0) + (o.px or 0), y + (o.py or 0)
  o.fs:ClearAllPoints()
  if o.clamp and self:Clamped(o, x, y) then return true end
  o.fs:SetPoint(o.fsPoint or "CENTER", o.anchor, o.point, x, y)
  return true
end

-- A plate near the screen edge: its text is placed in screen coordinates and
-- kept EDGE px inside (AnySCT's clamp). False when the plate cannot be measured.
function CT:Clamped(o, x, y)
  local plate = o.plate
  local cx = plate:GetCenter()
  local top = plate:GetTop()
  local ps, cs = plate:GetEffectiveScale(), container:GetEffectiveScale()
  local w, h = container:GetWidth(), container:GetHeight()
  if not (cx and top and ps and cs and w and h) or cs == 0 then return false end
  local X = cx * ps / cs + x
  local Y = top * ps / cs + y
  local half = (o.fs:GetStringWidth() or 0) / 2 + EDGE
  if X < half then X = half elseif X > w - half then X = w - half end
  if Y < o.size + EDGE then Y = o.size + EDGE elseif Y > h - o.size - EDGE then Y = h - o.size - EDGE end
  o.fs:SetPoint("CENTER", container, "BOTTOMLEFT", X, Y)
  return true
end

function CT.OnUpdate()
  local now = GetTime()
  local i = 1
  while i <= CT.nlive do
    local o = CT.live[i]
    if CT:Step(o, now) then i = i + 1 else Release(i) end
  end
  if CT.nlive == 0 then container:SetScript("OnUpdate", nil) end
end

-- Everything off the screen (zone change, switched off).
function CT:Clear()
  while self.nlive > 0 do Release(self.nlive) end
  self.sticky = {}
end

-- ---------------------------------------------------------------- layout mode

-- In Arrange panels every area shows a sample text so it can be placed.
local samples = { inc = { "-1234", 1, 0.2, 0.2 }, out = { "2468", 1, 1, 1 }, heal = { "+850", 0.2, 1, 0.2 },
                  note = { "Killing Blow!", 1, 0.3, 0.3 }, extra = { "Extra", 0.7, 0.7, 1 } }
B:Every(1.2, function()
  if not B.test or not B.db.sct.enabled then return end
  for key, s in pairs(samples) do
    if B.db.sct.areas[key].enabled then CT:Show(s[1], s[2], s[3], s[4], key, { crit = math.random() < 0.25 }) end
  end
end)

B:On("OBG_ZONE", function() CT:Clear() end)
B:On("OBG_INIT", function() CT:BuildPanels() end)
