-- Enchant panels: a list of the enchants on a player's gear that slides out to the right
-- of the character frame (your gear) and of the inspect frame (the inspected player's gear).
-- Toggled by the button left of the main hand slot, /bcs enchants or /bcs inspect.
local _G = _G or getfenv(0)

BCS = BCS or {}

local L = BCS.L

local PANEL_WIDTH = 230
local PAD = 8
local HEADER_HEIGHT = 30
local ICON_SIZE = 22
local LINE_HEIGHT = 12
local TEXT_WIDTH = PANEL_WIDTH - 2 * PAD - ICON_SIZE - 5

-- an inspected player's items can arrive after the frame opens; look again this often
local RETRY_DELAY = 1
local MAX_RETRIES = 10

local ENCHANT_COLOR = { r = 0.12, g = 1, b = 0.12 }
local MISSING_COLOR = { r = 1, g = 0.3, b = 0.3 }
local TEMP_COLOR = { r = 0.45, g = 0.8, b = 1 }

-- [2] = takes an enchant on this server (OctoWoW's Spell.dbc: necks and rings take gems,
-- belts take buckles); other slots are listed only when they carry an enchant.
-- [3] = the enchant is a belt buckle
local SLOTS = {
	{ "HeadSlot", true },
	{ "NeckSlot", true },
	{ "ShoulderSlot", true },
	{ "BackSlot", true },
	{ "ChestSlot", true },
	{ "ShirtSlot" },
	{ "TabardSlot" },
	{ "WristSlot", true },
	{ "HandsSlot", true },
	{ "WaistSlot", true, true },
	{ "LegsSlot", true },
	{ "FeetSlot", true },
	{ "Finger0Slot", true },
	{ "Finger1Slot", true },
	{ "Trinket0Slot" },
	{ "Trinket1Slot" },
	{ "MainHandSlot", true },
	{ "SecondaryHandSlot", true },
	{ "RangedSlot", true },
}

local MAINHAND, OFFHAND, RANGED = 16, 17, 18

local scanTooltip
local playerPanel, inspectPanel
local addonLoaded = false

-- enchant ID -> name, filled as enchants are seen
local enchantNames = {}

local function ScanLine(i)
	local line = _G["BCSEnchantScanTooltipTextLeft" .. i]
	return line and line:GetText()
end

local function ScanTooltip()
	if not scanTooltip then
		scanTooltip = CreateFrame("GameTooltip", "BCSEnchantScanTooltip", nil, "GameTooltipTemplate")
	end
	scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
	scanTooltip:ClearLines()
	return scanTooltip
end

-- ClassicAPI.dll resolves enchant IDs straight from the client's enchant table
local function EnchantNameFromAPI(enchantID)
	if not (C_Item and C_Item.GetEnchantInfo) then
		return
	end
	local ok, info = pcall(C_Item.GetEnchantInfo, enchantID)
	if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
		return info.name
	end
end

-- Without ClassicAPI: the line that the enchanted item's tooltip has and the bare item's lacks.
-- Lines are counted, as an enchant can read the same as a stat the item has ("+10 Intellect").
local seenLines = {}
local function EnchantNameFromTooltip(itemID, enchantID, suffixID)
	for k in pairs(seenLines) do
		seenLines[k] = nil
	end

	local tip = ScanTooltip()
	tip:SetHyperlink("item:" .. itemID .. ":0:" .. suffixID .. ":0")
	for i = 1, tip:NumLines() do
		local text = ScanLine(i)
		if text then
			seenLines[text] = (seenLines[text] or 0) + 1
		end
	end

	tip = ScanTooltip()
	tip:SetHyperlink("item:" .. itemID .. ":" .. enchantID .. ":" .. suffixID .. ":0")
	for i = 1, tip:NumLines() do
		local text = ScanLine(i)
		if text then
			local count = seenLines[text]
			if count and count > 0 then
				seenLines[text] = count - 1
			else
				return text
			end
		end
	end
end

local function EnchantName(enchantID, itemID, suffixID)
	local name = enchantNames[enchantID]
	if name then
		return name
	end
	name = EnchantNameFromAPI(enchantID)
	if not name and itemID then
		name = EnchantNameFromTooltip(itemID, enchantID, suffixID)
	end
	if name then
		enchantNames[enchantID] = name
	end
	return name
end

-- "%s (%d min)" -> "^(.-) %(%d+ min%)"
local tempPatterns
local function TempPatterns()
	if tempPatterns then
		return tempPatterns
	end
	tempPatterns = {}
	local formats = {
		ITEM_ENCHANT_TIME_LEFT_SEC,
		ITEM_ENCHANT_TIME_LEFT_MIN,
		ITEM_ENCHANT_TIME_LEFT_HOURS,
		ITEM_ENCHANT_TIME_LEFT_HOURS_P1,
		ITEM_ENCHANT_TIME_LEFT_DAYS,
		ITEM_ENCHANT_TIME_LEFT_DAYS_P1,
	}
	for i = 1, 6 do
		local fmt = formats[i]
		if fmt then
			local pattern = gsub(fmt, "([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
			pattern = gsub(pattern, "%%s", "(.-)")
			pattern = gsub(pattern, "%%d", "%%d+")
			tinsert(tempPatterns, "^" .. pattern)
		end
	end
	return tempPatterns
end

-- The weapon's own tooltip shows "Brilliant Wizard Oil (30 min)"; returns the name and the whole line
local function TempFromTooltip(unit, slotId)
	local tip = ScanTooltip()
	if not tip:SetInventoryItem(unit, slotId) then
		return
	end
	local patterns = TempPatterns()
	for i = 1, tip:NumLines() do
		local text = ScanLine(i)
		if text then
			for p = 1, getn(patterns) do
				local _, _, name = strfind(text, patterns[p])
				if name then
					return name, text
				end
			end
		end
	end
end

local function TimeLeft(ms)
	local seconds = floor(ms / 1000)
	if seconds >= 3600 then
		return format("%d hr %d min", floor(seconds / 3600), floor(math.mod(seconds, 3600) / 60))
	elseif seconds >= 60 then
		return format("%d min", ceil(seconds / 60))
	end
	return format("%d sec", seconds)
end

-- off hands held in the off hand, wands, thrown weapons and relics take no enchant
local function CanEnchant(slotId, enchantable, itemID)
	if not enchantable then
		return false
	end
	if slotId ~= OFFHAND and slotId ~= RANGED then
		return true
	end
	local _, _, _, _, _, subType, _, equipLoc = GetItemInfo(tonumber(itemID))
	if slotId == OFFHAND then
		return equipLoc ~= "INVTYPE_HOLDABLE"
	end
	if equipLoc == "INVTYPE_THROWN" or equipLoc == "INVTYPE_RELIC" then
		return false
	end
	return subType ~= "Wands" and subType ~= "Wand"
end

-- ---------------------------------------------------------------- one panel

local function StoreTemp(p, slotId, has, msLeft, charges, enchantID)
	local t = p.temp[slotId]
	has = has and true or false
	if enchantID == 0 then
		enchantID = nil
	end
	local changed = t.has ~= has or t.enchantID ~= enchantID
	t.has = has
	t.msLeft = msLeft or 0
	t.charges = charges or 0
	t.enchantID = enchantID
	if changed then
		t.name = nil
	end
	return changed
end

-- Reads the temporary enchants; true when one appeared, ran out or was replaced
local function ReadTempEnchants(p)
	local changed = false
	if not p.isPlayer then
		-- nothing reports another player's oils except, maybe, the item tooltip
		local unit = p.Unit()
		for slotId = MAINHAND, RANGED do
			local name, line
			if unit then
				name, line = TempFromTooltip(unit, slotId)
			end
			if StoreTemp(p, slotId, name, 0, 0) then changed = true end
			p.temp[slotId].name = line
		end
		return changed
	end
	if C_Item and C_Item.GetWeaponEnchantInfo then
		local ok, hasMain, mainMs, mainCharges, mainID, hasOff, offMs, offCharges, offID, hasRanged, rangedMs, rangedCharges, rangedID = pcall(C_Item.GetWeaponEnchantInfo)
		if ok then
			if StoreTemp(p, MAINHAND, hasMain, mainMs, mainCharges, mainID) then changed = true end
			if StoreTemp(p, OFFHAND, hasOff, offMs, offCharges, offID) then changed = true end
			if StoreTemp(p, RANGED, hasRanged, rangedMs, rangedCharges, rangedID) then changed = true end
			return changed
		end
	end
	local hasMain, mainMs, mainCharges, hasOff, offMs, offCharges = GetWeaponEnchantInfo()
	if StoreTemp(p, MAINHAND, hasMain, mainMs, mainCharges) then changed = true end
	if StoreTemp(p, OFFHAND, hasOff, offMs, offCharges) then changed = true end
	if StoreTemp(p, RANGED, nil) then changed = true end
	return changed
end

local function TempName(p, slotId)
	local t = p.temp[slotId]
	if not t.name then
		if t.enchantID then
			t.name = EnchantName(t.enchantID)
		end
		if not t.name then
			t.name = TempFromTooltip("player", slotId)
		end
	end
	return t.name or L.ENCHANT_TEMP_UNKNOWN
end

local function TempText(p, slotId)
	local t = p.temp[slotId]
	local text = TempName(p, slotId)
	if t.msLeft > 0 then
		text = text .. " (" .. TimeLeft(t.msLeft) .. ")"
	end
	if t.charges > 0 then
		if t.charges == 1 then
			text = text .. ", " .. format(ITEM_SPELL_CHARGES, t.charges)
		else
			text = text .. ", " .. format(ITEM_SPELL_CHARGES_P1, t.charges)
		end
	end
	return text
end

-- the icon the character / inspect frame shows for the slot, so the two always agree
local function SlotIcon(p, slotName, slotId)
	local icon = _G[p.slotPrefix .. slotName .. "IconTexture"]
	local texture = icon and icon:GetTexture()
	if texture and texture ~= "" then
		return texture
	end
	return GetInventoryItemTexture(p.Unit(), slotId)
end

local function Row_OnEnter()
	local unit = this.panel.Unit()
	if not unit then
		return
	end
	GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
	GameTooltip:SetInventoryItem(unit, this.slotId)
	GameTooltip:Show()
end

local function Row_OnLeave()
	GameTooltip:Hide()
end

local function Row_OnClick()
	local unit = this.panel.Unit()
	if unit and IsShiftKeyDown() and ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
		local link = GetInventoryItemLink(unit, this.slotId)
		if link then
			ChatFrameEditBox:Insert(link)
		end
	end
end

local function CreateLine(row, template)
	local line = row:CreateFontString(nil, "ARTWORK", template)
	line:SetWidth(TEXT_WIDTH)
	line:SetHeight(LINE_HEIGHT)
	line:SetJustifyH("LEFT")
	return line
end

local function CreateRow(p, i)
	local row = CreateFrame("Button", p.frame:GetName() .. "Row" .. i, p.frame)
	row.panel = p
	row:SetWidth(PANEL_WIDTH - 2 * PAD)

	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetWidth(ICON_SIZE)
	row.icon:SetHeight(ICON_SIZE)
	row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
	row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	row.name = CreateLine(row, "GameFontNormalSmall")
	row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 5, 0)
	row.enchant = CreateLine(row, "GameFontHighlightSmall")
	row.enchant:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, 0)
	row.temp = CreateLine(row, "GameFontHighlightSmall")
	row.temp:SetPoint("TOPLEFT", row.enchant, "BOTTOMLEFT", 0, 0)
	row.temp:SetTextColor(TEMP_COLOR.r, TEMP_COLOR.g, TEMP_COLOR.b)

	row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	row:SetScript("OnEnter", Row_OnEnter)
	row:SetScript("OnLeave", Row_OnLeave)
	row:SetScript("OnClick", Row_OnClick)

	p.rows[i] = row
	return row
