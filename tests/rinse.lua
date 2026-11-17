-- pfUI Octo: OctoRinse (modules/rinse.lua, rinse-options.lua, rinse-data.lua), run by tests\run.lua.
-- The user's rule first: a tick on a boss list counts ONLY in that boss's fight, never in PvP or elsewhere.
-- Then the scan (blacklist hides the school, priority first, hidden, class scopes), the UpsiRinse import and the pages.
local ok = octo_ok
local R = pfUI.rinse
ok(R and R.Scan and R.Seed and R.Import and R.UpdateActive, "OctoRinse loaded (pfUI.rinse)")
if not R then return end
local O = pfUI.octoui and pfUI.octoui.Options
for _, k in ipairs({ "rinsegeneral", "rinsebosses", "rinseeverywhere", "rinseplayers" }) do
  ok(O and O.BUILD and O.BUILD[k], "options page " .. k .. " registered")
end
local S = pfUI_config.rinse
ok(S and S.inraid == "1" and S.buttons == "5" and type(S.boss) == "table" and type(S.skip) == "table", "defaults (C.rinse)")

-- every UpsiRinse zone and boss is there
local zones, bosses = 0, 0
for _, z in ipairs(R.DATA.zones) do
  zones = zones + 1
  for _ in ipairs(z.bosses) do bosses = bosses + 1 end
end
ok(zones == 17 and bosses > 120, "UpsiRinse's encounter lists: " .. zones .. " zones, " .. bosses .. " bosses")

local HUHU = R.Key("Ahn'Qiraj Temple", "Princess Huhuran")
local GROB = R.Key("Naxxramas", "Grobbulus")
-- shipped defaults went to their bosses, not everywhere
ok(R.BossGet(HUHU, "Wyvern Sting", "b") and not R.GlobalGet("Wyvern Sting", "b"), "Wyvern Sting skipped on Huhuran only, not everywhere")
ok(R.GlobalGet("Curse of Recklessness", "b"), "a debuff no boss lists (Curse of Recklessness) stays in Everywhere")

local keep = {}
for _, k in ipairs({ "GetTime", "GetRealZoneText", "UnitAffectingCombat", "UnitExists", "UnitName", "UnitClass", "UnitIsVisible",
  "UnitCanAssist", "UnitIsCharmed", "UnitIsUnit", "UnitIsPlayer", "UnitIsFriend", "UnitIsDead", "UnitBuff", "CheckInteractDistance",
  "UnitCanAttack", "GetNumRaidMembers", "GetNumPartyMembers", "GetRaidRosterInfo", "RINSE_CONFIG", "RINSE_CHAR_CONFIG", "RINSE_ENCOUNTERS" }) do
  keep[k] = rawget(_G, k)
end
local keepDebuff, keepUsable, keepPrio = R.Debuff, R.usable, R.prio
local now, zone, fighting = 1000, "Warsong Gulch", nil
_G.GetTime = function() return now end
_G.GetRealZoneText = function() return zone end
_G.UnitAffectingCombat = function(u) if u == "player" then return fighting end return fighting end
_G.GetNumRaidMembers = function() return 0 end
_G.GetNumPartyMembers = function() return 1 end

