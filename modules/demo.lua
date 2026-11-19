pfUI:RegisterModule("demo", "vanilla", function ()
  -- pfUI Octo :: Demo mode (19 Nov 2026, phase 1 = the raid demo; user: "a full demo mode ... you can choose what kind
  -- of demo ... watch how it would be in a raid with your options running and edit stuff from here ... run full raid
  -- cycles until you quit it. boss fights everything").
  --
  -- The game cannot make raid members or bosses, so the demo makes a pretend world for pfUI only: while it runs,
  -- the unit questions pfUI's code asks (UnitName, UnitHealth, GetRaidRosterInfo, UnitDebuff ...) are answered in
  -- pfUI's own environment (pfUI.env, where every module and lib runs) from made-up data - a raid of 40 and a boss.
  -- pfUI's real frames draw that exactly as they would in a raid. The game itself and other add-ons see nothing;
  -- Stop puts every function back as it was. raid1 is you (the real player), as in a real raid.
  --
  -- A script loops: trash pull -> boss (abilities, debuffs to cure, a cast bar, raid warnings) -> kill or wipe ->
  -- rest (everyone up again) -> the next boss, until you stop it. The meter test fight and the combat text test
  -- join in. Nothing is saved: settings changed through Edit are real settings and stay.
  local DM = { on = false, kind = nil, speed = 1, paused = false, t = 0 }
  pfUI.demo = DM
  local function S() return C.demo or {} end

  -- ---------------------------------------------------------------- the raid
  DM.NAMES = { "Aldric", "Brenna", "Corvin", "Dalia", "Eamon", "Fenna", "Garrick", "Hilde", "Ivor", "Jessa", "Kael", "Lira",
    "Magnus", "Nessa", "Orin", "Pella", "Quill", "Rowan", "Sable", "Torvald", "Ulla", "Varek", "Wren", "Xander", "Yara",
    "Zorik", "Ansel", "Briar", "Cedric", "Delia", "Emrys", "Faye", "Gideon", "Hesper", "Isolde", "Joren", "Kestra", "Lucan",
    "Mirelle", "Nyx" }
  -- class, how many, role, health, power kind (0 mana, 1 rage, 3 energy), power
  DM.MAKEUP = {
    { "WARRIOR", 7, "dps", 5200, 1, 100 }, { "ROGUE", 5, "dps", 4300, 3, 100 }, { "MAGE", 5, "dps", 3900, 0, 6800 },
    { "WARLOCK", 4, "dps", 4400, 0, 6200 }, { "HUNTER", 4, "dps", 4600, 0, 5400 }, { "PRIEST", 6, "heal", 4000, 0, 7400 },
    { "DRUID", 4, "heal", 4500, 0, 6600 }, { "HYBRID", 4, "heal", 4900, 0, 6400 },
  }
  DM.LOCAL = { WARRIOR = "Warrior", ROGUE = "Rogue", MAGE = "Mage", WARLOCK = "Warlock", HUNTER = "Hunter", PRIEST = "Priest",
    DRUID = "Druid", PALADIN = "Paladin", SHAMAN = "Shaman" }
  -- buffs everyone has (the raid's usual ones)
  DM.BUFFS = { "Interface\\Icons\\Spell_Holy_WordFortitude", "Interface\\Icons\\Spell_Nature_Regeneration",
    "Interface\\Icons\\Spell_Holy_MagicalSentry" }

  local function Rand(a, b) return a + math.random() * (b - a) end
  local function Pick(list) return list[math.random(1, table.getn(list))] end

  function DM.MakeRaid()
    local faction = _G.UnitFactionGroup and _G.UnitFactionGroup("player")
    local hybrid = faction == "Horde" and "SHAMAN" or "PALADIN"
    local list = {}
    for _, m in ipairs(DM.MAKEUP) do
      for _ = 1, m[2] do table.insert(list, m) end
    end
    DM.units, DM.list = {}, {}
    local n = 1
    -- raid1 = you; 2..40 made up (the first two warriors tank)
    local tanks = 0
    for i = 2, 40 do
      local m = list[i - 1] or list[1]
      local class = m[1] == "HYBRID" and hybrid or m[1]
      local u = { token = "raid" .. i, name = DM.NAMES[i] or ("Raider" .. i), class = class, cl = DM.LOCAL[class] or class,
        role = m[3], max = math.floor(m[4] * Rand(.92, 1.1)), ptype = m[5], pmax = m[6], group = math.floor((i - 1) / 5) + 1,
        level = 60, player = true, debuffs = {}, buffs = DM.BUFFS }
      if class == "WARRIOR" and tanks < 2 then
        u.role, u.max, tanks = "tank", 9200 + tanks * 400, tanks + 1
        u.mark = tanks == 1 and 6 or 4
      end
      u.hp, u.pw = u.max, u.ptype == 1 and 0 or u.pmax
      DM.units[u.token] = u
      table.insert(DM.list, u)
      n = n + 1
    end
    DM.tank = DM.units.raid2
    DM.units.raid2.leader = true
  end

  -- ---------------------------------------------------------------- bosses
  -- every: seconds between uses; cast: cast time (nil = at once); what: raid | some | tank; n: how many it hits;
  -- dmg: { low, high }; debuff: { texture, type, seconds } (type = what can cure it); say: the raid warning
  local I = "Interface\\Icons\\"
  DM.BOSSES = {
    { name = "Flamescale Matriarch", ctype = "Dragonkin", level = -1, cls = "worldboss", max = 1450000, melee = { 1100, 1900 },
      abilities = {
        { name = "Fire Nova", icon = I .. "Spell_Fire_SealOfFire", every = 16, cast = 2.5, what = "raid", dmg = { 700, 1100 },
          say = "Flamescale Matriarch begins to cast Fire Nova!" },
        { name = "Searing Flames", icon = I .. "Spell_Fire_Immolation", every = 11, what = "some", n = 4, dmg = { 300, 500 },
          debuff = { I .. "Spell_Fire_Immolation", "Magic", 12 } },
        { name = "Wing Buffet", icon = I .. "INV_Misc_MonsterScales_05", every = 9, what = "tank", dmg = { 2200, 2800 } },
        { name = "Deep Breath", icon = I .. "Spell_Fire_Fire", every = 45, cast = 5, channel = true, what = "raid", dmg = { 1300, 1800 },
          say = "Flamescale Matriarch takes in a deep breath..." },
      } },
    { name = "Plaguefang", ctype = "Undead", level = -1, cls = "worldboss", max = 1250000, melee = { 1300, 2100 },
      abilities = {
        { name = "Poison Bolt Volley", icon = I .. "Spell_Nature_CorrosiveBreath", every = 12, cast = 2, what = "some", n = 9,
          dmg = { 400, 600 }, debuff = { I .. "Spell_Nature_CorrosiveBreath", "Poison", 10 } },
        { name = "Creeping Rot", icon = I .. "Spell_Shadow_CreepingPlague", every = 14, what = "some", n = 3, dmg = { 200, 300 },
          debuff = { I .. "Spell_Shadow_CreepingPlague", "Disease", 15 }, say = "Plaguefang spreads Creeping Rot - cure it!" },
        { name = "Mortal Wound", icon = I .. "Ability_CriticalStrike", every = 7, what = "tank", dmg = { 1600, 2200 },
          debuff = { I .. "Ability_CriticalStrike", "", 15 } },
      } },
    { name = "Lord Vexis", ctype = "Demon", level = -1, cls = "worldboss", max = 1350000, melee = { 1000, 1700 },
      abilities = {
        { name = "Shadow Bolt Volley", icon = I .. "Spell_Shadow_ShadowBolt", every = 10, cast = 2, what = "raid", dmg = { 500, 800 } },
        { name = "Curse of Agony", icon = I .. "Spell_Shadow_CurseOfSargeras", every = 13, what = "some", n = 5, dmg = { 250, 400 },
          debuff = { I .. "Spell_Shadow_CurseOfSargeras", "Curse", 18 }, say = "Lord Vexis curses the raid!" },
        { name = "Shadow Shock", icon = I .. "Spell_Shadow_ShadowWordPain", every = 8, what = "tank", dmg = { 1800, 2400 } },
      } },
  }
  DM.TRASH = { name = "Molten Guardian", ctype = "Elemental", level = 62, cls = "elite", max = 220000, melee = { 700, 1100 },
    abilities = { { name = "Lava Burst", icon = I .. "Spell_Fire_FlameBolt", every = 8, cast = 1.5, what = "some", n = 3, dmg = { 500, 900 } } } }

  -- the phases: trash (20 s), boss (until it dies or the raid does), kill / wipe (6 s), rest (12 s)
  DM.PHASES = { trash = 20, ended = 6, rest = 12 }

  local function NewMob(def)
    local b = { name = def.name, ctype = def.ctype, level = def.level, cls = def.cls, max = def.max, hp = def.max,
      def = def, enemy = true, mark = 8, debuffs = {}, buffs = {}, next = {} }
    for i, a in ipairs(def.abilities) do b.next[i] = Rand(3, a.every) end
    b.swing = 1.5
    return b
  end

  local function Warn(text)
    if S().warnings ~= "1" or not text then return end
    local rw = _G.RaidWarningFrame
    local i = _G.ChatTypeInfo and _G.ChatTypeInfo["RAID_WARNING"]
    if rw and rw.AddMessage then pcall(rw.AddMessage, rw, text, i and i.r or 1, i and i.g or .28, i and i.b or 0) end
    if _G.PlaySound then pcall(_G.PlaySound, "RaidWarning") end
  end
  DM.Warn = Warn

  -- ---------------------------------------------------------------- the pretend unit answers
  -- the data behind a unit token while the demo runs (nil = ask the game)
  local function Fake(u)
    if not DM.on or type(u) ~= "string" then return nil end
    u = string.lower(u)
    local d = DM.units[u]
    if d then return d end
    if u == "target" or u == "playertarget" then return S().target == "1" and DM.boss or nil end
    if u == "targettarget" then return S().target == "1" and DM.boss and DM.tank or nil end
    local _, _, n, rest = string.find(u, "^raid(%d+)(.*)$")
    if n then
      if rest == "target" then return DM.boss end
      return nil
    end
    _, _, n, rest = string.find(u, "^party(%d)(.*)$")
    if n then
      local m = DM.units["raid" .. (tonumber(n) + 1)]
      if rest == "" then return m end
      if rest == "target" then return DM.boss end
    end
    return nil
  end
  DM.Fake = Fake
  local function Is1(u) return type(u) == "string" and string.lower(u) == "raid1" end

  local ANS = {
    UnitExists = function(d) return 1 end,
    UnitName = function(d) return d.name end,
    UnitClass = function(d) if d.player then return d.cl, d.class end return "Warrior", "WARRIOR" end,
    UnitHealth = function(d) return math.max(0, math.floor(d.hp)) end,
    UnitHealthMax = function(d) return d.max end,
    UnitMana = function(d) return math.floor(d.pw or 0) end,
    UnitManaMax = function(d) return d.pmax or 0 end,
    UnitPowerType = function(d) return d.ptype or 0 end,
    UnitIsDead = function(d) return d.dead and 1 or nil end,
    UnitIsDeadOrGhost = function(d) return d.dead and 1 or nil end,
    UnitIsGhost = function(d) return nil end,
    UnitIsConnected = function(d) return 1 end,
    UnitIsPlayer = function(d) return d.player and 1 or nil end,
    UnitPlayerControlled = function(d) return d.player and 1 or nil end,
    UnitLevel = function(d) return d.level or 60 end,
    UnitClassification = function(d) return d.cls or "normal" end,
    UnitCreatureType = function(d) return d.ctype or (d.player and "Humanoid") end,
    UnitIsVisible = function(d) return 1 end,
    UnitInRaid = function(d) return d.player and 1 or nil end,
    UnitInParty = function(d) return d.player and 1 or nil end,
    UnitIsPartyLeader = function(d) return d.leader and 1 or nil end,
    UnitAffectingCombat = function(d) return DM.fight and 1 or nil end,
    UnitIsPVP = function(d) return nil end,
    UnitIsAFK = function(d) return nil end,
    UnitIsFeignDeath = function(d) return nil end,
    UnitIsCharmed = function(d) return nil end,
    UnitIsTapped = function(d) return nil end,
    UnitFactionGroup = function(d) if d.player then return _G.UnitFactionGroup("player") end end,
    GetRaidTargetIndex = function(d) return d.mark end,
    CheckInteractDistance = function(d) return 1 end,
    UnitDebuff = function(d, i)
      local e = d.debuffs[i]
      if e then return e.tex, e.count or 1, e.type ~= "" and e.type or nil end
    end,
    UnitBuff = function(d, i)
      local tex = d.buffs[i]
      if tex then return tex, 1 end
    end,
    UnitCastingInfo = function(d)
      local c = d.cast
      if c and not c.channel and GetTime() < c.finish then
        return c.name, "", c.name, c.icon, c.start * 1000, c.finish * 1000
      end
    end,
    UnitChannelInfo = function(d)
      local c = d.cast
      if c and c.channel and GetTime() < c.finish then
        return c.name, "", c.name, c.icon, c.start * 1000, c.finish * 1000
      end
    end,
  }
  DM.ANS = ANS

  -- two-unit questions: either side may be pretend
  local function Two(name)
    return function(a, b)
      local fa, fb = Fake(a), Fake(b)
      local orig = DM.orig[name]
      if not fa and not fb then return orig(a, b) end
      local pa = fa or (type(a) == "string" and (string.lower(a) == "player" or Is1(a)) and "me")
      local pb = fb or (type(b) == "string" and (string.lower(b) == "player" or Is1(b)) and "me")
      local enemyA = fa and fa.enemy
      local enemyB = fb and fb.enemy
      if name == "UnitIsUnit" then return (pa and pa == pb) and 1 or nil end
      local hostile = (enemyA and not enemyB) or (enemyB and not enemyA)
      if name == "UnitCanAttack" or name == "UnitIsEnemy" then return hostile and 1 or nil end
      if name == "UnitIsFriend" or name == "UnitCanAssist" then return (not hostile) and 1 or nil end
      if name == "UnitReaction" then return hostile and 2 or 5 end
    end
  end
  DM.TWO = { "UnitIsUnit", "UnitCanAttack", "UnitIsEnemy", "UnitIsFriend", "UnitCanAssist", "UnitReaction" }

  local ROSTER = {
    GetNumRaidMembers = function() return 40 end,
    GetNumPartyMembers = function() return 4 end,
    GetRaidRosterInfo = function(i)
      i = tonumber(i)
      if i == 1 then
        local _, class = _G.UnitClass("player")
        return _G.UnitName("player"), 1, 1, _G.UnitLevel("player"), (_G.UnitClass("player")), class, GetZoneText and GetZoneText(), 1, nil
      end
      local d = DM.units["raid" .. (i or 0)]
      if d then return d.name, d.leader and 2 or 0, d.group, d.level, d.cl, d.class, "Demo Raid", 1, d.dead and 1 or nil end
    end,
  }
  DM.ROSTER = ROSTER

  -- put the answers into pfUI's environment / take them out again (exactly what was there before)
  function DM.Install()
    local env = pfUI.env
    DM.saved, DM.orig = {}, {}
    local function Put(name, fn)
      DM.saved[name] = { rawget(env, name) }
      DM.orig[name] = rawget(env, name) or _G[name] or function() end
      rawset(env, name, fn)
    end
    for name, h in pairs(ANS) do
      local nm, hh = name, h
      Put(nm, function(u, a, b)
        local d = Fake(u)
        if d then return hh(d, a, b) end
        return DM.orig[nm](u, a, b)
      end)
    end
    for _, name in ipairs(DM.TWO) do Put(name, Two(name)) end
    for name, fn in pairs(ROSTER) do Put(name, fn) end
    -- "am I in a raid?" asked of the player
    rawset(env, "UnitInRaid", function(u)
      if type(u) == "string" and string.lower(u) == "player" then return 1 end
      local d = Fake(u)
      if d then return d.player and 1 or nil end
      return DM.orig.UnitInRaid(u)
    end)
  end
  function DM.Uninstall()
    local env = pfUI.env
    for name, was in pairs(DM.saved or {}) do rawset(env, name, was[1]) end
    DM.saved, DM.orig = nil, nil
  end

  -- ---------------------------------------------------------------- telling pfUI's frames
  local function Tok(f) return (f.label or "") .. (f.id or "") end
  -- every pfUI unit frame showing a pretend unit (or every frame, all = true) redraws
  function DM.Touch(all, aura)
    for _, f in pairs(pfUI.uf and pfUI.uf.frames or {}) do
      local tok = Tok(f)
      if all or Fake(tok) then
        if all then f.update_full = true elseif aura then f.update_aura = true else f.update_base = true end
      end
    end
  end
  function DM.Regroup()
    local uf = pfUI.uf
    if uf and uf.raid and uf.raid.Show then uf.raid:Show() end
    for _, f in pairs(uf and uf.frames or {}) do
      if uf.UpdateVisibility then pcall(uf.UpdateVisibility, f) end
      f.update_full = true
    end
  end

  -- ---------------------------------------------------------------- the fight
  local function Alive()
    local out = {}
    for _, u in ipairs(DM.list) do if not u.dead then table.insert(out, u) end end
    return out
  end
  local function Hurt(u, amount)
    if u.dead then return end
    u.hp = u.hp - amount
    if u.hp <= 0 then
      u.hp, u.dead, u.debuffs = 0, true, {}
      u.cast = nil
    end
    DM.dirty = true
  end
  local function AddDebuff(u, deb)
    if u.dead then return end
    for _, e in ipairs(u.debuffs) do
      if e.tex == deb[1] then
        e.left, e.count = deb[3], math.min(5, (e.count or 1) + 1)
        return
      end
    end
    if table.getn(u.debuffs) >= 8 then return end
    table.insert(u.debuffs, { tex = deb[1], type = deb[2], left = deb[3], count = 1,
      cure = deb[2] ~= "" and Rand(3, 7) or nil })
    DM.adirty = true
  end
  local function Use(b, a)
    local alive = Alive()
    if table.getn(alive) == 0 then return end
    local hits = {}
    if a.what == "raid" then hits = alive
    elseif a.what == "tank" then
      local tk = DM.tank
      if tk and tk.dead then tk = DM.units.raid3 end
      if tk and not tk.dead then hits = { tk } else hits = { Pick(alive) } end
    else
      for _ = 1, math.min(a.n or 1, table.getn(alive)) do table.insert(hits, Pick(alive)) end
    end
    for _, u in ipairs(hits) do
      Hurt(u, Rand(a.dmg[1], a.dmg[2]) * (u.role == "tank" and .8 or 1))
      if a.debuff then AddDebuff(u, a.debuff) end
    end
  end
  DM.Use = Use

  function DM.SetPhase(ph)
    DM.phase, DM.pt = ph, 0
    if ph == "trash" then
      DM.boss = NewMob(DM.TRASH)
      DM.fight = true
      Warn("Pull in 3... 2... 1...")
    elseif ph == "boss" then
      -- (after a wipe the same boss again, as a raid would)
      if not DM.retry then DM.bossIndex = math.mod(DM.bossIndex or 0, table.getn(DM.BOSSES)) + 1 end
      DM.retry, DM.trashDone = nil, nil
      DM.boss = NewMob(DM.BOSSES[DM.bossIndex])
      DM.fight = true
      DM.pulls = (DM.pulls or 0) + 1
      local every = tonumber(S().wipes) or 0
      DM.willWipe = every > 0 and math.mod(DM.pulls, every) == 0
      Warn(DM.boss.name .. " engaged!")
      DM.Joins(true)
    elseif ph == "ended" then
      DM.fight = false
      if DM.boss then DM.boss.cast = nil end
      if DM.wiped then DM.retry = true DM.trashDone = true Warn("Wipe! Run back and rebuff.") else Warn(DM.boss and (DM.boss.name .. " is defeated!") or nil) end
    elseif ph == "rest" then
      DM.fight = false
      DM.boss = nil
      for _, u in ipairs(DM.list) do
        u.dead, u.hp, u.debuffs, u.cast = nil, u.max, {}, nil
        if u.ptype ~= 1 then u.pw = u.pmax else u.pw = 0 end
      end
      DM.wiped = nil
    end
    DM.dirty, DM.adirty = true, true
    DM.Touch(true)
    if DM.onPhase then pcall(DM.onPhase, ph) end
  end

  -- one step of the pretend fight, dt seconds of demo time
  function DM.Step(dt)
    DM.t = DM.t + dt
    DM.pt = DM.pt + dt
    local ph = DM.phase
    if ph == "rest" then
      if DM.pt >= DM.PHASES.rest then DM.SetPhase(DM.trashDone and "boss" or "trash") end
      return
    end
    if ph == "ended" then
      if DM.pt >= DM.PHASES.ended then DM.SetPhase("rest") end
      return
    end
    local b = DM.boss
    if not b then return end
    -- the boss: melee on the tank, its abilities on their timers, its cast bar
    b.swing = b.swing - dt
    if b.swing <= 0 then
      b.swing = 2
      local tk = DM.tank
      if tk and tk.dead then tk = DM.units.raid3 end
      if tk then Hurt(tk, Rand(b.def.melee[1], b.def.melee[2])) end
    end
    if b.cast and GetTime() >= b.cast.finish then
      local a = b.cast.a
      b.cast = nil
      Use(b, a)
      DM.Touch(false)
    end
    for i, a in ipairs(b.def.abilities) do
      b.next[i] = b.next[i] - dt
      if b.next[i] <= 0 and not b.cast then
        b.next[i] = a.every * Rand(.85, 1.15)
        if a.cast then
          local now = GetTime()
          b.cast = { name = a.name, icon = a.icon, start = now, finish = now + a.cast / DM.speed, channel = a.channel, a = a }
        else
          Use(b, a)
        end
        if a.say then Warn(a.say) end
      end
    end
    -- the raid: healers heal the lowest, damage dealers drain the boss, mana goes down
    local alive = Alive()
    local healers, dps = 0, 0
    for _, u in ipairs(alive) do
      if u.role == "heal" then healers = healers + 1 elseif u.role == "dps" then dps = dps + 1 end
      if u.ptype == 1 then u.pw = math.min(100, (u.pw or 0) + dt * 6)
      elseif u.ptype == 3 then u.pw = math.max(0, math.min(100, (u.pw or 0) + dt * 10 - (math.random() < .3 and 20 or 0)))
      elseif u.role ~= "heal" then u.pw = math.max(0, (u.pw or 0) - dt * 25) end
    end
    DM.healAcc = (DM.healAcc or 0) + dt
    while DM.healAcc >= .5 do
      DM.healAcc = DM.healAcc - .5
      for _, h in ipairs(alive) do
        if h.role == "heal" and (h.pw or 0) > 200 and not (DM.willWipe and DM.pt > 40) then
          local low, worst = nil, 1
          for _, u in ipairs(alive) do
            local f = u.hp / u.max
            if not u.dead and f < worst then low, worst = u, f end
          end
          if low and worst < .95 then
            low.hp = math.min(low.max, low.hp + Rand(900, 1800))
            h.pw = h.pw - Rand(120, 260)
          end
        end
      end
    end
    -- cures: each curable debuff goes after a few seconds (as if someone dispelled it)
    for _, u in ipairs(alive) do
      local i = 1
      while u.debuffs[i] do
        local e = u.debuffs[i]
        e.left = e.left - dt
        if e.cure then e.cure = e.cure - dt end
        if e.left <= 0 or (e.cure and e.cure <= 0) then table.remove(u.debuffs, i) DM.adirty = true
        else
          if e.type ~= "" then Hurt(u, 40 * dt) end
          i = i + 1
        end
      end
    end
    -- a wipe: the raid goes down over a few seconds
    if DM.willWipe and DM.phase == "boss" and DM.pt > 40 then
      for _ = 1, 3 do
        local u = Pick(alive)
        if u then Hurt(u, u.max * .6) end
      end
    end
    b.hp = b.hp - dps * dt * Rand(.8, 1.2) * b.max / (ph == "trash" and 14 or 75) / 22
    if b.hp <= 0 then
      b.hp, b.dead = 0, true
      if ph == "trash" then DM.trashDone = true end
      DM.SetPhase("ended")
      return
    end
    if table.getn(Alive()) == 0 then
      DM.wiped = true
      DM.SetPhase("ended")
    end
  end

  -- the meter test fight and the combat text test while a boss is up
  function DM.Joins(on)
    local M = pfUI.meters
    if S().meters == "1" and M and M.TestMode then
      if on and not M.testOn then DM.metersMine = true pcall(M.TestMode, true)
      elseif not on and DM.metersMine then DM.metersMine = nil pcall(M.TestMode, false) end
    end
    -- (the combat text test's own clock, set straight: its TestMode prints a chat line on every call)
    local CT = pfUI.sct and pfUI.sct.CT
    if S().ctext == "1" and CT and CT.Testing then
      if on then DM.ctMine = true CT.testUntil = GetTime() + 3600
      elseif DM.ctMine then DM.ctMine = nil CT.testUntil = nil end
    end
  end

  -- ---------------------------------------------------------------- start / stop
  DM.KINDS = {
    { key = "raid", label = "Raid (40)", ready = true },
    { key = "dungeon", label = "Dungeon (5)" }, { key = "pvp", label = "PvP" }, { key = "afk", label = "AFK" },
    { key = "dummy", label = "Target dummy" }, { key = "showcase", label = "Showcase" },
  }
  function DM.Start(kind)
    kind = kind or "raid"
    if kind ~= "raid" then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r Demo: the " .. kind .. " demo comes in a later update. Starting the raid demo.")
      kind = "raid"
    end
    if _G.UnitAffectingCombat and _G.UnitAffectingCombat("player") then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r Demo: not while you are in a fight.")
      return false
    end
    if DM.on then DM.Stop(true) end
    math.randomseed(math.floor((GetTime() or 0) * 1000))
    DM.MakeRaid()
    DM.kind, DM.on, DM.paused, DM.t = kind, true, false, 0
    DM.speed = tonumber(S().speed) or 1
    DM.pulls, DM.bossIndex, DM.trashDone = 0, 0, nil
    DM.Install()
    DM.SetPhase("trash")
    DM.Regroup()
    DM.Joins(true)
    DM.bar:Show()
    DM.PaintBar()
    return true
  end
  function DM.Stop(quiet)
    if not DM.on then return end
    DM.Joins(false)
    DM.on, DM.boss, DM.fight = false, nil, false
    DM.Uninstall()
    DM.Regroup()
    DM.bar:Hide()
    if not quiet then DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r Demo stopped: everything is back as it was.") end
  end
  function DM.Next()
    if not DM.on then return end
    local ph = DM.phase
    if ph == "trash" or ph == "boss" then
      if DM.boss then DM.boss.hp = 0 end
      if ph == "trash" then DM.trashDone = true end
      DM.SetPhase("ended")
    elseif ph == "ended" then DM.SetPhase("rest")
    else DM.SetPhase(DM.trashDone and "boss" or "trash") end
    DM.PaintBar()
  end
  DM.SPEEDS = { .5, 1, 2, 4 }
  function DM.CycleSpeed()
    local nxt = DM.SPEEDS[1]
    for i, s in ipairs(DM.SPEEDS) do if s == DM.speed then nxt = DM.SPEEDS[i + 1] or DM.SPEEDS[1] end end
    DM.speed = nxt
    S().speed = tostring(nxt)
    DM.PaintBar()
  end

  -- ---------------------------------------------------------------- the bar at the top of the screen
  local bar = CreateFrame("Frame", "pfDemoBar", UIParent)
  DM.bar = bar
  bar:SetWidth(620)
  bar:SetHeight(34)
  bar:SetPoint("TOP", UIParent, "TOP", 0, -6)
  bar:SetFrameStrata("DIALOG")
  bar:EnableMouse(true)
  bar:Hide()
  if CreateBackdrop then CreateBackdrop(bar) end
  bar.title = bar:CreateFontString(nil, "OVERLAY")
  bar.title:SetFont(pfUI.font_default or STANDARD_TEXT_FONT, 12, "OUTLINE")
  bar.title:SetPoint("LEFT", bar, "LEFT", 10, 0)
  bar.title:SetJustifyH("LEFT")
  bar.buttons = {}
  local function Btn(label, w, fn, tip)
    local b = CreateFrame("Button", nil, bar)
    b:SetWidth(w)
    b:SetHeight(22)
    if CreateBackdrop then CreateBackdrop(b) end
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetFont(pfUI.font_default or STANDARD_TEXT_FONT, 11, "OUTLINE")
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.text:SetText(label)
    b:SetScript("OnClick", fn)
    b:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
      GameTooltip:AddLine(this.text:GetText())
      GameTooltip:AddLine(tip, 1, 1, 1, 1)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    table.insert(bar.buttons, b)
    return b
  end
  bar.stop = Btn("Stop", 52, function() DM.Stop() end, "Ends the demo; every frame goes back to what is really there.")
  bar.edit = Btn("Edit", 48, function()
    local O = pfUI.octoui and pfUI.octoui.Options
    if O and O.Open then O:Open("demo") elseif pfUI.gui then pfUI.gui:Show() end
  end, "Opens the options over the demo: change anything and watch it here at once.")
  bar.next = Btn("Next", 48, function() DM.Next() end, "Skips to the next part: trash -> boss -> kill -> rest.")
  bar.speedb = Btn("1x", 40, function() DM.CycleSpeed() end, "Demo speed: 0.5x, 1x, 2x, 4x.")
  bar.pause = Btn("Pause", 56, function() DM.paused = not DM.paused DM.PaintBar() end, "Holds the fight where it is.")
  local x = -6
  for _, b in ipairs(bar.buttons) do
    b:SetPoint("RIGHT", bar, "RIGHT", x, 0)
    x = x - b:GetWidth() - 4
  end
  local PHASENAME = { trash = "Trash", boss = "Boss", ended = "", rest = "Rest" }
  local function Clock(s) s = math.floor(s or 0) return math.floor(s / 60) .. ":" .. string.format("%02d", math.mod(s, 60)) end
  DM.Clock = Clock
  function DM.PaintBar()
    if not DM.on then return end
    local b = DM.boss
    local what = PHASENAME[DM.phase] or ""
    if DM.phase == "ended" then what = DM.wiped and "|cffff5544Wipe|r" or "|cff55ff66Kill|r" end
    local line = "|cff33ccffDEMO|r  Raid  |cff888888-|r  " .. what
    if b and (DM.phase == "boss" or DM.phase == "trash") then
      line = line .. ": |cffffffff" .. b.name .. "|r " .. math.floor(b.hp / b.max * 100 + .5) .. "%"
    end
    line = line .. "  |cff888888" .. Clock(DM.pt) .. "|r"
    bar.title:SetText(line)
    bar.pause.text:SetText(DM.paused and "Resume" or "Pause")
    bar.speedb.text:SetText((DM.speed == .5 and "0.5" or tostring(DM.speed)) .. "x")
  end

  -- ---------------------------------------------------------------- the clock
  local tick = CreateFrame("Frame")
  DM.ticker = tick
  local acc, paint = 0, 0
  tick:SetScript("OnUpdate", function()
    if not DM.on then return end
    local e = arg1 or 0
    acc, paint = acc + e, paint + e
    if paint >= .25 then paint = 0 DM.PaintBar() end
    if acc < .2 then return end
    local dt = acc
    acc = 0
    if DM.paused then return end
    DM.dirty, DM.adirty = false, false
    DM.Step(dt * DM.speed)
    if DM.adirty then DM.Touch(false, true) end
    if DM.dirty or DM.fight then DM.Touch(false) end
  end)
  tick:RegisterEvent("PLAYER_REGEN_DISABLED")
  tick:RegisterEvent("PLAYER_LOGOUT")
  tick:SetScript("OnEvent", function()
    if not DM.on then return end
    if event == "PLAYER_REGEN_DISABLED" then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r Demo stopped: you are in a real fight.")
    end
    DM.Stop(true)
  end)

  _G.SLASH_PFDEMO1 = "/demo"
  _G.SlashCmdList["PFDEMO"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "stop" or (msg == "" and DM.on) then DM.Stop()
    elseif msg == "next" then DM.Next()
    else DM.Start(msg ~= "" and msg or "raid") end
  end
end)