end

local function Refresh(p)
	p.dirtyTimer = nil
	local unit = p.Unit()
	if not unit then
		return
	end

	ReadTempEnchants(p)
	if p.isPlayer then
		-- an oil swapped for another keeps "has" set, so read the names again
		for _, t in pairs(p.temp) do
			t.name = nil
		end
	end

	local shown, enchanted, enchantable = 0, 0, 0
	local y = -HEADER_HEIGHT
	local incomplete = false

	for i = 1, getn(SLOTS) do
		local slotId = GetInventorySlotInfo(SLOTS[i][1])
		local link = GetInventoryItemLink(unit, slotId)
		local _, _, itemID, enchantID, suffixID = strfind(link or "", "item:(%d+):(%d+):(%-?%d+)")
		if not itemID and GetInventoryItemTexture(unit, slotId) then
			-- the slot has an item the client hasn't got the details of yet
			incomplete = true
		end
		if itemID then
			enchantID = tonumber(enchantID)
			local canEnchant = CanEnchant(slotId, SLOTS[i][2], itemID)
			local hasTemp = p.temp[slotId] and p.temp[slotId].has

			if canEnchant or enchantID > 0 or hasTemp then
				shown = shown + 1
				local row = p.rows[shown] or CreateRow(p, shown)
				row.slotId = slotId

				row.icon:SetTexture(SlotIcon(p, SLOTS[i][1], slotId))

				-- item name in its quality color, taken from the link
				local _, _, color = strfind(link, "^(|c%x+)")
				local _, _, name = strfind(link, "%[(.-)%]")
				row.name:SetText((color or "") .. (name or "") .. FONT_COLOR_CODE_CLOSE)

				-- second line: the permanent enchant, or the temporary one when the item takes no enchant
				row.tempLine = row.temp
				local isBuckle = SLOTS[i][3]
				if enchantID > 0 then
					local enchantText = EnchantName(enchantID, itemID, suffixID)
					if not enchantText then
						incomplete = true
						enchantText = format(L.ENCHANT_UNKNOWN, enchantID)
					end
					if isBuckle then
						enchantText = format(L.ENCHANT_BUCKLE, enchantText)
					end
					row.enchant:SetText(enchantText)
					row.enchant:SetTextColor(ENCHANT_COLOR.r, ENCHANT_COLOR.g, ENCHANT_COLOR.b)
				elseif canEnchant then
					if isBuckle then
						row.enchant:SetText(L.ENCHANT_NO_BUCKLE)
					else
						row.enchant:SetText(L.ENCHANT_MISSING)
					end
					row.enchant:SetTextColor(MISSING_COLOR.r, MISSING_COLOR.g, MISSING_COLOR.b)
				else
					row.tempLine = row.enchant
					row.enchant:SetTextColor(TEMP_COLOR.r, TEMP_COLOR.g, TEMP_COLOR.b)
				end

				if canEnchant then
					enchantable = enchantable + 1
					if enchantID > 0 then
						enchanted = enchanted + 1
					end
				end

				local height = ICON_SIZE + 4
				if hasTemp then
					row.tempLine:SetText(TempText(p, slotId))
				end
				if hasTemp and row.tempLine == row.temp then
					row.temp:Show()
					height = 3 * LINE_HEIGHT + 4
				else
					row.temp:Hide()
				end

				row:SetHeight(height)
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", p.frame, "TOPLEFT", PAD, y)
				row:Show()
				y = y - height
			end
		end
	end

	for i = shown + 1, getn(p.rows) do
		p.rows[i]:Hide()
	end

	if shown == 0 then
		p.frame.empty:Show()
		y = y - LINE_HEIGHT - 4
	else
		p.frame.empty:Hide()
	end

	if enchantable > 0 then
		local color = GREEN_FONT_COLOR_CODE
		if enchanted < enchantable then
			color = RED_FONT_COLOR_CODE
		end
		p.frame.summary:SetText(color .. enchanted .. "/" .. enchantable .. FONT_COLOR_CODE_CLOSE)
	else
		p.frame.summary:SetText("")
	end

	p.frame:SetHeight(-y + PAD)

	if incomplete and p.retries < MAX_RETRIES then
		p.retries = p.retries + 1
		p.dirtyTimer = RETRY_DELAY
	end
