-- Offline run of the character stats (EvenBetterCharacterStats, merged into pfUI Octo 1 Nov 2026: charstats)
-- (..\OctoBG\tests\mock.lua on DmorphOcto's LuaHost). Builds the XML frames,
-- fills every stat category, opens every tooltip, and drives the enchant
-- panel with and without ClassicAPI.
--   powershell -File tests\run.ps1

dofile("../OctoBG/tests/mock.lua")

local fails, checks = 0, 0
local function ok(cond, what)
	checks = checks + 1
	if not cond then
		fails = fails + 1
		print("FAIL: " .. what)
	end
end

-- ---------------------------------------------------------------- Lua aliases the client has

strfind, strlower, strupper, strsub, strlen, format, gsub = string.find, string.lower, string.upper, string.sub, string.len, string.format, string.gsub
tinsert, tremove, getn = table.insert, table.remove, table.getn
floor, ceil, max, min, abs = math.floor, math.ceil, math.max, math.min, math.abs

-- ---------------------------------------------------------------- game data

Mock.enchants = {
	[2545] = "+1% Dodge",
	[2604] = "+18 Healing Spells",
	[1889] = "+70 Armor",
	[1891] = "+4 All Stats",
	[2504] = "Spell Damage +30",
	[2628] = "Brilliant Wizard Oil",
	[3052] = "+10 Intellect",
	[3100] = "Spell Damage +5",
}

Mock.items = {
	[19375] = { name = "Mish'undare, Circlet of the Mind Flayer", q = "a335ee", loc = "INVTYPE_HEAD", sub = "Cloth", lines = { "+24 Intellect" } },
	[18814] = { name = "Choker of the Fire Lord", q = "a335ee", loc = "INVTYPE_NECK", sub = "Miscellaneous", lines = { "+7 Intellect" } },
	[19370] = { name = "Mantle of the Blackwing Cabal", q = "a335ee", loc = "INVTYPE_SHOULDER", sub = "Cloth", lines = { "+16 Intellect" } },
	[19378] = { name = "Cloak of the Brood Lord", q = "a335ee", loc = "INVTYPE_CLOAK", sub = "Cloth", lines = { "+14 Intellect" } },
	[16916] = { name = "Netherwind Robes", q = "a335ee", loc = "INVTYPE_ROBE", sub = "Cloth", lines = { "+26 Intellect", "Equip: Restores 4 health per 5 sec." } },
	[19374] = { name = "Bracers of Arcane Accuracy", q = "a335ee", loc = "INVTYPE_WRIST", sub = "Cloth", lines = { "+12 Intellect" } },
	[19400] = { name = "Firemaw's Clutch", q = "a335ee", loc = "INVTYPE_WAIST", sub = "Cloth", lines = { "+12 Intellect" } },
	-- two pieces of one set: the active bonus is on both tooltips, the inactive one has its "(4)" prefix
	[47200] = { name = "Raiments of Prophecy", q = "a335ee", loc = "INVTYPE_ROBE", sub = "Cloth", lines = { "300 Armor", "+20 Intellect", "-5 Agility", "+10 Fire Resistance", "Vestments of Prophecy (2/8)", "Set: Improves your chance to hit with spells by 1%.", "(4) Set: Improves your chance to get a critical strike with spells by 2%." } },
	[47199] = { name = "Shoulderpads of Prophecy", q = "a335ee", loc = "INVTYPE_SHOULDER", sub = "Cloth", lines = { "200 Armor", "+12 Stamina", "+4 All Resistances", "Vestments of Prophecy (2/8)", "Set: Improves your chance to hit with spells by 1%.", "(4) Set: Improves your chance to get a critical strike with spells by 2%." } },
	[19403] = { name = "Band of Forced Concentration", q = "a335ee", loc = "INVTYPE_FINGER", sub = "Miscellaneous", lines = {} },
	[19356] = { name = "Staff of the Shadow Flame", q = "ff8000", loc = "INVTYPE_2HWEAPON", sub = "Staves", lines = { "Equip: Increases damage and healing done by magical spells and effects by up to 84." } },
	[19366] = { name = "Master Dragonslayer's Orb", q = "a335ee", loc = "INVTYPE_HOLDABLE", sub = "Miscellaneous", lines = {} },
	[19367] = { name = "Dragon's Touch", q = "a335ee", loc = "INVTYPE_RANGEDRIGHT", sub = "Wands", lines = {} },
	[12345] = { name = "Shield of Testing", q = "1eff00", loc = "INVTYPE_SHIELD", sub = "Shields", lines = { "1500 Armor", "30 Block" } },
}

-- slot -> { itemID, enchantID }
Mock.inventory = {
	[1] = { 19375, 2545 },
	[2] = { 18814, 0 },
	[3] = { 19370, 2604 },
	[15] = { 19378, 1889 },
	[5] = { 16916, 1891 },
	[9] = { 19374, 0 },
	[6] = { 19400, 0 },
	[11] = { 19403, 0 },
	[16] = { 19356, 2504 },
	[17] = { 19366, 0 },
	[18] = { 19367, 0 },
}

-- temporary enchant on the main hand: name, ms left, charges
Mock.temp = { [16] = { 2628, 1500000, 0 } }

local SLOT_IDS = {
	HeadSlot = 1, NeckSlot = 2, ShoulderSlot = 3, ShirtSlot = 4, ChestSlot = 5, WaistSlot = 6, LegsSlot = 7,
	FeetSlot = 8, WristSlot = 9, HandsSlot = 10, Finger0Slot = 11, Finger1Slot = 12, Trinket0Slot = 13,
	Trinket1Slot = 14, BackSlot = 15, MainHandSlot = 16, SecondaryHandSlot = 17, RangedSlot = 18, TabardSlot = 19,
}

function GetInventorySlotInfo(name)
	local id = SLOT_IDS[name]
	assert(id, "unknown slot " .. tostring(name))
	return id, "Interface\\PaperDoll\\UI-PaperDoll-Slot-" .. name
end

-- other players' gear and oils by unit; Mock.uncached[unit][slot] = the client hasn't got that item yet
Mock.others, Mock.otherTemp, Mock.uncached = {}, {}, {}
local function Inventory(unit)
	if unit == "player" then return Mock.inventory end
	assert(type(unit) == "string", "unit expected, got " .. tostring(unit))
	return Mock.others[unit] or {}
end
local function Temps(unit)
	if unit == "player" then return Mock.temp end
	return Mock.otherTemp[unit] or {}
end

function GetInventoryItemLink(unit, slot)
	local inv = Inventory(unit)[slot]
	if not inv or (Mock.uncached[unit] and Mock.uncached[unit][slot]) then return nil end
	local item = Mock.items[inv[1]]
	return "|cff" .. item.q .. "|Hitem:" .. inv[1] .. ":" .. inv[2] .. ":0:0|h[" .. item.name .. "]|h|r"
end

function GetInventoryItemTexture(unit, slot)
	if Inventory(unit)[slot] then return "Interface\\Icons\\INV_Item_" .. slot end
end

function GetItemInfo(id)
	assert(type(id) == "number" or type(id) == "string", "GetItemInfo needs an id")
	local _, _, n = string.find(tostring(id), "(%d+)")
	local item = Mock.items[tonumber(n)]
	if not item then return nil end
	return item.name, "item:" .. n .. ":0:0:0", 4, 60, "Armor", item.sub, 1, item.loc, "Interface\\Icons\\INV"
end

function GetWeaponEnchantInfo()
	local m, o = Mock.temp[16], Mock.temp[17]
	return m and 1, m and m[2], m and m[3], o and 1, o and o[2], o and o[3]
end

local function ClassicAPI(on)
	if not on then
		C_Item, GetUnitSpeed, UnitSpellHaste = nil, nil, nil
		return
	end
	C_Item = {
		GetEnchantInfo = function(id)
			Mock.apiLookups = (Mock.apiLookups or 0) + 1
			return { enchantID = id, name = Mock.enchants[id] }
		end,
		GetWeaponEnchantInfo = function()
			local m, o, r = Mock.temp[16], Mock.temp[17], Mock.temp[18]
			return m ~= nil, m and m[2] or 0, m and m[3] or 0, m and m[1] or 0,
				o ~= nil, o and o[2] or 0, o and o[3] or 0, o and o[1] or 0,
				r ~= nil, r and r[2] or 0, r and r[3] or 0, r and r[1] or 0
		end,
	}
	GetUnitSpeed = function(unit) return 0, Mock.runSpeed or 7, 0, 4.722 end
	UnitSpellHaste = function(unit) return 0 end
end

-- ---------------------------------------------------------------- tooltips that hold lines

local function TipLines(link, unit, slot)
	local _, _, id, enchant = string.find(link or "", "item:(%d+):(%d+)")
	local item = id and Mock.items[tonumber(id)]
	if not item then return {} end
	local lines = { item.name }
	for _, l in ipairs(item.lines) do table.insert(lines, l) end
	if tonumber(enchant) > 0 then table.insert(lines, Mock.enchants[tonumber(enchant)]) end
	local t = slot and Temps(unit)[slot]
	if t then
		table.insert(lines, Mock.enchants[t[1]] .. " (" .. math.ceil(t[2] / 60000) .. " min)")
	end
	if slot then table.insert(lines, "Durability 75 / 75") end
	return lines
end

local realCreateFrame = CreateFrame
function CreateFrame(kind, name, parent, template)
	local f = realCreateFrame(kind, name, parent, template)
	if kind == "GameTooltip" then
		f.tipLines = {}
		local function Fill(lines)
			f.tipLines = lines
			for i = 1, math.max(table.getn(lines), 30) do
				local fs = _G[name .. "TextLeft" .. i] or Mock.New("FontString", name .. "TextLeft" .. i, f)
				fs.text = lines[i]
			end
		end
		f.SetOwner = function(self, owner) self.owner = owner end
		f.ClearLines = function(self) Fill({}) end
		f.NumLines = function(self) return table.getn(self.tipLines) end
		f.SetHyperlink = function(self, link)
			assert(string.find(link, "^item:%d+:%d+:%-?%d+:%d+$"), "bad hyperlink " .. link)
			Fill(TipLines(link))
		end
		f.SetInventoryItem = function(self, unit, slot)
			Fill(TipLines(GetInventoryItemLink(unit, slot), unit, slot))
			return GetInventoryItemLink(unit, slot) ~= nil
		end
		f.SetSpell = function(self) Fill({}) end
		f.SetTalent = function(self) Fill({}) end
		f.SetPlayerBuff = function(self) Fill({}) end
		Fill({})
	elseif template == "BetterStatFrameTemplate" then
		Mock.New("FontString", name .. "Label", f)
		local stat = Mock.New("Frame", name .. "Stat", f)
		Mock.New("FontString", name .. "StatText", stat)
	elseif template == "UIDropDownMenuTemplate" then
		Mock.New("Button", name .. "Button", f)
		Mock.New("FontString", name .. "Text", f)
	elseif kind == "Button" or kind == "CheckButton" then
		f.SetNormalTexture = function(self, t)
			self.normal = self.normal or Mock.New("Texture", nil, self)
			self.normal.texture = t
		end
		f.GetNormalTexture = function(self) return self.normal end
		f.Click = function(self) Mock.Run(self, "OnClick") end
	end
	return f
end

-- ---------------------------------------------------------------- the player

function UnitClass(u)
	local class = u ~= "player" and Mock.classes[u] or "MAGE"
	return class, class
end
function UnitRace(u) return "Troll", "Troll" end
function UnitStat(u, i)
	local s = { 34, 38, 282, 331, 254 }
	return s[i], s[i], 0, 0
end
function UnitArmor(u) return 709, 709, 709, 0, 0 end
function UnitDefense(u) return 300, Mock.defenseBonus or 0 end
function UnitResistance(u, i)
	local r = { [0] = 709, 0, 54, 10, 0, -5, 30 }
	if r[i] < 0 then return 0, r[i], 0, r[i] end
	return 0, r[i], r[i], 0
end
function GetBlockChance() return Mock.block or 0 end
function GetDodgeChance() return 3.5 end
function GetParryChance() return 0 end
function UnitAttackPower(u) return 24, 0, 0 end
function UnitRangedAttackPower(u) return 0, 0, 0 end
function UnitAttackSpeed(u) return 2.9, nil end
function UnitDamage(u) return 50, 80, 0, 0, 0, 0, 1 end
function UnitRangedDamage(u) return 1.5, 60, 90, 0, 0, 1 end
function UnitAttackBothHands(u) return 300, 0, 0, 0 end
function UnitRangedAttack(u) return 300, 0 end
function UnitHasRelicSlot(u) return nil end
function HasWandEquipped() return 1 end
function OffhandHasWeapon() return nil end
function UnitHealthMax(u) return 3800 end
function UnitHealth(u) return 3500 end
function UnitManaMax(u) return 6200 end
function UnitMana(u) return 6000 end
local skillCalls = 0
function GetNumSkillLines() return 2 end
-- (the real client crashes on an index past the last skill: this one counts the calls)
function GetSkillLineInfo(i) skillCalls = skillCalls + 1 if i > 2 then error("past the last skill") end if i == 1 then return "Weapon Skills" end return "Swords", nil, nil, 290, nil, 5 end
function GetNumSpellTabs() return 0 end
function GetNumTalentTabs() return 0 end
function GetPlayerBuff(i, f) return -1 end
function UnitBuff(u, i) return nil end
function GetNumPartyMembers() return 0 end
function GetNumRaidMembers() return 0 end
function debugprofilestop() return 0 end

-- ---------------------------------------------------------------- FrameXML bits

HEADSLOT, NECKSLOT = "Head", "Neck"
HEALTH_COLON, MANA_COLON, ARMOR, ARMOR_COLON, DEFENSE_COLON = "Health:", "Mana:", "Armor", "Armor:", "Defense:"
ARMOR_TOOLTIP = "Increases armor (lvl %d: %.2f%%)"
ATTACK_POWER_COLON, MELEE_ATTACK_POWER, RANGED_ATTACK_POWER = "Attack Power:", "Melee Attack Power", "Ranged Attack Power"
MELEE_ATTACK_POWER_TOOLTIP, RANGED_ATTACK_POWER_TOOLTIP = "+%.1f dps", "+%.1f dps"
ATTACK_POWER_MAGIC_NUMBER = 14
ATTACK_SPEED_COLON, DAMAGE_COLON, DAMAGE_PER_SECOND, SPEED = "Speed:", "Damage:", "DPS", "Speed"
INVTYPE_WEAPONMAINHAND, INVTYPE_WEAPONOFFHAND, INVTYPE_RANGED = "Main Hand", "Off Hand", "Ranged"
NOT_APPLICABLE = "N/A"
DODGE, PARRY, BLOCK = "Dodge", "Parry", "Block"
ITEM_SPELL_TRIGGER_ONEQUIP = "Equip:"
TOOLTIP_TALENT_NEXT_RANK = "Next rank:"
BOOKTYPE_SPELL, SPELLS_PER_PAGE = "spell", 12
GREEN_FONT_COLOR_CODE, RED_FONT_COLOR_CODE, HIGHLIGHT_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE = "|cff20ff20", "|cffff2020", "|cffffffff", "|r"
HIGHLIGHT_FONT_COLOR = { r = 1, g = 1, b = 1 }
NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0 }
SPELL_STAT0_NAME, SPELL_STAT1_NAME, SPELL_STAT2_NAME, SPELL_STAT3_NAME, SPELL_STAT4_NAME = "Strength", "Agility", "Stamina", "Intellect", "Spirit"
SPELL_SCHOOL2_CAP, SPELL_SCHOOL3_CAP, SPELL_SCHOOL4_CAP, SPELL_SCHOOL5_CAP, SPELL_SCHOOL6_CAP = "Fire", "Nature", "Frost", "Shadow", "Arcane"
RESISTANCE2_NAME, RESISTANCE3_NAME, RESISTANCE4_NAME, RESISTANCE5_NAME, RESISTANCE6_NAME = "Fire Resistance", "Nature Resistance", "Frost Resistance", "Shadow Resistance", "Arcane Resistance"
ITEM_ENCHANT_TIME_LEFT_DAYS, ITEM_ENCHANT_TIME_LEFT_DAYS_P1 = "%s (%d day)", "%s (%d days)"
ITEM_ENCHANT_TIME_LEFT_HOURS, ITEM_ENCHANT_TIME_LEFT_HOURS_P1 = "%s (%d hour)", "%s (%d hrs)"
ITEM_ENCHANT_TIME_LEFT_MIN, ITEM_ENCHANT_TIME_LEFT_SEC = "%s (%d min)", "%s (%d sec)"
ITEM_SPELL_CHARGES, ITEM_SPELL_CHARGES_P1 = "%d Charge", "%d Charges"
ChatFrame2 = Mock.New("Frame", "ChatFrame2", UIParent)
ChatFrameEditBox = Mock.New("EditBox", "ChatFrameEditBox", UIParent)
ChatFrameEditBox.Insert = function(self, t) Mock.inserted = t end

