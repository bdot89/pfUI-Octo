pfUI:RegisterModule("chat-plus", "vanilla:tbc", function ()
  -- pfUI Octo :: chat phase 2 (docs\chat-spec.md, 23 Oct 2026; Prat's
  -- features as the model - Prat is GPL-3, its option names were read,
  -- nothing copied). On top of pfUI's chat:
  --   before pfUI's formatting (each window's AddMessage): hidden words,
  --     repeated lines dropped (spam throttle), your own channel tags
  --   after it (HookAddMessage, the game's own): player levels next to
  --     names, your name and your words highlighted, a buffer for /find
  --   events: a sound per kind of message, your name / a word: sound and a
  --     popup, auto-invite on a keyword whisper
  --   Alt-click a name = invite; Shift + wheel = top / bottom, Ctrl + wheel
  --     = a page; /tt (tell target), /find, /clear
  -- Settings C.chat.plus. Not on 1.12: item icons in links (no |T escapes).
  local P = {}
  pfUI.chatPlus = P
  local function S() return C.chat.plus end
  local ME = UnitName("player")

  -- ---------------------------------------------------------------- helpers

  local function Lower(s) return string.lower(s or "") end
  -- a word list: "Trade=T, World=W" or "boss, loot" -> table
  function P.List(str)
    local out = {}
    for part in string.gfind(str or "", "[^,]+") do
      part = string.gsub(string.gsub(part, "^%s+", ""), "%s+$", "")
      if part ~= "" then table.insert(out, part) end
    end
    return out
  end
  function P.Tags()
    local out = {}
    for _, e in ipairs(P.List(S().tags)) do
      local _, _, name, tag = string.find(e, "^(.-)%s*=%s*(.*)$")
      if name and name ~= "" then out[Lower(name)] = tag end
    end
    return out
  end
  -- a channel's own tag ("Trade" -> "T"), if one is set
  function P.Tag(name)
    if not name then return end
    return P.Tags()[Lower(name)]
  end
  -- a Lua pattern matching a word in any case ("ony" -> "[oO][nN][yY]")
  local function NoCase(word)
    return (string.gsub(word, "(%a)", function(c) return "[" .. string.lower(c) .. string.upper(c) .. "]" end))
  end
  local function Escape(word) return (string.gsub(word, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")) end
  local function Hex(str)
    local r, g, b = GetStringColor(str or "1,1,1,1")
    return string.format("|cff%02x%02x%02x", math.floor((tonumber(r) or 1) * 255), math.floor((tonumber(g) or 1) * 255),
      math.floor((tonumber(b) or 1) * 255))
  end

  -- the words to highlight: your name (when on) and your own
  function P.Words()
    local out = {}
    if S().mention == "1" and ME then table.insert(out, { ME, S().mentioncolor }) end
    for _, w in ipairs(P.List(S().words)) do
      if string.len(w) >= 3 then table.insert(out, { w, S().wordcolor }) end
    end
    return out
  end

  -- runs fn on the plain parts of a text (not inside |c...|H...|h...|h|r links)
  local function Plainwise(text, fn)
    local out, pos = "", 1
    while true do
      local s, e = string.find(text, "|H.-|h.-|h", pos)
      if not s then break end
      out = out .. fn(string.sub(text, pos, s - 1)) .. string.sub(text, s, e)
      pos = e + 1
    end
    return out .. fn(string.sub(text, pos))
  end

  -- your name and words in their colour, in the message part only
  function P.Highlight(body)
    local words = P.Words()
    if table.getn(words) == 0 then return body end
    return Plainwise(body, function(part)
      for _, w in ipairs(words) do
        part = string.gsub(part, "(" .. NoCase(Escape(w[1])) .. ")", Hex(w[2]) .. "%1|r")
      end
      return part
    end)
  end
  -- does a message mention you or a word? (for sounds and popups)
  function P.Mentions(msg)
    local low = Lower(msg)
    for _, w in ipairs(P.Words()) do
      if string.find(low, Lower(w[1]), 1, true) then return w[1] end
    end
  end

  -- ---------------------------------------------------------------- levels

  -- names -> level, from everyone the game shows you
  P.levels = {}
  local function Learn(unit)
    if UnitExists(unit) and UnitIsPlayer(unit) then
      local n, l = UnitName(unit), UnitLevel(unit)
      if n and l and l > 0 then P.levels[n] = l end
    end
  end
  local learn = CreateFrame("Frame")
  for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE",
                       "WHO_LIST_UPDATE", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD" }) do learn:RegisterEvent(e) end
  learn:SetScript("OnEvent", function()
    Learn("player") Learn("target") Learn("mouseover")
    for i = 1, GetNumPartyMembers() do Learn("party" .. i) end
    for i = 1, GetNumRaidMembers() do Learn("raid" .. i) end
    if event == "WHO_LIST_UPDATE" and GetNumWhoResults then
      for i = 1, GetNumWhoResults() do
        local n, _, l = GetWhoInfo(i)
        if n and l then P.levels[n] = tonumber(l) end
      end
    end
  end)

  -- ---------------------------------------------------------------- the two stages

  local seen, seenCount = {}, 0
  -- before pfUI: nil = drop the line
  function P.Pre(text)
    if not text then return end
    local s = S()
    local player = string.find(text, "|Hplayer:")
    if player then
      -- hidden words
      local low = Lower(string.gsub(text, "|H.-|h", ""))
      for _, w in ipairs(P.List(s.hide)) do
        if string.find(low, Lower(w), 1, true) then return end
      end
      -- the same line again too soon
      local t = tonumber(s.throttle) or 0
      if t > 0 then
        local now = GetTime()
        if seen[text] and now - seen[text] < t then return end
        seen[text] = now
        seenCount = seenCount + 1
        if seenCount > 400 then seen, seenCount = {}, 0 end
      end
    end
    -- your own channel tags: "[2. Trade]" -> "[T]"
    if s.tags and s.tags ~= "" then
      -- (Lua 5.0: a function that returns nothing to gsub deletes the match,
      -- so every branch gives the text back)
      text = string.gsub(text, "%[(%d+)%. ([^%]]+)%]", function(num, name)
        local tag = P.Tag(name)
        if tag then return "[" .. tag .. "]" end
        return "[" .. num .. ". " .. name .. "]"
      end)
    end
    return text
  end

  -- after pfUI: levels, highlights, the /find buffer
  P.buffer = {}
  function P.Post(frame, text)
    if not text then return text end
    local s = S()
    if s.levels == "1" then
      text = string.gsub(text, "|Hplayer:([^:|]+)([^|]*)|h(.-)|h", function(name, rest, shown)
        local l = P.levels[name]
        if not l then return "|Hplayer:" .. name .. rest .. "|h" .. shown .. "|h" end
        return "|Hplayer:" .. name .. rest .. "|h" .. shown .. "|cff999999:" .. l .. "|r|h"
      end)
    end
    -- the message part: after the speaker's name link and its ": "
    local _, linkEnd = string.find(text, "|Hplayer:.-|h.-|h")
    local colon = linkEnd and string.find(text, ": ", linkEnd, true)
    if colon then
      text = string.sub(text, 1, colon + 1) .. P.Highlight(string.sub(text, colon + 2))
    end
    -- (a buffer of plain lines for /find)
    if frame and not P.finding then
      local id = frame.GetID and frame:GetID() or 1
      local buf = P.buffer[id]
      if not buf then buf = {} P.buffer[id] = buf end
      table.insert(buf, text)
      local keep = tonumber(s.findlines) or 300
      while table.getn(buf) > keep do table.remove(buf, 1) end
    end
    return text
  end

  local function Wrap(frame)
    if not frame or frame.octoPlus then return end
    frame.octoPlus = true
    local add = frame.AddMessage
    frame.AddMessage = function(self, text, a1, a2, a3, a4, a5)
      if self.pfCombatLog then return add(self, text, a1, a2, a3, a4, a5) end
      local ok, t = pcall(P.Pre, text)
      if ok then
        if not t then return end
        text = t
      end
      -- (without pfUI's chat the after stage runs here)
      if not self.HookAddMessage then
        local ok2, t2 = pcall(P.Post, self, text)
        if ok2 and t2 then text = t2 end
      end
      return add(self, text, a1, a2, a3, a4, a5)
    end
    if frame.HookAddMessage then
      local hook = frame.HookAddMessage
      frame.HookAddMessage = function(self, text, a1, a2, a3, a4, a5)
        if not self.pfCombatLog then
          local ok, t = pcall(P.Post, self, text)
          if ok and t then text = t end
        end
        return hook(self, text, a1, a2, a3, a4, a5)
      end
    end
  end
  function P.WrapAll()
    for i = 1, (tonumber(NUM_CHAT_WINDOWS) or 7) do Wrap(_G["ChatFrame" .. i]) end
  end
  P.WrapAll()

  -- ---------------------------------------------------------------- sounds, popup, invites

  local function Play(key)
    if not key or key == "" or key == "none" then return end
    local CT = pfUI.sctB and pfUI.sctB.SCT
    if CT and CT.PlaySound then CT.PlaySound(key) else PlaySound(key) end
  end
  P.Play = Play

  local popup = CreateFrame("Frame", "pfChatMention", UIParent)
  popup:SetFrameStrata("HIGH")
  popup:SetWidth(600)
  popup:SetHeight(30)
  popup:SetPoint("TOP", UIParent, "TOP", 0, -160)
  popup.text = popup:CreateFontString(nil, "OVERLAY")
  popup.text:SetFont(pfUI.font_default, 18, "OUTLINE")
  popup.text:SetAllPoints(popup)
  popup:Hide()
  popup:SetScript("OnUpdate", function()
    local left = (this.untilT or 0) - GetTime()
    if left <= 0 then this:Hide() elseif left < 1 then this:SetAlpha(left) end
  end)
  function P.Popup(text)
    popup.text:SetText(text)
    popup:SetAlpha(1)
    popup.untilT = GetTime() + 4
    popup:Show()
  end

  -- message events -> the sound picked for that kind
  P.KINDS = {
    { "whisper", "Whispers", { "CHAT_MSG_WHISPER" } },
    { "guild", "Guild", { "CHAT_MSG_GUILD" } },
    { "officer", "Officer", { "CHAT_MSG_OFFICER" } },
    { "party", "Party", { "CHAT_MSG_PARTY" } },
    { "raid", "Raid", { "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING" } },
    { "bg", "Battleground", { "CHAT_MSG_BATTLEGROUND", "CHAT_MSG_BATTLEGROUND_LEADER" } },
    { "say", "Say and yell", { "CHAT_MSG_SAY", "CHAT_MSG_YELL" } },
    { "channel", "Channels", { "CHAT_MSG_CHANNEL" } },
  }
  local KIND = {}
  local ev = CreateFrame("Frame")
  for _, k in ipairs(P.KINDS) do
    for _, e in ipairs(k[3]) do KIND[e] = k[1] ev:RegisterEvent(e) end
  end
  local lastSound = 0
  function P.OnMessage(evt, msg, sender)
    local s = S()
    if not sender or sender == ME then return end
    local kind = KIND[evt]
    local now = GetTime()
    -- your name or a word: its own sound and the popup
    local hit = P.Mentions(msg)
    if hit then
      if now - lastSound > 1 then P.Play(s.mentionsound) lastSound = now end
      if s.mentionpopup == "1" then P.Popup(Hex(s.mentioncolor) .. sender .. "|r: " .. string.sub(msg or "", 1, 80)) end
    elseif kind and now - lastSound > 1 then
      local key = s["sound_" .. kind]
      if key and key ~= "none" then P.Play(key) lastSound = now end
    end
    -- a whisper with the invite word
    if evt == "CHAT_MSG_WHISPER" and s.autoinvite == "1" and Lower(msg) == Lower(s.inviteword) then
      if GetNumRaidMembers() == 0 and (GetNumPartyMembers() == 0 or IsPartyLeader()) then InviteByName(sender) end
    end
  end
  ev:SetScript("OnEvent", function() P.OnMessage(event, arg1, arg2) end)

  -- Alt-click a name in chat: invite (wraps whoever handles links now)
  local function WrapLinks()
    if not _G.SetItemRef or _G.SetItemRef == P.linkFn then return end
    local orig = _G.SetItemRef
    P.linkFn = function(link, text, button)
      if S().altinvite == "1" and IsAltKeyDown() and link and string.sub(link, 1, 7) == "player:" then
        local name = string.sub(link, 8)
        local _, _, real = string.find(name, "^([^:]+)")
        InviteByName(real or name)
        return
      end
      return orig(link, text, button)
    end
    _G.SetItemRef = P.linkFn
  end

  -- Shift + wheel: top / bottom; Ctrl + wheel: a page (on top of pfUI's wheel)
  local function WrapWheels()
    for i = 1, (tonumber(NUM_CHAT_WINDOWS) or 7) do
      local f = _G["ChatFrame" .. i]
      local cur = f and f:GetScript("OnMouseWheel")
      if f and cur and cur ~= f.octoWheel then
        local orig = cur
        f.octoWheel = function()
          if S().wheeljump == "1" and IsShiftKeyDown() then
            if arg1 > 0 and this.ScrollToTop then this:ScrollToTop() elseif this.ScrollToBottom then this:ScrollToBottom() end
          elseif S().wheeljump == "1" and IsControlKeyDown() then
            if arg1 > 0 and this.PageUp then this:PageUp() elseif this.PageDown then this:PageDown() end
          else
            orig()
          end
        end
        f:SetScript("OnMouseWheel", f.octoWheel)
      end
    end
  end
  local watch = CreateFrame("Frame")
  watch:RegisterEvent("PLAYER_ENTERING_WORLD")
  watch:SetScript("OnEvent", function()
    P.WrapAll()
    WrapLinks()
    WrapWheels()
  end)
  -- (pfUI sets each window's wheel again when chat is arranged)
  libclient.Every(watch, 2, function()
    WrapWheels()
    -- (pfUI or another addon may set its own link handler later)
    WrapLinks()
  end)

  -- ---------------------------------------------------------------- slash commands

  local function Say(text) DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r: " .. text) end
  -- /tt message: whisper your target
  _G.SLASH_OCTOTT1, _G.SLASH_OCTOTT2 = "/tt", "/telltarget"
  _G.SlashCmdList.OCTOTT = function(msg)
    local name = UnitIsPlayer("target") and UnitName("target")
    if not name then Say("/tt whispers your target - target a player first.") return end
    if msg and msg ~= "" then SendChatMessage(msg, "WHISPER", nil, name)
    elseif ChatFrame_OpenChat then ChatFrame_OpenChat("/w " .. name .. " ") end
  end
  -- /find word: the last lines that have it, from every window
  function P.Find(word)
    local out = {}
    if not word or word == "" then return out end
    local low = Lower(word)
    for id, buf in pairs(P.buffer) do
      for _, line in ipairs(buf) do
        local plain = string.gsub(string.gsub(line, "|c%x%x%x%x%x%x%x%x", ""), "|r", "")
        plain = string.gsub(plain, "|H.-|h", "")
        if string.find(Lower(plain), low, 1, true) then table.insert(out, line) end
      end
    end
    return out
  end
  _G.SLASH_OCTOFIND1, _G.SLASH_OCTOFIND2 = "/find", "/chatfind"
  _G.SlashCmdList.OCTOFIND = function(msg)
    local hits = P.Find(msg)
    P.finding = true
    if table.getn(hits) == 0 then
      Say("nothing in chat has \"" .. (msg or "") .. "\".")
    else
      Say(table.getn(hits) .. " line" .. (table.getn(hits) == 1 and "" or "s") .. " with \"" .. msg .. "\" (last 15):")
      for i = math.max(1, table.getn(hits) - 14), table.getn(hits) do DEFAULT_CHAT_FRAME:AddMessage("  " .. hits[i]) end
    end
    P.finding = nil
  end
  -- /clear: empties the chat window you are looking at (/clear all: every one)
  _G.SLASH_OCTOCLEAR1 = "/clear"
  _G.SlashCmdList.OCTOCLEAR = function(msg)
    for i = 1, (tonumber(NUM_CHAT_WINDOWS) or 7) do
      local f = _G["ChatFrame" .. i]
      if f and f.Clear and (msg == "all" or f == SELECTED_CHAT_FRAME or (not SELECTED_CHAT_FRAME and f == DEFAULT_CHAT_FRAME)) then f:Clear() end
    end
  end
end)
