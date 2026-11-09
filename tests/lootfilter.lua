-- pfUI Octo: the loot filter (modules/lootfilter.lua) and Auto Loot's item-by-item
-- looting for the loot threshold (modules/autoloot.lua), run by tests\run.lua.
local ok = octo_ok
local LF, AL = pfUI.lootfilter, pfUI.autoloot
ok(LF and LF.Keep and LF.Active, "loot filter loaded (pfUI.lootfilter)")
ok(AL and AL.TakeItems and AL.Normalize and AL.Threshold, "Auto Loot can loot item by item")
if not LF or not AL then return end
local O = pfUI.octoui and pfUI.octoui.Options
ok(O and O.BUILD and O.BUILD.lootfilter, "options page Loot Filter registered")

local saved = {}
for _, k in ipairs({ "GetItemInfo", "C_Loot", "GetLootMethod", "GetLootThreshold", "GetNumRaidMembers", "GetNumPartyMembers" }) do saved[k] = rawget(_G, k) end
local items = {
  [4865] = { "Ruined Pelt", "item:4865:0:0:0", 0, 0, "Junk", "Junk", 5, "", "x" },
  [2589] = { "Linen Cloth", "item:2589:0:0:0", 1, 0, "Trade Goods", "Trade Goods", 20, "", "x" },
  [5000] = { "Green Sword", "item:5000:0:0:0", 2, 10, "Weapon", "One-Handed Swords", 1, "INVTYPE_WEAPON", "x" },
  [5001] = { "Gnoll Paw", "item:5001:0:0:0", 1, 0, "Quest", "Quest", 20, "", "x" },
  [5002] = { "Grey Quest Thing", "item:5002:0:0:0", 0, 0, "Quest", "Quest", 20, "", "x" },
}
_G.GetItemInfo = function(id) local t = items[tonumber(id)] if t then return unpack(t) end end

LF.Reset()
ok(LF.Active(), "the starting rules are on")
ok(not LF.Keep({ id = 4865 }), "grey items are left")
ok(LF.Keep({ id = 2589 }) and LF.Keep({ id = 5000 }), "other items are taken")
ok(LF.Keep({ id = 5002 }), "a grey quest item is taken: Quest items come first")
ok(LF.Keep({ id = 99999, link = "|cff9d9d9d|Hitem:99999:0:0:0|h[Unknown]|h|r", quality = 0 }) == false, "an item the client hasn't seen: quality from the link colour")
local before = LF.skipped
LF.Keep({ id = 4865 }, true)
ok(LF.skipped == before, "a try is not counted")
LF.List()[2].on = "0"
ok(LF.Keep({ id = 4865 }), "a switched-off rule is skipped")
LF.Reset()
LF.Move(2, -1)
ok(LF.List()[1].name == "Grey items (vendor trash)" and not LF.Keep({ id = 5002 }), "order matters: grey first leaves the grey quest item")
LF.Reset()
LF.Add() LF.List()[5].rule = 'Name("Linen")'
ok(LF.Keep({ id = 2589 }) == false, "an added rule works")
LF.Remove(5)
ok(table.getn(LF.List()) == 4, "a rule is removed")

-- a rule's own items (the item box), with or without text
LF.Add()
local nr = LF.List()[5]
ok(nr.rule == "" and type(nr.items) == "table", "a new rule starts as an empty item box")
ok(LF.Keep({ id = 2589 }), "an empty new rule matches nothing")
nr.items = { 2589 }
ok(LF.Keep({ id = 2589 }) == false and LF.Keep({ id = 5000 }), "an item in the box matches, others don't")
LF.Remove(5)
LF.List()[2].items = { 4865 } LF.List()[2].rule = ""
ok(not LF.Keep({ id = 4865 }) and LF.Keep({ id = 99998, quality = 0 }), "box only: the listed grey is left, other greys taken")
LF.Reset()

-- the item box widget: add (drop or pick) and take out
local W = pfUI.octoui and pfUI.octoui.W
ok(W and W.ItemBox and W.ItemPicker and W.CursorItem, "the item box widget is there")
if W and W.ItemBox and O and O.pages then
  O:Open("lootfilter")
  local pg = O.pages.lootfilter
  if pg then
    local store = { 2589 }
    local changed = 0
    local row = W.ItemBox(pg, "Test box", nil, function() return store end, function(v) store = v end, function() changed = changed + 1 end)
    row.Add(5000)
    ok(table.getn(store) == 2 and store[2] == 5000 and changed == 1, "an item is added")
    row.Add(5000)
    ok(table.getn(store) == 2, "...not twice")
    row.Remove(2589)
    ok(table.getn(store) == 1 and store[1] == 5000, "right-click takes one out")
  end
  local savedHas = rawget(_G, "CursorHasItem")
  _G.CursorHasItem = function() return true end
  W.cursorItem = 2589
  ok(W.CursorItem() == 2589, "the cursor's item is known while it is held")
  _G.CursorHasItem = function() return false end
  ok(W.CursorItem() == nil and W.cursorItem == nil, "...and forgotten when the cursor is empty")
  _G.CursorHasItem = savedHas

  -- icons (9 Nov 2026: the picker showed only question marks): GetItemInfo
  -- answering a texture number, the bag slot knows the path
  local sv = { rawget(_G, "GetContainerNumSlots"), rawget(_G, "GetContainerItemLink"), rawget(_G, "GetContainerItemInfo"), rawget(_G, "GetItemInfo") }
  _G.GetItemInfo = function(id) if id == 7001 then return "Thing", "item:7001:0:0:0", 1, 5, 5, "Junk", "Junk", 1, "", 132345, 10 end end
  _G.GetContainerNumSlots = function(bag) return bag == 0 and 2 or 0 end
  _G.GetContainerItemLink = function(bag, slot) if bag == 0 and slot == 2 then return "|cffffffff|Hitem:7001:0:0:0|h[Thing]|h|r" end end
  _G.GetContainerItemInfo = function(bag, slot) if bag == 0 and slot == 2 then return "Interface\\Icons\\INV_Misc_Thing", 1 end end
  W.texCache[7001] = nil
  ok(W.ItemTexture(7001) == "Interface\\Icons\\INV_Misc_Thing", "an item's icon is found from its bag slot when GetItemInfo has no path")
  _G.GetItemInfo = function(id) if id == 7002 then return "Other", "item:7002:0:0:0", 1, 5, "Junk", "Junk", 1, "", "INTERFACE\\ICONS\\INV_Other" end end
  local got = W.ItemTexture(7002)
  ok(got == "INTERFACE\\ICONS\\INV_Other", "a path in capitals is still a path (" .. tostring(got) .. ")")
  _G.GetContainerNumSlots, _G.GetContainerItemLink, _G.GetContainerItemInfo, _G.GetItemInfo = sv[1], sv[2], sv[3], sv[4]
