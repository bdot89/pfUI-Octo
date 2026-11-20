-- pfUI Octo: tooltip extras (modules/tooltip-extras.lua, tooltip-data.lua), run by tests\run.lua.
local ok = octo_ok
local TX = pfUI.tipExtras
ok(TX and TX.Item and TX.Unit and TX.Node, "tooltip extras loaded (pfUI.tipExtras)")
if not TX then return end
local D = pfUI.tipData
ok(D and D.nodeLoot and D.nodeSkills and D.skinningLoot, "data: nodes, skills and skinning")
ok(D.nodeSkills["Black Lotus"][2] == 300 and D.nodeLoot["Black Lotus"][1][1] == 13468, "Black Lotus: 300, gives Black Lotus")
local CT = pfUI_config.tooltip
ok(CT.x_sources == "1" and CT.x_disenchant == "auto" and CT.x_mobstats == "1", "defaults")

-- a fake tooltip that keeps its lines
local function Tip()
  local t = { lines = {} }
  function t:AddLine(a) table.insert(self.lines, tostring(a)) end
  function t:AddDoubleLine(a, b) table.insert(self.lines, tostring(a) .. " | " .. tostring(b)) end
  function t:NumLines() return table.getn(self.lines) end
  function t:GetName() return "FakeTip" end
  function t:Show() self.shown = true end
  function t:Has(s)
    for _, l in ipairs(self.lines) do if string.find(l, s, 1, true) then return true end end
  end
  return t
end

-- disenchanting
local de = TX.Disenchant(1, 4, 66, "INVTYPE_HAND")
ok(de and de.rows[1].id == 20725 and de.skill == 225, "epic level 66: Nexus Crystal, Enchanting 225")
de = TX.Disenchant(2, 2, 33, "INVTYPE_WEAPON")
ok(de and de.rows[1].id == 11134 and de.rows[1].chance == 75 and de.rows[3].id == 11138, "green weapon 33: essence first, then dust, a shard")
de = TX.Disenchant(3, 2, 33, "INVTYPE_CHEST")
ok(de and de.rows[1].id == 11083, "green armour 33: dust first")
ok(not TX.Disenchant(4, 2, 33, "INVTYPE_TABARD") and not TX.Disenchant(5, 1, 33, "INVTYPE_CHEST"), "tabards and white items: nothing")
ok(TX.DESkill(50, 2) == 150 and TX.DESkill(15, 3) == 25, "Enchanting needed by level")

-- where it drops (a stand-in pfQuest database)
local oldDB = pfDB
pfDB = { items = { data = { [900001] = { U = { [11982] = 12.5, [11983] = 0.4 }, V = { [5] = 0 } },
                            [900002] = { U = {} } } },
         units = { loc = { [11982] = "Magmadar", [11983] = "Firelord", [5] = "Some Vendor" },
                   data = { [5] = { coords = { { 1, 2, 1519 } } } } },
         zones = { loc = { [1519] = "Stormwind City" } }, objects = { loc = {} } }
local s = TX.Sources(900001)
ok(s and s.ndrops == 2 and s.drops[1][1] == "Magmadar" and s.vendors[1][1] == "Some Vendor", "sources read, most likely first")
ok(TX.Sources(900002) == nil, "an item with no sources: nothing")
local oldMF = _G.MerchantFrame
_G.MerchantFrame = { IsShown = function() return nil end }
local tt = Tip()
TX.AddSources(tt, 900001)
ok(tt:Has("Drops from") and tt:Has("Magmadar | 13%") and tt:Has("Sold by") and tt:Has("Stormwind City"), "drops and vendor lines")
tt = Tip()
tt:AddLine("Some Item")
tt:AddLine("Molten Core - Magmadar")
_G.FakeTipTextLeft2 = { GetText = function() return "Molten Core - Magmadar" end }
TX.AddSources(tt, 900001)
ok(not tt:Has("Drops from"), "drops left out when another add-on already named the boss")
pfDB = oldDB
_G.MerchantFrame = oldMF
_G.FakeTipTextLeft2 = nil

