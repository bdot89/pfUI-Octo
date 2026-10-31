pfUI:RegisterModule("sct-options", "vanilla", function ()
-- pfUI Octo :: combat text options
-- OctoBG's combat text pages (its SCTOptions.lua, the user's own addon) as
-- they were in OctoBG, in pfUI's window: basics, the five scroll areas,
-- nameplates (and teammates' damage on them), crits and sounds, every message
-- type in one grid (on, colour, where it scrolls from, always-crit, big,
-- sound), text and filters (formats, buff / proc / cooldown lists). Every
-- page's ON / OFF switch is combat text's master switch.
-- User, 20 Oct 2026: "PLEASE GET SCROLLING COMBAT TEXT OPTION PANEL IT WAS IN
-- OCTO BG". The threat page stays in OctoBG (Setup > Threat label).

local B = pfUI.sctB
local CT = B and B.SCT
local OU = pfUI.octoui
local W = OU and OU.W
local O = OU and OU.Options
if not CT or not W or not O or not O.AddPage then return end
local U = B.U
local BUILD = {}
local Chk, Sld, Drop, Pct, Px, On = O.Chk, O.Sld, O.Drop, O.Pct, O.Px, O.On

-- the message groups; OctoBG's alerts only while OctoBG is installed
local function GROUPS()
  local out = {}
  for _, grp in ipairs(CT.GROUPS) do
    if grp[1] ~= "obg" or IsAddOnLoaded("OctoBG") then table.insert(out, grp) end
  end
  return out
end

-- every default the settings table lacks (the Defaults button)
local function Fill(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      Fill(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

local function DB() return B.db.sct end
local function PL() return B.db.sct.plates end
local function Sec1(v) return string.format("%.1f s", v) end
local function Times(v) return string.format("%.2fx", v) end

-- Where a message can go: the screen areas and the nameplate.
local function Wheres(withPlate, withHide)
  local list = {}
  for i = 1, table.getn(CT.AREA_ORDER) do
    local k = CT.AREA_ORDER[i]
    table.insert(list, { key = k, label = CT.AREA_LABEL[k] })
  end
  if withPlate then table.insert(list, { key = "plate", label = "Nameplate" }) end
  if withHide then table.insert(list, { key = "hide", label = "Nowhere (hide)" }) end
  return list
end

-- The master switch on every combat text page: off hands the game's own numbers back.
local MASTER = { function() return B.db.sct.enabled end, function(v) CT:SetEnabled(v) end,
                 "Combat text on or off. Off: pfUI shows none and the game's own damage and healing numbers come back. Same on every combat text page." }

local function AllOut(where)
  local ev = B.db.sct.events
  for _, k in ipairs({ "outMelee", "outSpell", "outDot", "outPet", "outShield", "outMiss" }) do ev[k].area = where end
end
-- (the buttons light up for the place your damage goes now)
local function AllOutIs(where)
  local ev = B.db.sct.events
  for _, k in ipairs({ "outMelee", "outSpell", "outDot", "outPet", "outShield", "outMiss" }) do
    if not ev[k] or ev[k].area ~= where then return false end
  end
  return true
end
local function OnPlates() return AllOutIs("plate") end
local function OnScreen() return AllOutIs("out") end
-- one-shot tests light up for a moment after the click
local shotAt = {}
local function Shot(key, fn) return function() shotAt[key] = GetTime() fn() end end
local function Shooting(key) return function() return shotAt[key] and GetTime() - shotAt[key] < 2.5 end end

-- The combat text test (it used to sit in the window's top bar; user 17 Oct 2026:
-- "test mode is only for combat text ? this could be moved").
local TEST = { "Test combat text", function() CT:TestMode(not CT:Testing()) end, 130,
  "For a minute, sample texts keep coming in every area and on every nameplate on screen (V shows enemy "
    .. "nameplates, Shift-V friendly ones). Click again to stop.", on = function() return CT:Testing() end }

local function DamageButtons(p)
  W.Buttons(p, {
    TEST,
    { "Your damage on nameplates", function() AllOut("plate") end, 180, "Melee, spells, damage over time, pet, damage shields and misses rise from the enemy you hit.", on = OnPlates },
    { "Your damage on screen", function() AllOut("out") end, 160, "The same messages scroll in the Outgoing area (SCT - Damage).", on = OnScreen },
  })
end

-- the area picked on Scroll areas (a click on an area in the preview picks it)
local AREA = { cur = "inc" }

-- A small copy of your screen with every area and sample texts moving as set
-- (sct-preview.lua): click an area for its options, drag to move it, Shift +
-- wheel for its text size, right-click to put it back.
local function Preview(p)
  if not CT.Mini then return end
  -- (pinned at the top of the page: the options scroll under it)
  W.Pin(p, "Preview", "A small copy of your screen: every scroll area where it sits, an enemy nameplate, and "
    .. "sample texts moving as you set them. Click an area for its options, drag it to move it, hold Shift and scroll "
    .. "the mouse wheel over it for its text size, right-click it to put it back. Click this bar to fold it away.", function(p)
  local mini = CT.Mini((W.ZoomBox or W.Box)(p, 190), function(key)
    if key == "plate" then
      O:Open("ctplates")
    else
      AREA.cur = key
      O:Open("ctareas")
      O:Refresh()
    end
  end)
  table.insert(p.items, { Refresh = function() mini.Refresh() end })
  -- what the mouse does, in an accent band
  local band = W.Row(p, 20, 0, 3)
  local bg = band:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(band)
  bg:SetTexture("Interface\\Buttons\\WHITE8X8")
  local ar, ag, ab = 0.2, 0.55, 0.9
  if GetAccentColor then ar, ag, ab = GetAccentColor() end
  bg:SetVertexColor(ar, ag, ab, .22)
  local how = band:CreateFontString(nil, "OVERLAY")
  how:SetFont(W.UIFont(), 11, "OUTLINE")
  how:SetPoint("LEFT", band, "LEFT", 12, 0)
  how:SetPoint("RIGHT", band, "RIGHT", -8, 0)
  how:SetJustifyH("LEFT")
  local key = string.format("|cff%02x%02x%02x", math.floor(ar * 255), math.floor(ag * 255), math.floor(ab * 255))
  how:SetText(key .. "Click|r an area  options     " .. key .. "Drag|r  move     " .. key .. "Shift + wheel|r  text size     "
    .. key .. "Right-click|r  put it back")
  W.HowTo(p, band, how:GetText(), nil, 0)
  end)
end

-- every movement and crit entrance with what it does, in one folded card
-- (user, 26 Oct 2026: "hard to understand what does what"); and every way they can turn
local function StyleGuide(p, entrances)
  local function Lines(list)
    local s = ""
    for _, e in ipairs(list) do
      if e.tip then s = s .. "|cffffd100" .. e.label .. "|r  " .. e.tip .. "\n" end
    end
    return s
  end
  W.Card(p, "Every movement explained", { folded = true, text = "What each movement in the lists does (the same for hits, crits, areas and nameplates)." })
  W.Note(p, Lines(CT.MOVES), 0, true)
  W.Card(p, "Every way to turn them", { folded = true, text = "The choices under a movement: which of them show depends on the movement picked." })
  W.Note(p, "|cff73bfffDirection|r\n" .. Lines(CT.DIRS) .. "\n|cff73bfffSide|r\n" .. Lines(CT.SIDES)
    .. "\n|cff73bfffStraight or diagonal|r (movements that rise or fall)\n" .. Lines(CT.LEANS)
    .. "\n|cff73bfffHeight as it goes|r (movements that go sideways)\n" .. Lines(CT.DRIFTS)
    .. "\n|cff73bfffAngle|r  How steep a diagonal is: 15, 30, 45 or 60 degrees.", 0, true)
  if entrances then
    W.Card(p, "Every crit entrance explained", { folded = true, text = "How each crit entrance looks." })
    W.Note(p, Lines(CT.CRITS), 0, true)
  end
end

-- The ways the picked movement can turn, as up to four small lists in one row
-- that change with the movement (user, 26 Oct 2026: "horizontal choice should
-- show left and right options after you select it vertical should show up and
-- down"): direction, straight / diagonal (or height for sideways ones), side,
-- angle - only the ones that movement uses (CT.AimControls).
-- T() = the settings table, Move() = the movement, crit = the crit keys, after = run on a pick.
local function MoveName(m)
  for _, e in ipairs(CT.CRIT_PATHS) do if e.key == m then return e.label end end
  return tostring(m)
end
local function AimRow(p, T, Move, crit, after, sameText)
  W.Live(p, function()
    local m = Move()
    local list = CT.AimControls(m, T(), crit)
    if table.getn(list) == 0 then
      if m == "same" then return "|cff999999" .. (sameText or "Crits go the same way as the hits here.") .. "|r" end
      if m == "still" then return "|cff999999Crits stay where they appear: no way to turn them.|r" end
      if m == "fireworks" then return "|cff999999Fireworks burst out every way: no way to turn them.|r" end
      return "|cff999999" .. MoveName(m) .. " has no way to turn it.|r"
    end
    local words = {}
    for _, c in ipairs(list) do table.insert(words, string.lower(c.label)) end
    return "Which way |cffffd100" .. MoveName(m) .. "|r goes - " .. table.concat(words, ", ") .. ":"
  end)
  local row = W.Row(p, 42, 0, 2)
  local slots = {}
  for i = 1, 4 do
    local s = CreateFrame("Frame", nil, row)
    s:SetWidth(184)
    s:SetHeight(42)
    s:SetPoint("TOPLEFT", row, "TOPLEFT", (i - 1) * 192, 0)
    s.label = W.Font(s:CreateFontString(nil, "OVERLAY"), 12)
    s.label:SetPoint("TOPLEFT", s, "TOPLEFT", 2, -1)
    local box, Refresh, hit = W.MiniDrop(s, 180, function() return s.ctl and s.ctl.options or {} end,
      function() return s.ctl and s.ctl.value end, function(v)
        if not s.ctl then return end
        T()[s.ctl.key] = v
        if after then after() end
      end, 200)
    box:SetPoint("TOPLEFT", s, "TOPLEFT", 2, -18)
    W.Tip(hit, " ", " ")
    s.Refresh, s.hit = Refresh, hit
    slots[i] = s
  end
  table.insert(p.items, { Refresh = function()
    local list = CT.AimControls(Move(), T(), crit)
    for i, s in ipairs(slots) do
      s.ctl = list[i]
      if s.ctl then
        s.label:SetText(s.ctl.label)
        s.hit.tipTitle, s.hit.tipText = s.ctl.label, s.ctl.tip .. " Point at a choice in the list to see what it does."
        s.Refresh()
        s:Show()
      else
        s:Hide()
      end
    end
  end })
  for _, w in ipairs({ { "Direction", "Up, down, or up and down taking turns - for movements that rise or fall." },
                       { "Side", "Left, right, alternate, random, or damage one way and heals the other." },
                       { "Straight or diagonal", "Movements that rise or fall can slant left, right or to the side." },
                       { "Height as it goes", "Sideways movements can go level, at random heights, rising or falling." },
                       { "Angle", "How steep a diagonal is: 15 to 60 degrees." } }) do
    if p.key then table.insert(W.index, { page = p, card = p.cur, label = w[1], desc = w[2], region = row }) end
  end
  return row
end

-- One-click looks for all combat text: { key, label, top keys, every area's keys, plate keys, area keys by area }
local LOOKS = {
  { "octo", "pfUI Octo", { style = "octo", font = "Fonts\\FRIZQT__.TTF", outline = "OUTLINE", speed = 1, icons = true },
    { anim = "vertical", crit = "sticky" }, { hit = "fountain", crit = "pow" }, { note = { anim = "static" } } },
  { "sct", "Classic SCT", { style = "octo", font = "Fonts\\FRIZQT__.TTF", outline = "OUTLINE", speed = 1, icons = false },
    { anim = "vertical", crit = "flash" }, { hit = "vertical", crit = "flash" }, { note = { anim = "static" } } },
  { "msbt", "MSBT", { style = "octo", font = "Fonts\\FRIZQT__.TTF", outline = "THICKOUTLINE", speed = 1, icons = true },
    { anim = "parabola", crit = "pow" }, { hit = "parabola", crit = "pow" }, { note = { anim = "static" } } },
  { "fountain", "Fountain", { style = "octo", font = "Fonts\\FRIZQT__.TTF", outline = "OUTLINE", speed = 1.1, icons = true },
    { anim = "fountain", crit = "shake" }, { hit = "fountain", crit = "shake" }, { note = { anim = "static" } } },
  { "blizzard", "Blizzard", { style = "blizzard", outline = "OUTLINE", speed = 1, icons = false },
    { anim = "vertical", crit = "blizzard" }, { hit = "vertical", crit = "blizzard" }, { note = { anim = "static" } } },
  { "minimal", "Minimal", { style = "octo", font = "Fonts\\FRIZQT__.TTF", outline = "", speed = 1.25, icons = false },
    { anim = "vertical", crit = "normal" }, { hit = "vertical", crit = "normal" }, { note = { anim = "static" } } },
}

local function ApplyLook(key)
  local db = B.db.sct
  for _, l in ipairs(LOOKS) do
    if l[1] == key then
      for k, v in pairs(l[3]) do db[k] = v end
      for _, ak in ipairs(CT.AREA_ORDER) do
        for k, v in pairs(l[4]) do db.areas[ak][k] = v end
        for k, v in pairs((l[6] and l[6][ak]) or {}) do db.areas[ak][k] = v end
        -- (a look's crits move its way: no own crit movement left over)
        db.areas[ak].critPath, db.areas[ak].critOwn = nil, nil
        CT:PlaceArea(ak)
      end
      for k, v in pairs(l[5]) do db.plates[k] = v end
      db.plates.critPath, db.plates.critOwn = nil, nil
    end
  end
end

-- the look whose settings all still match (nil = your own mix)
local function CurrentLook()
  local db = B.db.sct
  for _, l in ipairs(LOOKS) do
    local same = true
    for k, v in pairs(l[3]) do if db[k] ~= v then same = false end end
    for _, ak in ipairs(CT.AREA_ORDER) do
      local want = {}
      for k, v in pairs(l[4]) do want[k] = v end
      for k, v in pairs((l[6] and l[6][ak]) or {}) do want[k] = v end
      for k, v in pairs(want) do if db.areas[ak][k] ~= v then same = false end end
      if db.areas[ak].critPath or db.areas[ak].critOwn then same = false end
    end
    for k, v in pairs(l[5]) do if db.plates[k] ~= v then same = false end end
    if db.plates.critPath or db.plates.critOwn then same = false end
    if same then return l[1], l[2] end
  end
end

CT.ApplyLook, CT.CurrentLook, CT.LOOKS = ApplyLook, CurrentLook, LOOKS

-- the looks, three to a row; the picked one is lit
local function Looks(p)
  local btns, rows = {}, {}
  for r = 1, math.ceil(table.getn(LOOKS) / 3) do rows[r] = W.Row(p, 24, 0, 6) end
  local function Paint()
    local cur = CurrentLook()
    for _, b in ipairs(btns) do W.Pick(b, b.key == cur) end
  end
  for i, l in ipairs(LOOKS) do
    local b = W.Button(rows[math.floor((i - 1) / 3) + 1], l[2], 180, 22)
    b:SetPoint("LEFT", b:GetParent(), "LEFT", math.mod(i - 1, 3) * 186, 0)
    b.key = l[1]
    b:SetScript("OnClick", function()
      ApplyLook(this.key)
      Paint()
      O:Refresh()
    end)
    W.Tip(b, l[2], "Letters, movements and crit style for all combat text in one click.")
    btns[i] = b
  end
  W.Live(p, function()
    local _, label = CurrentLook()
    return label and ("Look: |cffffffff" .. label .. "|r") or "Look: |cffffffffyour own mix|r (a setting was changed after picking a look)"
  end)
  rows[1]:SetScript("OnUpdate", function()
    if (this.tick or 0) > GetTime() then return end
    this.tick = GetTime() + .5
    Paint()
  end)
  Paint()
end

-- ---------------------------------------------------------------- basics

BUILD.ctgeneral = function(p)
  W.Heading(p, "Combat text", {
    on = MASTER,
    text = "Scrolling combat text in five screen areas you place - or rising from nameplates: your damage from the enemy you hit.",
    about = "Everything SCT and SCT - Damage showed (and Mik's Scrolling Battle Text, NameplateSCT, the game's own "
      .. "options over the years). Test combat text sends sample texts everywhere for a minute; Move frames shows "
      .. "the areas as blue boxes to drag and size.\n\nThe other combat text pages: Scroll areas (where and how text "
      .. "moves), Nameplates (and teammates' damage on them), Crits, Messages and sounds (what shows, its colour, where "
      .. "it comes from), Text and filters, Threat." })
  W.Live(p, function()
    local s = {}
    if CT:Testing() then table.insert(s, "|cff55ff55Test running|r (" .. math.ceil(CT.testUntil - GetTime()) .. " s)") end
    if pfUI.unlock and pfUI.unlock:IsShown() then table.insert(s, "|cff73bfffMoving frames|r - click Done when finished") end
    local n = table.getn(CT:Plates())
    table.insert(s, n .. " nameplate" .. ((n == 1) and "" or "s") .. " on screen" .. ((n == 0) and " - V shows enemy plates, Shift-V friendly" or ""))
    return table.concat(s, "    ")
  end)
  W.Card(p, "Looks", { tip = "Ready-made styles for all combat text: letters, how each area moves, how crits appear. "
    .. "Colours, messages and places stay as they are." })
  Looks(p)
  Preview(p)
  W.Card(p, "Look of all text", { tip = "The letters, size, outline and speed of every combat text. Areas can pick their own on Scroll areas." })
  Drop(p, "Style", "Blizzard numbers: the game's own damage-number look - its font, plain numbers, white melee and "
    .. "yellow spells, straight up, crits that pop - still placed and filtered by these pages.", CT.STYLES, DB, "style")
  Drop(p, "Font", "Shown in its own letters. Areas can pick their own on Scroll areas.", W.Fonts(), DB, "font")
  Drop(p, "Outline", "A dark edge around the letters makes them easier to read.", CT.OUTLINES, DB, "outline")
  Sld(p, "Text size", "Every combat text this much bigger or smaller.", 0.5, 2, 0.05, DB, "scale", nil, Pct)
  Sld(p, "Speed", "How fast all texts move: below 1 they stay longer, above 1 they pass quicker.", 0.5, 2, 0.05, DB, "speed", nil, Times)
  Sld(p, "Fade out over", "The last part of a text's time it fades away in.", 0.05, 0.9, 0.05, DB, "fade", nil, Pct)
  Sld(p, "Most on screen", "When more texts than this are showing, the oldest goes first.", 10, 150, 5, DB, "maxLive")
  Chk(p, "Shadow", "A soft shadow behind the letters.", DB, "shadow")
  Chk(p, "Spell icons", "The spell's icon next to its number.", DB, "icons")
  Sld(p, "Icon size", "Next to the text, relative to its height.", 0.5, 2, 0.1, DB, "iconScale", nil, Pct)
  W.Card(p, "Where your damage goes")
  DamageButtons(p)
  W.Card(p, "The game's own numbers", { folded = true,
    tip = "The ON / OFF switch swaps these for you; here they can be set one by one." })
  W.Check(p, "Game damage numbers", "The client's floating damage over targets (CombatDamage).",
    function() return CT:GameNumbersOn("dmg") end, function(v) CT:GameNumbers("dmg", v) end)
  W.Check(p, "Game pet damage numbers", "PetMeleeDamage.",
    function() return CT:GameNumbersOn("pet") end, function(v) CT:GameNumbers("pet", v) end)
  W.Check(p, "Game healing numbers", "SuperWoW's healing text (HealingText).",
    function() return CT:GameNumbersOn("heal") end, function(v) CT:GameNumbers("heal", v) end)
  W.Check(p, "Game scrolling text over you", "Blizzard's own combat text that floats over your character: heals you "
    .. "get (\"+954\"), damage you take. The same box as the game's Interface Options - Show Scrolling Combat Text.",
    function() return CT:GameNumbersOn("fct") end, function(v) CT:GameNumbers("fct", v) end, true)
end

-- ---------------------------------------------------------------- areas

local AREA_TAB = { inc = "Incoming", out = "Outgoing", heal = "Healing", note = "Notes", extra = "Extra" }
local AREA_INFO = {
  inc = "damage, misses and debuffs you take start here.",
  out = "your damage when it is not on nameplates, and your heals on others.",
  heal = "heals and power you get, combat start and end, combo points.",
  note = "messages - killing blows, warnings, procs, honor, loot (they stand still and fade).",
  extra = "a spare area: pick it for any message on the Messages page.",
}

BUILD.ctareas = function(p)
  local function A() return B.db.sct.areas[AREA.cur] end
  local function Place() CT:PlaceArea(AREA.cur) end
  W.Heading(p, "Scroll areas", {
    on = MASTER,
    text = "Five places on the screen text can scroll in. Pick one below to change it; each message picks its area on Messages.",
    about = "Move frames at the top shows the areas as blue boxes to drag and size. Each message type picks an area "
      .. "(Messages page) or the nameplate of the other unit." })
  local row = W.Row(p, 26, 0, 8)
  local tabs = {}
  for i = 1, table.getn(CT.AREA_ORDER) do
    local key = CT.AREA_ORDER[i]
    local b = W.Button(row, AREA_TAB[key], 96, 22, "pfOctoCtTab" .. i)
    b:SetPoint("LEFT", row, "LEFT", (i - 1) * 101, 0)
    b.key = key
    b:SetScript("OnClick", function()
      AREA.cur = this.key
      O:Refresh()
    end)
    tabs[i] = b
  end
  table.insert(p.items, { Refresh = function()
    for i = 1, table.getn(tabs) do W.Pick(tabs[i], tabs[i].key == AREA.cur) end
  end })
  W.Live(p, function()
    return "|cffffd100" .. CT.AREA_LABEL[AREA.cur] .. "|r - " .. AREA_INFO[AREA.cur]
  end)
  W.Buttons(p, { TEST, { "Test this area", Shot("area", function()
    CT:Show("1234", 1, 1, 1, AREA.cur, {})
    CT:Show("5678", 1, 0.3, 0.3, AREA.cur, { crit = true })
  end), 120, "A hit and a crit in the area picked above.", on = Shooting("area") } })
  Preview(p)
  W.Card(p, "Movement", { text = "How text moves in this area. The switch turns the area on or off.", on = { function() return A().enabled end, function(v) A().enabled = v end,
    "Use this area. Off: messages sent here are not shown." } })
  Drop(p, "Movement", "The way the text travels: straight up, in an arc, sideways, bouncing... Point at a name in the list to see what it does. "
    .. "The choices under it change to the ways that movement can go.", CT.MOVES, A, "anim", Place)
  AimRow(p, A, function() return A().anim end, false, Place)
  Sld(p, "Time on screen", "How long each text stays.", 0.5, 8, 0.1, A, "time", nil, Sec1)
  Sld(p, "Travel height", "How far up (or down) the text travels.", 40, 600, 10, A, "height", Place, Px)
  Sld(p, "Travel width", "How far sideways the text can travel.", 20, 600, 10, A, "width", Place, Px)
  W.Buttons(p, { { "Crits in this area: how they appear and move  >", function() O:Open("ctcrits", AREA.cur) end, 300,
    "Crits have their own page: how they appear, how they move, their size, time and travel - for each area and nameplates.", role = "open" } })
  W.Card(p, "Look", { text = "Size, crit size and letters of the text in this area." })
  Sld(p, "Text size", "How big the text is in this area.", 8, 48, 1, A, "size", Place, Px)
  Sld(p, "Crit size", "How much bigger crits are than normal hits.", 1, 3, 0.05, A, "critScale", nil, Times)
  Sld(p, "Opacity", "How solid the text is. Lower = more see-through.", 0.1, 1, 0.05, A, "alpha", nil, Pct)
  Drop(p, "Text alignment", "Line the texts up on the left, middle or right.", CT.ALIGNS, A, "align")
  Drop(p, "Spell icon", "Show the spell icon, and on which side.", CT.ICONS, A, "icon")
  local fonts = { { key = "", label = "Same as all" } }
  local flist = W.Fonts()
  for f = 1, table.getn(flist) do table.insert(fonts, flist[f]) end
  Drop(p, "Font", "Letters just for this area. 'Same as all' uses the one on General.", fonts, A, "font")
  Drop(p, "Outline", "A dark edge just for this area.", { { key = "", label = "Same as all" }, { key = "OUTLINE", label = "Outline" },
    { key = "THICKOUTLINE", label = "Thick outline" } }, A, "outline")
  W.Card(p, "Place", { folded = true, text = "Where the area sits on screen. Easier: tick Move frames at the top and drag it." })
  Sld(p, "X", "From the middle of the screen.", -900, 900, 5, A, "x", Place)
  Sld(p, "Y", "From the middle of the screen.", -600, 600, 5, A, "y", Place)
  StyleGuide(p)
end

-- ---------------------------------------------------------------- nameplates

local function TM() return B.db.sct.team end
local WHO = { { key = "party", label = "My party (and its pets)" }, { key = "raid", label = "My whole raid" } }

BUILD.ctplates = function(p)
  local function Roster() CT.EV:Roster() end
  W.Heading(p, "Nameplates", {
    on = MASTER,
    text = "Text set to \"Nameplate\" rises from the other unit's plate and follows it - and your team's damage can too.",
    about = "The damage you deal rises from the enemy you hit (every enemy, not just your target), the damage you take "
      .. "from whoever hit you. Your damage starts that way; any message can (Messages page).\n\nA plate has to be on "
      .. "screen: enemy nameplates on (V), within nameplate range. With no plate the text goes "
      .. "to the fallback area. Works with pfUI's nameplates.\n\nTeammates: the damage your party deals rises from the "
      .. "plate of whoever they hit - smaller, in their class colour, in a column beside your own numbers. Your own "
      .. "damage is never shown twice, and teammates' text never goes to the screen areas." })
  W.Buttons(p, {
    TEST,
    { "Your damage on nameplates", function() AllOut("plate") end, 180, "Melee, spells, damage over time, pet, damage shields and misses.", on = OnPlates },
    { "Test on nameplates", Shot("plates", function() CT:TestPlates() end), 140, "A hit, a crit, a miss and a heal on every nameplate on screen.", on = Shooting("plates") },
  })
  Preview(p)
  O.CardTabs(p, {
    { "mine", "Your text", "Ability_MeleeDamage", { "Basics", "Movement", "Look", "Keep it tidy" } },
    { "team", "Teammates", "INV_Banner_02", { "Teammates' damage", "Teammates' look" } },
  })
  W.Card(p, "Basics", { text = "Which nameplates get text, and what happens when there is no nameplate." })
  Chk(p, "Text on other enemies", "Off: only your target's plate shows text.", PL, "offTarget")
  Chk(p, "Show plates when I log in", "Switches the enemy plates on (V) - turn them off yourself (SCT - Damage did the same).", PL, "autoShow")
  Drop(p, "No plate showing", "Where nameplate messages go when the unit has no plate.", Wheres(false, true), PL, "fallback")
  W.Card(p, "Movement", { text = "How the text moves away from the nameplate." })
  Drop(p, "Hits", "How your hits move. The choices under the lists change to the ways it can go.", CT.MOVES, PL, "hit")
  Drop(p, "Misses", "How Dodge, Parry, Resist and the like move.", CT.MOVES, PL, "miss")
  Drop(p, "Heals", "How heals move.", CT.MOVES, PL, "heal")
  AimRow(p, PL, function() return PL().hit end, false)
  W.Buttons(p, { { "Nameplate crits: how they appear and move  >", function() O:Open("ctcrits", "plate") end, 300,
    "Crits have their own page: how they appear, how they move, their size, time and travel.", role = "open" } })
  Sld(p, "Time on screen", "How long each text stays.", 0.5, 5, 0.1, PL, "time", nil, Sec1)
  Sld(p, "Travel height", "How far up the text travels.", 20, 300, 5, PL, "height", nil, Px)
  Sld(p, "Travel width", "How far sideways the text can travel.", 20, 300, 5, PL, "width", nil, Px)
  Sld(p, "Random spread", "Each text starts a little left or right at random, so they don't sit on top of each other.", 0, 60, 1, PL, "xVariance", nil, Px)
  W.Card(p, "Look", { folded = true, text = "Size and height of the text, and how other enemies' text looks." })
  Sld(p, "Text size", "How big nameplate text is.", 8, 40, 1, PL, "size", nil, Px)
  Sld(p, "Height above the plate", "Where the text starts, above the nameplate.", -40, 120, 1, PL, "yOffset", nil, Px)
  Sld(p, "Your target bigger by", "Text on your target is this much bigger.", 1, 2, 0.05, PL, "targetScale", nil, Times)
  Sld(p, "Other enemies' size", "Text on enemies you are not targeting is this size.", 0.4, 1, 0.05, PL, "offScale", nil, Pct)
  Sld(p, "Other enemies' opacity", "Text on enemies you are not targeting is this see-through.", 0.1, 1, 0.05, PL, "offAlpha", nil, Pct)
  Sld(p, "Most texts per plate", "Yours and teammates' are counted apart.", 1, 20, 1, PL, "max")
  W.Card(p, "Keep it tidy", { text = "Stops lots of numbers piling on top of each other." })
  Chk(p, "Stack lines", "Fast hits in a straight movement (Vertical, Parabola, Sway, Wave, Zigzag) push the ones above them up a line, never on top of each other.", PL, "stack")
  Chk(p, "Add up the same attack", "The same attack on the same enemy within the merge window (Text and filters) adds "
    .. "to the number already there: \"1840 x3\" instead of three lines.", PL, "merge")
  Chk(p, "Keep text on screen", "Text of a nameplate at the screen edge stays inside the screen.", PL, "clamp")
  W.Card(p, "Teammates' damage", { text = "See your team's damage too: smaller numbers in their class colour beside yours.", on = On(TM, "on", Roster, "Teammates' damage on the nameplates of whoever they hit.") })
  Drop(p, "Whose damage", "A raid in a battleground is a lot of numbers - your party is the tidy choice.", WHO, TM, "who", Roster)
  W.Space(p, 2)
  Chk(p, "Their pets too", "Pets' damage as well.", TM, "pets", Roster)
  Chk(p, "Only on my target", "Teammates' numbers only on the enemy you are targeting.", TM, "onlyTarget")
  Chk(p, "Their misses", "Dodge, Parry, Resist... as words.", TM, "misses")
  Chk(p, "Their damage over time", "Ticks of DoTs too - busy with several warlocks or priests.", TM, "dots")
  W.Edit(p, "Also these players", "Names, comma separated - anyone, in your group or not, on any side.",
    function() return B.db.sct.team.names end, function(v)
      B.db.sct.team.names = v or ""
      Roster()
    end, 220)
  W.Card(p, "Teammates' look", { folded = true, text = "Colour, size and position of your team's numbers." })
  Chk(p, "Class colours", "Off: every teammate in the colour beside it.", TM, "classColor")
  W.Color(p, "Colour", "The colour used when class colours are off.", function() local t = B.db.sct.team return t.r, t.g, t.b end,
    function(r, g, b) local t = B.db.sct.team t.r, t.g, t.b = r, g, b end)
  Chk(p, "Name of who hit", "\"512 Bob\" - the teammate's name after the number.", TM, "sourceName")
  W.Space(p, 2)
  Sld(p, "Size", "Of your own nameplate text size.", 0.4, 1.2, 0.05, TM, "scale", nil, Pct)
  Sld(p, "Opacity", "How solid your team's numbers are.", 0.2, 1, 0.05, TM, "alpha", nil, Pct)
  Sld(p, "Beside yours by", "How far right of the middle of the plate their column is (negative: left).", -120, 120, 2, TM, "x", nil, Px)
  StyleGuide(p)
  O.TabFilter(p)
end

-- ---------------------------------------------------------------- crits and sounds

local function CL() return B.db.sct.critLook end
local CRIT_OUTLINES = { { key = "same", label = "Same as the text" }, { key = "", label = "None" },
                        { key = "OUTLINE", label = "Outline" }, { key = "THICKOUTLINE", label = "Thick outline" } }

-- the place whose crits the Crits page sets: "plate" or an area key
local CRIT = { cur = "plate" }
local CRIT_TABS = { { "plate", "Nameplates" }, { "inc", "Incoming" }, { "out", "Outgoing" }, { "heal", "Healing" },
                    { "note", "Notifications" }, { "extra", "Extra" } }
local function CP() if CRIT.cur == "plate" then return B.db.sct.plates end return B.db.sct.areas[CRIT.cur] end
O.tabs = O.tabs or {}
O.tabs.ctcrits = function(key) if key then CRIT.cur = key end end

local function SampleCrit()
  if CRIT.cur ~= "plate" then
    CT:Show("2468", 1, 1, 1, CRIT.cur, { crit = true })
    CT:Show("1357", 1, 1, 1, CRIT.cur, { crit = true })
  else
    CT:Show("2468", 1, 1, 1, "out", { crit = true })
  end
  local tg = U.GuidOf("target")
  if tg and CT:Plate(tg) then CT:Show("3579", 1, 0.85, 0.2, "plate", { guid = tg, target = true, crit = true, kind = "crit" }) end
end

-- One-click looks for crits.
local function CritPreset(which)
  local L, P = B.db.sct.critLook, B.db.sct.plates
  P.critPath, P.critOwn = nil, nil
  for _, k in ipairs(CT.AREA_ORDER) do B.db.sct.areas[k].critPath, B.db.sct.areas[k].critOwn = nil, nil end
  if which == "loud" then
    L.outline, L.tint, L.r, L.g, L.b, L.glow, L.glowSize, L.mark, L.hold = "THICKOUTLINE", true, 1, 0.82, 0.1, true, 1.3, "bang", 1.4
    P.crit, P.critScale = "pow", 1.8
    for _, k in ipairs(CT.AREA_ORDER) do B.db.sct.areas[k].crit, B.db.sct.areas[k].critScale = "pow", 1.7 end
  elseif which == "clean" then
    L.outline, L.tint, L.glow, L.mark, L.hold = "same", false, false, "none", 1
    P.crit, P.critScale = "normal", 1.4
    for _, k in ipairs(CT.AREA_ORDER) do B.db.sct.areas[k].crit, B.db.sct.areas[k].critScale = "normal", 1.4 end
  else   -- the game's
    L.outline, L.tint, L.glow, L.mark, L.hold, L.numberOnly = "same", false, false, "none", 1, true
    P.crit, P.critScale = "blizzard", 1.5
    for _, k in ipairs(CT.AREA_ORDER) do B.db.sct.areas[k].crit = "blizzard" end
  end
  SampleCrit()
end

local function PlaySnd(v) CT.PlaySound(v) end

BUILD.ctcrits = function(p)
  W.Heading(p, "Crits", {
    on = MASTER,
    text = "Pick a place below, then how its crits appear and how they move. Point at any name in a list to see what it does.",
    about = "Each place - nameplates and the five scroll areas - has its own crit entrance (how a crit appears: slam in, "
      .. "pop, swell...) and its own crit movement (the same as its hits, staying in place, or any of the movements "
      .. "hits can use), and can give crits their own time on screen, travel and direction. The crit look at the "
      .. "bottom (letters, colour, flash, mark) is for every crit. Crit sounds are on Messages and sounds." })
  W.Buttons(p, {
    TEST,
    { "Show a crit", Shot("crit", SampleCrit), 100, "A crit in the Outgoing area and on your target's nameplate.", on = Shooting("crit") },
    { "Loud", function() CritPreset("loud") end, 70, "Thick gold numbers that slam in with a flash and a !",
      on = function() return B.db.sct.plates.crit == "pow" and B.db.sct.critLook.mark == "bang" end },
    { "Clean", function() CritPreset("clean") end, 70, "Just bigger, no flash.",
      on = function() return B.db.sct.plates.crit == "normal" and not B.db.sct.critLook.glow end },
    { "Blizzard", function() CritPreset("blizzard") end, 80, "The game's crit: the number pops and moves on.",
      on = function() return B.db.sct.plates.crit == "blizzard" end },
  })
  Preview(p)
  -- the place whose crits are set below
  local row = W.Row(p, 26, 0, 8)
  local tabs = {}
  for i, t in ipairs(CRIT_TABS) do
    local b = W.Button(row, t[2], 104, 22, "pfOctoCtCritTab" .. i)
    b:SetPoint("LEFT", row, "LEFT", (i - 1) * 109, 0)
    b.key = t[1]
    b:SetScript("OnClick", function()
      CRIT.cur = this.key
      O:Refresh()
    end)
    W.Tip(b, t[2], "Set the crits " .. (t[1] == "plate" and "that rise from nameplates." or ("in the " .. CT.AREA_LABEL[t[1]] .. " area.")))
    tabs[i] = b
  end
  table.insert(p.items, { Refresh = function()
    for i = 1, table.getn(tabs) do W.Pick(tabs[i], tabs[i].key == CRIT.cur) end
  end })
  local function Label(list, key)
    for _, e in ipairs(list) do if e.key == key then return e.label end end
    return tostring(key)
  end
  W.Live(p, function()
    local t = CP()
    return "Crits " .. (CRIT.cur == "plate" and "on |cffffd100nameplates|r" or ("in |cffffd100" .. CT.AREA_LABEL[CRIT.cur] .. "|r"))
      .. ": appear |cffffffff" .. Label(CT.CRITS, t.crit) .. "|r, move |cffffffff" .. Label(CT.CRIT_PATHS, CT.CritPath(t, CRIT.cur == "plate")) .. "|r"
      .. (t.critOwn and " with their own time and travel" or "")
  end)

  W.Card(p, "How they appear", { text = "The crit's entrance. Point at a name in the list to see what it does." })
  Drop(p, "Entrance", "Slam in, pop, swell like the game's own, grow, or just bigger.", CT.CRITS, CP, "crit", SampleCrit)
  Sld(p, "Crit size", "How much bigger crits are than normal hits here.", 1, 3, 0.05, CP, "critScale", nil, Times)

  W.Card(p, "How they move", { text = "Crits can move like the hits here, stay in place, or take any other movement." })
  W.Dropdown(p, "Movement", "Every movement hits can use, plus staying in place. Point at a name in the list to see what it does.",
    CT.CRIT_PATHS, function() return CT.CritPath(CP(), CRIT.cur == "plate") end, function(v)
      CP().critPath = v
      SampleCrit()
    end)
  AimRow(p, CP, function() return CT.CritPath(CP(), CRIT.cur == "plate") end, true, SampleCrit,
    "Crits go the same way as the hits here (set on Scroll areas or Nameplates). Pick a movement above to turn crits their own way.")
  W.Card(p, "Their own time and travel", { folded = true,
    text = "Off: crits stay as long and travel as far as the hits here. On: the settings below are just for crits.",
    on = { function() return CP().critOwn end, function(v)
      local t = CP()
      t.critOwn = v and true or nil
      -- (starts from the hits' values, so switching it on changes nothing yet)
      if v then
        t.critTime = t.critTime or t.time
        t.critHeight = t.critHeight or t.height
        t.critWidth = t.critWidth or t.width
      end
    end, "Crits get their own time on screen and travel here." } })
  W.Slider(p, "Time on screen", "How long a crit stays here (Crit look's 'stay longer' still adds to it).", 0.5, 8, 0.1,
    function() return CP().critTime or CP().time end, function(v) CP().critTime = v end, Sec1)
  W.Slider(p, "Travel height", "How far up (or down) crits travel.", 20, 600, 5,
    function() return CP().critHeight or CP().height end, function(v) CP().critHeight = v end, Px)
  W.Slider(p, "Travel width", "How far sideways crits can travel.", 20, 600, 5,
    function() return CP().critWidth or CP().width end, function(v) CP().critWidth = v end, Px)

  W.Card(p, "Crit look", { text = "For every crit, everywhere: their own letters, colour, a flash and a mark." })
  local fonts = { { key = "", label = "Same as the text" } }
  local list = W.Fonts()
  for i = 1, table.getn(list) do table.insert(fonts, list[i]) end
  Drop(p, "Crit font", "A bold one stands out: Die Die Die, Londrina Solid, Squada One, Big Noodle Titling...", fonts, CL, "font", SampleCrit)
  Drop(p, "Crit outline", "A dark edge around crit numbers.", CRIT_OUTLINES, CL, "outline", SampleCrit)
  Chk(p, "Crits in their own colour", "Instead of the message's colour.", CL, "tint", SampleCrit)
  W.Color(p, "Crit colour", "The colour crits use when 'Crits in their own colour' is ticked.", function() local L = CL() return L.r, L.g, L.b end,
    function(r, g, b) local L = CL() L.r, L.g, L.b = r, g, b end)
  Chk(p, "Flash behind crits", "A starburst in the crit's colour that flares and fades.", CL, "glow", SampleCrit)
  Chk(p, "Only the number", "No spell name, school or names on crits - shorter and punchier.", CL, "numberOnly")
  Sld(p, "Flash size", "How big the flash behind crits is.", 0.5, 2, 0.1, CL, "glowSize", nil, Pct)
  Sld(p, "Crits stay longer", "Time on screen of a crit compared with a hit.", 1, 2.5, 0.05, CL, "hold", nil, Times)
  Drop(p, "Mark crits", "A sign beside crit numbers, like ! or *", CT.MARKS, CL, "mark", SampleCrit)
  W.Card(p, "Big messages", { folded = true, text = "Messages ticked 'big' on the Messages page (killing blows are) show bigger with a flash.",
    tip = "On the Messages page any message can be ticked big (killing blows are): it shows bigger, with the same flash." })
  Sld(p, "Big size", "How much bigger big messages are.", 1, 2.5, 0.05, DB, "bigScale", nil, Times)
  Chk(p, "Flash behind big ones", "The same flash crits get.", DB, "bigGlow")
  StyleGuide(p, true)
end

-- Sounds and warnings (on Messages and sounds)
local function SoundCards(p)
  W.Card(p, "Warnings", { tip = "Big text when your health or mana gets low." })
  Sld(p, "Low health under", "A warning when your health drops below this.", 5, 90, 5, DB, "lowHp", nil, function(v) return v .. "%" end)
  Sld(p, "Low mana under", "A warning when your mana drops below this.", 5, 90, 5, DB, "lowMana", nil, function(v) return v .. "%" end)
  W.Card(p, "Sounds", { text = "Sounds for killing blows and big crits. Picking a sound plays it." })
  Drop(p, "Killing blow", "Plays when you get a killing blow.", CT.SOUNDS, DB, "killSound", PlaySnd)
  W.Space(p, 2)
  Drop(p, "Crit sound", "Plays on crits at least as big as the number beside it.", CT.SOUNDS, DB, "critSoundKey", PlaySnd)
  Sld(p, "...for crits from", "Your crits at least this big (0 = off).", 0, 10000, 100, DB, "critSound")
  Drop(p, "Huge crit sound", "Plays on crits at least as big as the number beside it (instead of the crit sound).", CT.SOUNDS, DB, "hugeCritKey", PlaySnd)
  Sld(p, "...for huge crits from", "0 = off. Wins over the crit sound.", 0, 20000, 100, DB, "hugeCrit")
  W.Card(p, "Your own sounds", { folded = true, text = "Use up to four sound files of your own (see the tooltip on this bar for where to put them).",
    tip = "Put .wav or .mp3 files in Interface\\AddOns\\pfUI\\img\\sct\\sounds\\custom\\ and type their names here "
      .. "(finishhim.mp3). New files are read when the game starts, not on /reload." })
  for i = 1, 4 do
    local n = i
    W.Edit(p, "Your sound " .. n, nil, function() return B.db.sct.mySounds[n] end, function(v)
      B.db.sct.mySounds[n] = v or ""
      CT.PlaySound("my" .. n)
    end, 170)
  end
  W.Buttons(p, {
    { "Play 1", function() CT.PlaySound("my1") end, 64 }, { "Play 2", function() CT.PlaySound("my2") end, 64 },
    { "Play 3", function() CT.PlaySound("my3") end, 64 }, { "Play 4", function() CT.PlaySound("my4") end, 64 },
  })
end

-- ---------------------------------------------------------------- messages (grid)

local COL = { check = 0, label = 22, color = 172, where = 198, crit = 314, big = 342, sound = 370 }

local function EventRow(p, key)
  local e = CT.EVENT[key]
  local function S() return B.db.sct.events[key] end
  local row = W.Row(p, 24, 0, 1)
  local cb = W.CheckBox(row, 16)
  cb:SetPoint("LEFT", row, "LEFT", COL.check + 2, 0)
  cb:SetScript("OnClick", function() S().on = this:GetChecked() and true or false end)
  local label = W.Font(row:CreateFontString(nil, "OVERLAY"), 11, W.C.text[1], W.C.text[2], W.C.text[3])
  label:SetPoint("LEFT", row, "LEFT", COL.label, 0)
  label:SetWidth(COL.color - COL.label - 6)
  label:SetHeight(24)
  label:SetJustifyH("LEFT")
  label:SetText(e.label)
  -- colour swatch
  local sw = W.Swatch(row, 16)
  sw:SetPoint("LEFT", row, "LEFT", COL.color, 0)
  local fill = sw.fill
  sw:SetScript("OnClick", function()
    local s = S()
    local r, g, b = s.r, s.g, s.b
    ColorPickerFrame.func = function()
      local nr, ng, nb = ColorPickerFrame:GetColorRGB()
      s.r, s.g, s.b = nr, ng, nb
      fill:SetVertexColor(nr, ng, nb)
    end
    ColorPickerFrame.opacityFunc = nil
    ColorPickerFrame.cancelFunc = function()
      s.r, s.g, s.b = r, g, b
      fill:SetVertexColor(r, g, b)
    end
    ColorPickerFrame.hasOpacity = nil
    ColorPickerFrame:SetColorRGB(r, g, b)
    ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    ShowUIPanel(ColorPickerFrame)
  end)
  -- where it scrolls from
  local wf, whereRefresh = W.MiniDrop(row, 104, Wheres(true, false), function() return S().area end,
    function(v) S().area = v end, 140)
  wf:SetPoint("LEFT", row, "LEFT", COL.where + 4, 0)
  -- always crit
  local cc = W.CheckBox(row, 16)
  cc:SetPoint("LEFT", row, "LEFT", COL.crit + 3, 0)
  cc:SetScript("OnClick", function() S().crit = this:GetChecked() and true or false end)
  -- big: bigger, with the flash (Crits sets how much)
  local bg = W.CheckBox(row, 16)
  bg:SetPoint("LEFT", row, "LEFT", COL.big + 3, 0)
  bg:SetScript("OnClick", function() S().big = this:GetChecked() and true or false end)
  -- sound
  local sf, soundRefresh = W.MiniDrop(row, 120, CT.SOUNDS, function() return S().sound end, function(v)
    S().sound = v
    CT.PlaySound(v)
  end, 170)
  sf:SetPoint("LEFT", row, "LEFT", COL.sound + 6, 0)
  table.insert(p.items, { Refresh = function()
    local s = S()
    cb:SetChecked(s.on and 1 or nil)
    cc:SetChecked(s.crit and 1 or nil)
    bg:SetChecked(s.big and 1 or nil)
    fill:SetVertexColor(s.r, s.g, s.b)
    whereRefresh()
    soundRefresh()
  end })
  W.Tip(cb, e.label, "Tick to show this message.")
  W.Tip(sw, e.label, "Its colour. Click to pick another.")
  W.Tip(wf, e.label, "Where it comes from: one of the screen areas, or the nameplate of the other person.")
  W.Tip(cc, e.label, "Always show it as a crit (bigger, with the crit movement).")
  W.Tip(bg, e.label, "Bigger, with a flash, so it stands out (sizes on Crits).")
  W.Tip(sf, e.label, "A sound when it happens. Picking one plays it.")
  table.insert(W.index, { page = p, card = p.cur, label = e.label, desc = "A message type: on, colour, where it comes from, crit, big, sound.", region = row })
end

local OPEN_GROUPS = { out = true, ["in"] = true }
local GROUP_TEXT = {
  ["in"] = "Hits, misses and debuffs that land on you.",
  heal = "Heals, mana, rage and energy you get, and buffs you gain or lose.",
  out = "The damage you deal - from the enemy's nameplate or on screen.",
  outheal = "Heals you cast on others.",
  warn = "Low health, low mana, combat start and end, procs, cooldowns ready.",
  reward = "Honor, experience, reputation, loot and money.",
  obg = "OctoBG's own warnings shown as combat text.",
}

BUILD.ctevents = function(p)
  W.Heading(p, "Messages and sounds", {
    on = MASTER,
    text = "Every kind of combat text: show it, its colour, where it comes from, always a crit, big, and a sound.",
    about = "Tick to show a message. The swatch is its colour. Where it comes from: a screen area, or the nameplate of "
      .. "the other unit. Crit = always shown as a crit. Big = bigger with a flash so it stands out (Crits sets how "
      .. "much). Sound: picking one plays it.\n\nThe sound lists hold the game's alerts, gunshots and explosions, boss "
      .. "kill lines (\"Die, insect!\"), crowd cheers and victory horns, BigWigs' voices and four files of your own." })
  W.Buttons(p, {
    { "Your damage on nameplates", function() AllOut("plate") end, 180, nil, on = OnPlates },
    { "Your damage on screen", function() AllOut("out") end, 150, nil, on = OnScreen },
    { "Defaults", function()
      B.db.sct.events = {}
      Fill(B.db.sct.events, B.DEFAULTS.sct.events)
    end, 80, "Every message type back to how it started (formats too)." },
  })
  -- (31 Oct 2026, user: menus "overwhelming": one kind of message at a time)
  O.CardTabs(p, {
    { "out", "Your damage", "INV_Sword_04", { "Your damage", "Your healing" } },
    { "in", "Taken", "Spell_Shadow_ShadowWordPain", { "Damage you take", "Healing, power and buffs you get" } },
    { "warn", "Alerts", "INV_Misc_Bell_01", { "Alerts and warnings", "OctoBG alerts", "Warnings" } },
    { "reward", "Rewards", "INV_Misc_Coin_01", { "Rewards" } },
    { "sound", "Sounds", "INV_Misc_Drum_01", { "Sounds", "Your own sounds" } },
  })
  for g = 1, table.getn(GROUPS()) do
    local grp = GROUPS()[g]
    W.Card(p, grp[2], { folded = not OPEN_GROUPS[grp[1]], text = GROUP_TEXT[grp[1]] })
    local cols = W.Row(p, 12, 0, 0)
    local function Col(text, x)
      local fs = W.Font(cols:CreateFontString(nil, "OVERLAY"), 10, W.C.dim[1], W.C.dim[2], W.C.dim[3])
      fs:SetPoint("LEFT", cols, "LEFT", x, 0)
      fs:SetText(text)
    end
    Col("show", COL.check)
    Col("colour", COL.color - 4)
    Col("where it comes from", COL.where + 4)
    Col("crit", COL.crit + 2)
    Col("big", COL.big + 3)
    Col("sound", COL.sound + 6)
    for i = 1, table.getn(CT.EVENTS) do
      local e = CT.EVENTS[i]
      if e.group == grp[1] then EventRow(p, e.key) end
    end
  end
  SoundCards(p)
  O.TabFilter(p)
end

-- ---------------------------------------------------------------- text and filters

BUILD.ctfilters = function(p)
  W.Heading(p, "Text and filters", {
    on = MASTER,
    text = "What every text says, what is left out, which buffs are procs, and each message's wording.",
    about = "Formats: %a amount, %s spell, buff, item or other thing, %n the other unit's name, %t the kind (Dodge, "
      .. "Fire, Rage, Falling...). Spell names and names are added by themselves when the format leaves them out and "
      .. "their boxes under What the texts say are ticked. Press Enter to save; empty = the original.\n\nLists: names "
      .. "separated by commas, as the game spells them. Press Enter to save." })
  local formats = {}
  for g = 1, table.getn(GROUPS()) do table.insert(formats, "Formats: " .. string.lower(GROUPS()[g][2])) end
  O.CardTabs(p, {
    { "text", "Texts and filters", "INV_Scroll_03", { "What the texts say", "Less clutter", "Buffs, procs and cooldowns" } },
    { "fmt", "Wording of each message", "INV_Feather_05", formats },
  })
  W.Card(p, "What the texts say", { text = "What is written next to the numbers." })
  Chk(p, "Spell names", "\"2468 (Shadow Bolt)\" (SCT's skill names).", DB, "spellNames")
  Chk(p, "Damage school", "\"<Fire>\" after spell damage.", DB, "schoolNames")
  Chk(p, "Colour spells by school", "Fire orange, frost blue, shadow purple... instead of the message colour.", DB, "schoolColors")
  Chk(p, "Who hit you / you hit", "\"Name: 512\" on screen areas (nameplates already show who).", DB, "names")
  Chk(p, "Healer names", "\"+1300 (Healbot)\" on heals you get.", DB, "healerNames")
  Chk(p, "Resisted, blocked, absorbed", "\"-300 (120 resisted)\".", DB, "showResist")
  Chk(p, "Glancing ~ and crushing ^", "A ~ after glancing hits and a ^ after crushing ones.", DB, "showGlance")
  Chk(p, "Overheal (estimated)", "\"+1300 {400}\" - from your health before the heal; may be off by a tick.", DB, "overheal")
  Chk(p, "Your heals on yourself", "Show heals you cast on yourself.", DB, "selfHeals")
  Chk(p, "Short numbers", "12.3k, 1.2m.", DB, "abbreviate")
  Chk(p, "Thousands separators", "12,345 (when not shortened).", DB, "commas")
  W.Space(p, 2)
  Drop(p, "Long spell names", "Shorten long spell names so texts stay small.", { { key = "off", label = "In full" }, { key = "cut", label = "Cut after N letters" },
    { key = "initials", label = "Initials (SB)" } }, DB, "truncate")
  Sld(p, "Letters kept", "How many letters are kept when names are cut.", 6, 30, 1, DB, "truncateLen")
  W.Card(p, "Less clutter", { text = "Hide or shrink the small stuff so the numbers that matter stand out." })
  Chk(p, "Only damage on my target", "Outgoing damage to anyone else is not shown (SCT - Damage).", DB, "targetOnly")
  Chk(p, "Merge hits", "Several hits of one spell within a moment become one text with the total and \"x3\" (screen areas).", DB, "merge")
  Chk(p, "Hide small hits", "Hide hits under \"Small hits below\" instead of shrinking them.", DB, "smallHide")
  Chk(p, "Regeneration ticks", "Energy, rage and mana regeneration as power gains (SCT's \"all power\").", DB, "regen")
  Chk(p, "Power gains when full", "Show mana, rage or energy gains even when you are already full.", DB, "fullPower")
  W.Space(p, 2)
  Sld(p, "Merge window", "Hits this close together are added up into one number.", 0.1, 1.5, 0.1, DB, "mergeTime", nil, Sec1)
  Sld(p, "Power gains every", "Mana, rage and energy gains add up and show once per this many seconds (0 = each).", 0, 10, 0.5, DB, "throttlePower", nil,
    function(v) return (v == 0) and "each" or Sec1(v) end)
  Sld(p, "Smallest damage shown", "Hits below this are not shown at all (0 = all).", 0, 2000, 10, DB, "minDamage")
  Sld(p, "Smallest heal shown", "Heals smaller than this are not shown (0 = all).", 0, 2000, 10, DB, "minHeal")
  Sld(p, "Smallest power gain", "Mana, rage or energy gains smaller than this are not shown.", 0, 200, 1, DB, "minPower")
  Sld(p, "Small hits below", "Smaller text for hits under this amount (0 = off).", 0, 2000, 10, DB, "smallBelow")
  Sld(p, "Small hit size", "How small the small hits are.", 0.4, 1, 0.05, DB, "smallScale", nil, Pct)
  W.Card(p, "Buffs, procs and cooldowns", { folded = true, text = "Lists of names, separated by commas, as the game spells them. Press Enter to save." })
  W.Edit(p, "Proc buffs", "These buffs show as a proc alert (\"Clearcasting!\", crit size, Notifications) instead of a plain buff.",
    function() return B.db.sct.procs end, function(v) B.db.sct.procs = v end, 280)
  W.Edit(p, "Hidden auras", "Never shown as gained or fading (long buffs, auras you do not care about).",
    function() return B.db.sct.hideAuras end, function(v) B.db.sct.hideAuras = v end, 280)
  W.Edit(p, "Never say ready", "Cooldowns that never announce they are ready.",
    function() return B.db.sct.cdExclude end, function(v) B.db.sct.cdExclude = v end, 280)
  Sld(p, "Ready: cooldowns from", "Only spells with a cooldown this long say when they are ready.", 2, 120, 1, DB, "cdReadyMin", nil,
    function(v) return v .. " s" end)
  for g = 1, table.getn(GROUPS()) do
    W.Card(p, "Formats: " .. string.lower(GROUPS()[g][2]), { folded = true, text = "The wording of each message. %a = amount, %s = spell, %n = name, %t = kind. Empty = the original." })
    for i = 1, table.getn(CT.EVENTS) do
      local e = CT.EVENTS[i]
      if e.group == GROUPS()[g][1] then
        local key = e.key
        W.Edit(p, e.label, nil, function() return B.db.sct.events[key].fmt end, function(v)
          if v == "" then v = B.DEFAULTS.sct.events[key].fmt end
          B.db.sct.events[key].fmt = v
        end, 260)
      end
    end
  end
  O.TabFilter(p)
end

-- ---------------------------------------------------------------- the window's list

-- most used first (user, 22 Oct 2026: "regroup and tidy the combat text pages like the nameplates")
O:AddPage("Combat Text", "ctgeneral", "General", BUILD.ctgeneral)
O:AddPage("Combat Text", "ctareas", "Scroll areas", BUILD.ctareas)
O:AddPage("Combat Text", "ctplates", "Nameplates", BUILD.ctplates)
O:AddPage("Combat Text", "ctcrits", "Crits", BUILD.ctcrits)
O:AddPage("Combat Text", "ctevents", "Messages and sounds", BUILD.ctevents)
O:AddPage("Combat Text", "ctfilters", "Text and filters", BUILD.ctfilters)

-- /sct opens these pages (SCT's own command when SCT itself is not loaded)
if not (IsAddOnLoaded("sct") or IsAddOnLoaded("SCT")) then
  _G.SLASH_PFUISCT1 = "/sct"
  _G.SlashCmdList.PFUISCT = function(msg)
    local rest = string.lower(msg or "")
    if rest == "on" or rest == "off" then
      CT:SetEnabled(rest == "on")
    elseif rest == "test" then
      CT:TestMode(not CT:Testing())
    elseif rest == "plates" then
      CT:TestPlates()
    elseif rest == "preview" or rest == "crit" or rest == "plate" then
      CT:Preview(rest)
    else
      O:Open("ctgeneral")
    end
  end
end
end)
