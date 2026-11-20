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
  local GIVE_UP = 40   -- asks (8 s at the default speed) for an elite or boss with no answer at all
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

  -- two parts of one answer as one sorted list (a name in both: the newer part's numbers)
  function TH.Join(old, new)
    local out, seen = {}, {}
    for _, e in ipairs(new) do seen[e.name] = true table.insert(out, e) end
    for _, e in ipairs(old) do if not seen[e.name] then table.insert(out, e) end end
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
  -- (7 Nov 2026, GratisNinja: in a party the server sent no threat data and the meter showed only that hint)
  -- In a group whose server stays silent the same estimate is made for everyone: the hits and heals the meters
  -- read, with the stance / Salvation multipliers (TH.K). TH.UseEst() says when it replaces the server's numbers.
  -- (7 Nov 2026) What the server answers. The TWThreat addon this protocol comes from only asks for ELITE
  -- creatures and bosses, in a party or raid, while you and the target are in combat (its README: "in party or
  -- raid, attacking elite creatures or bosses"). pfUI asked for every mob, got nothing for the normal ones and
  -- gave up after 4 s, for the whole session - GratisNinja's "no data from the server" in a party. Now normal
  -- mobs are never asked about (they get the estimate), and a silent elite only costs that one target.
  function TH.ServerKind()
    if not UnitExists("target") then return false end
    local c = UnitClassification and UnitClassification("target")
    return (c == "elite" or c == "worldboss" or c == "rareelite") and true or false
  end
  -- (7 Nov 2026, "can we implement so normal mobs work too") Normal mobs are tried too, a few asks per
  -- target, with the estimate on screen meanwhile. If the server ever answers for one, normal mobs are
  -- asked about from then on, for good (C.meters.normalok): its numbers replace the estimate.
  function TH.NormalOK() return C.meters.normalok == "1" end
  function TH.Asks() return TH.ServerKind() or TH.NormalOK() end
  function TH.UseEst()
    return Solo() or (InGroup() and (TH.gaveUp or not TH.Asks())) and true or false
  end
  -- flat threat some warrior hits carry on top of their damage (highest rank: lower ranks give a little less)
  -- and the taunts that put the caster at the top (the mob's next hit then goes to them)
  TH.BONUS = { ["Heroic Strike"] = 145, ["Sunder Armor"] = 260, ["Revenge"] = 355 }
  TH.TAUNTS = { ["Taunt"] = true, ["Growl"] = true, ["Mocking Blow"] = true }
  local function Member(name)
    local w = name and M.Who and M.Who(name)
    return w and w.kind ~= "OTHER" and true or false
  end
  -- every record the meters read: yours, your pet's and your group's against a mob
  function TH.EstRecord(r)
    if not TH.UseEst() or not r or M.testOn then return end
    local me, pet = UnitName("player"), UnitName("pet")
    -- a taunt puts its caster at the top of that mob's list
    if r.spl and TH.TAUNTS[r.spl] and r.src and (r.kind == "cast" or r.kind == "dmg") and (r.src == me or Member(r.src)) then
      local mob = r.tgt or UnitName("target")
      local t = mob and TH.est[mob]
      if t then
        local top = 0
        for _, v in pairs(t) do if v > top then top = v end end
        t[r.src] = math.max(t[r.src] or 0, top + 1)
      end
    end
    if r.kind == "dmg" and r.amt and r.src and r.tgt and r.tgt ~= r.src then
      local mine = (r.src == me or r.src == pet)
      if mine and r.tgt ~= me and r.tgt ~= pet or (not mine and Solo() == false and Member(r.src) and not Member(r.tgt)) then
        -- the damage, times what changes it (stance, Salvation), plus the flat threat some hits carry
        TH.EstAdd(r.tgt, r.src, r.amt * (mine and 1 or TH.K(r.src)) + (TH.BONUS[r.spl or ""] or 0))
      end
    elseif r.kind == "heal" and r.amt and r.src and UnitExists("target") and (r.src == me or (not Solo() and Member(r.src))) then
      TH.EstAdd(UnitName("target"), r.src, r.amt / 2)
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
      if TH.LearnHit then pcall(TH.LearnHit, r) end
    end
  end
  -- the target's numbers as the server's list would give them
  function TH.Estimate()
    local mob = UnitName("target")
    local t = mob and TH.est[mob]
    local me, pet = UnitName("player"), UnitName("pet")
    if not me then return end
    local list, top, topName = {}, 0, nil
    local seen = {}
    local function Add(name, v)
      if not name or seen[name] then return end
      seen[name] = true
      table.insert(list, { name = name, tank = false, threat = math.floor(v + .5), perc = 0, melee = true })
      if v > top then top, topName = v, name end
    end
    for name, v in pairs(t or {}) do Add(name, v) end
    -- you and your pet are always on it (solo, that is the whole list)
    Add(me, 0)
    if pet and Solo() then Add(pet, 0) end
    -- the tank: whoever the mob is attacking, else the top
    local holder
    if UnitIsUnit("targettarget", "player") then holder = me
    elseif UnitIsUnit("targettarget", "pet") then holder = pet
    else holder = UnitName("targettarget") end
    if not holder or not seen[holder] then holder = topName end
    local tankT = 0
    for _, e in ipairs(list) do if e.name == holder then e.tank = true tankT = e.threat end end
    for _, e in ipairs(list) do
      if e.tank then e.perc = 100 elseif tankT > 0 then e.perc = math.floor(e.threat / tankT * 1000 + .5) / 10 end
      if e.name == me then e.melee = CheckInteractDistance("target", 3) and true or false end
    end
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
          if k > .3 and k < 6 then
            k = (TH.k[e.name] or 1) * .5 + k * .5
            TH.k[e.name] = math.max(TH.KMIN or .5, math.min(TH.KMAX or 2.6, k))
          end
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
  -- (20 Nov 2026, user: in raids "people going above the tank instantly when they are not pulling threat") Between
  -- two answers each hit moves its player by a guess: K per point of damage (learnt, kept within KMIN..KMAX), and
  -- the tank's own threat-only work (Sunder, taunts) is not in the guess at all - so a damage dealer's line could
  -- pass the tank's until the next answer pulled it back. Now a guess never takes anyone past the tank: above
  -- 99% of it only the server's own numbers can put them.
  TH.KMIN, TH.KMAX = .5, 2.6
  local function GuessK(name)
    local k = TH.K(name)
    if k < TH.KMIN then return TH.KMIN elseif k > TH.KMAX then return TH.KMAX end
    return k
  end
  function TH.Rebuild()
    local out, tankT, top = {}, 0, 0
    for _, e in ipairs(TH.base) do
      local t = e.threat + GuessK(e.name) * (TH.dmg[e.name] or 0)
      table.insert(out, { name = e.name, tank = e.tank, threat = t, melee = e.melee, perc = e.perc, sperc = e.perc, sthreat = e.threat })
      if t > top then top = t end
      if e.tank then tankT = t end
    end
    if tankT <= 0 then tankT = top end
    for _, c in ipairs(out) do
      if c.tank then c.perc = 100
      elseif tankT > 0 then
        c.perc = c.threat / tankT * 100
        local cap = math.max(99, c.sperc or 0)
        if c.perc > cap then
          c.perc = cap
          c.threat = math.max(c.sthreat or 0, tankT * cap / 100)
        end
      end
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

  -- (12 Nov 2026, user: TWThreat showed 16 players, ours 10) how many players to ask the server for: as many
  -- rows as the biggest threat window shows (Refresh notes win.visibleRows), at least 10, at most 40
  function TH.Limit()
    local n = 10
    for _, w in ipairs(M.windows or {}) do
      if w.mode == "threat" and w.visibleRows and w.visibleRows > n then n = w.visibleRows end
    end
    return math.min(40, n)
  end
  local function Send()
    return pcall(SendAddonMessage, "TWT_UDTSv4", "limit=" .. TH.Limit(), GetNumRaidMembers() > 0 and "RAID" or "PARTY")
  end
  TH.Send = Send

  function TH.Ask()
    if not TH.Wanted() then return end
    -- (6 Nov 2026, "threat meter updating slow ... INSTANT": asked every C.meters.threatrate seconds,
    -- default 0.2, no longer every 0.5; an answer anyone got in half that time is used instead)
    local rate = TH.Rate()
    if GetTime() - TH.askAt < rate or GetTime() - TH.at < rate * .5 then return end
    -- solo with a pet: the estimate (the server answers groups only)
    if Solo() then TH.Estimate() return end
    -- (the server sent nothing in a group: the estimate for everyone, from the hits and heals the meters read)
    if TH.gaveUp then TH.Estimate() return end
    if not TH.Asks() then
      -- a normal mob: tried a few times (the answer, if there is one, is what proves it), the estimate shows
      if (TH.probes or 0) < 8 then
        TH.probes = (TH.probes or 0) + 1
        Send()
        TH.askAt = GetTime()
      end
      TH.Estimate()
      return
    end
    -- (grouped again: the server's numbers only, never the estimate)
    if TH.estimated then TH.list, TH.estimated = nil, nil end
    if Send() then
      TH.askAt = GetTime()
      TH.silent = TH.silent + 1
      if TH.silent >= GIVE_UP and TH.answers == 0 then TH.gaveUp = true end
    end
  end

  -- what the window shows when there are no numbers
  function TH.Status()
    if InGroup() and TH.Wanted() and not TH.ServerKind() then return "Estimated from the fight (asking the server too: it has sent threat for elites and bosses)" end
    if TH.gaveUp then return T["No threat data from this server"] .. " - estimating from the fight" end
    if not InGroup() and not Solo() then return T["Threat shows in a group, or solo with a pet"] end
    if not TH.Wanted() then return T["Target a mob in combat"] end
    if TH.answers == 0 then return T["Asking the server..."] end
  end

  -- (12 Nov 2026) the line over the threat list. Not the tank: "pull", the threat you take aggro at (the tank's
  -- x 1.1 in melee range, x 1.3 at range) and how much more you can do before it. The tank: "lead", how far ahead
  -- of the next player you are, and who that is.
  function TH.Pull()
    if not TH.list then return end
    local me = UnitName("player")
    local tank, mine
    for _, e in ipairs(TH.list) do
      if e.tank then tank = e end
      if e.name == me then mine = e end
    end
    if not mine or not tank then return end
    if mine.tank then
      for _, e in ipairs(TH.list) do
        if not e.tank then return "lead", mine.threat - e.threat, e end
      end
      return
    end
    local at = tank.threat * ((mine.melee and 110 or 130) / 100)
    return "pull", at, at - mine.threat
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

  -- ---------------------------------------------------------------- what is on the way
  -- (20 Nov 2026, Shemp on Discord: warlocks "hitting the brakes on a container ship" - after a taunt their DoTs
  -- put them straight back on top; "at least they could see that overaggroing will happen in x sec and they could
  -- start moving to the tank"). Like incoming heals on a health bar: the threat your DoTs will still add (their
  -- ticks left x what each tick did last), plus the spell you are casting now, and when you will pass the pull
  -- point - with what is already on its way even if you stop now, or at the rate you are going.
  TH.ticks, TH.hits, TH.samples = {}, {}, {}
  -- threat a point of damage of some spells carries above the rest (Searing Pain: double)
  TH.SPELLK = { ["Searing Pain"] = 2 }
  function TH.PredictOn() return C.meters.tpredict ~= "0" end
  -- every record the meters read: your own ticks and hits teach what the next ones will do
  -- (20 Nov 2026, user: "this info should be available to all - if a raid leader wanted to see whos dots would
  -- overaggro in xxx seconds he can easily see it on his meters too") everyone's DoT ticks on your target, from the
  -- combat log: what a tick does, the gap between ticks, and when this application started (time left = the
  -- spell's length since then, TH.DOTDUR; no tick for 1.6 gaps = it is gone). Yours stay exact (TH.MyDots).
  TH.others = {}
  TH.DOTDUR = {
    ["Corruption"] = 18, ["Curse of Agony"] = 24, ["Immolate"] = 15, ["Siphon Life"] = 30, ["Curse of Doom"] = 60,
    ["Shadow Word: Pain"] = 18, ["Devouring Plague"] = 24, ["Vampiric Embrace"] = 60, ["Holy Fire"] = 10,
    ["Rend"] = 21, ["Deep Wounds"] = 12, ["Rupture"] = 16, ["Garrote"] = 18, ["Serpent Sting"] = 15,
    ["Moonfire"] = 12, ["Insect Swarm"] = 12, ["Rake"] = 9, ["Rip"] = 12, ["Flame Shock"] = 12, ["Ignite"] = 4,
    ["Consecration"] = 8, ["Pyroblast"] = 12, ["Fireball"] = 8,
  }
  local function LearnOther(r, amt, now)
    if not TH.IsTarget(r) then return end
    local o = TH.others[r.src] or {}
    TH.others[r.src] = o
    local t = o[r.spl] or {}
    o[r.spl] = t
    local gap = t.gap or 3
    if t.at then
      local g = now - t.at
      if g > .8 and g < 6 then t.gap = t.gap and (t.gap * .5 + g * .5) or g end
    end
    -- a new application: the first tick comes one gap after it went on
    if not t.at or now - t.at > gap * 1.8 then t.start = now - gap end
    t.at, t.amt = now, t.amt and (t.amt * .5 + amt * .5) or amt
  end
  function TH.LearnHit(r, now)
    if not r or M.testOn or r.kind ~= "dmg" or not r.spl then return end
    local amt = tonumber(r.amt)
    if not amt or amt <= 0 or not r.src then return end
    now = now or GetTime()
    if r.src ~= UnitName("player") then
      if r.dot then LearnOther(r, amt, now) end
      return
    end
    if r.dot then
      local t = TH.ticks[r.spl] or {}
      TH.ticks[r.spl] = t
      -- the time between two ticks of the same DoT (two mobs ticking together say nothing)
      if t.at then
        local gap = now - t.at
        if gap > .8 and gap < 6 then t.gap = t.gap and (t.gap * .5 + gap * .5) or gap end
      end
      t.at, t.amt = now, t.amt and (t.amt * .5 + amt * .5) or amt
    else
      local h = TH.hits[r.spl]
      TH.hits[r.spl] = h and (h * .6 + amt * .4) or amt
      if TH.cast and TH.cast.name == r.spl then TH.cast = nil end   -- the cast landed: it is in the threat now
    end
  end
  -- your DoTs on the target and their time left: OctoDoTs' reader (ClassicAPI / SuperWoW), else pfUI's timers
  local dotU = { auras = {}, na = 0 }
  function TH.MyDots(now)
    local out = {}
    if not UnitExists("target") then return out end
    local D = pfUI.dots
    if D and D.Read and D.Guid then
      dotU.guid = D.Guid("target") or "target"
      dotU.plain = not ((D.Classic and D.Classic()) or (D.SuperWoW and D.SuperWoW() and string.find(dotU.guid or "", "^0x")))
      if dotU.plain then dotU.guid = "target" end
      if pcall(D.Read, dotU, now) then
        for i = 1, dotU.na do
          local a = dotU.auras[i]
          if a and a.kind == "mine" and a.name and a.ends and a.ends > now then table.insert(out, { name = a.name, left = a.ends - now }) end
        end
        return out
      end
    end
    local ld = pfUI.api and pfUI.api.libdebuff
    if ld and ld.UnitDebuff then
      for i = 1, 16 do
        local name, _, tex, _, _, _, left, caster = ld:UnitDebuff("target", i)
        if not tex then break end
        if name and caster == "player" and left and left > 0 then table.insert(out, { name = name, left = left }) end
      end
    end
    return out
  end
  -- what is on its way: the threat still to come, and its moments { { in seconds, threat }, ... } in order
  function TH.OnTheWay(now)
    now = now or GetTime()
    -- (the demo's pretend DoTs: the same lines as a real fight would show)
    if TH.demoPending then
      local t, s = TH.demoPending(UnitName("player"), now)
      if t then return t, s end
    end
    local k = TH.K(UnitName("player") or "")
    local total, steps = 0, {}
    for _, d in ipairs(TH.MyDots(now)) do
      local t = TH.ticks[d.name]
      if t and t.amt then
        local gap = t.gap or 3
        local n = math.ceil(d.left / gap - .01)
        local each = t.amt * k * (TH.SPELLK[d.name] or 1)
        for i = 1, n do
          local at = d.left - (n - i) * gap
          if at > 0 then
            table.insert(steps, { at, each })
            total = total + each
          end
        end
      end
    end
    local c = TH.cast
    if c and c.ends and now < c.ends + 1.5 and TH.hits[c.name] then
      local each = TH.hits[c.name] * k * (TH.SPELLK[c.name] or 1)
      table.insert(steps, { math.max(0, c.ends - now), each })
      total = total + each
    end
    table.sort(steps, function(a, b) return a[1] < b[1] end)
    return total, steps
  end
  -- another player's DoTs on your target: the threat still to come and its moments (as TH.OnTheWay)
  function TH.OthersOnTheWay(name, now)
    now = now or GetTime()
    if TH.demoPending then
      local t, s = TH.demoPending(name, now)
      if t then return t, s end
    end
    local k = TH.K(name)
    local total, steps = 0, {}
    for spl, t in pairs(TH.others[name] or {}) do
      local gap = t.gap or 3
      if t.at and t.amt and now - t.at <= gap * 1.6 then
        local left = (TH.DOTDUR[spl] or 18) - (now - (t.start or t.at))
        if left < gap then left = gap end   -- still ticking past its length: refreshed, at least one more
        local n = math.ceil(left / gap - .01)
        local each = t.amt * k * (TH.SPELLK[spl] or 1)
        local first = gap - (now - t.at)
        if first < 0 then first = 0 end
        for i = 1, n do
          local at = first + (i - 1) * gap
          if at <= left then
            table.insert(steps, { at, each })
            total = total + each
          end
        end
      end
    end
    table.sort(steps, function(a, b) return a[1] < b[1] end)
    return total, steps
  end
  -- everyone's threat for a few seconds (TH.hist[name] = { { time, threat }, ... }): how fast each is going
  TH.hist = {}
  function TH.RateOf(name)
    local s = TH.hist[name]
    local a, b = s and s[1], s and s[table.getn(s)]
    if not a or not b or b[1] - a[1] < 1.5 then return end
    return math.max(0, (b[2] - a[2]) / (b[1] - a[1]))
  end
  -- your threat and the tank's, a few seconds of them: how fast each is going
  function TH.TakeSample(now)
    if not TH.list then return end
    local me = UnitName("player")
    local mine, tank
    for _, e in ipairs(TH.list) do
      if e.name == me then mine = e end
      if e.tank then tank = e end
      local h = TH.hist[e.name] or {}
      TH.hist[e.name] = h
      local last = h[table.getn(h)]
      if not last or now - last[1] >= .1 then
        -- (a taunt or a new holder starts that player's history again)
        if last and e.threat < last[2] then for i = table.getn(h), 1, -1 do h[i] = nil end end
        table.insert(h, { now, e.threat })
        while h[1] and now - h[1][1] > 6 do table.remove(h, 1) end
      end
    end
    if not mine or not tank or mine.tank then return end
    local s = TH.samples
    local last = s[table.getn(s)]
    if last and now - last[1] < .1 then return end
    table.insert(s, { now, mine.threat, tank.threat })
    while s[1] and now - s[1][1] > 6 do table.remove(s, 1) end
  end
  function TH.Rates()
    local s = TH.samples
    local a, b = s[1], s[table.getn(s)]
    if not a or not b or b[1] - a[1] < 1.5 then return end
    local dt = b[1] - a[1]
    return math.max(0, (b[2] - a[2]) / dt), math.max(0, (b[3] - a[3]) / dt)
  end
  -- { pending, aggroIn, stopNow, room } for you (not the tank): pending = threat still coming; aggroIn = seconds
  -- until you pass the pull point; stopNow = true when what is already on its way does it even if you stop now
  function TH.Predict(now)
    if not TH.PredictOn() or not TH.list then return end
    -- (the demo's "DoTs pull aggro" event answers for itself)
    if TH.demoPredict then return TH.demoPredict(now) end
    now = now or GetTime()
    local me = UnitName("player")
    local mine, tank
    for _, e in ipairs(TH.list) do
      if e.name == me then mine = e end
      if e.tank then tank = e end
    end
    if not mine or not tank or mine.tank then return end
    local mult = mine.melee and 1.1 or 1.3
    local room = tank.threat * mult - mine.threat
    local pending, steps = TH.OnTheWay(now)
    local myRate, tankRate = TH.Rates()
    local p = { pending = pending, room = room }
    if room <= 0 then p.aggroIn = 0 return p end
    -- what is on its way, against the tank still going at its pace
    local got, tr = 0, (tankRate or 0) * mult
    for _, st in ipairs(steps) do
      got = got + st[2]
      if got >= room + tr * st[1] then
        p.aggroIn, p.stopNow = st[1], true
        return p
      end
    end
    -- at the rate you are going
    if myRate and myRate > tr then p.aggroIn = room / (myRate - tr) end
    return p
  end
  -- the same for anyone on the list (not the tank): yours = TH.Predict; others from their DoT ticks and pace
  function TH.PredictFor(name, now)
    if not TH.PredictOn() or not TH.list or not name then return end
    -- (the demo's threat cycle answers for the player it is pulling)
    if TH.demoPredictFor then
      local dp = TH.demoPredictFor(name, now)
      if dp then return dp end
    end
    if name == UnitName("player") then return TH.Predict(now) end
    now = now or GetTime()
    local e, tank
    for _, x in ipairs(TH.list) do
      if x.name == name then e = x end
      if x.tank then tank = x end
    end
    if not e or not tank or e.tank then return end
    local mult = e.melee and 1.1 or 1.3
    local room = tank.threat * mult - e.threat
    local pending, steps = TH.OthersOnTheWay(name, now)
    local p = { pending = pending, room = room }
    if room <= 0 then p.aggroIn = 0 return p end
    local tr = (TH.RateOf(tank.name) or 0) * mult
    local got = 0
    for _, st in ipairs(steps) do
      got = got + st[2]
      if got >= room + tr * st[1] then
        p.aggroIn, p.stopNow = st[1], true
        return p
      end
    end
    local rate = TH.RateOf(name)
    if rate and rate > tr then p.aggroIn = room / (rate - tr) end
    return p
  end
  -- everyone's at once, kept for a fifth of a second (the window asks for every row)
  function TH.PredictAll(now)
    now = now or GetTime()
    if TH.all and TH.allAt and now >= TH.allAt and now - TH.allAt < .2 and TH.allFor == TH.list then return TH.all end
    local out = {}
    for _, e in ipairs(TH.list or {}) do
      if not e.tank then out[e.name] = TH.PredictFor(e.name, now) end
    end
    TH.all, TH.allAt, TH.allFor = out, now, TH.list
    return out
  end
  -- who pulls next, and in how long (within the countdown's seconds): name, prediction
  function TH.NextToPull(now)
    local best, bp
    for name, p in pairs(TH.PredictAll(now)) do
      if p and p.aggroIn and p.aggroIn <= TH.SoonSec() and (not bp or p.aggroIn < bp.aggroIn) then best, bp = name, p end
    end
    return best, bp
  end
  -- the spell you are casting (its hit lands a moment after the cast ends)
  local castf = CreateFrame("Frame")
  castf:RegisterEvent("SPELLCAST_START")
  castf:RegisterEvent("SPELLCAST_FAILED")
  castf:RegisterEvent("SPELLCAST_INTERRUPTED")
  castf:SetScript("OnEvent", function()
    if event == "SPELLCAST_START" then
      TH.cast = { name = arg1, ends = GetTime() + (tonumber(arg2) or 0) / 1000 }
    else
      TH.cast = nil
    end
  end)

  local f = CreateFrame("Frame", "pfMetersThreat", UIParent)
  f:RegisterEvent("CHAT_MSG_ADDON")
  f:RegisterEvent("PLAYER_TARGET_CHANGED")
  f:RegisterEvent("PLAYER_REGEN_ENABLED")
  f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  f:RegisterEvent("PARTY_MEMBERS_CHANGED")
  f:RegisterEvent("RAID_ROSTER_UPDATE")
  f:SetScript("OnEvent", function()
    if event == "CHAT_MSG_ADDON" then
      if type(arg2) ~= "string" or not string.find(arg2, "TWTv4=", 1, true) then return end
      local list = TH.Parse(arg2)
      if not list then return end
      -- (12 Nov 2026) a longer list may come in more than one message: parts that answer the same ask join up
      if TH.list and TH.ansAsk == TH.askAt and TH.askAt > 0 and not TH.estimated then list = TH.Join(TH.list, list) end
      TH.ansAsk = TH.askAt
      TH.list, TH.at, TH.silent, TH.answers = list, GetTime(), 0, TH.answers + 1
      -- an answer for a normal mob: this server sends them too
      if UnitExists("target") and not TH.ServerKind() and not TH.NormalOK() then C.meters.normalok = "1" end
      TH.Snapshot(list)
      TH.estimated = nil
      TH.Warn()
      M.Changed()
      -- shown at once, not at the next .2 s redraw of every window
      if M.RefreshThreat then M.RefreshThreat() end
    elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
      -- (7 Nov 2026, GratisNinja: the meter did not go back to solo when the group was dismissed) a new group,
      -- or none: the server gets asked again, and an estimate of the old one goes
      TH.gaveUp, TH.silent, TH.answers = nil, 0, 0
      TH.list, TH.base, TH.estimated, TH.est = nil, nil, nil, {}
      M.Changed()
    elseif event == "ZONE_CHANGED_NEW_AREA" then
      TH.gaveUp, TH.silent, TH.answers = nil, 0, 0
    else
      TH.list, TH.warned, TH.estimated = nil, nil, nil
      TH.base, TH.baseBy, TH.dmg, TH.shown = nil, nil, {}, {}
      TH.samples, TH.predWarned, TH.others, TH.hist, TH.all = {}, nil, {}, {}, nil
      -- (a fight over: the solo tallies start again)
      if event == "PLAYER_REGEN_ENABLED" then TH.est = {} end
      -- a new target: ask at once
      if event == "PLAYER_TARGET_CHANGED" then
        TH.askAt = 0
        TH.gaveUp, TH.silent, TH.probes = nil, 0, 0   -- every target gets its own try
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
    -- (ClassicAPI eases the bars itself: no redraw every 30 ms for our own glide then)
    elseif TH.list and not (M.Eased and M.Eased()) and TH.Animate() and M.RefreshThreat then
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
    -- (20 Nov 2026) what is on its way, and when you pass the pull point
    local p = mine and TH.Predict()
    if p then
      j.aggroIn, j.stopNow = p.aggroIn, p.stopNow
      if p.pending > 0 then
        if ref == "pull" then
          local at = p.room + mine.threat
          j.pendShare = at > 0 and ((mine.threat + p.pending) / at * 100) or nil
        elseif j.share > 0 then
          j.pendShare = j.share * (mine.threat + p.pending) / math.max(1, mine.threat)
        end
      end
    end
    return j
  end
  -- seconds to show "aggro in" from (C.meters.tpredsec)
  function TH.SoonSec() return tonumber(C.meters.tpredsec) or 8 end
  function TH.SoonText(j)
    if not j.aggroIn or j.aggroIn > TH.SoonSec() then return end
    local s = j.aggroIn < 1 and "now" or ("in " .. math.ceil(j.aggroIn) .. " s")
    return (j.stopNow and "DoTs pull " or "aggro ") .. s
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
    -- what is on its way ("72% > 88%") and when you pull ("aggro in 4 s")
    local extra = ""
    if j.pendShare and j.pendShare - (j.share or 0) >= 1 and look ~= "number" then
      extra = " |cffb0b0b0> " .. floor(j.pendShare + .5) .. "%|r"
    end
    local soon = TH.SoonText(j)
    if soon then extra = extra .. "  " .. Hex(C.meters.tcolover) .. soon .. "|r" end
    if look == "words" then return c .. T["Threat"] .. " " .. pct .. "|r" .. extra end
    return c .. pct .. "|r" .. extra
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
    -- the threat still on its way, lighter, past the bar (as incoming heals)
    l.ghost = l:CreateTexture(nil, "BORDER")
    l.ghost:SetTexture("Interface\\Buttons\\WHITE8X8")
    l.ghost:Hide()
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
      local lim = math.max(1, tonumber(C.meters.threatwarn) or 90)
      local gf = j.pendShare and math.min(1, j.pendShare / lim) or 0
      if gf > f + .01 then
        l.ghost:ClearAllPoints()
        l.ghost:SetPoint("LEFT", l.barBg, "LEFT", BAR_W * f, 0)
        l.ghost:SetWidth(math.max(1, BAR_W * (gf - f)))
        l.ghost:SetHeight(BAR_H)
        l.ghost:SetVertexColor(r, g, b, .4)
        l.ghost:Show()
      else
        l.ghost:Hide()
      end
      l.text:SetPoint("LEFT", l.barBg, "RIGHT", 4, 0)
    else
      l.barBg:Hide()
      l.bar:Hide()
      l.ghost:Hide()
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
    local j = { share = share, state = (f >= 1) and 3 or ((f >= near) and 2 or 1) }
    if TH.PredictOn() then j.pendShare, j.aggroIn, j.stopNow = share + 16, 4, true end
    return j
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
    -- (20 Nov 2026) a few seconds before you pull: time to stop or move to the tank
    local warnS = tonumber(C.meters.tpredwarn) or 3
    if C.meters.tpredpopup ~= "0" and j.aggroIn and j.aggroIn > 0 and j.aggroIn <= warnS then
      if not TH.predWarned then
        TH.predWarned = true
        local s = math.ceil(j.aggroIn) .. " s"
        TH.Alert(j.stopNow and ("DOTS PULL AGGRO IN " .. s) or ("AGGRO IN " .. s), 1, .6, .1)
        TH.Sound()
      end
    elseif TH.predWarned and (not j.aggroIn or j.aggroIn > warnS + 2) then
      TH.predWarned = nil
    end
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
    if TH.list then TH.TakeSample(GetTime()) end
    if TH.list and TH.Wanted() then TH.Popups(TH.Judge(TH.list)) end
    TH.Draw()
  end

  -- the label follows the plate ten times a second
  local tick = CreateFrame("Frame")
  libclient.Every(tick, .1, function()
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