function PaperDollFormatStat(name, base, posBuff, negBuff, frame, text)
	text:SetText(base + posBuff + negBuff)
	frame.tooltip = name
end
function PaperDollStatTooltip() end
function RaiseFrameLevel() end
function UIDropDownMenu_SetSelectedValue() end
function UIDropDownMenu_SetWidth(w, f) assert(type(w) == "number", "1.12 SetWidth takes width first") end
function UIDropDownMenu_JustifyText() end
function UIDropDownMenu_SetText(text, frame)
	assert(type(text) == "string" and type(frame) == "table", "1.12 SetText takes text, frame")
	frame.ddText = text
end
Mock.group, Mock.classes = {}, {}
function UnitInParty(u) return Mock.group[u] end
function UnitInRaid(u) return Mock.group[u] end
function ToggleCharacter(tab) Mock.toggled = tab end

-- XML of the client and of this addon
CharacterFrame = Mock.New("Frame", "CharacterFrame", UIParent)
CharacterFrame.shown = false
PaperDollFrame = Mock.New("Frame", "PaperDollFrame", CharacterFrame)
CharacterModelFrame = Mock.New("PlayerModel", "CharacterModelFrame", PaperDollFrame)
CharacterModelFrame.h = 224
CharacterAttributesFrame = Mock.New("Frame", "CharacterAttributesFrame", PaperDollFrame)
CharacterMainHandSlot = Mock.New("Button", "CharacterMainHandSlot", PaperDollFrame)
-- the character frame's slot icons (ItemButtonTemplate's $parentIconTexture)
for slotName, id in pairs(SLOT_IDS) do
	Mock.New("Texture", "Character" .. slotName .. "IconTexture", PaperDollFrame).GetTexture = function(self)
		local inv = Mock.inventory[id]
		if not inv then return "Interface\\PaperDoll\\UI-PaperDoll-Slot-" .. slotName end
		return Mock.slotIcons[id] or GetInventoryItemTexture("player", id)
	end