-- the boss rule
R.engaged = {}
R.UpdateActive()
ok(not R.IsBlack("Wyvern Sting", "HUNTER"), "in a battleground Wyvern Sting is cured as usual")
zone = "Ahn'Qiraj"
R.UpdateActive()
ok(not R.IsBlack("Wyvern Sting", "HUNTER"), "in the zone but before Huhuran: still cured")
ok(R.active[R.Key("Ahn'Qiraj Temple", "Trash & Adds")], "the zone's trash list counts while no boss is up")
R.Engage("Princess Huhuran")
R.UpdateActive()
ok(R.IsBlack("Wyvern Sting", "HUNTER") and R.active[HUHU], "fighting Huhuran: her Wyvern Sting is skipped")
ok(not R.active[R.Key("Ahn'Qiraj Temple", "Trash & Adds")], "trash list off while a boss is up")
ok(not R.IsBlack("Mutating Injection", "WARRIOR"), "Grobbulus's tick does not count in Huhuran's fight")
now = now + 30
R.UpdateActive()
ok(not R.active[HUHU], "out of combat 30 s later the boss list stops counting")
fighting = 1
R.Engage("Lord Kri")
R.UpdateActive()
ok(R.active[R.Key("Ahn'Qiraj Temple", "The Bug Family")], "an encounter of several NPCs is known by any of them (Lord Kri)")
zone = "Warsong Gulch"
R.engaged = {}
R.Engage("Princess Huhuran")
R.UpdateActive()
ok(not R.active[HUHU], "a boss name heard outside its zone does not switch its list on")
fighting = nil

-- a boss tick with a class scope: cure first only on warriors, only in that fight
local NOTH = R.Key("Naxxramas", "Noth the Plaguebringer")
R.BossSet(NOTH, "Curse of the Plaguebringer", "p", true)
R.ScopeSet(NOTH, "Curse of the Plaguebringer", "pc", "WARRIOR", true)
zone = "Naxxramas"
fighting = 1
R.engaged = {}
R.Engage("Noth the Plaguebringer")
R.UpdateActive()
ok(R.IsPriority("Curse of the Plaguebringer", "WARRIOR") and not R.IsPriority("Curse of the Plaguebringer", "MAGE"),
  "cure first scoped to warriors")
R.BossSet(NOTH, "Curse of the Plaguebringer", "p", false)
ok(not R.BossEntry(NOTH, "Curse of the Plaguebringer").pc, "taking cure first off drops its class scope")
fighting = nil

-- the scan: party1 has Wyvern Sting + Poison Bolt Volley, player has a Magic debuff
local UNITS = {
  player = { name = "Me", class = "PRIEST", debuffs = { { "Magic", "Shadow Word: Pain", "tex1" } } },
  party1 = { name = "Hunty", class = "HUNTER", debuffs = { { "Poison", "Wyvern Sting", "tex2" }, { "Poison", "Poison Bolt Volley", "tex3" } } },
}
_G.UnitExists = function(u) return UNITS[u] and 1 end
_G.UnitName = function(u) return UNITS[u] and UNITS[u].name end
_G.UnitClass = function(u) local x = UNITS[u] return x and x.class, x and x.class end
_G.UnitIsVisible = function() return 1 end
_G.UnitCanAssist = function() return 1 end
_G.UnitIsCharmed = function() return nil end
_G.UnitIsUnit = function(a, b) return a == b end
_G.UnitIsFriend = function() return 1 end
_G.UnitCanAttack = function() return nil end
_G.UnitIsPlayer = function() return 1 end
_G.UnitBuff = function() return nil end
_G.CheckInteractDistance = function() return 1 end
R.Debuff = function(unit, i)
  local d = UNITS[unit] and UNITS[unit].debuffs[i]
  if not d then return end
  return d[1], d[2], d[3], 0
end
R.usable = { Magic = "Dispel Magic", Poison = "Cure Poison" }
local keepHide = { Magic = R.Cfg("hide").Magic, Poison = R.Cfg("hide").Poison }
R.Cfg("hide").Magic, R.Cfg("hide").Poison = "0", "0"
R.prio = { "player", "party1" }
R.skipNames = {}
local function Shown()
  local out = {}
  for i = 1, R.shown do
    local b = R.buttons[i]
    if b.unit then table.insert(out, b.debuffName .. "@" .. b.unitName) end
  end
  return table.concat(out, ",")
