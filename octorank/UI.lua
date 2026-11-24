if ORANK_SKIP then return end
--[[--------------------------------------------------------------------
	OctoRank - window. The look, the list and the ranking views are OctoRank's
	(its UI.lua), in a window with only the rankings and the logger.
----------------------------------------------------------------------]]

local W = OctoRank
local UI = {}
W.UI = UI

local floor = math.floor
local getn = table.getn
local FmtNum = W.FmtNum

local WIDTH, HEIGHT = 940, 562
local LEFTW = 230
local ROWH, NROWS = 16, 21
local FROWH, FROWS = 30, 14

------------------------------------------------------------------ the look

-- Flat dark panels and buttons with crisp 1-pixel borders. WHITE8X8 is a plain
-- white square in the client (Interface\Buttons\WHITE8X8.blp, checked in its files).
UI.FLAT = "Interface\\Buttons\\WHITE8X8"
UI.COL = {
	frame = { 0.035, 0.035, 0.045, 0.96 }, frameEdge = { 0.42, 0.34, 0.16, 1 },
	panel = { 0.07, 0.07, 0.085, 0.88 },   panelEdge = { 0.2, 0.2, 0.24, 1 },
	btn   = { 0.11, 0.11, 0.13, 0.96 },    btnEdge   = { 0.3, 0.3, 0.35, 1 },
	sel   = { 0.85, 0.66, 0.15, 1 },       hover     = { 1, 0.82, 0, 0.13 },
}
-- OctoRank's font: Fira Sans Condensed (SIL Open Font Licence, Fonts\OFL.txt), regular for
-- text, semibold for the gold titles and button labels, one size up from WoW's own
-- (it's narrower). Copies of the WoW font objects OctoRank uses; without CreateFont
-- on this client the WoW ones stay.
UI.FONT = "Interface\\AddOns\\pfUI\\fonts\\FiraSansCondensed-Regular.ttf"
UI.FONT_BOLD = "Interface\\AddOns\\pfUI\\fonts\\FiraSansCondensed-SemiBold.ttf"
UI.FONTS = {}
if CreateFont then
	for _, name in ipairs({ "GameFontNormal", "GameFontNormalSmall", "GameFontNormalLarge",
		"GameFontHighlight", "GameFontHighlightSmall", "GameFontDisable", "GameFontDisableSmall" }) do
		local base = getglobal(name)
		if base and base.GetFont then
			local _, size, flags = base:GetFont()
			local fo = CreateFont("OctoRank" .. name)
			fo:SetFont(string.find(name, "Normal") and UI.FONT_BOLD or UI.FONT, (size or 12) + 1, flags or "")
			if base.GetTextColor then
				local r, g, b = base:GetTextColor()
				fo:SetTextColor(r or 1, g or 1, b or 1)
			end
			UI.FONTS[name] = "OctoRank" .. name
		end
	end
end
-- smaller still, for a translated button label that doesn't fit (UI.Fit)
if CreateFont then
	for _, name in ipairs({ "GameFontNormalSmall", "GameFontHighlightSmall", "GameFontDisableSmall" }) do
		local base = getglobal(UI.FONTS[name] or name)
		if base and base.GetFont then
			local p, size, flags = base:GetFont()
			local fo = CreateFont("OctoRankTiny" .. name)
			fo:SetFont(p, (size or 11) - 1.5, flags or "")
			if base.GetTextColor then
				local r, g, b = base:GetTextColor()
				fo:SetTextColor(r or 1, g or 1, b or 1)
			end
			UI.FONTS["Tiny" .. name] = "OctoRankTiny" .. name
		end
	end
end
-- Fira Sans (Locale.lua swaps UI.FONT for Chinese / Korean; the flags' names keep Fira)
UI.FIRA = UI.FONT
-- every button in the window (UI.Fit shrinks a translated label that's too wide)
UI.allBtns = {}
-- a font template name / font object: OctoRank's copy when there is one
function UI.F(name) return UI.FONTS[name] or name end
function UI.FO(name) return getglobal(UI.FONTS[name] or name) end

-- a font string that shows what it's given in the player's language (fixed texts
-- are translated, anything else stays as it is)
function UI.SinkText(fs)
	local setText = fs.SetText
	fs.SetText = function(self, t) return setText(self, W.L(t)) end
end

function UI.Flat(fr, bg, edge)
	fr:SetBackdrop({ bgFile = UI.FLAT, edgeFile = UI.FLAT, tile = false, edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 } })
	fr:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
	fr:SetBackdropBorderColor(edge[1], edge[2], edge[3], edge[4])
end

-- a WoW panel button made flat: its red art hidden, a dark fill, a thin border,
-- a soft gold glow on hover (and while it's the selected tab)
function UI.Skin(b)
	if not b or b.wdiSkin then return b end
	b.wdiSkin = true
	b.wdiLevel = 1
	tinsert(UI.allBtns, b)
	-- labels are given in English; the button shows them in the player's language
	local setText = b.SetText
	b.SetText = function(self, t) return setText(self, W.L(t)) end
	local hidden = 0
	for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
		local t = b[get] and b[get](b)
		if t then t:SetAlpha(0); hidden = hidden + 1 end
	end
	if hidden == 0 then
		-- no Get...Texture on this client: take the art away instead
		pcall(b.SetNormalTexture, b, "")
		pcall(b.SetPushedTexture, b, "")
		pcall(b.SetDisabledTexture, b, "")
	end
	-- the hover glow: the client's own quest-log highlight (a soft gold band)
	b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
	local h = b.GetHighlightTexture and b:GetHighlightTexture()
	if h then
		h:ClearAllPoints()
		h:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
		h:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
		h:SetAlpha(0.55)
	end
	UI.Flat(b, UI.COL.btn, UI.COL.btnEdge)
	if b.SetTextFontObject then b:SetTextFontObject(UI.FO("GameFontNormal")) end
	if b.SetHighlightFontObject then b:SetHighlightFontObject(UI.FO("GameFontHighlight")) end
	if b.SetDisabledFontObject then b:SetDisabledFontObject(UI.FO("GameFontDisable")) end
	return b
end
-- the selected tab: a gold border and the glow kept on
function UI.SkinSelect(b, on)
	local e = on and UI.COL.sel or UI.COL.btnEdge
	if b.wdiSkin then b:SetBackdropBorderColor(e[1], e[2], e[3], e[4]) end
	if on then b:LockHighlight() else b:UnlockHighlight() end
end

------------------------------------------------------------------ list widget

local function CreateList(parent, nrows, rowh, width)
	local L = CreateFrame("Frame", nil, parent)
	L:SetWidth(width)
	L:SetHeight(nrows * rowh)
	L.nrows, L.rowh, L.offset, L.data, L.rows = nrows, rowh, 0, {}, {}
	local rowW = width - 18
	L.rowW = rowW

	local function wheel()
		L:Scroll(arg1 > 0 and -3 or 3)
	end
	L:EnableMouseWheel(true)
	L:SetScript("OnMouseWheel", wheel)

	for i = 1, nrows do
		local b = CreateFrame("Button", nil, L)
		b:SetWidth(rowW)
		b:SetHeight(rowh)
		b:SetPoint("TOPLEFT", L, "TOPLEFT", 0, -(i - 1) * rowh)
		b:EnableMouseWheel(true)
		b:SetScript("OnMouseWheel", wheel)
		b:RegisterForClicks("LeftButtonUp", "RightButtonUp")

		b.stripe = b:CreateTexture(nil, "BACKGROUND")
		b.stripe:SetAllPoints(b)

		-- a picture behind the row (d.art), e.g. a raid's loading screen on a run header
		b.art = b:CreateTexture(nil, "BACKGROUND")
		b.art:SetAllPoints(b)
		b.art:Hide()

		b.bar = b:CreateTexture(nil, "BORDER")
		b.bar:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
		b.bar:SetPoint("TOPLEFT", b, "TOPLEFT", 0, -1)
		b.bar:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 1)
		b.bar:Hide()

		local hl = b:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints(b)
		hl:SetTexture(1, 1, 1, 0.08)

		b.r = b:CreateFontString(nil, "OVERLAY", UI.F("GameFontHighlightSmall"))
		b.r:SetPoint("RIGHT", b, "RIGHT", -4, 0)
		b.r:SetJustifyH("RIGHT")

		b.l = b:CreateFontString(nil, "OVERLAY", UI.F("GameFontHighlightSmall"))
		b.l:SetPoint("LEFT", b, "LEFT", 4, 0)
		b.l:SetJustifyH("LEFT")
		b.l:SetHeight(rowh)

		b:SetScript("OnEnter", function() UI.RowEnter(this) end)
		b:SetScript("OnLeave", function() W.TT:Hide() end)
		b:SetScript("OnClick", function()
			local d = this.d
			if not (d and d.click) then return end
			-- x = where on the row it was clicked, so a row can tell its columns apart
			local cx = GetCursorPosition()
			local x = cx / this:GetEffectiveScale() - (this:GetLeft() or 0)
			d.click(d, arg1, x)
		end)
		L.rows[i] = b
	end

	local s = CreateFrame("Slider", nil, L)
	s:SetOrientation("VERTICAL")
	s:SetWidth(14)
	s:SetPoint("TOPRIGHT", L, "TOPRIGHT", 0, 0)
	s:SetPoint("BOTTOMRIGHT", L, "BOTTOMRIGHT", 0, 0)
	s:SetWidth(8)
	UI.Flat(s, { 0, 0, 0, 0.35 }, { 0.18, 0.18, 0.22, 1 })
	s:SetThumbTexture(UI.FLAT)
	local thumb = s:GetThumbTexture()
	if thumb then
		thumb:SetVertexColor(0.55, 0.5, 0.38, 0.9)
		thumb:SetWidth(6)
		thumb:SetHeight(24)
	end
	s:SetMinMaxValues(0, 0)
	s:SetValueStep(1)
	s:SetValue(0)
	s:SetScript("OnValueChanged", function()
		if L.updating then return end
		L.offset = floor(this:GetValue() + 0.5)
		L:Refresh()
	end)
	L.slider = s

	function L:MaxOffset()
		return math.max(0, getn(self.data) - self.nrows)
	end

	function L:SetData(data, keepOffset)
		self.data = data or {}
		if not keepOffset then self.offset = 0 end
		if self.offset > self:MaxOffset() then self.offset = self:MaxOffset() end
		self:Refresh()
	end

	function L:Scroll(delta)
		local o = self.offset + delta
		if o < 0 then o = 0 end
		if o > self:MaxOffset() then o = self:MaxOffset() end
		self.offset = o
		self:Refresh()
	end

	function L:Refresh()
		local max = self:MaxOffset()
		self.updating = true
		self.slider:SetMinMaxValues(0, max)
		self.slider:SetValue(self.offset)
		self.updating = false
		if max == 0 then self.slider:Hide() else self.slider:Show() end
		for i = 1, self.nrows do
			local b = self.rows[i]
			local d = self.data[self.offset + i]
			b.d = d
			if d then
				b.c = b.c or {}
				local ncols = d.cols and getn(d.cols) or 0
				if ncols > 0 then
					-- table row: every cell on a fixed column
					b.l:SetText("")
					b.r:SetText("")
					for j = 1, ncols do
						local c = d.cols[j]
						local fs = b.c[j]
						if not fs then
							fs = b:CreateFontString(nil, "OVERLAY", UI.F("GameFontHighlightSmall"))
							fs:SetHeight(self.rowh)
							b.c[j] = fs
						end
						fs:ClearAllPoints()
						fs:SetPoint("LEFT", b, "LEFT", c[1], 0)
						fs:SetWidth(c[2])
						fs:SetJustifyH(c[4] or "LEFT")
						fs:SetText(W.L(c[3] or ""))
						fs:Show()
					end
				else
					b.r:SetText(W.L(d.r or ""))
					b.l:SetText(W.L(d.l or ""))
					-- d.indent: start the text further in (fights under their raid run)
					b.l:ClearAllPoints()
					b.l:SetPoint("LEFT", b, "LEFT", 4 + (d.indent or 0), 0)
					local rw = (d.r and d.r ~= "") and (b.r:GetStringWidth() + 12) or 0
					b.l:SetWidth(self.rowW - rw - 8 - (d.indent or 0))
				end
				-- d.art = { path, alpha, left, right, top, bottom } (tex coords crop the picture)
				if d.art and d.art[1] then
					b.art:SetTexture(d.art[1])
					b.art:SetTexCoord(d.art[3] or 0, d.art[4] or 1, d.art[5] or 0, d.art[6] or 1)
					b.art:SetAlpha(d.art[2] or 0.35)
					b.art:Show()
				else
					b.art:Hide()
				end
				for j = ncols + 1, getn(b.c) do b.c[j]:Hide() end
				if d.bar then
					b.bar:SetWidth(math.max(1, self.rowW * math.min(1, d.bar)))
					b.bar:SetVertexColor(d.cr or 0.5, d.cg or 0.5, d.cb or 0.5, d.ba or 0.45)
					b.bar:Show()
				else
					b.bar:Hide()
				end
				if d.sel then
					b.stripe:SetTexture(0.9, 0.7, 0.1, 0.22)
				elseif d.head then
					b.stripe:SetTexture(0.25, 0.25, 0.32, 0.55)
				elseif math.mod(self.offset + i, 2) == 0 then
					b.stripe:SetTexture(1, 1, 1, 0.035)
				else
					b.stripe:SetTexture(0, 0, 0, 0)
				end
				b:Show()
			else
				b:Hide()
			end
		end
	end

	return L
end
function UI.RowEnter(b)
	local d = b.d
	if not d or not (d.tip or d.link) then return end
	W.TT:SetOwner(b, "ANCHOR_RIGHT")
	if d.link then
		-- an item: its real tooltip, then our lines under it
		W.TT:SetHyperlink(d.link)
		for i = 1, getn(d.tip or {}) do
			if type(d.tip[i]) == "string" and d.tip[i] ~= "" then W.TT:AddLine(W.LT(d.tip[i]), 0.9, 0.9, 0.9, 1) end
		end
		W.TT:Show()
		return
	end
	W.TT:SetText(W.LT(d.tipTitle or d.l or ""), 1, 0.82, 0, 1)
	for i = 1, getn(d.tip) do
		local line = d.tip[i]
		if type(line) == "table" then
			W.TT:AddDoubleLine(W.LT(line[1]), W.L(line[2]), 0.9, 0.9, 0.9, 1, 1, 1)
		elseif line and line ~= "" then
			W.TT:AddLine(W.LT(line), 0.9, 0.9, 0.9, 1)
		end
	end
	W.TT:Show()
end
------------------------------------------------------------------ frame
--
--  +-------------------------------------------------------------+
--  | OctoRank  [Raids][5-mans][Chronicle Logs]               [x] |  title bar
--  | N online                                              flags |
--  | +-----------+ +---------------------------------------------+ |
--  | | instances | | title / info / verdict over the raid's art  | |  header
--  | |  or       | +---------------------------------------------+ |
--  | | dungeons  | [Kill times][Full clears][Realm][Faction]       |  strip
--  | |           | +---------------------------------------------+ |
--  | |           | |  the board                                  | |
--  | | [share]   | +---------------------------------------------+ |
--  | +-----------+  hint                                           |
--  +-------------------------------------------------------------+

local PAD, GAP = 10, 8
local TOP = -58   -- under the title bar's two rows
local RX = PAD + LEFTW + GAP
local RW = WIDTH - RX - PAD
local HEADH = 78
local HEADW = RW - 24
local TABY = TOP - HEADH - 6
local TABH = 22
local CONTY = TABY - TABH - 4
local CONTH = HEIGHT + CONTY - 38
local BW = floor((LEFTW - 22) / 2)

local f = CreateFrame("Frame", "OctoRankFrame", UIParent)
f:SetWidth(WIDTH)
f:SetHeight(HEIGHT)
f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
f:SetFrameStrata("HIGH")
f:SetToplevel(true)
f:SetMovable(true)
f:EnableMouse(true)
f:SetClampedToScreen(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", function() this:StartMoving() end)
f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
UI.Flat(f, UI.COL.frame, UI.COL.frameEdge)
f:Hide()
UI.frame = f
tinsert(UISpecialFrames, "OctoRankFrame")

local titleBar = f:CreateTexture(nil, "ARTWORK")
titleBar:SetTexture(UI.FLAT)
if titleBar.SetGradientAlpha then
	titleBar:SetGradientAlpha("VERTICAL", 0.1, 0.08, 0.04, 0.9, 0.22, 0.17, 0.07, 0.9)
else
	titleBar:SetVertexColor(0.16, 0.13, 0.06, 0.9)
end
titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 5, -5)
titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
titleBar:SetHeight(24)
local titleLine = f:CreateTexture(nil, "ARTWORK")
titleLine:SetTexture(UI.FLAT)
titleLine:SetVertexColor(UI.COL.frameEdge[1], UI.COL.frameEdge[2], UI.COL.frameEdge[3], 0.8)
titleLine:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0)
titleLine:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, 0)
titleLine:SetHeight(1)
local statusBar = f:CreateTexture(nil, "ARTWORK")
statusBar:SetTexture(1, 1, 1, 0.03)
statusBar:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, -2)
statusBar:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, -2)
statusBar:SetHeight(20)