end
-- the character frame shows a different cloak icon than GetInventoryItemTexture (seen in game)
Mock.slotIcons = { [15] = "Interface\\Icons\\INV_Misc_Cape_02" }

dofile("charstats/Localization.lua")
dofile("charstats/helper.lua")
dofile("charstats/BetterCharacterStats.lua")

BCSFrame = Mock.New("Frame", "BCSFrame", PaperDollFrame)
for _, side in ipairs({ "Left", "Right" }) do
	for i = 1, 6 do
		local f = Mock.New("Frame", "PlayerStatFrame" .. side .. i, BCSFrame)
		Mock.New("FontString", f.name .. "Label", f)
		local stat = Mock.New("Frame", f.name .. "Stat", f)
		Mock.New("FontString", stat.name .. "Text", stat)
	end
	local dd = Mock.New("Frame", "PlayerStatFrame" .. side .. "DropDown", BCSFrame)
	Mock.New("Button", dd.name .. "Button", dd)
	this = dd
	_G["PlayerStatFrame" .. side .. "DropDown_OnLoad"]()
end
BCSFrame:SetScript("OnShow", function() BCS:OnShow() end)
BCSFrame:SetScript("OnEvent", function() BCS:OnEvent() end)
this = BCSFrame
BCS:OnLoad()
this = nil

