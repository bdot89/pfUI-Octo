-- pfUI Octo: bag categories (modules/bagcategories.lua, bagcategories-options.lua),
-- run by tests\run.lua after bags.lua. Which category items go to, groups
-- packed side by side, the real bag window drawn in groups, the page builds.
local ok = octo_ok
local BC, BO, R = pfUI.bagCats, pfUI.bagsOcto, pfUI.rules
ok(BC and BC.Pick and BC.Pack and BC.Group, "bagcategories loaded (pfUI.bagCats)")
if not BC or not BO or not R then return end
local O = pfUI.octoui and pfUI.octoui.Options
ok(O and O.BUILD and O.BUILD.bagcats, "options page Categories (bagcats) registered")
ok(BO.grouper == BC.Group and BO.drawLabels == BC.DrawLabels, "the bag windows ask the categories where slots go")

-- (re-making the windows needs the chat frame the mock lacks: bags.lua lays them out once)
local rawRefresh = BO.Refresh
BO.Refresh = function() end
local S = pfUI_config.bagcategories
ok(S and S.labels == "1", "defaults (C.bagcategories)")
local savedList = S.list
S.list = nil
local list = BC.List()
ok(table.getn(list) == table.getn(BC.DEFAULTS) and list[1].name == "Quest Items" and list[table.getn(list)].name == "Junk",
  "the default list, Quest Items first and Junk last (" .. table.getn(list) .. ")")
local bad
for _, c in ipairs(list) do
  local fn, err = R.Compile(c.rule)
  if not fn then bad = c.name .. ": " .. tostring(err) end
end
ok(not bad, "every default rule compiles " .. tostring(bad or ""))

-- ---------------------------------------------------------------- items (GetItemInfo mocked)
-- 1.12 order: name, link, quality, min level, type, subtype, stack, equip slot, texture
local items = {
  [2770] = { "Copper Ore", "item:2770:0:0:0", 1, 0, "Trade Goods", "Trade Goods", 20, "", "x" },
  [2840] = { "Copper Bar", "item:2840:0:0:0", 1, 0, "Trade Goods", "Trade Goods", 20, "", "x" },
  [2589] = { "Linen Cloth", "item:2589:0:0:0", 1, 0, "Trade Goods", "Trade Goods", 20, "", "x" },
  [2862] = { "Rough Sharpening Stone", "item:2862:0:0:0", 1, 0, "Trade Goods", "Trade Goods", 20, "", "x" },
  [765] = { "Silverleaf", "item:765:0:0:0", 1, 0, "Trade Goods", "Trade Goods", 20, "", "x" },
  [4865] = { "Ruined Pelt", "item:4865:0:0:0", 0, 0, "Junk", "Junk", 5, "", "x" },
  [2140] = { "Carving Knife", "item:2140:0:0:0", 0, 1, "Weapon", "Daggers", 1, "INVTYPE_WEAPON", "x" },
  [9999] = { "Iron Shield", "item:9999:0:0:0", 2, 20, "Armor", "Shields", 1, "INVTYPE_SHIELD", "x" },
  [2318] = { "Light Leather", "item:2318:0:0:0", 1, 0, "Trade Goods", "Trade Goods", 20, "", "x" },
  [5000] = { "Coal", "item:5000:0:0:0", 1, 0, "Reagent", "Reagent", 20, "", "x" },
  [8000] = { "Odd Thing", "item:8000:0:0:0", 1, 0, "Miscellaneous", "Junk", 1, "", "x" },
  [7000] = { "Letter", "item:7000:0:0:0", 1, 0, "Quest", "Quest", 1, "", "x" },
}
local keep = {}
for _, k in ipairs({ "GetItemInfo", "GetContainerItemLink", "GetContainerItemInfo", "GetContainerNumSlots" }) do keep[k] = rawget(_G, k) end
_G.GetItemInfo = function(id)
  local t = items[R.IdOf(id)]
  if t then return unpack(t) end
end

local function Goes(id) return (BC.Pick(R.Info(id))) end
BC.Changed()
ok(Goes(2770) == "Metal & Stone" and Goes(2840) == "Metal & Stone", "ore and bars: Metal & Stone")
ok(Goes(2862) == "Stones & Oils", "a sharpening stone is not metal: Stones & Oils")
ok(Goes(2589) == "Cloth" and Goes(765) == "Herbs" and Goes(2318) == "Leather", "cloth, herbs, leather")
ok(Goes(4865) == "Junk" and Goes(2140) == "Junk", "grey items, gear too: Junk")
ok(Goes(9999) == "Gear", "a green shield: Gear")
ok(Goes(5000) == "Reagents", "Reagents by type")
ok(Goes(7000) == "Quest Items", "a quest item first of all")
ok(Goes(8000) == BC.OTHER, "nothing matches: Other")

