-- pfUI Octo: missing recipes in the profession windows (modules/professions-missing.lua + professions-data.lua),
-- run by tests\run.lua. 25 Nov 2026, Javelin on Discord.
local ok = octo_ok
local PM = pfUI.professionsMissing
local PO = pfUI.professionsOcto
ok(pfUI.recipeData and pfUI.recipeData["Alchemy"] and pfUI.recipeData["Enchanting"], "every profession's recipes are in the data")
ok(PM and PM.All and PM.Missing and PM.Source, "missing recipes loaded (pfUI.professionsMissing)")
if not PM then return end
local all = PM.All("Alchemy")
ok(all and table.getn(all) > 100, "Alchemy has its recipes (" .. (all and table.getn(all) or 0) .. ")")
local mm
for _, r in ipairs(all or {}) do if r.name == "Minor Mana Potion" then mm = r end end
ok(mm and mm.need == 30 and mm.yellow == 65, "Minor Mana Potion: needs 30, yellow at 65")
ok(PM.All("Smelting") == PM.All("Mining"), "Smelting's window reads Mining's list")

-- known = seen in this character's window; the rest is missing, easiest first, and the search box filters it
pfUI_cache.profknown = nil
local known = PM.Known("Alchemy")
known["Minor Healing Potion"] = 1
local list, total = PM.Missing("Alchemy")
local hasHealing, first
for _, r in ipairs(list) do if r.name == "Minor Healing Potion" then hasHealing = true end end
ok(not hasHealing and table.getn(list) == total - 1, "a known recipe is not missing")
ok(list[1].yellow <= list[2].yellow and list[2].yellow <= list[table.getn(list)].yellow, "easiest first: by where it turns yellow (" .. list[1].name .. ")")
local only = PM.Missing("Alchemy", "mana")
local allMana = true
for _, r in ipairs(only) do if not string.find(string.lower(r.name), "mana", 1, true) then allMana = false end end
ok(table.getn(only) > 0 and allMana, "the search box filters the missing list")

-- where it comes from: a recipe item in pfQuest's database (vendor / drop), else the trainer
local was = rawget(_G, "pfDB")
_G.pfDB = { items = { loc = { [100] = "Recipe: Elixir of Wisdom", [101] = "Formula: Enchant Boots - Minor Agility", [102] = "Recipe: Rare Thing" },
  data = { [100] = { V = { [5] = 1 } }, [101] = { U = { [6] = 2.5, [7] = .5 } }, [102] = {} } },
  units = { loc = { [5] = "Vendor Vic", [6] = "Mob Max", [7] = "Mob Min" }, data = { [5] = { coords = { { 1, 2, 33 } } } } },
  zones = { loc = { [33] = "Stranglethorn Vale" } } }
local s1, s2, s3, s4 = PM.Source("Elixir of Wisdom"), PM.Source("Enchant Boots - Minor Agility"), PM.Source("Rare Thing"), PM.Source("Minor Mana Potion")
ok(s1.tag == "Vendor" and string.find(s1.lines[1], "Vendor Vic (Stranglethorn Vale)", 1, true), "a vendor with its zone")
ok(s2.tag == "Drop" and string.find(s2.lines[1], "Mob Max", 1, true) and string.find(s2.lines[1], "2.5%", 1, true), "drops, the most likely first")
ok(s3.tag == "Quest" and s4.tag == "Trainer", "no vendor or drop = quest / event; no recipe item = the trainer")
_G.pfDB = was

-- the window: the button, the panel swaps for the list and back
local k = PO.KINDS.TradeSkill
local f = getglobal(k.frame)
if f and f.octoProf then
  local lineWas, countWas, nameWas = k.line, k.count, k.name
  k.line = function() return "Alchemy" end
  k.count = function() return 0 end
  local p = PM.Build(k)
  ok(p and p.btn, "a Missing button beside the search box")
  PM.Toggle(k, true)
  ok(p:IsShown() and p.rows[1]:IsShown() and p.rows[1].d, "Missing: the panel lists recipes")
  PM.Toggle(k, false)
  ok(not p:IsShown(), "and back to your own recipes")
  k.line, k.count, k.name = lineWas, countWas, nameWas
end
pfUI_cache.profknown = nil