dofile("charstats/Enchants.lua")
dofile("charstats/InspectStats.lua")

-- like the client: showing a frame shows its shown children too
local function Open(frame)
	local function Walk(f)
		if f.shown then
			Mock.Run(f, "OnShow")
			for _, c in ipairs(f.children) do Walk(c) end
		end
	end
	frame.shown = true
	Walk(frame)
end
local function OpenCharacter()
	Open(CharacterFrame)
end
local function CloseCharacter()
	CharacterFrame.shown = false
end

local function Text(name) return _G[name] and _G[name].text end

-- ---------------------------------------------------------------- login

ClassicAPI(true)
BCSConfig = { DropdownLeft = "PLAYERSTAT_GENERAL", DropdownRight = "PLAYERSTAT_EXTRA" }
Mock.Fire("ADDON_LOADED", "pfUI")
ok(BCSConfig.EnchantPanel == true, "enchant panel defaults to shown")
ok(BCSEnchantFrame.shown and not BCSEnchantFrame:IsVisible(), "panel waits for the character frame")

OpenCharacter()
ok(BCSEnchantFrame:IsVisible(), "panel opens with the character frame")
ok(BCSEnchantFrameToggleButton.checked == 1, "toggle shows checked")

-- ---------------------------------------------------------------- every stat category

