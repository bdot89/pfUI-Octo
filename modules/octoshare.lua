pfUI:RegisterModule("octoshare", "vanilla:tbc", function ()
  -- pfUI Octo :: OctoShare (27 Nov 2026; emp + Upsilon on Discord: "put something into pfui ... sends me the master
  -- advanced info to make more fun boards", "we will make users aware of the file ... lightweight and none impactable").
  --
  -- What it is. pfUI Octo ALREADY shares small bits of crowd data between players in your guild / raid, each with its
  -- own on/off switch: auction prices (pfAP), flight times (pfFT), transport timings (pfOctoTR), gathering nodes (pfGN),
  -- world buffs (pfWB) and the OctoBoards stats (pfLB). OctoShare adds two things on top, both OFF as it comes:
  --   1. Collector  - a role for ONE character (the master's): it writes every share message it hears into
  --                   pfUI_cache.octoshare.log (time, kind, sender, channel, payload), capped. tools\Sync-OctoShare.ps1
  --                   reads that saved file and appends it to CSVs a database can load. Ordinary players never collect.
  --   2. Emit       - OctoShare.Emit(kind, payload) broadcasts a NEW kind of record (BG queues, population...) on the
  --                   pfOS prefix, so new feeds don't need their own transport. Off until octoshare.enable = "1".
  --
  -- Disclosure (the whole point): the Data sharing page (Quality of Life) lists every feed, says who it reaches, and
  -- turns each off. Nothing is hidden. Realm-wide reach needs a shared custom channel (octoshare.channel) - the client
  -- has the channel API but whether THIS server relays addon messages over a custom channel is unverified: test in game
  -- before trusting it, guild / raid (proven) is the default.
  -- Lightweight: it only logs on CHAT_MSG_ADDON (an event, never a scan), appends one capped-list entry, and Emit sends
  -- at most one throttled message every few seconds. No per-frame work beyond a light outbox tick.

  local OS = {}
  pfUI.octoshare = OS

  OS.PREFIX = "pfOS"                       -- OctoShare's own new-feed channel
  OS.MAXLOG = 20000                        -- oldest entries drop past this
  OS.SEP = "`"                             -- log field separator (a backtick never appears in a share payload)

  -- the feeds already shared by other modules, by addon prefix: { prefix, label, config group/key for its switch }
  OS.FEEDS = {
    { "pfAP",     "Auction prices",  "auction",    "share" },
    { "pfFT",     "Flight times",    "flight",     "share" },
    { "pfOctoTR", "Transport times", "transports", "share" },
    { "pfGN",     "Gathering nodes", "gather",     "share" },
    { "pfWB",     "World buffs",     "worldbuffs", "share" },
    { "pfLB",     "Leaderboards",    nil,          nil },     -- OctoBoards shares in guild / raid; no single key
    { "pfOS",     "OctoShare feeds", "octoshare",  "enable" },
  }
  OS.KNOWN = {}
  for _, f in ipairs(OS.FEEDS) do OS.KNOWN[f[1]] = f[2] end

  local function Cfg() return C.octoshare or {} end
  function OS.Collecting() return Cfg().collect == "1" end
  function OS.Enabled()    return Cfg().enable == "1" end

  local function DB()
    pfUI_cache = pfUI_cache or {}
    pfUI_cache.octoshare = pfUI_cache.octoshare or { log = {}, n = 0, since = (time and time() or 0) }
    local d = pfUI_cache.octoshare
    if type(d.log) ~= "table" then d.log = {} end
    return d
  end
  OS.DB = DB

  -- ------------------------------------------------------------------ collector: log what we hear
  -- a ring buffer kept as a list; when it is full the oldest quarter is dropped in one pass (cheaper than shifting
  -- every message). table.setn keeps the length honest under Lua 5.0 (a list emptied with nil keeps its old length).
  local function Trim(d)
    local log = d.log
    local n = table.getn(log)
    if n <= OS.MAXLOG then return end
    local drop = math.floor(OS.MAXLOG / 4)
    local keep = {}
    for i = drop + 1, n do table.insert(keep, log[i]) end
    d.log = keep
    if table and table.setn then table.setn(keep, table.getn(keep)) end
  end

  function OS.Log(prefix, msg, chan, who)
    if not OS.Collecting() then return end
    if not OS.KNOWN[prefix] then return end
    if type(msg) ~= "string" or msg == "" then return end
    if who and UnitName and who == UnitName("player") then return end   -- not our own echo
    local d = DB()
    local line = (time and time() or 0) .. OS.SEP .. prefix .. OS.SEP .. (who or "?") .. OS.SEP
      .. (chan or "?") .. OS.SEP .. msg
    table.insert(d.log, line)
    d.n = (d.n or 0) + 1
    Trim(d)
  end

  function OS.Clear()
    local d = DB()
    d.log = {}
    d.n = 0
    d.since = time and time() or 0
  end

  -- ------------------------------------------------------------------ custom channel (realm-wide)
  -- ------------------------------------------------------------------ realm-wide reach: whisper the master
  -- (27 Nov 2026, seen in game) A custom chat CHANNEL does NOT carry addon messages on this client: every CHANNEL send
  -- printed a red "Unknown addon chat type (prefix ...)". So the channel is gone. Guild / raid / party work (proven).
  -- For realm-wide, each client also sends an ADDON WHISPER to the master's collector character (whisper IS a valid
  -- addon chat type here, and it is invisible), but only when its name is set - off until the master fills it in and
  -- confirms it does not error (an addon whisper to an offline name may draw a "no such player" line).
  --
  -- (28 Nov 2026, user: the realm bots "can accept whispers", they can't be put in a guild - "force our master chars
  -- into their addons") The realm DATA BOTS are built in: OS.BOTS[realm][faction] (or .any on a cross-faction realm).
  -- On by default (octoshare.realmbots, a switch on the Data sharing page); a master typed in by hand wins. Only your
  -- own faction's bot (a whisper to the other faction fails). If the bot is offline the server answers "No player named
  -- ..." - that one line is hidden for the bot's name and sending to it pauses for OS.DOWNFOR seconds.
  --
  -- (28 Nov 2026, user: "make them not changeable it should be hardset in nobody should be able to change it") The
  -- masters are FIXED per realm + faction. No option, no saved setting (octoshare.master / realmbots are ignored, and
  -- dropped from saved configs), and the list is a local here - OS.BOTS is only a copy for display, so neither another
  -- addon nor a profile import can redirect the data. A new bot = a new pfUI Octo release.
  local BOTS = {
    ["Y'Shaarj"] = { Horde = "Errorgchat", Alliance = "Octopfui" },
    ["C'Thun"]   = {},
    ["N'Zoth"]   = { any = "Pfuiocto" },   -- cross-faction: one bot hears both factions
  }
  OS.BOTS = {}
  for realm, list in pairs(BOTS) do
    OS.BOTS[realm] = {}
    for k, v in pairs(list) do OS.BOTS[realm][k] = v end
  end
  Cfg().master, Cfg().realmbots = nil, nil                -- the old changeable settings, gone for good
  OS.DOWNFOR = 600
  OS.masterDownUntil = 0
  function OS.RealmBot()
    local realm = GetRealmName and GetRealmName()
    local bots = realm and BOTS[realm]
    if not bots then return nil end
    local faction = UnitFactionGroup and (UnitFactionGroup("player"))
    return (faction and bots[faction]) or bots.any
  end
  -- (28 Nov 2026, SEEN IN GAME - the user's screenshot again: red "Unknown addon chat type (prefix pfLB / pfOctoTR /
  -- pfGN)" every few seconds from 1.2.80 on) This server refuses ADDON WHISPERS too: only PARTY / RAID / GUILD /
  -- BATTLEGROUND carry addon messages. So nothing is whispered to the bots until another way to reach them exists.
  -- OS.noWhisper is also set at run time when the server sends that line about one of our prefixes (OS.AddonRefused).
  OS.noWhisper = true
  -- (28 Nov 2026, user: "Yes, try it") The way that does work: a NORMAL whisper "~OS~<prefix>~<message>" to the bot,
  -- through the same governor (one line per gap, never in combat, never while AFK in case talking clears AFK). The
  -- bot files it like an addon message (its GamePacketHandler octoPeekChat). The "To Errorgchat:" line is hidden in
  -- every chat frame, and pfUI's whisper windows / chat history skip "~OS~" lines. Seen working in game 28 Nov 07:03
  -- (1.2.87 trial), so from 1.2.88 it is ON for everyone with no switch (user: "Yes, turn it on"; the bots are
  -- hard-set and nobody changes them). The only way out is turning the feeds off on the Data sharing page.
  OS.MARK = "~OS~"
  Cfg().bottest = nil                                     -- the 1.2.87 trial switch, gone
  function OS.ChatWhisperOn() return true end
  -- AFK as the feeds module saw it (the game's "You are now AFK" line; 1.12 has no UnitIsAFK)
  function OS.IsAfk() return OS.feeds and OS.feeds.afk and true or false end
  -- (28 Nov 2026, LazyBones: "You cannot whisper yet (too low level)" at login, even with every feed off) new characters
  -- may not whisper on this server: no bot whisper below OS.MINLEVEL, and when the server still refuses one, none until
  -- the next level up (OS.LowLevelRefused). Nothing is queued for the bot meanwhile.
  OS.MINLEVEL = 5                                     -- the server lets you whisper from level 5 (user, 28 Nov)
  OS.refusedAt = nil                                     -- the level the server last said "too low level" at
  function OS.AnyFeedOn()
    if OS.Enabled() then return true end
    for _, g in ipairs({ "auction", "flight", "transports", "gather", "worldbuffs" }) do
      if C[g] and C[g].share == "1" then return true end
    end
    return false
  end
  function OS.LevelOk()
    local lvl = UnitLevel and UnitLevel("player") or 0
    if type(lvl) ~= "number" or lvl < OS.MINLEVEL then return false end
    if OS.refusedAt and lvl <= OS.refusedAt then return false end
    return true
  end
  function OS.Master()
    if not OS.ChatWhisperOn() then return nil end
    if not OS.LevelOk() then return nil end
    -- every switch on the Data sharing page off = nothing to the bot either (the leaderboards have no switch of their own)
    if not OS.AnyFeedOn() then return nil end
    if (GetTime and GetTime() or 0) < OS.masterDownUntil then return nil end   -- offline: paused
    local m = OS.RealmBot()
    if m and m ~= "" and (not UnitName or m ~= (UnitName("player"))) then return m end
    return nil
  end
  -- the server's "No player named 'X' is currently playing." for the master: true = it was about our master
  function OS.MasterNotFound(text)
    if type(text) ~= "string" then return false end
    local m = OS.RealmBot()
    if not m or m == "" then return false end
    local lower, name = string.lower(text), string.lower(m)
    if not string.find(lower, "no player named", 1, true) and not string.find(lower, "not found", 1, true) then return false end
    return string.find(lower, "'" .. name .. "'", 1, true) or string.find(lower, '"' .. name .. '"', 1, true)
      or string.find(lower, " " .. name .. " ", 1, true) and true or false
  end
  function OS.MasterDown()
    OS.masterDownUntil = (GetTime and GetTime() or 0) + OS.DOWNFOR
    -- drop whatever was still waiting for the master
    local keep = {}
    for _, item in ipairs(OS.q) do if item[3] ~= "WHISPER" then table.insert(keep, item) end end
    OS.q, OS.qn = keep, table.getn(keep)
  end
  -- the server's "Unknown addon chat type (prefix X)" about one of OUR prefixes: stop whispering for good this session,
  -- drop the whispers still queued, and hide the line (other add-ons' lines are left alone)
  OS.OURS = { pfAP = true, pfOS = true, pfLB = true, pfGN = true, pfFT = true, pfOctoTR = true, pfWB = true }
  function OS.AddonRefused(text)
    if type(text) ~= "string" or not string.find(text, "Unknown addon chat type", 1, true) then return false end
    local _, _, prefix = string.find(text, "prefix ([^%)%s]+)")
    if not (prefix and OS.OURS[prefix]) then return false end
    OS.noWhisper = true
    local keep = {}
    for _, item in ipairs(OS.q) do if item[3] ~= "WHISPER" then table.insert(keep, item) end end
    OS.q, OS.qn = keep, table.getn(keep)
    return true
  end
  -- one of our data whispers ("To <bot>: ~OS~pfLB~..." or a bundle "~O2~...") - hidden everywhere
  OS.BUNDLE = "~O2~"
  function OS.IsOurWhisper(text)
    return type(text) == "string" and (string.sub(text, 1, string.len(OS.MARK)) == OS.MARK
      or string.sub(text, 1, string.len(OS.BUNDLE)) == OS.BUNDLE)
  end
  -- (28 Nov 2026, user: "make the hidden whispers carry more info by making it a code") a BUNDLE: the first waiting
  -- line for the bot plus every next one that still fits, as "~O2~" .. "prefix~msg}prefix~msg..." (the bot splits on
  -- "}"; no feed uses that sign). One whisper instead of several, so the same data costs far fewer chat lines. A line
  -- with "}" in it, or a lone line, goes the old way ("~OS~prefix~msg") - bots from before still read those.
  OS.BUNDLEMAX = 250
  function OS.TakeBundle(first)
    local recs, len = { first[1] .. "~" .. first[2] }, string.len(OS.BUNDLE) + string.len(first[1]) + 1 + string.len(first[2])
    if string.find(first[2], "}", 1, true) then return nil end
    local i = 1
    while i <= OS.qn do
      local it = OS.q[i]
      if it[3] == "WHISPER" and it[4] == first[4] and not string.find(it[2], "}", 1, true) then
        local add = 1 + string.len(it[1]) + 1 + string.len(it[2])
        if len + add > OS.BUNDLEMAX then break end
        table.insert(recs, it[1] .. "~" .. it[2])
        len = len + add
        table.remove(OS.q, i)
        OS.qn = OS.qn - 1
      else
        i = i + 1
      end
    end
    if table.getn(recs) < 2 then return nil end
    return OS.BUNDLE .. table.concat(recs, "}")
  end
  -- the text of a data whisper (under the 255 a chat line may hold)
  function OS.WhisperText(prefix, msg)
    local t = OS.MARK .. prefix .. "~" .. msg
    if string.len(t) > 250 then t = string.sub(t, 1, 250) end
    return t
  end
  -- the server's "You cannot whisper yet (too low level)" right after one of OUR whispers (within 5 s): no bot whispers
  -- until the next level, the queued ones dropped, the line hidden. After the player's own whisper it stays in chat.
  OS.lastBotWhisper = 0
  function OS.LowLevelRefused(text)
    if type(text) ~= "string" or not string.find(string.lower(text), "cannot whisper yet", 1, true) then return false end
    if (GetTime and GetTime() or 0) - (OS.lastBotWhisper or 0) > 5 then return false end
    OS.refusedAt = UnitLevel and UnitLevel("player") or 0
    local keep = {}
    for _, item in ipairs(OS.q) do if item[3] ~= "WHISPER" then table.insert(keep, item) end end
    OS.q, OS.qn = keep, table.getn(keep)
    return true
  end
  -- the player talking: the last time they sent any chat line (not ours), and whether a chat box is open
  OS.TALKHOLD = 10
  OS.userChatAt = 0
  local origSend = _G.SendChatMessage
  if type(origSend) == "function" and not OS.sendWrapped then
    OS.sendWrapped = true
    _G.SendChatMessage = function(msg, chan, lang, target)
      if not OS.IsOurWhisper(msg) then OS.userChatAt = GetTime and GetTime() or 0 end
      return origSend(msg, chan, lang, target)
    end
  end
  function OS.UserBusy(now)
    now = now or (GetTime and GetTime() or 0)
    if now - (OS.userChatAt or 0) < OS.TALKHOLD then return true end
    for i = 1, (NUM_CHAT_WINDOWS or 7) do
      local box = _G["ChatFrame" .. i .. "EditBox"]
      if box and box.IsVisible and box:IsVisible() then return true end
    end
    local box = _G.ChatFrameEditBox
    if box and box.IsVisible and box:IsVisible() then return true end
    return false
  end
  -- hide that line from every chat frame (1.12 has no message filters: wrap the chat frame's event handler once)
  local origChatEvent = _G.ChatFrame_OnEvent
  if type(origChatEvent) == "function" and not OS.chatWrapped then
    OS.chatWrapped = true
    _G.ChatFrame_OnEvent = function(ev, a2, a3, a4, a5)
      local e = ev or _G.event
      if e == "CHAT_MSG_SYSTEM" and (OS.MasterNotFound(_G.arg1) or OS.AddonRefused(_G.arg1) or OS.LowLevelRefused(_G.arg1)) then return end
      if (e == "CHAT_MSG_WHISPER_INFORM" or e == "CHAT_MSG_WHISPER") and OS.IsOurWhisper(_G.arg1) then return end
      return origChatEvent(ev, a2, a3, a4, a5)
    end
  end
  -- where OctoShare's own feeds go: guild / raid / party (string channels)
  function OS.Channels()
    local list = {}
    if IsInGuild and IsInGuild() then table.insert(list, "GUILD") end
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then table.insert(list, "RAID")
    elseif GetNumPartyMembers and GetNumPartyMembers() > 0 then table.insert(list, "PARTY") end
    return list
  end

  -- ------------------------------------------------------------------ the send governor (the "never get throttled" piece)
  -- Every pfUI Octo broadcast goes through OS.Send, which paces ALL of them onto ONE slow outbound stream so the sum of
  -- the feeds can never trip the server's "sending too quickly" timeout (emp confirmed addon messages are allowed; the
  -- user: this "needs to never happen"). Rules:
  --   - at most one wire message every OS.gap seconds (default 2 s = ~30/min, far under the server's limit);
  --   - NOTHING is sent while the player is in combat, and for a few seconds after - sharing never gets in the way of a
  --     pull or a raid fight (the user: "if in raids it slows down or stops ... none noticable");
  --   - if the server ever does warn about chat speed, back off hard (OS.BACKOFF seconds of total silence) and the queue
  --     is trimmed - we would rather drop crowd data than spam;
  --   - the queue is capped (OS.QCAP): past it the OLDEST waiting message is dropped, so a backlog can never later flood.
  OS.q, OS.qn = {}, 0
  OS.QCAP = 300
  OS.BACKOFF = 45
  OS.combatUntil = 0
  OS.silentUntil = 0
  function OS.Gap() return tonumber(Cfg().gap) or 2 end
  function OS.Send(prefix, msg, chan, idx)
    if type(SendAddonMessage) ~= "function" or type(prefix) ~= "string" or type(msg) ~= "string" then return end
    if string.find(msg, "|") then return end           -- a "|" makes the server drop the message (and can look like spam)
    if OS.qn >= OS.QCAP then table.remove(OS.q, 1) OS.qn = OS.qn - 1 end
    table.insert(OS.q, { prefix, msg, chan or "GUILD", idx })
    OS.qn = OS.qn + 1
  end

  -- the other feed modules call this with their own list of string channels ("GUILD", "RAID"...): every one is paced
  -- through the governor, and the custom realm channel is added when set. One place so realm-wide + throttle-safety
  -- cover every feed at once.
  function OS.Broadcast(prefix, msg, chans)
    if type(chans) == "table" then for _, c in ipairs(chans) do OS.Send(prefix, msg, c) end end
    local m = OS.Master()
    if m then OS.Send(prefix, msg, "WHISPER", m) end
  end

  -- Emit: a NEW feed's record (BG queues, population...). kind is a short tag, payload is "^"-joined, never "|".
  function OS.Emit(kind, payload)
    if not OS.Enabled() then return end
    if type(kind) ~= "string" or kind == "" then return end
    payload = payload or ""
    local msg = kind .. "^" .. payload
    if string.len(msg) > 240 then msg = string.sub(msg, 1, 240) end
    OS.Broadcast(OS.PREFIX, msg, OS.Channels())
  end
  -- (28 Nov 2026) a record only the realm's data bot needs (the heartbeat): the same governor, no guild / raid copy.
  -- Nothing goes out when there is no bot on this realm or it is offline (paused).
  function OS.EmitBot(kind, payload)
    if not OS.Enabled() or type(kind) ~= "string" or kind == "" then return end
    local m = OS.Master()
    if not m then return end
    local msg = kind .. "^" .. (payload or "")
    if string.len(msg) > 240 then msg = string.sub(msg, 1, 240) end
    OS.Send(OS.PREFIX, msg, "WHISPER", m)
  end

  -- the server's "too quickly" warnings (strings vary by core): any of these backs us off hard
  local THROTTLE = { "too quickly", "too fast", "wait a", "being muted", "you are muted", "spamming" }
  local function IsThrottle(text)
    text = string.lower(text or "")
    for _, s in ipairs(THROTTLE) do if string.find(text, s, 1, true) then return true end end
    return false
  end

  local ev = CreateFrame("Frame")
  ev:RegisterEvent("CHAT_MSG_ADDON")
  ev:RegisterEvent("PLAYER_REGEN_DISABLED")   -- entered combat
  ev:RegisterEvent("PLAYER_REGEN_ENABLED")    -- left combat
  ev:RegisterEvent("CHAT_MSG_SYSTEM")
  ev:SetScript("OnEvent", function()
    if event == "CHAT_MSG_ADDON" then
      OS.Log(arg1, arg2, arg3, arg4)
    elseif event == "PLAYER_REGEN_DISABLED" then
      OS.combatUntil = (GetTime and GetTime() or 0) + 99999        -- in combat: hold (cleared on regen enabled)
    elseif event == "PLAYER_REGEN_ENABLED" then
      OS.combatUntil = (GetTime and GetTime() or 0) + 3            -- a few seconds' grace after combat
    elseif event == "CHAT_MSG_SYSTEM" then
      if OS.MasterNotFound(arg1) then OS.MasterDown() return end
      if IsThrottle(arg1) then
        OS.silentUntil = (GetTime and GetTime() or 0) + OS.BACKOFF
        -- shed most of the backlog so we do not immediately try again
        OS.q, OS.qn = {}, 0
      end
    end
  end)

  -- the drain: one message per gap, never in combat, never during a backoff
  ev:SetScript("OnUpdate", function()
    local now = GetTime and GetTime() or 0
    if OS.qn <= 0 then return end
    if now < OS.silentUntil then return end
    if now < OS.combatUntil then return end
    -- a late safety net in case an event was missed
    if (UnitAffectingCombat and UnitAffectingCombat("player")) or (InCombatLockdown and InCombatLockdown()) then return end
    if (this.sendAt or 0) > now then return end
    -- (28 Nov 2026, user: "make sure this isn't flooding peoples chats to lock them out from talking if they are typing")
    -- nothing goes out while you type (a chat box open) or for OS.TALKHOLD seconds after you said anything, so the
    -- server's chat speed limit is always yours to use
    if OS.UserBusy(now) then return end
    -- a data whisper waits while you are AFK (talking may clear AFK); guild / raid lines go on as before
    local item = OS.q[1]
    if item[3] == "WHISPER" and OS.IsAfk() then
      for i = 2, OS.qn do
        if OS.q[i][3] ~= "WHISPER" then item = table.remove(OS.q, i) OS.qn = OS.qn - 1 break end
      end
      if item == OS.q[1] then return end                      -- only whispers waiting: hold them
    else
      table.remove(OS.q, 1)
      OS.qn = OS.qn - 1
    end
    this.sendAt = now + OS.Gap()
    if item[3] == "WHISPER" then
      -- addon whispers are refused here: a normal whisper the bot understands (hidden on our side)
      if OS.ChatWhisperOn() and item[4] and SendChatMessage and OS.LevelOk() then
        OS.lastBotWhisper = now
        local text = OS.TakeBundle(item) or OS.WhisperText(item[1], item[2])
        pcall(SendChatMessage, text, "WHISPER", nil, item[4])
      end
    elseif item[4] then pcall(SendAddonMessage, item[1], item[2], item[3], item[4])
    else pcall(SendAddonMessage, item[1], item[2], item[3]) end
  end)

  -- ------------------------------------------------------------------ /octoshare
  local function Say(t) if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccOctoShare|r " .. t) end end
  _G.SlashCmdList = _G.SlashCmdList or {}
  _G.SLASH_OCTOSHARE1 = "/octoshare"
  _G.SLASH_OCTOSHARE2 = "/oshare"
  _G.SlashCmdList["OCTOSHARE"] = function(a)
    a = string.lower(a or "")
    if a == "clear" then OS.Clear() Say("collector log cleared.") return end
    local d = DB()
    Say("collector: " .. (OS.Collecting() and "|cff55ff55ON|r" or "off") .. "  new feeds: "
      .. (OS.Enabled() and "|cff55ff55ON|r" or "off")
      .. "  realm data bot: " .. (OS.Master() or ((GetTime and GetTime() or 0) < OS.masterDownUntil and "offline - paused"
      or "none (guild / raid only)")))
    Say("logged: " .. table.getn(d.log) .. " of " .. OS.MAXLOG .. " (seen " .. (d.n or 0) .. " total).  /octoshare clear empties it.")
    Say("send queue: " .. OS.qn .. "  one message every " .. OS.Gap() .. "s, paused in combat (throttle-safe).")
  end
end)
