-- pfUI Octo: item rules (libs/librules.lua), run by tests\run.lua.
local ok = octo_ok
local R = pfUI.rules
ok(R and R.Compile and R.Match and R.Info, "librules loaded (pfUI.rules)")
if not R then return end

local items = {
  [2770] = { "Copper Ore", "item:2770:0:0:0", 1, 0, "Trade Goods", "Trade Goods", 20, "", "Interface\\Icons\\INV_Ore_Copper_01" },
  [2840] = { "Copper Bar", "item:2840:0:0:0", 1, 0, "Trade Goods", "Trade Goods", 20, "", "Interface\\Icons\\INV_Ingot_02" },
  [3486] = { "Sharpening Stone", "item:3486:0:0:0", 1, 0, "Trade Goods", "Trade Goods", 20, "", "x" },
  [4306] = { "Silk Cloth", "item:4306:0:0:0", 1, 0, "Trade Goods", "Trade Goods", 20, "", "x" },
  [2589] = { "Linen Cloth", "item:2589:0:0:0", 1, 0, "Trade Goods", "Trade Goods", 20, "", "x" },
  [4865] = { "Ruined Pelt", "item:4865:0:0:0", 0, 0, "Junk", "Junk", 5, "", "x" },
  [6256] = { "Fishing Pole", "item:6256:0:0:0", 1, 0, "Weapon", "Fishing Pole", 1, "INVTYPE_2HWEAPON", "x" },
  [9999] = { "Iron Shield", "item:9999:0:0:0", 2, 20, "Armor", "Shields", 1, "INVTYPE_SHIELD", "x" },
  -- ClassicAPI's later order: name, link, quality, item level, min level, type, subtype, stack, slot, texture, price
  [7777] = { "Odd Bar", "item:7777:0:0:0", 3, 40, 35, "Trade Goods", "Metal", 20, "", "x", 1250 },
}
local saved = rawget(_G, "GetItemInfo")
_G.GetItemInfo = function(id) local t = items[tonumber(id)] if t then return unpack(t) end end

local function T(rule, id) local hit, err = R.Test(rule, id) return hit, err end

ok(T('Name("ore")', 2770) and not T('Name("ore")', 2840), "Name: any case, anywhere in the name")
ok(T('NameIs("copper bar")', 2840) and not T('NameIs("copper")', 2840), "NameIs: the whole name")
ok(T('ID(1, 2840)', 2840) and not T('ID(2770)', 2840), "ID")
ok(T('Quality("poor")', 4865) and T('Quality(0)', 4865) and not T('Quality("poor")', 2770), "Quality by name or number")
ok(T('MinQuality("uncommon")', 9999) and not T('MinQuality("uncommon")', 2770), "MinQuality")
ok(T('Equip()', 9999) and T('Equip("SHIELD")', 9999) and not T('Equip()', 2770), "Equip")
ok(T('Level(10, 30)', 9999) and not T('Level(25)', 9999), "Level range")
ok(T('Stackable()', 2770) and not T('Stackable()', 9999), "Stackable")

-- Bread's Metal rule, trimmed to the checks the mock can answer
local metal = '(Name("Ore", "Bar")) and Type("Trade Goods") and not Name("Stone", "Grindstone", "Sharpening") and not Type("Armor", "Quest")'
ok(T(metal, 2770) and T(metal, 2840), "Bread's Metal rule takes ore and bars")
ok(not T(metal, 3486) and not T(metal, 9999), "...not sharpening stones or armour")
ok(T('Name("Cloth") and not Name("Linen")', 4306) and not T('Name("Cloth") and not Name("Linen")', 2589), "and / not")

-- the later GetItemInfo order (ClassicAPI): type, level and price read right
local info = R.Info(7777)
ok(info.type == "Trade Goods" and info.subtype == "Metal" and info.level == 35 and info.value == 1250, "later GetItemInfo order read by the fifth answer")
ok(T('Value(1000, 2000)', 7777) and not T('Value(1, 10)', 7777) and not T('Value(1)', 2770), "Value only when the client gives a price")
ok(R.Info("|cff9d9d9d|Hitem:4865:0:0:0|h[Ruined Pelt]|h|r").id == 4865, "an item link is read")

-- bad rules: told, never an error
local fn, err = R.Compile('Name("ore"')
ok(fn == nil and type(err) == "string", "a broken rule is refused with a reason (" .. tostring(err) .. ")")
ok(not T('Nope("x")', 2770), "an unknown check is no match, not an error")
ok(R.Compile("") == nil, "an empty rule is refused")
local hit, e = T('Name("x")', 123456)
ok(not hit and e, "an item the client does not know yet is reported")
ok(not T('os.exit()', 2770) and not T('print("x")', 2770), "rules only see the checks")

_G.GetItemInfo = saved