for _, cat in ipairs(BCS.PLAYERSTAT_DROPDOWN_OPTIONS) do
	BCS.needScanGear, BCS.needScanTalents, BCS.needScanAuras, BCS.needScanSkills = true, true, true, true
	BCS:RunScans()
	BCS:UpdatePaperdollStats("PlayerStatFrameLeft", cat)
	for i = 1, 6 do
		local name = "PlayerStatFrameLeft" .. i
		ok(Text(name .. "Label") and Text(name .. "Label") ~= "", cat .. " row " .. i .. " has a label")
		ok(Text(name .. "StatText") ~= nil, cat .. " row " .. i .. " has a value")
		local f = _G[name]
		if f.scripts.OnEnter then
			local good, err = pcall(Mock.Run, f, "OnEnter")
			ok(good, cat .. " row " .. i .. " tooltip: " .. tostring(err))
		end
		if f.scripts.OnUpdate then
			GameTooltip.owner = f
			local good, err = pcall(Mock.Run, f, "OnUpdate", 0.3)
			ok(good, cat .. " row " .. i .. " tooltip refresh: " .. tostring(err))
		end
	end
end

local function Show(cat)
	BCS:UpdatePaperdollStats("PlayerStatFrameLeft", cat)
	local out = {}
	for i = 1, 6 do
		table.insert(out, (Text("PlayerStatFrameLeft" .. i .. "Label") or "?") .. " " .. (Text("PlayerStatFrameLeft" .. i .. "StatText") or "?"))
	end
	return out
end

local general = Show("PLAYERSTAT_GENERAL")
print("General:     " .. table.concat(general, " | "))
ok(general[1] == "Health: 3800", "health row")
-- troll mage, 254 spirit: (254 * 0.11 + 1) * 1.1 = 31.8; 4 hp5 adds 1.6 per tick
ok(general[2] == "HP Regen: 33 (4)", "hp regen row, got " .. general[2])
ok(general[3] == "Mana: 6200", "mana row")
-- mage, 254 spirit: 254 / 4 + 12.5 = 76 per tick = 190 per 5 sec
ok(string.find(general[4], "^MP5: 19%d$") ~= nil, "mp5 row, got " .. general[4])
ok(general[6] == "Speed: 100%", "speed row, got " .. general[6])

local resist = Show("PLAYERSTAT_RESISTANCES")
print("Resistances: " .. table.concat(resist, " | "))
ok(resist[2] == "Arcane: |cff20ff2030|r", "arcane row, got " .. resist[2])
ok(resist[3] == "Fire: |cff20ff2054|r", "fire row")
ok(resist[6] == "Shadow: |cffff2020-5|r", "negative shadow shows red, got " .. resist[6])
Mock.Run(PlayerStatFrameLeft3, "OnEnter")

local extra = Show("PLAYERSTAT_EXTRA")
print("Extra:       " .. table.concat(extra, " | "))
ok(extra[5] == "Block Value: N/A", "no shield, no block value")
ok(extra[6] == "Crit Taken: 5.60%", "crit taken at 300 defense, got " .. extra[6])
ok(PlayerStatFrameLeft6.tooltipExtra == "140 more defense for crit immunity.", "defense needed")
Mock.defenseBonus = 140
Show("PLAYERSTAT_EXTRA")
ok(Text("PlayerStatFrameLeft6StatText") == "0.00%", "crit immune at 440")
ok(PlayerStatFrameLeft6.tooltipExtra == BCS.L.CRIT_TAKEN_IMMUNE, "immune text")
Mock.defenseBonus = nil
Mock.block = 5
extra = Show("PLAYERSTAT_EXTRA")
ok(string.find(extra[5], "^Block Value: %d+$") ~= nil, "block value with a shield, got " .. extra[5])
Mock.block = nil

-- movement speed is polled while General is open (left dropdown from BCSConfig)
Mock.runSpeed = 11.2
Mock.Tick(0.6)
ok(Text("PlayerStatFrameLeft6StatText") == "160%", "speed follows a mount, got " .. tostring(Text("PlayerStatFrameLeft6StatText")))
Mock.runSpeed = nil

-- without ClassicAPI speed is N/A and the rest still works
ClassicAPI(false)
general = Show("PLAYERSTAT_GENERAL")
ok(general[6] == "Speed: N/A", "speed without ClassicAPI")
Mock.Run(PlayerStatFrameLeft6, "OnEnter")
ClassicAPI(true)

-- ---------------------------------------------------------------- enchant panel

local function Rows(prefix)
	local out = {}
	for i = 1, 20 do
		local r = _G[(prefix or "BCSEnchantFrame") .. "Row" .. i]
		if r and r.shown then
			local line = r.slotId .. " " .. (r.enchant.text or "")
			if r.temp.shown then line = line .. " + " .. r.temp.text end
			table.insert(out, line)
		end
	end
	return out
end

