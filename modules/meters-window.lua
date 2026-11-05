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

  -- the rows a window shows: { name, value, class, text, actor }
  function M.Rows(modekey, segkey)
    local rows = {}
    local mode = MODE[modekey] or MODE.damage

    if mode.key == "threat" then
      local TH = M.threat
      if not TH or not TH.list then return rows end
      local top = 1
      -- (bars glide: TH.shown holds the value on its way to e.perc)
      local function Shown(e) return (TH.shown and TH.shown[e.name]) or e.perc end
      for _, e in ipairs(TH.list) do if Shown(e) > top then top = Shown(e) end end
      for _, e in ipairs(TH.list) do
        local w = M.Who(e.name)
        table.insert(rows, { name = e.name, value = Shown(e), max = top, class = w and w.class,
                             text = floor(e.perc) .. "%", extra = Num(e.threat), tank = e.tank })
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
  menu:SetFrameStrata("FULLSCREEN_DIALOG")
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
    b:SetScript("OnEnter", function() if not this.win.preview then Tooltip(this) end end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function()
      if this.win.preview then
        if M.PreviewClick then M.PreviewClick(this.win, "bars") end
        return
      end
      if this.row then M.ShowDetails(this.win, this.row) end
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

  -- a free window dropped near another one sits flush against it (side by
  -- side with the tops lined up, or one under the other)
  function M.Snap(win)
    local L, T, R, B = win:GetLeft(), win:GetTop(), win:GetRight(), win:GetBottom()
    if not (L and T) then return end
    local x, y = L, T
    local near = 12
    for _, o in ipairs(M.windows) do
      if o ~= win and o:IsShown() and o:GetLeft() then
        local ol, ot, orr, ob = o:GetLeft(), o:GetTop(), o:GetRight(), o:GetBottom()
        local overlapY = B < ot and T > ob
        local overlapX = L < orr and R > ol
        -- side by side: flush, and the tops lined up when close
        local side
        if overlapY and math.abs(L - orr) < near then x, side = orr + 1, true end
        if overlapY and math.abs(R - ol) < near then x, side = ol - (R - L) - 1, true end
        if side and math.abs(T - ot) < near then y = ot end
        -- one under the other: flush, and the left edges lined up when close
        local stack
        if overlapX and math.abs(B - ot) < near then y, stack = ot + (T - B) + 1, true end
        if overlapX and math.abs(T - ob) < near then y, stack = ob - 1, true end
        if stack and math.abs(L - ol) < near then x = ol end
      end
    end
    if x ~= L or y ~= T then
      win:ClearAllPoints()
      win:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
      SaveMovable(win)
    end
    return x ~= L or y ~= T
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
      for i, r in ipairs(win.rowsShown or {}) do
        if r.name == me or (win.preview and i == 2) then return "#" .. i .. "  " .. (r.text or "") end
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
    if win.mode == "threat" then
      win.seg:SetText("")
    else
      win.seg:SetText(SegmentName(win.segment, win))
    end

    -- (test bars: every window shows the made-up fight; with the test fight
    -- built (meters-test.lua) its real rows, so every bar opens a breakdown)
    local testing = M.Testing()
    local rows
    if win.preview or (testing and not M.testSeg) then
      rows = M.SampleRows(win.mode)
    else
      rows = M.Rows(win.mode, win.segment)
    end
    local height = tonumber(s.barheight) or 16
    local gap = tonumber(s.spacing) or 1
    local top = s.title ~= "0" and ((tonumber(s.titleheight) or 18) + 2) or 2
    local statush = s.status == "1" and 14 or 0
    local room = win:GetHeight() - top - 2 - statush
    local visible = max(1, floor((room + gap) / (height + gap)))
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
    for i = 1, visible do
      local row = rows[i + win.offset]
      local b = Bar(win, i)
      if row then
        b:ClearAllPoints()
        if up then
          b:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 2, 2 + statush + (i - 1) * (height + gap))
          b:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -2, 2 + statush + (i - 1) * (height + gap))
        else
          b:SetPoint("TOPLEFT", win, "TOPLEFT", 2, -top - (i - 1) * (height + gap))
          b:SetPoint("TOPRIGHT", win, "TOPRIGHT", -2, -top - (i - 1) * (height + gap))
        end
        b:SetHeight(height)
        b.row = row
        b.bar:SetStatusBarTexture(s.texture)
        b.bar:SetValue(row.max and row.max > 0 and row.value / row.max or 0)
        b.bg:SetTexture(bgr, bgg, bgb, bga)
        local color = row.class and RAID_CLASS_COLORS[row.class]
        local r, g, bb = tr, tg, tb
        if color and s.colorby ~= "fixed" then r, g, bb = color.r, color.g, color.b end
        if win.mode == "threat" then
          -- you: green -> yellow -> red towards the pull point; the tank: dark red
          local share = row.name == me and M.threat and M.threat.Mine()
          if row.tank then r, g, bb = .6, .15, .15
          elseif share then r, g, bb = min(1, share * 2), min(1, 2 - share * 2), .1 end
        end
        -- your own bar: a border or a brighter bar (25 Oct 2026)
        local mine = row.name == me and (s.selfmark == "border" or s.selfmark == "tint")
        if mine and s.selfmark == "tint" then
          local sr, sg, sb = Col(s.selfcolor, "1,0.82,0.2,1")
          r, g, bb = sr, sg, sb
        end
        b.bar:SetStatusBarColor(r, g, bb, balpha)
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
        b.left:SetText((s.rank ~= "0" and (Hex(s.rankcolor, "0.67,0.67,0.67,1") .. (i + win.offset) .. ".|r ") or "") .. row.name)
        b.right:SetText(RightText(s, row))
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
    -- (with no saved spot this is the window's default from now on: pfUI
    -- keeps the first spot it saw and layout mode put a reset window back
    -- there - off the screen, 24 Oct 2026)
    UpdateMovable(win, not saved)
    if S(win).lock == "1" then win.grip:Hide() else win.grip:Show() end
    if C.meters.hidden == "1" then win:Hide() else win:Show() end
    Refresh(win)
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
        pfUI.api.DragStart(win)
        win.moving = true
      end
    end
    local function DragStop()
      if win.moving then
        pfUI.api.DragStop(win)
        win.moving = nil
        if C.meters.snap ~= "0" and M.Snap then M.Snap(win) end
        SaveMovable(win)
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
      SaveMovable(win)
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
    local last = M.windows[n]
    if last.id == 2 and not last.free then M.SetDocked(last, false) end
    RemoveMovable(last)
    last:Hide()
    M.windows[n] = nil
    C.meters.windows = tostring(n - 1)
    M.RestyleAll()
  end

  -- in / out of combat: opacity, and hiding when the window says so
  function M.CombatLook()
    local fighting = UnitAffectingCombat("player")
    for _, w in ipairs(M.windows) do
      local s = S(w)
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
    -- offer to turn off the addons the meters replace
    local old = {}
    if IsAddOnLoaded("ShaguDPS") then table.insert(old, "ShaguDPS") end
    if IsAddOnLoaded("TWThreat") then table.insert(old, "TWThreat") end
    if table.getn(old) > 0 and C.meters.asked ~= "1" then
      C.meters.asked = "1"
      CreateQuestionDialog(string.format(T["pfUI Octo has its own damage and threat meters now (in the right chat panel).\n\nTurn off %s? The UI reloads."], table.concat(old, " + ")),
        function()
          for _, name in ipairs(old) do DisableAddOn(name) end
          ReloadUI()
        end)
    end

    -- entering an instance with old data: ask to reset (as Details! does)
    local inInstance = IsInInstance()
    local zone = GetRealZoneText()
    if inInstance and C.meters.resetask == "1" and zone ~= M.lastInstance and table.getn(M.history) > 0 then
      CreateQuestionDialog(string.format(T["Reset the meters for %s?"], zone or "?"), function() M.Reset() end)
    end
    if inInstance then M.lastInstance = zone end
  end)
end)