end

-- only the time left and charges change while nothing is swapped
local function UpdateTempLines(p)
	if not p.Unit() then
		return
	end
	if ReadTempEnchants(p) then
		Refresh(p)
		return
	end
	for i = 1, getn(p.rows) do
		local row = p.rows[i]
		if row:IsShown() and p.temp[row.slotId] and p.temp[row.slotId].has then
			row.tempLine:SetText(TempText(p, row.slotId))
		end
	end
end

-- pfUI skins the character frame with its own backdrop; follow it when it is there
local function Style(p)
	if p.styled then
		return
	end
	p.styled = true

	local pfApi = pfUI and pfUI.api
	if p.host.backdrop and pfApi and pfApi.CreateBackdrop then
		pfApi.CreateBackdrop(p.frame, nil, nil, .75)
		if pfApi.CreateBackdropShadow then
			pfApi.CreateBackdropShadow(p.frame)
		end
		if pfApi.SkinCloseButton then
			pfApi.SkinCloseButton(p.frame.close, p.frame.backdrop or p.frame, -6, -6)
		end
		pfApi.CreateBackdrop(p.toggle)
	else
		p.frame:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 16,
			insets = { left = 4, right = 4, top = 4, bottom = 4 },
		})
		p.frame:SetBackdropColor(0, 0, 0, 0.9)
		p.frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
	end
