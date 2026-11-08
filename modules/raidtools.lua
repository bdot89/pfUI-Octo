pfUI:RegisterModule("raidtools", "vanilla:tbc", function ()
  -- pfUI Octo :: Raid Tools (8 Nov 2026; user with EllesmereUI's Quality of
  -- Life > Raid Tools: "raid markers auto loot everything in here"). Our own
  -- small window, written fresh: Ready Check, Convert to Raid, Disband, a pull
  -- countdown (3 / 5 / 10 s, Stop) and the eight target markers + clear.
  -- 1.12 has no world markers and no role check, so those are not here.
  -- Settings C.raidtools: show = never | group | raid | lead | always,
  -- collapsed, scale. Moved in layout mode (pfRaidTools).

  local RT = {}
  pfUI.raidtools = RT
  local function S() return C.raidtools end

  local MEDIA = "Interface\\Buttons\\WHITE8X8"
  local MARKS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
  local BW, GAP = 24, 3

  local f = CreateFrame("Frame", "pfRaidTools", UIParent)
  f:SetFrameStrata("MEDIUM")
  f:SetWidth(8 * (BW + GAP) + BW + 12)
  f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -160)
  f:SetMovable(true)
  f:EnableMouse(true)
  CreateBackdrop(f, nil, nil, .85)
  CreateBackdropShadow(f)
  f:Hide()
  RT.frame = f

  -- title bar: name, collapse
  local title = f:CreateFontString(nil, "OVERLAY")
  title:SetFont(pfUI.font_default, 11, "OUTLINE")
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -5)
  title:SetText("Raid Tools")
  local fold = CreateFrame("Button", nil, f)
  fold:SetWidth(16)
  fold:SetHeight(14)
  fold:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -3)
  fold.text = fold:CreateFontString(nil, "OVERLAY")
  fold.text:SetFont(pfUI.font_default, 12, "OUTLINE")
  fold.text:SetPoint("CENTER", fold, "CENTER", 0, 1)
  fold:SetScript("OnClick", function()
    S().collapsed = (S().collapsed == "1") and "0" or "1"
    RT.Layout()
  end)

  local body = CreateFrame("Frame", nil, f)
  body:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -20)
  body:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -20)
  body:SetHeight(10)

  local function Tip(b, head, text)
    b:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:AddLine(head)
      if text then GameTooltip:AddLine(text, 1, 1, 1, 1) end
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end

  local function Btn(text, w, fn, tip)
    local b = CreateFrame("Button", nil, body)
    b:SetWidth(w)
    b:SetHeight(18)
    CreateBackdrop(b, nil, true)
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetFont(pfUI.font_default, 10, "OUTLINE")
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.text:SetText(text)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(MEDIA)
    hl:SetVertexColor(1, 1, 1, .1)
    hl:SetAllPoints(b)
    b:SetScript("OnClick", fn)
    Tip(b, text, tip)
    return b
  end

  local function Leader() return IsPartyLeader() or IsRaidLeader() end
  local function Assist() return Leader() or (IsRaidOfficer and IsRaidOfficer()) end
  local function InGroup() return GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0 end

  -- the pull countdown: one message a second, to raid warning when allowed
  local count = CreateFrame("Frame", nil, f)
  count:Hide()
  local function Say(msg)
    local chan
    if GetNumRaidMembers() > 0 then chan = Assist() and "RAID_WARNING" or "RAID"
    elseif GetNumPartyMembers() > 0 then chan = "PARTY" end
    if chan then SendChatMessage(msg, chan) else DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffRaid Tools|r: " .. msg) end
  end
  count:SetScript("OnUpdate", function()
    local left = math.ceil((this.at or 0) - GetTime())
    if left ~= this.last then
      this.last = left
      if left <= 0 then
        Say("Pull now!")
        this:Hide()
      else
        Say("Pull in " .. left)
      end
    end
  end)
  function RT.Pull(sec)
    if not sec or sec <= 0 then
      if count:IsShown() then Say("Pull stopped") end
      count:Hide()
      return
    end
    count.at, count.last = GetTime() + sec, nil
    count:Show()
  end

  local half = (f:GetWidth() - 12 - GAP) / 2
  local rows = {}
  rows[1] = {
    Btn("Ready Check", half, function() if Assist() then DoReadyCheck() end end, "Asks everyone if they are ready (leader or assist)."),
    Btn("Convert to Raid", half, function() if Leader() and GetNumRaidMembers() == 0 then ConvertToRaid() end end, "Your party becomes a raid (leader)."),
  }
  rows[2] = {
    Btn("Disband", half, function()
      if not Leader() then return end
      CreateQuestionDialog("Disband the group? Everyone is removed, then you leave.", function()
        if GetNumRaidMembers() > 0 then
          for i = GetNumRaidMembers(), 1, -1 do
            local name = GetRaidRosterInfo(i)
            if name and name ~= UnitName("player") then UninviteByName(name) end
          end
        else
          for i = GetNumPartyMembers(), 1, -1 do
            local name = UnitName("party" .. i)
            if name then UninviteByName(name) end
          end
        end
        LeaveParty()
      end)
    end, "Removes everyone and leaves (leader). Asks first."),
    Btn("Stop", half, function() RT.Pull(0) end, "Stops a running pull countdown."),
  }
  local q = (f:GetWidth() - 12 - 2 * GAP) / 3
  rows[3] = {
    Btn("Pull 3", q, function() RT.Pull(3) end, "A 3 second pull countdown in raid warning (party chat in a party)."),
    Btn("Pull 5", q, function() RT.Pull(5) end, "A 5 second pull countdown."),
    Btn("Pull 10", q, function() RT.Pull(10) end, "A 10 second pull countdown."),
  }
  -- the target markers: 1 star .. 8 skull, then clear
  local markRow = CreateFrame("Frame", nil, body)
  markRow:SetHeight(BW)
  local markLabel = body:CreateFontString(nil, "OVERLAY")
  markLabel:SetFont(pfUI.font_default, 9, "OUTLINE")
  markLabel:SetTextColor(.7, .7, .7)
  markLabel:SetText("Target markers")
  local NAMES = { "Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull" }
  for i = 1, 9 do
    local m = CreateFrame("Button", nil, markRow)
    m:SetWidth(BW)
    m:SetHeight(BW)
    m:SetPoint("LEFT", markRow, "LEFT", (i - 1) * (BW + GAP), 0)
    m.tex = m:CreateTexture(nil, "ARTWORK")
    m.tex:SetAllPoints(m)
    if i <= 8 then
      m.tex:SetTexture(MARKS)
      local col, row = math.mod(i - 1, 4), math.floor((i - 1) / 4)
      m.tex:SetTexCoord(col * .25, (col + 1) * .25, row * .25, (row + 1) * .25)
      Tip(m, NAMES[i], "Puts this mark on your target (click again to take it off).")
    else
      m.tex:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
      Tip(m, "Clear", "Takes the mark off your target.")
    end
    local hl = m:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(MEDIA)
    hl:SetVertexColor(1, 1, 1, .15)
    hl:SetAllPoints(m)
    m.i = i
    m:SetScript("OnClick", function()
      if not UnitExists("target") then return end
      local cur = GetRaidTargetIndex and GetRaidTargetIndex("target")
      if this.i > 8 or cur == this.i then SetRaidTarget("target", 0) else SetRaidTarget("target", this.i) end
    end)
  end

  -- stacks the rows; folded = the title bar only
  function RT.Layout()
    local s = S()
    f:SetScale(tonumber(s.scale) or 1)
    local folded = s.collapsed == "1"
    fold.text:SetText(folded and "+" or "-")
    if folded then
      body:Hide()
      f:SetHeight(20)
      return
    end
    body:Show()
    local y = 0
    for _, r in ipairs(rows) do
      local x = 0
      for _, b in ipairs(r) do
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", body, "TOPLEFT", x, -y)
        x = x + b:GetWidth() + GAP
      end
      y = y + 18 + GAP
    end
    markLabel:ClearAllPoints()
    markLabel:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y - 1)
    y = y + 12
    markRow:ClearAllPoints()
    markRow:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
    markRow:SetWidth(9 * (BW + GAP))
    y = y + BW
    f:SetHeight(20 + y + 6)
  end

  -- when it shows
  function RT.Update()
    local s = S()
    local show = s.show or "group"
    local on
    if show == "always" then on = true
    elseif show == "group" then on = InGroup()
    elseif show == "raid" then on = GetNumRaidMembers() > 0
    elseif show == "lead" then on = InGroup() and Assist()
    end
    if pfUI.unlock and pfUI.unlock.IsShown and pfUI.unlock:IsShown() then on = true end
    RT.Layout()
    if on then f:Show() else f:Hide() end
  end
  function RT:UpdateConfig() RT.Update() end

  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE", "PARTY_LEADER_CHANGED" }) do ev:RegisterEvent(e) end
  ev:SetScript("OnEvent", function() RT.Update() end)

  if UpdateMovable then UpdateMovable(f) end
  RT.Update()
end)
