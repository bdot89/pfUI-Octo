pfUI:RegisterModule("worldbuffs", "vanilla", function ()
  -- pfUI Octo :: world buff drops (21 Nov 2026, Bread on Discord: "Is there an addon that keeps track of when world buffs
  -- are going to go off and what buff it is?"). Written fresh.
  -- A head handed in makes an NPC yell (Orgrimmar, Stormwind, Yojamba Isle); the buff lands on everyone in the zone a few
  -- seconds later. The yell starts a countdown bar with the buff's name, picture and where it lands, a popup and a sound,
  -- and is passed on (addon channel "pfWB", guild and group) so pfUI Octo users elsewhere see it too. The seconds after the
  -- yell start as estimates (WB.DROPS delay) and are learnt: the buff landing on you times it (pfUI_cache.wbdelay).
  -- Settings C.worldbuffs: enable, popup, sound, share. /wb lists the last drops.
  local WB = { pending = {}, PREFIX = "pfWB" }
  pfUI.worldbuffs = WB
  local function S() return C.worldbuffs end
  local function On(k) return S()[k] ~= "0" end
  local I = "Interface\\Icons\\"
  -- npc = the one who yells; word = a word of the yell that tells which head (when the npc alone could mean two)
  WB.DROPS = {
    { key = "ony_h", buff = "Rallying Cry of the Dragonslayer", what = "Onyxia", zone = "Orgrimmar", npc = "Overlord Runthak", delay = 14, tex = I .. "INV_Misc_Head_Dragon_01" },
    { key = "ony_a", buff = "Rallying Cry of the Dragonslayer", what = "Onyxia", zone = "Stormwind City", npc = "Major Mattingly", delay = 13, tex = I .. "INV_Misc_Head_Dragon_01" },
    -- (the row shows Nefarian's black head; the buff itself is Rallying Cry's red one - bufftex)
    { key = "nef_h", buff = "Rallying Cry of the Dragonslayer", what = "Nefarian", zone = "Orgrimmar", npc = "High Overlord Saurfang", delay = 15, tex = I .. "INV_Misc_Head_Dragon_Black", bufftex = I .. "INV_Misc_Head_Dragon_01" },
    { key = "nef_a", buff = "Rallying Cry of the Dragonslayer", what = "Nefarian", zone = "Stormwind City", npc = "Field Marshal Afrasiabi", delay = 15, tex = I .. "INV_Misc_Head_Dragon_Black", bufftex = I .. "INV_Misc_Head_Dragon_01" },
    { key = "rend", buff = "Warchief's Blessing", what = "Rend", zone = "Orgrimmar", npc = "Thrall", word = "Rend", delay = 6, tex = I .. "Spell_Arcane_TeleportOrgrimmar" },
    { key = "zg", buff = "Spirit of Zandalar", what = "Hakkar", zone = "Stranglethorn Vale", npc = "Molthor", delay = 30, tex = I .. "Ability_Creature_Poison_05" },
  }
  function WB.Def(key)
    for _, d in ipairs(WB.DROPS) do if d.key == key then return d end end
  end
  -- the seconds from the yell to the buff: learnt, else the estimate
  function WB.Delay(d)
    local learnt = pfUI_cache.wbdelay and tonumber(pfUI_cache.wbdelay[d.key])
    return learnt or d.delay, learnt and true or false
  end
  -- which drop a yell is: by who yells (and a word of it, for the ones that need it)
  function WB.Match(npc, text)
    if type(npc) ~= "string" then return end
    for _, d in ipairs(WB.DROPS) do
      if npc == d.npc and (not d.word or (type(text) == "string" and string.find(string.lower(text), string.lower(d.word), 1, true))) then
        return d
      end
    end
  end

  -- a drop is coming: in `secs` seconds (from a yell here, or passed on by `from`)
  function WB.Coming(d, secs, from, now)
    if not d or not On("enable") then return end
    now = now or GetTime()
    local p = WB.pending[d.key]
    -- the same drop again (a second yell line, or it passed on by several): keep the first
    if p and now < p.at + 30 then return end
    WB.pending[d.key] = { d = d, at = now + secs, heard = now, from = from }
    pfUI_cache.wblast = pfUI_cache.wblast or {}
    pfUI_cache.wblast[d.key] = time()
    local where = from and (" (" .. from .. ")") or ""
    local line = "|cffffd24d" .. d.buff .. "|r (" .. d.what .. ") in " .. d.zone .. " in " .. math.ceil(secs) .. " s" .. where
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfUI|r World buff: " .. line)
    if On("popup") and UIErrorsFrame then UIErrorsFrame:AddMessage(d.buff .. " in " .. math.ceil(secs) .. " s - " .. d.zone, 1, .82, .3, 1, 5) end
    if On("sound") then PlaySound("RaidWarning") end
    if not from then WB.Share(d, secs) end
    WB.Paint()
  end

  -- passed on to the guild and the group: "D^key^seconds"
  function WB.Share(d, secs)
    if not On("share") or type(SendAddonMessage) ~= "function" then return end
    local msg = "D^" .. d.key .. "^" .. math.floor(secs + .5)
    if IsInGuild and IsInGuild() then pcall(SendAddonMessage, WB.PREFIX, msg, "GUILD") end
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then pcall(SendAddonMessage, WB.PREFIX, msg, "RAID")
    elseif GetNumPartyMembers and GetNumPartyMembers() > 0 then pcall(SendAddonMessage, WB.PREFIX, msg, "PARTY") end
  end
  function WB.Receive(msg, sender)
    if type(msg) ~= "string" or sender == UnitName("player") then return end
    local _, _, key, secs = string.find(msg, "^D%^([%w_]+)%^(%d+)$")
    local d = key and WB.Def(key)
    secs = tonumber(secs)
    if d and secs and secs >= 0 and secs <= 120 then WB.Coming(d, secs, sender) end
  end

  -- the buff on you: how long after the yell it came (learnt for next time)
  function WB.Landed(now)
    now = now or GetTime()
    for key, p in pairs(WB.pending) do
      if not p.timed and not p.from and now - p.heard < 90 and WB.HasBuff(p.d.bufftex or p.d.tex) then
        p.timed = true
        local took = now - p.heard
        if took > 1 and took < 90 then
          pfUI_cache.wbdelay = pfUI_cache.wbdelay or {}
          local old = tonumber(pfUI_cache.wbdelay[key])
          pfUI_cache.wbdelay[key] = tostring(math.floor(((old and (old + took) / 2) or took) * 10 + .5) / 10)
        end
        p.at = math.min(p.at, now)
      end
    end
  end
  local function Base(t)
    local _, _, b = string.find(t or "", "([^\\]+)$")
    return b and string.lower(b)
  end
  function WB.HasBuff(tex)
    local want = Base(tex)
    for i = 1, 32 do
      local t = UnitBuff("player", i)
      if not t then return false end
      if Base(t) == want then return true end
    end
    return false
  end

  -- ---------------------------------------------------------------- the bar
  local f = CreateFrame("Frame", "pfWorldBuffs", UIParent)
  WB.frame = f
  f:SetWidth(240)
  f:SetHeight(22)
  f:SetPoint("TOP", UIParent, "TOP", 0, -150)
  f:Hide()
  if UpdateMovable then UpdateMovable(f) end
  WB.rows = {}
  local function Row(i)
    local r = WB.rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, f)
    r:SetWidth(240)
    r:SetHeight(22)
    r:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(i - 1) * 24)
    if CreateBackdrop then CreateBackdrop(r) end
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetWidth(20)
    r.icon:SetHeight(20)
    r.icon:SetPoint("LEFT", r, "LEFT", 1, 0)
    r.icon:SetTexCoord(.08, .92, .08, .92)
    r.bar = CreateFrame("StatusBar", nil, r)
    r.bar:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 2, 0)
    r.bar:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -1, 1)
    r.bar:SetStatusBarTexture(pfUI.media and pfUI.media["img:bar"] or "Interface\\TargetingFrame\\UI-StatusBar")
    r.bar:SetStatusBarColor(1, .7, .2, .85)
    r.bar:SetMinMaxValues(0, 1)
    r.text = r.bar:CreateFontString(nil, "OVERLAY")
    r.text:SetFont(pfUI.font_default or STANDARD_TEXT_FONT, 11, "OUTLINE")
    r.text:SetPoint("LEFT", r.bar, "LEFT", 4, 0)
    r.time = r.bar:CreateFontString(nil, "OVERLAY")
    r.time:SetFont(pfUI.font_default or STANDARD_TEXT_FONT, 12, "OUTLINE")
    r.time:SetPoint("RIGHT", r.bar, "RIGHT", -4, 0)
    WB.rows[i] = r
    return r
  end
  WB.Row = Row
  -- a row per drop coming (and 15 s of "now" after it lands)
  function WB.Paint(now)
    now = now or GetTime()
    local list = {}
    for key, p in pairs(WB.pending) do
      if now > p.at + 15 then WB.pending[key] = nil else table.insert(list, p) end
    end
    table.sort(list, function(a, b) return a.at < b.at end)
    for i, p in ipairs(list) do
      local r = Row(i)
      local left = p.at - now
      local total = math.max(1, p.at - p.heard)
      r.icon:SetTexture(p.d.tex)
      r.text:SetText(p.d.buff .. " |cffaaaaaa- " .. p.d.zone .. "|r")
      if left > 0 then
        r.time:SetText(math.ceil(left) .. " s")
        r.bar:SetValue(math.max(0, math.min(1, 1 - left / total)))
        r.bar:SetStatusBarColor(1, .7, .2, .85)
      else
        r.time:SetText("|cff40d977now|r")
        r.bar:SetValue(1)
        r.bar:SetStatusBarColor(.25, .85, .47, .85)
      end
      r:Show()
    end
    for i = table.getn(list) + 1, table.getn(WB.rows) do WB.rows[i]:Hide() end
    WB.shown = table.getn(list)
    if WB.shown > 0 then f:Show() elseif not (pfUI.unlock and pfUI.unlock:IsShown()) then f:Hide() end
  end

  -- ---------------------------------------------------------------- events
  local ev = CreateFrame("Frame")
  WB.events = ev
  ev:RegisterEvent("CHAT_MSG_MONSTER_YELL")
  ev:RegisterEvent("CHAT_MSG_ADDON")
  ev:RegisterEvent("PLAYER_AURAS_CHANGED")
  ev:SetScript("OnEvent", function()
    if event == "CHAT_MSG_MONSTER_YELL" then
      local d = WB.Match(arg2, arg1)
      if d then WB.Coming(d, (WB.Delay(d))) end
    elseif event == "CHAT_MSG_ADDON" then
      if arg1 == WB.PREFIX then WB.Receive(arg2, arg4) end
    elseif event == "PLAYER_AURAS_CHANGED" then
      WB.Landed()
    end
  end)
  ev:SetScript("OnUpdate", function()
    if (this.tick or 0) > GetTime() then return end
    this.tick = GetTime() + .2
    if WB.shown and WB.shown > 0 then WB.Paint() end
  end)

  -- /wb: the last drops
  _G.SLASH_PFWORLDBUFFS1, _G.SLASH_PFWORLDBUFFS2 = "/wb", "/worldbuffs"
  _G.SlashCmdList["PFWORLDBUFFS"] = function()
    local last = pfUI_cache.wblast or {}
    local any
    for _, d in ipairs(WB.DROPS) do
      local t = last[d.key]
      if t then
        any = true
        local ago = time() - t
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfUI|r " .. d.buff .. " (" .. d.what .. ", " .. d.zone .. "): "
          .. (ago < 3600 and (math.floor(ago / 60) .. " min ago") or (math.floor(ago / 360) / 10 .. " h ago")))
      end
    end
    if not any then DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfUI|r No world buff drop seen yet.") end
  end
end)
