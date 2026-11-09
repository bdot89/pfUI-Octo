pfUI:RegisterModule("bagcategories", "vanilla:tbc", function ()
  -- pfUI Octo :: bag categories (9 Nov 2026). Bread (Discord), on Bagshui:
  -- categories made from item IDs plus rules, e.g. "Metal" takes iron ore and
  -- iron bars but no armour, weapons or quest items; the bag window is drawn
  -- as labelled blocks (Gear, Food, Mana, Scroll, Stone, Metal ...). User:
  -- "please make this be enabled and disabled just like the rest of our
  -- modules inside our addon" - a pfUI module (C.disabled.bagcategories);
  -- off = the plain grid of modules/bags-octo.lua.
  --
  -- Written fresh (no Bagshui code). Rules are libs/librules.lua's (the loot
  -- filter uses the same ones). A category: { name, rule, items = "id,id",
  -- on = "1" | "0" } in C.bagcategories.list, in order: an item goes to the
  -- first category that names its ID in items, else the first whose rule
  -- matches, else Other. Empty slots make their own group at the end.
  -- The groups flow in rows like words: as many as fit side by side.
  -- Settings page: bagcategories-options.lua.
  local BO, R = pfUI.bagsOcto, pfUI.rules
  if not BO or not R then return end

  local BC = {}
  pfUI.bagCats = BC

  local function S() return C.bagcategories end

  BC.LABEL = 13 -- height of a group's name above its slots
  BC.GAP = 6    -- extra room between two groups side by side
  BC.ROWGAP = 4 -- and between two rows of groups

  -- ---------------------------------------------------------------- defaults
  -- (close to Bread's screenshot; 1.12 has few item subtypes, so most go by name)
  BC.HERBS = [[Name("Peacebloom", "Silverleaf", "Earthroot", "Mageroyal", "Briarthorn", "Stranglekelp", "Bruiseweed", "Steelbloom", "Grave Moss", "Kingsblood", "Liferoot", "Fadeleaf")
 or Name("Goldthorn", "Khadgar's Whisker", "Wintersbite", "Firebloom", "Purple Lotus", "Arthas' Tears", "Sungrass", "Blindweed", "Ghost Mushroom", "Gromsblood", "Golden Sansam", "Dreamfoil")
 or Name("Mountain Silversage", "Plaguebloom", "Icecap", "Black Lotus", "Swiftthistle", "Wildvine")]]
  BC.GEMS = [[Name("Malachite", "Tigerseye", "Shadowgem", "Moss Agate", "Moonstone", "Jade", "Citrine", "Aquamarine", "Star Ruby", "Arcane Crystal", "Azerothian Diamond", "Large Opal")
 or Name("Blue Sapphire", "Huge Emerald", "Black Diamond", "Pearl", "Blood of the Mountain")]]
  BC.DEFAULTS = {
    { name = "Quest Items", rule = [[Quest()]] },
    { name = "BoE", rule = [[Equip() and BoE() and MinQuality("uncommon")]] },
    { name = "Gear", rule = [[Equip() and not Quality("poor")]] },
    { name = "Food", rule = [[Type("Consumable") and Tooltip("while eating")]] },
    { name = "Drink", rule = [[Type("Consumable") and Tooltip("while drinking")]] },
    { name = "Potions", rule = [[Type("Consumable") and Name("Potion", "Elixir", "Flask", "Draught", "Rejuvenation")]] },
    { name = "Scrolls", rule = [[Type("Consumable") and Name("Scroll")]] },
    { name = "Stones & Oils", rule = [[Name("Sharpening Stone", "Weightstone", "Wizard Oil", "Mana Oil", "Poison")]] },
    { name = "Herbs", rule = "Type(\"Trade Goods\") and (" .. BC.HERBS .. ")" },
    { name = "Metal & Stone", rule = [[(Name(" Ore", " Bar", "Rough Stone", "Coarse Stone", "Heavy Stone", "Solid Stone", "Dense Stone") or Tooltip("Smelted"))
 and Type("Trade Goods") and not Name("Grindstone", "Sharpening", "Weightstone") and not Type("Armor", "Weapon", "Quest")]] },
    { name = "Gems", rule = "Type(\"Trade Goods\", \"Gem\") and (" .. BC.GEMS .. ")" },
    { name = "Leather", rule = [[Type("Trade Goods") and Name("Leather", "Hide", "Scale", "Scraps")]] },
    { name = "Cloth", rule = [[Type("Trade Goods") and Name("Cloth", "Bolt of", "Silk", "Linen", "Wool", "Mageweave", "Runecloth", "Felcloth")]] },
    { name = "Enchanting", rule = [[Type("Trade Goods") and Name("Dust", "Essence", "Shard", "Nexus Crystal")]] },
    { name = "Reagents", rule = [[Type("Reagent")]] },
    { name = "Trade Goods", rule = [[Type("Trade Goods")]] },
    { name = "Junk", rule = [[Quality("poor")]] },
  }
  BC.OTHER, BC.EMPTY = "Other", "Empty"

  function BC.Copy(c) return { name = c.name, rule = c.rule, items = c.items or "", on = c.on or "1" } end

  -- the saved list (made from the defaults the first time)
  function BC.List()
    local s = S()
    if type(s.list) ~= "table" then
      s.list = {}
      for i, c in ipairs(BC.DEFAULTS) do s.list[i] = BC.Copy(c) end
    end
    return s.list
  end

  function BC.Reset()
    S().list = nil
    BC.Changed()
  end

  -- "1, 2,3" -> { [1] = true, ... }
  function BC.Ids(text)
    local t = {}
    for id in string.gfind(text or "", "(%d+)") do t[tonumber(id)] = true end
    return t
  end

  -- ---------------------------------------------------------------- sorting items
  local cache = {}   -- ["bag:slot"] = { link, cat }
  BC.cache = cache
  local compiled     -- { { cat, fn, ids, name } ... } of the categories that are on

  function BC.Changed()
    compiled = nil
    for k in pairs(cache) do cache[k] = nil end
    BO.Refresh()
  end

  function BC.Compiled()
    if compiled then return compiled end
    compiled = {}
    for i, c in ipairs(BC.List()) do
      if c.on ~= "0" then
        local fn = R.Compile(c.rule or "")
        table.insert(compiled, { index = i, name = c.name or "?", fn = fn, ids = BC.Ids(c.items) })
      end
    end
    return compiled
  end

  -- the category of an item (info from pfUI.rules.Info): its name and order
  function BC.Pick(info)
    local list = BC.Compiled()
    if info.id then
      for n, c in ipairs(list) do
        if c.ids[info.id] then return c.name, n end
      end
    end
    for n, c in ipairs(list) do
      if c.fn and R.Match(c.fn, info) then return c.name, n end
    end
    return BC.OTHER, table.getn(list) + 1
  end

  -- the category of what is in a bag slot (kept until that slot's item changes)
  function BC.Slot(bag, slot)
    local link = GetContainerItemLink(bag, slot)
    if not link then return BC.EMPTY, 10000 end
    local key = bag .. ":" .. slot
    local c = cache[key]
    if c and c.link == link then return c.name, c.n end
    local _, count = GetContainerItemInfo(bag, slot)
    -- (the tooltip of a bag slot shows Soulbound; the bank's main slots and
    -- the keyring are read from the link)
    local tb, ts
    if bag >= 0 then tb, ts = bag, slot end
    local info = R.Info(link, tb, ts, count)
    local name, n = BC.Pick(info)
    -- an item the client does not know yet is asked again next time
    if info.name then cache[key] = { link = link, name = name, n = n } end
    return name, n
  end

  -- ---------------------------------------------------------------- layout
  -- places: bags-octo's slot list (hidden bags already left out). Each slot
  -- gets x / y in pixels from the grid's top left; returns w, h, labels.
  function BC.Group(which, places, m)
    local groups, byName = {}, {}
    for _, e in ipairs(places) do
      local name, n = BC.Slot(e.bag, e.slot)
      local g = byName[name]
      if not g then
        g = { name = name, n = n, list = {} }
        byName[name] = g
        table.insert(groups, g)
      end
      table.insert(g.list, e)
    end
    table.sort(groups, function(a, b) return a.n < b.n end)
    BC.signs[which] = BC.Sign(which)
    return BC.Pack(groups, m.cols, m.size, m.gap, S().labels ~= "0")
  end

  -- groups = { { name, list = { place ... } } ... } in order. Each group is
  -- as wide as it needs (up to cols slots); groups go side by side while
  -- their slots fit in cols, then a new row starts.
  function BC.Pack(groups, cols, size, gap, labels)
    cols = math.max(1, cols)
    local step = size + gap
    local lh = labels and BC.LABEL or 0
    local x, y, used, rowH, w = 0, 0, 0, 0, 0
    local out = {}
    for _, g in ipairs(groups) do
      local n = table.getn(g.list)
      local gc = math.min(n, cols)
      local gr = math.ceil(n / gc)
      local gw, gh = gc * step - gap, lh + gr * step - gap
      if used > 0 and used + gc > cols then
        x, y, used, rowH = 0, y + rowH + BC.ROWGAP, 0, 0
      end
      for i, e in ipairs(g.list) do
        e.x = x + math.mod(i - 1, gc) * step
        e.y = y + lh + math.floor((i - 1) / gc) * step
      end
      if labels then table.insert(out, { text = g.name, x = x, y = y, w = gw + BC.GAP, n = n }) end
      g.x, g.y, g.w, g.h = x, y, gw, gh
      w = math.max(w, x + gw)
      rowH = math.max(rowH, gh)
      x, used = x + gw + gap + BC.GAP, used + gc
    end
    return { w = w, h = (table.getn(groups) > 0) and (y + rowH) or 0, labels = out }
  end

  -- the group names on a window (font strings kept on the window)
  function BC.DrawLabels(f, m)
    f.octoCats = f.octoCats or {}
    local pool = f.octoCats
    local list = m.labels or {}
    for i, l in ipairs(list) do
      local fs = pool[i]
      if not fs then
        fs = f:CreateFontString(nil, "OVERLAY")
        fs:SetFont(pfUI.font_default, 10, "OUTLINE")
        fs:SetJustifyH("LEFT")
        fs:SetHeight(BC.LABEL)
        pool[i] = fs
      end
      fs:ClearAllPoints()
      fs:SetPoint("TOPLEFT", f, "TOPLEFT", m.pad + l.x, -(m.gridY + l.y - 1))
      fs:SetWidth(math.max(l.w, 20))
      if l.text == BC.EMPTY then fs:SetTextColor(.6, .61, .65) else fs:SetTextColor(1, .82, .3) end
      fs:SetText(l.text)
      fs:Show()
    end
    for i = table.getn(list) + 1, table.getn(pool) do pool[i]:Hide() end
  end

  BO.grouper = BC.Group
  BO.drawLabels = BC.DrawLabels

  -- what goes where in a shown window, as one string: when it changes (an
  -- item came, went or moved) the window is laid out again
  function BC.Sign(which)
    local t = {}
    for _, bag in ipairs(BO.ORDER[which]) do
      if not BO.Hidden(bag) then
        for slot = 1, BO.BagSize(bag) do
          local name = BC.Slot(bag, slot)
          table.insert(t, name)
        end
      end
    end
    return table.concat(t, ";")
  end

  BC.signs = {}
  function BC.Check()
    if not BO.On() then return end
    local PB = pfUI.bag
    for which, f in pairs({ bags = PB.right, bank = PB.left }) do
      if f and f:IsShown() then
        local sign = BC.Sign(which)
        if sign ~= BC.signs[which] then
          BC.signs[which] = sign
          BO.Layout(which)
        end
      end
    end
  end

  local rawShown = BO.UpdateShown
  function BO.UpdateShown()
    rawShown()
    BC.Check()
  end

  -- a UI layout switch brings its own categories (octo-layouts.lua loads
  -- after this module: its list of live parts is joined once the game runs)
  local join = CreateFrame("Frame")
  join:RegisterEvent("PLAYER_ENTERING_WORLD")
  join:SetScript("OnEvent", function()
    this:UnregisterAllEvents()
    local live = pfUI.layouts and pfUI.layouts.LIVE
    if live and not live.bagcategories then live.bagcategories = function() BC.Changed() end end
  end)

  -- where an item would go (the options' "Try it")
  function BC.Where(item)
    local info = type(item) == "table" and item or R.Info(item)
    if not info.name then return end
    return (BC.Pick(info))
  end

  -- an item typed in the options: an ID, an item link, "item:123", or part
  -- of the name of something in your bags or bank
  function BC.Find(text)
    if not text or text == "" then return end
    if tonumber(text) or string.find(text, "item:%d+") then return text end
    local want = string.lower(text)
    for _, bag in ipairs({ 0, 1, 2, 3, 4, -1, 5, 6, 7, 8, 9, 10, -2 }) do
      for slot = 1, (bag == -2 and GetKeyRingSize and GetKeyRingSize() or GetContainerNumSlots(bag) or 0) do
        local link = GetContainerItemLink(bag, slot)
        local _, _, name = string.find(link or "", "%[(.-)%]")
        if name and string.find(string.lower(name), want, 1, true) then return link end
      end
    end
  end
end)
