pfUI:RegisterModule("unitframes-blizz", "vanilla:tbc", function ()
  -- pfUI Octo :: Blizzard's look on pfUI's own unit frames, and a stance /
  -- form icon at the end of the health bar (9 Nov 2026; Bread on Discord:
  -- "use the Blizzard unit frame but have the same customisation as pfUI",
  -- and "that stance icon at the end of the health bar"). The user picked a
  -- Blizzard skin on pfUI's frames, so every pfUI setting keeps working.
  --
  -- Blizzard look (C.unitframes[unit].o_bz = "1"): the portrait becomes the
  -- game's round 2D portrait inside the game's own ring, cut from the
  -- client's Interface\TargetingFrame\UI-TargetingFrame[-Elite / -Rare]
  -- (the dragon for elites and bosses, silver for rares), with the unit's
  -- level in the small ring. A portrait on the left uses the art mirrored,
  -- as Blizzard's player frame does. Measured from the 256 x 128 texture
  -- (patch-4's TargetFrame.xml: the 64 px portrait's centre is at 182, 44):
  -- ring 150 - 214, small ring centre 203, 65; the elite dragon's head and
  -- tail reach left to 134 above and below the bar lines (y 21 - 62).
  --
  -- Stance icon (o_stance = "1"): the player's from the stance bar
  -- (GetShapeshiftFormInfo: warrior stances, druid forms, paladin auras,
  -- stealth, shadowform); other units' from their buffs (forms, stealth,
  -- shadowform, a paladin's aura), and a warrior's stance from SuperWoW's
  -- UNIT_CASTEVENT (stances are not buffs others can see), kept per GUID.
  if not pfUI.uf then return end
  local BZ = {}
  pfUI.ufBlizz = BZ

  local TEX = "Interface\\TargetingFrame\\UI-TargetingFrame"
  BZ.ART = { normal = TEX, elite = TEX .. "-Elite", worldboss = TEX .. "-Elite", rare = TEX .. "-Rare", rareelite = TEX .. "-Rare" }
  BZ.CX, BZ.CY = 182, 44          -- portrait centre in the texture
  BZ.LX, BZ.LY = 203, 65          -- small (level) ring centre
  -- pieces { left, top, right, bottom } in texture pixels; 2 and 3 only for dragons
  BZ.PIECES = { { 149, 0, 256, 100 }, { 134, 0, 149, 20 }, { 134, 64, 149, 100 } }

  local function Unit(f)
    if not f or not f.label or f.label == "" then return end
    return f.label .. (f.id or "")
  end
  BZ.Unit = Unit

  -- which side the portrait is on: "left" | "right" | nil (none / on the bar)
  local function Side(c)
    local p = c and c.portrait
    if p == "left" or p == "right" then return p end
  end
  BZ.Side = Side

  -- where a piece goes, from the portrait's centre: x, y (TOPLEFT offset),
  -- width, height and the texture coordinates (mirrored on the left)
  function BZ.Place(piece, k, mirror)
    local x1, y1, x2, y2 = piece[1], piece[2], piece[3], piece[4]
    local w, h = (x2 - x1) * k, (y2 - y1) * k
    local x = mirror and -(x2 - BZ.CX) * k or (x1 - BZ.CX) * k
    local y = (BZ.CY - y1) * k
    local l, r = x1 / 256, x2 / 256
    if mirror then l, r = r, l end
    return x, y, w, h, l, r, y1 / 128, y2 / 128
  end

  -- ---------------------------------------------------------------- Blizzard look

  function BZ.Configure(f)
    local c = f and f.config
    if not c or not f.hp then return end
    local side = c.o_bz == "1" and Side(c)
    if not side or not f.portrait then
      if f.bz then f.bz:Hide() f.bz.on = nil end
      return
    end
    -- pfUI's square portrait makes room; ours draws over that room
    f.portrait:Hide()
    local bz = f.bz
    if not bz then
      bz = CreateFrame("Frame", nil, f)
      bz.face = bz:CreateTexture(nil, "BACKGROUND")
      bz.art = {}
      for i = 1, 3 do bz.art[i] = bz:CreateTexture(nil, "ARTWORK") end
      bz.level = bz:CreateFontString(nil, "OVERLAY")
      f.bz = bz
    end
    bz:SetFrameLevel((f.hp:GetFrameLevel() or 1) + 4)
    bz:ClearAllPoints()
    bz:SetPoint("CENTER", f.portrait, "CENTER", 0, 0)
    local size = tonumber(c.o_bzsize) or 64
    if size < 24 then size = 24 end
    bz:SetWidth(size)
    bz:SetHeight(size)
    bz.k = size / 64
    bz.mirror = side == "left"
    bz.face:ClearAllPoints()
    bz.face:SetPoint("CENTER", bz, "CENTER", 0, 0)
    bz.face:SetWidth(size)
    bz.face:SetHeight(size)
    bz.face:SetTexCoord(0, 1, 0, 1)
    for i = 1, 3 do
      local x, y, w, h, l, r, t, b = BZ.Place(BZ.PIECES[i], bz.k, bz.mirror)
      local a = bz.art[i]
      a:ClearAllPoints()
      a:SetPoint("TOPLEFT", bz, "CENTER", x, y)
      a:SetWidth(w)
      a:SetHeight(h)
      a:SetTexCoord(l, r, t, b)
    end
    local lx = (BZ.LX - BZ.CX) * bz.k
    bz.level:ClearAllPoints()
    bz.level:SetPoint("CENTER", bz, "CENTER", bz.mirror and -lx or lx, -(BZ.LY - BZ.CY) * bz.k)
    bz.level:SetFont(pfUI.font_unit or STANDARD_TEXT_FONT, math.max(7, math.floor(10 * bz.k + .5)), "OUTLINE")
    bz.on = true
    bz:Show()
    BZ.Update(f)
  end

  function BZ.Update(f)
    local bz = f and f.bz
    local c = f and f.config
    if not bz or not bz.on or not c then return end
    local unit = Unit(f)
    local exists = unit and UnitExists(unit)
    -- (Configure hid it; pfUI shows it again only in its own UpdateConfig)
    if f.portrait and f.portrait:IsShown() then f.portrait:Hide() end
    if exists then
      SetPortraitTexture(bz.face, unit)
      bz.face:Show()
    else
      bz.face:Hide()
    end
    local kind = exists and UnitClassification and UnitClassification(unit) or "normal"
    if f.octoForceElite then kind = f.octoForceElite end
    if f.label == "player" or f.label == "pet" then kind = "normal" end
    local tex = BZ.ART[kind] or BZ.ART.normal
    local dragon = tex ~= BZ.ART.normal
    for i = 1, 3 do
      local a = bz.art[i]
      a:SetTexture(tex)
      if i == 1 or dragon then a:Show() else a:Hide() end
    end
    -- the game's own elite crest / word would sit on the dragon
    if f.octoElite then f.octoElite:Hide() end
    if f.octoEliteText then f.octoEliteText:Hide() end
    -- level in the small ring, in the game's difficulty colour
    local lvl = exists and UnitLevel(unit)
    if c.o_bzlevel ~= "0" and lvl then
      if lvl < 0 or kind == "worldboss" then
        bz.level:SetText("??")
        bz.level:SetTextColor(1, .1, .1)
      else
        bz.level:SetText(lvl)
        local col = GetDifficultyColor and GetDifficultyColor(lvl)
        if col and not UnitIsUnit(unit, "player") then bz.level:SetTextColor(col.r, col.g, col.b)
        else bz.level:SetTextColor(1, .82, 0) end
      end
      bz.level:Show()
    else
      bz.level:Hide()
    end
  end

  -- ---------------------------------------------------------------- stance icon

  -- buff pictures that are a stance / form (lower case, part of the path);
  -- class = only on that class (a paladin's aura is on everyone near them)
  BZ.STANCEBUFFS = {
    { "ability_racial_bearform" }, { "ability_druid_catform" }, { "ability_druid_travelform" },
    { "ability_druid_aquaticform" }, { "spell_nature_forceofnature", "DRUID" }, { "ability_druid_treeoflife" },
    { "spell_shadow_shadowform" }, { "ability_stealth" }, { "ability_ambush", "DRUID" },
    { "spell_nature_spiritwolf" }, { "ability_warrior_offensivestance" }, { "ability_warrior_defensivestance" },
    { "ability_racial_avatar", "WARRIOR" },
    { "spell_holy_devotionaura", "PALADIN" }, { "spell_holy_auraoflight", "PALADIN" },
    { "spell_holy_mindsooth", "PALADIN" }, { "spell_shadow_sealofkings", "PALADIN" },
    { "spell_frost_wizardmark", "PALADIN" }, { "spell_fire_sealoffire", "PALADIN" },
    { "spell_holy_mindvision", "PALADIN" },
  }
  -- spell ids seen cast (SuperWoW) that set a stance, with the picture when
  -- SpellInfo / ClassicAPI cannot say
  local I = "Interface\\Icons\\"
  BZ.STANCESPELLS = {
    [2457] = I .. "Ability_Warrior_OffensiveStance", [71] = I .. "Ability_Warrior_DefensiveStance",
    [2458] = I .. "Ability_Racial_Avatar",
    [5487] = I .. "Ability_Racial_BearForm", [9634] = I .. "Ability_Racial_BearForm",
    [768] = I .. "Ability_Druid_CatForm", [783] = I .. "Ability_Druid_TravelForm",
    [1066] = I .. "Ability_Druid_AquaticForm", [24858] = I .. "Spell_Nature_ForceOfNature",
    [15473] = I .. "Spell_Shadow_Shadowform", [2645] = I .. "Spell_Nature_SpiritWolf",
  }
  BZ.seen = {}   -- GUID -> stance picture from its last stance cast

  local function StanceBuff(unit)
    local _, class = UnitClass(unit)
    for i = 1, 32 do
      local tex = UnitBuff(unit, i)
      if not tex then break end
      local low = string.lower(tex)
      for _, s in ipairs(BZ.STANCEBUFFS) do
        if string.find(low, s[1], 1, true) and (not s[2] or s[2] == class) then return tex end
      end
    end
  end
  BZ.StanceBuff = StanceBuff

  -- the stance / form picture of a unit, or nil
  function BZ.Stance(unit)
    if not unit or not UnitExists(unit) then return end
    if UnitIsUnit(unit, "player") and GetNumShapeshiftForms and GetShapeshiftFormInfo then
      for i = 1, (GetNumShapeshiftForms() or 0) do
        local tex, _, active = GetShapeshiftFormInfo(i)
        if active and tex then return tex end
      end
    end
    local tex = StanceBuff(unit)
    if tex then return tex end
    local _, class = UnitClass(unit)
    if class == "WARRIOR" then
      local lc = pfUI.api.libclient
      local guid = lc and lc.GUID and lc.GUID(unit)
      return guid and BZ.seen[guid]
    end
  end

  -- where the icon sits: auto = the bar's end away from the portrait
  BZ.STANCEPOS = {
    { key = "auto", label = "End of the bar" }, { key = "right", label = "Right, outside" },
    { key = "left", label = "Left, outside" }, { key = "inright", label = "Right, inside the bar" },
    { key = "inleft", label = "Left, inside the bar" },
  }
  function BZ.StanceConfigure(f)
    local c = f and f.config
    if not c or not f.hp then return end
    if c.o_stance ~= "1" then
      if f.octoStance then f.octoStance:Hide() end
      return
    end
    local s = f.octoStance
    if not s then
      s = CreateFrame("Frame", nil, f)
      s.icon = s:CreateTexture(nil, "ARTWORK")
      s.icon:SetAllPoints(s)
      s.icon:SetTexCoord(.08, .92, .08, .92)
      pfUI.api.CreateBackdrop(s, nil, true)
      f.octoStance = s
    end
    s:SetFrameLevel((f.hp:GetFrameLevel() or 1) + 5)
    local size = tonumber(c.o_stancesize) or 0
    if size <= 0 then size = math.max(8, math.floor((f.hp:GetHeight() or 16) + .5)) end
    s:SetWidth(size)
    s:SetHeight(size)
    local pos = c.o_stancepos or "auto"
    if pos == "auto" then pos = c.portrait == "right" and "left" or "right" end
    local _, border = pfUI.api.GetBorderSize("unitframes")
    local gap = (tonumber(border) or 1) * 2 + 1
    s:ClearAllPoints()
    if pos == "left" then s:SetPoint("RIGHT", f.hp, "LEFT", -gap, 0)
    elseif pos == "inright" then s:SetPoint("RIGHT", f.hp, "RIGHT", -1, 0)
    elseif pos == "inleft" then s:SetPoint("LEFT", f.hp, "LEFT", 1, 0)
    else s:SetPoint("LEFT", f.hp, "RIGHT", gap, 0) end
    BZ.StanceUpdate(f)
  end

  function BZ.StanceUpdate(f)
    local s = f and f.octoStance
    local c = f and f.config
    if not s or not c or c.o_stance ~= "1" then return end
    local tex = f.octoForceStance or BZ.Stance(Unit(f))
    if tex then
      s.icon:SetTexture(tex)
      s:Show()
    else
      s:Hide()
    end
  end

  -- a warrior's stance from SuperWoW's cast events (arg1 caster GUID,
  -- arg3 "CAST", arg4 spell id)
  local ev = CreateFrame("Frame")
  BZ.events = ev
  ev:RegisterEvent("UNIT_CASTEVENT")
  ev:SetScript("OnEvent", function()
    if arg3 ~= "CAST" or not arg1 then return end
    local id = tonumber(arg4)
    local tex = id and BZ.STANCESPELLS[id]
    if not tex then return end
    local lc = pfUI.api.libclient
    local own = lc and lc.SpellIcon and lc.SpellIcon(id)
    BZ.seen[arg1] = own or tex
  end)

  -- ---------------------------------------------------------------- hooks

  local ticker = CreateFrame("Frame")
  BZ.ticker = ticker
  ticker:SetScript("OnUpdate", function()
    if (this.t or 0) > GetTime() then return end
    this.t = GetTime() + .25
    for _, f in ipairs(pfUI.uf.frames or {}) do
      local c = f.config
      if c and f:IsVisible() then
        if f.octoStance and c.o_stance == "1" then BZ.StanceUpdate(f) end
      end
    end
  end)

  local function Configure(f)
    BZ.Configure(f)
    BZ.StanceConfigure(f)
  end
  BZ.ConfigureAll = Configure

  local UpdateConfig = pfUI.uf.UpdateConfig
  local function BlizzUpdateConfig(self)
    UpdateConfig(self)
    Configure(self)
  end
  pfUI.uf.UpdateConfig = BlizzUpdateConfig
  for _, f in ipairs(pfUI.uf.frames) do
    f.UpdateConfig = BlizzUpdateConfig
    Configure(f)
  end

  local RefreshUnit = pfUI.uf.RefreshUnit
  pfUI.uf.RefreshUnit = function(self, unit, component)
    RefreshUnit(self, unit, component)
    if not unit then return end
    if unit.bz and unit.bz.on and (not component or component == "all" or component == "portrait" or component == "base") then
      BZ.Update(unit)
    end
    if unit.octoStance and (not component or component == "all" or component == "aura") then BZ.StanceUpdate(unit) end
  end

  -- one button: Blizzard's look on a frame (portrait on the game's side,
  -- the game's bar picture); pfUI's own settings stay settable afterwards
  function BZ.MakeBlizzard(key)
    local c = C.unitframes[key]
    if not c then return end
    c.o_bz = "1"
    if not Side(c) then c.portrait = key == "player" and "left" or "right" end
    c.bartexture = "Interface\\TargetingFrame\\UI-StatusBar"
    if c.o_skin == "pfui" or not c.o_skin then c.o_skin = "silver" end
  end
end)
