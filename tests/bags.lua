-- pfUI Octo: the Bagnon-style bag windows (modules/bags-octo.lua, bags-options.lua),
-- run by tests\run.lua. Layout numbers, hidden bags, free slots (plain and ClassicAPI),
-- and both windows laid out on pfUI's own bag slots.
local ok = octo_ok
local BO = pfUI.bagsOcto
ok(BO and BO.Places and BO.Metrics and BO.Layout, "bags-octo loaded (pfUI.bagsOcto)")
if not BO then return end
local S = pfUI_config.bagsocto
ok(S and S.enable == "1" and S.columns == "10" and S.hidden == "", "bag window defaults (C.bagsocto)")
local O = pfUI.octoui and pfUI.octoui.Options
ok(O and O.BUILD and O.BUILD.bagsocto, "options page Bags (bagsocto) registered")

local saved = {}
for k, v in pairs(S) do saved[k] = v end
local savedG = {}
for _, k in ipairs({ "GetContainerNumSlots", "GetContainerItemInfo", "C_UnitAuras", "C_Container", "GetKeyRingSize" }) do
  savedG[k] = rawget(_G, k)
end

-- ---------------------------------------------------------------- where slots go
do
  local order = { 0, 1, 2 }
  local list, rows = BO.Places(order, { [0] = 4, [1] = 3, [2] = 2 }, 3)
  ok(table.getn(list) == 9 and rows == 3, "9 slots in 3 columns = 3 rows")
  ok(list[4].bag == 0 and list[4].col == 0 and list[4].row == 1, "the 4th slot starts row 2")
  list, rows = BO.Places(order, { [0] = 4, [1] = 3, [2] = 2 }, 3, nil, true)
  ok(rows == 4 and list[5].bag == 1 and list[5].col == 0 and list[5].row == 2, "each bag on a new row: bag 1 starts row 3")
  list = BO.Places(order, { [0] = 4, [1] = 3, [2] = 2 }, 3, nil, false, true)
  ok(list[1].bag == 2 and list[1].slot == 2 and list[9].bag == 0 and list[9].slot == 1, "last slot first")
  list, rows = BO.Places(order, { [0] = 4, [1] = 3, [2] = 2 }, 3, function(b) return b == 1 end)
  ok(table.getn(list) == 6 and rows == 2, "a hidden bag's slots are left out")
  list, rows = BO.Places(order, {}, 3)
  ok(table.getn(list) == 0 and rows == 0, "no bags: no rows")
end

-- ---------------------------------------------------------------- hidden bags
do
  S.hidden = ""
  BO.SetHidden(2, true)
  BO.SetHidden(-1, true)
  ok(BO.Hidden(2) and BO.Hidden(-1) and not BO.Hidden(1) and not BO.Hidden(-2), "hidden bags kept by number (" .. S.hidden .. ")")
  BO.SetHidden(2, false)
  ok(not BO.Hidden(2) and BO.Hidden(-1), "a bag shown again")
  BO.SetHidden(-1, false)
  ok(S.hidden == "", "nothing hidden: empty list")
end

-- ---------------------------------------------------------------- window measures
do
  local sizes = { [0] = 16, [1] = 14, [2] = 0, [3] = 0, [4] = 0, [-2] = 0 }
  S.columns, S.size, S.spacing, S.search, S.bagbar, S.free, S.money = "10", "30", "2", "1", "1", "1", "1"
  local m = BO.Metrics("bags", sizes)
  ok(m.rows == 3 and m.gridW == 10 * 32 - 2 and m.w == m.gridW + 2 * BO.PAD, "30 slots, 10 columns: 3 rows, width from the grid")
  ok(m.searchY and m.barY and m.footY and m.gridY > m.barY, "search, bag bar, grid, footer from the top")
  S.search, S.bagbar = "0", "0"
  local m2 = BO.Metrics("bags", sizes)
  ok(not m2.searchY and not m2.barY and m2.h == m.h - (BO.SEARCH + 4) - (BO.BAR + 4), "no search / bag bar: shorter window")
  S.free, S.money = "0", "0"
  ok(not BO.Metrics("bags", sizes).footY, "no free slots / money: no footer")
  S.free = "1"
  local mb = BO.Metrics("bank", { [-1] = 24 })
  ok(not mb.searchY and mb.footY and mb.cols == 14, "bank: no search box, its own columns")
  S.columns = "4"
  local small = BO.Metrics("bags", { [0] = 2 })
  ok(small.w == BO.MINW + 2 * BO.PAD, "a small grid keeps the title bar's room")
  for k, v in pairs(saved) do S[k] = v end
