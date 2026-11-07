pfUI:RegisterModule("meters-test", "vanilla:tbc", function ()
  -- pfUI Octo :: the meters' test mode (23 Oct 2026). User: "The meters
  -- section should have a full test mode with this you are able to click on
  -- test bars in the meter and look at the extra frames with information".
  -- A made-up 2 minute Onyxia fight is recorded through the meter's own
  -- engine (M.Record, the same as the combat log feeds), so every display
  -- and every breakdown tab has real numbers behind it: spells with hits,
  -- crits, ticks and misses, targets, damage taken by spell and source,
  -- healing and overhealing, friendly fire, interrupts, dispels, kills,
  -- a death with its log and a battle res, cooldowns, buff and debuff
  -- uptime, mana / rage / energy gained, and a chart.
  -- While test mode is on every window shows that fight (M.Segment answers
  -- with it); a real fight starting turns it off. The real fights are put
  -- aside while it is recorded and come back untouched.
  local M = pfUI.meters
  if not M or not M.Record or not M.Segment or not M.Reset then return end
  local TM = {}
  M.test = TM

  local BOSS, WHELP, WARDER = "Onyxia", "Onyxian Whelp", "Onyxian Warder"
  local LENGTH = 120
  local floor = math.floor
  local MELEE = T["Melee"]
  local MANA_, RAGE_, ENERGY_ = MANA or "Mana", RAGE or "Rage", ENERGY or "Energy"

  -- who is in the made-up group; each one's spells:
  -- { name, low, high, every n seconds, dot = ticks, heal = true }
  local ROSTER = {
    { "Garrosh", "WARRIOR", { { MELEE, 380, 560, 1 }, { "Bloodthirst", 650, 900, 6 }, { "Heroic Strike", 520, 720, 3 },
        { "Whirlwind", 400, 600, 10 } } },
    { "Valeera", "ROGUE", { { MELEE, 260, 420, 1 }, { "Sinister Strike", 380, 520, 2 }, { "Eviscerate", 1300, 1900, 9 } } },
    { "Rexxar", "HUNTER", { { "Auto Shot", 380, 520, 2 }, { "Aimed Shot", 1100, 1600, 7 }, { "Multi-Shot", 450, 650, 10 },
        { "Serpent Sting", 80, 110, 3, dot = true } } },
    { "Jaina", "MAGE", { { "Frostbolt", 700, 950, 2 }, { "Fire Blast", 520, 680, 8 }, { "Arcane Explosion", 260, 330, 12 } } },
    { "Gul'dan", "WARLOCK", { { "Shadow Bolt", 780, 1050, 3 }, { "Corruption", 140, 170, 3, dot = true },
        { "Curse of Agony", 90, 160, 2, dot = true } } },
    { "Thrall", "SHAMAN", { { "Lightning Bolt", 520, 700, 3 }, { "Chain Lightning", 480, 620, 6 }, { "Earth Shock", 450, 580, 6 },
        { "Chain Heal", 500, 750, 5, heal = true } } },
    { "Malfurion", "DRUID", { { "Moonfire", 180, 240, 6 }, { "Rejuvenation", 180, 230, 3, dot = true, heal = true },
        { "Regrowth", 900, 1200, 6, heal = true }, { "Healing Touch", 1600, 2200, 7, heal = true } } },
    { "Anduin", "PRIEST", { { "Smite", 300, 380, 14 }, { "Greater Heal", 1900, 2600, 3, heal = true },
        { "Flash Heal", 700, 950, 4, heal = true }, { "Renew", 160, 210, 3, dot = true, heal = true } } },
    { "Uther", "PALADIN", { { MELEE, 150, 260, 2 }, { "Holy Light", 1600, 2300, 3, heal = true },
        { "Flash of Light", 420, 560, 2, heal = true } } },
  }
  TM.ROSTER = ROSTER

  -- the same numbers every time (Park-Miller)
  local seed = 1
  local function Rand(a, b)
    seed = math.mod(seed * 16807, 2147483647)
    return a + math.mod(seed, b - a + 1)
  end
  local function Chance(pct) return Rand(1, 100) <= pct end

  local function Script(Rec, At)
    seed = 1
    local dead = {}
    local function Alive(name) return not dead[name] end
    local MISS = { "miss", "dodge", "parry", "resist" }
    local function Who(list) return list[Rand(1, table.getn(list))] end
    local everyone = {}
    for _, p in ipairs(ROSTER) do table.insert(everyone, p[1]) end
    local healed = { "Garrosh", "Garrosh", "Garrosh", "Valeera", "Rexxar", "Jaina", "Gul'dan", "Thrall" }

    -- auras that last the whole fight (closed at the end, so none stay open)
    At(0, function()
      for _, n in ipairs(everyone) do Rec({ kind = "aura", tgt = n, aura = "Power Word: Fortitude", up = true }) end
      for _, n in ipairs({ "Garrosh", "Valeera", "Uther" }) do Rec({ kind = "aura", tgt = n, aura = "Battle Shout", up = true }) end
    end)
    -- (Lua 5.0: a function made in a for loop shares the loop counter -
    -- every second would see the last one; each gets its own copy)
    for tt = 0, LENGTH - 1 do
      local t = tt
      local add = t >= 40 and t < 75   -- the whelps' phase
      local target = add and (math.mod(t, 3) == 0 and WARDER or WHELP) or BOSS
      At(t, function()
        -- the group's spells
        for _, p in ipairs(ROSTER) do
          local name = p[1]
          if Alive(name) then
            for i, s in ipairs(p[3]) do
              if math.mod(t + i, s[4]) == 0 then
                local amt = Rand(s[2], s[3])
                if s.heal then
                  local tgt = Who(healed)
                  local crit = not s.dot and Chance(14)
                  if crit then amt = floor(amt * 1.5) end
                  Rec({ kind = "heal", src = name, tgt = tgt, spl = s[1], amt = amt, crit = crit, dot = s.dot,
                        over = Chance(35) and floor(amt * Rand(10, 60) / 100) or nil })
                elseif not s.dot and Chance(6) then
                  Rec({ kind = "miss", src = name, tgt = target, spl = s[1] ~= MELEE and s[1] or nil, how = Who(MISS) })
                else
                  local crit = not s.dot and Chance(18)
                  if crit then amt = amt * 2 end
                  Rec({ kind = "dmg", src = name, tgt = target, spl = s[1] ~= MELEE and s[1] or nil, amt = amt, crit = crit,
                        dot = s.dot, glancing = s[1] == MELEE and not crit and Chance(10) or nil })
                end
              end
            end
          end
        end
        -- what hits the group
        if Chance(12) then
          Rec({ kind = "miss", src = BOSS, tgt = "Garrosh", how = Who({ "dodge", "parry", "miss" }) })
        else
          Rec({ kind = "dmg", src = BOSS, tgt = "Garrosh", amt = Rand(900, 1350), crit = Chance(5) })
        end
        if math.mod(t, 15) == 7 then
          for _, n in ipairs({ Who(everyone), Who(everyone) }) do
            if Alive(n) then Rec({ kind = "dmg", src = BOSS, tgt = n, spl = "Flame Breath", amt = Rand(1600, 2400) }) end
          end
        end
        -- (avoidable damage for the "Avoidable Damage Taken" display: people standing in the tail sweep)
        if math.mod(t, 18) == 5 then
          for _, n in ipairs({ Who(everyone), Who(everyone) }) do
            if Alive(n) then Rec({ kind = "dmg", src = BOSS, tgt = n, spl = "Tail Sweep", amt = Rand(500, 900) }) end
          end
        end
        if math.mod(t, 20) == 11 then Rec({ kind = "dmg", src = BOSS, tgt = "Garrosh", spl = "Wing Buffet", amt = Rand(700, 1000) }) end
        if add then
          local n = Who(everyone)
          if Alive(n) then Rec({ kind = "dmg", src = WHELP, tgt = n, amt = Rand(120, 260) }) end
          if math.mod(t, 5) == 0 then Rec({ kind = "death", tgt = WHELP }) end
        end
        if M.current then M.Sample(M.current) end
      end)
    end

    -- interrupts, dispels, cooldowns, friendly fire, a death and a battle res
    At(2, function() Rec({ kind = "cast", src = "Garrosh", spl = "Sunder Armor", tgt = BOSS })
      Rec({ kind = "aura", tgt = BOSS, aura = "Sunder Armor", up = true, harm = true }) end)
    At(3, function() Rec({ kind = "aura", tgt = BOSS, aura = "Curse of Agony", up = true, harm = true })
      Rec({ kind = "cast", src = "Malfurion", spl = "Faerie Fire", tgt = BOSS })
      Rec({ kind = "aura", tgt = BOSS, aura = "Faerie Fire", up = true, harm = true }) end)
    At(5, function() Rec({ kind = "cast", src = "Garrosh", spl = "Recklessness" })
      Rec({ kind = "power", tgt = "Garrosh", spl = "Bloodrage", amt = 20, pow = RAGE_ }) end)
    At(8, function() Rec({ kind = "cast", src = "Rexxar", spl = "Rapid Fire" }) end)
    At(10, function() Rec({ kind = "cast", src = "Jaina", spl = "Arcane Power" })
      Rec({ kind = "aura", tgt = "Jaina", aura = "Arcane Power", up = true }) end)
    At(12, function() Rec({ kind = "cast", src = "Valeera", spl = "Adrenaline Rush" }) end)
    At(25, function() Rec({ kind = "aura", tgt = "Jaina", aura = "Arcane Power" }) end)
    for tt = 4, LENGTH - 1, 4 do
      local t = tt
      At(t, function()
        Rec({ kind = "power", tgt = "Valeera", spl = "Relentless Strikes", amt = 25, pow = ENERGY_ })
        Rec({ kind = "power", tgt = "Garrosh", spl = "Unbridled Wrath", amt = Rand(2, 6), pow = RAGE_ })
        Rec({ kind = "power", tgt = "Thrall", src = "Thrall", spl = "Mana Spring Totem", amt = 40, pow = MANA_ })
      end)
    end
    At(22, function() Rec({ kind = "cast", src = "Jaina", spl = "Counterspell", tgt = WARDER })
      Rec({ kind = "interrupt", src = "Jaina", tgt = WARDER, spl = "Fire Nova" }) end)
    At(48, function() Rec({ kind = "cast", src = "Valeera", spl = "Kick", tgt = WARDER })
      Rec({ kind = "interrupt", src = "Valeera", tgt = WARDER, spl = "Fireball" }) end)
    At(61, function() Rec({ kind = "cast", src = "Garrosh", spl = "Pummel", tgt = WARDER })
      Rec({ kind = "interrupt", src = "Garrosh", tgt = WARDER, spl = "Fire Nova" }) end)
    At(44, function() Rec({ kind = "cast", src = "Anduin", spl = "Dispel Magic", tgt = "Jaina" })
      Rec({ kind = "dispel", tgt = "Jaina", aura = "Ignite Flesh" }) end)
    At(57, function() Rec({ kind = "cast", src = "Uther", spl = "Cleanse", tgt = "Valeera" })
      Rec({ kind = "dispel", tgt = "Valeera", aura = "Ignite Flesh" }) end)
    At(40, function() Rec({ kind = "cast", src = "Malfurion", spl = "Innervate", tgt = "Anduin" })
      Rec({ kind = "power", tgt = "Anduin", src = "Malfurion", spl = "Innervate", amt = 2400, pow = MANA_ }) end)
    At(52, function() Rec({ kind = "dmg", src = "Gul'dan", tgt = "Valeera", spl = "Hellfire Effect", amt = 210 })
      Rec({ kind = "dmg", src = "Gul'dan", tgt = "Garrosh", spl = "Hellfire Effect", amt = 190 }) end)
    At(84, function() Rec({ kind = "dmg", src = BOSS, tgt = "Rexxar", spl = "Flame Breath", amt = 2900 })
      Rec({ kind = "dmg", src = BOSS, tgt = "Rexxar", spl = "Fireball", amt = 3100, crit = true })
      Rec({ kind = "death", src = BOSS, tgt = "Rexxar" })
      dead.Rexxar = true end)
    At(92, function() Rec({ kind = "cast", src = "Malfurion", spl = "Rebirth", tgt = "Rexxar" })
      dead.Rexxar = nil end)
    At(95, function() Rec({ kind = "cast", src = "Garrosh", spl = "Shield Wall" })
      Rec({ kind = "aura", tgt = "Garrosh", aura = "Shield Wall", up = true }) end)
    At(105, function() Rec({ kind = "aura", tgt = "Garrosh", aura = "Shield Wall" }) end)
    -- every aura closed before the end
    At(LENGTH, function()
      for _, n in ipairs(everyone) do Rec({ kind = "aura", tgt = n, aura = "Power Word: Fortitude" }) end
      for _, n in ipairs({ "Garrosh", "Valeera", "Uther" }) do Rec({ kind = "aura", tgt = n, aura = "Battle Shout" }) end
      for _, a in ipairs({ "Sunder Armor", "Curse of Agony", "Faerie Fire" }) do Rec({ kind = "aura", tgt = BOSS, aura = a }) end
      Rec({ kind = "death", tgt = BOSS })
    end)
  end

  -- records the fight on a made-up clock, with the real fights put aside
  function TM.Build()
    local keep = { overall = M.overall, history = M.history, current = M.current, recent = M.recent, onStart = M.onStart,
                   force = M.forceCombat }
    local who = {}
    for _, p in ipairs(ROSTER) do
      who[p[1]] = M.who[p[1]]
      M.who[p[1]] = { checked = 1e12, kind = "PLAYER", class = p[2] }
    end
    local realTime = _G.GetTime
    local start = realTime() - LENGTH - 60
    local clock = start
    local events = {}
    local function At(t, fn) table.insert(events, { t = t, n = table.getn(events), fn = fn }) end
    local seg
    local ok, err = pcall(function()
      M.Reset()
      M.recent, M.onStart, M.forceCombat = {}, {}, true
      _G.GetTime = function() return clock end
      Script(M.Record, At)
      table.sort(events, function(a, b) if a.t ~= b.t then return a.t < b.t end return a.n < b.n end)
      for _, e in ipairs(events) do
        clock = start + e.t
        e.fn()
      end
      if M.current then
        M.current.boss = BOSS
        M.EndFight()
      end
      seg = M.history[1]
    end)
    _G.GetTime = realTime
    M.overall, M.history, M.current, M.recent, M.onStart, M.forceCombat =
      keep.overall, keep.history, keep.current, keep.recent, keep.onStart, keep.force
    for _, p in ipairs(ROSTER) do M.who[p[1]] = who[p[1]] end
    if not ok then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r: the test fight could not be made: " .. tostring(err))
      return
    end
    seg.name = BOSS .. " |cffffaa00(test)|r"
    seg.test = true
    M.testSeg = seg
    return seg
  end

  -- while testing, every window shows the test fight
  local segment = M.Segment
  M.Segment = function(key)
    if M.testSeg and M.Testing and M.Testing() then return M.testSeg end
    return segment(key)
  end

  -- test mode on / off (a real fight turns it off)
  function M.TestMode(on)
    if on == nil then on = not M.testOn end
    if on and not M.testSeg then TM.Build() end
    M.testOn = on and M.testSeg and true or nil
    if not M.testOn then M.testUntil = nil end
    for _, w in ipairs(M.windows or {}) do
      if M.testOn then w:Show() end
      if w.Refresh then w.Refresh(w) end
    end
    if not M.testOn and M.breakdown and M.breakdown.frame and M.breakdown.seg == M.testSeg then M.breakdown.frame:Hide() end
    M.Changed()
    return M.testOn
  end
  table.insert(M.onStart, function() if M.testOn then M.TestMode(false) end end)

  -- /pfmeter test
  _G.SLASH_PFMETERTEST1 = "/pfmetertest"
  _G.SlashCmdList.PFMETERTEST = function()
    local on = M.TestMode()
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r: meter test mode " .. (on and "|cff55ff55on|r - click any bar for its breakdown" or "off"))
  end
end)