-- assigned items win over the rules; a category switched off is skipped
local gear
for i, c in ipairs(list) do if c.name == "Gear" then gear = c end end
gear.items = "2589, 12"
BC.Changed()
ok(Goes(2589) == "Gear", "an assigned item goes to its category whatever the rules say")
gear.items = ""
gear.on = "0"
BC.Changed()
ok(Goes(9999) == BC.OTHER, "Gear off: the shield goes on to the next match (none: Other)")
gear.on = "1"
-- a broken rule never errors
table.insert(list, 1, { name = "Broken", rule = 'Name("x"', items = "", on = "1" })
BC.Changed()
local good, e = pcall(function() return Goes(2770) end)
ok(good and e == "Metal & Stone", "a broken rule takes nothing and breaks nothing: " .. tostring(e))
table.remove(list, 1)
BC.Changed()

-- ---------------------------------------------------------------- packing
do
  local function G(name, n) local l = {} for i = 1, n do l[i] = {} end return { name = name, list = l } end
  local groups = { G("A", 3), G("B", 4), G("C", 12), G("D", 2) }
  local r = BC.Pack(groups, 10, 30, 2, true)
  local step = 32
  ok(groups[1].x == 0 and groups[1].y == 0 and groups[2].y == 0 and groups[2].x == 3 * step - 2 + 2 + BC.GAP,
    "two small groups side by side (B at x " .. tostring(groups[2].x) .. ")")
  ok(groups[3].x == 0 and groups[3].y > 0 and groups[3].w == 10 * step - 2, "a group of 12 in 10 columns: a row of its own, full width")
  ok(groups[4].x == 0 and groups[4].y > groups[3].y, "the next group under it")
  ok(groups[1].list[1].y == BC.LABEL and groups[1].list[3].x == 2 * step, "slots under the group's name, left to right")
  ok(groups[3].list[11].x == 0 and groups[3].list[11].y == groups[3].y + BC.LABEL + step, "the 11th slot wraps")
  ok(r.h == groups[4].y + BC.LABEL + step - 2 and table.getn(r.labels) == 4, "grid height and a label per group")
  local plain = BC.Pack({ G("A", 3) }, 10, 30, 2, false)
  ok(plain.h == 30 and table.getn(plain.labels) == 0, "no names: no room for them")
  ok(BC.Pack({}, 10, 30, 2, true).h == 0, "nothing: no height")
end

-- ---------------------------------------------------------------- the real window
do
  local bag0 = { 2770, 9999, nil, 2840, 4865, nil, 2589 }
  _G.GetContainerNumSlots = function(bag) if bag == 0 then return 8 end return 0 end
  _G.GetContainerItemLink = function(bag, slot)
    local id = bag == 0 and bag0[slot]
    return id and ("|cffffffff|Hitem:" .. id .. ":0:0:0|h[" .. items[id][1] .. "]|h|r")
  end
  _G.GetContainerItemInfo = function(bag, slot) if bag == 0 and bag0[slot] then return "x", 1 end end
  BC.Changed()
  local m = BO.Metrics("bags", BO.Sizes("bags"), true)
  local names = {}
  for _, l in ipairs(m.labels or {}) do table.insert(names, l.text) end
  ok(table.concat(names, ",") == "Gear,Metal & Stone,Cloth,Junk,Empty", "the bag window's groups in order: " .. table.concat(names, ","))
  local placed = true
  for _, e in ipairs(m.places) do if not (e.x and e.y) then placed = false end end
  ok(placed and m.gridH > 0, "every slot has a place")
  local plain = BO.Metrics("bags", BO.Sizes("bags"))
  ok(not plain.labels and not plain.places[1].x, "the options preview keeps the plain grid")
  ok(BC.Find("copper b") and R.IdOf(BC.Find("copper b")) == 2840 and BC.Find("2770") == "2770" and not BC.Find("nothing here"),
    "an item found by part of its name, or by ID")
  -- a window laid out in groups, its names drawn
  local PB = pfUI.bag
  if PB.right then
    local good2, err = pcall(function() BO.Layout("bags") end)
    ok(good2 and PB.right.octoCats and PB.right.octoCats[1] and PB.right.octoCats[1]:GetText() == "Gear",
      "the bag window draws its group names: " .. tostring(err))
    BC.signs.bags = nil
    PB.right:Show()
    good2, err = pcall(BC.Check)
    ok(good2 and BC.signs.bags, "a change in the bags lays the window out again: " .. tostring(err))
  end
end

-- the page builds (with a category picked)
do
  local good, e = pcall(function() O:Page("bagcats") end)
  ok(good, "Categories page builds: " .. tostring(e))
  local BP = pfUI.bagCatsOptions
  if BP then
    BP.try = "copper ore"
    local t = BP.TryText('Name("Ore")')
    ok(string.find(t, "matches this rule", 1, true) and string.find(t, "Metal & Stone", 1, true), "Try it: matches, and where it goes")
    ok(string.find(BP.TryText('Name("Bar")'), "does not match", 1, true), "Try it: no match")
    ok(string.find(BP.Rule('Name("x"'), "ff6060", 1, true) and string.find(BP.Rule('Name("x")'), "fine", 1, true), "the rule check")
    ok(string.find(BP.ItemsText({ items = "2770" }), "Copper Ore", 1, true), "assigned items shown by name")
  end
end

for _, k in ipairs({ "GetItemInfo", "GetContainerItemLink", "GetContainerItemInfo", "GetContainerNumSlots" }) do _G[k] = keep[k] end
S.list = savedList
BC.Changed()
BO.Refresh = rawRefresh