local rows = Rows()
print("Enchants:    " .. table.concat(rows, " | ") .. "  [" .. tostring(BCSEnchantFrame.summary.text) .. "]")
-- head neck shoulder back chest wrist waist ring main hand; no holdable off hand, no wand
ok(table.getn(rows) == 9, "nine rows, got " .. table.getn(rows))
ok(rows[1] == "1 +1% Dodge", "head enchant")
ok(rows[2] == "2 " .. BCS.L.ENCHANT_MISSING, "neck takes a gem here")
ok(rows[6] == "9 " .. BCS.L.ENCHANT_MISSING, "wrist missing")
ok(rows[7] == "6 " .. BCS.L.ENCHANT_NO_BUCKLE, "belt without a buckle, got " .. tostring(rows[7]))
ok(rows[8] == "11 " .. BCS.L.ENCHANT_MISSING, "ring takes a gem here")
ok(rows[9] == "16 Spell Damage +30 + Brilliant Wizard Oil (25 min)", "weapon with oil, got " .. tostring(rows[9]))
ok(BCSEnchantFrame.summary.text == "|cffff20205/9|r", "summary counts enchantable slots, got " .. tostring(BCSEnchantFrame.summary.text))
ok(BCSEnchantFrame.h > 30, "panel sized to rows")
ok(BCSEnchantFrameRow1.name.text == "|cffa335eeMish'undare, Circlet of the Mind Flayer|r", "item name in quality color")
ok(BCSEnchantFrameRow4.slotId == 15 and BCSEnchantFrameRow4.icon.texture == "Interface\\Icons\\INV_Misc_Cape_02", "cloak icon from the character frame, got " .. tostring(BCSEnchantFrameRow4.icon.texture))
ok(BCSEnchantFrameRow1.icon.texture == "Interface\\Icons\\INV_Item_1", "other icons unchanged")

-- time left counts down without a refresh
Mock.temp[16][2] = 59000
Mock.Tick(1.1)
ok(Rows()[9] == "16 Spell Damage +30 + Brilliant Wizard Oil (59 sec)", "oil time ticks, got " .. tostring(Rows()[9]))

-- oil runs out
Mock.temp[16] = nil
Mock.Tick(1.1)
ok(Rows()[9] == "16 Spell Damage +30", "oil gone, got " .. tostring(Rows()[9]))

-- enchanting the wrist, a buckle on the belt, gems in the neck and ring
Mock.inventory[9][2] = 1891
Mock.inventory[6][2] = 3052
Mock.inventory[2][2] = 3100
Mock.inventory[11][2] = 3100
Mock.Fire("UNIT_INVENTORY_CHANGED", "player")
Mock.Tick(0.3)
rows = Rows()
print("Enchanted:   " .. table.concat(rows, " | ") .. "  [" .. tostring(BCSEnchantFrame.summary.text) .. "]")
ok(rows[6] == "9 +4 All Stats", "wrist after enchanting, got " .. tostring(rows[6]))
ok(rows[7] == "6 Buckle: +10 Intellect", "belt buckle, got " .. tostring(rows[7]))
ok(rows[2] == "2 Spell Damage +5", "neck gem")
ok(BCSEnchantFrame.summary.text == "|cff20ff209/9|r", "all enchanted, got " .. tostring(BCSEnchantFrame.summary.text))

-- without ClassicAPI: enchant IDs not seen yet come from the tooltip diff, the oil from the stock call
ClassicAPI(false)
Mock.enchants[4001] = "+8 Intellect"
Mock.enchants[4002] = "+12 Intellect"
Mock.inventory[1][2] = 4001
Mock.inventory[6][2] = 4002
Mock.temp[16] = { 2628, 1500000, 0 }
local lookups = Mock.apiLookups
Mock.Fire("UNIT_INVENTORY_CHANGED", "player")
Mock.Tick(0.3)
rows = Rows()
print("No API:      " .. table.concat(rows, " | "))
ok(Mock.apiLookups == lookups, "no ClassicAPI calls")
ok(rows[1] == "1 +8 Intellect", "head via tooltip diff, got " .. tostring(rows[1]))
ok(rows[7] == "6 Buckle: +12 Intellect", "buckle via tooltip diff, got " .. tostring(rows[7]))
ok(rows[9] == "16 Spell Damage +30 + Brilliant Wizard Oil (25 min)", "oil via tooltip, got " .. tostring(rows[9]))

-- a shield takes an enchant, a held off hand does not
Mock.inventory[17] = { 12345, 0 }
Mock.Fire("UNIT_INVENTORY_CHANGED", "player")
Mock.Tick(0.3)
rows = Rows()
ok(rows[10] == "17 " .. BCS.L.ENCHANT_MISSING, "shield listed as missing, got " .. tostring(rows[10]))

-- toggle button and slash command
BCSEnchantFrameToggleButton:Click()
ok(not BCSEnchantFrame.shown and BCSConfig.EnchantPanel == false, "toggle hides and saves")
ok(BCSEnchantFrameToggleButton.checked == nil, "toggle unchecked")
BCSEnchantFrameCloseButton:Click()
ok(not BCSEnchantFrame.shown, "close button keeps it hidden")
CloseCharacter()
SlashCmdList.BETTERCHARACTERSTATS("enchants")
ok(BCSEnchantFrame.shown and BCSConfig.EnchantPanel == true, "slash shows it")
ok(Mock.toggled == "PaperDollFrame", "slash opens the character frame")
SlashCmdList.BETTERCHARACTERSTATS("")
local n = table.getn(Mock.printed)
ok(string.find(Mock.printed[n - 1], "/bcs enchants") and string.find(Mock.printed[n], "/bcs inspect"), "slash help")

-- shift-click links the item
OpenCharacter()
Mock.shift = true
ChatFrameEditBox.shown = true
Mock.Run(BCSEnchantFrameRow1, "OnClick")
ok(Mock.inserted == GetInventoryItemLink("player", 1), "shift-click links")
Mock.Run(BCSEnchantFrameRow1, "OnEnter")
Mock.shift = nil
CloseCharacter()

-- ---------------------------------------------------------------- inspecting someone

-- the inspect UI loads on demand; nothing exists before that
ok(BCSInspectEnchantFrame == nil, "no inspect panel before the inspect UI loads")
SlashCmdList.BETTERCHARACTERSTATS("inspect")
ok(BCSConfig.InspectEnchantPanel == false, "slash flips the saved choice before the inspect UI loads")
SlashCmdList.BETTERCHARACTERSTATS("inspect")
ok(BCSConfig.InspectEnchantPanel == true, "and back")

