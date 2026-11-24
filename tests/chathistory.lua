-- pfUI Octo: chat history (modules/chat-history.lua) and its place in the whisper window (chat-whispers.lua),
-- run by tests\run.lua.
local ok = octo_ok
local CH = pfUI.chatHistory
ok(CH and CH.Add and CH.Prune and CH.People and CH.Lines, "chat history loaded (pfUI.chatHistory)")
if not CH then return end
local S = pfUI_config.chat.history
ok(S and S.days == "30" and S.max == "4000" and S.guild == "1" and S.say == "0", "defaults (C.chat.history): 30 days, say off")

local keep = { time = rawget(_G, "time"), date = rawget(_G, "date") }
local wall = 1795564800 + 10 * 3600
_G.time = function(t) if t then return keep.time(t) end return wall end
_G.date = os.date
local was, was2 = pfUI_cache.chathistory, pfUI_cache.octochat
pfUI_cache.chathistory = nil
pfUI_cache.octochat = nil

-- a line packs into one string and back, tabs in the text made safe
local line = CH.Pack(wall, "Thrall", "hello\tthere")
local t, who, text = CH.Unpack(line)
ok(t == wall and who == "Thrall" and text == "hello there", "a line in one string and back")

-- events: whispers both ways, guild, a raid warning; say is off
CH.OnEvent("CHAT_MSG_WHISPER", "bid 50", "Bidwell")
CH.OnEvent("CHAT_MSG_WHISPER_INFORM", "ok", "Bidwell")
CH.OnEvent("CHAT_MSG_GUILD", "raid at 8", "Gm")
CH.OnEvent("CHAT_MSG_RAID_WARNING", "pull in 5", "Lead")
CH.OnEvent("CHAT_MSG_SAY", "hi", "Someone")
local w = CH.Lines("whisper", "Bidwell")
local _, w1 = CH.Unpack(w[1])
local _, w2 = CH.Unpack(w[2])
ok(table.getn(w) == 2 and w1 == "<Bidwell" and w2 == ">Bidwell", "whispers kept both ways, per person")
local _, _, g = CH.Unpack(CH.Lines("guild")[1])
ok(g == "raid at 8", "guild kept")
local _, _, rw = CH.Unpack(CH.Lines("raid")[1])
ok(rw == "[Warning] pull in 5", "raid warnings kept in the raid history, marked")
ok(table.getn(CH.Lines("say")) == 0, "say is not kept unless switched on")
S.say = "1"
CH.OnEvent("CHAT_MSG_YELL", "for the horde", "Grunt")
local _, _, y = CH.Unpack(CH.Lines("say")[1])
ok(y == "[Yell] for the horde", "yells go with say when it is on")
S.say = "0"

-- people, newest first
wall = wall + 600
CH.OnEvent("CHAT_MSG_WHISPER", "hey", "Thrall")
local people = CH.People()
ok(people[1].name == "Thrall" and people[2].name == "Bidwell" and people[2].n == 2, "old whispers: newest person first")

-- 30 days, then gone; caps
CH.Add("guild", "Old", "long ago", wall - 40 * 86400)
CH.Prune()
local old = false
for _, l in ipairs(CH.Lines("guild")) do local _, _, x = CH.Unpack(l) if x == "long ago" then old = true end end
ok(not old and table.getn(CH.Lines("guild")) == 1, "lines older than 30 days go at login")
S.max = "500"
for i = 1, 600 do CH.Add("guild", "Spam", "line " .. i) end
CH.Prune()
local _, _, last = CH.Unpack(CH.Lines("guild")[table.getn(CH.Lines("guild"))])
ok(table.getn(CH.Lines("guild")) == 500 and last == "line 600", "a channel keeps at most its cap, the newest")
S.max = "4000"
S.enable = "0"
CH.Add("guild", "X", "not kept")
local _, _, l2 = CH.Unpack(CH.Lines("guild")[table.getn(CH.Lines("guild"))])
ok(l2 == "line 600", "history off: nothing new is kept")
S.enable = "1"

