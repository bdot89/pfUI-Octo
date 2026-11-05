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
  local TH = { list = nil, at = 0, askAt = 0, silent = 0, answers = 0, gaveUp = nil, warned = nil }
  M.threat = TH
  local GIVE_UP = 20
  -- seconds between two asks of the server (C.meters.threatrate, 0.1 - 1)
  function TH.Rate()
    local r = tonumber(C.meters.threatrate) or .2
    if r < .1 then r = .1 elseif r > 1 then r = 1 end
    return r
  end

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
  -- the server answers groups only, so the numbers are estimated here (TH.Estimate).
  -- Only ever true out of a group: nothing grouped uses the estimate.
  local function Solo() return not InGroup() and C.meters.threatsolo ~= "0" and UnitExists("pet") end

  -- in a group, the target a mob you can attack, in combat
  function TH.Wanted()
    if not InGroup() and not Solo() then return false end
    if not UnitExists("target") or UnitIsPlayer("target") or not UnitCanAttack("player", "target") then return false end
    return UnitAffectingCombat("target") and true or false
  end

  -- ---------------------------------------------------------------- solo estimate
  -- (1 Nov 2026, user: "surely there is a way to see the threat between you and your
  -- pet"). The server sends threat to groups only, so solo with a pet the numbers are
  -- worked out here, the way KTM did before servers sent them: from the hits the
  -- meters already read. Damage = 1 threat a point, your heals = 1/2 a point, and the
  -- pet's threat-only abilities their fixed threat (by rank from the pet's level).
  -- An estimate: talents and threat-lowering effects make it drift a little. Who the
  -- mob is attacking (its target) is exact and always wins the "tank" mark.
  TH.est = {}
  TH.FIXED = {
    -- name = { { from pet level, threat }, ... } highest rank the pet can have
    ["Torment"] = { { 10, 45 }, { 20, 75 }, { 30, 125 }, { 40, 215 }, { 50, 300 }, { 60, 395 } },
    ["Suffering"] = { { 24, 150 }, { 36, 300 }, { 48, 450 }, { 60, 600 } },
    ["Growl"] = { { 1, 50 }, { 10, 65 }, { 20, 110 }, { 30, 170 }, { 40, 240 }, { 50, 320 }, { 60, 415 } },
  }
  function TH.Fixed(spell)
    local ranks = spell and TH.FIXED[spell]
    if not ranks then return 0 end
    local lvl, v = UnitLevel("pet") or 60, 0
    for _, r in ipairs(ranks) do if lvl >= r[1] then v = r[2] end end
    return v
  end
  function TH.EstAdd(mob, who, amount)
    if not mob or not who or not amount or amount <= 0 then return end
    local t = TH.est[mob] or {}
    TH.est[mob] = t
    t[who] = (t[who] or 0) + amount
  end
  -- every record the meters read: yours and your pet's against a mob
  function TH.EstRecord(r)
    if not Solo() or not r or (M.testOn) then return end
    local me, pet = UnitName("player"), UnitName("pet")
    if r.kind == "dmg" and r.amt and (r.src == me or r.src == pet) and r.tgt and r.tgt ~= me and r.tgt ~= pet then
      TH.EstAdd(r.tgt, r.src, r.amt)
    elseif r.kind == "heal" and r.amt and r.src == me and UnitExists("target") then
      TH.EstAdd(UnitName("target"), me, r.amt / 2)
    elseif (r.kind == "cast" or r.kind == "dmg" or r.kind == "miss") and r.src == pet and TH.FIXED[r.spl or ""] then
      TH.EstAdd(r.tgt or UnitName("target"), pet, TH.Fixed(r.spl))
    end
  end
  if M.Record and not M.octoEstHooked then
    M.octoEstHooked = true
    local record = M.Record
    M.Record = function(r)
      record(r)
      pcall(TH.EstRecord, r)
      pcall(TH.GroupRecord, r)
    end
  end
  -- the target's numbers as the server's list would give them
  function TH.Estimate()
    local mob = UnitName("target")
    local t = mob and TH.est[mob]
    local me, pet = UnitName("player"), UnitName("pet")
    if not (me and pet) then return end
    local mine, its = t and t[me] or 0, t and t[pet] or 0
    local holder = (UnitIsUnit("targettarget", "player") and me) or (UnitIsUnit("targettarget", "pet") and pet)
      or (its >= mine and pet or me)
    local top = holder == me and mine or its
    local function Perc(v) return top > 0 and math.floor(v / top * 1000 + .5) / 10 or 0 end
    local list = {
      { name = pet, tank = holder == pet, threat = math.floor(its + .5), perc = Perc(its), melee = true },
      { name = me, tank = holder == me, threat = math.floor(mine + .5), perc = Perc(mine), melee = CheckInteractDistance("target", 3) and true or false },
    }
    table.sort(list, function(a, b) return a.threat > b.threat end)
    TH.list, TH.at, TH.estimated = list, GetTime(), true
    TH.Warn()
    M.Changed()
  end

  -- ------------------------------------------------- between the server's answers
  -- (6 Nov 2026, user: "make it faster and smoother"). The server answers a few times a second;
  -- in between, every hit and heal the meters read moves that player's threat by what it
  -- added last time (TH.k = threat per point of damage, learnt from the last two answers,
  -- 1 to start), so the numbers and bars move the instant a hit lands. Each answer replaces
  -- the guess with the server's number. The bars glide to their value (TH.Animate).
  TH.k, TH.dmg, TH.shown = {}, {}, {}
  -- (6 Nov 2026, ClassicAPI) the mob you target by its own id when the combat log gives it
  -- (a pack of the same name is told apart); the name otherwise
  function TH.IsTarget(r)
    local g = TH.targetGuid
    if g and r.tgtGuid and string.len(g) == string.len(r.tgtGuid) and string.sub(g, 1, 2) == string.sub(r.tgtGuid, 1, 2) then
      return g == r.tgtGuid
    end
    return r.tgt and r.tgt == UnitName("target")
  end
  -- what changes a player's threat: Defensive Stance / Bear Form x1.3, Salvation x0.7
  -- (read from the buff pictures, group members only, every 3 s)
  TH.MODTEX = {
    ["Ability_Warrior_DefensiveStance"] = 1.3, ["Ability_Racial_BearForm"] = 1.3,
    ["Spell_Holy_SealOfSalvation"] = .7, ["Spell_Holy_GreaterBlessingofSalvation"] = .7,
  }
  TH.mods = {}
  function TH.ScanMods()
    local units = { "player" }
    local n = GetNumRaidMembers()
    if n > 0 then for i = 1, n do table.insert(units, "raid" .. i) end
    else for i = 1, GetNumPartyMembers() do table.insert(units, "party" .. i) end end
    for _, u in ipairs(units) do
      local name = UnitName(u)
      if name then
        local m = 1
        for i = 1, 32 do
          local tex = UnitBuff(u, i)
          if not tex then break end
          local _, _, file = string.find(tex, "([^\\]+)$")
          local f = file and TH.MODTEX[file]
          if f then m = m * f end
        end
        if TH.mods[name] and TH.mods[name] ~= m then TH.k[name] = nil end   -- a change: relearn
        TH.mods[name] = m
      end
    end
  end
  -- threat per point of damage: what was learnt, else from the auras
  function TH.K(name) return TH.k[name] or TH.mods[name] or 1 end
  function TH.Snapshot(list)
    if TH.base and TH.baseBy then
      for _, e in ipairs(list) do
        local old, d = TH.baseBy[e.name], TH.dmg[e.name]
        if old and d and d >= 100 then
          local k = (e.threat - old) / d
          if k > .3 and k < 6 then TH.k[e.name] = (TH.k[e.name] or 1) * .5 + k * .5 end
        end
      end
    end
    TH.base, TH.baseBy, TH.dmg = list, {}, {}
    for _, e in ipairs(list) do TH.baseBy[e.name] = e.threat end
    TH.dirty = nil
  end
  function TH.GroupRecord(r)
    if not r or M.testOn or not TH.base or not r.src or not TH.baseBy[r.src] then return end
    local amt = tonumber(r.amt)
    if not amt or amt <= 0 then return end
    if r.kind == "dmg" and TH.IsTarget(r) then
      TH.dmg[r.src] = (TH.dmg[r.src] or 0) + amt
    elseif r.kind == "heal" then
      TH.dmg[r.src] = (TH.dmg[r.src] or 0) + amt / 2
    else
      return
    end
    TH.dirty = true
  end
  -- the list as it is now: the server's numbers plus what has been done since
  function TH.Rebuild()
    local out, tankT, top = {}, 0, 0
    for _, e in ipairs(TH.base) do
      local t = e.threat + TH.K(e.name) * (TH.dmg[e.name] or 0)
      table.insert(out, { name = e.name, tank = e.tank, threat = t, melee = e.melee, perc = e.perc })
      if t > top then top = t end
      if e.tank then tankT = t end
    end
    if tankT <= 0 then tankT = top end
    for _, c in ipairs(out) do
      if c.tank then c.perc = 100 elseif tankT > 0 then c.perc = c.threat / tankT * 100 end
    end
    table.sort(out, function(a, b) return a.threat > b.threat end)
    TH.list = out
  end
  -- bars glide: true when a bar is still on its way
  function TH.Animate()
    local moving
    for _, e in ipairs(TH.list or {}) do
      local s = TH.shown[e.name] or e.perc
      local d = e.perc - s
      if d > .2 or d < -.2 then s = s + d * .35 moving = true else s = e.perc end
      TH.shown[e.name] = s
    end
    return moving
  end

  function TH.Ask()
    if not TH.Wanted() or TH.gaveUp then return end
    -- (6 Nov 2026, "threat meter updating slow ... INSTANT": asked every C.meters.threatrate seconds,
    -- default 0.2, no longer every 0.5; an answer anyone got in half that time is used instead)
    local rate = TH.Rate()
    if GetTime() - TH.askAt < rate or GetTime() - TH.at < rate * .5 then return end
    -- solo with a pet: the estimate (the server answers groups only)
    if Solo() then TH.Estimate() return end
    -- (grouped again: the server's numbers only, never the estimate)
    if TH.estimated then TH.list, TH.estimated = nil, nil end
    if pcall(SendAddonMessage, "TWT_UDTSv4", "limit=10", GetNumRaidMembers() > 0 and "RAID" or "PARTY") then
      TH.askAt = GetTime()
      TH.silent = TH.silent + 1
      if TH.silent >= GIVE_UP and TH.answers == 0 then TH.gaveUp = true end
    end
  end

  -- what the window shows when there are no numbers
  function TH.Status()
    if TH.gaveUp then return T["No threat data from this server"] end
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
      TH.Snapshot(list)
      TH.estimated = nil
      TH.Warn()
      M.Changed()
      -- shown at once, not at the next .2 s redraw of every window
      if M.RefreshThreat then M.RefreshThreat() end
    elseif event == "ZONE_CHANGED_NEW_AREA" then
      TH.gaveUp, TH.silent, TH.answers = nil, 0, 0
    else
      TH.list, TH.warned, TH.estimated = nil, nil, nil
      TH.base, TH.baseBy, TH.dmg, TH.shown = nil, nil, {}, {}
      -- (a fight over: the solo tallies start again)
      if event == "PLAYER_REGEN_ENABLED" then TH.est = {} end
      -- a new target: ask at once
      if event == "PLAYER_TARGET_CHANGED" then
        TH.askAt = 0
        local lc = pfUI.api and pfUI.api.libclient
        TH.targetGuid = lc and lc.GUID and lc.GUID("target") or nil
        TH.scanAt = 0
      end
      M.Changed()
    end
  end)

  f:SetScript("OnUpdate", function()
    if (this.tick or 0) > GetTime() then return end
    this.tick = GetTime() + .03
    TH.Ask()
    -- a hit or heal landed: the numbers move now; bars glide
    if TH.dirty and TH.base then
      TH.dirty = nil
      TH.Rebuild()
      TH.Warn()
      if M.RefreshThreat then M.RefreshThreat() end
    elseif TH.list and TH.Animate() and M.RefreshThreat then
      M.RefreshThreat()
    end
    -- buffs that change threat: looked at every 3 s while the numbers are on screen
    if TH.list and (TH.scanAt or 0) <= GetTime() then
      TH.scanAt = GetTime() + 3
      TH.ScanMods()
    end
    if (this.stale or 0) > GetTime() then return end
    this.stale = GetTime() + .25
    -- answers older than 3 s are stale
    if TH.list and GetTime() - TH.at > 3 then
      TH.list, TH.base = nil, nil
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