local title = f:CreateFontString(nil, "OVERLAY", UI.F("GameFontNormalLarge"))
title:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 4, -10)
title:SetText("|cff33ccffOcto|cffffd100Rank|r")

local version = f:CreateFontString(nil, "OVERLAY", UI.F("GameFontDisableSmall"))
version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 4, 1)
version:SetText("v" .. W.version)

-- how many users are online, under the title
local envText = f:CreateFontString(nil, "OVERLAY", UI.F("GameFontDisableSmall"))
envText:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 4, -38)
envText:SetJustifyH("LEFT")

local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)

if W.Locale then
	local Loc = W.Locale
	local n = getn(Loc.LANGS)
	local FW, FH, GAP = 18, 12, 4
	local bar = CreateFrame("Frame", nil, f)
	bar:SetWidth(n * (FW + GAP) - GAP)
	bar:SetHeight(FH + 4)
	bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -38)
	local label = bar:CreateFontString(nil, "OVERLAY")
	label:SetPoint("RIGHT", bar, "LEFT", -8, 0)
	label:SetJustifyH("RIGHT")
	UI.flagBar, UI.flagBtns = bar, {}
	local pending, pendingAt
	local function say(L, text, r, g, b)
		label:SetFont(L.font or UI.FIRA, 11, "")
		label:SetTextColor(r, g, b)
		label:SetText(text)
	end
	-- the chosen flag bright with a gold edge, the others dimmed; its name beside them
	function UI.FlagIdle()
		pending = nil
		for i = 1, getn(UI.flagBtns) do
			local b = UI.flagBtns[i]
			local on = (b.lang.code == Loc.lang)
			b.tex:SetAlpha(on and 1 or 0.45)
			if on then b.edge:SetTexture(UI.COL.sel[1], UI.COL.sel[2], UI.COL.sel[3], 1) else b.edge:SetTexture(0, 0, 0, 0.9) end
		end
		say(Loc.BY[Loc.lang], Loc.BY[Loc.lang].name, 0.55, 0.55, 0.55)
	end
	for i = 1, n do
		local b = CreateFrame("Button", nil, bar)
		b:SetWidth(FW)
		b:SetHeight(FH)
		b:SetPoint("LEFT", bar, "LEFT", (i - 1) * (FW + GAP), 2)
		b.edge = b:CreateTexture(nil, "BACKGROUND")
		b.edge:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1)
		b.edge:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
		b.tex = b:CreateTexture(nil, "ARTWORK")
		b.tex:SetAllPoints(b)
		b.tex:SetTexture(Loc.Flag(Loc.LANGS[i].code))
		b.lang = Loc.LANGS[i]
		b:SetScript("OnEnter", function()
			this.tex:SetAlpha(1)
			if not pending then say(this.lang, this.lang.name, 1, 1, 1) end
		end)
		b:SetScript("OnLeave", function() if not pending then UI.FlagIdle() end end)
		b:SetScript("OnClick", function()
			local code = this.lang.code
			if code == Loc.lang then UI.FlagIdle() return end
			if pending == code and GetTime() - pendingAt < 8 then Loc.Set(code) return end
			UI.FlagIdle()
			pending, pendingAt = code, GetTime()
			this.tex:SetAlpha(1)
			say(this.lang, this.lang.confirm, 1, 0.82, 0)
		end)
		UI.flagBtns[i] = b
	end
	-- a click that wasn't followed by a second one: back to normal after a while
	W:Every(1, function() if pending and GetTime() - pendingAt > 8 then UI.FlagIdle() end end)
	UI.FlagIdle()
end

local function panel(x, y, w, h)
	local p = CreateFrame("Frame", nil, f)
	p:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
	p:SetWidth(w)
	p:SetHeight(h)
	UI.Flat(p, UI.COL.panel, UI.COL.panelEdge)
	return p
end

local function button(parent, text, w, h)
	local b = UI.Skin(CreateFrame("Button", nil, parent, "UIPanelButtonTemplate"))
	b:SetWidth(w)
	b:SetHeight(h or 20)
	b:SetText(text)
	return b
end

-- tooltip on hover; lines may be a function returning lines
local function tooltip(b, titleText, lines, anchor)
	b:SetScript("OnEnter", function()
		W.TT:SetOwner(this, anchor or "ANCHOR_RIGHT")
		W.TT:SetText(W.L(titleText), 1, 0.82, 0)
		local l = (type(lines) == "function") and lines() or lines
		for i = 1, getn(l) do W.TT:AddLine(W.LT(l[i]), 0.9, 0.9, 0.9, 1) end
		W.TT:Show()
	end)
	b:SetScript("OnLeave", function() W.TT:Hide() end)
end

------------------------------------------------------------------ left: instances / dungeons

local left = panel(PAD, TOP, LEFTW, HEIGHT + TOP - PAD)

local leftHead = left:CreateFontString(nil, "OVERLAY", UI.F("GameFontNormal"))
leftHead:SetPoint("TOPLEFT", left, "TOPLEFT", 10, -9)

local leftCount = left:CreateFontString(nil, "OVERLAY", UI.F("GameFontDisableSmall"))
leftCount:SetPoint("TOPRIGHT", left, "TOPRIGHT", -10, -11)
leftCount:SetJustifyH("RIGHT")

local fightList = CreateList(left, FROWS, FROWH, LEFTW - 12)
fightList:SetPoint("TOPLEFT", left, "TOPLEFT", 6, -28)

local function smallText(b)
	if b.SetTextFontObject then b:SetTextFontObject(UI.FO("GameFontNormalSmall")) end
	if b.SetHighlightFontObject then b:SetHighlightFontObject(UI.FO("GameFontHighlightSmall")) end
	if b.SetDisabledFontObject then b:SetDisabledFontObject(UI.FO("GameFontDisableSmall")) end
	b.wdiLevel = 2
	return b
end

-- under the list, on the 5-mans: sharing and naming your group
local shareBtn = smallText(button(left, "Sharing: on", BW, 20))
shareBtn:SetPoint("BOTTOMLEFT", left, "BOTTOMLEFT", 8, 8)
shareBtn:SetScript("OnClick", function() W.Runs:Slash(W.Runs.On() and "off" or "on") end)
tooltip(shareBtn, "Share 5-man runs", function()
	return { W.LF("On: when your group finishes a dungeon, its run (group name, members\nand classes, time, deaths, boss splits) goes to every OctoRank user on\n%s, so the 5-man boards fill up across the realm.", W.Board.Realm()),
		"Off: your runs stay on your PC, and while you're in a group, nobody's\nOctoRank shares that group's run.",
		" ",
		W.LF("Now: %s", W.L(W.Runs.On() and "|cff33ff33on|r" or "|cffff9933off|r")) .. "   |cff888888(/orank 5man on|off)|r" }
end, "ANCHOR_TOP")

local nameBtn = smallText(button(left, "Name my group", BW, 20))
nameBtn:SetPoint("BOTTOMLEFT", left, "BOTTOMLEFT", 8 + BW + 6, 8)
nameBtn:SetScript("OnClick", function()
	local _, gk, n = W.Runs.Group()
	if not gk or n < 2 then W.Print("Be in a group to name it (or rename a group from one of its runs).") return end
	W:Prompt("Name your group (2-24 characters)\n|cff888888Remembered for these players; their runs show under it.|r",
		W.Runs:GroupName(gk) or "", function(text) W.Runs:Rename(gk, text) end)
end)
tooltip(nameBtn, "Name my group", { "Give the group you're in now a name for the 5-man boards.",
	"It's asked for when your group first finishes a dungeon; this renames it,\nand your group's runs are shared again under the new name." }, "ANCHOR_TOP")

------------------------------------------------------------------ right: header

local header = panel(RX, TOP, RW, HEADH)

local rTitle = header:CreateFontString(nil, "OVERLAY", UI.F("GameFontNormalLarge"))
rTitle:SetPoint("TOPLEFT", header, "TOPLEFT", 10, -9)
rTitle:SetWidth(HEADW)
rTitle:SetHeight(18)
rTitle:SetJustifyH("LEFT")

local rInfo = header:CreateFontString(nil, "OVERLAY", UI.F("GameFontHighlightSmall"))
rInfo:SetPoint("TOPLEFT", rTitle, "BOTTOMLEFT", 0, -3)
rInfo:SetWidth(HEADW)
rInfo:SetHeight(12)
rInfo:SetJustifyH("LEFT")

local rVerdict = header:CreateFontString(nil, "OVERLAY", UI.F("GameFontHighlightSmall"))
rVerdict:SetPoint("TOPLEFT", rInfo, "BOTTOMLEFT", 0, -5)
rVerdict:SetWidth(HEADW)
rVerdict:SetHeight(28)
rVerdict:SetJustifyH("LEFT")
rVerdict:SetJustifyV("TOP")

UI.headArt = header:CreateTexture(nil, "BACKGROUND")
UI.headArt:SetPoint("TOPLEFT", header, "TOPLEFT", 4, -4)
UI.headArt:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -4, 4)
UI.headArt:Hide()
UI.headShade = header:CreateTexture(nil, "BORDER")
UI.headShade:SetPoint("TOPLEFT", header, "TOPLEFT", 4, -4)
UI.headShade:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -4, 4)
UI.headShade:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
if UI.headShade.SetGradientAlpha then
	UI.headShade:SetGradientAlpha("HORIZONTAL", 0, 0, 0, 0.9, 0, 0, 0, 0.2)
else
	UI.headShade:SetVertexColor(0, 0, 0, 0.6)
end
UI.headShade:Hide()
-- the header shows the raid or dungeon it's about (nil: plain)
function UI.SetHeaderArt(zone)
	local a = zone and UI.ZoneArt(zone)
	if a then
		UI.headArt:SetTexture(a[1])
		UI.headArt:SetTexCoord(0, 1, 0.40, 0.58)
		UI.headArt:SetAlpha(0.6)
		UI.headArt:Show()
		UI.headShade:Show()
	else
		UI.headArt:Hide()
		UI.headShade:Hide()
	end
end

------------------------------------------------------------------ right: the board

local content = panel(RX, CONTY, RW, CONTH)
local mainList = CreateList(content, NROWS, ROWH, RW - 10)
mainList:SetPoint("TOPLEFT", content, "TOPLEFT", 5, -6)

local hintText = f:CreateFontString(nil, "OVERLAY", UI.F("GameFontDisableSmall"))
hintText:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", RX + 4, PAD + 6)
hintText:SetJustifyH("LEFT")
for _, fs in ipairs({ leftHead, leftCount, rTitle, rInfo, rVerdict, hintText }) do UI.SinkText(fs) end

------------------------------------------------------------------ the buttons

