pfUI:RegisterModule("swing", "vanilla", function ()
  -- pfUI Octo :: swing timers (24 Oct 2026). User: WeaponSwingTimer "in its
  -- own category ... work the same with the same art / bars / colours".
  -- WeaponSwingTimer is GPL-3 and pfUI MIT (user's choice: built in, written
  -- fresh): its settings, defaults and colours were matched, none of its code
  -- or art used. The looks use the game's own art where it copies Blizzard
  -- (cast bar border, status bar, spark) and pfUI Octo's own (img\bars\swing-*)
  -- for the rest.
  --   your swing   main hand and off hand, blue; Heroic Strike / Cleave /
  --                Maul / Raptor Strike waiting on the next swing colour it
  --   target       your target's swing at you, red
  --   ranged       Auto Shot (hunters) and wand Shoot: the reload, white, then
  --                the half-second aim, red (moving restarts the aim)
  -- Swings: SuperWoW's UNIT_CASTEVENT (MAINHAND / OFFHAND / CAST, exact hand)
  -- when it runs, else the combat log (any line of your own white hits /
  -- misses is a swing; the hand nearest its end takes it). Parries haste the
  -- one who parried (40% of the swing, never under 20% left).
  -- Settings C.swing.<bar>.*, C.swing.look.*; options: Swing Timer.
  local ST = { bars = {}, state = {} }
  pfUI.swing = ST
  local function S(bar) return C.swing[bar] end
  local function L() return C.swing.look end
  local function Col(str, fb)
    local r, g, b, a = GetStringColor(str or fb or "1,1,1,1")
    return tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1
  end

  -- ---------------------------------------------------------------- looks

  ST.BARS = {
    { key = "classic", label = "Classic", tex = "Interface\\TargetingFrame\\UI-StatusBar" },
    { key = "plain", label = "Plain", tex = "Interface\\Buttons\\WHITE8X8" },
    { key = "minimal", label = "Minimalist", tex = "Interface\\AddOns\\pfUI\\img\\bars\\bar-minimal" },
    { key = "cdm", label = "Cooldown Manager", tex = "Interface\\AddOns\\pfUI\\img\\bars\\swing-cdm" },
  }
  ST.BORDERS = {
    { key = "classic", label = "Classic cast bar" }, { key = "classicgold", label = "Classic cast bar (gold)" },
    { key = "cdm", label = "Cooldown Manager" }, { key = "cdmgrey", label = "Cooldown Manager (grey)" },
    { key = "blizzard", label = "Blizzard swing timer" }, { key = "pixel", label = "Black pixel line" },
    { key = "none", label = "None" },
  }
  -- whole looks in one pick (1 Nov 2026: dennis wanted the bars "more akin to
  -- blizzards frames"; the user: "more styles ... in a tidy drop down with
  -- examples"). bar, border, spark, back opacity; the pieces stay below it.
  local IMG = "Interface\\AddOns\\pfUI\\img\\"
  ST.STYLES = {
    { key = "blizzard", label = "Blizzard cast bar", bar = "classic", border = "classic", spark = "1", backalpha = ".6", height = "14", me = "1,.7,0,1", them = ".8,.1,.1,1" },
    { key = "blizzgold", label = "Blizzard gold", bar = "classic", border = "classicgold", spark = "1", backalpha = ".6", height = "14", me = "1,.82,0,1", them = ".85,.25,.1,1" },
    { key = "blizzswing", label = "Blizzard swing timer", bar = "classic", border = "blizzard", spark = "1", backalpha = ".5", height = "12", me = ".1,.1,.9,1", them = ".8,.1,.1,1" },
    { key = "cdm", label = "Cooldown Manager", bar = "cdm", border = "cdm", spark = "1", backalpha = ".5", height = "12", me = ".25,.55,1,1", them = ".9,.2,.2,1" },
    { key = "pfui", label = "pfUI", bar = IMG .. "bar", border = "pixel", spark = "1", backalpha = ".4", height = "16", me = ".2,1,.8,1", them = "1,.3,.3,1" },
    { key = "elvui", label = "ElvUI", bar = IMG .. "bar_elvui", border = "pixel", spark = "0", backalpha = ".35", height = "18", me = ".4,.6,.9,1", them = ".9,.3,.3,1" },
    { key = "tukui", label = "Tukui", bar = IMG .. "bar_tukui", border = "pixel", spark = "0", backalpha = ".35", height = "10", me = ".8,.8,.8,1", them = ".75,.2,.2,1" },
    { key = "smooth", label = "Smooth", bar = IMG .. "bars\\bar-smooth", border = "cdmgrey", spark = "1", backalpha = ".45", height = "14", me = ".3,.6,1,1", them = "1,.4,.4,1" },
    { key = "steel", label = "Steel", bar = IMG .. "bars\\bar-steel", border = "classic", spark = "1", backalpha = ".55", height = "14", me = ".7,.75,.82,1", them = ".7,.3,.3,1" },
    { key = "gradient", label = "Gradient", bar = IMG .. "bar_gradient", border = "pixel", spark = "1", backalpha = ".4", height = "16", me = ".6,.3,1,1", them = "1,.5,.1,1" },
    { key = "striped", label = "Striped", bar = IMG .. "bar_striped", border = "pixel", spark = "0", backalpha = ".4", height = "16", me = "1,.8,.2,1", them = ".9,.2,.2,1" },
    { key = "pill", label = "Pill", bar = IMG .. "bars\\bar-pill", border = "none", spark = "0", backalpha = ".3", height = "8", me = ".2,.9,.5,1", them = "1,.35,.35,1" },
    { key = "minimal", label = "Minimalist", bar = "minimal", border = "none", spark = "0", backalpha = ".25", height = "4", me = "1,1,1,1", them = "1,.3,.3,1" },
    { key = "flat", label = "Flat", bar = "plain", border = "pixel", spark = "0", backalpha = ".3", height = "12", me = ".25,.5,.9,1", them = ".85,.25,.25,1" },
  }
  -- the style the look is now, or nil (changed by hand)
  function ST.CurrentStyle()
    local l = L()
    for _, s in ipairs(ST.STYLES) do
      if l.bar == s.bar and l.border == s.border and l.spark == s.spark and tonumber(l.backalpha) == tonumber(s.backalpha) then
        return s.key
      end
    end
  end
  function ST.ApplyStyle(key)
    for _, s in ipairs(ST.STYLES) do
      if s.key == key then
        local l = L()
        l.bar, l.border, l.spark, l.backalpha = s.bar, s.border, s.spark, s.backalpha
        -- (height and colours too: a texture alone hardly shows on a thin bar)
        for _, b in ipairs({ "player", "target", "ranged", "cast" }) do
          if C.swing[b] and s.height then C.swing[b].height = s.height end
        end
        if C.swing.player and s.me then C.swing.player.maincolor, C.swing.player.offcolor = s.me, s.me end
        if C.swing.target and s.them then C.swing.target.maincolor, C.swing.target.offcolor = s.them, s.them end
        if ST.ApplyLayout then ST.ApplyLayout() end
        return true
      end
    end
  end

  function ST.BarTexture()
    local k = L().bar
    for _, b in ipairs(ST.BARS) do if b.key == k then return b.tex end end
    -- (any of pfUI's bar textures can be picked too)
    return (k and k ~= "") and k or ST.BARS[1].tex
  end
  local SPARK = "Interface\\CastingBar\\UI-CastingBar-Spark"
  local CASTBORDER = "Interface\\CastingBar\\UI-CastingBar-Border"
  local ART = "Interface\\AddOns\\pfUI\\img\\bars\\"

  -- one bar: back, fill, spark, two texts, and its border
  local function Part(parent)
    local p = CreateFrame("Frame", nil, parent)
    p.back = p:CreateTexture(nil, "BACKGROUND")
    p.back:SetAllPoints(p)
    p.fill = p:CreateTexture(nil, "ARTWORK")
    p.fill:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
    p.fill:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 0, 0)
    p.spark = p:CreateTexture(nil, "OVERLAY")
    p.spark:SetTexture(SPARK)
    p.spark:SetBlendMode("ADD")
    -- the texts on their own layer, over the border art and the marks (in game
    -- the border covered them and a white reload bar hid white text)
    p.text = CreateFrame("Frame", nil, p)
    p.text:SetAllPoints(p)
    p.text:SetFrameLevel(p:GetFrameLevel() + 4)
    p.left = p.text:CreateFontString(nil, "OVERLAY")
    p.left:SetPoint("LEFT", p, "LEFT", 3, 0)
    p.right = p.text:CreateFontString(nil, "OVERLAY")
    p.right:SetPoint("RIGHT", p, "RIGHT", -3, 0)
    p.border = CreateFrame("Frame", nil, p)
    p.border:SetFrameLevel(p:GetFrameLevel() + 2)
    p.border.tex = p.border:CreateTexture(nil, "OVERLAY")
    p.border.tex:SetAllPoints(p.border)
    p.border.diaL = p.border:CreateTexture(nil, "OVERLAY")
    p.border.diaR = p.border:CreateTexture(nil, "OVERLAY")
    -- the rounded frame's two ends (drawn at their own shape, not stretched)
    p.border.capL = p.border:CreateTexture(nil, "OVERLAY")
    p.border.capR = p.border:CreateTexture(nil, "OVERLAY")
    -- and the dark inside of those ends, under the bar (on the bar: textures
    -- can sit outside their frame)
    p.backL = p:CreateTexture(nil, "BACKGROUND")
    p.backR = p:CreateTexture(nil, "BACKGROUND")
    p.backM = p:CreateTexture(nil, "BACKGROUND")
    -- marks on the bar: Multi-Shot clip zone, latency, Slam window and its
    -- GCD spark, the paladin's twist and GCD lines
    for _, k in ipairs({ "clip", "lag", "slam", "gcd", "mark1", "mark2" }) do
      p[k] = p:CreateTexture(nil, "OVERLAY")
      p[k]:SetTexture("Interface\\Buttons\\WHITE8X8")
      p[k]:Hide()
    end
    p.gcd:SetTexture(SPARK)
    p.gcd:SetBlendMode("ADD")
    return p
  end

  -- a mark `secs` long ending `before` seconds before the swing's end (or
  -- starting there, for a line: secs = nil), on a part `speed` seconds long
  local function Mark(p, tex, before, secs, speed, fills, r, g, b, a, line, pad)
    if not speed or speed <= 0 then tex:Hide() return end
    local w = p:GetWidth() or 1
    local px = w / speed
    tex:ClearAllPoints()
    tex:SetVertexColor(r, g, b, a or 1)
    local width = line and 2 or math.max(1, (secs or 0) * px)
    tex:SetWidth(width)
    local off = before * px
    local up = pad or 0
    if fills then
      tex:SetPoint("TOPRIGHT", p, "TOPRIGHT", -off, up)
      tex:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -off, -up)
    else
      tex:SetPoint("TOPLEFT", p, "TOPLEFT", off, up)
      tex:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", off, -up)
    end
    tex:Show()
  end
  ST.Mark = Mark

  -- a bar frame (name) with up to two parts (main / off hand, or reload / aim)
  function ST.NewBar(name, parent)
    local f = CreateFrame("Frame", name, parent or UIParent)
    f:SetFrameStrata("MEDIUM")
    f.main = Part(f)
    f.off = Part(f)
    f.off:Hide()
    return f
  end

  -- the look on one part: texture, border style, back, spark, font
  local function Skin(p, w, h, size)
    local l = L()
    p:SetWidth(w)
    p:SetHeight(h)
    local tex = ST.BarTexture()
    p.fill:SetTexture(tex)
    local _, _, _, ba = Col("0,0,0," .. (l.backalpha or ".5"))
    p.back:SetTexture("Interface\\Buttons\\WHITE8X8")
    p.back:SetVertexColor(0, 0, 0, ba)
    local font = pfUI.font_unit or pfUI.font_default
    p.left:SetFont(font, size, "OUTLINE")
    p.right:SetFont(font, size, "OUTLINE")
    for _, fs in ipairs({ p.left, p.right }) do
      fs:SetShadowColor(0, 0, 0, 1)
      fs:SetShadowOffset(1, -1)
    end
    p.text:SetFrameLevel(p:GetFrameLevel() + 4)
    p.spark:SetWidth(math.max(8, h * 1.3))
    p.spark:SetHeight(h * 2.2)
    local b, t = p.border, p.border.tex
    b:ClearAllPoints()
    b.diaL:Hide()
    b.diaR:Hide()
    t:SetVertexColor(1, 1, 1, 1)
    t:SetTexCoord(0, 1, 0, 1)
    t:ClearAllPoints()
    t:SetAllPoints(b)
    b.capL:Hide()
    b.capR:Hide()
    p.backL:Hide()
    p.backR:Hide()
    p.backM:Hide()
    local style = l.border or "cdm"
    if style == "classic" or style == "classicgold" then
      -- the game's cast bar border, round a bar it was drawn for (195 x 13 in 256 x 64)
      b:SetWidth(w * 256 / 195)
      b:SetHeight(h * 64 / 13)
      b:SetPoint("CENTER", p, "CENTER", 0, 0)
      t:SetTexture(CASTBORDER)
      if style == "classicgold" then t:SetVertexColor(1, .82, .25, 1) end
      b:Show()
    elseif style == "cdm" or style == "cdmgrey" or style == "blizzard" then
      -- (24 Oct 2026, seen in game: one rounded box stretched to the bar's
      -- length had long tapered ends. Now three pieces: the ends keep the
      -- art's own shape, only the middle stretches; the back stays straight.)
      -- (seen in game: the bar's square ends, marks and fill showed past the
      -- round ends. The round ends now sit just outside the bar, filled dark,
      -- so the bar ends square inside the straight part of the frame.)
      local bh = h + 8
      local cap = bh / 2
      b:SetPoint("TOPLEFT", p, "TOPLEFT", -cap, 4)
      b:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", cap, -4)
      local BACK = ART .. "swing-back"
      local _, _, _, inside = Col("0,0,0," .. (l.backalpha or ".5"))
      inside = math.min(1, inside + .2)
      for _, x in ipairs({ p.backL, p.backR, p.backM }) do
        x:SetTexture(BACK)
        x:SetVertexColor(0, 0, 0, inside)
        x:ClearAllPoints()
        x:Show()
      end
      p.backL:SetTexCoord(0, 16 / 256, 0, 1)
      p.backL:SetPoint("TOPRIGHT", p, "TOPLEFT", 0, 4)
      p.backL:SetPoint("BOTTOMRIGHT", p, "BOTTOMLEFT", 0, -4)
      p.backL:SetWidth(cap)
      p.backR:SetTexCoord(240 / 256, 1, 0, 1)
      p.backR:SetPoint("TOPLEFT", p, "TOPRIGHT", 0, 4)
      p.backR:SetPoint("BOTTOMLEFT", p, "BOTTOMRIGHT", 0, -4)
      p.backR:SetWidth(cap)
      -- (the strips above and below the bar, inside the frame)
      p.backM:SetTexCoord(16 / 256, 240 / 256, 0, 1)
      p.backM:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 4)
      p.backM:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, -4)
      local r, g, bl = .05, .05, .05
      if style == "cdmgrey" then r, g, bl = .45, .45, .48
      elseif style == "blizzard" then r, g, bl = .85, .7, .35 end
      local ART_FRAME = ART .. "swing-frame"
      b.capL:SetTexture(ART_FRAME)
      b.capL:SetTexCoord(0, 16 / 256, 0, 1)
      b.capL:ClearAllPoints()
      b.capL:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
      b.capL:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
      b.capL:SetWidth(cap)
      b.capR:SetTexture(ART_FRAME)
      b.capR:SetTexCoord(240 / 256, 1, 0, 1)
      b.capR:ClearAllPoints()
      b.capR:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
      b.capR:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
      b.capR:SetWidth(cap)
      t:SetTexture(ART_FRAME)
      t:SetTexCoord(16 / 256, 240 / 256, 0, 1)
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", b.capL, "TOPRIGHT", 0, 0)
      t:SetPoint("BOTTOMRIGHT", b.capR, "BOTTOMLEFT", 0, 0)
      for _, x in ipairs({ t, b.capL, b.capR }) do x:SetVertexColor(r, g, bl, 1) end
      b.capL:Show()
      b.capR:Show()
      p.back:SetVertexColor(0, 0, 0, math.min(1, ba + .2))
      if style == "blizzard" then
        for _, d in ipairs({ b.diaL, b.diaR }) do
          d:SetTexture(ART .. "swing-diamond")
          d:SetVertexColor(1, .82, .3, 1)
          d:SetWidth(h + 6)
          d:SetHeight(h + 6)
          d:Show()
        end
        b.diaL:ClearAllPoints()
        b.diaL:SetPoint("CENTER", p, "LEFT", 0, 0)
        b.diaR:ClearAllPoints()
        b.diaR:SetPoint("CENTER", p, "RIGHT", 0, 0)
      end
      b:Show()
    elseif style == "pixel" then
      b:SetPoint("TOPLEFT", p, "TOPLEFT", -1, 1)
      b:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 1, -1)
      t:SetTexture(nil)
      if b.SetBackdrop then
        b:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        b:SetBackdropBorderColor(0, 0, 0, 1)
      end
      b:Show()
    else
      b:Hide()
    end
    if style ~= "pixel" and b.SetBackdrop then b:SetBackdrop(nil) end
  end
  ST.Skin = Skin

  -- one part drawn at progress (0..1), with its colour and texts
  local function Draw(p, prog, r, g, b, a, lefttext, righttext, fills)
    local w = p:GetWidth() or 1
    prog = math.max(0, math.min(1, prog or 0))
    local shown = fills and prog or (1 - prog)
    p.fill:SetVertexColor(r, g, b, a or 1)
    p.fill:SetWidth(math.max(.01, w * shown))
    p.fill:SetTexCoord(0, math.max(.01, shown), 0, 1)
    if shown <= 0 then p.fill:Hide() else p.fill:Show() end
    if L().spark == "1" and prog > 0 and prog < 1 then
      p.spark:ClearAllPoints()
      p.spark:SetPoint("CENTER", p, "LEFT", w * shown, 0)
      p.spark:Show()
    else
      p.spark:Hide()
    end
    p.left:SetText(lefttext or "")
    p.right:SetText(righttext or "")
  end
  ST.Draw = Draw

  -- lay out a bar frame: one part, or two stacked / combined
  function ST.Layout(f, set, two)
    local w, h = tonumber(set.width) or 300, tonumber(set.height) or 12
    local size = tonumber(set.fontsize) or 10
    local combined = set.combined == "1"
    f:SetWidth(w)
    Skin(f.main, w, (two and combined) and h or h, size)
    f.main:ClearAllPoints()
    f.main:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    if two then
      local oh = combined and math.max(3, math.floor(h / 3)) or h
      Skin(f.off, w, oh, math.max(6, size - (combined and 3 or 0)))
      f.off:ClearAllPoints()
      if combined then
        f.off:SetPoint("BOTTOMLEFT", f.main, "BOTTOMLEFT", 0, 0)
        f.off.border:Hide()
        f.off.backL:Hide()
        f.off.backR:Hide()
        f.off.backM:Hide()
        f.off.back:SetVertexColor(0, 0, 0, 0)
        f:SetHeight(h)
      else
        f.off:SetPoint("TOPLEFT", f.main, "BOTTOMLEFT", 0, -(L().border ~= "none" and 8 or 2))
        f:SetHeight(h * 2 + 8)
      end
      f.off:SetFrameLevel(f.main:GetFrameLevel() + (combined and 3 or 0))
      f.off:Show()
    else
      f.off:Hide()
      f:SetHeight(h)
    end
  end

  -- ---------------------------------------------------------------- state

  local now = GetTime
  local s = ST.state
  s.mhStart, s.ohStart, s.tgStart, s.rgStart = 0, 0, 0, 0
  s.mhSpeed, s.ohSpeed, s.tgSpeed, s.rgSpeed = 2, 2, 2, 2
  s.lastSwing = 0
  -- a wand (every class but hunters, who cannot use one): no aim, one bar
  local _, myClass = UnitClass("player")
  s.wand = myClass ~= "HUNTER"

  local function Speeds()
    local mh, oh = UnitAttackSpeed("player")
    if mh and mh > 0 then
      -- (a change of speed mid-swing keeps the part already done)
      if s.mhSpeed and s.mhSpeed > 0 and math.abs(mh - s.mhSpeed) > .01 then
        local t = now()
        local done = (t - s.mhStart) / s.mhSpeed
        if done < 1 then s.mhStart = t - done * mh end
      end
      s.mhSpeed = mh
    end
    if oh and oh > 0 then
      if s.ohSpeed and s.ohSpeed > 0 and math.abs(oh - s.ohSpeed) > .01 then
        local t = now()
        local done = (t - s.ohStart) / s.ohSpeed
        if done < 1 then s.ohStart = t - done * oh end
      end
      s.ohSpeed = oh
    end
    s.dual = (oh and oh > 0) and true or false
    if UnitRangedDamage then
      local speed = UnitRangedDamage("player")
      if speed and speed > 0 then s.rgSpeed = speed s.ranged = true else s.ranged = false end
    end
    if UnitExists("target") then
      local tmh = UnitAttackSpeed("target")
      if tmh and tmh > 0 then s.tgSpeed = tmh end
    end
  end
  ST.Speeds = Speeds

  function ST.Swing(hand)
    local t = now()
    if hand == "off" then s.ohStart = t else s.mhStart = t end
    s.lastSwing = t
  end
  function ST.TargetSwing() s.tgStart = now() s.tgSeen = now() end
  -- (wand: the Multi-Shot clip zone is for Auto Shot only)
  function ST.Shot(wand)
    s.rgStart = now()
    s.rgSeen = now()
    local was = s.wand
    s.wand = (wand or myClass ~= "HUNTER") and true or false
    if was ~= s.wand and ST.ApplyLayout then ST.ApplyLayout() end
  end

  -- the swing that just happened, from the combat log: the hand nearest its end
  function ST.SwingFromLog()
    if not s.dual then ST.Swing("main") return end
    local t = now()
    local mh = (t - s.mhStart) / s.mhSpeed
    local oh = (t - s.ohStart) / s.ohSpeed
    ST.Swing(oh > mh and "off" or "main")
  end

  -- a parry hastes the one who parried: 40% of the swing off, not under 20% left
  local function Haste(startKey, speedKey)
    local t = now()
    local speed = s[speedKey]
    local left = speed - (t - s[startKey])
    if left <= 0 then return end
    local newLeft = math.max(speed * .2, left - speed * .4)
    s[startKey] = s[startKey] - (left - newLeft)
  end
  ST.Haste = Haste

  -- ---------------------------------------------------------------- queued attacks

  -- next-swing attacks, by their icon on your action bars
  ST.QUEUE = {
    ["Interface\\Icons\\Ability_Rogue_Ambush"] = "queue",       -- Heroic Strike
    ["Interface\\Icons\\Ability_Warrior_Cleave"] = "cleave",    -- Cleave
    ["Interface\\Icons\\Ability_Druid_Maul"] = "maul",          -- Maul
    ["Interface\\Icons\\Ability_MeleeDamage"] = "queue",        -- Raptor Strike
  }
  ST.QUEUE_SPELLS = { [78] = 1, [284] = 1, [285] = 1, [1608] = 1, [11564] = 1, [11565] = 1, [11566] = 1, [11567] = 1,
    [25286] = 1, [845] = 1, [7369] = 1, [11608] = 1, [11609] = 1, [20569] = 1, [6807] = 1, [6808] = 1, [6809] = 1,
    [8972] = 1, [9745] = 1, [9880] = 1, [9881] = 1, [2973] = 1, [14260] = 1, [14261] = 1, [14262] = 1, [14263] = 1,
    [14264] = 1, [14265] = 1, [14266] = 1 }
  local slots = {}
  function ST.ScanSlots()
    slots = {}
    for i = 1, 120 do
      local tex = GetActionTexture(i)
      if tex and ST.QUEUE[tex] then table.insert(slots, { i, ST.QUEUE[tex] }) end
    end
  end
  function ST.Queued()
    for _, sl in ipairs(slots) do
      if IsCurrentAction(sl[1]) then return sl[2] end
    end
  end

  -- ---------------------------------------------------------------- the real bars

  local function Mover(f, bar)
    local set = S(bar)
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", tonumber(set.x) or 0, tonumber(set.y) or 0)
    if UpdateMovable then UpdateMovable(f) end
  end

  ST.bars.player = ST.NewBar("pfSwingPlayer")
  ST.bars.target = ST.NewBar("pfSwingTarget")
  ST.bars.ranged = ST.NewBar("pfSwingRanged")
  ST.bars.cast = ST.NewBar("pfSwingCast")
  Mover(ST.bars.player, "player")
  Mover(ST.bars.target, "target")
  Mover(ST.bars.ranged, "ranged")
  Mover(ST.bars.cast, "cast")

  function ST.ApplyLayout()
    Speeds()
    ST.Layout(ST.bars.player, S("player"), s.dual and S("player").offhand == "1")
    ST.Layout(ST.bars.target, S("target"), false)
    ST.Layout(ST.bars.ranged, S("ranged"), S("ranged").onebar ~= "1" and not s.wand)
    ST.Layout(ST.bars.cast, S("cast"), false)
  end
  ST.UpdateConfig = ST.ApplyLayout

  local function Hex(r, g, b) return string.format("|cff%02x%02x%02x", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255)) end
  local function Left(t) return string.format("%.1f", math.max(0, t)) end

  -- how see-through a bar is: in / out of combat, fading when idle
  local function Alpha(set, idle)
    local a = UnitAffectingCombat("player") and (tonumber(set.alpha) or 1) or (tonumber(set.oocalpha) or .25)
    if set.fadeidle == "1" and idle then a = math.min(a, tonumber(set.oocalpha) or .25) end
    return a
  end

  -- each frame: the three bars from the state (t = the time to draw, so the
  -- preview can run the same code on a made-up clock)
  function ST.Paint(f, bar, t, st)
    st = st or s
    local set = S(bar)
    local fills = set.fill ~= "0"
    if bar == "player" then
      local queued = st.queued
      local mhp = (t - st.mhStart) / st.mhSpeed
      local r, g, b, a = Col(set.maincolor)
      if queued == "cleave" then r, g, b, a = Col(C.swing.warrior.cleavecolor)
      elseif queued == "maul" then r, g, b, a = Col(C.swing.warrior.maulcolor)
      elseif queued then r, g, b, a = Col(C.swing.warrior.queuecolor) end
      -- (ClassicAPI: your target out of melee reach - the bar dims)
      if st.outMelee and not st.preview then r, g, b = r * .4, g * .4, b * .4 end
      local tr, tg, tb = Col(set.textcolor)
      Draw(f.main, mhp, r, g, b, a, set.lefttext == "1" and (Hex(tr, tg, tb) .. "Main hand|r") or "",
        set.righttext == "1" and (Hex(tr, tg, tb) .. Left(st.mhSpeed - (t - st.mhStart)) .. "|r") or "", fills)
      -- warrior: the Slam window at the swing's end and the GCD spark before it
      local wa = C.swing.warrior
      if ST.SlamShown(st) then
        if (tonumber(wa.slamdelay) or 0) > 0 then
          local sr, sg, sb, sa = Col(wa.slamcolor)
          Mark(f.main, f.main.slam, 0, tonumber(wa.slamdelay), st.mhSpeed, fills, sr, sg, sb, sa)
        else
          f.main.slam:Hide()
        end
        if wa.slamgcd == "1" then
          local gr, gg, gb, ga = Col(wa.gcdcolor)
          Mark(f.main, f.main.gcd, 1.5, nil, st.mhSpeed, fills, gr, gg, gb, ga, true, 4)
          f.main.gcd:SetWidth(10)
        else
          f.main.gcd:Hide()
        end
      else
        f.main.slam:Hide()
        f.main.gcd:Hide()
      end
      -- paladin: the seal twist line 0.4 s before the swing, the GCD line 1.5 s before
      local pa = C.swing.paladin
      local pad = tonumber(pa.offset) or 6
      if ST.PaladinShown(st, "twist") then local r1, g1, b1, a1 = Col(pa.twistcolor) Mark(f.main, f.main.mark1, .4, nil, st.mhSpeed, fills, r1, g1, b1, a1, true, pad)
      else f.main.mark1:Hide() end
      if ST.PaladinShown(st, "gcd") then local r2, g2, b2, a2 = Col(pa.gcdcolor) Mark(f.main, f.main.mark2, 1.5, nil, st.mhSpeed, fills, r2, g2, b2, a2, true, pad)
      else f.main.mark2:Hide() end
      if f.off:IsShown() then
        local ohp = (t - st.ohStart) / st.ohSpeed
        local or2, og, ob, oa = Col(set.offcolor)
        Draw(f.off, ohp, or2, og, ob, oa, (set.lefttext == "1" and set.combined ~= "1") and (Hex(tr, tg, tb) .. "Off hand|r") or "",
          (set.righttext == "1" and set.combined ~= "1") and (Hex(tr, tg, tb) .. Left(st.ohSpeed - (t - st.ohStart)) .. "|r") or "", fills)
      end
      return t - (st.lastSwing or 0) > (st.mhSpeed + 1)
    elseif bar == "target" then
      local p = (t - st.tgStart) / st.tgSpeed
      local r, g, b, a = Col(set.maincolor)
      local tr, tg, tb = Col(set.textcolor)
      Draw(f.main, p, r, g, b, a, set.lefttext == "1" and (Hex(tr, tg, tb) .. (st.tgName or "Target") .. "|r") or "",
        set.righttext == "1" and (Hex(tr, tg, tb) .. Left(st.tgSpeed - (t - st.tgStart)) .. "|r") or "", fills)
      return t - (st.tgStart or 0) > (st.tgSpeed + 1)
    elseif bar == "ranged" then
      -- ranged: the reload (speed - 0.5) then the aim (0.5)
      local speed = st.rgSpeed
      local elapsed = t - st.rgStart
      local reload = math.max(.01, speed - .5)
      local cr, cg, cb, ca = Col(set.cooldowncolor)
      local ar, ag, ab, aa = Col(set.castcolor)
      if st.outRanged and not st.preview then cr, cg, cb, ar, ag, ab = cr * .4, cg * .4, cb * .4, ar * .4, ag * .4, ab * .4 end
      local text = set.text == "1"
      if st.wand then
        -- a wand: one bar over the whole shot time; full = the next shot is ready
        Draw(f.main, elapsed / speed, cr, cg, cb, ca, text and "Wand" or "", text and Left(speed - elapsed) or "", true)
        f.main.clip:Hide()
        return elapsed > speed + 1
      elseif set.onebar == "1" then
        local p = elapsed / speed
        local inAim = elapsed >= reload
        Draw(f.main, p, inAim and ar or cr, inAim and ag or cg, inAim and ab or cb, inAim and aa or ca,
          text and (inAim and "Aim" or "Auto Shot") or "", text and Left(speed - elapsed) or "", true)
      else
        Draw(f.main, elapsed / reload, cr, cg, cb, ca, text and "Reload" or "", text and Left(reload - elapsed) or "", true)
        local aim = st.aimStart and (t - st.aimStart) / .5 or (elapsed >= reload and (elapsed - reload) / .5 or 0)
        Draw(f.off, aim, ar, ag, ab, aa, text and "Aim" or "", "", true)
      end
      -- Multi-Shot clip zone: starting one in the last half second before
      -- the aim delays the next Auto Shot
      local cs = C.swing.cast
      -- (hunters' Auto Shot only: a wand has no Multi-Shot; the preview shows it always)
      local _, cls = UnitClass("player")
      if cs.clip == "1" and (st.preview or (cls == "HUNTER" and not st.wand)) then
        local kr, kg, kb, ka = Col(cs.clipcolor)
        if set.onebar == "1" then Mark(f.main, f.main.clip, .5, .5, speed, true, kr, kg, kb, ka)
        else Mark(f.main, f.main.clip, 0, .5, reload, true, kr, kg, kb, ka) end
      else
        f.main.clip:Hide()
      end
      return elapsed > speed + 1
    elseif bar == "cast" then
      -- Aimed / Multi-Shot: the cast filling, with your latency at its end
      local c = st.cast
      if not c then return true end
      local p = (t - c.start) / c.dur
      local r, g, b, a = Col(set.castcolor)
      local text = set.text == "1"
      Draw(f.main, p, r, g, b, a, text and c.name or "", text and Left(c.dur - (t - c.start)) or "", true)
      if set.latency == "1" then
        local lag = ST.Latency()
        local lr, lg, lb, la = Col(set.latencycolor)
        Mark(f.main, f.main.lag, 0, math.min(c.dur, lag), c.dur, true, lr, lg, lb, la)
      else
        f.main.lag:Hide()
      end
      return false
    end
  end

  -- your latency in seconds (1.12: GetNetStats' third return)
  function ST.Latency()
    if not GetNetStats then return 0 end
    local _, _, home, world = GetNetStats()
    return ((tonumber(world) or tonumber(home) or 0)) / 1000
  end

  -- the Slam marks: warriors who know Slam, with a two-hander (or always)
  local _, playerClass = UnitClass("player")
  function ST.SlamShown(st)
    local wa = C.swing.warrior
    if wa.slam ~= "1" then return false end
    if st and st.preview then return true end
    if playerClass ~= "WARRIOR" or not s.knowsSlam then return false end
    return (not s.dual) or wa.slamonehand == "1"
  end
  function ST.PaladinShown(st, which)
    local pa = C.swing.paladin
    if (which == "twist" and pa.twist ~= "1") or (which == "gcd" and pa.gcd ~= "1") then return false end
    return (st and st.preview) or playerClass == "PALADIN"
  end
  -- does the spellbook have Slam?
  function ST.ScanSpells()
    s.knowsSlam = false
    for i = 1, 300 do
      local name = GetSpellName(i, BOOKTYPE_SPELL or "spell")
      if not name then break end
      if name == "Slam" then s.knowsSlam = true end
    end
  end

  -- the shots the cast bar shows
  ST.CASTS = { ["Aimed Shot"] = "aimed", ["Multi-Shot"] = "multi" }
  function ST.CastWanted(kind)
    return kind == "test" or (kind and C.swing.cast[kind] == "1")
  end

  local ticker = CreateFrame("Frame")
  ST.ticker = ticker
  ticker:SetScript("OnUpdate", function()
    local t = now()
    -- (slot and map checks 10 times a second, not every frame - user, 31 Oct
    -- 2026: "make the game run smoother"; the bars still draw every frame)
    if (this.slow or 0) <= t then
      this.slow = t + .1
      s.queued = ST.Queued()
      -- moving restarts a hunter's aim
      local x, y
      if s.ranged then x, y = GetPlayerMapPosition("player") end
      if x and (x ~= s.px or y ~= s.py) then
        s.moving = s.px ~= nil
        s.px, s.py = x, y
      else
        s.moving = false
      end
    end
    local reload = s.rgSpeed - .5
    if not s.wand and s.moving and t - s.rgStart >= reload and t - s.rgStart < s.rgSpeed then s.rgStart = t - reload end
    -- layout mode: every bar shows (a made-up fight) so each can be placed
    local unlocked = pfUI.unlock and pfUI.unlock:IsShown()
    if unlocked and not (ST.testUntil and t < ST.testUntil) then
      ST.Test(3600)
      ST.testUnlock = true
    elseif not unlocked and ST.testUnlock then
      ST.testUnlock = nil
      ST.testUntil = 0
    end
    local testing = ST.testUntil and t < ST.testUntil
    -- a test over: the real weapons again (a test gives a two-hander an off hand)
    if s.wasTesting and not testing then
      Speeds()
      ST.ApplyLayout()
      s.tgSeen, s.rgSeen, s.cast = 0, 0, nil
    end
    s.wasTesting = testing
    local function Run(bar, show)
      local f = ST.bars[bar]
      if not (show or testing) or S(bar).enabled ~= "1" then f:Hide() return end
      f:Show()
      local idle = ST.Paint(f, bar, t)
      -- (a test shows at the in-combat opacity: out of combat some bars are see-through)
      f:SetAlpha(testing and math.max(.5, tonumber(S(bar).alpha) or 1) or Alpha(S(bar), idle))
    end
    Run("player", not (pfUI.blizz and pfUI.blizz.IsBlizz and pfUI.blizz.IsBlizz("swing")))
    Run("target", UnitExists("target") and UnitCanAttack("player", "target") and (s.tgSeen or 0) > 0
      and t - (s.tgSeen or 0) < 10)
    Run("ranged", s.ranged and (s.rgSeen or 0) > 0 and t - (s.rgSeen or 0) < 10)
    -- the shot being cast (dropped a moment after it should have ended)
    if s.cast and t > s.cast.start + s.cast.dur + .3 then s.cast = nil end
    Run("cast", s.cast and ST.CastWanted(s.cast.kind))
  end)

  -- ---------------------------------------------------------------- events

  local function Pattern(str)
    if not str then return end
    str = string.gsub(str, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    str = string.gsub(str, "%%%%s", "(.+)")
    return "^" .. string.gsub(str, "%%%%d", "%%d+") .. "$"
  end
  local PARRY_ME = Pattern(VSPARRYOTHERSELF)   -- "X attacks. You parry."
  local PARRY_THEM = Pattern(VSPARRYSELFOTHER)  -- "You attack. X parries."

  local _, playerGUID = UnitExists("player")
  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "UNIT_ATTACK_SPEED", "UNIT_INVENTORY_CHANGED", "PLAYER_TARGET_CHANGED",
                       "ACTIONBAR_SLOT_CHANGED", "UNIT_CASTEVENT", "CHAT_MSG_COMBAT_SELF_HITS", "CHAT_MSG_COMBAT_SELF_MISSES",
                       "CHAT_MSG_SPELL_SELF_DAMAGE", "CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS", "CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES",
                       "CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS", "CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES", "START_AUTOREPEAT_SPELL",
                       "STOP_AUTOREPEAT_SPELL", "SPELLCAST_START", "SPELLCAST_STOP", "SPELLCAST_FAILED",
                       "SPELLCAST_INTERRUPTED", "SPELLCAST_DELAYED", "LEARNED_SPELL_IN_TAB" }) do
    pcall(ev.RegisterEvent, ev, e)
  end
  -- ClassicAPI (25 Oct 2026, NOT seen in game): PLAYER_SWING = each reset of
  -- one of your attack timers (arg1 = seconds to the next, arg2 = 0 main hand /
  -- 1 off hand / 2 ranged) - exact, so SuperWoW and the log stand aside for your
  -- own swings; PLAYER_SWING_RANGE_UPDATE = your target in or out of reach
  -- (arg1 = kind, arg2 = in reach, arg3 = it could tell): the bar dims
  local LC = pfUI.api.libclient
  ST.classic = LC and LC.SwingEvents and LC.SwingEvents() or nil
  if ST.classic then
    pcall(ev.RegisterEvent, ev, "PLAYER_SWING")
    pcall(ev.RegisterEvent, ev, "PLAYER_SWING_RANGE_UPDATE")
  end
  function ST.Reach()
    if not ST.classic then return end
    for _, kind in ipairs({ 0, 2 }) do
      pcall(C_SwingTimer.EnableRangeCheck, kind, true)
      -- (nil = it cannot tell: no target, no weapon - not "out of reach")
      local ok, inr = pcall(C_SwingTimer.IsTargetWithinSwingRange, kind)
      local out = (ok and inr == false) and true or false
      if kind == 0 then s.outMelee = out else s.outRanged = out end
    end
  end
  function ST.OnEvent(evt, a1, a2, a3, a4)
    if evt == "PLAYER_SWING" then
      local left, kind = tonumber(a1) or 0, tonumber(a2) or 0
      Speeds()
      local t = now()
      if kind == 2 then
        ST.Shot(myClass ~= "HUNTER")
        if s.rgSpeed and s.rgSpeed > 0 then s.rgStart = t + left - s.rgSpeed end
        s.rsw, s.cwr = true, true
      else
        local hand = kind == 1 and "off" or "main"
        ST.Swing(hand)
        -- (a parried hit can make it shorter than the weapon's speed)
        local speed = hand == "off" and s.ohSpeed or s.mhSpeed
        if speed and speed > 0 and left > 0 then
          if hand == "off" then s.ohStart = t + left - speed else s.mhStart = t + left - speed end
        end
        s.sw, s.cw = true, true
      end
      return
    end
    if evt == "PLAYER_SWING_RANGE_UPDATE" then
      local out = (a3 and not a2) and true or false
      if tonumber(a1) == 2 then s.outRanged = out elseif tonumber(a1) == 0 then s.outMelee = out end
      return
    end
    if evt == "PLAYER_ENTERING_WORLD" then
      _, playerGUID = UnitExists("player")
      ST.Reach()
      ST.ScanSlots()
      ST.ScanSpells()
      ST.ApplyLayout()
      return
    end
    if evt == "UNIT_ATTACK_SPEED" or evt == "UNIT_INVENTORY_CHANGED" then
      if a1 == "player" then
        local wasDual = s.dual
        Speeds()
        if wasDual ~= s.dual then ST.ApplyLayout() end
      end
      return
    end
    if evt == "PLAYER_TARGET_CHANGED" then
      Speeds()
      ST.Reach()
      s.tgName = UnitName("target")
      s.tgSeen = 0
      local _, g = UnitExists("target")
      s.tgGUID = g
      return
    end
    if evt == "ACTIONBAR_SLOT_CHANGED" then ST.ScanSlots() return end
    if evt == "LEARNED_SPELL_IN_TAB" then ST.ScanSpells() return end
    -- your own casts: Aimed Shot and Multi-Shot for the cast bar
    if evt == "SPELLCAST_START" then
      local kind = ST.CASTS[a1 or ""]
      if kind then s.cast = { name = a1, kind = kind, start = now(), dur = math.max(.1, (tonumber(a2) or 0) / 1000) } end
      return
    end
    if evt == "SPELLCAST_DELAYED" then
      if s.cast then s.cast.dur = s.cast.dur + (tonumber(a1) or 0) / 1000 end
      return
    end
    if evt == "SPELLCAST_STOP" or evt == "SPELLCAST_FAILED" or evt == "SPELLCAST_INTERRUPTED" then
      s.cast = nil
      return
    end
    if evt == "START_AUTOREPEAT_SPELL" then Speeds() s.rgSeen = now() return end
    -- SuperWoW: the exact hand, your target's swings, shots and next-swing attacks
    if evt == "UNIT_CASTEVENT" then
      local caster, kind, id = a1, a3, a4
      if caster == playerGUID then
        -- (ClassicAPI's PLAYER_SWING tells your own swings exactly: leave them to it)
        if s.cw and (kind == "MAINHAND" or kind == "OFFHAND" or (kind == "CAST" and ST.QUEUE_SPELLS[id])) then
        elseif s.cwr and kind == "CAST" and (id == 75 or id == 5019) then
        elseif kind == "MAINHAND" then ST.Swing("main") s.sw = true
        elseif kind == "OFFHAND" then ST.Swing("off") s.sw = true
        elseif kind == "CAST" and (id == 75 or id == 5019) then Speeds() ST.Shot(id == 5019) s.rsw = true
        elseif kind == "CAST" and ST.QUEUE_SPELLS[id] then ST.Swing("main") s.sw = true end
      elseif s.tgGUID and caster == s.tgGUID and (kind == "MAINHAND" or kind == "OFFHAND") then
        ST.TargetSwing() s.tsw = true
      end
      return
    end
    -- the combat log (when SuperWoW does not tell)
    local msg = a1 or ""
    if evt == "CHAT_MSG_COMBAT_SELF_HITS" or evt == "CHAT_MSG_COMBAT_SELF_MISSES" then
      if PARRY_THEM and string.find(msg, PARRY_THEM) then
        -- they parried you: their swing comes sooner
        Haste("tgStart", "tgSpeed")
      end
      if not s.sw then ST.SwingFromLog() end
    elseif evt == "CHAT_MSG_SPELL_SELF_DAMAGE" then
      if string.find(msg, "Auto Shot", 1, true) or string.find(msg, "^Your Shoot") then
        -- (not when SuperWoW told already: the log line comes when the shot
        -- lands, later, and restarted the bar part way - seen in game)
        if not s.rsw then Speeds() ST.Shot(string.find(msg, "^Your Shoot") ~= nil) end
      end
      for _, name in ipairs({ "Heroic Strike", "Cleave", "Maul", "Raptor Strike" }) do
        if not s.sw and string.find(msg, "^Your " .. name) then ST.Swing("main") end
      end
    else
      -- something swinging at you: your target's swing (by its name)
      if PARRY_ME and string.find(msg, PARRY_ME) then Haste("mhStart", "mhSpeed") end
      local tname = UnitName("target")
      if tname and not s.tsw and string.sub(msg, 1, string.len(tname) + 1) == tname .. " " then ST.TargetSwing() end
    end
  end
  ev:SetScript("OnEvent", function() ST.OnEvent(event, arg1, arg2, arg3, arg4) end)

  -- a test: every bar runs a made-up fight for a while
  function ST.Test(secs)
    local t = now()
    ST.testUntil = t + (secs or 20)
    Speeds()
    s.mhStart, s.ohStart, s.tgStart, s.rgStart = t, t - .6, t - .3, t
    s.tgSeen, s.rgSeen, s.ranged = t, t, true
    s.tgName = "Test target"
    if not s.dual and S("player").offhand == "1" then s.dual = true s.ohSpeed = s.ohSpeed or 1.5 end
    ST.ApplyLayout()
  end
  local test = CreateFrame("Frame")
  test:SetScript("OnUpdate", function()
    if not ST.testUntil or now() > ST.testUntil then return end
    local t = now()
    if t - s.mhStart >= s.mhSpeed then s.mhStart = t s.lastSwing = t end
    if s.dual and t - s.ohStart >= s.ohSpeed then s.ohStart = t end
    if t - s.tgStart >= s.tgSpeed then s.tgStart = t s.tgSeen = t end
    if t - s.rgStart >= s.rgSpeed then s.rgStart = t s.rgSeen = t end
    -- an Aimed Shot every few seconds
    if not s.cast or s.cast.kind == "test" and t > s.cast.start + s.cast.dur + 1 then
      s.cast = { name = "Aimed Shot", kind = "test", start = t, dur = 3 }
    end
  end)
end)
