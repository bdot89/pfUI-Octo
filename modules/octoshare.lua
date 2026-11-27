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
  OS.channelIndex = nil
  -- join the shared channel and HIDE it from every chat window, so it is never seen or in the way (the user: "none
  -- noticable"). Addon messages ride it invisibly; no one has to see a channel. Re-tried from the drain if it drops.
  function OS.JoinChannel()
    local name = Cfg().channel
    if not name or name == "" or not JoinChannelByName then OS.channelIndex = nil return end
    pcall(JoinChannelByName, name)
    local id = GetChannelName and GetChannelName(name)
    OS.channelIndex = (id and type(id) == "number" and id > 0) and id or nil
    if OS.channelIndex and _G.ChatFrame_RemoveChannel then
      for i = 1, (_G.NUM_CHAT_WINDOWS or 10) do
        local cf = _G["ChatFrame" .. i]
        if cf then pcall(_G.ChatFrame_RemoveChannel, cf, name) end
      end
    end
  end
  -- the custom channel as a { "CHANNEL", index } pair, or nil - the feed modules add this to their own channel lists
  function OS.ExtraChannel()
    if OS.channelIndex then return { "CHANNEL", OS.channelIndex } end
    return nil
  end
  -- where OctoShare's own feeds go: guild / raid / party, plus the custom channel when set
  function OS.Channels()
    local list = {}
    if IsInGuild and IsInGuild() then table.insert(list, { "GUILD" }) end
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then table.insert(list, { "RAID" })
    elseif GetNumPartyMembers and GetNumPartyMembers() > 0 then table.insert(list, { "PARTY" }) end
    local x = OS.ExtraChannel()
    if x then table.insert(list, x) end
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
    local x = OS.ExtraChannel()
    if x then OS.Send(prefix, msg, x[1], x[2]) end
  end

  -- Emit: a NEW feed's record (BG queues, population...). kind is a short tag, payload is "^"-joined, never "|".
  function OS.Emit(kind, payload)
    if not OS.Enabled() then return end
    if type(kind) ~= "string" or kind == "" then return end
    payload = payload or ""
    local msg = kind .. "^" .. payload
    if string.len(msg) > 240 then msg = string.sub(msg, 1, 240) end
    for _, c in ipairs(OS.Channels()) do OS.Send(OS.PREFIX, msg, c[1], c[2]) end
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
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:RegisterEvent("PLAYER_REGEN_DISABLED")   -- entered combat
  ev:RegisterEvent("PLAYER_REGEN_ENABLED")    -- left combat
  ev:RegisterEvent("CHAT_MSG_SYSTEM")
  ev:SetScript("OnEvent", function()
    if event == "CHAT_MSG_ADDON" then
      OS.Log(arg1, arg2, arg3, arg4)
    elseif event == "PLAYER_ENTERING_WORLD" then
      if not this.joined then this.joined = true OS.JoinChannel() end
    elseif event == "PLAYER_REGEN_DISABLED" then
      OS.combatUntil = (GetTime and GetTime() or 0) + 99999        -- in combat: hold (cleared on regen enabled)
    elseif event == "PLAYER_REGEN_ENABLED" then
      OS.combatUntil = (GetTime and GetTime() or 0) + 3            -- a few seconds' grace after combat
    elseif event == "CHAT_MSG_SYSTEM" then
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
    -- re-join the shared channel if it is set but we are not on it (a channel can drop on a loading screen)
    if Cfg().channel ~= "" and not OS.channelIndex and (this.joinAt or 0) <= now then
      this.joinAt = now + 15
      OS.JoinChannel()
    end
    if OS.qn <= 0 then return end
    if now < OS.silentUntil then return end
    if now < OS.combatUntil then return end
    -- a late safety net in case an event was missed
    if (UnitAffectingCombat and UnitAffectingCombat("player")) or (InCombatLockdown and InCombatLockdown()) then return end
    if (this.sendAt or 0) > now then return end
    this.sendAt = now + OS.Gap()
    local item = table.remove(OS.q, 1)
    OS.qn = OS.qn - 1
    if item[4] then pcall(SendAddonMessage, item[1], item[2], item[3], item[4])
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
      .. "  channel: " .. ((Cfg().channel ~= "" and Cfg().channel or "guild / raid only")))
    Say("logged: " .. table.getn(d.log) .. " of " .. OS.MAXLOG .. " (seen " .. (d.n or 0) .. " total).  /octoshare clear empties it.")
    Say("send queue: " .. OS.qn .. "  one message every " .. OS.Gap() .. "s, paused in combat (throttle-safe).")
  end
end)
