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
    url = "https://github.com/bdot89/pfUI-Octo",
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
  function U.Heard(name, version)
    if not name or name == "" then return end
    local _, _, short = string.find(name, "^([^%-]+)")
    name = short or name
    local s = U.Store()
    local e = s[name] or {}
    s[name] = e
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

  pfUI.updater = CreateFrame("Frame")
  pfUI.updater:RegisterEvent("CHAT_MSG_ADDON")
  pfUI.updater:RegisterEvent("PLAYER_ENTERING_WORLD")
  pfUI.updater:RegisterEvent("PARTY_MEMBERS_CHANGED")
  -- answers to "Q" wait 1-4 s (so a guild does not answer all at once), one per channel each 30 s
  local answer, answered = {}, {}
  pfUI.updater:SetScript("OnUpdate", function()
    for chan, at in pairs(answer) do
      if GetTime() >= at then
        answer[chan] = nil
        answered[chan] = GetTime()
        pcall(SendAddonMessage, OCTO_PREFIX, "V:" .. tostring(pfUI.version.octo), chan)
      end
    end
  end)
  pfUI.updater:SetScript("OnEvent", function()
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
      local _, _, v = string.find(arg2 or "", "^V:(.+)$")
      if v and OctoNum(v) > OctoNum(pfUI.version.octo) and OctoNum(v) > OctoNum(pfUI_init.octoupdate) then
        pfUI_init.octoupdate = v
      end
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
      local newer = pfUI.octoUpdate.Newer()
      if newer and not this.octoshown then
        this.octoshown = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff33b3ffpfUI Octo|r: " .. string.format(T["version %s is out (you have %s)."], newer, pfUI.version.octo)
          .. " " .. T["Open /pfui > About to copy the link for the OctoWoW launcher."])
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
