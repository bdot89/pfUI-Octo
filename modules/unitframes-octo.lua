pfUI:RegisterModule("unitframes-octo", "vanilla:tbc", function ()
  -- pfUI Octo unit frame extras (user, 22 Oct 2026: "look at this TPerl and
  -- use what it has in our addon, anything we miss must have the options and
  -- artwork"). TPerl is GPL-3 and pfUI is MIT: nothing of TPerl's code or art
  -- is used, only its list of features, rebuilt here on pfUI's own frames:
  --   border skins and a gradient behind the bars
  --   fading bars (the health just lost fades away)
  --   combat flash (red on a hit, green on a heal)
  --   debuff highlight (border / background in the debuff's colour, only
  --     what you can cure) and a highlight on the frame of your target
  --   class icon, class picture as portrait, elite / rare badge
  --   status: AFK, offline, dead / ghost / feigning
  --   player buffs flash in their last 30 seconds; pet happiness only when
  --     unhappy, flashing
  --   target sounds; more bar textures in every texture menu
  -- Settings: C.unitframes[unit].o_* and C.unitframes.o_targetsound.
  -- Options: Unit Frames > Frames (unitframes-options.lua).
  if not pfUI.uf then return end
  local UO = {}
  pfUI.ufExtras = UO

  local WHITE = "Interface\\Buttons\\WHITE8X8"
  local ART = "Interface\\AddOns\\pfUI\\img\\bars\\"
  UO.ART = ART

  local function Col(s, fallback)
    local r, g, b, a = GetStringColor(s or fallback or "1,1,1,1")
    return tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1
  end

  local function Unit(f)
    if not f or not f.label or f.label == "" then return end
    return f.label .. (f.id or "")
  end

  -- a frame over another with four edge lines and a fill
  local function Layer(parent, level, out)
    local l = CreateFrame("Frame", nil, parent)
    out = out or 0
    l:SetPoint("TOPLEFT", parent, "TOPLEFT", -out, out)
    l:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", out, -out)
    l:SetFrameLevel((parent:GetFrameLevel() or 1) + (level or 1))
    l.fill = l:CreateTexture(nil, "OVERLAY")
    l.fill:SetAllPoints(l)
    l.fill:SetTexture(WHITE)
    l.fill:Hide()
    l.edges = {}
    for i = 1, 4 do
      l.edges[i] = l:CreateTexture(nil, "OVERLAY")
      l.edges[i]:SetTexture(WHITE)
    end
    return l
  end
  local function Edges(l, px, r, g, b, a)
    local e = l.edges
    e[1]:ClearAllPoints() e[1]:SetPoint("TOPLEFT", l, "TOPLEFT") e[1]:SetPoint("TOPRIGHT", l, "TOPRIGHT") e[1]:SetHeight(px)
    e[2]:ClearAllPoints() e[2]:SetPoint("BOTTOMLEFT", l, "BOTTOMLEFT") e[2]:SetPoint("BOTTOMRIGHT", l, "BOTTOMRIGHT") e[2]:SetHeight(px)
    e[3]:ClearAllPoints() e[3]:SetPoint("TOPLEFT", l, "TOPLEFT") e[3]:SetPoint("BOTTOMLEFT", l, "BOTTOMLEFT") e[3]:SetWidth(px)
    e[4]:ClearAllPoints() e[4]:SetPoint("TOPRIGHT", l, "TOPRIGHT") e[4]:SetPoint("BOTTOMRIGHT", l, "BOTTOMRIGHT") e[4]:SetWidth(px)
    for i = 1, 4 do e[i]:SetVertexColor(r, g, b, a or 1) e[i]:Show() end
  end
  UO.Layer, UO.Edges = Layer, Edges

  -- ---------------------------------------------------------------- lists

  UO.SKINS = {
    { key = "pfui", label = "pfUI's" },
    { key = "thin", label = "Thin black", edge = WHITE, size = 1, off = 1, color = { 0, 0, 0, 1 } },
    { key = "shadow", label = "Soft shadow", edge = "img:glow2", size = 6, off = 4, color = { 0, 0, 0, .9 } },
    { key = "thick", label = "Thick black", edge = WHITE, size = 2, off = 2, color = { 0, 0, 0, 1 } },
    { key = "gold", label = "Gold line", edge = WHITE, size = 1, off = 1, color = { .85, .68, .3, 1 } },
    { key = "silver", label = "Silver line", edge = WHITE, size = 1, off = 1, color = { .75, .78, .82, 1 } },
    { key = "accent", label = "Accent line", edge = WHITE, size = 1, off = 1, color = { 1, 1, 1, 1 }, accent = true },
    { key = "neon", label = "Neon glow (accent)", edge = "img:glow", size = 6, off = 5, color = { 1, 1, 1, .8 }, accent = true },
    { key = "class", label = "Class colour line", edge = WHITE, size = 1, off = 1, color = { 1, 1, 1, 1 }, class = true },
  }
  local SKINBY = {}
  for _, s in ipairs(UO.SKINS) do SKINBY[s.key] = s end

  UO.GRADIENTS = {
    { key = "none", label = "None" },
    { key = "VERTICAL", label = "Top to bottom" },
    { key = "HORIZONTAL", label = "Left to right" },
  }
  UO.HIGHLIGHTS = {
    { key = "none", label = "Off" },
    { key = "border", label = "Border" },
    { key = "background", label = "Background" },
    { key = "both", label = "Border and background" },
  }
  UO.CLASSICON = {
    { key = "none", label = "Off" },
    { key = "TOPLEFT", label = "Top left" },
    { key = "TOPRIGHT", label = "Top right" },
    { key = "LEFT", label = "Left" },
    { key = "RIGHT", label = "Right" },
  }
  UO.ELITE = {
    { key = "none", label = "Off" },
    { key = "graphic", label = "Crest", tex = "uf-elite" },
    { key = "text", label = "Word (Elite, Rare, Boss)" },
  }
  UO.CORNERS = {
    { key = "TOPRIGHT", label = "Top right" },
    { key = "TOPLEFT", label = "Top left" },
  }
  -- what each class can cure
  UO.CURES = {
    PRIEST = { Magic = true, Disease = true }, PALADIN = { Magic = true, Poison = true, Disease = true },
    DRUID = { Curse = true, Poison = true }, SHAMAN = { Poison = true, Disease = true }, MAGE = { Curse = true },
  }
  local _, myclass = UnitClass("player")

  -- more bar textures for every texture menu (pfUI's list of them)
  UO.BARS = {
    { "img:plates\\bar-flat", "Octo Flat" }, { "img:plates\\bar-soft", "Octo Soft" }, { "img:plates\\bar-gloss", "Octo Gloss" },
    { "img:plates\\bar-glass", "Octo Glass" }, { "img:plates\\bar-split", "Octo Split" },
    { "img:bars\\bar-smooth", "Octo Smooth" }, { "img:bars\\bar-bevel", "Octo Bevel" }, { "img:bars\\bar-steel", "Octo Steel" },
    { "img:bars\\bar-cloud", "Octo Cloud" }, { "img:bars\\bar-diagonal", "Octo Diagonal" }, { "img:bars\\bar-pill", "Octo Pill" },
    { "img:bars\\bar-minimal", "Octo Minimal" },
  }
  local list = pfUI.gui and pfUI.gui.dropdowns and pfUI.gui.dropdowns.uf_bartexture
  if type(list) == "table" then
    local have = {}
    for _, e in ipairs(list) do have[e] = true end
    for _, b in ipairs(UO.BARS) do
      local path = string.gsub(b[1], "^img:", "Interface\\AddOns\\pfUI\\img\\")
      local e = path .. ":" .. b[2]
      if not have[e] then table.insert(list, e) end
    end
  end

  -- ---------------------------------------------------------------- build

  -- after pfUI's UpdateConfig: make and place the extras
  function UO.Configure(f)
    local c = f and f.config
    if not c or not f.hp then return end

    -- border skin round the whole frame
    local sk = SKINBY[c.o_skin or "pfui"]
    f.octoSkin = f.octoSkin or CreateFrame("Frame", nil, f)
    if sk and sk.edge then
      local s = f.octoSkin
      s:ClearAllPoints()
      s:SetPoint("TOPLEFT", f, "TOPLEFT", -sk.off - 1, sk.off + 1)
      s:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", sk.off + 1, -sk.off - 1)
      s:SetBackdrop({ edgeFile = pfUI.media[sk.edge] or sk.edge, edgeSize = sk.size, insets = { left = 0, right = 0, top = 0, bottom = 0 } })
      local r, g, b, a = sk.color[1], sk.color[2], sk.color[3], sk.color[4]
      if sk.accent and GetAccentColor then r, g, b = GetAccentColor() end
      if sk.class then
        local cc = RAID_CLASS_COLORS[myclass or ""]
        if cc then r, g, b = cc.r, cc.g, cc.b end
      end
      s:SetBackdropBorderColor(r, g, b, a)
      s:Show()
    else
      f.octoSkin:Hide()
    end

    -- gradient behind both bars' fill
    for _, bar in ipairs({ f.hp.bar, f.power and f.power.bar }) do
      if bar then
        if c.o_grad and c.o_grad ~= "none" then
          bar.octoGrad = bar.octoGrad or bar:CreateTexture(nil, "BORDER")
          bar.octoGrad:SetAllPoints(bar)
          bar.octoGrad:SetTexture(WHITE)
          local r1, g1, b1, a1 = Col(c.o_gradstart, ".1,.1,.1,.8")
          local r2, g2, b2, a2 = Col(c.o_gradend, ".3,.3,.3,.8")
          bar.octoGrad:SetGradientAlpha(c.o_grad, r1, g1, b1, a1, r2, g2, b2, a2)
          bar.octoGrad:Show()
        elseif bar.octoGrad then
          bar.octoGrad:Hide()
        end
      end
    end

    -- fading bar: the health just lost, behind the fill
    if c.o_fade == "1" then
      f.octoGhost = f.octoGhost or f.hp.bar:CreateTexture(nil, "BORDER")
      f.octoGhost:SetTexture(pfUI.media[c.bartexture] or WHITE)
      local r, g, b, a = Col(c.o_fadecolor, "1,.9,.6,.7")
      f.octoGhost:SetVertexColor(r, g, b, a)
      f.octoGhost:ClearAllPoints()
      if c.verticalbar == "1" then
        f.octoGhost:SetPoint("BOTTOMLEFT", f.hp.bar, "BOTTOMLEFT")
        f.octoGhost:SetPoint("BOTTOMRIGHT", f.hp.bar, "BOTTOMRIGHT")
      else
        f.octoGhost:SetPoint("TOPLEFT", f.hp.bar, "TOPLEFT")
        f.octoGhost:SetPoint("BOTTOMLEFT", f.hp.bar, "BOTTOMLEFT")
      end
      f.octoGhost:Hide()
      f.octoGhostFrac = nil
    elseif f.octoGhost then
      f.octoGhost:Hide()
    end

    -- combat flash, target highlight and debuff highlight: edges round the frame
    f.octoFlash = f.octoFlash or Layer(f, 18, 1)
    f.octoFlash:Hide()
    f.octoSel = f.octoSel or Layer(f, 17, 2)
    f.octoSel:Hide()
    f.octoDebuff = f.octoDebuff or Layer(f, 17, 1)
    f.octoDebuff:Hide()
    f.octoDebuffBg = f.octoDebuffBg or f.hp.bar:CreateTexture(nil, "OVERLAY")
    f.octoDebuffBg:SetAllPoints(f.hp.bar)
    f.octoDebuffBg:SetTexture(WHITE)
    f.octoDebuffBg:Hide()

    -- class icon, elite badge and status marks sit with pfUI's texts
    local top = f.texts or f
    f.octoClass = f.octoClass or top:CreateTexture(nil, "OVERLAY")
    local size = tonumber(c.o_classsize) or 14
    f.octoClass:SetWidth(size)
    f.octoClass:SetHeight(size)
    f.octoClass:ClearAllPoints()
    local pos = c.o_classicon or "none"
    if pos == "TOPLEFT" then f.octoClass:SetPoint("CENTER", f, "TOPLEFT", 2, -2)
    elseif pos == "TOPRIGHT" then f.octoClass:SetPoint("CENTER", f, "TOPRIGHT", -2, -2)
    elseif pos == "LEFT" then f.octoClass:SetPoint("RIGHT", f, "LEFT", -3, 0)
    elseif pos == "RIGHT" then f.octoClass:SetPoint("LEFT", f, "RIGHT", 3, 0) end
    f.octoClass:Hide()

    f.octoElite = f.octoElite or top:CreateTexture(nil, "OVERLAY")
    f.octoElite:SetTexture(ART .. "uf-elite")
    f.octoElite:SetWidth(36)
    f.octoElite:SetHeight(18)
    f.octoElite:ClearAllPoints()
    local corner = c.o_elitepos or "TOPRIGHT"
    f.octoElite:SetPoint("CENTER", f, corner, corner == "TOPLEFT" and 6 or -6, 2)
    f.octoElite:Hide()
    f.octoEliteText = f.octoEliteText or top:CreateFontString(nil, "OVERLAY")
    f.octoEliteText:SetFont(pfUI.font_unit or STANDARD_TEXT_FONT, 10, "OUTLINE")
    f.octoEliteText:ClearAllPoints()
    f.octoEliteText:SetPoint(corner == "TOPLEFT" and "BOTTOMLEFT" or "BOTTOMRIGHT", f, corner, 0, 2)
    f.octoEliteText:Hide()

    f.octoStatus = f.octoStatus or top:CreateTexture(nil, "OVERLAY")
    f.octoStatus:SetWidth(18)
    f.octoStatus:SetHeight(18)
    f.octoStatus:ClearAllPoints()
    f.octoStatus:SetPoint("CENTER", f.hp, "CENTER", 0, 0)
    f.octoStatus:Hide()
    f.octoStatusText = f.octoStatusText or top:CreateFontString(nil, "OVERLAY")
    f.octoStatusText:SetFont(pfUI.font_unit or STANDARD_TEXT_FONT, 12, "OUTLINE")
    f.octoStatusText:ClearAllPoints()
    f.octoStatusText:SetPoint("CENTER", f.hp, "CENTER", 0, 0)
    f.octoStatusText:Hide()

    UO.Update(f)
  end

  -- ---------------------------------------------------------------- update

  -- the debuff to show: the first one you can cure, else (when allowed) any
  local function DebuffType(unit, curable)
    local cures = UO.CURES[myclass or ""] or {}
    local any
    for i = 1, 16 do
      local tex, _, kind = UnitDebuff(unit, i)
      if not tex then break end
      if kind and kind ~= "" then
        if cures[kind] then return kind end
        any = any or kind
      end
    end
    if not curable then return any end
  end
  UO.DebuffType = DebuffType

  local function ShowDebuff(f, kind, mode)
    local col = kind and DebuffTypeColor and DebuffTypeColor[kind]
    if not col or mode == "none" then
      f.octoDebuff:Hide()
      f.octoDebuffBg:Hide()
      return
    end
    if mode == "border" or mode == "both" then
      Edges(f.octoDebuff, 2, col.r, col.g, col.b, 1)
      f.octoDebuff:Show()
    else
      f.octoDebuff:Hide()
    end
    if mode == "background" or mode == "both" then
      f.octoDebuffBg:SetVertexColor(col.r, col.g, col.b, .3)
      f.octoDebuffBg:Show()
    else
      f.octoDebuffBg:Hide()
    end
  end
  UO.ShowDebuff = ShowDebuff

  -- after pfUI refreshes a frame: what the unit is now
  function UO.Update(f)
    local c = f and f.config
    if not c or not f.octoClass then return end
    local unit = Unit(f)
    local exists = unit and UnitExists(unit)
    local player = exists and UnitIsPlayer(unit)
    local _, class
    if player then _, class = UnitClass(unit) end
    local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]

    -- class icon
    if coords and (c.o_classicon or "none") ~= "none" then
      f.octoClass:SetTexture(pfUI.media["img:classicons"])
      f.octoClass:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
      f.octoClass:Show()
    else
      f.octoClass:Hide()
    end

    -- the class picture in place of the portrait (players only)
    if c.o_classport == "1" and coords and f.portrait and f.portrait:IsShown() then
      if f.portrait.model then f.portrait.model:Hide() end
      f.portrait.tex:SetTexture(pfUI.media["img:classicons"])
      f.portrait.tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
      f.portrait.tex:Show()
      f.octoClassPort = true
    elseif f.octoClassPort then
      f.octoClassPort = nil
      f.portrait.tex:SetTexCoord(.1, .9, .1, .9)
      if f.portrait.model then f.portrait.model:Show() end
      pfUI.uf:RefreshUnit(f, "portrait")
    end

    -- elite / rare / boss badge
    local kind = exists and UnitClassification and UnitClassification(unit) or "normal"
    if f.octoForceElite then kind = f.octoForceElite end
    local mode = c.o_elite or "none"
    local special = kind == "elite" or kind == "rareelite" or kind == "rare" or kind == "worldboss"
    if special and mode == "graphic" then
      local rare = kind == "rare" or kind == "rareelite"
      -- (5 Nov 2026, Art page: a drawn crest in its own gold / silver / red, bigger)
      local crest = pfUI.art and pfUI.art.Crest(nil, kind == "worldboss" and "boss" or (rare and "rare" or "elite"))
      if crest then
        f.octoElite:SetTexture(crest)
        f.octoElite:SetVertexColor(1, 1, 1)
        f.octoElite:SetWidth(46)
        f.octoElite:SetHeight(23)
      else
        f.octoElite:SetTexture(ART .. (rare and "uf-rare" or "uf-elite"))
        f.octoElite:SetWidth(36)
        f.octoElite:SetHeight(18)
        if kind == "worldboss" then f.octoElite:SetVertexColor(1, .35, .3)
        elseif rare then f.octoElite:SetVertexColor(.8, .85, .95)
        else f.octoElite:SetVertexColor(1, .82, .3) end
      end
      f.octoElite:Show()
      f.octoEliteText:Hide()
    elseif special and mode == "text" then
      local word = (kind == "worldboss" and "Boss") or (kind == "rareelite" and "Rare elite") or (kind == "rare" and "Rare") or "Elite"
      f.octoEliteText:SetText(word)
      if kind == "rare" or kind == "rareelite" then f.octoEliteText:SetTextColor(.8, .85, .95)
      elseif kind == "worldboss" then f.octoEliteText:SetTextColor(1, .35, .3)
      else f.octoEliteText:SetTextColor(1, .82, .3) end
      f.octoEliteText:Show()
      f.octoElite:Hide()
    else
      f.octoElite:Hide()
      f.octoEliteText:Hide()
    end

    -- status: offline, AFK, dead / ghost / feigning
    local mark, word
    if c.o_status == "1" and exists then
      if not UnitIsConnected(unit) then
        mark = "uf-offline"
      elseif UnitIsFeignDeath and UnitIsFeignDeath(unit) then
        word = "Feigning"
      elseif UnitIsGhost(unit) then
        word = "Ghost"
      elseif UnitIsDead(unit) then
        -- (a res on its way shows its icon there instead, api/unitframes.lua)
        local lp = pfUI.api and pfUI.api.libpredict
        if not (lp and lp.UnitHasIncomingResurrection and lp:UnitHasIncomingResurrection(unit)) then word = "Dead" end
      elseif player and UnitIsAFK and UnitIsAFK(unit) then
        mark = "uf-afk"
      end
    end
    -- (the options' Test buttons show a state for a few seconds)
    local fs = f.octoForceStatus
    if fs and GetTime() < (fs[3] or 0) then mark, word = fs[1], fs[2] else f.octoForceStatus = nil end
    if mark then
      f.octoStatus:SetTexture(ART .. mark)
      f.octoStatus:Show()
    else
      f.octoStatus:Hide()
    end
    if word then
      f.octoStatusText:SetText(word)
      f.octoStatusText:Show()
    else
      f.octoStatusText:Hide()
    end

    -- the frame of the unit you target
    if c.o_selhl == "1" and exists and f.label ~= "target" and UnitIsUnit(unit, "target") then
      local r, g, b = 1, 1, 1
      if GetAccentColor then r, g, b = GetAccentColor() end
      Edges(f.octoSel, 1, r, g, b, 1)
      f.octoSel:Show()
    else
      f.octoSel:Hide()
    end

    -- debuffs in their colour
    if f.octoForceDebuff and GetTime() >= f.octoForceDebuff then f.octoForceDebuff = nil end
    if not f.octoForceDebuff then
      local hl = c.o_debuffhl or "none"
      if hl ~= "none" and exists and UnitIsFriend(unit, "player") then
        ShowDebuff(f, DebuffType(unit, c.o_curable == "1"), hl)
      else
        ShowDebuff(f, nil, "none")
      end
    end

    -- pet happiness: only when unhappy
    if f.happinessIcon and f.label == "pet" and C.unitframes.pet.o_happysad == "1" and GetPetHappiness and GetPetHappiness() == 3 then
      f.happinessIcon:Hide()
    end
  end

  -- ---------------------------------------------------------------- ClassicAPI auras

  -- 1.12 gives no timer on other units' buffs and no dispel type on buffs;
  -- ClassicAPI (libclient.Aura) does when the client saw the cast. Without it
  -- the buffs stay as pfUI draws them.
  function UO.Auras(f)
    if not libclient or not libclient.HasClassicAPI() or pfUI.client > 11200 then return end
    if not f or not f.buffs or not f.config or f.label == "player" then return end
    local unit = Unit(f)
    if not unit or not UnitExists(unit) then return end
    local purge = f.config.o_purge == "1" and UnitCanAttack("player", unit)
    for i, b in ipairs(f.buffs) do
      if b:IsShown() then
        local tex = UnitBuff(unit, i)
        local name, duration, left, _, _, dtype = libclient.Aura(unit, i, nil, tex)
        if b.cd then
          if duration and left then
            CooldownFrame_SetTimer(b.cd, GetTime() + left - duration, duration, 1)
          elseif b.octoTimer then
            CooldownFrame_SetTimer(b.cd, 0, 0, 0)
          end
          b.octoTimer = (duration and left) and true or nil
        end
        if b.backdrop then
          local col = purge and dtype == "Magic" and DebuffTypeColor and DebuffTypeColor.Magic
          if col then
            b.backdrop:SetBackdropBorderColor(col.r, col.g, col.b, 1)
            b.octoPurge = true
          elseif b.octoPurge then
            b.backdrop:SetBackdropBorderColor(GetStringColor(C.appearance.border.color))
            b.octoPurge = nil
          end
        end
      end
    end
  end

  -- ---------------------------------------------------------------- combat flash

  function UO.Flash(f, heal)
    local c = f and f.config
    if not c or not f.octoFlash then return end
    if heal then Edges(f.octoFlash, 2, .2, 1, .3, 1) else Edges(f.octoFlash, 2, 1, .15, .1, 1) end
    f.octoFlash.start = GetTime()
    f.octoFlash:SetAlpha(1)
    f.octoFlash:Show()
  end

  local ev = CreateFrame("Frame")
  ev:RegisterEvent("UNIT_COMBAT")
  ev:RegisterEvent("PLAYER_TARGET_CHANGED")
  ev:SetScript("OnEvent", function()
    if event == "UNIT_COMBAT" then
      local heal = arg2 == "HEAL"
      if not heal and (arg2 ~= "WOUND" or (tonumber(arg4) or 0) <= 0) then return end
      for _, f in ipairs(pfUI.uf.frames) do
        if f.config and f.config.o_flash == "1" and Unit(f) == arg1 and f:IsVisible() then UO.Flash(f, heal) end
      end
    elseif event == "PLAYER_TARGET_CHANGED" then
      for _, f in ipairs(pfUI.uf.frames) do
        if f.config and f.config.o_selhl == "1" and f:IsVisible() then UO.Update(f) end
      end
      if C.unitframes.o_targetsound == "1" then
        if not UnitExists("target") then
          PlaySound("INTERFACESOUND_LOSTTARGETUNIT")
        elseif UnitIsEnemy("target", "player") then
          PlaySound("igCreatureAggroSelect")
        elseif UnitIsFriend("target", "player") then
          PlaySound("igCharacterNPCSelect")
        else
          PlaySound("igCreatureNeutralSelect")
        end
      end
    end
  end)

  -- ---------------------------------------------------------------- every frame

  -- fading bars, flash fade-out, expiring buffs, unhappy pet
  local watch = CreateFrame("Frame")
  UO.watch = watch
  watch:SetScript("OnUpdate", function()
    local now = GetTime()
    local dt = now - (this.last or now)
    this.last = now
    local pulse = .45 + .55 * math.abs(math.sin(now * 4))
    for _, f in ipairs(pfUI.uf.frames) do
      local c = f.config
      if c and f:IsVisible() then
        -- combat flash fades over half a second
        local fl = f.octoFlash
        if fl and fl:IsShown() then
          local k = (now - (fl.start or 0)) / .5
          if k >= 1 then fl:Hide() else fl:SetAlpha(1 - k) end
        end
        -- fading bar
        local gh = f.octoGhost
        if gh and c.o_fade == "1" then
          -- (the bar's own value: what it is heading to)
          local bar = f.hp.bar
          local frac = 0
          if bar.max and bar.max > 0 and bar.val then
            frac = (bar.val - (bar.min or 0)) / (bar.max - (bar.min or 0))
          else
            local unit = Unit(f)
            local max = unit and UnitHealthMax(unit) or 0
            frac = max > 0 and UnitHealth(unit) / max or 0
            if c.invert_healthbar == "1" then frac = 1 - frac end
          end
          local g = f.octoGhostFrac or frac
          if frac >= g then
            g = frac
          else
            -- the lost part shrinks to nothing over the fade time
            local t = math.max(.1, tonumber(c.o_fadetime) or .6)
            g = math.max(frac, g - dt / t * math.max(.05, g - frac + .05))
          end
          g = math.min(1, g)
          f.octoGhostFrac = g
          if g - frac > .002 then
            local vertical = c.verticalbar == "1"
            local size = vertical and (f.hp.bar:GetHeight() or 0) or (f.hp.bar:GetWidth() or 0)
            if vertical then gh:SetHeight(math.max(.1, size * g)) else gh:SetWidth(math.max(.1, size * g)) end
            gh:Show()
          else
            gh:Hide()
          end
        end
        -- player buffs in their last 30 seconds
        if f == pfUI.uf.player and c.o_flashexpire == "1" and f.buffs and GetPlayerBuff then
          for _, b in pairs(f.buffs) do
            if b:IsShown() and b.id then
              local left = GetPlayerBuffTimeLeft(GetPlayerBuff(PLAYER_BUFF_START_ID + b.id, "HELPFUL")) or 0
              b:SetAlpha((left > 0 and left < 30) and pulse or 1)
            end
          end
        end
        -- an unhappy pet's mark flashes
        if f.label == "pet" and f.happinessIcon and f.happinessIcon:IsShown() and C.unitframes.pet.o_happyflash == "1" then
          local h = GetPetHappiness and GetPetHappiness()
          f.happinessIcon:SetAlpha((h and h < 3) and pulse or 1)
        end
      end
    end
  end)

  -- ---------------------------------------------------------------- hook pfUI

  local UpdateConfig = pfUI.uf.UpdateConfig
  local function OctoUpdateConfig(self)
    UpdateConfig(self)
    UO.Configure(self)
  end
  pfUI.uf.UpdateConfig = OctoUpdateConfig
  -- (frames made before this module carry pfUI's own function)
  for _, f in ipairs(pfUI.uf.frames) do
    f.UpdateConfig = OctoUpdateConfig
    UO.Configure(f)
  end

  -- each text's own colour (user, 23 Oct 2026: "EVERYTHING that can change
  -- colour can and has a clear and simple selector"): o_tc_<pos> = "" (the
  -- text's own colour codes), "class" or "custom" (o_tcc_<pos>)
  local GetStatusValue = pfUI.uf.GetStatusValue
  pfUI.uf.GetStatusValue = function(self, unit, pos)
    local text = GetStatusValue(self, unit, pos)
    local cfg = unit and unit.config
    local mode = cfg and pos and cfg["o_tc_" .. pos]
    if not text or text == "" or not mode or mode == "" then return text end
    local r, g, b
    if mode == "class" then
      local _, class = UnitClass((unit.label or "") .. (unit.id or ""))
      local cc = class and RAID_CLASS_COLORS[class]
      if not cc then return text end
      r, g, b = cc.r, cc.g, cc.b
    else
      local cr, cg, cb = GetStringColor(cfg["o_tcc_" .. pos] or "1,1,1,1")
      r, g, b = tonumber(cr) or 1, tonumber(cg) or 1, tonumber(cb) or 1
    end
    text = gsub(gsub(text, "|c%x%x%x%x%x%x%x%x", ""), "|r", "")
    return string.format("|cff%02x%02x%02x", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255)) .. text .. "|r"
  end
  UO.TEXTS = { "hpleft", "hpcenter", "hpright", "powerleft", "powercenter", "powerright" }

  local RefreshUnit = pfUI.uf.RefreshUnit
  pfUI.uf.RefreshUnit = function(self, unit, component)
    RefreshUnit(self, unit, component)
    if unit and unit.octoClass then UO.Update(unit) end
    if unit and (not component or component == "all" or component == "aura") then UO.Auras(unit) end
  end

  -- ---------------------------------------------------------------- cast bars on group frames
  -- (1 Nov 2026, user: "make sure cast bars show on raid frames of our members").
  -- A thin bar along the bottom of each raid / party frame (C.unitframes[raid|group].o_cast):
  -- gold while casting, green while channelling, from UnitCastingInfo / UnitChannelInfo
  -- (libcast: ClassicAPI's or SuperWoW's exact casts when present, else the combat log).
  -- One driver for all frames, 15 times a second - nothing runs while nobody casts.
  local CASTCOL, CHANCOL = { 1, .78, .2 }, { .3, .9, .4 }
  local function CastBar(f)
    if f.octoCast then return f.octoCast end
    local holder = f.hp or f
    local b = CreateFrame("StatusBar", nil, f)
    b:SetFrameLevel((f:GetFrameLevel() or 1) + 6)
    b:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 1, 1)
    b:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -1, 1)
    b:SetHeight(3)
    b:SetStatusBarTexture(pfUI.media["img:bar"])
    b:SetMinMaxValues(0, 1)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints(b)
    b.bg:SetTexture(0, 0, 0, .6)
    b:Hide()
    f.octoCast = b
    return b
  end
  UO.CastBar = CastBar
  local function CastOn(f)
    local c = f.config
    local label = f.label
    return c and c.o_cast == "1" and label and (string.find(label, "^raid") or string.find(label, "^party"))
  end
  function UO.CastTick(f)
    if not CastOn(f) or not f:IsVisible() then
      if f.octoCast then f.octoCast:Hide() end
      return
    end
    local unit = f.label .. (f.id or "")
    local channel
    local name, _, _, _, startMs, endMs = UnitCastingInfo(unit)
    if not name then
      name, _, _, _, startMs, endMs = UnitChannelInfo(unit)
      channel = name and true
    end
    local b = f.octoCast
    if not name or not startMs or not endMs or endMs <= startMs then
      if b then b:Hide() end
      return
    end
    b = b or CastBar(f)
    local now = GetTime() * 1000
    local v = (now - startMs) / (endMs - startMs)
    if v < 0 then v = 0 elseif v > 1 then v = 1 end
    if channel then v = 1 - v end
    local col = channel and CHANCOL or CASTCOL
    b:SetStatusBarColor(col[1], col[2], col[3], 1)
    b:SetValue(v)
    b:Show()
  end
  local castDriver = CreateFrame("Frame")
  UO.castDriver = castDriver
  castDriver:SetScript("OnUpdate", function()
    if (this.t or 0) > GetTime() then return end
    this.t = GetTime() + 1 / 15
    for _, f in ipairs(pfUI.uf.frames or {}) do
      if f.label and (f.octoCast or CastOn(f)) then pcall(UO.CastTick, f) end
    end
  end)
end)
