pfUI:RegisterModule("octoloot", "vanilla:tbc", function ()
  -- pfUI Octo :: OctoLoot (26 Nov 2026). User with Atlas-CFM: "How heavy would this be ... could we make this and not
  -- make it effect raid and infight performance", then "Own load-on-demand", the OctoWoW database (octowow.st/db) as
  -- the source, "Keep loot the same so it isn't showing greys ... look better run faster ... artwork where needed for
  -- each instance make it AMAZING", "We call this OctoLoot".
  --
  -- Atlas-CFM is GPL-2: none of its code or art is in here. Its boss lists gave the facts of which boss is in which
  -- instance and its number on the map; the drops and chances are the OctoWoW server's own (its AoWoW database), in
  -- modules\octoloot-data.lua (tools\Make-OctoLootData.ps1). The banners are the game's own loading screens. When
  -- Atlas-CFM is in the AddOns folder (on or off), its map pictures are shown from there - nothing of it is copied.
  --
  -- Cost: the data is ONE text (pfUI.octolootData). It becomes tables only when the window opens (OL.Load) and they
  -- go again a minute after it closes (OL.Unload), so a session that never opens it pays only the text. No events, no
  -- OnUpdate while the window is shut: nothing at all in a fight.
  local OL = {}
  pfUI.octoloot = OL
  local W = pfUI.octoui and pfUI.octoui.W
  local P = W and W.C or {
    bg = { .067, .071, .078 }, panel = { .094, .098, .11 }, card = { .125, .13, .145 }, field = { .07, .073, .08 },
    btn = { .18, .19, .21 }, line = { .23, .24, .27 }, text = { .92, .92, .93 }, dim = { .6, .61, .65 }, accent = { .2, .7, 1 },
  }
  local WHITE = "Interface\\Buttons\\WHITE8X8"
  local GLUE = "Interface\\Glues\\LoadingScreens\\"
  local ICONS = "Interface\\Icons\\"
  local FONT = "Interface\\AddOns\\pfUI\\fonts\\"
  local MAPS = "Interface\\AddOns\\Atlas-CFM\\Images\\Maps\\"

  C.octoloot = C.octoloot or {}
  local function S(k, d) local v = C.octoloot[k] if v == nil then return d end return v end

  -- ---------------------------------------------------------------- the data

  local function Split(s)
    local t, n = {}, 0
    for f in string.gfind(s .. "^", "([^%^]*)%^") do
      n = n + 1
      t[n] = f
    end
    return t
  end

  function OL.Load()
    if OL.db then return OL.db end
    local text = pfUI.octolootData
    if type(text) ~= "string" then return nil end
    local db = { list = {}, by = {}, raw = {}, items = {} }
    local cur
    for line in string.gfind(text, "[^\n]+") do
      local kind = string.sub(line, 1, 1)
      if kind == "I" then
        local f = Split(line)
        local lo, hi = 0, 0
        local _, _, a, b = string.find(f[5] or "", "^(%d+)%-?(%d*)$")
        lo = tonumber(a) or 0
        hi = tonumber(b) or lo
        cur = { key = f[2], name = f[3], kind = f[4], lo = lo, hi = hi, players = tonumber(f[6]) or 0, short = f[7],
          where = f[8], map = f[9] ~= "" and f[9] or nil, ent = f[10] ~= "" and f[10] or nil, zone = tonumber(f[11]),
          bosses = {} }
        table.insert(db.list, cur)
        db.by[cur.key] = cur
      elseif kind == "B" and cur then
        local f = Split(line)
        local num, ent = f[2] or "", false
        if string.sub(num, 1, 1) == "E" then ent = true num = string.sub(num, 2) end
        table.insert(cur.bosses, { num = num, ent = ent, name = f[3], obj = f[4] == "o", id = tonumber(f[5]), lootText = f[6] or "", inst = cur })
      elseif kind == "N" then
        local _, _, id = string.find(line, "^N%^(%d+)%^")
        if id then db.raw[tonumber(id)] = line end
      end
    end
    OL.db = db
    return db
  end

  function OL.Unload()
    OL.db = nil
    OL.sources = nil
    if OL.frame then OL.ClearArt() end
  end

  -- { id, q, name, icon, il, rl, cl, sc } of an item, read from its N line the first time
  function OL.Item(id)
    local db = OL.Load()
    if not db or not id then return nil end
    local it = db.items[id]
    if it then return it end
    local line = db.raw[id]
    if not line then return nil end
    local f = Split(line)
    it = { id = id, q = tonumber(f[3]) or 1, name = f[4] or ("Item " .. id), icon = f[5] ~= "" and f[5] or nil,
      il = tonumber(f[6]) or 0, rl = tonumber(f[7]) or 0, cl = tonumber(f[8]) or 0, sc = tonumber(f[9]) or 0 }
    db.items[id] = it
    return it
  end

  -- a boss's drops as groups: { { chance = nil | n, items = { { id, pct } } } }
  function OL.Loot(boss)
    if boss.loot then return boss.loot end
    local groups, g = {}, nil
    for tok in string.gfind(boss.lootText or "", "[^,]+") do
      if string.sub(tok, 1, 1) == "#" then
        g = { chance = tonumber(string.sub(tok, 2)) or 100, items = {} }
        table.insert(groups, g)
      else
        local _, _, id, pct = string.find(tok, "^(%d+):(%-?[%d%.]+)$")
        if id then
          if not g then
            g = { items = {} }
            table.insert(groups, g)
          end
          table.insert(g.items, { id = tonumber(id), pct = tonumber(pct) or 0 })
        end
      end
    end
    -- the loose drops first, then the groups the server rolls once
    table.sort(groups, function(a, b)
      if (a.chance == nil) ~= (b.chance == nil) then return a.chance == nil end
      return false
    end)
    boss.loot = groups
    return groups
  end

  -- where each item drops: id -> { { boss, pct } }, made the first time something is searched
  function OL.Sources()
    if OL.sources then return OL.sources end
    local db = OL.Load()
    local src = {}
    for _, inst in ipairs(db and db.list or {}) do
      for _, b in ipairs(inst.bosses) do
        for _, g in ipairs(OL.Loot(b)) do
          for _, e in ipairs(g.items) do
            src[e.id] = src[e.id] or {}
            table.insert(src[e.id], { boss = b, pct = e.pct, group = g.chance })
          end
        end
      end
    end
    OL.sources = src
    return src
  end

  -- ---------------------------------------------------------------- facts for the window

  OL.QCOLOR = {
    [0] = { .62, .62, .62 }, [1] = { 1, 1, 1 }, [2] = { .12, 1, 0 }, [3] = { 0, .44, .87 },
    [4] = { .64, .21, .93 }, [5] = { 1, .5, 0 }, [6] = { .9, .8, .5 },
  }
  OL.QNAME = { [0] = "Poor", [1] = "Common", [2] = "Uncommon", [3] = "Rare", [4] = "Epic", [5] = "Legendary", [6] = "Artifact" }
  local WEAPONS = { [0] = "One-Hand Axe", [1] = "Two-Hand Axe", [2] = "Bow", [3] = "Gun", [4] = "One-Hand Mace",
    [5] = "Two-Hand Mace", [6] = "Polearm", [7] = "One-Hand Sword", [8] = "Two-Hand Sword", [10] = "Staff", [13] = "Fist Weapon",
    [14] = "Miscellaneous", [15] = "Dagger", [16] = "Thrown", [17] = "Spear", [18] = "Crossbow", [19] = "Wand", [20] = "Fishing Pole" }
  local ARMOUR = { [0] = "Jewellery / trinket", [1] = "Cloth", [2] = "Leather", [3] = "Mail", [4] = "Plate", [6] = "Shield",
    [7] = "Libram", [8] = "Idol", [9] = "Totem" }
  local CLASSES = { [0] = "Consumable", [1] = "Bag", [5] = "Reagent", [6] = "Projectile", [7] = "Trade goods", [9] = "Recipe",
    [11] = "Quiver", [12] = "Quest item", [13] = "Key", [15] = "Miscellaneous" }
  function OL.TypeText(it)
    if not it then return "" end
    if it.cl == 2 then return WEAPONS[it.sc] or "Weapon" end
    if it.cl == 4 then return ARMOUR[it.sc] or "Armour" end
    return CLASSES[it.cl] or ""
  end

  -- every instance's banner: the game's own loading screen for it (names checked in the client's MPQ listfiles)
  OL.ART = {
    BlackfathomDeeps = "LoadScreenBlackFathomDeeps", BlackrockDepths = "LoadScreenBlackrockDepths",
    BlackrockSpireLower = "LoadScreenBlackrockSpire", BlackrockSpireUpper = "LoadScreenBlackrockSpire",
    BlackwingLair = "LoadScreenBlackWingLair", DireMaulEast = "LoadScreenDireMaul", DireMaulWest = "LoadScreenDireMaul",
    DireMaulNorth = "LoadScreenDireMaul", DragonmawRetreat = "LoadScreenDragonmaw", EmeraldSanctum = "LoadScreenEmeraldSanctum",
    FrostmaneHollow = "LoadScreenFrostmane", GilneasCity = "LoadScreenGilneasCity", Gnomeregan = "LoadScreenGnomeregan",
    HateforgeQuarry = "LoadScreenHateforge", KarazhanCrypt = "LoadscreenKarazhanCrypt", LowerKarazhan = "LoadScreenKarazhan",
    Maraudon = "LoadScreenMaraudon", MoltenCore = "LoadScreenMoltenCore", Naxxramas = "LoadScreenNaxxramas",
    OnyxiasLair = "LoadScreenRaid", RagefireChasm = "LoadScreenRagefireChasm", RazorfenDowns = "LoadScreenRazorfenDowns",
    RazorfenKraul = "LoadScreenRazorfenKraul", TheRuinsofAhnQiraj = "LoadScreenAhnQiraj20man",
    ScarletMonasteryLibrary = "LoadScreenMonastery", ScarletMonasteryArmory = "LoadScreenMonastery",
    ScarletMonasteryCathedral = "LoadScreenMonastery", ScarletMonasteryGraveyard = "LoadScreenMonastery",
    Scholomance = "LoadScreenScholomance", ShadowfangKeep = "LoadScreenShadowFangKeep", StormwindVault = "LoadScreenStormwindStockade",
    StormwroughtRuins = "LoadScreenBalor", Stratholme = "LoadScreenStrathome", TheTempleofAhnQiraj = "LoadScreenAhnQiraj40man",
    CavernsOfTimeBlackMorass = "LoadScreenCavernsTime", TheCrescentGrove = "LoadScreenTwistedbranchGrove",
    TheDeadmines = "LoadScreenDeadmines", TheStockade = "LoadScreenStormwindStockade", TheSunkenTemple = "LoadScreenSunkenTemple",
    TimbermawHold = "LoadScreenTimbermaw", TowerofKarazhan = "LoadScreenKarazhanForty", Uldaman = "LoadScreenUldaman",
    WailingCaverns = "LoadScreenWailingCaverns", WindhornCanyon = "LoadScreenWindhorn", ZulFarrak = "LoadScreenZulFarrak",
    ZulGurub = "LoadScreenZulGurub",
    -- world bosses: the land they walk in
    CowKing = "LoadScreencowlevel", FourDragons = "LoadScreenEmeraldDream", Reaver = "LoadScreenKarazhan",
    Azuregos = "LoadScreenKalimdor", KingMosh = "LoadScreenKalimdor", Ostarius = "LoadScreenKalimdor",
    Kurinnaxx = "LoadScreenKalimdor", Clackora = "LoadScreenKalimdor",
  }
  function OL.Art(inst)
    local a = inst and OL.ART[inst.key]
    if a then return GLUE .. a end
    if inst and inst.kind == "w" then return GLUE .. "LoadScreenEasternKingdom" end
    if inst and inst.kind == "r" then return GLUE .. "LoadScreenRaid" end
    return GLUE .. "LoadScreenDungeon"
  end

  -- Atlas-CFM's map pictures, when that add-on's folder is there (it may be switched off)
  function OL.HasMaps()
    if OL.mapsKnown ~= nil then return OL.mapsKnown end
    local name, title, _, _, _, reason = GetAddOnInfo("Atlas-CFM")
    OL.mapsKnown = (name and title and reason ~= "MISSING") and true or false
    return OL.mapsKnown
  end

  -- the level colour against yours, as quest colours
  function OL.LevelColor(lo, hi)
    local me = UnitLevel("player") or 60
    if lo == 0 then return .8, .8, .8 end
    if me < lo - 4 then return 1, .1, .1 end
    if me < lo then return 1, .5, .25 end
    if me <= hi then return 1, .82, 0 end
    if me <= hi + 5 then return .25, .75, .25 end
    return .55, .55, .55
  end

  -- the instance you are in, matched by name (wings: the first of that name)
  function OL.Here()
    local db = OL.Load()
    local z = GetRealZoneText and GetRealZoneText() or ""
    if not db or z == "" then return nil end
    for _, inst in ipairs(db.list) do if inst.name == z then return inst end end
    for _, inst in ipairs(db.list) do
      local base = string.gsub(inst.name, " %(.*%)$", "")
      if base == z then return inst end
    end
  end

  -- ---------------------------------------------------------------- item helpers

  function OL.Link(it)
    local c = OL.QCOLOR[it.q] or OL.QCOLOR[1]
    return string.format("|cff%02x%02x%02x|Hitem:%d:0:0:0|h[%s]|h|r", c[1] * 255, c[2] * 255, c[3] * 255, it.id, it.name)
  end
  function OL.Icon(it)
    if it and it.icon then return ICONS .. it.icon end
    -- ClassicAPI tells an icon without asking the server; plain 1.12 only knows cached items
    if it and _G.GetItemIcon and _G.C_Item then
      local ok, tex = pcall(_G.GetItemIcon, it.id)
      if ok and type(tex) == "string" then return tex end
    end
    if it then
      local _, _, _, _, _, _, _, _, tex = _G.GetItemInfo(it.id)
      if tex then return tex end
    end
    return ICONS .. "INV_Misc_QuestionMark"
  end
  function OL.ShowTip(owner, it)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local ok = false
    if GameTooltip.SetItemByID then ok = pcall(GameTooltip.SetItemByID, GameTooltip, it.id) end
    if not ok then ok = pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. it.id .. ":0:0:0") end
    if GameTooltip:NumLines() == 0 then
      local c = OL.QCOLOR[it.q] or OL.QCOLOR[1]
      GameTooltip:AddLine(it.name, c[1], c[2], c[3])
      GameTooltip:AddLine("Not seen by your game yet - hover again in a moment.", .6, .6, .6, 1)
    end
    GameTooltip:Show()
  end
  function OL.ClickItem(it, button)
    if IsShiftKeyDown() then
      local box = ChatFrameEditBox or (DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox)
      if box then
        if not box:IsVisible() then box:Show() end
        box:Insert(OL.Link(it))
      end
    elseif IsControlKeyDown() then
      if DressUpItemLink then DressUpItemLink("item:" .. it.id .. ":0:0:0") end
    elseif button == "RightButton" then
      OL.SearchFor(it.name)
    end
  end

  -- ---------------------------------------------------------------- search

  -- instances, bosses and items whose name has the text: { { kind = "inst" | "boss" | "item", ... } }
  function OL.Search(text)
    local db = OL.Load()
    local out = {}
    if not db or not text or string.len(text) < 2 then return out end
    local q = string.lower(text)
    local function has(s) return s and string.find(string.lower(s), q, 1, true) end
    for _, inst in ipairs(db.list) do
      if has(inst.name) or has(inst.short) then table.insert(out, { kind = "inst", inst = inst }) end
    end
    for _, inst in ipairs(db.list) do
      for _, b in ipairs(inst.bosses) do
        if has(b.name) then table.insert(out, { kind = "boss", boss = b }) end
      end
    end
    local src = OL.Sources()
    local items = {}
    for id, line in pairs(db.raw) do
      -- the name is the 4th field; a plain find on the line, then the field checked
      if string.find(string.lower(line), q, 1, true) then
        local it = OL.Item(id)
        if it and has(it.name) and src[id] then table.insert(items, it) end
      end
    end
    table.sort(items, function(a, b)
      if a.q ~= b.q then return a.q > b.q end
      return a.name < b.name
    end)
    for i = 1, math.min(table.getn(items), 200) do
      local it = items[i]
      for _, s in ipairs(src[it.id]) do table.insert(out, { kind = "item", item = it, src = s }) end
    end
    return out
  end

  -- ---------------------------------------------------------------- the window

  local function Fill(parent, c, a, layer)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetTexture(WHITE)
    t:SetVertexColor(c[1], c[2], c[3], a or 1)
    return t
  end
  local function Edge(f, c, a)
    local parts = {}
    for i = 1, 4 do
      local t = Fill(f, c, a, "BORDER")
      parts[i] = t
    end
    parts[1]:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0) parts[1]:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0) parts[1]:SetHeight(1)
    parts[2]:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0) parts[2]:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0) parts[2]:SetHeight(1)
    parts[3]:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0) parts[3]:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0) parts[3]:SetWidth(1)
    parts[4]:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0) parts[4]:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0) parts[4]:SetWidth(1)
    return parts
  end
  local function Paint(parts, r, g, b, a)
    for i = 1, table.getn(parts) do parts[i]:SetVertexColor(r, g, b, a or 1) end
  end
  local function Font(fs, size, c, face)
    fs:SetFont(face or (W and W.UIFont and W.UIFont()) or STANDARD_TEXT_FONT, size or 12, "")
    if c then fs:SetTextColor(c[1], c[2], c[3]) end
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, .9)
    return fs
  end
  local function Grad(t, r, g, b, a1, a2, horiz)
    t:SetTexture(WHITE)
    if t.SetGradientAlpha then
      t:SetVertexColor(1, 1, 1, 1)
      t:SetGradientAlpha(horiz and "HORIZONTAL" or "VERTICAL", r, g, b, a1, r, g, b, a2)
    else
      t:SetVertexColor(r, g, b, math.max(a1, a2))
    end
  end
  local function Accent()
    if pfUI.api and pfUI.api.GetAccentColor then
      local ok, r, g, b = pcall(pfUI.api.GetAccentColor)
      if ok and r then return r, g, b end
    end
    return P.accent[1], P.accent[2], P.accent[3]
  end
  local function Tip(f, title, text)
    f:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:AddLine(title, 1, 1, 1)
      if text then GameTooltip:AddLine(text, .8, .8, .8, 1) end
      GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  local function TextButton(parent, label, w, h)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(w) b:SetHeight(h or 24)
    b.bg = Fill(b, P.btn, .9)
    b.bg:SetAllPoints(b)
    b.edge = Edge(b, P.line, 1)
    b.hl = Fill(b, { 1, 1, 1 }, .06, "HIGHLIGHT")
    b.hl:SetAllPoints(b)
    b.text = Font(b:CreateFontString(nil, "OVERLAY"), 12, P.text)
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.text:SetText(label)
    function b.Lit(on)
      local r, g, bl = Accent()
      if on then
        b.bg:SetVertexColor(r * .35, g * .35, bl * .35, .95)
        Paint(b.edge, r, g, bl, 1)
        b.text:SetTextColor(1, 1, 1)
      else
        b.bg:SetVertexColor(P.btn[1], P.btn[2], P.btn[3], .9)
        Paint(b.edge, P.line[1], P.line[2], P.line[3], 1)
        b.text:SetTextColor(P.text[1], P.text[2], P.text[3])
      end
    end
    return b
  end

  local WIDTH, HEIGHT = 1080, 660
  local LEFT_W, BOSS_W, BANNER_H, ROW_H, ITEM_H = 250, 232, 150, 34, 40

  function OL.Build()
    if OL.frame then return OL.frame end
    local f = CreateFrame("Frame", "pfOctoLoot", UIParent)
    OL.frame = f
    f:SetWidth(WIDTH) f:SetHeight(HEIGHT)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetScale(tonumber(S("scale", 1)) or 1)
    f.bg = Fill(f, P.bg, .97)
    f.bg:SetAllPoints(f)
    f.edge = Edge(f, { 0, 0, 0 }, 1)
    f:Hide()
    table.insert(UISpecialFrames, "pfOctoLoot")
    f:SetScript("OnShow", function() OL.OnShow() end)
    f:SetScript("OnHide", function() OL.OnHide() end)

    -- ---- header: chest glyph, name, search, settings, close
    local top = CreateFrame("Frame", nil, f)
    top:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    top:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    top:SetHeight(52)
    top:EnableMouse(true)
    top:RegisterForDrag("LeftButton")
    top:SetScript("OnDragStart", function() f:StartMoving() end)
    top:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    local tb = Fill(top, P.panel, 1)
    tb:SetAllPoints(top)
    f.topShade = top:CreateTexture(nil, "BORDER")
    f.topShade:SetAllPoints(top)
    f.topLine = Fill(top, P.accent, 1, "ARTWORK")
    f.topLine:SetPoint("BOTTOMLEFT", top, "BOTTOMLEFT", 0, 0)
    f.topLine:SetPoint("BOTTOMRIGHT", top, "BOTTOMRIGHT", 0, 0)
    f.topLine:SetHeight(2)
    local glyph = top:CreateTexture(nil, "ARTWORK")
    glyph:SetTexture("Interface\\AddOns\\pfUI\\img\\octo\\icons\\loot")
    glyph:SetWidth(30) glyph:SetHeight(30)
    glyph:SetPoint("LEFT", top, "LEFT", 14, 0)
    glyph:SetVertexColor(1, .82, .2, 1)
    local title = Font(top:CreateFontString(nil, "OVERLAY"), 22, { 1, 1, 1 }, FONT .. "FiraSansCondensed-SemiBold.ttf")
    title:SetPoint("TOPLEFT", glyph, "TOPRIGHT", 10, 3)
    title:SetText("OctoLoot")
    local sub = Font(top:CreateFontString(nil, "OVERLAY"), 11, P.dim)
    sub:SetPoint("BOTTOMLEFT", glyph, "BOTTOMRIGHT", 11, -2)
    sub:SetText("Every boss on OctoWoW and what it drops - from the server's own database")
    f.sub = sub

    local close = TextButton(top, "x", 26, 26)
    close:SetPoint("RIGHT", top, "RIGHT", -12, 0)
    close:SetScript("OnClick", function() f:Hide() end)
    Tip(close, "Close", "Escape closes it too.")
    local gear = TextButton(top, "Options", 76, 26)
    gear:SetPoint("RIGHT", close, "LEFT", -6, 0)
    gear:SetScript("OnClick", function()
      f:Hide()
      local O = pfUI.octoui and pfUI.octoui.Options
      if O and O.Open then O:Open("octoloot") elseif pfUI.gui then pfUI.gui:Show() end
    end)
    Tip(gear, "OctoLoot options", "Window size, what opens first, and where the maps come from.")
    local here = TextButton(top, "Where I am", 96, 26)
    here:SetPoint("RIGHT", gear, "LEFT", -6, 0)
    here:SetScript("OnClick", function()
      local inst = OL.Here()
      if inst then OL.Select(inst) else UIErrorsFrame:AddMessage("You are not in an instance OctoLoot knows.", 1, .82, 0) end
    end)
    Tip(here, "Where I am", "Opens the instance you are standing in.")

    -- search box
    local sb = CreateFrame("EditBox", "pfOctoLootSearch", top)
    sb:SetWidth(260) sb:SetHeight(26)
    sb:SetPoint("RIGHT", here, "LEFT", -12, 0)
    sb:SetAutoFocus(false)
    sb:SetFontObject(GameFontHighlight)
    sb:SetFont((W and W.UIFont and W.UIFont()) or STANDARD_TEXT_FONT, 12, "")
    sb:SetTextInsets(26, 8, 0, 0)
    local sbg = Fill(sb, P.field, 1)
    sbg:SetAllPoints(sb)
    sb.edge = Edge(sb, P.line, 1)
    local mag = sb:CreateTexture(nil, "OVERLAY")
    mag:SetTexture("Interface\\Minimap\\Tracking\\None")
    mag:SetTexture(ICONS .. "INV_Misc_Spyglass_02")
    mag:SetTexCoord(.08, .92, .08, .92)
    mag:SetWidth(16) mag:SetHeight(16)
    mag:SetPoint("LEFT", sb, "LEFT", 6, 0)
    local hint = Font(sb:CreateFontString(nil, "OVERLAY"), 12, { .45, .46, .5 })
    hint:SetPoint("LEFT", sb, "LEFT", 28, 0)
    hint:SetText("Search an item, boss or instance")
    sb:SetScript("OnEscapePressed", function() this:SetText("") this:ClearFocus() end)
    sb:SetScript("OnEnterPressed", function() this:ClearFocus() end)
    sb:SetScript("OnEditFocusGained", function() hint:Hide() Paint(sb.edge, Accent()) end)
    sb:SetScript("OnEditFocusLost", function()
      if this:GetText() == "" then hint:Show() end
      Paint(sb.edge, P.line[1], P.line[2], P.line[3], 1)
    end)
    sb:SetScript("OnTextChanged", function()
      local t = this:GetText() or ""
      if t ~= "" then hint:Hide() end
      OL.searchAt = GetTime() + .25
      OL.searchText = t
    end)
    f.search = sb

    -- ---- left: kind tabs + instance list
    local left = CreateFrame("Frame", nil, f)
    left:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
    left:SetWidth(LEFT_W)
    local lb = Fill(left, P.panel, .85)
    lb:SetAllPoints(left)
    local lline = Fill(left, P.line, 1, "BORDER")
    lline:SetPoint("TOPRIGHT", left, "TOPRIGHT", 0, 0)
    lline:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", 0, 0)
    lline:SetWidth(1)
    f.left = left
    f.kinds = {}
    local KINDS = { { "d", "Dungeons" }, { "r", "Raids" }, { "w", "World" } }
    for i, k in ipairs(KINDS) do
      local kk = k[1]
      local b = TextButton(left, k[2], (LEFT_W - 24) / 3, 24)
      b:SetPoint("TOPLEFT", left, "TOPLEFT", 8 + (i - 1) * ((LEFT_W - 24) / 3 + 4), -10)
      b:SetScript("OnClick", function() OL.kind = kk OL.listTop = 0 OL.PaintList() end)
      f.kinds[kk] = b
    end
    f.rows = {}
    local nrows = math.floor((HEIGHT - 52 - 46 - 8) / ROW_H)
    for i = 1, nrows do
      local r = CreateFrame("Button", nil, left)
      r:SetHeight(ROW_H - 2)
      r:SetPoint("TOPLEFT", left, "TOPLEFT", 6, -44 - (i - 1) * ROW_H)
      r:SetPoint("TOPRIGHT", left, "TOPRIGHT", -7, -44 - (i - 1) * ROW_H)
      r.bg = Fill(r, { 1, 1, 1 }, .025)
      r.bg:SetAllPoints(r)
      -- a strip of the instance's loading screen behind its name, fading out to the right
      r.art = r:CreateTexture(nil, "BORDER")
      r.art:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
      r.art:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
      r.art:SetWidth(120)
      r.art:SetAlpha(.55)
      r.fade = r:CreateTexture(nil, "ARTWORK")
      r.fade:SetPoint("TOPLEFT", r.art, "TOPLEFT", 0, 0)
      r.fade:SetPoint("BOTTOMRIGHT", r.art, "BOTTOMRIGHT", 0, 0)
      Grad(r.fade, P.panel[1], P.panel[2], P.panel[3], .15, 1, true)
      r.mark = Fill(r, P.accent, 1, "OVERLAY")
      r.mark:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
      r.mark:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
      r.mark:SetWidth(3)
      r.hl = Fill(r, { 1, 1, 1 }, .07, "HIGHLIGHT")
      r.hl:SetAllPoints(r)
      r.name = Font(r:CreateFontString(nil, "OVERLAY"), 13, P.text)
      r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 10, -4)
      r.name:SetPoint("RIGHT", r, "RIGHT", -40, 0)
      r.name:SetJustifyH("LEFT")
      r.info = Font(r:CreateFontString(nil, "OVERLAY"), 10, P.dim)
      r.info:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 10, 4)
      r.lvl = Font(r:CreateFontString(nil, "OVERLAY"), 12, P.text, FONT .. "Expressway.ttf")
      r.lvl:SetPoint("RIGHT", r, "RIGHT", -8, 0)
      r:SetScript("OnClick", function() if this.inst then OL.Select(this.inst) end end)
      r:EnableMouseWheel(true)
      r:SetScript("OnMouseWheel", function() OL.ScrollList(arg1) end)
      f.rows[i] = r
    end
    left:EnableMouseWheel(true)
    left:SetScript("OnMouseWheel", function() OL.ScrollList(arg1) end)

    -- ---- right: banner
    local main = CreateFrame("Frame", nil, f)
    main:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
    main:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    f.main = main
    local ban = CreateFrame("Frame", nil, main)
    ban:SetPoint("TOPLEFT", main, "TOPLEFT", 0, 0)
    ban:SetPoint("TOPRIGHT", main, "TOPRIGHT", 0, 0)
    ban:SetHeight(BANNER_H)
    f.banner = ban
    ban.art = ban:CreateTexture(nil, "BACKGROUND")
    ban.art:SetAllPoints(ban)
    ban.shade = ban:CreateTexture(nil, "BORDER")
    ban.shade:SetAllPoints(ban)
    Grad(ban.shade, 0, 0, 0, .92, .05)
    ban.side = ban:CreateTexture(nil, "BORDER")
    ban.side:SetPoint("TOPLEFT", ban, "TOPLEFT", 0, 0)
    ban.side:SetPoint("BOTTOMLEFT", ban, "BOTTOMLEFT", 0, 0)
    ban.side:SetWidth(420)
    Grad(ban.side, 0, 0, 0, .75, 0, true)
    ban.line = Fill(ban, P.accent, .9, "ARTWORK")
    ban.line:SetPoint("BOTTOMLEFT", ban, "BOTTOMLEFT", 0, 0)
    ban.line:SetPoint("BOTTOMRIGHT", ban, "BOTTOMRIGHT", 0, 0)
    ban.line:SetHeight(1)
    ban.name = Font(ban:CreateFontString(nil, "OVERLAY"), 32, { 1, 1, 1 }, FONT .. "FiraSansCondensed-SemiBold.ttf")
    ban.name:SetPoint("BOTTOMLEFT", ban, "BOTTOMLEFT", 20, 42)
    ban.name:SetShadowOffset(2, -2)
    ban.meta = Font(ban:CreateFontString(nil, "OVERLAY"), 13, { .9, .9, .92 })
    ban.meta:SetPoint("BOTTOMLEFT", ban, "BOTTOMLEFT", 21, 18)
    ban.badge = CreateFrame("Frame", nil, ban)
    ban.badge:SetHeight(22)
    ban.badge:SetPoint("TOPLEFT", ban, "TOPLEFT", 20, -16)
    ban.badge.bg = Fill(ban.badge, { 0, 0, 0 }, .55)
    ban.badge.bg:SetAllPoints(ban.badge)
    ban.badge.edge = Edge(ban.badge, P.accent, 1)
    ban.badge.text = Font(ban.badge:CreateFontString(nil, "OVERLAY"), 11, { 1, 1, 1 }, FONT .. "Expressway.ttf")
    ban.badge.text:SetPoint("CENTER", ban.badge, "CENTER", 0, 0)
    ban.youare = Font(ban:CreateFontString(nil, "OVERLAY"), 11, { .35, 1, .5 })
    ban.youare:SetPoint("LEFT", ban.badge, "RIGHT", 10, 0)
    -- views: loot / map / entrance
    f.views = {}
    local VIEWS = { { "loot", "Loot", 70 }, { "map", "Map", 60 }, { "ent", "Entrance", 84 } }
    local prev
    for i = table.getn(VIEWS), 1, -1 do
      local v = VIEWS[i]
      local vk = v[1]
      local b = TextButton(ban, v[2], v[3], 24)
      if prev then b:SetPoint("RIGHT", prev, "LEFT", -6, 0) else b:SetPoint("BOTTOMRIGHT", ban, "BOTTOMRIGHT", -16, 16) end
      b:SetScript("OnClick", function() OL.view = vk OL.PaintMain() end)
      f.views[vk] = b
      prev = b
    end
    Tip(f.views.map, "Map", "The instance's map with its bosses' numbers. Maps come from Atlas-CFM's pictures when its "
      .. "folder is in your AddOns (it can stay switched off).")

    -- ---- right below the banner: bosses, then the loot
    local bosses = CreateFrame("Frame", nil, main)
    bosses:SetPoint("TOPLEFT", ban, "BOTTOMLEFT", 0, 0)
    bosses:SetPoint("BOTTOMLEFT", main, "BOTTOMLEFT", 0, 0)
    bosses:SetWidth(BOSS_W)
    local bb = Fill(bosses, P.card, .6)
    bb:SetAllPoints(bosses)
    local bl = Fill(bosses, P.line, 1, "BORDER")
    bl:SetPoint("TOPRIGHT", bosses, "TOPRIGHT", 0, 0)
    bl:SetPoint("BOTTOMRIGHT", bosses, "BOTTOMRIGHT", 0, 0)
    bl:SetWidth(1)
    f.bosses = bosses
    f.brows = {}
    local nb = math.floor((HEIGHT - 52 - BANNER_H - 12) / 26)
    for i = 1, nb do
      local r = CreateFrame("Button", nil, bosses)
      r:SetHeight(24)
      r:SetPoint("TOPLEFT", bosses, "TOPLEFT", 6, -6 - (i - 1) * 26)
      r:SetPoint("TOPRIGHT", bosses, "TOPRIGHT", -7, -6 - (i - 1) * 26)
      r.bg = Fill(r, { 1, 1, 1 }, 0)
      r.bg:SetAllPoints(r)
      r.mark = Fill(r, P.accent, 1, "OVERLAY")
      r.mark:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
      r.mark:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
      r.mark:SetWidth(3)
      r.hl = Fill(r, { 1, 1, 1 }, .07, "HIGHLIGHT")
      r.hl:SetAllPoints(r)
      -- the map number in a small disc
      r.disc = r:CreateTexture(nil, "ARTWORK")
      r.disc:SetTexture("Interface\\AddOns\\pfUI\\img\\octo\\disc")
      r.disc:SetWidth(20) r.disc:SetHeight(20)
      r.disc:SetPoint("LEFT", r, "LEFT", 8, 0)
      r.num = Font(r:CreateFontString(nil, "OVERLAY"), 10, { 1, 1, 1 }, FONT .. "Expressway.ttf")
      r.num:SetPoint("CENTER", r.disc, "CENTER", 0, 0)
      r.name = Font(r:CreateFontString(nil, "OVERLAY"), 12, P.text)
      r.name:SetPoint("LEFT", r.disc, "RIGHT", 7, 0)
      r.name:SetPoint("RIGHT", r, "RIGHT", -24, 0)
      r.name:SetJustifyH("LEFT")
      r.count = Font(r:CreateFontString(nil, "OVERLAY"), 10, P.dim, FONT .. "Expressway.ttf")
      r.count:SetPoint("RIGHT", r, "RIGHT", -6, 0)
      r:SetScript("OnClick", function() OL.boss = this.boss OL.itemTop = 0 OL.view = "loot" OL.PaintMain() end)
      r:EnableMouseWheel(true)
      r:SetScript("OnMouseWheel", function() OL.ScrollBosses(arg1) end)
      f.brows[i] = r
    end
    bosses:EnableMouseWheel(true)
    bosses:SetScript("OnMouseWheel", function() OL.ScrollBosses(arg1) end)

    local loot = CreateFrame("Frame", nil, main)
    loot:SetPoint("TOPLEFT", bosses, "TOPRIGHT", 0, 0)
    loot:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", 0, 0)
    f.loot = loot
    loot.head = Font(loot:CreateFontString(nil, "OVERLAY"), 16, { 1, 1, 1 }, FONT .. "FiraSansCondensed-SemiBold.ttf")
    loot.head:SetPoint("TOPLEFT", loot, "TOPLEFT", 16, -12)
    loot.headInfo = Font(loot:CreateFontString(nil, "OVERLAY"), 11, P.dim)
    loot.headInfo:SetPoint("LEFT", loot.head, "RIGHT", 10, -1)
    loot.keys = Font(loot:CreateFontString(nil, "OVERLAY"), 10, { .5, .51, .55 })
    loot.keys:SetPoint("BOTTOMRIGHT", loot, "BOTTOMRIGHT", -14, 8)
    loot.keys:SetText("Shift-click: link   Ctrl-click: try on   Right-click: where else it drops   Wheel: scroll")
    loot.empty = Font(loot:CreateFontString(nil, "OVERLAY"), 13, P.dim)
    loot.empty:SetPoint("CENTER", loot, "CENTER", 0, 0)
    loot.empty:SetWidth(440)
    f.items = {}
    local cols, per = 2, math.floor((HEIGHT - 52 - BANNER_H - 44 - 24) / ITEM_H)
    local colW = (WIDTH - 2 - LEFT_W - BOSS_W - 40) / cols
    for c = 1, cols do
      for i = 1, per do
        local r = CreateFrame("Button", nil, loot)
        r:SetWidth(colW - 6)
        r:SetHeight(ITEM_H - 4)
        r:SetPoint("TOPLEFT", loot, "TOPLEFT", 14 + (c - 1) * colW, -40 - (i - 1) * ITEM_H)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r.bg = Fill(r, { 1, 1, 1 }, .03)
        r.bg:SetAllPoints(r)
        r.hl = Fill(r, { 1, 1, 1 }, .07, "HIGHLIGHT")
        r.hl:SetAllPoints(r)
        r.ib = Fill(r, { 0, 0, 0 }, 1, "BORDER")
        r.ib:SetWidth(32) r.ib:SetHeight(32)
        r.ib:SetPoint("LEFT", r, "LEFT", 2, 0)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetWidth(30) r.icon:SetHeight(30)
        r.icon:SetPoint("CENTER", r.ib, "CENTER", 0, 0)
        r.icon:SetTexCoord(.07, .93, .07, .93)
        r.qedge = Edge(r, { 1, 1, 1 }, 1)
        for _, e in ipairs(r.qedge) do e:ClearAllPoints() end
        r.qedge[1]:SetPoint("TOPLEFT", r.ib, "TOPLEFT", 0, 0) r.qedge[1]:SetPoint("TOPRIGHT", r.ib, "TOPRIGHT", 0, 0)
        r.qedge[2]:SetPoint("BOTTOMLEFT", r.ib, "BOTTOMLEFT", 0, 0) r.qedge[2]:SetPoint("BOTTOMRIGHT", r.ib, "BOTTOMRIGHT", 0, 0)
        r.qedge[3]:SetPoint("TOPLEFT", r.ib, "TOPLEFT", 0, 0) r.qedge[3]:SetPoint("BOTTOMLEFT", r.ib, "BOTTOMLEFT", 0, 0)
        r.qedge[4]:SetPoint("TOPRIGHT", r.ib, "TOPRIGHT", 0, 0) r.qedge[4]:SetPoint("BOTTOMRIGHT", r.ib, "BOTTOMRIGHT", 0, 0)
        r.glow = Fill(r, { 1, 1, 1 }, .08, "BORDER")
        r.glow:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
        r.glow:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
        r.glow:SetWidth(160)
        r.name = Font(r:CreateFontString(nil, "OVERLAY"), 13, P.text)
        r.name:SetPoint("TOPLEFT", r.ib, "TOPRIGHT", 9, -2)
        r.name:SetPoint("RIGHT", r, "RIGHT", -56, 0)
        r.name:SetJustifyH("LEFT")
        r.info = Font(r:CreateFontString(nil, "OVERLAY"), 10, P.dim)
        r.info:SetPoint("BOTTOMLEFT", r.ib, "BOTTOMRIGHT", 9, 2)
        r.info:SetPoint("RIGHT", r, "RIGHT", -56, 0)
        r.info:SetJustifyH("LEFT")
        r.pct = Font(r:CreateFontString(nil, "OVERLAY"), 14, P.text, FONT .. "Expressway.ttf")
        r.pct:SetPoint("RIGHT", r, "RIGHT", -8, 0)
        r.head = Font(r:CreateFontString(nil, "OVERLAY"), 11, { 1, .82, .2 })
        r.head:SetPoint("LEFT", r, "LEFT", 6, -4)
        r.head:SetPoint("RIGHT", r, "RIGHT", -6, 0)
        r.head:SetJustifyH("LEFT")
        r.rule = Fill(r, { 1, .82, .2 }, .35, "ARTWORK")
        r.rule:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 6, 4)
        r.rule:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -6, 4)
        r.rule:SetHeight(1)
        r:SetScript("OnEnter", function()
          if this.entry and this.entry.item then OL.ShowTip(this, this.entry.item) end
          if this.entry and this.entry.where then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Click: open " .. this.entry.where, .4, .8, 1)
            GameTooltip:Show()
          end
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r:SetScript("OnClick", function()
          local e = this.entry
          if not e then return end
          if e.item and (IsShiftKeyDown() or IsControlKeyDown() or arg1 == "RightButton") then OL.ClickItem(e.item, arg1) return end
          if e.go then e.go() end
        end)
        r:EnableMouseWheel(true)
        r:SetScript("OnMouseWheel", function() OL.ScrollItems(arg1) end)
        table.insert(f.items, r)
      end
    end
    f.perCol = per
    loot:EnableMouseWheel(true)
    loot:SetScript("OnMouseWheel", function() OL.ScrollItems(arg1) end)

    -- the map: Atlas-CFM's picture, fitted into the loot area
    local map = CreateFrame("Frame", nil, main)
    map:SetPoint("TOPLEFT", bosses, "TOPRIGHT", 10, -10)
    map:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -10, 10)
    map.tex = map:CreateTexture(nil, "ARTWORK")
    map.tex:SetPoint("CENTER", map, "CENTER", 0, 0)
    map.note = Font(map:CreateFontString(nil, "OVERLAY"), 13, P.dim)
    map.note:SetPoint("CENTER", map, "CENTER", 0, 0)
    map.note:SetWidth(460)
    map:Hide()
    f.map = map

    -- the search's wait (.25 s after the last key) - only while the window is open
    f:SetScript("OnUpdate", function()
      if OL.searchAt and GetTime() >= OL.searchAt then
        OL.searchAt = nil
        OL.RunSearch(OL.searchText)
      end
      if OL.iconAt and GetTime() >= OL.iconAt then
        -- pictures the game learns while the window is open
        OL.iconAt = GetTime() + 1
        if OL.missing then OL.PaintItems() end
      end
    end)
    return f
  end

  -- ---------------------------------------------------------------- painting

  function OL.Visible()
    local db = OL.Load()
    local out = {}
    for _, inst in ipairs(db and db.list or {}) do
      if inst.kind == (OL.kind or "d") then table.insert(out, inst) end
    end
    if OL.kind ~= "w" then
      table.sort(out, function(a, b)
        if a.lo ~= b.lo then return a.lo < b.lo end
        return a.name < b.name
      end)
    end
    return out
  end

  function OL.PaintList()
    local f = OL.frame
    if not f then return end
    for k, b in pairs(f.kinds) do b.Lit(k == (OL.kind or "d")) end
    local list = OL.Visible()
    local n = table.getn(f.rows)
    local maxTop = math.max(0, table.getn(list) - n)
    OL.listTop = math.max(0, math.min(OL.listTop or 0, maxTop))
    local here = OL.Here()
    local r1, g1, b1 = Accent()
    for i = 1, n do
      local r = f.rows[i]
      local inst = list[i + OL.listTop]
      r.inst = inst
      if inst then
        r.name:SetText(inst.name)
        local info = (inst.players > 0 and (inst.players .. " players") or "")
        if inst.where and inst.where ~= "" and inst.kind ~= "w" then info = info .. (info ~= "" and "  -  " or "") .. inst.where end
        if inst == here then info = "|cff55ff77You are here|r  " .. info end
        r.info:SetText(info)
        if inst.lo > 1 or inst.kind ~= "w" then
          local cr, cg, cb = OL.LevelColor(inst.lo, inst.hi)
          r.lvl:SetText(inst.lo == inst.hi and tostring(inst.lo) or (inst.lo .. "-" .. inst.hi))
          r.lvl:SetTextColor(cr, cg, cb)
        else
          r.lvl:SetText("")
        end
        r.art:SetTexture(OL.Art(inst))
        r.art:SetTexCoord(.1, .55, .38, .5)
        local on = inst == OL.inst
        r.mark:SetVertexColor(r1, g1, b1, 1)
        if on then r.mark:Show() r.bg:SetVertexColor(r1, g1, b1, .14) else r.mark:Hide() r.bg:SetVertexColor(1, 1, 1, .025) end
        r:Show()
      else
        r:Hide()
      end
    end
  end

  function OL.ClearArt()
    local f = OL.frame
    if not f then return end
    -- drop the big pictures so the game can free them while the window is shut
    for _, r in ipairs(f.rows) do r.art:SetTexture(nil) end
    f.banner.art:SetTexture(nil)
    f.map.tex:SetTexture(nil)
  end

  function OL.Select(inst, boss)
    if not inst then return end
    if not OL.frame or not OL.frame:IsShown() then
      OL.pending = { inst, boss }
      OL.Show()
      return
    end
    OL.inst = inst
    OL.kind = inst.kind
    OL.boss = boss
    OL.view = "loot"
    OL.itemTop, OL.bossTop = 0, 0
    OL.results = nil
    -- keep the picked one in view
    local list = OL.Visible()
    for i, x in ipairs(list) do
      if x == inst then
        local n = table.getn(OL.frame.rows)
        if i <= (OL.listTop or 0) or i > (OL.listTop or 0) + n then OL.listTop = math.max(0, i - math.floor(n / 2)) end
      end
    end
    C.octoloot.last = inst.key
    OL.PaintList()
    OL.PaintMain()
  end

  function OL.PaintBanner()
    local f, inst = OL.frame, OL.inst
    local ban = f.banner
    local r, g, b = Accent()
    ban.line:SetVertexColor(r, g, b, .9)
    Paint(ban.badge.edge, r, g, b, 1)
    f.topLine:SetVertexColor(r, g, b, 1)
    Grad(f.topShade, r, g, b, .16, 0, true)
    if OL.results then
      ban.art:SetTexture(GLUE .. "LoadScreenDungeon")
      ban.art:SetTexCoord(0, 1, .3, .62)
      ban.name:SetText("Search")
      ban.meta:SetText(table.getn(OL.results) .. " found for \"" .. (OL.searchText or "") .. "\"")
      ban.badge:Hide()
      ban.youare:SetText("")
      for _, v in pairs(f.views) do v:Hide() end
      return
    end
    if not inst then return end
    ban.art:SetTexture(OL.Art(inst))
    -- a wide band out of the 4:3 picture
    ban.art:SetTexCoord(0, 1, .3, .62)
    ban.name:SetText(inst.name)
    local parts = {}
    if inst.kind ~= "w" then
      table.insert(parts, inst.lo == inst.hi and ("Level " .. inst.lo) or ("Levels " .. inst.lo .. " - " .. inst.hi))
    end
    if inst.players > 0 then table.insert(parts, inst.players .. " players") end
    if inst.where and inst.where ~= "" and inst.kind ~= "w" then table.insert(parts, inst.where) end
    table.insert(parts, table.getn(inst.bosses) .. " bosses")
    ban.meta:SetText(table.concat(parts, "   |cff666870/|r   "))
    if inst.short and inst.short ~= "" then
      ban.badge.text:SetText(inst.short)
      ban.badge:SetWidth(ban.badge.text:GetStringWidth() + 16)
      ban.badge:Show()
    else
      ban.badge:Hide()
    end
    ban.youare:SetText(inst == OL.Here() and "YOU ARE HERE" or "")
    local maps = OL.HasMaps()
    f.views.loot:Show()
    if inst.map and maps then f.views.map:Show() else f.views.map:Hide() end
    if inst.ent and maps then f.views.ent:Show() else f.views.ent:Hide() end
    for k, v in pairs(f.views) do v.Lit(k == (OL.view or "loot")) end
  end

  function OL.PaintBosses()
    local f, inst = OL.frame, OL.inst
    local rows = f.brows
    local list = {}
    if OL.results then
      for i = 1, table.getn(rows) do rows[i]:Hide() end
      return
    end
    table.insert(list, false) -- "Everything here"
    for _, b in ipairs(inst and inst.bosses or {}) do table.insert(list, b) end
    local n = table.getn(rows)
    OL.bossTop = math.max(0, math.min(OL.bossTop or 0, table.getn(list) - n))
    local r1, g1, b1 = Accent()
    for i = 1, n do
      local r = rows[i]
      local e = list[i + OL.bossTop]
      if e == nil then
        r:Hide()
      else
        r.boss = e or nil
        local on = (e or nil) == OL.boss
        if e then
          r.name:SetText(e.name)
          local num = e.num or ""
          num = string.gsub(num, "[%)']", "")
          r.num:SetText(num)
          if num ~= "" then r.disc:Show() else r.disc:Hide() end
          if e.ent then r.disc:SetVertexColor(.45, .7, .45) else r.disc:SetVertexColor(r1 * .7, g1 * .7, b1 * .7) end
          local cnt = 0
          for _, g in ipairs(OL.Loot(e)) do cnt = cnt + table.getn(g.items) end
          r.count:SetText(cnt > 0 and tostring(cnt) or "")
          r.name:SetTextColor(cnt > 0 and P.text[1] or .5, cnt > 0 and P.text[2] or .5, cnt > 0 and P.text[3] or .52)
        else
          r.name:SetText("|cffffd133Everything here|r")
          r.num:SetText("")
          r.disc:Hide()
          r.count:SetText("")
        end
        r.mark:SetVertexColor(r1, g1, b1, 1)
        if on then r.mark:Show() r.bg:SetVertexColor(r1, g1, b1, .14) else r.mark:Hide() r.bg:SetVertexColor(1, 1, 1, 0) end
        r:Show()
      end
    end
  end

  -- the rows of the loot area: { head = text } | { item, pct, group } | search results with go
  function OL.Entries()
    local out = {}
    if OL.results then
      for _, res in ipairs(OL.results) do
        if res.kind == "inst" then
          local inst = res.inst
          table.insert(out, { title = inst.name, sub = (inst.short or "") .. "  " .. table.getn(inst.bosses) .. " bosses",
            icon = OL.Art(inst), art = true, where = inst.name, go = function() OL.ClearSearch() OL.Select(inst) end })
        elseif res.kind == "boss" then
          local b = res.boss
          table.insert(out, { title = b.name, sub = b.inst.name, icon = OL.Art(b.inst), art = true, where = b.inst.name,
            go = function() OL.ClearSearch() OL.Select(b.inst, b) end })
        else
          local s = res.src
          table.insert(out, { item = res.item, pct = s.pct, group = s.group, sub2 = s.boss.name .. "  -  " .. s.boss.inst.name,
            where = s.boss.name, go = function() OL.ClearSearch() OL.Select(s.boss.inst, s.boss) end })
        end
      end
      return out
    end
    local inst = OL.inst
    if not inst then return out end
    local bosses = OL.boss and { OL.boss } or inst.bosses
    local seen = {}
    for _, b in ipairs(bosses) do
      if not OL.boss then table.insert(out, { head = b.name, big = true }) end
      for _, g in ipairs(OL.Loot(b)) do
        local count = table.getn(g.items)
        if g.chance then
          local txt
          if count == 1 then txt = "Rolled once a kill"
          else txt = "One of these " .. count end
          if g.chance < 100 then txt = txt .. "  -  in " .. g.chance .. "% of kills" end
          table.insert(out, { head = txt })
        end
        for _, e in ipairs(g.items) do
          local it = OL.Item(e.id)
          if it and (OL.boss or not seen[e.id .. ":" .. b.name]) then
            seen[e.id .. ":" .. b.name] = true
            table.insert(out, { item = it, pct = e.pct, group = g.chance })
          end
        end
      end
    end
    return out
  end

  local function PctText(pct, group)
    if not pct then return "" end
    if pct < 0 then return "|cffffd133Quest|r" end
    local v = pct
    if group and group < 100 then v = pct * group / 100 end
    if v >= 99.5 then return "|cff55ff77100%|r" end
    if v >= 10 then return string.format("%d%%", v + .5) end
    if v >= 1 then return string.format("%.1f%%", v) end
    return string.format("|cff9a9ca3%.2f%%|r", v)
  end

  function OL.PaintItems()
    local f = OL.frame
    local rows = f.items
    local list = OL.entries or {}
    local n = table.getn(rows)
    OL.itemTop = math.max(0, math.min(OL.itemTop or 0, math.max(0, table.getn(list) - n)))
    OL.missing = false
    -- fill down the first column, then the second
    for i = 1, n do
      local r = rows[i]
      local e = list[i + OL.itemTop]
      r.entry = e
      if not e then
        r:Hide()
      elseif e.head then
        r.head:SetText(e.big and ("|cffffffff" .. e.head .. "|r") or e.head)
        r.head:SetFont(r.head:GetFont(), e.big and 14 or 11, "")
        r.head:Show() r.rule:Show()
        r.rule:SetVertexColor(1, .82, .2, e.big and .6 or .3)
        r.icon:Hide() r.ib:Hide() r.name:Hide() r.info:Hide() r.pct:Hide() r.glow:Hide() r.bg:Hide()
        for _, x in ipairs(r.qedge) do x:Hide() end
        r:Show()
      else
        r.head:Hide() r.rule:Hide()
        r.icon:Show() r.ib:Show() r.name:Show() r.info:Show() r.pct:Show() r.glow:Show() r.bg:Show()
        for _, x in ipairs(r.qedge) do x:Show() end
        if e.item then
          local it = e.item
          local c = OL.QCOLOR[it.q] or OL.QCOLOR[1]
          local tex = OL.Icon(it)
          if string.find(tex, "QuestionMark") then OL.missing = true end
          r.icon:SetTexture(tex)
          r.icon:SetTexCoord(.07, .93, .07, .93)
          r.name:SetText(it.name)
          r.name:SetTextColor(c[1], c[2], c[3])
          Paint(r.qedge, c[1], c[2], c[3], 1)
          Grad(r.glow, c[1], c[2], c[3], .16, 0, true)
          local info = e.sub2 or OL.TypeText(it)
          if not e.sub2 and it.il and it.il > 0 and (it.cl == 2 or it.cl == 4) then info = info .. "   |cff7a7c82ilvl " .. it.il .. "|r" end
          r.info:SetText(info)
          r.pct:SetText(PctText(e.pct, e.group))
        else
          r.icon:SetTexture(e.icon)
          if e.art then r.icon:SetTexCoord(.3, .62, .3, .62) end
          r.name:SetText(e.title)
          r.name:SetTextColor(1, .82, .2)
          Paint(r.qedge, .4, .41, .45, 1)
          Grad(r.glow, 1, .82, .2, .1, 0, true)
          r.info:SetText(e.sub or "")
          r.pct:SetText("|cff66ccff>|r")
        end
        r:Show()
      end
    end
  end

  function OL.PaintMain()
    local f = OL.frame
    if not f then return end
    OL.PaintBanner()
    OL.PaintBosses()
    local view = OL.view or "loot"
    local inst = OL.inst
    if not OL.results and inst and view ~= "loot" and OL.HasMaps() and ((view == "map" and inst.map) or (view == "ent" and inst.ent)) then
      f.loot:Hide()
      f.map:Show()
      local key = view == "ent" and inst.ent or inst.map
      local s = math.min(f.map:GetWidth() or 400, f.map:GetHeight() or 400)
      if s < 50 then s = 440 end
      f.map.tex:SetWidth(s) f.map.tex:SetHeight(s)
      f.map.tex:SetTexture(MAPS .. key)
      f.map.tex:Show()
      f.map.note:SetText("")
      return
    end
    f.map:Hide()
    f.map.tex:SetTexture(nil)
    f.loot:Show()
    OL.entries = OL.Entries()
    local loot = f.loot
    if OL.results then
      loot.head:SetText("Search")
      loot.headInfo:SetText("click a line to open it")
    elseif OL.boss then
      loot.head:SetText(OL.boss.name)
      local cnt = 0
      for _, g in ipairs(OL.Loot(OL.boss)) do cnt = cnt + table.getn(g.items) end
      loot.headInfo:SetText(cnt .. " drops" .. (OL.boss.obj and "  -  a chest or object" or ""))
    else
      loot.head:SetText(inst and inst.name or "")
      loot.headInfo:SetText("every boss's drops - pick a boss on the left for one")
    end
    if table.getn(OL.entries) == 0 then
      loot.empty:SetText(OL.results and "Nothing found." or "The server's database lists no drops for this one.")
      loot.empty:Show()
    else
      loot.empty:Hide()
    end
    OL.PaintItems()
  end

  function OL.ScrollList(d)
    OL.listTop = (OL.listTop or 0) - (d or 0) * 3
    OL.PaintList()
  end
  function OL.ScrollBosses(d)
    OL.bossTop = (OL.bossTop or 0) - (d or 0) * 3
    OL.PaintBosses()
  end
  function OL.ScrollItems(d)
    local f = OL.frame
    local step = f and f.perCol or 6
    OL.itemTop = (OL.itemTop or 0) - (d or 0) * math.floor(step / 2)
    OL.PaintItems()
  end

  function OL.RunSearch(text)
    if not text or string.len(text) < 2 then
      if OL.results then OL.results = nil OL.PaintMain() end
      return
    end
    OL.results = OL.Search(text)
    OL.itemTop = 0
    OL.PaintMain()
  end
  function OL.ClearSearch()
    OL.results = nil
    if OL.frame then
      OL.frame.search:SetText("")
      OL.frame.search:ClearFocus()
    end
  end
  function OL.SearchFor(text)
    OL.Show()
    OL.frame.search:SetText(text or "")
    OL.searchAt = nil
    OL.searchText = text
    OL.RunSearch(text)
  end

  -- ---------------------------------------------------------------- open / close

  function OL.OnShow()
    OL.unloadAt = nil
    if not OL.Load() then return end
    OL.iconAt = GetTime() + 1
    local p = OL.pending
    OL.pending = nil
    if p then
      OL.Select(p[1], p[2])
    elseif not OL.inst or not OL.db.by[OL.inst.key] then
      local inst = (S("openhere", "1") == "1" and OL.Here()) or OL.db.by[C.octoloot.last or ""] or OL.db.by["MoltenCore"] or OL.db.list[1]
      OL.Select(inst)
    else
      if S("openhere", "1") == "1" then
        local here = OL.Here()
        if here and here ~= OL.inst then OL.Select(here) return end
      end
      OL.PaintList()
      OL.PaintMain()
    end
  end

  -- a minute after it closes its tables go (and the art), unless it opens again
  local sleeper = CreateFrame("Frame")
  sleeper:Hide()
  sleeper:SetScript("OnUpdate", function()
    if not OL.unloadAt then this:Hide() return end
    if GetTime() >= OL.unloadAt then
      OL.unloadAt = nil
      this:Hide()
      if not (OL.frame and OL.frame:IsShown()) then
        -- the picked instance is kept by key; its tables go with the rest
        OL.inst, OL.boss, OL.results, OL.entries = nil, nil, nil, nil
        OL.Unload()
      end
    end
  end)
  function OL.OnHide()
    GameTooltip:Hide()
    if OL.frame then OL.frame.search:ClearFocus() end
    if S("unload", "1") == "1" then
      OL.unloadAt = GetTime() + 60
      sleeper:Show()
    end
  end

  function OL.Show()
    local f = OL.Build()
    f:SetScale(tonumber(S("scale", 1)) or 1)
    f:Show()
  end
  function OL.Toggle()
    if OL.frame and OL.frame:IsShown() then OL.frame:Hide() else OL.Show() end
  end

  _G.BINDING_HEADER_PFOCTOLOOT = "pfUI Octo: OctoLoot"
  _G.BINDING_NAME_PFOCTOLOOT = "Open / close OctoLoot"

  -- /octoloot [text], /ol [text]; /atlas and /atlasloot when those add-ons are not loaded
  _G.SLASH_PFOCTOLOOT1 = "/octoloot"
  _G.SLASH_PFOCTOLOOT2 = "/ol"
  local n = 3
  if not IsAddOnLoaded("Atlas-CFM") and not IsAddOnLoaded("Atlas") then _G["SLASH_PFOCTOLOOT" .. n] = "/atlas" n = n + 1 end
  if not IsAddOnLoaded("AtlasLoot") then _G["SLASH_PFOCTOLOOT" .. n] = "/atlasloot" n = n + 1 end
  _G.SlashCmdList.PFOCTOLOOT = function(msg)
    msg = msg or ""
    if msg ~= "" then OL.SearchFor(msg) else OL.Toggle() end
  end
end)
