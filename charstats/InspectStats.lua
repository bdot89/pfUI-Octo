-- Stats on the inspect window, in the same two dropdown pages as the character frame.
-- The client is only told another player's gear (and health and mana for group members),
-- not their stats, talents or buff effects, so the pages show what their items, enchants
-- and set bonuses add up to.
local _G = _G or getfenv(0)

BCS = BCS or {}

local L = BCS.L

local OPTIONS = {
	"PLAYERSTAT_BASE_STATS",
	"PLAYERSTAT_MELEE_COMBAT",
	"PLAYERSTAT_SPELL_COMBAT",
	"PLAYERSTAT_SPELL_SCHOOLS",
	"PLAYERSTAT_DEFENSES",
	"PLAYERSTAT_GENERAL",
	"PLAYERSTAT_RESISTANCES",
}

-- right page for a class the first time; the user's own pick is saved after that
local CLASS_PAGE = {
	WARRIOR = "PLAYERSTAT_MELEE_COMBAT",
	ROGUE = "PLAYERSTAT_MELEE_COMBAT",
	HUNTER = "PLAYERSTAT_MELEE_COMBAT",
}

local RETRY_DELAY = 1
local MAX_RETRIES = 10

local frame, scanTooltip
local totals = {}
local addonLoaded = false
local dirtyTimer, retries = nil, 0

-- ---------------------------------------------------------------- reading gear

