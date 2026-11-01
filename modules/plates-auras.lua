pfUI:RegisterModule("plates-auras", "vanilla:tbc", function ()
  -- pfUI Octo nameplates, phase 2: Plater's auras (docs\plates-spec.md).
  --   row      debuffs (yours, crowd control, or all) then the enemy's buffs
  --            (important ones, or all) above the name: icon, timer, stacks,
  --            border by type (Magic blue, Curse purple, Disease brown,
  --            Poison green; important buffs gold)
  --   special  chosen spells as big icons above the row (CC, immunities...)
  --   ghost    your own debuffs missing on a mob fighting you, faded
  -- Data: SuperWoW's UnitDebuff / UnitBuff(guid, i) with spell ids (names by
  -- SpellInfo), pfUI's libdebuff for names it scans and your own debuffs'
  -- timers, ClassicAPI's C_UnitAuras.GetUnitAuras end times when it has them
  -- (unverified). Replaces pfUI's own debuff row while it is on.
  local P = pfUI.plates
  if not P then return end
  local S = C.plates
  local A = {}
  P.Auras = A

  local function Set(list)
    local out = {}
    for _, v in ipairs(list) do out[string.lower(v)] = true end
    return out
  end
  local function SetOf(str)
    local out = {}
    for _, v in pairs({ strsplit("#", str or "") }) do
      if v and v ~= "" then out[string.lower(v)] = true end
    end
    return out
  end

  -- crowd control, stuns, roots, silences on 1.12
  A.CC = Set({ "Polymorph", "Polymorph: Pig", "Polymorph: Turtle", "Sap", "Blind", "Gouge", "Kidney Shot", "Cheap Shot",
    "Hammer of Justice", "Repentance", "Fear", "Psychic Scream", "Howl of Terror", "Intimidating Shout", "Seduction",
    "Death Coil", "Hibernate", "Entangling Roots", "Frost Nova", "Freezing Trap Effect", "Scatter Shot", "Wyvern Sting",
    "Bash", "Pounce", "Feral Charge Effect", "Concussion Blow", "Charge Stun", "Intercept Stun", "Mace Stun Effect",
    "War Stomp", "Mind Control", "Shackle Undead", "Banish", "Sleep", "Counterspell - Silenced", "Silence",
    "Impact", "Blackout", "Improved Concussive Shot", "Starfire Stun", "Improved Hamstring", "Frostbite",
    "Spell Lock", "Garrote - Silence", "Kick - Silenced", "Reckless Charge", "Stun", "Net-o-Matic", "Tidal Charm" })
  -- buffs worth seeing on an enemy
  A.IMPORTANT = Set({ "Ice Block", "Divine Shield", "Blessing of Protection", "Divine Protection", "Blessing of Freedom",
    "Evasion", "Blade Flurry", "Adrenaline Rush", "Sprint", "Cold Blood", "Recklessness", "Shield Wall", "Retaliation",
    "Death Wish", "Berserker Rage", "Sweeping Strikes", "Arcane Power", "Combustion", "Presence of Mind", "Ice Barrier",
    "Mana Shield", "Power Infusion", "Inner Focus", "Power Word: Shield", "Fear Ward", "Barkskin", "Nature's Swiftness",
    "Innervate", "Dash", "Frenzied Regeneration", "Bestial Wrath", "Rapid Fire", "Elemental Mastery",
    "Grounding Totem Effect", "Free Action", "Living Action", "Will of the Forsaken", "Stoneform", "Perception",
    "Enrage", "Frenzy", "Berserk", "Spell Reflection", "Fire Ward", "Frost Ward", "Shadow Ward", "Divine Favor",
    "Hand of Freedom", "Blessing of Sacrifice", "Lay on Hands", "Unending Breath" })
  -- what each class usually keeps on a mob (the ghost list's "fill" button)
  A.GHOSTS = {
    WARLOCK = "Corruption#Curse of Agony#Immolate", PRIEST = "Shadow Word: Pain", DRUID = "Moonfire#Faerie Fire",
    HUNTER = "Serpent Sting#Hunter's Mark", ROGUE = "Rupture", WARRIOR = "Sunder Armor#Rend",
    PALADIN = "Judgement of Wisdom", SHAMAN = "Flame Shock", MAGE = "",
  }

  local TYPE = {
    Magic = { .2, .6, 1 }, Curse = { .6, 0, 1 }, Disease = { .6, .4, 0 }, Poison = { 0, .6, 0 },
    none = { .8, 0, 0 }, buff = { .25, .25, .25 }, important = { 1, .8, .2 }, ghost = { .5, .5, .5 },
  }
  A.TYPE = TYPE

  local special, ghost, black, white = {}, {}, {}, {}
  function A.ReadLists()
    special = SetOf(S.specialauras)
    ghost = SetOf(S.ghostauras)
    black = SetOf(C.nameplates.debuffs.blacklist)
    white = SetOf(C.nameplates.debuffs.whitelist)
  end

  -- ---------------------------------------------------------------- reading auras

  -- spellbook name -> icon (ghost auras need the icon of a spell you know)
  local bookIcons
  function A.BookIcon(name)
    if not bookIcons then
      bookIcons = {}
      local i = 1
      while i <= 1024 do -- (bounded, 1 Nov 2026)
        local n = GetSpellName(i, BOOKTYPE_SPELL)
        if not n then break end
        bookIcons[string.lower(n)] = GetSpellTexture(i, BOOKTYPE_SPELL)
        i = i + 1
      end
    end
    return bookIcons[string.lower(name or "")]
  end
  local book = CreateFrame("Frame")
  book:RegisterEvent("SPELLS_CHANGED")
  book:SetScript("OnEvent", function() bookIcons = nil end)

  -- your own debuffs' timers from pfUI's libdebuff (no tooltip scan)
  local function OwnTime(unitname, unitlevel, effect)
    local objs = libdebuff and libdebuff.objects and libdebuff.objects[unitname]
    local data = objs and (objs[unitlevel] or objs[0])
    local d = data and data[effect]
    if d and d.duration and d.start and d.duration + d.start > GetTime() then
      return d.duration, d.start + d.duration, d.caster
    end
  end

  -- ClassicAPI's list: spell id -> { duration, ends, mine } (when it has them)
  local function ClassicTimes(unit)
    if not (C_UnitAuras and C_UnitAuras.GetUnitAuras) then return end
    local out
    local _, me = UnitExists("player")
    for _, filter in ipairs({ "HARMFUL", "HELPFUL" }) do
      local ok, list = pcall(C_UnitAuras.GetUnitAuras, unit, filter)
      if ok and type(list) == "table" then
        for _, a in ipairs(list) do
          if type(a) == "table" and a.spellId and a.expirationTime and a.expirationTime > GetTime() then
            out = out or {}
            out[a.spellId] = { duration = a.duration, ends = a.expirationTime, mine = me and a.sourceGUID == me }
          end
        end
      end
    end
    return out
  end

  -- one aura list for a unit: { name, icon, stacks, kind, dtype, ends, duration, mine, cc, important }
  -- kind = "debuff" | "buff". o.acache keeps scanned debuff names per slot.
  function A.Read(o, unit)
    local list = {}
    local unitname, unitlevel = UnitName(unit), UnitLevel(unit)
    local capi = ClassicTimes(unit)
    o.acache = o.acache or {}
    local count = 0
    for i = 1, 16 do
      local tex, stacks, dtype, sid = UnitDebuff(unit, i)
      if not tex then break end
      count = i
      local c = o.acache[i]
      if not c or c.tex ~= tex or c.sid ~= sid then
        local name = sid and SpellInfo and SpellInfo(sid)
        if not name and libdebuff then name = libdebuff:UnitDebuff(unit, i) end
        c = { tex = tex, sid = sid, name = name or "" }
        o.acache[i] = c
      end
      local e = { name = c.name, icon = tex, stacks = stacks, kind = "debuff", dtype = dtype, sid = sid }
      local dur, ends, caster = OwnTime(unitname, unitlevel, c.name)
      e.duration, e.ends, e.mine = dur, ends, caster == "player"
      local t = sid and capi and capi[sid]
      if t then
        e.duration, e.ends = t.duration or e.duration, t.ends
        if t.mine then e.mine = true end
      end
      e.cc = A.CC[string.lower(c.name)]
      table.insert(list, e)
    end
    for i = count + 1, 16 do o.acache[i] = nil end
    for i = 1, 32 do
      local tex, stacks, sid = UnitBuff(unit, i)
      if not tex then break end
      local name = sid and SpellInfo and SpellInfo(sid) or ""
      local e = { name = name, icon = tex, stacks = stacks, kind = "buff", sid = sid }
      local t = sid and capi and capi[sid]
      if t then e.duration, e.ends = t.duration, t.ends end
      e.important = A.IMPORTANT[string.lower(name)]
      table.insert(list, e)
    end
    return list
  end

  -- What shows where: the row (in order: your debuffs, crowd control, other
  -- debuffs, buffs) and the special icons. enemy: the plate is hostile.
  function A.Pick(list, enemy)
    local row, big = {}, {}
    local dmode, bmode = S.debuffshow or "mine_cc", S.buffshow or "important"
    local filter = C.nameplates.debuffs.filter
    local rank = {}
    for _, e in ipairs(list) do
      local lname = string.lower(e.name or "")
      local keep
      if S.specialon == "1" and special[lname] then
        table.insert(big, e)
      elseif e.kind == "debuff" then
        if dmode == "all" then keep = true
        elseif dmode == "mine" then keep = e.mine
        else keep = e.mine or e.cc end
        if filter == "blacklist" and black[lname] then keep = nil end
        if filter == "whitelist" and not white[lname] then keep = nil end
        rank[e] = e.mine and 1 or (e.cc and 2 or 3)
      elseif enemy then
        if bmode == "all" then keep = true elseif bmode == "important" then keep = e.important end
        rank[e] = e.important and 4 or 5
      end
      if keep then table.insert(row, e) end
    end
    -- stable order: rank, then as the game lists them
    local pos = {}
    for i, e in ipairs(row) do pos[e] = i end
    table.sort(row, function(a, b)
      if rank[a] ~= rank[b] then return rank[a] < rank[b] end
      return pos[a] < pos[b]
    end)
    return row, big
  end

  -- your ghost auras missing from a list (icons from your spellbook)
  function A.Ghosts(list)
    local have, out = {}, {}
    for _, e in ipairs(list) do if e.kind == "debuff" then have[string.lower(e.name or "")] = true end end
    for name in pairs(ghost) do
      if not have[name] then
        local icon = A.BookIcon(name)
        if icon then table.insert(out, { name = name, icon = icon, kind = "ghost" }) end
      end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
  end

  -- ---------------------------------------------------------------- icons

  local WHITE = "Interface\\Buttons\\WHITE8X8"

  local function Icon(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1, insets = { left = 0, right = 0, top = 0, bottom = 0 } })
    f:SetBackdropColor(0, 0, 0, 1)
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    f.tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    f.timer = f:CreateFontString(nil, "OVERLAY")
    f.timer:SetPoint("CENTER", f, "CENTER", 0, 0)
    -- stacks in the top right corner, clear of the timer in the middle
    f.stacks = f:CreateFontString(nil, "OVERLAY")
    f.stacks:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 3)
    f:Hide()
    return f
  end

  -- size: the automatic timer size (from the icon); the sliders win when set
  local function Fonts(f, size)
    local font = (S.font and S.font ~= "") and S.font or pfUI.font_unit
    local ts, ss = tonumber(S.auratimersize) or 0, tonumber(S.aurastacksize) or 0
    f.timer:SetFont(font, ts > 0 and ts or math.max(7, size), "OUTLINE")
    f.stacks:SetFont(font, ss > 0 and ss or math.max(6, size - 2), "OUTLINE")
    f.stacks:SetTextColor(.6, .85, 1)
  end

  -- crop the square icon to the frame's shape (wider than tall: cut top / bottom)
  local function Crop(f, w, h)
    local cut = (w > h) and (1 - h / w) / 2 or 0
    f.tex:SetTexCoord(.08, .92, .08 + cut * .84, .92 - cut * .84)
  end

  function A.Build(plate, o)
    o.arow = CreateFrame("Frame", nil, plate)
    o.arow:SetWidth(1)
    o.arow:SetHeight(1)
    o.abig = CreateFrame("Frame", nil, plate)
    o.abig:SetWidth(1)
    o.abig:SetHeight(1)
    o.aicons, o.bicons = {}, {}
  end

  -- (a preview's icons can be clicked: they open the Auras page)
  local function Get(pool, parent, i, what)
    if not pool[i] then
      pool[i] = Icon(parent)
      local game = parent:GetParent() and parent:GetParent().parent
      if game and game.preview then P.Hot(game, pool[i], what, 34) end
    end
    return pool[i]
  end

  -- place n icons of w x h in rows of `per`, growing from the anchor
  -- gap between icons, rowgap between rows (user, 22 Oct 2026: the auras need
  -- a gap setting)
  local function Layout(pool, n, w, h, per, grow, gap, rowgap)
    rowgap = rowgap or gap
    for i = 1, n do
      local f = pool[i]
      local r = math.floor((i - 1) / per)
      local c = i - 1 - r * per
      local inRow = math.min(per, n - r * per)
      local x
      if grow == "left" then x = -c * (w + gap) - w
      elseif grow == "right" then x = c * (w + gap)
      else x = (c - inRow / 2) * (w + gap) + gap / 2 end
      f:ClearAllPoints()
      f:SetPoint("BOTTOMLEFT", f:GetParent(), "BOTTOM", x, r * (h + rowgap))
      f:SetWidth(w)
      f:SetHeight(h)
      Crop(f, w, h)
    end
  end

  local function Paint(f, e)
    f.tex:SetTexture(e.icon)
    local c = TYPE.none
    if e.kind == "ghost" then c = TYPE.ghost
    elseif e.kind == "buff" then c = e.important and TYPE.important or TYPE.buff
    elseif e.dtype and TYPE[e.dtype] then c = TYPE[e.dtype] end
    if S.auraborder ~= "1" and e.kind == "debuff" then c = TYPE.buff end
    f:SetBackdropBorderColor(c[1], c[2], c[3], 1)
    if f.tex.SetDesaturated then f.tex:SetDesaturated(e.kind == "ghost" and 1 or nil) end
    f:SetAlpha(e.kind == "ghost" and (tonumber(S.ghostalpha) or .5) or 1)
    if e.stacks and e.stacks > 1 and S.aurastacks == "1" then f.stacks:SetText(e.stacks) else f.stacks:SetText("") end
    f.ends = (S.auratimer == "1") and e.ends or nil
    if not f.ends then f.timer:SetText("") end
    f.last = nil
    f:Show()
  end

  function A.Configure(plate, o)
    if not o.arow then A.Build(plate, o) end
    A.ReadLists()
    local off = tonumber(S.auraoffset) or 2
    o.arow:ClearAllPoints()
    local nx, ny = P.NameOff()
    o.arow:SetPoint("BOTTOM", plate.name, "TOP", (tonumber(S.auraoffx) or 0) - nx, off - ny)
    o.abig:ClearAllPoints()
    o.abig:SetPoint("BOTTOM", o.arow, "TOP", 0, 2)
    o.aw, o.ah = tonumber(S.aurawidth) or 20, tonumber(S.auraheight) or 16
    o.bs = tonumber(S.specialsize) or 28
    o.agap, o.arowgap, o.bgap = tonumber(S.auragap) or 2, tonumber(S.auragaprow) or 2, tonumber(S.specialgap) or 3
    for _, f in ipairs(o.aicons) do Fonts(f, math.floor(o.ah * .6)) end
    for _, f in ipairs(o.bicons) do Fonts(f, math.floor(o.bs * .45)) end
    o.akey = nil
    if S.auras ~= "1" then A.Off(o) end
  end

  function A.Off(o)
    if not o.arow then return end
    for _, f in ipairs(o.aicons) do f:Hide() end
    for _, f in ipairs(o.bicons) do f:Hide() end
  end

  -- (re)draws the icons; called a few times a second per plate
  function A.Update(plate, o, unit, enemy)
    if not o.arow then A.Build(plate, o) A.Configure(plate, o) end
    if S.auras ~= "1" or not plate.health:IsShown() then A.Off(o) return end
    local pv = plate.parent and plate.parent.preview
    local list
    if pv and pv.auras then
      list = pv.auras
    elseif P.Testing() and not pv and enemy then
      list = A.TestAuras()
    elseif unit and UnitExists(unit) then
      list = A.Read(o, unit)
    else
      list = {}
    end
    local row, big = A.Pick(list, enemy)
    -- ghost auras: your missing debuffs on a mob fighting you
    if S.ghoston == "1" and enemy and ((pv and pv.ghost) or (unit and not pv and UnitAffectingCombat(unit) and UnitAffectingCombat("player"))) then
      for _, g in ipairs(A.Ghosts(list)) do table.insert(row, g) end
    end
    local per, rows = tonumber(S.auraperrow) or 6, tonumber(S.aurarows) or 2
    local n = math.min(table.getn(row), per * rows)
    for i = 1, n do
      local f = Get(o.aicons, o.arow, i, "auras")
      if not f.fonted then Fonts(f, math.floor(o.ah * .6)) f.fonted = true end
      Paint(f, row[i])
    end
    for i = n + 1, table.getn(o.aicons) do o.aicons[i]:Hide() end
    Layout(o.aicons, n, o.aw, o.ah, per, S.auragrow or "center", o.agap or 2, o.arowgap)
    -- the special row sits on top of the normal rows that are in use
    local used = math.ceil(n / per)
    o.abig:ClearAllPoints()
    -- from the name, where the rows sit by default: moving the rows (or the
    -- name) leaves the big icons where they are
    local nx, ny = P.NameOff()
    o.abig:SetPoint("BOTTOM", plate.name, "TOP", (tonumber(S.specialoffx) or 0) - nx,
      2 + used * (o.ah + (o.arowgap or 2)) + (o.bgap or 3) + (tonumber(S.specialoffy) or 0) - ny)
    local m = (S.specialon == "1") and math.min(table.getn(big), 6) or 0
    for i = 1, m do
      local f = Get(o.bicons, o.abig, i, "special")
      if not f.fonted then Fonts(f, math.floor(o.bs * .45)) f.fonted = true end
      Paint(f, big[i])
      local ac = { GetAccentColor() }
      f:SetBackdropBorderColor(ac[1] or 1, ac[2] or 1, ac[3] or 1, 1)
    end
    for i = m + 1, table.getn(o.bicons) do o.bicons[i]:Hide() end
    Layout(o.bicons, m, o.bs, o.bs, 6, "center", o.bgap or 3)
    o.ashown = n + m
  end

  -- timers: whole seconds over 10, tenths under, minutes over 60; red under 3 s
  function A.Timer(left)
    if left >= 60 then return math.ceil(left / 60) .. "m", 1, 1, 1 end
    if left >= 10 then return tostring(math.floor(left)), 1, 1, 1 end
    if left >= 3 then return tostring(math.floor(left)), 1, .85, .2 end
    return string.format("%.1f", left), 1, .25, .2
  end

  function A.Tick(plate, o, now)
    if not o.ashown or o.ashown == 0 then return end
    -- the two pools without a new table each frame
    for n = 1, 2 do
      local pool = n == 1 and o.aicons or o.bicons
      for _, f in ipairs(pool or {}) do
        if f.ends and f:IsShown() then
          local left = f.ends - now
          if left <= 0 then
            f.timer:SetText("")
          else
            local text, r, g, b = A.Timer(left)
            if text ~= f.last then
              f.timer:SetText(text)
              f.timer:SetTextColor(r, g, b)
              f.last = text
            end
          end
        end
      end
    end
  end

  -- pretend auras for the preview and "Test on real nameplates"
  function A.TestAuras()
    local now = GetTime()
    local t = math.mod(now, 30)
    return {
      { name = "Corruption", icon = "Interface\\Icons\\Spell_Shadow_AbominationExplosion", kind = "debuff", dtype = "Magic", mine = true, ends = now + 18 - math.mod(t, 18) },
      { name = "Sunder Armor", icon = "Interface\\Icons\\Ability_Warrior_Sunder", kind = "debuff", stacks = 5, mine = true, ends = now + 30 - t },
      { name = "Polymorph", icon = "Interface\\Icons\\Spell_Nature_Polymorph", kind = "debuff", dtype = "Magic", cc = true, ends = now + 8 - math.mod(t, 8) },
      { name = "Curse of Agony", icon = "Interface\\Icons\\Spell_Shadow_CurseOfSargeras", kind = "debuff", dtype = "Curse", mine = true, ends = now + 24 - math.mod(t, 24) },
      { name = "Ice Block", icon = "Interface\\Icons\\Spell_Frost_Frost", kind = "buff", important = true, ends = now + 10 - math.mod(t, 10) },
      { name = "Power Word: Shield", icon = "Interface\\Icons\\Spell_Holy_PowerWordShield", kind = "buff", important = true, ends = now + 30 - t },
    }
  end

  -- once: the special icons' old default (28) grows to the new one (32)
  if S.auraver ~= "2" then
    if S.specialsize == "28" then S.specialsize = "32" end
    S.auraver = "2"
  end

  A.ReadLists()
end)