end

-- the scan's shapes
local a = AL.Normalize({ { guid = "0xA", items = { { link = "item:4865", count = 2 }, { itemID = 2589 } }, money = 120 } })
ok(table.getn(a) == 2 and a[1].guid == "0xA" and a[1].id == 4865 and a[1].count == 2, "per corpse with items")
local b = AL.Normalize({ { guid = "0xB", itemID = 5000 }, { guid = "0xB", link = "|cff1eff00|Hitem:5000:0:0:0|h[Green Sword]|h|r" } })
ok(table.getn(b) == 2 and b[2].quality == 2, "flat list with a link: quality from its colour")
local c, u = AL.Normalize({ ["0xC"] = { { id = 2589 }, { id = 4865 } } })
ok(table.getn(c) == 2 and u["0xC"].n == 2, "a map of corpses")
ok(table.getn(AL.Normalize(nil)) == 0 and table.getn(AL.Normalize("x")) == 0, "nothing / nonsense: no items, no error")

-- taking: a corpse with nothing to leave is looted whole, the rest item by item
local whole, single = {}, {}
_G.C_Loot = {
  LootAllCorpses = function() return true end, IsScanInProgress = function() return false end,
  ScanNearbyLoot = function() return true end, GetLastScanResults = function() return nil end,
  LootUnit = function(g) table.insert(whole, g) return true end,
  LootUnitItem = function(g, id) table.insert(single, g .. ":" .. id) return true end,
}
_G.GetNumRaidMembers = function() return 0 end
_G.GetNumPartyMembers = function() return 0 end
local res = {
  { guid = "0x1", items = { { itemID = 2589 }, { itemID = 5000 } }, money = 50 },
  { guid = "0x2", items = { { itemID = 2589 }, { itemID = 4865 } } },
  { guid = "0x3", items = { { itemID = 4865 } }, money = 10 },
}
AL.TakeItems(res)
ok(table.getn(whole) == 1 and whole[1] == "0x1", "a corpse with only wanted items is looted whole (coins too)")
ok(table.getn(single) == 1 and single[1] == "0x2:2589", "a corpse with trash: only the wanted item is taken")

-- master loot: the threshold and better is left for the master looter
whole, single = {}, {}
_G.GetNumRaidMembers = function() return 10 end
_G.GetLootMethod = function() return "master", 0 end
_G.GetLootThreshold = function() return 2 end
ok(AL.Threshold() == 2 and AL.ItemMode(), "master loot in a raid: item by item, threshold green")
AL.TakeItems({ { guid = "0x9", items = { { itemID = 5000 }, { itemID = 2589 } } } })
ok(table.getn(whole) == 0 and table.getn(single) == 1 and single[1] == "0x9:2589", "the green sword is left for the master looter, the cloth taken")
_G.GetLootMethod = function() return "freeforall" end
ok(AL.Threshold() == nil, "free for all: no threshold")
_G.GetLootMethod = function() return "group" end
ok(AL.Threshold() == 2, "group loot: the roll gets them")

-- a pass in item mode: scan, then take when the scan is in
local scans = 0
_G.C_Loot.ScanNearbyLoot = function() scans = scans + 1 return true end
_G.C_Loot.GetLastScanResults = function() return { { guid = "0x7", items = { { itemID = 2589 } } } } end
whole, single = {}, {}
local st = AL.state
st.walking, st.want, st.due, st.settleUntil = nil, nil, nil, 0
pfUI_config.autoloot.enable = "1"
AL.Run(1000)
ok(scans == 1 and st.itemScan, "a pass in a group starts with a scan")
AL.Step(1000.5, false)
ok(table.getn(single) == 1 or table.getn(whole) == 1, "when the scan is in, the wanted item is taken")
AL.Step(1001, false)
ok(not st.walking, "...and the pass ends")
pfUI_config.autoloot.enable = "0"

-- no group, no rules on: whole corpses as before
_G.GetNumRaidMembers = function() return 0 end
for _, r in ipairs(LF.List()) do r.on = "0" end
ok(not AL.ItemMode(), "alone with no rules on: LootAllCorpses as before")
LF.Reset()

for k, v in pairs(saved) do _G[k] = v end
