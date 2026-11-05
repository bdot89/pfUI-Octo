pfUI:RegisterModule("plates", "vanilla:tbc", function ()
  -- pfUI Octo nameplates: Plater's ideas on pfUI's own nameplates
  -- (docs\plates-spec.md). User, 20 Oct 2026: "implement our own version of
  -- this name plate addon into our PFUI with all features and art work".
  -- Plater is All Rights Reserved, so this is written fresh and the art is
  -- our own (img\plates, drawn by tools\MakePlateArt.ps1).
  --   look     bar texture, background, fonts and text sizes
  --   size     per kind (enemy NPC / player, friendly NPC / player), smaller
  --            out of combat, bigger target - eased, by the overlay's scale
  --   threat   aggro colours that flip for tanks, "pulling" from the server's
  --            threat list (your target only), off-tank, aggro glow
  --   target   arrows / chevrons / corners / light under the bar, mouse-over
  --            highlight
  --   execute  bar colour and a marker at N % (warriors and paladins)
  --   cast bar Plater's layout, colours for cast / channel / done / stopped,
  --            spark, "Interrupted by NAME", fade out
  --   range    plates fade beyond N yards or out of sight (UnitXP)
  --   marks    elite / rare / boss icon by the name
  -- Settings: C.plates (strings). Options: Nameplates (plates-options.lua).
  -- nameplates.lua stays as upstream: its functions are wrapped here (they are
  -- looked up on pfUI.nameplates at each call, and no plate exists yet).
  local NP = pfUI.nameplates
  if not NP then return end
  local S = C.plates
  local P = {}
  pfUI.plates = P

  local function Art(name) return pfUI.media["img:plates\\" .. name] end
  P.ART = Art

  -- ---------------------------------------------------------------- settings

  local COL = {}
  local COLORS = { "c_aggro", "c_pulling", "c_safe", "c_tankaggro", "c_losing", "c_offtank", "c_lost", "c_taking",
    "executecolor", "c_cast", "c_channel", "c_done", "c_stopped", "bgcolor", "castbg", "targetcolor",
    "namecolor", "levelcolor", "hptextcolor", "casttextcolor", "bordercolor", "skincolor", "cpcustom",
    "elitecolor", "rarecolor", "bosscolor", "questcolor", "questgivercolor" }
  local function ReadColors()
    for _, k in ipairs(COLORS) do
      local r, g, b, a = GetStringColor(S[k] or "1,1,1,1")
      COL[k] = { tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1 }
    end
  end
  P.COL = COL

  -- other tanks: pfUI's raid tank roles and its off-tank names
  local offtanks = {}
  local function ReadTanks()
    offtanks = {}
    for _, v in pairs({ strsplit("#", C.nameplates.combatofftanks or "") }) do
      if v and v ~= "" then offtanks[string.lower(v)] = true end
    end
  end
  function P.IsTank(name)
    if not name then return end
    if offtanks[string.lower(name)] then return true end
    local raid = pfUI.uf and pfUI.uf.raid
    return raid and raid.tankrole and raid.tankrole[name] and true or nil
  end

  -- ---------------------------------------------------------------- role, threat, execute

  local role, roleAt = "dps", 0
  -- "tank" in Defensive Stance, bear form or with Righteous Fury (or marked a
  -- tank in pfUI's raid frames), else "dps"; or the role picked in the options
  function P.Role()
    if S.role == "tank" or S.role == "dps" then return S.role end
    if GetTime() < roleAt then return role end
    roleAt = GetTime() + 1
    role = "dps"
    local _, class = UnitClass("player")
    if class == "WARRIOR" or class == "DRUID" then
      for i = 1, (GetNumShapeshiftForms() or 0) do
        local icon, _, active = GetShapeshiftFormInfo(i)
        if active and icon and (string.find(icon, "DefensiveStance") or string.find(icon, "BearForm")) then role = "tank" end
      end
    elseif class == "PALADIN" then
      for i = 1, 32 do
        local tex = UnitBuff("player", i)
        if not tex then break end
        if string.find(tex, "SealOfFury") then role = "tank" end
      end
    end
    if P.IsTank(UnitName("player")) then role = "tank" end
    return role
  end

  -- the server's threat list for your target, while fresh
  local function ServerThreat()
    local TH = pfUI.meters and pfUI.meters.threat
    if not TH or not TH.list or GetTime() - (TH.at or 0) > 2 then return end
    return TH.list
  end

  -- What a mob is doing about you (nil = not fighting you, or not a mob).
  -- unit: the plate's GUID (SuperWoW) or "target"; istarget: it is your target
  -- (only then the server's threat list is about it).
  --   damage / healer: aggro (on you), pulling (you are near the tank), safe
  --   tank:            aggro (on you), losing (someone is near you),
  --                    offtank (on another tank), lost (on someone else)
  function P.ThreatState(unit, istarget)
    if not unit or not UnitExists(unit) or UnitIsPlayer(unit) then return end
    if not UnitAffectingCombat("player") or not UnitAffectingCombat(unit) then return end
    if not UnitCanAttack("player", unit) then return end
    local tu = unit .. "target"
    local onme = UnitIsUnit(tu, "player")
    local tname = UnitName(tu)
    local me = UnitName("player")
    local pull = tonumber(S.pullat) or 90
    local list = istarget and ServerThreat()
    if P.Role() == "tank" then
      if onme then
        for _, e in ipairs(list or {}) do
          if e.name ~= me and (e.perc or 0) >= pull then return "losing" end
        end
        return "aggro"
      end
      if not tname then return end
      if P.IsTank(tname) then
        -- you are about to take it from the other tank (Plater's pulling_from_tank)
        for _, e in ipairs(list or {}) do
          if e.name == me and (e.perc or 0) >= pull then return "taking" end
        end
        return "offtank"
      end
      return "lost"
    end
    if onme then return "aggro" end
    for _, e in ipairs(list or {}) do
      if e.name == me and not e.tank and (e.perc or 0) >= pull then return "pulling" end
    end
    if tname then return "safe" end
  end

  local THREATCOL = {
    dps = { aggro = "c_aggro", pulling = "c_pulling", safe = "c_safe" },
    tank = { aggro = "c_tankaggro", losing = "c_losing", offtank = "c_offtank", lost = "c_lost", taking = "c_taking" },
  }
  -- the bar colour of a threat state, nil = keep the normal colour
  function P.ThreatColor(state)
    local key = state and THREATCOL[P.Role()][state]
    if not key or (key == "c_safe" and S.safenormal == "1") then return end
    return COL[key]
  end
  -- the states that light the aggro glow: a mob on a damage dealer, or off a tank
  function P.Alarming(state)
    if P.Role() == "tank" then return state == "lost" end
    return state == "aggro"
  end

  -- execute range in %, nil = off (auto: warriors and paladins)
  function P.ExecutePct()
    if S.execute == "off" then return end
    if S.execute == "auto" then
      local _, class = UnitClass("player")
      if class ~= "WARRIOR" and class ~= "PALADIN" then return end
    end
    local v = tonumber(S.executepct) or 20
    if v <= 0 then return end
    return v
  end

  -- enemynpc / enemyplayer / friendlynpc / friendlyplayer, from the game's bar
  -- colour (blue = friendly player, green = friendly NPC) and pfUI's cache
  function P.Kind(plate)
    local r, g, b = plate.original.healthbar:GetStatusBarColor()
    local player = plate.cache and plate.cache.player == "PLAYER"
    r, g, b = r or 1, g or 0, b or 0
    if r < .2 and g < .2 and b > .9 then return "friendlyplayer" end
    if r < .2 and g > .9 and b < .2 then return player and "friendlyplayer" or "friendlynpc" end
    return player and "enemyplayer" or "enemynpc"
  end

  -- the name's own offset: parts that hang off the name take it back off, so
  -- moving the name moves nothing else (user, 22 Oct 2026: parts "stay locked
  -- together ... make sure they are free")
  function P.NameOff()
    return tonumber(S.nameoffx) or 0, tonumber(S.nameoffy) or 0
  end

  -- SuperWoW is there (pfUI's own superwow_active only turns on after the
  -- first cast event it sees, so it reads "missing" until someone casts)
  function P.SuperWoW()
    return (superwow_active or SUPERWOW_VERSION) and true or nil
  end

  -- the plate's unit: its GUID with SuperWoW, else "target" for your target
  local function UnitOf(plate)
    if plate.parent and plate.parent.preview then return end
    if P.SuperWoW() and plate.parent and plate.parent.GetName then
      local guid = plate.parent:GetName(1)
      if guid and guid ~= "" then return guid end
    end
    if plate.istarget then return "target" end
  end

  -- ---------------------------------------------------------------- interrupts

  -- victim's name -> { by = kicker, spell = spell, at = time }
  local kicks = {}
  P.kicks = kicks
  function P.ParseInterrupt(msg)
    if type(msg) ~= "string" then return end
    local victim, spell, by
    if SPELLINTERRUPTSELFOTHER then
      victim, spell = cmatch(msg, SPELLINTERRUPTSELFOTHER)
      if victim then by = T["You"] end
    end
    if not victim and SPELLINTERRUPTOTHEROTHER then
      by, victim, spell = cmatch(msg, SPELLINTERRUPTOTHEROTHER)
    end
    if not victim or not by then return end
    kicks[victim] = { by = by, spell = spell, at = GetTime() }
    return victim, by, spell
  end

  local log = CreateFrame("Frame")
  for _, e in ipairs({ "CHAT_MSG_SPELL_SELF_DAMAGE", "CHAT_MSG_SPELL_PARTY_DAMAGE", "CHAT_MSG_SPELL_PET_DAMAGE",
      "CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE", "CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE",
      "CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE" }) do
    log:RegisterEvent(e)
  end
  log:SetScript("OnEvent", function()
    if S.enable == "1" then P.ParseInterrupt(arg1) end
  end)

  -- ---------------------------------------------------------------- plate parts

  local function Build(plate)
    local o = {}
    plate.octo = o
    local h, cb = plate.health, plate.castbar

    o.hl = h:CreateTexture(nil, "OVERLAY")
    o.hl:SetAllPoints(h)
    o.hl:SetBlendMode("ADD")
    o.hl:SetVertexColor(1, 1, 1, .22)
    o.hl:Hide()

    o.tick = h:CreateTexture(nil, "OVERLAY")
    o.tick:SetTexture(Art("tick"))
    o.tick:SetWidth(4)
    o.tick:Hide()

    o.left = h:CreateTexture(nil, "OVERLAY")
    o.right = h:CreateTexture(nil, "OVERLAY")
    o.corners = {}
    for i = 1, 4 do
      o.corners[i] = h:CreateTexture(nil, "OVERLAY")
      o.corners[i]:SetTexture(Art("corner"))
      o.corners[i]:Hide()
    end
    o.under = plate:CreateTexture(nil, "BACKGROUND")
    o.under:SetTexture(Art("underglow"))
    o.under:SetBlendMode("ADD")
    o.under:Hide()
    o.left:Hide()
    o.right:Hide()

    o.glow = CreateFrame("Frame", nil, h)
    o.glow:SetPoint("TOPLEFT", h, "TOPLEFT", -7, 7)
    o.glow:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 7, -7)
    o.glow:SetBackdrop({ edgeFile = pfUI.media["img:glow"], edgeSize = 8,
                         insets = { left = 0, right = 0, top = 0, bottom = 0 } })
    o.glow:Hide()

    -- border skins around the health and cast bars
    o.skinH = CreateFrame("Frame", nil, h)
    o.skinC = CreateFrame("Frame", nil, cb)
    o.skinH:Hide()
    o.skinC:Hide()

    o.mark = plate:CreateTexture(nil, "OVERLAY")
    o.mark:Hide()

    o.spark = cb:CreateTexture(nil, "OVERLAY")
    o.spark:SetTexture(Art("spark"))
    o.spark:SetBlendMode("ADD")
    o.spark:SetWidth(10)
    o.spark:Hide()

    -- the cast bar's last look after it ends (pfUI hides its bar at once)
    o.cend = CreateFrame("StatusBar", nil, h)
    o.cend:SetAllPoints(cb)
    o.cend:SetMinMaxValues(0, 1)
    o.cend:SetValue(1)
    o.cend.text = o.cend:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    o.cend.text:SetPoint("LEFT", o.cend, "LEFT", 3, 0)
    o.cend.text:SetPoint("RIGHT", o.cend, "RIGHT", -3, 0)
    o.cend.text:SetTextColor(1, 1, 1, 1)
    o.cend:Hide()
    return o
  end

  local function Vis(region, on) if on then region:Show() else region:Hide() end end

  -- border skins: an edge around each bar, outside pfUI's own 1 px border
  -- (pfui = only that border)
  local WHITE = "Interface\\Buttons\\WHITE8X8"
  local SKINS = {
    shadow = { edge = pfUI.media["img:glow2"], size = 6, off = 4, color = { 0, 0, 0, .9 } },
    thick = { edge = WHITE, size = 2, off = 2, color = { 0, 0, 0, 1 } },
    accent = { edge = WHITE, size = 1, off = 1, color = { 1, 1, 1, 1 }, accent = true },
    neon = { edge = pfUI.media["img:glow"], size = 6, off = 5, color = { 1, 1, 1, .8 }, accent = true },
    gold = { edge = WHITE, size = 1, off = 1, color = { .85, .68, .3, 1 } },
  }
  P.SKINS = SKINS

  local function Font()
    local font = C.nameplates.use_unitfonts == "1" and pfUI.font_unit or pfUI.font_default
    local size = C.nameplates.use_unitfonts == "1" and C.global.font_unit_size or C.global.font_size
    if S.font and S.font ~= "" then font = S.font end
    return font, tonumber(size) or 12
  end

  -- everything that only changes with the settings
  function P.Configure(plate)
    if not plate or not plate.health then return end
    local o = plate.octo or Build(plate)
    if S.enable ~= "1" then
      P.Off(plate)
      return
    end
    local _, border = GetBorderSize("nameplates")
    border = tonumber(border) or 1
    local font, fsize = Font()
    local style = C.nameplates.name.fontstyle
    local namesize = tonumber(S.namesize) or 0
    if namesize <= 0 then namesize = fsize end
    local hpsize = tonumber(S.hpsize) or 0
    if hpsize <= 0 then hpsize = fsize - 2 end
    local h, cb = plate.health, plate.castbar

    -- places: the bar hangs from the top of the plate (pfUI hangs it from the
    -- name) so the name can be moved on its own; health text moves too
    local nx, ny = tonumber(S.nameoffx) or 0, tonumber(S.nameoffy) or 0
    plate.name:ClearAllPoints()
    plate.name:SetPoint("TOP", plate, "TOP", nx, ny)
    h:ClearAllPoints()
    h:SetPoint("TOP", plate, "TOP", 0, -namesize + (tonumber(C.nameplates.health.offset) or -3))
    local hx, hy = tonumber(S.hpoffx) or 0, tonumber(S.hpoffy) or 0
    h.text:ClearAllPoints()
    h.text:SetPoint("TOPLEFT", h, "TOPLEFT", 2 + hx, hy)
    h.text:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", -2 + hx, hy)

    -- look
    plate.name:SetFont(font, namesize, style)
    plate.level:SetFont(font, namesize, style)
    plate.guild:SetFont(font, fsize, style)
    h.text:SetFont(font, hpsize, "OUTLINE")
    local tex = (S.bartexture and S.bartexture ~= "") and pfUI.media[S.bartexture] or pfUI.media[C.nameplates.healthtexture]
    h:SetStatusBarTexture(tex)
    cb:SetStatusBarTexture(tex)
    o.cend:SetStatusBarTexture(tex)
    o.hl:SetTexture(tex)
    local bg, cbg = COL.bgcolor, COL.castbg
    if h.backdrop then h.backdrop:SetBackdropColor(bg[1], bg[2], bg[3], bg[4]) end
    -- the cast bar's empty part is lighter: a cast just started still shows
    if cb.backdrop then cb.backdrop:SetBackdropColor(cbg[1], cbg[2], cbg[3], cbg[4]) end
    if not o.cend.backdrop then CreateBackdrop(o.cend, border) end
    if o.cend.backdrop then o.cend.backdrop:SetBackdropColor(cbg[1], cbg[2], cbg[3], cbg[4]) end

    -- cast bar: Plater's layout (icon to the left, name left, time right)
    local ch = tonumber(S.castheight) or 12
    local tsize = math.max(8, math.min(fsize, ch + 1))
    if (tonumber(S.casttextsize) or 0) > 0 then tsize = tonumber(S.casttextsize) end
    -- the cast bar's place: under the health bar, moved by your offsets
    -- (dragged in the preview or set on Cast bar)
    local cx, cy = tonumber(S.castoffx) or 0, tonumber(S.castoffy) or 0
    cb:ClearAllPoints()
    cb:SetPoint("TOPLEFT", h, "BOTTOMLEFT", cx, -border * 3 + cy)
    cb:SetPoint("TOPRIGHT", h, "BOTTOMRIGHT", cx, -border * 3 + cy)
    if S.castlayout == "plater" then
      cb:SetHeight(ch)
      cb.icon:ClearAllPoints()
      cb.icon:SetPoint("TOPRIGHT", cb, "TOPLEFT", -border * 3, 0)
      local isz = (tonumber(S.casticonsize) or 0) > 0 and tonumber(S.casticonsize) or ch
      cb.icon:SetWidth(isz)
      cb.icon:SetHeight(isz)
      cb.spell:ClearAllPoints()
      cb.spell:SetPoint("LEFT", cb, "LEFT", 3, 0)
      cb.spell:SetPoint("RIGHT", cb, "RIGHT", -30, 0)
      cb.spell:SetJustifyH("LEFT")
      cb.spell:SetFont(font, tsize, "OUTLINE")
      cb.text:ClearAllPoints()
      cb.text:SetPoint("RIGHT", cb, "RIGHT", -2, 0)
      cb.text:SetJustifyH("RIGHT")
      cb.text:SetFont(font, tsize, "OUTLINE")
      cb.text:SetTextColor(1, 1, 1, 1)
    end
    o.cend.text:SetFont(font, tsize, "OUTLINE")
    -- pfUI recolours name / level only when the game's colour changes: make it
    -- do so again (a colour of yours switched off goes back to pfUI's)
    plate.cache.namecolor, plate.cache.levelcolor = nil, nil
    -- text colours (pfUI's white unless picked)
    local tc, cc = COL.hptextcolor, COL.casttextcolor
    h.text:SetTextColor(tc[1], tc[2], tc[3], tc[4])
    cb.spell:SetTextColor(cc[1], cc[2], cc[3], cc[4])
    cb.text:SetTextColor(cc[1], cc[2], cc[3], cc[4])
    o.cend.text:SetJustifyH(S.castlayout == "plater" and "LEFT" or "CENTER")
    o.spark:SetHeight(ch * 2.4)

    -- target indicators
    local hh = tonumber(C.nameplates.heighthealth) or 8
    local r, g, b, a = COL.targetcolor[1], COL.targetcolor[2], COL.targetcolor[3], COL.targetcolor[4]
    if S.targetaccent == "1" and GetAccentColor then r, g, b = GetAccentColor() end
    local isz = (tonumber(S.targetsize) or 0) > 0 and tonumber(S.targetsize) or math.max(12, hh * 2)
    local tgap = tonumber(S.targetgap) or 0
    local arrow = S.indicator == "chevrons" and Art("chevron") or Art("arrow")
    o.left:SetTexture(arrow)
    o.right:SetTexture(arrow)
    o.left:SetTexCoord(0, 1, 0, 1)
    o.right:SetTexCoord(1, 0, 0, 1)
    for _, t in ipairs({ o.left, o.right }) do
      t:SetWidth(isz)
      t:SetHeight(isz)
      t:SetVertexColor(r, g, b, a)
    end
    o.left:ClearAllPoints()
    -- (the left arrow's x is set on each update from the level's width, so
    -- moving the level does not move it)
    o.left:SetPoint("RIGHT", h, "LEFT", -24 - tgap, 0)
    o.tgap = tgap
    o.right:ClearAllPoints()
    o.right:SetPoint("LEFT", h, "RIGHT", 3 + tgap, 0)
    local csz = math.max(6, hh)
    local CORNERS = {
      { "TOPLEFT", -3, 3, 0, 1, 0, 1 }, { "TOPRIGHT", 3, 3, 1, 0, 0, 1 },
      { "BOTTOMLEFT", -3, -3, 0, 1, 1, 0 }, { "BOTTOMRIGHT", 3, -3, 1, 0, 1, 0 },
    }
    for i = 1, 4 do
      local c, d = o.corners[i], CORNERS[i]
      c:ClearAllPoints()
      c:SetPoint(d[1], h, d[1], d[2], d[3])
      c:SetTexCoord(d[4], d[5], d[6], d[7])
      c:SetWidth(csz)
      c:SetHeight(csz)
      c:SetVertexColor(r, g, b, a)
    end
    o.under:ClearAllPoints()
    o.under:SetPoint("CENTER", h, "CENTER", 0, -hh * .2)
    o.under:SetWidth((tonumber(C.nameplates.width) or 120) * 1.5)
    o.under:SetHeight(hh * 5)
    o.under:SetVertexColor(r, g, b, a * .9)

    -- border skin
    local sk = SKINS[S.skin or "pfui"]
    for _, pair in ipairs({ { o.skinH, h }, { o.skinC, cb } }) do
      local f, bar = pair[1], pair[2]
      if sk then
        local off = sk.off + border
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", bar, "TOPLEFT", -off, off)
        f:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", off, -off)
        f:SetBackdrop({ edgeFile = sk.edge, edgeSize = sk.size, insets = { left = 0, right = 0, top = 0, bottom = 0 } })
        local c = sk.color
        if S.skincustom == "1" then
          c = { COL.skincolor[1], COL.skincolor[2], COL.skincolor[3], COL.skincolor[4] }
        elseif sk.accent and GetAccentColor then
          local ar, ag, ab = GetAccentColor()
          c = { ar, ag, ab, sk.color[4] }
        end
        f:SetBackdropBorderColor(c[1], c[2], c[3], c[4])
        f:Show()
      else
        f:Hide()
      end
    end

    -- parts you can switch off (they keep their place so the bar does not move)
    cb.icon:SetAlpha(S.casticon == "0" and 0 or 1)
    cb.text:SetAlpha(S.casttimer == "0" and 0 or 1)
    cb.spell:SetAlpha(S.castname == "0" and 0 or 1)
    local msz = (tonumber(S.marksize) or 0) > 0 and tonumber(S.marksize) or (namesize + 2)
    o.mark:SetWidth(msz)
    o.mark:SetHeight(msz)
    o.mark:ClearAllPoints()
    o.mark:SetPoint("RIGHT", plate.name, "LEFT", -2 + (tonumber(S.markoffx) or 0) - nx, (tonumber(S.markoffy) or 0) - ny)

    o.scale = nil
    if P.Lists then P.Lists.Configure(plate, o) end
    if P.Auras then P.Auras.Configure(plate, o) end
    P.Update(plate)
  end

  -- module switched off: our parts go, pfUI's own look stays (its config ran)
  function P.Off(plate)
    local o = plate.octo
    if not o then return end
    for _, region in ipairs({ o.hl, o.tick, o.left, o.right, o.under, o.glow, o.mark, o.spark, o.cend, o.skinH, o.skinC }) do region:Hide() end
    for i = 1, 4 do o.corners[i]:Hide() end
    if P.Auras then P.Auras.Off(o) end
    if P.Lists then P.Lists.Off(o) end
    if o.cp then for i = 1, 5 do o.cp[i]:Hide() end end
    if o.scale then
      plate:SetScale(UIParent:GetScale())
      o.scale, o.applied = nil, nil
    end
  end

  -- ---------------------------------------------------------------- combo points

  -- Our own combo points (user, 22 Oct 2026: pfUI's tiny squares are
  -- "pathetic"): orbs, gems, squares or segments of a bar, empty slots
  -- shown as rings, coloured by count / class / one colour, a glow at 5.
  local CPSTYLE = { orbs = "cp-orb", gems = "cp-gem", squares = "cp-square" }
  P.CPSTYLE = CPSTYLE
  local CPGRAD = { { 1, .95, .3 }, { 1, .8, .2 }, { 1, .6, .1 }, { 1, .4, .1 }, { 1, .2, .1 } }

  function P.ComboColor(i)
    if S.cpcolor == "class" then
      local _, class = UnitClass("player")
      local c = class and RAID_CLASS_COLORS[class]
      if c then return c.r, c.g, c.b end
    elseif S.cpcolor == "custom" then
      return COL.cpcustom[1], COL.cpcustom[2], COL.cpcustom[3]
    end
    local c = CPGRAD[i] or CPGRAD[5]
    return c[1], c[2], c[3]
  end

  local function ComboBuild(plate, o)
    o.cp = {}
    for i = 1, 5 do
      local f = CreateFrame("Frame", nil, plate)
      f:SetFrameLevel(plate.health:GetFrameLevel() + 3)
      f.glow = f:CreateTexture(nil, "BACKGROUND")
      f.glow:SetTexture(Art("cp-glow"))
      f.glow:SetBlendMode("ADD")
      f.glow:SetPoint("CENTER", f, "CENTER", 0, 0)
      f.tex = f:CreateTexture(nil, "ARTWORK")
      f.tex:SetAllPoints(f)
      f:Hide()
      o.cp[i] = f
    end
  end

  -- n points (nil = none); shown under the cast bar or the health bar
  function P.Combo(plate, o, n)
    if not o.cp then
      ComboBuild(plate, o)
      for i = 1, 5 do P.Hot(plate.parent, o.cp[i], "combo", 34) end
    end
    local style = S.cpstyle or "orbs"
    local on = C.nameplates.cpdisplay == "1" and style ~= "pfui" and S.enable == "1" and n and n > 0
    o.cpn = on and n or 0
    -- ours replace pfUI's little squares
    if style ~= "pfui" and plate.combopoints then
      for i = 1, 5 do plate.combopoints[i]:Hide() end
    end
    if not on then
      for i = 1, 5 do o.cp[i]:Hide() end
      return
    end
    local size, gap = tonumber(S.cpsize) or 12, tonumber(S.cpgap) or 3
    local h, cb = plate.health, plate.castbar
    -- under the health bar, clear of where a cast bar sits by default (moving
    -- the cast bar does not move them)
    local under = cb:IsShown() and -((tonumber(S.castheight) or 12) + 8) or -3
    local nx, ny = P.NameOff()
    local seg = style == "segments"
    local w = seg and ((h:GetWidth() - gap * 4) / 5) or size
    local ht = seg and math.max(3, math.floor(size / 3)) or size
    for i = 1, 5 do
      local f = o.cp[i]
      local lit = i <= n
      f:SetWidth(w)
      f:SetHeight(ht)
      f:ClearAllPoints()
      local x = (i - 3) * (w + gap) + (tonumber(S.cpoffx) or 0)
      local y = tonumber(S.cpoffy) or 0
      if S.cpplace == "above" then
        f:SetPoint("BOTTOM", plate.name, "TOP", x - nx, 2 + y - ny)
      elseif S.cpplace == "inside" then
        f:SetPoint("CENTER", h, "BOTTOM", x, y)
      else
        f:SetPoint("TOP", h, "BOTTOM", x, under + y)
      end
      if seg then
        f.tex:SetTexture(pfUI.media[S.bartexture ~= "" and S.bartexture or C.nameplates.healthtexture])
      else
        f.tex:SetTexture(Art(lit and CPSTYLE[style] or "cp-ring"))
      end
      local r, g, b = P.ComboColor(i)
      if lit then
        f.tex:SetVertexColor(r, g, b, 1)
      else
        f.tex:SetVertexColor(.5, .5, .5, seg and .35 or .6)
      end
      f.glow:SetWidth(w * 2.4)
      f.glow:SetHeight(ht * 2.4)
      f.glow:SetVertexColor(r, g, b, 1)
      f.glow:Hide()
      if lit or S.cpempty == "1" then f:Show() else f:Hide() end
    end
  end

  -- at 5 points the glows pulse
  function P.ComboTick(o, now)
    if not o.cp or (o.cpn or 0) < 5 or S.cpglow ~= "1" then
      if o.cp and o.cpglowing then
        for i = 1, 5 do o.cp[i].glow:Hide() end
        o.cpglowing = nil
      end
      return
    end
    local a = .45 + .4 * math.sin(now * 6)
    for i = 1, 5 do
      o.cp[i].glow:SetAlpha(a)
      o.cp[i].glow:Show()
    end
    o.cpglowing = true
  end

  -- the art you can pick for any mark (user, 22 Oct 2026: "different elite
  -- markers and different quest icons all should have art options")
  P.MARKART = {
    { key = "star", label = "Star", art = "star" }, { key = "crown", label = "Crown", art = "mark-crown" },
    { key = "sparkle", label = "Sparkle", art = "mark-sparkle" }, { key = "shield", label = "Shield", art = "mark-shield" },
    { key = "hex", label = "Hexagon", art = "mark-hex" }, { key = "gem", label = "Gem", art = "cp-gem" },
    { key = "orb", label = "Orb", art = "cp-orb" }, { key = "skull", label = "Skull", art = "skull" },
    { key = "diamond", label = "Diamond !", art = "quest-objective" }, { key = "circle", label = "Circle !", art = "quest-circle" },
    { key = "bang", label = "!", art = "quest-start" }, { key = "ask", label = "?", art = "quest-end" },
    { key = "circleask", label = "Circle ?", art = "quest-circle-ask" },
    -- 3D chrome crests (5 Nov 2026, tools\MakeMarkArt.ps1): wide, tinted by the mark's colour
    { key = "crest-wings", label = "3D winged gem", art = "crest-wings", wide = true },
    { key = "crest-star", label = "3D star", art = "crest-star", wide = true },
    { key = "crest-shield", label = "3D shield", art = "crest-shield", wide = true },
    { key = "crest-skull", label = "3D skull", art = "crest-skull", wide = true },
    { key = "crest-crown", label = "3D crown", art = "crest-crown", wide = true },
    { key = "none", label = "None" },
  }
  local MARKBY = {}
  P.MARKWIDE = {}
  for _, m in ipairs(P.MARKART) do MARKBY[m.key] = m.art P.MARKWIDE[m.key] = m.wide end
  function P.MarkArt(key) return MARKBY[key or ""] and Art(MARKBY[key]) end
  -- unit kind -> its style and colour settings
  local MARKS = {
    elite = { "markelite", "elitecolor" }, rareelite = { "markrareelite", "rarecolor" }, rare = { "markrare", "rarecolor" },
    worldboss = { "markboss", "bosscolor" }, boss = { "markboss", "bosscolor" },
  }

  -- everything that changes with the unit (runs after pfUI's own update)
  function P.Update(plate)
    local o = plate and plate.octo
    if not o or S.enable ~= "1" or not plate:IsVisible() then return end
    local h = plate.health
    local unit = UnitOf(plate)
    local istarget = plate.istarget
    o.unit = unit
    o.kind = P.Kind(plate)
    local enemy = o.kind == "enemynpc" or o.kind == "enemyplayer"
    local shown = h:IsShown()

    -- bar colour: execute, then threat, else pfUI's
    local hp = h:GetValue() or 0
    local _, maxhp = h:GetMinMaxValues()
    maxhp = maxhp or 0
    local pct = maxhp > 0 and hp / maxhp * 100 or 100
    local ex = enemy and P.ExecutePct()
    local col
    if ex and pct > 0 and pct <= ex then col = COL.executecolor end
    local state = (S.threat == "1" and enemy) and P.ThreatState(unit, istarget) or nil
    local pv = plate.parent and plate.parent.preview
    if pv then
      state = S.threat == "1" and pv.state or nil
    elseif P.Testing() and enemy and S.threat == "1" then
      state = P.TestState(o)
    end
    o.state = state
    if P.Lists then o.quest = P.Lists.QuestFor(plate) end
    if not col then
      col = P.ThreatColor(state)
      -- NPC colours (threat wins unless set otherwise), then quest units
      if P.Lists then col = P.Lists.QuestColor(o, P.Lists.BarColor(plate, state, col)) end
    end
    if col then
      h:SetStatusBarColor(col[1], col[2], col[3], col[4])
      plate.cache.r, plate.cache.g, plate.cache.b = col[1], col[2], col[3]
    end

    -- your own border colour on the bars (pfUI's target / combat state colours otherwise)
    if S.bordercustom == "1" then
      local bc = COL.bordercolor
      if h.backdrop then h.backdrop:SetBackdropBorderColor(bc[1], bc[2], bc[3], bc[4]) end
      if plate.castbar.backdrop then plate.castbar.backdrop:SetBackdropBorderColor(bc[1], bc[2], bc[3], bc[4]) end
    end

    -- execute marker
    if ex and S.executemark == "1" and pct > ex and shown and C.nameplates.verticalhealth ~= "1" then
      o.tick:ClearAllPoints()
      o.tick:SetPoint("CENTER", h, "LEFT", h:GetWidth() * ex / 100, 0)
      o.tick:SetHeight(h:GetHeight() + 2)
      o.tick:Show()
    else
      o.tick:Hide()
    end

    -- aggro glow
    if S.aggroglow == "1" and shown and P.Alarming(state) then
      local c = P.ThreatColor(state) or COL.c_aggro
      o.glow:SetBackdropBorderColor(c[1], c[2], c[3], 1)
      o.glow:Show()
    else
      o.glow:Hide()
    end

    -- target indicator
    local ind = istarget and shown and S.indicator or "none"
    if ind == "arrows" or ind == "chevrons" then
      -- left of where the level text sits by default, whatever its width
      o.left:ClearAllPoints()
      o.left:SetPoint("RIGHT", h, "LEFT", -6 - (plate.level:GetStringWidth() or 12) - (o.tgap or 0), 0)
    end
    Vis(o.left, ind == "arrows" or ind == "chevrons")
    Vis(o.right, ind == "arrows" or ind == "chevrons")
    for i = 1, 4 do Vis(o.corners[i], ind == "corners") end
    Vis(o.under, ind == "underglow")

    -- elite / rare / boss mark
    local mark
    if S.eliteicon == "1" and plate.name:IsShown() then
      local cls = unit and UnitClassification and UnitClassification(unit)
      if not cls or cls == "normal" then
        local _, _, elite = GetUnitData(plate.original.name:GetText(), true)
        cls = elite
      end
      if plate.original.levelicon and plate.original.levelicon:IsShown() then cls = "worldboss" end
      if pv then cls = pv.class end
      mark = cls and MARKS[cls]
    end
    local tex = mark and P.MarkArt(S[mark[1]])
    if tex then
      local c = COL[mark[2]]
      o.mark:SetTexture(tex)
      -- (a 3D crest is twice as wide as tall)
      local mh = o.mark:GetHeight() or 0
      if mh > 0 then o.mark:SetWidth(P.MARKWIDE[S[mark[1]] or ""] and mh * 2 or mh) end
      o.mark:SetVertexColor(c[1], c[2], c[3], c[4])
      o.mark:Show()
    else
      o.mark:Hide()
    end

    -- combo points: yours on your target (the preview and the test act them out)
    local cp
    if pv then cp = pv.cp
    elseif P.Testing() and enemy then cp = math.mod(math.floor(GetTime() / .7), 6)
    elseif istarget and GetComboPoints then cp = GetComboPoints("target") end
    P.Combo(plate, o, cp)

    if P.Lists then P.Lists.Update(plate, o, unit, enemy) end
    if P.Auras then P.Auras.Update(plate, o, unit, enemy) end
  end

  -- ---------------------------------------------------------------- every frame

  function P.CastEnd(plate, o, done, now)
    if S.castend ~= "1" then return end
    local unit = o.unit
    -- still casting: the bar was hidden for another reason (target-only bars)
    if unit and ((UnitCastingInfo and UnitCastingInfo(unit)) or (UnitChannelInfo and UnitChannelInfo(unit))) then return end
    local c = done and COL.c_done or COL.c_stopped
    o.cend:SetStatusBarColor(c[1], c[2], c[3], c[4])
    o.cend:SetValue(1)
    o.cendAt, o.cendDone, o.kicked = now, done, nil
    o.victim = plate.original.name:GetText()
    o.cend.text:SetText(done and "" or T["Interrupted"])
    if not done then P.Kicker(o) end
    o.cend:SetAlpha(1)
    o.cend:Show()
  end

  -- "Interrupted by NAME" once the combat log names who did it
  function P.Kicker(o)
    local k = o.victim and kicks[o.victim]
    if k and o.cendAt and math.abs(k.at - o.cendAt) < 1 then
      o.kicked = true
      if S.kicker == "1" then o.cend.text:SetText(string.format(T["Interrupted by %s"], k.by)) end
    end
  end

  function P.TickCast(plate, o, now)
    local cb = plate.castbar
    if cb:IsShown() then
      local _, max = cb:GetMinMaxValues()
      local v = cb:GetValue() or 0
      max = max or 0
      -- a new cast: its name and whether it is channelled
      if not o.casting or max ~= o.castmax then
        o.casting, o.castmax, o.channel, o.castname = true, max, nil, nil
        local unit = o.unit
        local name = plate.original.name:GetText()
        local spell
        for _, who in ipairs({ unit or false, name or false }) do
          if who and not spell then
            spell = UnitCastingInfo and UnitCastingInfo(who)
            if not spell and UnitChannelInfo then
              spell = UnitChannelInfo(who)
              if spell then o.channel = true end
            end
          end
        end
        o.castname = spell
        -- cast colours and new names (phase 3)
        local ce = P.Lists and P.Lists.CastEntry(spell or cb.spell:GetText())
        o.castcol, o.castrename = ce and ce.color, ce and ce.rename
      end
      o.castv = v
      local c = o.castcol or (o.channel and COL.c_channel or COL.c_cast)
      cb:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
      if o.castrename then cb.spell:SetText(o.castrename)
      elseif S.castlayout == "plater" and o.castname then cb.spell:SetText(o.castname) end
      if S.spark == "1" and max > 0 then
        o.spark:ClearAllPoints()
        o.spark:SetPoint("CENTER", cb, "LEFT", cb:GetWidth() * math.min(1, math.max(0, v / max)), 0)
        o.spark:Show()
      else
        o.spark:Hide()
      end
      o.cend:Hide()
    elseif o.casting then
      -- it ended: done when it reached its end, else stopped
      o.casting = nil
      o.spark:Hide()
      local done
      if o.channel then done = (o.castv or 1) <= .3 else done = (o.castv or 0) >= (o.castmax or 0) - .3 end
      P.CastEnd(plate, o, done, now)
    end

    if o.cend:IsShown() then
      if not o.cendDone and not o.kicked then P.Kicker(o) end
      local left = 1 - (now - (o.cendAt or 0)) / (o.cendDone and .35 or 1.2)
      if left <= 0 then o.cend:Hide() else o.cend:SetAlpha(math.min(1, left * 1.5)) end
    end
  end

  function P.Tick(plate)
    local o = plate and plate.octo
    if not o or S.enable ~= "1" then return end
    local now = GetTime()
    local dt = now - (o.last or now)
    o.last = now
    local istarget = plate.istarget
    local pv = plate.parent and plate.parent.preview
    local fighting = UnitAffectingCombat("player")
    if pv then fighting = pv.combat end

    -- size: kind, out of combat, target - eased
    local want = (tonumber(S["size_" .. (o.kind or "enemynpc")]) or 100) / 100
    if not fighting then want = want * (tonumber(S.size_ooc) or 100) / 100 end
    if istarget then want = want * (tonumber(S.size_target) or 100) / 100 end
    if not o.scale then o.scale = want end
    if o.scale ~= want then
      o.scale = o.scale + (want - o.scale) * math.min(1, dt * 12)
      if math.abs(want - o.scale) < .005 then o.scale = want end
    end
    -- (phase 4: animations and rules can make it bigger or smaller for a moment)
    local mul = P.Fx and P.Fx.Scale(plate, o, now) or 1
    local final = o.scale * mul
    if o.applied ~= final then
      -- a preview plate sits in the options window, already at the UI's scale
      plate:SetScale((pv and 1 or UIParent:GetScale()) * final)
      o.applied = final
    end

    -- range / line of sight: fade (after pfUI's non-target alpha)
    if S.range == "1" and UnitXP and o.unit and o.unit ~= "target" then
      if now >= (o.rangeAt or 0) then
        o.rangeAt = now + .2
        local ok, d = pcall(UnitXP, "distanceBetween", "player", o.unit)
        o.far = (ok and type(d) == "number" and d > (tonumber(S.rangeyards) or 40)) or nil
        o.unseen = nil
        if S.los == "1" then
          local ok2, seen = pcall(UnitXP, "inSight", "player", o.unit)
          o.unseen = (ok2 and seen == false) or nil
        end
      end
      if (o.far or o.unseen) and not istarget then
        plate:SetAlpha(plate:GetAlpha() * (tonumber(S.rangealpha) or .4))
      end
    end

    Vis(o.hl, S.mouseover == "1" and plate.cache.mouseover and plate.health:IsShown())
    -- the level's place (pfUI puts it back on every update)
    if plate.health:IsShown() and ((tonumber(S.leveloffx) or 0) ~= 0 or (tonumber(S.leveloffy) or 0) ~= 0) then
      plate.level:ClearAllPoints()
      plate.level:SetPoint("RIGHT", plate.health, "LEFT", -5 + (tonumber(S.leveloffx) or 0), tonumber(S.leveloffy) or 0)
    end
    -- name / level shown or not (see-through, so the bar under them stays put)
    plate.name:SetAlpha(S.nameshow == "0" and 0 or 1)
    plate.level:SetAlpha(S.levelshow == "0" and 0 or 1)
    -- name / level colours picked by you (pfUI recolours them as units change)
    if S.namecustom == "1" then
      local c = COL.namecolor
      plate.name:SetTextColor(c[1], c[2], c[3], c[4])
    end
    if S.levelcustom == "1" then
      local c = COL.levelcolor
      plate.level:SetTextColor(c[1], c[2], c[3], c[4])
    end
    -- the test leaves friendly plates alone (quest givers casting Fireball confused)
    local enemy = o.kind == "enemynpc" or o.kind == "enemyplayer"
    if (pv and pv.cast) or (not pv and enemy and P.Testing() and S.enable == "1") then P.FakeCast(plate, o, now) end
    P.TickCast(plate, o, now)
    if P.Auras then P.Auras.Tick(plate, o, now) end
    P.ComboTick(o, now)
    if P.Fx then P.Fx.Tick(plate, o, now) end
    -- something on it moves: keep it on every frame (P.Calm)
    o.busy = o.scale ~= want or o.anim or o.casting or o.cend:IsShown() or o.cpglowing
      or plate.health.zoomed or plate.health.zoomTransition or nil
  end

  -- ---------------------------------------------------------------- test mode and preview

  -- "Test on real nameplates": for a while every plate on screen gets
  -- pretend threat states and casts (one in two is interrupted by "Bob")
  P.testUntil = 0
  function P.Testing() return GetTime() < (P.testUntil or 0) end
  function P.Test(seconds)
    P.testUntil = (seconds and seconds > 0) and (GetTime() + seconds) or 0
  end

  local TESTSTATES = { dps = { "aggro", "pulling", "safe" }, tank = { "aggro", "losing", "offtank", "taking", "lost" } }
  P.TESTSTATES = TESTSTATES
  local testCount = 0
  function P.TestState(o)
    if not o.testi then testCount = testCount + 1 o.testi = testCount end
    local list = TESTSTATES[P.Role()]
    return list[math.mod(math.floor(GetTime() / 3) + o.testi, table.getn(list)) + 1]
  end

  -- a pretend cast: 2.5 s, every other one stopped at 1.5 s by Bob
  local FAKE = { "Fireball", "Interface\\Icons\\Spell_Fire_FlameBolt" }
  function P.FakeCast(plate, o, now)
    if not o.testi then testCount = testCount + 1 o.testi = testCount end
    local cb = plate.castbar
    -- a 2.5 s cast every 3 s (a short gap, so the bar is easy to click in the preview)
    local t = now + o.testi * 1.3
    local k = math.floor(t / 3)
    t = t - k * 3
    local kicked = math.mod(k, 2) == 1
    if t < 2.5 and not (kicked and t >= 1.5) then
      cb:SetMinMaxValues(0, 2.5)
      cb:SetValue(t)
      cb.text:SetText(string.format("%.1f", 2.5 - t))
      cb.spell:SetText(FAKE[1])
      cb.icon.tex:SetTexture(FAKE[2])
      cb.icon.tex:SetTexCoord(.1, .9, .1, .9)
      cb:Show()
      o.castname = FAKE[1]
    else
      if kicked and o.casting then
        local victim = plate.original.name:GetText()
        if victim then kicks[victim] = { by = "Bob", spell = FAKE[1], at = now } end
      end
      cb:Hide()
    end
  end

  P.previews = {}

  -- Sample plates in an options box, drawn by pfUI's real nameplate code and
  -- ours: your target casting, a mob going through the threat colours, one in
  -- execute range and a friendly player. They follow every setting at once.
  local SAMPLES = {
    { name = "Defias Pillager", level = "17", hp = 80, color = { 1, 0, 0 }, target = true, class = "elite", state = "aggro",
      cast = true, auras = "all", caption = "your target - elite - casting" },
    { name = "Defias Thug", level = "16", hp = 55, color = { 1, 0, 0 }, cycle = true, auras = "few", ghost = true,
      raidmark = true, far = true },
    { name = "Defias Watchman", level = "16", hp = 15, color = { 1, 0, 0 }, state = "safe", quest = "objective", class = "rare",
      caption = "rare - quest mob - execute range" },
    { name = "Healbot", level = "60", hp = 100, color = { 0, 0, 1 }, caption = "friendly player", guild = "Octo Raiders", hover = true },
  }
  local STATEWORDS = { aggro = "on you", pulling = "you are pulling it", safe = "on someone else",
    losing = "someone is pulling it", offtank = "on another tank", lost = "loose on someone else",
    taking = "you are taking it from a tank" }

  -- What pfUI only shows for a real target / mouse-over / guild, acted out on
  -- the samples so every setting can be seen: combo points rolling 0-5 on the
  -- target, a skull raid mark, a guild name, the mouse-over light, target zoom.
  function P.Show(plate, pv)
    local d = pv.data
    local now = GetTime()
    if pv.target then
      local n = math.mod(math.floor(now / .7), 6)
      pv.cp = n
      if S.cpstyle == "pfui" then
        for i = 1, 5 do
          if C.nameplates.cpdisplay == "1" and i <= n then plate.combopoints[i]:Show() else plate.combopoints[i]:Hide() end
        end
      elseif plate.octo then
        P.Combo(plate, plate.octo, n)
      end
      local w, h = tonumber(C.nameplates.width) or 120, tonumber(C.nameplates.heighthealth) or 8
      if C.nameplates.targetzoom == "1" then
        local z = (tonumber(C.nameplates.targetzoomval) or .4) + 1
        w, h = w * z, h * z * .9
      end
      plate.health:SetWidth(w)
      plate.health:SetHeight(h)
    end
    if d.raidmark then
      plate.raidicon:SetTexCoord(.75, 1, .25, .5)
      plate.raidicon:Show()
    end
    if d.guild then
      if C.nameplates.showguildname == "1" then
        plate.guild:SetText(d.guild)
        plate.guild:SetTextColor(0, .9, 0, 1)
        plate.guild:Show()
      else
        plate.guild:Hide()
      end
    end
    if d.hover then plate.cache.mouseover = math.mod(math.floor(now / 2), 2) == 0 or nil end
  end

  -- Clickable parts of the samples (user, 22 Oct 2026: "EVERY PIECE can be
  -- clicked on, this will take you straight to that menu of options"). A
  -- see-through button over the part; P.OnPreviewClick(what) is set by the
  -- options. Parts made later (combo points, aura icons) get theirs then.
  P.HOTLABEL = { name = "Name and text", level = "Level", health = "Health bar", hptext = "Health text",
    threat = "Threat colours", cast = "Cast bar", combo = "Combo points", auras = "Auras", special = "Special auras",
    target = "Target marker", elite = "Elite, rare and boss marks", quest = "Quest marks", raid = "Raid mark",
    icons = "Class and pet icons", guild = "Name and text" }
  -- what can be dragged, and its x / y settings (pf = pfUI's own keys)
  P.DRAG = {
    cast = { "castoffx", "castoffy" }, combo = { "cpoffx", "cpoffy" },
    auras = { "auraoffx", "auraoffset" }, special = { "specialoffx", "specialoffy" },
    raid = { "raidiconoffx", "raidiconoffy", pf = true },
    name = { "nameoffx", "nameoffy" }, level = { "leveloffx", "leveloffy" }, hptext = { "hpoffx", "hpoffy" },
    elite = { "markoffx", "markoffy" }, quest = { "questoffx", "questoffy" }, icons = { "ciconoffx", "ciconoffy" },
    target = { "targetgap" },
  }
  -- what the mouse wheel makes bigger / smaller (pf = pfUI's own keys)
  P.SIZE = {
    name = { "namesize" }, level = { "namesize" }, guild = { "namesize" }, hptext = { "hpsize" },
    cast = { "castheight" }, combo = { "cpsize" }, auras = { "aurawidth", "auraheight" }, special = { "specialsize" },
    elite = { "marksize" }, quest = { "questsize" }, icons = { "ciconsize" }, target = { "targetsize" },
    raid = { "raidiconsize", pf = true }, health = { "heighthealth", pf = true }, threat = { "heighthealth", pf = true },
  }
  -- what right-click puts back
  P.PUTBACK = {
    namesize = "0", hpsize = "0", castheight = "12", cpsize = "12", aurawidth = "20", auraheight = "16",
    specialsize = "32", marksize = "0", questsize = "0", ciconsize = "0", targetsize = "0", auraoffset = "2",
    raidiconsize = "16", heighthealth = "12", raidiconoffy = "-5",
  }
  function P.Hot(game, region, what, level)
    if not region or not game or not game.preview then return end
    region.hots = region.hots or {}
    if region.hots[game] then return end
    local b = CreateFrame("Button", nil, game)
    b:SetFrameLevel((game:GetFrameLevel() or 1) + (level or 30))
    b:SetAllPoints(region)
    b.region, b.what = region, what
    b.hl = b:CreateTexture(nil, "OVERLAY")
    b.hl:SetAllPoints(b)
    b.hl:SetTexture("Interface\\Buttons\\WHITE8X8")
    local ar, ag, ab = 1, 1, 1
    if GetAccentColor then ar, ag, ab = GetAccentColor() end
    b.hl:SetVertexColor(ar, ag, ab, .25)
    b.hl:Hide()
    -- (the cast bar comes and goes: its spot answers even between casts)
    b.always = what == "cast"
    b:SetScript("OnEnter", function()
      if not this.region:IsVisible() and not this.always then return end
      this.hl:Show()
      GameTooltip:SetOwner(this, "ANCHOR_TOP")
      GameTooltip:AddLine(P.HOTLABEL[this.what] or this.what)
      GameTooltip:AddLine("Click: its options", 1, 1, 1)
      if P.DRAG[this.what] then GameTooltip:AddLine("Drag: move it", 1, 1, 1) end
      if P.SIZE[this.what] then GameTooltip:AddLine("Shift + mouse wheel: bigger / smaller", 1, 1, 1) end
      GameTooltip:AddLine("Right-click: put it back", 1, 1, 1)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function()
      this.hl:Hide()
      GameTooltip:Hide()
    end)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function()
      -- a drag is not a click
      if this.dragged then this.dragged = nil return end
      if not this.region:IsVisible() and not this.always then return end
      if arg1 == "RightButton" then
        P.PutBack(this.what)
      elseif P.OnPreviewClick then
        P.OnPreviewClick(this.what)
      end
    end)
    -- Shift + mouse wheel makes the part bigger or smaller; the plain wheel
    -- still scrolls the page (user, 22 Oct 2026: the wheel only scrolled)
    b:EnableMouseWheel(true)
    b:SetScript("OnMouseWheel", function()
      if IsShiftKeyDown() and P.SIZE[this.what] and this.region:IsVisible() then
        P.Resize(this.what, arg1 or 0, this.region)
      else
        P.PassWheel(this)
      end
    end)
    -- (user, 22 Oct 2026: "you should be able to drag features") parts with a
    -- place of their own move with the mouse; the setting follows
    local drag = P.DRAG[what]
    if drag then
      b:SetScript("OnMouseDown", function()
        local cx, cy = GetCursorPosition()
        local t = drag.pf and C.nameplates or S
        this.down = { cx, cy, tonumber(t[drag[1]]) or 0, drag[2] and tonumber(t[drag[2]]) or 0 }
        -- How far the part may go: measured once now (positions read while
        -- moving come a frame late), from all its pieces and the box. A part
        -- already outside may still come back in.
        this.lim = P.Limits(game, this.what)
        this.dragged = nil
        this:SetScript("OnUpdate", function()
          local d = this.down
          if not d then return end
          local x, y = GetCursorPosition()
          local s = this:GetEffectiveScale() or 1
          local dx, dy = math.floor((x - d[1]) / s + .5), math.floor((y - d[2]) / s + .5)
          if not this.dragged and math.abs(dx) + math.abs(dy) < 3 then return end
          if not this.dragged then P.Front(game, this.region, this.what) end
          this.dragged = true
          -- it stops at the edge of the preview box
          local lim = this.lim
          if lim then
            dx = math.max(lim[1], math.min(lim[2], dx))
            dy = math.max(lim[3], math.min(lim[4], dy))
          end
          local t = drag.pf and C.nameplates or S
          local ox, oy = t[drag[1]], drag[2] and t[drag[2]]
          t[drag[1]] = tostring(d[3] + dx)
          if drag[2] then t[drag[2]] = tostring(d[4] + dy) end
          if t[drag[1]] == ox and (not drag[2] or t[drag[2]] == oy) then return end
          P.Refresh()
        end)
      end)
      b:SetScript("OnMouseUp", function()
        this.down = nil
        this:SetScript("OnUpdate", nil)
        if this.dragged then P.Refresh() end
      end)
    end
    region.hots[game] = b
    game.hotlist = game.hotlist or {}
    table.insert(game.hotlist, b)
    P.FitSpot(b)
    return b
  end

  -- A text's spot is as big as its words, not the whole box the text sits in
  -- (user, 23 Oct 2026: the health text's spot covered the whole bar, so the
  -- bar was hard to pick or resize). Run again when the text changes.
  function P.FitSpot(b)
    local r = b.region
    if not (r.IsObjectType and r:IsObjectType("FontString")) then return end
    local w = math.floor((r:GetStringWidth() or 0) + 6)
    local _, size = r:GetFont()
    local h = math.floor((tonumber(size) or 10) + 4)
    local j = r.GetJustifyH and r:GetJustifyH() or "CENTER"
    local key = w .. ":" .. h .. ":" .. tostring(j)
    if b.fit == key then return end
    b.fit = key
    b:ClearAllPoints()
    b:SetWidth(math.max(w, 10))
    b:SetHeight(h)
    if j == "LEFT" then
      b:SetPoint("LEFT", r, "LEFT", -3, 0)
    elseif j == "RIGHT" then
      b:SetPoint("RIGHT", r, "RIGHT", 3, 0)
    else
      b:SetPoint("CENTER", r, "CENTER", 0, 0)
    end
  end

  -- How far all visible pieces of a part may move and stay in the preview
  -- box: { min dx, max dx, min dy, max dy } (0 where it is already outside,
  -- so it can only come back in).
  -- (limits are the sample's column inside the box, in the part's own units)
  function P.Limits(game, what)
    local l, r, t, b = P.Column(game)
    local ul, ur, ut, ub = P.Extent(game, what)
    if not l or not ul then return end
    local k = game:GetEffectiveScale() or 1
    return { math.min(0, l - ul) / k, math.max(0, r - ur) / k, math.min(0, b - ub) / k, math.max(0, t - ut) / k }
  end

  -- the part under the mouse in a preview box (Shift + wheel on the box)
  function P.HotUnderMouse(samples)
    local best
    for _, game in ipairs(samples or {}) do
      for _, b in ipairs(game.hotlist or {}) do
        if b.region:IsVisible() and MouseIsOver(b) and (not best or b:GetFrameLevel() > best:GetFrameLevel()) then best = b end
      end
    end
    return best
  end

  -- the part being dragged comes to the front (and stays there), with the
  -- pieces that belong to it
  local function Lift(f, level)
    f:SetFrameLevel(level)
    for _, kid in ipairs({ f:GetChildren() }) do Lift(kid, level + 1) end
  end
  function P.Front(game, region, what)
    local pl, o = game.nameplate, game.nameplate.octo
    local list
    if what == "combo" then list = o.cp
    elseif what == "auras" then list = o.aicons
    elseif what == "special" then list = o.bicons
    elseif what == "cast" then list = { pl.castbar, o.cend }
    elseif region.GetChildren then list = { region } end
    P.frontLevel = (P.frontLevel or 12) + 1
    if P.frontLevel > 26 then P.frontLevel = 13 end
    for _, f in ipairs(list or {}) do Lift(f, game:GetFrameLevel() + P.frontLevel) end
  end

  -- hands the wheel to the nearest frame above that scrolls (the page)
  function P.PassWheel(from)
    local f = from:GetParent()
    while f and not (f.GetScript and f:GetScript("OnMouseWheel")) do f = f:GetParent() end
    if not f then return end
    -- the game's own `this` (_G): a plain `this = f` in pfUI's environment
    -- made a pfUI-only `this` that hid the real one from every pfUI script
    -- afterwards (errors all over, a blank options page - 22 Oct 2026)
    local old = _G.this
    _G.this = f
    f:GetScript("OnMouseWheel")()
    _G.this = old
  end

  -- one step of the mouse wheel on a part: its size settings go up / down
  -- a pixel ("0" = automatic starts from the size it has now)
  function P.Resize(what, step, region)
    local keys = P.SIZE[what]
    if not keys then return end
    local t = keys.pf and C.nameplates or S
    local was = {}
    -- growing stops a few pixels before the box's edge (measured before the
    -- change: positions read after it come a frame late)
    local host = region and region.hots and next(region.hots)
    if step > 0 and host then
      local lim = P.Limits(host, what)
      if lim and (lim[1] > -3 or lim[2] < 3 or lim[3] > -3 or lim[4] < 3) then return end
    end
    for _, k in ipairs(keys) do
      was[k] = t[k]
      local cur = tonumber(t[k]) or 0
      if cur <= 0 and region then cur = math.floor((region:GetHeight() or 10) + .5) end
      t[k] = tostring(math.max(2, math.min(80, cur + step)))
    end
    P.Refresh()
  end

  -- right-click on a part: its place and size go back to the first ones
  function P.PutBack(what)
    for _, set in ipairs({ P.DRAG[what], P.SIZE[what] }) do
      local t = set and set.pf and C.nameplates or S
      for _, k in ipairs(set or {}) do t[k] = P.PUTBACK[k] or "0" end
    end
    P.Refresh()
  end

  local function SamplePlate(box, d)
    local game = CreateFrame("Button", nil, box)
    -- pfUI builds a plate on low frame levels (bar 4, its dark backdrop 3).
    -- In the options window those sit under the window and the backdrop
    -- covered the fill; a layer of its own above the window (menus and
    -- tooltips stay on top) lets every part keep pfUI's own levels.
    -- Children made later take this layer too.
    game:SetFrameStrata("FULLSCREEN")
    game:SetFrameLevel(1)
    game:SetWidth(150)
    game:SetHeight(60)
    local hb = CreateFrame("StatusBar", nil, game)
    CreateFrame("StatusBar", nil, game)
    hb:SetMinMaxValues(0, 100)
    hb:SetValue(d.hp)
    hb:SetStatusBarColor(d.color[1], d.color[2], d.color[3], 1)
    local regions, ordered = {}, {}
    for _, k in ipairs(NAMEPLATE_OBJECTORDER) do
      local r
      if k == "name" or k == "level" then
        r = game:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      else
        r = game:CreateTexture(nil, "OVERLAY")
      end
      regions[k] = r
      table.insert(ordered, r)
    end
    -- in the game's order, as a real plate gives them
    game.GetRegions = function() return unpack(ordered) end
    regions.name:SetText(d.name)
    regions.level:SetText(d.level)
    regions.name:SetTextColor(1, 1, 1)
    regions.level:SetTextColor(.7, .7, .3)
    regions.levelicon:Hide()
    regions.raidicon:Hide()
    regions.glow:Hide()
    game.preview = { state = d.state, target = d.target, class = d.class, cast = d.cast, combat = true, ghost = d.ghost,
      quest = d.quest, data = d }
    NP.OnCreate(game)
    -- every part can be clicked to open its options
    local pl = game.nameplate
    local po = pl.octo
    P.Hot(game, pl.health, d.cycle and "threat" or "health", 30)
    P.Hot(game, pl.health.text, "hptext", 31)
    P.Hot(game, pl.name, "name", 32)
    P.Hot(game, pl.level, "level", 32)
    P.Hot(game, pl.guild, "guild", 32)
    P.Hot(game, pl.castbar, "cast", 30)
    P.Hot(game, pl.raidicon, "raid", 33)
    if po then
      P.Hot(game, po.cend, "cast", 31)
      P.Hot(game, po.left, "target", 33)
      P.Hot(game, po.right, "target", 33)
      for i = 1, 4 do P.Hot(game, po.corners[i], "target", 33) end
      P.Hot(game, po.mark, "elite", 33)
      if po.qmark then P.Hot(game, po.qmark, "quest", 33) end
      if po.cicon then P.Hot(game, po.cicon, "icons", 33) end
    end
    -- pfUI's own every-frame code needs the real target and casts: the sample
    -- runs its own instead
    game:SetScript("OnUpdate", function()
      local plate = this.nameplate
      local pv = this.preview
      if pv.data.cycle then
        local list = TESTSTATES[P.Role()]
        pv.state = list[math.mod(math.floor(GetTime() / 2.5), table.getn(list)) + 1]
      end
      plate.istarget = pv.target
      if (this.tick or 0) < GetTime() then
        this.tick = GetTime() + .2
        if pv.data.auras and P.Auras then
          local all = P.Auras.TestAuras()
          pv.auras = (pv.data.auras == "few") and { all[1] } or all
        end
        NP:OnDataChanged(plate)
        for _, h in ipairs(this.hotlist or {}) do P.FitSpot(h) end
        if this.caption then
          local word = pv.data.caption or ("mob " .. (STATEWORDS[pv.state] or ""))
          if pv.data.cycle and S.threat ~= "1" then word = "threat colours are off" end
          if pv.data.raidmark then word = word .. " - skull raid mark" end
          if pv.data.hp < 20 and not P.ExecutePct() then word = string.gsub(word, "execute range", "low health") end
          if pv.away then word = word .. ", out of range" end
          this.caption:SetText(word)
        end
      end
      -- (the preview keeps every sample easy to see: the fade for plates you
      -- have not targeted shows, but never darker than 3 in 4 - user, 26 Oct
      -- 2026: "nameplates DARK TOO")
      plate:SetAlpha((pv.target or not pv.anyTarget) and 1 or math.max(.75, tonumber(C.nameplates.notargalpha) or 1))
      P.Show(plate, pv)
      P.Tick(plate)
      -- range fade: the thug walks out of range every other few seconds
      if pv.data.far and S.range == "1" and math.mod(math.floor(GetTime() / 3), 2) == 1 then
        plate:SetAlpha(math.max(.6, plate:GetAlpha() * (tonumber(S.rangealpha) or .4)))
        pv.away = true
      else
        pv.away = nil
      end
    end)
    return game
  end

  -- the samples are shown this much bigger than in the game (they shrink
  -- only when something does not fit their cell)
  P.ZOOM = 1.15

  -- Faint grid lines over the box, each sample's cell outlined, and a yellow
  -- middle line across and down every cell to line plates up against
  -- (user, 22 Oct 2026). C.plates.previewgrid.
  local function Grid(box, cells)
    local g = CreateFrame("Frame", nil, box)
    g:SetAllPoints(box)
    g.lines = {}
    local function Line(x, y, w, h, r, gg, b, a)
      local t = g:CreateTexture(nil, "BACKGROUND")
      t:SetTexture("Interface\\Buttons\\WHITE8X8")
      t:SetVertexColor(r, gg, b, a)
      t:SetPoint("TOPLEFT", box, "TOPLEFT", x, -y)
      t:SetWidth(w)
      t:SetHeight(h)
      table.insert(g.lines, t)
    end
    local W, H = box:GetWidth() or 640, box:GetHeight() or 320
    for x = 20, W - 1, 20 do Line(x, 0, 1, H, 1, 1, 1, .05) end
    for y = 20, H - 1, 20 do Line(0, y, W, 1, 1, 1, 1, .05) end
    for _, c in ipairs(cells) do
      Line(c[1], c[2], c[3], 1, 1, 1, 1, .14)
      Line(c[1], c[2] + c[4] - 1, c[3], 1, 1, 1, 1, .14)
      Line(c[1], c[2], 1, c[4], 1, 1, 1, .14)
      Line(c[1] + c[3] - 1, c[2], 1, c[4], 1, 1, 1, .14)
      Line(c[1] + 6, c[2] + c[4] * .62, c[3] - 12, 1, 1, .82, 0, .45)
      Line(c[1] + c[3] / 2, c[2] + 6, 1, c[4] - 12, 1, .82, 0, .45)
    end
    function g.Apply()
      if S.previewgrid == "0" then g:Hide() else g:Show() end
    end
    g.Apply()
    return g
  end

  function P.AttachPreview(box)
    local list = {}
    local n = table.getn(SAMPLES)
    -- one row of four in a wide box (compact: the options below keep their
    -- room), two by two in a narrow one
    local W, H = box:GetWidth() or 640, box:GetHeight() or 320
    local cols = (W >= 700) and n or 2
    local cw, ch = W / cols, H / math.ceil(n / cols)
    local cells = {}
    for i = 1, n do
      local cx, cy = math.mod(i - 1, cols) * cw, math.floor((i - 1) / cols) * ch
      cells[i] = { cx, cy, cw, ch }
    end
    box.grid = Grid(box, cells)
    for i = 1, n do
      local game = SamplePlate(box, SAMPLES[i])
      local c = cells[i]
      game.cell, game.fit = c, P.ZOOM
      -- the health bar on the cell's yellow middle line (a little below the
      -- middle, as the aura rows above it take more room than the cast bar)
      game.at = { c[1] + c[3] / 2, -(c[2] + c[4] * .62) + 18 }
      game:SetScale(P.ZOOM)
      game:SetPoint("TOP", box, "TOPLEFT", game.at[1] / P.ZOOM, game.at[2] / P.ZOOM)
      game.preview.anyTarget = true
      game.caption = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      game.caption:SetPoint("BOTTOM", box, "TOPLEFT", c[1] + c[3] / 2, -(c[2] + c[4]) + 6)
      game.caption:SetTextColor(.6, .6, .6)
      table.insert(list, game)
      table.insert(P.previews, game)
    end
    -- The samples draw in their own layer, which the page's scrolling does
    -- not cut off: while the box is not wholly in view they hide, so nothing
    -- of them shows outside the window (user, 22 Oct 2026).
    local W = pfUI.octoui and pfUI.octoui.W
    local watch = CreateFrame("Frame", nil, box)
    watch:SetScript("OnUpdate", function()
      if not W or not W.Visible then return end
      -- (a zoomed preview: its stage grows past the box, the box is what is seen -
      -- the samples hid as soon as you zoomed, user 26 Oct 2026)
      local vb = box.outer or box
      local l, r, t, b = W.Visible(vb)
      local k = (vb:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
      local whole = l and vb:GetTop() and math.abs(t - vb:GetTop() * k) < 4 and math.abs(b - vb:GetBottom() * k) < 4
      -- (while the window is resized positions come a frame late: only hide
      -- once the box has been out of view for a moment)
      if whole then this.outSince = nil elseif not this.outSince then this.outSince = GetTime() end
      local hide = this.outSince and GetTime() - this.outSince > .25
      for _, game in ipairs(list) do
        if not hide and not game:IsShown() then game:Show() elseif hide and game:IsShown() then game:Hide() end
        if whole then P.Fit(game) end
      end
    end)
    return list
  end

  -- A sample's column of its box, in screen units, with a margin all round
  -- (and room for the caption at the bottom).
  function P.Column(game)
    local box = game:GetParent()
    local k = box:GetEffectiveScale() or 1
    local l, t = box:GetLeft(), box:GetTop()
    local c = game.cell
    if not (l and t and c) then return end
    local m = 6
    -- (the bottom keeps room for the caption)
    return (l + c[1] + m) * k, (l + c[1] + c[3] - m) * k, (t - c[2] - m) * k, (t - c[2] - c[4] + 20) * k
  end

  -- All visible parts of a sample (or only those of one kind), screen units.
  function P.Extent(game, what)
    local ul, ur, ut, ub
    for _, h in ipairs(game.hotlist or {}) do
      if (not what or h.what == what) and h.region:IsVisible() and h:GetLeft() then
        local k = h:GetEffectiveScale() or 1
        ul = math.min(ul or h:GetLeft() * k, h:GetLeft() * k)
        ur = math.max(ur or h:GetRight() * k, h:GetRight() * k)
        ut = math.max(ut or h:GetTop() * k, h:GetTop() * k)
        ub = math.min(ub or h:GetBottom() * k, h:GetBottom() * k)
      end
    end
    return ul, ur, ut, ub
  end

  -- Keeps every part of a sample inside its column (user, 22 Oct 2026: "the
  -- plates should sit inside better"): a sample whose parts stick out
  -- shrinks a little each frame; one with room to spare grows back to full.
  function P.Fit(game)
    local cl, cr, ct, cb = P.Column(game)
    local ul, ur, ut, ub = P.Extent(game)
    if not cl or not ul then return end
    local fit = game.fit or P.ZOOM
    if ul < cl or ur > cr or ut > ct or ub < cb then
      fit = math.max(.45, fit * .97)
    elseif fit < P.ZOOM and ul - cl > 10 and cr - ur > 10 and ct - ut > 10 and ub - cb > 10 then
      fit = math.min(P.ZOOM, fit * 1.01)
    end
    if fit ~= game.fit then
      game.fit = fit
      game:SetScale(fit)
      -- its place in the box stays (offsets count in the sample's own scale)
      game:ClearAllPoints()
      game:SetPoint("TOP", game:GetParent(), "TOPLEFT", game.at[1] / fit, game.at[2] / fit)
    end
  end

  -- ---------------------------------------------------------------- wrap pfUI's nameplates

  local OnConfigChange = NP.OnConfigChange
  NP.OnConfigChange = function(frame)
    OnConfigChange(frame)
    P.Configure(frame and frame.nameplate)
  end

  local OnDataChanged = NP.OnDataChanged
  NP.OnDataChanged = function(self, plate)
    -- our aura rows replace pfUI's debuff row: it skips its own (and its
    -- scan) while they are on; the setting is put back even on an error
    if S.enable == "1" and S.auras == "1" and C.nameplates.showdebuffs == "1" then
      C.nameplates.showdebuffs = "0"
      local good, err = pcall(OnDataChanged, self, plate)
      C.nameplates.showdebuffs = "1"
      if not good then error(err) end
    else
      OnDataChanged(self, plate)
    end
    if plate and not plate.octo then return end
    P.Update(plate)
  end

  -- Calm plates redraw C.plates.calmfps times a second instead of on every
  -- frame (idea from the ClassicAPI pfUI fork, which throttles plates by kind):
  -- pfUI's OnUpdate and our Tick both read a dozen things per plate per frame.
  -- Health is event-driven (OnValueChanged), so only these need every frame:
  -- the target (and the plate just leaving it), queued events, mouseover,
  -- casts, anything animating (o.busy, set by P.Tick), previews and the test.
  function P.Calm(parent, plate)
    local fps = tonumber(S.calmfps) or 30
    if fps >= 60 or S.enable ~= "1" then return end
    local o = plate.octo
    if plate.istarget or plate.eventcache or parent.preview or not o or o.busy then return end
    if plate.castbar:IsShown() or plate.cache.mouseover then return end
    if UnitExists("target") and parent:GetAlpha() == 1 then return end
    if UnitExists("mouseover") and plate.original.glow and plate.original.glow:IsShown() then return end
    if P.Testing() then return end
    local now = GetTime()
    if (plate.calmAt or 0) > now then return true end
    plate.calmAt = now + 1 / fps
  end

  local OnUpdate = NP.OnUpdate
  NP.OnUpdate = function(frame)
    local parent = frame or this
    local plate = parent and parent.nameplate
    if plate and P.Calm(parent, plate) then return end
    OnUpdate(frame)
    if parent then P.Tick(parent.nameplate) end
  end

  local UpdateConfig = NP.UpdateConfig
  NP.UpdateConfig = function(a1, a2)
    ReadColors()
    ReadTanks()
    UpdateConfig(a1, a2)
  end

  -- Settings changed on our pages. pfUI's UpdateConfig also re-applies "show
  -- on enemies / friends", which switched plates the V key had turned on off
  -- (user, 21 Oct): only the Show tick boxes do that (P.ApplyShow).
  function P.Refresh()
    local SetGameVariables = NP.SetGameVariables
    NP.SetGameVariables = function() end
    NP.UpdateConfig()
    NP.SetGameVariables = SetGameVariables
    for _, game in ipairs(P.previews) do
      NP.OnConfigChange(game)
      local box = game:GetParent()
      if box and box.grid then box.grid.Apply() end
    end
  end
  function P.ApplyShow()
    NP.UpdateConfig()
    for _, game in ipairs(P.previews) do NP.OnConfigChange(game) end
  end

  -- One-click looks ("skins"): { key, label, { plates keys }, { nameplates keys } }.
  -- Each sets bars, border skin, text, sizes and target marker; colours stay.
  local OCTO = "Interface\\AddOns\\pfUI\\img\\plates\\"
  local PRESETS = {
    { "plater", "Plater", {
        bartexture = OCTO .. "bar-soft", skin = "pfui", indicator = "arrows", castlayout = "plater", castheight = "12",
        size_target = "110", size_ooc = "90", size_enemyplayer = "100", size_friendlynpc = "80", size_friendlyplayer = "80" },
      { width = "130", heighthealth = "12", showhp = "1", hptextpos = "CENTER", hptextformat = "percent",
        targetglow = "0", targetzoom = "0" } },
    { "slim", "Slim", {
        bartexture = OCTO .. "bar-flat", skin = "pfui", indicator = "corners", castlayout = "plater", castheight = "8",
        size_target = "105", size_ooc = "90", size_enemyplayer = "100", size_friendlynpc = "80", size_friendlyplayer = "80" },
      { width = "110", heighthealth = "6", showhp = "0", targetglow = "0", targetzoom = "0" } },
    { "elvui", "ElvUI", {
        bartexture = "Interface\\AddOns\\pfUI\\img\\bar_elvui", skin = "shadow", indicator = "corners", castlayout = "plater",
        castheight = "10", size_target = "105", size_ooc = "100", size_enemyplayer = "100", size_friendlynpc = "80", size_friendlyplayer = "80" },
      { width = "125", heighthealth = "10", showhp = "1", hptextpos = "RIGHT", hptextformat = "percent",
        targetglow = "0", targetzoom = "0" } },
    { "big", "Big and bold", {
        bartexture = OCTO .. "bar-gloss", skin = "thick", indicator = "arrows", castlayout = "plater", castheight = "14",
        size_target = "115", size_ooc = "90", size_enemyplayer = "100", size_friendlynpc = "75", size_friendlyplayer = "75" },
      { width = "150", heighthealth = "16", showhp = "1", hptextpos = "CENTER", hptextformat = "curperc",
        targetglow = "0", targetzoom = "0" } },
    { "neon", "Neon", {
        bartexture = OCTO .. "bar-glass", skin = "neon", indicator = "underglow", castlayout = "plater", castheight = "10",
        size_target = "110", size_ooc = "90", size_enemyplayer = "100", size_friendlynpc = "80", size_friendlyplayer = "80" },
      { width = "130", heighthealth = "10", showhp = "1", hptextpos = "CENTER", hptextformat = "percent",
        targetglow = "0", targetzoom = "0" } },
    { "classic", "Classic", {
        bartexture = "Interface\\TargetingFrame\\UI-StatusBar", skin = "gold", indicator = "chevrons", castlayout = "plater",
        castheight = "10", size_target = "110", size_ooc = "100", size_enemyplayer = "100", size_friendlynpc = "85", size_friendlyplayer = "85" },
      { width = "120", heighthealth = "10", showhp = "0", targetglow = "0", targetzoom = "0" } },
    { "pvp", "PvP", {
        bartexture = OCTO .. "bar-split", skin = "accent", indicator = "chevrons", castlayout = "plater", castheight = "12",
        size_target = "115", size_ooc = "100", size_enemyplayer = "115", size_friendlynpc = "70", size_friendlyplayer = "75" },
      { width = "135", heighthealth = "12", showhp = "1", hptextpos = "RIGHT", hptextformat = "percent",
        enemyclassc = "1", targetglow = "0", targetzoom = "0" } },
    { "pfui", "pfUI", {
        bartexture = "Interface\\AddOns\\pfUI\\img\\bar", skin = "pfui", indicator = "none", castlayout = "pfui", castheight = "8",
        size_target = "100", size_ooc = "100", size_enemyplayer = "100", size_friendlynpc = "100", size_friendlyplayer = "100" },
      { width = "120", heighthealth = "8", showhp = "0", hptextpos = "RIGHT", hptextformat = "curmaxs",
        targetglow = "1" } },
  }
  P.PRESETS = PRESETS

  function P.ApplyPreset(key)
    for _, p in ipairs(PRESETS) do
      if p[1] == key then
        for k, v in pairs(p[3]) do S[k] = v end
        for k, v in pairs(p[4]) do C.nameplates[k] = v end
        C.nameplates.heightcast = p[3].castheight
      end
    end
    P.Refresh()
  end

  -- Every nameplate setting back to a fresh install (user, 22 Oct 2026: "a
  -- reset all back to out of the box"): pfUI's own nameplate settings and
  -- ours are emptied in place (other code holds these tables), pfUI fills
  -- in its defaults, then the Plater look as on a first load.
  function P.ResetAll()
    for _, t in ipairs({ C.plates, C.nameplates }) do
      for k in pairs(t) do t[k] = nil end
    end
    pfUI:LoadConfig()
    S.firstlook = "1"
    P.ApplyPreset("plater")
  end

  -- the look whose settings are all still as it set them (nil = your own mix)
  function P.CurrentLook()
    for _, p in ipairs(PRESETS) do
      local same = true
      for k, v in pairs(p[3]) do if S[k] ~= v then same = false end end
      for k, v in pairs(p[4]) do if C.nameplates[k] ~= v then same = false end end
      if same then return p[1], p[2] end
    end
  end

  ReadColors()
  ReadTanks()

  -- once: Plater's look (the user asked for Plater's nameplates)
  if S.firstlook ~= "1" then
    S.firstlook = "1"
    P.ApplyPreset("plater")
  end
end)
