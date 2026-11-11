-- pfUI Octo: the consumables tracker (modules/consumes.lua, consumes-options.lua),
-- run by tests\run.lua. Lists and zones, adding items, reading buffs (ClassicAPI
-- and plain), weapon enchants, states, warnings, using an item, learning a buff.
local ok = octo_ok
local CS = pfUI.consumes
ok(CS and CS.Scan and CS.State and CS.Add and CS.Use, "consumes loaded (pfUI.consumes)")
if not CS then return end
local O = pfUI.octoui and pfUI.octoui.Options
ok(O and O.BUILD and O.BUILD.consumes and O.BUILD.consumesbar, "options pages Tracker (consumes) and Bar and alerts (consumesbar) registered")
local S = pfUI_config.consumes
ok(S and S.warn == "5" and S.bar == "1" and S.sound == "raidwarning" and type(S.lists) == "table", "defaults (C.consumes)")
ok(getglobal("BINDING_NAME_PFCONSUMENEXT") ~= nil, "key binding name for \"use the next missing\"")

-- the catalogue: unique item ids, every category filled, weapon entries have no buff
do
  local seen, dup, n = {}, nil, 0
  for _, c in ipairs(CS.CATS) do
    ok(table.getn(CS.CATALOG[c[1]] or {}) > 0, "catalogue has " .. c[2])
    for _, e in ipairs(CS.CATALOG[c[1]]) do
      n = n + 1
      if seen[e[1]] then dup = e[2] end
      seen[e[1]] = true
    end
  end
  ok(not dup and n > 80, "catalogue: " .. n .. " items, no id twice " .. tostring(dup or ""))
  ok(CS.BYID[13510].buff == "Flask of the Titans" and CS.BYID[18262].buff == "*", "flask buff name, a stone is a weapon enchant")
end

local keep = {}
for _, k in ipairs({ "C_UnitAuras", "GetPlayerBuff", "GetPlayerBuffTexture", "GetPlayerBuffTimeLeft", "GetWeaponEnchantInfo",
  "GetContainerNumSlots", "GetContainerItemLink", "GetContainerItemInfo", "UseContainerItem", "UnitAffectingCombat",
  "UnitIsDeadOrGhost", "GetInventoryItemLink", "SpellIsTargeting", "PickupInventoryItem", "MerchantFrame", "PlaySound",
  "GetItemInfo", "BankFrame", "TradeFrame", "SendMailFrame", "AuctionFrame" }) do keep[k] = rawget(_G, k) end
local shut = { IsVisible = function() return false end }
for _, k in ipairs({ "MerchantFrame", "BankFrame", "TradeFrame", "SendMailFrame", "AuctionFrame" }) do _G[k] = shut end
local savedLists = S.lists
local ctx = pfUI.context
local rawZone = ctx and ctx.Zone
local zone = "raid"
if ctx then ctx.Zone = function() return zone end end

-- bags: bag 0 slot 1 = 3 flasks, slot 2 = 5 mongoose, slot 3 = 2 elemental stones, slot 4 = 1 odd thing
local bag = {
  { "item:13510:0:0:0", 3 }, { "item:13452:0:0:0", 5 }, { "item:18262:0:0:0", 2 }, { "item:7777:0:0:0", 1 },
}
_G.GetContainerNumSlots = function(b) return b == 0 and 4 or 0 end
_G.GetContainerItemLink = function(b, s) return b == 0 and bag[s] and bag[s][1] or nil end
_G.GetContainerItemInfo = function(b, s) if b == 0 and bag[s] then return "Interface\\Icons\\X", bag[s][2] end end
_G.GetItemInfo = function(id) if tonumber(id) == 7777 then return "Odd Brew", "item:7777", 1, 0, "Consumable", "", 1, "", "Interface\\Icons\\Odd" end end
local used = {}
_G.UseContainerItem = function(b, s) table.insert(used, b .. ":" .. s) end
_G.SpellIsTargeting = function() return false end
_G.PickupInventoryItem = function() end
_G.GetInventoryItemLink = function(u, slot) if slot == 16 then return "item:1:0:0:0" end end
local combat, dead = false, false
_G.UnitAffectingCombat = function() return combat end
_G.UnitIsDeadOrGhost = function() return dead end
local sounds = 0
_G.PlaySound = function() sounds = sounds + 1 end

-- buffs through ClassicAPI: { name, seconds left (nil = no timer) }
local auras = {}
local now = GetTime()
_G.C_UnitAuras = { UnitAura = function(u, i)
  local a = auras[i]
  if not a then return end
  return a[1], "tex", 0, nil, a[2] and 3600 or 0, a[2] and (GetTime() + a[2]) or 0, "player", nil, nil, a[3]
end }
local wpn = { false, 0, 0, false, 0, 0 }
_G.GetWeaponEnchantInfo = function() return wpn[1], wpn[2], wpn[3], wpn[4], wpn[5], wpn[6] end

S.lists = {}
CS.bagsDirty = true
local lists = CS.Lists()
ok(table.getn(lists) == 1 and lists[1].name == "Raid" and lists[1].raid == "1" and lists[1].world == "0", "a first list: Raid, raid and dungeon ticked")
local L = lists[1]