-- { pattern, key }: the first capture is added to totals[key]
local PATTERNS = {
	-- item stats, random suffixes and enchants read the same ("+15 Stamina")
	{ "^([%+%-]%d+) Strength$", "str" },
	{ "^([%+%-]%d+) Agility$", "agi" },
	{ "^([%+%-]%d+) Stamina$", "sta" },
	{ "^([%+%-]%d+) Intellect$", "int" },
	{ "^([%+%-]%d+) Spirit$", "spi" },
	{ "^%+(%d+) All Stats$", "allStats" },
	{ "^(%d+) Armor$", "armor" },
	{ "^%+(%d+) Armor$", "armor" },
	{ "^([%+%-]%d+) Arcane Resistance$", "resArcane" },
	{ "^([%+%-]%d+) Fire Resistance$", "resFire" },
	{ "^([%+%-]%d+) Frost Resistance$", "resFrost" },
	{ "^([%+%-]%d+) Nature Resistance$", "resNature" },
	{ "^([%+%-]%d+) Shadow Resistance$", "resShadow" },
	{ "^%+(%d+) All Resistances$", "resAll" },
	{ "^%+(%d+) to All Resistances$", "resAll" },
	{ "^%+(%d+) Health$", "health" },
	{ "^%+(%d+) Mana$", "mana" },

	-- physical
	{ "^Equip: %+(%d+) Attack Power%.", "ap" },
	{ "^%+(%d+) Attack Power$", "ap" },
	{ "^Equip: %+(%d+) ranged Attack Power%.", "rap" },
	{ "^%+(%d+) Ranged Attack Power$", "rap" },
	{ L["Equip: Improves your chance to hit by (%d)%%."], "hit" },
	{ L["/Hit %+(%d+)"], "hit" },
	{ L["^Equip: Improves your chance to hit with spells and attacks by (%d+)%%"], "hit" },
	{ L["Equip: Improves your chance to get a critical strike by (%d)%%."], "crit" },
	{ L["^Equip: Increases your attack and casting speed by (%d+)%%"], "haste" },
	{ L["^%+(%d+)%% Haste"], "haste" },
	{ L["^Attack Speed %+(%d+)%%"], "haste" },
	{ L["^Equip: Your attacks ignore (%d+) of the target's armor"], "armorPen" },

	-- spells
	{ L["Equip: Improves your chance to hit with spells by (%d)%%."], "spellHit" },
	{ L["/Spell Hit %+(%d+)"], "spellHit" },
	{ L["^Equip: Improves your chance to hit with spells and attacks by (%d+)%%"], "spellHit" },
	{ L["Equip: Improves your chance to get a critical strike with spells by (%d)%%."], "spellCrit" },
	{ L["(%d)%% Spell Critical Strike"], "spellCrit" },
	{ L["Equip: Increases damage and healing done by magical spells and effects by up to (%d+)%."], "spellPower" },
	{ L["Spell Damage %+(%d+)"], "spellPower" },
	{ L["^%+(%d+) Spell Damage and Healing"], "spellPower" },
	{ L["^%+(%d+) Damage and Healing Spells"], "spellPower" },
	{ L["^%+(%d+) Spell Power"], "spellPower" },
	{ L["Equip: Increases healing done by spells and effects by up to (%d+)."], "healing" },
	{ L["Healing Spells %+(%d+)"], "healing" },
	{ L["^%+(%d+) Healing Spells"], "healing" },
	{ L["Healing %+(%d+)"], "healing" },
	{ L["Equip: Increases damage done by Arcane spells and effects by up to (%d+)."], "Arcane" },
	{ L["^%+(%d+) Arcane Spell Damage"], "Arcane" },
	{ L["Arcane Damage %+(%d+)"], "Arcane" },
	{ L["Equip: Increases damage done by Fire spells and effects by up to (%d+)."], "Fire" },
	{ L["^%+(%d+) Fire Spell Damage"], "Fire" },
	{ L["Fire Damage %+(%d+)"], "Fire" },
	{ L["Equip: Increases damage done by Frost spells and effects by up to (%d+)."], "Frost" },
	{ L["^%+(%d+) Frost Spell Damage"], "Frost" },
	{ L["Frost Damage %+(%d+)"], "Frost" },
	{ L["Equip: Increases damage done by Holy spells and effects by up to (%d+)."], "Holy" },
	{ L["^%+(%d+) Holy Spell Damage"], "Holy" },
	{ L["Holy Damage %+(%d+)"], "Holy" },
	{ L["Equip: Increases damage done by Nature spells and effects by up to (%d+)."], "Nature" },
	{ L["^%+(%d+) Nature Spell Damage"], "Nature" },
	{ L["Nature Damage %+(%d+)"], "Nature" },
	{ L["Equip: Increases damage done by Shadow spells and effects by up to (%d+)."], "Shadow" },
	{ L["^%+(%d+) Shadow Spell Damage"], "Shadow" },
	{ L["Shadow Damage %+(%d+)"], "Shadow" },
	{ L["^Mana Regen %+(%d+)"], "mp5" },
	{ L["Equip: Restores (%d+) mana per 5 sec."], "mp5" },
	{ L["^Healing %+%d+ and (%d+) mana per 5 sec."], "mp5" },
	{ L["^%+(%d+) mana every 5 sec."], "mp5" },
	{ L["^Equip: Increases your casting speed by (%d+)%%"], "spellHaste" },
	{ L["^Equip: Decreases the magical resistances of your spell targets by (%d+)"], "spellPen" },
	{ L["^%+(%d+) Spell Penetration"], "spellPen" },
	{ L["^Equip: Restores (%d+) health per 5 sec"], "hp5" },
	{ L["^Equip: Restores (%d+) health every 5 sec"], "hp5" },

	-- defense
	{ "^Equip: Increased Defense %+(%d+)%.", "defense" },
	{ "^%+(%d+) Defense$", "defense" },
	{ "^Defense %+(%d+)", "defense" },
	{ "^Equip: Increases your chance to dodge an attack by (%d+)%%%.", "dodge" },
	{ "^%+(%d+)%% Dodge$", "dodge" },
	{ "^Equip: Increases your chance to parry an attack by (%d+)%%%.", "parry" },
	{ "^Equip: Increases your chance to block attacks with a shield by (%d+)%%%.", "block" },
	{ "^(%d+) Block$", "blockValue" },
	{ L["Equip: Increases the block value of your shield by (%d+)."], "blockValue" },
	{ L["Block Value %+(%d+)"], "blockValue" },
}

local function ScanTooltip()
	if not scanTooltip then
		scanTooltip = CreateFrame("GameTooltip", "BCSInspectScanTooltip", nil, "GameTooltipTemplate")
	end
	scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
	scanTooltip:ClearLines()
	return scanTooltip
end