end

-- ---------------------------------------------------------------- free slots
do
  local filled = { [0] = { [1] = true, [3] = true }, [1] = { [2] = true } }
  _G.GetContainerNumSlots = function(bag) if bag == 0 then return 4 elseif bag == 1 then return 6 end return 0 end
  _G.GetContainerItemInfo = function(bag, slot) if filled[bag] and filled[bag][slot] then return "Interface\\Icons\\INV_Misc_Rune_01", 1 end end
  _G.C_UnitAuras, _G.C_Container = nil, nil
  local free, total = BO.Free("bags")
  ok(free == 7 and total == 10, "free slots counted slot by slot without ClassicAPI (" .. free .. " / " .. total .. ")")
  _G.C_UnitAuras = {}
  _G.C_Container = { GetContainerNumFreeSlots = function(bag) return bag == 0 and 1 or 0, 0 end }
  free = BO.Free("bags")
  ok(free == 1, "ClassicAPI: C_Container.GetContainerNumFreeSlots per bag")
  _G.C_Container = { GetContainerNumFreeSlots = function() error("no") end }
  free = BO.Free("bags")
  ok(free == 7, "ClassicAPI error: back to counting")
  _G.C_UnitAuras, _G.C_Container = nil, nil
end

-- ---------------------------------------------------------------- the real windows
do
  _G.GetContainerNumSlots = function(bag) if bag == 0 then return 16 elseif bag == 1 then return 6 elseif bag == -1 then return 24 end return 0 end
  _G.GetContainerItemInfo = function() end
  local PB = pfUI.bag
  -- (the mock's InputBoxTemplate has no named side textures)
  for _, n in ipairs({ "pfUIBagSearchLeft", "pfUIBagSearchMiddle", "pfUIBagSearchRight" }) do
    if not rawget(_G, n) then rawset(_G, n, { SetTexture = function() end }) end
  end
  -- (nor do the item button templates have their parts: pfUI's slot buttons
  -- are made here the way bags.lua keeps them, so it only updates them)
  local made = {}
  for _, bag in ipairs({ -2, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }) do
    if not pfUI.bags[bag] then
      local holder = CreateFrame("Frame")
      holder.slots = {}
      for slot = 1, 24 do
        local f = CreateFrame("Button")
        f.backdrop = CreateFrame("Frame")
        f.qtext = f:CreateFontString()
        holder.slots[slot] = { frame = f, bag = bag, slot = slot }
      end
      pfUI.bags[bag] = holder
    end
    for slot = 1, 24 do
      for _, part in ipairs({ "Cooldown", "Count", "IconTexture", "NormalTexture" }) do
        local n = "pfBag" .. bag .. "item" .. slot .. part
        if not rawget(_G, n) then rawset(_G, n, CreateFrame("Frame")) table.insert(made, n) end
      end
    end
  end
  -- (the chat module does not start in the mock: no chat frame to size the bags from)
  local appbags = pfUI_config.appearance.bags
  local savedIcon = appbags.icon_size
  appbags.icon_size = "30"
  local good, err = pcall(function()
    if not PB.right then PB:CreateBags() end
    if not PB.left then PB:CreateBags("bank") end
    BO.Refresh()
  end)
  ok(good, "both windows lay out on pfUI's bag slots: " .. tostring(err))
  if good and PB.right and PB.right.octo then
    local o = PB.right.octo
    ok(o.head and o.bar and o.foot and table.getn(o.bags) == 6, "bag window: title bar, bag bar of 6, footer")
    ok(PB.left.octo and table.getn(PB.left.octo.bags) == 7, "bank window: bag bar of 7")
    -- a hidden bag's slot stays hidden when pfUI updates it
    BO.SetHidden(1, true)
    PB:UpdateSlot(1, 1)
    local sl = pfUI.bags[1] and pfUI.bags[1].slots[1]
    ok(sl and sl.frame and not sl.frame:IsShown(), "a slot of a hidden bag stays hidden after pfUI updates it")
    BO.SetHidden(1, false)
    PB:UpdateSlot(1, 1)
    ok(sl and sl.frame:IsShown(), "shown again with its bag")

    -- item marks: bag 0 holds a grey bone (1), a quest letter (2), a plate helm (3)
    local items = { [1] = { 1001, 0, "Junk" }, [2] = { 1002, 1, "Quest" }, [3] = { 1003, 4, "Armor" } }
    local keep = {}
    for _, k in ipairs({ "GetContainerItemLink", "GetItemInfo", "C_PlayerInfo", "C_NewItems", "GetInventoryItemLink" }) do keep[k] = rawget(_G, k) end
    _G.GetContainerItemLink = function(bag, slot)
      local it = bag == 0 and items[slot]
      return it and ("|cff9d9d9d|Hitem:" .. it[1] .. ":0:0:0|h[x]|h|r")
    end
    _G.GetContainerItemInfo = function(bag, slot) if bag == 0 and items[slot] then return "Interface\\Icons\\INV_Misc_Rune_01", 1 end end
    _G.GetItemInfo = function(s)
      local _, _, id = string.find(s, "item:(%d+)")
      for _, it in pairs(items) do if it[1] == tonumber(id) then return "x", s, it[2], 1, it[3] end end
    end
    _G.GetInventoryItemLink = function() end
    local m = BO.Marks(0, 1)
    ok(m.junk and not m.quest and not m.new, "grey item: junk coin")
    ok(BO.Marks(0, 2).quest == "quest", "quest item: ? mark")
    S.junk, S.quest = "0", "0"
    m = BO.Marks(0, 1)
    ok(not m.junk and not BO.Marks(0, 2).quest, "junk / quest marks off")
    S.junk, S.quest = "1", "1"
    local appb = pfUI_config.appearance.bags
    local savedUnusable = appb.unusable
    appb.unusable = "1"
    _G.C_UnitAuras = {}
    _G.C_PlayerInfo = { CanUseItem = function(id) return id ~= 1003 end }
    ok(BO.Marks(0, 3).bad and not BO.Marks(0, 1).bad, "ClassicAPI CanUseItem: the plate helm is red")
    _G.C_PlayerInfo = nil
    ok(not BO.Marks(0, 3).bad, "no ClassicAPI: left to pfUI's tooltip check")

    -- new items with ClassicAPI's flag
    local flagged = { [3] = true }
    _G.C_NewItems = {
      IsNewItem = function(bag, slot) return bag == 0 and flagged[slot] or false end,
      RemoveNewItem = function(bag, slot) flagged[slot] = nil end,
      ClearAll = function() flagged = {} end,
    }
    ok(BO.IsNew(0, 3) and not BO.IsNew(0, 1) and not BO.IsNew(-1, 3), "ClassicAPI C_NewItems.IsNewItem (bags 0-4 only)")
    BO.Mark(0, 3)
    local f3 = pfUI.bags[0].slots[3].frame
    ok(f3.octoMarks and f3.octoMarks.glow:IsShown() and BO.glowing[f3], "a new item glows")
    BO.Pulse(1)
    BO.Seen(0, 3)
    ok(not flagged[3] and not f3.octoMarks.glow:IsShown() and not BO.glowing[f3], "mouse over: RemoveNewItem, glow off")
    flagged[1] = true
    BO.ClearNew()
    ok(not flagged[1], "close the bags: C_NewItems.ClearAll")
    S.glownew = "0"
    flagged[1] = true
    ok(not BO.IsNew(0, 1), "glow off: nothing new")
    S.glownew = "1"

    -- new items without ClassicAPI: an id you had none of a moment ago
    _G.C_UnitAuras, _G.C_NewItems = nil, nil
    BO.seen, BO.new, BO.bankCount = nil, {}, {}
    BO.readyAt = 0
    BO.ScanNew()
    ok(not next(BO.new), "first look: everything you carry is already yours")
    items[4] = { 1004, 2, "Armor" }
    BO.ScanNew()
    ok(BO.new[1004] and BO.IsNew(0, 4) and not BO.IsNew(0, 1), "looted item: new")
    items[5], items[1] = items[1], nil
    BO.ScanNew()
    ok(not BO.new[1001] and BO.new[1004], "an item moved to another slot: not new")
    BO.Seen(0, 4)
    ok(not BO.new[1004], "mouse over: seen")
    items[4] = nil
    BO.seen, BO.readyAt = nil, GetTime() + 60
    BO.ScanNew()
    items[6] = { 1006, 1, "Armor" }
    BO.ScanNew()
    ok(not BO.new[1006], "right after login nothing counts as new")

    for k, v in pairs(keep) do rawset(_G, k, v) end
    appb.unusable = savedUnusable
    BO.new, BO.seen = {}, nil
  end
  appbags.icon_size = savedIcon
  for _, n in ipairs(made) do rawset(_G, n, nil) end
  -- the options preview draws from the same numbers
  local BP = pfUI.bagsOctoOptions
  ok(BP and BP.Sizes, "bags-options loaded")
end

-- ---------------------------------------------------------------- bank snapshots
do
  local keep = {}
  for _, k in ipairs({ "GetContainerItemLink", "GetContainerNumSlots", "GetContainerItemInfo", "GetRealmName", "UnitName", "UnitClass" }) do keep[k] = rawget(_G, k) end
  _G.GetRealmName = function() return "Octo" end
  _G.UnitName = function() return "Bdot" end
  _G.UnitClass = function() return "Priest", "PRIEST" end
  _G.GetContainerNumSlots = function(bag) if bag == -1 then return 3 elseif bag == 5 then return 2 end return 0 end
  _G.GetContainerItemLink = function(bag, slot)
    if bag == -1 and slot == 2 then return "|cff0070dd|Hitem:18609:0:0:0|h[Anathema]|h|r" end
    if bag == 5 and slot == 1 then return "|cffffffff|Hitem:2589:0:0:0|h[Linen Cloth]|h|r" end
  end
  _G.GetContainerItemInfo = function(bag, slot) return "Interface\\Icons\\INV_Misc_QuestionMark", 7 end
  pfUI_cache.banks = nil
  BO.bankOpen = nil
  BO.SaveBank()
  ok(pfUI_cache.banks == nil, "a shut bank is never saved over")
  BO.bankOpen = true
  BO.SaveBank()
  local d = pfUI_cache.banks and pfUI_cache.banks.Octo and pfUI_cache.banks.Octo.Bdot
  ok(d and d.total == 5 and d.class == "PRIEST", "the open bank is saved per realm and character (5 slots)")
  ok(d and d.slots[1] == false and d.slots[2].count == 7 and d.slots[4].link and not d.slots[5], "slots kept in order, empty ones as false")
  pfUI_cache.banks.Octo.Alt = { class = "MAGE", at = time(), slots = { false }, total = 1 }
  BO.ShowSnapshot("Alt")
  ok(BO.snap and BO.snap:IsShown() and BO.snap.who == "Alt", "another character's bank opens in the snapshot window")
  BO.ShowSnapshot("Nobody")
  ok(BO.snap.empty:IsShown(), "a character with no snapshot says how to get one")
  BO.ToggleSnapshot()
  ok(not BO.snap:IsShown(), "the Bank tab closes it again")
  BO.bankOpen = nil
  pfUI_cache.banks = nil
  for k, v in pairs(keep) do rawset(_G, k, v) end
end

for k, v in pairs(savedG) do rawset(_G, k, v) end
for k, v in pairs(saved) do S[k] = v end