-- the whisper window: channel pages, old whispers, the list arrow
local WH = pfUI.whispers
ok(WH and WH.OpenChannel and WH.HistoryMenu and WH.ApplyList, "whisper window has channels, old whispers and the list arrow")
if WH and WH.OpenChannel then
  local good, err = pcall(WH.OpenChannel, "guild")
  ok(good, "a channel page opens" .. (good and "" or (": " .. tostring(err))))
  local c = WH.windows["#guild"]
  ok(c and c.chan and c.chan.key == "guild" and WH.active == "#guild", "the guild page is picked")
  local sent
  local env = getfenv(WH.Send)
  local keepSend, keepEnv = rawget(_G, "SendChatMessage"), rawget(env, "SendChatMessage")
  local fake = function(msg, kind) sent = kind .. ":" .. msg end
  _G.SendChatMessage = fake
  rawset(env, "SendChatMessage", fake)
  WH.Send("#guild", "hello guild")
  ok(sent == "GUILD:hello guild", "the box talks in the picked channel")
  _G.SendChatMessage = keepSend
  rawset(env, "SendChatMessage", keepEnv)
  -- a new guild line goes in while the page is made, counted when you look elsewhere
  local total = WH.Unread()
  CH.OnEvent("CHAT_MSG_GUILD", "new line", "Gm")
  ok(WH.Unread() == total, "channel lines never count as unread whispers (no pulsing)")
  local good2, err2 = pcall(WH.HistoryMenu, WH.hub and WH.hub.hist or UIParent)
  ok(good2, "the old whispers menu opens" .. (good2 and "" or (": " .. tostring(err2))))
  if WH.menu then
    local open1 = WH.menu:IsShown()
    WH.HistoryMenu(WH.hub and WH.hub.hist or UIParent)
    ok(open1 and not WH.menu:IsShown(), "clicking History again shuts the menu")
  end
  local H = WH.hub
  if H then
    -- (on a whisper's page: a channel's page has no people list at all)
    WH.Open("Bidwell", true)
    pfUI_config.chat.whisper.listhidden = "1"
    WH.ApplyList()
    ok(not H.list:IsShown(), "the arrow hides the list")
    pfUI_config.chat.whisper.listhidden = "0"
    WH.ApplyList()
    ok(H.list:IsShown(), "and brings it back")
  end
  -- an old conversation opens with its whole history
  WH.Open("Bidwell", true)
  local bc = WH.windows.Bidwell
  ok(bc and bc.day, "an old whisper opens with its kept lines and day dividers")
  WH.CloseAll()
end

