pfUI:RegisterModule("plates-options", "vanilla:tbc", function ()
  -- pfUI Octo :: the Nameplates section in OctoBG's look. Every setting of
  -- pfUI's own Nameplates page (that page is hidden from the topic list and
  -- Find) plus the Plater-style ones of plates.lua: General, Look and size,
  -- Threat and colours, Target, Cast bar, Debuffs, Range and execute.
  local P = pfUI.plates
  local OU = pfUI.octoui
  local W = OU and OU.W
  local O = OU and OU.Options
  if not P or not W or not O or not O.AddPage then return end
  local BUILD = {}
  local PfChk, PfSld = O.PfChk, O.PfSld

  local function S() return C.plates end
  local function N() return C.nameplates end
  local function ND() return C.nameplates.debuffs end
  local function NN() return C.nameplates.name end
  local function NH() return C.nameplates.health end
  local function U() P.Refresh() end
  local function Pct(v) return math.floor(v + 0.5) .. "%" end
  local function Px(v) return v .. " px" end
  local function Yd(v) return v .. " yd" end
  local function Alpha(v) return math.floor(v * 100 + 0.5) .. "%" end

  -- a pfUI-style string setting as a dropdown / colour / text field
  local function Drop(p, label, desc, options, group, key)
    return W.Dropdown(p, label, desc, options, function() return group()[key] end, function(v)
      group()[key] = v
      U()
    end)
  end
  local function Color(p, label, desc, group, key)
    return W.Color(p, label, desc, function()
      local r, g, b, a = GetStringColor(group()[key] or "1,1,1,1")
      return tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1
    end, function(r, g, b, a)
      group()[key] = string.format("%.2f,%.2f,%.2f,%.2f", r, g, b, a or 1)
      U()
    end)
  end
  local function Edit(p, label, desc, group, key)
    return W.Edit(p, label, desc, function() return group()[key] end, function(v)
      group()[key] = v or ""
      U()
    end, 300)
  end
  local function Chk(p, label, desc, group, key) return PfChk(p, label, desc, group, key, U) end
  local function Sld(p, label, desc, min, max, step, group, key, fmt) return PfSld(p, label, desc, min, max, step, group, key, U, fmt) end

  -- pfUI's "key:label" dropdown lists as Octo options
  local function PfList(list)
    local out = {}
    for _, e in ipairs(list or {}) do
      local _, _, k, l = string.find(e, "^(.-):(.*)$")
      if k then table.insert(out, { key = k, label = l }) end
    end
    return out
  end
  local function DD(name) return PfList(pfUI.gui and pfUI.gui.dropdowns and pfUI.gui.dropdowns[name]) end

  local BARS = {
    { key = "Interface\\AddOns\\pfUI\\img\\plates\\bar-soft", label = "Octo soft" },
    { key = "Interface\\AddOns\\pfUI\\img\\plates\\bar-flat", label = "Octo flat" },
    { key = "Interface\\AddOns\\pfUI\\img\\plates\\bar-gloss", label = "Octo gloss" },
    { key = "Interface\\AddOns\\pfUI\\img\\plates\\bar-glass", label = "Octo glass" },
    { key = "Interface\\AddOns\\pfUI\\img\\plates\\bar-split", label = "Octo split" },
  }
  local function Bars()
    local out = {}
    for _, b in ipairs(BARS) do table.insert(out, b) end
    for _, b in ipairs(DD("uf_bartexture")) do table.insert(out, b) end
    -- each shows as a strip of itself in the menu
    for _, b in ipairs(out) do b.texture = pfUI.media[b.key] end
    return out
  end
  local function Fonts()
    local out = { { key = "", label = "pfUI's font", font = pfUI.font_default } }
    for _, f in ipairs(W.Fonts()) do table.insert(out, { key = f.key, label = f.label, font = f.key }) end
    return out
  end

  local function Count()
    local n = 0
    local kids = { WorldFrame:GetChildren() }
    for _, f in ipairs(kids) do
      if f.nameplate and f:IsVisible() then n = n + 1 end
    end
    return n
  end

  local ROLE = { auto = "Automatic", tank = "Tank", dps = "Damage / healer" }

  local function Auto(v) return v == 0 and "auto" or (v .. " px") end

  -- a mark's art, each choice shown as its icon in its colour
  local function MarkDrop(p, label, key, colorKey)
    local list = {}
    local r, g, b = GetStringColor(C.plates[colorKey] or "1,1,1,1")
    for _, m in ipairs(P.MARKART) do
      table.insert(list, { key = m.key, label = m.label, icon = P.MarkArt(m.key),
        iconColor = { tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1 } })
    end
    return W.Dropdown(p, label, "The art of this mark; None = no mark.", list,
      function() return C.plates[key] end, function(v) C.plates[key] = v; U() end)
  end

  -- Sample nameplates drawn with every setting as it is now (OctoBG's
  -- "Icons on nameplates" box), and the test on the real ones.
  -- A row under the preview naming each mark (user, 22 Oct 2026: "showing
  -- which is a marked target, which is an elite, which is a rare, what the
  -- marks mean"), drawn in the art and colours picked for them.
  local LEGEND = {
    { "Target", function() return P.ART(C.plates.indicator == "chevrons" and "chevron" or "arrow") end, "targetcolor" },
    { "Elite", function() return P.MarkArt(C.plates.markelite) end, "elitecolor" },
    { "Rare", function() return P.MarkArt(C.plates.markrare) end, "rarecolor" },
    { "Rare elite", function() return P.MarkArt(C.plates.markrareelite) end, "rarecolor" },
    { "Boss", function() return P.MarkArt(C.plates.markboss) end, "bosscolor" },
    { "Quest mob", function() return P.MarkArt(C.plates.questobjstyle) end, "questcolor" },
    { "Quest", function() return P.MarkArt(C.plates.queststartstyle) end, "questgivercolor" },
    { "Hand in", function() return P.MarkArt(C.plates.questendstyle) end, "questgivercolor" },
    { "Raid mark", function() return "Interface\\TargetingFrame\\UI-RaidTargetingIcons" end, nil, { .75, 1, .25, .5 } },
  }
  local function Legend(p)
    local row = W.Row(p, 16, 0, 3)
    local items = {}
    local x = 0
    for i, l in ipairs(LEGEND) do
      -- a new line when this one is full
      if x > W.CW - 110 then
        row = W.Row(p, 16, 0, 1)
        x = 0
      end
      local ic = row:CreateTexture(nil, "ARTWORK")
      ic:SetWidth(12)
      ic:SetHeight(12)
      ic:SetPoint("LEFT", row, "LEFT", x, 0)
      local fs = W.Font(row:CreateFontString(nil, "OVERLAY"), 10, .75, .75, .75)
      fs:SetPoint("LEFT", ic, "RIGHT", 3, 0)
      fs:SetText(l[1])
      x = x + 12 + 3 + (fs:GetStringWidth() or 40) + 14
      items[i] = ic
    end
    local function Paint()
      for i, l in ipairs(LEGEND) do
        local ic = items[i]
        local tex = l[2]()
        if tex then ic:SetTexture(tex) ic:Show() else ic:Hide() end
        if l[4] then ic:SetTexCoord(l[4][1], l[4][2], l[4][3], l[4][4]) end
        local r, g, b = 1, 1, 1
        if l[3] == "targetcolor" and C.plates.targetaccent == "1" and GetAccentColor then
          r, g, b = GetAccentColor()
        elseif l[3] then
          r, g, b = GetStringColor(C.plates[l[3]] or "1,1,1,1")
        end
        ic:SetVertexColor(tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1)
      end
    end
    Paint()
    table.insert(p.items, { Refresh = Paint })
  end

  -- (pinned at the top of the page: the options scroll under it)
  local function Preview(p, h)
    W.Pin(p, "Preview", "Click any part to open its settings, drag it to move it, hold Shift and scroll the mouse wheel over it "
      .. "to make it bigger or smaller, right-click it to put it back. "
      .. "Sample plates drawn by the real nameplate code with your settings: your target "
      .. "casting (every other cast is interrupted), a mob going through the threat colours, one at low health and "
      .. "a friendly player. Changes show here at once. Click this bar to fold it away.", function(p)
    -- (29 Oct 2026, user: the preview "takes up too much room"): the full one
    -- on General and Look and size; a short box without the legend elsewhere
    local full = not p.key or p.key == "npgeneral" or p.key == "nplook"
    local box = (W.ZoomBox or W.Box)(p, h or (full and 215 or 110))
    local samples = P.AttachPreview(box)
    -- Shift + wheel anywhere on the box sizes the part under the mouse; the
    -- plain wheel scrolls the page
    box:EnableMouseWheel(true)
    box:SetScript("OnMouseWheel", function()
      local hot = IsShiftKeyDown() and P.HotUnderMouse(samples)
      if hot and P.SIZE[hot.what] then P.Resize(hot.what, arg1 or 0, hot.region) else P.PassWheel(this) end
    end)
    if full then
    -- what the marks mean, in your own art and colours
    Legend(p)
    -- what the mouse does, in an accent band so it stands out
    local band = W.Row(p, 20, 0, 3)
    local bg = band:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(band)
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    local ar, ag, ab = 0.2, 0.55, 0.9
    if GetAccentColor then ar, ag, ab = GetAccentColor() end
    bg:SetVertexColor(ar, ag, ab, .22)
    local edge = band:CreateTexture(nil, "BORDER")
    edge:SetTexture("Interface\\Buttons\\WHITE8X8")
    edge:SetVertexColor(ar, ag, ab, 1)
    edge:SetWidth(3)
    edge:SetPoint("TOPLEFT", band, "TOPLEFT", 0, 0)
    edge:SetPoint("BOTTOMLEFT", band, "BOTTOMLEFT", 0, 0)
    local how = band:CreateFontString(nil, "OVERLAY")
    how:SetFont(W.UIFont(), 11, "OUTLINE")
    how:SetPoint("LEFT", band, "LEFT", 12, 0)
    how:SetPoint("RIGHT", band, "RIGHT", -8, 0)
    how:SetJustifyH("LEFT")
    local key = string.format("|cff%02x%02x%02x", math.floor(ar * 255), math.floor(ag * 255), math.floor(ab * 255))
    how:SetText(key .. "Click|r  options     " .. key .. "Drag|r  move     " .. key .. "Shift + wheel|r  bigger / smaller     "
      .. key .. "Right-click|r  put it back")
    W.HowTo(p, band, how:GetText(), nil, 150)
    -- the test's time left, at the band's right end
    local status = band:CreateFontString(nil, "OVERLAY")
    status:SetFont(W.UIFont(), 12, "OUTLINE")
    status:SetPoint("RIGHT", band, "RIGHT", -8, 0)
    band:SetScript("OnUpdate", function()
      if P.Testing() then status:SetText("|cff55ff55Test " .. math.ceil(P.testUntil - GetTime()) .. " s|r") else status:SetText("") end
    end)
    end
    W.Buttons(p, {
      { "Reset everything", function()
        -- a second click within 4 s does it
        if (P.resetAsk or 0) < GetTime() then
          P.resetAsk = GetTime() + 4
          DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r: click |cffffffffReset everything|r again to put every nameplate setting back as it came.")
          return
        end
        P.resetAsk = nil
        P.ResetAll()
        -- the controls read the settings again (no rebuild: pages stay as built)
        O:Refresh()
      end, 130, "Every nameplate setting - looks, sizes, colours, places, auras, lists - back to how it came (the Plater look). Click twice." },
      { "Put parts back", function()
        for _, k in ipairs({ "castoffx", "castoffy", "cpoffx", "cpoffy", "auraoffx", "specialoffx", "specialoffy",
          "nameoffx", "nameoffy", "leveloffx", "leveloffy", "hpoffx", "hpoffy", "markoffx", "markoffy",
          "questoffx", "questoffy", "ciconoffx", "ciconoffy", "targetgap" }) do C.plates[k] = "0" end
        C.plates.auraoffset = "2"
        C.nameplates.raidiconoffx, C.nameplates.raidiconoffy = "0", "-5"
        U()
        W.Refresh(p)
      end, 120, "Everything you dragged goes back to its first place." },
      -- (lit while it runs; a second click stops it)
      { "Test on real nameplates", function() if P.Testing() then P.Test(0) else P.Test(60) end end, 180,
        "For a minute every nameplate you can see gets pretend threat colours and casts (every other one interrupted by Bob). V shows enemy plates, Shift-V friendly ones, e.g. in a city. Click again to stop.",
        on = function() return P.Testing() end },
      { "Grid", function()
        C.plates.previewgrid = (C.plates.previewgrid == "0") and "1" or "0"
        U()
      end, 60, "Grid lines in the preview on or off, with a yellow middle line across and down each sample to line parts up.",
        on = function() return C.plates.previewgrid ~= "0" end },
    })
    end)
  end

  -- the looks, four to a row; the picked one is lit (none = your own mix)
  local function Looks(p)
    local btns = {}
    local rows = {}
    local n = table.getn(P.PRESETS)
    for r = 1, math.ceil(n / 4) do rows[r] = W.Row(p, 24, 0, 6) end
    local mix = W.Live(p, function()
      local _, label = P.CurrentLook()
      return label and ("Look: |cffffffff" .. label .. "|r") or "Look: |cffffffffyour own mix|r (a setting was changed after picking a look)"
    end)
    local function Paint()
      local cur = P.CurrentLook()
      for _, b in ipairs(btns) do W.Pick(b, b.key == cur) end
    end
    for i, pr in ipairs(P.PRESETS) do
      local b = W.Button(rows[math.floor((i - 1) / 4) + 1], pr[2], 160, 22)
      b:SetPoint("LEFT", b:GetParent(), "LEFT", math.mod(i - 1, 4) * 166, 0)
      b.key = pr[1]
      b:SetScript("OnClick", function()
        P.ApplyPreset(this.key)
        Paint()
        W.Refresh(p)
      end)
      W.Tip(b, pr[2], "Sets the bar texture, border, size, text and target marker. Colours, lists and on / off switches stay as they are.")
      btns[i] = b
    end
    -- other pages change settings too: keep the lit button right
    rows[1]:SetScript("OnUpdate", function()
      if (this.tick or 0) > GetTime() then return end
      this.tick = GetTime() + .5
      Paint()
    end)
    Paint()
    return mix
  end

  -- ---------------------------------------------------------------- general

  BUILD.npgeneral = function(p)
    W.Heading(p, "Nameplates", {
      on = { function() return C.plates.enable == "1" end, function(v) C.plates.enable = v and "1" or "0"; U() end,
             "Plater-style nameplates on or off. Off: pfUI's own nameplates as they were." },
      about = "Plater's ideas on pfUI's nameplates: aggro colours that flip for tanks, sizes per kind of unit, "
        .. "target arrows, a Plater cast bar that says who interrupted, execute range, plates that fade out of "
        .. "range. The art is pfUI Octo's own." })
    W.Live(p, function()
      local s = {}
      local n = Count()
      table.insert(s, n .. " nameplate" .. ((n == 1) and "" or "s") .. " on screen" .. ((n == 0) and " - V shows enemy plates, Shift-V friendly" or ""))
      table.insert(s, "role: " .. (P.Role() == "tank" and "tank" or "damage / healer"))
      table.insert(s, P.SuperWoW() and "SuperWoW |cff55ff55found|r" or "SuperWoW |cffff5555missing|r (no threat colours on other plates)")
      table.insert(s, UnitXP and "UnitXP |cff55ff55found|r" or "UnitXP |cffff5555missing|r (no range fade)")
      return table.concat(s, "    ")
    end)
    Preview(p)
    W.Card(p, "Show")
    PfChk(p, "Enemies", "Nameplates on hostile units at login (V turns them on and off in game).", N, "showhostile", P.ApplyShow)
    PfChk(p, "Friends", "Nameplates on friendly units at login (Shift-V in game).", N, "showfriendly", P.ApplyShow)
    if pfUI.client <= 11200 then
      Chk(p, "Overlap - no jumping (stacking off)", "Plates cross over each other smoothly instead of jumping apart to make room. Best with many targets.", N, "overlap")
    end
    Chk(p, "Totems as icons", "A totem shows its icon instead of a bar.", N, "totemicons")
    Chk(p, "Guild names", "The guild under a player's name.", N, "showguildname")
    Chk(p, "Combo points", "Your combo points under the target's plate.", N, "cpdisplay")
    Chk(p, "Elite, rare and boss marks", "A star (gold elite, silver rare) or a skull (boss) by the name.", S, "eliteicon")
    W.Card(p, "Name only (no bar) on", { tip = "These show just their name and level." })
    Chk(p, "Enemy NPCs", nil, N, "enemynpc")
    Chk(p, "Enemy players", nil, N, "enemyplayer")
    Chk(p, "Neutral NPCs", nil, N, "neutralnpc")
    Chk(p, "Friendly NPCs", nil, N, "friendlynpc")
    Chk(p, "Friendly players", nil, N, "friendlyplayer")
    Chk(p, "Critters", nil, N, "critters")
    Chk(p, "Totems", nil, N, "totems")
    Chk(p, "Still a bar when hurt", "A unit that has lost health keeps its bar.", N, "fullhealth")
    Chk(p, "Still a bar on the target", nil, N, "target")
    W.Card(p, "Smoothness", { folded = true, tip = "Your target, casting plates and plates that are moving always redraw on every frame." })
    Sld(p, "Other plates redraw", "How often a calm plate redraws, per second. Lower = more frames per second in big pulls; 60 = every frame.",
      10, 60, 5, S, "calmfps", function(v) return (tonumber(v) or 30) >= 60 and "every frame" or (v .. " a second") end)
    if pfUI.client <= 11200 then
      W.Card(p, "Clicks", { folded = true })
      Chk(p, "Click through", "Plates ignore the mouse.", N, "clickthrough")
      Chk(p, "Right-click turns the camera", "Hold right-click on a plate to turn; a quick click targets and attacks.", N, "rightclick")
      Sld(p, "Quick click under", "How short a right-click must be to count as a click.", 0.1, 1, 0.05, N, "clickthreshold", function(v) return v .. " s" end)
      Sld(p, "Raise plates by", "Moves every plate up (or down) from where the game puts it.", -50, 50, 1, N, "vertical_offset", Px)
    end
  end

  -- ---------------------------------------------------------------- look and size

  -- the four kinds of plate, sized as % of the width and height; the one you
  -- moved last is the one "Match" copies (user, 23 Oct 2026: "a button ...
  -- that matches all the frame sizes if you change one")
  local KINDS = { { "size_enemynpc", "Enemy NPCs" }, { "size_enemyplayer", "Enemy players" },
    { "size_friendlynpc", "Friendly NPCs" }, { "size_friendlyplayer", "Friendly players" } }
  function P.MatchSizes(from)
    from = from or P.lastSize or "size_enemynpc"
    local v = C.plates[from] or "100"
    for _, k in ipairs(KINDS) do C.plates[k[1]] = v end
    U()
  end
  local function KindLabel(key)
    for _, k in ipairs(KINDS) do if k[1] == key then return k[2] end end
    return KINDS[1][2]
  end

  BUILD.nplook = function(p)
    W.Heading(p, "Look and size", { about = "Ready-made looks first, then one card for each part of a plate - everything "
      .. "about it in one place: shown or not, letters, size, colour and where it sits. Click a part in the preview to jump to its card." })
    Preview(p)
    O.CardTabs(p, {
      { "look", "Look", "INV_Misc_Gem_Variety_01", { "Looks", "Size by kind", "Border" } },
      { "bar", "Health bar", "Spell_Holy_Heal02", { "Health bar", "Health text" } },
      { "text", "Name and level", "INV_Scroll_03", { "Letters", "Name", "Level" } },
      { "marks", "Marks", "INV_Banner_01", { "Combo points", "Raid mark" } },
    })
    W.Card(p, "Looks", { tip = "Ready-made styles: bar texture, border skin, sizes, text and target marker in one click." })
    Looks(p)
    W.Card(p, "Size by kind", { tip = "% of the health bar's width and height; plates grow and shrink smoothly." })
    for _, k in ipairs(KINDS) do
      local key = k[1]
      PfSld(p, k[2], nil, 40, 160, 5, S, key, function()
        P.lastSize = key
        if C.plates.sizematch == "1" then P.MatchSizes(key) O:Refresh() else U() end
      end, Pct)
    end
    Sld(p, "Out of combat", "Plates shrink to this while you are not fighting.", 40, 120, 5, S, "size_ooc", Pct)
    Chk(p, "Keep every kind the same size", "Moving one of the four sizes above moves the others with it.", S, "sizematch")
    W.Buttons(p, {
      { "Match all sizes", function()
        P.MatchSizes()
        O:Refresh()
      end, 150, "Every kind of plate takes the size of the one you changed last (enemy NPCs if you have not changed one)." },
    })
    W.Live(p, function()
      return "Match copies: |cffffffff" .. KindLabel(P.lastSize) .. " (" .. (C.plates[P.lastSize or "size_enemynpc"] or "100") .. "%)|r"
    end)
    -- letters for all text on plates
    W.Card(p, "Letters", { tip = "The font and outline of every text on plates." })
    Drop(p, "Font", "The letters of names and numbers on plates.", Fonts(), S, "font")
    Drop(p, "Outline", nil, DD("fontstyle"), NN, "fontstyle")
    Chk(p, "Unit frame font", "Use pfUI's unit frame font when no font is picked above.", N, "use_unitfonts")
    W.Card(p, "Name", { on = { function() return C.plates.nameshow ~= "0" end, function(v) C.plates.nameshow = v and "1" or "0"; U() end,
      "Show the name." }, tip = "Click a swatch for the colour wheel." })
    Sld(p, "Size", "0 = pfUI's font size.", 0, 24, 1, S, "namesize", function(v) return v == 0 and "pfUI's" or (v .. " px") end)
    Chk(p, "My own colour", "Off: white, orange in a fight, class colours as set on Threat and colours.", S, "namecustom")
    Color(p, "Colour", nil, S, "namecolor")
    Sld(p, "Left / right", "Or drag the name in the preview.", -80, 80, 1, S, "nameoffx", Px)
    Sld(p, "Up / down", nil, -40, 40, 1, S, "nameoffy", Px)
    W.Card(p, "Level", { on = { function() return C.plates.levelshow ~= "0" end, function(v) C.plates.levelshow = v and "1" or "0"; U() end,
      "Show the level." } })
    Chk(p, "My own colour", "Off: the game's difficulty colour.", S, "levelcustom")
    Color(p, "Colour", nil, S, "levelcolor")
    Sld(p, "Left / right", "Or drag the level in the preview.", -80, 80, 1, S, "leveloffx", Px)
    Sld(p, "Up / down", nil, -40, 40, 1, S, "leveloffy", Px)
    W.Card(p, "Health bar")
    Drop(p, "Texture", "The fill of the health and cast bars. The Octo ones are pfUI Octo's own art.", Bars(), S, "bartexture")
    Color(p, "Background", "Behind the bars (the empty part).", S, "bgcolor")
    Sld(p, "Width", nil, 60, 250, 1, N, "width", Px)
    Sld(p, "Height", nil, 2, 30, 1, N, "heighthealth", Px)
    Sld(p, "Gap under the name", "Space between the name and the bar.", -10, 10, 1, NH, "offset", Px)
    Chk(p, "Upright bar", "The health bar fills from the bottom up.", N, "verticalhealth")
    W.Card(p, "Border", { tip = "The thin border round the bars, and the skin around that." })
    Drop(p, "Border skin", "The edge around the health and cast bars.", {
      { key = "pfui", label = "Thin black (pfUI)" }, { key = "shadow", label = "Soft shadow" }, { key = "thick", label = "Thick black" },
      { key = "accent", label = "Accent line" }, { key = "neon", label = "Neon glow (accent)" }, { key = "gold", label = "Gold line" },
    }, S, "skin")
    Chk(p, "My own skin colour", "Off: each border skin's own colour (black, accent, gold...).", S, "skincustom")
    Color(p, "Skin colour", nil, S, "skincolor")
    Chk(p, "My own border colour", "Off: pfUI's black, or its target / combat state colours.", S, "bordercustom")
    Color(p, "Border colour", "The thin border round the health and cast bars.", S, "bordercolor")
    W.Card(p, "Health text", { on = { function() return C.nameplates.showhp == "1" end, function(v) C.nameplates.showhp = v and "1" or "0"; U() end,
      "Numbers on the health bar." } })
    Drop(p, "Shows", nil, DD("hpformat"), N, "hptextformat")
    Drop(p, "Place", nil, DD("textalign"), N, "hptextpos")
    Sld(p, "Size", "0 = a bit smaller than the name.", 0, 24, 1, S, "hpsize", function(v) return v == 0 and "auto" or (v .. " px") end)
    Color(p, "Colour", nil, S, "hptextcolor")
    Sld(p, "Left / right", "Or drag it in the preview.", -80, 80, 1, S, "hpoffx", Px)
    Sld(p, "Up / down", nil, -30, 30, 1, S, "hpoffy", Px)
    W.Card(p, "Combo points", { on = { function() return C.nameplates.cpdisplay == "1" end,
      function(v) C.nameplates.cpdisplay = v and "1" or "0"; U() end, "Your combo points on your target's plate." } })
    W.Dropdown(p, "Style", nil, { { key = "orbs", label = "Orbs" }, { key = "gems", label = "Gems" },
      { key = "squares", label = "Squares" }, { key = "segments", label = "Bar segments" }, { key = "pfui", label = "pfUI's small squares" } },
      function() return C.plates.cpstyle end, function(v) C.plates.cpstyle = v; U() end)
    W.Dropdown(p, "Place", nil, { { key = "below", label = "Under the bars" }, { key = "above", label = "Above the name" },
      { key = "inside", label = "On the health bar" } }, function() return C.plates.cpplace end, function(v) C.plates.cpplace = v; U() end)
    Sld(p, "Size", nil, 6, 30, 1, S, "cpsize", Px)
    Sld(p, "Gap", nil, 0, 12, 1, S, "cpgap", Px)
    Sld(p, "Left / right", nil, -80, 80, 1, S, "cpoffx", Px)
    Sld(p, "Up / down", nil, -40, 40, 1, S, "cpoffy", Px)
    W.Dropdown(p, "Colour", nil, { { key = "gradient", label = "Yellow to red by count" }, { key = "class", label = "Class colour" },
      { key = "custom", label = "One colour" } }, function() return C.plates.cpcolor end, function(v) C.plates.cpcolor = v; U() end)
    Color(p, "One colour", nil, S, "cpcustom")
    Chk(p, "Empty slots", "Show the points you do not have yet, dimmed.", S, "cpempty")
    Chk(p, "Glow at 5", "The points pulse when you have all five.", S, "cpglow")
    W.Card(p, "Raid mark", { folded = true })
    Drop(p, "Place", nil, DD("positions"), N, "raidiconpos")
    Sld(p, "Size", nil, 8, 48, 1, N, "raidiconsize", Px)
    Sld(p, "Left / right", nil, -60, 60, 1, N, "raidiconoffx", Px)
    Sld(p, "Up / down", nil, -60, 60, 1, N, "raidiconoffy", Px)
    O.TabFilter(p)
  end

  -- ---------------------------------------------------------------- threat

  BUILD.npthreat = function(p)
    W.Heading(p, "Threat and colours", {
      on = { function() return C.plates.threat == "1" end, function(v) C.plates.threat = v and "1" or "0"; U() end,
             "Aggro colours on the bars of mobs fighting you." },
      about = "Damage and healers: red = the mob is on you, orange = you are about to pull it off the tank (your "
        .. "target, from the server's threat numbers), purple = it is on someone else. Tanks: blue = it is on you, orange = someone is about to "
        .. "pull it, purple = another tank has it, red = it is loose on someone else. Needs SuperWoW for plates "
        .. "other than your target." })
    W.Live(p, function() return "You count as: " .. (P.Role() == "tank" and "|cff55aaffTank|r" or "|cffff7755Damage / healer|r") end)
    Preview(p)
    W.Card(p, "Role")
    W.Dropdown(p, "Role", "Automatic: tank in Defensive Stance, bear form, with Righteous Fury or marked a tank in pfUI's raid frames.",
      { { key = "auto", label = ROLE.auto }, { key = "tank", label = ROLE.tank }, { key = "dps", label = ROLE.dps } },
      function() return C.plates.role end, function(v) C.plates.role = v; U() end)
    Sld(p, "Pulling at", "% of the tank's threat that counts as about to pull.", 50, 130, 5, S, "pullat", Pct)
    Chk(p, "Aggro glow", "A glow around the plate when a mob is on you (or, for tanks, loose on someone else).", S, "aggroglow")
    W.Card(p, "Damage and healer colours")
    Color(p, "On you", nil, S, "c_aggro")
    Color(p, "Pulling", nil, S, "c_pulling")
    Color(p, "On someone else", nil, S, "c_safe")
    Chk(p, "Keep the normal colour", "On someone else: no colour of its own.", S, "safenormal")
    W.Card(p, "Tank colours")
    Color(p, "On you", nil, S, "c_tankaggro")
    Color(p, "Losing it", nil, S, "c_losing")
    Color(p, "On another tank", nil, S, "c_offtank")
    Color(p, "Lost", nil, S, "c_lost")
    Color(p, "Taking it from a tank", "On another tank, and you are near its threat (your target).", S, "c_taking")
    Edit(p, "Other tanks", "Names separated by #. pfUI's raid frame tank marks count too.", N, "combatofftanks")
    W.Card(p, "Class and name colours")
    Chk(p, "Class colours on enemies", nil, N, "enemyclassc")
    Chk(p, "Class colours on friends", nil, N, "friendclassc")
    Chk(p, "Class coloured friend names", nil, N, "friendclassnamec")
    Chk(p, "Orange name in a fight", "The name turns orange while the unit fights.", N, "namefightcolor")
    W.Card(p, "Border colours", { folded = true, tip = "pfUI's own colours on the bar's border." })
    Chk(p, "Friendly players blue", nil, N, "outfriendly")
    Chk(p, "Friendly NPCs green", nil, N, "outfriendlynpc")
    Chk(p, "Neutral yellow", nil, N, "outneutral")
    Chk(p, "Enemies red", nil, N, "outenemy")
    Chk(p, "Combat state on the border", "SuperWoW: the border shows who the mob attacks (colours below).", N, "outcombatstate")
    Chk(p, "Combat state on the bar", "pfUI's own bar colours by combat state (threat colours above win).", N, "barcombatstate")
    Chk(p, "Attacking you", nil, N, "ccombatthreat")
    Chk(p, "Attacking an off-tank", nil, N, "ccombatofftank")
    Chk(p, "Attacking others", nil, N, "ccombatnothreat")
    Chk(p, "Attacking no one", nil, N, "ccombatstun")
    Chk(p, "Casting", nil, N, "ccombatcasting")
    Color(p, "Attacking you", nil, N, "combatthreat")
    Color(p, "Attacking an off-tank", nil, N, "combatofftank")
    Color(p, "Attacking others", nil, N, "combatnothreat")
    Color(p, "Attacking no one", nil, N, "combatstun")
    Color(p, "Casting", nil, N, "combatcasting")
  end

  -- ---------------------------------------------------------------- target

  BUILD.nptarget = function(p)
    W.Heading(p, "Target, range and execute", { about = "How your target's plate stands out, plates that fade when far "
      .. "away or out of sight (needs UnitXP), and the colour of a mob low enough to execute." })
    Preview(p)
    W.Card(p, "Target")
    W.Dropdown(p, "Marker", "Beside or around your target's bar.",
      { { key = "arrows", label = "Arrows" }, { key = "chevrons", label = "Double arrows" }, { key = "corners", label = "Corners" },
        { key = "underglow", label = "Light under the bar" }, { key = "none", label = "None" } },
      function() return C.plates.indicator end, function(v) C.plates.indicator = v; U() end)
    Chk(p, "Accent colour", "The marker in pfUI Octo's accent colour.", S, "targetaccent")
    Color(p, "Marker colour", "When the accent colour is off.", S, "targetcolor")
    Sld(p, "Target size", "Your target's plate grows to this.", 80, 160, 5, S, "size_target", Pct)
    Sld(p, "Marker size", "0 = twice the bar's height.", 0, 60, 1, S, "targetsize", Auto)
    Sld(p, "Marker distance", "How far the arrows sit from the bar. Or drag them in the preview.", -20, 60, 1, S, "targetgap", Px)
    Sld(p, "Other plates", "How see-through the plates that are not your target are.", 0.1, 1, 0.05, N, "notargalpha", Alpha)
    Chk(p, "Mouse-over highlight", "The bar lights up under the mouse.", S, "mouseover")
    W.Card(p, "More target effects", { folded = true })
    Chk(p, "Glow", "pfUI's soft glow behind the target.", N, "targetglow")
    Color(p, "Glow colour", nil, N, "glowcolor")
    Chk(p, "Border", "A coloured border on the target's bar.", N, "targethighlight")
    Color(p, "Border colour", nil, N, "highlightcolor")
    Chk(p, "Zoom", "pfUI's zoom: the target's bar gets wider and taller.", N, "targetzoom")
    Sld(p, "Zoom by", nil, 0.05, 1, 0.05, N, "targetzoomval", Alpha)
  end

  -- ---------------------------------------------------------------- cast bar

  BUILD.npcast = function(p)
    W.Heading(p, "Cast bar", {
      on = { function() return C.nameplates.showcastbar == "1" end, function(v) C.nameplates.showcastbar = v and "1" or "0"; U() end,
             "Cast bars under nameplates." },
      about = "What a unit is casting, under its plate. When a cast ends it flashes green (done) or red (stopped), "
        .. "with who interrupted it when the combat log says." })
    Preview(p)
    W.Card(p, "Bar")
    W.Dropdown(p, "Layout", "Plater: the icon left of the bar, the spell's name in the bar, the time on the right. pfUI: as pfUI had it.",
      { { key = "plater", label = "Plater" }, { key = "pfui", label = "pfUI" } },
      function() return C.plates.castlayout end, function(v) C.plates.castlayout = v; U() end)
    W.Slider(p, "Height", nil, 4, 24, 1, function() return tonumber(C.plates.castheight) end, function(v)
      C.plates.castheight = tostring(v)
      C.nameplates.heightcast = tostring(v)
      U()
    end, Px)
    Chk(p, "Only your target", "Other units' casts are not shown.", N, "targetcastbar")
    Chk(p, "Spell icon", nil, S, "casticon")
    Sld(p, "Icon size", "0 = as tall as the bar.", 0, 40, 1, S, "casticonsize", function(v) return v == 0 and "auto" or (v .. " px") end)
    Chk(p, "Time left", nil, S, "casttimer")
    Chk(p, "Spell name", nil, S, "castname")
    Sld(p, "Text size", "0 = fits the bar.", 0, 24, 1, S, "casttextsize", function(v) return v == 0 and "auto" or (v .. " px") end)
    Color(p, "Text colour", "The spell name and time.", S, "casttextcolor")
    Sld(p, "Left / right", "Or drag the cast bar in the preview.", -100, 100, 1, S, "castoffx", Px)
    Sld(p, "Up / down", "Minus = lower. Or drag the cast bar in the preview.", -80, 80, 1, S, "castoffy", Px)
    Chk(p, "Spell name (pfUI layout)", "The Plater layout always shows it.", N, "spellname")
    Chk(p, "Spark", "A bright edge where the bar fills.", S, "spark")
    Chk(p, "Flash when it ends", "Green when the cast went off, red when it was stopped.", S, "castend")
    Chk(p, "Who interrupted", "\"Interrupted by NAME\" on the red flash.", S, "kicker")
    W.Card(p, "Colours")
    Color(p, "Casting", nil, S, "c_cast")
    Color(p, "Channelling", nil, S, "c_channel")
    Color(p, "Done", nil, S, "c_done")
    Color(p, "Stopped", nil, S, "c_stopped")
    Color(p, "Background", "The empty part of the cast bar (lighter than the health bar's, so a new cast shows).", S, "castbg")
  end

  -- ---------------------------------------------------------------- debuffs

  local function ListEdit(p, label, desc, key)
    return W.Edit(p, label, desc, function() return C.plates[key] end, function(v)
      C.plates[key] = v or ""
      U()
    end, 420)
  end

  BUILD.npauras = function(p)
    W.Heading(p, "Auras", {
      on = { function() return C.plates.auras == "1" end, function(v) C.plates.auras = v and "1" or "0"; U() end,
             "Plater-style buff and debuff icons. Off: pfUI's own debuff row (Old debuff row below)." },
      about = "Icons above the name: your debuffs and crowd control on the mob, then its important buffs (gold edge), "
        .. "with timers and stacks. Edges show the debuff type: blue Magic, purple Curse, brown Disease, green Poison. "
        .. "Special auras are big icons on top; ghost auras are your own debuffs missing from a mob you fight, faded. "
        .. "With SuperWoW every plate knows its auras; without it only your target does. Timers are known for your own "
        .. "debuffs (and others' when ClassicAPI tells)." })
    Preview(p)
    O.CardTabs(p, {
      { "show", "What shows", "Spell_Holy_MagicalSentry", { "Enemy buffs", "What shows", "Icons" } },
      { "special", "Special and ghost", "Spell_Shadow_DeathCoil", { "Special auras", "Ghost auras" } },
      { "old", "Old debuff row", "INV_Misc_Book_08", { "Old debuff row" } },
    })
    -- (user, 29 Oct 2026: "SHOW ENEMY BUFFS clear somewhere ... all ENEMY NPC AND PLAYERS buffs")
    W.Card(p, "Enemy buffs", { tip = "Buffs on enemies - NPCs and players. The same switches are on Unit frames > Frames." })
    W.Dropdown(p, "Enemy buffs on nameplates", "All: every buff an enemy has. Important: big cooldowns only (Ice Block, Shield Wall...).",
      { { key = "all", label = "All of them" }, { key = "important", label = "Important ones" }, { key = "none", label = "None" } },
      function() return C.plates.buffshow end, function(v) C.plates.buffshow = v; U() end)
    W.Check(p, "Show every enemy buff on your target's frame", "Buffs the game hides on enemy players are found too (pfUI's "
      .. "enemy buff detection). Changes after a reload.", function() return C.unitframes.buffdetect == "1" end,
      function(v) C.unitframes.buffdetect = v and "1" or "0" if pfUI.gui then pfUI.gui.settingChanged = true end end)
    W.Card(p, "What shows")
    W.Dropdown(p, "Debuffs", nil, { { key = "mine_cc", label = "Yours and crowd control" }, { key = "mine", label = "Only yours" },
      { key = "all", label = "All" } }, function() return C.plates.debuffshow end, function(v) C.plates.debuffshow = v; U() end)
    W.Dropdown(p, "Filter", "Applies to debuffs.",
      { { key = "none", label = "No list" }, { key = "blacklist", label = "Hide the black list" }, { key = "whitelist", label = "Only the white list" } },
      function() return C.nameplates.debuffs.filter end, function(v) C.nameplates.debuffs.filter = v; U() end)
    Edit(p, "Black list", "Debuff names separated by #.", ND, "blacklist")
    Edit(p, "White list", "Debuff names separated by #.", ND, "whitelist")
    W.Card(p, "Icons")
    Sld(p, "Width", nil, 10, 40, 1, S, "aurawidth", Px)
    Sld(p, "Height", nil, 10, 40, 1, S, "auraheight", Px)
    Sld(p, "Per row", nil, 1, 12, 1, S, "auraperrow")
    Sld(p, "Rows", nil, 1, 3, 1, S, "aurarows")
    W.Dropdown(p, "Grow", nil, { { key = "center", label = "From the middle" }, { key = "right", label = "To the right" },
      { key = "left", label = "To the left" } }, function() return C.plates.auragrow end, function(v) C.plates.auragrow = v; U() end)
    Sld(p, "Above the name by", nil, -10, 30, 1, S, "auraoffset", Px)
    Sld(p, "Left / right", "Or drag the icons in the preview.", -100, 100, 1, S, "auraoffx", Px)
    Sld(p, "Gap between icons", nil, 0, 12, 1, S, "auragap", Px)
    Sld(p, "Gap between rows", nil, 0, 12, 1, S, "auragaprow", Px)
    Sld(p, "Timer size", "0 = fits the icon.", 0, 24, 1, S, "auratimersize", function(v) return v == 0 and "auto" or (v .. " px") end)
    Sld(p, "Stack size", "0 = fits the icon.", 0, 24, 1, S, "aurastacksize", function(v) return v == 0 and "auto" or (v .. " px") end)
    Chk(p, "Timers", "Time left on the icon (red under 3 s).", S, "auratimer")
    Chk(p, "Stacks", nil, S, "aurastacks")
    Chk(p, "Edges by debuff type", nil, S, "auraborder")
    W.Card(p, "Special auras", { on = { function() return C.plates.specialon == "1" end, function(v) C.plates.specialon = v and "1" or "0"; U() end,
      "Big icons for the spells listed." } })
    Sld(p, "Size", nil, 16, 48, 1, S, "specialsize", Px)
    Sld(p, "Gap", "Between the big icons, and above the normal rows.", 0, 12, 1, S, "specialgap", Px)
    Sld(p, "Left / right", "Or drag them in the preview.", -100, 100, 1, S, "specialoffx", Px)
    Sld(p, "Up / down", nil, -60, 60, 1, S, "specialoffy", Px)
    ListEdit(p, "Spells", "Names separated by #. Shown big, on top, edged in the accent colour.", "specialauras")
    W.Card(p, "Ghost auras", { on = { function() return C.plates.ghoston == "1" end, function(v) C.plates.ghoston = v and "1" or "0"; U() end,
      "Your own debuffs that are missing from a mob you are fighting, shown faded." } })
    ListEdit(p, "Spells", "Your debuffs to keep up, separated by #. Their icons come from your spellbook.", "ghostauras")
    Sld(p, "Faded to", nil, 0.1, 1, 0.05, S, "ghostalpha", Alpha)
    W.Buttons(p, { { "Fill with my class's usual", function()
      local _, class = UnitClass("player")
      C.plates.ghostauras = P.Auras and P.Auras.GHOSTS[class or ""] or ""
      U()
      W.Refresh(p)
    end, 200, "Warlock: Corruption, Curse of Agony, Immolate; priest: Shadow Word: Pain; and so on." } })
    W.Card(p, "Old debuff row", { folded = true, tip = "pfUI's own debuff icons, used while Auras is off." })
    Chk(p, "Show it", nil, N, "showdebuffs")
    W.Dropdown(p, "Place", nil, { { key = "TOP", label = "Above" }, { key = "BOTTOM", label = "Below" } },
      function() return C.nameplates.debuffs.position end, function(v) C.nameplates.debuffs.position = v; U() end)
    Sld(p, "Size", nil, 8, 40, 1, N, "debuffsize", Px)
    Sld(p, "Gap", "Space between the bar and the icons.", 0, 20, 1, N, "debuffoffset", Px)
    Chk(p, "Stacks", "The stack count on the icon.", ND, "showstacks")
    Chk(p, "Only yours", "Only the debuffs you put on.", N, "selfdebuff")
    Chk(p, "Estimate", "Remember debuffs seen on a unit for plates that cannot read them.", N, "guessdebuffs")
    O.TabFilter(p)
  end

  -- ---------------------------------------------------------------- colours and names

  local function Hex(c)
    if not c then return "" end
    return string.format("|cff%02x%02x%02x", math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255))
  end

  -- An editor for one list (NPCs or spells): name, colour, new name, then
  -- Save / Remove, and the list below. Typing a name already listed loads it.
  local function ListEditor(p, key, what, fromTarget, targetTip)
    local ed = { name = "", color = nil, rename = "" }
    local L = P.Lists
    local function Load(name)
      ed.name = name or ""
      local e = L.Parse(C.plates[key])[string.lower(ed.name)]
      ed.color = e and e.color
      ed.rename = e and e.rename or ""
    end
    W.Edit(p, what, "Type the name and press Enter (an entry already listed is loaded).", function() return ed.name end,
      function(v) Load(v) W.Refresh(p) end, 300)
    W.Color(p, "Colour", "The bar colour for this name. No colour = only the new name.", function()
      local c = ed.color or { 1, 1, 1 }
      return c[1], c[2], c[3], 1
    end, function(r, g, b) ed.color = { r, g, b } end)
    W.Edit(p, "Show as", "A new name to show instead (empty = keep).", function() return ed.rename end, function(v) ed.rename = v or "" end, 300)
    W.Buttons(p, {
      { "Use my target", function() Load(fromTarget() or "") end, 130, targetTip },
      { "No colour", function() ed.color = nil end, 100, "Keeps the normal colour; only the new name is used." },
      { "Save", function()
        L.Put(key, ed.name, ed.color, ed.rename)
        P.Refresh()
      end, 90, "Adds or changes this entry." },
      { "Remove", function()
        L.Remove(key, ed.name)
        Load("")
        P.Refresh()
      end, 90, "Takes this name off the list." },
    })
    W.Live(p, function()
      local list = L.Parse(C.plates[key])
      local keys = {}
      for k in pairs(list) do table.insert(keys, k) end
      table.sort(keys)
      if table.getn(keys) == 0 then return "|cff999999Nothing listed yet.|r" end
      local lines = {}
      for _, k in ipairs(keys) do
        local e = list[k]
        table.insert(lines, (e.color and (Hex(e.color) .. "####|r ") or "") .. e.name .. (e.rename and ("  ->  " .. e.rename) or ""))
      end
      return table.concat(lines, "\n")
    end)
  end

  -- Plater's NPC Colors (on Threat and colours) and Cast Colors (on Cast bar)
  local function NpcCards(p)
    W.Card(p, "NPC colours and names", { tip = "An NPC's own bar colour or a shorter name. Threat colours win while you fight, unless ticked below." })
    ListEditor(p, "npclist", "NPC name", function() return UnitName("target") end, "Takes your target's name.")
    Chk(p, "NPC colour wins over threat", nil, S, "npcoverthreat")
  end
  local function SpellCards(p)
    W.Card(p, "Spell colours and names", { tip = "A spell's own cast bar colour or a new name for it." })
    ListEditor(p, "castlist", "Spell name", function()
      return UnitCastingInfo and UnitCastingInfo("target") or (UnitChannelInfo and UnitChannelInfo("target"))
    end, "Takes the spell your target is casting right now.")
  end

  BUILD.npquest = function(p)
    W.Heading(p, "Quests, icons and auto", { about = "Marks for quest units (from pfQuest when it is on, else your quest "
      .. "log), class icons on players and paws on pets, and nameplates that switch on and off by themselves." })
    Preview(p)
    W.Card(p, "Quests")
    W.Live(p, function()
      return (pfMap and pfMap.tooltips) and "pfQuest |cff55ff55found|r: kill and loot objectives, quests to take (!) and hand in (?)"
        or "pfQuest |cffff5555not on|r: only mobs to kill from your quest log"
    end)
    Chk(p, "Quest marks", "A mark right of the name for quest mobs, quest givers and hand-ins.", S, "questmark")
    Chk(p, "Colour quest mobs", "Quest mobs' bars in the objective colour (threat and NPC colours win).", S, "questbar")
    MarkDrop(p, "Quest mob mark", "questobjstyle", "questcolor")
    Color(p, "Quest mob colour", nil, S, "questcolor")
    MarkDrop(p, "Quest to take", "queststartstyle", "questgivercolor")
    MarkDrop(p, "Quest to hand in", "questendstyle", "questgivercolor")
    Color(p, "Quest giver colour", nil, S, "questgivercolor")
    Sld(p, "Size", "0 = a bit bigger than the name.", 0, 40, 1, S, "questsize", Auto)
    Sld(p, "Left / right", "Or drag the mark in the preview.", -80, 80, 1, S, "questoffx", Px)
    Sld(p, "Up / down", nil, -40, 40, 1, S, "questoffy", Px)
    W.Card(p, "Elite, rare and boss marks", { on = { function() return C.plates.eliteicon == "1" end,
      function(v) C.plates.eliteicon = v and "1" or "0"; U() end, "A mark left of the name for elite, rare and boss units." } })
    MarkDrop(p, "Elite", "markelite", "elitecolor")
    Color(p, "Elite colour", nil, S, "elitecolor")
    MarkDrop(p, "Rare", "markrare", "rarecolor")
    MarkDrop(p, "Rare elite", "markrareelite", "rarecolor")
    Color(p, "Rare colour", nil, S, "rarecolor")
    MarkDrop(p, "Boss", "markboss", "bosscolor")
    Color(p, "Boss colour", nil, S, "bosscolor")
    Sld(p, "Size", "0 = as big as the name.", 0, 40, 1, S, "marksize", Auto)
    Sld(p, "Left / right", "Or drag the mark in the preview.", -80, 80, 1, S, "markoffx", Px)
    Sld(p, "Up / down", nil, -40, 40, 1, S, "markoffy", Px)
    W.Card(p, "Class and pet icons")
    Chk(p, "Class icon on enemy players", nil, S, "classicon_enemy")
    Chk(p, "Class icon on friendly players", nil, S, "classicon_friend")
    Chk(p, "Paw on pets", nil, S, "peticon")
    Sld(p, "Size", "0 = as big as the name.", 0, 40, 1, S, "ciconsize", Auto)
    Sld(p, "Left / right", "Or drag the icon in the preview.", -80, 80, 1, S, "ciconoffx", Px)
    Sld(p, "Up / down", nil, -40, 40, 1, S, "ciconoffy", Px)
    W.Card(p, "Auto", { tip = "Nameplates switch themselves on or off. Leave = as you set them with V / Shift-V." })
    local ACT = { { key = "keep", label = "Leave" }, { key = "show", label = "On" }, { key = "hide", label = "Off" } }
    local function A(label, k, list)
      W.Dropdown(p, label, nil, list or ACT, function() return C.plates[k] end, function(v)
        C.plates[k] = v
        if P.Lists then P.Lists.Auto(UnitAffectingCombat("player")) end
      end)
    end
    A("Enemies in combat", "autoenemy_combat", { { key = "keep", label = "Leave" }, { key = "show", label = "On" } })
    A("Enemies out of combat", "autoenemy_ooc")
    A("Friends in cities", "autofriend_city")
    A("Friends in dungeons and raids", "autofriend_instance")
    A("Friends in the open world", "autofriend_world")
  end

  -- ---------------------------------------------------------------- range and execute

  local function RangeCards(p)
    W.Card(p, "Range", { on = { function() return C.plates.range == "1" end, function(v) C.plates.range = v and "1" or "0"; U() end,
      "Fade plates of far units." } })
    Sld(p, "Further than", nil, 5, 100, 1, S, "rangeyards", Yd)
    Sld(p, "Fade to", nil, 0.05, 1, 0.05, S, "rangealpha", Alpha)
    Chk(p, "Out of sight too", "Also fade units behind walls.", S, "los")
    W.Card(p, "Execute")
    W.Dropdown(p, "Execute range", "Automatic: on for warriors (Execute) and paladins (Hammer of Wrath).",
      { { key = "auto", label = "Automatic" }, { key = "on", label = "Always" }, { key = "off", label = "Off" } },
      function() return C.plates.execute end, function(v) C.plates.execute = v; U() end)
    Sld(p, "Under", nil, 5, 50, 1, S, "executepct", Pct)
    Color(p, "Colour", "The bar's colour once the mob is in execute range.", S, "executecolor")
    Chk(p, "Marker", "A line on the bar where execute range starts.", S, "executemark")
  end

  -- seven pages, most used first (user, 22 Oct 2026: "group up some things
  -- into the same menus and reorder them in order of importance")
  local threat, target, cast = BUILD.npthreat, BUILD.nptarget, BUILD.npcast
  BUILD.npthreat = function(p) threat(p) NpcCards(p) end
  BUILD.nptarget = function(p) target(p) RangeCards(p) end
  BUILD.npcast = function(p) cast(p) SpellCards(p) end

  -- A click on a part of a preview opens its page at its card (opened and
  -- scrolled to, with a short glow).
  local GO = {
    name = { "nplook", "Name" }, guild = { "nplook", "Name" }, hptext = { "nplook", "Health text" },
    level = { "nplook", "Level" }, health = { "nplook", "Health bar" }, raid = { "nplook", "Raid mark" },
    combo = { "nplook", "Combo points" }, threat = { "npthreat", "Damage and healer colours" },
    target = { "nptarget", "Target" }, cast = { "npcast", "Bar" }, auras = { "npauras", "Icons" },
    special = { "npauras", "Special auras" }, elite = { "npquest", "Elite, rare and boss marks" }, quest = { "npquest", "Quests" },
    icons = { "npquest", "Class and pet icons" },
  }
  P.GO = GO
  function P.OpenSection(key, title)
    -- (the window opens first: callers outside it - the gear menu's Options,
    -- a right-click on a set - found nothing happened, 24 Oct 2026)
    if not (O.frame and O.frame:IsShown()) then O:Open(key) else O:Select("o:" .. key) end
    local p = O.pages[key]
    if not p then return end
    -- (a page with card tabs: the card's tab first)
    local tab = p.tabs and p.tabs.of[title]
    if tab and tab ~= p.tabs.cur and O.TabSet then O.TabSet(p, tab, true) end
    for _, c in ipairs(p.cards) do
      if c.title == title then
        if not W.IsOpen(c) then W.SetOpen(c, true) end
        p.after = function()
          local top, at = p.body:GetTop(), c.card:GetTop()
          if top and at then
            local off = math.max(0, top - at - 10)
            local sb = getglobal(p.frame:GetName() .. "ScrollBar")
            if sb then sb:SetValue(off) else p.frame:SetVerticalScroll(off) end
          end
          W.Flash(c.card)
        end
        W.Measure(p)
        return c
      end
    end
  end
  P.OnPreviewClick = function(what)
    local t = GO[what]
    if t then P.OpenSection(t[1], t[2]) end
  end

  O.replaced[T["Nameplates"]] = true
  -- phase 4: animations and rules (plates-fx.lua)
  BUILD.npfx = function(p)
    local Fx = P.Fx
    W.Heading(p, "Animations and rules", { about = "Plates that move when something happens, and your own rules: when a "
      .. "plate matches, its bar changes colour, glows, grows, shrinks or hides (Plater's scripts, without code)." })
    -- (the sample plates follow your rules too)
    Preview(p)
    local function L(src)
      local out = {}
      for _, e in ipairs(src or {}) do table.insert(out, { key = e[1], label = e[2] }) end
      return out
    end
    W.Card(p, "Animations", { tip = "Movement when you crit a unit, or when a plate becomes your target." })
    Drop(p, "When you crit it", nil, L(Fx and Fx.ANIMS), S, "animcrit")
    Drop(p, "When it becomes your target", nil, L(Fx and Fx.ANIMS), S, "animtarget")
    Sld(p, "How much it grows", "For Pop and Bounce.", 5, 60, 1, S, "animsize", Pct)
    W.Buttons(p, { { "Play on the preview", function()
      P.playAt = GetTime()
      for _, game in ipairs(P.previews or {}) do
        local o = game.nameplate and game.nameplate.octo
        if o and Fx then Fx.Play(o, S().animcrit ~= "none" and S().animcrit or "pop") end
      end
    end, nil, nil, on = function() return P.playAt and GetTime() - P.playAt < 1.5 end } })
    for i = 1, (Fx and Fx.RULES or 6) do
      local n = i
      local function R() return C.plates["rule" .. n] end
      W.Card(p, "Rule " .. n, { tip = "When a plate matches, this happens to it. Rules further down win over earlier ones.",
        on = { function() return R().on == "1" end, function(v) R().on = v and "1" or "0" U() end, "This rule on or off." } })
      Drop(p, "When", nil, L(Fx and Fx.WHEN), R, "when")
      Edit(p, "Name, spell, debuff or %", "A word of the name, a spell's or debuff's name, or a health %.", R, "value")
      Drop(p, "Then", nil, L(Fx and Fx.THEN), R, "effect")
      Color(p, "Colour", "For the bar colour and the glow.", R, "color")
      Sld(p, "Size", "For bigger / smaller.", 105, 200, 5, R, "size", Pct)
    end
  end

  O:AddPage("Nameplates", "npgeneral", "General", BUILD.npgeneral)
  O:AddPage("Nameplates", "nplook", "Look and size", BUILD.nplook)
  O:AddPage("Nameplates", "npthreat", "Threat and colours", BUILD.npthreat)
  O:AddPage("Nameplates", "nptarget", "Target, range and execute", BUILD.nptarget)
  O:AddPage("Nameplates", "npcast", "Cast bar", BUILD.npcast)
  O:AddPage("Nameplates", "npauras", "Auras", BUILD.npauras)
  O:AddPage("Nameplates", "npquest", "Quests, icons and auto", BUILD.npquest)
  O:AddPage("Nameplates", "npfx", "Animations and rules", BUILD.npfx)
end)
