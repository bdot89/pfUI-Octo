pfUI:RegisterModule("consumes", "vanilla", function ()
  -- pfUI Octo :: consumables tracker (11 Nov 2026; Wolfahrt on Discord: "a way to
  -- track consumes, with an edited list you can pick from the existing OctoWoW
  -- consumes, by character like this is the case for gear. It would then alert
  -- when one is missing or expiring soon and maybe an option to reapply it").
  --
  -- C.consumes.lists = { { name, raid, dungeon, bg, arena, world ("1" / "0"),
  --   spec (C.gear.specs slot or ""), layout (UI layout name or ""),
  --   items = { { item = id, name, buff, kind = "buff" | "weapon", hand = "16" | "17",
  --   cat, on = "1" | "0", learned } } } }. pfUI_config is per character, so the
  -- lists are too. The first list whose zone (pfUI.context.Zone), spec and layout
  -- match is the one watched.
  --
  -- Buffs: ClassicAPI C_UnitAuras.UnitAura (name + expiry, no tooltip) first, else
  -- GetPlayerBuff + GetPlayerBuffTimeLeft + a tooltip scan for the name (cached
  -- until PLAYER_AURAS_CHANGED). Oils / stones / poisons: GetWeaponEnchantInfo -
  -- any temporary enchant on that hand counts (1.12 does not say which one).
  -- Buff names: CS.CATALOG (item ids from pfQuest's item names, buff names checked
  -- against this client's Spell.dbc, patch-O, 11 Nov 2026), else the item's name;
  -- the buff that really appears after you use the item is learned (CS.Learn).
  --
  -- Reapply: a click on an icon, or the key "Use the next missing consumable"
  -- (Bindings.xml PFCONSUMENEXT). Both are key / mouse presses. Nothing uses an
  -- item by itself: an add-on using items with no key press is what bots do, and
  -- the rules of most servers forbid it, so no automatic option is offered.
  local CS = { listeners = {}, names = {}, last = {}, rows = {} }
  pfUI.consumes = CS

  local function S() return C.consumes end
  local function Num(v, d) return tonumber(v) or d end
  local function Lower(s) return string.lower(string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end
  CS.Key = Lower

  -- ---------------------------------------------------------------- the catalogue
  -- { item id, item name, buff name ("*" = weapon enchant), icon (the buff's) }
  CS.CATS = {
    { "flask", "Flasks", "INV_Potion_62" },
    { "elixir", "Elixirs", "INV_Potion_32" },
    { "zanza", "Zanza", "INV_Potion_30" },
    { "blasted", "Blasted Lands", "Spell_Nature_Strength" },
    { "juju", "Juju and firewater", "INV_Misc_MonsterScales_11" },
    { "food", "Food", "Spell_Misc_Food" },
    { "drink", "Drinks", "INV_Drink_04" },
    { "scroll", "Scrolls", "INV_Scroll_02" },
    { "protect", "Protection potions", "Spell_Fire_FireArmor" },
    { "weapon", "Oils, stones and poisons", "INV_Stone_SharpeningStone_01" },
  }
  CS.CATALOG = {
    flask = {
      { 13510, "Flask of the Titans", "Flask of the Titans", "INV_Potion_62" },
      { 13512, "Flask of Supreme Power", "Supreme Power", "INV_Potion_41" },
      { 13511, "Flask of Distilled Wisdom", "Distilled Wisdom", "inv_potion_120" },
      { 13513, "Flask of Chromatic Resistance", "Chromatic Resistance", "inv_potion_128" },
    },
    elixir = {
      { 13452, "Elixir of the Mongoose", "Elixir of the Mongoose", "INV_Potion_32" },
      { 9206, "Elixir of Giants", "Elixir of the Giants", "INV_Potion_61" },
      { 9187, "Elixir of Greater Agility", "Greater Agility", "INV_Potion_93" },
      { 13453, "Elixir of Brute Force", "Elixir of Brute Force", "INV_Potion_40" },
      { 13454, "Greater Arcane Elixir", "Greater Arcane Elixir", "INV_Potion_25" },
      { 9155, "Arcane Elixir", "Arcane Elixir", "INV_Potion_30" },
      { 9264, "Elixir of Shadow Power", "Shadow Power", "INV_Potion_46" },
      { 17708, "Elixir of Frost Power", "Frost Power", "inv_potion_115" },
      { 21546, "Elixir of Greater Firepower", "Greater Firepower", "INV_Potion_60" },
      { 50237, "Elixir of Greater Nature Power", "Elixir of Greater Nature Power", "inv_potion_106" },
      { 55046, "Elixir of Greater Frost Power", "Elixir of Greater Frost Power", "inv_potion_115" },
      { 55048, "Elixir of Greater Arcane Power", "Elixir of Greater Arcane Power", "INV_Potion_25" },
      { 9179, "Elixir of Greater Intellect", "Greater Intellect", "INV_Potion_10" },
      { 13447, "Elixir of the Sages", "Elixir of the Sages", "inv_potion_142" },
      { 13445, "Elixir of Superior Defense", "Greater Armor", "INV_Potion_86" },
      { 3825, "Elixir of Fortitude", "Health II", "INV_Potion_44" },
      { 9088, "Gift of Arthas", "Gift of Arthas", "Spell_Shadow_FingerOfDeath" },
      { 20007, "Mageblood Potion", "Mana Regeneration", "INV_Potion_45" },
      { 20004, "Major Troll's Blood Potion", "Regeneration", "INV_Potion_79" },
      { 61423, "Dreamtonic", "Dreamtonic", "inv_potion_114" },
      { 61224, "Dreamshard Elixir", "Dreamshard Elixir", "inv_potion_113" },
      { 61225, "Lucidity Potion", "Lucidity Potion", "inv_potion_141" },
      { 47410, "Concoction of the Emerald Mongoose", "Concoction of the Emerald Mongoose", "inv_blue_gold_elixir_2" },
      { 47412, "Concoction of the Arcane Giant", "Concoction of the Arcane Giant", "inv_yellow_purple_elixir_2" },
      { 47414, "Concoction of the Dreamwater", "Concoction of the Dreamwater", "inv_green_pink_elixir_1" },
      { 9224, "Elixir of Demonslaying", "Elixir of Demonslaying", "Spell_Holy_RetributionAura" },
    },
    zanza = {
      { 20079, "Spirit of Zanza", "Spirit of Zanza", "INV_Potion_30" },
      { 20081, "Swiftness of Zanza", "Swiftness of Zanza", "INV_Potion_31" },
      { 20080, "Sheen of Zanza", "Sheen of Zanza", "INV_Potion_29" },
    },
    blasted = {
      { 8410, "R.O.I.D.S.", "Rage of Ages", "Spell_Nature_Strength" },
      { 8412, "Ground Scorpok Assay", "Strike of the Scorpok", "Spell_Nature_ForceOfNature" },
      { 8411, "Lung Juice Cocktail", "Spirit of Boar", "Spell_Nature_Purge" },
      { 8423, "Cerebral Cortex Compound", "Infallible Mind", "Spell_Ice_Lament" },
      { 8424, "Gizzard Gum", "Spiritual Domination", "Spell_Fire_Incinerate" },
    },
    juju = {
      { 12451, "Juju Power", "Juju Power", "INV_Misc_MonsterScales_11" },
      { 12460, "Juju Might", "Juju Might", "INV_Misc_MonsterScales_07" },
      { 12455, "Juju Ember", "Juju Ember", "INV_Misc_MonsterScales_15" },
      { 12457, "Juju Chill", "Juju Chill", "INV_Misc_MonsterScales_09" },
      { 12458, "Juju Guile", "Juju Guile", "INV_Misc_MonsterScales_13" },
      { 12820, "Winterfall Firewater", "Winterfall Firewater", "INV_Potion_92" },
    },
    food = {
      { 20452, "Smoked Desert Dumplings", "Well Fed", "Spell_Misc_Food" },
      { 13928, "Grilled Squid", "Well Fed", "Spell_Misc_Food" },
      { 13931, "Nightfin Soup", "Well Fed", "Spell_Misc_Food" },
      { 18254, "Runn Tum Tuber Surprise", "Well Fed", "Spell_Misc_Food" },
      { 21023, "Dirge's Kickin' Chimaerok Chops", "Well Fed", "Spell_Misc_Food" },
      { 21217, "Sagefish Delight", "Well Fed", "Spell_Misc_Food" },
      { 18045, "Tender Wolf Steak", "Well Fed", "Spell_Misc_Food" },
      { 12218, "Monster Omelet", "Well Fed", "Spell_Misc_Food" },
      { 60977, "Danonzo's Tel'Abim Delight", "Well Fed", "Spell_Misc_Food" },
      { 60978, "Danonzo's Tel'Abim Medley", "Well Fed", "Spell_Misc_Food" },
      { 60976, "Danonzo's Tel'Abim Surprise", "Well Fed", "Spell_Misc_Food" },
      { 53015, "Gurubashi Gumbo", "Well Fed", "Spell_Misc_Food" },
      { 51720, "Power Mushroom", "Well Fed", "Spell_Misc_Food" },
      { 51717, "Hardened Mushroom", "Well Fed", "Spell_Misc_Food" },
      { 84040, "Le Fishe Au Chocolat", "Well Fed", "Spell_Misc_Food" },
      { 83309, "Empowering Herbal Salad", "Well Fed", "Spell_Misc_Food" },
      { 13810, "Blessed Sunfruit", "Blessed Sunfruit", "Spell_Holy_Devotion" },
      { 13813, "Blessed Sunfruit Juice", "Blessed Sunfruit Juice", "Spell_Holy_LayOnHands" },
    },
    drink = {
      { 21151, "Rumsey Rum Black Label", "Rumsey Rum Black Label", "INV_Drink_04" },
      { 61174, "Medivh's Merlot", "Medivh's Merlot", "INV_Drink_04" },
      { 18269, "Gordok Green Grog", "Gordok Green Grog", "INV_Drink_03" },
      { 18284, "Kreeg's Stout Beatdown", "Kreeg's Stout Beatdown", "INV_Drink_05" },
    },
    scroll = {
      { 10309, "Scroll of Agility IV", "Agility", "INV_Potion_93" },
      { 10310, "Scroll of Strength IV", "Strength", "INV_Potion_58" },
      { 10305, "Scroll of Protection IV", "Armor", "INV_Potion_86" },
      { 10307, "Scroll of Stamina IV", "Stamina", "Spell_Nature_UnyeildingStamina" },
      { 10308, "Scroll of Intellect IV", "Intellect", "INV_Potion_10" },
      { 10306, "Scroll of Spirit IV", "Spirit", "Spell_Shadow_BurningSpirit" },
    },
    protect = {
      { 13457, "Greater Fire Protection Potion", "Fire Protection", "Spell_Fire_FireArmor" },
      { 13456, "Greater Frost Protection Potion", "Frost Protection", "Spell_Frost_FrostArmor02" },
      { 13458, "Greater Nature Protection Potion", "Nature Protection", "Spell_Nature_SpiritArmor" },
      { 13459, "Greater Shadow Protection Potion", "Shadow Protection", "Spell_Shadow_AntiShadow" },
      { 13461, "Greater Arcane Protection Potion", "Arcane Protection", "Spell_Holy_PrayerOfHealing02" },
      { 13460, "Greater Holy Protection Potion", "Holy Protection", "Spell_Holy_HolyProtection" },
    },
    weapon = {
      { 18262, "Elemental Sharpening Stone", "*", "INV_Stone_02" },
      { 12404, "Dense Sharpening Stone", "*", "INV_Stone_SharpeningStone_05" },
      { 12643, "Dense Weightstone", "*", "INV_Stone_WeightStone_05" },
      { 20749, "Brilliant Wizard Oil", "*", "INV_Potion_105" },
      { 20748, "Brilliant Mana Oil", "*", "INV_Potion_100" },
      { 20750, "Wizard Oil", "*", "INV_Potion_104" },
      { 20747, "Lesser Mana Oil", "*", "INV_Potion_99" },
      { 3824, "Shadow Oil", "*", "INV_Potion_23" },
      { 3829, "Frost Oil", "*", "INV_Potion_20" },
      { 8928, "Instant Poison VI", "*", "Ability_Poisons" },
      { 20844, "Deadly Poison V", "*", "Ability_Rogue_DualWeild" },
      { 3776, "Crippling Poison II", "*", "Ability_PoisonSting" },
      { 9186, "Mind-numbing Poison III", "*", "Spell_Nature_NullifyDisease" },
      { 10922, "Wound Poison IV", "*", "INV_Misc_Herb_16" },
    },
  }
  -- item id -> { cat, name, buff, icon }
  CS.BYID = {}
  for _, c in ipairs(CS.CATS) do
    for _, e in ipairs(CS.CATALOG[c[1]] or {}) do CS.BYID[e[1]] = { cat = c[1], name = e[2], buff = e[3], icon = e[4] } end
  end
  -- buffs that are eating / drinking, not the buff the item leaves
  CS.SKIPLEARN = { ["food"] = true, ["drink"] = true, ["refreshment"] = true, ["food & drink"] = true }

  -- ---------------------------------------------------------------- lists

  CS.ZONES = { "raid", "dungeon", "bg", "arena", "world" }
  function CS.NewList(name)
    return { name = name or "Raid", raid = "1", dungeon = "1", bg = "0", arena = "0", world = "0", spec = "", layout = "", items = {} }
  end
  function CS.Lists()
    if type(S().lists) ~= "table" then S().lists = {} end
    if table.getn(S().lists) == 0 then table.insert(S().lists, CS.NewList("Raid")) end
    return S().lists
  end
  function CS.Zone()
    return (pfUI.context and pfUI.context.Zone) and pfUI.context.Zone() or "world"
  end
  -- does a list apply now (zone, then spec and UI layout when it names them)
  function CS.ListOn(list, zone)
    if not list then return false end
    if list[zone or CS.Zone()] ~= "1" then return false end
    if list.spec and list.spec ~= "" then
      if not (C.gear and C.gear.specnow and tostring(C.gear.specnow) == list.spec) then return false end
    end
    if list.layout and list.layout ~= "" then
      if not (C.layouts and C.layouts.current == list.layout) then return false end
    end
    return true
  end
  function CS.Active()
    if S().track == "0" then return nil end
    local zone = CS.Zone()
    for i, l in ipairs(CS.Lists()) do
      if CS.ListOn(l, zone) and table.getn(l.items or {}) > 0 then return l, i end
    end
  end

  -- ---------------------------------------------------------------- bags

  local function IdOf(link)
    if type(link) == "number" then return link end
    local _, _, id = string.find(link or "", "item:(%d+)")
    return tonumber(id)
  end
  CS.IdOf = IdOf
  -- id -> { count, bag, slot } (first stack), rebuilt after BAG_UPDATE
  function CS.Bags()
    if CS.bags and not CS.bagsDirty then return CS.bags end
    local out = {}
    for bag = 0, 4 do
      local n = GetContainerNumSlots and GetContainerNumSlots(bag) or 0
      for slot = 1, (tonumber(n) or 0) do
        local id = IdOf(GetContainerItemLink(bag, slot))
        if id then
          local _, count = GetContainerItemInfo(bag, slot)
          local e = out[id]
          if not e then
            e = { count = 0, bag = bag, slot = slot }
            out[id] = e
          end
          e.count = e.count + (tonumber(count) or 1)
        end
      end
    end
    CS.bags, CS.bagsDirty = out, nil
    return out
  end
  function CS.Count(id) local e = CS.Bags()[id] return e and e.count or 0 end

  -- name and picture of an item (the client's item info, the catalogue, the bags)
  function CS.ItemInfo(id)
    local info = _G.GetItemInfo
    local name, tex
    if info and id then
      local n, _, _, _, _, _, _, _, t = info(id)
      if type(n) == "string" then name = n end
      if type(t) == "string" then tex = t end
    end
    local cat = CS.BYID[id]
    if not name and cat then name = cat.name end
    if not tex then
      local b = CS.Bags()[id]
      if b then tex = GetContainerItemInfo(b.bag, b.slot) end
    end
    if type(tex) ~= "string" and cat and cat.icon then tex = "Interface\\Icons\\" .. cat.icon end
    return name, tex
  end

  local scanner
  local function Scanner()
    if scanner then return scanner end
    if libtipscan and libtipscan.GetScanner then scanner = libtipscan:GetScanner("consumes") end
    return scanner
  end
  -- a bag item's "Use:" line: is it a consumable, and does it go on a weapon
  function CS.UseText(bag, slot)
    local sc = Scanner()
    if not sc or not sc.SetBagItem then return end
    sc:SetBagItem(bag, slot)
    local _, text = sc:Find("^" .. (ITEM_SPELL_TRIGGER_ONUSE or "Use:"))
    if text then return text end
    local lines = sc.Text and sc:Text() or {}
    for _, l in pairs(lines) do
      local left = type(l) == "table" and l[1]
      if type(left) == "string" and string.find(left, "^Use:") then return left end
    end
  end

  -- ---------------------------------------------------------------- buffs

  local function Put(out, name, left, sid)
    if not name or name == "" then return end
    local k = Lower(name)
    local had = out[k]
    -- -1 = no timer (lasts until it is gone): beats any time
    if had == nil or had >= 0 and (left < 0 or left > had) then out[k] = left end
    if sid and out.ids then out.ids[sid] = true end
  end
  -- name (lower case) -> seconds left, -1 = no timer
  function CS.ReadBuffs()
    local out = { ids = {} }
    local ui = C_UnitAuras and C_UnitAuras.UnitAura
    if ui and S().classicapi ~= "0" then
      local good = true
      for i = 1, 40 do
        local ok, name, _, _, _, _, expires, _, _, _, sid = pcall(ui, "player", i, "HELPFUL")
        if not ok then good = false break end
        if not name then break end
        local left = -1
        if type(expires) == "number" and expires > 0 then left = math.max(0, expires - GetTime()) end
        Put(out, name, left, sid)
      end
      if good then CS.source = "ClassicAPI" return out end
      out = { ids = {} }
    end
    CS.source = "plain"
    if not GetPlayerBuff then return out end
    for i = 0, 31 do
      local bid = GetPlayerBuff(i, "HELPFUL")
      if type(bid) ~= "number" or bid < 0 then break end
      local tex = GetPlayerBuffTexture and GetPlayerBuffTexture(bid)
      local key = bid .. ":" .. tostring(tex)
      local name = CS.names[key]
      if not name then
        local sc = Scanner()
        if sc and sc.SetPlayerBuff then
          sc:SetPlayerBuff(bid)
          name = sc:Line(1)
        end
        CS.names[key] = name or false
      end
      local left = GetPlayerBuffTimeLeft and GetPlayerBuffTimeLeft(bid)
      if type(left) ~= "number" or left <= 0 then left = -1 end
      if name then Put(out, name, left) end
    end
    return out
  end

  -- { [16] = { has, seconds }, [17] = ... } from GetWeaponEnchantInfo
  function CS.Weapons()
    local out = { [16] = { false, 0 }, [17] = { false, 0 } }
    if not GetWeaponEnchantInfo then return out end
    local mh, mt, _, oh, ot = GetWeaponEnchantInfo()
    out[16] = { mh and true or false, (tonumber(mt) or 0) / 1000 }
    out[17] = { oh and true or false, (tonumber(ot) or 0) / 1000 }
    return out
  end

  -- one entry's state: "ok" | "low" | "missing" | "none" (no weapon in that hand), seconds left
  function CS.State(e, buffs, wpn)
    local warn = Num(S().warn, 5) * 60
    local left
    if e.kind == "weapon" then
      local hand = tonumber(e.hand) or 16
      if hand == 17 and not GetInventoryItemLink("player", 17) then return "none" end
      local w = (wpn or CS.Weapons())[hand]
      if not w or not w[1] then return "missing" end
      left = w[2] > 0 and w[2] or -1
      warn = Num(S().warnweapon, 5) * 60
    else
      buffs = buffs or CS.ReadBuffs()
      left = buffs[Lower(e.buff or e.name)]
      if left == nil then return "missing" end
    end
    if left >= 0 and left < warn then return "low", left end
    return "ok", left
  end

  function CS.Time(left)
    if not left or left < 0 then return "" end
    if left >= 3600 then return math.floor(left / 3600 + .5) .. "h" end
    if left >= 60 then return math.ceil(left / 60) .. "m" end
    return math.floor(left) .. "s"
  end

  -- ---------------------------------------------------------------- adding

  -- a new list entry for an item id (name / buff / kind from the catalogue,
  -- else the item name and its "Use:" line)
  function CS.Entry(id, bag, slot)
    id = IdOf(id)
    if not id then return end
    local cat = CS.BYID[id]
    local name = CS.ItemInfo(id)
    local e = { item = id, name = name or ("item " .. id), on = "1", kind = "buff", hand = "16" }
    if cat then
      e.cat = cat.cat
      e.buff = (cat.buff ~= "*") and cat.buff or nil
      if cat.buff == "*" then e.kind = "weapon" end
    else
      e.buff = e.name
      if not bag then
        local b = CS.Bags()[id]
        if b then bag, slot = b.bag, b.slot end
      end
      local use = bag and CS.UseText(bag, slot)
      if use and string.find(string.lower(use), "weapon") then e.kind = "weapon" e.buff = nil end
    end
    return e
  end
  function CS.Has(list, id, hand)
    for i, e in ipairs(list.items or {}) do
      if e.item == id and (e.kind ~= "weapon" or not hand or e.hand == hand) then return i end
    end
  end
  -- add an item (id, link, or part of a name: bags first, then the catalogue,
  -- then pfQuest's item names) to a list; returns the entry or nil, why
  function CS.Add(list, what)
    list = list or CS.Lists()[1]
    local id = IdOf(what)
    if not id and type(what) == "string" then
      local n = tonumber(what)
      if n then id = n else id = CS.FindName(what) end
    end
    if not id then return nil, "No item called \"" .. tostring(what) .. "\" in your bags or the list of consumables." end
    if CS.Has(list, id) and not (CS.BYID[id] and CS.BYID[id].buff == "*") then return nil, "That one is already on the list." end
    local e = CS.Entry(id)
    if not e then return nil, "Not an item." end
    -- a second oil goes on the other hand
    if e.kind == "weapon" and CS.Has(list, id, "16") then
      if CS.Has(list, id, "17") then return nil, "That one is already on the list for both hands." end
      e.hand = "17"
    end
    list.items = list.items or {}
    table.insert(list.items, e)
    CS.Changed()
    return e
  end
  function CS.FindName(text)
    local want = Lower(text)
    if want == "" then return end
    local partial
    for id in pairs(CS.Bags()) do
      local n = Lower(CS.ItemInfo(id))
      if n == want then return id end
      if not partial and string.find(n, want, 1, true) then partial = id end
    end
    for id, c in pairs(CS.BYID) do
      local n = Lower(c.name)
      if n == want then return id end
      if not partial and string.find(n, want, 1, true) then partial = id end
    end
    local db = pfDB and pfDB["items"]
    db = db and (db["loc"] or db["enUS"])
    if type(db) == "table" then
      for id, n in pairs(db) do
        if type(n) == "string" and Lower(n) == want then return id end
      end
    end
    return partial
  end

  -- the item on the cursor (ClassicAPI GetCursorInfo, else the bag slot it was picked up from)
  function CS.CursorItem()
    if not (CursorHasItem and CursorHasItem()) then return end
    if C_UnitAuras and _G.GetCursorInfo then
      local ok, kind, id, link = pcall(_G.GetCursorInfo)
      if ok and kind == "item" then return IdOf(link) or tonumber(id) end
    end
    local p = CS.picked
    if p and GetTime() - p.t < 120 then return IdOf(GetContainerItemLink(p.bag, p.slot)) or p.id end
  end
  function CS.AddFromCursor(list)
    local id = CS.CursorItem()
    if not id then return nil, "Pick an item up from your bags first, then click here." end
    ClearCursor()
    return CS.Add(list, id)
  end

  -- ---------------------------------------------------------------- using

  -- an item used now would be sold, banked, traded or mailed instead
  function CS.Blocked()
    for _, f in ipairs({ { "MerchantFrame", "a vendor" }, { "BankFrame", "the bank" }, { "TradeFrame", "a trade" },
                         { "SendMailFrame", "the mail" }, { "AuctionFrame", "the auction house" } }) do
      local fr = _G[f[1]]
      if fr and fr.IsVisible and fr:IsVisible() then return "Close " .. f[2] .. " first: an item clicked now would go there." end
    end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return "You are dead." end
  end

  local function Say(text, r, g, b)
    if UIErrorsFrame then UIErrorsFrame:AddMessage(text, r or 1, g or .82, b or .2, 1, 4) end
  end
  local function Chat(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r consumes: " .. text) end
  end
  CS.Chat = Chat

  -- use the item of an entry (from a click or a key: both are hardware events)
  function CS.Use(e)
    if not e then return end
    local why = CS.Blocked()
    if why then Say(why, 1, .3, .3) return false end
    if e.cat == "food" and UnitAffectingCombat("player") then Say("You cannot eat in combat.", 1, .3, .3) return false end
    CS.bagsDirty = true
    local b = CS.Bags()[e.item]
    if not b then Say("No " .. (e.name or "item") .. " in your bags.", 1, .3, .3) return false end
    CS.StartLearn(e)
    UseContainerItem(b.bag, b.slot)
    if e.kind == "weapon" and SpellIsTargeting and SpellIsTargeting() then
      PickupInventoryItem(tonumber(e.hand) or 16)
    end
    CS.bagsDirty = true
    return true
  end

  -- the first missing, then the one running out soonest, that can be used now
  function CS.Next()
    local best, bestLeft
    for _, r in ipairs(CS.rows) do
      local e = r.e
      local usable = r.count > 0 and not (e.cat == "food" and UnitAffectingCombat("player"))
      if usable and r.state == "missing" then return e end
      if usable and r.state == "low" and (not bestLeft or (r.left or 0) < bestLeft) then best, bestLeft = e, r.left or 0 end
    end
    return best
  end
  function CS.UseNext()
    CS.Scan()
    local e = CS.Next()
    if not e then Say("Nothing to put on: every consumable on your list is up (or none left in your bags).", .3, 1, .4) return end
    CS.Use(e)
  end
  _G.BINDING_HEADER_PFCONSUMES = "pfUI Octo: consumables"
  _G.BINDING_NAME_PFCONSUMENEXT = "Use the next missing consumable"

  -- ---------------------------------------------------------------- learning

  -- after an item of the list is used: the buff that appears in the next 40 s
  -- (eating first shows "Food", then "Well Fed") is the one it gives
  function CS.StartLearn(e)
    if not e or e.kind == "weapon" or S().learn == "0" then return end
    local before = CS.ReadBuffs()
    CS.learning = { e = e, before = before, t = GetTime() }
  end
  function CS.Learn(buffs)
    local L = CS.learning
    if not L then return end
    if GetTime() - L.t > 40 then CS.learning = nil return end
    local e = L.e
    -- the buff it should give is there now: nothing to learn
    if buffs[Lower(e.buff or e.name)] and not L.before[Lower(e.buff or e.name)] then CS.learning = nil return end
    for k in pairs(buffs) do
      if k ~= "ids" and L.before[k] == nil and not CS.SKIPLEARN[k] then
        CS.learning = nil
        if Lower(e.buff) ~= k then
          -- the real name, as the game writes it
          e.buff = CS.Proper(k) or k
          e.learned = "1"
          Chat((e.name or "?") .. " gives the buff \"" .. e.buff .. "\": tracked by that now.")
          CS.Changed()
        end
        return
      end
    end
  end
  -- a buff's name as written, from the lower-case key
  function CS.Proper(k)
    if C_UnitAuras and C_UnitAuras.UnitAura then
      for i = 1, 40 do
        local ok, name = pcall(C_UnitAuras.UnitAura, "player", i, "HELPFUL")
        if not ok or not name then break end
        if Lower(name) == k then return name end
      end
    end
    for _, n in pairs(CS.names) do if n and Lower(n) == k then return n end end
  end

  -- items used from the bags count too (a hook on the game's UseContainerItem /
  -- PickupContainerItem; the cursor's item for the "drop here" box)
  if not CS.hooked and _G.UseContainerItem then
    CS.hooked = true
    local rawUse = _G.UseContainerItem
    _G.UseContainerItem = function(bag, slot, a3, a4)
      if not CS.learning then
        pcall(function()
          local l = CS.Active()
          local id = IdOf(GetContainerItemLink(bag, slot))
          local i = l and id and CS.Has(l, id)
          if i then CS.StartLearn(l.items[i]) end
        end)
      end
      return rawUse(bag, slot, a3, a4)
    end
    local rawPick = _G.PickupContainerItem
    if rawPick then
      _G.PickupContainerItem = function(bag, slot)
        CS.picked = { bag = bag, slot = slot, t = GetTime(), id = IdOf(GetContainerItemLink(bag, slot)) }
        return rawPick(bag, slot)
      end
    end
  end

  -- ---------------------------------------------------------------- watching

  -- CS.rows = { { e, state, left, count } } for the active list's ticked items
  function CS.Scan()
    local l = CS.Active()
    CS.list = l
    local rows = {}
    local buffs = CS.ReadBuffs()
    local wpn = CS.Weapons()
    CS.Learn(buffs)
    if l then
      for _, e in ipairs(l.items) do
        if e.on ~= "0" then
          local st, left = CS.State(e, buffs, wpn)
          if st ~= "none" then table.insert(rows, { e = e, state = st, left = left, count = CS.Count(e.item) }) end
        end
      end
    end
    CS.rows = rows
    CS.CheckAlerts()
    CS.UpdateBar()
    for _, fn in pairs(CS.listeners) do pcall(fn) end
    return rows
  end

  local function KeyOf(e) return tostring(e.item) .. (e.kind == "weapon" and (":" .. tostring(e.hand)) or "") end
  CS.KeyOf = KeyOf

  -- new problems (missing / running out) said once each; again every N minutes when set
  function CS.CheckAlerts()
    local quiet = S().quiet == "1" and UnitAffectingCombat("player")
    local dead = UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")
    local now = GetTime()
    local again = Num(S().again, 0) * 60
    local miss, low = {}, {}
    local seen = {}
    for _, r in ipairs(CS.rows) do
      local k = KeyOf(r.e)
      seen[k] = true
      local was = CS.last[k]
      if r.state == "ok" then
        CS.last[k] = { state = "ok" }
      elseif not quiet and not dead then
        -- (in combat with "quiet" on, nothing is marked: it is said when combat ends)
        local due = not was or was.state ~= r.state or (again > 0 and now - (was.t or 0) >= again)
        if due then
          CS.last[k] = { state = r.state, t = now }
          if r.state == "missing" then table.insert(miss, r.e.name) else table.insert(low, r.e.name .. " (" .. CS.Time(r.left) .. ")") end
        end
      end
    end
    -- (a list that stops applying forgets its items: entering the raid again says them again)
    for k in pairs(CS.last) do if not seen[k] then CS.last[k] = nil end end
    if table.getn(miss) == 0 and table.getn(low) == 0 then return end
    local text = ""
    if table.getn(miss) > 0 then text = "Missing: " .. table.concat(miss, ", ") end
    if table.getn(low) > 0 then text = text .. (text ~= "" and "  -  " or "") .. "Running out: " .. table.concat(low, ", ") end
    CS.lastAlert = text
    if S().text == "1" then Say(text, 1, .55, .2) end
    if S().chat == "1" then Chat(text) end
    if S().sound == "raidwarning" then PlaySound("RaidWarning")
    elseif S().sound == "ping" then PlaySoundFile("Sound\\Interface\\MapPing.wav") end
  end

  -- ---------------------------------------------------------------- the bar

  local function Flat(f, a)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(.06, .06, .08, a or .95)
    f:SetBackdropBorderColor(.2, .2, .24, 1)
  end
  CS.COLORS = { missing = { .95, .25, .25 }, low = { 1, .78, .2 }, ok = { .2, .2, .24 } }

  -- one icon (on the bar, or in the options preview: preview = true)
  function CS.NewButton(parent, preview)
    local b = CreateFrame("Button", nil, parent)
    Flat(b, 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(.07, .93, .07, .93)
    b.time = b:CreateFontString(nil, "OVERLAY")
    b.time:SetFont(pfUI.font_default, 12, "OUTLINE")
    b.time:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.count = b:CreateFontString(nil, "OVERLAY")
    b.count:SetFont(pfUI.font_default, 10, "OUTLINE")
    b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    if preview then return b end
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function()
      local e = this.e
      if not e then return end
      if arg1 == "RightButton" then CS.OpenOptions() return end
      if IsShiftKeyDown() and ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
        local link = CS.Bags()[e.item] and GetContainerItemLink(CS.Bags()[e.item].bag, CS.Bags()[e.item].slot)
        if link then ChatFrameEditBox:Insert(link) end
        return
      end
      CS.Use(e)
    end)
    b:SetScript("OnEnter", function()
      local e = this.e
      if not e then return end
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      if GameTooltip.SetHyperlink and e.item then GameTooltip:SetHyperlink("item:" .. e.item .. ":0:0:0") end
      if GameTooltip:NumLines() == 0 then GameTooltip:AddLine(e.name or "?") end
      local st = this.state
      if st == "missing" then GameTooltip:AddLine("Missing", 1, .3, .3)
      elseif st == "low" then GameTooltip:AddLine("Running out: " .. CS.Time(this.left) .. " left", 1, .78, .2)
      elseif st == "ok" then GameTooltip:AddLine("Up" .. ((this.left and this.left >= 0) and (": " .. CS.Time(this.left) .. " left") or ""), .3, 1, .4) end
      if e.kind == "weapon" then
        GameTooltip:AddLine((e.hand == "17" and "Off hand" or "Main hand") .. ": any oil, stone or poison on it counts.", .7, .7, .75, 1)
      else
        GameTooltip:AddLine("Buff: " .. (e.buff or e.name or "?") .. (e.learned and " (learned)" or ""), .7, .7, .75)
      end
      GameTooltip:AddLine(CS.Count(e.item) .. " in your bags", .7, .7, .75)
      GameTooltip:AddLine("Click: use it.  Right-click: options.", .35, .7, 1)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
  end

  -- paint a button for a row { e, state, left, count }
  function CS.Paint(b, r)
    local e = r.e
    b.e, b.state, b.left = e, r.state, r.left
    local _, tex = CS.ItemInfo(e.item)
    b.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
    local col = CS.COLORS[r.state] or CS.COLORS.ok
    b:SetBackdropBorderColor(col[1], col[2], col[3], 1)
    if r.state == "missing" then
      b.icon:SetVertexColor(1, .35, .35)
      b.icon:SetDesaturated(r.count == 0)
      b.time:SetText("")
    else
      b.icon:SetVertexColor(1, 1, 1)
      b.icon:SetDesaturated(false)
      local show = r.state == "low" or S().timers == "1"
      b.time:SetText(show and CS.Time(r.left) or "")
      if r.state == "low" then b.time:SetTextColor(1, .82, .2) else b.time:SetTextColor(1, 1, 1) end
    end
    if S().counts == "1" or r.count == 0 then
      b.count:SetText(r.count)
      if r.count == 0 then b.count:SetTextColor(1, .3, .3) else b.count:SetTextColor(1, 1, 1) end
    else
      b.count:SetText("")
    end
  end

  -- the rows the bar shows (all, or only the ones that need you)
  function CS.Shown(rows)
    local out = {}
    for _, r in ipairs(rows) do
      if S().show ~= "problems" or r.state ~= "ok" then table.insert(out, r) end
    end
    return out
  end

  -- lay buttons out in frame; returns how many
  function CS.Layout(frame, buttons, rows, make)
    local size = Num(S().size, 34)
    local gap = Num(S().spacing, 4)
    local per = math.max(1, Num(S().per, 10))
    local vertical = S().vertical == "1"
    for _, b in ipairs(buttons) do b:Hide() end
    local n = table.getn(rows)
    for ii = 1, n do
      local i = ii
      local b = buttons[i]
      if not b then
        b = make()
        buttons[i] = b
      end
      local line = math.floor((i - 1) / per)
      local pos = i - 1 - line * per
      local x, y = pos * (size + gap), line * (size + gap)
      if vertical then x, y = y, x end
      b:SetWidth(size)
      b:SetHeight(size)
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
      CS.Paint(b, rows[i])
      b:Show()
    end
    local cols = math.min(math.max(n, 1), per)
    local lines = math.max(1, math.ceil(n / per))
    local w, h = cols * size + (cols - 1) * gap, lines * size + (lines - 1) * gap
    if vertical then w, h = h, w end
    frame:SetWidth(math.max(size, w))
    frame:SetHeight(math.max(size, h))
    return n
  end

  -- sample rows for layout mode and the preview: the active (or first) list, its real states when known
  function CS.Samples()
    if table.getn(CS.rows) > 0 then return CS.rows end
    local l = CS.Active() or CS.Lists()[1]
    local out = {}
    local states = { "missing", "low", "ok" }
    for i, e in ipairs(l and l.items or {}) do
      if e.on ~= "0" then
        local st = states[math.mod(i - 1, 3) + 1]
        table.insert(out, { e = e, state = st, left = (st == "low") and 150 or 2400, count = CS.Count(e.item) })
      end
    end
    if table.getn(out) == 0 then
      table.insert(out, { e = { item = 13510, name = "Flask of the Titans", buff = "Flask of the Titans" }, state = "missing", count = 1 })
      table.insert(out, { e = { item = 13452, name = "Elixir of the Mongoose", buff = "Elixir of the Mongoose" }, state = "low", left = 150, count = 3 })
      table.insert(out, { e = { item = 20452, name = "Smoked Desert Dumplings", buff = "Well Fed" }, state = "ok", left = 840, count = 12 })
    end
    return out
  end

  local bar = CreateFrame("Frame", "pfConsumes", UIParent)
  bar:SetFrameStrata("MEDIUM")
  bar:SetPoint("CENTER", UIParent, "CENTER", 0, 190)
  bar:SetWidth(34)
  bar:SetHeight(34)
  bar.buttons = {}
  CS.bar = bar
  local function MakeButton() return CS.NewButton(bar) end

  function CS.UpdateBar()
    local layout = pfUI.unlock and pfUI.unlock:IsShown()
    local rows = layout and CS.Samples() or CS.Shown(CS.rows)
    local n = CS.Layout(bar, bar.buttons, rows, MakeButton)
    bar:SetAlpha(Num(S().alpha, 1))
    local want = S().bar == "1" and n > 0
    if not layout then
      if not CS.list then want = false end
      if S().hidecombat == "1" and UnitAffectingCombat("player") then want = false end
    end
    if want or layout then bar:Show() else bar:Hide() end
  end

  -- missing icons pulse (and the bar is drawn again while layout mode is open)
  bar:SetScript("OnUpdate", function()
    if S().pulse ~= "1" then return end
    local a = .55 + .45 * math.abs(math.sin(GetTime() * 3))
    for _, b in ipairs(this.buttons) do
      if b:IsShown() then b.icon:SetAlpha(b.state == "missing" and a or 1) end
    end
  end)

  function CS.Changed()
    CS.last = {}
    CS.bagsDirty = true
    CS.Scan()
  end
  function CS.OpenOptions()
    if pfUI.gui and pfUI.octoui and pfUI.octoui.Options and pfUI.octoui.Options.Open then
      if not pfUI.gui:IsShown() then pfUI.gui:Show() end
      pfUI.octoui.Options:Open("consumes")
    end
  end

  -- ---------------------------------------------------------------- events

  local ev = CreateFrame("Frame")
  CS.ev = ev
  for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_AURAS_CHANGED", "BAG_UPDATE", "UNIT_INVENTORY_CHANGED",
                       "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_DEAD", "PLAYER_UNGHOST", "PLAYER_ALIVE" }) do
    pcall(ev.RegisterEvent, ev, e)
  end
  ev:SetScript("OnEvent", function()
    if event == "PLAYER_AURAS_CHANGED" then CS.names = {} end
    if event == "BAG_UPDATE" then CS.bagsDirty = true end
    if event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then return end
    this.soon = true
  end)
  -- a scan a second (timers count down), at once after an event
  ev:SetScript("OnUpdate", function()
    this.t = (this.t or 0) + arg1
    local open = pfUI.unlock and pfUI.unlock:IsShown()
    if open ~= this.open then this.open = open this.soon = true end
    if this.t < 1 and not (this.soon and this.t > .2) then return end
    this.t, this.soon = 0, nil
    CS.Scan()
  end)
  if pfUI.context and pfUI.context.listeners then
    pfUI.context.listeners.consumes = function() CS.last = {} CS.Scan() end
  end
  if UpdateMovable then UpdateMovable(bar) end

  _G.SLASH_PFCONSUMES1, _G.SLASH_PFCONSUMES2 = "/consumes", "/cons"
  SlashCmdList["PFCONSUMES"] = function(msg)
    msg = Lower(msg)
    if msg == "next" or msg == "use" then CS.UseNext()
    elseif msg == "check" then
      CS.Changed()
      if not CS.list then Chat("no list applies here (" .. CS.Zone() .. ").")
      elseif table.getn(CS.rows) == 0 then Chat("nothing ticked on " .. (CS.list.name or "?") .. ".")
      else
        for _, r in ipairs(CS.rows) do Chat(r.e.name .. ": " .. r.state .. (r.left and r.left >= 0 and (" " .. CS.Time(r.left)) or "") .. ", " .. r.count .. " in bags") end
      end
    elseif string.find(msg, "^add ") then
      local e, why = CS.Add(CS.Active() or CS.Lists()[1], string.sub(msg, 5))
      Chat(e and (e.name .. " added.") or why)
    else
      CS.OpenOptions()
    end
  end

  CS.Scan()
end)