end

local function Anchor(p)
	p.frame:ClearAllPoints()
	if p.host.backdrop then
		p.frame:SetPoint("TOPLEFT", p.host.backdrop, "TOPRIGHT", 3, 0)
	else
		-- the default frame art ends about 32 px inside the frame's right edge
		p.frame:SetPoint("TOPLEFT", p.host, "TOPRIGHT", -33, -13)
	end
end

local function SetPanelShown(p, show)
	BCSConfig[p.configKey] = show and true or false
	if show then
		p.frame:Show()
		p.toggle:SetChecked(1)
	else
		p.frame:Hide()
		p.toggle:SetChecked(nil)
	end
end

local function TogglePanel(p)
	SetPanelShown(p, not p.frame:IsShown())
end

-- spec: name, host (frame to sit beside), parent (tab frame), slotPrefix ("Character" /
-- "Inspect"), configKey, isPlayer, Unit() -> unit token or nil
local function CreatePanel(spec)
	local p = spec
	p.rows = {}
	p.temp = { [MAINHAND] = {}, [OFFHAND] = {}, [RANGED] = {} }
	p.tempTimer = 0
	p.retries = 0

	local frame = CreateFrame("Frame", p.name, p.parent)
	p.frame = frame
	frame:SetWidth(PANEL_WIDTH)
	frame:SetHeight(100)
	frame:EnableMouse(true)
	frame:Hide()

	frame.title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 2, -PAD - 2)
	frame.title:SetText(L.ENCHANTS_TITLE)

	frame.close = CreateFrame("Button", p.name .. "CloseButton", frame, "UIPanelCloseButton")
	frame.close:SetWidth(24)
	frame.close:SetHeight(24)
	frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	frame.close:SetScript("OnClick", function()
		SetPanelShown(p, false)
	end)

	frame.summary = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	frame.summary:SetPoint("RIGHT", frame.close, "LEFT", -2, 0)

	frame.empty = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	frame.empty:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 2, -HEADER_HEIGHT)
	frame.empty:SetText(L.ENCHANTS_NONE)
	frame.empty:Hide()

	frame:SetScript("OnShow", function()
		p.retries = 0
		Style(p)
		Anchor(p)
		Refresh(p)
	end)

	frame:SetScript("OnUpdate", function()
		if p.dirtyTimer then
			p.dirtyTimer = p.dirtyTimer - arg1
			if p.dirtyTimer <= 0 then
				Refresh(p)
			end
		end
		p.tempTimer = p.tempTimer - arg1
		if p.tempTimer <= 0 then
			p.tempTimer = 1
			UpdateTempLines(p)
		end
	end)

	frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
	frame:SetScript("OnEvent", function()
		-- wait a moment so a whole gear set swap gives one refresh
		if arg1 and arg1 == p.Unit() and frame:IsVisible() then
			p.retries = 0
			p.dirtyTimer = 0.2
		end
	end)

	local toggle = CreateFrame("CheckButton", p.name .. "ToggleButton", p.parent)
	p.toggle = toggle
	toggle:SetWidth(24)
	toggle:SetHeight(24)
	toggle:SetPoint("RIGHT", _G[p.slotPrefix .. "MainHandSlot"], "LEFT", -16, 0)
	toggle:SetNormalTexture("Interface\\Icons\\Trade_Engraving")
	toggle:GetNormalTexture():SetTexCoord(0.07, 0.93, 0.07, 0.93)
	toggle:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	toggle:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight", "ADD")
	toggle:SetScript("OnClick", function()
		TogglePanel(p)
	end)
	toggle:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		GameTooltip:SetText(L.ENCHANTS_BUTTON_TOOLTIP, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
		GameTooltip:AddLine(p.tooltip, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1)
		GameTooltip:Show()
	end)
	toggle:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	toggle:SetScript("OnShow", function()
		Style(p)
	end)

	-- shown unless it was closed before
	SetPanelShown(p, BCSConfig[p.configKey] ~= false)
	return p