-- ---------------------------------------------------------------- adding
do
  local e = CS.Add(L, 13510)
  ok(e and e.buff == "Flask of the Titans" and e.kind == "buff" and e.cat == "flask", "add by id: Flask of the Titans")
  local _, why = CS.Add(L, 13510)
  ok(why and string.find(why, "already"), "the same item twice is refused")
  e = CS.Add(L, "mongoose")
  ok(e and e.item == 13452 and e.buff == "Elixir of the Mongoose", "add by part of a name (bags first)")
  e = CS.Add(L, "item:18262:0:0:0")
  ok(e and e.kind == "weapon" and e.hand == "16" and not e.buff, "add by link: Elemental Sharpening Stone, main hand")
  local e2 = CS.Add(L, 18262)
  ok(e2 and e2.kind == "weapon" and e2.hand == "17", "the same stone again goes on the off hand")
  local _, why2 = CS.Add(L, 18262)
  ok(why2 and string.find(why2, "both hands"), "a third time is refused")
  e = CS.Add(L, "Odd Brew")
  ok(e and e.item == 7777 and e.buff == "Odd Brew" and not e.cat, "an item not in the catalogue: tracked by its own name")
  local _, why3 = CS.Add(L, "no such thing at all")
  ok(why3 and string.find(why3, "No item"), "an unknown name says so")
  ok(table.getn(L.items) == 5, "five items on the list (" .. table.getn(L.items) .. ")")
end

-- ---------------------------------------------------------------- states
do
  auras = { { "Flask of the Titans", 7000 }, { "Elixir of the Mongoose", 120 } }
  wpn = { 1, 20 * 60000, 0, nil, 0, 0 }
  local rows = CS.Scan()
  ok(CS.source == "ClassicAPI", "buffs read through ClassicAPI")
  local by = {}
  for _, r in ipairs(rows) do by[CS.KeyOf(r.e)] = r end
  ok(by["13510"] and by["13510"].state == "ok", "flask up: ok")
  ok(by["13452"] and by["13452"].state == "low" and math.floor(by["13452"].left + .5) == 120, "mongoose 2 min left: running out")
  ok(by["18262:16"] and by["18262:16"].state == "ok", "main hand stone 20 min: ok")
  ok(not by["18262:17"], "no off-hand weapon: the off-hand stone is left out")
  ok(by["7777"] and by["7777"].state == "missing" and by["7777"].count == 1, "odd brew missing, 1 in bags")
  ok(CS.Time(7000) == "2h" and CS.Time(120) == "2m" and CS.Time(45) == "45s" and CS.Time(-1) == "", "time text")

  -- a buff with no timer counts as up
  auras = { { "Flask of the Titans" } }
  ok(CS.State(L.items[1], CS.ReadBuffs()) == "ok", "a buff without a timer: up")
  -- the plain path: names from the (cached) tooltip, time from GetPlayerBuffTimeLeft
  _G.C_UnitAuras = nil
  _G.GetPlayerBuff = function(i) if i < 2 then return i end return -1 end
  _G.GetPlayerBuffTexture = function(b) return "tex" .. b end
  _G.GetPlayerBuffTimeLeft = function(b) return b == 0 and 100 or 0 end
  CS.names = { ["0:tex0"] = "Flask of the Titans", ["1:tex1"] = "Elixir of the Mongoose" }
  local buffs = CS.ReadBuffs()
  ok(CS.source == "plain" and buffs["flask of the titans"] == 100 and buffs["elixir of the mongoose"] == -1, "plain path: names cached, timers from the client")
  local st = CS.State(L.items[1], buffs)
  ok(st == "low", "flask with 100 s left (plain): running out")
end

