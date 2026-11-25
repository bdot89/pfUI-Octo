-- pfUI Octo: craft cost against sell price in the profession windows (modules/professions-profit.lua), run by
-- tests\run.lua. 25 Nov 2026, Wolfahrt on Discord.
local ok = octo_ok
local PP = pfUI.professionsProfit
local AH = pfUI.auction
ok(PP and PP.Craft and PP.Price and PP.Short, "craft profit loaded (pfUI.professionsProfit)")
if not PP or not AH then return end
ok(PP.Short(12345) == "1g 23s" and PP.Short(-4500, true) == "-45s" and PP.Short(50, true) == "+50c", "money in short")

-- a recipe: 2 x reagent A (auction house 1s each) + 1 vial (vendor only, buys at 20c) -> 1 potion (auction house 50s)
local valueWas, keyWas, sellWas = AH.Value, AH.ItemKey, rawget(_G, "pfSellData")
local prices = { ["1001"] = 100, ["1003"] = 5000 }
AH.Value = function(key) return prices[key] end
_G.pfSellData = { [1002] = "1,20", [1003] = "300,1200" }
local dbWas = rawget(_G, "pfDB")
_G.pfDB = { items = { data = { [1002] = { V = { [5] = 1 } } } } }
local k = {
  numReagents = function() return 2 end,
  reagent = function(i, r) if r == 1 then return "|Hitem:1001:0:0:0|h", 2 end return "|Hitem:1002:0:0:0|h", 1 end,
  itemLink = function() return "|Hitem:1003:0:0:0|h" end,
  made = function() return 1 end,
}
local c = PP.Craft(k, 1)
ok(c and c.cost == 220 and c.value == 5000 and c.profit == 4780, "cost 2s 20c (auction house + vendor), sells 50s, profit +47s 80c")
prices["1003"] = nil
c = PP.Craft(k, 1)
ok(c.value == 300 and c.from == "vendor" and c.profit == 80, "never seen on the auction house: its vendor sell price")
_G.pfSellData = {}
c = PP.Craft(k, 1)
ok(c.missing == 1 and c.profit == nil, "a reagent without a price: no profit shown, never a guess")
k.itemLink = function() return "|Henchant:7867|h" end
c = PP.Craft(k, 1)
ok(c.enchant and c.value == nil, "an enchant makes no item: cost only")
AH.Value, AH.ItemKey, _G.pfSellData = valueWas, keyWas, sellWas
_G.pfDB = dbWas