local function AddLine(text)
	for i = 1, getn(PATTERNS) do
		local _, _, value = strfind(text, PATTERNS[i][1])
		if value then
			local key = PATTERNS[i][2]
			totals[key] = (totals[key] or 0) + tonumber(value)
		end
	end
end

-- Adds up the unit's gear into totals; true when an item isn't known to the client yet
local seenSetLines = {}
local function ScanGear(unit)
	for k in pairs(totals) do
		totals[k] = nil
	end
	for k in pairs(seenSetLines) do
		seenSetLines[k] = nil
	end

	local incomplete = false
	for slot = 1, 19 do
		if GetInventoryItemLink(unit, slot) then
			local tip = ScanTooltip()
			tip:SetInventoryItem(unit, slot)
			local setName
			for i = 1, tip:NumLines() do
				local line = _G["BCSInspectScanTooltipTextLeft" .. i]
				local text = line and line:GetText()
				if text then
					local _, _, name = strfind(text, L.SET_PATTERN)
					if name then
						setName = name
					end
					if strfind(text, "^Set: ") then
						-- an active set bonus, listed on every piece: count it once
						local key = (setName or "") .. text
						if not seenSetLines[key] then
							seenSetLines[key] = true
							AddLine(ITEM_SPELL_TRIGGER_ONEQUIP .. strsub(text, 5))
						end
					else
						AddLine(text)
					end
				end
			end
		elseif GetInventoryItemTexture(unit, slot) then
			incomplete = true
		end
	end
	return incomplete
end

local function T(key)
	return totals[key] or 0
end

-- ---------------------------------------------------------------- showing it

local function Signed(value, suffix)
	suffix = suffix or ""
	if value > 0 then
		return GREEN_FONT_COLOR_CODE .. "+" .. value .. suffix .. FONT_COLOR_CODE_CLOSE
	elseif value < 0 then
		return RED_FONT_COLOR_CODE .. value .. suffix .. FONT_COLOR_CODE_CLOSE
	end
	return "0" .. suffix
end

