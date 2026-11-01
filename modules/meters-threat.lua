pfUI:RegisterModule("meters-threat", "vanilla", function ()
  -- pfUI Octo threat meter data. The numbers come from the server, asked
  -- the way the TWThreat addon asks (written fresh here: TWThreat has no
  -- licence): every 0.5 s, while you are in a group and your target is a
  -- mob in combat, SendAddonMessage("TWT_UDTSv4", "limit=N", RAID|PARTY).
  -- The answer is CHAT_MSG_ADDON with "TWTv4=Name:tank:threat:perc:melee;..."
  -- (a tank-mode tail after "#" is skipped). perc is the % of the tank's
  -- threat; the server moves the mob at 110 % in melee range, 130 % at range.
  -- When anyone (TWThreat, OctoBG) got an answer in the last 0.45 s, we do
  -- not ask again. Unverified on this server: after GIVE_UP unanswered asks
  -- the window says so and asking stops until the next zone change.
  if C.meters.enable ~= "1" or C.meters.threat ~= "1" then return end
  if not pfUI.meters then return end

  local M = pfUI.meters
  local TH = { list = nil, at = 0, silent = 0, answers = 0, gaveUp = nil, warned = nil }
  M.threat = TH
  local GIVE_UP = 20

  -- "TWTv4=Name:tank:threat:perc:melee;..." -> sorted list or nil
  function TH.Parse(msg)
    if type(msg) ~= "string" then return end
    local _, e = string.find(msg, "TWTv4=", 1, true)
    if not e then return end
    local body = string.sub(msg, e + 1)
    local cut = string.find(body, "#", 1, true)
    if cut then body = string.sub(body, 1, cut - 1) end
    local out = {}
    for name, tank, threat, perc, melee in string.gfind(body, "([^:;]+):(%d+):(%-?%d+):([%-%d%.]+):(%d+)") do
      table.insert(out, { name = name, tank = (tank == "1"), threat = tonumber(threat) or 0,
                          perc = tonumber(perc) or 0, melee = (melee == "1") })
    end
    if table.getn(out) == 0 then return end
    table.sort(out, function(a, b) return a.threat > b.threat end)
    return out
  end

  local function InGroup() return GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0 end
  -- solo with a pet tanking (1 Nov 2026, GratisNinja: a warlock and his Voidwalker):
  -- asked by a whisper to yourself; a server that never answers that is left alone
  -- (TH.soloGaveUp) without stopping the group asks
  local function Solo() return not InGroup() and C.meters.threatsolo ~= "0" and UnitExists("pet") end

  -- in a group, the target a mob you can attack, in combat
  function TH.Wanted()
    if not InGroup() and not (Solo() and not TH.soloGaveUp) then return false end
    if not UnitExists("target") or UnitIsPlayer("target") or not UnitCanAttack("player", "target") then return false end
    return UnitAffectingCombat("target") and true or false
  end

  function TH.Ask()
    if not TH.Wanted() or TH.gaveUp then return end
    if GetTime() - TH.at < .45 then return end
    if Solo() then
      if pcall(SendAddonMessage, "TWT_UDTSv4", "limit=10", "WHISPER", UnitName("player")) then
        TH.soloSilent = (TH.soloSilent or 0) + 1
        if TH.soloSilent >= GIVE_UP and not TH.soloAnswered then TH.soloGaveUp = true end
      end
      return
    end
    if pcall(SendAddonMessage, "TWT_UDTSv4", "limit=10", GetNumRaidMembers() > 0 and "RAID" or "PARTY") then
      TH.silent = TH.silent + 1
      if TH.silent >= GIVE_UP and TH.answers == 0 then TH.gaveUp = true end
    end
  end

  -- what the window shows when there are no numbers
  function TH.Status()
    if TH.gaveUp then return T["No threat data from this server"] end
    if Solo() and TH.soloGaveUp then return T["This server sends threat in a group only"] end
    if not InGroup() and not Solo() then return T["Threat shows in a group, or solo with a pet"] end
    if not TH.Wanted() then return T["Target a mob in combat"] end
    if TH.answers == 0 then return T["Asking the server..."] end
  end

  -- your share of the pull point: 1.0 = you pull aggro
  function TH.Mine()
    if not TH.list then return end
    local me = UnitName("player")
    for _, e in ipairs(TH.list) do
      if e.name == me then
        if e.tank then return nil, e end
        local pull = e.melee and 110 or 130
        return e.perc / pull, e
      end
    end
  end

  local f = CreateFrame("Frame", "pfMetersThreat", UIParent)
  f:RegisterEvent("CHAT_MSG_ADDON")
  f:RegisterEvent("PLAYER_TARGET_CHANGED")
  f:RegisterEvent("PLAYER_REGEN_ENABLED")
  f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  f:SetScript("OnEvent", function()
    if event == "CHAT_MSG_ADDON" then
      if type(arg2) ~= "string" or not string.find(arg2, "TWTv4=", 1, true) then return end
      local list = TH.Parse(arg2)
      if not list then return end
      TH.list, TH.at, TH.silent, TH.answers = list, GetTime(), 0, TH.answers + 1
      if Solo() then TH.soloAnswered, TH.soloSilent = true, 0 end
      TH.Warn()
      M.Changed()
    elseif event == "ZONE_CHANGED_NEW_AREA" then
      TH.gaveUp, TH.silent, TH.answers = nil, 0, 0
    else
      TH.list, TH.warned = nil, nil
      M.Changed()
    end
  end)

  f:SetScript("OnUpdate", function()
    if (this.tick or 0) > GetTime() then return end
    this.tick = GetTime() + .5
    TH.Ask()
    -- answers older than 3 s are stale
    if TH.list and GetTime() - TH.at > 3 then
      TH.list = nil
      M.Changed()
    end
  end)

  -- ---------------------------------------------------------------- your cap
  -- (moved from OctoBG's Threat.lua, 23 Oct 2026 - the user: "bring the
  -- threat section over here and add to it"). Your cap: stay under
  -- C.meters.threatwarn % of the pull point ("pull"), or of the 1st / 2nd /
  -- 3rd highest other player's threat (C.meters.threatref 1 / 2 / 3).
  -- Green, yellow from C.meters.tnear % of the cap, red past it.

  TH.REFS = { { "pull", "the pull point (110% melee, 130% range)" }, { "1", "the top player (the tank)" },
              { "2", "the top two" }, { "3", "the top three" } }

  -- what the label shows: { aggro, share (% of the reference), nextP, nextName, state 1 / 2 / 3 }
  function TH.Judge(list)
    local me = UnitName("player")
    local mine
    local others = {}
    for _, p in ipairs(list or {}) do
      if p.name == me then mine = p else table.insert(others, p) end
    end
    table.sort(others, function(a, b) return a.threat > b.threat end)
    local j = { aggro = mine and mine.tank }
    if j.aggro then
      local n = others[1]
      j.nextP, j.nextName = n and n.perc, n and n.name
      j.state = (j.nextP and j.nextP >= 90) and 2 or 1
      return j
    end
    local limit = math.max(1, tonumber(C.meters.threatwarn) or 90)
    local ref = C.meters.threatref or "pull"
    if ref == "pull" then
      local pull = (mine and mine.melee) and 110 or 130
      j.share = mine and (mine.perc / pull * 100) or 0
    else
      local r = others[math.min(tonumber(ref) or 1, table.getn(others))]
      local mineT = mine and mine.threat or 0
      j.share = (r and r.threat > 0) and (mineT / r.threat * 100) or 0
    end
    local f = j.share / limit
    local near = (tonumber(C.meters.tnear) or 80) / 100
    j.state = (f >= 1) and 3 or ((f >= near) and 2 or 1)
    return j
  end

  local function Col(s) local r, g, b = GetStringColor(s or "1,1,1,1") return tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1 end
  local function Hex(s)
    local r, g, b = Col(s)
    return string.format("|cff%02x%02x%02x", floor(r * 255), floor(g * 255), floor(b * 255))
  end
  local STATECOL = { "tcolsafe", "tcolnear", "tcolover" }

  function TH.Text(j)
    local look = C.meters.tlook
    local c = Hex(C.meters[STATECOL[j.state or 1]])
    if j.aggro then
      local s = Hex(C.meters.tcolaggro) .. (look == "number" and "AGGRO" or "Aggro") .. "|r"
      if C.meters.tnext == "1" and j.nextP and look ~= "number" then
        local who = (C.meters.tnextname == "1" and j.nextName) and (j.nextName .. " ") or ""
        s = s .. "  " .. c .. "next " .. who .. floor(j.nextP + .5) .. "%|r"
      end
      return s
    end
    local pct = floor((j.share or 0) + .5) .. "%"
    if look == "words" then return c .. T["Threat"] .. " " .. pct .. "|r" end
    return c .. pct .. "|r"
  end

  -- ---------------------------------------------------------------- the label

  local BAR_W, BAR_H = 70, 7
  -- a label: text, and a bar behind for the "bar" look (also the options' preview)
  function TH.NewLabel(parent, name)
    local l = CreateFrame("Frame", name, parent or UIParent)
    l:SetWidth(180)
    l:SetHeight(18)
    l:SetFrameStrata("HIGH")
    l.text = l:CreateFontString(nil, "OVERLAY")
    l.barBg = l:CreateTexture(nil, "BACKGROUND")
    l.barBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    l.barBg:SetVertexColor(0, 0, 0, .6)
    l.bar = l:CreateTexture(nil, "ARTWORK")
    l.bar:SetTexture("Interface\\Buttons\\WHITE8X8")
    l:Hide()
    return l
  end

  function TH.Paint(l, j)
    local outline = C.meters.toutline or ""
    if outline == "NONE" then outline = "" end
    l.text:SetFont(pfUI.font_unit or pfUI.font_default, tonumber(C.meters.tsize) or 13, outline)
    l.text:ClearAllPoints()
    if C.meters.tlook == "bar" and not j.aggro then
      local f = math.min(1, (j.share or 0) / math.max(1, tonumber(C.meters.threatwarn) or 90))
      local r, g, b = Col(C.meters[STATECOL[j.state or 1]])
      l.barBg:ClearAllPoints()
      l.barBg:SetPoint("LEFT", l, "LEFT", 4, 0)
      l.barBg:SetWidth(BAR_W)
      l.barBg:SetHeight(BAR_H)
      l.bar:ClearAllPoints()
      l.bar:SetPoint("LEFT", l.barBg, "LEFT", 0, 0)
      l.bar:SetWidth(math.max(1, BAR_W * f))
      l.bar:SetHeight(BAR_H)
      l.bar:SetVertexColor(r, g, b, 1)
      l.barBg:Show()
      l.bar:Show()
      l.text:SetPoint("LEFT", l.barBg, "RIGHT", 4, 0)
    else
      l.barBg:Hide()
      l.bar:Hide()
      l.text:SetPoint("CENTER", l, "CENTER", 0, 0)
    end
    l.text:SetText(TH.Text(j))
  end

  TH.LOOKS = { { "words", "Words: Threat 72%" }, { "number", "Just the number: 72%" }, { "bar", "A bar and the number" },
               { "none", "Nothing (popups only)" } }
  TH.PLACES = { { "above", "Above the nameplate" }, { "below", "Below the nameplate" }, { "left", "Left of the nameplate" },
                { "right", "Right of the nameplate" }, { "screen", "A box I place (Move frames)" } }
  local POINTS = { above = { "BOTTOM", "TOP" }, below = { "TOP", "BOTTOM" }, left = { "RIGHT", "LEFT" }, right = { "LEFT", "RIGHT" } }
  TH.POINTS = POINTS

  -- the label, and its box for "a box I place" (a pfUI mover)
  local label = TH.NewLabel(UIParent, "pfThreatLabel")
  TH.label = label
  local box = CreateFrame("Frame", "pfThreatBox", UIParent)
  box:SetWidth(180)
  box:SetHeight(22)
  box:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
  TH.box = box
  if UpdateMovable then UpdateMovable(box) end

  -- your target's nameplate (pfUI Octo's plates keep the ones on screen)
  function TH.TargetPlate()
    local Fx = pfUI.plates and pfUI.plates.Fx
    if not Fx or not Fx.Plates then return end
    for _, plate in ipairs(Fx.Plates()) do
      if plate.istarget and not (plate.parent and plate.parent.preview) then return plate end
    end
  end

  function TH.Place(l, plate)
    l:ClearAllPoints()
    if C.meters.twhere == "screen" then
      l:SetPoint("CENTER", box, "CENTER", 0, 0)
      return true
    end
    if not plate then return false end
    local p = POINTS[C.meters.twhere] or POINTS.above
    l:SetPoint(p[1], plate, p[2], tonumber(C.meters.tx) or 0, tonumber(C.meters.ty) or 0)
    return true
  end

  function TH.Draw()
    local j
    if TH.sampleUntil and GetTime() < TH.sampleUntil then
      j = TH.SampleJudge()
    elseif TH.list and GetTime() - TH.at < 2 and TH.Wanted() then
      j = TH.Judge(TH.list)
    elseif pfUI.unlock and pfUI.unlock:IsShown() and C.meters.twhere == "screen" then
      j = TH.SampleJudge()   -- layout mode: something to place
    end
    if not j or C.meters.tlabel ~= "1" or C.meters.tlook == "none" or not TH.Place(label, TH.TargetPlate()) then
      label:Hide()
      return
    end
    TH.Paint(label, j)
    label:Show()
  end

  -- a made-up reading: 72 % (or as close to your cap as that is)
  function TH.SampleJudge(share, aggro)
    if aggro then return { aggro = true, nextP = 92, nextName = "Jaina", state = 2 } end
    share = share or 72
    local limit = math.max(1, tonumber(C.meters.threatwarn) or 90)
    local near = (tonumber(C.meters.tnear) or 80) / 100
    local f = share / limit
    return { share = share, state = (f >= 1) and 3 or ((f >= near) and 2 or 1) }
  end

  function TH.Sample(seconds)
    TH.sampleUntil = GetTime() + (seconds or 8)
    TH.Draw()
  end

  -- ---------------------------------------------------------------- popups

  -- a big line in the middle of the screen
  local alert = CreateFrame("Frame", "pfThreatAlert", UIParent)
  alert:SetWidth(600)
  alert:SetHeight(40)
  alert:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
  alert:SetFrameStrata("HIGH")
  alert.text = alert:CreateFontString(nil, "OVERLAY")
  alert.text:SetAllPoints(alert)
  alert:Hide()
  alert:SetScript("OnUpdate", function()
    local t = GetTime() - (this.at or 0)
    if t > 2.5 then this:Hide() return end
    this:SetAlpha(t < 1.8 and 1 or (1 - (t - 1.8) / .7))
  end)
  function TH.Alert(text, r, g, b)
    alert.text:SetFont(pfUI.font_default, 26, "THICKOUTLINE")
    alert.text:SetTextColor(r or 1, g or .3, b or .2)
    alert.text:SetText(text)
    alert.at = GetTime()
    alert:SetAlpha(1)
    alert:Show()
  end
  function TH.Sound()
    if C.meters.threatsound ~= "1" then return end
    local CT = pfUI.sctB and pfUI.sctB.SCT
    if CT and CT.PlaySound then CT.PlaySound(C.meters.threatsoundkey) else PlaySound("RaidWarning") end
  end

  -- once per crossing: past your cap (again after dropping under 85 % of it),
  -- or the mob turning to you
  function TH.Popups(j)
    if C.meters.threatflash ~= "1" then return end
    if j.aggro then
      if C.meters.threataggro == "1" and not TH.hadAggro then
        TH.Alert(T["AGGRO!"], 1, .45, .2)
        TH.Sound()
      end
      TH.hadAggro = true
      return
    end
    TH.hadAggro = nil
    local limit = tonumber(C.meters.threatwarn) or 90
    if j.state == 3 and not TH.warned then
      TH.warned = true
      TH.Alert(C.meters.threatpopup or "THREAT", 1, .25, .2)
      TH.Sound()
    elseif TH.warned and (j.share or 0) < limit * .85 then
      TH.warned = nil
    end
  end

  -- with each answer from the server
  function TH.Warn()
    if TH.list and TH.Wanted() then TH.Popups(TH.Judge(TH.list)) end
    TH.Draw()
  end

  -- the label follows the plate ten times a second
  local tick = CreateFrame("Frame")
  tick:SetScript("OnUpdate", function()
    if (this.t or 0) > GetTime() then return end
    this.t = GetTime() + .1
    if TH.list or label:IsShown() or TH.sampleUntil or (pfUI.unlock and pfUI.unlock:IsShown()) then TH.Draw() end
    if TH.sampleUntil and GetTime() >= TH.sampleUntil then TH.sampleUntil = nil end
  end)

  -- one line for the options page and /pfthreat
  function TH.StatusLine()
    if TH.list and GetTime() - TH.at < 2 then
      return "|cff5aff5aServer threat data coming in|r (" .. TH.answers .. " answers)."
    end
    if TH.gaveUp then return "|cffff7a3aThis server sent no threat data|r - asking again after the next zone change." end
    if TH.answers > 0 then return "The server answered " .. TH.answers .. " times; waiting for the next fight." end
    if not InGroup() then return "Waiting: threat data needs a party or raid." end
    return "Waiting for a fight with a mob (asked " .. TH.silent .. " times so far)."
  end
  function TH.CapText()
    local ref = C.meters.threatref or "pull"
    local who = (ref == "pull" and "the pull point") or (ref == "2" and "the 2nd highest player") or
      (ref == "3" and "the 3rd highest player") or "the top player (tank)"
    return "stay under " .. (C.meters.threatwarn or "90") .. "% of " .. who
  end

  -- OctoBG's threat settings, taken over once (OctoBG no longer has threat;
  -- its saved file keeps them for this). OctoBG loads before pfUI.
  function TH.ImportOctoBG()
    if C.meters.timported == "1" or type(OctoBGDB) ~= "table" or type(OctoBGDB.threat) ~= "table" then return end
    local o = OctoBGDB.threat
    local function S2(v) return v ~= nil and tostring(v) or nil end
    local function B2(v) if v == nil then return nil end return v and "1" or "0" end
    C.meters.tlabel = B2(o.enabled) or C.meters.tlabel
    C.meters.tlook = S2(o.look) or C.meters.tlook
    C.meters.twhere = S2(o.where) or C.meters.twhere
    C.meters.tx, C.meters.ty = S2(o.x) or C.meters.tx, S2(o.y) or C.meters.ty
    C.meters.tsize = S2(o.size) or C.meters.tsize
    C.meters.toutline = S2(o.outline) or C.meters.toutline
    if o.limit then C.meters.threatwarn = tostring(o.limit) end
    if o.ref then C.meters.threatref = tostring(o.ref) end
    C.meters.tnext = B2(o.next) or C.meters.tnext
    C.meters.threatflash = B2(o.popup) or C.meters.threatflash
    C.meters.threatpopup = S2(o.popupText) or C.meters.threatpopup
    C.meters.threatsoundkey = S2(o.popupSound) or C.meters.threatsoundkey
    C.meters.threataggro = B2(o.popupAggro) or C.meters.threataggro
    C.meters.timported = "1"
    return true
  end
  TH.ImportOctoBG()

  -- /pfthreat              status
  -- /pfthreat 70 [2]       cap 70 % of the top (or 2nd / 3rd) player; /pfthreat 70 pull
  _G.SLASH_PFTHREAT1 = "/pfthreat"
  _G.SlashCmdList.PFTHREAT = function(msg)
    local _, _, n, r = string.find(msg or "", "^%s*(%d+)%s*(%w*)")
    if n then
      C.meters.threatwarn = tostring(math.max(10, math.min(150, tonumber(n))))
      if r == "pull" or r == "1" or r == "2" or r == "3" then C.meters.threatref = r end
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfUI Octo|r threat cap: " .. TH.CapText())
      return
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfUI Octo|r threat: " .. TH.StatusLine() .. "  Cap: " .. TH.CapText() ..
      " (/pfthreat 70 2 to change).")
  end
end)
