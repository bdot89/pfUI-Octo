pfUI:RegisterModule("octorank-timer", "vanilla:tbc", function ()
  -- pfUI Octo :: the OctoRanks run timer (25 Nov 2026). User: "make sure people know when entering a 5man ... when they
  -- pull first mob a timer starts. People can enable or disable a timer to see their run time live. Make a tidy timer".
  -- Reads the engine that runs (pfUI's copy, the OctoRank add-on or WhoDidIt: the same Runs table) and draws:
  --   waiting  - inside a 5-man at 60, no run yet: "the timer starts at your first pull"
  --   running  - the dungeon, bosses down, the time live, a bar against your best (green ahead, red behind),
  --              the realm's fastest, and each boss's split as it dies
  --   done     - the final time in green and where it ranks on the board (10 minutes, while still inside)
  -- The engine's own small timer stands aside while this one is on (C.octorank.timer).
  local OR = pfUI.octorank
  if not OR then return end
  local CFG = C.octorank
  local function On(k) return CFG[k] == "1" end
  local floor = math.floor
  local function Clock(secs)
    secs = floor(tonumber(secs) or 0)
    if secs < 0 then secs = 0 end
    if secs >= 3600 then return string.format("%d:%02d:%02d", floor(secs / 3600), floor(math.mod(secs, 3600) / 60), math.mod(secs, 60)) end
    return string.format("%d:%02d", floor(secs / 60), math.mod(secs, 60))
  end
  local FONT = "Interface\\AddOns\\pfUI\\fonts\\FiraSansCondensed-SemiBold.ttf"
  local NUM = "Interface\\AddOns\\pfUI\\fonts\\Expressway.ttf"
  local WHITE = "Interface\\Buttons\\WHITE8X8"
  local W, H, SPLITS = 250, 86, 8

  local T = {}
  OR.timer = T

  -- what to show now, or nil: { state = "wait" | "run" | "done", title, secs, n, of, best, top, place, of2, splits = { { name, secs } } }
  function T.State(now)
    local kind, eng = OR.Engine()
    if not kind or not eng.Runs then return nil end
    local R, D, B = eng.Runs, eng.Data, eng.Board
    local inside, itype = IsInInstance()
    if not inside or itype ~= "party" then return nil end
    local zone = GetRealZoneText() or ""
    local ok, r = pcall(R.Current, R)
    if not ok then r = nil end
    now = now or time()
    if not r or (r.zone and r.zone ~= zone) then
      if (UnitLevel("player") or 0) < 60 or not On("waiting") then return nil end
      return { state = "wait", title = zone }
    end
    local dg = r.key and D and D.DUNGEON and D.DUNGEON[r.key]
    local s = { title = dg and dg.title or zone, splits = {} }
    s.secs = r.cs or (now - (r.at or now))
    if r.cs and r.at and now - (r.at + r.cs) > 600 then return nil end
    s.state = r.cs and "done" or "run"
    -- bosses down, in the order they died
    local n = 0
    if type(r.k) == "table" then
      for name, at in pairs(r.k) do
        n = n + 1
        table.insert(s.splits, { name, at })
      end
      table.sort(s.splits, function(a, b) return (a[2] or 0) < (b[2] or 0) end)
    end
    s.n = n
    s.of = dg and dg.bosses and table.getn(dg.bosses) or nil
    -- the pace: your best, the realm's fastest, and for a finished run its place
    local key = r.key or (dg and dg.key)
    if key then
      local okB, best = pcall(R.MyBest, R, key)
      if okB and best then s.best = best.t end
      local realm = B and B.Realm and B.Realm() or GetRealmName()
      local okL, list = pcall(R.Board, R, realm, key, "All")
      if okL and type(list) == "table" and list[1] then s.top, s.topName = list[1][2].t, list[1][2].g end
      if r.cs then
        local okP, place, of2 = pcall(R.Place, R, realm, key, r.cs, "All")
        if okP then s.place, s.of2 = place, of2 end
      end
    end
    return s
  end

  -- ---------------------------------------------------------------- the frame
  local holder = CreateFrame("Frame", "pfOctoRankTimer", UIParent)
  holder:SetPoint("TOP", UIParent, "TOP", 0, -140)
  holder:SetWidth(W)
  holder:SetHeight(H)
  holder:SetFrameStrata("MEDIUM")
  T.holder = holder
  local f = CreateFrame("Frame", nil, holder)
  f:SetAllPoints(holder)
  if CreateBackdrop then CreateBackdrop(f, nil, nil, .85) end
  T.frame = f
  local function Text(font, size, r, g, b)
    local fs = f:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font, size, "OUTLINE")
    fs:SetTextColor(r or 1, g or 1, b or 1)
    return fs
  end
  local ar, ag, ab = 1, .82, .2
  if pfUI.api and pfUI.api.GetAccentColor then
    local ok, r1, g1, b1 = pcall(pfUI.api.GetAccentColor)
    if ok and r1 then ar, ag, ab = r1, g1, b1 end
  end
  -- a thin gold line along the top
  f.line = f:CreateTexture(nil, "ARTWORK")
  f.line:SetTexture(WHITE)
  f.line:SetHeight(2)
  f.line:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  f.line:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  f.line:SetGradientAlpha("HORIZONTAL", 1, .82, .2, .15, 1, .82, .2, .9)
  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetTexture("Interface\\AddOns\\pfUI\\img\\octo\\icons\\rank")
  f.icon:SetVertexColor(1, .82, .2)
  f.icon:SetWidth(14)
  f.icon:SetHeight(14)
  f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", 7, -7)
  f.title = Text(FONT, 12, 1, .82, .2)
  f.title:SetPoint("LEFT", f.icon, "RIGHT", 5, 0)
  f.title:SetPoint("RIGHT", f, "RIGHT", -52, 0)
  f.title:SetJustifyH("LEFT")
  f.count = Text(FONT, 12, 1, 1, 1)
  f.count:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -7)
  f.count:SetJustifyH("RIGHT")
  f.time = Text(NUM, 26, 1, 1, 1)
  f.time:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -24)
  f.state = Text(FONT, 11, .7, .72, .76)
  f.state:SetPoint("BOTTOMLEFT", f.time, "BOTTOMRIGHT", 8, 3)
  -- the pace bar: the time against your best (else the realm's fastest)
  f.bar = CreateFrame("StatusBar", nil, f)
  f.bar:SetStatusBarTexture(pfUI.media and pfUI.media["img:bar"] or WHITE)
  f.bar:SetHeight(5)
  f.bar:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -58)
  f.bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -58)
  f.bar:SetMinMaxValues(0, 1)
  f.bar.bg = f.bar:CreateTexture(nil, "BACKGROUND")
  f.bar.bg:SetAllPoints(f.bar)
  f.bar.bg:SetTexture(1, 1, 1, .08)
  f.pace = Text(FONT, 11, .7, .72, .76)
  f.pace:SetPoint("TOPLEFT", f.bar, "BOTTOMLEFT", 0, -4)
  f.pace:SetPoint("TOPRIGHT", f.bar, "BOTTOMRIGHT", 0, -4)
  f.pace:SetJustifyH("LEFT")
  -- the boss splits, one line each under the rest
  f.split = {}
  for i = 1, SPLITS do
    local l = Text(FONT, 11, .86, .87, .9)
    l:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -H - (i - 1) * 14 + 6)
    l:SetPoint("RIGHT", f, "RIGHT", -10, 0)
    l:SetJustifyH("LEFT")
    l.right = Text(NUM, 11, .86, .87, .9)
    l.right:SetPoint("TOP", l, "TOP", 0, 0)
    l.right:SetPoint("RIGHT", f, "RIGHT", -10, 0)
    f.split[i] = l
  end
  holder:EnableMouse(true)
  holder:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
    GameTooltip:SetText("OctoRanks run timer", 1, .82, .2)
    GameTooltip:AddLine("The official time: from the first pull after you zone in to the last boss, the way the 5-man boards count it.", .9, .9, .9, 1)
    GameTooltip:AddLine("Bar: your time against your best in this dungeon (green = ahead).", .7, .7, .7, 1)
    GameTooltip:AddLine("Move it in layout mode (/moveui). Switch it off: pfUI options > OctoRanks.", .5, .7, 1, 1)
    GameTooltip:Show()
  end)
  holder:SetScript("OnLeave", function() GameTooltip:Hide() end)
  if UpdateMovable then UpdateMovable(holder) end
  holder:Hide()

  local SAMPLE = { state = "run", title = "Stratholme (Undead)", secs = 754, n = 3, of = 7, best = 1314, top = 1314, topName = "Ludenlord's group",
    splits = { { "Magistrate Barthilas", 198 }, { "Stonespine", 402 }, { "Baroness Anastari", 690 } } }

  function T.Paint(s)
    local splits = (s.state ~= "wait" and On("splits")) and math.min(SPLITS, table.getn(s.splits or {})) or 0
    holder:SetHeight(H + (splits > 0 and (splits * 14 + 4) or 0) - (s.state == "wait" and 22 or 0))
    holder:SetScale(tonumber(CFG.scale) or 1)
    f.title:SetText(s.title or "")
    if s.state == "wait" then
      f.count:SetText("")
      f.time:SetText("|cff8a8c92--:--|r")
      f.state:SetText("")
      f.bar:Hide()
      f.pace:ClearAllPoints()
      f.pace:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -54)
      f.pace:SetPoint("RIGHT", f, "RIGHT", -8, 0)
      f.pace:SetText("|cffffd24dThe timer starts at your first pull.|r")
    else
      f.pace:ClearAllPoints()
      f.pace:SetPoint("TOPLEFT", f.bar, "BOTTOMLEFT", 0, -4)
      f.pace:SetPoint("TOPRIGHT", f.bar, "BOTTOMRIGHT", 0, -4)
      f.count:SetText(s.of and ((s.n >= s.of and "|cff55ff55" or "|cffffffff") .. s.n .. "/" .. s.of .. "|r") or (s.n .. " |cff8a8c92bosses|r"))
      local done = s.state == "done"
      f.time:SetText((done and "|cff55ff55" or "|cffffffff") .. Clock(s.secs) .. "|r")
      local ref = s.best or s.top
      if done then
        f.state:SetText(s.place and ("|cffffd24d#" .. s.place .. "|r |cff8a8c92of " .. (s.of2 or s.place) .. " on the board|r") or "|cff55ff55done|r")
      elseif ref then
        local diff = s.secs - ref
        f.state:SetText(diff <= 0 and ("|cff55ff55" .. Clock(-diff) .. " ahead|r") or ("|cffff6a55" .. Clock(diff) .. " behind|r"))
      else
        f.state:SetText("|cff8a8c92first run here|r")
      end
      if ref and ref > 0 then
        f.bar:Show()
        f.bar:SetValue(math.min(1, s.secs / ref))
        if s.secs <= ref then f.bar:SetStatusBarColor(.3, .85, .4) else f.bar:SetStatusBarColor(.95, .35, .3) end
      else
        f.bar:Show()
        f.bar:SetValue(0)
      end
      local parts = {}
      if s.best then table.insert(parts, "your best |cffffffff" .. Clock(s.best) .. "|r") end
      if s.top then table.insert(parts, "realm #1 |cffffffff" .. Clock(s.top) .. "|r") end
      f.pace:SetText(table.getn(parts) > 0 and table.concat(parts, "   ") or "|cff8a8c92no times on the board yet|r")
    end
    for i = 1, SPLITS do
      local l, e = f.split[i], s.splits and s.splits[i]
      if i <= splits and e then
        l:SetText("|cff55ff55+|r " .. e[1])
        l.right:SetText(Clock(e[2]))
        l:Show() l.right:Show()
      else
        l:Hide() l.right:Hide()
      end
    end
  end

  -- the engine's small timer stands aside while ours is on
  local function Quiet()
    local old = _G.OctoRankRunTimer
    if not old or old.octoQuiet then return end
    old.octoQuiet = true
    local show = old.Show
    old.Show = function(self) if On("timer") then return end return show(self) end
    old:Hide()
  end

  local said = {}
  local lastState
  function T.Update()
    local layout = pfUI.unlock and pfUI.unlock.IsShown and pfUI.unlock:IsShown()
    local real = T.State()
    local s = On("timer") and real or nil
    if not s and layout and On("timer") then s = SAMPLE end
    if On("timer") then Quiet() end
    -- what the player is told (timer on or off): each time into a dungeon, and when the clock starts
    local st = real and real.state
    if st ~= lastState then
      if st == "wait" then
        local zone = real.title or ""
        if not said[zone] or GetTime() - said[zone] > 300 then
          said[zone] = GetTime()
          if UIErrorsFrame then UIErrorsFrame:AddMessage("OctoRanks: the run timer starts at your first pull", 1, .82, .2, 1, 5) end
        end
      elseif st == "run" and lastState == "wait" then
        if UIErrorsFrame then UIErrorsFrame:AddMessage("OctoRanks: run timer started - good luck!", .4, 1, .5, 1, 4) end
      end
      lastState = st
    end
    if not s then
      if holder:IsShown() then holder:Hide() end
      return
    end
    T.Paint(s)
    if not holder:IsShown() then holder:Show() end
  end
  local tick = 0
  holder.ticker = CreateFrame("Frame")
  holder.ticker:SetScript("OnUpdate", function()
    tick = tick + (arg1 or 0)
    if tick < .25 then return end
    tick = 0
    T.Update()
  end)
  T.SAMPLE = SAMPLE
end)