UI.mode = "rankings"
UI.rk = { view = "kills" }   -- rankings state: view, realm, faction, inst, boss

-- a row of buttons over the board
local function stripButtons(defs)
	local n = getn(defs)
	local w = floor((RW - (n - 1) * 4) / n)
	local list = {}
	for i = 1, n do
		local d = defs[i]
		local b = button(f, d[1], w, TABH)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", RX + (i - 1) * (w + 4), TABY)
		b:SetScript("OnClick", d[2])
		if d[3] then tooltip(b, d[1], d[3]) end
		b:Hide()
		list[i] = b
	end
	return list
end

local function cycleList(list, cur)
	for i = 1, getn(list) do
		if list[i] == cur then return list[i + 1] or list[1] end
	end
	return list[1]
end

UI.rankButtons = stripButtons({
	{ "Kill times", function()
		if UI.rk.five then UI.rk.fv = nil else UI.rk.view = "kills" end
		UI.rk.boss = nil; UI.rk.log = nil; UI.rk.run = nil
		UI:Refresh()
	  end },
	{ "Full clears", function()
		if UI.rk.five then UI.rk.fv = "mine" else UI.rk.view = "clears" end
		UI.rk.boss = nil; UI.rk.log = nil; UI.rk.run = nil
		UI:Refresh()
	  end },
	{ "Realm", function()
		local list = UI.rk.five and W.Runs:Realms() or W.Board:Realms()
		tinsert(list, 2, W.Board.ALL)   -- your realm, then all realms together, then the rest
		UI.rk.realm = cycleList(list, UI.rk.realm or W.Board.Realm())
		UI.rk.boss = nil; UI.rk.log = nil; UI.rk.run = nil
		UI:Refresh()
	  end, { "Your realm, then all realms together (compare against every guild), then each other realm." } },
	{ "Faction", function()
		local mine = W.Board.Faction()
		local other = (mine == "Horde") and "Alliance" or "Horde"
		UI.rk.faction = cycleList({ mine, "All", other }, UI.rk.faction or mine)
		UI:Refresh()
	  end, { "Your faction first, then everyone, then the other faction." } },
})

-- the first two say what they do in Raids or in 5-mans
do
	local function tip2(b, a, al, c, cl)
		b:SetScript("OnEnter", function()
			W.TT:SetOwner(this, "ANCHOR_RIGHT")
			W.TT:SetText(W.L(UI.rk.five and c or a), 1, 0.82, 0)
			local l = UI.rk.five and cl or al
			for i = 1, getn(l) do W.TT:AddLine(W.LT(l[i]), 0.9, 0.9, 0.9, 1) end
			W.TT:Show()
		end)
		b:SetScript("OnLeave", function() W.TT:Hide() end)
	end
	tip2(UI.rankButtons[1], "Kill times", { "Best kill time on every boss: you, your guild and the realm." },
		"Leaderboard", { "The fastest groups through this dungeon: first pull to the last boss.", "Click a group to see its run." })
	tip2(UI.rankButtons[2], "Full clears", { "Fastest full clear of the instance: first combat inside to the last boss.", "Optional bosses aren't required." },
		"Your runs", { "Every 5-man run you've finished, newest first (not only the bests)." })
end

UI.logButtons = stripButtons({
	{ "Start logging", function()
		if W.Logs:Enabled() then W.Logs:Stop() else W.Logs:Start() end
		UI:Refresh()
	  end, { "Start Chronicle combat logging, or stop it and save everything to the log file." } },
	{ "Save now", function() W.Logs:Save(); UI:Refresh() end,
	  { "Write everything logged so far to the log file (logging keeps going)." } },
	{ "Archive log", function() W.Logs:Archive(); UI:Refresh() end,
	  { "Save, then move the current log to a backup file and start a fresh one.", "Do this between raid lockouts." } },
	{ "|cffff5555Delete log|r", function() W.Logs:Delete() end,
	  { "Delete the current log file and anything unsaved (Chronicle asks first)." } },
})

-- Raids, 5-mans, Chronicle Logs: in the title bar
local MODEW = 112
UI.modeBtns = {}
do
	local defs = {
		{ "Raids", "rankings", nil, "Raid rankings: boss kill times and full clears of every guild,\nfrom Chronicle, through the maintainer's master feed." },
		{ "5-mans", "rankings", true, "5-man rankings: the fastest groups through each level-60 dungeon,\nfirst pull to the last boss. Click a group for its run:\nmembers, boss splits and deaths. Name your group when it finishes." },
		{ "Chronicle Logs", "logs", nil, "The Chronicle combat logger: start, save and upload your logs." },
	}
	for i = 1, getn(defs) do
		local d = defs[i]
		local b = button(f, d[1], MODEW, 20)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", RX + (i - 1) * (MODEW + 4), -7)
		b:SetScript("OnClick", function()
			UI.rk.five = d[3]
			UI:SetMode(d[2])
		end)
		tooltip(b, d[1], { d[4] }, "ANCHOR_BOTTOM")
		b.mode, b.five = d[2], d[3]
		UI.modeBtns[i] = b
	end
