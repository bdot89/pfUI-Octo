if ORANK_SKIP then return end
--[[--------------------------------------------------------------------
	OctoRank - core: what WhoDidIt's ranking files need from their addon,
	and nothing more: events, timers, saved variables, the group roster,
	a text box, the slash command.

	Board.lua, Dungeons.lua, RunTimer.lua, Logs.lua, Data.lua, Locale.lua and
	Chronicle\ are WhoDidIt's own files (tools\Sync-FromWhoDidIt.ps1).
----------------------------------------------------------------------]]

OctoRank = {}
local W = OctoRank

W.version = "1.0.0"
W.env = {}

local floor = math.floor
local getn = table.getn

-- so clients don't all wait the same time before asking on the channel
if math.randomseed then pcall(math.randomseed, time() + floor(math.mod(GetTime() * 1000, 100000))) end

------------------------------------------------------------------ output / formatting

function W.Print(msg)
	msg = tostring(msg)
	if W.L then msg = W.L(msg) end
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffOcto|cffffd100Rank|r: " .. msg)
end

-- (Locale.lua replaces these)
function W.L(s) return s end
function W.LF(fmt, ...) return string.format(fmt, unpack(arg)) end
function W.LT(s) return s end
function W.LTLines(s) return s end
function W.LDate(fmt, t) return date(fmt, t) end
function W.ShowPopup(which, a1, a2) return StaticPopup_Show(which, a1, a2) end
W.TT = GameTooltip

function W.FmtNum(n)
	n = n or 0
	if n >= 1000000 then return string.format("%.2fM", n / 1000000) end
	if n >= 10000 then return string.format("%.1fk", n / 1000) end
	return tostring(floor(n + 0.5))
end

local FALLBACK_COLORS = {
	WARRIOR = { r = 0.78, g = 0.61, b = 0.43 }, ROGUE   = { r = 1.00, g = 0.96, b = 0.41 },
	MAGE    = { r = 0.41, g = 0.80, b = 0.94 }, WARLOCK = { r = 0.58, g = 0.51, b = 0.79 },
	HUNTER  = { r = 0.67, g = 0.83, b = 0.45 }, PRIEST  = { r = 1.00, g = 1.00, b = 1.00 },
	DRUID   = { r = 1.00, g = 0.49, b = 0.04 }, SHAMAN  = { r = 0.00, g = 0.44, b = 0.87 },
	PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
}
function W.CName(name, class)
	local c = (RAID_CLASS_COLORS and class and RAID_CLASS_COLORS[class]) or (class and FALLBACK_COLORS[class])
	local r, g, b = 0.7, 0.7, 0.7
	if c then r, g, b = c.r, c.g, c.b end
	return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, name or "?")
end

------------------------------------------------------------------ what the ranking files call, that OctoRank doesn't do

-- OctoRank posts nothing to chat by itself
W.Shout = { PALETTE = {} }
function W.Shout:Channel() return "SELF" end
function W.Shout:ChannelLabel() return "you" end
function W:Send() end
function W:ConfirmSend() end
function W:AskHandover() end
function W.CanLead() return true end

------------------------------------------------------------------ "type a value" popup

StaticPopupDialogs["OCTORANK_PROMPT"] = {
	text = "%s",
	button1 = ACCEPT, button2 = CANCEL,
	hasEditBox = 1, maxLetters = 48,
	OnShow = function()
		W.popup = this
		local eb = getglobal(this:GetName() .. "EditBox")
		eb:SetText(W.prompt and W.prompt.default or "")
		eb:HighlightText()
		eb:SetFocus()
	end,
	OnAccept = function()
		local eb = W.popup and getglobal(W.popup:GetName() .. "EditBox")
		local p = W.prompt
		W.prompt = nil
		if eb and p then p.fn(eb:GetText()) end
	end,
	EditBoxOnEnterPressed = function()
		local p = W.prompt
		W.prompt = nil
		local text = this:GetText()
		this:GetParent():Hide()
		if p then p.fn(text) end
	end,
	EditBoxOnEscapePressed = function() this:GetParent():Hide() end,
	timeout = 0, whileDead = 1, hideOnEscape = 1,
}

function W:Prompt(text, default, fn)
	W.prompt = { default = tostring(default or ""), fn = fn }
	W.ShowPopup("OCTORANK_PROMPT", W.L(text))
end

-- a link to copy: straight onto the clipboard with ClassicAPI, otherwise a box with it selected
function W:CopyLink(what, url)
	if CopyToClipboard and pcall(CopyToClipboard, url) then
		W.Print(W.LF("%s link copied - paste it with Ctrl+V: |cffffd100%s|r", W.L(what), url))
		return
	end
	W:Prompt(W.L(what) .. "\n|cffffd100" .. url .. "|r\n" .. W.L("|cff888888Press Ctrl+C to copy the link, then Esc.|r"), url, function() end)
end

------------------------------------------------------------------ the group

W.roster = { byName = {}, n = 0 }

function W:UpdateRoster()
	local R = { byName = {}, n = 0 }
	local function add(unit)
		if not UnitExists(unit) then return end
		local name = UnitName(unit)
		if not name or name == UNKNOWNOBJECT then return end
		local _, class = UnitClass(unit)
		R.byName[name] = { name = name, class = class or "WARRIOR", unit = unit }
		R.n = R.n + 1
	end
	local nr = GetNumRaidMembers()
	if nr > 0 then
		for i = 1, nr do add("raid" .. i) end
	else
		add("player")
		for i = 1, GetNumPartyMembers() do add("party" .. i) end
	end
	W.roster = R