InspectFrame = Mock.New("Frame", "InspectFrame", UIParent)
InspectFrame.shown = false
InspectPaperDollFrame = Mock.New("Frame", "InspectPaperDollFrame", InspectFrame)
InspectMainHandSlot = Mock.New("Button", "InspectMainHandSlot", InspectPaperDollFrame)
InspectModelFrame = Mock.New("PlayerModel", "InspectModelFrame", InspectPaperDollFrame)
InspectModelFrame.h = 300
for slotName, id in pairs(SLOT_IDS) do
	Mock.New("Texture", "Inspect" .. slotName .. "IconTexture", InspectPaperDollFrame).GetTexture = function(self)
		return GetInventoryItemTexture(InspectFrame.unit, id) or ("Interface\\PaperDoll\\UI-PaperDoll-Slot-" .. slotName)
	end
end
Mock.loaded = { Blizzard_InspectUI = true }
Mock.Fire("ADDON_LOADED", "Blizzard_InspectUI")
ok(BCSInspectEnchantFrame ~= nil and BCSInspectEnchantFrameToggleButton ~= nil, "inspect panel built when the inspect UI loads")
ok(BCSInspectEnchantFrame.shown and BCSInspectEnchantFrameToggleButton.checked == 1, "inspect panel shown by default")
ok(BCSInspectStatFrame ~= nil and BCSInspectStatFrameRight6 ~= nil, "inspect stat pages built")
ok(InspectModelFrame.h == 205, "inspect model shortened to make room")

-- a raider: unenchanted head and chest, a buckle, an oiled weapon; the cloak isn't in the client's cache yet
Mock.others.target = {
	[1] = { 19375, 0 },
	[5] = { 16916, 0 },
	[6] = { 19400, 3052 },
	[15] = { 19378, 1889 },
	[16] = { 19356, 2504 },
	[17] = { 19366, 0 },
}
Mock.otherTemp.target = { [16] = { 2628, 600000 } }
Mock.uncached.target = { [15] = true }
Mock.classes.target = "DRUID"
InspectFrame.unit = "target"
Open(InspectFrame)
rows = Rows("BCSInspectEnchantFrame")
print("Inspect:     " .. table.concat(rows, " | ") .. "  [" .. tostring(BCSInspectEnchantFrame.summary.text) .. "]")
ok(table.getn(rows) == 4, "four rows while the cloak is unknown, got " .. table.getn(rows))
ok(rows[1] == "1 " .. BCS.L.ENCHANT_MISSING, "their head is missing an enchant")
ok(rows[3] == "6 Buckle: +10 Intellect", "their buckle")
ok(rows[4] == "16 Spell Damage +30 + Brilliant Wizard Oil (10 min)", "their oil from the item tooltip, got " .. tostring(rows[4]))
ok(BCSInspectEnchantFrame.summary.text == "|cffff20202/4|r", "their count")
ok(BCSInspectEnchantFrameRow1.icon.texture == "Interface\\Icons\\INV_Item_1", "their icons")
ok(table.getn(Rows()) == 10, "own panel untouched")

local function Page(side)
	local out = {}
	for i = 1, 6 do
		local n = "BCSInspectStatFrame" .. side .. i
		table.insert(out, (Text(n .. "Label") or "?") .. " " .. (Text(n .. "StatText") or "?"))
	end
	return out
end
local function Green(v) return "|cff20ff20" .. v .. "|r" end