end

local function CreatePlayerPanel()
	playerPanel = CreatePanel({
		name = "BCSEnchantFrame",
		host = CharacterFrame,
		parent = PaperDollFrame,
		slotPrefix = "Character",
		configKey = "EnchantPanel",
		tooltip = L.ENCHANTS_BUTTON_TOOLTIP_SUB,
		isPlayer = true,
		Unit = function() return "player" end,
	})
end

-- Blizzard_InspectUI loads on demand, the first time someone is inspected
local function CreateInspectPanel()
	if inspectPanel or not (InspectFrame and InspectPaperDollFrame and InspectMainHandSlot) then
		return
	end
	inspectPanel = CreatePanel({
		name = "BCSInspectEnchantFrame",
		host = InspectFrame,
		parent = InspectPaperDollFrame,
		slotPrefix = "Inspect",
		configKey = "InspectEnchantPanel",
		tooltip = L.ENCHANTS_INSPECT_TOOLTIP_SUB,
		isPlayer = false,
		Unit = function() return InspectFrame.unit end,
	})
end

function BCS:ToggleEnchantPanel()
	if playerPanel then
		TogglePanel(playerPanel)
	end
end

function BCS:ToggleInspectEnchantPanel()
	if inspectPanel then
		TogglePanel(inspectPanel)
	else
		-- not loaded yet: flip the saved choice, the panel reads it when it is built
		BCSConfig.InspectEnchantPanel = BCSConfig.InspectEnchantPanel == false
	end