-- NEW STYLE (chat-bar.lua): the chat does not start in the mock, so a stand-in left chat with its tab strip,
-- and the bar's module started again on it
if WH and WH.Embed and pfUI.module and pfUI.module["chat-bar"] then
  local hadChat = pfUI.chat
  pfUI.chat = pfUI.chat or {}
  local hadLeft = pfUI.chat.left
  local left = CreateFrame("Frame", "pfChatLeftTest", UIParent)
  left:SetWidth(400) left:SetHeight(180)
  left.panelTop = CreateFrame("Frame", nil, left)
  left.panelTop:SetHeight(18)
  left.panelTop:SetPoint("TOPLEFT", left, "TOPLEFT", 2, -2)
  left.panelTop:SetPoint("TOPRIGHT", left, "TOPRIGHT", -2, -2)
  pfUI.chat.left = left
  local styleWas = pfUI_config.chat.style
  pfUI_config.chat.style = "new"
  local started, serr = pcall(pfUI.module["chat-bar"])
  ok(started and pfUI.chatBar and pfUI.chatBar.Apply, "the new chat bar starts" .. (started and "" or (": " .. tostring(serr))))
  local CB = pfUI.chatBar
  if started and CB then
    CB.Apply()
    ok(CB.bar:IsShown() and WH.embedded, "NEW STYLE: the bar is on the chat and the whisper window sits inside it")
    -- (24 Nov 2026, user: "when the bar first loads up you have to minimize it and bring it back out to show the channels")
    -- straight after it loads, with no size from the game yet, every kept channel is there
    -- (at login the game has not laid the bar out: no edges yet - the room comes from the chat panel's set width.
    -- The mock counts colour codes as letters, so its labels measure far wider than in game: a wide chat here.)
    local barLeft, chatLeft, widthWas = CB.bar.GetLeft, left.GetLeft, pfUI_config.chat.left.width
    CB.bar.GetLeft = function() return nil end
    left.GetLeft = function() return nil end
    pfUI_config.chat.left.width = "1400"
    ok(CB.Width() == 1396, "no size from the game yet: the room is the chat panel's set width (" .. tostring(CB.Width()) .. ")")
    CB.Paint()
    local shownCh = 0
    for _, b in ipairs(CB.chanBtns) do if b:IsShown() then shownCh = shownCh + 1 end end
    ok(shownCh >= 5, "every kept channel shows on the first layout, no folding needed (" .. shownCh .. ")")
    CB.bar.GetLeft, left.GetLeft, pfUI_config.chat.left.width = barLeft, chatLeft, widthWas
    -- ("the text is overlapping") each button hangs on the one before it, so a longer name pushes the rest along
    local wp = CB.btns.whispers.points and CB.btns.whispers.points[1]
    ok(wp and wp[2] == CB.btns.chat and wp[3] == "RIGHT", "Whispers hangs on the chat button's right edge")
    CB.btns.chat:SetLabel("Loot & Spam  v")
    ok(CB.btns.chat:GetWidth() > 60, "a longer chat name makes its button wider")
    left.panelTop:Show()
    ok(not left.panelTop:IsShown(), "the mouse-over tab strip stays away under the bar")
    -- (24 Nov 2026, in game: the view opened under the chat's text) above the chat windows, pinned over the panel
    local p1 = WH.hub.points and WH.hub.points[1]
    local p2 = WH.hub.points and WH.hub.points[2]
    ok(WH.hub:GetFrameStrata() == "MEDIUM" and p1 and (p1[2] == CB.bar or p1[2] == left.panelTop or p1[2] == left) and p2 and p2[2] == left
      and not WH.hub:IsShown(), "the view sits above the chat windows, over the chat panel, closed until you open it")
    -- a whisper while you look at your chat: counted on the bar, the chat stays in view
    WH.Add("Quietguy", "in", "psst")
    ok(not WH.hub:IsShown() and WH.windows.Quietguy and WH.windows.Quietguy.unread == 1, "a new whisper waits on the bar (no pop-up)")
    CB.Paint()
    ok(string.find(CB.btns.whispers.text:GetText() or "", "66ff661", 1, true), "the Whispers button counts it")
    -- Whispers: the oldest new one opens in the chat; Chat: back; Chat again: the same conversation (quick toggle)
    CB.btns.whispers:GetScript("OnClick")()
    ok(WH.hub:IsShown() and WH.active == "Quietguy", "Whispers opens the new one inside the chat")
    -- (24 Nov 2026, in game: every line faint) the view's own backdrop never above its text: what is in it sits higher
    local hl = WH.hub:GetFrameLevel() or 0
    local ml = WH.windows.Quietguy.msg:GetFrameLevel() or 0
    ok((WH.hub.page:GetFrameLevel() or 0) > hl and ml > hl and (WH.hub.list:GetFrameLevel() or 0) > hl,
      "the conversation's lines and list sit above its own backdrop (" .. hl .. " / " .. ml .. ")")
    -- (24 Nov 2026, in game: the chat's own lines showed through the conversation) a chat window of the panel goes
    -- invisible while a conversation shows, and comes back after
    local keepCF7 = rawget(_G, "ChatFrame7")
    local cf7 = CreateFrame("Frame", nil, left)
    _G.ChatFrame7 = cf7
    WH.CoverChat(true)
    ok(cf7:GetAlpha() == 0, "the chat under an open conversation is out of sight")
    -- (opening Whispers kept every channel on the bar: the person buttons are in the conversation now)
    CB.Paint()
    local stillCh = 0
    for _, b in ipairs(CB.chanBtns) do if b:IsShown() then stillCh = stillCh + 1 end end
    ok(not CB.btns.invite:IsShown() and WH.hub.invite:GetParent() == WH.hub, "invite / target / who sit in the conversation, not on the bar")
    WH.CoverChat(false)
    ok(cf7:GetAlpha() == 1, "and back when you return to chat")
    _G.ChatFrame7 = keepCF7
    -- each channel its own colour (B and R were both orange)
    local seenCol, clash = {}, nil
    for _, k in ipairs(pfUI.chatHistory.KINDS) do
      local id = k.color[1] .. "," .. k.color[2] .. "," .. k.color[3]
      if seenCol[id] then clash = k.short .. " = " .. seenCol[id] end
      seenCol[id] = k.short
    end
    ok(not clash, "every channel has its own colour" .. (clash and (" (" .. clash .. ")") or ""))
    _G.this, _G.arg1 = CB.btns.chat, "LeftButton"
    CB.btns.chat:GetScript("OnClick")()
    ok(not WH.hub:IsShown(), "Chat goes back to your chat")
    CB.btns.chat:GetScript("OnClick")()
    ok(WH.hub:IsShown() and WH.active == "Quietguy", "Chat again flips back to the last conversation")
    -- a channel button
    CB.btns["#guild"]:GetScript("OnClick")()
    ok(WH.Showing() == "#guild", "G opens guild history in the chat")
    -- (24 Nov 2026, user: "what is this side bar for in guild chat") no people list on a channel's page
    ok(not WH.hub.list:IsShown(), "a channel's page has no people list")
    -- the day picker: Now, then each day the page has, newest first; a day scrolls back to its divider
    local gc = WH.windows["#guild"]
    ok(gc.days and table.getn(gc.days) >= 1 and gc.count and gc.count > 0, "the guild page knows its days (" .. table.getn(gc.days or {}) .. ")")
    local opts = WH.DaysMenu(WH.hub.days)
    ok(opts and opts[1].key == 0 and table.getn(opts) == table.getn(gc.days) + 1, "Days: Now, then every day")
    if WH.dmenu then WH.dmenu:Hide() end
    local ups, bottom = 0, false
    local keepUp, keepBottom = gc.msg.ScrollUp, gc.msg.ScrollToBottom
    gc.msg.ScrollUp = function() ups = ups + 1 end
    gc.msg.ScrollToBottom = function() bottom = true end
    local first = gc.days[1]
    WH.JumpDay(gc, first)
    ok(bottom and ups == gc.count - first.at, "picking a day scrolls back to its first line (" .. ups .. ")")
    -- Shift + wheel down: the newest line
    bottom = false
    local keepShift = rawget(_G, "IsShiftKeyDown")
    _G.IsShiftKeyDown = function() return true end
    _G.this, _G.arg1 = gc.msg, -1
    gc.msg:GetScript("OnMouseWheel")()
    ok(bottom, "Shift + wheel down jumps to the newest line")
    _G.IsShiftKeyDown = keepShift
    gc.msg.ScrollUp, gc.msg.ScrollToBottom = keepUp, keepBottom
    CB.btns["#guild"]:GetScript("OnClick")()
    ok(not WH.hub:IsShown(), "G again: back to chat")
    -- the chat panel hidden (the panel arrow, Blizzard's chat): the view goes with it
    CB.btns["#guild"]:GetScript("OnClick")()
    left:Hide()
    local hideScript = left:GetScript("OnHide")
    if hideScript then hideScript() end
    ok(not WH.hub:IsShown(), "the chat panel hidden: the view goes too")
    left:Show()
    -- fold the bar
    pfUI_config.chat.barfolded = "1"
    CB.Layout()
    ok(CB.btns.fold:IsShown() and not CB.btns.whispers:IsShown(), "< folds the bar to one small arrow")
    pfUI_config.chat.barfolded = "0"
    -- OLD CHAT: all of it back as it was
    CB.SetStyle("old")
    ok(not CB.bar:IsShown() and not WH.embedded and WH.hub:GetParent() ~= left, "OLD CHAT: the bar goes, the window floats again")
    left.panelTop:Show()
    ok(left.panelTop:IsShown(), "and the tab strip works as before")
    WH.CloseAll()
  end
  pfUI_config.chat.style = styleWas
  pfUI.chat.left = hadLeft
  if not hadChat then pfUI.chat = nil end
end

-- (24 Nov 2026) Old chat / New style in the strip at the top of the Chat pages, beside Chat and Panels
do
  local O = pfUI.octoui and pfUI.octoui.Options
  if O and O.frame and O.SWAPEXTRA and O.SWAPEXTRA["Chat & Panels"] then
    local styleWas = pfUI_config.chat.style
    pfUI.gui:Show()
    local good, err = pcall(function() O:Open("chwindows") end)
    local E = O.swap and O.swap.extra
    ok(good and E and E.def and E.btns[1] and E.btns[1]:IsShown() and E.btns[2]:IsShown()
      and E.btns[2].label:GetText() == "New style", "the Chat pages' strip offers Old chat / New style" .. (good and "" or (": " .. tostring(err))))
    if E and E.btns[2] then
      _G.this = E.btns[2]
      E.btns[2]:GetScript("OnClick")()
      ok(pfUI_config.chat.style == "new", "New style in the strip switches the chat")
      _G.this = E.btns[1]
      E.btns[1]:GetScript("OnClick")()
      ok(pfUI_config.chat.style == "old", "and Old chat back")
    end
    pfUI_config.chat.style = styleWas
    if pfUI.chatBar and pfUI.chatBar.Apply then pcall(pfUI.chatBar.Apply) end
    pfUI.gui:Hide()
  end
end

_G.time, _G.date = keep.time, keep.date
pfUI_cache.chathistory, pfUI_cache.octochat = was, was2