-- the buffer adds its blank line only when something was said
local real = Tip()
real:AddLine("Some Item")
local b = TX.Buffer(real)
ok(b.Flush(true) == false and real:NumLines() == 1, "an empty buffer adds nothing")
b = TX.Buffer(real)
b:AddLine("hello")
ok(b.Flush(true) and real:NumLines() == 3, "a buffer with a line adds a blank line first")

-- herb and ore nodes
local oldSkill = TX.Skill
TX.Skill = function(n) if n == "Herbalism" then return 250 end end
tt = Tip()
TX.Node(tt, "Black Lotus")
ok(tt:Has("Herbalism | 300") and tt:Has("Black Lotus"), "a herb node: skill needed and what it gives")
-- (user, 17 Nov 2026: "i don't need to see skinning info im not a skinner") a profession you don't have:
-- nothing, unless set to "all" or Shift is held
local oldShift = IsShiftKeyDown
IsShiftKeyDown = function() return nil end
tt = Tip()
TX.Node(tt, "Rich Thorium Vein")
ok(tt:NumLines() == 0, "an ore node for a non-miner: nothing")
pfUI_config.tooltip.x_gather = "all"
TX.Node(tt, "Rich Thorium Vein")
ok(tt:Has("Mining | 275") and tt:Has("you don't have it"), "set to everyone: Mining, and you don't have it")
pfUI_config.tooltip.x_gather = "1"
ok(not TX.ProfWanted("x_skin", "Skinning"), "skinning lines hidden for a non-skinner")
IsShiftKeyDown = function() return 1 end
ok(TX.ProfWanted("x_skin", "Skinning"), "Shift shows them anyway")
IsShiftKeyDown = oldShift
TX.Skill = oldSkill

-- MobStats' own lines are muted while ours are on
local oldMS = _G.MobStats
_G.MobStats = { ApplicationService = { GetMobStats = function() return { armor = 1 } end } }
TX.msOrig = nil
TX.MuteMobStats()
ok(_G.MobStats.ApplicationService:GetMobStats("mouseover") == nil, "MobStats answers nothing while ours are on")
pfUI_config.tooltip.x_mobstats = "0"
ok(_G.MobStats.ApplicationService:GetMobStats("mouseover") ~= nil, "ours off: MobStats draws again")
pfUI_config.tooltip.x_mobstats = "1"
_G.MobStats, TX.msOrig = oldMS, nil
-- (20 Nov 2026, Wolfahrt) resistances as the raw value, the %, or both
ok(TX.ResistText(75, 20, "raw") == "75" and TX.ResistText(75, 20, "pct") == "20%"
  and string.find(TX.ResistText(75, 20, "both"), "^75") and string.find(TX.ResistText(75, 20, "both"), "(20%)", 1, true),
  "resists: raw 75, 20%, or 75 (20%)")
ok(CT.x_resistform == "both", "resists show both by default")
local r = TX.SkillColor(250, 300)
ok(r == 1, "skill colour: red below what it needs")

-- creatures
ok(TX.CreatureID("0xF13000ECA2001234") == 60578 or TX.CreatureID("0xF13000ECA2001234") ~= nil, "creature id from a GUID")
ok(TX.CreatureID("0x0000000000000001") == nil, "players have no creature id")
ok(TX.SkinSkill(5) == 1 and TX.SkinSkill(15) == 50 and TX.SkinSkill(60) == 300, "skinning needed by level")

-- mob stats (MobStats' formulas)
ok(math.floor(TX.ArmorCut(3731, 60) + .5) == 40, "armour 3731 against a 60: 40% physical")
ok(math.floor(TX.Resist(0, 60, 63, 2) + .5) == 6, "a level 63 boss with no fire resistance: 6% resisted")
ok(math.floor(TX.Resist(300, 60, 60, 4) + .5) == 69, "300 frost resistance at 60: 69%")
