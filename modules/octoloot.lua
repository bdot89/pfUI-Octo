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
  -- (26 Nov 2026, in game: "octoloot.lua:525: attempt to call global `Accent'" - the QuickLook buttons' painter sits
  -- above where these were made; locals must be made before the functions that use them)
  local function Paint(parts, r, g, b, a)
    for i = 1, table.getn(parts) do parts[i]:SetVertexColor(r, g, b, a or 1) end
  end
  local function Accent()
    if pfUI.api and pfUI.api.GetAccentColor then
      local ok, r, g, b = pcall(pfUI.api.GetAccentColor)
      if ok and r then return r, g, b end
    end
    return P.accent[1], P.accent[2], P.accent[3]
  end

  -- ---------------------------------------------------------------- the data

  local function Split(s)
    local t, n = {}, 0
    for f in string.gfind(s .. "^", "([^%^]*)%^") do
      n = n + 1
      t[n] = f
    end
    return t
  end

  -- the I / B lines of one text into db (dungeons and raids; the other sections' pages use the same lines)
  local function ReadPages(db, text)
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
          icon = f[12] ~= "" and f[12] or nil, bosses = {} }
        table.insert(db.list, cur)
        db.by[cur.key] = cur
      elseif kind == "B" and cur then
        local f = Split(line)
        local num, ent = f[2] or "", false
        if string.sub(num, 1, 1) == "E" then ent = true num = string.sub(num, 2) end
        table.insert(cur.bosses, { num = num, ent = ent, name = f[3], obj = f[4] == "o", page = f[4] == "p", id = tonumber(f[5]),
          lootText = f[6] or "", inst = cur })
      elseif kind == "R" then
        local _, _, id = string.find(line, "^R%^(%d+)%^")
        if id then db.recipes[tonumber(id)] = line end
      elseif kind == "S" then
        table.insert(db.setLines, line)
      elseif kind == "Q" then
        -- an instance's quest (octoloot-quests.lua reads them)
        local _, _, key = string.find(line, "^Q%^([^%^]+)%^")
        if key then
          db.quests[key] = db.quests[key] or {}
          table.insert(db.quests[key], line)
        end
      elseif kind == "X" then
        local _, _, id, to = string.find(line, "^X%^(%d+)%^([%d,]+)")
        if id then db.swaps[tonumber(id)] = to end
      elseif kind == "N" then
        local _, _, id = string.find(line, "^N%^(%d+)%^")
        if id then db.raw[tonumber(id)] = line end
      end
    end
  end

  function OL.Load()
    if OL.db then return OL.db end
    local text = pfUI.octolootData
    if type(text) ~= "string" then return nil end
    local db = { list = {}, by = {}, raw = {}, items = {}, recipes = {}, setLines = {}, swaps = {}, quests = {} }
    ReadPages(db, text)
    OL.db = db
    return db
  end
  -- the other sections (events, collections, factions, PvP, crafting): read the first time one is wanted
  OL.PAGEKINDS = { e = true, c = true, f = true, p = true, x = true }
  function OL.LoadPages()
    local db = OL.Load()
    if not db or db.pagesRead then return db end
    db.pagesRead = true
    if type(pfUI.octolootPages) == "string" then ReadPages(db, pfUI.octolootPages) end
    OL.sources = nil
    return db
  end

  function OL.Unload()
    OL.db = nil
    OL.sources = nil
    OL.setOf, OL.swapFrom, OL.usedIn, OL.backs = nil, nil, nil, nil
    if OL.frame then OL.ClearArt() end
  end

  -- every item's line, indexed the first time an item is needed (one pass over the items text)
  function OL.ItemIndex()
    local db = OL.Load()
    if not db then return nil end
    if db.itemsRead then return db.raw end
    db.itemsRead = true
    local text = pfUI.octolootItems
    if type(text) == "string" then
      -- (Lua 5.0 drops the newline right after "[[": the first line has none in front of it)
      for id, line in string.gfind("\n" .. text, "\nN%^(%d+)(%^[^\n]*)") do db.raw[tonumber(id)] = "N^" .. id .. line end
    end
    return db.raw
  end

  -- { id, q, name, icon, il, rl, cl, sc, slot } of an item, read from its N line the first time
  function OL.Item(id)
    local db = OL.Load()
    if not db or not id then return nil end
    local it = db.items[id]
    if it then return it end
    local line = OL.ItemIndex()[id]
    if not line then return nil end
    local f = Split(line)
    it = { id = id, q = tonumber(f[3]) or 1, name = f[4] or ("Item " .. id), icon = f[5] ~= "" and f[5] or nil,
      il = tonumber(f[6]) or 0, rl = tonumber(f[7]) or 0, cl = tonumber(f[8]) or 0, sc = tonumber(f[9]) or 0, slot = tonumber(f[10]) or 0 }
    db.items[id] = it
    return it
  end

  -- a recipe: { id, name, skill, made = item id, levels = "a,b,c,d", reagents = { { id, n } } }
  function OL.Recipe(id)
    local db = OL.Load()
    local line = db and db.recipes[id]
    if not line then return nil end
    if type(line) == "table" then return line end
    local f = Split(line)
    local r = { id = id, name = f[3], skill = tonumber(f[4]), made = tonumber(f[5]), levels = f[6] or "", reagents = {} }
    for rid, n in string.gfind(f[7] or "", "(%d+)x(%d+)") do table.insert(r.reagents, { id = tonumber(rid), n = tonumber(n) }) end
    db.recipes[id] = r
    return r
  end

  -- a page's / boss's items as groups: { { chance = nil | n, title = nil | text, items = { { id, pct, note, spell } } } }
  -- tokens: "#chance" a group the server rolls once, "@title" a heading, "id[:pct][~note]" an item, "s<spell>" a recipe
  function OL.Loot(boss)
    if boss.loot then return boss.loot end
    local groups, g = {}, nil
    for tok in string.gfind(boss.lootText or "", "[^,]+") do
      local c = string.sub(tok, 1, 1)
      if c == "#" then
        g = { chance = tonumber(string.sub(tok, 2)) or 100, items = {} }
        table.insert(groups, g)
      elseif c == "@" then
        g = { title = string.sub(tok, 2), items = {} }
        table.insert(groups, g)
      elseif c == "s" then
        if not g then g = { items = {} } table.insert(groups, g) end
        table.insert(g.items, { spell = tonumber(string.sub(tok, 2)) })
      else
        local _, _, id, rest = string.find(tok, "^(%d+)(.*)$")
        if id then
          local _, _, pct = string.find(rest, "^:(%-?[%d%.]+)")
          local _, _, note = string.find(rest, "~(.+)$")
          if not g then
            g = { items = {} }
            table.insert(groups, g)
          end
          table.insert(g.items, { id = tonumber(id), pct = tonumber(pct), note = note })
        end
      end
    end
    -- a boss: the loose drops first, then the groups the server rolls once (pages keep their order)
    if not boss.page then
      table.sort(groups, function(a, b)
        if (a.chance == nil) ~= (b.chance == nil) then return a.chance == nil end
        return false
      end)
    end
    boss.loot = groups
    return groups
  end

  -- where each item is: id -> { { boss, pct, group } } (drops, and the pages of the other sections once read)
  function OL.Sources()
    if OL.sources then return OL.sources end
    local db = OL.Load()
    local src = {}
    for _, inst in ipairs(db and db.list or {}) do
      for _, b in ipairs(inst.bosses) do
        for _, g in ipairs(OL.Loot(b)) do
          for _, e in ipairs(g.items) do
            local id = e.id
            if e.spell then
              local r = OL.Recipe(e.spell)
              id = r and r.made
            end
            if id then
              src[id] = src[id] or {}
              table.insert(src[id], { boss = b, pct = e.pct, group = g.chance, spell = e.spell })
            end
          end
        end
      end
    end
    OL.sources = src
    return src
  end

  -- the item sets: id -> { id, q, name, pieces = { ids } }, and which set each piece is in (made when first asked)
  function OL.SetOf(id)
    local db = OL.LoadPages()
    if not db then return nil end
    if not OL.setOf then
      OL.setOf = {}
      for _, line in ipairs(db.setLines) do
        local f = Split(line)
        local set = { id = tonumber(f[2]), q = tonumber(f[3]) or 4, name = f[4], pieces = {} }
        for p in string.gfind(f[5] or "", "%d+") do
          table.insert(set.pieces, tonumber(p))
          OL.setOf[tonumber(p)] = set
        end
      end
    end
    return OL.setOf[id]
  end
  -- what an item can be swapped for, and what can be swapped for it
  function OL.Swaps(id)
    local db = OL.LoadPages()
    if not db then return {}, {} end
    if not OL.swapFrom then
      OL.swapFrom = {}
      for from, to in pairs(db.swaps) do
        for x in string.gfind(to, "%d+") do
          local t = tonumber(x)
          OL.swapFrom[t] = OL.swapFrom[t] or {}
          table.insert(OL.swapFrom[t], from)
        end
      end
    end
    local out = {}
    for x in string.gfind(db.swaps[id] or "", "%d+") do table.insert(out, tonumber(x)) end
    return out, OL.swapFrom[id] or {}
  end
  -- how many you have (ClassicAPI counts the bank too, shut or not)
  function OL.Have(id)
    if not GetItemCount then return 0 end
    local ok, n = pcall(GetItemCount, id, true)
    if ok and n then return n end
    return 0
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
  -- the other sections' banners: a loading screen that fits each (names from the MPQ listfiles)
  OL.KINDART = { e = "LoadScreenWinterVeil", c = "LoadScreenHallofLegends", f = "LoadScreenEnviroment",
    p = "LoadScreenPvpBattleground", x = "LoadScreenDeepRunTram", wish = "LoadScreenHallofLegends" }
  function OL.Art(inst)
    local a = inst and OL.ART[inst.key]
    if a then return GLUE .. a end
    if inst and OL.KINDART[inst.kind] then return GLUE .. OL.KINDART[inst.kind] end
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
  -- the item tooltip (ClassicAPI's SetItemByID asks the server for an unseen item without a link), then OctoLoot's
  -- own lines: the recipe (skill, reagents with how many you have), the set, the swaps, how many you have, wishlist
  function OL.ShowTip(owner, it, recipe)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if it.id and it.id > 0 then
      local ok = false
      if GameTooltip.SetItemByID then ok = pcall(GameTooltip.SetItemByID, GameTooltip, it.id) end
      if not ok then pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. it.id .. ":0:0:0") end
    end
    if GameTooltip:NumLines() == 0 then
      local c = OL.QCOLOR[it.q] or OL.QCOLOR[1]
      GameTooltip:AddLine(it.name, c[1], c[2], c[3])
      if it.id and it.id > 0 then GameTooltip:AddLine("Not seen by your game yet - hover again in a moment.", .6, .6, .6, 1) end
    end
    OL.TipLines(GameTooltip, it, recipe)
    GameTooltip:Show()
  end
  OL.SKILLNAME = { [164] = "Blacksmithing", [165] = "Leatherworking", [171] = "Alchemy", [197] = "Tailoring", [202] = "Engineering",
    [333] = "Enchanting", [186] = "Mining", [182] = "Herbalism", [393] = "Skinning", [755] = "Jewelcrafting", [185] = "Cooking",
    [129] = "First Aid", [356] = "Fishing", [40] = "Poisons" }
  function OL.TipLines(tt, it, recipe)
    if recipe then
      tt:AddLine(" ")
      local lv = {}
      for n in string.gfind(recipe.levels or "", "%d+") do table.insert(lv, n) end
      tt:AddLine((OL.SKILLNAME[recipe.skill or 0] or "Recipe") .. (lv[1] and ("  |cffff8040" .. lv[1] .. "|r") or "")
        .. (lv[2] and ("  |cffffff00" .. lv[2] .. "|r") or "") .. (lv[3] and ("  |cff40c040" .. lv[3] .. "|r") or "")
        .. (lv[4] and ("  |cff808080" .. lv[4] .. "|r") or ""), 1, .82, .2)
      for _, rg in ipairs(recipe.reagents) do
        local ri = OL.Item(rg.id)
        local have = OL.Have(rg.id)
        local c = (have >= rg.n) and "|cff55ff77" or "|cffff6655"
        tt:AddDoubleLine((ri and ri.name or ("Item " .. rg.id)) .. " x" .. rg.n, c .. have .. "|r", .9, .9, .9, 1, 1, 1)
      end
    end
    if it.id and it.id > 0 then
      local set = OL.SetOf(it.id)
      local to, from = OL.Swaps(it.id)
      local have = OL.Have(it.id)
      if set or table.getn(to) > 0 or table.getn(from) > 0 or have > 0 or OL.Wished(it.id) then tt:AddLine(" ") end
      if set then tt:AddLine("Set: " .. set.name .. " (" .. table.getn(set.pieces) .. " pieces)", .4, .8, 1) end
      if table.getn(to) > 0 then tt:AddLine("Swaps for " .. table.getn(to) .. (table.getn(to) == 1 and " item" or " items"), .4, .8, 1) end
      if table.getn(from) > 0 then tt:AddLine("Comes from swapping " .. table.getn(from) .. (table.getn(from) == 1 and " item" or " items"), .4, .8, 1) end
      if have > 0 then tt:AddLine("You have " .. have, .35, 1, .5) end
      if OL.Wished(it.id) then tt:AddLine("On your wishlist", 1, .82, .2) end
      tt:AddLine("Click: everything about it   Alt-click: wishlist", .5, .51, .55)
    end
  end
  function OL.ClickItem(it, button)
    if IsAltKeyDown() then
      OL.ToggleWish(it.id)
    elseif IsShiftKeyDown() then
      local box = ChatFrameEditBox or (DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox)
      if box then
        if not box:IsVisible() then box:Show() end
        box:Insert(OL.Link(it))
      end
    elseif IsControlKeyDown() then
      if DressUpItemLink then DressUpItemLink("item:" .. it.id .. ":0:0:0") end
    elseif button == "RightButton" then
      OL.SearchFor(it.name)
    else
      OL.ShowItem(it)
    end
  end

  -- ---------------------------------------------------------------- wishlist and QuickLook (per character)

  function OL.WishList()
    local out, seen = {}, {}
    for x in string.gfind(C.octoloot.wish or "", "%d+") do
      local id = tonumber(x)
      if not seen[id] then seen[id] = true table.insert(out, id) end
    end
    return out
  end
  function OL.Wished(id)
    if not id then return false end
    return string.find("," .. (C.octoloot.wish or "") .. ",", "," .. id .. ",", 1, true) ~= nil
  end
  function OL.ToggleWish(id)
    if not id or id <= 0 then return end
    local list, out = OL.WishList(), {}
    local had = false
    for _, x in ipairs(list) do if x == id then had = true else table.insert(out, x) end end
    if not had then table.insert(out, id) end
    C.octoloot.wish = table.concat(out, ",")
    local it = OL.Item(id)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd133OctoLoot|r: " .. (it and OL.Link(it) or ("item " .. id)) .. (had and " off your wishlist." or " on your wishlist."))
    if OL.inst and OL.inst.kind == "wish" then
      OL.inst = OL.WishPage()
      OL.boss = OL.inst.bosses[1]
    end
    if OL.frame and OL.frame:IsShown() then OL.PaintMain() end
  end
  -- the wishlist as one page group: every wished item with where it comes from
  function OL.WishPage()
    local db = OL.LoadPages()
    local page = { key = "wish", name = "Wishlist", kind = "wish", lo = 0, hi = 0, players = 0, where = "", icon = "INV_Misc_Note_02", bosses = {} }
    local toks = {}
    for _, id in ipairs(OL.WishList()) do table.insert(toks, tostring(id)) end
    table.insert(page.bosses, { name = "Everything on it", page = true, wish = true, lootText = table.concat(toks, ","), inst = page })
    if db then db.by.wish = page end
    return page
  end

  -- QuickLook slots: C.octoloot.quick = "key^boss|key^boss|..." (6)
  function OL.QuickList()
    local out = {}
    local s = C.octoloot.quick or ""
    for part in string.gfind(s .. "|", "([^|]*)|") do table.insert(out, part) end
    for i = 1, 6 do out[i] = out[i] or "" end
    return out
  end
  function OL.QuickEntry(i)
    local q = OL.QuickList()[i]
    if not q or q == "" then return nil end
    local _, _, key, boss = string.find(q, "^([^%^]*)%^?(.*)$")
    local db = OL.LoadPages()
    local inst = db and db.by[key]
    local title = inst and inst.name or key
    if boss and boss ~= "" then title = title .. " - " .. boss end
    return { key = key, boss = boss, title = title }
  end
  function OL.Pin(inst, boss)
    if not inst or inst.kind == "wish" then return end
    local list = OL.QuickList()
    local want = inst.key .. "^" .. (boss and boss.name or "")
    for i = 1, 6 do
      if list[i] == want then list[i] = "" C.octoloot.quick = table.concat(list, "|") OL.PaintQuick() return end
    end
    for i = 1, 6 do
      if list[i] == "" then
        list[i] = want
        C.octoloot.quick = table.concat(list, "|")
        OL.PaintQuick()
        return
      end
    end
    UIErrorsFrame:AddMessage("QuickLook is full - right-click a slot to free it.", 1, .82, 0)
  end
  function OL.Unpin(i)
    local list = OL.QuickList()
    list[i] = ""
    C.octoloot.quick = table.concat(list, "|")
    OL.PaintQuick()
  end
  function OL.OpenQuick(i)
    local e = OL.QuickEntry(i)
    if not e then return end
    local db = OL.LoadPages()
    local inst = db and db.by[e.key]
    if not inst then return end
    local boss
    for _, b in ipairs(inst.bosses) do if b.name == e.boss then boss = b end end
    OL.Select(inst, boss)
  end
  function OL.PaintQuick()
    local f = OL.frame
    if not f then return end
    local r1, g1, b1 = Accent()
    for i = 1, 6 do
      local q = f.quick[i]
      local e = OL.QuickEntry(i)
      if e then
        local db = OL.LoadPages()
        local inst = db and db.by[e.key]
        if inst and inst.icon then
          q.art:SetTexture(ICONS .. inst.icon) q.art:SetTexCoord(.07, .93, .07, .93)
        else
          q.art:SetTexture(OL.Art(inst)) q.art:SetTexCoord(.3, .62, .35, .6)
        end
        q.art:Show()
        q.num:SetText("")
        Paint(q.edge, r1, g1, b1, 1)
      else
        q.art:Hide()
        q.num:SetText("+")
        Paint(q.edge, P.line[1], P.line[2], P.line[3], 1)
      end
    end
  end

  function OL.PickKind(kind)
    OL.kind = kind
    OL.listTop = 0
    if kind == "wish" then OL.Select(OL.WishPage()) return end
    if OL.PAGEKINDS[kind] then OL.LoadPages() end
    OL.PaintList()
    -- open the first group of a section that is not showing yet
    if not OL.inst or OL.inst.kind ~= kind then
      local list = OL.Visible()
      if list[1] then OL.Select(list[1]) end
    end
  end

  -- ---------------------------------------------------------------- one item, interlinked
  -- (26 Nov 2026, user: "when i click on a set item ... it shows me the other sets i can switch it for ... it should all
  -- be interlinked and fast") everything about one item: what it swaps for and from, its set, where it drops or is
  -- sold or earned, the recipe that makes it, what it is used to make. Every line opens what it names.
  function OL.ShowItem(it)
    if not it or not it.id or it.id <= 0 then return end
    if OL.results and OL.results.view == it then return end
    OL.LoadPages()
    -- a stack, so Back walks through every item opened from another (at most 20 kept)
    OL.backs = OL.backs or {}
    table.insert(OL.backs, { inst = OL.inst, boss = OL.boss, results = OL.results, top = OL.itemTop })
    if table.getn(OL.backs) > 20 then table.remove(OL.backs, 1) end
    OL.results = { view = it }
    OL.itemTop = 0
    if OL.frame and OL.frame:IsShown() then OL.PaintMain() else OL.Show() end
  end
  -- a quest's guide (octoloot-quests.lua), on the same Back stack as an item's page
  function OL.ShowQuest(id)
    if not id then return end
    if OL.results and OL.results.quest == id then return end
    OL.backs = OL.backs or {}
    table.insert(OL.backs, { inst = OL.inst, boss = OL.boss, results = OL.results, top = OL.itemTop })
    if table.getn(OL.backs) > 20 then table.remove(OL.backs, 1) end
    OL.results = { quest = id }
    OL.itemTop = 0
    if OL.frame and OL.frame:IsShown() then OL.PaintMain() else OL.Show() end
  end
  function OL.Back()
    local b = OL.backs and table.remove(OL.backs)
    OL.results = b and b.results or nil
    if b and b.inst then OL.inst, OL.boss = b.inst, b.boss end
    OL.itemTop = b and b.top or 0
    OL.PaintMain()
  end
  -- what an item is a reagent for: reagent id -> { recipe ids } (made when first asked)
  function OL.UsedIn(id)
    local db = OL.LoadPages()
    if not db then return {} end
    if not OL.usedIn then
      OL.usedIn = {}
      for sid, line in pairs(db.recipes) do
        local text = type(line) == "table" and "" or line
        for rid in string.gfind(text, "%^?(%d+)x%d+") do
          local r = tonumber(rid)
          OL.usedIn[r] = OL.usedIn[r] or {}
          table.insert(OL.usedIn[r], sid)
        end
        if type(line) == "table" then
          for _, rg in ipairs(line.reagents) do
            OL.usedIn[rg.id] = OL.usedIn[rg.id] or {}
            table.insert(OL.usedIn[rg.id], sid)
          end
        end
      end
    end
    return OL.usedIn[id] or {}
  end
  function OL.ItemEntries(it)
    local out = {}
    table.insert(out, { head = it.name, big = true, note = OL.QNAME[it.q] .. "  " .. OL.TypeText(it) })
    table.insert(out, { item = it })
    local to, from = OL.Swaps(it.id)
    if table.getn(to) > 0 then
      table.insert(out, { head = "Swap it for", note = "hand it in for one of these" })
      for _, x in ipairs(to) do local xi = OL.Item(x) if xi then table.insert(out, { item = xi, view = true }) end end
    end
    if table.getn(from) > 0 then
      table.insert(out, { head = "Comes from swapping", note = "one of these is handed in for it" })
      for _, x in ipairs(from) do local xi = OL.Item(x) if xi then table.insert(out, { item = xi, view = true }) end end
    end
    local set = OL.SetOf(it.id)
    if set then
      table.insert(out, { head = "Set: " .. set.name, note = table.getn(set.pieces) .. " pieces" })
      for _, x in ipairs(set.pieces) do local xi = OL.Item(x) if xi then table.insert(out, { item = xi, view = true }) end end
    end
    local src = OL.Sources()[it.id] or {}
    if table.getn(src) > 0 then
      table.insert(out, { head = "Where it comes from", note = "click one to open it" })
      for _, s in ipairs(src) do
        local b = s.boss
        local where = b.inst.name
        local sub = b.page and (b.name ~= b.inst.name and (b.inst.name .. "  -  " .. b.name) or b.inst.name) or (b.name .. "  -  " .. b.inst.name)
        table.insert(out, { title = b.page and (s.spell and "Made by a recipe" or b.name) or b.name, sub = sub,
          icon = b.inst.icon and (ICONS .. b.inst.icon) or OL.Art(b.inst), art = not b.inst.icon, pct = s.pct, group = s.group,
          where = where, go = function() OL.results = nil OL.Select(b.inst, b) end })
      end
    end
    local used = OL.UsedIn(it.id)
    if table.getn(used) > 0 then
      table.insert(out, { head = "Used to make", note = table.getn(used) .. (table.getn(used) == 1 and " recipe" or " recipes") })
      for i = 1, math.min(table.getn(used), 40) do
        local r = OL.Recipe(used[i])
        if r then
          local mi = r.made and OL.Item(r.made) or { id = 0, q = 1, name = r.name, icon = "Trade_Engraving" }
          table.insert(out, { item = mi, recipe = r, view = true })
        end
      end
    end
    return out
  end

  -- ---------------------------------------------------------------- search

  -- instances, bosses and items whose name has the text: { { kind = "inst" | "boss" | "item", ... } }
  function OL.Search(text)
    local db = OL.LoadPages()
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
    for id, line in pairs(OL.ItemIndex()) do
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
    -- (26 Nov 2026, user with Atlas-CFM's bar: "PvP sets, collections, pvp rewards, crafting ... EVERYTHING") nine
    -- sections in three rows; the five past World read their pages the first time they are picked
    OL.KINDS = { { "d", "Dungeons" }, { "r", "Raids" }, { "w", "World" }, { "e", "Events" }, { "c", "Collections" },
      { "f", "Factions" }, { "p", "PvP" }, { "x", "Crafting" }, { "wish", "Wishlist" } }
    local TW = (LEFT_W - 24) / 3
    for i, k in ipairs(OL.KINDS) do
      local kk = k[1]
      local b = TextButton(left, k[2], TW, 24)
      local col, row = math.mod(i - 1, 3), math.floor((i - 1) / 3)
      b:SetPoint("TOPLEFT", left, "TOPLEFT", 8 + col * (TW + 4), -10 - row * 28)
      b:SetScript("OnClick", function() OL.PickKind(kk) end)
      f.kinds[kk] = b
    end
    -- QuickLook: six pages of your own at the foot of the list (right-click a list or page row to pin / unpin)
    f.quick = {}
    local QW = (LEFT_W - 12 - 5 * 4) / 6
    for i = 1, 6 do
      local q = CreateFrame("Button", nil, left)
      q:SetWidth(QW) q:SetHeight(34)
      q:SetPoint("BOTTOMLEFT", left, "BOTTOMLEFT", 6 + (i - 1) * (QW + 4), 8)
      q:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      q.bg = Fill(q, P.field, 1)
      q.bg:SetAllPoints(q)
      q.edge = Edge(q, P.line, 1)
      q.art = q:CreateTexture(nil, "ARTWORK")
      q.art:SetPoint("TOPLEFT", q, "TOPLEFT", 1, -1)
      q.art:SetPoint("BOTTOMRIGHT", q, "BOTTOMRIGHT", -1, 1)
      q.num = Font(q:CreateFontString(nil, "OVERLAY"), 11, { .5, .51, .55 }, FONT .. "Expressway.ttf")
      q.num:SetPoint("CENTER", q, "CENTER", 0, 0)
      q.hl = Fill(q, { 1, 1, 1 }, .12, "HIGHLIGHT")
      q.hl:SetAllPoints(q)
      local qi = i
      q:SetScript("OnClick", function()
        if arg1 == "RightButton" then OL.Unpin(qi) else OL.OpenQuick(qi) end
      end)
      q:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        local e = OL.QuickEntry(qi)
        if e then
          GameTooltip:AddLine("QuickLook " .. qi .. ": " .. e.title, 1, .82, .2)
          GameTooltip:AddLine("Click: jump straight back to it.  Right-click: take it off.", .8, .8, .8, 1)
        else
          GameTooltip:AddLine("QuickLook " .. qi .. " (empty)", 1, .82, .2)
          GameTooltip:AddLine("Six shortcuts to the pages you use most - your raid's bosses, a faction's rewards, a crafting "
            .. "list. Keep one here by right-clicking it in the list, or open it and press Pin at the banner's top right.", .8, .8, .8, 1)
        end
        GameTooltip:Show()
      end)
      q:SetScript("OnLeave", function() GameTooltip:Hide() end)
      f.quick[i] = q
    end
    -- (26 Nov 2026, user: "how does this even work what is it meant for") it says so above the buttons
    f.quickLabel = Font(left:CreateFontString(nil, "OVERLAY"), 10, { .55, .56, .6 })
    f.quickLabel:SetPoint("BOTTOMLEFT", f.quick[1], "TOPLEFT", 1, 4)
    f.quickLabel:SetText("QUICKLOOK  -  right-click a list row or press Pin to keep it here")
    f.rows = {}
    local LIST_TOP = 10 + 3 * 28 + 4
    local nrows = math.floor((HEIGHT - 52 - LIST_TOP - 66) / ROW_H)
    for i = 1, nrows do
      local r = CreateFrame("Button", nil, left)
      r:SetHeight(ROW_H - 2)
      r:SetPoint("TOPLEFT", left, "TOPLEFT", 6, -LIST_TOP - (i - 1) * ROW_H)
      r:SetPoint("TOPRIGHT", left, "TOPRIGHT", -7, -LIST_TOP - (i - 1) * ROW_H)
      r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
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
      -- a group's own icon (events, collections, factions, PvP, crafting) in place of the loading screen strip
      r.pic = r:CreateTexture(nil, "ARTWORK")
      r.pic:SetWidth(24) r.pic:SetHeight(24)
      r.pic:SetPoint("LEFT", r, "LEFT", 6, 0)
      r.pic:SetTexCoord(.07, .93, .07, .93)
      r:SetScript("OnClick", function()
        if not this.inst then return end
        if arg1 == "RightButton" then OL.Pin(this.inst) else OL.Select(this.inst) end
      end)
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
    -- (26 Nov 2026, user with Naowh's Dungeon Journal) the instance's quests, with their chains and waypoints
    local VIEWS = { { "loot", "Loot", 70 }, { "quests", "Quests", 96 }, { "map", "Map", 60 }, { "ent", "Entrance", 84 } }
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
    -- Back: out of an item's own page to what was open before it
    f.backBtn = TextButton(ban, "< Back", 76, 24)
    f.backBtn:SetPoint("BOTTOMRIGHT", ban, "BOTTOMRIGHT", -16, 16)
    f.backBtn:SetScript("OnClick", function() OL.Back() end)
    f.backBtn:Hide()
    -- the wishlist star and QuickLook pin for what is open
    f.pinBtn = TextButton(ban, "Pin", 50, 24)
    f.pinBtn:SetPoint("TOPRIGHT", ban, "TOPRIGHT", -16, -16)
    f.pinBtn:SetScript("OnClick", function() if OL.inst then OL.Pin(OL.inst, OL.boss) end end)
    Tip(f.pinBtn, "Pin to QuickLook", "Puts what is open (with its boss or page) on one of the six QuickLook buttons at the "
      .. "foot of the list. Click again to take it off.")
    Tip(f.views.quests, "Quests", "This instance's quests for your side: in your log, ready to take, needing a quest first, done. "
      .. "Click one for its guide: the whole chain, who gives it and where, waypoints with pfQuest's arrow, the rewards.")
    -- share every quest of this instance in your log with the group
    f.shareBtn = TextButton(ban, "Share quests", 104, 24)
    f.shareBtn:SetPoint("RIGHT", f.pinBtn, "LEFT", -6, 0)
    f.shareBtn:SetScript("OnClick", function() if OL.quests and OL.inst then OL.quests.ShareAll(OL.inst) end end)
    Tip(f.shareBtn, "Share quests", "Shares every quest of this instance that is in your log with your group, one a second.")
    f.shareBtn:Hide()

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
    loot.keys:SetText("Click: all about it   Shift: link   Ctrl: try on   Alt: wishlist   Right-click: search   Wheel: scroll")
    loot.empty = Font(loot:CreateFontString(nil, "OVERLAY"), 13, P.dim)
    loot.empty:SetPoint("CENTER", loot, "CENTER", 0, 0)
    loot.empty:SetWidth(440)
    -- (26 Nov 2026, user: "look how the tables are layed out ... when it says one of these 12 they are out of line")
    -- a table of lines: a heading runs across the whole width, items go two to a line under it (left, then right),
    -- so a group never starts in one column and ends in the other
    f.items, f.cells, f.heads = {}, {}, {}
    local cols, per = 2, math.floor((HEIGHT - 52 - BANNER_H - 44 - 24) / ITEM_H)
    local colW = (WIDTH - 2 - LEFT_W - BOSS_W - 40) / cols
    for i = 1, per do
      f.cells[i] = {}
      local hd = CreateFrame("Frame", nil, loot)
      hd:SetHeight(ITEM_H - 4)
      hd:SetPoint("TOPLEFT", loot, "TOPLEFT", 14, -40 - (i - 1) * ITEM_H)
      hd:SetWidth(colW * cols - 6)
      hd:EnableMouseWheel(true)
      hd:SetScript("OnMouseWheel", function() OL.ScrollItems(arg1) end)
      hd.text = Font(hd:CreateFontString(nil, "OVERLAY"), 12, { 1, .82, .2 })
      hd.text:SetPoint("BOTTOMLEFT", hd, "BOTTOMLEFT", 4, 8)
      hd.note = Font(hd:CreateFontString(nil, "OVERLAY"), 11, P.dim)
      hd.note:SetPoint("LEFT", hd.text, "RIGHT", 10, 0)
      hd.rule = Fill(hd, { 1, .82, .2 }, .35, "ARTWORK")
      hd.rule:SetPoint("BOTTOMLEFT", hd, "BOTTOMLEFT", 4, 3)
      hd.rule:SetPoint("BOTTOMRIGHT", hd, "BOTTOMRIGHT", -4, 3)
      hd.rule:SetHeight(1)
      hd.para = Font(hd:CreateFontString(nil, "OVERLAY"), 12, { .88, .88, .9 })
      hd.para:SetPoint("TOPLEFT", hd, "TOPLEFT", 6, -2)
      hd.para:SetWidth(colW * cols - 18)
      hd.para:SetHeight(ITEM_H - 6)
      hd.para:SetJustifyH("LEFT")
      hd.para:SetJustifyV("TOP")
      hd.para:Hide()
      hd:EnableMouse(true)
      hd:SetScript("OnEnter", function()
        if not this.fullText then return end
        GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
        GameTooltip:AddLine(this.fullText, 1, 1, 1, 1)
        GameTooltip:Show()
      end)
      hd:SetScript("OnLeave", function() GameTooltip:Hide() end)
      hd:Hide()
      f.heads[i] = hd
      for c = 1, cols do
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
        r:SetScript("OnEnter", function()
          local e = this.entry
          if e and e.quest and OL.quests then OL.quests.Tip(this, e) return end
          if e and e.item then OL.ShowTip(this, e.item, e.recipe) end
          if e and e.where then
            if not e.item then GameTooltip:SetOwner(this, "ANCHOR_RIGHT") GameTooltip:AddLine(e.title or "", 1, .82, .2) end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Click: open " .. e.where, .4, .8, 1)
            GameTooltip:Show()
          end
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- a plain click on an item = everything about it (OL.ShowItem); Shift / Ctrl / Alt / right-click as the keys say;
        -- a search result or a "where it comes from" line opens what it names
        r:SetScript("OnClick", function()
          local e = this.entry
          if not e then return end
          if e.quest and OL.quests then OL.quests.Click(e, arg1) return end
          if e.item and (e.view or not e.go or IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown() or arg1 == "RightButton") then
            OL.ClickItem(e.item, arg1)
            return
          end
          if e.go then e.go() end
        end)
        r:EnableMouseWheel(true)
        r:SetScript("OnMouseWheel", function() OL.ScrollItems(arg1) end)
        table.insert(f.items, r)
        f.cells[i][c] = r
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
    if OL.kind == "wish" then return { OL.WishPage() } end
    if OL.PAGEKINDS[OL.kind or "d"] then db = OL.LoadPages() end
    for _, inst in ipairs(db and db.list or {}) do
      if inst.kind == (OL.kind or "d") then table.insert(out, inst) end
    end
    if OL.kind == "d" or OL.kind == "r" or not OL.kind then
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
        local paged = OL.PAGEKINDS[inst.kind] or inst.kind == "wish"
        local info = (inst.players > 0 and (inst.players .. " players") or "")
        if inst.where and inst.where ~= "" and inst.kind ~= "w" then info = info .. (info ~= "" and "  -  " or "") .. inst.where end
        if paged and info == "" then
          local n = table.getn(inst.bosses)
          info = n == 1 and "1 page" or (n .. " pages")
        end
        if inst == here then info = "|cff55ff77You are here|r  " .. info end
        r.info:SetText(info)
        if not paged and (inst.lo > 1 or inst.kind ~= "w") then
          local cr, cg, cb = OL.LevelColor(inst.lo, inst.hi)
          r.lvl:SetText(inst.lo == inst.hi and tostring(inst.lo) or (inst.lo .. "-" .. inst.hi))
          r.lvl:SetTextColor(cr, cg, cb)
        else
          r.lvl:SetText("")
        end
        r.name:ClearAllPoints()
        r.info:ClearAllPoints()
        if inst.icon then
          -- a group with its own icon: the icon, no strip
          r.pic:SetTexture(ICONS .. inst.icon)
          r.pic:Show()
          r.art:Hide() r.fade:Hide()
          r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 38, -4)
          r.info:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 38, 4)
        else
          r.pic:Hide()
          r.art:SetTexture(OL.Art(inst))
          r.art:SetTexCoord(.1, .55, .38, .5)
          r.art:Show() r.fade:Show()
          r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 10, -4)
          r.info:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 10, 4)
        end
        r.name:SetPoint("RIGHT", r, "RIGHT", -40, 0)
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
    -- a section's group opens on its first page (a dungeon on "Everything here")
    if not boss and (OL.PAGEKINDS[inst.kind] or inst.kind == "wish") then boss = inst.bosses[1] end
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
    local hasBack = OL.backs and table.getn(OL.backs) > 0
    if hasBack and OL.results and OL.results.view then f.backBtn:Show() else f.backBtn:Hide() end
    if f.shareBtn then f.shareBtn:Hide() end
    if hasBack and OL.results and OL.results.quest then f.backBtn:Show() end
    if OL.results and OL.results.quest then
      -- a quest's guide: the instance's own banner behind its name
      local qid = OL.results.quest
      local Q = OL.quests
      local d = Q and Q.Data(qid)
      ban.art:SetTexture(OL.Art(OL.inst))
      ban.art:SetTexCoord(0, 1, .3, .62)
      local r, g, b2 = 1, 1, 0
      if Q then r, g, b2 = Q.LevelColor(d and d.lvl) end
      ban.name:SetText(string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b2 * 255, Q and Q.Title(qid) or ""))
      ban.meta:SetText("Quest guide   |cff666870/|r   level " .. (d and d.lvl or "?") .. (d and d.min and ("   |cff666870/|r   from level " .. d.min) or "")
        .. (OL.inst and ("   |cff666870/|r   " .. OL.inst.name) or ""))
      ban.badge:Hide()
      ban.youare:SetText("")
      for _, v in pairs(f.views) do v:Hide() end
      return
    end
    if OL.results then
      local view = OL.results.view
      ban.art:SetTexture(GLUE .. (view and "LoadScreenHallofLegends" or "LoadScreenDungeon"))
      ban.art:SetTexCoord(0, 1, .3, .62)
      if view then
        local c = OL.QCOLOR[view.q] or OL.QCOLOR[1]
        ban.name:SetText(string.format("|cff%02x%02x%02x%s|r", c[1] * 255, c[2] * 255, c[3] * 255, view.name))
        local bits = { OL.QNAME[view.q] or "" }
        if OL.TypeText(view) ~= "" then table.insert(bits, OL.TypeText(view)) end
        if view.il and view.il > 0 then table.insert(bits, "item level " .. view.il) end
        if view.rl and view.rl > 1 then table.insert(bits, "requires level " .. view.rl) end
        ban.meta:SetText(table.concat(bits, "   |cff666870/|r   "))
      else
        ban.name:SetText("Search")
        ban.meta:SetText(table.getn(OL.results) .. " found for \"" .. (OL.searchText or "") .. "\"")
      end
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
    local paged = OL.PAGEKINDS[inst.kind] or inst.kind == "wish"
    if paged then
      local SECT = { e = "World event", c = "Collection", f = "Faction", p = "PvP rewards", x = "Crafting", wish = "Your wishlist" }
      table.insert(parts, SECT[inst.kind])
    elseif inst.kind ~= "w" then
      table.insert(parts, inst.lo == inst.hi and ("Level " .. inst.lo) or ("Levels " .. inst.lo .. " - " .. inst.hi))
    end
    if inst.players > 0 then table.insert(parts, inst.players .. " players") end
    if inst.where and inst.where ~= "" and inst.kind ~= "w" then table.insert(parts, inst.where) end
    local nb = table.getn(inst.bosses)
    if paged then
      if inst.kind == "wish" then
        nb = table.getn(OL.WishList())
        table.insert(parts, nb == 1 and "1 item" or (nb .. " items"))
      else
        table.insert(parts, nb == 1 and "1 page" or (nb .. " pages"))
      end
    else
      table.insert(parts, nb .. " bosses")
    end
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
    -- the quests button with how many you can still do here (in your log or ready to take)
    local Q = OL.quests
    local todo, total = 0, 0
    if Q and not paged then todo, total = Q.ToDo(inst) end
    if total > 0 then
      f.views.quests.text:SetText("Quests " .. (todo > 0 and ("|cffffd133" .. todo .. "|r") or ("|cff55ff77" .. total .. "|r")))
      f.views.quests:Show()
      if todo > 0 then ban.meta:SetText(ban.meta:GetText() .. "   |cff666870/|r   |cffffd133" .. todo .. " quests to do|r") end
    else
      f.views.quests:Hide()
      if OL.view == "quests" then OL.view = "loot" end
    end
    if OL.view == "quests" and GetNumPartyMembers and (GetNumPartyMembers() or 0) > 0 then f.shareBtn:Show() else f.shareBtn:Hide() end
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
    -- "Everything here" for dungeons, raids and world bosses; a section's pages stand on their own
    if not (inst and (OL.PAGEKINDS[inst.kind] or inst.kind == "wish")) then table.insert(list, false) end
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
    if OL.results and OL.results.view then return OL.ItemEntries(OL.results.view) end
    if OL.results and OL.results.quest and OL.quests then return OL.quests.PageEntries(OL.results.quest, OL.inst) end
    if not OL.results and OL.view == "quests" and OL.quests and OL.inst then return OL.quests.ListEntries(OL.inst) end
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
      local loot = OL.Loot(b)
      local grouped = false
      for _, g in ipairs(loot) do if g.chance then grouped = true end end
      for _, g in ipairs(loot) do
        local count = table.getn(g.items)
        if g.title then
          table.insert(out, { head = g.title })
        elseif g.chance then
          local txt, note
          if count == 1 then txt = "Rolled once a kill"
          else txt = "One of these " .. count end
          if g.chance < 100 then note = "the roll happens in " .. g.chance .. "% of kills"
          elseif count > 1 then note = "one of them drops every kill" end
          table.insert(out, { head = txt, note = note })
        elseif grouped then
          table.insert(out, { head = "Drops on their own", note = "each has its own chance" })
        end
        for _, e in ipairs(g.items) do
          if e.spell then
            -- a recipe: the item it makes (an enchant makes none: its name and the enchanting picture)
            local r = OL.Recipe(e.spell)
            if r then
              local it = r.made and OL.Item(r.made) or { id = 0, q = 1, name = r.name, icon = "Trade_Engraving" }
              table.insert(out, { item = it, recipe = r })
            end
          else
            local it = OL.Item(e.id)
            if it and (OL.boss or not seen[e.id .. ":" .. b.name]) then
              seen[e.id .. ":" .. b.name] = true
              table.insert(out, { item = it, pct = e.pct, group = g.chance, note = e.note })
            end
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

  -- the entries as lines of the table: { head = entry } or { a, b } (two items side by side)
  function OL.Lines(list)
    local lines, pend = {}, nil
    for _, e in ipairs(list or {}) do
      if e.head or e.text then
        if pend then table.insert(lines, { pend }) pend = nil end
        table.insert(lines, { head = e })
      elseif pend then
        table.insert(lines, { pend, e })
        pend = nil
      else
        pend = e
      end
    end
    if pend then table.insert(lines, { pend }) end
    return lines
  end

  local function PaintCell(r, e)
    r.entry = e
    if not e then r:Hide() return end
        if e.quest then
          -- a quest: its mark, its name in the quest log's level colour, where you are with it
          local Qm = OL.quests
          local cr, cg, cb = Qm.LevelColor(e.lvl)
          r.icon:SetTexture(Qm.ICON[e.state] or Qm.ICON.ready)
          r.icon:SetTexCoord(0, 1, 0, 1)
          if e.state == "locked" or e.state == "low" then r.icon:SetVertexColor(.5, .5, .5) else r.icon:SetVertexColor(1, 1, 1) end
          local nm = (e.step and (e.step .. ". ") or "") .. "[" .. (e.lvl or "?") .. "] " .. Qm.Title(e.quest)
          if e.here then nm = "> " .. nm end
          r.name:SetText(nm)
          r.name:SetTextColor(cr, cg, cb)
          local edge = e.state == "done" and { .3, .8, .4 } or (e.state == "log" and { 1, .82, .2 } or { .35, .36, .4 })
          Paint(r.qedge, edge[1], edge[2], edge[3], 1)
          Grad(r.glow, edge[1], edge[2], edge[3], e.here and .25 or .1, 0, true)
          r.info:SetText(e.info or "")
          r.pct:SetText(e.right or "")
          r:Show()
          return
        end
        r.icon:SetVertexColor(1, 1, 1)
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
          if e.note and e.note ~= "" then info = info .. "   |cffc8a860" .. e.note .. "|r" end
          if it.id and it.id > 0 then
            if OL.Wished(it.id) then info = "|cffffd133*|r " .. info end
            local have = OL.Have(it.id)
            if have > 0 then info = info .. "   |cff55ff77have " .. have .. "|r" end
          end
          r.info:SetText(info)
          if e.recipe then
            -- a recipe: where it turns yellow, in its colour against your skill when the profession is known
            local lv = {}
            for n in string.gfind(e.recipe.levels or "", "%d+") do table.insert(lv, tonumber(n)) end
            r.pct:SetText(lv[1] and ("|cffff8040" .. lv[1] .. "|r") or "")
            if e.recipe.skill and OL.SKILLNAME[e.recipe.skill] then
              r.info:SetText(OL.SKILLNAME[e.recipe.skill] .. (lv[2] and ("   |cffffff00" .. lv[2] .. "|r |cff40c040" .. (lv[3] or "") .. "|r |cff808080" .. (lv[4] or "") .. "|r") or ""))
            end
          else
            r.pct:SetText(PctText(e.pct, e.group))
          end
        else
          r.icon:SetTexture(e.icon)
          if e.art then r.icon:SetTexCoord(.3, .62, .3, .62)
          elseif e.plain then r.icon:SetTexCoord(0, 1, 0, 1)
          else r.icon:SetTexCoord(.07, .93, .07, .93) end
          r.name:SetText(e.title)
          r.name:SetTextColor(1, .82, .2)
          Paint(r.qedge, .4, .41, .45, 1)
          Grad(r.glow, 1, .82, .2, .1, 0, true)
          r.info:SetText(e.sub or "")
          r.pct:SetText("|cff66ccff>|r")
        end
    r:Show()
  end

  function OL.PaintItems()
    local f = OL.frame
    local lines = OL.lines or {}
    local n = table.getn(f.heads)
    OL.itemTop = math.max(0, math.min(OL.itemTop or 0, math.max(0, table.getn(lines) - n)))
    OL.missing = false
    for i = 1, n do
      local line = lines[i + OL.itemTop]
      local hd, cells = f.heads[i], f.cells[i]
      if line and line.head then
        local e = line.head
        if e.text then
          -- a paragraph (a quest's objective): up to three lines, the whole of it on hover
          hd.text:SetText("")
          hd.note:SetText("")
          hd.para:SetText(e.text)
          hd.para:Show()
          hd.rule:Hide()
          hd.fullText = e.text
        else
          hd.para:Hide()
          hd.rule:Show()
          hd.fullText = nil
          hd.text:SetText(e.big and ("|cffffffff" .. e.head .. "|r") or e.head)
          hd.text:SetFont(hd.text:GetFont(), e.big and 15 or 12, "")
          hd.note:SetText(e.note or "")
          hd.rule:SetVertexColor(1, .82, .2, e.big and .6 or .3)
        end
        hd:Show()
        PaintCell(cells[1], nil)
        PaintCell(cells[2], nil)
      else
        hd:Hide()
        PaintCell(cells[1], line and line[1])
        PaintCell(cells[2], line and line[2])
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
    OL.lines = OL.Lines(OL.entries)
    local loot = f.loot
    if OL.results and OL.results.quest then
      loot.head:SetText("Quest guide")
      loot.headInfo:SetText("waypoints, the chain step by step, what it asks for, the rewards")
    elseif not OL.results and OL.view == "quests" then
      local todo, total = 0, 0
      if OL.quests and inst then todo, total = OL.quests.ToDo(inst) end
      loot.head:SetText("Quests")
      loot.headInfo:SetText(total .. " here for your side  -  " .. todo .. " still to do")
    elseif OL.results and OL.results.view then
      loot.head:SetText("All about it")
      loot.headInfo:SetText("swaps, set, where it comes from, what it makes - click any line")
    elseif OL.results then
      loot.head:SetText("Search")
      loot.headInfo:SetText("click a line to open it")
    elseif OL.boss then
      loot.head:SetText(OL.boss.name)
      local cnt = 0
      for _, g in ipairs(OL.Loot(OL.boss)) do cnt = cnt + table.getn(g.items) end
      local word = OL.boss.page and (cnt == 1 and " item" or " items") or " drops"
      loot.headInfo:SetText(cnt .. word .. (OL.boss.obj and "  -  a chest or object" or ""))
    else
      loot.head:SetText(inst and inst.name or "")
      loot.headInfo:SetText("every boss's drops - pick a boss on the left for one")
    end
    if f.pinBtn then
      if OL.results or not inst or inst.kind == "wish" then f.pinBtn:Hide() else f.pinBtn:Show() end
    end
    if table.getn(OL.entries) == 0 then
      local msg = OL.results and "Nothing found." or "The server's database lists no drops for this one."
      if inst and inst.kind == "wish" and not OL.results then msg = "Nothing on your wishlist yet. Alt-click any item to put it here." end
      loot.empty:SetText(msg)
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
    -- (26 Nov 2026, user: "the scrolling is abit too much") two lines a notch, was half a column
    OL.itemTop = (OL.itemTop or 0) - (d or 0) * 2
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
    OL.PaintQuick()
    local p = OL.pending
    OL.pending = nil
    if p then
      OL.Select(p[1], p[2])
    elseif OL.results and OL.results.view then
      -- an item opened from outside (a tooltip click, /ol item): its own page
      OL.PaintList()
      OL.PaintMain()
    elseif not OL.inst or not OL.db.by[OL.inst.key] then
      local last = C.octoloot.last or ""
      if not OL.db.by[last] and last ~= "" then OL.LoadPages() end
      local inst = (S("openhere", "1") == "1" and OL.Here()) or OL.db.by[last] or OL.db.by["MoltenCore"] or OL.db.list[1]
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

  -- ---------------------------------------------------------------- world map markers
  -- (26 Nov 2026, Lo5t1ncyb3r: "octoloot is really neat too ... just need the world markers") every dungeon / raid
  -- entrance and world boss on its zone's map: our own pins (tools\mklootpins.c), hover = what it is, click = OctoLoot
  -- on it. Only the data's small M lines are read (OL.Marks), not the whole text, and only while the map is open.
  local PINS = "Interface\\AddOns\\pfUI\\img\\octoloot\\"
  local BADGE = "Interface\\AddOns\\pfUI\\img\\transports\\"
  OL.PINCOLOR = { d = { .35, .85, .55 }, r = { 1, .45, .2 }, w = { .75, .45, 1 } }
  OL.PINART = { d = "dungeon", r = "raid", w = "worldboss" }

  function OL.Marks()
    if OL.marks then return OL.marks end
    local out = {}
    local text = pfUI.octolootData
    if type(text) == "string" then
      for line in string.gfind(text, "\nM%^([^\n]+)") do
        local f = Split(line)
        table.insert(out, { key = f[1], cont = tonumber(f[2]), zone = f[3], x = tonumber(f[4]), y = tonumber(f[5]),
          kind = f[6], note = f[7] ~= "" and f[7] or nil })
      end
    end
    OL.marks = out
    return out
  end
  -- name, levels and size of an instance without reading everything: its I line
  function OL.Meta(key)
    local text = pfUI.octolootData
    if type(text) ~= "string" then return nil end
    local s = string.find(text, "\nI^" .. key .. "^", 1, true) or string.find(text, "I^" .. key .. "^", 1, true)
    if not s then return nil end
    local e = string.find(text, "\n", s + 1, true) or string.len(text)
    local f = Split(string.sub(text, s + (string.sub(text, s, s) == "\n" and 1 or 0), e - 1))
    return { key = f[2], name = f[3], kind = f[4], levels = f[5], players = tonumber(f[6]) or 0, short = f[7] }
  end

  -- the zone the world map shows, by its English name (nil on a continent or the whole world)
  function OL.MapZone()
    local c = GetCurrentMapContinent and GetCurrentMapContinent() or 0
    local z = GetCurrentMapZone and GetCurrentMapZone() or 0
    if not c or c < 1 or not z or z < 1 then return nil end
    local names = { GetMapZones(c) }
    return names[z], c
  end

  OL.pins = {}
  local function NewPin(i)
    local p = CreateFrame("Button", "pfOctoLootPin" .. i, WorldMapButton)
    p:SetWidth(24) p:SetHeight(24)
    p.badge = p:CreateTexture(nil, "BACKGROUND")
    p.badge:SetTexture(BADGE .. "badge")
    p.badge:SetAllPoints(p)
    p.badge:SetVertexColor(.06, .06, .07, .92)
    p.ring = p:CreateTexture(nil, "BORDER")
    p.ring:SetTexture(BADGE .. "ring")
    p.ring:SetAllPoints(p)
    p.glyph = p:CreateTexture(nil, "ARTWORK")
    p.glyph:SetPoint("TOPLEFT", p, "TOPLEFT", 3, -3)
    p.glyph:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -3, 3)
    p:SetScript("OnEnter", function()
      local m = this.mark
      if not m then return end
      this:SetWidth(30) this:SetHeight(30)
      local meta = OL.Meta(m.key)
      local c = OL.PINCOLOR[m.kind] or OL.PINCOLOR.d
      WorldMapTooltip:SetOwner(this, "ANCHOR_RIGHT")
      WorldMapTooltip:AddLine(meta and meta.name or m.key, c[1], c[2], c[3])
      local what = m.kind == "w" and "World boss" or (m.kind == "r" and "Raid" or "Dungeon")
      if m.note == "back" then what = what .. " - back entrance" elseif m.note then what = what .. " - " .. m.note end
      WorldMapTooltip:AddLine(what, .8, .8, .8)
      if meta and m.kind ~= "w" then
        local lv = meta.levels or ""
        WorldMapTooltip:AddLine("Level " .. lv .. (meta.players > 0 and ("   " .. meta.players .. " players") or ""), 1, .82, 0)
      end
      WorldMapTooltip:AddLine("Click: its bosses and loot in OctoLoot", .4, .8, 1)
      WorldMapTooltip:Show()
    end)
    p:SetScript("OnLeave", function()
      this:SetWidth(24) this:SetHeight(24)
      WorldMapTooltip:Hide()
    end)
    p:SetScript("OnClick", function()
      local m = this.mark
      if not m then return end
      local db = OL.Load()
      local inst = db and db.by[m.key]
      if not inst then return end
      local boss
      if m.note and m.note ~= "back" then
        for _, b in ipairs(inst.bosses) do if b.name == m.note then boss = b end end
      end
      if WorldMapFrame and WorldMapFrame:IsShown() then ToggleWorldMap() end
      OL.Select(inst, boss)
    end)
    return p
  end

  function OL.PaintPins()
    local zone = OL.MapZone()
    local show = S("mapmarks", "1") == "1" and zone and WorldMapButton and WorldMapButton:IsVisible()
    local n = 0
    if show then
      local w, h = WorldMapButton:GetWidth() or 0, WorldMapButton:GetHeight() or 0
      for _, m in ipairs(OL.Marks()) do
        if m.zone == zone and m.x and m.y then
          n = n + 1
          local p = OL.pins[n] or NewPin(n)
          OL.pins[n] = p
          p.mark = m
          local c = OL.PINCOLOR[m.kind] or OL.PINCOLOR.d
          p.ring:SetVertexColor(c[1], c[2], c[3], 1)
          p.glyph:SetTexture(PINS .. (OL.PINART[m.kind] or "dungeon"))
          p.glyph:SetVertexColor(1, 1, 1, 1)
          p:SetFrameLevel((WorldMapButton:GetFrameLevel() or 1) + 6)
          p:ClearAllPoints()
          p:SetPoint("CENTER", WorldMapButton, "TOPLEFT", m.x * w, -m.y * h)
          p:Show()
        end
      end
    end
    for i = n + 1, table.getn(OL.pins) do OL.pins[i]:Hide() OL.pins[i].mark = nil end
  end

  -- the map's own event (fires while it is open and its zone changes); nothing is read before the map is opened
  local mapev = CreateFrame("Frame")
  mapev:RegisterEvent("WORLD_MAP_UPDATE")
  mapev:SetScript("OnEvent", function()
    if WorldMapFrame and WorldMapFrame:IsShown() then OL.PaintPins() end
  end)
  -- (1.12 frames have no :HookScript - pfUI's own HookScript chains the handler)
  if WorldMapFrame and HookScript then HookScript(WorldMapFrame, "OnShow", function() OL.PaintPins() end) end

  -- ---------------------------------------------------------------- tooltips anywhere in the game
  -- (26 Nov 2026, user with Atlas-CFM's options: "make our own version ... work with octo loot and our built in database")
  -- An item's tooltip gains: the set it is in, what it swaps for / from, the faction / PvP / event / crafting page it is
  -- on, the recipe that makes it and what it is used to make (by profession). pfUI's tooltip extras already name where
  -- it drops (pfQuest's database): OctoLoot adds the server's own drop chances only while those are off.
  -- Fast without the tables: the texts are searched for the item's id once and the answer kept (OL.tipCache, 300 items).
  local function LineAt(text, pos)
    local s = pos
    while s > 1 and string.byte(text, s - 1) ~= 10 do s = s - 1 end
    local e = string.find(text, "\n", pos, true) or (string.len(text) + 1)
    return string.sub(text, s, e - 1), s
  end
  -- the I line above a position (once per text: every I line's start)
  local iStarts = {}
  local function GroupAt(text, pos)
    local list = iStarts[text]
    if not list then
      list = {}
      if string.sub(text, 1, 2) == "I^" then table.insert(list, 1) end
      local p = 1
      while true do
        local a = string.find(text, "\nI^", p, true)
        if not a then break end
        table.insert(list, a + 1)
        p = a + 1
      end
      iStarts[text] = list
    end
    local best
    for i = 1, table.getn(list) do
      if list[i] <= pos then best = list[i] else break end
    end
    if not best then return nil end
    local line = LineAt(text, best)
    return Split(line)
  end
  local SECT = { d = "", r = "", w = "", e = "Event", c = "Collection", f = "Faction", p = "PvP", x = "Crafting" }
  function OL.TipFacts(id)
    OL.tipCache = OL.tipCache or {}
    OL.tipN = OL.tipN or 0
    local got = OL.tipCache[id]
    if got then return got end
    if OL.tipN > 300 then OL.tipCache, OL.tipN = {}, 0 end
    local facts = { pages = {}, drops = {}, used = {}, made = nil, set = nil, swaps = 0, from = 0 }
    local pat = "[,%^]" .. id .. "[:,~\n]"
    for _, text in ipairs({ pfUI.octolootData or "", pfUI.octolootPages or "" }) do
      local p = 1
      local n = 0
      while n < 40 do
        local a, b = string.find(text, pat, p)
        if not a then break end
        n = n + 1
        local line = LineAt(text, a + 1)
        local kind = string.sub(line, 1, 1)
        if kind == "B" then
          local f = Split(line)
          local g = GroupAt(text, a)
          if g then
            local tok = string.sub(text, a + 1, b - 1)
            local _, _, pct = string.find(string.sub(text, a + 1, a + 40), "^%d+:(%-?[%d%.]+)")
            local entry = { boss = f[3], group = g[3], kind = g[4], pct = tonumber(pct) }
            if f[4] == "p" then table.insert(facts.pages, entry) else table.insert(facts.drops, entry) end
          end
        elseif kind == "S" and not facts.set then
          local f = Split(line)
          local cnt = 0
          for _ in string.gfind(f[5] or "", "%d+") do cnt = cnt + 1 end
          facts.set = { name = f[4], n = cnt }
        elseif kind == "X" then
          local _, _, from = string.find(line, "^X%^(%d+)%^")
          if tonumber(from) == id then
            for _ in string.gfind(string.sub(line, string.len(from) + 4), "%d+") do facts.swaps = facts.swaps + 1 end
          else
            facts.from = facts.from + 1
          end
        end
        p = b
      end
    end
    local pages = pfUI.octolootPages or ""
    -- the recipe that makes it, and the recipes it is a reagent of
    local _, _, sid, sname, skill = string.find(pages, "\nR%^(%d+)%^([^%^]*)%^(%d+)%^" .. id .. "%^")
    if sid then facts.made = { skill = tonumber(skill), name = sname } end
    local used = {}
    local p = 1
    while true do
      local a, b = string.find(pages, "[%^,]" .. id .. "x%d+", p)
      if not a then break end
      local line = LineAt(pages, a + 1)
      local f = Split(line)
      if f[1] == "R" then
        local sk = tonumber(f[4]) or 0
        used[sk] = (used[sk] or 0) + 1
      end
      p = b
    end
    facts.used = used
    OL.tipCache[id] = facts
    OL.tipN = OL.tipN + 1
    return facts
  end

  -- your professions by skill line id (for "only mine")
  function OL.MyProfessions()
    local mine = {}
    local byName = {}
    for sk, name in pairs(OL.SKILLNAME) do byName[name] = sk end
    if GetNumSkillLines then
      for i = 1, GetNumSkillLines() do
        local name, header = GetSkillLineInfo(i)
        if name and not header and byName[name] then mine[byName[name]] = true end
      end
    end
    return mine
  end

  function OL.Tooltip(tt, id)
    if S("tip", "1") ~= "1" or not id then return end
    local fx = OL.TipFacts(id)
    local rows, max = 0, tonumber(S("tiprows", 4)) or 4
    local HEAD = { 1, .82, .2 }
    local added = false
    local function Head()
      if not added then
        tt:AddLine(" ")
        tt:AddLine("OctoLoot", HEAD[1], HEAD[2], HEAD[3])
        added = true
      end
    end
    if fx.set then Head() tt:AddDoubleLine("  Set", fx.set.name .. " (" .. fx.set.n .. ")", .7, .7, .7, .4, .8, 1) end
    if fx.swaps > 0 then Head() tt:AddDoubleLine("  Swaps for", fx.swaps .. (fx.swaps == 1 and " item" or " items"), .7, .7, .7, .4, .8, 1) end
    if fx.from > 0 then Head() tt:AddDoubleLine("  Swapped from", fx.from .. (fx.from == 1 and " item" or " items"), .7, .7, .7, .4, .8, 1) end
    -- the server's drop chances, only while pfUI's own "where it drops" lines are off
    if C.tooltip and C.tooltip.x_sources == "0" then
      for _, d in ipairs(fx.drops) do
        if rows >= max then break end
        Head()
        local pct = d.pct and (d.pct < 0 and "quest" or (d.pct .. "%")) or ""
        tt:AddDoubleLine("  " .. d.boss .. " |cff8c8c8c" .. d.group .. "|r", pct, 1, 1, 1, .8, .8, .8)
        rows = rows + 1
      end
    end
    for _, pg in ipairs(fx.pages) do
      if rows >= max then break end
      Head()
      local where = pg.group
      if pg.boss and pg.boss ~= pg.group then where = where .. " - " .. pg.boss end
      tt:AddDoubleLine("  " .. (SECT[pg.kind] or ""), where, .7, .7, .7, 1, 1, 1)
      rows = rows + 1
    end
    if fx.made then
      Head()
      tt:AddDoubleLine("  Made with", OL.SKILLNAME[fx.made.skill or 0] or "a recipe", .7, .7, .7, 1, 1, 1)
    end
    if S("tipreagent", "1") == "1" then
      local mine = S("tipmine", "0") == "1" and OL.MyProfessions() or nil
      local parts = {}
      for sk, n in pairs(fx.used) do
        if not mine or mine[sk] then table.insert(parts, (OL.SKILLNAME[sk] or "?") .. " " .. n) end
      end
      if table.getn(parts) > 0 then
        table.sort(parts)
        Head()
        tt:AddDoubleLine("  Used in", table.concat(parts, ", "), .7, .7, .7, 1, 1, 1)
      end
    end
    if added then tt:Show() end
  end
  -- a frame shown with GameTooltip (as tooltip-extras.lua): runs once each time a tooltip shows
  local tipf = CreateFrame("Frame", "pfOctoLootTip", GameTooltip)
  tipf:SetScript("OnShow", function()
    if S("tip", "1") ~= "1" then return end
    local lt = pfUI.api and pfUI.api.libtooltip or rawget(_G, "libtooltip")
    local id = lt and lt.GetItemID and lt:GetItemID()
    if id then pcall(OL.Tooltip, GameTooltip, tonumber(id)) end
  end)

  -- ---------------------------------------------------------------- minimap button
  -- (26 Nov 2026) the chest glyph on the map's edge: click = OctoLoot, right-click = its options, drag = move round
  function OL.MinimapButton()
    if OL.mm or not Minimap then return OL.mm end
    local b = CreateFrame("Button", "pfOctoLootMinimapButton", Minimap)
    OL.mm = b
    b:SetWidth(30) b:SetHeight(30)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetTexture(BADGE .. "badge")
    b.bg:SetAllPoints(b)
    b.bg:SetVertexColor(.06, .06, .07, .95)
    b.ring = b:CreateTexture(nil, "BORDER")
    b.ring:SetTexture(BADGE .. "ring")
    b.ring:SetAllPoints(b)
    b.ring:SetVertexColor(1, .82, .2, 1)
    b.pic = b:CreateTexture(nil, "ARTWORK")
    b.pic:SetTexture("Interface\\AddOns\\pfUI\\img\\octo\\icons\\loot")
    b.pic:SetPoint("TOPLEFT", b, "TOPLEFT", 6, -6)
    b.pic:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -6, 6)
    b.pic:SetVertexColor(1, .82, .2, 1)
    local function Place()
      local a = math.rad(tonumber(S("mmangle", 200)) or 200)
      local r = (Minimap:GetWidth() or 140) / 2 + 4
      b:ClearAllPoints()
      b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
    end
    OL.PlaceMinimap = Place
    b:SetScript("OnDragStart", function() this.dragging = true end)
    b:SetScript("OnDragStop", function() this.dragging = nil end)
    b:SetScript("OnUpdate", function()
      if not this.dragging then return end
      local mx, my = GetCursorPosition()
      local s = Minimap:GetEffectiveScale()
      local cx, cy = Minimap:GetCenter()
      local ang = math.deg(math.atan2(my / s - cy, mx / s - cx))
      C.octoloot.mmangle = math.floor(ang + .5)
      Place()
    end)
    b:SetScript("OnClick", function()
      if arg1 == "RightButton" then
        local O = pfUI.octoui and pfUI.octoui.Options
        if O and O.Open then O:Open("octoloot") end
      else
        OL.Toggle()
      end
    end)
    b:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_LEFT")
      GameTooltip:AddLine("OctoLoot", 1, .82, .2)
      GameTooltip:AddLine("Click: open   Right-click: options   Drag: move", .8, .8, .8)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Place()
    return b
  end
  function OL.ShowMinimap()
    if S("minimap", "1") == "1" then
      local b = OL.MinimapButton()
      if b then b:Show() end
    elseif OL.mm then
      OL.mm:Hide()
    end
  end
  OL.ShowMinimap()

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
    if msg == "clear" then
      if OL.ClearWaypoint then OL.ClearWaypoint() end
    elseif msg == "quests" then
      local inst = OL.Here() or OL.inst
      OL.Show()
      if inst then OL.Select(inst) OL.view = "quests" OL.PaintMain() end
    elseif msg ~= "" then OL.SearchFor(msg) else OL.Toggle() end
  end
end)
