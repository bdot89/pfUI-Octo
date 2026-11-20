pfUI:RegisterModule("chat-raid", "vanilla:tbc", function ()
  -- pfUI Octo :: raid chat window (20 Nov 2026, user: "a raid chat window that enables when you enter a raid. This
  -- will show all info that is important ... it stops any other spam channels ... Shows Taunts, Overaggros, Healer %
  -- of mana on the raid after combat drop, Loot that is linked from the masterlooter (works as normal can click item
  -- links etc) This is combat ready chat log ideal for raid leaders and main tanks ... Should only show raid chat for
  -- example if the raid leader makes a call and a raider puts + to show they have heard him this is important info").
  -- One window, opened by itself in a raid: raid chat and raid warnings (the leader's and assists' calls stand out,
  -- the "+" answers gather under the call as one line of names), taunts (SuperWoW's cast events; resists, misses and
  -- dodges from the combat log), a boss turning to someone who is not tanking it (raid targets scanned), the healers'
  -- mana when a fight ends, the master looter's item links and epic loot. Links and names click as in any chat. A box
  -- at the bottom talks to the raid. While in a raid the other chat windows can go quiet: no General / Trade / LFG
  -- channels (and say / yell if asked) until you leave - the Q button or the options switch it back at once.
  -- Settings C.chat.raidchat; options: Chat & Panels > Raid chat.
  local RC = { lines = {}, class = {}, rank = {}, mobs = {}, tanks = {}, taunted = {} }
  pfUI.raidchat = RC
  local function S() return C.chat.raidchat end
  local function On(k) return S()[k] == "1" end
  local ME = UnitName("player")
  local MAXLINES = 200

  local function Accent()
    if GetAccentColor then return GetAccentColor() end
    return .2, .55, .9
  end
  local function Font() return pfUI.font_default, tonumber(S().fontsize) or 12 end
  local function Hex(token)
    local c = token and RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
    if not c then return "|cffffffff" end
    return string.format("|cff%02x%02x%02x", math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255))
  end
  -- a name in class colour that clicks like a chat name (whisper, menu)
  local function Name(n)
    if not n then return "?" end
    return Hex(RC.class[n]) .. "|Hplayer:" .. n .. "|h" .. n .. "|h|r"
  end
  RC.Name = Name
  local function InRaid() return (GetNumRaidMembers and GetNumRaidMembers() or 0) > 0 end

  -- ---------------------------------------------------------------- the window

  local function Btn(parent, label, tip, fn)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(18)
    b:SetHeight(18)
    b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    b:SetBackdropColor(.1, .1, .12, 1)
    b:SetBackdropBorderColor(.25, .25, .28, 1)
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetFont(pfUI.font_default, 10, "OUTLINE")
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.text:SetText(label)
    b.tip = tip
    b:SetScript("OnClick", fn)
    b:SetScript("OnEnter", function()
      local r, g, bb = Accent()
      this:SetBackdropBorderColor(r, g, bb, 1)
      GameTooltip:SetOwner(this, "ANCHOR_TOP")
      GameTooltip:SetText(type(this.tip) == "function" and this.tip() or this.tip, 1, 1, 1)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if this.Paint then this.Paint() else this:SetBackdropBorderColor(.25, .25, .28, 1) end GameTooltip:Hide() end)
    return b
  end

  local F
  local function Window()
    if F then return F end
    F = CreateFrame("Frame", "pfRaidChat", UIParent)
    F:SetFrameStrata("MEDIUM")
    F:SetWidth(tonumber(S().width) or 400)
    F:SetHeight(tonumber(S().height) or 220)
    F:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    F:SetBackdropColor(.05, .05, .07, .92)
    F:SetBackdropBorderColor(.2, .2, .24, 1)
    F:SetMovable(true)
    F:SetResizable(true)
    F:EnableMouse(true)
    F:SetClampedToScreen(true)
    if F.SetMinResize then F:SetMinResize(240, 110) end

    local bar = CreateFrame("Button", nil, F)
    bar:SetPoint("TOPLEFT", F, "TOPLEFT", 1, -1)
    bar:SetPoint("TOPRIGHT", F, "TOPRIGHT", -1, -1)
    bar:SetHeight(22)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar)
    bar.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bar.bg:SetVertexColor(.12, .12, .15, 1)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() F:StartMoving() end)
    bar:SetScript("OnDragStop", function()
      F:StopMovingOrSizing()
      S().x, S().y = tostring(math.floor(F:GetLeft() + .5)), tostring(math.floor(F:GetTop() + .5))
    end)
    bar:SetScript("OnClick", function() RC.Fold() end)
    F.bar = bar
    F.title = bar:CreateFontString(nil, "OVERLAY")
    F.title:SetFont(pfUI.font_default, 12, "OUTLINE")
    F.title:SetPoint("LEFT", bar, "LEFT", 6, 0)
    F.title:SetJustifyH("LEFT")

    F.close = Btn(bar, "x", "Hide (it opens again in your next raid)", function() RC.Hide() end)
    F.close:SetPoint("RIGHT", bar, "RIGHT", -2, 0)
    F.fold = Btn(bar, "_", "Fold / unfold", function() RC.Fold() end)
    F.fold:SetPoint("RIGHT", F.close, "LEFT", -2, 0)
    F.clear = Btn(bar, "C", "Clear the window", function() RC.Clear() end)
    F.clear:SetPoint("RIGHT", F.fold, "LEFT", -8, 0)
    F.quiet = Btn(bar, "Q", function()
      return (On("quiet") and "|cff40d966Quiet chat: on|r" or "|cfff24d4dQuiet chat: off|r")
        .. "\nIn a raid, the other chat windows show no General / Trade / LFG channels.\nClick to switch it."
    end, function()
      S().quiet = On("quiet") and "0" or "1"
      RC.ApplyQuiet()
      this.Paint()
      if MouseIsOver(this) then this:GetScript("OnEnter")() end
    end)
    F.quiet:SetPoint("RIGHT", F.clear, "LEFT", -2, 0)
    F.quiet.Paint = function()
      local q = F.quiet
      if On("quiet") then
        q:SetBackdropBorderColor(.25, .85, .4, 1) q.text:SetTextColor(.4, 1, .5)
      else
        q:SetBackdropBorderColor(.25, .25, .28, 1) q.text:SetTextColor(.7, .7, .7)
      end
    end
    F.quiet.Paint()
    F.title:SetPoint("RIGHT", F.quiet, "LEFT", -4, 0)

    local msg = CreateFrame("ScrollingMessageFrame", nil, F)
    -- (19 Nov 2026 lesson from the whisper window: a message frame needs its font before the first AddMessage)
    if msg.SetFontObject and ChatFontNormal then msg:SetFontObject(ChatFontNormal) end
    if msg.SetFont then msg:SetFont(Font()) end
    msg:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 5, -3)
    msg:SetPoint("BOTTOMRIGHT", F, "BOTTOMRIGHT", -5, 26)
    if msg.SetFading then msg:SetFading(false) end
    if msg.SetMaxLines then msg:SetMaxLines(MAXLINES) end
    if msg.SetJustifyH then msg:SetJustifyH("LEFT") end
    msg:EnableMouse(true)
    msg:EnableMouseWheel(true)
    msg:SetScript("OnMouseWheel", function()
      if arg1 > 0 then
        if IsShiftKeyDown() and this.ScrollToTop then this:ScrollToTop() elseif this.ScrollUp then this:ScrollUp() end
      else
        if IsShiftKeyDown() and this.ScrollToBottom then this:ScrollToBottom() elseif this.ScrollDown then this:ScrollDown() end
      end
    end)
    -- item links, names: as in any chat (shift-click puts a link in the typing box)
    msg:SetScript("OnHyperlinkClick", function() SetItemRef(arg1, arg2, arg3) end)
    msg:SetScript("OnHyperlinkEnter", function()
      if type(arg1) == "string" and string.find(arg1, "^item:") then
        GameTooltip:SetOwner(this, "ANCHOR_CURSOR")
        GameTooltip:SetHyperlink(arg1)
        GameTooltip:Show()
      end
    end)
    msg:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)
    F.msg = msg

    -- a box that talks to the raid
    local eb = CreateFrame("EditBox", nil, F)
    if eb.SetFontObject and ChatFontNormal then eb:SetFontObject(ChatFontNormal) end
    if eb.SetFont then eb:SetFont(Font()) end
    eb:SetPoint("BOTTOMLEFT", F, "BOTTOMLEFT", 4, 4)
    eb:SetPoint("BOTTOMRIGHT", F, "BOTTOMRIGHT", -16, 4)
    eb:SetHeight(18)
    eb:SetAutoFocus(false)
    if eb.SetTextInsets then eb:SetTextInsets(4, 4, 0, 0) end
    eb:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    eb:SetBackdropColor(0, 0, 0, .6)
    eb:SetBackdropBorderColor(.25, .25, .28, 1)
    eb.hint = eb:CreateFontString(nil, "OVERLAY")
    eb.hint:SetFont(pfUI.font_default, 10, "")
    eb.hint:SetPoint("LEFT", eb, "LEFT", 6, 0)
    eb.hint:SetTextColor(.45, .45, .5)
    eb.hint:SetText("Say to the raid...")
    eb:SetScript("OnEnterPressed", function()
      local text = this:GetText()
      if text and text ~= "" then RC.Say(text) end
      this:SetText("")
      this:ClearFocus()
    end)
    eb:SetScript("OnEscapePressed", function() this:SetText("") this:ClearFocus() end)
    eb:SetScript("OnTextChanged", function() if this:GetText() == "" then this.hint:Show() else this.hint:Hide() end end)
    eb:SetScript("OnEditFocusGained", function() this.hint:Hide() end)
    eb:SetScript("OnEditFocusLost", function() if this:GetText() == "" then this.hint:Show() end end)
    F.edit = eb

    local grip = CreateFrame("Button", nil, F)
    grip:SetWidth(12)
    grip:SetHeight(12)
    grip:SetPoint("BOTTOMRIGHT", F, "BOTTOMRIGHT", -1, 1)
    grip.tex = grip:CreateTexture(nil, "OVERLAY")
    grip.tex:SetAllPoints(grip)
    grip.tex:SetTexture("Interface\\Buttons\\WHITE8X8")
    grip.tex:SetVertexColor(.4, .4, .45, .6)
    grip:SetScript("OnMouseDown", function() F:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
      F:StopMovingOrSizing()
      S().width, S().height = tostring(math.floor(F:GetWidth() + .5)), tostring(math.floor(F:GetHeight() + .5))
    end)
    F.grip = grip

    -- (a new frame counts as shown in the real client: made hidden, it is placed and shown like any other)
    F:Hide()
    RC.frame = F
    RC.Paint()
    return F
  end

  function RC.Paint()
    if not F then return end
    local n = GetNumRaidMembers and GetNumRaidMembers() or 0
    F.title:SetText("|cffff7f00Raid chat|r" .. (n > 0 and ("  |cff999999" .. n .. " in the raid|r") or "")
      .. (RC.test and "  |cff888888(test)|r" or ""))
    local font, size = Font()
    if F.msg.SetFont then F.msg:SetFont(font, size, "") end
    if F.edit.SetFont then F.edit:SetFont(font, size, "") end
    F.quiet.Paint()
  end

  function RC.Show()
    Window()
    if not F:IsShown() then
      F:SetWidth(tonumber(S().width) or 400)
      F:SetHeight(F.folded and 24 or (tonumber(S().height) or 220))
      local x, y = tonumber(S().x), tonumber(S().y)
      F:ClearAllPoints()
      if x and y then F:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
      else F:SetPoint("LEFT", UIParent, "LEFT", 40, 60) end
      F:Show()
    end
    RC.Paint()
  end
  function RC.Hide() if F then F:Hide() end end

  function RC.Fold(fold)
    Window()
    if fold == nil then fold = not F.folded end
    F.folded = fold
    if fold then
      F:SetHeight(24)
      F.msg:Hide() F.edit:Hide() F.grip:Hide()
    else
      F:SetHeight(tonumber(S().height) or 220)
      F.msg:Show() F.edit:Show() F.grip:Show()
    end
  end

  -- ---------------------------------------------------------------- lines

  local function Stamp() return "|cff777777" .. date("%H:%M") .. "|r " end

  -- every line is kept, so a "+" can grow the line under its call and all of it is drawn again
  local function Redraw()
    if not F then return end
    F.msg:Clear()
    for _, l in ipairs(RC.lines) do F.msg:AddMessage(l.text, l.r, l.g, l.b) end
  end
  function RC.Add(text, r, g, b)
    Window()
    local l = { text = Stamp() .. text, r = r or 1, g = g or 1, b = b or 1 }
    table.insert(RC.lines, l)
    if table.getn(RC.lines) > MAXLINES then table.remove(RC.lines, 1) end
    F.msg:AddMessage(l.text, l.r, l.g, l.b)
    return l
  end
  function RC.Clear()
    RC.lines = {}
    RC.call = nil
    if F then F.msg:Clear() end
  end

  function RC.Say(text)
    if RC.test or not InRaid() then
      RC.Raid(ME, text, "RAID")
      return
    end
    SendChatMessage(text, "RAID")
  end

  -- "+", "1", "ok", "rgr"...: heard the call
  local ACK = { ["+"] = true, ["++"] = true, ["+++"] = true, ["1"] = true, ["ok"] = true, ["k"] = true, ["kk"] = true,
                ["y"] = true, ["yes"] = true, ["yep"] = true, ["rgr"] = true, ["roger"] = true, ["ready"] = true,
                ["rdy"] = true, ["r"] = true, ["np"] = true, ["on it"] = true }
  function RC.IsAck(text)
    local t = string.lower(string.gsub(text or "", "^%s*(.-)%s*$", "%1"))
    t = string.gsub(t, "[!%.]+$", "")
    return ACK[t] or false
  end

  -- the master looter's name, when there is one
  function RC.Looter()
    if RC.testLooter then return RC.testLooter end
    if not (GetLootMethod and GetRaidRosterInfo) then return nil end
    local method, _, raidID = GetLootMethod()
    if method ~= "master" or not raidID then return nil end
    return (GetRaidRosterInfo(raidID))
  end

  -- a raid line (kind RAID, RAID_LEADER or RAID_WARNING)
  function RC.Raid(who, text, kind)
    if not (who and text) then return end
    local leaderish = kind == "RAID_LEADER" or kind == "RAID_WARNING" or (RC.rank[who] or 0) >= 1
    -- a "+" under a call: one line of names under it
    if On("acks") and RC.call and RC.IsAck(text) and GetTime() - RC.call.at < 90 and who ~= RC.call.who then
      local c = RC.call
      if not c.seen[who] then
        c.seen[who] = true
        table.insert(c.names, who)
        local list = {}
        for _, n in ipairs(c.names) do table.insert(list, Name(n)) end
        local text2 = "|cff40d966   + " .. table.getn(c.names) .. " heard:|r " .. table.concat(list, ", ")
        if c.line then
          c.line.text = string.sub(c.line.text, 1, string.find(c.line.text, "|r ", 1, true) + 2) .. text2
          Redraw()
        else
          c.line = RC.Add(text2, 1, 1, 1)
        end
      end
      return
    end
    local tag, r, g, b
    local looter = RC.Looter()
    if kind == "RAID_WARNING" then
      tag, r, g, b = "|cffff4040[RW]|r ", 1, .45, .3
    elseif looter and who == looter and string.find(text, "|Hitem:", 1, true) then
      tag, r, g, b = "|cffffd100[ML]|r ", 1, .85, .35
    elseif leaderish then
      tag, r, g, b = (kind == "RAID_LEADER" and "|cffff9900[Lead]|r " or "|cffffcc66[Assist]|r "), 1, .75, .35
    else
      tag, r, g, b = "", 1, .5, 0
    end
    if not On("raid") and tag == "" then return end
    RC.Add(tag .. Name(who) .. ": " .. text, r, g, b)
    if leaderish then RC.call = { who = who, at = GetTime(), names = {}, seen = {} } end
  end

  -- ---------------------------------------------------------------- taunts

  RC.TAUNTS = { ["Taunt"] = true, ["Mocking Blow"] = true, ["Challenging Shout"] = true, ["Growl"] = true, ["Challenging Roar"] = true }
  -- (the ranks, for clients that cannot name a spell id)
  RC.TAUNT_IDS = { [355] = "Taunt", [694] = "Mocking Blow", [7400] = "Mocking Blow", [7402] = "Mocking Blow", [20559] = "Mocking Blow",
                   [20560] = "Mocking Blow", [1161] = "Challenging Shout", [6795] = "Growl", [5209] = "Challenging Roar" }
  local function SpellName(id)
    if RC.TAUNT_IDS[id] then return RC.TAUNT_IDS[id] end
    if SpellInfo then
      local ok, n = pcall(SpellInfo, id)
      if ok and n then return n end
    end
  end
  function RC.Taunt(who, spell, target)
    if not On("taunts") then return end
    RC.taunted[who] = GetTime()
    RC.tanks[who] = true
    local what = spell == "Taunt" and "" or (" |cff999999(" .. spell .. ")|r")
    RC.Add("|cffff9933TAUNT|r " .. Name(who) .. " |cffaaaaaa>|r |cffffffff" .. (target or "?") .. "|r" .. what, 1, .8, .5)
  end
  function RC.TauntFailed(who, spell, target, how)
    if not On("taunts") then return end
    RC.Add("|cffff3030" .. string.upper(spell) .. " " .. string.upper(how) .. "|r " .. Name(who) .. " |cffaaaaaa>|r |cffffffff"
      .. (target or "?") .. "|r", 1, .4, .4)
  end
  -- the combat log: "Your Taunt was resisted by X." / "Brenna's Mocking Blow was parried by X." / "... missed X."
  function RC.CombatLine(text)
    if not text then return end
    local _, _, who, spell, how, target = string.find(text, "^(.-)'?s? (%a[%a ]-) was (%a+) by (.+)%.$")
    if not who then _, _, who, spell, target = string.find(text, "^(.-)'?s? (%a[%a ]-) missed (.+)%.$") how = "missed" end
    if not (who and spell and RC.TAUNTS[spell]) then return end
    if who == "Your" or who == "You" then who = ME end
    who = string.gsub(who, "'s$", "")
    if not (RC.class[who] or who == ME) then return end
    RC.TauntFailed(who, spell, target, how)
  end

  -- ---------------------------------------------------------------- overaggro

  -- a boss (elites too if asked) turning to someone: who held it first is its tank; one who taunted it is a tank;
  -- anyone else taking it is an overaggro. A new target must hold 0.8 s (spells aimed at a player swap it briefly).
  function RC.Seen(key, mob, target, now)
    local st = RC.mobs[key]
    if not st then st = {} RC.mobs[key] = st end
    if not target then return end
    if target == st.holder then
      st.cand = nil
      if st.since and now - st.since > 6 then RC.tanks[target] = true end
      return
    end
    if st.cand ~= target then st.cand, st.candAt = target, now return end
    if now - st.candAt < .8 then return end
    local old = st.holder
    st.holder, st.since, st.cand = target, now, nil
    if not On("aggro") then return end
    if not old then
      RC.tanks[target] = true
      RC.Add("|cffccccccPULL|r |cffffffff" .. mob .. "|r on " .. Name(target), .8, .8, .8)
    elseif RC.taunted[target] and now - RC.taunted[target] < 4 then
      -- (the taunt line said it)
    elseif RC.tanks[target] then
      RC.Add("|cffccccccSWAP|r |cffffffff" .. mob .. "|r > " .. Name(target), .8, .8, .8)
    else
      RC.Add("|cffff3030OVERAGGRO|r " .. Name(target) .. " pulled |cffffffff" .. mob .. "|r off " .. Name(old), 1, .35, .35)
    end
  end
  local scan = CreateFrame("Frame")
  scan.t = 0
  scan:SetScript("OnUpdate", function()
    this.t = this.t + arg1
    if this.t < .25 then return end
    this.t = 0
    if not (On("aggro") and RC.inRaid and UnitAffectingCombat("player")) then return end
    local n = GetNumRaidMembers()
    local done = {}
    local now = GetTime()
    for i = 1, n do
      local u = "raid" .. i .. "target"
      if UnitExists(u) and UnitCanAttack("player", u) and UnitAffectingCombat(u) and not UnitIsDead(u) then
        local cls = UnitClassification(u)
        if cls == "worldboss" or (On("elites") and (cls == "elite" or cls == "rareelite")) then
          local _, guid = UnitExists(u)
          local key = guid or UnitName(u)
          if key and not done[key] then
            done[key] = true
            RC.Seen(key, UnitName(u), UnitName(u .. "target"), now)
          end
        end
      end
    end
  end)

  -- ---------------------------------------------------------------- healer mana when a fight ends

  RC.HEALERS = { PRIEST = true, DRUID = true, SHAMAN = true, PALADIN = true }
  -- list = { { name, class, mana %, dead } } (from the raid, or a test)
  function RC.ManaLine(list)
    if table.getn(list) == 0 then return end
    table.sort(list, function(a, b) return a[3] < b[3] end)
    local sum, parts = 0, {}
    for _, h in ipairs(list) do
      sum = sum + h[3]
      local p = h[3]
      local col = p < 30 and "|cffff4040" or (p < 60 and "|cffffcc33" or "|cff40d966")
      table.insert(parts, Name(h[1]) .. " " .. (h[4] and "|cff888888dead|r" or (col .. p .. "%|r")))
    end
    local avg = math.floor(sum / table.getn(list) + .5)
    local col = avg < 30 and "|cffff4040" or (avg < 60 and "|cffffcc33" or "|cff40d966")
    return RC.Add("|cff66ccffHEALER MANA|r " .. col .. avg .. "% avg|r  " .. table.concat(parts, "  "), .8, .9, 1)
  end
  function RC.Mana()
    if not On("mana") then return end
    local list = {}
    for i = 1, GetNumRaidMembers() do
      local u = "raid" .. i
      local n = UnitName(u)
      local _, token = UnitClass(u)
      if n and token and RC.HEALERS[token] and UnitPowerType(u) == 0 and (UnitManaMax(u) or 0) > 0 then
        local dead = UnitIsDeadOrGhost(u)
        table.insert(list, { n, token, dead and 0 or math.floor(UnitMana(u) * 100 / UnitManaMax(u) + .5), dead })
      end
    end
    RC.ManaLine(list)
  end

  -- ---------------------------------------------------------------- loot

  local QCOL = { ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2, ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5, ["e6cc80"] = 6 }
  function RC.Loot(text)
    if not (On("loot") and text) then return end
    local _, _, hex = string.find(text, "|cff(%x%x%x%x%x%x)|Hitem:")
    local q = hex and QCOL[string.lower(hex)]
    if not q or q < (tonumber(S().lootq) or 4) then return end
    local _, _, who, link = string.find(text, "^(.-) receives? loot: (.+)%.$")
    if not who then return end
    if who == "You" then who = ME end
    RC.Add("|cffffd100LOOT|r " .. Name(who) .. " " .. link, 1, .85, .35)
  end

  -- ---------------------------------------------------------------- the other chat goes quiet in a raid

  RC.QUIET = { CHAT_MSG_CHANNEL = true }
  RC.QUIETSAY = { CHAT_MSG_SAY = true, CHAT_MSG_YELL = true, CHAT_MSG_EMOTE = true, CHAT_MSG_TEXT_EMOTE = true }
  function RC.ApplyQuiet()
    RC.quieted = RC.inRaid and On("quiet") and true or false
  end
  -- (1.12: each chat window's OnEvent calls ChatFrame_OnEvent(event) by name, so this one wrap covers all of them)
  if type(_G.ChatFrame_OnEvent) == "function" then
    local orig = _G.ChatFrame_OnEvent
    _G.ChatFrame_OnEvent = function(e, a2, a3, a4, a5)
      local evt = e or event
      if RC.quieted and (RC.QUIET[evt] or (On("quietsay") and RC.QUIETSAY[evt])) then return end
      return orig(e, a2, a3, a4, a5)
    end
  end

  -- ---------------------------------------------------------------- the raid

  function RC.Roster()
    local was = RC.inRaid
    RC.inRaid = InRaid()
    RC.class, RC.rank = {}, {}
    for i = 1, (GetNumRaidMembers and GetNumRaidMembers() or 0) do
      local name, rank, _, _, _, token = GetRaidRosterInfo(i)
      if name then RC.class[name], RC.rank[name] = token, rank or 0 end
    end
    if RC.test then
      for n, c in pairs(RC.testClass or {}) do RC.class[n] = c end
    end
    if RC.inRaid and not was then
      RC.tanks, RC.mobs, RC.taunted = {}, {}, {}
      if On("auto") then RC.Show() end
    elseif was and not RC.inRaid then
      RC.tanks, RC.mobs = {}, {}
      if On("autohide") and not RC.test then RC.Hide() end
    end
    RC.ApplyQuiet()
    RC.Paint()
  end

  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "RAID_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
                       "CHAT_MSG_RAID_WARNING", "CHAT_MSG_LOOT", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
                       "CHAT_MSG_SPELL_SELF_DAMAGE", "CHAT_MSG_SPELL_PARTY_DAMAGE", "CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE",
                       "UNIT_CASTEVENT" }) do
    pcall(ev.RegisterEvent, ev, e)
  end
  function RC.OnEvent(evt, a1, a2, a3, a4)
    if evt == "RAID_ROSTER_UPDATE" or evt == "PLAYER_ENTERING_WORLD" then RC.Roster() return end
    if not RC.inRaid and not RC.test then return end
    if evt == "CHAT_MSG_RAID" or evt == "CHAT_MSG_RAID_LEADER" or evt == "CHAT_MSG_RAID_WARNING" then
      RC.Raid(a2, a1, string.sub(evt, 10))
    elseif evt == "CHAT_MSG_LOOT" then
      RC.Loot(a1)
    elseif evt == "PLAYER_REGEN_DISABLED" then
      RC.fightAt = GetTime()
    elseif evt == "PLAYER_REGEN_ENABLED" then
      RC.mobs = {}
      -- the healers' mana a moment after the fight (short trash pulls say nothing)
      if RC.fightAt and GetTime() - RC.fightAt >= (tonumber(S().manafight) or 20) then RC.manaAt = GetTime() + 1.5 end
      RC.fightAt = nil
    elseif evt == "UNIT_CASTEVENT" then
      -- SuperWoW: caster, target, kind, spell id
      if a3 ~= "CAST" then return end
      local spell = SpellName(a4)
      if not (spell and RC.TAUNTS[spell]) then return end
      local who = UnitName(a1)
      if not (who and (RC.class[who] or who == ME) and UnitIsPlayer(a1)) then return end
      RC.Taunt(who, spell, a2 and UnitName(a2))
    else
      RC.CombatLine(a1)
    end
  end
  ev:SetScript("OnEvent", function() RC.OnEvent(event, arg1, arg2, arg3, arg4) end)
  ev:SetScript("OnUpdate", function()
    if RC.manaAt and GetTime() >= RC.manaAt then
      RC.manaAt = nil
      RC.Mana()
    end
  end)

  -- ---------------------------------------------------------------- a made-up raid to see it

  function RC.Test()
    RC.test = true
    RC.testLooter = "Brenna"
    RC.testClass = { Brenna = "WARRIOR", Corvin = "WARRIOR", Jaina = "MAGE", Thrall = "SHAMAN", Anduin = "PRIEST",
                     Malfurion = "DRUID", Uther = "PALADIN", Valeera = "ROGUE", Rexxar = "HUNTER" }
    RC.Roster()
    RC.rank.Brenna = 2
    RC.Show()
    RC.Clear()
    RC.Raid("Brenna", "Tanks on the boss, healers spread, no DPS until 3 sunders", "RAID_LEADER")
    for _, n in ipairs({ "Jaina", "Thrall", "Anduin", "Valeera" }) do RC.Raid(n, "+", "RAID") end
    RC.Seen("test-rag", "Ragnaros", "Brenna", 0) RC.Seen("test-rag", "Ragnaros", "Brenna", 1)
    RC.Taunt("Corvin", "Taunt", "Ragnaros")
    RC.TauntFailed("Corvin", "Taunt", "Ragnaros", "resisted")
    RC.Seen("test-rag", "Ragnaros", "Jaina", 10) RC.Seen("test-rag", "Ragnaros", "Jaina", 11)
    RC.Raid("Rexxar", "is it loot time yet", "RAID")
    RC.Raid("Brenna", "|cffa335ee|Hitem:16800:0:0:0|h[Arcanist Boots]|h|r - bid in whispers", "RAID")
    RC.Raid("Brenna", "Next pull in 30, drink up", "RAID_WARNING")
    RC.Raid("Malfurion", "+", "RAID")
    RC.ManaLine({ { "Anduin", "PRIEST", 18 }, { "Thrall", "SHAMAN", 44 }, { "Malfurion", "DRUID", 72 }, { "Uther", "PALADIN", 0, true } })
    RC.Loot("Jaina receives loot: |cffa335ee|Hitem:16800:0:0:0|h[Arcanist Boots]|h|r.")
    RC.Paint()
  end
  function RC.EndTest()
    RC.test, RC.testLooter, RC.testClass = nil, nil, nil
    RC.Clear()
    RC.Roster()
    if not RC.inRaid then RC.Hide() end
  end

  _G.SLASH_OCTORAIDCHAT1 = "/raidchat"
  _G.SlashCmdList.OCTORAIDCHAT = function(msg)
    msg = string.lower(msg or "")
    if msg == "test" then RC.Test()
    elseif msg == "hide" then RC.Hide()
    elseif msg == "clear" then RC.Clear()
    elseif msg == "quiet" then S().quiet = On("quiet") and "0" or "1" RC.ApplyQuiet() RC.Paint()
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r: quiet chat in raids " .. (On("quiet") and "on" or "off"))
    elseif F and F:IsShown() then RC.Hide()
    else RC.Show() end
  end
end)