end
function UI.LayoutModes() end   -- (fixed places; Locale.lua's UI.Relabel calls this)

function UI:ApplyMode()
	local rank = (UI.mode == "rankings")
	for i = 1, getn(UI.modeBtns) do
		local b = UI.modeBtns[i]
		UI.SkinSelect(b, b.mode == UI.mode and (not rank or (b.five and true or false) == (UI.rk.five and true or false)))
	end
	for i = 1, getn(UI.rankButtons) do if rank then UI.rankButtons[i]:Show() else UI.rankButtons[i]:Hide() end end
	for i = 1, getn(UI.logButtons) do if rank then UI.logButtons[i]:Hide() else UI.logButtons[i]:Show() end end
	if rank and UI.rk.five then
		shareBtn:Show(); nameBtn:Show()
		shareBtn:SetText(W.LF("Sharing: %s", W.L(W.Runs.On() and "|cff33ff33on|r" or "|cffff9933off|r")))
	else
		shareBtn:Hide(); nameBtn:Hide()
	end
end

function UI:SetMode(mode)
	UI.mode = mode
	UI.rk.boss = nil; UI.rk.log = nil; UI.rk.run = nil
	if mode == "rankings" then W.Board:LoadChronicle() end
	UI:Open()
end

-- (OctoRank's sync bar is the maintainer's; the ranking views still ask for it)
function UI:UpdateSync() end

function UI.OnlineText()
	local B = W.Board
	if not (OctoRankDB and OctoRankDB.opts.shareBoard) then return "" end
	return "|cff888888" .. W.LF("%s online", B.OnlineCount()) .. "|r"
end

local function row(l, r, extra)
	local d = extra or {}
	d.l = l
	d.r = r
	return d
end

local function head(rows, text)
	tinsert(rows, { l = "|cffffd100" .. text .. "|r", head = true })
end

-- a paragraph that takes several rows (rows clip, they don't wrap): one text with
-- line breaks, so each language breaks its own lines
function UI.Para(rows, text, colour)
	for line in string.gfind(W.L(text), "[^\n]+") do tinsert(rows, { l = (colour or "") .. line .. (colour and "|r" or "") }) end
end
-- table rows: cells on fixed columns so everything lines up.
-- spec = { { width, "LEFT" | "RIGHT" | "CENTER" }, ... } (main list: ~570px)
local function cells(spec, values, extra)
	local d = extra or {}
	local c, x = {}, 4
	for i = 1, getn(spec) do
		c[i] = { x, spec[i][1], values[i] or "", spec[i][2] }
		x = x + spec[i][1] + 6
	end
	d.cols = c
	return d
end

-- the column titles row
local function colHead(rows, spec, titles)
	local v = {}
	for i = 1, getn(titles) do v[i] = "|cffffd100" .. titles[i] .. "|r" end
	tinsert(rows, cells(spec, v, { head = true }))
end
local C_TIME  = "|cffffffff"   -- times / numbers
local C_DIM   = "|cff888888"   -- dates, secondary text
local C_YOU   = "|cff66ccff"
local C_GUILD = "|cff33ff33"

-- /orank art); nil = none, the header is plain
-- names from the client's own file lists (8 Oct 2026; ZG, MC, BWL, Naxx, ES and Karazhan also
-- checked in game with /orank art). The first that loads is used; none = a plain header.
do   -- (a block: UI.lua is near Lua 5.0's 200 file-level locals)
local LS = "Interface\\Glues\\LoadingScreens\\"
UI.ART = {
	["Zul'Gurub"]               = { LS .. "LoadScreenZulGurub" },
	["Molten Core"]             = { LS .. "LoadScreenMoltenCore" },
	["Blackwing Lair"]          = { LS .. "LoadScreenBlackwingLair" },
	["Naxxramas"]               = { LS .. "LoadScreenNaxxramas" },
	["Emerald Sanctum"]         = { LS .. "LoadScreenEmeraldSanctum" },
	["Tower of Karazhan"]       = { LS .. "LoadScreenKarazhan" },
	["Lower Tower of Karazhan"] = { LS .. "LoadScreenKarazhan" },
	["Upper Tower of Karazhan"] = { LS .. "LoadScreenKarazhan" },
	["Onyxia's Lair"]           = { LS .. "LoadScreenRaid" },   -- vanilla gave her lair no picture of its own: the general raid one
	["Ruins of Ahn'Qiraj"]      = { LS .. "LoadScreenAhnQiraj20man" },
	["Ahn'Qiraj"]               = { LS .. "LoadScreenAhnQiraj40man" },
}
-- 5-man dungeons by "5:" .. key (Data.lua D.DUNGEONS names each one's loading screen;
-- the general dungeon one if the game hasn't got it)
for i = 1, getn(W.Data.DUNGEONS or {}) do
	local d = W.Data.DUNGEONS[i]
	UI.ART["5:" .. d.key] = { LS .. d.art, LS .. "LoadScreenDungeon" }
end
end
UI.artOK = {}
-- the first path the game can load; SetTexture says whether it could
function UI.FirstArt(paths)
	if not UI.artTest then UI.artTest = UIParent:CreateTexture(nil, "BACKGROUND") end
	for i = 1, getn(paths) do
		local p = paths[i]
		if UI.artOK[p] == nil then UI.artOK[p] = UI.artTest:SetTexture(p) and true or false end
		if UI.artOK[p] then return p end
	end
end
function UI.ZoneArt(zone)
	local paths = UI.ART[zone or ""]
	local p = paths and UI.FirstArt(paths)
	-- the middle band of the picture, faded: text stays readable over it
	if p then return { p, 0.4, 0, 1, 0.38, 0.62 } end
end

------------------------------------------------------------------ Rankings view

local lastModeKey
local FAC_COL = { Alliance = "|cff3399ff", Horde = "|cffff4444", Mixed = "|cffcc77ff" }
local FAC_TAG = { Alliance = "A", Horde = "H", Mixed = "M" }

local function facTag(fac)
	return (FAC_COL[fac] or "|cffaaaaaa") .. (FAC_TAG[fac] or "?") .. "|r"
end
local function rkRealm() return UI.rk.realm or W.Board.Realm() end
local function rkFaction() return UI.rk.faction or W.Board.Faction() end
local function instTitle(zone) return W.Data.instanceTitle[zone] or zone end

-- an instance's encounters: the clear list first, then optional ones
local function instBosses(zone)
	local list, have = {}, {}
	local need = W.Data.clears[zone] or {}
	for i = 1, getn(need) do
		tinsert(list, need[i])
		have[need[i]] = true
	end
	local extra = {}
	for enc, def in pairs(W.Data.encounters) do
		if def.zone == zone and not have[enc] then tinsert(extra, enc) end
	end
	-- bosses only Chronicle knows (Turtle's custom ones, Karazhan...)
	local chron = W.Board:ChronBosses(zone)
	for i = 1, getn(chron) do
		if not have[chron[i]] then tinsert(extra, chron[i]) end
	end
	table.sort(extra)
	for i = 1, getn(extra) do
		if not have[extra[i]] then
			tinsert(list, extra[i])
			have[extra[i]] = true
		end
	end
	return list
end

-- the raid scaling change (Data.lua D.SCALING): Rankings shows all times, with
-- the ones from before it marked *, or only the times since (the "+" boards)
function UI.RkKind(kind) return (UI.rk.era == "post") and (kind .. "+") or kind end
function UI.PreMark(rec) return (rec and W.Board.PrePatch(rec)) and " |cffff9933*|r" or "" end
function UI.PreTip(rec)
	if not (rec and W.Board.PrePatch(rec)) then return " " end
	return W.LF("|cffff9933* Set before %s.|r Raids under 30 now have it harder, so it isn't directly comparable.", W.L(W.Data.SCALING.name))
end

local RANK_COL = { "|cffffd100", "|cffd0d0d0", "|cffe08a3c" }   -- gold, silver, bronze
local FAC_BAR = { Alliance = { 0.2, 0.5, 1 }, Horde = { 0.9, 0.2, 0.2 }, Mixed = { 0.65, 0.35, 0.9 } }

local function rankTxt(i, suffix)
	return (RANK_COL[i] or "|cffaaaaaa") .. "#" .. i .. "|r" .. (suffix or "")
end

-- guild names in their faction's colour
local function facName(g, fac, mine)
	if mine then return "|cffffd100" .. g .. "|r" end
	return (FAC_COL[fac] or "|cffdddddd") .. g .. "|r"
end

local KILL_SPEC = { { 150, "LEFT" }, { 58, "RIGHT" }, { 58, "RIGHT" }, { 34, "RIGHT" }, { 62, "RIGHT" }, { 58, "RIGHT" }, { 104, "LEFT" } }
local LB_SPEC = { { 28, "RIGHT" }, { 14, "CENTER" }, { 176, "LEFT" }, { 86, "LEFT" }, { 50, "RIGHT" }, { 70, "RIGHT" }, { 104, "RIGHT" } }
local LB_SPEC_ALL = { { 28, "RIGHT" }, { 14, "CENTER" }, { 120, "LEFT" }, { 76, "LEFT" }, { 70, "LEFT" }, { 40, "RIGHT" }, { 70, "RIGHT" }, { 100, "RIGHT" } }

-- the ranked leaderboard for one boss or one instance's clears, every
-- time compared with your guild's ("1:38.6 faster" / "3:51.1 slower")
local function boardRows(rows, realm, faction, kind, key, myGuild)
	local B = W.Board
	local list = B:Board(realm, UI.RkKind(kind), key, faction)
	if getn(list) == 0 then
		if UI.rk.era == "post" then
			tinsert(rows, row(C_DIM .. W.LF("No times since %s yet (%s). Switch to All times at the top.", W.L(W.Data.SCALING.short), W.L(W.Data.SCALING.name)) .. "|r"))
			return
		end
		UI.Para(rows, "No times yet. Yours show up when you get one,\nor when the raid times arrive from the master feed.", C_DIM)
		return
	end
	local home = B.Realm()
	local mine = myGuild and B:GuildBest(home, UI.RkKind(kind), key, myGuild)
	local best = list[1][2].t
	local allRealms = (realm == B.ALL)
	local spec = allRealms and LB_SPEC_ALL or LB_SPEC
	if allRealms then
		colHead(rows, spec, { "#", "", "Guild", "Realm", "Date", "Raid", "Time", "vs your guild" })
	else
		colHead(rows, spec, { "#", "", "Guild", "Date", "Raid", "Time", "vs your guild" })
	end
	for i = 1, getn(list) do
		local g, rec, rlm = list[i][1], list[i][2], list[i][3]
		local isMine = (g == myGuild and rlm == home)
		local cmp = ""
		if isMine then
			cmp = "|cffffd100your guild|r"
		elseif mine then
			local d = rec.t - mine.t
			cmp = (d < 0) and ("|cffff5555" .. W.LF("%s faster", B.Fmt(-d)) .. "|r") or ("|cff33ff33" .. W.LF("%s slower", B.Fmt(d)) .. "|r")
		elseif i > 1 then
			cmp = C_DIM .. "+" .. B.Fmt(rec.t - best) .. "|r"
		end
		local vals = { rankTxt(i), facTag(rec.f), facName(g, rec.f, isMine) }
		if allRealms then tinsert(vals, C_DIM .. rlm .. "|r") end
		tinsert(vals, C_DIM .. B.Date(rec.d) .. "|r" .. UI.PreMark(rec))
		tinsert(vals, (rec.n and rec.n > 0) and (C_DIM .. rec.n .. "|r") or "")
		tinsert(vals, C_TIME .. B.Fmt(rec.t) .. "|r")
		tinsert(vals, cmp)
		local c = FAC_BAR[rec.f] or { 0.5, 0.5, 0.5 }
		tinsert(rows, cells(spec, vals,
			{ sel = isMine, bar = best / rec.t, ba = 0.16, cr = c[1], cg = c[2], cb = c[3], tipTitle = g,
			  tip = rec.chron and {
			          W.LF("|cffffd100From Chronicle|r (chronicleclassic.com) - %s", B.Date(rec.d)),
			          W.LF("Realm: %s   Faction: %s", B.RealmLabel(rlm), W.L(rec.f or "?")) .. ((rec.f == "Mixed") and (" " .. W.L("(cross-faction raid)")) or ""),
			          "|cff33ff33Click: open this raid - every boss kill, wipes, and the Chronicle link|r",
			          UI.PreTip(rec),
			      } or {
			          W.LF("Recorded %s", B.Date(rec.d)) .. (rec.by and (" " .. W.LF("by %s", rec.by)) or "") .. "   " .. W.LF("Realm: %s", rlm or "?"),
			          rec.net and "Shared by a OctoRank user (self-reported)" or "Recorded by your OctoRank",
			          "|cff888888Click: what's known about this time|r",
			          UI.PreTip(rec),
			      },
			  click = function()
				UI.rk.log = { slug = rec.slug, guild = g, realm = rlm, rec = rec, kind = kind, key = key }
				UI:Refresh()
			  end }))
	end
end

-- "your best" / "your guild" rows above a leaderboard
local PIN_SPEC = { { 180, "LEFT" }, { 70, "RIGHT" }, { 80, "LEFT" }, { 222, "LEFT" } }

local function pinRows(rows, realm, faction, kind, key, guild)
	local B = W.Board
	local mine = B:MyBest(kind, key)
	tinsert(rows, cells(PIN_SPEC, {
		C_YOU .. W.L((kind == "kills") and "Your best kill" or "Your best clear") .. "|r",
		mine and (C_TIME .. B.Fmt(mine.t) .. "|r" .. UI.PreMark(mine)) or (C_DIM .. "-|r"),
		"",
		mine and (C_DIM .. B.Date(mine.d) .. ((mine.g and mine.g ~= "") and ("  " .. W.LF("with %s", mine.g)) or "") .. "|r") or (C_DIM .. W.L("none yet") .. "|r"),
	}, mine and mine.slug and {
		tipTitle = "Your best", tip = { "Click: open that raid" },
		click = function() UI.rk.log = { slug = mine.slug, guild = mine.g or "?", realm = B.Realm(), rec = mine, kind = kind, key = key }; UI:Refresh() end } or nil))
	if guild then
		local ek = UI.RkKind(kind)
		local g = B:GuildBest(realm, ek, key, guild)
		local rank, of = B:Rank(realm, ek, key, guild, faction)
		local top = B:Board(realm, ek, key, faction)[1]
		local note = ""
		if g and top and top[2] ~= g then
			note = "|cffff7777" .. W.LF("%s behind", B.Fmt(g.t - top[2].t)) .. "|r " .. facName(top[1], top[2].f)
		elseif g and rank == 1 then
			note = "|cffffd100fastest on the board|r"
		end
		tinsert(rows, cells(PIN_SPEC, {
			C_GUILD .. guild .. "|r",
			g and (C_TIME .. B.Fmt(g.t) .. "|r" .. UI.PreMark(g)) or (C_DIM .. "-|r"),
			rank and (rankTxt(rank) .. C_DIM .. " " .. W.LF("of %s", of) .. "|r") or (g and (C_DIM .. B.Realm() .. "|r") or ""),
			g and note or (C_DIM .. W.L((kind == "kills") and "no kill yet" or "no clear yet") .. "|r"),
		}, g and {
			tipTitle = guild, tip = { "Click: open the raid this time came from" },
			click = function() UI.rk.log = { slug = g.slug, guild = guild, realm = B.Realm(), rec = g, kind = kind, key = key }; UI:Refresh() end } or nil))
	end
end


function UI:RankNavRows(realm)
	local B = W.Board
	local rows = {}
	local guild = B.MyGuild()
	local run = B:CurrentRun()
	local zones = B:Zones()
	local home = B.Realm()
	for i = 1, getn(zones) do
		local zone = zones[i]
		local me = B:MyBest("clears", zone)
		local ck = UI.RkKind("clears")
		local g = guild and B:GuildBest(home, ck, zone, guild)
		local top = B:Board(realm, ck, zone, "All")[1]
		local rank, of
		if g then rank, of = B:Rank(realm, ck, zone, guild, "All") end
		local right = ""
		if run and run.zone == zone then
			right = "|cff33ccffrun|r"
		elseif rank then
			right = rankTxt(rank, "|cff777777/" .. of .. "|r")
		end
		local nRivals = B.Rivals and getn(B:Rivals(zone)) or 0
		if nRivals > 0 then right = "|cffff5555! |r" .. right end
		local line2
		if g then
			line2 = "|cff33ff33" .. B.Fmt(g.t) .. "|r" .. UI.PreMark(g)
			if top and top[2] ~= g then line2 = line2 .. "  |cff888888#1 " .. B.Fmt(top[2].t) .. "|r" .. UI.PreMark(top[2]) end
		elseif top then
			line2 = "|cff888888#1 " .. B.Fmt(top[2].t) .. "|r" .. UI.PreMark(top[2]) .. "  |cff888888" .. top[1] .. "|r"
		else
			line2 = "|cff555555" .. W.L("no times yet") .. "|r"
		end
		tinsert(rows, row("|cffffffff" .. instTitle(zone) .. "|r\n" .. line2, right,
			{ sel = (UI.rk.inst == zone), art = UI.ZoneArt(zone),
			  bar = (g and top) and (top[2].t / g.t) or nil, ba = 0.28, cr = 0.15, cg = 0.75, cb = 0.3,
			  tipTitle = instTitle(zone),
			  tip = {
			      W.LF("Your guild: %s", g and (B.Fmt(g.t) .. (rank and ("  #" .. rank .. " " .. W.LF("of %s", of)) or ("  (" .. W.LF("on %s", home) .. ")"))) or W.L("no clear yet")),
			      W.LF("You: %s", me and B.Fmt(me.t) or W.L("no clear yet")),
			      "#1: " .. (top and (B.Fmt(top[2].t) .. "  " .. top[1]) or "-"),
			      (nRivals > 0) and ("|cffff5555! " .. W.LF((nRivals == 1) and "%s recent time beat ours here - see Rival watch" or "%s recent times beat ours here - see Rival watch", nRivals) .. "|r") or " ",
			      "|cff888888The green bar is how close your guild is to #1.|r",
			  },
			  click = function() UI.rk.inst = zone; UI.rk.boss = nil; UI.rk.log = nil; UI:Refresh() end }))
	end
	return rows
end

function UI:RankKillRows(realm, faction, zone)
	local B = W.Board
	local rows = {}
	local guild = B.MyGuild()
	local spec = KILL_SPEC
	colHead(rows, spec, { "Boss", "You", "Guild", "Rank", "Gap to #1", "#1", "Held by" })
	local bosses = instBosses(zone)
	for i = 1, getn(bosses) do
		local enc = bosses[i]
		local kk = UI.RkKind("kills")
		local top = B:Board(realm, kk, enc, faction)[1]
		local mine = B:MyBest("kills", enc)
		local g = guild and B:GuildBest(realm, kk, enc, guild)
		local rank = g and B:Rank(realm, kk, enc, guild, faction)
		local gap = ""
		if g and top and top[2] ~= g then
			gap = "|cffff7777+" .. B.Fmt(g.t - top[2].t) .. "|r"
		elseif g and rank == 1 then
			gap = "|cffffd100fastest|r"
		end
		local beaten = B.Rivals and B:Rivals(nil, "kills", enc)[1]
		tinsert(rows, cells(spec, {
				(beaten and "|cffff5555! |r" or "") .. "|cffffffff" .. enc .. "|r",
				mine and (C_YOU .. B.Fmt(mine.t) .. "|r" .. UI.PreMark(mine)) or (C_DIM .. "-|r"),
				g and (C_GUILD .. B.Fmt(g.t) .. "|r" .. UI.PreMark(g)) or (C_DIM .. "-|r"),
				rank and rankTxt(rank) or "",
				gap,
				top and (C_TIME .. B.Fmt(top[2].t) .. "|r" .. UI.PreMark(top[2])) or (C_DIM .. "-|r"),
				top and facName(top[1], top[2].f, top[1] == guild and top[3] == B.Realm()) or "",
			},
			{ click = function()
				-- Shift-click: straight to the #1's raid
				if IsShiftKeyDown() and top then
					UI.rk.log = { slug = top[2].slug, guild = top[1], realm = top[3], rec = top[2], kind = "kills", key = enc }
				else
					UI.rk.boss = enc
				end
				UI:Refresh()
			  end,
			  bar = (g and top) and (top[2].t / g.t) or nil, ba = 0.2, cr = 0.15, cg = 0.75, cb = 0.3,
			  tip = { "you = your best kill (OctoRank or Chronicle)",
			          "guild = your guild's best, its rank and how far behind #1 it is",
			          W.LF("#1 = the fastest guild (%s, %s)", W.L(realm), W.L(faction)),
			          beaten and ("|cffff5555! " .. B:RivalText(beaten) .. "|r") or " ",
			          W.LF("|cffff9933*|r = set before %s", W.L(W.Data.SCALING.name)),
			          "|cff888888Click: the full leaderboard (click a guild there to open its raid)|r",
			          "|cff888888Shift-click: open the #1 guild's raid|r" },
			  tipTitle = enc }))
	end
	return rows
end

function UI:RankBossRows(realm, faction, enc)
	local B = W.Board
	local rows = {}
	local guild = B.MyGuild()
	tinsert(rows, row("|cffffd100<< Back to all bosses|r", nil, { head = true, click = function() UI.rk.boss = nil; UI.rk.log = nil; UI:Refresh() end }))
	head(rows, W.LF("%s on %s", enc, W.L(realm)) .. "  |cff888888(" .. W.L(faction) .. ")|r")
	pinRows(rows, realm, faction, "kills", enc, guild)
	head(rows, "Leaderboard")
	boardRows(rows, realm, faction, "kills", enc, guild)
	return rows
end

function UI:RankClearRows(realm, faction, zone)
	local B = W.Board
	local rows = {}
	local guild = B.MyGuild()
	local need = W.Data.clears[zone] or {}
	head(rows, W.LF("Full clears of %s", instTitle(zone)))
	pinRows(rows, realm, faction, "clears", zone, guild)
	local run = B:CurrentRun()
	if run and run.zone == zone then
		local done = 0
		for i = 1, getn(need) do if run.kills[need[i]] then done = done + 1 end end
		tinsert(rows, cells(PIN_SPEC, {
			"|cff33ccffRun in progress|r",
			C_TIME .. B.Fmt(time() - run.start) .. "|r",
			C_TIME .. done .. "|r" .. C_DIM .. " / " .. getn(need) .. "|r",
			C_DIM .. "bosses down so far|r",
		}))
	end
	head(rows, "Leaderboard")
	boardRows(rows, realm, faction, "clears", zone, guild)
	head(rows, "Counts as a full clear")
	local parts = {}
	for i = 1, getn(need) do
		local killed = run and run.zone == zone and run.kills[need[i]]
		tinsert(parts, (killed and "|cff33ff33" or "|cffaaaaaa") .. need[i] .. "|r")
	end
	local line = {}
	for i = 1, getn(parts) do
		tinsert(line, parts[i])
		if getn(line) == 4 or i == getn(parts) then
			tinsert(rows, row(table.concat(line, ", ")))
			line = {}
		end
	end
	return rows
end

-- one guild's raid: every boss kill from its Chronicle log, against our times
local LOG_SPEC = { { 20, "RIGHT" }, { 168, "LEFT" }, { 64, "RIGHT" }, { 66, "RIGHT" }, { 40, "RIGHT" }, { 100, "RIGHT" }, { 70, "RIGHT" } }

local function clock(secs)
	if not secs then return "-" end
	secs = floor(secs)
	if secs >= 3600 then return string.format("%d:%02d:%02d", floor(secs / 3600), floor(math.mod(secs, 3600) / 60), math.mod(secs, 60)) end
	return string.format("%d:%02d", floor(secs / 60), math.mod(secs, 60))
end

-- who was in a raid, and one of: damage, healing, deaths (the download has this for the top raids)
function UI:RaidStatRows(rows, slug)
	local st = W.Board:RaidStats(slug)
	if not st then
		if slug then tinsert(rows, row(C_DIM .. W.L("Player details are in the download for each board's top raids. The rest is on Chronicle.") .. "|r")) end
		return
	end
	if UI.rk.statFor ~= slug then UI.rk.statFor, UI.rk.statBoss = slug, nil end   -- (a boss picked in another raid)
	local view = UI.rk.stat or "d"
	local LABEL = { d = "Damage", h = "Healing", x = "Deaths" }
	local function pick()
		if not UI.statMenu then UI.statMenu = CreateFrame("Frame", "OctoRankStatMenu", UIParent, "UIDropDownMenuTemplate") end
		UIDropDownMenu_Initialize(UI.statMenu, function()
			for _, k in ipairs({ "d", "h", "x" }) do
				local key = k
				UIDropDownMenu_AddButton({ text = W.L(LABEL[k]), checked = (view == k), func = function() UI.rk.stat = key; UI:Refresh() end })
			end
		end, "MENU")
		ToggleDropDownMenu(1, nil, UI.statMenu, "cursor")
	end
	tinsert(rows, row("|cffffd100" .. W.L("Players") .. "|r  " .. C_DIM .. "(" .. W.L("the whole raid, trash included; pets not counted") .. ")|r",
		"|cffffd100" .. W.L(LABEL[view]) .. "  v|r", { head = true, click = pick, tipTitle = LABEL[view], tip = { "Click to choose what to show" } }))
	local CL = W.Runs and W.Runs.CLASS_OF or {}
	if view == "x" then
		local class = {}
		for i = 1, getn(st.players) do class[st.players[i].n] = CL[st.players[i].c] end
		local DSPEC = { { 170, "LEFT" }, { 44, "RIGHT" }, { 130, "LEFT" }, { 200, "LEFT" } }
		if getn(st.deaths) == 0 then tinsert(rows, row(C_DIM .. W.L("none yet") .. "|r")) return end
		colHead(rows, DSPEC, { "Boss", "Time", "Player", "Killed by" })
		for i = 1, getn(st.deaths) do
			local d = st.deaths[i]
			if not UI.rk.statBoss or d.boss == UI.rk.statBoss then
			tinsert(rows, cells(DSPEC, { "|cffdddddd" .. d.boss .. "|r", C_DIM .. clock(d.at) .. "|r", W.CName(d.n, class[d.n]), "|cffff7777" .. d.by .. "|r" }))
			end
		end
		return
	end
	local list = {}
	for i = 1, getn(st.players) do tinsert(list, st.players[i]) end
	table.sort(list, function(a, b) return a[view] > b[view] end)
	local top = (list[1] and list[1][view] > 0) and list[1][view] or 1
	local PSPEC = { { 20, "RIGHT" }, { 170, "LEFT" }, { 90, "RIGHT" }, { 60, "RIGHT" } }
	colHead(rows, PSPEC, { "#", "Player", LABEL[view], "%" })
	local total = 0
	for i = 1, getn(list) do total = total + math.max(0, list[i][view]) end
	for i = 1, getn(list) do
		local p, v = list[i], list[i][view]
		tinsert(rows, cells(PSPEC, { C_DIM .. i .. ".|r", W.CName(p.n, CL[p.c]), C_TIME .. FmtNum(v) .. "|r",
			C_DIM .. ((total > 0) and floor(v / total * 100 + 0.5) or 0) .. "%|r" }, { bar = math.max(0, v) / top, ba = 0.2, cr = 0.2, cg = 0.6, cb = 1 }))
	end
end

function UI:RankLogRows()
	local B = W.Board
	local L = UI.rk.log
	local rec = L.rec or {}
	local rows = {}
	local back = UI.rk.boss and W.LF("<< Back to the %s leaderboard", UI.rk.boss) or W.L("<< Back to the leaderboard")
	tinsert(rows, row("|cffffd100" .. back .. "|r", nil, { head = true, click = function() UI.rk.log = nil; UI:Refresh() end }))
	local log = B:Log(L.slug)
	local guild = B.MyGuild()
	local home = B.Realm()
	local mine = (L.guild == guild and L.realm == home)
	local zone = (log and log.zone) or B:KeyZone(L.kind, L.key) or UI.rk.inst

	head(rows, facName(L.guild, rec.f, mine) .. "  |cffffffff" .. instTitle(zone) .. "|r  " .. C_DIM .. B.Date(rec.d) .. "|r")
	tinsert(rows, row("Realm", "|cffcc99ff" .. B.RealmLabel(L.realm) .. "|r"))
	tinsert(rows, row("Faction  /  raid size", "|cffffffff" .. W.L(rec.f or "?") .. "|r" .. C_DIM .. "  /  |r" .. C_TIME .. W.LF("%s|r players", (log and log.n) or rec.n or "?")))
	local place, of = B:Place(L.realm, L.kind, L.key, rec.t or 0)
	tinsert(rows, row((L.kind == "clears") and "Full clear" or W.LF("%s kill", L.key),
		C_TIME .. B.Fmt(rec.t) .. "|r  " .. rankTxt(place) .. C_DIM .. " " .. W.LF("of %s on %s", of, L.realm) .. "|r"))
	if L.slug then
		local url = B.LogURL(L.slug)
		tinsert(rows, row(W.L("Chronicle log") .. "  " .. C_DIM .. url .. "|r", "|cffffd100copy link  >|r",
			{ tipTitle = "Chronicle log", tip = { "Opens a box with the link selected: press Ctrl+C, then paste it in your browser." },
			  click = function() W:CopyLink(W.LF("Chronicle log for %s", L.guild), url) end }))
	end

	UI:RaidStatRows(rows, L.slug)
	if not log then
		head(rows, "Boss kills in this raid")
		if L.slug then
			if B.chronFeed and B.master and B:AskLog(L.slug) then
				tinsert(rows, row(C_DIM .. W.LF("Asked %s for this raid's boss list - it appears here in a few seconds.", B.master.name) .. "|r"))
			elseif B.chronFeed then
				tinsert(rows, row(C_DIM .. W.LF("This raid's boss list comes from %s - open it again while they're online.", B.chronFrom or W.L("the master")) .. "|r"))
			else
				tinsert(rows, row(C_DIM .. "This raid's boss list isn't here yet. It's asked for from the master feed while the master is online.|r"))
			end
		else
			tinsert(rows, row(C_DIM .. (rec.net and (W.L("Shared by a OctoRank user") .. (rec.by and (" (" .. rec.by .. ")") or "") .. W.L(" - there's no Chronicle log for it."))
				or W.L("Recorded by your OctoRank - there's no Chronicle log for it.")) .. "|r"))
		end
		return rows
	end

	local total, wipes = 0, 0
	for i = 1, getn(log.kills) do wipes = wipes + (log.kills[i].w or 0) end
	local last = log.kills[getn(log.kills)]
	head(rows, W.L("Boss kills in this raid") .. "  " .. C_DIM .. "(" .. W.LF("%s kills", getn(log.kills)) .. ((wipes > 0) and (", " .. W.LF("%s wipes", wipes)) or "")
		.. ((last and last.a) and (", " .. W.LF("%s start to last kill", clock(last.a))) or "") .. W.L(" - click a boss for its deaths") .. ")|r")
	colHead(rows, LOG_SPEC, { "#", "Boss", "Kill", "Into raid", "Wipes", mine and "vs our best" or "vs our guild", "Rank" })
	for i = 1, getn(log.kills) do
		local k = log.kills[i]
		local ours = guild and B:GuildBest(home, "kills", k.n, guild)
		local cmp = C_DIM .. "-|r"
		if ours and k.s then
			local d = k.s - ours.t
			if math.abs(d) < 0.05 then cmp = "|cffffd100our best|r"
			elseif d < 0 then cmp = "|cffff7777" .. W.LF("%s faster", B.Fmt(-d)) .. "|r"
			else cmp = C_GUILD .. W.LF("%s slower", B.Fmt(d)) .. "|r" end
		end
		local kp, kof = B:Place(log.realm or L.realm, "kills", k.n, k.s or 0)
		local isKey = (L.kind == "kills" and k.n == L.key)
		local boss = k.n
		tinsert(rows, cells(LOG_SPEC,
			{ C_DIM .. i .. ".|r", (isKey and "|cffffd100" or "|cffffffff") .. k.n .. "|r", C_TIME .. B.Fmt(k.s) .. "|r",
			  k.a and (C_DIM .. clock(k.a) .. "|r") or (C_DIM .. "-|r"),
			  (k.w and k.w > 0) and ("|cffff7777" .. k.w .. "|r") or (C_DIM .. "-|r"),
			  cmp, rankTxt(kp) .. C_DIM .. "/" .. kof .. "|r" },
			{ sel = isKey, tipTitle = k.n,
			  tip = { W.LF("Killed in %s", B.Fmt(k.s)) .. (k.a and (", " .. W.LF("%s into the raid", clock(k.a))) or "")
			            .. ((k.w and k.w > 0) and (" " .. W.LF((k.w == 1) and "after %s wipe" or "after %s wipes", k.w)) or ""),
			          ours and W.LF("Our guild's best: %s", B.Fmt(ours.t)) or "Our guild has no kill yet",
			          W.LF("That time would be #%s of %s on %s", kp, kof, log.realm or L.realm),
			          "|cff888888Click: deaths on this boss.  Shift-click: its leaderboard|r" },
			  click = function()
				  -- stays in this raid: its deaths on that boss. Shift-click: the boss's leaderboard
				  if IsShiftKeyDown() then UI.rk.log = nil; UI.rk.boss = boss
				  else UI.rk.stat = "x"; UI.rk.statBoss = (UI.rk.statBoss ~= boss) and boss or nil end
				  UI:Refresh()
			  end }))
	end
	return rows
end

function UI:RefreshRankings()
	if UI.rk.five and W.Runs then return UI:RefreshRuns() end
	local B = W.Board
	local realm, faction = rkRealm(), rkFaction()
	UI.rankButtons[1]:SetText("Kill times")
	UI.rankButtons[2]:SetText("Full clears")
	if not UI.rk.inst then
		UI.rk.inst = B.RunZone(GetRealZoneText()) or W.Data.clearOrder[1]
	end
	local zone = UI.rk.inst
	leftHead:SetText("Instances")
	leftCount:SetText(W.L(realm))
	fightList:SetData(UI:RankNavRows(realm), true)

	UI.rankButtons[3]:SetText(W.LF("Realm: %s", W.L(realm)))
	UI.rankButtons[4]:SetText(W.LF("Faction: %s", W.L(faction)))
	if UI.rk.view == "kills" then
		UI.SkinSelect(UI.rankButtons[1], true); UI.SkinSelect(UI.rankButtons[2], false)
	else
		UI.SkinSelect(UI.rankButtons[2], true); UI.SkinSelect(UI.rankButtons[1], false)
	end

	local guilds = {}
	local all = B:Board(realm, "clears", zone, "All")
	for i = 1, getn(all) do guilds[all[i][1]] = true end
	local bosses = instBosses(zone)
	for i = 1, getn(bosses) do
		all = B:Board(realm, "kills", bosses[i], "All")
		for j = 1, getn(all) do guilds[all[j][1]] = true end
	end
	local ng = 0
	for _ in pairs(guilds) do ng = ng + 1 end

	local c = B.chron
	local chron
	local st = B.SyncStatus and B:SyncStatus()
	if st and st.alive and st.state == "running" and B.CanMaster and B.CanMaster() then
		chron = "|cff66ccffChronicle syncing (see the bar, bottom left)|r"
	elseif c and c.synced and B.chronFeed then
		local mins = floor((time() - c.synced) / 60)
		chron = W.LF("Chronicle via %s (%s)", B.chronFrom or W.L("the master"), mins < 2 and W.L("just synced") or (mins < 120 and W.LF("%s min ago", mins) or W.LF("%s h ago", floor(mins / 60))))
	elseif c and c.synced then
		local mins = floor((time() - c.synced) / 60)
		chron = "Chronicle " .. ((c.status ~= "ok") and ("|cffffd100" .. (c.status or "") .. "|r") or (mins < 2 and W.L("just synced") or W.LF("%s min ago", mins)))
	else
		chron = W.L("|cffff9933Chronicle times: waiting for the master feed|r")
	end
	UI:UpdateSync()
	rTitle:SetText(instTitle(zone) .. "  |cff888888" .. W.L(UI.rk.view == "kills" and "kill times" or "full clears") .. "|r")
	UI.SetHeaderArt(zone)
	rInfo:SetText("|cffaaaaaa" .. W.L(realm) .. "   |   " .. W.L(faction) .. "   |   " .. W.LF("%s guild(s)", ng) .. "   |   " .. chron
		.. "   |   " .. W.LF("sharing %s", W.L(OctoRankDB.opts.shareBoard and "on" or "off")) .. "|r")
	local guild = B.MyGuild()
	local verdict
	if guild then
		local g = B:GuildBest(realm, "clears", zone, guild)
		if g then
			local rank, of = B:Rank(realm, "clears", zone, guild, "All")
			local top = B:Board(realm, "clears", zone, "All")[1]
			verdict = W.LF("|cff33ff33%s|r best clear |cffffffff%s|r", guild, B.Fmt(g.t)) .. "  "
			if rank then
				verdict = verdict .. rankTxt(rank) .. " " .. ((realm == B.ALL) and W.LF("of %s on all realms", of) or W.LF("of %s on %s", of, realm))
			else
				verdict = verdict .. "|cff888888(" .. W.LF("on %s", B.Realm()) .. ")|r"
			end
			if top and top[2] ~= g then
				verdict = verdict .. "  |cffff7777" .. W.LF("%s behind", B.Fmt(g.t - top[2].t)) .. "|r |cffffffff" .. top[1] .. "|r"
			end
		else
			verdict = W.LF("|cff33ff33%s|r has no full clear recorded here yet.", guild)
		end
	else
		verdict = W.L("You're not in a guild - your own times still count as personal bests.")
	end
	local pbc = B:MyBest("clears", zone)
	verdict = verdict .. "\n" .. W.L("|cff66ccffYour best clear:|r") .. " " .. (pbc and B.Fmt(pbc.t) or W.L("none yet"))
	rVerdict:SetText(verdict)

	local rows
	if UI.rk.log then rows = UI:RankLogRows()
	elseif UI.rk.boss then rows = UI:RankBossRows(realm, faction, UI.rk.boss)
	elseif UI.rk.view == "kills" then rows = UI:RankKillRows(realm, faction, zone)
	else rows = UI:RankClearRows(realm, faction, zone) end
	-- all times (marked * before the raid scaling change), or only the times since
	if not UI.rk.log then
		local S = W.Data.SCALING
		local post = (UI.rk.era == "post")
		local short, sname = W.L(S.short), W.L(S.name)
		tinsert(rows, 1, row(W.L("|cffffd100Times:|r") .. "  " .. (post and ("|cff888888" .. W.L("All times") .. "|r  |cffffffff< " .. W.LF("Since %s", short) .. " >|r")
				or ("|cffffffff< " .. W.L("All times") .. " >|r  |cff888888" .. W.LF("Since %s", short) .. "|r")),
			post and (C_DIM .. W.LF("only since %s", sname) .. "|r") or ("|cffff9933*|r " .. C_DIM .. W.LF("= before %s", sname) .. "|r"),
			{ tipTitle = W.LF("Raid scaling change, %s", short),
			  tip = { W.L(S.what), "Times set before it aren't directly comparable with times since.",
			          " ",
			          "|cffffd100All times|r: every best, the ones from before marked |cffff9933*|r",
			          W.LF("|cffffd100Since %s|r: only times set since the change, ranked on their own", short),
			          " ",
			          "|cff33ff33Click to switch.|r" },
			  click = function() UI.rk.era = (UI.rk.era ~= "post") and "post" or nil; UI:Refresh() end }))
	end
	-- no Chronicle times yet: say what's happening and how the sharing works, on top
	if not B.chron and not UI.rk.log then
		local top = UI:FeedPanel()
		for i = 1, getn(rows) do tinsert(top, rows[i]) end
		rows = top
	end

	hintText:SetText("Click a guild's time to open their raid.  Clears: first combat to the last boss.")
	hintText:Show()
	local key = "rk" .. realm .. faction .. zone .. UI.rk.view .. tostring(UI.rk.era) .. tostring(UI.rk.boss) .. (UI.rk.log and (UI.rk.log.guild .. tostring(UI.rk.log.slug)) or "")
	mainList:SetData(rows, key == lastModeKey)
	lastModeKey = key
end

------------------------------------------------------------------ Rankings > 5-mans
-- The same layout as the raids: dungeons on the left (with their loading
-- screens), the fastest groups on the right; click a group for its run.

do   -- (a block: UI.lua is near Lua 5.0's 200 file-level locals)
local RUN_SPEC = { { 24, "RIGHT" }, { 120, "LEFT" }, { 262, "LEFT" }, { 62, "LEFT" }, { 40, "RIGHT" }, { 52, "RIGHT" }, { 56, "RIGHT" } }
local RUN_SPEC_ALL = { { 24, "RIGHT" }, { 112, "LEFT" }, { 196, "LEFT" }, { 66, "LEFT" }, { 62, "LEFT" }, { 36, "RIGHT" }, { 52, "RIGHT" }, { 52, "RIGHT" } }
local MEM_SPEC = { { 20, "RIGHT" }, { 150, "LEFT" }, { 90, "LEFT" }, { 300, "LEFT" } }
local SPLIT_SPEC = { { 20, "RIGHT" }, { 230, "LEFT" }, { 70, "RIGHT" }, { 70, "RIGHT" }, { 130, "RIGHT" } }
local MINE_SPEC = { { 70, "LEFT" }, { 150, "LEFT" }, { 140, "LEFT" }, { 40, "RIGHT" }, { 56, "RIGHT" }, { 80, "RIGHT" } }

-- "Name, Name, Name" in class colours, and the members
local function memText(m)
	local list = W.Runs.Members(m) or {}
	local out = {}
	for i = 1, getn(list) do tinsert(out, W.CName(list[i].n, list[i].c)) end
	return table.concat(out, ", "), list
end

local function className(c)
	c = c or "?"
	return string.upper(string.sub(c, 1, 1)) .. string.lower(string.sub(c, 2))
end

-- the run in progress, if it's in this dungeon's zone
local function inProgress(dg)
	local r = W.Runs:Current()
	if r and r.zone and string.find(dg.title, r.zone, 1, true) then return r end
end

local function openRun(key, gk, rec, rlm)
	UI.rk.run = { key = key, gk = gk, rec = rec, realm = rlm }
	UI:Refresh()
end

function UI:RunNavRows(realm)
	local R, D = W.Runs, W.Data
	local rows = {}
	for i = 1, getn(D.DUNGEONS) do
		local dg = D.DUNGEONS[i]
		local key = dg.key
		local list = R:Board(realm, key, "All")
		local top = list[1]
		local mine = R:MyBest(key)
		local right = ""
		if inProgress(dg) then
			right = "|cff33ccffrun|r"
		elseif mine then
			local place, of = R:Place(realm, key, mine.t)
			right = rankTxt(place, "|cff777777/" .. of .. "|r")
		elseif getn(list) > 0 then
			right = "|cff777777" .. getn(list) .. "|r"
		end
		local line2
		if mine then
			line2 = C_GUILD .. R.Fmt(mine.t) .. "|r"
			if top and top[2].t < mine.t then line2 = line2 .. "  |cff888888#1 " .. R.Fmt(top[2].t) .. "|r" end
		elseif top then
			line2 = "|cff888888#1 " .. R.Fmt(top[2].t) .. "  " .. top[2].g .. "|r"
		else
			line2 = "|cff555555" .. W.L("no runs yet") .. "|r"
		end
		tinsert(rows, row("|cffffffff" .. dg.title .. "|r\n" .. line2, right,
			{ sel = (UI.rk.dg == key), art = UI.ZoneArt("5:" .. key),
			  bar = (mine and top) and (top[2].t / mine.t) or nil, ba = 0.28, cr = 0.15, cg = 0.75, cb = 0.3,
			  tipTitle = dg.title,
			  tip = {
			      W.LF("You: %s", mine and (R.Fmt(mine.t) .. "  " .. W.LF("with %s", mine.g)) or W.L("no run yet")),
			      "#1: " .. (top and (R.Fmt(top[2].t) .. "  " .. top[2].g) or "-"),
			      W.LF("Groups on the board: %s", getn(list)),
			      W.LF("|cff888888Ends when %s dies.|r", table.concat(dg.final, W.L(" or "))),
			  },
			  click = function() UI.rk.dg = key; UI.rk.run = nil; UI.rk.fv = nil; UI:Refresh() end }))
	end
	return rows
end

-- the leaderboard of one dungeon
function UI:RunBoardRows(realm, faction, key)
	local R, D = W.Runs, W.Data
	local dg = D.DUNGEON[key]
	local rows = {}
	local mine = R:MyBest(key)
	tinsert(rows, cells(PIN_SPEC, {
		C_YOU .. "Your best run|r",
		mine and (C_TIME .. R.Fmt(mine.t) .. "|r") or (C_DIM .. "-|r"),
		mine and (rankTxt((R:Place(realm, key, mine.t))) .. C_DIM .. " " .. W.LF("of %s", getn(R:Board(realm, key, "All"))) .. "|r") or "",
		mine and (C_DIM .. W.Board.Date(mine.d) .. "  " .. W.LF("with %s", "|r|cffffd100" .. mine.g) .. "|r") or (C_DIM .. W.L("none yet") .. "|r"),
	}, mine and { tipTitle = "Your best run", tip = { "Click: open that run" },
		click = function() openRun(key, mine.gk, mine, mine.realm or realm) end } or nil))
	local r = inProgress(dg)
	if r then
		local down = 0
		for i = 1, getn(dg.bosses) do if r.k[dg.bosses[i]] then down = down + 1 end end
		tinsert(rows, cells(PIN_SPEC, {
			"|cff33ccffRun in progress|r",
			C_TIME .. R.Fmt(time() - r.at) .. "|r",
			C_TIME .. down .. "|r" .. C_DIM .. " / " .. getn(dg.bosses) .. "|r",
			C_DIM .. W.LF((r.x == 1) and "bosses down, %s death" or "bosses down, %s deaths", r.x or 0) .. "|r",
		}))
	end
	head(rows, "Fastest groups")
	local list = R:Board(realm, key, faction)
	if getn(list) == 0 then
		UI.Para(rows, W.LF("No runs yet. A run counts from the first pull after zoning in to %s,\nfor groups of up to %s. Runs arrive from OctoRank users on the realm as they finish.", table.concat(dg.final, W.L(" or ")), dg.max or D.GROUP_MAX), C_DIM)
	else
		local all = (realm == W.Board.ALL)
		local spec = all and RUN_SPEC_ALL or RUN_SPEC
		if all then
			colHead(rows, spec, { "#", "Group", "Members", "Realm", "Date", "Dth", "Time", "vs #1" })
		else
			colHead(rows, spec, { "#", "Group", "Members", "Date", "Deaths", "Time", "vs #1" })
		end
		local best = list[1][2].t
		for i = 1, getn(list) do
			local gk, rec, rlm = list[i][1], list[i][2], list[i][3]
			local isMine = R.HasMember(rec)
			local mt = memText(rec.m)
			local vals = { rankTxt(i), (isMine and "|cffffd100" or ((rec.f == "Horde") and "|cffff7777" or "|cff77aaff")) .. rec.g .. "|r", mt }
			if all then tinsert(vals, C_DIM .. rlm .. "|r") end
			tinsert(vals, C_DIM .. W.Board.Date(rec.d) .. "|r")
			tinsert(vals, ((rec.x or 0) > 0) and ("|cffff7777" .. rec.x .. "|r") or (C_DIM .. "0|r"))
			tinsert(vals, C_TIME .. R.Fmt(rec.t) .. "|r")
			tinsert(vals, (i > 1) and (C_DIM .. "+" .. R.Fmt(rec.t - best) .. "|r") or "|cffffd100fastest|r")
			tinsert(rows, cells(spec, vals,
				{ sel = isMine, bar = best / rec.t, ba = 0.16, cr = 0.2, cg = 0.6, cb = 1, tipTitle = rec.g,
				  tip = { mt, " ",
				          W.LF((rec.x == 1) and "%s on %s, %s death, %s players" or "%s on %s, %s deaths, %s players", R.Fmt(rec.t), W.Board.Date(rec.d), rec.x or 0, rec.n or "?"),
				          rec.net and W.LF("Shared by %s (self-reported)", rec.by or W.L("a OctoRank user")) or "Recorded by your OctoRank",
				          "|cff33ff33Click: the whole run - members, boss splits, deaths|r" },
				  click = function() openRun(key, gk, rec, rlm) end }))
		end
	end
	head(rows, W.L("Bosses") .. "  " .. C_DIM .. W.LF("(the run ends when %s dies)", table.concat(dg.final, W.L(" or "))) .. "|r")
	local line = {}
	for i = 1, getn(dg.bosses) do
		local b = dg.bosses[i]
		local isFinal = D.DUNGEON_FINAL[b] == key
		local killed = r and r.k[b]
		tinsert(line, (isFinal and "|cffffd100" or (killed and "|cff33ff33" or "|cffaaaaaa")) .. b .. "|r")
		if getn(line) == 4 or i == getn(dg.bosses) then
			tinsert(rows, row(table.concat(line, ", ")))
			line = {}
		end
	end
	return rows
end

-- one run: the group, the time, every boss split
function UI:RunDetailRows()
	local R, D = W.Runs, W.Data
	local run = UI.rk.run
	local rec, key = run.rec, run.key
	local dg = D.DUNGEON[key]
	local rows = {}
	tinsert(rows, row("|cffffd100" .. W.L((UI.rk.fv == "mine") and "<< Back to your runs" or "<< Back to the leaderboard") .. "|r", nil,
		{ head = true, click = function() UI.rk.run = nil; UI:Refresh() end }))
	local isMine = R.HasMember(rec)
	local out = run.gk and R:Withdrawn(run.realm, key, run.gk, rec.t)
	head(rows, (isMine and "|cffffd100" or "|cffffffff") .. rec.g .. "|r  |cffffffff" .. dg.title .. "|r  " .. C_DIM .. W.Board.Date(rec.d) .. "|r")
	local place, of = R:Place(run.realm, key, rec.t)
	tinsert(rows, row(W.L("Time") .. "  " .. C_DIM .. W.LF("(first pull to %s)", table.concat(dg.final, " / ")) .. "|r",
		C_TIME .. R.Fmt(rec.t) .. "|r  " .. (out and ("|cffff7777" .. W.L("withdrawn") .. "|r")
			or (rankTxt(place) .. C_DIM .. " " .. W.LF("of %s on %s", of, run.realm) .. "|r"))))
	tinsert(rows, row("Deaths", ((rec.x or 0) > 0) and ("|cffff7777" .. rec.x .. "|r") or "|cff33ff33none|r"))
	tinsert(rows, row("Realm  /  faction", "|cffcc99ff" .. W.Board.RealmLabel(run.realm) .. "|r" .. C_DIM .. "  /  |r|cffffffff" .. W.L(rec.f or "?") .. "|r"))
	tinsert(rows, row("Recorded", C_DIM .. (rec.net and W.LF("shared by %s (self-reported)", rec.by or W.L("a OctoRank user"))
		or W.L("by your OctoRank")) .. (rec.priv and W.L(" - kept on your PC") or "") .. "|r"))
	if isMine and run.gk then
		tinsert(rows, row("Your group", "|cffffd100rename it  >|r",
			{ tipTitle = "Rename this group", tip = { "Renames it on every board and shares its runs again under the new name." },
			  click = function()
				W:Prompt(W.LF("New name for |cffffd100%s|r (2-24 characters)", rec.g), rec.g, function(text)
					if W.Runs:Rename(run.gk, text) then UI.rk.run = nil; UI:Refresh() end
				end)
			  end }))
	end
	-- a time the timer got wrong: a member takes it off the boards (asks first)
	if out then
		tinsert(rows, row("Withdrawn", "|cffff7777" .. W.LF("off the boards since %s, withdrawn by %s", W.Board.Date(out.at), W.L(out.by or "?")) .. "|r"))
	elseif isMine and run.gk then
		tinsert(rows, row("Wrong time?", "|cffff7777withdraw this run  >|r",
			{ tipTitle = "Withdraw this run", tip = { "Takes it off the 5-man boards: yours and those of the OctoRank users on your realm.",
				"Only a member of the group can. For a time the timer got wrong.", "Asks first. It can't be undone." },
			  click = function() R:AskWithdraw(run.realm, key, run.gk, rec) end }))
	end

	local _, list = memText(rec.m)
	head(rows, W.L("The group") .. "  " .. C_DIM .. "(" .. W.LF("%s players", getn(list)) .. ")|r")
	for i = 1, getn(list) do
		local p = list[i]
		tinsert(rows, cells(MEM_SPEC, { C_DIM .. i .. ".|r", W.CName(p.n, p.c) .. ((p.n == UnitName("player")) and (C_DIM .. "  " .. W.L("(you)") .. "|r") or ""),
			W.CName(W.L(className(p.c)), p.c), "" }))
	end

	local splits = R.Splits(rec, key)
	head(rows, "Boss splits")
	if getn(splits) == 0 then
		tinsert(rows, row(C_DIM .. "No splits for this run (they stay home when a run's message would be too long).|r"))
		return rows
	end
	-- against your best run here, boss by boss
	local myBest = R:MyBest(key)
	local mySplit = {}
	if myBest and myBest ~= rec then
		local ms = R.Splits(myBest, key)
		for i = 1, getn(ms) do mySplit[ms[i].name] = ms[i].at end
	end
	colHead(rows, SPLIT_SPEC, { "#", "Boss", "Into run", "Since last", next(mySplit) and "vs your best" or "" })
	local prev = 0
	for i = 1, getn(splits) do
		local s = splits[i]
		local cmp = ""
		local mine = mySplit[s.name]
		if mine then
			local d = s.at - mine
			cmp = (d < 0) and ("|cffff7777" .. W.LF("%s faster", R.Fmt(-d)) .. "|r") or (C_GUILD .. W.LF("%s slower", R.Fmt(d)) .. "|r")
		end
		local isFinal = D.DUNGEON_FINAL[s.name] == key
		tinsert(rows, cells(SPLIT_SPEC, { C_DIM .. i .. ".|r", (isFinal and "|cffffd100" or "|cffffffff") .. s.name .. "|r",
			C_TIME .. clock(s.at) .. "|r", C_DIM .. "+" .. clock(s.at - prev) .. "|r", cmp }))
		prev = s.at
	end
	return rows
end

-- every run you've finished, newest first
function UI:MyRunRows(realm)
	local R, D = W.Runs, W.Data
	local rows = {}
	local mine = R:MyRuns()
	head(rows, W.L("Your 5-man runs") .. "  " .. C_DIM .. W.LF("(%s, newest first - click one for its splits)", getn(mine)) .. "|r")
	if getn(mine) == 0 then
		tinsert(rows, row(C_DIM .. "None yet. Finish a level-60 dungeon (to its last boss) and it shows up here.|r"))
		return rows
	end
	colHead(rows, MINE_SPEC, { "Date", "Dungeon", "Group", "Deaths", "Time", "Rank" })
	for i = 1, getn(mine) do
		local e = mine[i]
		local dg = D.DUNGEON[e.k]
		if dg then
			local place, of = R:Place(e.realm or realm, e.k, e.t)
			tinsert(rows, cells(MINE_SPEC, { C_DIM .. W.LDate("%d %b %H:%M", e.d) .. "|r", "|cffffffff" .. dg.title .. "|r", "|cffffd100" .. e.g .. "|r",
				((e.x or 0) > 0) and ("|cffff7777" .. e.x .. "|r") or (C_DIM .. "0|r"), (e.wd and C_DIM or C_TIME) .. R.Fmt(e.t) .. "|r",
				e.wd and ("|cffff7777" .. W.L("withdrawn") .. "|r") or (rankTxt(place) .. C_DIM .. "/" .. of .. "|r") },
				{ sel = (e.k == UI.rk.dg), tipTitle = dg.title, tip = { (memText(e.m)), "|cff888888Click: the whole run|r" },
				  click = function() openRun(e.k, e.gk, e, e.realm or realm) end }))
		end
	end
	return rows
end


function UI:RefreshRuns()
	local R, D = W.Runs, W.Data
	local realm, faction = rkRealm(), rkFaction()
	if not D.DUNGEON[UI.rk.dg or ""] then
		-- the dungeon you're in, else the first
		UI.rk.dg = D.DUNGEONS[1].key
		local z = GetRealZoneText() or ""
		for i = 1, getn(D.DUNGEONS) do
			if z ~= "" and string.find(D.DUNGEONS[i].title, z, 1, true) then UI.rk.dg = D.DUNGEONS[i].key break end
		end
	end
	local key = UI.rk.dg
	local dg = D.DUNGEON[key]
	leftHead:SetText("5-mans")
	leftCount:SetText(W.L(realm))
	fightList:SetData(UI:RunNavRows(realm), true)

	UI.rankButtons[1]:SetText("Leaderboard")
	UI.rankButtons[2]:SetText("Your runs")
	UI.rankButtons[3]:SetText(W.LF("Realm: %s", W.L(realm)))
	UI.rankButtons[4]:SetText(W.LF("Faction: %s", W.L(faction)))
	UI.SkinSelect(UI.rankButtons[1], UI.rk.fv ~= "mine")
	UI.SkinSelect(UI.rankButtons[2], UI.rk.fv == "mine")
	UI:UpdateSync()

	local list = R:Board(realm, key, faction)
	rTitle:SetText(dg.title .. "  |cff888888" .. W.L((UI.rk.fv == "mine") and "your runs" or "5-man runs") .. "|r")
	UI.SetHeaderArt("5:" .. key)
	rInfo:SetText("|cffaaaaaa" .. W.L(realm) .. "   |   " .. W.L(faction) .. "   |   " .. W.LF("%s group(s)", getn(list)) .. "   |   "
		.. W.LF("sharing 5-man runs %s", W.L((R.On() and OctoRankDB.opts.shareBoard) and "on" or "|cffff9933off|r")) .. "|r")
	local mine = R:MyBest(key)
	local verdict
	if mine then
		local place, of = R:Place(realm, key, mine.t)
		verdict = W.LF("|cff66ccffYour best:|r |cffffffff%s|r with |cffffd100%s|r", R.Fmt(mine.t), mine.g) .. "  " .. rankTxt(place) .. " " .. W.LF("of %s", of)
		local top = R:Board(realm, key, "All")[1]
		if top and top[2].t < mine.t then verdict = verdict .. "  |cffff7777" .. W.LF("%s behind", R.Fmt(mine.t - top[2].t)) .. "|r |cffffffff" .. top[2].g .. "|r" end
	else
		verdict = W.L("|cff66ccffYour best:|r none yet.")
	end
	verdict = verdict .. "\n|cff888888" .. W.LF("First pull after zoning in to %s, up to %s players.", table.concat(dg.final, " / "), dg.max or D.GROUP_MAX) .. "|r"
	rVerdict:SetText(verdict)

	local rows
	if UI.rk.run then rows = UI:RunDetailRows()
	elseif UI.rk.fv == "mine" then rows = UI:MyRunRows(realm)
	else rows = UI:RunBoardRows(realm, faction, key) end
	hintText:SetText("Click a group for its run.  A run: first pull after zoning in to the last boss.  Name your group when it finishes.")
	hintText:Show()
	local k = "r5" .. realm .. faction .. key .. tostring(UI.rk.fv) .. (UI.rk.run and (tostring(UI.rk.run.gk) .. UI.rk.run.key) or "")
	mainList:SetData(rows, k == lastModeKey)
	lastModeKey = k
end
end
------------------------------------------------------------------ Logs view

local function onOff(v) return W.L(v and "|cff33ff33on|r" or "|cff888888off|r") end

function UI:LogNavRows()
	local rows = {}
	local hist = W.Logs.history
	if getn(hist) == 0 then
		tinsert(rows, row("|cff888888Nothing saved yet\nthis session.|r"))
	end
	for i = 1, math.min(12, getn(hist)) do
		local h = hist[i]
		tinsert(rows, row(h[3] .. "\n|cff888888" .. h[1] .. "|r", W.LF("|cffffffff%s|r lines", FmtNum(h[2]))))
	end
	return rows
end

function UI:LogRows()
	local L = W.Logs
	local rows = {}
	if not L:Available() then

		head(rows, "The Chronicle logger didn't load")
		tinsert(rows, row("OctoRank has Chronicle's logger (|cffffd100ChronicleCompanion|r) built in - it writes the logs you upload to chronicleclassic.com."))
		tinsert(rows, row(W.LF("Its files are missing or didn't load: %s, then %s.", W.L(W.SYNC_HOWTO), W.L(W.RESTART_HINT))))
		return rows
	end
	local opts = OctoRankDB.opts
	local file = L:File() or "?"
	local src = L:Source()
	head(rows, "Status")
	tinsert(rows, row("Chronicle logging", L:Enabled() and "|cff33ff33ON|r" or "|cffff5555OFF|r"))
	if src == "builtin" then
		tinsert(rows, row("Logger", W.L("|cff33ff33built into OctoRank|r") .. "  |cffffffffv" .. (L:Version() or "?") .. "|r"
			.. (WDI_CHRON_DATE and ("  |cff888888" .. WDI_CHRON_DATE .. "|r") or ""),
			{ tipTitle = "Built-in Chronicle logger", tip = {
				"ChronicleCompanion by Emyrk, from github.com/Emyrk/ChronicleCompanion.",
				"Ships with OctoRank at the version the maintainer tested; newer ones come with OctoRank updates.",
				(OctoRankDB.opts.chronUse == true) and "You said yes to logging raids." or "Logs nothing until you say yes (asked in your first raid, or Start logging).",
				W.LF("Commit: %s", string.sub(WDI_CHRON_COMMIT or "?", 1, 7)) } }))
	elseif WDI_CHRON_VERSION then
		tinsert(rows, row("Logger", W.L("|cffffd100ChronicleCompanion addon|r") .. "  |cffffffffv" .. (L:Version() or "?") .. "|r  |cff888888" .. W.LF("built-in v%s takes over after /reload", WDI_CHRON_VERSION) .. "|r"))
	else
		tinsert(rows, row("Logger", W.L("|cffffd100ChronicleCompanion addon|r") .. "  |cffffffffv" .. (L:Version() or "?") .. "|r"))
	end
	tinsert(rows, row("Log file", (L.target and L.cur and ("|cffffd100" .. W.LF("log %d", L.cur.n) .. "|r  ") or "")
		.. "|cffffffff" .. W.L("WoW folder") .. "\\CustomData\\" .. file .. "|r"))
	tinsert(rows, row("Lines logged but not saved yet", "|cffffffff" .. FmtNum(L:Unsaved()) .. "|r"))
	tinsert(rows, row("Saved by OctoRank this session",
		W.LF("|cffffffff%s|r lines", FmtNum(L.savedLines)) .. (L.lastSave and ("  |cff888888" .. W.LF("last %s", L.lastSave) .. "|r") or "")))
	tinsert(rows, row("File access (Nampower)", WriteCustomFile and "|cff33ff33ok|r" or "|cffff5555missing - logs can't be written|r"))

	head(rows, W.L("Automatic logging") .. "  |cff888888" .. W.L("(click to switch on / off)") .. "|r")
	local function toggle(label, value, fn, tip)
		tinsert(rows, row(label, onOff(value), { click = function() fn(); UI:Refresh() end, tip = { tip }, tipTitle = label }))
	end
	toggle("Start logging when I enter a raid", L:Setting("autoEnableInRaid"),
		function() L:ToggleSetting("autoEnableInRaid") end, "Chronicle setting.")
	toggle("Start logging when I enter a dungeon", L:Setting("autoEnableInDungeon"),
		function() L:ToggleSetting("autoEnableInDungeon") end, "Chronicle setting.")
	toggle("Save after every combat", L:Setting("autoCombatSave"),
		function() L:ToggleSetting("autoCombatSave") end, "Chronicle setting: writes the log to disk whenever you leave combat.")
	toggle("Start logging when a boss is pulled", opts.chronStartOnPull,
		function() opts.chronStartOnPull = not opts.chronStartOnPull end, "OctoRank: a safety net in case logging was off when the boss was pulled.")
	toggle("Save after every boss fight", opts.chronSaveOnFight,
		function() opts.chronSaveOnFight = not opts.chronSaveOnFight end, "OctoRank: writes the log to disk after every kill or wipe.")
	toggle("One log file per realm", L:Setting("includeRealmInFilename"),
		function() L:ToggleSetting("includeRealmInFilename") end, "Chronicle setting: adds the realm to the file name.")
	if src == "builtin" then
		toggle("Own numbered file for every raid and 5-man run", opts.chronSplit ~= false,
			function() opts.chronSplit = (opts.chronSplit == false) end,
			"OctoRank: raids and 5-mans never mix, and entering a raid tells you its file. Off: everything goes into one file, Chronicle's way.")
	end

	head(rows, "Uploading to Chronicle")
	tinsert(rows, row("1.  After the raid click |cffffd100Stop & save|r (or |cffffd100Save now|r)."))
	tinsert(rows, row("2.  Open |cffffd100chronicleclassic.com|r and click |cffffd100Upload|r."))
	-- (a Log Format left on "WoW Forever" fails with "no realm info found in log (format v22-cleu)")
	tinsert(rows, row("     Server |cffffd100OctoWoW|r, Log Format |cffffd1001.12a · ChronicleCompanion|r, not WoW Forever (it then says |cffffffffUploading as 1.12a-cc-addon|r)."))
	tinsert(rows, row(W.LF("3.  Choose |cffffffffWoW folder\\CustomData\\%s|r.", file)))
	if L:SplitOn() then
		tinsert(rows, row("4.  Every raid and 5-man run has its own numbered file (below), so nothing needs archiving."))
		local recent = L:Recent()
		if table.getn(recent) > 0 then
			head(rows, "Your log files")
			for i = 1, math.min(10, table.getn(recent)) do
				local r = recent[i]
				tinsert(rows, row("|cffffd100" .. string.format("%03d", r.n) .. "|r  " .. (r.zone or "?") .. "  |cff888888" .. W.LDate("%d %b %H:%M", r.at or 0) .. "|r",
					"|cffffffff" .. (r.file or "?") .. "|r  |cff888888" .. W.LF("%s lines", FmtNum(r.lines or 0)) .. "|r"))
			end
		end
	else
		tinsert(rows, row("4.  Before your next lockout, |cffffd100Archive log|r or |cffffd100Delete log|r so raids don't mix."))
	end
	tinsert(rows, row("|cff888888Addons can't reach the internet, so the upload itself is done on the website.|r"))
	return rows
end

function UI:RefreshLogs()
	local L = W.Logs
	leftHead:SetText("Saved this session")
	leftCount:SetText("")
	fightList:SetData(UI:LogNavRows(), true)
	UI.logButtons[1]:SetText(L:Enabled() and "|cffff5555Stop & save|r" or "|cff33ff33Start logging|r")
	if L:Available() then
		rTitle:SetText(W.L("Chronicle Logs") .. "  " .. W.L(L:Enabled() and "|cff33ff33ON - logging|r" or "|cffff5555OFF|r"))
		rInfo:SetText("|cffaaaaaaCustomData\\" .. (L:File() or "?") .. "   |   " .. W.LF("%s unsaved lines", FmtNum(L:Unsaved())) .. "|r")
	else
		rTitle:SetText("Chronicle Logs  |cffff5555Chronicle logger not found|r")
		rInfo:SetText("|cffaaaaaaIts files are missing: download OctoRank again|r")
	end
	rVerdict:SetText("Upload the log at |cffffd100chronicleclassic.com|r after your raid.\n|cff888888Addons can't reach the internet, so uploading happens on the website.|r")
	hintText:SetText("Click an option to switch it on or off.  Hover the buttons for details.")
	hintText:Show()
	local key = "logs"
	mainList:SetData(UI:LogRows(), key == lastModeKey)
	lastModeKey = key
end
------------------------------------------------------------------ Rankings: waiting for the raid times

-- shown on Rankings while there are no Chronicle times yet: where they'll
-- come from, how far along it is, and what the sharing does and doesn't do
function UI:FeedPanel()
	local B = W.Board
	local rows = {}
	local o = OctoRankDB.opts
	local realm = B.Realm()
	local names = B.MasterList and B.MasterList() or {}
	local who = (getn(names) > 0) and table.concat(names, " / ") or nil
	-- (the maintainer has dozens of characters: a few names and how many more)
	if getn(names) > 4 then who = names[1] .. " / " .. names[2] .. " / " .. names[3] .. " " .. W.LF("+%d more", getn(names) - 3) end
	local fs = B.FeedStatus and B:FeedStatus()
	local m = B.master and (GetTime() - B.master.at) < 150 and B.master or nil

	head(rows, "Getting every guild's raid times")
	if not o.shareBoard then
		tinsert(rows, row("|cffff9933Sharing is off|r, so the raid times can't reach you.", C_DIM .. "/orank share on|r"))
	elseif o.noFeed then
		tinsert(rows, row("|cffff9933You switched the feed off|r (/orank feed off).", C_DIM .. "/orank feed on|r"))
	elseif fs and not fs.master and fs.total > 0 then
		-- seconds per message as they're really arriving (the master paces itself for the server's chat limit)
		local per = (fs.t0 and fs.got >= 10) and ((GetTime() - fs.t0) / fs.got) or 1.6
		local left = math.max(1, floor((fs.total - fs.got) * per / 60 + 0.5))
		tinsert(rows, row(W.LF("|cff66ccffReceiving them from %s|r - the boards fill in when it's done.", fs.from or "?"),
			C_TIME .. floor(fs.got / fs.total * 100) .. "%|r  " .. C_DIM .. W.LF("about %s min left", left) .. "|r",
			{ bar = fs.got / fs.total, cr = 0.2, cg = 0.55, cb = 1, ba = 0.45 }))
		tinsert(rows, row(C_DIM .. W.LF("%s of %s messages. Keep playing as normal - it comes in quietly in the background.", fs.got, fs.total) .. "|r"))
	elseif m then
		tinsert(rows, row(W.LF("|cff33ff33%s is online|r with times from %s. Your OctoRank is asking for them.", m.name, B.Ago(m.synced)),
			C_DIM .. "starts within a minute|r"))
		tinsert(rows, row(C_DIM .. "The first copy takes about 15 minutes; after that only changes are sent (seconds). If a full copy went out just before you logged in, the next one can take up to half an hour.|r"))
	elseif who then
		tinsert(rows, row(W.LF("Waiting for |cffffd100%s|r to come online on %s.", who, realm),
			C_DIM .. "nothing to do|r"))
		tinsert(rows, row(C_DIM .. "The raid times come from their OctoRank. When they log in, yours notices within a minute and they arrive by themselves.|r"))
	else
		tinsert(rows, row(W.LF("No master on %s yet, so the raid times can't arrive in game here.", realm),
			C_DIM .. "or run the helper|r"))
	end

	head(rows, "How the sharing works")
	local function info(a, b) tinsert(rows, row("|cffffd100" .. W.L(a) .. "|r  " .. C_DIM .. W.L(b) .. "|r")) end
	info("What arrives:", "guild names, raid and boss names, kill and clear times, dates, raid sizes and Chronicle log links.")
	info("", "Nothing about any player - no characters, no gear, nothing personal.")
	info("What you send:", "only a short request (\"send me what's new since ...\"). Nothing about you, your character or your PC.")
	info("Who from:", W.LF("only %s. Anyone else trying to send times is ignored.", who or W.L("the OctoRank maintainer's characters")))
	info("Where it goes:", "saved with your OctoRank settings on your PC, so Rankings is full next login, even when they're offline.")
	info("Never posted:", "other guilds' names never go into chat by themselves; anything you post shows you the text first.")
	info("Live:", "after the first copy, new times arrive within minutes of being uploaded to Chronicle, while they're online.")
	info("Your choice:", "/orank feed off ignores the feed. Nothing to install or run either way.")
	head(rows, "Times recorded in game")
	return rows
end
-- The window is built in English while the files load; the language is only known
-- at ADDON_LOADED (Locale.lua), which calls this: every label and button gets its
-- translation, the mode buttons are laid out again and the flags show the language.
function UI.Relabel()
	local function walk(fr)
		local kind = fr.GetObjectType and fr:GetObjectType()
		if kind == "Button" and fr.GetText then
			local t = fr:GetText()
			if t then fr:SetText(W.L(t)) end
		end
		local regions = { fr:GetRegions() }
		for i = 1, getn(regions) do
			local r = regions[i]
			if r.GetObjectType and r:GetObjectType() == "FontString" then
				local t = r:GetText()
				if t then r:SetText(W.L(t)) end
			end
		end
		local kids = { fr:GetChildren() }
		for i = 1, getn(kids) do walk(kids[i]) end
	end
	walk(f)
	UI.LayoutModes()
	UI.FlagIdle()
end

-- a translated label wider than its button: the next smaller font, then the
-- smallest (English labels fit; this only runs for the other languages)
UI.FIT = {
	{ "GameFontNormal", "GameFontHighlight", "GameFontDisable" },
	{ "GameFontNormalSmall", "GameFontHighlightSmall", "GameFontDisableSmall" },
	{ "TinyGameFontNormalSmall", "TinyGameFontHighlightSmall", "TinyGameFontDisableSmall" },
}
function UI.Fit(b)
	if not (b.GetTextWidth and b.SetTextFontObject) then return end
	local room = b:GetWidth() - 8
	for lv = b.wdiLevel or 1, 3 do
		local set = UI.FIT[lv]
		local fo = UI.FONTS[set[1]] and getglobal(UI.FONTS[set[1]])
		if fo then
			b:SetTextFontObject(fo)
			if b.SetHighlightFontObject then b:SetHighlightFontObject(UI.FO(set[2])) end
			if b.SetDisabledFontObject then b:SetDisabledFontObject(UI.FO(set[3])) end
			if (b:GetTextWidth() or 0) <= room then return end
		end
	end
end
function UI.FitAll()
	if not f:IsVisible() then return end
	for i = 1, getn(UI.allBtns) do
		local b = UI.allBtns[i]
		if b:IsVisible() then UI.Fit(b) end
	end
end


------------------------------------------------------------------ refresh

function UI:Refresh()
	if not f:IsVisible() then return end
	envText:SetText(UI.OnlineText())
	UI.SetHeaderArt(nil)   -- each view sets its own
	UI:ApplyMode()
	if UI.mode == "logs" then UI:RefreshLogs() else UI:RefreshRankings() end
	if W.Locale and W.Locale.lang ~= "en" then UI.FitAll() end
end

function UI:Toggle()
	if f:IsVisible() then
		f:Hide()
	else
		if UI.mode == "rankings" then W.Board:LoadChronicle() end
		f:Show()
	end
end

function UI:Open()
	if not f:IsVisible() then f:Show() else UI:Refresh() end
end

-- the logs view counts unsaved lines while it's open
W:Every(1.5, function()
	if f:IsVisible() and UI.mode == "logs" then UI:Refresh() end
end)

------------------------------------------------------------------ minimap button

-- where it sits: a direction (no trig, its units depend on the client build), dragged by hand
local ICONS = { "Interface\\Icons\\INV_Misc_PocketWatch_01", "Interface\\Icons\\INV_Misc_Note_01", "Interface\\Icons\\INV_Misc_QuestionMark" }
local mini
local function placeMini()
	local o = OctoRankDB.opts
	local x, y = o.miniX or -0.7, o.miniY or -0.7
	mini:ClearAllPoints()
	mini:SetPoint("CENTER", Minimap, "CENTER", x * 80, y * 80)
end
local function dragMini()
	local mx, my = Minimap:GetCenter()
	local cx, cy = GetCursorPosition()
	local s = Minimap:GetEffectiveScale()
	local dx, dy = cx / s - mx, cy / s - my
	local d = math.sqrt(dx * dx + dy * dy)
	if d < 1 then return end
	OctoRankDB.opts.miniX, OctoRankDB.opts.miniY = dx / d, dy / d
	placeMini()
end
function UI.UpdateMinimap()
	if OctoRankDB.opts.noMinimap then
		if mini then mini:Hide() end
		return
	end
	if not mini then
		mini = CreateFrame("Button", "OctoRankMinimapButton", Minimap)
		mini:SetWidth(32)
		mini:SetHeight(32)
		mini:SetFrameStrata("MEDIUM")
		mini:SetToplevel(true)
		mini:RegisterForDrag("LeftButton")
		mini:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		local icon = mini:CreateTexture(nil, "BACKGROUND")
		icon:SetWidth(20)
		icon:SetHeight(20)
		icon:SetPoint("CENTER", mini, "CENTER", 0, 0)
		icon:SetTexture(UI.FirstArt(ICONS))
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		local border = mini:CreateTexture(nil, "OVERLAY")
		border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
		border:SetWidth(54)
		border:SetHeight(54)
		border:SetPoint("TOPLEFT", mini, "TOPLEFT", 0, 0)
		mini:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
		mini:SetScript("OnClick", function()
			if arg1 == "RightButton" then UI.rk.five = true; UI:SetMode("rankings") else UI:Toggle() end
		end)
		mini:SetScript("OnDragStart", function() this:SetScript("OnUpdate", dragMini) end)
		mini:SetScript("OnDragStop", function() this:SetScript("OnUpdate", nil) end)
		mini:SetScript("OnEnter", function()
			W.TT:SetOwner(this, "ANCHOR_LEFT")
			W.TT:SetText("|cff33ccffOcto|cffffd100Rank|r")
			W.TT:AddLine("Click: the rankings   Right-click: 5-mans   Drag: move", 0.9, 0.9, 0.9)
			W.TT:AddLine("/orank minimap off hides this button", 0.6, 0.6, 0.6)
			W.TT:Show()
		end)
		mini:SetScript("OnLeave", function() W.TT:Hide() end)
	end
	placeMini()
	mini:Show()
end
W:On("ADDON_LOADED", function(name) if name == "pfUI" then UI.UpdateMinimap() end end)
