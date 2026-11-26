pfUI:RegisterModule("meters-window", "vanilla", function ()
  -- pfUI Octo meter windows, Details! style. Two windows by default, docked
  -- side by side in the right chat panel (the panel's toggle button swaps
  -- chat and meters): damage on the left, threat on the right. In each:
  --   click the title    -> pick what it shows (damage, DPS, healing, HPS,
  --                         overhealing, damage taken, interrupts, dispels,
  --                         deaths, casts, threat)
  --   click the segment  -> current fight, overall, or an earlier fight
  --   hover a bar        -> top spells; click a bar -> the full breakdown
  --   R / X              -> report to chat / reset all data
  -- Data: meters.lua (pfUI.meters) and meters-threat.lua (pfUI.meters.threat).
  if C.meters.enable ~= "1" or not pfUI.meters then return end

  local M = pfUI.meters
  local floor, max, min = math.floor, math.max, math.min
  local rawborder, border = GetBorderSize()

  -- ---------------------------------------------------------------- numbers

  -- 12345 as "12345" with commas: 12,345
  local function Commas(n)
    local s = tostring(floor(n + .5))
    local out = ""
    while string.len(s) > 3 do
      out = "," .. string.sub(s, -3) .. out
      s = string.sub(s, 1, -4)
    end
    return s .. out
  end

  local function Num(v)
    v = tonumber(v) or 0
    -- (Details' number formats: short 12.3k, with commas 12,345, or in full)
    local fmt = C.meters.numformat
    if fmt == "comma" and v >= 1000 then return Commas(v) end
    if fmt == "full" and v >= 100 then return tostring(floor(v + .5)) end
    if v >= 1000000 then return string.format("%.2fm", v / 1000000) end
    if v >= 10000 then return string.format("%.1fk", v / 1000) end
    if v >= 1000 then return string.format("%.2fk", v / 1000) end
    if v >= 100 then return tostring(floor(v + .5)) end
    if v ~= floor(v) then return string.format("%.1f", v) end
    return tostring(v)
  end
  M.Num = Num

  local function Clock(t)
    t = max(0, floor(t or 0))
    return string.format("%d:%02d", floor(t / 60), math.mod(t, 60))
  end

  -- the time per-second values divide by: the actor's own active time
  -- (Details' "activity"), or the whole fight ("effective")
  local timeSeg
  local function ActiveTime(a)
    if C.meters.timemeasure == "effective" and timeSeg then return M.Duration(timeSeg) end
    return max(1, a.active or 0)
  end
  M.ActiveTime = ActiveTime

  -- ---------------------------------------------------------------- per window
  -- (user, 22 Oct 2026, Details! as the model: "able to add windows and set
  -- them up, change the looks, everything") Up to six windows, each with its
  -- own settings in C.meters.winN; win.cfg is that number (the options'
  -- preview window borrows the one being edited).
  M.MAXWIN = 6
  local function S(win) return C.meters["win" .. ((win and (win.cfg or win.id)) or 1)] or C.meters.win1 end
  M.S = S

  -- the old shared settings, copied into windows 1 and 2 once
  if C.meters.migrated ~= "1" then
    for id = 1, 2 do
      local s = C.meters["win" .. id]
      s.mode = C.meters["mode" .. id] or s.mode
      s.segment = C.meters["segment" .. id] or s.segment
      s.width = C.meters["width" .. id] or C.meters.width or s.width
      s.height = C.meters["height" .. id] or C.meters.height or s.height
      s.lock = C.meters["lock" .. id] or s.lock
      s.barheight = C.meters.barheight or s.barheight
      s.texture = C.meters.texture or s.texture
      s.bg = C.meters.background or s.bg
      s.colorby = C.meters.classcolor == "0" and "fixed" or "class"
      s.rank = C.meters.showrank or s.rank
      s.showps = C.meters.showps or s.showps
      s.showpct = C.meters.showpct or s.showpct
    end
    C.meters.migrated = "1"
  end

  -- one-click looks: { key, label, settings }
  M.LOOKS = {
    { "octo", "Octo", { bg = "0.06,0.06,0.06,0.75", border = "pfui", titlebg = "0,0,0,0.45", titleaccent = "1",
      texture = "Interface\\AddOns\\pfUI\\img\\bar_elvui", spacing = "1", barbg = "1,1,1,0.05", baralpha = "0.85", icons = "class" } },
    { "minimal", "Minimal", { bg = "0,0,0,0.35", border = "none", titlebg = "0,0,0,0", titleaccent = "0", titlecolor = "0.9,0.9,0.9,1",
      texture = "Interface\\AddOns\\pfUI\\img\\plates\\bar-flat", spacing = "2", barbg = "0,0,0,0", baralpha = "0.7", icons = "none" } },
    { "elvui", "ElvUI", { bg = "0.1,0.1,0.1,0.9", border = "pfui", titlebg = "0.1,0.1,0.1,1", titleaccent = "1",
      texture = "Interface\\AddOns\\pfUI\\img\\bar_elvui", spacing = "1", barbg = "0,0,0,0.4", baralpha = "1", icons = "class" } },
    { "glass", "Glass", { bg = "0.04,0.05,0.08,0.5", border = "accent", titlebg = "0.2,0.3,0.5,0.35", titleaccent = "0",
      titlecolor = "1,1,1,1", texture = "Interface\\AddOns\\pfUI\\img\\plates\\bar-glass", spacing = "2", barbg = "1,1,1,0.06",
      baralpha = "0.8", icons = "class" } },
    { "classic", "Classic", { bg = "0.05,0.05,0.05,0.85", border = "gold", titlebg = "0.2,0.15,0.05,0.8", titleaccent = "0",
      titlecolor = "1,0.82,0,1", texture = "Interface\\TargetingFrame\\UI-StatusBar", spacing = "1", barbg = "0,0,0,0.5",
      baralpha = "1", icons = "class" } },
    { "neon", "Neon", { bg = "0,0,0,0.6", border = "glow", titlebg = "0,0,0,0.6", titleaccent = "1",
      texture = "Interface\\AddOns\\pfUI\\img\\bars\\bar-smooth", spacing = "3", barbg = "1,1,1,0.04", baralpha = "0.9", icons = "none" } },
  }
  function M.ApplyLook(win, key)
    local s = S(win)
    for _, l in ipairs(M.LOOKS) do
      if l[1] == key then
        for k, v in pairs(l[3]) do s[k] = v end
        s.look = key
      end
    end
  end
  function M.CurrentLook(win)
    local s = S(win)
    for _, l in ipairs(M.LOOKS) do
      local same = true
      for k, v in pairs(l[3]) do if s[k] ~= v then same = false end end
      if same then return l[1], l[2] end
    end
  end

  -- a window's look as text to share (Details' skin export): every setting
  -- but what it shows, which fight and its lock, as "OCTOMETER1:key=value|..."
  local NOTLOOK = { mode = true, segment = true, lock = true }
  function M.ExportLook(win)
    local s = S(win)
    local keys = {}
    for k in pairs(s) do if not NOTLOOK[k] then table.insert(keys, k) end end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do table.insert(parts, k .. "=" .. tostring(s[k])) end
    return "OCTOMETER1:" .. table.concat(parts, "|")
  end
  -- returns how many settings it took (0: not a look string)
  function M.ImportLook(win, text)
    if type(text) ~= "string" then return 0 end
    local _, _, body = string.find(text, "^%s*OCTOMETER1:(.*)$")
    if not body then return 0 end
    local s, n = S(win), 0
    for pair in string.gfind(body, "[^|]+") do
      local _, _, k, v = string.find(pair, "^([%w_]+)=(.*)$")
      -- only settings a window has (nothing else gets in)
      if k and not NOTLOOK[k] and s[k] ~= nil and v then
        s[k] = v
        n = n + 1
      end
    end
    return n
  end

  -- a made-up fight for the options' preview window
  local SAMPLE = {
    { "Thrall", "SHAMAN", 48210, 512, 2100, 3, 1, 4 }, { "Jaina", "MAGE", 45800, 0, 0, 2, 0, 0 },
    { "Valeera", "ROGUE", 41100, 0, 8600, 4, 0, 1 }, { "Rexxar", "HUNTER", 37950, 0, 1200, 1, 0, 0 },
    { "Garrosh", "WARRIOR", 33400, 0, 21400, 2, 0, 2 }, { "Gul'dan", "WARLOCK", 30120, 0, 3300, 0, 1, 0 },
    { "Malfurion", "DRUID", 12900, 38800, 2500, 0, 2, 0 }, { "Anduin", "PRIEST", 4100, 52600, 900, 0, 4, 0 },
    { "Uther", "PALADIN", 9800, 41200, 6100, 1, 3, 1 },
  }
  function M.SampleRows(modekey)
    local rows = {}
    -- (12 Nov 2026) threat as the real window shows it: the pull line, then threat and % of the tank's
    if modekey == "threat" then
      -- (20 Nov 2026, user: the preview showed lines the meter never did) the preview's made-up raid goes through the
      -- very same M.Rows as the live window: a server-shaped list, DoTs ticking for the warlock and the priest
      local TH = M.threat
      if TH and M.Rows then
        local me = UnitName("player") or "You"
        local _, myClass = UnitClass("player")
        local tank = 47080
        local list = {
          { name = "Garrosh", tank = true, threat = tank, perc = 100, melee = true },
          { name = "Gul'dan", tank = false, threat = 58600, perc = 124.5, melee = false },
          { name = "Valeera", tank = false, threat = 44900, perc = 95.4, melee = true },
          { name = "Thrall", tank = false, threat = 39800, perc = 84.5, melee = true },
          { name = me, tank = false, threat = 33500, perc = 71.2, melee = true },
          { name = "Jaina", tank = false, threat = 41200, perc = 87.5, melee = false },
          { name = "Anduin", tank = false, threat = 30100, perc = 63.9, melee = false },
          { name = "Rexxar", tank = false, threat = 27400, perc = 58.2, melee = false },
          { name = "Malfurion", tank = false, threat = 12600, perc = 26.8, melee = false },
        }
        local keep = { TH.list, TH.shown, TH.all, TH.allAt, TH.allFor, TH.demoPending, TH.demoPredict, TH.hist, TH.sampleClass }
        TH.list, TH.shown, TH.all, TH.allAt, TH.allFor, TH.demoPredict, TH.hist = list, {}, nil, nil, nil, nil, {}
        TH.sampleClass = { Garrosh = "WARRIOR", ["Gul'dan"] = "WARLOCK", Valeera = "ROGUE", Thrall = "SHAMAN", Jaina = "MAGE",
                           Anduin = "PRIEST", Rexxar = "HUNTER", Malfurion = "DRUID" }
        TH.sampleClass[me] = myClass or "WARRIOR"
        -- Gul'dan's DoTs take him past his pull point (61.2k at range) on the 3rd tick, in 7 s; Anduin's never do
        local DOTS = { ["Gul'dan"] = 1100, Anduin = 600 }
        TH.demoPending = function(name)
          local each = DOTS[name]
          if not each then return 0, {} end
          return each * 4, { { 1, each }, { 4, each }, { 7, each }, { 10, each } }
        end
        local keepOrder = M.threatOrder
        M.threatOrder = {}
        local good, out = pcall(M.Rows, "threat", "current")
        M.threatOrder = keepOrder or {}
        TH.list, TH.shown, TH.all, TH.allAt, TH.allFor, TH.demoPending, TH.demoPredict, TH.hist, TH.sampleClass =
          keep[1], keep[2], keep[3], keep[4], keep[5], keep[6], keep[7], keep[8] or {}, keep[9]
        if good and out then return out end
      end
      return rows
    end
    for _, p in ipairs(SAMPLE) do
      local v
      if modekey == "heal" or modekey == "hps" then v = p[4]
      elseif modekey == "taken" then v = p[5]
      elseif modekey == "interrupts" then v = p[6]
      elseif modekey == "dispels" then v = p[7]
      elseif modekey == "deaths" then v = p[8]
      elseif modekey == "threat" then v = p[3] / 500
      else v = p[3] end
      if modekey == "dps" or modekey == "hps" then v = v / 102 end
      if v > 0 then table.insert(rows, { name = p[1], class = p[2], value = v, extra = Num(v / 102) }) end
    end
    table.sort(rows, function(x, y) return x.value > y.value end)
    local total = 0
    for _, r in ipairs(rows) do total = total + r.value end
    for _, r in ipairs(rows) do
      r.max = rows[1].value
      r.text = Num(r.value)
      r.pct = total > 0 and r.value / total * 100 or 0
      if modekey == "threat" then r.text = floor(r.value) .. "%" end
    end
    return rows
  end

  -- ---------------------------------------------------------------- modes

  local function Power(a, pow) return (a.power and a.power[pow]) or 0 end

  -- the bosses of the fight being shown (timeSeg); the overall: every
  -- boss of the kept fights
  local function Bosses()
    local out = {}
    if timeSeg and timeSeg ~= M.overall then
      if timeSeg.boss then out[timeSeg.boss] = true end
    else
      for _, s in ipairs(M.history or {}) do if s.boss then out[s.boss] = true end end
      if M.current and M.current.boss then out[M.current.boss] = true end
    end
    return out
  end
  function M.BossDamage(a)
    local total = 0
    for name in pairs(Bosses()) do total = total + (a.targets[name] or 0) end
    return total
  end
  function M.BossTargets(a)
    local out = {}
    for name in pairs(Bosses()) do if a.targets[name] then out[name] = a.targets[name] end end
    return out
  end
  function M.OtherTargets(a)
    local bosses, out = Bosses(), {}
    for name, v in pairs(a.targets) do if not bosses[name] then out[name] = v end end
    return out
  end
  local MANA_, RAGE_, ENERGY_ = MANA or "Mana", RAGE or "Rage", ENERGY or "Energy"
  local function Secs(v) return Clock(v) end

  -- What a window can show, in Details' groups. value(a) for your group's
  -- players; rows(seg) for lists that are not players (enemies, spells);
  -- list(a) = the breakdown table for the tooltip (name -> amount).
  local MODES = {
    { key = "damage", group = "Damage", name = T["Damage Done"], value = function(a) return a.damage end,
      extra = function(a) return Num(a.damage / ActiveTime(a)) end, list = function(a) return a.spells, a.damage end },
    { key = "dps", group = "Damage", name = T["DPS"], value = function(a) return a.damage > 0 and a.damage / ActiveTime(a) or 0 end,
      extra = function(a) return Num(a.damage) end, list = function(a) return a.spells, a.damage end },
    -- damage on the boss only, and on everything else (adds, trash): the
    -- bosses are those of the fight shown (all fights' for the overall)
    { key = "bossdmg", group = "Damage", name = T["Boss Damage"], value = function(a) return M.BossDamage(a) end,
      extra = function(a) return Num(M.BossDamage(a) / ActiveTime(a)) end,
      plain = function(a) return M.BossTargets(a), M.BossDamage(a) end },
    { key = "noboss", group = "Damage", name = T["Damage Without Boss"], value = function(a) return a.damage - M.BossDamage(a) end,
      extra = function(a) return Num((a.damage - M.BossDamage(a)) / ActiveTime(a)) end,
      plain = function(a) return M.OtherTargets(a), a.damage - M.BossDamage(a) end },
    { key = "taken", group = "Damage", name = T["Damage Taken"], value = function(a) return a.taken end,
      list = function(a) return a.tspells, a.taken end },
    { key = "avoid", group = "Damage", name = T["Avoidable Damage Taken"], value = function(a) return a.avtotal or 0 end,
      list = function(a) return a.avspells, a.avtotal or 0 end },
    { key = "ff", group = "Damage", name = T["Friendly Fire"], value = function(a) return a.ff or 0 end,
      list = function(a) return a.ffspells, a.ff end },
    { key = "enemytaken", group = "Damage", name = T["Enemy Damage Taken"], rows = function(seg)
        local out = {}
        for name, f in pairs(seg.foes or {}) do
          if f.taken > 0 then table.insert(out, { name = name, value = f.taken, foe = f, tlist = f.from }) end
        end
        return out
      end },
    { key = "enemydone", group = "Damage", name = T["Enemy Damage Done"], rows = function(seg)
        local out = {}
        for name, f in pairs(seg.foes or {}) do
          if f.done > 0 then table.insert(out, { name = name, value = f.done, foe = f, tlist = f.to }) end
        end
        return out
      end },
    { key = "byspell", group = "Damage", name = T["Damage Taken By Spell"], rows = function(seg)
        local out = {}
        for name, b in pairs(seg.byspell or {}) do
          table.insert(out, { name = name, value = b.total, byspell = b, tlist = b.targets })
        end
        return out
      end },
    { key = "frags", group = "Damage", name = T["Frags"], value = function(a) return a.frags or 0 end },
    { key = "heal", group = "Healing", name = T["Healing Done"], value = function(a) return a.heal end,
      extra = function(a) return Num(a.heal / ActiveTime(a)) end, list = function(a) return a.hspells, a.heal end },
    { key = "hps", group = "Healing", name = T["HPS"], value = function(a) return a.heal > 0 and a.heal / ActiveTime(a) or 0 end,
      extra = function(a) return Num(a.heal) end, list = function(a) return a.hspells, a.heal end },
    { key = "overheal", group = "Healing", name = T["Overhealing"], value = function(a) return a.overheal end,
      extra = function(a)
        local all = a.heal + a.overheal
        return all > 0 and floor(a.overheal / all * 100) .. "%" or "0%"
      end, list = function(a) return a.hspells, a.heal end },
    { key = "htaken", group = "Healing", name = T["Healing Taken"], value = function(a) return a.htaken or 0 end,
      plain = function(a) return a.hsources, a.htaken end },
    { key = "mana", group = "Resources", name = T["Mana Restored"], value = function(a) return Power(a, MANA_) end,
      plain = function(a) return a.psources and a.psources[MANA_], Power(a, MANA_) end },
    { key = "rage", group = "Resources", name = T["Rage Generated"], value = function(a) return Power(a, RAGE_) end,
      plain = function(a) return a.psources and a.psources[RAGE_], Power(a, RAGE_) end },
    { key = "energy", group = "Resources", name = T["Energy Generated"], value = function(a) return Power(a, ENERGY_) end,
      plain = function(a) return a.psources and a.psources[ENERGY_], Power(a, ENERGY_) end },
    { key = "interrupts", group = "Misc", name = T["Interrupts"], value = function(a) return a.interrupts end },
    { key = "dispels", group = "Misc", name = T["Dispels"], value = function(a) return a.dispels end },
    { key = "deaths", group = "Misc", name = T["Deaths"], value = function(a) return a.deaths end },
    { key = "ress", group = "Misc", name = T["Resurrects"], value = function(a) return a.ress or 0 end },
    { key = "cooldowns", group = "Misc", name = T["Cooldowns"], value = function(a) return a.cds or 0 end },
    -- (25 Nov 2026, Lobo) how often each proc fired, and what set it off: "Engulfing Shadows <- Shadow Bolt"
    { key = "procs", group = "Misc", name = T["Procs"], value = function(a) return a.nprocs or 0 end,
      plain = function(a) return a.procs or {}, a.nprocs or 0 end },
    { key = "buffs", group = "Misc", name = T["Buff Uptime"], value = function(a) return a.buffsum or 0 end,
      text = Secs, plain = function(a) return a.buffs, a.buffsum end },
    { key = "debuffs", group = "Misc", name = T["Debuff Uptime"], value = function(a) return a.debuffsum or 0 end,
      text = Secs, plain = function(a) return a.debuffs, a.debuffsum end },
    { key = "casts", group = "Misc", name = T["Casts"], value = function(a) return a.ncasts end,
      plain = function(a) return a.casts, a.ncasts end },
    { key = "threat", group = "Misc", name = T["Threat"] },
  }
  M.GROUPS = { "Damage", "Healing", "Resources", "Misc", "Custom" }

  -- custom displays (Details' "custom" tab): C.meters.customN = { name, kind,
  -- spell }; shown in the menu once a spell is set
  M.CUSTOMKINDS = {
    { "dmgspell", "Damage of a spell" }, { "healspell", "Healing of a spell" }, { "casts", "Casts of a spell" },
    { "taken", "Damage taken from a spell" }, { "buff", "Uptime of a buff" }, { "debuff", "Uptime of a debuff" },
  }
  local function CustomValue(c, a)
    local spell = c.spell
    if c.kind == "healspell" then return a.hspells[spell] and a.hspells[spell].total or 0 end
    if c.kind == "casts" then return a.casts[spell] or 0 end
    if c.kind == "buff" then return a.buffs and a.buffs[spell] or 0 end
    if c.kind == "debuff" then return a.debuffs and a.debuffs[spell] or 0 end
    if c.kind == "taken" then
      -- (taken spells are kept as "spell - source")
      local total = 0
      local prefix = spell .. " - "
      for key, s in pairs(a.tspells) do
        if key == spell or string.sub(key, 1, string.len(prefix)) == prefix then total = total + s.total end
      end
      return total
    end
    return a.spells[spell] and a.spells[spell].total or 0
  end
  M.CustomValue = CustomValue
  for i = 1, 5 do
    local n = i
    local function Cfg() return C.meters["custom" .. n] end
    table.insert(MODES, { key = "custom" .. n, group = "Custom", custom = n,
      name = "Custom " .. n,
      value = function(a) return CustomValue(Cfg(), a) end,
      text = function(v)
        local k = Cfg().kind
        if k == "buff" or k == "debuff" then return Clock(v) end
        return Num(v)
      end,
      shown = function() return (Cfg().spell or "") ~= "" end })
  end
  -- a custom display's name follows its settings
  function M.CustomNames()
    for _, m in ipairs(MODES) do
      if m.custom then
        local c = C.meters["custom" .. m.custom]
        m.name = (c.name ~= "" and c.name) or (c.spell ~= "" and c.spell) or ("Custom " .. m.custom)
      end
    end
  end
  M.CustomNames()
  local MODE = {}
  for _, m in ipairs(MODES) do MODE[m.key] = m end
  M.MODES = MODES

  -- (15 Nov 2026, user: threat "jumping ... it should look stable") players close
  -- together kept swapping places every update. Start from the last order and
  -- only move someone up when they lead the one above by 3% of the top.
  M.threatOrder = {}
  function M.SteadyOrder(list, top)
    local rank = {}
    for i, name in ipairs(M.threatOrder) do rank[name] = i end
    local out = {}
    for _, e in ipairs(list) do table.insert(out, e) end
    table.sort(out, function(a, b)
      local ra, rb = rank[a.name] or 1000, rank[b.name] or 1000
      if ra ~= rb then return ra < rb end
      return a.perc > b.perc
    end)
    local n, margin = table.getn(out), (top or 100) * .03
    for pass = 1, n do
      local moved
      for i = 1, n - 1 do
        local b, a = out[i + 1], out[i]
        if b.perc > a.perc + margin or (b.perc >= 100 and b.perc > a.perc) then
          out[i], out[i + 1] = out[i + 1], out[i]
          moved = true
        end
      end
      if not moved then break end
    end
    M.threatOrder = {}
    for i, e in ipairs(out) do M.threatOrder[i] = e.name end
    return out
  end

  -- the rows a window shows: { name, value, class, text, actor }
  -- ClassicAPI's eased bars (C.meters.smooth): its Enum.StatusBarInterpolation, else nil
  function M.Eased()
    if C.meters.smooth == "0" then return end
    local E = rawget(_G, "Enum")
    local I = type(E) == "table" and E.StatusBarInterpolation
    if type(I) == "table" and I.ExponentialEaseOut then return I end
  end
  -- a player's class (the roster's, or the made-up preview raid's) and their name in its colour
  local function ClassOf(name, TH)
    local w = M.Who and M.Who(name)
    return (w and w.class) or (TH and TH.sampleClass and TH.sampleClass[name])
  end
  local function ClassName(name, TH)
    local c = ClassOf(name, TH)
    local cc = c and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c]
    if cc then return string.format("|cff%02x%02x%02x%s|r", floor(cc.r * 255), floor(cc.g * 255), floor(cc.b * 255), name) end
    return "|cffffffff" .. (name or "") .. "|r"
  end
  function M.Rows(modekey, segkey)
    local rows = {}
    local mode = MODE[modekey] or MODE.damage

    if mode.key == "threat" then
      local TH = M.threat
      if not TH or not TH.list then return rows end
      -- (20 Nov 2026, user: "when somebody overtakes the tank it would be the point the boss targets them. nothing
      -- ever goes above tank without this happening") A player's % is of THEIR pull point (110% of the tank's threat
      -- in melee range, 130% at range): 100% = the boss turns to them. The tank - whoever the boss is on - is the
      -- only one at 100; anyone else stops at 99 until the server moves the boss to them.
      local pctToPull = C.meters.tpullpct ~= "0"
      local function PullPct(e, perc)
        if e.tank then return 100 end
        local v = pctToPull and (perc / (e.melee and 110 or 130) * 100) or perc
        if v > 99 then v = 99 end
        return v
      end
      -- (bars glide: TH.shown holds the value on its way to e.perc)
      -- (with ClassicAPI's eased bars the client glides them: the real value)
      local eased = M.Eased()
      local function Shown(e) return PullPct(e, (not eased and TH.shown and TH.shown[e.name]) or e.perc) end
      local top = 100
      local me = UnitName("player")
      local tankE
      for _, e in ipairs(TH.list) do if e.tank then tankE = e end end
      local preds = TH.PredictAll and TH.PredictAll() or {}
      local pred = preds[me]
      local soonSec = TH.SoonSec and TH.SoonSec() or 8
      local function Soon(p) return p and p.aggroIn and p.aggroIn <= soonSec and p.aggroIn end
      -- (12 Nov 2026) the pull line first: where you take aggro and how far off it is (tank: your lead)
      local kind, a, b
      if TH.Pull then kind, a, b = TH.Pull() end
      if kind and C.meters.threatpull ~= "0" then
        if kind == "pull" then
          -- (17 Nov 2026) the bar fills with your threat towards the pull point
          local soon = pred and TH.SoonText and TH.SoonText(pred)
          local now = math.max(0, a - b)
          table.insert(rows, { name = T["You pull aggro at"], pullrow = kind, value = now, max = math.max(1, a),
                               extra = Num(a), text = (b >= 0 and "+" or "-") .. Num(math.abs(b)), gap = b, at = a,
                               label = soon and ("|cffb8b8b8" .. T["Pull in"] .. "|r  " .. math.max(0, math.ceil(pred.aggroIn)) .. " s"
                                 .. (pred.stopNow and ("  |cffb8b8b8" .. T["DoTs"] .. "|r") or "")) or nil,
                               ghost = pred and pred.pending > 0 and (now + pred.pending) or nil, stopNow = pred and pred.stopNow })
        else
          -- (20 Nov 2026) you hold aggro: how far ahead of the next one you are
          table.insert(rows, { name = T["You hold aggro"], pullrow = kind, value = top, max = top,
                               label = "|cffb8b8b8" .. T["You hold aggro"] .. "|r  " .. ClassName(b.name, TH),
                               extra = Num(math.abs(a)), text = "+" .. Num(math.abs(a)), gap = a })
        end
      end
      -- (20 Nov 2026, user: "where has the name of the person whos dots will take over next should be clear and visibile
      -- under or next to DoTs") ONE DoTs line for the whole group: whose DoTs take them closest to (or past) their pull
      -- point - you or anyone - by name in class colour, "in 4 s" when they pull within the countdown, and the threat
      -- their DoTs still add. Then the next one to pull at their pace (no DoTs), when that is someone else.
      local dotWho, dotP, dotE, dotShare
      for _, e in ipairs(TH.list) do
        local p = preds[e.name]
        if p and p.pending > 0 and not e.tank and tankE and tankE.threat > 0 then
          local at = tankE.threat * (e.melee and 1.1 or 1.3)
          local share = (e.threat + p.pending) / at
          local better
          if not dotP then better = true
          elseif p.stopNow and Soon(p) and not (dotP.stopNow and Soon(dotP)) then better = true
          elseif (p.stopNow and Soon(p)) and (dotP.stopNow and Soon(dotP)) then better = p.aggroIn < dotP.aggroIn
          elseif not (dotP.stopNow and Soon(dotP)) then better = share > dotShare end
          if better then dotWho, dotP, dotE, dotShare = e.name, p, e, share end
        end
      end
      if dotWho and C.meters.tdotrow ~= "0" then
        local at = tankE.threat * (dotE.melee and 1.1 or 1.3)
        local s = dotP.stopNow and Soon(dotP)
        table.insert(rows, { name = dotWho, pullrow = "dots", value = math.min(dotE.threat + dotP.pending, at), max = math.max(1, at),
                             label = "|cffb8b8b8" .. T["DoTs"] .. "|r  " .. ClassName(dotWho, TH)
                               .. (s and ("  |cffffffff" .. T["in"] .. " " .. math.max(0, math.ceil(dotP.aggroIn)) .. " s|r") or ""),
                             text = "+" .. Num(dotP.pending), gap = at - dotE.threat - dotP.pending, at = at, stopNow = s and true or nil })
      end
      if C.meters.tnextpull ~= "0" and TH.NextToPull then
        local who, p = TH.NextToPull()
        if who and who ~= me and not (who == dotWho and p.stopNow) then
          table.insert(rows, { name = who, pullrow = "next", value = 1, max = 1, gap = -1, at = 1,
                               label = "|cffb8b8b8" .. T["Next"] .. "|r  " .. ClassName(who, TH),
                               text = math.max(0, math.ceil(p.aggroIn)) .. " s" })
        end
      end
      -- (20 Nov 2026) small grey headings over the columns, above the first player
      if C.meters.theads ~= "0" then table.insert(rows, { name = "", pullrow = "head", value = 0, max = 1 }) end
      -- the order goes by the shown %: the one the boss is on first, always
      local order = {}
      for _, e in ipairs(TH.list) do table.insert(order, { name = e.name, perc = PullPct(e, e.perc), e = e }) end
      local n = 0
      for _, oe in ipairs(M.SteadyOrder(order, 100)) do
        local e = oe.e
        local w = { class = ClassOf(e.name, TH) }
        n = n + 1
        local p = preds[e.name]
        local v = Shown(e)
        local ghost
        if p and p.pending > 0 and tankE and tankE.threat > 0 then
          local add = p.pending / tankE.threat * 100
          if pctToPull then add = add / (e.melee and 110 or 130) * 100 end
          ghost = math.min(100, v + add)
        end
        local soon = Soon(p)
        local pct = floor(PullPct(e, e.perc)) .. "%"
        if e.tank then pct = T["Aggro"] end
        table.insert(rows, { name = e.name, value = v, max = top, class = w and w.class, rank = n,
                             text = pct, cd = soon and (math.ceil(soon) .. "s") or nil,
                             tps = TH.RateOf and TH.RateOf(e.name) and Num(TH.RateOf(e.name)) or "",
                             extra = Num(e.threat), tank = e.tank, ghost = ghost, stopNow = p and p.stopNow })
      end
      return rows
    end

    local seg = M.Segment(segkey)
    if not seg then return rows end
    timeSeg = seg
    if mode.rows then
      rows = mode.rows(seg)
    else
      for name, a in pairs(seg.actors) do
        local v = mode.value(a)
        if v and v > 0 then
          table.insert(rows, { name = name, value = v, class = a.class, actor = a,
                               extra = mode.extra and mode.extra(a) })
        end
      end
    end
    table.sort(rows, function(x, y) return x.value > y.value end)
    local total = 0
    for _, r in ipairs(rows) do total = total + r.value end
    for _, r in ipairs(rows) do
      r.max = rows[1].value
      r.text = mode.text and mode.text(r.value) or Num(r.value)
      r.pct = total > 0 and r.value / total * 100 or 0
    end
    return rows
  end

  local function SegmentName(key, win)
    if win and win.preview then return "|cff66ff661:42|r  Hogger" end
    if key == "overall" then return T["Overall"] end
    local seg = M.Segment(key)
    if not seg then return T["No fight yet"] end
    -- the time first, so a narrow window cuts the name, not the time
    local live = seg == M.current and "|cff66ff66" or "|cff888888"
    return live .. Clock(M.Duration(seg)) .. "|r  " .. (seg.name or T["Fight"])
  end

  -- ---------------------------------------------------------------- menu

  -- a small pfUI-style list under an anchor. items = { { text, func, ... } }:
  --   checked = true   the current choice (accent text)
  --   tick = true/false a tick box in front (an on/off setting)
  --   head = true      a grey section title, not clickable
  --   keep = true      the menu stays open after the click (redrawn by func)
  local menu = CreateFrame("Frame", "pfMeterMenu", UIParent)
  -- (21 Nov 2026, Wolfahrt: the breakdown's Report menu "is in background") the breakdown window is
  -- FULLSCREEN_DIALOG too and was drawn over it: the menu goes on the top layer
  menu:SetFrameStrata("TOOLTIP")
  menu:Hide()
  menu:EnableMouse(true)
  CreateBackdrop(menu, nil, true, .95)
  menu.buttons = {}
  menu:SetScript("OnUpdate", function()
    if not MouseIsOver(this) and not MouseIsOver(this.anchor) then
      this.away = (this.away or 0) + arg1
      if this.away > .6 then this:Hide() end
    else
      this.away = 0
    end
  end)

  local function ShowMenu(anchor, items)
    local width = 140
    for i, item in ipairs(items) do
      local b = menu.buttons[i]
      if not b then
        b = CreateFrame("Button", nil, menu)
        b:SetHeight(16)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontWhite")
        b.text:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
        b.text:SetPoint("LEFT", 8, 0)
        b.text:SetJustifyH("LEFT")
        b.hl = b:CreateTexture(nil, "BACKGROUND")
        b.hl:SetAllPoints()
        b.hl:SetTexture(1, 1, 1, .08)
        b.hl:Hide()
        b.box = b:CreateTexture(nil, "ARTWORK")
        b.box:SetWidth(9)
        b.box:SetHeight(9)
        b.box:SetPoint("LEFT", 8, 0)
        b.boxbg = b:CreateTexture(nil, "BORDER")
        b.boxbg:SetWidth(11)
        b.boxbg:SetHeight(11)
        b.boxbg:SetPoint("CENTER", b.box, "CENTER", 0, 0)
        b.boxbg:SetTexture(0, 0, 0, 1)
        b:SetScript("OnEnter", function() if not this.head then this.hl:Show() end end)
        b:SetScript("OnLeave", function() this.hl:Hide() end)
        b:SetScript("OnClick", function()
          if this.head then return end
          if not this.keep then menu:Hide() end
          if this.func then this.func() end
        end)
        menu.buttons[i] = b
      end
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2 - (i - 1) * 16)
      b:SetPoint("RIGHT", menu, "RIGHT", -2, 0)
      local ar, ag, ab = GetAccentColor()
      b.head, b.keep = item.head, item.keep
      b.text:ClearAllPoints()
      b.text:SetPoint("LEFT", (item.tick ~= nil) and 24 or 8, 0)
      if item.head then
        b.text:SetTextColor(.55, .55, .55, 1)
      elseif item.checked then
        b.text:SetTextColor(ar, ag, ab, 1)
      else
        b.text:SetTextColor(1, 1, 1, 1)
      end
      if item.tick ~= nil then
        b.boxbg:Show()
        b.box:Show()
        if item.tick then b.box:SetTexture(ar, ag, ab, 1) else b.box:SetTexture(.15, .15, .15, 1) end
      else
        b.boxbg:Hide()
        b.box:Hide()
      end
      b.text:SetText(item[1])
      b.func = item[2]
      b:Show()
      local w = b.text:GetStringWidth() + ((item.tick ~= nil) and 40 or 24)
      if w > width then width = w end
    end
    for i = table.getn(items) + 1, table.getn(menu.buttons) do menu.buttons[i]:Hide() end
    menu.anchor = anchor
    menu.away = 0
    local height = table.getn(items) * 16 + 4
    menu:SetWidth(width)
    menu:SetHeight(height)
    menu:ClearAllPoints()
    -- open upwards / leftwards when there is no room (the meters sit at the bottom right)
    local s = anchor:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local below = (anchor:GetBottom() or 500) * s
    local left = (anchor:GetLeft() or 0) * s
    local v = below < height + 10 and "BOTTOM" or "TOP"
    local h = left + width > GetScreenWidth() - 10 and "RIGHT" or "LEFT"
    menu:SetPoint(v .. h, anchor, (v == "TOP" and "BOTTOM" or "TOP") .. h, 0, v == "TOP" and -2 or 2)
    menu:Show()
  end
  M.ShowMenu = ShowMenu
  M.SegmentName = SegmentName
  M.Clock = Clock

  -- ---------------------------------------------------------------- report

  -- the report as lines of text: a title, then one per bar
  local function ReportLines(win)
    local rows = M.Rows(win.mode, win.segment)
    if table.getn(rows) == 0 then return end
    local mode = MODE[win.mode] or MODE.damage
    local title = "pfUI Octo - " .. mode.name
    if win.mode ~= "threat" then title = title .. " - " .. gsub(SegmentName(win.segment), "|c%x%x%x%x%x%x%x%x", "") end
    title = gsub(gsub(title, "|r", ""), "%*", "")
    local out = { title }
    -- (the threat window's pull line is yours alone: not in reports)
    if rows[1] and rows[1].pullrow then table.remove(rows, 1) end
    for i = 1, min(table.getn(rows), tonumber(C.meters.reportlines) or 10) do
      local r = rows[i]
      local line = i .. ". " .. r.name .. "  " .. r.text
      if r.extra then line = line .. " (" .. r.extra .. ")" end
      if r.pct then line = line .. "  " .. string.format("%.1f%%", r.pct) end
      table.insert(out, line)
    end
    return out
  end
  M.ReportLines = ReportLines

  local function Report(win, channel, whisper)
    local lines = ReportLines(win)
    if not lines then return end
    -- (ClassicAPI: the clipboard, as plain text, to paste anywhere - Discord, a forum)
    if channel == "CLIPBOARD" then
      local lc = pfUI.api and pfUI.api.libclient
      if lc and lc.Copy and lc.Copy(table.concat(lines, "\n"), true) then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI Octo|r: the report is on your clipboard - paste it with Ctrl+V.")
      end
      return
    end
    for _, line in ipairs(lines) do SendChatMessage(line, channel, nil, whisper) end
  end
  M.CanCopy = function() return _G.CopyToClipboard and true or false end

  local function ReportMenu(win, anchor)
    local items = {
      { T["Say"], function() Report(win, "SAY") end },
      { T["Party"], function() Report(win, "PARTY") end },
      { T["Raid"], function() Report(win, "RAID") end },
      { T["Guild"], function() Report(win, "GUILD") end },
      { T["Officer"], function() Report(win, "OFFICER") end },
    }
    if M.CanCopy() then table.insert(items, { "Copy to the clipboard", function() Report(win, "CLIPBOARD") end }) end
    if UnitIsPlayer("target") and UnitIsFriend("player", "target") then
      local name = UnitName("target")
      table.insert(items, { T["Whisper"] .. " " .. name, function() Report(win, "WHISPER", name) end })
    end
    ShowMenu(anchor, items)
  end

  -- ---------------------------------------------------------------- details

  local details = CreateFrame("Frame", "pfMeterDetails", UIParent)
  details:SetWidth(520)
  details:SetHeight(380)
  details:SetPoint("CENTER", 0, 60)
  details:SetFrameStrata("DIALOG")
  details:SetMovable(true)
  details:EnableMouse(true)
  details:RegisterForDrag("LeftButton")
  details:SetScript("OnDragStart", function() pfUI.api.DragStart(this) end)
  details:SetScript("OnDragStop", function() pfUI.api.DragStop(this) end)
  details:Hide()
  CreateBackdrop(details, nil, true, .92)
  CreateBackdropShadow(details)
  table.insert(UISpecialFrames, "pfMeterDetails")

  details.title = details:CreateFontString(nil, "OVERLAY", "GameFontWhite")
  details.title:SetFont(pfUI.font_default, C.global.font_size + 3, "OUTLINE")
  details.title:SetPoint("TOPLEFT", 10, -8)
  details.title:SetPoint("RIGHT", -30, 0)
  details.title:SetJustifyH("LEFT")

  details.close = CreateFrame("Button", nil, details)
  details.close:SetPoint("TOPRIGHT", -8, -8)
  details.close:SetWidth(12)
  details.close:SetHeight(12)
  details.close.texture = details.close:CreateTexture(nil, "OVERLAY")
  details.close.texture:SetTexture(pfUI.media["img:close"])
  details.close.texture:SetAllPoints()
  details.close.texture:SetVertexColor(1, .25, .25, 1)
  SkinButton(details.close, 1, .5, .5)
  details.close:SetScript("OnClick", function() details:Hide() end)

  details.scroll = CreateScrollFrame("pfMeterDetailsScroll", details)
  details.scroll:SetPoint("TOPLEFT", details, "TOPLEFT", 8, -30)
  details.scroll:SetPoint("BOTTOMRIGHT", details, "BOTTOMRIGHT", -8, 8)
  details.content = CreateScrollChild("pfMeterDetailsContent", details.scroll)
  details.content:SetWidth(490)
  details.lines = {}

  -- columns: x offset and width of each cell, first one left-aligned
  local COLS = { { 4, 170 }, { 178, 64 }, { 246, 46 }, { 296, 44 }, { 344, 46 }, { 394, 46 }, { 444, 44 } }

  local function Line(i)
    local l = details.lines[i]
    if l then return l end
    l = CreateFrame("Frame", nil, details.content)
    l:SetHeight(15)
    l:SetPoint("TOPLEFT", details.content, "TOPLEFT", 0, -(i - 1) * 15)
    l:SetPoint("RIGHT", details.content, "RIGHT", 0, 0)
    l.cells = {}
    for c, col in ipairs(COLS) do
      local s = l:CreateFontString(nil, "OVERLAY", "GameFontWhite")
      s:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
      s:SetPoint("LEFT", l, "LEFT", col[1], 0)
      s:SetWidth(col[2])
      s:SetJustifyH(c == 1 and "LEFT" or "RIGHT")
      l.cells[c] = s
    end
    l.wide = l:CreateFontString(nil, "OVERLAY", "GameFontWhite")
    l.wide:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
    l.wide:SetPoint("LEFT", l, "LEFT", 4, 0)
    l.wide:SetPoint("RIGHT", l, "RIGHT", -4, 0)
    l.wide:SetJustifyH("LEFT")
    details.lines[i] = l
    return l
  end

  -- rows: { cells = { ... } } or { wide = "text" }, color r,g,b
  local function FillDetails(title, rows)
    details.title:SetText(title)
    local ar, ag, ab = GetAccentColor()
    for i, row in ipairs(rows) do
      local l = Line(i)
      for c = 1, table.getn(COLS) do l.cells[c]:SetText(row.cells and row.cells[c] or "") end
      l.wide:SetText(row.wide or "")
      local r, g, b = 1, 1, 1
      if row.head then r, g, b = ar, ag, ab elseif row.color then r, g, b = row.color[1], row.color[2], row.color[3] end
      for c = 1, table.getn(COLS) do l.cells[c]:SetTextColor(r, g, b, 1) end
      l.wide:SetTextColor(r, g, b, 1)
      l:Show()
    end
    for i = table.getn(rows) + 1, table.getn(details.lines) do details.lines[i]:Hide() end
    details.content:SetHeight(max(1, table.getn(rows) * 15))
    details.scroll:SetVerticalScroll(0)
    details:Show()
  end

  local function Pct(part, all) return all > 0 and string.format("%.1f%%", part / all * 100) or "-" end

  local HOWS = { miss = T["miss"], dodge = T["dodge"], parry = T["parry"], block = T["block"], evade = T["evade"],
                 immune = T["immune"], absorb = T["absorbed"], resist = T["resisted"], reflect = T["reflected"],
                 glancing = T["glancing"], crushing = T["crushing"] }

  local function SpellRows(rows, list, total, heal)
    local sorted = {}
    for name, s in pairs(list) do table.insert(sorted, { name = name, s = s }) end
    table.sort(sorted, function(x, y) return x.s.total > y.s.total end)
    table.insert(rows, { head = true, cells = { T["Spell"], heal and T["Healed"] or T["Amount"], "%", T["Hits"], T["Crit"],
      heal and T["Over"] or T["Miss"], T["Max"] } })
    for _, e in ipairs(sorted) do
      local s = e.s
      local n = s.hits + s.ticks
      local fifth
      if heal then
        fifth = Pct(s.over, s.total + s.over)
      else
        fifth = (s.misses > 0) and Pct(s.misses, n + s.misses) or "-"
      end
      table.insert(rows, { cells = { e.name, Num(s.total), Pct(s.total, total), n, Pct(s.crits, max(1, n)), fifth, Num(s.max) } })
      -- how the misses went: 3 dodge, 1 parry...
      local hows = ""
      for how, count in pairs(s.how) do hows = hows .. count .. " " .. (HOWS[how] or how) .. "  " end
      if hows ~= "" then table.insert(rows, { wide = "      |cff888888" .. hows .. "|r" }) end
    end
  end

  local function TableRows(rows, title, list)
    local sorted, total = {}, 0
    for name, v in pairs(list) do table.insert(sorted, { name = name, v = v }) total = total + v end
    if table.getn(sorted) == 0 then return end
    table.sort(sorted, function(x, y) return x.v > y.v end)
    table.insert(rows, { wide = " " })
    table.insert(rows, { head = true, cells = { title, T["Amount"], "%" } })
    for _, e in ipairs(sorted) do
      table.insert(rows, { cells = { e.name, Num(e.v), Pct(e.v, total) } })
    end
  end

  function M.ShowDetails(win, row)
    local a = row.actor
    local seg = M.Segment(win.segment)
    local start = seg and seg.start or 0
    local mode = MODE[win.mode] or MODE.damage
    local rows = {}
    -- enemies and spells (not players)
    if row.foe or row.byspell then
      local title = row.name .. "  |cff888888" .. mode.name .. "  -  " .. SegmentName(win.segment) .. "|r"
      local f, b = row.foe, row.byspell
      if f and win.mode == "enemytaken" then
        table.insert(rows, { wide = T["Damage Taken"] .. ": " .. Num(f.taken) })
        TableRows(rows, T["Sources"], f.from)
        SpellRows(rows, f.tspells, f.taken)
      elseif f then
        table.insert(rows, { wide = T["Damage Done"] .. ": " .. Num(f.done) })
        SpellRows(rows, f.dspells, f.done)
        TableRows(rows, T["Targets"], f.to)
      elseif b then
        table.insert(rows, { wide = T["Damage"] .. ": " .. Num(b.total) .. "   " .. T["Hits"] .. ": " .. b.hits ..
          "   " .. T["Max"] .. ": " .. Num(b.max) })
        TableRows(rows, T["Targets"], b.targets)
        TableRows(rows, T["Sources"], b.from)
      end
      FillDetails(title, rows)
      return
    end
    if not a then return end
    local title = a.name .. "  |cff888888" .. mode.name .. "  -  " .. SegmentName(win.segment) .. "|r"
    local fight = seg and M.Duration(seg) or 1

    if win.mode == "damage" or win.mode == "dps" then
      table.insert(rows, { wide = T["Damage"] .. ": " .. Num(a.damage) .. "   " .. T["DPS"] .. ": " .. Num(a.damage / ActiveTime(a)) ..
        "   " .. T["Active"] .. ": " .. Clock(a.active) })
      SpellRows(rows, a.spells, a.damage)
      TableRows(rows, T["Targets"], a.targets)
    elseif win.mode == "heal" or win.mode == "hps" or win.mode == "overheal" then
      table.insert(rows, { wide = T["Healing"] .. ": " .. Num(a.heal) .. "   " .. T["Overhealing"] .. ": " .. Num(a.overheal) ..
        "   " .. T["HPS"] .. ": " .. Num(a.heal / ActiveTime(a)) })
      SpellRows(rows, a.hspells, a.heal, true)
      TableRows(rows, T["Healed"], a.htargets)
    elseif win.mode == "taken" then
      table.insert(rows, { wide = T["Damage Taken"] .. ": " .. Num(a.taken) })
      SpellRows(rows, a.tspells, a.taken)
      TableRows(rows, T["Sources"], a.sources)
      local av = ""
      for how, n in pairs(a.avoid) do av = av .. n .. " " .. (HOWS[how] or how) .. "   " end
      if av ~= "" then table.insert(rows, { wide = " " }) table.insert(rows, { wide = T["Avoided"] .. ": " .. av }) end
    elseif win.mode == "avoid" then
      local pct = a.taken > 0 and math.floor((a.avtotal or 0) / a.taken * 100 + .5) or 0
      table.insert(rows, { wide = T["Avoidable Damage Taken"] .. ": " .. Num(a.avtotal or 0) .. "   (" .. pct .. "% of all damage taken)" })
      SpellRows(rows, a.avspells, a.avtotal or 0)
    elseif win.mode == "interrupts" then
      table.insert(rows, { head = true, cells = { T["Interrupted"], T["Time"] } })
      for _, e in ipairs(a.ilist) do
        table.insert(rows, { wide = Clock(e.t - start) .. "   " .. (e.with and (e.with .. "  >  ") or "") ..
          (e.target or "?") .. ":  |cffffcc66" .. (e.spell or "?") .. "|r" })
      end
    elseif win.mode == "dispels" then
      for _, e in ipairs(a.dlist) do
        table.insert(rows, { wide = Clock(e.t - start) .. "   " .. (e.with or "") .. "  >  " .. (e.target or "?") ..
          ":  |cff66ccff" .. (e.aura or "?") .. "|r" })
      end
    elseif win.mode == "deaths" then
      for i, d in ipairs(a.deathlogs) do
        table.insert(rows, { head = true, wide = string.format(T["Death %d at %s"], i, Clock(d.t - start)) ..
          (d.killer and ("  -  " .. T["killed by"] .. " " .. d.killer) or "") })
        for _, e in ipairs(d.log) do
          local sign = e.kind == "heal" and "+" or "-"
          local hp = e.hp and e.hpmax and e.hpmax > 0 and ("  |cff888888" .. floor(e.hp / e.hpmax * 100) .. "%|r") or ""
          table.insert(rows, { color = e.kind == "heal" and { .4, 1, .4 } or { 1, .45, .45 },
            wide = string.format("%5.1fs  ", e.t - d.t) .. sign .. Num(e.amount) .. (e.crit and "*" or "") ..
              "   " .. (e.spell or "") .. "  " .. (e.who or "") .. hp })
        end
        table.insert(rows, { wide = " " })
      end
    elseif win.mode == "casts" then
      local sorted = {}
      for name, n in pairs(a.casts) do table.insert(sorted, { name = name, n = n }) end
      table.sort(sorted, function(x, y) return x.n > y.n end)
      table.insert(rows, { head = true, cells = { T["Spell"], T["Casts"], "%" } })
      for _, e in ipairs(sorted) do table.insert(rows, { cells = { e.name, e.n, Pct(e.n, a.ncasts) } }) end
    elseif win.mode == "ff" then
      table.insert(rows, { wide = T["Friendly Fire"] .. ": " .. Num(a.ff or 0) })
      SpellRows(rows, a.ffspells or {}, a.ff or 0)
      TableRows(rows, T["Targets"], a.fftargets or {})
    elseif win.mode == "htaken" then
      table.insert(rows, { wide = T["Healing Taken"] .. ": " .. Num(a.htaken or 0) })
      TableRows(rows, T["Healed by"], a.hsources or {})
    elseif win.mode == "mana" or win.mode == "rage" or win.mode == "energy" then
      local pow = (win.mode == "mana" and (MANA or "Mana")) or (win.mode == "rage" and (RAGE or "Rage")) or (ENERGY or "Energy")
      table.insert(rows, { wide = pow .. ": " .. Num(Power(a, pow)) })
      TableRows(rows, T["From"], a.psources and a.psources[pow] or {})
    elseif win.mode == "frags" then
      table.insert(rows, { head = true, cells = { T["Killed"], T["Time"] } })
      for _, e in ipairs(a.fraglist or {}) do table.insert(rows, { cells = { e.target or "?", Clock(e.t - start) } }) end
    elseif win.mode == "ress" or win.mode == "cooldowns" then
      local list = win.mode == "ress" and a.resslist or a.cdlist
      table.insert(rows, { head = true, cells = { T["Spell"], T["Time"] } })
      for _, e in ipairs(list or {}) do
        table.insert(rows, { wide = Clock(e.t - start) .. "   |cffffcc66" .. (e.spell or "?") .. "|r" ..
          (e.target and ("  >  " .. e.target) or "") })
      end
    elseif win.mode == "buffs" or win.mode == "debuffs" then
      local list = win.mode == "buffs" and a.buffs or a.debuffs
      local sorted = {}
      for name, v in pairs(list or {}) do table.insert(sorted, { name = name, v = v }) end
      table.sort(sorted, function(x, y) return x.v > y.v end)
      table.insert(rows, { head = true, cells = { win.mode == "buffs" and T["Buff"] or T["Debuff"], T["Time"], T["Uptime"] } })
      for _, e in ipairs(sorted) do
        table.insert(rows, { cells = { e.name, Clock(e.v), string.format("%.0f%%", min(100, e.v / fight * 100)) } })
      end
    end
    FillDetails(title, rows)
  end

  -- ---------------------------------------------------------------- windows

  local function Tooltip(bar)
    local row = bar.row
    if not row or C.meters.tooltip == "0" then return end
    GameTooltip:SetOwner(bar, "ANCHOR_LEFT")
    -- the threat window's pull line explains itself
    if row.pullrow then
      GameTooltip:AddLine(row.name, 1, .82, 0)
      if row.pullrow == "pull" then
        GameTooltip:AddLine(T["The mob turns on you at this threat: the tank's x 1.1 in melee range, x 1.3 at range."], 1, 1, 1, 1)
        GameTooltip:AddDoubleLine(T["Room left"], row.text or "", .6, .6, .6, 1, 1, 1)
      else
        GameTooltip:AddLine(T["You hold aggro: this is how far ahead of the next player you are."], 1, 1, 1, 1)
      end
      GameTooltip:AddLine(T["Meters > Threat: \"Pull aggro line\" turns it off."], .6, .6, .6, 1)
      GameTooltip:Show()
      return
    end
    -- (18 Nov 2026, user: "make our tooltip look like this with icons and the bar" - ClassicAPI's meter's spell
    -- window) the new hover panel, when it has spells / sources to draw; the plain tooltip stays for the rest
    if M.HoverPanel and M.HoverPanel(bar) then
      GameTooltip:Hide()
      return
    end
    GameTooltip:AddLine(row.name, 1, 1, 1)
    local a = row.actor
    local mode = MODE[bar.win.mode] or MODE.damage
    GameTooltip:AddDoubleLine(mode.name, row.text or "", .6, .6, .6, 1, 1, 1)
    -- the top entries: spells (with totals), or plain name -> amount lists
    local sorted, total = {}, 0
    if a and mode.list then
      local list
      list, total = mode.list(a)
      for name, s in pairs(list or {}) do table.insert(sorted, { name = name, v = s.total }) end
    elseif a and mode.plain then
      local list
      list, total = mode.plain(a)
      for name, v in pairs(list or {}) do table.insert(sorted, { name = name, v = v }) end
    elseif row.tlist then
      total = row.value
      for name, v in pairs(row.tlist) do table.insert(sorted, { name = name, v = v }) end
    end
    if a or row.foe or row.byspell then
      table.sort(sorted, function(x, y) return x.v > y.v end)
      for i = 1, min(tonumber(C.meters.tooltiplines) or 8, table.getn(sorted)) do
        local e = sorted[i]
        local v = mode.text and mode.text(e.v) or Num(e.v)
        GameTooltip:AddDoubleLine(e.name, v .. "  " .. Pct(e.v, total or 0), 1, 1, 1, .8, .8, .8)
      end
      GameTooltip:AddLine(T["Click for the full breakdown"], .5, .5, .5)
    elseif row.tank then
      GameTooltip:AddLine(T["Tanking"], 1, .3, .3)
    end
    GameTooltip:Show()
  end

  local function Bar(win, i)
    local b = win.bars[i]
    if b then return b end
    b = CreateFrame("Button", nil, win)
    b.win = win
    b:SetFrameLevel(win:GetFrameLevel() + 2)
    b.lift = 2
    b.bar = CreateFrame("StatusBar", nil, b)
    b.bar:SetAllPoints()
    b.bar:SetStatusBarTexture(S(win).texture)
    b.bar:SetMinMaxValues(0, 1)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetTexture(1, 1, 1, .05)
    -- (20 Nov 2026) threat on its way: a lighter part past the fill, as incoming heals on a health bar
    b.ghost = b:CreateTexture(nil, "BORDER")
    b.ghost:SetTexture("Interface\\Buttons\\WHITE8X8")
    b.ghost:Hide()
    -- the class icon at the left of the bar
    b.icon = b.bar:CreateTexture(nil, "OVERLAY")
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    -- the hover colour, a thin border round the bar, and your own bar's mark (25 Oct 2026)
    b.hov = b:CreateTexture(nil, "HIGHLIGHT")
    b.hov:SetAllPoints(b)
    b.hov:SetTexture("Interface\\Buttons\\WHITE8X8")
    b.hov:SetVertexColor(1, 1, 1, .12)
    b.rim = CreateFrame("Frame", nil, b)
    b.rim:SetAllPoints(b)
    b.rim:SetFrameLevel(b:GetFrameLevel() + 3)
    b.rim:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    b.rim:Hide()
    b.left = b.bar:CreateFontString(nil, "OVERLAY", "GameFontWhite")
    b.left:SetFont(pfUI.font_unit, C.global.font_unit_size, "OUTLINE")
    b.left:SetPoint("LEFT", 4, 0)
    b.left:SetJustifyH("LEFT")
    b.right = b.bar:CreateFontString(nil, "OVERLAY", "GameFontWhite")
    b.right:SetFont(pfUI.font_unit, C.global.font_unit_size, "OUTLINE")
    b.right:SetPoint("RIGHT", -4, 0)
    b.right:SetJustifyH("RIGHT")
    b.left:SetPoint("RIGHT", b.right, "LEFT", -6, 0)
    b:SetScript("OnEnter", function()
      if this.row and this.row.pullrow == "head" then return end
      if not this.win.preview then Tooltip(this) end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() if M.HoverHide then M.HoverHide() end end)
  b:SetScript("OnClick", function()
      if this.win.preview then
        if M.PreviewClick then M.PreviewClick(this.win, "bars") end
        return
      end
      if this.row and not this.row.pullrow then M.ShowDetails(this.win, this.row) end
    end)
    win.bars[i] = b
    return b
  end

  local function Col(s, fallback)
    local r, g, b, a = GetStringColor(s or fallback or "1,1,1,1")
    return tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(a) or 1
  end
  M.Col = Col

  -- the right text: total, per second and percent in the chosen order
  M.ORDERS = {
    { "tps", "Total (per second, percent)" }, { "tsp", "Total (percent, per second)" },
    { "pts", "Percent  total (per second)" }, { "t", "Total only" }, { "p", "Percent only" },
  }
  -- a colour setting as a |cffrrggbb code (the grey of the small numbers is a setting too)
  local function Hex(str, fallback)
    local r, g, b = Col(str, fallback)
    return string.format("|cff%02x%02x%02x", floor(r * 255 + .5), floor(g * 255 + .5), floor(b * 255 + .5))
  end
  M.Hex = Hex
  local function RightText(s, row)
    local total = row.text or ""
    local ps = (s.showps ~= "0" and row.extra) or nil
    local pct = (s.showpct ~= "0" and row.pct) and string.format("%.0f%%", row.pct) or nil
    local grey = Hex(s.subcolor, "0.67,0.67,0.67,1")
    local open, close = " " .. grey .. "(", ")|r"
    if s.brackets == "0" then open, close = "  " .. grey, "|r" end
    local order = s.order or "tps"
    if order == "t" then return total end
    if order == "p" then return pct or total end
    local list = {}
    if order == "tps" then
      if ps then table.insert(list, ps) end
      if pct then table.insert(list, pct) end
    elseif order == "tsp" then
      if pct then table.insert(list, pct) end
      if ps then table.insert(list, ps) end
    elseif order == "pts" then
      if ps then table.insert(list, ps) end
      local head = pct and (grey .. pct .. "|r  " .. total) or total
      if table.getn(list) > 0 then return head .. open .. table.concat(list, ", ") .. close end
      return head
    end
    if table.getn(list) > 0 then return total .. open .. table.concat(list, ", ") .. close end
    return total
  end
  M.RightText = RightText

  -- (12 Nov 2026, user: another threat meter "looks a bit neater") threat rows get the threat and the % in two
  -- columns of their own, right-aligned, so the numbers line up down the window (they shared one text). The pull
  -- line: the threat you pull at, then how far off it is - green with room, gold when close, red past it.
  -- the pull line's state colour: green with room (or holding aggro), gold within 10%, red past it
  -- (20 Nov 2026, user: "the red bars all merge in") each info line its own colour: your DoTs purple, the next to pull
  -- amber, the mob grey-green; the pull line green / gold / red by how close you are
  -- (20 Nov 2026, user: "the colours are abit shit on the threat meter the top can we not have options for this ... our
  -- look for the bars just with numbers that are CLEAR ... clear neat tidy") The top lines share one calm ground and one
  -- quiet fill (C.meters.tinfobg / tinfofill); what kind of line it is shows as a mark at its left edge and the colour
  -- of its number: the pull line green / gold / red by how close you are (tcolsafe / tcolnear / tcolover), your DoTs
  -- tcoldots, the next to pull tcolnext. Every one is an option (Meters > Threat window > Top lines).
  local function Cfg(key, fallback) return Col(C.meters[key], fallback) end
  function M.InfoColor(row)
    local k = row.pullrow or ""
    if k == "dots" then return Cfg("tcoldots", "0.72,0.56,1,1") end
    if k == "next" then return Cfg("tcolnext", "1,0.72,0.28,1") end
    if k == "mob" then return .85, .87, .9 end
    local gap = row.gap or 0
    if gap < 0 then return Cfg("tcolover", "1,0.29,0.23,1") end
    if k == "lead" or gap > (row.at or 0) * .1 then return Cfg("tcolsafe", "0.35,1,0.35,1") end
    return Cfg("tcolnear", "1,0.82,0.23,1")
  end
  M.PullColor = M.InfoColor
  -- (20 Nov 2026, user: "make ours neat and clear", after another threat meter's tidy columns - ideas only) The
  -- threat window's columns: name, then (when there is room) TPS and threat, then %, each a fixed width from the font
  -- size, right-aligned, so every number lines up down the window. One font size for names and numbers, never taller
  -- than the line. A narrow window drops TPS first, then threat, so a name always keeps NAMEMIN px.
  M.NAMEMIN = 60
  -- (20 Nov 2026, user: "this should be in all meters these changes not just threat") every window uses these columns:
  -- threat = TPS / threat / %, the others = per second / total / % (opts.tps, opts.mid say which it has at all)
  function M.ThreatCols(win, nsize, rightpad, iconw, opts)
    local bw = ((win and win:GetWidth()) or 200) - 4 - (rightpad or 0)
    local w = { pct = floor(nsize * 3.2), mid = floor(nsize * 3.8), tps = floor(nsize * 3), cd = floor(nsize * 2.2) }
    local need = 4 + (iconw or 0) + floor(nsize * 1.6) + M.NAMEMIN
    local use = { tps = C.meters.ttps == "1", mid = true }
    if opts then use.tps, use.mid = opts.tps and true or false, opts.mid ~= false end
    local function Room()
      return bw - need - w.pct - 4 - (use.mid and (w.mid + 4) or 0) - (use.tps and (w.tps + 4) or 0)
    end
    if Room() < 0 then use.tps = false end
    if Room() < 0 then use.mid = false end
    return use, w
  end
  local function ThreatColumns(b, s, row, vsize, font, outline, rightpad, iconw, opts)
    if not b.mid then
      b.mid = b.bar:CreateFontString(nil, "OVERLAY", "GameFontWhite")
      b.mid:SetJustifyH("RIGHT")
      b.pct = b.bar:CreateFontString(nil, "OVERLAY", "GameFontWhite")
      b.pct:SetJustifyH("RIGHT")
      -- (20 Nov 2026) a player's own seconds before they pull: a column of its own, so threat and % stay lined up
      b.cd = b.bar:CreateFontString(nil, "OVERLAY", "GameFontWhite")
      b.cd:SetJustifyH("RIGHT")
      b.tps = b.bar:CreateFontString(nil, "OVERLAY", "GameFontWhite")
      b.tps:SetJustifyH("RIGHT")
    end
    -- one size for the names and every number, outlined, never taller than the line
    local _, lsize = b.left:GetFont()
    local nsize = tonumber(lsize) or vsize
    local cap = floor((b:GetHeight() or 16) * .8)
    if cap >= 8 and nsize > cap then nsize = cap end
    local fflag = outline ~= "" and outline or "OUTLINE"
    b.left:SetFont(font, nsize, fflag)
    local head = row.pullrow == "head"
    for _, fs in ipairs({ b.mid, b.pct, b.cd, b.tps }) do
      fs:SetFont(font, head and math.max(7, nsize - 3) or nsize, fflag)
      if s.shadow == "1" then fs:SetShadowOffset(1, -1) fs:SetShadowColor(0, 0, 0, 1) else fs:SetShadowOffset(0, 0) end
      fs:SetHeight(nsize + 4)
    end
    local use, w = M.ThreatCols(b.win, nsize, rightpad, iconw, opts)
    b.pct:SetWidth(w.pct)
    b.mid:SetWidth(w.mid)
    b.cd:SetWidth(w.cd)
    b.tps:SetWidth(w.tps)
    b.pct:ClearAllPoints()
    b.pct:SetPoint("RIGHT", b, "RIGHT", -4 - (rightpad or 0), 0)
    local last = b.pct
    b.mid:ClearAllPoints()
    if use.mid then b.mid:SetPoint("RIGHT", last, "LEFT", -4, 0) last = b.mid end
    b.tps:ClearAllPoints()
    if use.tps then b.tps:SetPoint("RIGHT", last, "LEFT", -4, 0) last = b.tps end
    b.cd:ClearAllPoints()
    b.cd:SetPoint("RIGHT", last, "LEFT", -2, 0)
    if row.cd and not row.pullrow then
      b.cd:SetText(row.cd)
      b.cd:SetTextColor(Cfg("tcolover", "1,0.35,0.3,1"))
      b.cd:Show()
      b.left:SetPoint("RIGHT", b.cd, "LEFT", -2, 0)
    else
      b.cd:SetText("")
      b.cd:Hide()
      b.left:SetPoint("RIGHT", last, "LEFT", -4, 0)
    end
    b.right:SetText("")
    if use.mid then b.mid:Show() else b.mid:Hide() end
    if use.tps then b.tps:Show() b.tps:SetText(row.tps or "") b.tps:SetTextColor(Col(s.subcolor, "0.67,0.67,0.67,1")) else b.tps:Hide() end
    b.colsUsed = use
    -- the small grey headings over the columns
    if head then
      b.left:SetText("")
      local hl = opts and opts.heads
      b.tps:SetText(use.tps and (hl and hl[1] or T["TPS"]) or "")
      b.mid:SetText(hl and hl[2] or T["Threat"])
      b.pct:SetText(hl and hl[3] or "%")
      for _, fs in ipairs({ b.tps, b.mid, b.pct }) do fs:SetTextColor(.55, .57, .6) end
      b.pct:Show()
      return
    end
    local color = row.class and RAID_CLASS_COLORS[row.class]
    if s.valuecolor == "class" and color then b.mid:SetTextColor(color.r, color.g, color.b)
    elseif s.valuecolor == "custom" then b.mid:SetTextColor(Col(s.valuecustom, "1,1,1,1"))
    else b.mid:SetTextColor(1, 1, 1) end
    b.pct:SetTextColor(Col(s.subcolor, "0.67,0.67,0.67,1"))
    if row.pullrow then
      -- (15 Nov 2026, user: "you cant see the threat you pull aggro at") the name and the number share
      -- the left side, the gap gets the room of both right columns, so nothing is cut off
      b.left:SetPoint("RIGHT", b.pct, "LEFT", -4, 0)
      b.pct:SetWidth(floor(nsize * 5))
      b.mid:Hide()
      b.tps:Hide()
      -- (17 Nov 2026, user: "cleaner ... easier to see") a short grey label, the number in white, the
      -- room left in its state colour (the bar under it fills in the same colour, M.PullColor)
      -- (20 Nov 2026: the countdown in row.name never showed - this line wrote its own words over it) a line with its
      -- own words (the countdown, your DoTs, the next to pull) shows them
      if row.label then
        b.left:SetText(row.label)
      elseif row.pullrow == "pull" then
        b.left:SetText("|cffb8b8b8" .. T["Pull at"] .. "|r  " .. (row.extra or ""))
      else
        b.left:SetText("|cffb8b8b8" .. T["Lead on"] .. "|r  " .. (string.gsub(row.name, "^.- on ", "")))
      end
      row = { pullrow = row.pullrow, gap = row.gap, at = row.at, text = row.text ~= "" and row.text or ("+" .. (row.extra or "")), extra = "" }
      b.left:SetTextColor(1, 1, 1)
      b.pct:SetTextColor(M.InfoColor(row))
      b.pct:SetWidth(floor(nsize * 5))
      -- (20 Nov 2026, user: "its all off the meter cant read it") the words get smaller (to 8 px) until they fit
      local lf, ls, lo = b.left:GetFont()
      local room = math.max(b:GetWidth() or 0, ((b.win and b.win:GetWidth()) or 0) - 4) - floor(nsize * 5) - 14
      ls = tonumber(ls)
      if lf and ls and room > 30 then
        while ls > 8 and (b.left:GetStringWidth() or 0) > room do
          ls = ls - 1
          b.left:SetFont(lf, ls, lo)
        end
      end
    end
    b.mid:SetText(row.extra or "")
    b.pct:SetText(row.text or "")
    b.pct:Show()
  end

  -- the look of a window from its settings: background, border, title bar,
  -- buttons, fonts (bars are drawn in Refresh)
  local function ApplyStyle(win)
    local s = S(win)
    if win.backdrop then
      win.backdrop:SetBackdropColor(Col(s.bg))
      local border = s.border or "pfui"
      local r, g, b, a = Col(s.bordercolor, "0,0,0,1")
      if border == "none" then a = 0
      elseif border == "gold" then r, g, b, a = .85, .68, .3, 1
      elseif border == "accent" or border == "glow" then r, g, b = GetAccentColor() a = 1 end
      win.backdrop:SetBackdropBorderColor(r, g, b, a)
      -- a soft glow round the window
      if border == "glow" then
        win.glow = win.glow or CreateFrame("Frame", nil, win)
        win.glow:SetPoint("TOPLEFT", win, "TOPLEFT", -6, 6)
        win.glow:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", 6, -6)
        win.glow:SetBackdrop({ edgeFile = pfUI.media["img:glow"], edgeSize = 8 })
        win.glow:SetBackdropBorderColor(r, g, b, .7)
        win.glow:Show()
      elseif win.glow then
        win.glow:Hide()
      end
    end
    local th = tonumber(s.titleheight) or 18
    local titled = s.title ~= "0"
    win.head:SetHeight(th)
    win.head:SetTexture(Col(s.titlebg, "0,0,0,0.45"))
    local tsize = tonumber(s.titlesize) or C.global.font_size
    local tfont = (s.titlefont and s.titlefont ~= "") and s.titlefont or pfUI.font_default
    win.title:SetFont(tfont, tsize, "OUTLINE")
    win.seg:SetFont(tfont, max(6, tsize - 1), "OUTLINE")
    win.segFont, win.segSize = tfont, max(6, tsize - 1)
    if s.titleaccent == "1" then
      local ar, ag, ab = GetAccentColor()
      win.title:SetTextColor(ar, ag, ab, 1)
    else
      win.title:SetTextColor(Col(s.titlecolor))
    end
    for _, part in ipairs({ win.head, win.titlebtn, win.segbtn }) do
      if titled then part:Show() else part:Hide() end
    end
    if s.showseg == "0" then win.segbtn:Hide() end
    win.titlebtn:ClearAllPoints()
    win.titlebtn:SetPoint("TOPLEFT", 2, -(th - 16) / 2 - 1)
    -- buttons from the right: reset, report, menu (as many as are on)
    local x = -2
    for _, e in ipairs({ { win.reset, "btnreset" }, { win.report, "btnreport" }, { win.menu, "btnmenu" }, { win.lockbtn, "btnlock" } }) do
      local btn = e[1]
      btn:ClearAllPoints()
      if titled and s[e[2]] ~= "0" then
        btn:SetPoint("TOPRIGHT", win, "TOPRIGHT", x, -(th - 16) / 2 - 1)
        btn:Show()
        x = x - 17
      else
        btn:Hide()
      end
    end
    win.segbtn:ClearAllPoints()
    win.segbtn:SetPoint("LEFT", win.titlebtn, "RIGHT", 2, 0)
    win.segbtn:SetPoint("RIGHT", win, "TOPRIGHT", x - 2, -th / 2)
    if win.status then
      if s.status == "1" then win.status:Show() else win.status:Hide() end
      win.status.bg:SetTexture(Col(s.titlebg, "0,0,0,0.45"))
    end
    win:SetAlpha(tonumber(s.alpha) or 1)
    M.PaintLock(win)
  end
  M.ApplyStyle = ApplyStyle

  -- the displays used last (newest first, six), for the title's right-click
  function M.Recent()
    local out = {}
    for key in string.gfind(C.meters.recent or "", "[^,]+") do table.insert(out, key) end
    if table.getn(out) == 0 then out = { "damage", "heal", "taken", "interrupts", "deaths", "threat" } end
    return out
  end
  function M.SetMode(win, key)
    -- (20 Nov 2026, user: "one of the meters hard locked to threat") a threat window stays on threat
    if key ~= "threat" and S(win).threatlock == "1" then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfUI Octo|r This is your threat window - it stays on threat (Meters > Threat to unlock it).")
      return
    end
    win.mode = key
    S(win).mode = key
    win.offset = 0
    local list = { key }
    for _, k in ipairs(M.Recent()) do
      if k ~= key and table.getn(list) < 6 then table.insert(list, k) end
    end
    C.meters.recent = table.concat(list, ",")
    win.Refresh(win)
  end

  -- test bars: every window shows the made-up fight for a while, to try
  -- looks on the real windows (Details' "create test bars"); meters-test.lua
  -- turns this into a whole test fight with breakdowns behind every bar
  function M.TestBars(seconds)
    M.testUntil = GetTime() + (seconds or 30)
    for _, w in ipairs(M.windows or {}) do w:Show() w.Refresh(w) end
  end
  function M.Testing()
    return M.testOn or (M.testUntil or 0) > GetTime()
  end

  -- a free window dropped near another one sits flush against it, in line
  -- (9 Nov 2026, user: windows snapped "slightly overlayed ... it should be
  -- smart and snap in line"). Edges are the OUTER ones (the frame's border
  -- is drawn outside it), so borders touch instead of overlapping; then the
  -- nearest edge pair is lined up (left / right when stacked, top / bottom
  -- side by side) from up to M.SNAPALIGN px away. The closest window wins.
  -- (9 Nov 2026, seen in game: still overlapping. The window is dragged by hand
  -- (pfUI.api.DragStart sets BOTTOMLEFT x, y each frame) and the client reports a
  -- moved frame's edges late, so GetLeft at the drop was where it had been BEFORE
  -- the drag. Edges now come from the window's own point when it has one on
  -- UIParent, the size and the backdrop's offset - never from edges read back -
  -- all in UIParent units (a window may have its own scale).)
  M.SNAPNEAR, M.SNAPALIGN = 20, 48
  local function Border(f)
    local b = f.backdrop
    if not b or not b.GetPoint then return 0 end
    local _, _, _, x = b:GetPoint(1)
    x = tonumber(x) or 0
    return x < 0 and -x or 0
  end
  local function Scale(f)
    local us = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local s = f.GetEffectiveScale and f:GetEffectiveScale() or us
    if not s or not us or us == 0 then return 1 end
    return s / us
  end
  -- the frame's own left / bottom in its own units
  local function Corner(f)
    local w, h = f:GetWidth() or 0, f:GetHeight() or 0
    if (f.GetNumPoints and f:GetNumPoints() or 1) == 1 then
      local p, rel, rp, x, y = f:GetPoint(1)
      if (rel == nil or rel == UIParent) and rp == "BOTTOMLEFT" and x and y then
        if p == "BOTTOMLEFT" then return x, y, w, h end
        if p == "TOPLEFT" then return x, y - h, w, h end
      end
    end
    return f:GetLeft(), f:GetBottom(), w, h
  end
  local function Outer(f)
    local l, b, w, h = Corner(f)
    if not l or not b then return end
    local k, e = Scale(f), Border(f)
    return (l - e) * k, (b + h + e) * k, (l + w + e) * k, (b - e) * k
  end
  M.Outer = Outer
  -- the smaller of two moves that line edges up, when within reach
  local function Align(a, b)
    local best
    for _, d in ipairs({ a, b }) do
      if math.abs(d) <= M.SNAPALIGN and (not best or math.abs(d) < math.abs(best)) then best = d end
    end
    return best or 0
  end
  function M.SnapMove(win)
    local L, T, R, B = Outer(win)
    if not (L and T and R and B) then return 0, 0 end
    local near = M.SNAPNEAR
    local best, bdx, bdy
    for _, o in ipairs(M.windows or {}) do
      if o ~= win and o:IsShown() and Outer(o) then
        local ol, ot, orr, ob = Outer(o)
        local overlapY = B < ot + near and T > ob - near
        local overlapX = L < orr + near and R > ol - near
        local cands = {}
        if overlapX then
          -- under it / on top of it, the left or right edges lined up
          table.insert(cands, { ob - T, Align(ol - L, orr - R), true })
          table.insert(cands, { ot - B, Align(ol - L, orr - R), true })
        end
        if overlapY then
          -- right of it / left of it, the tops or bottoms lined up
          table.insert(cands, { orr - L, Align(ot - T, ob - B), false })
          table.insert(cands, { ol - R, Align(ot - T, ob - B), false })
        end
        for _, c in ipairs(cands) do
          local d = math.abs(c[1])
          if d <= near and (not best or d < best) then
            best = d
            if c[3] then bdx, bdy = c[2], c[1] else bdx, bdy = c[1], c[2] end
          end
        end
      end
    end
    return bdx or 0, bdy or 0
  end
  function M.Snap(win)
    local L, B, _, H = Corner(win)
    if not (L and B) then return end
    local dx, dy = M.SnapMove(win)
    if dx == 0 and dy == 0 then return false end
    local k = Scale(win)
    win:ClearAllPoints()
    win:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", L + dx / k, B + H + dy / k)
    M.Pin(win)
    return true
  end

  -- (21 Nov 2026, Javelin: windows placed side by side and locked "keep breaking their positions") a window is
  -- always saved by its TOP-LEFT corner against the screen's top-left. It was saved by whatever point the move left
  -- (a drag: bottom-left; a snap: TOPLEFT on the screen's BOTTOMLEFT, which LoadMovable reloads on the screen's
  -- TOPLEFT - above the screen; layout mode: the screen third's point), so a window fitting its lines grew or shrank
  -- from the wrong edge and side-by-side windows came apart. Worked out from the point itself, not from GetLeft /
  -- GetTop, so it also works before the client has placed the window.
  -- how far up the window its point is (BOTTOM* 0, TOP* its height, else half)
  local function Along(p, size)
    if string.find(p, "BOTTOM") then return 0 end
    if string.find(p, "TOP") then return size end
    return size / 2
  end
  -- the window's left and top (its own units, from the screen's bottom-left), or nil when it hangs on another frame
  function M.TopLeft(win)
    if not win or not win.GetPoint or (win.GetNumPoints and win:GetNumPoints() > 1) then return end
    local a, rel, rp, x, y = win:GetPoint(1)
    if not a then return end
    -- (22 Nov 2026, user: the threat meter "keeps jumping to the top left of my screen when i resize it") after
    -- StartSizing / StartMoving the client hands the point back as (point, nil, relativePoint, x, y): no frame means
    -- the screen. This used to be read as the SetPoint(point, x, y) form, which took x from the nil and y from the
    -- point's name - both 0 - and pinned the window to the screen's top-left corner.
    if type(rel) == "number" then rel, rp, x, y = UIParent, a, rel, rp -- SetPoint(point, x, y)
    elseif rel == nil then rel = UIParent end
    if type(rel) == "string" then rel = _G[rel] end
    if rel == nil then return end
    if rel ~= UIParent then return end
    local f = 1 / ((win.GetScale and win:GetScale()) or 1)
    local SW, SH = GetScreenWidth() * f, GetScreenHeight() * f
    local w, h = win:GetWidth() or 0, win:GetHeight() or 0
    rp = rp or a
    local px = (string.find(rp, "LEFT") and 0) or (string.find(rp, "RIGHT") and SW) or SW / 2
    local py = (string.find(rp, "BOTTOM") and 0) or (string.find(rp, "TOP") and SH) or SH / 2
    local left = px + (tonumber(x) or 0) - (string.find(a, "LEFT") and 0 or string.find(a, "RIGHT") and w or w / 2)
    local top = py + (tonumber(y) or 0) + (h - Along(a, h))
    return left, top, SH
  end
  -- put it there by its top-left corner and save that; left / top as M.TopLeft gives them (default: where it is)
  function M.PinAt(win, left, top)
    if not win or not win.free then return end
    local pos = C.position and C.position[win:GetName()]
    if pos and pos.attach then return end -- locked onto another frame in layout mode: that stays
    local _, _, SH = M.TopLeft(win)
    if not SH then
      local f = 1 / ((win.GetScale and win:GetScale()) or 1)
      SH = GetScreenHeight() * f
    end
    if not (left and top) then return end
    local x, y = round(left), round(top - SH)
    win:ClearAllPoints()
    win:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
    SaveMovable(win)
    return x, y
  end
  -- an older snap's save (TOPLEFT measured from the screen's bottom) measured from the top, as LoadMovable reads it
  function M.FixOldSnap(win, saved)
    if saved and saved.xpos and not saved.attach and (saved.anchor or "TOPLEFT") == "TOPLEFT" and (tonumber(saved.ypos) or 0) > 0 then
      local f = 1 / ((tonumber(saved.scale) or (win and win:GetScale()) or 1))
      saved.ypos = round(saved.ypos - GetScreenHeight() * f)
      return true
    end
  end
  function M.Pin(win)
    local left, top = M.TopLeft(win)
    if left then return M.PinAt(win, left, top) end
    if win and win.free then SaveMovable(win) end
  end

  -- (11 Nov 2026, Wolfahrt: "a way to move 2 windows together") windows snapped flush
  -- against each other are a group: dragging one moves the others with it (Alt = alone)
  -- (19 Nov 2026, user: "my meters are snapping together and when i move them it is dragging them all") moving
  -- together is off by default now; everyone who had the old default is switched off once. Meters > Data has it.
  if C.meters.snapgroupreset ~= "1" then
    C.meters.snapgroupreset = "1"
    C.meters.snapgroup = "0"
  end
  -- (22 Nov 2026, user: the threat window "stays this size even if i drag it ... it should let me drag it to what ever
  -- size i want it and stay there") fitting the lines shrank every window back to its lines the moment the grip was let
  -- go (one line with no fight). Off for everyone once; the size you drag is the size. Meters > Data still has it.
  if C.meters.tfitoff ~= "1" then
    C.meters.tfitoff = "1"
    C.meters.tfit = "0"
    -- a size saved while it was fitted (a line or two) comes back at the usual size, to drag from there
    for i = 1, 6 do
      local s = C.meters["win" .. i]
      if type(s) == "table" and tonumber(s.height) and tonumber(s.height) < 100 then s.height = "160" end
    end
  end
  local TOUCH = 2
  function M.Touching(a, b)
    local la, ta, ra, ba = Outer(a)
    local lb, tb, rb, bb = Outer(b)
    if not (la and lb) then return false end
    local overlapX = la < rb - TOUCH and ra > lb + TOUCH
    local overlapY = ba < tb - TOUCH and ta > bb + TOUCH
    if overlapY and (math.abs(ra - lb) <= TOUCH or math.abs(rb - la) <= TOUCH) then return true end
    if overlapX and (math.abs(ba - tb) <= TOUCH or math.abs(bb - ta) <= TOUCH) then return true end
    return false
  end
  -- every shown free window joined to win through touching edges (not win itself)
  function M.Group(win)
    local seen, out, todo = { [win] = true }, {}, { win }
    while table.getn(todo) > 0 do
      local w = table.remove(todo)
      for _, o in ipairs(M.windows or {}) do
        if not seen[o] and o:IsShown() and o.free and M.Touching(w, o) then
          seen[o] = true
          table.insert(out, o)
          table.insert(todo, o)
        end
      end
    end
    return out
  end
  -- note where the group sits from win (UIParent units), to follow it while it moves
  function M.GroupStart(win)
    win.followers = nil
    if C.meters.snapgroup == "0" or (IsAltKeyDown and IsAltKeyDown()) then return end
    local l, b = Corner(win)
    if not l then return end
    local k = Scale(win)
    local list = {}
    for _, o in ipairs(M.Group(win)) do
      local ol, ob = Corner(o)
      if ol then
        local ko = Scale(o)
        table.insert(list, { o, ol * ko - l * k, ob * ko - b * k })
      end
    end
    if table.getn(list) > 0 then win.followers = list end
  end
  function M.GroupFollow(win, save)
    if not win.followers then return end
    local k = Scale(win)
    local l, b = win:GetLeft(), win:GetBottom()
    if not (l and b) then return end
    for _, f in ipairs(win.followers) do
      local o, dx, dy = f[1], f[2], f[3]
      local ko = Scale(o)
      o:ClearAllPoints()
      o:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", (l * k + dx) / ko, (b * k + dy) / ko)
      if save then M.Pin(o) end
    end
    if save then win.followers = nil end
  end

  -- what a status bar slot shows
  M.SLOTS = {
    { "none", "Nothing" }, { "time", "Fight time" }, { "mine", "Your value and rank" }, { "segment", "Fight name" },
    { "clock", "Clock" }, { "fps", "Frames per second" }, { "ping", "Latency" },
  }
  local function Slot(win, kind)
    if kind == "time" then
      if win.preview then return "1:42" end
      local seg = M.Segment(win.segment)
      return seg and Clock(M.Duration(seg)) or "0:00"
    elseif kind == "mine" then
      local me = UnitName("player")
      local n = 0
      for i, r in ipairs(win.rowsShown or {}) do
        if not r.pullrow then n = n + 1 end
        if not r.pullrow and (r.name == me or (win.preview and i == 2)) then return "#" .. n .. "  " .. (r.text or "") end
      end
      return "-"
    elseif kind == "segment" then
      local seg = win.preview and "Hogger" or SegmentName(win.segment)
      return gsub(gsub(seg, "|c%x%x%x%x%x%x%x%x", ""), "|r", "")
    elseif kind == "clock" then
      return date("%H:%M")
    elseif kind == "fps" then
      return floor(GetFramerate() or 0) .. " fps"
    elseif kind == "ping" then
      local _, _, lag = GetNetStats()
      return (lag or 0) .. " ms"
    end
    return ""
  end
  function M.StatusText(win)
    local st = win.status
    if not st or not st:IsShown() then return end
    local s = S(win)
    st.slots[1]:SetText(Slot(win, s.statusleft))
    st.slots[2]:SetText(Slot(win, s.statusmid))
    st.slots[3]:SetText(Slot(win, s.statusright))
  end

  local function Refresh(win)
    if not win:IsShown() then return end
    local s = S(win)
    if win.styled ~= s then ApplyStyle(win) win.styled = s end
    local mode = MODE[win.mode] or MODE.damage
    if mode.custom then M.CustomNames() end
    win.title:SetText(mode.name)
    win.titlebtn:SetWidth(win.title:GetStringWidth() + 10)
    -- (20 Nov 2026, user: the target's name "is always like this not showing the full ... it should be clear and all
    -- there") the name beside the title is never cut: it gets smaller (to 8 px) until it fits; still too long, the
    -- threat window shows it in full on a line of its own at the top instead
    local mobLine
    local function FitSeg(text)
      local size = win.segSize or 11
      win.seg:SetFont(win.segFont or pfUI.font_default, size, "OUTLINE")
      win.seg:SetText(text)
      -- (the button's own width can read 0 before the window is laid out: the room is worked out from the window)
      local room = (win:GetWidth() or 0) - (win.titlebtn:GetWidth() or 0) - 2 - 56 - 4
      if text == "" then return true end
      if room <= 20 then room = 20 end
      while size > 8 and (win.seg:GetStringWidth() or 0) > room do
        size = size - 1
        win.seg:SetFont(win.segFont or pfUI.font_default, size, "OUTLINE")
      end
      return (win.seg:GetStringWidth() or 0) <= room
    end
    if win.mode == "threat" then
      -- (12 Nov 2026) the mob the numbers are for, beside the title
      local mob = UnitExists("target") and UnitName("target")
      -- (20 Nov 2026) "Target  NN%": your own % beside the mob's name (Aggro while it is on you)
      local tag = ""
      local THm = M.threat
      if mob and THm and THm.list and THm.Mine then
        local share, mine = THm.Mine()
        if share then tag = "  |cffffffff" .. floor(math.min(share, .99) * 100) .. "%|r"
        elseif mine then tag = "  |cffffffff" .. T["Aggro"] .. "|r" end
      end
      if mob and not FitSeg("|cffaaaaaa" .. mob .. "|r" .. tag) then
        win.seg:SetText("")
        mobLine = mob
      elseif not mob then
        win.seg:SetText("")
      end
    else
      FitSeg(SegmentName(win.segment, win) or "")
    end

    -- (test bars: every window shows the made-up fight; with the test fight
    -- built (meters-test.lua) its real rows, so every bar opens a breakdown)
    local testing = M.Testing()
    local rows
    -- (20 Nov 2026, user: "why is this showing the top bars in my preview but not on my meter this should never
    -- happen") with threat numbers coming in (a fight, the demo) the threat preview shows the meter's own lines;
    -- the made-up sample only when there are none
    local TH = M.threat
    if win.preview and win.mode == "threat" and TH and TH.list then
      rows = M.Rows("threat", win.segment)
      win.previewLive = true
    elseif win.preview or (testing and not M.testSeg) then
      rows = M.SampleRows(win.mode)
      win.previewLive = nil
    else
      rows = M.Rows(win.mode, win.segment)
    end
    -- (the mob's name too long for the title: in full on the first line, with its health)
    if mobLine and win.mode == "threat" then
      local hp, hpmax = UnitHealth("target") or 0, UnitHealthMax("target") or 0
      local f = hpmax > 0 and hp / hpmax or 0
      table.insert(rows, 1, { name = mobLine, pullrow = "mob", value = f, max = 1, gap = 1, at = 1,
                              label = "|cffe6e6e6" .. mobLine .. "|r", text = floor(f * 100 + .5) .. "%" })
    end
    -- (20 Nov 2026) every other window's column headings too (threat adds its own in M.Rows)
    if win.mode ~= "threat" and C.meters.mcols ~= "0" and C.meters.mheads ~= "0" and table.getn(rows) > 0 and not rows[1].pullrow then
      win.hasPs, win.hasPct = nil, nil
      for _, r in ipairs(rows) do
        if r.extra then win.hasPs = true end
        if r.pct then win.hasPct = true end
      end
      table.insert(rows, 1, { name = "", pullrow = "head", value = 0, max = 1 })
    end
    local height = tonumber(s.barheight) or 16
    local gap = tonumber(s.spacing) or 1
    local top = s.title ~= "0" and ((tonumber(s.titleheight) or 18) + 2) or 2
    local statush = s.status == "1" and 14 or 0
    -- (20 Nov 2026, user: "neat and clear") the threat window fits the lines it shows - no empty space under them;
    -- its size setting (or the grip) is the most it grows to (C.meters.tfit)
    -- (every window, 20 Nov 2026: "this should be in all meters")
    local fit = C.meters.tfit ~= "0" and not win.sizing and not win.psize
    local fullH = win:GetHeight()
    -- (20 Nov 2026, user: the demo's threat window showed only its pull line) the most a window grows to is its size
    -- setting, a preview's box, or - with neither - the height it had before it was ever fitted (win.baseH). Never the
    -- height it was just fitted to: one short list shrank it, and it stayed that small.
    if not win.fitH or not win.baseH then win.baseH = math.max(win.baseH or 0, fullH or 0) end
    if fit then
      if win.preview then fullH = win.previewH or tonumber(s.height) or win.baseH or fullH
      else fullH = tonumber(s.height) or win.baseH or fullH end
      -- (a size saved while fitted - layout mode read the fitted height - must not keep it that small: room for at
      -- least 10 lines on a threat window (its top lines + the raid), 6 on the others; fitting takes away the rest)
      local bh = (tonumber(s.barheight) or 16) + (tonumber(s.spacing) or 1)
      local floorH = (s.title ~= "0" and ((tonumber(s.titleheight) or 18) + 2) or 2) + (win.mode == "threat" and 10 or 6) * bh + 6
        + (s.status == "1" and 14 or 0)
      if fullH < floorH then fullH = floorH end
    end
    local room = fullH - top - 2 - statush
    -- (20 Nov 2026) the threat window's info lines sit apart from the players: a small gap under them
    local SPLIT = 4
    if win.mode == "threat" then room = room - SPLIT end
    local visible = max(1, floor((room + gap) / (height + gap)))
    -- (the threat meter asks the server for this many players, meters-threat.lua TH.Limit)
    win.visibleRows = visible
    if win.offset > max(0, table.getn(rows) - visible) then win.offset = max(0, table.getn(rows) - visible) end

    -- texts
    local font = (s.font and s.font ~= "") and s.font or pfUI.font_unit
    local fsize = tonumber(s.fontsize) or C.global.font_unit_size
    local outline = s.outline == "NONE" and "" or (s.outline or "OUTLINE")
    local tr, tg, tb, ta = Col(s.barcolor, "0.6,0.6,0.6,1")
    local bgr, bgg, bgb, bga = Col(s.barbg, "1,1,1,0.05")
    local balpha = tonumber(s.baralpha) or .85
    local up = s.grow == "up"

    local me = UnitName("player")
    -- the info lines at the top (pull line, your DoTs, next to pull, the mob): the players come SPLIT px under them
    local info = 0
    while rows[info + 1 + win.offset] and rows[info + 1 + win.offset].pullrow and rows[info + 1 + win.offset].pullrow ~= "head" do info = info + 1 end
    -- the window fits exactly the lines it shows
    if fit then
      local shown = math.min(visible, math.max(1, table.getn(rows) - win.offset))
      local h = top + shown * (height + gap) - gap + 2 + statush + ((info > 0 and shown > info) and SPLIT or 0)
      if math.abs((win:GetHeight() or 0) - h) >= 1 then win:SetHeight(h) end
      win.fitH = h
    end
    for i = 1, visible do
      local row = rows[i + win.offset]
      local b = Bar(win, i)
      if row then
        b:ClearAllPoints()
        local split = (win.mode == "threat" and info > 0 and i > info) and SPLIT or 0
        if up then
          b:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 2, 2 + statush + (i - 1) * (height + gap))
          b:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -2, 2 + statush + (i - 1) * (height + gap))
        else
          b:SetPoint("TOPLEFT", win, "TOPLEFT", 2, -top - (i - 1) * (height + gap) - split)
          b:SetPoint("TOPRIGHT", win, "TOPRIGHT", -2, -top - (i - 1) * (height + gap) - split)
        end
        b:SetHeight(height)
        b.row = row
        b.bar:SetStatusBarTexture(s.texture)
        -- (20 Nov 2026, user: "can we add this smooth glide ... this should be in all meters") ClassicAPI eases the fill
        -- in the client (StatusBar:SetValue(v, Enum.StatusBarInterpolation.ExponentialEaseOut): no Lua each frame,
        -- the same speed at any frame rate). A bar that now shows someone else jumps (Immediate), never glides from
        -- the last owner's value. Without ClassicAPI: the plain fill (threat keeps its own glide, TH.Animate).
        local v = row.max and row.max > 0 and row.value / row.max or 0
        local owner = (row.pullrow or "") .. ":" .. (row.name or "")
        local ease = M.Eased()
        if ease then
          local how = (b.owner == owner) and ease.ExponentialEaseOut or ease.Immediate
          if not pcall(b.bar.SetValue, b.bar, v, how) then b.bar:SetValue(v) end
        else
          b.bar:SetValue(v)
        end
        b.owner = owner
        b.bg:SetTexture(bgr, bgg, bgb, bga)
        -- (info lines on a darker ground than the players)
        local headRow = row.pullrow == "head"
        local info = row.pullrow and win.mode == "threat" and not headRow
        if info then b.bg:SetTexture(Col(C.meters.tinfobg, "0.07,0.08,0.1,0.92")) end
        -- (players on a black 35% backing; the heading line on nothing at all)
        if win.mode == "threat" and not row.pullrow then b.bg:SetTexture(0, 0, 0, .35) end
        if headRow then b.bg:SetTexture(0, 0, 0, 0) end
        -- the kind of top line: a mark down its left edge in its colour
        if info then
          if not b.mark then
            b.mark = b.bar:CreateTexture(nil, "OVERLAY")
            b.mark:SetTexture("Interface\\Buttons\\WHITE8X8")
            b.mark:SetWidth(3)
            b.mark:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
            b.mark:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
          end
          b.mark:SetVertexColor(M.InfoColor(row))
          b.mark:Show()
        elseif b.mark then
          b.mark:Hide()
        end
        local color = row.class and RAID_CLASS_COLORS[row.class]
        local r, g, bb = tr, tg, tb
        if color and s.colorby ~= "fixed" then r, g, bb = color.r, color.g, color.b end
        if win.mode == "threat" then
          -- you: green -> yellow -> red towards the pull point; the tank: dark red
          local share = row.name == me and M.threat and M.threat.Mine()
          if row.pullrow then
            -- one quiet fill for every top line, so the white words and the coloured numbers stay easy to read
            r, g, bb = Col(C.meters.tinfofill, "0.24,0.27,0.32,1")
          elseif row.tank then r, g, bb = .6, .15, .15
          elseif share then r, g, bb = min(1, share * 2), min(1, 2 - share * 2), .1 end
        end
        -- your own bar: a border or a brighter bar (25 Oct 2026)
        local mine = row.name == me and (s.selfmark == "border" or s.selfmark == "tint")
        if mine and s.selfmark == "tint" then
          local sr, sg, sb = Col(s.selfcolor, "1,0.82,0.2,1")
          r, g, bb = sr, sg, sb
        end
        b.bar:SetStatusBarColor(r, g, bb, balpha)
        if row.ghost and row.max and row.max > 0 and row.ghost > row.value then
          local w = math.max(1, (win:GetWidth() or 100) - 4)
          local f1 = math.min(1, row.value / row.max)
          local f2 = math.min(1, row.ghost / row.max)
          b.ghost:ClearAllPoints()
          -- (it starts where the fill ends, so it moves with an easing fill)
          local fillTex = b.bar.GetStatusBarTexture and b.bar:GetStatusBarTexture()
          if fillTex and v > 0 then
            b.ghost:SetPoint("TOPLEFT", fillTex, "TOPRIGHT", 0, 0)
            b.ghost:SetPoint("BOTTOMLEFT", fillTex, "BOTTOMRIGHT", 0, 0)
          else
            b.ghost:SetPoint("TOPLEFT", b, "TOPLEFT", w * f1, 0)
            b.ghost:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", w * f1, 0)
          end
          b.ghost:SetWidth(math.max(1, w * (f2 - f1)))
          -- (a light tint, never the bar's own red: it must read apart from the fill)
          if row.stopNow then b.ghost:SetVertexColor(1, .78, .72, .5) else b.ghost:SetVertexColor(1, 1, 1, .3) end
          b.ghost:Show()
        else
          b.ghost:Hide()
        end
        b.hov:SetVertexColor(Col(s.hovercolor, "1,1,1,0.12"))
        if mine and s.selfmark == "border" then
          b.rim:SetBackdropBorderColor(Col(s.selfcolor, "1,0.82,0.2,1"))
          b.rim:Show()
        elseif s.barborder == "1" then
          b.rim:SetBackdropBorderColor(Col(s.barbordercolor, "0,0,0,1"))
          b.rim:Show()
        else
          b.rim:Hide()
        end
        -- class icon: its size (0 = the bar's height) and side are settings
        local coords = row.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[row.class]
        local iconw = 0
        local isize = tonumber(s.iconsize) or 0
        if isize <= 0 then isize = height end
        local iconright = s.iconside == "right"
        if s.icons == "class" and coords then
          b.icon:SetTexture(pfUI.media["img:classicons"])
          b.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
          b.icon:SetWidth(isize)
          b.icon:SetHeight(isize)
          b.icon:ClearAllPoints()
          b.icon:SetPoint(iconright and "RIGHT" or "LEFT", b, iconright and "RIGHT" or "LEFT", 0, 0)
          b.icon:Show()
          iconw = isize
        else
          b.icon:Hide()
        end
        local vsize = tonumber(s.valuesize) or 0
        if vsize <= 0 then vsize = fsize end
        b.left:SetFont(font, fsize, outline)
        b.right:SetFont(font, vsize, outline)
        for _, fs in ipairs({ b.left, b.right }) do
          if s.shadow == "1" then fs:SetShadowOffset(1, -1) fs:SetShadowColor(0, 0, 0, 1) else fs:SetShadowOffset(0, 0) end
        end
        b.right:ClearAllPoints()
        b.right:SetPoint("RIGHT", b, "RIGHT", -4 - (iconright and iconw or 0), 0)
        b.left:ClearAllPoints()
        b.left:SetPoint("LEFT", b, "LEFT", 4 + (iconright and 0 or iconw), 0)
        b.left:SetPoint("RIGHT", b.right, "LEFT", -6, 0)
        if s.namecolor == "class" and color then b.left:SetTextColor(color.r, color.g, color.b)
        elseif s.namecolor == "custom" then b.left:SetTextColor(Col(s.namecustom, "1,1,1,1"))
        else b.left:SetTextColor(1, 1, 1) end
        if s.valuecolor == "class" and color then b.right:SetTextColor(color.r, color.g, color.b)
        elseif s.valuecolor == "custom" then b.right:SetTextColor(Col(s.valuecustom, "1,1,1,1"))
        else b.right:SetTextColor(1, 1, 1) end
        -- (the pull line has no rank, and the players under it count from 1)
        local rank = row.rank or (i + win.offset - ((rows[1] and rows[1].pullrow) and 1 or 0))
        b.left:SetText((s.rank ~= "0" and not row.pullrow and (Hex(s.rankcolor, "0.67,0.67,0.67,1") .. rank .. ".|r ") or "") .. row.name)
        if win.mode == "threat" then
          ThreatColumns(b, s, row, vsize, font, outline, iconright and iconw or 0, (not iconright) and iconw or 0)
        elseif C.meters.mcols ~= "0" then
          -- (20 Nov 2026, user: "this should be in all meters") the same neat columns: per second, total, %
          if b.mark then b.mark:Hide() end
          local showPct = s.showpct ~= "0" and row.pct
          local opts = { tps = s.showps ~= "0" and row.extra ~= nil, mid = showPct and true or false,
                         heads = { T["/s"], T["Total"], showPct and "%" or T["Total"] } }
          if row.pullrow == "head" then
            opts.tps = s.showps ~= "0" and win.hasPs
            opts.mid = s.showpct ~= "0" and win.hasPct
            opts.heads[3] = opts.mid and "%" or T["Total"]
          end
          local cr = { name = row.name, class = row.class, pullrow = row.pullrow,
                       extra = row.text, tps = row.extra,
                       text = showPct and string.format("%.0f%%", row.pct) or row.text }
          ThreatColumns(b, s, cr, vsize, font, outline, iconright and iconw or 0, (not iconright) and iconw or 0, opts)
        else
          if b.mid then b.mid:Hide() b.pct:Hide() if b.cd then b.cd:Hide() end if b.tps then b.tps:Hide() end end
          if b.mark then b.mark:Hide() end
          b.right:SetText(RightText(s, row))
        end
        b:Show()
      else
        b.row = nil
        b:Hide()
      end
    end
    for i = visible + 1, table.getn(win.bars) do win.bars[i]:Hide() end
    win.rowsShown = rows
    if M.StatusText then M.StatusText(win) end

    -- empty: say why
    if table.getn(rows) == 0 then
      local why = win.mode == "threat" and M.threat and M.threat.Status() or T["Nothing yet - go fight something"]
      if win.mode == "threat" and not M.threat then why = T["Threat is turned off"] end
      win.empty:SetText(why or "")
      win.empty:Show()
    else
      win.empty:Hide()
    end
  end

  -- a small title-bar button: a letter, or icon = "menu" (three lines)
  local function HeaderButton(win, text, tip, func, icon)
    local b = CreateFrame("Button", nil, win)
    b:SetWidth(16)
    b:SetHeight(16)
    b:SetFrameLevel(win:GetFrameLevel() + 3)
    local function Paint(r, g, bb)
      if b.lines then
        for _, l in ipairs(b.lines) do l:SetTexture(r, g, bb, 1) end
      elseif b.tex then
        if b.PaintIcon then b.PaintIcon(r, g, bb) else b.tex:SetVertexColor(r, g, bb, 1) end
      else
        b.text:SetTextColor(r, g, bb, 1)
      end
    end
    if icon == "lock" then
      -- the game's chat padlock (Interface\ChatFrame\UI-ChatFrame-LockIcon)
      b.tex = b:CreateTexture(nil, "OVERLAY")
      b.tex:SetTexture("Interface\\ChatFrame\\UI-ChatFrame-LockIcon")
      b.tex:SetWidth(14)
      b.tex:SetHeight(14)
      b.tex:SetPoint("CENTER", b, "CENTER", 0, 0)
    elseif icon == "menu" then
      b.lines = {}
      for i = 1, 3 do
        local l = b:CreateTexture(nil, "OVERLAY")
        l:SetWidth(9)
        l:SetHeight(1)
        l:SetPoint("CENTER", b, "CENTER", 0, 4 - (i - 1) * 4)
        b.lines[i] = l
      end
    else
      b.text = b:CreateFontString(nil, "OVERLAY", "GameFontWhite")
      b.text:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
      b.text:SetAllPoints()
      b.text:SetText(text)
    end
    Paint(.7, .7, .7)
    b:SetScript("OnEnter", function()
      Paint(GetAccentColor())
      GameTooltip:SetOwner(this, "ANCHOR_TOP")
      GameTooltip:SetText(this.tipfn and this.tipfn() or tip, 1, 1, 1)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() Paint(.7, .7, .7) GameTooltip:Hide() end)
    b:SetScript("OnClick", func)
    return b
  end

  local function RefreshAll()
    for _, w in ipairs(M.windows) do Refresh(w) end
  end
  -- (6 Nov 2026) only the threat windows, at once: the server's answer is on screen as it arrives
  function M.RefreshThreat()
    for _, w in ipairs(M.windows or {}) do
      if w.mode == "threat" and w:IsVisible() then Refresh(w) end
    end
  end

  -- the padlock's look: gold locked (or docked), grey unlocked
  function M.PaintLock(win)
    local b = win and win.lockbtn
    if not b then return end
    if not win.free or S(win).lock == "1" then
      b.tex:SetVertexColor(1, .82, .2, 1)
      b.tex:SetAlpha(1)
    else
      b.tex:SetVertexColor(.6, .6, .6, 1)
      b.tex:SetAlpha(.55)
    end
  end

  function M.ToggleLock(win)
    if not win then return end
    local s = S(win)
    if not win.free and M.SetDocked then
      s.lock = "0"
      M.SetDocked(win, false)
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r meters: " .. T["window out of the chat panel and unlocked - drag its title to move it."])
    else
      s.lock = (s.lock == "1") and "0" or "1"
      if win.grip then if s.lock == "1" then win.grip:Hide() else win.grip:Show() end end
    end
    M.PaintLock(win)
  end

  -- ---------------------------------------------------------------- docking

  -- window 1 docks as "damage", window 2 as "threat" (pfUI's dock sides)
  local function KeyOf(win) return (win.id == 1 and "pfmeter") or (win.id == 2 and "pfthreat") or nil end
  local function SideOf(win) return win.id == 1 and "damage" or "threat" end

  -- Docking in the right chat is gone (user, 24 Oct 2026: windows "move all
  -- over", "tied to this bottom button ... remove this function ... it just
  -- confuses and makes a mess of the UI"). Every window is a free window you
  -- place; the chat panel's toggle button is hidden (panel.lua).
  local function CanDock() return false end
  if C.thirdparty then
    for _, k in ipairs({ "pfmeter", "pfthreat" }) do
      if type(C.thirdparty[k]) == "table" then C.thirdparty[k].dock = "0" end
    end
    C.thirdparty.showmeter = "0"
  end
  -- (a chat hidden by the old toggle comes back)
  if pfUI.chat and pfUI.chat.right and C.chat.right.enable == "1" then pfUI.chat.right:Show() end

  -- 1.12 does not carry a parent's new frame level over to its children: after
  -- the window is raised (docked over the chat) its buttons would sit below
  -- the window itself, which takes every click. Put each child back on top.
  local function Lift(win, inner)
    local level, strata = win:GetFrameLevel(), win:GetFrameStrata()
    local kids = { win:GetChildren() }
    for _, kid in ipairs(kids) do
      kid:SetFrameStrata(strata)
      kid:SetFrameLevel(level + (inner and 1 or kid.lift or 3))
      Lift(kid, true)
    end
  end
  M.Lift = Lift

  -- fills the right chat, or its half when the other window is docked too
  local function Dock(win)
    if win.free or not CanDock() then return end
    local chat = pfUI.chat.right
    local bottom = pfUI.panel and pfUI.panel.right and pfUI.panel.right:GetHeight() or 0
    local other = M.windows[win.id == 1 and 2 or 1]
    local half = other and not other.free
    win:ClearAllPoints()
    if not half then
      win:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, 0)
      win:SetPoint("BOTTOMRIGHT", chat, "BOTTOMRIGHT", 0, bottom)
    elseif win.id == 1 then
      win:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, 0)
      win:SetPoint("BOTTOMRIGHT", chat, "BOTTOM", -border, bottom)
    else
      win:SetPoint("TOPLEFT", chat, "TOP", border, 0)
      win:SetPoint("BOTTOMRIGHT", chat, "BOTTOMRIGHT", 0, bottom)
    end
    win:SetFrameStrata(chat:GetFrameStrata())
    win:SetFrameLevel(chat:GetFrameLevel() + 5)
    win.grip:Hide()
    Refresh(win)
    Lift(win)
  end

  -- a free window: its own size and place, movable with the title bar, /moveui
  local function Float(win)
    local id = win.id
    win:ClearAllPoints()
    win:SetFrameStrata("MEDIUM")
    win:SetWidth(tonumber(S(win).width) or 260)
    win:SetHeight(tonumber(S(win).height) or 160)
    local saved = C.position and C.position[win:GetName()]
    if not saved then
      win:SetPoint("CENTER", UIParent, "CENTER", M.HomeX(id), M.HomeY(id))
    end
    -- (21 Nov 2026) a snapped window was saved as TOPLEFT on the screen's BOTTOMLEFT, and LoadMovable reads that
    -- as TOPLEFT on the screen's TOPLEFT (above the screen): measured from the bottom, so it moves down by the
    -- screen's height
    M.FixOldSnap(win, saved)
    -- (with no saved spot this is the window's default from now on: pfUI
    -- keeps the first spot it saw and layout mode put a reset window back
    -- there - off the screen, 24 Oct 2026)
    UpdateMovable(win, not saved)
    if S(win).lock == "1" then win.grip:Hide() else win.grip:Show() end
    if C.meters.hidden == "1" then win:Hide() else win:Show() end
    Refresh(win)
    -- (21 Nov 2026) saved by another point (older saves, layout mode): now by its top-left at the height it fits
    -- (a TOPLEFT one comes out the same)
    if saved and saved.xpos and not saved.attach then M.Pin(win) end
    Lift(win)
  end

  -- where a free window starts: three to a row around the middle of the
  -- screen (window 5 and 6 used to start off its right edge)
  function M.HomeX(id) return (math.mod(id - 1, 3) - 1) * 280 end
  function M.HomeY(id) return -120 - math.floor((id - 1) / 3) * 190 end

  -- back to the start (user, 24 Oct 2026: a meter went off the screen):
  -- free windows to their home spot, docked ones back into the chat panel
  function M.ResetPosition(win)
    if not win then return end
    if C.position then C.position[win:GetName()] = nil end
    if win.free then
      win:ClearAllPoints()
      Float(win)
    elseif Dock then
      Dock(win)
    end
  end
  -- every other window takes this one's size and look (user, 24 Oct 2026:
  -- "an option that matches all windows size and looks"); what each window
  -- shows (display, fight) and its padlock stay its own
  local KEEP = { mode = true, segment = true, lock = true }
  function M.MatchAll(fromId)
    local src = C.meters["win" .. (fromId or 1)]
    if type(src) ~= "table" then return 0 end
    local n = 0
    for _, w in ipairs(M.windows) do
      local id = w.cfg or w.id
      if id ~= fromId then
        local dst = C.meters["win" .. id]
        if type(dst) == "table" then
          for k, v in pairs(src) do
            if not KEEP[k] and type(v) ~= "table" then dst[k] = v end
          end
          w:SetWidth(tonumber(dst.width) or 260)
          w:SetHeight(tonumber(dst.height) or 160)
          if M.ApplyStyle then M.ApplyStyle(w) end
          w.Refresh(w)
          n = n + 1
        end
      end
    end
    if M.CombatLook then M.CombatLook() end
    return n
  end

  function M.ResetPositions()
    for _, w in ipairs(M.windows) do M.ResetPosition(w) end
    -- (the show / hide button too)
    if M.toggle then
      if C.position then C.position["pfMeterToggle"] = nil end
      M.toggle:ClearAllPoints()
      M.toggle:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -260, 40)
      UpdateMovable(M.toggle, true)
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r meters: " .. T["every meter window is back in its starting place."])
  end
  _G.SLASH_PFMETERRESET1 = "/pfmeterreset"
  _G.SlashCmdList.PFMETERRESET = function() M.ResetPositions() end

  local function Register(win)
    pfUI.thirdparty.meters:RegisterMeter(SideOf(win), { KeyOf(win), "pfUI", win,
      function() Dock(win) end, function() Dock(win) end,
      function() if not win.free then win:Show() end end,
      function() if not win.free then win:Hide() end end })
  end

  -- dock / undock while playing
  function M.SetDocked(win, dock)
    dock = dock and CanDock()   -- (docking is gone: always a free window)
    local other = M.windows[win.id == 1 and 2 or 1]
    C.thirdparty[KeyOf(win)].dock = dock and "1" or "0"
    if dock and CanDock() then
      win.free = nil
      RemoveMovable(win)
      if pfUI.thirdparty.meters[SideOf(win)] ~= nil then Dock(win) else Register(win) end
      if other then Dock(other) end
      -- the meters show in place of the chat
      if not pfUI.thirdparty.meters.state then pfUI.thirdparty.meters:Toggle() end
      Dock(win)
      win:Show()
    else
      win.free = true
      Float(win)
      if other then Dock(other) end
      -- nothing docked any more: give the chat back
      local any = other and not other.free
      if not any and pfUI.thirdparty.meters and pfUI.thirdparty.meters.state then
        pfUI.thirdparty.meters:Toggle()
      end
    end
    M.PaintLock(win)
  end

  -- ---------------------------------------------------------------- the window menu

  local function OpenOptions()
    local O = pfUI.octoui and pfUI.octoui.Options
    if O and O.Open and O.frame then return O:Open("mtwindows") end
    pfUI.gui:Show()
    if pfUI.gui.frames[T["Meters"]] then pfUI.gui.frames[T["Meters"]]:Click() end
  end

  local BAR_HEIGHTS = { "12", "14", "16", "18", "20", "24" }

  local function WindowMenu(win, anchor)
    local s = S(win)
    -- a window setting (tbl = s) or a meter-wide one (tbl = C.meters)
    local function Flip(tbl, key, after)
      return function()
        tbl[key] = tbl[key] == "1" and "0" or "1"
        if after then after() end
        ApplyStyle(win)
        RefreshAll()
        WindowMenu(win, anchor)
      end
    end
    local items = { { T["Window"], head = true } }
    if win.free then
      table.insert(items, { T["Lock position and size"], Flip(s, "lock", function()
        if s.lock == "1" then win.grip:Hide() else win.grip:Show() end
        M.PaintLock(win)
      end), tick = s.lock == "1", keep = true })
      table.insert(items, { T["Reset position"], function() M.ResetPosition(win) end })
    end
    table.insert(items, { string.format(T["Bar height: %s (click: bigger)"], s.barheight), function()
      local nextv = BAR_HEIGHTS[1]
      for i, v in ipairs(BAR_HEIGHTS) do
        if v == s.barheight and BAR_HEIGHTS[i + 1] then nextv = BAR_HEIGHTS[i + 1] end
      end
      s.barheight = nextv
      RefreshAll()
      WindowMenu(win, anchor)
    end, keep = true })
    table.insert(items, { T["Show"], head = true })
    table.insert(items, { T["Rank numbers"], Flip(s, "rank"), tick = s.rank ~= "0", keep = true })
    table.insert(items, { T["Per second"], Flip(s, "showps"), tick = s.showps ~= "0", keep = true })
    table.insert(items, { T["Percent of the total"], Flip(s, "showpct"), tick = s.showpct ~= "0", keep = true })
    table.insert(items, { T["Class colors"], function()
      s.colorby = s.colorby == "fixed" and "class" or "fixed"
      RefreshAll()
      WindowMenu(win, anchor)
    end, tick = s.colorby ~= "fixed", keep = true })
    table.insert(items, { T["Track"], head = true })
    table.insert(items, { T["Merge pets into their owner"], Flip(C.meters, "mergepets", function() M.who = {} end),
      tick = C.meters.mergepets == "1", keep = true })
    table.insert(items, { T["Everyone nearby (battlegrounds)"], Flip(C.meters, "trackall", function() M.who = {} end),
      tick = C.meters.trackall == "1", keep = true })
    table.insert(items, { T["Windows"], head = true })
    if table.getn(M.windows) < M.MAXWIN then
      table.insert(items, { T["New window"], function() M.AddWindow() end })
    end
    if win.id > 1 then
      table.insert(items, { T["Close this window"], function()
        CreateQuestionDialog(T["Remove this meter window?"], function() M.RemoveWindow(win.id) end)
      end })
    end
    table.insert(items, { T["Actions"], head = true })
    table.insert(items, { T["Report to chat..."], function() ReportMenu(win, anchor) end })
    table.insert(items, { T["Reset all data"], function()
      CreateQuestionDialog(T["Reset all meter data?"], function() M.Reset() end)
    end })
    table.insert(items, { T["All meter options..."], OpenOptions })
    ShowMenu(anchor, items)
  end
  M.WindowMenu = WindowMenu

  -- ---------------------------------------------------------------- windows

  -- pv = { parent = box, cfg = window number }: the options' preview window,
  -- a real window on a made-up fight whose parts open their settings
  local function CreateWindow(id, pv)
    local win = CreateFrame("Frame", (not pv) and ("pfMeter" .. id) or nil, pv and pv.parent or UIParent)
    win.id = id
    if pv then
      win.preview = true
      win.cfg = pv.cfg
    end
    win.mode = S(win).mode or "damage"
    win.segment = S(win).segment or "current"
    win.offset = 0
    win.bars = {}
    win:SetWidth(tonumber(S(win).width) or 260)
    win:SetHeight(tonumber(S(win).height) or 160)
    win:SetPoint("CENTER", UIParent, "CENTER", M.HomeX(id), M.HomeY(id))
    win:SetFrameStrata("MEDIUM")
    win:SetMovable(true)
    win:SetResizable(true)
    win:SetMinResize(150, 60)
    win:SetClampedToScreen(true)
    -- (21 Nov 2026) moved in layout mode: saved by its top-left too (unlock.lua calls OnMove after a drop)
    win.OnMove = function(self) if M.Pin then M.Pin(self or win) end end
    win:EnableMouse(true)
    win:EnableMouseWheel(true)
    CreateBackdrop(win, nil, nil, .8)
    win.backdrop:SetBackdropColor(Col(S(win).bg))

    -- title bar: drag it to move a free window
    win.head = win:CreateTexture(nil, "ARTWORK")
    win.head:SetPoint("TOPLEFT", 0, 0)
    win.head:SetPoint("TOPRIGHT", 0, 0)
    win.head:SetHeight(18)
    win.head:SetTexture(0, 0, 0, .45)

    local function DragStart()
      if win.free and S(win).lock ~= "1" then
        -- (closing layout mode sets every mover frame unmovable)
        win:SetMovable(true)
        M.GroupStart(win)
        pfUI.api.DragStart(win)
        win.moving = true
        if win.followers then
          M.groupMover = M.groupMover or CreateFrame("Frame")
          M.groupMover.win = win
          M.groupMover:SetScript("OnUpdate", function() if this.win and this.win.moving then M.GroupFollow(this.win) end end)
          M.groupMover:Show()
        end
      end
    end
    local function DragStop()
      if win.moving then
        pfUI.api.DragStop(win)
        win.moving = nil
        if M.groupMover then M.groupMover:Hide() end
        -- (a group keeps its shape: it is not snapped onto one of its own windows)
        if C.meters.snap ~= "0" and M.Snap and not win.followers then M.Snap(win) end
        M.Pin(win)
        M.GroupFollow(win, true)
      end
    end

    win.titlebtn = CreateFrame("Button", nil, win)
    win.titlebtn:SetPoint("TOPLEFT", 2, -1)
    win.titlebtn:SetHeight(16)
    win.titlebtn:SetWidth(110)
    win.titlebtn:RegisterForDrag("LeftButton")
    win.titlebtn:SetScript("OnDragStart", DragStart)
    win.titlebtn:SetScript("OnDragStop", DragStop)
    win.title = win.titlebtn:CreateFontString(nil, "OVERLAY", "GameFontWhite")
    win.title:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
    win.title:SetPoint("LEFT", 4, 0)
    local ar, ag, ab = GetAccentColor()
    win.title:SetTextColor(ar, ag, ab, 1)
    win.titlebtn:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_TOP")
      GameTooltip:SetText(T["Click: what this window shows"], 1, 1, 1)
      if win.free then GameTooltip:AddLine(T["Drag: move the window"], .7, .7, .7) end
      GameTooltip:Show()
    end)
    win.titlebtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    win.titlebtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    win.titlebtn:SetScript("OnClick", function()
      if win.preview then if M.PreviewClick then M.PreviewClick(win, "title") end return end
      -- right-click: the displays used last, to switch fast
      if arg1 == "RightButton" then
        local items = { { T["Recent"], head = true } }
        for _, key in ipairs(M.Recent()) do
          local m = MODE[key]
          if m then
            table.insert(items, { m.name, function() M.SetMode(win, key) end, checked = (key == win.mode) })
          end
        end
        ShowMenu(this, items)
        return
      end
      -- Details' groups, each with its displays
      local items = {}
      M.CustomNames()
      for _, g in ipairs(M.GROUPS) do
        -- (a group shows when one of its displays does: Custom only once set)
        local any
        for _, m in ipairs(MODES) do if m.group == g and (not m.shown or m.shown()) then any = true end end
        if any then table.insert(items, { T[g], head = true }) end
        for _, m in ipairs(MODES) do
          if m.group == g and (not m.shown or m.shown()) then
            local key = m.key
            table.insert(items, { m.name, function() M.SetMode(win, key) end, checked = (key == win.mode) })
          end
        end
      end
      ShowMenu(this, items)
    end)

    win.segbtn = CreateFrame("Button", nil, win)
    win.segbtn:SetPoint("LEFT", win.titlebtn, "RIGHT", 2, 0)
    win.segbtn:SetPoint("RIGHT", win, "TOPRIGHT", -56, -9)
    win.segbtn:SetHeight(16)
    win.segbtn:RegisterForDrag("LeftButton")
    win.segbtn:SetScript("OnDragStart", DragStart)
    win.segbtn:SetScript("OnDragStop", DragStop)
    win.seg = win.segbtn:CreateFontString(nil, "OVERLAY", "GameFontWhite")
    win.seg:SetFont(pfUI.font_default, C.global.font_size - 1, "OUTLINE")
    win.seg:SetAllPoints()
    win.seg:SetJustifyH("LEFT")
    win.seg:SetTextColor(.8, .8, .8, 1)
    win.segbtn:SetScript("OnEnter", function()
      if win.mode == "threat" then return end
      GameTooltip:SetOwner(this, "ANCHOR_TOP")
      GameTooltip:SetText(T["Click: which fight"], 1, 1, 1)
      GameTooltip:Show()
    end)
    win.segbtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    win.segbtn:SetScript("OnClick", function()
      if win.preview then if M.PreviewClick then M.PreviewClick(win, "title") end return end
      if win.mode == "threat" then return end
      local items = { { T["Fight"], head = true } }
      local function Pick(key)
        return function()
          win.segment = key
          S(win).segment = key
          Refresh(win)
        end
      end
      table.insert(items, { T["Current fight"], Pick("current"), checked = win.segment == "current" })
      table.insert(items, { T["Overall"], Pick("overall"), checked = win.segment == "overall" })
      for i, seg in ipairs(M.history) do
        -- bosses in red with a skull
        local mark = seg.boss and "|cffff5555" or ""
        local skull = seg.boss and " |TInterface\\TargetingFrame\\UI-TargetingFrame-Skull:12|t" or ""
        table.insert(items, { mark .. Clock(M.Duration(seg)) .. "  " .. (seg.name or T["Fight"]) .. skull, Pick(tostring(i)),
          checked = win.segment == tostring(i) })
      end
      ShowMenu(this, items)
    end)

    -- (in the preview the buttons open their settings instead)
    local function Btn(fn)
      return function()
        if win.preview then if M.PreviewClick then M.PreviewClick(win, "buttons") end return end
        fn()
      end
    end
    win.reset = HeaderButton(win, "X", T["Reset all meter data"], Btn(function()
      CreateQuestionDialog(T["Reset all meter data?"], function() M.Reset() end)
    end))
    win.reset:SetPoint("TOPRIGHT", -2, -1)
    win.report = HeaderButton(win, "R", T["Report to chat"], Btn(function() ReportMenu(win, this) end))
    win.report:SetPoint("RIGHT", win.reset, "LEFT", -1, 0)
    win.menu = HeaderButton(win, nil, T["Window settings: dock, lock, bars, what to track"], Btn(function()
      WindowMenu(win, this)
    end), "menu")
    win.menu:SetPoint("RIGHT", win.report, "LEFT", -1, 0)
    -- the padlock (user, 24 Oct 2026: "add padlock to the meters so they can
    -- be unlocked and locked and moved at will"): gold = locked, grey =
    -- unlocked (drag the title, resize from the corner). A docked window
    -- comes out of the dock, unlocked, so it can be moved.
    win.lockbtn = HeaderButton(win, nil, "", Btn(function() M.ToggleLock(win) end), "lock")
    win.lockbtn.tipfn = function()
      if not win.free then return T["Docked - click to take it out of the chat panel and move it"] end
      if S(win).lock == "1" then return T["Locked - click to unlock: then drag the title to move, the corner to resize"] end
      return T["Unlocked - drag the title to move, the corner to resize. Click to lock"]
    end
    win.lockbtn.PaintIcon = function(r, g, bb)
      -- (hover lights it in the accent; otherwise its state's colour)
      win.lockbtn.tex:SetVertexColor(r, g, bb, 1)
    end
    win.lockbtn:SetScript("OnLeave", function() GameTooltip:Hide() M.PaintLock(win) end)

    -- resize grip (free, unlocked windows)
    win.grip = CreateFrame("Button", nil, win)
    win.grip:SetWidth(12)
    win.grip:SetHeight(12)
    win.grip:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", 0, 0)
    win.grip:SetFrameLevel(win:GetFrameLevel() + 6)
    win.grip.lift = 6
    for i = 1, 3 do
      local dot = win.grip:CreateTexture(nil, "OVERLAY")
      dot:SetWidth(2)
      dot:SetHeight(2)
      dot:SetTexture(.7, .7, .7, .9)
      dot:SetPoint("BOTTOMRIGHT", win.grip, "BOTTOMRIGHT", -2 - (i - 1) * 3, 2)
      if i > 1 then
        local up = win.grip:CreateTexture(nil, "OVERLAY")
        up:SetWidth(2)
        up:SetHeight(2)
        up:SetTexture(.7, .7, .7, .9)
        up:SetPoint("BOTTOMRIGHT", win.grip, "BOTTOMRIGHT", -2, 2 + (i - 1) * 3)
      end
    end
    win.grip:SetScript("OnMouseDown", function()
      -- the preview: dragging the grip sets the window's size setting
      if win.preview then
        local cx, cy = GetCursorPosition()
        win.psize = { cx, cy, win:GetWidth() or 260, win:GetHeight() or 160 }
        return
      end
      if win.free and S(win).lock ~= "1" then
        -- the top-left corner stays where it is: noted now, put back when the grip is let go
        local l, t = win:GetLeft(), win:GetTop()
        win.sizeFrom = l and t and { l, t } or nil
        win:SetResizable(true)
        win:StartSizing("BOTTOMRIGHT")
        win.sizing = true
      end
    end)
    win.grip:SetScript("OnMouseUp", function()
      if win.psize then
        win.psize = nil
        if M.PreviewSized then M.PreviewSized(win) end
        return
      end
      if not win.sizing then return end
      win:StopMovingOrSizing()
      win.sizing = nil
      S(win).width = tostring(floor(win:GetWidth()))
      S(win).height = tostring(floor(win:GetHeight()))
      local from = win.sizeFrom
      win.sizeFrom = nil
      if from then M.PinAt(win, from[1], from[2]) else M.Pin(win) end
      Refresh(win)
    end)
    win.grip:SetScript("OnUpdate", function()
      local p = win.psize
      if p then
        local cx, cy = GetCursorPosition()
        local k = win:GetEffectiveScale() or 1
        local w = max(150, min(600, floor(p[3] + (cx - p[1]) / k + .5)))
        local h = max(60, min(500, floor(p[4] - (cy - p[2]) / k + .5)))
        S(win).width, S(win).height = tostring(w), tostring(h)
        win:SetWidth(w)
        win:SetHeight(h)
        Refresh(win)
        return
      end
      if not win.sizing or (this.tick or 0) > GetTime() then return end
      this.tick = GetTime() + .05
      Refresh(win)
    end)
    win.grip:Hide()

    -- the status bar (Details' "status bar" with its micro displays): three
    -- slots under the bars
    win.status = CreateFrame("Frame", nil, win)
    win.status:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 0, 0)
    win.status:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", 0, 0)
    win.status:SetHeight(14)
    win.status.bg = win.status:CreateTexture(nil, "BACKGROUND")
    win.status.bg:SetAllPoints(win.status)
    win.status.bg:SetTexture(0, 0, 0, .45)
    win.status.slots = {}
    for i, just in ipairs({ "LEFT", "CENTER", "RIGHT" }) do
      local t = win.status:CreateFontString(nil, "OVERLAY", "GameFontWhite")
      t:SetFont(pfUI.font_default, max(8, C.global.font_size - 2), "OUTLINE")
      t:SetJustifyH(just)
      t:SetPoint(just, win.status, just, just == "LEFT" and 4 or (just == "RIGHT" and -14 or 0), 0)
      t:SetTextColor(.8, .8, .8)
      win.status.slots[i] = t
    end
    win.status:SetScript("OnUpdate", function()
      if (this.tick or 0) > GetTime() then return end
      this.tick = GetTime() + 1
      if M.StatusText then M.StatusText(win) end
    end)
    win.status:Hide()

    win.empty = win:CreateFontString(nil, "OVERLAY", "GameFontWhite")
    win.empty:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
    win.empty:SetPoint("TOPLEFT", 6, -26)
    win.empty:SetPoint("RIGHT", -6, 0)
    win.empty:SetJustifyH("LEFT")
    win.empty:SetTextColor(.6, .6, .6, 1)

    win:SetScript("OnMouseWheel", function()
      this.offset = max(0, this.offset - arg1)
      Refresh(this)
    end)
    win:SetScript("OnShow", function() Refresh(this) end)
    win.Refresh = Refresh
    if pv then
      -- (above the options window; its parts follow)
      win:SetFrameStrata("FULLSCREEN")
      Lift(win)
      win.free = true
      win.grip:Show()
    end
    ApplyStyle(win)
    return win
  end
  M.CreateWindow = CreateWindow

  -- a fight starts: windows showing an earlier one go back to the current
  -- one (Details' "auto switch to current")
  table.insert(M.onStart or {}, function()
    if C.meters.autocurrent ~= "1" then return end
    for _, w in ipairs(M.windows) do
      if w.segment ~= "current" and w.segment ~= "overall" then
        w.segment = "current"
        S(w).segment = "current"
      end
    end
  end)

  M.windows = {}
  local count = math.max(1, math.min(M.MAXWIN, tonumber(C.meters.windows) or 2))
  for id = 1, count do M.windows[id] = CreateWindow(id) end
  table.insert(M.callbacks, RefreshAll)

  -- after a look changes (the options)
  function M.RestyleAll()
    for _, w in ipairs(M.windows) do
      ApplyStyle(w)
      if w.free then
        w:SetWidth(tonumber(S(w).width) or 260)
        w:SetHeight(tonumber(S(w).height) or 160)
      end
      w.mode, w.segment = S(w).mode or w.mode, S(w).segment or w.segment
      Refresh(w)
    end
    if M.CombatLook then M.CombatLook() end
  end

  -- a new window (it floats; windows 1 and 2 can dock)
  function M.AddWindow()
    local id = table.getn(M.windows) + 1
    if id > M.MAXWIN then return end
    C.meters.windows = tostring(id)
    local win = _G["pfMeter" .. id] or CreateWindow(id)
    M.windows[id] = win
    win.free = true
    Float(win)
    if C.meters.hidden == "1" then M.ShowAll(true) end
    return win
  end

  -- (20 Nov 2026) your threat window: the one locked to threat, else one already on threat (it becomes the locked
  -- one), else a new window. make = false: only find it.
  function M.ThreatWindow(make)
    for _, w in ipairs(M.windows or {}) do if S(w).threatlock == "1" then return w end end
    if make == false then return end
    local win
    for _, w in ipairs(M.windows or {}) do if w.mode == "threat" then win = w break end end
    if not win then win = M.AddWindow() end
    if not win then return end
    S(win).threatlock = "0"
    M.SetMode(win, "threat")
    S(win).threatlock = "1"
    win:Show()
    return win
  end
  function M.UnlockThreatWindow()
    local w = M.ThreatWindow(false)
    if w then S(w).threatlock = "0" end
  end

  -- remove window id: the ones after it move up a place (settings and spot)
  function M.RemoveWindow(id)
    local n = table.getn(M.windows)
    if id < 1 or id > n or n <= 1 then return end
    for i = id, n - 1 do
      local s, nxt = C.meters["win" .. i], C.meters["win" .. (i + 1)]
      for k, v in pairs(nxt) do s[k] = v end
      if C.position then C.position["pfMeter" .. i] = C.position["pfMeter" .. (i + 1)] end
    end
    if C.position then C.position["pfMeter" .. n] = nil end
    -- (the last window's settings stay for a later new window: never as a locked threat window)
    if C.meters["win" .. n] then C.meters["win" .. n].threatlock = "0" end
    local last = M.windows[n]
    if last.id == 2 and not last.free then M.SetDocked(last, false) end
    RemoveMovable(last)
    last:Hide()
    M.windows[n] = nil
    C.meters.windows = tostring(n - 1)
    M.RestyleAll()
  end

  -- in / out of combat: opacity, and hiding when the window says so
  -- (26 Nov 2026, Lo5t: after a /reload a meter shown in combat had the left chat's text over it until a relog)
  -- a free window always sits above the chat frames: their strata or MEDIUM, whichever is higher
  local ORDER = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
  function M.AboveChat(w)
    if not w.free then return end
    local top, lvl = "MEDIUM", 0
    for i = 1, (NUM_CHAT_WINDOWS or 7) do
      local cf = _G["ChatFrame" .. i]
      if cf and cf.GetFrameStrata and cf:IsShown() then
        local s = cf:GetFrameStrata()
        if (ORDER[s] or 0) > (ORDER[top] or 0) then top, lvl = s, 0 end
        if s == top then lvl = math.max(lvl, (cf:GetFrameLevel() or 0)) end
      end
    end
    local moved
    if w:GetFrameStrata() ~= top then w:SetFrameStrata(top) moved = true end
    if (w:GetFrameLevel() or 0) <= lvl then w:SetFrameLevel(lvl + 5) moved = true end
    -- (1.12: children keep their old strata / level - put them back on top)
    if moved then Lift(w) end
  end
  function M.CombatLook()
    local fighting = UnitAffectingCombat("player")
    for _, w in ipairs(M.windows) do
      local s = S(w)
      M.AboveChat(w)
      local a = tonumber(fighting and s.alpha or s.oocalpha) or 1
      local hide = (s.autohide == "outofcombat" and not fighting) or (s.autohide == "incombat" and fighting)
      if hide then a = 0 end
      w:SetAlpha(a)
      -- (a hidden window lets clicks through)
      if w.free then w:EnableMouse(not hide) end
    end
  end
  local combat = CreateFrame("Frame")
  combat:RegisterEvent("PLAYER_REGEN_DISABLED")
  combat:RegisterEvent("PLAYER_REGEN_ENABLED")
  combat:RegisterEvent("PLAYER_ENTERING_WORLD")
  combat:SetScript("OnEvent", function() M.CombatLook() end)

  -- docked windows go into the right chat, the others float
  if CanDock() and C.meters.shown ~= "1" then
    -- show the meters instead of the right chat the first time
    C.thirdparty.showmeter = "1"
    C.meters.shown = "1"
  end
  for _, win in ipairs(M.windows) do
    local key = KeyOf(win)
    win.free = not (CanDock() and C.thirdparty[key] and C.thirdparty[key].dock == "1") or nil
  end
  for _, win in ipairs(M.windows) do
    if win.free then Float(win) else Register(win) end
  end

  -- ---------------------------------------------------------------- show / hide all

  -- One button for all the meters (user, 24 Oct 2026: "just a button ... on
  -- screen and can be moved, pressing it shows ALL meters, pressing it again
  -- hides them"). C.meters.hidden keeps the state over a reload.
  function M.AnyShown()
    for _, w in ipairs(M.windows) do if w:IsShown() then return true end end
    return false
  end
  function M.ShowAll(on)
    C.meters.hidden = on and "0" or "1"
    for _, w in ipairs(M.windows) do
      if on then w:Show() w.Refresh(w) else w:Hide() end
    end
    if M.PaintToggle then M.PaintToggle() end
  end
  function M.ToggleAll() M.ShowAll(not M.AnyShown()) end

  local tb = CreateFrame("Button", "pfMeterToggle", UIParent)
  tb:SetWidth(32)
  tb:SetHeight(32)
  tb:SetFrameStrata("MEDIUM")
  tb:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -260, 40)
  tb:SetMovable(true)
  tb:SetClampedToScreen(true)
  CreateBackdrop(tb, nil, nil, .9)
  tb.icon = tb:CreateTexture(nil, "ARTWORK")
  tb.icon:SetTexture("Interface\\Icons\\Ability_Marksmanship")
  tb.icon:SetTexCoord(.08, .92, .08, .92)
  tb.icon:SetPoint("TOPLEFT", tb, "TOPLEFT", 2, -2)
  tb.icon:SetPoint("BOTTOMRIGHT", tb, "BOTTOMRIGHT", -2, 2)
  tb:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  tb:RegisterForDrag("LeftButton")
  tb:SetScript("OnClick", function()
    if arg1 == "RightButton" then
      local O = pfUI.octoui and pfUI.octoui.Options
      if O and O.Open then O:Open(T["Meters"]) end
      return
    end
    M.ToggleAll()
  end)
  -- Shift + drag moves it (layout mode moves it too)
  tb:SetScript("OnDragStart", function() if IsShiftKeyDown() then pfUI.api.DragStart(this) this.moving = true end end)
  tb:SetScript("OnDragStop", function()
    if this.moving then pfUI.api.DragStop(this) this.moving = nil SaveMovable(this) end
  end)
  tb:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_TOP")
    GameTooltip:AddLine(T["Meters"])
    GameTooltip:AddLine(M.AnyShown() and T["Click: hide all meters"] or T["Click: show all meters"], 1, 1, 1)
    GameTooltip:AddLine(T["Right-click: meter options"], .7, .7, .7)
    GameTooltip:AddLine(T["Shift + drag: move this button"], .7, .7, .7)
    GameTooltip:Show()
  end)
  tb:SetScript("OnLeave", function() GameTooltip:Hide() end)
  function M.PaintToggle()
    if M.AnyShown() then tb.icon:SetVertexColor(1, 1, 1) tb.icon:SetDesaturated(nil)
    else tb.icon:SetVertexColor(.6, .6, .6) tb.icon:SetDesaturated(1) end
  end
  if UpdateMovable then UpdateMovable(tb) end
  M.toggle = tb
  if C.meters.togglebtn == "0" then tb:Hide() end
  if C.meters.hidden == "1" then M.ShowAll(false) else M.PaintToggle() end

  -- the right chat window stood empty once the meters left it (user, 24 Oct
  -- 2026: "the black window is there remove it completely"): switched off
  -- once; its Loot & Spam tab goes into the left chat. Chat settings can
  -- switch it back on.
  if C.meters.rightchatoff ~= "1" and pfUI.chat and pfUI.chat.SetupRightChat and C.chat.right.enable == "1" then
    C.meters.rightchatoff = "1"
    pcall(function()
      pfUI.chat.SetupRightChat(false)
      if ChatFrame3 then
        ChatFrame3:SetParent(UIParent)
        local tab = _G["ChatFrame3Tab"]
        if tab then tab:SetParent(UIParent) end
        if FCF_DockFrame then FCF_DockFrame(ChatFrame3) end
        if FCF_DockUpdate then FCF_DockUpdate() end
      end
    end)
  end

  -- ---------------------------------------------------------------- old addons, instances

  local events = CreateFrame("Frame")
  events:RegisterEvent("PLAYER_ENTERING_WORLD")
  events:SetScript("OnEvent", function()
    -- (11 Nov 2026: ShaguDPS / TWThreat are offered to be turned off with every other add-on pfUI Octo already
    -- does, by modules\addoncompat.lua)

    -- entering an instance with old data: ask to reset (as Details! does)
    local inInstance = IsInInstance()
    local zone = GetRealZoneText()
    if inInstance and C.meters.resetask == "1" and zone ~= M.lastInstance and table.getn(M.history) > 0 then
      CreateQuestionDialog(string.format(T["Reset the meters for %s?"], zone or "?"), function() M.Reset() end)
    end
    if inInstance then M.lastInstance = zone end
  end)
end)