end
zone = "Warsong Gulch"
R.engaged = {}
R.Scan()
ok(string.find(Shown(), "Wyvern Sting@Hunty"), "battleground: Wyvern Sting is offered (" .. Shown() .. ")")
zone = "Ahn'Qiraj"
fighting = 1
R.Engage("Princess Huhuran")
R.Scan()
ok(not string.find(Shown(), "Hunty"), "Huhuran: Wyvern Sting skipped, and Poison Bolt Volley on that player too (" .. Shown() .. ")")
ok(string.find(Shown(), "Shadow Word: Pain@Me"), "other players still offered")
-- the tick off on Huhuran: offered again
R.BossSet(HUHU, "Wyvern Sting", "b", false)
R.Scan()
ok(string.find(Shown(), "@Hunty"), "tick off: offered in Huhuran's fight again")
R.BossSet(HUHU, "Wyvern Sting", "b", true)
-- hide one debuff only (Everywhere): the other of that player shows
fighting = nil
R.engaged = {}
zone = "Warsong Gulch"
R.GlobalSet("Wyvern Sting", "h", true)
R.Scan()
ok(string.find(Shown(), "Poison Bolt Volley@Hunty") and not string.find(Shown(), "Wyvern Sting"), "Everywhere hide: only that debuff")
R.GlobalSet("Wyvern Sting", "h", false)
-- cure first goes to the top
R.GlobalSet("Poison Bolt Volley", "p", true)
R.Scan()
ok(R.buttons[1].debuffName == "Poison Bolt Volley", "cure first is the top row (" .. Shown() .. ")")
R.GlobalSet("Poison Bolt Volley", "p", false)
-- never cure a player
R.skipNames = { Hunty = true }
R.Scan()
ok(not string.find(Shown(), "Hunty"), "Never cure list leaves the player out")
R.skipNames = {}
-- class and group rules (the quick menu's class pictures and group buttons)
R.RuleSet("class", "HUNTER", "never")
R.Scan()
ok(not string.find(Shown(), "Hunty") and string.find(Shown(), "@Me"), "never cure hunters: the hunter is left out")
R.RuleSet("class", "HUNTER", "first")
ok(R.RuleState("class", "HUNTER") == "first", "cure first on the same class takes the never rule off")
R.UpdatePrio()
ok(R.prio[1] == "party1", "cure-first class goes to the front of the scan (" .. table.concat(R.prio, ",") .. ")")
R.RuleSet("class", "HUNTER", "first")
ok(R.RuleState("class", "HUNTER") == nil, "clicking again: rule off")
R.RuleSet("group", "1", "never")
R.UpdatePrio()
R.Scan()
ok(Shown() == "", "never cure group 1 (a party is group 1): nobody offered")
R.ClearRules()
ok(R.RuleState("group", "1") == nil, "Clear rules")
-- shaman: a poison in your own group gets the cleansing totem first, with the totem's picture, and still obeys the rules
do
  local keepTotem, keepOpt = R.totem, S.totems
  R.totem = { Poison = "Poison Cleansing Totem" }
  S.totems = "1"
  R.totemAt = {}
  R.UpdatePrio()
  R.Scan()
  local b = R.buttons[1]
  ok(b.totem == "Poison Cleansing Totem" and b.icon:GetTexture() == "Interface\\Icons\\Spell_Nature_PoisonCleansingTotem",
    "totem row first with the totem's icon (" .. Shown() .. ")")
  R.RuleSet("class", "HUNTER", "never")
  R.Scan()
  ok(not string.find(Shown(), "Hunty"), "never-cure rule: no totem offered for that player")
  R.ClearRules()
  R.totemAt["Poison Cleansing Totem"] = now
  R.Scan()
  ok(not R.buttons[1].totem, "totem just dropped: the direct cure is offered for 5 s")
  R.totem, S.totems = keepTotem, keepOpt
end
R.prio = { "player", "party1" }

-- UpsiRinse's saved settings come over; its browser ticks on boss debuffs go to those bosses only
local bossBefore = R.BossGet(GROB, "Mutating Injection", "b")
_G.RINSE_CONFIG = { SCALE = 1.2, BUTTONS = 7, PRINT = false, SKIP_ARRAY = { { name = "Bob", class = "MAGE" } },
  PRIO_ARRAY = { { name = "Tank", class = "WARRIOR" } } }
_G.RINSE_CHAR_CONFIG = { BLACKLIST = { ["Mutating Injection"] = true, ["My Own Thing"] = true },
  FILTER = { ["Ignite Mana"] = true }, PRIORITY = {}, PRIORITY_CLASS = {}, FILTER_CLASS = { ROGUE = { ["Silence"] = true } } }
_G.RINSE_ENCOUNTERS = { ["Molten Core"] = { ["Lucifron"] = { ["New Thing"] = "Magic" } } }
local keepSettings = {}
for k, v in pairs(S) do keepSettings[k] = v end
ok(R.Import(true), "imported from UpsiRinse")
ok(S.scale == "1.2" and S.buttons == "7" and S.print == "0", "bar settings copied")
ok(S.skip[1] and S.skip[1].name == "Bob" and S.prio[1] and S.prio[1].name == "Tank", "skip and priority players copied")
ok(R.BossGet(GROB, "Mutating Injection", "b") and not R.GlobalGet("Mutating Injection", "b"), "a boss debuff stays on its boss")
ok(R.GlobalGet("My Own Thing", "b"), "a debuff no boss lists goes to Everywhere")
ok(R.BossGet(R.Key("Molten Core", "Baron Geddon"), "Ignite Mana", "h") and not R.GlobalGet("Ignite Mana", "h"), "hidden boss debuff: on Geddon only")
ok(R.Learned()["Molten Core"]["Lucifron"]["New Thing"] == "Magic", "learned debuffs copied")
for k in pairs(S) do S[k] = nil end
for k, v in pairs(keepSettings) do S[k] = v end
ok(bossBefore ~= nil, "Grobbulus seeded")

-- the boss browser draws a boss with its debuffs
local RO = pfUI.rinseOptions
ok(RO and RO.Spells and RO.Paint, "boss browser")
if RO and RO.rrows then
  RO.zone, RO.boss, RO.roff = "Blackwing Lair", "Chromaggus", 0
  RO.Paint()
  local names = {}
  for _, r in ipairs(RO.rrows) do if r:IsShown() and r.spell then table.insert(names, r.spell.name) end end
  ok(table.getn(names) == 4, "Chromaggus: four Brood Afflictions (" .. table.concat(names, ", ") .. ")")
  ok(RO.rrows[2].key == R.Key("Blackwing Lair", "Chromaggus"), "rows carry the boss's own key")
  RO.zone, RO.boss = R.EVERYWHERE, "Buffs & Consumables"
  RO.Paint()
  ok(RO.rrows[2].key == nil, "Everywhere rows write the Everywhere lists")
end
local s = RO and RO.Spells("Molten Core", "Lucifron") or {}
local found
for _, e in ipairs(s) do if e.name == "Lucifron's Curse" then found = e end end
ok(found and found.school == "Curse", "Lucifron's Curse listed as a Curse")

-- one size: layout mode's scale stays through any option change, and the options' Scale is the same one
do
  local keepPos, keepScale = pfUI_config.position and pfUI_config.position.pfRinse, S.scale
  pfUI_config.position = pfUI_config.position or {}
  pfUI_config.position.pfRinse = { scale = .7 }
  R.frame:SetScale(.7)
  R.frame:OnScale(.7)
  S.headhover = "1"
  R.ApplyLayout()
  ok(math.abs(R.frame:GetScale() - .7) < .001 and S.scale == "0.7", "layout mode's 70% kept after an option change")
  pfUI_config.position.pfRinse = nil
  S.scale = "1.3"
  R.ApplyLayout()
  ok(math.abs(R.frame:GetScale() - 1.3) < .001, "no layout scale saved: the option's scale")
  R.SetScale(.9)
  ok(pfUI_config.position.pfRinse and pfUI_config.position.pfRinse.scale == .9 and math.abs(R.frame:GetScale() - .9) < .001,
    "options' Scale saves where layout mode keeps it")
  R.ApplyLayout()
  ok(math.abs(R.frame:GetScale() - .9) < .001, "and stays")
  pfUI_config.position.pfRinse = keepPos
  S.scale = keepScale
  S.headhover = "0"
  R.ApplyLayout()
end

-- the title bar hidden until the mouse is over it
do
  local keepOver = rawget(_G, "MouseIsOver")
  local over
  _G.MouseIsOver = function() return over end
  local head = R.frame.head
  R.testUntil = 0
  head:Show()
  S.headhover = "1"
  for _ = 1, 30 do R.HeadFade(.05) end
  ok(head:GetAlpha() == 0, "hidden until hover: title invisible (" .. tostring(head:GetAlpha()) .. ")")
  over = 1
  for _ = 1, 5 do R.HeadFade(.05) end
  ok(head:GetAlpha() == 1, "mouse over it: shown")
  S.headhover = "0"
  over = nil
  for _ = 1, 30 do R.HeadFade(.05) end
  ok(head:GetAlpha() == 1, "option off: always shown")
  _G.MouseIsOver = keepOver
end

-- the quick player list on the bar (in combat, no options window): left = cure first, Shift = top, right = never
do
  local keepSkip, keepPrioList = S.skip, S.prio
  S.skip, S.prio = {}, {}
  local keepShift = rawget(_G, "IsShiftKeyDown")
  local raid = { { "Tanky", 1, "WARRIOR" }, { "Healy", 1, "PRIEST" }, { "Stabby", 2, "ROGUE" } }
  _G.GetNumRaidMembers = function() return table.getn(raid) end
  _G.GetRaidRosterInfo = function(i) local r = raid[i] if r then return r[1], 0, r[2], 60, r[3], r[3] end end
  R.ToggleQuick()
  local q = _G.pfRinseQuick
  ok(q and q:IsShown(), "Players picture opens the quick list")
  local cells = {}
  for _, c in ipairs(q.cells) do if c.who then cells[c.who.name] = c end end
  ok(cells.Tanky and cells.Healy and cells.Stabby, "every raid member has a name to click")
  local click = cells.Tanky:GetScript("OnClick")
  _G.this, _G.arg1 = cells.Tanky, "LeftButton"
  _G.IsShiftKeyDown = function() return nil end
  click()
  ok(S.prio[1] and S.prio[1].name == "Tanky" and S.prio[1].class == "WARRIOR", "left-click: cure first")
  _G.this = cells.Healy
  _G.IsShiftKeyDown = function() return 1 end
  click()
  ok(S.prio[1].name == "Healy" and S.prio[2].name == "Tanky", "Shift-click: to the top of cure first")
  _G.this, _G.arg1 = cells.Tanky, "RightButton"
  _G.IsShiftKeyDown = function() return nil end
  click()
  ok(S.skip[1] and S.skip[1].name == "Tanky" and table.getn(S.prio) == 1 and R.skipNames.Tanky, "right-click: never cure (and off cure first)")
  click()
  ok(table.getn(S.skip) == 0 and not R.skipNames.Tanky, "right-click again: back to normal")
  table.remove(raid, 2)
  R.QuickPaint()
  local away
  for _, c in ipairs(q.cells) do if c.who and c.who.name == "Healy" and c.who.group == 0 then away = true end end
  ok(away, "someone on a list who left the group still shows, to take them off")
  q:Hide()
  _G.IsShiftKeyDown = keepShift
  S.skip, S.prio = keepSkip, keepPrioList
  R.RebuildSkip()
end

R.Debuff, R.usable, R.prio = keepDebuff, keepUsable, keepPrio
R.Cfg("hide").Magic, R.Cfg("hide").Poison = keepHide.Magic, keepHide.Poison
R.engaged = {}
R.Cfg("boss")[NOTH] = nil
for k, v in pairs(keep) do _G[k] = v end
R.UpdateActive()
