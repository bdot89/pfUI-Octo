pfUI:RegisterModule("meters", "vanilla", function ()
  -- pfUI Octo meters: who did what in a fight, Details!/Recount style.
  --
  -- The data comes from the combat log messages, matched against the
  -- client's own GlobalStrings templates (so it works in every language).
  -- The template matching (sanitize / captures / cfind) is ShaguDPS's, by
  -- Shagu, pfUI's author. Recorded per player (pets merged into the owner):
  -- damage done and taken, effective healing and overhealing, every spell
  -- with hits / crits / misses / max / min, interrupts (who, what, with
  -- what), dispels (what was removed, from whom), deaths with the last
  -- hits and heals, every cast, avoidance. Fights are segments: the running
  -- one, the last C.meters.history ones and "overall".
  -- Design and data sources: docs/meters-spec.md. The window is
  -- meters-window.lua, threat is meters-threat.lua.
  if C.meters.enable ~= "1" then return end

  local M = {}
  pfUI.meters = M
  M.callbacks = {}

  local floor, min, max = math.floor, math.min, math.max
  local player = UnitName("player")
  local MELEE = T["Melee"]

  -- ---------------------------------------------------------------- templates

  -- template -> pattern for string.find (escape magic characters, drop
  -- capture indexes like %1$s, %s -> (.+), %d -> (%d+), anchored)
  local sanitize_cache = {}
  local function sanitize(pattern)
    if not sanitize_cache[pattern] then
      local ret = pattern
      ret = gsub(ret, "([%+%-%*%(%)%?%[%]%^%.])", "%%%1")
      ret = gsub(ret, "%d%$", "")
      ret = gsub(ret, "(%%%a)", "%(%1+%)")
      ret = gsub(ret, "%%s%+", ".+")
      ret = gsub(ret, "%(.%+%)%(%%d%+%)", "%(.-%)%(%%d%+%)")
      sanitize_cache[pattern] = "^" .. ret .. "$"
    end
    return sanitize_cache[pattern]
  end

  -- the order of %1$s style captures in a template
  local capture_cache = {}
  local function captures(pat)
    local r = capture_cache
    if not r[pat] then
      r[pat] = { nil, nil, nil, nil, nil }
      for a, b, c, d, e in string.gfind(gsub(pat, "%((.+)%)", "%1"), gsub(pat, "%d%$", "%%(.-)$")) do
        r[pat][1], r[pat][2], r[pat][3], r[pat][4], r[pat][5] = tonumber(a), tonumber(b), tonumber(c), tonumber(d), tonumber(e)
      end
    end
    return r[pat][1], r[pat][2], r[pat][3], r[pat][4], r[pat][5]
  end

  -- string.find aware of up to 5 capture indexes
  local ra, rb, rc, rd, re, ca, cb, cc, cd, ce, match, num, va, vb, vc, vd, ve
  local function cfind(str, pat)
    ca, cb, cc, cd, ce = captures(pat)
    match, num, va, vb, vc, vd, ve = string.find(str, sanitize(pat))
    ra = ce == 1 and ve or cd == 1 and vd or cc == 1 and vc or cb == 1 and vb or va
    rb = ce == 2 and ve or cd == 2 and vd or cc == 2 and vc or ca == 2 and va or vb
    rc = ce == 3 and ve or cd == 3 and vd or ca == 3 and va or cb == 3 and vb or vc
    rd = ce == 4 and ve or ca == 4 and va or cc == 4 and vc or cb == 4 and vb or vd
    re = ca == 5 and va or cd == 5 and vd or cc == 5 and vc or cb == 5 and vb or ve
    return match, ra, rb, rc, rd, re
  end
  M.cfind = cfind

  -- Each spec: global string name, kind, the roles of its captures in
  -- order, and fixed values. src/tgt "self" = the player.
  --   kinds: dmg heal miss interrupt cast start dispel death
  local SPECS = {
    -- interrupts first: they also come in the spell damage events
    { "SPELLINTERRUPTSELFOTHER", "interrupt", "tgt spl", src = "self" },
    { "SPELLINTERRUPTOTHERSELF", "interrupt", "src spl", tgt = "self" },
    { "SPELLINTERRUPTOTHEROTHER", "interrupt", "src tgt spl" },

    -- deaths
    { "UNITDIESSELF", "death", "", tgt = "self" },
    { "PARTYKILLOTHER", "death", "tgt src" },
    { "SELFKILLOTHER", "death", "tgt", src = "self" },
    { "UNITDIESOTHER", "death", "tgt" },

    -- dispels: "X's Y is removed." (credited to the last dispel cast on X)
    { "AURADISPELSELF", "dispel", "aura", tgt = "self" },
    { "AURADISPELOTHER", "dispel", "tgt aura" },

    -- melee
    { "COMBATHITCRITSCHOOLSELFOTHER", "dmg", "tgt amt sch", src = "self", spl = MELEE, crit = true },
    { "COMBATHITSCHOOLSELFOTHER", "dmg", "tgt amt sch", src = "self", spl = MELEE },
    { "COMBATHITCRITSELFOTHER", "dmg", "tgt amt", src = "self", spl = MELEE, crit = true },
    { "COMBATHITSELFOTHER", "dmg", "tgt amt", src = "self", spl = MELEE },
    { "COMBATHITCRITSCHOOLOTHERSELF", "dmg", "src amt sch", tgt = "self", spl = MELEE, crit = true },
    { "COMBATHITSCHOOLOTHERSELF", "dmg", "src amt sch", tgt = "self", spl = MELEE },
    { "COMBATHITCRITOTHERSELF", "dmg", "src amt", tgt = "self", spl = MELEE, crit = true },
    { "COMBATHITOTHERSELF", "dmg", "src amt", tgt = "self", spl = MELEE },
    { "COMBATHITCRITSCHOOLOTHEROTHER", "dmg", "src tgt amt sch", spl = MELEE, crit = true },
    { "COMBATHITSCHOOLOTHEROTHER", "dmg", "src tgt amt sch", spl = MELEE },
    { "COMBATHITCRITOTHEROTHER", "dmg", "src tgt amt", spl = MELEE, crit = true },
    { "COMBATHITOTHEROTHER", "dmg", "src tgt amt", spl = MELEE },

    -- spells
    { "SPELLLOGCRITSCHOOLSELFSELF", "dmg", "spl amt sch", src = "self", tgt = "self", crit = true },
    { "SPELLLOGSCHOOLSELFSELF", "dmg", "spl amt sch", src = "self", tgt = "self" },
    { "SPELLLOGCRITSELFSELF", "dmg", "spl amt", src = "self", tgt = "self", crit = true },
    { "SPELLLOGSELFSELF", "dmg", "spl amt", src = "self", tgt = "self" },
    { "SPELLLOGCRITSCHOOLSELFOTHER", "dmg", "spl tgt amt sch", src = "self", crit = true },
    { "SPELLLOGSCHOOLSELFOTHER", "dmg", "spl tgt amt sch", src = "self" },
    { "SPELLLOGCRITSELFOTHER", "dmg", "spl tgt amt", src = "self", crit = true },
    { "SPELLLOGSELFOTHER", "dmg", "spl tgt amt", src = "self" },
    { "SPELLLOGCRITSCHOOLOTHERSELF", "dmg", "src spl amt sch", tgt = "self", crit = true },
    { "SPELLLOGSCHOOLOTHERSELF", "dmg", "src spl amt sch", tgt = "self" },
    { "SPELLLOGCRITOTHERSELF", "dmg", "src spl amt", tgt = "self", crit = true },
    { "SPELLLOGOTHERSELF", "dmg", "src spl amt", tgt = "self" },
    { "SPELLLOGCRITSCHOOLOTHEROTHER", "dmg", "src spl tgt amt sch", crit = true },
    { "SPELLLOGSCHOOLOTHEROTHER", "dmg", "src spl tgt amt sch" },
    { "SPELLLOGCRITOTHEROTHER", "dmg", "src spl tgt amt", crit = true },
    { "SPELLLOGOTHEROTHER", "dmg", "src spl tgt amt" },

    -- damage over time
    { "PERIODICAURADAMAGESELFSELF", "dmg", "amt sch spl", src = "self", tgt = "self", dot = true },
    { "PERIODICAURADAMAGESELFOTHER", "dmg", "tgt amt sch spl", src = "self", dot = true },
    { "PERIODICAURADAMAGEOTHERSELF", "dmg", "amt sch src spl", tgt = "self", dot = true },
    { "PERIODICAURADAMAGEOTHEROTHER", "dmg", "tgt amt sch src spl", dot = true },

    -- damage shields (Thorns, Retribution Aura, Fire Shield...)
    { "DAMAGESHIELDSELFOTHER", "dmg", "amt sch tgt", src = "self", spl = T["Damage Shield"] },
    { "DAMAGESHIELDOTHERSELF", "dmg", "src amt sch", tgt = "self", spl = T["Damage Shield"] },
    { "DAMAGESHIELDOTHEROTHER", "dmg", "src amt sch tgt", spl = T["Damage Shield"] },

    -- heals
    { "HEALEDCRITSELFSELF", "heal", "spl amt", src = "self", tgt = "self", crit = true },
    { "HEALEDSELFSELF", "heal", "spl amt", src = "self", tgt = "self" },
    { "HEALEDCRITSELFOTHER", "heal", "spl tgt amt", src = "self", crit = true },
    { "HEALEDSELFOTHER", "heal", "spl tgt amt", src = "self" },
    { "HEALEDCRITOTHERSELF", "heal", "src spl amt", tgt = "self", crit = true },
    { "HEALEDOTHERSELF", "heal", "src spl amt", tgt = "self" },
    { "HEALEDCRITOTHEROTHER", "heal", "src spl tgt amt", crit = true },
    { "HEALEDOTHEROTHER", "heal", "src spl tgt amt" },
    { "PERIODICAURAHEALSELFSELF", "heal", "amt spl", src = "self", tgt = "self", dot = true },
    { "PERIODICAURAHEALSELFOTHER", "heal", "tgt amt spl", src = "self", dot = true },
    { "PERIODICAURAHEALOTHERSELF", "heal", "amt src spl", tgt = "self", dot = true },
    { "PERIODICAURAHEALOTHEROTHER", "heal", "tgt amt src spl", dot = true },

    -- resources gained (octo, phase 2): "You gain 25 Rage from Bloodrage." -
    -- credited to who gains it; the spell (and caster when told) is the source
    { "POWERGAINOTHEROTHER", "power", "tgt amt pow src spl" },
    { "POWERGAINOTHERSELF", "power", "amt pow src spl", tgt = "self" },
    { "POWERGAINSELFOTHER", "power", "tgt amt pow spl" },
    { "POWERGAINSELFSELF", "power", "amt pow spl", src = "self", tgt = "self" },

    -- auras gained and lost (buff / debuff uptime, cooldowns used)
    { "AURAAPPLICATIONADDEDOTHERHELPFUL", "aura", "tgt aura amt", up = true },
    { "AURAAPPLICATIONADDEDSELFHELPFUL", "aura", "aura amt", tgt = "self", up = true },
    { "AURAAPPLICATIONADDEDOTHERHARMFUL", "aura", "tgt aura amt", up = true, harm = true },
    { "AURAAPPLICATIONADDEDSELFHARMFUL", "aura", "aura amt", tgt = "self", up = true, harm = true },
    { "AURAADDEDOTHERHELPFUL", "aura", "tgt aura", up = true },
    { "AURAADDEDSELFHELPFUL", "aura", "aura", tgt = "self", up = true },
    { "AURAADDEDOTHERHARMFUL", "aura", "tgt aura", up = true, harm = true },
    { "AURAADDEDSELFHARMFUL", "aura", "aura", tgt = "self", up = true, harm = true },
    { "AURAREMOVEDOTHER", "aura", "aura tgt" },
    { "AURAREMOVEDSELF", "aura", "aura", tgt = "self" },

    -- melee misses and avoidance
    { "MISSEDSELFOTHER", "miss", "tgt", src = "self", spl = MELEE, how = "miss" },
    { "MISSEDOTHERSELF", "miss", "src", tgt = "self", spl = MELEE, how = "miss" },
    { "MISSEDOTHEROTHER", "miss", "src tgt", spl = MELEE, how = "miss" },
  }

  -- melee avoidance: VS<HOW><SELF|OTHER><SELF|OTHER>
  for _, how in pairs({ "DODGE", "PARRY", "BLOCK", "EVADE", "IMMUNE", "ABSORB", "RESIST" }) do
    local h = strlower(how)
    table.insert(SPECS, { "VS" .. how .. "SELFOTHER", "miss", "tgt", src = "self", spl = MELEE, how = h })
    table.insert(SPECS, { "VS" .. how .. "OTHERSELF", "miss", "src", tgt = "self", spl = MELEE, how = h })
    table.insert(SPECS, { "VS" .. how .. "OTHEROTHER", "miss", "src tgt", spl = MELEE, how = h })
  end

  -- spell misses: SPELL<HOW>SELFOTHER "Your %s ... %s." etc.
  local SPELLHOW = { MISS = "miss", DODGED = "dodge", PARRIED = "parry", BLOCKED = "block", EVADED = "evade",
                     RESIST = "resist", LOGABSORB = "absorb", REFLECT = "reflect", IMMUNE = "immune" }
  for name, h in pairs(SPELLHOW) do
    table.insert(SPECS, { "SPELL" .. name .. "SELFOTHER", "miss", "spl tgt", src = "self", how = h })
    table.insert(SPECS, { "SPELL" .. name .. "OTHERSELF", "miss", "src spl", tgt = "self", how = h })
    table.insert(SPECS, { "SPELL" .. name .. "OTHEROTHER", "miss", "src spl tgt", how = h })
  end

  -- casts (targeted forms first: "You cast X." would also match "You cast X on Y.")
  for _, spec in pairs({
    { "SPELLCASTGOSELFTARGETTED", "cast", "spl tgt", src = "self" },
    { "SPELLPERFORMGOSELFTARGETTED", "cast", "spl tgt", src = "self" },
    { "SPELLCASTGOOTHERTARGETTED", "cast", "src spl tgt" },
    { "SPELLPERFORMGOOTHERTARGETTED", "cast", "src spl tgt" },
    { "SPELLCASTGOSELF", "cast", "spl", src = "self" },
    { "SPELLPERFORMGOSELF", "cast", "spl", src = "self" },
    { "SPELLCASTGOOTHER", "cast", "src spl" },
    { "SPELLPERFORMGOOTHER", "cast", "src spl" },
    { "SPELLCASTOTHERSTART", "start", "src spl" },
    { "SPELLPERFORMOTHERSTART", "start", "src spl" },
    { "SPELLPERFORMSELFSTART", "start", "spl", src = "self" },
  }) do table.insert(SPECS, spec) end

  -- keep the specs whose template this client has, split their roles
  local ACTIVE = {}
  for i, spec in ipairs(SPECS) do
    local template = _G[spec[1]]
    if type(template) == "string" then
      spec.template = template
      spec.roles = {}
      for role in string.gfind(spec[3], "%a+") do table.insert(spec.roles, role) end
      -- fixed text: "Your %s hits %s for %d %s damage." must be tried before
      -- "%s hits %s for %d %s damage." (which would read "Your Fireball" as a name)
      spec.fixed = string.len((gsub(gsub(template, "%%%d%$[sd]", ""), "%%[sd]", "")))
      spec.index = i
      sanitize(template)
      table.insert(ACTIVE, spec)
    end
  end
  table.sort(ACTIVE, function(a, b)
    if a.fixed ~= b.fixed then return a.fixed > b.fixed end
    return a.index < b.index
  end)
  M.specs = ACTIVE

  -- the kinds tried for each combat log event (by its name)
  local function KindsFor(event)
    if strfind(event, "DEATH") then return { death = true } end
    if strfind(event, "_HITS") then return { dmg = true } end
    if strfind(event, "_MISSES") then return { miss = true } end
    if strfind(event, "DAMAGESHIELDS") then return { dmg = true, miss = true } end
    if strfind(event, "AURA_GONE") or strfind(event, "BREAK_AURA") then return { dispel = true, aura = true } end
    if strfind(event, "PERIODIC") then return { dmg = true, heal = true, power = true, aura = true } end
    if strfind(event, "_BUFF") then return { heal = true, cast = true, start = true, power = true, aura = true } end
    if strfind(event, "_DAMAGE") then return { interrupt = true, dmg = true, miss = true, cast = true, start = true, power = true, aura = true } end
    return { dmg = true, heal = true, miss = true, interrupt = true, cast = true, start = true, dispel = true, death = true,
             power = true, aura = true }
  end

  local EVENTS = {
    "CHAT_MSG_COMBAT_SELF_HITS", "CHAT_MSG_COMBAT_SELF_MISSES",
    "CHAT_MSG_COMBAT_PARTY_HITS", "CHAT_MSG_COMBAT_PARTY_MISSES",
    "CHAT_MSG_COMBAT_FRIENDLYPLAYER_HITS", "CHAT_MSG_COMBAT_FRIENDLYPLAYER_MISSES",
    "CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS", "CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES",
    "CHAT_MSG_COMBAT_PET_HITS", "CHAT_MSG_COMBAT_PET_MISSES",
    "CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS", "CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES",
    "CHAT_MSG_COMBAT_CREATURE_VS_PARTY_HITS", "CHAT_MSG_COMBAT_CREATURE_VS_PARTY_MISSES",
    "CHAT_MSG_COMBAT_CREATURE_VS_CREATURE_HITS", "CHAT_MSG_COMBAT_CREATURE_VS_CREATURE_MISSES",
    "CHAT_MSG_SPELL_SELF_DAMAGE", "CHAT_MSG_SPELL_SELF_BUFF",
    "CHAT_MSG_SPELL_PARTY_DAMAGE", "CHAT_MSG_SPELL_PARTY_BUFF",
    "CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE", "CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF",
    "CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE", "CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF",
    "CHAT_MSG_SPELL_PET_DAMAGE", "CHAT_MSG_SPELL_PET_BUFF",
    "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE", "CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE",
    "CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE",
    "CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF", "CHAT_MSG_SPELL_DAMAGESHIELDS_ON_OTHERS",
    "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE", "CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS",
    "CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE", "CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS",
    "CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE", "CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS",
    "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE", "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_BUFFS",
    "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE",
    "CHAT_MSG_SPELL_BREAK_AURA", "CHAT_MSG_SPELL_AURA_GONE_OTHER", "CHAT_MSG_SPELL_AURA_GONE_SELF",
    "CHAT_MSG_SPELL_AURA_GONE_PARTY", "CHAT_MSG_SPELL_PERIODIC_CREATURE_BUFFS",
    "CHAT_MSG_COMBAT_FRIENDLY_DEATH", "CHAT_MSG_COMBAT_HOSTILE_DEATH",
  }

  -- trailers: " (12 absorbed)", " (8 resisted)", " (30 blocked)", " (glancing)", " (crushing)"
  local TRAILERS = {}
  for _, name in pairs({ "ABSORB_TRAILER", "RESIST_TRAILER", "BLOCK_TRAILER", "VULNERABLE_TRAILER" }) do
    if type(_G[name]) == "string" then
      local p = sanitize(_G[name])
      table.insert(TRAILERS, string.sub(p, 2, -2) .. "$")
    end
  end
  local GLANCING = type(GLANCING_TRAILER) == "string" and GLANCING_TRAILER or " (glancing)"
  local CRUSHING = type(CRUSHING_TRAILER) == "string" and CRUSHING_TRAILER or " (crushing)"

  -- reads one combat log line: a record table or nil (reused table)
  local rec = {}
  function M.Read(event, msg)
    if type(msg) ~= "string" then return end

    local glancing, crushing
    if strfind(msg, GLANCING, 1, true) then glancing = true msg = gsub(msg, "%s?%(.-%)$", "") end
    if strfind(msg, CRUSHING, 1, true) then crushing = true msg = gsub(msg, "%s?%(.-%)$", "") end
    local n
    repeat
      n = 0
      for _, p in pairs(TRAILERS) do
        local before = msg
        msg = gsub(msg, p, "")
        if msg ~= before then n = n + 1 end
      end
    until n == 0

    local kinds = KindsFor(event or "")
    for _, spec in ipairs(ACTIVE) do
      if kinds[spec[2]] then
        local found, a1, a2, a3, a4, a5 = cfind(msg, spec.template)
        if found then
          rec.kind, rec.how, rec.crit, rec.dot = spec[2], spec.how, spec.crit, spec.dot
          rec.glancing, rec.crushing = glancing, crushing
          rec.src, rec.tgt, rec.spl, rec.amt, rec.sch, rec.aura = nil, nil, spec.spl, nil, nil, nil
          rec.pow, rec.up, rec.harm, rec.amt2, rec.pow2, rec.leech = nil, spec.up, spec.harm, nil, nil, spec.leech
          local values = { a1, a2, a3, a4, a5 }
          for i, role in ipairs(spec.roles) do rec[role] = values[i] end
          if spec.src == "self" then rec.src = player end
          if spec.tgt == "self" then rec.tgt = player end
          rec.amt = tonumber(rec.amt)
          return rec
        end
      end
    end
  end

  -- ---------------------------------------------------------------- who is tracked

  local units = { "player", "pet" }
  for i = 1, 4 do table.insert(units, "party" .. i) table.insert(units, "partypet" .. i) end
  for i = 1, 40 do table.insert(units, "raid" .. i) table.insert(units, "raidpet" .. i) end

  local unitcache = {}
  local function UnitByName(name)
    local u = unitcache[name]
    if u and UnitName(u) == name then return u end
    for _, unit in ipairs(units) do
      if UnitName(unit) == name then
        unitcache[name] = unit
        return unit
      end
    end
  end
  M.UnitByName = UnitByName

  -- name -> { kind = "PLAYER" | "PET" | "OTHER", class, owner }
  M.who = {}

  -- octo (29 Oct 2026; user: "all players pets should be tracked ... any summoned pets even pets from item
  -- procs ... TOTEMS TOO"): who summoned what, for creatures without a unit of their own - totems,
  -- guardians, summons, item pets. Filled from ClassicAPI's SPELL_SUMMON (meters-clog.lua), your group's
  -- guardian flags there, and the cast lines (M.Record below: "X casts Searing Totem").
  M.owners = {}
  -- summon spells whose creature has another name (item pets included)
  M.SUMMONS = {
    ["Inferno"] = "Infernal", ["Ritual of Doom"] = "Doomguard", ["Force of Nature"] = "Treant",
    ["Summon Water Elemental"] = "Water Elemental", ["Gnomish Battle Chicken"] = "Battle Chicken",
    ["Arcanite Dragonling"] = "Arcanite Dragonling", ["Mechanical Dragonling"] = "Mechanical Dragonling",
    ["Mithril Mechanical Dragonling"] = "Mithril Mechanical Dragonling", ["Lifelike Mechanical Toad"] = "Lifelike Toad",
    ["Summon Felguard"] = "Felguard", ["Eye of Kilrogg"] = "Eye of Kilrogg", ["Summon Treant Allies"] = "Treant",
    ["Summon Spirit Wolf"] = "Spirit Wolf", ["Feral Spirit"] = "Spirit Wolf", ["Summon Skeleton"] = "Skeleton",
  }
  function M.SetOwner(creature, owner)
    if not creature or not owner or creature == owner then return end
    M.owners[creature] = owner
    M.who[creature] = nil
  end
  -- a cast that makes a creature: its name -> the caster (totems are named as their spell)
  function M.SummonCast(caster, spell)
    if not caster or not spell then return end
    local creature = M.SUMMONS[spell] or (strfind(spell, "Totem") and spell)
    if creature then M.SetOwner(creature, caster) end
  end
  local function Who(name)
    if not name then return end
    local w = M.who[name]
    if w and w.checked and w.checked > GetTime() - 10 then return w.kind and w end

    w = { checked = GetTime() }
    M.who[name] = w
    local unit = UnitByName(name)
    if unit then
      if strfind(unit, "pet") then
        w.kind = "PET"
        local owner = unit == "pet" and "player" or gsub(unit, "pet", "")
        w.owner = UnitName(owner)
      elseif UnitIsPlayer(unit) then
        w.kind = "PLAYER"
        local _, class = UnitClass(unit)
        w.class = class
      end
    else
      -- SuperWoW names pets "Wolf (Owner)"
      local _, _, owner = strfind(name, "%((.+)%)$")
      -- totems carry their rank: "Searing Totem III" is the Searing Totem
      local base = gsub(name, " [IVX]+$", "")
      local summoned = M.owners[name] or M.owners[base]
      if summoned and (UnitByName(summoned) or Who(summoned)) then
        w.kind, w.owner = "PET", summoned
      elseif owner and UnitByName(owner) then
        w.kind, w.owner = "PET", owner
      elseif C.meters.trackall == "1" then
        w.kind = "OTHER"
      end
    end
    return w.kind and w
  end
  M.Who = Who

  -- ---------------------------------------------------------------- segments

  -- a segment: actors = your group by name; enemies = damage each enemy took
  -- (names the fight); foes = enemies in detail (damage taken / done, by
  -- whom, with what); byspell = what hit your group, by spell
  local function NewSegment(name)
    return { name = name, start = GetTime(), last = GetTime(), actors = {}, enemies = {}, foes = {}, byspell = {} }
  end

  M.overall = NewSegment(T["Overall"])
  M.history = {}    -- finished and running fights, newest first
  M.current = nil   -- the running fight

  function M.Duration(seg)
    if not seg then return 1 end
    if seg == M.overall then
      local t = 0
      for _, s in ipairs(M.history) do t = t + max(1, (s.last or s.start) - s.start) end
      return max(1, t)
    end
    return max(1, (seg.last or seg.start) - seg.start)
  end

  local function Actor(seg, name, info)
    local a = seg.actors[name]
    if not a then
      a = { name = name, class = info and info.class, damage = 0, heal = 0, overheal = 0, taken = 0,
            interrupts = 0, interrupted = 0, dispels = 0, deaths = 0, ncasts = 0, active = 0,
            spells = {}, hspells = {}, tspells = {}, targets = {}, htargets = {}, sources = {},
            casts = {}, avoid = {}, ilist = {}, dlist = {}, deathlogs = {},
            -- phase 2: friendly fire, healing taken, kills, resources, ress, cooldowns, uptime
            ff = 0, ffspells = {}, fftargets = {}, htaken = 0, hsources = {}, frags = 0, fraglist = {},
            power = {}, psources = {}, ress = 0, resslist = {}, cds = 0, cdlist = {},
            buffs = {}, debuffs = {}, buffsum = 0, debuffsum = 0 }
      seg.actors[name] = a
    end
    if info and info.class and not a.class then a.class = info.class end
    return a
  end
  M.Actor = Actor

  -- an enemy in detail
  local function Foe(seg, name)
    local f = seg.foes[name]
    if not f then
      f = { name = name, taken = 0, done = 0, from = {}, to = {}, tspells = {}, dspells = {} }
      seg.foes[name] = f
    end
    return f
  end
  M.Foe = Foe

  -- activity time: gaps longer than 3.5 s count as 1.5 s
  local function Active(a, now)
    if a.lastact then
      local gap = now - a.lastact
      a.active = a.active + (gap > 3.5 and 1.5 or gap)
    end
    a.lastact = now
  end

  local function Spell(list, name)
    local s = list[name]
    if not s then
      s = { total = 0, hits = 0, crits = 0, ticks = 0, misses = 0, over = 0, max = 0, min = nil, how = {} }
      list[name] = s
    end
    return s
  end

  -- every fight starts when a tracked player acts while the group is in combat
  local function GroupInCombat()
    if UnitAffectingCombat("player") or UnitAffectingCombat("pet") then return true end
    local raid, party = GetNumRaidMembers(), GetNumPartyMembers()
    if raid > 0 then
      for i = 1, raid do
        if UnitAffectingCombat("raid" .. i) or UnitAffectingCombat("raidpet" .. i) then return true end
      end
    else
      for i = 1, party do
        if UnitAffectingCombat("party" .. i) or UnitAffectingCombat("partypet" .. i) then return true end
      end
    end
  end
  M.GroupInCombat = GroupInCombat

  M.onStart = {}  -- called with the new segment (windows go back to it)
  function M.StartFight()
    local seg = NewSegment(T["Fight"])
    M.current = seg
    table.insert(M.history, 1, seg)
    local keep = tonumber(C.meters.history) or 10
    while table.getn(M.history) > keep do table.remove(M.history) end
    for _, fn in pairs(M.onStart) do fn(seg) end
    return seg
  end

  -- one segment added into another (numbers summed, max / min kept, lists
  -- joined): trash fights merged into one
  local LISTS = { ilist = true, dlist = true, deathlogs = true, fraglist = true, resslist = true, cdlist = true }
  -- (a merged fight keeps the first fight's chart: times count from each start)
  local SKIP = { start = true, last = true, lastact = true, name = true, class = true, boss = true, trash = true,
                 timeline = true }
  local function Merge(dst, src)
    for k, v in pairs(src) do
      local d = dst[k]
      if SKIP[k] then
        if d == nil then dst[k] = v end
      elseif type(v) == "number" then
        if k == "max" or k == "cmax" then dst[k] = max(d or 0, v)
        elseif k == "min" or k == "cmin" then dst[k] = d and min(d, v) or v
        else dst[k] = (d or 0) + v end
      elseif type(v) == "table" then
        if not d then d = {} dst[k] = d end
        if LISTS[k] then
          for _, e in ipairs(v) do table.insert(d, e) end
        else
          Merge(d, v)
        end
      elseif d == nil then
        dst[k] = v
      end
    end
  end
  M.Merge = Merge

  -- auras still up when a fight ends count up to its end
  local CloseAuras

  function M.EndFight()
    local seg = M.current
    if not seg then return end
    if CloseAuras then CloseAuras(seg) end
    M.current = nil
    -- name it after the boss, else the enemy that took the most damage
    local best, bestv = nil, 0
    for name, v in pairs(seg.enemies) do
      if v > bestv then best, bestv = name, v end
    end
    seg.name = seg.boss or best or T["Fight"]
    seg.trash = not seg.boss
    -- trash fights in a row become one "Trash" fight (Details' "merge trash")
    local prev = M.history[2]
    if seg.trash and C.meters.mergetrash == "1" and prev and prev.trash and M.history[1] == seg then
      Merge(prev, seg)
      prev.last = seg.last
      prev.merged = (prev.merged or 1) + 1
      prev.name = T["Trash"] .. " (" .. prev.merged .. ")"
      table.remove(M.history, 1)
    end
    -- or trash is not kept at all (Details' "auto erase trash segments";
    -- the overall keeps it)
    if seg.trash and C.meters.erasetrash == "1" then
      for i, s in ipairs(M.history) do
        if s.trash then table.remove(M.history, i) break end
      end
    end
    M.Changed()
  end

  function M.Reset()
    M.overall = NewSegment(T["Overall"])
    M.history = {}
    M.current = nil
    M.Changed()
  end

  -- the segments a window can show: "overall", "current" (running or
  -- last), or a history index
  function M.Segment(key)
    if key == "overall" then return M.overall end
    if key == "current" then return M.current or M.history[1] end
    return M.history[tonumber(key) or 1]
  end

  -- ---------------------------------------------------------------- death logs

  -- the last 15 things that happened to each player, for the death log
  M.recent = {}
  local function Remember(name, kind, amount, spell, other, crit)
    local ring = M.recent[name]
    if not ring then ring = { n = 0 } M.recent[name] = ring end
    ring.n = ring.n + 1
    ring[math.mod(ring.n - 1, 15) + 1] = { t = GetTime(), kind = kind, amount = amount, spell = spell, who = other,
                                           crit = crit, hp = nil }
    local unit = UnitByName(name)
    if unit then
      local entry = ring[math.mod(ring.n - 1, 15) + 1]
      entry.hp, entry.hpmax = UnitHealth(unit), UnitHealthMax(unit)
    end
  end

  local function DeathLog(name)
    local ring = M.recent[name]
    local log = {}
    if not ring then return log end
    local first = max(1, ring.n - 14)
    for i = first, ring.n do
      local e = ring[math.mod(i - 1, 15) + 1]
      if e and GetTime() - e.t < 15 then table.insert(log, e) end
    end
    M.recent[name] = nil
    return log
  end

  -- ---------------------------------------------------------------- recording

  local DISPELS = {}
  for _, s in pairs({ "Dispel Magic", "Cleanse", "Purify", "Remove Curse", "Remove Lesser Curse", "Cure Poison",
                      "Abolish Poison", "Cure Disease", "Abolish Disease", "Purge", "Devour Magic",
                      "Tranquilizing Shot", "Poison Cleansing Totem", "Disease Cleansing Totem" }) do
    DISPELS[T[s]] = true
  end
  -- resurrections and cooldowns worth listing (English names through T[])
  local RESS, COOLDOWNS = {}, {}
  for _, s in pairs({ "Resurrection", "Redemption", "Rebirth", "Ancestral Spirit" }) do RESS[T[s]] = true end
  for _, s in pairs({ "Shield Wall", "Last Stand", "Recklessness", "Retaliation", "Death Wish", "Challenging Shout",
                      "Evasion", "Vanish", "Sprint", "Adrenaline Rush", "Blade Flurry", "Cold Blood", "Preparation",
                      "Ice Block", "Arcane Power", "Combustion", "Presence of Mind", "Cold Snap", "Evocation",
                      "Divine Shield", "Divine Protection", "Blessing of Protection", "Lay on Hands", "Divine Favor",
                      "Barkskin", "Innervate", "Tranquility", "Nature's Swiftness", "Dash", "Frenzied Regeneration",
                      "Challenging Roar", "Power Infusion", "Inner Focus", "Desperate Prayer", "Mana Tide Totem",
                      "Elemental Mastery", "Deterrence", "Rapid Fire", "Bestial Wrath", "Fel Domination", "Amplify Curse",
                      "Soulstone Resurrection" }) do
    COOLDOWNS[T[s]] = true
  end
  M.RESS, M.COOLDOWNS = RESS, COOLDOWNS

  local pendingDispel = {}  -- target -> { src, spell, t }
  local lastHit = {}        -- enemy -> { actor, t } (who killed it)
  local lastCaster = {}     -- spell -> { actor, t } (whose debuff it is)
  local open = {}           -- unit name -> { aura -> { start, caster, harm } } (uptime)
  local cdSeen = {}         -- actor .. spell -> time (a cooldown counted once)
  local pendingStart = {}   -- src .. spell -> time a cast began
  local lastSpell = {}      -- src -> { spell, t } (what an interrupt was done with)

  -- the actor names a record belongs to: a player, or a pet's owner
  local function Owner(name)
    local w = Who(name)
    if not w then return end
    if w.kind == "PET" then
      if C.meters.mergepets == "1" and w.owner then return w.owner, name end
      return name
    end
    return name
  end

  local function Each(fn)
    fn(M.overall)
    if M.current then fn(M.current) end
  end

  function M.Record(r)
    if not r or not r.kind then return end
    local now = GetTime()
    -- (a cast that summons a totem / guardian: who it belongs to, before its first hit)
    if (r.kind == "cast" or r.kind == "start") and r.src and r.spl then M.SummonCast(r.src, r.spl) end
    local srcname, srcpet = Owner(r.src)
    local tgtname = Owner(r.tgt)

    -- a fight starts with the first tracked action in combat
    if not M.current and (srcname or tgtname) and (r.kind == "dmg" or r.kind == "heal" or r.kind == "miss") then
      if GroupInCombat() or M.forceCombat then M.StartFight() end
    end
    if M.current then M.current.last = now end

    local label = r.spl or MELEE
    if srcpet then label = label .. " (" .. srcpet .. ")" end
    -- what each unit last used (an interrupt names the spell it stopped, not the kick)
    local with = r.with or (r.kind == "interrupt" and r.src and lastSpell[r.src] and now - lastSpell[r.src].t < 1.5 and lastSpell[r.src].spell)
    if r.src and r.spl and r.kind ~= "interrupt" and r.kind ~= "start" then lastSpell[r.src] = { spell = r.spl, t = now } end

    if r.kind == "dmg" then
      if not r.amt or r.src == r.tgt then return end
      -- one of your group hitting another: friendly fire, not damage done
      -- (Details! counts it apart; with "everyone nearby" on, enemy players
      -- are tracked too, and are not friends)
      local sw, tw = srcname and Who(srcname), tgtname and Who(tgtname)
      if sw and tw and sw.kind ~= "OTHER" and tw.kind ~= "OTHER" and srcname ~= tgtname then
        Each(function(seg)
          local a = Actor(seg, srcname, sw)
          a.ff = a.ff + r.amt
          local s = Spell(a.ffspells, label)
          s.total = s.total + r.amt
          s.hits = s.hits + 1
          if r.amt > s.max then s.max = r.amt end
          a.fftargets[tgtname] = (a.fftargets[tgtname] or 0) + r.amt
          local t = Actor(seg, tgtname, tw)
          t.taken = t.taken + r.amt
          t.sources[r.src] = (t.sources[r.src] or 0) + r.amt
        end)
        Remember(tgtname, "dmg", r.amt, label, r.src, r.crit)
        M.Changed()
        return
      end
      -- enemies in detail, what hit your group by spell, who hit last
      if srcname and r.tgt and not tgtname then
        lastHit[r.tgt] = { name = srcname, t = now }
        if r.spl and r.spl ~= MELEE then lastCaster[r.spl] = { name = srcname, t = now } end
        if M.current and not M.current.boss and M.IsBoss(r.tgt) then M.current.boss = r.tgt end
        Each(function(seg)
          local f = Foe(seg, r.tgt)
          f.taken = f.taken + r.amt
          f.from[srcname] = (f.from[srcname] or 0) + r.amt
          local s = Spell(f.tspells, label .. " - " .. srcname)
          s.total = s.total + r.amt
          s.hits = s.hits + 1
        end)
      elseif tgtname and r.src and not srcname then
        Each(function(seg)
          local f = Foe(seg, r.src)
          f.done = f.done + r.amt
          f.to[tgtname] = (f.to[tgtname] or 0) + r.amt
          local s = Spell(f.dspells, label)
          s.total = s.total + r.amt
          s.hits = s.hits + 1
          if r.amt > s.max then s.max = r.amt end
          local b = seg.byspell[label]
          if not b then b = { total = 0, hits = 0, max = 0, targets = {}, from = {} } seg.byspell[label] = b end
          b.total = b.total + r.amt
          b.hits = b.hits + 1
          if r.amt > b.max then b.max = r.amt end
          b.targets[tgtname] = (b.targets[tgtname] or 0) + r.amt
          b.from[r.src] = (b.from[r.src] or 0) + r.amt
        end)
        if M.current and not M.current.boss and M.IsBoss(r.src) then M.current.boss = r.src end
      end
      if srcname then
        Each(function(seg)
          local a = Actor(seg, srcname, Who(srcname))
          a.damage = a.damage + r.amt
          Active(a, now)
          local s = Spell(a.spells, label)
          s.total = s.total + r.amt
          if r.dot then
            s.ticks = s.ticks + 1
            s.ttotal = (s.ttotal or 0) + r.amt
          else
            s.hits = s.hits + 1
          end
          if r.crit then
            s.crits = s.crits + 1
            -- (crits apart: their total, max and min, for the breakdown)
            s.ctotal = (s.ctotal or 0) + r.amt
            if r.amt > (s.cmax or 0) then s.cmax = r.amt end
            if not s.cmin or r.amt < s.cmin then s.cmin = r.amt end
          end
          if r.glancing then s.how.glancing = (s.how.glancing or 0) + 1 end
          if r.crushing then s.how.crushing = (s.how.crushing or 0) + 1 end
          if r.amt > s.max then s.max = r.amt end
          if not r.dot and (not s.min or r.amt < s.min) then s.min = r.amt end
          if r.tgt then
            a.targets[r.tgt] = (a.targets[r.tgt] or 0) + r.amt
            -- (each spell's targets, for the breakdown)
            s.targets = s.targets or {}
            s.targets[r.tgt] = (s.targets[r.tgt] or 0) + r.amt
          end
          if not tgtname and r.tgt then seg.enemies[r.tgt] = (seg.enemies[r.tgt] or 0) + r.amt end
        end)
        -- a direct hit of a spell that began casting counts as its cast
        if not r.dot and r.spl and r.spl ~= MELEE then
          local key = r.src .. "\031" .. r.spl
          if pendingStart[key] then pendingStart[key] = nil elseif not r.nocast then M.Cast(srcname, r.spl, r.tgt, true) end
        end
      end
      if tgtname then
        Each(function(seg)
          local a = Actor(seg, tgtname, Who(tgtname))
          a.taken = a.taken + r.amt
          local who = r.src or "?"
          a.sources[who] = (a.sources[who] or 0) + r.amt
          local s = Spell(a.tspells, label .. " - " .. who)
          s.total = s.total + r.amt
          s.hits = s.hits + 1
          if r.amt > s.max then s.max = r.amt end
        end)
        Remember(tgtname, "dmg", r.amt, label, r.src, r.crit)
      end

    elseif r.kind == "heal" then
      if not r.amt then return end
      local effective = r.amt
      local unit = r.tgt and UnitByName(r.tgt)
      if unit then effective = min(r.amt, max(0, UnitHealthMax(unit) - UnitHealth(unit)))
      -- (the test fight says how much of a heal was too much)
      elseif r.over then effective = max(0, r.amt - r.over) end
      if srcname then
        Each(function(seg)
          local a = Actor(seg, srcname, Who(srcname))
          a.heal = a.heal + effective
          a.overheal = a.overheal + (r.amt - effective)
          Active(a, now)
          local s = Spell(a.hspells, label)
          s.total = s.total + effective
          s.over = s.over + (r.amt - effective)
          if r.dot then
            s.ticks = s.ticks + 1
            s.ttotal = (s.ttotal or 0) + effective
          else
            s.hits = s.hits + 1
          end
          if r.crit then
            s.crits = s.crits + 1
            s.ctotal = (s.ctotal or 0) + effective
            if r.amt > (s.cmax or 0) then s.cmax = r.amt end
            if not s.cmin or r.amt < s.cmin then s.cmin = r.amt end
          end
          if r.amt > s.max then s.max = r.amt end
          if not r.dot and (not s.min or r.amt < s.min) then s.min = r.amt end
          if r.tgt then
            a.htargets[r.tgt] = (a.htargets[r.tgt] or 0) + effective
            s.targets = s.targets or {}
            s.targets[r.tgt] = (s.targets[r.tgt] or 0) + effective
          end
        end)
        if r.spl then lastCaster[r.spl] = { name = srcname, t = now } end
        if not r.dot and r.spl then
          local key = r.src .. "\031" .. r.spl
          if pendingStart[key] then pendingStart[key] = nil elseif not r.nocast then M.Cast(srcname, r.spl, r.tgt, true) end
        end
      end
      if tgtname then
        Remember(tgtname, "heal", effective, label, r.src, r.crit)
        -- healing taken, and from whom
        Each(function(seg)
          local t = Actor(seg, tgtname, Who(tgtname))
          t.htaken = t.htaken + effective
          local from = r.src or "?"
          t.hsources[from] = (t.hsources[from] or 0) + effective
        end)
      end

    elseif r.kind == "miss" then
      if srcname then
        Each(function(seg)
          local a = Actor(seg, srcname, Who(srcname))
          Active(a, now)
          local s = Spell(a.spells, label)
          s.misses = s.misses + 1
          s.how[r.how or "miss"] = (s.how[r.how or "miss"] or 0) + 1
        end)
      end
      if tgtname then
        Each(function(seg)
          local a = Actor(seg, tgtname, Who(tgtname))
          a.avoid[r.how or "miss"] = (a.avoid[r.how or "miss"] or 0) + 1
        end)
      end

    elseif r.kind == "interrupt" then
      if with == r.spl then with = nil end
      if srcname then
        Each(function(seg)
          local a = Actor(seg, srcname, Who(srcname))
          a.interrupts = a.interrupts + 1
          table.insert(a.ilist, { t = now, spell = r.spl, target = r.tgt, with = with })
        end)
      end
      if tgtname then
        Each(function(seg)
          local a = Actor(seg, tgtname, Who(tgtname))
          a.interrupted = a.interrupted + 1
        end)
      end

    elseif r.kind == "start" then
      if r.src and r.spl then pendingStart[r.src .. "\031" .. r.spl] = now end
      if srcname then M.Cast(srcname, r.spl, nil) end

    elseif r.kind == "cast" then
      if srcname then M.Cast(srcname, r.spl, r.tgt) end
      if r.spl and DISPELS[r.spl] and r.tgt then
        pendingDispel[r.tgt] = { src = srcname, spell = r.spl, t = now }
      end

    elseif r.kind == "dispel" then
      local p = r.tgt and pendingDispel[r.tgt]
      -- (ClassicAPI's combat log names the dispeller itself)
      if r.src and srcname then p = { src = srcname, t = now } end
      if p and p.src and now - p.t < 2 then
        Each(function(seg)
          local a = Actor(seg, p.src, Who(p.src))
          a.dispels = a.dispels + 1
          table.insert(a.dlist, { t = now, aura = r.aura, target = r.tgt, with = p.spell })
        end)
      end

    elseif r.kind == "death" then
      if tgtname then
        local w = Who(r.tgt)
        if w and w.kind ~= "PET" then
          local log = DeathLog(tgtname)
          Each(function(seg)
            local a = Actor(seg, tgtname, w)
            a.deaths = a.deaths + 1
            table.insert(a.deathlogs, { t = now, killer = r.src, log = log })
          end)
        end
      end
      if r.tgt and M.current then M.current.enemies[r.tgt] = M.current.enemies[r.tgt] or 0 end
      -- an enemy died: a frag for whoever killed it (the log names the
      -- killer, else the last of your group to hit it, within 10 s)
      if r.tgt and not tgtname then
        local killer = srcname
        if not killer and lastHit[r.tgt] and now - lastHit[r.tgt].t < 10 then killer = lastHit[r.tgt].name end
        if killer then
          Each(function(seg)
            local a = Actor(seg, killer, Who(killer))
            a.frags = a.frags + 1
            table.insert(a.fraglist, { t = now, target = r.tgt })
          end)
        end
        lastHit[r.tgt] = nil
      end
      -- whatever was on the dead stops counting
      if r.tgt then M.AuraGone(r.tgt, nil, now) end

    elseif r.kind == "power" then
      -- resources gained: mana, rage, energy (and others by their name)
      if tgtname and r.amt and r.pow then
        local from = r.spl or "?"
        if r.src and r.src ~= r.tgt then from = from .. " (" .. r.src .. ")" end
        Each(function(seg)
          local a = Actor(seg, tgtname, Who(tgtname))
          a.power[r.pow] = (a.power[r.pow] or 0) + r.amt
          a.psources[r.pow] = a.psources[r.pow] or {}
          a.psources[r.pow][from] = (a.psources[r.pow][from] or 0) + r.amt
        end)
      end

    elseif r.kind == "aura" then
      if not r.tgt or not r.aura then return end
      if r.up then
        M.AuraUp(r.tgt, r.aura, r.harm, now, r.src)
        -- a cooldown seen as its buff (cast by the one who has it)
        if not r.harm and tgtname and COOLDOWNS[r.aura] then M.Cooldown(tgtname, r.aura, r.tgt, now) end
      else
        M.AuraGone(r.tgt, r.aura, now)
      end
      return
    end

    M.Changed()
  end

  -- ---------------------------------------------------------------- uptime

  -- Buffs on your group count for the one who has them; debuffs on enemies
  -- for the one who cast them (1.12's log does not say who: the last of
  -- your group seen using that spell, within 30 s).
  local function Credit(name, aura, harm, t0, now, onlyseg)
    if not name then return end
    local function Add(seg)
      local from = max(t0, seg.start)
      local dt = now - from
      if dt <= 0 then return end
      local a = Actor(seg, name, Who(name))
      if harm then
        a.debuffs[aura] = (a.debuffs[aura] or 0) + dt
        a.debuffsum = a.debuffsum + dt
      else
        a.buffs[aura] = (a.buffs[aura] or 0) + dt
        a.buffsum = a.buffsum + dt
      end
    end
    if onlyseg then Add(onlyseg) else Each(Add) end
  end

  function M.AuraUp(unit, aura, harm, now, by)
    local friend = Owner(unit)
    local caster
    if harm then
      if friend then return end   -- debuffs on your group are not uptime
      local lc = lastCaster[aura]
      -- (ClassicAPI says who cast it; the text lines never do)
      caster = (by and Owner(by)) or (lc and now - lc.t < 30 and lc.name)
      if not caster then return end
    else
      if not friend then return end
      caster = friend
    end
    open[unit] = open[unit] or {}
    if not open[unit][aura] then open[unit][aura] = { start = now, caster = caster, harm = harm } end
  end

  -- aura == nil: everything on that unit (it died)
  function M.AuraGone(unit, aura, now)
    local list = open[unit]
    if not list then return end
    for name, o in pairs(list) do
      if not aura or name == aura then
        Credit(o.caster, name, o.harm, o.start, now)
        list[name] = nil
      end
    end
    if not next(list) then open[unit] = nil end
    M.Changed()
  end

  -- a fight ends: what is still up counts for it up to now (the overall
  -- and the next fight get theirs when it fades)
  CloseAuras = function(seg)
    local now = GetTime()
    for unit, list in pairs(open) do
      for name, o in pairs(list) do
        Credit(o.caster, name, o.harm, o.start, now, seg)
        -- (from here the overall still counts from the start, the next
        -- fight from its own start)
      end
    end
  end

  -- a cooldown used, counted once (its cast and its buff may both show)
  function M.Cooldown(name, spell, target, now)
    local key = name .. "\031" .. spell
    if cdSeen[key] and now - cdSeen[key] < 3 then return end
    cdSeen[key] = now
    Each(function(seg)
      local a = Actor(seg, name, Who(name))
      a.cds = a.cds + 1
      table.insert(a.cdlist, { t = now, spell = spell, target = target })
    end)
    M.Changed()
  end

  -- a boss: the game marks it (skull level or "worldboss") on a unit we can see
  function M.IsBoss(name)
    for _, unit in ipairs({ "target", "targettarget", "mouseover", "pettarget", "party1target", "party2target",
                            "party3target", "party4target" }) do
      if UnitName(unit) == name then
        if UnitClassification(unit) == "worldboss" or UnitLevel(unit) == -1 then return true end
        return false
      end
    end
    return false
  end

  -- a cast by an actor; counted == true when it came from its hit
  -- (with SuperWoW casts also come from its cast events - every cast, with
  -- its target; a cast seen by both the log and the event counts once)
  local castSeen = {}
  function M.Cast(name, spell, target, counted, fromCastEvent)
    if not name or not spell then return end
    local now = GetTime()
    local key = name .. "\031" .. spell
    local seen = castSeen[key]
    if seen and now - seen.t < 1 and seen.event ~= fromCastEvent then
      -- the other source already counted it; keep its target if it had none
      return
    end
    castSeen[key] = { t = now, event = fromCastEvent }
    Each(function(seg)
      local a = Actor(seg, name, Who(name))
      a.casts[spell] = (a.casts[spell] or 0) + 1
      a.ncasts = a.ncasts + 1
      if RESS[spell] then
        a.ress = a.ress + 1
        table.insert(a.resslist, { t = now, spell = spell, target = target })
      end
    end)
    lastCaster[spell] = { name = name, t = now }
    if COOLDOWNS[spell] then M.Cooldown(name, spell, target, now) end
  end

  -- SuperWoW: UNIT_CASTEVENT(caster GUID, target GUID, "START" / "CAST" /
  -- "CHANNEL" / "FAIL" / "MAINHAND" / "OFFHAND", spell id, duration).
  -- Names come from UnitName(GUID), spell names from SpellInfo(id).
  function M.CastEvent(casterGUID, targetGUID, kind, spellId)
    if kind ~= "CAST" and kind ~= "CHANNEL" then return end
    local caster = casterGUID and UnitName(casterGUID)
    local name = caster and Owner(caster)
    if not name then return end
    local spell = SpellInfo and spellId and SpellInfo(spellId)
    if not spell or spell == "" then return end
    local target = targetGUID and targetGUID ~= "" and UnitName(targetGUID) or nil
    M.Cast(name, spell, target, nil, true)
    if M.current then M.current.last = GetTime() end
  end

  -- a sample of the fight: { t = seconds in, d = { name = damage }, h = { name = healing } }
  function M.Sample(seg)
    seg.timeline = seg.timeline or {}
    if table.getn(seg.timeline) >= 3600 then return end
    local d, h = {}, {}
    for name, a in pairs(seg.actors) do
      d[name], h[name] = a.damage, a.heal
    end
    table.insert(seg.timeline, { t = GetTime() - seg.start, d = d, h = h })
  end

  -- per second over time for one actor (or everyone: name nil), smoothed over
  -- `span` seconds: a list of values, one per sample
  function M.Curve(seg, name, heal, span)
    local line = seg and seg.timeline or {}
    span = span or 5
    local out = {}
    local n = table.getn(line)
    for i = 1, n do
      local j = max(1, i - span)
      local function Sum(e)
        local list = heal and e.h or e.d
        if name then return list[name] or 0 end
        local total = 0
        for _, v in pairs(list) do total = total + v end
        return total
      end
      local dt = line[i].t - line[j].t
      out[i] = dt > 0 and (Sum(line[i]) - Sum(line[j])) / dt or 0
    end
    return out
  end

  -- windows refresh at most 5 times a second
  local dirty
  function M.Changed() dirty = true end

  local f = CreateFrame("Frame", "pfMetersParser", UIParent)
  for _, event in pairs(EVENTS) do f:RegisterEvent(event) end
  f:RegisterEvent("PLAYER_REGEN_DISABLED")
  f:RegisterEvent("PLAYER_REGEN_ENABLED")
  -- SuperWoW's cast events: every cast of everyone near, with its target
  -- (the combat log misses many instant casts). Without SuperWoW the casts
  -- come from the log as before.
  local lc = pfUI.api and pfUI.api.libclient
  if (lc and lc.HasSuperWoW and lc.HasSuperWoW()) or SUPERWOW_VERSION then
    f:RegisterEvent("UNIT_CASTEVENT")
    M.castEvents = true
  end
  f:SetScript("OnEvent", function()
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
      this.check = 0
      return
    end
    if event == "UNIT_CASTEVENT" then
      if M.clog then return end   -- ClassicAPI's combat log has every cast
      M.CastEvent(arg1, arg2, arg3, arg4)
      return
    end
    -- (ClassicAPI's combat log events carry all of this, exactly: the text lines step aside)
    if M.clog then return end
    M.Record(M.Read(event, arg1))
  end)

  f:SetScript("OnUpdate", function()
    if (this.tick or 0) > GetTime() then return end
    this.tick = GetTime() + (tonumber(C.meters.refresh) or .1)
    -- once a second: everyone's damage and healing so far, for the charts
    -- (Details' "timed data for charts"); an hour at most
    if M.current and (this.sample or 0) <= GetTime() then
      this.sample = GetTime() + 1
      M.Sample(M.current)
    end
    -- the fight ends a second after the whole group left combat
    if (this.check or 0) <= GetTime() then
      this.check = GetTime() + 1
      if M.current and not GroupInCombat() and not M.forceCombat then M.EndFight() end
    end
    -- forget stale cast starts / dispel casts / last spells
    if (this.clean or 0) <= GetTime() then
      this.clean = GetTime() + 10
      local old = GetTime() - 10
      for k, t in pairs(pendingStart) do if t < old then pendingStart[k] = nil end end
      for k, p in pairs(pendingDispel) do if p.t < old then pendingDispel[k] = nil end end
      for k, p in pairs(lastSpell) do if p.t < old then lastSpell[k] = nil end end
      local older = GetTime() - 60
      for k, p in pairs(lastHit) do if p.t < older then lastHit[k] = nil end end
      for k, p in pairs(lastCaster) do if p.t < older then lastCaster[k] = nil end end
      for k, t in pairs(cdSeen) do if t < older then cdSeen[k] = nil end end
      for k, s in pairs(castSeen) do if s.t < older then castSeen[k] = nil end end
      -- (an aura whose fade was never seen, after 10 minutes)
      for unit, list in pairs(open) do
        for name, o in pairs(list) do
          if GetTime() - o.start > 600 then list[name] = nil end
        end
        if not next(list) then open[unit] = nil end
      end
    end
    if dirty then
      dirty = nil
      for _, fn in pairs(M.callbacks) do fn() end
    end
  end)
  M.frame = f
end)
