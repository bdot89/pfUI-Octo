-- pfUI Octo: OctoLazy (modules/octolazy.lua, octolazy-options.lua), run by tests\run.lua.
-- Roll rules (zones, where, safety, wait, Ctrl+Alt), invites, summons, resurrections, duels,
-- battlegrounds, gossip and quests, bag clicks and splits, chat lines, Salvation, the new rule checks.
local ok = octo_ok
local LZ = pfUI.octolazy
ok(LZ and LZ.Decide and LZ.OnRoll and LZ.OnInvite, "OctoLazy loaded (pfUI.octolazy)")
if not LZ then return end
local R = pfUI.rules
local O = pfUI.octoui and pfUI.octoui.Options
ok(O and O.BUILD and O.BUILD.lzrolls and O.BUILD.lzgroup and O.BUILD.lzbg and O.BUILD.lznpc and O.BUILD.lzmore, "its five tabs")
local S = pfUI_config.octolazy
ok(S and S.rolls == "1" and S.summonmode == "late" and S.quests == "shift" and S.salva == "off" and S.worldname == "World", "defaults (C.octolazy)")
ok(rawget(_G, "SLASH_PFOCTOLAZY1") == "/lazy" and _G.BINDING_HEADER_PFLAZY, "/lazy and its key bindings")

local keep = {}
local NAMES = { "GetItemInfo", "GetLootRollItemInfo", "GetLootRollItemLink", "GetLootRollItemID", "RollOnLoot", "GetRealZoneText",
  "GetSubZoneText", "IsInInstance", "GetTime", "IsShiftKeyDown", "IsControlKeyDown", "IsAltKeyDown", "AcceptGroup", "DeclineGroup",
  "GetNumFriends", "GetFriendInfo", "IsInGuild", "GetNumGuildMembers", "GetGuildRosterInfo", "GetBattlefieldStatus",
  "GetSummonConfirmTimeLeft", "ConfirmSummon", "AcceptResurrect", "GetCorpseRecoveryDelay", "CancelDuel", "UnitAffectingCombat",
  "GetGossipOptions", "GetGossipActiveQuests", "GetGossipAvailableQuests", "SelectGossipOption", "SelectGossipActiveQuest",
  "SelectGossipAvailableQuest", "GetNumQuestLogEntries", "GetQuestLogTitle", "UnitName", "GetContainerItemInfo",
  "GetContainerItemLink", "GetContainerNumSlots", "SplitContainerItem", "PickupContainerItem", "GetInventoryItemLink",
  "GetPlayerBuff", "GetPlayerBuffTexture", "CancelPlayerBuff", "UnitClass", "IsEquippedItemType", "GetShapeshiftFormInfo",
  "GetNumRaidMembers", "GetNumPartyMembers", "ConfirmLootRoll", "CursorHasItem", "C_Container" }
