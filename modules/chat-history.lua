pfUI:RegisterModule("chat-history", "vanilla:tbc", function ()
  -- pfUI Octo :: chat history (23 Nov 2026; user: "chat history possible with a possible 30day roll ... open up old
  -- whispers in a drop down menu it shows history of whispers. We can look into guild chat history etc and raid chat
  -- easy make a really good navigation system ... use the bar we had and add to it").
  -- Every whisper (in and out), guild, officer, party, raid (and raid warnings), battleground and - if wanted - say
  -- and yell line is kept for C.chat.history.days (30) days, per character, in pfUI_cache.chathistory["name-realm"].
  -- The whisper window (chat-whispers.lua) shows it: old whispers in a menu, a channel row for guild / raid / ...
  -- A line is one string "time<TAB>who<TAB>text" (who for whispers: "<" + them in, ">" + them out), so 30 days of a
  -- busy guild stays small; every kind also has a most-lines cap (C.chat.history.max) on top of the days.
  local CH = {}
  pfUI.chatHistory = CH
  local function S() return C.chat.history end
  local ME = UnitName("player")

  -- the kinds kept: key, name, the events that feed it, the chat type to answer in, a colour
  CH.KINDS = {
    { key = "guild",   name = "Guild",        short = "G", events = { "CHAT_MSG_GUILD" }, send = "GUILD", color = { .25, 1, .25 } },
    { key = "officer", name = "Officer",      short = "O", events = { "CHAT_MSG_OFFICER" }, send = "OFFICER", color = { .25, .75, .25 } },
    { key = "party",   name = "Party",        short = "P", events = { "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER" }, send = "PARTY", color = { .67, .67, 1 } },
    { key = "raid",    name = "Raid",         short = "R", events = { "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING" },
      send = "RAID", color = { 1, .5, 0 } },
    { key = "bg",      name = "Battleground", short = "B", events = { "CHAT_MSG_BATTLEGROUND", "CHAT_MSG_BATTLEGROUND_LEADER" },
      send = "BATTLEGROUND", color = { 1, .5, 0 } },
    { key = "say",     name = "Say and yell", short = "S", events = { "CHAT_MSG_SAY", "CHAT_MSG_YELL" }, send = "SAY", color = { 1, 1, 1 } },
  }
  CH.BYKEY, CH.BYEVENT = {}, {}
  for _, k in ipairs(CH.KINDS) do
    CH.BYKEY[k.key] = k
    for _, e in ipairs(k.events) do CH.BYEVENT[e] = k end
  end

  function CH.Store()
    pfUI_cache.chathistory = pfUI_cache.chathistory or {}
    local key = (ME or "?") .. "-" .. (GetRealmName and GetRealmName() or "")
    local s = pfUI_cache.chathistory[key]
    if not s then
      s = { w = {} }
      pfUI_cache.chathistory[key] = s
    end
    s.w = s.w or {}
    return s
  end
  -- is a kind kept (whispers: "whisper")
  function CH.On(kind)
    if S().enable == "0" then return false end
    return S()[kind] ~= "0"
  end

  -- one line in and out of its string
  function CH.Pack(t, who, text)
    -- (gsub's second return - the count - must not reach the concatenation: brackets)
    local w = (string.gsub(who or "", "\t", " "))
    local x = (string.gsub(text or "", "\t", " "))
    return tostring(math.floor(tonumber(t) or 0)) .. "\t" .. w .. "\t" .. x
  end
  function CH.Unpack(line)
    local _, _, t, who, text = string.find(line or "", "^(%d+)\t([^\t]*)\t(.*)$")
    return tonumber(t), who, text
  end

  local function Cap(list, max)
    local n = table.getn(list)
    if n <= max then return list end
    local out = {}
    for i = n - max + 1, n do table.insert(out, list[i]) end
    return out
  end
  -- the lines of a kind (or of one person's whispers)
  function CH.Lines(kind, name)
    local s = CH.Store()
    if kind == "whisper" then return s.w[name] or {} end
    return s[kind] or {}
  end
  -- keep a line: kind = a CH.KINDS key, or "whisper" with name = them and dir "in" / "out"
  function CH.Add(kind, who, text, t, name, dir)
    if not text or text == "" then return end
    if not CH.On(kind) then return end
    local s = CH.Store()
    t = t or time()
    local list
    if kind == "whisper" then
      if not name then return end
      s.w[name] = s.w[name] or {}
      list = s.w[name]
      who = (dir == "out" and ">" or "<") .. name
    else
      s[kind] = s[kind] or {}
      list = s[kind]
    end
    table.insert(list, CH.Pack(t, who, text))
    -- (over the cap by a tenth: trimmed at once; the days are trimmed at login)
    local max = tonumber(S().max) or 4000
    if kind == "whisper" then max = math.max(50, math.floor(max / 4)) end
    if table.getn(list) > max * 1.1 then
      if kind == "whisper" then s.w[name] = Cap(list, max) else s[kind] = Cap(list, max) end
    end
    if CH.onAdd then CH.onAdd(kind, who, text, t, name, dir) end
  end

  -- lines older than the days go, and every list keeps at most its cap
  function CH.Prune(now)
    local s = CH.Store()
    local cut = (now or time()) - (tonumber(S().days) or 30) * 86400
    local max = tonumber(S().max) or 4000
    local function Trim(list, m)
      local out = {}
      for _, line in ipairs(list or {}) do
        local t = CH.Unpack(line)
        if t and t >= cut then table.insert(out, line) end
      end
      return Cap(out, m)
    end
    for _, k in ipairs(CH.KINDS) do
      if s[k.key] then s[k.key] = Trim(s[k.key], max) end
    end
    for name, list in pairs(s.w) do
      local kept = Trim(list, math.max(50, math.floor(max / 4)))
      if table.getn(kept) == 0 then s.w[name] = nil else s.w[name] = kept end
    end
  end

  -- everyone whispered with, newest first: { { name, t = last time, n = lines } }
  function CH.People()
    local out = {}
    for name, list in pairs(CH.Store().w) do
      local n = table.getn(list)
      if n > 0 then
        local t = CH.Unpack(list[n])
        table.insert(out, { name = name, t = t or 0, n = n })
      end
    end
    table.sort(out, function(a, b) return a.t > b.t end)
    return out
  end

  -- the old whispers kept by the whisper window before this (pfUI_cache.whispers) come over once
  function CH.ImportWhispers()
    local s = CH.Store()
    if s.importedWhispers then return 0 end
    s.importedWhispers = time()
    local old = pfUI_cache.whispers and pfUI_cache.whispers[(ME or "?") .. "-" .. (GetRealmName and GetRealmName() or "")]
    if not old then return 0 end
    local n = 0
    for name, list in pairs(old) do
      if type(list) == "table" and not s.w[name] then
        s.w[name] = {}
        for _, e in ipairs(list) do
          if e.msg and (e.dir == "in" or e.dir == "out") then
            table.insert(s.w[name], CH.Pack(e.t or 0, (e.dir == "out" and ">" or "<") .. name, e.msg))
            n = n + 1
          end
        end
      end
    end
    return n
  end

  -- ---------------------------------------------------------------- events

  local ev = CreateFrame("Frame", "pfChatHistory")
  CH.events = ev
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:RegisterEvent("CHAT_MSG_WHISPER")
  ev:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
  for e in pairs(CH.BYEVENT) do ev:RegisterEvent(e) end
  function CH.OnEvent(evt, msg, sender)
    if evt == "PLAYER_ENTERING_WORLD" then
      if not CH.pruned then
        CH.pruned = true
        CH.ImportWhispers()
        CH.Prune()
      end
      return
    end
    if evt == "CHAT_MSG_WHISPER" then
      CH.Add("whisper", nil, msg, nil, sender, "in")
    elseif evt == "CHAT_MSG_WHISPER_INFORM" then
      CH.Add("whisper", nil, msg, nil, sender, "out")
    else
      local k = CH.BYEVENT[evt]
      if k then
        -- (a raid warning keeps its tag)
        if evt == "CHAT_MSG_RAID_WARNING" then msg = "[Warning] " .. (msg or "") end
        if evt == "CHAT_MSG_YELL" then msg = "[Yell] " .. (msg or "") end
        CH.Add(k.key, sender, msg)
      end
    end
  end
  ev:SetScript("OnEvent", function() CH.OnEvent(event, arg1, arg2) end)
end)