end

-- the saved choices are only known once the addon's saved variables are in
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function()
	if arg1 == BCS.ADDON_NAME then
		addonLoaded = true
		CreatePlayerPanel()
		if IsAddOnLoaded("Blizzard_InspectUI") then
			CreateInspectPanel()
		end
	elseif arg1 == "Blizzard_InspectUI" and addonLoaded then
		CreateInspectPanel()
	end
	if inspectPanel then
		loader:UnregisterEvent("ADDON_LOADED")
	end
end)

SLASH_BETTERCHARACTERSTATS1 = "/bcs"
SlashCmdList["BETTERCHARACTERSTATS"] = function(msg)
	msg = strlower(msg or "")
	if msg == "enchants" or msg == "enchant" or msg == "e" then
		BCS:ToggleEnchantPanel()
		if playerPanel and playerPanel.frame:IsShown() and not PaperDollFrame:IsVisible() then
			ToggleCharacter("PaperDollFrame")
		end
	elseif msg == "inspect" or msg == "i" then
		BCS:ToggleInspectEnchantPanel()
		local on = BCSConfig.InspectEnchantPanel ~= false
		DEFAULT_CHAT_FRAME:AddMessage("|cffa0dbffEvenBetterCharacterStats|r " .. (on and L.ENCHANTS_INSPECT_ON or L.ENCHANTS_INSPECT_OFF))
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cffa0dbffEvenBetterCharacterStats|r " .. L.ENCHANTS_SLASH_HELP)
		DEFAULT_CHAT_FRAME:AddMessage("|cffa0dbffEvenBetterCharacterStats|r " .. L.ENCHANTS_SLASH_HELP_INSPECT)
	end
end