end

------------------------------------------------------------------ event bus / timers

local frame = CreateFrame("Frame", "OctoRankEventFrame")
W.frame = frame
local handlers = {}

function W:On(ev, fn)
	if not handlers[ev] then
		handlers[ev] = {}
		pcall(frame.RegisterEvent, frame, ev)
	end
	tinsert(handlers[ev], fn)
end

-- an error in one handler is reported once and the others still run
local seenErr, nSeen = {}, 0
function W:Oops(where, err)
	err = tostring(err)
	local key = tostring(where) .. ":" .. string.sub(err, 1, 60)
	if seenErr[key] or nSeen >= 50 then return end
	seenErr[key] = true
	nSeen = nSeen + 1
	W.Print("|cffff5555error|r in " .. tostring(where) .. ": " .. err)
end

frame:SetScript("OnEvent", function()
	local list = handlers[event]
	if not list then return end
	for i = 1, getn(list) do
		local ok, err = pcall(list[i], arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
		if not ok then W:Oops(event, err) end
	end
end)

local tickers = {}
function W:Every(interval, fn)
	tinsert(tickers, { i = interval, f = fn, a = 0 })
end

frame:SetScript("OnUpdate", function()
	local e = arg1
	for i = 1, getn(tickers) do
		local t = tickers[i]
		t.a = t.a + e
		if t.a >= t.i then
			t.a = 0
			local ok, err = pcall(t.f)
			if not ok then W:Oops("timer", err) end
		end
	end
end)

------------------------------------------------------------------ saved variables

local DEFAULTS = {
	noMinimap = true,         -- (pfUI Octo) the sidebar's OctoRanks entry and /orank open it
	shareBoard = true,        -- the hidden realm channel: raid times from the master feed, 5-man runs
	chronStartOnPull = true,  -- the logger, once you've said yes (Logs.lua)
	chronSaveOnFight = true,
	chronSplit = true,        -- an own numbered log file for every raid and 5-man run
}

W:On("ADDON_LOADED", function(name)
	if name ~= "pfUI" then return end
	if type(OctoRankDB) ~= "table" then OctoRankDB = {} end
	OctoRankDB.opts = OctoRankDB.opts or {}
	if pfUI_config and pfUI_config.disabled and pfUI_config.disabled.octorank == "1" then
		W.off = true
		frame:SetScript("OnEvent", nil)
		frame:SetScript("OnUpdate", nil)
		if ChronicleEventFrame then ChronicleEventFrame:UnregisterAllEvents() end
	end
	for k, v in pairs(DEFAULTS) do
		if OctoRankDB.opts[k] == nil then OctoRankDB.opts[k] = v end
	end
end)

W:On("PLAYER_ENTERING_WORLD", function()
	W:UpdateRoster()
	-- once: what it is and how to open it
	local o = OctoRankDB and OctoRankDB.opts
	if o and not o.welcomed then
		o.welcomed = true
		W.Print("Rankings for every guild's raids and your 5-man runs. |cffffd100/orank|r or the minimap button opens it.")
	end
end)
W:On("RAID_ROSTER_UPDATE", function() W:UpdateRoster() end)
W:On("PARTY_MEMBERS_CHANGED", function() W:UpdateRoster() end)

------------------------------------------------------------------ slash command

SLASH_OCTORANK1 = "/orank"
SLASH_OCTORANK2 = "/octorank"
SlashCmdList["OCTORANK"] = function(msg)
	local _, _, cmd, rest = string.find(msg or "", "^(%S*)%s*(.-)$")
	cmd = strlower(cmd or "")
	local UI = W.UI
	if cmd == "" then
		UI:Toggle()
	elseif cmd == "raids" or cmd == "rankings" then
		UI.rk.five = nil
		UI:SetMode("rankings")
	elseif cmd == "5man" or cmd == "5" or cmd == "dungeons" then
		W.Runs:Slash(rest)
	elseif cmd == "logs" or cmd == "log" then
		UI:SetMode("logs")
	elseif cmd == "timer" then
		W.RunTimer:Slash(rest)
	elseif cmd == "share" then
		OctoRankDB.opts.shareBoard = (rest ~= "off")
		if OctoRankDB.opts.shareBoard then W.Board:Join() else W.Board:Leave() end
		W.Print("The hidden realm channel (raid times from the master feed, 5-man runs): " .. (OctoRankDB.opts.shareBoard and "on" or "off"))
		UI:Refresh()
	elseif cmd == "minimap" then
		OctoRankDB.opts.noMinimap = (rest == "off")
		UI.UpdateMinimap()
	elseif cmd == "feed" then
		OctoRankDB.opts.noFeed = (rest == "off")
		W.Print("Raid times from a master's feed: " .. (OctoRankDB.opts.noFeed and "off (ignored)" or "|cff33ff33on|r"))
		W.Board:LoadChronicle()
		UI:Refresh()
	else
		W.Print("|cffffd100/orank|r window   |cffffd100/orank 5man|r 5-mans (|cffffd100on|off|r sharing, |cffffd100name <name>|r your group)   |cffffd100/orank logs|r logging   |cffffd100/orank timer on|off|reset|r   |cffffd100/orank share on|off|r   |cffffd100/orank feed on|off|r")
	end
end