local function Row_OnEnter()
	if not this.tooltip then
		return
	end
	GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
	GameTooltip:SetText(this.tooltip, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	if this.tooltipSubtext then
		GameTooltip:AddLine(this.tooltipSubtext, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1)
	end
	if this.note then
		GameTooltip:AddLine(this.note, 0.6, 0.6, 0.6, 1)
	end
	GameTooltip:Show()
end

-- label, value text, tooltip title and text; source: nil = added up from their gear,
-- "real" = a value the client has for them, "none" = no note
local function SetRow(row, label, value, tooltip, sub, source)
	_G[row:GetName() .. "Label"]:SetText(label)
	_G[row:GetName() .. "StatText"]:SetText(value)
	row.tooltip = tooltip or label
	row.tooltipSubtext = sub
	if source == "real" then
		row.note = L.INSPECT_REAL_NOTE
	elseif source == "none" then
		row.note = nil
	else
		row.note = L.INSPECT_GEAR_NOTE
	end
	row:SetScript("OnEnter", Row_OnEnter)
end

local function InGroup(unit)
	return UnitIsUnit(unit, "player") or UnitInParty(unit) or UnitInRaid(unit)
end

local function SetHealth(row, unit)
	if InGroup(unit) then
		SetRow(row, HEALTH_COLON, UnitHealthMax(unit), HEALTH, L.INSPECT_HEALTH_REAL, "real")
	else
		SetRow(row, HEALTH_COLON, Signed((T("sta") + T("allStats")) * 10 + T("health")), HEALTH, L.INSPECT_HEALTH_GEAR)
	end
end

local function SetMana(row, unit)
	local _, class = UnitClass(unit)
	if class == "WARRIOR" or class == "ROGUE" then
		SetRow(row, MANA_COLON, NOT_APPLICABLE, MANA, nil, "none")
	elseif InGroup(unit) and UnitPowerType(unit) == 0 then
		SetRow(row, MANA_COLON, UnitManaMax(unit), MANA, L.INSPECT_MANA_REAL, "real")
	else
		SetRow(row, MANA_COLON, Signed((T("int") + T("allStats")) * 15 + T("mana")), MANA, L.INSPECT_MANA_GEAR)
	end
end

local function SetSpeed(row, unit)
	local ok, run
	if GetUnitSpeed then
		local _
		ok, _, run = pcall(GetUnitSpeed, unit)
	end
	if ok and type(run) == "number" and run > 0 then
		SetRow(row, L.MOVE_SPEED_COLON, format("%d%%", floor(run / 7 * 100 + 0.5)), L.MOVE_SPEED_MISSING, L.INSPECT_SPEED, "real")
	else
		SetRow(row, L.MOVE_SPEED_COLON, NOT_APPLICABLE, L.MOVE_SPEED_MISSING, L.MOVE_SPEED_MISSING_SUB, "none")
	end
end

local RESISTANCES = {
	{ "resArcane", 6 },
	{ "resFire", 2 },
	{ "resFrost", 4 },
	{ "resNature", 3 },
	{ "resShadow", 5 },
}

local SCHOOLS = { "Arcane", "Fire", "Frost", "Holy", "Nature", "Shadow" }

local function Fill(prefix, page, unit)
	local r = {}
	for i = 1, 6 do
		r[i] = _G[prefix .. i]
	end

	if page == "PLAYERSTAT_BASE_STATS" then
		local keys = { "str", "agi", "sta", "int", "spi" }
		for i = 1, 5 do
			SetRow(r[i], _G["SPELL_STAT" .. (i - 1) .. "_NAME"] .. ":", Signed(T(keys[i]) + T("allStats")), _G["SPELL_STAT" .. (i - 1) .. "_NAME"])
		end
		SetRow(r[6], ARMOR_COLON, Signed(T("armor")), ARMOR)
	elseif page == "PLAYERSTAT_MELEE_COMBAT" then
		SetRow(r[1], ATTACK_POWER_COLON, Signed(T("ap")), MELEE_ATTACK_POWER)
		SetRow(r[2], L.INSPECT_RANGED_AP_COLON, Signed(T("ap") + T("rap")), RANGED_ATTACK_POWER)
		SetRow(r[3], L.MELEE_HIT_RATING_COLON, Signed(T("hit"), "%"), L.MELEE_HIT_TOOLTIP, L.MELEE_HIT_TOOLTIP_SUB)
		SetRow(r[4], L.MELEE_CRIT_COLON, Signed(T("crit"), "%"), L.MELEE_CRIT_TOOLTIP, L.MELEE_CRIT_TOOLTIP_SUB)
		SetRow(r[5], L.HASTE_COLON, Signed(T("haste"), "%"), L.MELEE_HASTE_TOOLTIP, L.MELEE_HASTE_TOOLTIP_SUB)
		SetRow(r[6], L.ARMOR_PEN_SHORT_COLON, Signed(T("armorPen")), L.ARMOR_PEN_TOOLTIP, L.ARMOR_PEN_TOOLTIP_SUB)
	elseif page == "PLAYERSTAT_SPELL_COMBAT" then
		local power, healing = T("spellPower"), T("spellPower") + T("healing")
		SetRow(r[1], L.SPELL_POWER_COLON, Signed(power), format(L.SPELL_POWER_TOOLTIP, power), L.SPELL_POWER_TOOLTIP_SUB)
		SetRow(r[2], L.SPELL_HIT_RATING_COLON, Signed(T("spellHit"), "%"), L.SPELL_HIT_TOOLTIP, L.SPELL_HIT_TOOLTIP_SUB)
		SetRow(r[3], L.SPELL_CRIT_COLON, Signed(T("spellCrit"), "%"), L.SPELL_CRIT_TOOLTIP, L.SPELL_CRIT_TOOLTIP_SUB)
		SetRow(r[4], L.HEAL_POWER_COLON, Signed(healing), format(L.SPELL_HEALING_POWER_TOOLTIP, healing), L.SPELL_HEALING_POWER_TOOLTIP_SUB)
		SetRow(r[5], L.MP5_COLON, Signed(T("mp5")), format(L.MP5_TOOLTIP, T("mp5")), L.INSPECT_MP5)
		SetRow(r[6], L.HASTE_COLON, Signed(T("haste") + T("spellHaste"), "%"), L.SPELL_HASTE_TOOLTIP, L.SPELL_HASTE_TOOLTIP_SUB)
	elseif page == "PLAYERSTAT_SPELL_SCHOOLS" then
		for i = 1, 6 do
			local school = SCHOOLS[i]
			SetRow(r[i], L["SPELL_SCHOOL_" .. strupper(school)], Signed(T("spellPower") + T(school)),
				format(L.INSPECT_SCHOOL_TOOLTIP, school), format(L.SPELL_SCHOOL_TOOLTIP_SUB, strlower(school)))
		end
	elseif page == "PLAYERSTAT_DEFENSES" then
		SetRow(r[1], ARMOR_COLON, Signed(T("armor")), ARMOR)
		SetRow(r[2], DEFENSE_COLON, Signed(T("defense")), L.DEFENSE_TOOLTIP, L.DEFENSE_TOOLTIP_SUB)
		SetRow(r[3], L.DODGE_COLON, Signed(T("dodge"), "%"), L.PLAYER_DODGE_TOOLTIP, L.PLAYER_DODGE_TOOLTIP_SUB)
		SetRow(r[4], L.PARRY_COLON, Signed(T("parry"), "%"), L.PLAYER_PARRY_TOOLTIP, L.PLAYER_PARRY_TOOLTIP_SUB)
		SetRow(r[5], L.BLOCK_COLON, Signed(T("block"), "%"), L.PLAYER_BLOCK_TOOLTIP, L.PLAYER_BLOCK_TOOLTIP_SUB)
		SetRow(r[6], L.BLOCK_VALUE_COLON, Signed(T("blockValue")), format(L.BLOCK_VALUE_TOOLTIP, T("blockValue")), L.INSPECT_BLOCK_VALUE)
	elseif page == "PLAYERSTAT_GENERAL" then
		SetHealth(r[1], unit)
		SetMana(r[2], unit)
		SetRow(r[3], L.INSPECT_HP5_COLON, Signed(T("hp5")), format(L.INSPECT_HP5_TOOLTIP, T("hp5")), L.INSPECT_HP5)
		SetRow(r[4], L.MP5_COLON, Signed(T("mp5")), format(L.MP5_TOOLTIP, T("mp5")), L.INSPECT_MP5)
		SetRow(r[5], L.SPELL_PEN_COLON, Signed(T("spellPen")), L.SPELL_PEN_TOOLTIP, L.SPELL_PEN_TOOLTIP_SUB)
		SetSpeed(r[6], unit)
	elseif page == "PLAYERSTAT_RESISTANCES" then
		SetRow(r[1], ARMOR_COLON, Signed(T("armor")), ARMOR)
		for i = 1, 5 do
			local key, index = RESISTANCES[i][1], RESISTANCES[i][2]
			SetRow(r[i + 1], _G["SPELL_SCHOOL" .. index .. "_CAP"] .. ":", Signed(T(key) + T("resAll")), _G["RESISTANCE" .. index .. "_NAME"])
		end
	end
end

local function PageFor(side, unit)
	local saved = BCSConfig["InspectDropdown" .. side]
	if saved then
		return saved
	end
	if side == "Left" then
		return "PLAYERSTAT_BASE_STATS"
	end
	local _, class = UnitClass(unit)
	return CLASS_PAGE[class or ""] or "PLAYERSTAT_SPELL_COMBAT"
end

local function ShowPages(unit)
	for _, side in ipairs({ "Left", "Right" }) do
		local page = PageFor(side, unit)
		local dropdown = _G["BCSInspectStatFrame" .. side .. "DropDown"]
		UIDropDownMenu_SetSelectedValue(dropdown, page)
		UIDropDownMenu_SetText(L[page], dropdown)
		Fill("BCSInspectStatFrame" .. side, page, unit)
	end
end

local function Refresh()
	dirtyTimer = nil
	local unit = InspectFrame.unit
	if not unit then
		return
	end
	local incomplete = ScanGear(unit)
	ShowPages(unit)
	if incomplete and retries < MAX_RETRIES then
		retries = retries + 1
		dirtyTimer = RETRY_DELAY
	end
end

-- ---------------------------------------------------------------- the frame

local function Dropdown_OnClick()
	local side = this.owner
	BCSConfig["InspectDropdown" .. side] = this.value
	if InspectFrame.unit then
		ShowPages(InspectFrame.unit)
	end
end

local info = {}
local function DropdownInit(side)
	return function()
		for i = 1, getn(OPTIONS) do
			info.text = L[OPTIONS[i]]
			info.func = Dropdown_OnClick
			info.value = OPTIONS[i]
			info.owner = side
			info.checked = nil
			UIDropDownMenu_AddButton(info)
		end
	end
end

-- same art and layout as BCSFrame in BetterCharacterStats.xml
local function Background(name, anchorTo, anchorPoint, height, top, bottom)
	local tex = frame:CreateTexture(name, "BORDER")
	tex:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-StatBackground")
	tex:SetWidth(115)
	tex:SetHeight(height)
	tex:SetTexCoord(0, 0.8984375, top, bottom)
	tex:SetPoint("TOPLEFT", anchorTo, anchorPoint)
	return tex
end

local function CreateStatFrame()
	if frame or not (InspectFrame and InspectPaperDollFrame and InspectModelFrame) then
		return
	end

	frame = CreateFrame("Frame", "BCSInspectStatFrame", InspectPaperDollFrame)
	frame:SetWidth(230)
	frame:SetHeight(78)
	frame:SetPoint("TOPLEFT", InspectPaperDollFrame, "TOPLEFT", 67, -291)

	local leftTop = Background("BCSInspectStatLeftTop", frame, "TOPLEFT", 16, 0, 0.125)
	local leftMiddle = Background(nil, leftTop, "BOTTOMLEFT", 53, 0.125, 0.1953125)
	Background(nil, leftMiddle, "BOTTOMLEFT", 16, 0.484375, 0.609375)
	local rightTop = Background("BCSInspectStatRightTop", leftTop, "TOPRIGHT", 16, 0, 0.125)
	local rightMiddle = Background(nil, rightTop, "BOTTOMLEFT", 53, 0.125, 0.1953125)
	Background(nil, rightMiddle, "BOTTOMLEFT", 16, 0.484375, 0.609375)

	for _, side in ipairs({ "Left", "Right" }) do
		local top = side == "Left" and leftTop or rightTop
		local previous
		for i = 1, 6 do
			local row = CreateFrame("Frame", "BCSInspectStatFrame" .. side .. i, frame, "BetterStatFrameTemplate")
			if previous then
				row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, 0)
			else
				row:SetPoint("TOPLEFT", top, "TOPLEFT", 6, -3)
			end
			row:EnableMouse(true)
			previous = row
		end

		local dropdown = CreateFrame("Frame", "BCSInspectStatFrame" .. side .. "DropDown", frame, "UIDropDownMenuTemplate")
		dropdown:SetPoint("BOTTOMLEFT", top, "TOPLEFT", -17, -8)
		RaiseFrameLevel(dropdown)
		RaiseFrameLevel(_G[dropdown:GetName() .. "Button"])
		UIDropDownMenu_Initialize(dropdown, DropdownInit(side))
		UIDropDownMenu_SetWidth(99, dropdown)
		UIDropDownMenu_JustifyText("LEFT", dropdown)
	end

	-- leave room under the model, as BetterCharacterStats does on the character frame
	InspectModelFrame:SetHeight(205)

	frame:SetScript("OnShow", function()
		retries = 0
		Refresh()
	end)
	frame:SetScript("OnUpdate", function()
		if dirtyTimer then
			dirtyTimer = dirtyTimer - arg1
			if dirtyTimer <= 0 then
				Refresh()
			end
		end
	end)
	frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
	frame:SetScript("OnEvent", function()
		if arg1 and arg1 == InspectFrame.unit and frame:IsVisible() then
			retries = 0
			dirtyTimer = 0.3
		end
	end)
end

-- Blizzard_InspectUI loads on demand, the first time someone is inspected
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function()
	if arg1 == BCS.ADDON_NAME then
		addonLoaded = true
		if IsAddOnLoaded("Blizzard_InspectUI") then
			CreateStatFrame()
		end
	elseif arg1 == "Blizzard_InspectUI" and addonLoaded then
		CreateStatFrame()
	end
	if frame then
		loader:UnregisterEvent("ADDON_LOADED")
	end
end)