-- ---------------------------------------------------------------- zones and alerts
do
  _G.GetPlayerBuff = function() return -1 end
  CS.names = {}
  wpn = { nil, 0, 0, nil, 0, 0 }
  CS.last, CS.lastAlert = {}, nil
  zone = "world"
  CS.Scan()
  ok(CS.list == nil and table.getn(CS.rows) == 0 and CS.lastAlert == nil, "open world: the Raid list does not apply, no warning")
  ok(not CS.bar:IsShown(), "no list: the bar hides")
  zone = "raid"
  sounds = 0
  CS.Scan()
  ok(CS.list == L and CS.lastAlert and string.find(CS.lastAlert, "Missing: Flask of the Titans", 1, true), "entering a raid: missing items said (" .. tostring(CS.lastAlert) .. ")")
  ok(sounds == 1, "with the raid warning sound")
  ok(CS.bar:IsShown(), "the bar shows")
  CS.lastAlert = nil
  CS.Scan()
  ok(CS.lastAlert == nil, "said once, not every scan")
  -- quiet in combat: a new problem waits for combat to end
  L.items[1].on = "1"
  _G.C_UnitAuras = { UnitAura = function(u, i)
    local a = auras[i]
    if not a then return end
    return a[1], "tex", 0, nil, 3600, GetTime() + a[2]
  end }
  auras = { { "Flask of the Titans", 7000 } }
  CS.Scan()
  combat = true
  auras = {}
  CS.lastAlert = nil
  CS.Scan()
  ok(CS.lastAlert == nil, "quiet in combat: the flask running out is not said")
  combat = false
  CS.Scan()
  ok(CS.lastAlert and string.find(CS.lastAlert, "Flask", 1, true), "said when combat ends")
  -- only problems on the bar
  S.show = "problems"
  auras = { { "Flask of the Titans", 7000 } }
  CS.Scan()
  local shown = 0
  for _, b in ipairs(CS.bar.buttons) do if b:IsShown() then shown = shown + 1 end end
  ok(shown == table.getn(CS.rows) - 1, "show only problems: the flask that is up is left off (" .. shown .. ")")
  S.show = "all"
  -- spec / layout conditions
  L.spec = "2"
  local C = pfUI_config
  C.gear = C.gear or {}
  local spec = C.gear.specnow
  C.gear.specnow = "1"
  ok(not CS.ListOn(L, "raid"), "a list tied to spec 2 is off in spec 1")
  C.gear.specnow = "2"
  ok(CS.ListOn(L, "raid"), "and on in spec 2")
  C.gear.specnow = spec
  L.spec = ""
end

-- ---------------------------------------------------------------- using
do
  auras = {}
  CS.Scan()
  used = {}
  local nxt = CS.Next()
  ok(nxt and nxt.item == 13510, "next missing: the flask (first on the list)")
  CS.UseNext()
  ok(used[1] == "0:1", "the key uses it from its bag slot (" .. tostring(used[1]) .. ")")
  _G.MerchantFrame = { IsVisible = function() return true end }
  used = {}
  ok(CS.Use(L.items[1]) == false and table.getn(used) == 0, "never while a vendor is open (it would be sold)")
  _G.MerchantFrame = shut
  dead = true
  ok(CS.Use(L.items[1]) == false, "not while dead")
  dead = false
  -- an oil on the main hand: the game asks for a target, the hand is picked
  local picked
  _G.SpellIsTargeting = function() return true end
  _G.PickupInventoryItem = function(slot) picked = slot end
  ok(CS.Use(L.items[3]) and picked == 16, "a stone goes on the main hand")
  _G.SpellIsTargeting = function() return false end
  -- none in the bags
  bag[2] = nil
  CS.bagsDirty = true
  ok(CS.Use(L.items[2]) == false and CS.Count(13452) == 0, "none left: not used")
  bag[2] = { "item:13452:0:0:0", 5 }
  CS.bagsDirty = true
end

-- ---------------------------------------------------------------- learning
do
  local odd = L.items[5]
  auras = { { "Flask of the Titans", 7000 } }
  CS.learning = nil
  ok(CS.Use(odd), "using the odd brew")
  ok(CS.learning and CS.learning.e == odd, "starts learning its buff")
  auras = { { "Flask of the Titans", 7000 }, { "Food", 20 } }
  CS.Scan()
  ok(odd.buff == "Odd Brew" and CS.learning, "eating (Food) is not the buff")
  auras = { { "Flask of the Titans", 7000 }, { "Food", 10 }, { "Strange Glow", 1800 } }
  CS.Scan()
  ok(odd.buff == "Strange Glow" and odd.learned == "1" and not CS.learning, "the new buff is learned (" .. tostring(odd.buff) .. ")")
  local st = CS.State(odd, CS.ReadBuffs())
  ok(st == "ok", "and the odd brew counts as up")
  -- an item used straight from the bags starts learning too
  CS.learning = nil
  _G.UseContainerItem = keep.UseContainerItem
end

-- ---------------------------------------------------------------- cursor and pages
do
  _G.CursorHasItem = function() return true end
  _G.ClearCursor = function() end
  CS.picked = { bag = 0, slot = 4, t = GetTime() }
  local e, why = CS.AddFromCursor(L)
  ok(e == nil and why and string.find(why, "already"), "dropping an item already on the list says so")
  _G.CursorHasItem = nil
  local built = 0
  for _, k in ipairs({ "consumes", "consumesbar" }) do
    local good, err = pcall(function() O:Page(k) end)
    ok(good, "page " .. k .. " builds: " .. tostring(err))
    if good then built = built + 1 end
  end
  local cp = pfUI.consumesOptions
  ok(cp and table.getn(cp.CatalogMenu()) > 80, "the pick list has every catalogue item")
  local bm = cp and cp.BagMenu(CS.NewList("x"))
  ok(bm and table.getn(bm) >= 3, "the bag menu lists the usable items in the bags (" .. tostring(bm and table.getn(bm)) .. ")")
  ok(string.find(cp.Status(), "Watching", 1, true), "preview status: watching the list")
end

-- put things back
for k, v in pairs(keep) do _G[k] = v end
if ctx then ctx.Zone = rawZone end
S.lists = savedLists
CS.last, CS.rows, CS.learning, CS.list = {}, {}, nil, nil
CS.bagsDirty = true