-- their stats: base stats on the left, a druid gets the spell page on the right
local left, right = Page("Left"), Page("Right")
print("Their base:  " .. table.concat(left, " | "))
print("Their spell: " .. table.concat(right, " | "))
ok(BCSInspectStatFrameLeftDropDown.ddText == "Base Stats" and BCSInspectStatFrameRightDropDown.ddText == "Spell", "default pages")
-- head 24, chest 26, belt 12 + buckle 10 (the cloak isn't known yet)
ok(left[4] == "Intellect: " .. Green("+72"), "their intellect from gear, got " .. left[4])
ok(left[1] == "Strength: 0", "nothing for strength")
-- staff 84 + enchant 30
ok(right[1] == "Power: " .. Green("+114"), "their spell power, got " .. right[1])
ok(right[4] == "Healing: " .. Green("+114"), "their healing, got " .. right[4])

-- the cloak arrives; the panel and the stats look again by themselves
Mock.uncached.target = nil
Mock.Tick(1.1)
rows = Rows("BCSInspectEnchantFrame")
ok(rows[2] == "15 +70 Armor", "late item shows up, got " .. tostring(rows[2]))
ok(BCSInspectEnchantFrame.summary.text == "|cffff20203/5|r", "count with the cloak")
left = Page("Left")
ok(left[4] == "Intellect: " .. Green("+86"), "intellect with the cloak, got " .. left[4])
ok(left[6] == "Armor: " .. Green("+70"), "armor from the cloak enchant, got " .. left[6])

-- two set pieces: the active bonus counts once, the inactive one not at all
Mock.others.target[3] = { 47199, 0 }
Mock.others.target[5] = { 47200, 0 }
Mock.Fire("UNIT_INVENTORY_CHANGED", "target")
Mock.Tick(0.4)
left, right = Page("Left"), Page("Right")
print("Their set:   " .. table.concat(left, " | ") .. " || " .. table.concat(right, " | "))
ok(right[2] == "Hit Rating: " .. Green("+1%"), "set spell hit once, got " .. right[2])
ok(right[3] == "Crit Chance: 0%", "inactive set bonus ignored, got " .. right[3])
ok(left[2] == "Agility: |cffff2020-5|r", "negative stats in red, got " .. left[2])
ok(left[6] == "Armor: " .. Green("+570"), "item armor plus enchant, got " .. left[6])

-- switching pages with the dropdowns, and every page's tooltips
Mock.menuItems = {}
Mock.menuInit()
local pick = Mock.menuItems[1].func
local function Choose(side, page)
	this = { owner = side, value = page }
	pick()
	this = nil
end
Choose("Left", "PLAYERSTAT_RESISTANCES")
left = Page("Left")
ok(BCSConfig.InspectDropdownLeft == "PLAYERSTAT_RESISTANCES" and BCSInspectStatFrameLeftDropDown.ddText == "Resistances", "page choice saved")
ok(left[3] == "Fire: " .. Green("+14"), "fire resistance plus all resistances, got " .. left[3])
ok(left[2] == "Arcane: " .. Green("+4"), "all resistances, got " .. left[2])
for _, page in ipairs({ "PLAYERSTAT_BASE_STATS", "PLAYERSTAT_MELEE_COMBAT", "PLAYERSTAT_SPELL_COMBAT", "PLAYERSTAT_SPELL_SCHOOLS", "PLAYERSTAT_DEFENSES", "PLAYERSTAT_GENERAL", "PLAYERSTAT_RESISTANCES" }) do
	Choose("Left", page)
	for i = 1, 6 do
		local good, err = pcall(Mock.Run, _G["BCSInspectStatFrameLeft" .. i], "OnEnter")
		ok(good, page .. " row " .. i .. " tooltip: " .. tostring(err))
		ok(Text("BCSInspectStatFrameLeft" .. i .. "StatText") ~= nil, page .. " row " .. i .. " has a value")
	end
end
-- General: real health and mana for group members, gear otherwise
Choose("Left", "PLAYERSTAT_GENERAL")
left = Page("Left")
ok(left[1] == "Health: " .. Green("+120"), "health from gear when not grouped, got " .. left[1])
Mock.group.target = true
ClassicAPI(true)
Choose("Left", "PLAYERSTAT_GENERAL")
left = Page("Left")
ok(left[1] == "Health: 3800" and left[2] == "Mana: 6200", "real health and mana in a group, got " .. left[1] .. " / " .. left[2])
ok(left[6] == "Speed: 100%", "their speed from ClassicAPI, got " .. left[6])
Mock.group.target = nil
Choose("Left", "PLAYERSTAT_BASE_STATS")

-- hover and shift-click use the inspected unit
Mock.Run(BCSInspectEnchantFrameRow1, "OnEnter")
Mock.shift = true
Mock.Run(BCSInspectEnchantFrameRow1, "OnClick")
ok(Mock.inserted == GetInventoryItemLink("target", 1), "shift-click links their item")
Mock.shift = nil

-- their gear changes while the window is open
Mock.others.target[1][2] = 2545
Mock.Fire("UNIT_INVENTORY_CHANGED", "target")
Mock.Fire("UNIT_INVENTORY_CHANGED", "player")
Mock.Tick(0.3)
ok(Rows("BCSInspectEnchantFrame")[1] == "1 +1% Dodge", "refresh on their inventory change")

-- inspecting someone else: the frame is hidden and shown again with the new unit
InspectFrame.shown = false
Mock.others.raid2 = { [16] = { 19356, 0 } }
InspectFrame.unit = "raid2"
Open(InspectFrame)
rows = Rows("BCSInspectEnchantFrame")
ok(table.getn(rows) == 1 and rows[1] == "16 " .. BCS.L.ENCHANT_MISSING, "next player, got " .. table.concat(rows, " | "))

-- closing clears the unit; nothing runs without one
InspectFrame.unit = nil
local good, err = pcall(Mock.Tick, 1.1)
ok(good, "no unit, no errors: " .. tostring(err))
InspectFrame.shown = false

-- toggling the inspect panel
InspectFrame.unit = "target"
Open(InspectFrame)
BCSInspectEnchantFrameToggleButton:Click()
ok(not BCSInspectEnchantFrame.shown and BCSConfig.InspectEnchantPanel == false, "inspect toggle hides and saves")
ok(BCSEnchantFrame.shown, "own panel keeps its own setting")
SlashCmdList.BETTERCHARACTERSTATS("inspect")
ok(BCSInspectEnchantFrame.shown and BCSConfig.InspectEnchantPanel == true, "slash shows the inspect panel")
InspectFrame.shown = false

-- naked
OpenCharacter()
Mock.inventory = {}
Mock.temp = {}
Mock.Fire("UNIT_INVENTORY_CHANGED", "player")
Mock.Tick(0.3)
ok(table.getn(Rows()) == 0 and BCSEnchantFrame.empty.shown, "empty text when nothing is equipped")

print(string.format("%d checks, %d failed", checks, fails))
if fails > 0 then os.exit(1) end


-- GetSkillLineInfo is never asked past the last skill (it crashes the real client)
do
  local good, v = pcall(function() return BCS:GetWeaponSkill("Swords") end)
  ok(good and v == 295, "weapon skill found without going past the last skill")
  good, v = pcall(function() return BCS:GetWeaponSkill("Maces") end)
  ok(good and v == 0, "an unknown skill: 0, no call past the end")
end
