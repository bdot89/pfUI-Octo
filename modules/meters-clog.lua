pfUI:RegisterModule("meters-clog", "vanilla", function ()
  -- pfUI Octo :: the meters' main source when ClassicAPI is there (25 Oct 2026; user: "USE IT WHEREVER IT MAKES
  -- pfUI OCTO BETTER"). ClassicAPI's COMBAT_LOG_EVENT_UNFILTERED sends each combat log event retail style: a
  -- subevent, who did it, to whom, the spell, exact numbers (critical / glancing / crushing flags, absorbed,
  -- interrupted spell, dispelled aura, who cast an aura) with no text to parse and no language to worry about.
  -- Each one becomes a record for M.Record, so everything downstream (segments, breakdown, death log) is the
  -- same code. The first event that arrives switches the text lines off (M.clog); without ClassicAPI, or with
  -- C.meters.clog = "0", nothing here runs and the text lines (meters.lua) work as before.
  --
  -- The event gives 11 fixed values and up to 13 more, and 1.12 hands a handler only arg1-arg9, so the values
  -- are read with CombatLogGetCurrentEventInfo() (ClassicAPI docs, "CombatLog").
  local M = pfUI.meters
  if not M or not M.Record then return end
  local floor, mod = math.floor, math.mod
  local lower = string.lower

  local POWER = { [0] = MANA or "Mana", [1] = RAGE or "Rage", [2] = "Focus", [3] = ENERGY or "Energy", [4] = "Happiness" }
  local ENV = { FATIGUE = "Fatigue", DROWNING = "Drowning", FALLING = "Falling", LAVA = "Lava", SLIME = "Slime", FIRE = "Fire" }
  local DAMAGE = { SWING_DAMAGE = 0, RANGE_DAMAGE = 3, SPELL_DAMAGE = 3, SPELL_PERIODIC_DAMAGE = 3, DAMAGE_SHIELD = 3, DAMAGE_SPLIT = 3 }

  -- the flags: affiliation bits 1 (mine) 2 (party) 4 (raid); type bits 0x1000 pet, 0x2000 guardian
  local function Group(flags)
    if not flags then return false end
    if mod(flags, 8) ~= 0 then return true end
    return mod(floor(flags / 4096), 4) ~= 0
  end
  M.ClogGroup = Group

  local rec = {}
  local function Fill(kind, src, tgt, spl, amt)
    rec.kind, rec.src, rec.tgt, rec.spl, rec.amt = kind, src, tgt, spl, amt
    rec.how, rec.crit, rec.dot, rec.glancing, rec.crushing = nil, nil, nil, nil, nil
    rec.aura, rec.up, rec.harm, rec.pow, rec.over, rec.with = nil, nil, nil, nil, nil, nil
    rec.nocast = true   -- the cast events are in the log: a hit does not count a cast of its own
    return rec
  end
  local function Name(n)
    if n == nil or n == "" or n == UNKNOWNOBJECT then return nil end
    return n
  end

  local kills = {}   -- victim GUID -> { killer name, time } from PARTY_KILL
  local ids = {}     -- spell name -> spell id, as the events named them
  M.spellIds = ids
  M.clogStats = { events = 0, used = 0 }

  function M.ClogHandle(ts, sub, hide, sg, sn, sf, srf, dg, dn, df, drf, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24)
    if not sub then return end
    local st = M.clogStats
    st.events = st.events + 1
    if not M.clog then M.clog = true end   -- the text lines step aside from now on
    local src, tgt = Name(sn), Name(dn)
    local mine = Group(sf) or Group(df)
    -- octo (29 Oct 2026): who owns totems, guardians and summons - the summon names both; and a guardian or
    -- pet flagged as yours (affiliation bit 1, type bits 0x3000) is yours when nothing else says
    if M.SetOwner then
      if (sub == "SPELL_SUMMON" or sub == "SPELL_CREATE") and src and tgt then M.SetOwner(tgt, src) end
      local me = UnitName("player")
      if src and sf and mod(sf, 2) == 1 and mod(floor(sf / 4096), 4) ~= 0 and src ~= me and not M.owners[src] then M.SetOwner(src, me) end
      if tgt and df and mod(df, 2) == 1 and mod(floor(df / 4096), 4) ~= 0 and tgt ~= me and not M.owners[tgt] then M.SetOwner(tgt, me) end
    end
    -- who is worth the work: your group (and pets), anyone with "everyone nearby" on; an enemy's death only
    -- when the group hit it
    if not mine and C.meters.trackall ~= "1" then
      if sub ~= "UNIT_DIED" or not (M.current and tgt and M.current.enemies[tgt] ~= nil) then return end
    end
    st.used = st.used + 1
    local r

    -- spell names -> ids, for the right picture (breakdown rows: C_Spell.GetSpellTexture(id))
    if a13 and type(a12) == "number" and a12 > 0 and (DAMAGE[sub] == 3 or string.find(sub, "^SPELL_") or string.find(sub, "^RANGE_")) then
      ids[a13] = a12
    end
    if (sub == "SPELL_INTERRUPT" or sub == "SPELL_DISPEL") and a16 and type(a15) == "number" and a15 > 0 then ids[a16] = a15 end

    local dprefix = DAMAGE[sub]
    if dprefix then
      -- SWING_: amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing
      -- SPELL_ / RANGE_ / shields: spell id, name, school first, so everything is 3 later
      local amt, crit, glance, crush, spl
      if dprefix == 0 then
        amt, crit, glance, crush = a12, a18, a19, a20
      else
        amt, crit, glance, crush = a15, a21, a22, a23
        spl = a13 or (sub == "DAMAGE_SHIELD" and "Damage shield") or nil
      end
      r = Fill("dmg", src, tgt, spl, tonumber(amt))
      r.crit, r.glancing, r.crushing = crit and true or nil, glance and true or nil, crush and true or nil
      r.dot = sub == "SPELL_PERIODIC_DAMAGE" or nil
    elseif sub == "ENVIRONMENTAL_DAMAGE" then
      r = Fill("dmg", nil, tgt, ENV[a12] or a12, tonumber(a13))
    elseif sub == "SWING_MISSED" then
      r = Fill("miss", src, tgt, nil, nil)
      r.how = a12 and lower(a12) or "miss"
    elseif sub == "SPELL_MISSED" or sub == "RANGE_MISSED" or sub == "SPELL_PERIODIC_MISSED" or sub == "DAMAGE_SHIELD_MISSED" then
      r = Fill("miss", src, tgt, a13, nil)
      r.how = a15 and lower(a15) or "miss"
    elseif sub == "SPELL_HEAL" or sub == "SPELL_PERIODIC_HEAL" then
      r = Fill("heal", src, tgt, a13, tonumber(a15))
      r.crit = a18 and true or nil
      r.dot = sub == "SPELL_PERIODIC_HEAL" or nil
    elseif sub == "SPELL_ENERGIZE" or sub == "SPELL_PERIODIC_ENERGIZE" then
      r = Fill("power", src, tgt, a13, tonumber(a15))
      r.pow = POWER[a16] or tostring(a16)
    elseif sub == "SPELL_CAST_START" then
      r = Fill("start", src, nil, a13, nil)
    elseif sub == "SPELL_CAST_SUCCESS" then
      r = Fill("cast", src, tgt, a13, nil)
    elseif sub == "SPELL_INTERRUPT" then
      -- a13 = the spell that interrupted, a16 = the spell it stopped
      r = Fill("interrupt", src, tgt, a16, nil)
      r.with = a13
    elseif sub == "SPELL_DISPEL" then
      -- a16 = the aura that was removed (the dispelling spell is not named)
      r = Fill("dispel", src, tgt, nil, nil)
      r.aura = a16
    elseif sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REMOVED" then
      r = Fill("aura", src, tgt, nil, nil)
      r.aura, r.up, r.harm = a13, sub == "SPELL_AURA_APPLIED", a15 == "DEBUFF"
    elseif sub == "PARTY_KILL" then
      if dg and src then kills[dg] = { src, GetTime() } end
      return
    elseif sub == "UNIT_DIED" then
      local k = dg and kills[dg]
      r = Fill("death", (k and GetTime() - k[2] < 3) and k[1] or nil, tgt, nil, nil)
      if dg then kills[dg] = nil end
    else
      return
    end
    if r and dg then r.tgtGuid = dg end
    M.Record(r)
  end

  -- ---------------------------------------------------------------- listening

  local f = CreateFrame("Frame", "pfMetersCombatLog", UIParent)
  f:SetScript("OnEvent", function()
    local info = _G.CombatLogGetCurrentEventInfo
    if type(info) == "function" then M.ClogHandle(info()) end
  end)

  -- on when ClassicAPI has the event and the setting allows it; off puts the text lines back
  function M.ClogAvailable() return type(_G.CombatLogGetCurrentEventInfo) == "function" end
  function M.ClogApply()
    if M.ClogAvailable() and C.meters.clog ~= "0" then
      f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
      M.clogOn = true
    else
      f:UnregisterAllEvents()
      M.clogOn, M.clog = nil, nil
    end
  end
  M.ClogApply()

  -- one line for the options page
  function M.ClogStatus()
    if not M.ClogAvailable() then return "ClassicAPI's combat log is not there: the text lines of the chat log are read (it works, with less detail)." end
    if C.meters.clog == "0" then return "Switched off: the text lines of the chat log are read." end
    if M.clog then return "|cff55ff55In use|r - " .. M.clogStats.events .. " events so far, " .. M.clogStats.used .. " about your group." end
    return "Waiting for the first event (the text lines are read until then)."
  end

  -- everyone has left: forget kills nobody saw die
  f:SetScript("OnUpdate", function()
    if (this.tick or 0) > GetTime() then return end
    this.tick = GetTime() + 10
    local old = GetTime() - 10
    for k, v in pairs(kills) do if v[2] < old then kills[k] = nil end end
  end)
end)
