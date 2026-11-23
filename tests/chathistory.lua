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
local was = pfUI_cache.chathistory
pfUI_cache.chathistory = nil

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
  local H = WH.hub
  if H then
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

_G.time, _G.date = keep.time, keep.date
pfUI_cache.chathistory = was