for _, k in ipairs(NAMES) do keep[k] = rawget(_G, k) end
-- (the test world's game strings are their own names: the real ones here)
local STR = { ITEM_SPELL_KNOWN = "Already known", LOOT_ROLL_GREED = "%s has selected Greed for: %s", LOOT_ROLL_NEED = "%s has selected Need for: %s",
  LOOT_ROLL_PASSED = "%s passed on: %s", LOOT_ROLL_ROLLED_NEED = "Need Roll - %d for %s by %s", LOOT_ROLL_ROLLED_GREED = "Greed Roll - %d for %s by %s",
  LOOT_ITEM = "%s receives loot: %s.", LOOT_ITEM_MULTIPLE = "%s receives loot: %sx%d.", YOU = "You" }
for k, v in pairs(STR) do table.insert(NAMES, k) keep[k] = rawget(_G, k) _G[k] = v end
local now = 1000
_G.GetTime = function() return now end
local shift, ctrl, alt = false, false, false
_G.IsShiftKeyDown = function() return shift end
_G.IsControlKeyDown = function() return ctrl end
_G.IsAltKeyDown = function() return alt end
local zone, inst = "Zul'Gurub", { true, "raid" }
_G.GetRealZoneText = function() return zone end
_G.GetSubZoneText = function() return "" end
_G.IsInInstance = function() return inst[1], inst[2] end
_G.GetNumRaidMembers = function() return 0 end
_G.GetNumPartyMembers = function() return 0 end
_G.UnitAffectingCombat = function() return false end
_G.CursorHasItem = function() return false end

-- items: id -> name, quality, equip slot, level (1.12 order)
local ITEMS = {
  [19707] = { "Red Hakkari Bijou", 2 }, [19698] = { "Zulian Coin", 2 }, [21761] = { "Corrupted Sand", 2 },
  [22484] = { "Necrotic Rune", 1 }, [9999] = { "Shiny Bracers", 2, "INVTYPE_WRIST", 40, "Armor" }, [8888] = { "Gnome Hat", 3, "INVTYPE_HEAD", 50, "Armor" },
  [7777] = { "Old Bracers", 2, "INVTYPE_WRIST", 30, "Armor" },
}
_G.GetItemInfo = function(id)
  local t = ITEMS[tonumber(id)]
  if not t then return nil end
  return t[1], "item:" .. id .. ":0:0:0", t[2], t[4] or 1, t[5] or "Miscellaneous", "", 1, t[3] or "", "tex"
end
local function Link(id) return "|cff1eff00|Hitem:" .. id .. ":0:0:0|h[" .. ITEMS[id][1] .. "]|h|r" end

-- the rules: first match decides, zone boxes, where
LZ.ResetRules()
local rules = LZ.Rules()
ok(rules[1].zone == "Zul'Gurub" and rules[3].zone == "The Black Morass" and rules[3].act == "greed", "starting rules: rep items each their own rule, with their dungeon")
local function D(id) local info = R.Info(id) info.lines = {} return LZ.Decide(info) end
local act, why = D(19707)
ok(act == "need" and why == "Zul'Gurub: Hakkari Bijous", "a bijou in Zul'Gurub: Need (" .. tostring(act) .. ")")
ok(D(19698) == "need", "a Zul'Gurub coin: Need")
zone = "Stormwind City" inst = { false }
ok(D(19707) == nil, "the same bijou outside Zul'Gurub: no rule (its zone box)")
zone = "The Black Morass" inst = { true, "party" }
ok(D(21761) == "greed", "Corrupted Sand in The Black Morass: Greed")
rules[3].act = "pass"
ok(D(21761) == "pass", "full control: set to Pass, it passes")
rules[3].on = "0"
ok(D(21761) == nil, "switched off: left to you")
LZ.ResetRules()
ok(LZ.ZoneOk("") and LZ.ZoneOk("morass") and LZ.ZoneOk("Zul'Gurub, The Black Morass") and not LZ.ZoneOk("Molten Core"), "\"Only in\": commas, part of a name, any case")
inst = { true, "raid" }
ok(LZ.WhereOk("raid") and LZ.WhereOk("instance") and not LZ.WhereOk("dungeon") and not LZ.WhereOk("world"), "where: raids, instances")

-- a rule of your own: the item box, Need made safe
LZ.AddRule("need", "My bracers", { 9999 })
local info = R.Info(9999) info.lines = {} info.red = true
ok(LZ.Decide(info) == "greed", "Need on something you cannot use becomes Greed")
S.needsafe = "0"
ok(LZ.Decide(info) == "need", "unless that is switched off")
S.needsafe = "1"
LZ.RemoveRule(1)

-- the new checks
local function T(text, id, red, extra)
  local i = R.Info(id) i.lines = extra or {} i.red = red
  return R.Match(R.Compile(text), i)
end
ok(T("Usable()", 9999, false) and not T("Usable()", 9999, true), "Usable(): no red line")
ok(T("Known()", 9999, false, { "already known" }) and not T("Known()", 9999, false), "Known(): \"Already known\"")
_G.GetInventoryItemLink = function(u, slot) if slot == 9 then return "item:7777:0:0:0" end end
ok(T("Upgrade()", 9999) and not T("Upgrade()", 7777), "Upgrade(): a higher level than what you wear")
ok(T("Upgrade()", 8888), "Upgrade(): an empty slot")
inst = { true, "raid" }
ok(T('Instance("raid")', 9999) and not T('Instance("dungeon", "world")', 9999), "Instance(): raid")
inst = { false }
ok(T('Instance("world")', 9999) and T('Instance("none")', 9999), "Instance(): the open world")
_G.UnitClass = function() return "Warrior", "WARRIOR" end
ok(T('Class("warrior")', 9999) and not T('Class("Mage")', 9999), "Class()")

-- a roll: rolled, chat line, frame hidden, history
local rolled = {}
_G.RollOnLoot = function(id, n) table.insert(rolled, { id, n }) end
_G.GetLootRollItemInfo = function(id) return "tex", ITEMS[id] and ITEMS[id][1], 1, ITEMS[id] and ITEMS[id][2], nil end
_G.GetLootRollItemLink = function(id) return ITEMS[id] and Link(id) end
zone = "Zul'Gurub" inst = { true, "raid" }
LZ.history = {}
LZ.OnRoll(19707, 60000)
ok(table.getn(rolled) == 1 and rolled[1][1] == 19707 and rolled[1][2] == 1 and LZ.history[1] and LZ.history[1].act == "need", "a bijou roll: Need at once, noted")
-- Shift: this one is mine
shift = true
LZ.OnRoll(19698, 60000)
shift = false
ok(table.getn(rolled) == 1 and LZ.open[19698], "Shift held: left to you")
-- a wait first
S.rolldelay = "3"
LZ.OnRoll(19698, 60000)
ok(table.getn(rolled) == 1 and LZ.pending[19698], "with a wait: not yet")
now = now + 4
LZ.frame:GetScript("OnUpdate")()
ok(table.getn(rolled) == 2 and rolled[2][1] == 19698 and not LZ.pending[19698], "rolled once the wait is over")
S.rolldelay = "0"
-- over the quality allowed
S.rollmax = "1"
LZ.OnRoll(19707, 60000)
ok(table.getn(rolled) == 2, "a green item over \"roll by itself up to\": left to you")
S.rollmax = "4"
-- the bind on pickup question, only for our rolls
local confirmed
_G.ConfirmLootRoll = function(id, n) confirmed = { id, n } end
LZ.OnConfirmRoll(19698, 1)
ok(confirmed and confirmed[1] == 19698, "our roll's bind on pickup question answered")
confirmed = nil
LZ.OnConfirmRoll(5555, 1)
ok(confirmed == nil, "someone else's roll: not ours to answer")
-- Ctrl + Alt: greens
LZ.open = { [9999] = { quality = 2, link = "x" }, [8888] = { quality = 3, link = "y" } }
S.greenroll = "pass"
LZ.GreenKey()
ok(rolled[3] and rolled[3][1] == 9999 and rolled[3][2] == 0 and not rolled[4], "Ctrl + Alt: the green one passed, the blue one left")
LZ.open = {}

-- invites
local acc, dec = 0, 0
_G.AcceptGroup = function() acc = acc + 1 end
_G.DeclineGroup = function() dec = dec + 1 end
_G.GetNumFriends = function() return 1 end
_G.GetFriendInfo = function() return "Pal" end
_G.IsInGuild = function() return true end
_G.GetNumGuildMembers = function() return 1 end
_G.GetGuildRosterInfo = function() return "Mate" end
_G.GetBattlefieldStatus = function() return "none" end
inst = { false }
ok(LZ.OnInvite("Mate") == "accept" and LZ.OnInvite("pal") == "accept" and acc == 2, "guild and friends: joined")
ok(LZ.OnInvite("Rando") == nil and acc == 2, "anyone else: the window stays")
S.invdecline = "1"
ok(LZ.OnInvite("Rando") == "decline" and dec == 1, "or is turned down")
S.invdecline = "0"
_G.GetBattlefieldStatus = function() return "queued" end
ok(LZ.OnInvite("Mate") == nil, "not while in a battleground queue")
_G.GetBattlefieldStatus = function() return "none" end

-- summons: just before it runs out
local left, summoned = 120, 0
_G.GetSummonConfirmTimeLeft = function() return left end
_G.ConfirmSummon = function() summoned = summoned + 1 end
LZ.OnSummon()
ok(LZ.summonAt and math.abs(LZ.summonAt - (now + 116)) < .01, "summon taken 4 s before it runs out")
now = now + 117
LZ.frame:GetScript("OnUpdate")()
ok(summoned == 1 and not LZ.summonAt, "and taken")
S.summonmode = "wait"
LZ.OnSummon()
ok(math.abs(LZ.summonAt - (now + 5)) < .01, "or after the wait you set")
_G.UnitAffectingCombat = function() return true end
now = now + 6
LZ.DoSummon()
ok(summoned == 1 and LZ.summonAt, "in combat: waits")
_G.UnitAffectingCombat = function() return false end
LZ.summonAt = nil
S.summonmode = "late"

-- resurrections
local rezzed = 0
_G.AcceptResurrect = function() rezzed = rezzed + 1 end
_G.GetCorpseRecoveryDelay = function() return 0 end
inst = { false }
ok(not LZ.OnRez("Priest") and rezzed == 0, "outside instances: yours to take (default)")
inst = { true, "raid" }
ok(LZ.OnRez("Priest") and rezzed == 1, "in a raid: taken")

-- duels
local cancelled = 0
_G.CancelDuel = function() cancelled = cancelled + 1 end
ok(not LZ.OnDuel("Bob") and cancelled == 0, "duels: off by default")
S.duel = "1"
ok(LZ.OnDuel("Bob") and cancelled == 1, "turned down")
ok(not LZ.OnDuel("Mate") and cancelled == 1, "but not from guild members")
shift = true
ok(not LZ.OnDuel("Bob"), "Shift: you see it")
shift = false
S.duel = "0"

-- gossip: one flight master line is opened, Ctrl shows the menu
local picked
_G.SelectGossipOption = function(i) picked = i end
_G.GetGossipActiveQuests = function() return nil end
_G.GetGossipAvailableQuests = function() return nil end
_G.GetGossipOptions = function() return "Hello", "gossip", "I need a ride", "taxi" end
ok(LZ.OnGossip() == "skip" and picked == 2, "a flight master: its line opened")
picked = nil
ctrl = true
ok(LZ.OnGossip() == nil and picked == nil, "Ctrl: the menu shows")
ctrl = false
_G.GetGossipOptions = function() return "Teleport me to the Molten Core", "gossip" end
ok(LZ.OnGossip() == "line" and picked == 1, "your own lines: picked")
_G.GetGossipOptions = function() return "Buy", "vendor", "Bind here", "binder" end
ok(LZ.OnGossip() == "skip" and picked == 1, "an innkeeper: the vendor, never the hearthstone")
picked = nil
_G.GetGossipOptions = function() return "Train me", "trainer", "Let me browse your goods", "vendor" end
ok(LZ.OnGossip() == nil and picked == nil, "a trainer who also sells: the menu stays (training reachable)")
-- quests with Shift: a done quest first, then a new one, the last repeated
local qa, qv
_G.SelectGossipActiveQuest = function(i) qa = i end
_G.SelectGossipAvailableQuest = function(i) qv = i end
_G.GetGossipActiveQuests = function() return "Kill Ten", 10, "Bring Coins", 60 end
_G.GetGossipAvailableQuests = function() return "New One", 60 end
_G.GetNumQuestLogEntries = function() return 2 end
_G.GetQuestLogTitle = function(i) if i == 1 then return "Kill Ten", 10, nil, nil, nil, nil end return "Bring Coins", 60, nil, nil, nil, 1 end
shift = true
LZ.tried = {}
ok(LZ.OnGossip() == "quest" and qa == 2, "Shift: the finished quest is handed in first")
qa = nil
ok(LZ.OnGossip() == "quest" and qv == 1, "then the new one")
shift = false
LZ.tried = {}
qa, qv = nil, nil
ok(LZ.OnGossip() == nil and not qa and not qv, "without Shift: nothing")
_G.UnitName = function(u) if u == "npc" then return "Quartermaster" end return keep.UnitName and keep.UnitName(u) end
LZ.last.Quartermaster = "Kill Ten"
shift = true
ok(LZ.OnGossip() == "quest" and qa == 1, "the last quest at this person is repeated first")
shift = false
LZ.tried, LZ.last = {}, {}

-- chat lines
S.chatrolls = "1"
local rollLine = string.format(_G.LOOT_ROLL_GREED or "%s has selected Greed for: %s", "Bob", Link(9999))
ok(LZ.ChatDrop("CHAT_MSG_LOOT", rollLine), "others' green roll lines hidden")
ok(not LZ.ChatDrop("CHAT_MSG_LOOT", "You won: " .. Link(9999)), "your own lines stay")
S.chatrolls = "0"
ok(not LZ.ChatDrop("CHAT_MSG_LOOT", rollLine), "switched off: shown")
S.worldmute = "1"
inst = { true, "raid" }
ok(LZ.ChatDrop("CHAT_MSG_CHANNEL", "lfg", "Bob", "", "5. World", "", "", "", "", "World"), "World quiet in a raid")
inst = { false }
ok(not LZ.ChatDrop("CHAT_MSG_CHANNEL", "lfg", "Bob", "", "5. World", "", "", "", "", "World"), "and heard outside")
S.worldmute = "0"

-- making stacks
local slots = { [0] = { [1] = { 20, 9999 } } }
_G.GetContainerNumSlots = function(b) return b == 0 and 6 or 0 end
_G.GetContainerItemLink = function(b, s) local x = slots[b] and slots[b][s] return x and ("item:" .. x[2] .. ":0:0:0") end
_G.GetContainerItemInfo = function(b, s) local x = slots[b] and slots[b][s] if x then return "tex", x[1], false end end
_G.C_Container = nil
local moves = {}
_G.SplitContainerItem = function(b, s, n) slots[b][s][1] = slots[b][s][1] - n table.insert(moves, n) end
_G.PickupContainerItem = function(b, s) slots[b][s] = { 5, 9999 } end
ok(LZ.Split(0, 1, 5) == 3, "20 into stacks of 5: three new stacks")
for _ = 1, 5 do LZ.SplitTick() end
ok(table.getn(moves) == 3 and slots[0][1][1] == 5 and slots[0][4] and slots[0][4][1] == 5, "made one by one (" .. table.getn(moves) .. ")")
ok(LZ.Split(0, 1, 5) == 0, "a stack that is the size already: nothing to do")

-- Salvation for a tank
local gone
_G.GetPlayerBuff = function(i) if i == 0 then return 0 end return -1 end
_G.GetPlayerBuffTexture = function() return "Interface\\Icons\\Spell_Holy_SealOfSalvation" end
_G.CancelPlayerBuff = function(i) gone = i end
_G.IsEquippedItemType = function(t) return t == "Shields" end
_G.GetShapeshiftFormInfo = function() return nil end
S.salva = "tank"
ok(LZ.Salvation() and gone == 0, "a warrior with a shield: Salvation off")
gone = nil
_G.IsEquippedItemType = function() return false end
ok(not LZ.Salvation() and gone == nil, "no shield, no stance: kept")
S.salva = "off"

-- the flag carriers
_G.UnitFactionGroup = _G.UnitFactionGroup or function() return "Horde" end
local fac = UnitFactionGroup("player")
LZ.OnFlagLine("The " .. fac .. " Flag was picked up by Sneaky!")
ok(LZ.efc == "Sneaky", "the enemy flag carrier from the battleground line")
LZ.OnFlagLine("The " .. fac .. " Flag was dropped by Sneaky!")
ok(LZ.efc == nil, "dropped: gone")

for _, k in ipairs(NAMES) do _G[k] = keep[k] end
LZ.ResetRules()

-- (16 Nov 2026, "abit overwhelming") the Loot rolls tab: a table of rules, one rule's details when picked
if O and O.Select then
  S.lzsel = "3"
  local good, err = pcall(function() O:Select("o:lzrolls") O:Rebuild("lzrolls") end)
  ok(good, "Loot rolls tab with rule 3 open builds (" .. tostring(err) .. ")")
  S.lzsel = "0"
  good, err = pcall(function() O:Rebuild("lzrolls") end)
  ok(good, "and with none open (" .. tostring(err) .. ")")
end
