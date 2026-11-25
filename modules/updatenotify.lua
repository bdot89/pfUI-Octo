pfUI:RegisterModule("updatenotify", "vanilla:tbc", function ()
  local localversion  = tonumber(pfUI.version.major*10000 + pfUI.version.minor*100 + pfUI.version.fix)
  local loginchannels = { "BATTLEGROUND", "RAID", "GUILD" }
  local groupchannels = { "BATTLEGROUND", "RAID" }

  -- octo (29 Oct 2026, user: the About screen "should also show if there is a
  -- new update of this fork"): pfUI Octo users tell each other their
  -- X-Octo-Version on the same channels (prefix "pfUIOcto", "V:1.2.3"); a
  -- higher one is kept in pfUI_init.octoupdate for the About page and its
  -- flashing NEW mark. pfUI's own "VERSION" message stays 5.5.4.
  local OCTO_PREFIX = "pfUIOcto"
  local function OctoNum(v)
    local _, _, a, b, c = string.find(tostring(v or ""), "^(%d+)%.?(%d*)%.?(%d*)")
    if not a then return 0 end
    return tonumber(a) * 1000000 + (tonumber(b) or 0) * 1000 + (tonumber(c) or 0)
  end
  pfUI.octoUpdate = {
    -- the link OctoLauncher takes (Addons > Add custom git addon); the About page's
    -- "OctoLauncher link" is the same one
    url = "https://github.com/bdot89/pfUI",
    Num = OctoNum,
    -- the newer version seen, or nil
    Newer = function()
      local seen = pfUI_init and pfUI_init.octoupdate
      if seen and OctoNum(seen) > OctoNum(pfUI.version.octo) then return seen end
    end,
  }
  local function OctoSend(chans)
    for _, chan in pairs(chans) do
      pcall(SendAddonMessage, OCTO_PREFIX, "V:" .. tostring(pfUI.version.octo), chan)
    end
  end

  -- (16 Nov 2026, user: "an ingame count for how many people are on running our pfui any version even past
  -- versions ... in the about page") Every pfUI Octo since 29 Oct says "V:<version>" under pfUIOcto at each
  -- loading screen and when a group grows; later ones also share under pfGN (gathering, 9 Nov), pfFT (flights),
  -- pfOctoTR (boats), pfAP (auction prices). Whoever sends any of them runs pfUI Octo. Addon messages only reach
  -- guild, group and battleground, so this counts the players you can hear, not the whole server.
  -- pfUI_cache.octousers[realm][name] = { v = version or nil, t = time() last heard }.
  -- New here: "Q" asks the others to say their version now (older versions ignore it, they only read "V:").
  local U = { session = {}, PREFIXES = { [OCTO_PREFIX] = true, pfGN = true, pfFT = true, pfOctoTR = true, pfAP = true } }
  pfUI.octoUsers = U
  function U.Store()
    pfUI_cache = pfUI_cache or {}
    pfUI_cache.octousers = pfUI_cache.octousers or {}
    local realm = GetRealmName and GetRealmName() or "?"
    pfUI_cache.octousers[realm] = pfUI_cache.octousers[realm] or {}
    return pfUI_cache.octousers[realm]
  end
  U.KEEP_DAYS, U.MAX = 30, 2000
  function U.Prune()
    local s = U.Store()
    local now, list = time(), {}
    for name, e in pairs(s) do
      if not e.t or now - e.t > U.KEEP_DAYS * 86400 then s[name] = nil else table.insert(list, { name, e.t }) end
    end
    if table.getn(list) > U.MAX then
      table.sort(list, function(a, b) return a[2] > b[2] end)
      for i = U.MAX + 1, table.getn(list) do s[list[i][1]] = nil end
    end
  end
  function U.Heard(name, version)
    if not name or name == "" then return end
    local _, _, short = string.find(name, "^([^%-]+)")
    name = short or name
    local s = U.Store()
    local e = s[name]
    if not e then
      e = {}
      s[name] = e
      -- (25 Nov 2026, code review: one entry for every name ever heard, never pruned) now and then: names not heard for
      -- U.KEEP_DAYS go, and the oldest beyond U.MAX
      U.newN = (U.newN or 0) + 1
      if U.newN >= 100 then U.newN = 0 U.Prune() end
    end
    e.t = time()
    if version then e.v = version end
    U.session[name] = GetTime()
  end
  -- names online right now that we can check: guild roster and group (true / false), else nil
  function U.OnlineCheck()
    local on = {}
    if IsInGuild and IsInGuild() and GetNumGuildMembers then
      for i = 1, GetNumGuildMembers(true) do
        local n, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
        if n then on[n] = online and true or false end
      end
    end
    for i = 1, GetNumRaidMembers() do
      local n, _, _, _, _, _, _, online = GetRaidRosterInfo(i)
      if n then on[n] = online and true or false end
    end
    for i = 1, GetNumPartyMembers() do
      local n = UnitName("party" .. i)
      if n then on[n] = UnitIsConnected("party" .. i) and true or false end
    end
    on[UnitName("player") or "?"] = true
    return on
  end
  -- online now / heard in 24 h / 7 days / ever, and the versions seen in the last 7 days
  function U.Counts()
    local s, now, on = U.Store(), time(), U.OnlineCheck()
    local c = { online = 0, day = 0, week = 0, ever = 0, versions = {}, list = {} }
    for name, e in pairs(s) do
      local age = now - (e.t or 0)
      local live = on[name]
      if live == nil then live = U.session[name] and (GetTime() - U.session[name]) < 1800 end
      -- (in the realm channel now: online, whatever the guild list says)
      if pfUI.realmChannel and pfUI.realmChannel.IsOnline(name) then live = true end
      c.ever = c.ever + 1
      if age < 86400 then c.day = c.day + 1 end
      if age < 604800 then
        c.week = c.week + 1
        local v = e.v or "?"
        c.versions[v] = (c.versions[v] or 0) + 1
      end
      if live then c.online = c.online + 1 end
      table.insert(c.list, { name = name, v = e.v, t = e.t or 0, live = live and true or nil })
    end
    table.sort(c.list, function(a, b)
      if (a.live and 1 or 0) ~= (b.live and 1 or 0) then return a.live ~= nil end
      if a.t ~= b.t then return a.t > b.t end
      return a.name < b.name
    end)
    return c
  end

  -- ---------------------------------------------------------------- the realm channel
  -- (23 Nov 2026, user: "show all players on the realm with same hidden channel as the arcade uses it should tell
  -- people to update in the popup ... they all join the channel once i login and push it out no matter what version")
  -- Addon messages never leave guild / group / battleground, so every pfUI Octo now joins OctoArcade's hidden realm
  -- channel at login (whether OctoArcade is on or not; Minigames > "Share on the realm channel" off = never) and says
  -- "OV1 <version> ?" once. Everyone in it is counted:
  --   * the channel's member list (ListChannelByName -> CHAT_MSG_CHANNEL_LIST) = who runs pfUI Octo online now, older
  --     versions too (OctoArcade has joined it since 1.2.16), asked after joining and every 5 minutes;
  --   * "OV1 <version>" = that player's version; OctoArcade's "OA1 / OA2" score lines = pfUI Octo, version unsaid.
  -- A newer version heard there opens the update window, as one heard in the guild does. The "?" asks for the newest:
  -- ONE player newer than the asker answers "OV1 <theirs>" 2-10 s later; anyone hearing an answer at least as new as
  -- their own stays quiet. Older versions read only their score lines, so they are told by guild and group as before.
  -- Nothing ever shows in chat: the lines, the join notices and the member list are kept out of every chat window.
  local RC = { NAME = "OctoArcade", q = {}, online = {} }
  pfUI.realmChannel = RC
  local lowerName = string.lower(RC.NAME)
  function RC.On() return not (C.minigames and C.minigames.realm == "0") end
  function RC.Id()
    local id = GetChannelName and GetChannelName(RC.NAME)
    if id and id ~= 0 then return id end
  end
  function RC.IsOurs(a9, a4)
    local n = string.lower(tostring(a9 or "") .. " " .. tostring(a4 or ""))
    return string.find(n, lowerName, 1, true) and true or nil
  end
  function RC.Join()
    if not RC.On() or not JoinChannelByName then return end
    if not RC.Id() then pcall(JoinChannelByName, RC.NAME) end
    for i = 1, (NUM_CHAT_WINDOWS or 7) do
      local cf = _G["ChatFrame" .. i]
      if cf and ChatFrame_RemoveChannel then pcall(ChatFrame_RemoveChannel, cf, RC.NAME) end
    end
  end
  function RC.Say(line)
    if line and RC.On() and RC.Id() and table.getn(RC.q) < 6 then table.insert(RC.q, line) end
  end
  function RC.Line(ask)
    return "OV1 " .. string.gsub(tostring(pfUI.version.octo), "[^%d%.]", "") .. (ask and " ?" or "")
  end
  -- the member list: who is in the channel now (each event may hold part of a long list)
  function RC.List()
    if not RC.On() or not RC.Id() or not ListChannelByName then return end
    RC.listAsked, RC.fresh = GetTime(), {}
    pcall(ListChannelByName, RC.NAME)
  end
  function RC.ReadList(text)
    if not RC.listAsked or GetTime() - RC.listAsked > 10 or type(text) ~= "string" then return end
    local n = 0
    for name in string.gfind(text, "[^,%s]+") do
      name = string.gsub(name, "^[%*@#]+", "")
      local _, _, short = string.find(name, "^([^%-]+)")
      name = short or name
      if string.find(name, "^[%a\128-\255]+$") then
        RC.fresh[name] = true
        U.Heard(name, nil)
        n = n + 1
      end
    end
    RC.online, RC.listAt = RC.fresh, GetTime()
    return n
  end
  -- a line said in the channel: version (or nil), and whether it asks for the newest
  function RC.Read(msg, from)
    if type(msg) ~= "string" or not from then return end
    local _, _, v, ask = string.find(msg, "^OV1 ([%d%.]+)(.*)$")
    if v then
      U.Heard(from, v)
      return v, string.find(ask or "", "?", 1, true) and true or nil
    end
    local head = string.sub(msg, 1, 4)
    if head == "OA1 " or head == "OA2 " then U.Heard(from, nil) end
  end
  -- planned answer to a "?": only newer than the asker, and only until someone at least as new answers
  function RC.Asked(theirs)
    if OctoNum(theirs) >= OctoNum(pfUI.version.octo) or RC.answerAt then return end
    if GetTime() - (RC.answered or -100) < 60 then return end
    RC.answerAt = GetTime() + 2 + math.random() * 8
  end
  function RC.HeardAnswer(v)
    if RC.answerAt and OctoNum(v) >= OctoNum(pfUI.version.octo) then RC.answerAt = nil RC.answered = GetTime() end
  end
  -- every half second from the updater: answer, send one waiting line (one every 1.5 s), refresh the list
  function RC.Tick(now)
    if RC.answerAt and now >= RC.answerAt then
      RC.answerAt, RC.answered = nil, now
      RC.Say(RC.Line(false))
    end
    if RC.q[1] and now >= (RC.sendAt or 0) then
      RC.sendAt = now + 1.5
      local line = table.remove(RC.q, 1)
      local id = RC.Id()
      if id then pcall(SendChatMessage, line, "CHANNEL", nil, id) end
    end
    if RC.listAt and now - RC.listAt > 300 then RC.List() end
  end
  -- online now, from the channel (fresh for 10 minutes)
  function RC.IsOnline(name)
    return RC.listAt and GetTime() - RC.listAt < 600 and RC.online[name] and true or nil
  end
  -- the channel never shows in a chat window
  local chatEvent = _G.ChatFrame_OnEvent
  if chatEvent then
    _G.ChatFrame_OnEvent = function(e)
      local ev2 = e or event
      if (ev2 == "CHAT_MSG_CHANNEL" or ev2 == "CHAT_MSG_CHANNEL_NOTICE" or ev2 == "CHAT_MSG_CHANNEL_JOIN"
          or ev2 == "CHAT_MSG_CHANNEL_LEAVE" or ev2 == "CHAT_MSG_CHANNEL_NOTICE_USER" or ev2 == "CHAT_MSG_CHANNEL_LIST")
          and RC.IsOurs(arg9, arg4) then
        return
      end
      return chatEvent(e)
    end
  end

  -- (17 Nov 2026, user: "a warning to people if they are outdated that pops up when they login ... a link they
  -- can copy and paste into the launcher ... what to do and what the new version offers from theirs ... neat tidy
  -- window not intrusive") A small window at the top of the screen once a session, out of combat.
  -- What's new: our own notes (updatenotes.lua, made from the README) can only know versions up to ours, so an
  -- older client asks "N:<its version>" where it heard the newer one, and one newer client answers with the
  -- titles of every version after it: "W^<version>^title^title" (no | in addon messages).
  local UP = pfUI.octoUpdate
  UP.heard = {}                -- heard[version] = { titles } from newer clients
  local wq, wsent = {}, {}     -- answers waiting to be sent; wsent[chan] = when one was sent / heard there
  local askedNotes = {}        -- askedNotes[chan] = when we asked there

  function UP.Clean(s)
    return (string.gsub(tostring(s or ""), "[|%^]", ""))
  end

  -- versions after `have`, newest first: { { v, items = { { title, text } } } }, own notes + heard titles
  function UP.NotesSince(have)
    local out, byv = {}, {}
    local mine = UP.Num(have)
    for _, e in ipairs(pfUI.octoNotes or {}) do
      if UP.Num(e[1]) > mine then
        local entry = { v = e[1], items = {} }
        for _, it in ipairs(e[2] or {}) do table.insert(entry.items, { it[1], it[2] }) end
        byv[e[1]] = entry
        table.insert(out, entry)
      end
    end
    for v, titles in pairs(UP.heard) do
      if UP.Num(v) > mine then
        local entry = byv[v]
        if not entry then
          entry = { v = v, items = {} }
          byv[v] = entry
          table.insert(out, entry)
        end
        for _, t in ipairs(titles) do
          local known
          for _, it in ipairs(entry.items) do if it[1] == t then known = true end end
          if not known then table.insert(entry.items, { t }) end
        end
      end
    end
    table.sort(out, function(a, b) return UP.Num(a.v) > UP.Num(b.v) end)
    return out
  end

  -- messages telling a pfUI Octo on version `have` what came after it (at most 6 versions, 240 chars each)
  function UP.NoteMessages(have)
    local msgs = {}
    local list = UP.NotesSince(have)
    for i = 1, math.min(6, table.getn(list)) do
      local e = list[i]
      local head = "W^" .. UP.Clean(e.v)
      local msg = head
      for _, it in ipairs(e.items) do
        local t = UP.Clean(it[1])
        if string.len(t) > 90 then t = string.sub(t, 1, 87) .. "..." end
        if string.len(msg) + 1 + string.len(t) > 240 then
          table.insert(msgs, msg)
          msg = head
        end
        msg = msg .. "^" .. t
      end
      if msg ~= head then table.insert(msgs, msg) end
    end
    return msgs
  end

  -- (25 Nov 2026, code review: anyone on the realm could open the update window on every Octo client with a made-up
  -- "OV1 99.0.0", and one guild member could write its "what's new" text.) A newer version only counts once
  -- UP.VOUCH different players said it, and only a likely next one (same major, at most one minor ahead: UP.Likely).
  -- Notes lines from others show only when UP.LINE_VOUCH players sent the same line; colour codes go, and a line with
  -- a web address is dropped (the window already shows the real link).
  UP.VOUCH, UP.LINE_VOUCH = 3, 2
  UP.vouch, UP.lineBy = {}, {}
  function UP.Likely(v)
    local _, _, a, b = string.find(tostring(v or ""), "^(%d+)%.(%d+)")
    local _, _, oa, ob = string.find(tostring(pfUI.version.octo or ""), "^(%d+)%.(%d+)")
    if not (a and oa) then return false end
    return tonumber(a) == tonumber(oa) and tonumber(b) <= tonumber(ob) + 1
  end
  -- true once enough different players said this newer version
  function UP.Vouch(v, from)
    if not v or not from or UP.Num(v) <= UP.Num(pfUI.version.octo) or not UP.Likely(v) then return false end
    local by = UP.vouch[v]
    if not by then by = { n = 0 } UP.vouch[v] = by end
    if not by[from] then by[from] = true by.n = by.n + 1 end
    return by.n >= UP.VOUCH
  end
  function UP.ReadNotes(text, from)
    local parts = {}
    for p in string.gfind(text, "[^%^]+") do table.insert(parts, p) end
    if parts[1] ~= "W" or not parts[2] then return end
    local v = parts[2]
    if UP.Num(v) <= UP.Num(pfUI.version.octo) or not UP.Likely(v) then return end
    local list = UP.heard[v] or {}
    UP.heard[v] = list
    local by = UP.lineBy[v] or {}
    UP.lineBy[v] = by
    for i = 3, table.getn(parts) do
      local line = string.sub(string.gsub(string.gsub(parts[i], "|c%x%x%x%x%x%x%x%x", ""), "|[rH]", ""), 1, 140)
      local low = string.lower(line)
      if line ~= "" and not string.find(low, "http", 1, true) and not string.find(low, "www.", 1, true)
        and not string.find(low, ".com", 1, true) then
        local who = by[line] or { n = 0 }
        by[line] = who
        if from and not who[from] then who[from] = true who.n = who.n + 1 end
        local known
        for _, t in ipairs(list) do if t == line then known = true end end
        if not known and who.n >= UP.LINE_VOUCH and table.getn(list) < 20 then table.insert(list, line) end
      end
    end
    if UP.frame and UP.frame:IsShown() then UP.Fill() end
    return v
  end

  -- ask for the notes where a newer version was heard, once a minute per channel at most
  function UP.Ask(chan)
    if not chan or GetTime() - (askedNotes[chan] or -100) < 60 then return end
    askedNotes[chan] = GetTime()
    pcall(SendAddonMessage, OCTO_PREFIX, "N:" .. tostring(pfUI.version.octo), chan)
  end

  -- someone older asked: answer after 1-4 s unless another newer client answered there first
  function UP.Asked(chan, have)
    if not chan or UP.Num(have) <= 0 or UP.Num(have) >= UP.Num(pfUI.version.octo) then return end
    if wq[chan] or GetTime() - (wsent[chan] or -100) < 60 then return end
    wq[chan] = { at = GetTime() + 1 + math.random() * 3, have = have }
  end

  -- runs from the updater's OnUpdate
  function UP.SendWaiting()
    for chan, w in pairs(wq) do
      if w.msgs then
        if GetTime() >= w.at then
          local m = table.remove(w.msgs, 1)
          if m then pcall(SendAddonMessage, OCTO_PREFIX, m, chan) end
          w.at = GetTime() + .3
          if not w.msgs[1] then wq[chan] = nil end
        end
      elseif GetTime() >= w.at then
        wsent[chan] = GetTime()
        w.msgs = UP.NoteMessages(w.have)
        if not w.msgs[1] then wq[chan] = nil end
      end
    end
  end

  -- the window -------------------------------------------------------------
  local function Font(parent, size, r, g, b)
    local t = parent:CreateFontString(nil, "OVERLAY")
    t:SetFont(pfUI.font_default, size, "")
    t:SetShadowColor(0, 0, 0, 1)
    t:SetShadowOffset(1, -1)
    t:SetTextColor(r or 1, g or 1, b or 1)
    t:SetJustifyH("LEFT")
    return t
  end
  local function Accent()
    if pfUI.api.GetAccentColor then
      local ok, r, g, b = pcall(pfUI.api.GetAccentColor)
      if ok and r then return r, g, b end
    end
    return .35, .7, 1
  end
  local function Button(parent, text, w, r, g, b)
    local bt = CreateFrame("Button", nil, parent)
    bt:SetWidth(w)
    bt:SetHeight(22)
    bt:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8", edgeFile = "Interface\\BUTTONS\\WHITE8X8", edgeSize = 1 })
    bt:SetBackdropColor(r * .18, g * .18, b * .18, 1)
    bt:SetBackdropBorderColor(r * .8, g * .8, b * .8, 1)
    bt.text = Font(bt, 11, r + (1 - r) * .5, g + (1 - g) * .5, b + (1 - b) * .5)
    bt.text:SetPoint("CENTER", 0, 0)
    bt.text:SetJustifyH("CENTER")
    bt.text:SetText(text)
    bt:SetScript("OnEnter", function() this:SetBackdropColor(r * .35, g * .35, b * .35, 1) end)
    bt:SetScript("OnLeave", function() this:SetBackdropColor(r * .18, g * .18, b * .18, 1) GameTooltip:Hide() end)
    return bt
  end

  local W_WIDTH, MAXLINES = 400, 10

  function UP.Build()
    if UP.frame then return UP.frame end
    local ar, ag, ab = Accent()
    local f = CreateFrame("Frame", "pfOctoUpdate", UIParent)
    UP.frame = f
    f:SetWidth(W_WIDTH)
    f:SetHeight(300)
    f:SetPoint("TOP", UIParent, "TOP", 0, -90)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    f:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8", edgeFile = "Interface\\BUTTONS\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(.05, .055, .065, .94)
    f:SetBackdropBorderColor(ar * .7, ag * .7, ab * .7, 1)
    table.insert(UISpecialFrames, "pfOctoUpdate")

    local bar = f:CreateTexture(nil, "ARTWORK")
    bar:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    bar:SetVertexColor(ar, ag, ab, .9)
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("TOPRIGHT", -1, -1)
    bar:SetHeight(2)

    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
    icon:SetTexCoord(.08, .92, .08, .92)
    icon:SetWidth(28)
    icon:SetHeight(28)
    icon:SetPoint("TOPLEFT", 12, -12)

    f.title = Font(f, 15, ar + (1 - ar) * .3, ag + (1 - ag) * .3, ab + (1 - ab) * .3)
    f.title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 0)
    f.title:SetText(T["A new pfUI Octo is out"])
    f.versions = Font(f, 11, .75, .77, .8)
    f.versions:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 10, 0)

    local close = CreateFrame("Button", nil, f)
    close:SetWidth(20)
    close:SetHeight(20)
    close:SetPoint("TOPRIGHT", -6, -6)
    close.text = Font(close, 14, .6, .62, .66)
    close.text:SetPoint("CENTER", 0, 0)
    close.text:SetText("x")
    close:SetScript("OnEnter", function() this.text:SetTextColor(1, .35, .35) end)
    close:SetScript("OnLeave", function() this.text:SetTextColor(.6, .62, .66) end)
    close:SetScript("OnClick", function() f:Hide() end)

    -- how to update
    local how = Font(f, 12, ar, ag, ab)
    how:SetPoint("TOPLEFT", 14, -54)
    how:SetText(T["How to update"])
    f.steps = Font(f, 11, .88, .89, .92)
    f.steps:SetPoint("TOPLEFT", how, "BOTTOMLEFT", 0, -4)
    f.steps:SetWidth(W_WIDTH - 28)
    f.steps:SetText("|cffffd24d1.|r " .. T["Copy the link below (Copy, or click it and press Ctrl+C)."] .. "\n"
      .. "|cffffd24d2.|r " .. T["OctoLauncher: Addons > Add custom git addon, paste it, add."] .. "\n"
      .. "|cffffd24d3.|r " .. T["The launcher installs it and keeps it up to date from then on. Restart the game after."])

    local box = CreateFrame("EditBox", "pfOctoUpdateLink", f)
    f.box = box
    box:SetHeight(22)
    box:SetPoint("TOPLEFT", f.steps, "BOTTOMLEFT", 0, -8)
    box:SetPoint("RIGHT", f, "RIGHT", -96, 0)
    box:SetAutoFocus(false)
    box:SetFontObject(GameFontWhite)
    box:SetFont(pfUI.font_default, 12, "")
    box:SetTextInsets(6, 6, 0, 0)
    box:SetBackdrop({ bgFile = "Interface\\BUTTONS\\WHITE8X8", edgeFile = "Interface\\BUTTONS\\WHITE8X8", edgeSize = 1 })
    box:SetBackdropColor(0, 0, 0, .6)
    box:SetBackdropBorderColor(ar * .8, ag * .8, ab * .8, 1)
    box:SetText(UP.url)
    box:SetScript("OnTextChanged", function() if this:GetText() ~= UP.url then this:SetText(UP.url) this:HighlightText() end end)
    box:SetScript("OnEditFocusGained", function() this:HighlightText() end)
    box:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    box:SetScript("OnEnterPressed", function() this:ClearFocus() end)

    local copy = Button(f, T["Copy"], 74, .25, .85, .47)
    copy:SetPoint("LEFT", box, "RIGHT", 8, 0)
    copy:SetScript("OnClick", function()
      local lc = pfUI.api.libclient
      if lc and lc.Copy and lc.Copy(UP.url) then
        f.copied:SetText("|cff40d977" .. T["Copied - now paste it in the launcher."] .. "|r")
      else
        box:SetFocus()
        box:HighlightText()
        f.copied:SetText("|cffffd24d" .. T["Selected - press Ctrl+C, then paste it in the launcher."] .. "|r")
      end
    end)
    f.copied = Font(f, 10, .6, .62, .66)
    f.copied:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -4)
    f.copied:SetText(T["Already added it? The launcher's Update button gets the new version."])

    -- what's new
    local rule = f:CreateTexture(nil, "ARTWORK")
    rule:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    rule:SetVertexColor(1, 1, 1, .08)
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", f.copied, "BOTTOMLEFT", 0, -10)
    rule:SetPoint("RIGHT", f, "RIGHT", -14, 0)
    f.newHead = Font(f, 12, ar, ag, ab)
    f.newHead:SetPoint("TOPLEFT", rule, "BOTTOMLEFT", 0, -8)
    f.lines = {}
    for i = 1, MAXLINES do
      local l = CreateFrame("Button", nil, f)
      l:SetHeight(15)
      l:SetPoint("LEFT", f, "LEFT", 14, 0)
      l:SetPoint("RIGHT", f, "RIGHT", -14, 0)
      if i == 1 then l:SetPoint("TOP", f.newHead, "BOTTOM", 0, -4) else l:SetPoint("TOP", f.lines[i - 1], "BOTTOM", 0, 0) end
      l.text = Font(l, 11, .9, .91, .93)
      l.text:SetPoint("LEFT", 0, 0)
      l.text:SetPoint("RIGHT", 0, 0)
      l:SetScript("OnEnter", function()
        if not this.tip then return end
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText(this.tipTitle or "", 1, 1, 1)
        GameTooltip:AddLine(this.tip, .8, .82, .86, 1)
        GameTooltip:Show()
      end)
      l:SetScript("OnLeave", function() GameTooltip:Hide() end)
      f.lines[i] = l
    end
    f.more = Font(f, 10, .6, .62, .66)

    -- bottom buttons
    local later = Button(f, T["Remind me later"], 130, .55, .58, .62)
    later:SetPoint("BOTTOMLEFT", 14, 12)
    later:SetScript("OnClick", function() f:Hide() end)
    later:SetScript("OnEnter", function()
      this:SetBackdropColor(.55 * .35, .58 * .35, .62 * .35, 1)
      GameTooltip:SetOwner(this, "ANCHOR_TOP")
      GameTooltip:SetText(T["Shows again at your next login."], 1, 1, 1)
      GameTooltip:Show()
    end)
    f.skip = Button(f, T["Don't show for this version"], 190, .9, .3, .3)
    f.skip:SetPoint("BOTTOMRIGHT", -14, 12)
    f.skip:SetScript("OnClick", function()
      pfUI_init.octoupdateskip = UP.Newer()
      f:Hide()
    end)
    f.skip:SetScript("OnEnter", function()
      this:SetBackdropColor(.9 * .35, .3 * .35, .3 * .35, 1)
      GameTooltip:SetOwner(this, "ANCHOR_TOP")
      GameTooltip:SetText(T["Quiet until an even newer version is out."], 1, 1, 1)
      GameTooltip:AddLine(T["The About page still shows the link. Switch the window off: Settings > Scale, profiles and look."], .8, .82, .86, 1)
      GameTooltip:Show()
    end)
    f:Hide()
    return f
  end

  -- fill the window for the newest version heard; also used when notes come in while it shows
  function UP.Fill()
    local f = UP.Build()
    local newer = UP.Newer() or pfUI.version.octo
    f.versions:SetText(string.format(T["You have %s  -  %s is out"], "|cffff6060" .. tostring(pfUI.version.octo) .. "|r",
      "|cff40d977" .. tostring(newer) .. "|r"))
    local list = UP.NotesSince(pfUI.version.octo)
    f.newHead:SetText(table.getn(list) > 0 and string.format(T["What's new since %s"], pfUI.version.octo) or T["What's new"])
    -- headings + items, at most MAXLINES rows
    local rows, total = {}, 0
    for _, e in ipairs(list) do
      table.insert(rows, { head = e.v })
      for _, it in ipairs(e.items) do
        total = total + 1
        table.insert(rows, { title = it[1], text = it[2], v = e.v })
      end
    end
    local shown, items = 0, 0
    for i = 1, MAXLINES do
      local l, r = f.lines[i], rows[i]
      -- never end the list on a heading
      if r and r.head and (not rows[i + 1] or i == MAXLINES) then r = nil end
      if r then
        shown = i
        if r.head then
          l.text:SetText("|cff8a8f99v" .. r.head .. "|r")
          l.tip, l.tipTitle = nil, nil
        else
          items = items + 1
          l.text:SetText("|cffffd24d-|r " .. r.title)
          l.tip, l.tipTitle = r.text, r.title
        end
        l:Show()
      else
        l:Hide()
      end
    end
    f.more:ClearAllPoints()
    local last = shown > 0 and f.lines[shown] or f.newHead
    f.more:SetPoint("TOPLEFT", last, "BOTTOMLEFT", shown > 0 and 0 or 0, -4)
    f.more:SetWidth(W_WIDTH - 28)
    if total == 0 then
      f.more:SetText(T["Not known yet: it fills in as soon as someone on the new version is in your guild or group. The home page lists it too."])
    elseif total > items then
      f.more:SetText(string.format(T["... and %d more. Hover a line for more, the home page has it all."], total - items))
    else
      f.more:SetText(T["Hover a line for more."])
    end
    -- height: header and link area (the steps may wrap), the rows, the line under them, the buttons
    local stepsH = tonumber(f.steps:GetHeight()) or 42
    local moreH = tonumber(f.more:GetHeight()) or 14
    if stepsH < 30 or stepsH > 120 then stepsH = 42 end
    if moreH < 10 or moreH > 60 then moreH = 14 end
    f:SetHeight(math.floor(54 + 18 + stepsH + 8 + 22 + 16 + 11 + 22 + shown * 15 + 4 + moreH + 46))
    f.skip.text:SetText(string.format(T["Don't show for %s"], tostring(newer)))
  end

  function UP.Show()
    UP.Fill()
    UP.frame:Show()
  end

  -- may the window open by itself now?
  function UP.Wanted()
    if C.global and C.global.updatepopup == "0" then return end
    local newer = UP.Newer()
    if not newer or UP.shownThis then return end
    if pfUI_init.octoupdateskip and UP.Num(pfUI_init.octoupdateskip) >= UP.Num(newer) then return end
    return true
  end
  function UP.Check()
    if not UP.Wanted() then return end
    if UnitAffectingCombat and UnitAffectingCombat("player") then return end
    UP.shownThis = true
    UP.Show()
  end

  _G.SLASH_PFOCTOUPDATE1 = "/octoupdate"
  _G.SlashCmdList["PFOCTOUPDATE"] = function() UP.Show() end

  pfUI.updater = CreateFrame("Frame")
  pfUI.updater:RegisterEvent("CHAT_MSG_ADDON")
  pfUI.updater:RegisterEvent("PLAYER_ENTERING_WORLD")
  pfUI.updater:RegisterEvent("PARTY_MEMBERS_CHANGED")
  -- answers to "Q" wait 1-4 s (so a guild does not answer all at once), one per channel each 30 s
  local answer, answered = {}, {}
  pfUI.updater:RegisterEvent("PLAYER_REGEN_ENABLED")
  pfUI.updater:RegisterEvent("CHAT_MSG_CHANNEL")
  pfUI.updater:RegisterEvent("CHAT_MSG_CHANNEL_LIST")
  -- a newer version heard anywhere: kept for the About page, and the update window when it may open
  function UP.Saw(v, from)
    if not v or OctoNum(v) <= OctoNum(pfUI.version.octo) then return end
    if not UP.Vouch(v, from) then return end
    if OctoNum(v) > OctoNum(pfUI_init.octoupdate) then pfUI_init.octoupdate = v end
    local up = pfUI.updater
    if UP.Wanted() then up.popAt = math.max(GetTime() + 3, (up.loginAt or 0) + 6) end
  end
  pfUI.updater:SetScript("OnUpdate", function()
    UP.SendWaiting()
    -- the realm channel: joined 20 s after the first loading screen, our version said 5 s later, the list asked 3 s
    -- after that
    local now = GetTime()
    if this.rcAt and now >= this.rcAt then
      local step = this.rcStep or 1
      if step == 1 then RC.Join() this.rcAt, this.rcStep = now + 5, 2
      elseif step == 2 then RC.Say(RC.Line(true)) this.rcAt, this.rcStep = now + 3, 3
      else RC.List() this.rcAt = nil end
    end
    if (this.rcTick or 0) <= now then
      this.rcTick = now + .25
      RC.Tick(now)
    end
    -- the update window: first look 6 s after the first loading screen, then whenever a newer one is heard
    if this.popAt and GetTime() >= this.popAt then
      this.popAt = nil
      UP.Check()
    end
    for chan, at in pairs(answer) do
      if GetTime() >= at then
        answer[chan] = nil
        answered[chan] = GetTime()
        pcall(SendAddonMessage, OCTO_PREFIX, "V:" .. tostring(pfUI.version.octo), chan)
      end
    end
  end)
  pfUI.updater:SetScript("OnEvent", function()
    if event == "CHAT_MSG_CHANNEL" or event == "CHAT_MSG_CHANNEL_LIST" then
      if not RC.IsOurs(arg9, arg4) then return end
      if event == "CHAT_MSG_CHANNEL_LIST" then RC.ReadList(arg1) return end
      if arg2 == UnitName("player") then return end
      local v, ask = RC.Read(arg1, arg2)
      if v then
        UP.Saw(v, arg2)
        if ask then RC.Asked(v) else RC.HeardAnswer(v) end
      end
      return
    end
    if event == "CHAT_MSG_ADDON" and U.PREFIXES[arg1 or ""] then
      local me = UnitName("player")
      if arg4 and arg4 ~= me then
        local _, _, v = string.find(arg2 or "", "^V:(.+)$")
        U.Heard(arg4, arg1 == OCTO_PREFIX and v or nil)
        if arg1 == OCTO_PREFIX and arg2 == "Q" and arg3 and not answer[arg3]
          and GetTime() - (answered[arg3] or -100) > 30 then
          answer[arg3] = GetTime() + 1 + math.random() * 3
        end
      end
      if arg1 ~= OCTO_PREFIX then return end
      if arg4 == me then return end
      local msg = arg2 or ""
      -- an older pfUI Octo asks what came after its version / a newer one tells us
      local _, _, have = string.find(msg, "^N:(.+)$")
      if have then UP.Asked(arg3, have) return end
      if string.sub(msg, 1, 2) == "W^" then
        if arg3 then wsent[arg3] = GetTime() wq[arg3] = nil end
        UP.ReadNotes(msg, arg4)
        return
      end
      local _, _, v = string.find(msg, "^V:(.+)$")
      if v and OctoNum(v) > OctoNum(pfUI.version.octo) then
        -- (the notes are asked for at once; the version counts once enough players said it: UP.Saw)
        if UP.Likely(v) then UP.Ask(arg3) end
        UP.Saw(v, arg4)
      end
      return
    end

    if event == "PLAYER_REGEN_ENABLED" then
      if UP.Wanted() then this.popAt = GetTime() + 2 end
      return
    end

    if event == "PARTY_MEMBERS_CHANGED" then
      local size = GetNumRaidMembers() > 0 and GetNumRaidMembers() or GetNumPartyMembers()
      if (this.octogroup or 0) < size then OctoSend(groupchannels) end
      this.octogroup = size
    end

    if event == "PLAYER_ENTERING_WORLD" then
      OctoSend(loginchannels)
      U.Heard(UnitName("player"), pfUI.version.octo)
      -- once a session: ask who else runs it (guild, and the group / battleground you are in)
      if not this.asked then
        this.asked = true
        for _, chan in pairs(loginchannels) do pcall(SendAddonMessage, OCTO_PREFIX, "Q", chan) end
        if GuildRoster then GuildRoster() end
      end
      if not this.loginAt then
        this.loginAt = GetTime()
        this.popAt = GetTime() + 6
        this.rcAt = GetTime() + 20
      end
      local newer = pfUI.octoUpdate.Newer()
      if newer and not this.octoshown then
        this.octoshown = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff33b3ffpfUI Octo|r: " .. string.format(T["version %s is out (you have %s)."], newer, pfUI.version.octo)
          .. " " .. T["Type /octoupdate (or open /pfui > About) for the link for the OctoWoW launcher."])
      end
    end

    if event == "PARTY_MEMBERS_CHANGED" then
      local groupsize = GetNumRaidMembers() > 0 and GetNumRaidMembers() or GetNumPartyMembers() > 0 and GetNumPartyMembers() or 0
      if ( this.group or 0 ) < groupsize then
        for _, chan in pairs(groupchannels) do
          SendAddonMessage("pfUI", "VERSION:" .. localversion, chan)
        end
      end
      this.group = groupsize
    end

    if event == "PLAYER_ENTERING_WORLD" then
      -- (pfUI Octo only tells about its own versions: Shagu's "new version at
      -- shagu.org" is never shown - user, 31 Oct 2026)
      pfUI_init.updateavailable = nil

      for _, chan in pairs(loginchannels) do
        SendAddonMessage("pfUI", "VERSION:" .. localversion, chan)
      end
    end
  end)
end)
