pfUI:RegisterModule("dots", "vanilla", function ()
  -- pfUI Octo :: OctoDoTs (16 Nov 2026; user: "merge cursive into our pfui make our own version ...
  -- better faster stronger use any DLLs needed ... standalone and enabled/disabled inside pfUI ... its own
  -- section on the left called OctoDoTs", then with screenshots of Cursive's six tabs: "im sure we can
  -- do alot better but these should still be there"). Cursive-Raid (MIT: Kirchlive / Teto, after Shagu's
  -- Cursive) is the model: one row per enemy with its health and the debuffs on it - yours and the
  -- raid's - and a multi-DoT command. Written fresh on pfUI's frames; Cursive's spell tables are turned
  -- into modules\dots-data.lua by tools\Make-DotsData.ps1; its two sounds and stripe texture are in
  -- img\dots. Every Cursive option has a home (dots-options.lua: General, Raid, Class, Display, Filter,
  -- Profiles).
  --
  -- What is better than Cursive:
  --   * Real timers. ClassicAPI's C_UnitAuras.GetUnitAuras(guid) gives every debuff's true end time and
  --     its caster's GUID (talents, haste, combo points, refreshes included). Cursive guessed them from
  --     duration tables, tooltip scans and hand-made rules (Dark Harvest, Conflagrate, Ferocious Bite...).
  --     Without ClassicAPI: SuperWoW's UnitDebuff(guid) + UNIT_CASTEVENT (anyone's cast, anyone's target)
  --     and the data file's durations, as Cursive. Without SuperWoW: your target only, pfUI's libdebuff.
  --   * Every DoT of every class is "yours" by its caster - no per-class lists to keep up.
  --   * Mobs come from the target, mouseover, nameplates, anyone's casts, UNIT_COMBAT and what the group
  --     is targeting (raidNtarget, once a second); they leave when dead, gone or 300 yd away.
  --   * Auras are read only for the mobs that get a row, at C.dots.rate (5 a second); time texts every
  --     0.1 s from those.
  --   * /dot cast <spell> spreads a DoT (the best mob without yours), and /cursive multicurse / curse /
  --     target keep working for people's old Cursive macros while Cursive itself is off.
  -- Settings C.dots (api\config.lua); profiles per account in pfUI_cache.dotprofiles.
  local D = { units = {}, list = {}, rows = {}, cast = {}, seen = {}, pending = {}, played = {}, maxarmor = {},
              icons = {}, names = {}, classes = {}, n = 0 }
  pfUI.dots = D
  local DATA = pfUI.dotsData or { raid = {}, spells = {} }
  D.DATA = DATA
  local lc = pfUI.api.libclient
  local MAXICONS, MAXUNITS, FAR, OTHERMAX = 18, 60, 300, 6
  D.MAXICONS = MAXICONS
  D.IMG = "Interface\\AddOns\\pfUI\\img\\dots\\"

  local function S() return C.dots end
  local function On(k) return C.dots[k] == "1" end
  local function Num(k, d) return tonumber(C.dots[k]) or d end
  local function Lower(s) return string.lower(string.gsub(s or "", "%s*%(.-%)%s*$", "")) end
  D.Lower = Lower

  -- ---------------------------------------------------------------- the client

  function D.SuperWoW() return SUPERWOW_VERSION and true or nil end
  function D.Classic()
    local ca = _G.C_UnitAuras
    return ca and ca.GetUnitAuras and true or nil
  end
  local function Guid(unit)
    if not unit then return end
    if string.find(unit, "^0x") then return unit end
    local ok, e, g = pcall(UnitExists, unit)
    if ok and e and type(g) == "string" and string.find(g, "^0x") then return g end
    if lc and lc.GUID then
      g = lc.GUID(unit)
      if type(g) == "string" and string.find(g, "^0x") then return g end
    end
  end
  D.Guid = Guid
  function D.Me()
    if not D.me then D.me = Guid("player") end
    return D.me
  end
  local function Safe(fn, a, b)
    local ok, r = pcall(fn, a, b)
    if ok then return r end
  end
  -- empty a list for reuse. Lua 5.0 (the game) keeps the length table.insert set even after
  -- every entry is nil'd, so the next inserts went after a run of holes and table.sort read
  -- them ("dots.lua: attempt to index local `a'", 16 Nov 2026). table.setn puts it back to 0;
  -- 5.1 has no working setn, and there the nil'd list is already empty.
  local SETN = table.setn and pcall(table.setn, {}, 0) and table.setn
  local function Wipe(t)
    for i = table.getn(t), 1, -1 do t[i] = nil end
    if SETN then SETN(t, 0) end
  end
  D.Wipe = Wipe

  -- raid debuffs by spell id
  D.RAIDID, D.RAIDKEY = {}, {}
  for _, r in ipairs(DATA.raid) do
    D.RAIDKEY[r.key] = r
    for _, id in ipairs(r.ids) do D.RAIDID[id] = r end
  end
  -- is a raid debuff watched? (nil in C.dots.raid = the data's own choice)
  function D.Watched(r)
    if not r or not r.key then return end
    local v = C.dots.raid and C.dots.raid[r.key]
    if v == nil or v == "" then return r.raid end
    return v == "1"
  end
  function D.SetWatched(key, on)
    if type(C.dots.raid) ~= "table" then C.dots.raid = {} end
    C.dots.raid[key] = on and "1" or "0"
    D.dirty = true
  end
  function D.SpellName(id)
    if not id then return end
    if D.names[id] then return D.names[id] end
    local n
    if _G.SpellInfo then
      local ok, name = pcall(_G.SpellInfo, id)
      if ok and type(name) == "string" and name ~= "" then n = name end
    end
    if not n and DATA.spells[id] then n = DATA.spells[id][1] end
    if not n and D.RAIDID[id] then n = D.RAIDID[id].name end
    D.names[id] = n
    return n
  end
  -- (fallback icons when no DLL can name a spell's icon: the raid debuffs in the options)
  D.ICONS = {
    sunderarmor = "Ability_Warrior_Sunder", exposearmor = "Ability_Warrior_Riposte", faeriefire = "Spell_Nature_FaerieFire",
    curseofrecklessness = "Spell_Shadow_UnholyStrength", firevulnerability = "Spell_Fire_SoulBurn", winterschill = "Spell_Frost_ChillingBlast",
    shadowvulnerability = "Spell_Shadow_ShadowBolt", shadowweaving = "Spell_Shadow_BlackPlague", curseoftheelements = "Spell_Shadow_ChillTouch",
    curseofshadow = "Spell_Shadow_CurseOfAchimonde", thunderfury = "Spell_Nature_Cyclone", demoshout = "Ability_Warrior_WarCry",
    thunderclap = "Spell_Nature_ThunderClap", mortalstrike = "Ability_Warrior_SavageBlow", demoroar = "Ability_Druid_DemoralizingRoar",
    huntersmark = "Ability_Hunter_SniperShot", polymorph = "Spell_Nature_Polymorph", sap = "Ability_Sap", banish = "Spell_Shadow_Cripple",
    fear = "Spell_Shadow_Possession", curseoftongues = "Spell_Shadow_CurseOfTounges", curseofweakness = "Spell_Shadow_CurseOfMannoroth",
    judgementofwisdom = "Spell_Holy_RighteousnessAura", judgementoflight = "Spell_Holy_HealingAura", judgementofthecrusader = "Spell_Holy_HolySmite",
    hammerofjustice = "Spell_Holy_SealOfMight", woundpoison = "INV_Misc_Herb_16", ignite = "Spell_Fire_Incinerate",
  }
  function D.SpellIcon(id, key)
    local tex
    if id then
      if D.icons[id] ~= nil then tex = D.icons[id] or nil
      else
        tex = lc and lc.SpellIcon and lc.SpellIcon(id)
        if type(tex) ~= "string" or string.find(tex, "QuestionMark") then tex = nil end
        D.icons[id] = tex or false
      end
    end
    if not tex and key and D.ICONS[key] then tex = "Interface\\Icons\\" .. D.ICONS[key] end
    return tex
  end
  function D.ReadHide()
    D.hide = {}
    for part in string.gfind(C.dots.hide or "", "[^,]+") do
      local n = Lower(string.gsub(part, "^%s*(.-)%s*$", "%1"))
      if n ~= "" then D.hide[n] = true end
    end
    -- the raid order: key -> place
    D.rorder = {}
    if type(C.dots.raidorder) == "table" then
      for i, k in ipairs(C.dots.raidorder) do D.rorder[k] = i end
    end
  end
  -- the raid debuff keys in the picked order (unknown ones last, in the data's order)
  function D.RaidOrder()
    local out, seen = {}, {}
    if type(C.dots.raidorder) == "table" then
      for _, k in ipairs(C.dots.raidorder) do
        if D.RAIDKEY[k] and not seen[k] then table.insert(out, k) seen[k] = true end
      end
    end
    for _, r in ipairs(DATA.raid) do
      if not seen[r.key] then table.insert(out, r.key) end
    end
    return out
  end
  function D.MoveRaid(key, by)
    local list = D.RaidOrder()
    for i, k in ipairs(list) do
      if k == key then
        local j = math.max(1, math.min(table.getn(list), i + by))
        table.remove(list, i)
        table.insert(list, j, key)
        break
      end
    end
    C.dots.raidorder = list
    D.ReadHide()
  end

  -- the ignore list (names, or Lua patterns with "Use patterns")
  function D.Ignored(name)
    if C.dots.ignored ~= "1" or not name or type(C.dots.ignore) ~= "table" then return end
    local n = string.lower(name)
    for _, x in ipairs(C.dots.ignore) do
      local p = string.lower(x)
      if C.dots.regex == "1" then
        local ok, hit = pcall(string.find, n, p)
        if ok and hit then return true end
      elseif p == n then return true end
    end
  end
  function D.AddIgnore(name)
    if not name or name == "" then return end
    if type(C.dots.ignore) ~= "table" then C.dots.ignore = {} end
    for _, x in ipairs(C.dots.ignore) do if string.lower(x) == string.lower(name) then return end end
    table.insert(C.dots.ignore, name)
    D.dirty = true
  end

  -- ---------------------------------------------------------------- the mobs

  function D.Add(unit)
    if not D.SuperWoW() then return end
    local g = Guid(unit)
    if not g then return end
    local u = D.units[g]
    local now = GetTime()
    if u then u.seen = now return u end
    if D.n >= MAXUNITS then return end
    local ok, dead = pcall(UnitIsDead, g)
    if ok and dead then return end
    u = { guid = g, added = now, seen = now, auras = {}, na = 0 }
    D.units[g] = u
    D.n = D.n + 1
    D.dirty = true
    return u
  end
  function D.Remove(g)
    if D.units[g] then
      D.units[g] = nil
      D.n = math.max(0, D.n - 1)
    end
    D.cast[g], D.seen[g], D.maxarmor[g] = nil, nil, nil
    -- (and its "expiring" sound marks: never emptied before, one per mob and DoT)
    local n = string.len(g)
    for k in pairs(D.played) do if string.sub(k, 1, n) == g then D.played[k] = nil end end
    if D.place then D.place[g] = nil end
    D.dirty = true
  end
  function D.Clear()
    for g in pairs(D.units) do D.Remove(g) end
    D.n = 0
  end
  function D.Distance(g)
    local d = lc and lc.Distance and lc.Distance(g)
    if not d and _G.UnitXP then
      local ok, x = pcall(_G.UnitXP, "distanceBetween", "player", g)
      if ok and type(x) == "number" then d = x end
    end
    return d
  end
  -- dead, gone or far away mobs leave (once a second)
  function D.Evict()
    local now = GetTime()
    local tg = Guid("target")
    for g, u in pairs(D.units) do
      if g ~= tg and g ~= "target" then
        local ok, e = pcall(UnitExists, g)
        local okd, dead = pcall(UnitIsDead, g)
        local far
        if ok and e then
          u.dist = D.Distance(g)
          far = u.dist and u.dist > FAR
        end
        if not (ok and e) or (okd and dead) or far or now - u.seen > 600 then D.Remove(g) end
      end
    end
  end
  -- what the group is fighting: everyone's target (once a second)
  function D.ScanGroup()
    local n = GetNumRaidMembers and GetNumRaidMembers() or 0
    local pre, k = "raid", n
    if n == 0 then pre, k = "party", (GetNumPartyMembers and GetNumPartyMembers() or 0) end
    for i = 1, k do
      local t = pre .. i .. "target"
      if UnitExists(t) and UnitCanAttack("player", t) and UnitAffectingCombat(t) then D.Add(t) end
    end
    if UnitExists("pettarget") and UnitCanAttack("player", "pettarget") then D.Add("pettarget") end
  end

  -- ---------------------------------------------------------------- reading a mob's debuffs

  -- spell reflect buffs on mobs (Cursive's list): faded rows
  D.REFLECT = { [22067] = "All", [20619] = "All", [13022] = "Fire/Arcane", [19595] = "Shadow/Frost", [460856] = "All" }
  -- one aura of a mob, reused: { name, icon, stacks, ends, dur, kind = mine|raid|other|missing, id, caster, key, t }
  local function Slot(u)
    u.na = u.na + 1
    local a = u.auras[u.na]
    if not a then
      a = {}
      u.auras[u.na] = a
    end
    a.name, a.icon, a.stacks, a.ends, a.dur, a.kind, a.id, a.caster, a.key, a.t = nil, nil, 0, nil, nil, nil, nil, nil, nil, nil
    return a
  end
  -- a timer from what was seen (no ClassicAPI): the last cast on it, else when it was first seen
  -- (a change of stacks counts as new), with the data file's duration
  local function Guess(g, id, stacks, now)
    local data = DATA.spells[id]
    local dur = data and data[2]
    local c = D.cast[g] and D.cast[g][id]
    if c and dur and c.t + dur > now then return c.t + dur, dur, c.caster end
    D.seen[g] = D.seen[g] or {}
    local s = D.seen[g][id]
    if not s or s.stacks ~= stacks or (dur and s.t + dur < now) then
      s = { t = now, stacks = stacks }
      D.seen[g][id] = s
    end
    if dur then return s.t + dur, dur, c and c.caster end
  end
  local function Kind(u, a, me)
    local r = a.id and D.RAIDID[a.id]
    if r then a.key = r.key end
    if me and a.caster == me then a.kind = "mine"
    elseif r then a.kind = "raid"
    else a.kind = "other" end
    if r and r.cat == "cc" then u.cc = true end
    a.t = a.ends and a.dur and (a.ends - a.dur) or 0
  end
  -- fills u.auras (u.na of them) from the best source there is
  function D.Read(u, now)
    local g, me = u.guid, D.Me()
    u.na, u.cc, u.reflect = 0, nil, nil
    if D.Classic() then
      local ok, list = pcall(_G.C_UnitAuras.GetUnitAuras, g, "HARMFUL")
      if ok and type(list) == "table" then
        for _, x in ipairs(list) do
          if type(x) == "table" and x.spellId then
            local a = Slot(u)
            a.id, a.name, a.icon, a.stacks = x.spellId, x.name, x.icon, x.applications or 0
            a.caster = x.sourceGUID
            if x.expirationTime and x.expirationTime > 0 then
              a.ends, a.dur = x.expirationTime, x.duration
            else
              a.ends, a.dur = Guess(g, a.id, a.stacks, now)
            end
            Kind(u, a, me)
          end
        end
        if C.dots.ccfade == "1" then
          local okb, buffs = pcall(_G.C_UnitAuras.GetUnitAuras, g, "HELPFUL")
          if okb and type(buffs) == "table" then
            for _, x in ipairs(buffs) do
              if type(x) == "table" and x.spellId and D.REFLECT[x.spellId] then u.reflect = D.REFLECT[x.spellId] end
            end
          end
        end
        return true
      end
    end
    if D.SuperWoW() and string.find(g, "^0x") then
      local have = {}
      for i = 1, 64 do
        local ok, tex, stacks, _, id = pcall(UnitDebuff, g, i)
        if not ok or not tex then break end
        local a = Slot(u)
        a.icon, a.stacks, a.id = tex, tonumber(stacks) or 0, id
        a.name = D.SpellName(id)
        a.ends, a.dur, a.caster = Guess(g, id, a.stacks, now)
        Kind(u, a, me)
        if id then have[id] = true end
      end
      -- (servers park extra debuffs in buff slots: only known debuffs from there; reflects too)
      for i = 1, 32 do
        local ok, tex, stacks, id = pcall(UnitBuff, g, i)
        if not ok or not tex then break end
        if id and D.REFLECT[id] then u.reflect = D.REFLECT[id] end
        if id and (DATA.spells[id] or D.RAIDID[id]) and not have[id] then
          local a = Slot(u)
          a.icon, a.stacks, a.id = tex, tonumber(stacks) or 0, id
          a.name = D.SpellName(id)
          a.ends, a.dur, a.caster = Guess(g, id, a.stacks, now)
          Kind(u, a, me)
        end
      end
      return true
    end
    -- no DLLs: the target only, with pfUI's own debuff timers
    if u.plain then
      local ld = pfUI.api.libdebuff
      for i = 1, 16 do
        local name, _, tex, stacks, _, dur, left, caster
        if ld and ld.UnitDebuff then name, _, tex, stacks, _, dur, left, caster = ld:UnitDebuff("target", i)
        else tex, stacks = UnitDebuff("target", i) end
        if not tex then break end
        local a = Slot(u)
        a.name, a.icon, a.stacks = name, tex, tonumber(stacks) or 0
        if left and dur and dur > 0 then a.ends, a.dur = now + left, dur end
        a.kind = caster == "player" and "mine" or "other"
        for _, r in ipairs(DATA.raid) do
          if name and Lower(name) == Lower(r.name) then
            a.key = r.key
            if a.kind ~= "mine" then a.kind = "raid" end
            if r.cat == "cc" then u.cc = true end
          end
        end
        a.t = a.ends and a.dur and (a.ends - a.dur) or 0
      end
    end
    return true
  end

  -- the four groups of icons (Cursive's "debuff order"): your class's own, your raid debuffs,
  -- other players' class debuffs, other players' raid debuffs
  D.CATS = { { key = "ownclass", label = "Own class debuffs" }, { key = "ownraid", label = "Own raid debuffs" },
             { key = "otherclass", label = "Other class debuffs" }, { key = "otherraid", label = "Other raid debuffs" } }
  function D.CatOf(a)
    if a.kind == "missing" then return "otherraid" end
    if a.kind == "mine" then return a.key and "ownraid" or "ownclass" end
    if a.kind == "raid" then return "otherraid" end
    return "otherclass"
  end
  -- is the aura shown at all?
  local function Allowed(a, s)
    if a.name and D.hide and D.hide[Lower(a.name)] then return end
    if a.kind == "mine" then return s.showmine == "1" end
    if a.kind == "raid" then return s.showraid == "1" and D.Watched(D.RAIDKEY[a.key]) end
    if a.kind == "other" then
      -- a class debuff of another player that the raid list knows and watches shows with "raid"
      return s.showother == "1"
    end
    if a.kind == "missing" then return true end
  end
  -- sort inside one group: your own by time left (or as put on), raid debuffs by the picked order
  local function ByTime(a, b)
    local ea, eb = a.ends or 1e9, b.ends or 1e9
    if ea ~= eb then return ea < eb end
    return (a.name or "") < (b.name or "")
  end
  local function ByApplied(a, b)
    if (a.t or 0) ~= (b.t or 0) then return (a.t or 0) < (b.t or 0) end
    return (a.name or "") < (b.name or "")
  end
  local function ByRaid(a, b)
    local ra, rb = D.rorder[a.key or ""] or 999, D.rorder[b.key or ""] or 999
    if ra ~= rb then return ra < rb end
    return ByTime(a, b)
  end
  local BUCK = { ownclass = {}, ownraid = {}, otherclass = {}, otherraid = {} }
  -- the auras of a mob to draw: main = the icons beside the bar, other = the "other side" group
  function D.Shown(u, main, other)
    Wipe(main)
    Wipe(other)
    for _, b in pairs(BUCK) do Wipe(b) end
    local s = S()
    local present = {}
    for i = 1, u.na do
      local a = u.auras[i]
      if a.key then present[a.key] = true end
      if Allowed(a, s) then
        local cat = D.CatOf(a)
        -- "include own raid debuffs in the order": yours sort in with the raid's
        if cat == "ownraid" and s.includeown == "1" then cat = "otherraid" end
        table.insert(BUCK[cat], a)
      end
    end
    -- grey icons for the armour / spell damage debuffs nobody has put up yet
    if s.missing == "1" and s.showraid == "1" and not u.test then
      u.miss = u.miss or {}
      local k = 0
      for _, r in ipairs(DATA.raid) do
        if not present[r.key] and (r.cat == "armor" or r.cat == "spellvuln") and D.Watched(r) then
          local icon = D.SpellIcon(r.ids[1], r.key)
          if icon then
            k = k + 1
            local a = u.miss[k] or {}
            u.miss[k] = a
            a.name, a.icon, a.kind, a.key, a.stacks, a.ends, a.dur, a.id = r.name, icon, "missing", r.key, 0, nil, nil, r.ids[1]
            table.insert(BUCK.otherraid, a)
          end
        end
      end
    end
    table.sort(BUCK.ownclass, s.mineorder == "applied" and ByApplied or ByTime)
    table.sort(BUCK.ownraid, ByRaid)
    table.sort(BUCK.otherclass, ByTime)
    table.sort(BUCK.otherraid, ByRaid)
    for _, n in ipairs({ s.order1, s.order2, s.order3, s.order4 }) do
      if BUCK[n] and n ~= s.otherside then
        for _, a in ipairs(BUCK[n]) do table.insert(main, a) end
      end
    end
    if BUCK[s.otherside or ""] then
      for _, a in ipairs(BUCK[s.otherside]) do table.insert(other, a) end
    end
    return main, other
  end
  function D.HasMine(u)
    for i = 1, u.na do if u.auras[i].kind == "mine" then return true end end
  end

  -- ---------------------------------------------------------------- which mobs, in which order

  -- name, health, mark, combat... of a mob (once per scan)
  function D.Info(u)
    local g = u.guid
    u.name = Safe(UnitName, g) or u.name or UNKNOWN
    u.hp = tonumber(Safe(UnitHealth, g)) or 0
    u.hpmax = tonumber(Safe(UnitHealthMax, g)) or 0
    u.mark = Safe(GetRaidTargetIndex, g)
    u.combat = Safe(UnitAffectingCombat, g)
    u.hostile = Safe(UnitIsEnemy, "player", g)
    u.attackable = Safe(UnitCanAttack, "player", g)
    u.player = Safe(UnitIsPlayer, g)
    u.reaction = Safe(UnitReaction, "player", g)
    local _, _, cls = pcall(UnitClass, g)
    u.class = u.player and cls or nil
    if On("armor") and _G.UnitResistance then
      local ok, base, eff = pcall(_G.UnitResistance, g, 0)
      eff = ok and tonumber(eff or base)
      if eff then
        u.armor = math.max(0, eff)
        if not D.maxarmor[g] or u.armor > D.maxarmor[g] then D.maxarmor[g] = u.armor end
        u.armormax = D.maxarmor[g]
      end
    end
  end
  -- Cursive's "Show only" filters (the "has my debuff" one is checked after reading the auras)
  function D.Wanted(u, tg)
    local s = S()
    local istg = u.guid == tg
    if istg and s.alwaystarget == "1" then return u.attackable and true or nil end
    if s.onlytarget == "1" and not istg then return end
    if s.attackable == "1" and not u.attackable then return end
    if s.hostile == "1" and not u.hostile and not istg then return end
    if not u.attackable and not u.hostile then return end
    if s.incombat == "1" and not u.combat and not istg then return end
    if s.onlyplayers == "1" and not u.player then return end
    if s.onlynpcs == "1" and u.player then return end
    if s.withinrange == "1" and u.dist and u.dist > Num("rangeyards", 120) then return end
    if s.markedonly == "1" and not u.mark then return end
    if D.Ignored(u.name) then return end
    return true
  end
  -- sort: the target first (C.dots.targettop), then the order picked
  local ORDER, TG
  -- Locked order in combat (C.dots.lockorder; user 17 Nov 2026: rows "jumping around as you change
  -- target ... should just be locked and added to"): a mob keeps the place it first got in the
  -- list, new ones join at the end, the target is not lifted to the top. Places are forgotten
  -- once you are out of combat.
  D.place, D.nextPlace = {}, 0
  local LOCKED
  function D.Locked()
    return C.dots.lockorder == "1" and UnitAffectingCombat("player") and true or false
  end
  local function Before(a, b)
    if LOCKED then
      local pa, pb = D.place[a.guid], D.place[b.guid]
      if pa and pb then return pa < pb end
      if pa then return true end
      if pb then return false end
    end
    if TG and C.dots.targettop == "1" and not LOCKED then
      if a.guid == TG then return b.guid ~= TG end
      if b.guid == TG then return false end
    end
    if ORDER == "marks" then
      local ma, mb = a.mark or 0, b.mark or 0
      if ma ~= mb then return ma > mb end
    elseif ORDER == "lowhp" then
      local pa, pb = a.hp / math.max(1, a.hpmax), b.hp / math.max(1, b.hpmax)
      if pa ~= pb then return pa < pb end
    elseif ORDER == "old" then
      if a.added ~= b.added then return a.added < b.added end
    elseif ORDER == "new" then
      if a.added ~= b.added then return a.added > b.added end
    end
    if a.hpmax ~= b.hpmax then return a.hpmax > b.hpmax end
    if a.added ~= b.added then return a.added < b.added end
    return a.guid < b.guid
  end
  D.Before = Before
  -- without SuperWoW only the target can be read: one entry under the key "target"
  function D.Plain()
    for g in pairs(D.units) do if g ~= "target" then D.Remove(g) end end
    if UnitExists("target") then
      if not D.units.target then
        D.units.target = { guid = "target", added = GetTime(), seen = GetTime(), auras = {}, na = 0, plain = true }
        D.n = 1
      end
      D.units.target.seen = GetTime()
    elseif D.units.target then
      D.Remove("target")
    end
  end
  function D.Slots() return Num("rows", 8) * math.max(1, Num("cols", 1)) end
  -- every tracked mob filtered and sorted into D.list. Cheap facts first (health, combat, marks);
  -- auras are read only for mobs in sort order until the rows are full (faster than Cursive's
  -- read-everything), so 40 mobs in a raid cost as much as the rows shown.
  local POOL = {}
  -- (22 Nov 2026, user: "use classicAPI better for this and the dot tracker") every mob on the bars had all its
  -- debuffs read (and a new table made for them) five times a second. With ClassicAPI the bars' mobs are registered
  -- for UNIT_AURA by GUID (frame:RegisterGUIDEvent): a mob is read again only when its auras changed, when your own or
  -- a tracked cast lands (D.readAll / D.auraSeen), and every D.READ_EVERY s to be safe. Time left needs no read: the
  -- end times are kept. Without ClassicAPI (or if the GUID registration is refused) every pass reads, as before.
  D.READ_EVERY = 1
  D.auraSeen = {}
  local gev = CreateFrame("Frame")
  D.auraEvents = gev
  local watchList, watchN = {}, 0
  gev:SetScript("OnEvent", function()
    local g = arg1
    if not g then return end
    if D.units[g] then D.auraSeen[g] = true else D.readAll = true end
    D.dirty = true
  end)
  -- register the GUIDs of the bars' mobs (only when the set changed)
  function D.WatchAuras(list)
    if not gev.RegisterGUIDEvent or not D.Classic() then D.guidEvents = nil return end
    local n, same = 0, true
    for _, u in ipairs(list) do
      if u.guid and u.guid ~= "target" then
        n = n + 1
        if watchList[n] ~= u.guid then same = false watchList[n] = u.guid end
      end
    end
    if same and n == watchN then return end
    for i = n + 1, watchN do watchList[i] = nil end
    if SETN then SETN(watchList, n) end
    watchN = n
    if n == 0 then
      if gev.UnregisterGUIDEvent then pcall(gev.UnregisterGUIDEvent, gev, "UNIT_AURA") end
      return
    end
    local ok = pcall(gev.RegisterGUIDEvent, gev, "UNIT_AURA", unpack(watchList))
    D.guidEvents = ok or nil
  end
  local function NeedRead(u, now)
    if not D.guidEvents or D.readAll or u.guid == "target" or not u.readAt or D.auraSeen[u.guid] then return true end
    return now - u.readAt >= D.READ_EVERY or now < u.readAt
  end

  function D.Scan()
    local now = GetTime()
    local list = D.list
    Wipe(list)
    Wipe(POOL)
    if D.SuperWoW() then TG = Guid("target") else D.Plain() TG = "target" end
    LOCKED = D.Locked()
    if not LOCKED and D.nextPlace > 0 then Wipe(D.place) D.nextPlace = 0 end
    for _, u in pairs(D.units) do
      D.Info(u)
      -- a placed row stays while the mob lives and can be attacked (the "show current target"
      -- row would otherwise vanish when you click the next one)
      if D.Wanted(u, TG) or (LOCKED and D.place[u.guid] and u.attackable and u.hp > 0
                             and C.dots.onlytarget ~= "1" and not D.Ignored(u.name)) then
        table.insert(POOL, u)
      end
    end
    ORDER = C.dots.order or "marks"
    table.sort(POOL, Before)
    local rows, mine = D.Slots(), C.dots.mineonly == "1"
    for _, u in ipairs(POOL) do
      if table.getn(list) >= rows then break end
      if NeedRead(u, now) then
        D.Read(u, now)
        u.readAt = now
        D.auraSeen[u.guid] = nil
      end
      if not mine or (u.guid == TG and C.dots.alwaystarget == "1") or D.HasMine(u) then
        -- out of range / out of sight (stripes)
        if C.dots.stripes == "1" and u.guid ~= "target" then
          local d = u.dist or D.Distance(u.guid)
          local los = lc and lc.LineOfSight and lc.LineOfSight(u.guid)
          u.far = (d and d > Num("striperange", 30)) or los == false
        else
          u.far = nil
        end
        table.insert(list, u)
        if LOCKED and not D.place[u.guid] then
          D.nextPlace = D.nextPlace + 1
          D.place[u.guid] = D.nextPlace
        end
      end
    end
    D.dirty = nil
    D.readAll = nil
    D.WatchAuras(list)
    return list
  end

  -- ---------------------------------------------------------------- drawing

  local function Font() return pfUI.font_unit or pfUI.font_default or STANDARD_TEXT_FONT end
  local function FS(k, d) return math.max(5, math.floor(Num(k, d) * Num("fontscale", 1) + .5)) end
  local function Col(str, r, g, b)
    local cr, cg, cb, ca = GetStringColor(str or "")
    return tonumber(cr) or r, tonumber(cg) or g, tonumber(cb) or b, tonumber(ca) or 1
  end
  function D.Texture()
    local t = C.dots.texture
    if not t or t == "" then t = "Interface\\AddOns\\pfUI\\img\\bar_elvui" end
    return t
  end
  -- the time left as a short text (tenths under C.dots.decimals seconds)
  function D.TimeText(left)
    if not left then return "" end
    if left >= 100 then return math.ceil((left - 30) / 60) .. "m" end
    if left < (tonumber(C.dots.decimals) or 0) then return string.format("%.1f", math.max(0, left)) end
    return tostring(math.ceil(left))
  end
  -- class colour of a caster GUID (cached), or of a raid debuff's class
  function D.ClassColor(a)
    local cls
    if a.kind == "mine" then
      local _, c = UnitClass("player")
      cls = c
    elseif a.caster then
      cls = D.classes[a.caster]
      if cls == nil then
        local ok, _, c = pcall(UnitClass, a.caster)
        cls = ok and c or false
        D.classes[a.caster] = cls
      end
    end
    if not cls and a.key and D.RAIDKEY[a.key] then cls = D.RAIDKEY[a.key].class end
    local c = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
    if c then return c.r, c.g, c.b end
    return .6, .6, .6
  end
  local NAMED = { green = { .3, .9, .4 }, red = { .95, .25, .2 }, black = { 0, 0, 0 }, white = { 1, 1, 1 }, yellow = { 1, .82, 0 } }
  -- "off" | "green" | "red" | "black" | "classcolor" | "white" | "yellow" -> r, g, b (nil = off / none)
  function D.Named(v, a)
    if v == "classcolor" then return D.ClassColor(a) end
    local c = NAMED[v or ""]
    if c then return c[1], c[2], c[3] end
  end

  local function NewIcon(row, i)
    local f = CreateFrame("Button", nil, row)
    f:EnableMouse(true)
    f.edge = f:CreateTexture(nil, "BACKGROUND")
    f.edge:SetAllPoints(f)
    f.edge:SetTexture("Interface\\Buttons\\WHITE8X8")
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetTexCoord(.08, .92, .08, .92)
    f.time = f:CreateFontString(nil, "OVERLAY")
    f.stack = f:CreateFontString(nil, "OVERLAY")
    f:SetScript("OnEnter", function()
      local a = this.aura
      if not a then return end
      GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT")
      GameTooltip:AddLine(a.name or "?")
      if a.kind == "missing" then
        GameTooltip:AddLine("Not on this enemy yet.", .7, .7, .7)
      else
        local who = a.caster and Safe(UnitName, a.caster)
        if a.kind == "mine" then who = "you" end
        if who then GameTooltip:AddLine("From " .. who, 1, 1, 1) end
        if a.ends then GameTooltip:AddLine(D.TimeText(a.ends - GetTime()) .. " left", 1, 1, 1) end
        if a.stacks and a.stacks > 1 then GameTooltip:AddLine(a.stacks .. " stacks", 1, 1, 1) end
      end
      GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:SetScript("OnClick", function()
      local r = this:GetParent()
      local fn = r:GetScript("OnClick")
      if fn then
        local old = _G.this
        _G.this = r
        fn()
        _G.this = old
      end
    end)
    row.icons[i] = f
    return f
  end

  -- one row: [other side icons][mark][bar: name ... armour / hp][icons]  (inverted: mirrored)
  function D.NewRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row.icons = {}
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.mark = row:CreateTexture(nil, "OVERLAY")
    row.mark:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetMinMaxValues(0, 1)
    row.bg = row.bar:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(row.bar)
    row.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.edge = row:CreateTexture(nil, "BACKGROUND")
    row.edge:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.stripes = row.bar:CreateTexture(nil, "OVERLAY")
    row.stripes:SetAllPoints(row.bar)
    row.stripes:SetTexture(D.IMG .. "diagonal_stripes_rev")
    row.stripes:SetAlpha(.5)
    row.stripes:Hide()
    row.text = CreateFrame("Frame", nil, row.bar)
    row.text:SetAllPoints(row.bar)
    row.text:SetFrameLevel(row.bar:GetFrameLevel() + 2)
    row.name = row.text:CreateFontString(nil, "OVERLAY")
    row.name:SetJustifyH("LEFT")
    row.hp = row.text:CreateFontString(nil, "OVERLAY")
    row.hp:SetJustifyH("RIGHT")
    row.armor = row.text:CreateFontString(nil, "OVERLAY")
    row.shield = row.text:CreateTexture(nil, "OVERLAY")
    row.shield:SetTexture("Interface\\Icons\\INV_Shield_06")
    row.shield:SetTexCoord(.08, .92, .08, .92)
    row.flash = row.text:CreateFontString(nil, "OVERLAY")
    row.flash:SetPoint("CENTER", row.bar, "CENTER", 0, 0)
    row:SetScript("OnClick", function()
      local g = this.guid
      if not g or this.preview then
        if this.preview and this.onPick then this.onPick(this) end
        return
      end
      if C.dots.clicks ~= "1" then return end
      if arg1 == "RightButton" then
        if D.SuperWoW() and SetRaidTarget and (GetNumRaidMembers() == 0 or IsRaidOfficer() or IsRaidLeader()) then
          local cur = Safe(GetRaidTargetIndex, g) or 0
          pcall(SetRaidTarget, g, math.mod(cur, 8) + 1)
        end
        return
      end
      if D.SuperWoW() then pcall(TargetUnit, g) end
    end)
    row:SetScript("OnEnter", function()
      if this.preview then
        if this.onEnter then this.onEnter(this) end
        return
      end
      if not this.guid then return end
      GameTooltip:SetOwner(this, "ANCHOR_LEFT")
      local ok = D.SuperWoW() and string.find(this.guid, "^0x") and pcall(GameTooltip.SetUnit, GameTooltip, this.guid)
      if not ok then GameTooltip:AddLine(this.name:GetText() or "") end
      if this.reflect then GameTooltip:AddLine("Reflects spells: " .. this.reflect, 1, .4, .4) end
      if C.dots.clicks == "1" then GameTooltip:AddLine("Click: target   Right-click: next raid mark", .6, .8, 1) end
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
  end

  -- sizes, fonts and places from the settings (when they change)
  function D.LayoutRow(row)
    local s = S()
    local h = Num("rowh", 18)
    local w = Num("width", 120)
    local isz = Num("iconsize", 18)
    local msz = Num("marksize", h)
    local gap = Num("iconspacing", 1)
    local font = Font()
    local inv = s.invert == "1"
    local per = math.min(MAXICONS, Num("icons", 14))
    local iw = isz + gap
    local ow = (s.otherside and s.otherside ~= "none") and (OTHERMAX * iw + 1) or 0
    local mw = s.marks == "1" and (msz + 2) or 0
    row:SetHeight(math.max(h, isz, mw > 0 and msz or 0))
    row.mark:SetWidth(msz)
    row.mark:SetHeight(msz)
    row.mark:ClearAllPoints()
    row.bar:ClearAllPoints()
    row.bar:SetWidth(w)
    row.bar:SetHeight(h)
    -- x positions from the row's left edge
    local barx, markx, mainx, otherx, step
    if not inv then
      otherx = ow - iw
      markx = ow
      barx = ow + mw
      mainx = barx + w + 2
      row.ostep, row.mstep = -iw, iw
    else
      mainx = (per - 1) * iw
      barx = per * iw + 1
      markx = barx + w + 2
      otherx = markx + mw
      row.ostep, row.mstep = iw, -iw
    end
    row.bar:SetPoint("LEFT", row, "LEFT", barx, 0)
    row.mark:SetPoint("LEFT", row, "LEFT", markx, 0)
    row.mainx, row.otherx = mainx, otherx
    row.bar:SetStatusBarTexture(D.Texture())
    local barAlpha = s.healthbar == "1" and 1 or 0
    local bt = row.bar:GetStatusBarTexture()
    if bt and bt.SetAlpha then bt:SetAlpha(barAlpha) end
    row.bg:SetAlpha(barAlpha)
    row.edge:ClearAllPoints()
    row.edge:SetPoint("TOPLEFT", row.bar, "TOPLEFT", -1, 1)
    row.edge:SetPoint("BOTTOMRIGHT", row.bar, "BOTTOMRIGHT", 1, -1)
    row.edge:SetAlpha(barAlpha)
    row.name:SetFont(font, FS("namesize", 9), "OUTLINE")
    row.hp:SetFont(font, FS("fontsize", 9), "OUTLINE")
    row.armor:SetFont(font, FS("armorsize", 9), "OUTLINE")
    row.flash:SetFont(font, FS("fontsize", 9) + 2, "OUTLINE")
    row.hp:ClearAllPoints()
    row.hp:SetPoint("RIGHT", row.bar, "RIGHT", -3, 0)
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", row.bar, "LEFT", 3, 0)
    row.name:SetPoint("RIGHT", row.hp, "LEFT", -2, 0)
    local nl = Num("namelen", 0)
    if nl > 0 then row.name:SetWidth(nl) end
    -- armour text: on the bar (left / centre / right) with an optional shield picture
    local apos, off = s.armorpos or "center", Num("armoroffset", 0)
    local ssz = math.max(8, h - 4)
    row.shield:SetWidth(ssz)
    row.shield:SetHeight(ssz)
    row.armor:ClearAllPoints()
    row.shield:ClearAllPoints()
    if apos == "left" then row.armor:SetPoint("LEFT", row.bar, "LEFT", 3 + off, 0)
    elseif apos == "right" then row.armor:SetPoint("RIGHT", row.hp, "LEFT", -4 + off, 0)
    else row.armor:SetPoint("CENTER", row.bar, "CENTER", off, 0) end
    if s.armoricon == "right" then row.shield:SetPoint("LEFT", row.armor, "RIGHT", 2, 0)
    else row.shield:SetPoint("RIGHT", row.armor, "LEFT", -2, 0) end
    local tsz, ssz2 = FS("timersize", 10), FS("stacksize", 9)
    for i = 1, MAXICONS do
      local f = row.icons[i] or NewIcon(row, i)
      f:SetWidth(isz)
      f:SetHeight(isz)
      local b = Num("bordersize", 1)
      f.tex:ClearAllPoints()
      f.tex:SetPoint("TOPLEFT", f, "TOPLEFT", b, -b)
      f.tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -b, b)
      f.time:ClearAllPoints()
      f.time:SetPoint("CENTER", f, "CENTER", Num("timerx", 0), Num("timery", 0))
      f.time:SetFont(font, tsz, "OUTLINE")
      f.stack:ClearAllPoints()
      f.stack:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", Num("stackx", 0), 1 + Num("stacky", 0))
      f.stack:SetFont(font, ssz2, "OUTLINE")
      f.place = nil
      f:Hide()
    end
    row:SetWidth(math.max(mainx, otherx, markx) + (inv and (ow + mw) or (per * iw)) + 2)
    row.per = per
  end

  local function Place(row, f, side, n)
    local key = side .. n
    if f.place == key then return end
    f.place = key
    f:ClearAllPoints()
    local x = side == "m" and (row.mainx + (n - 1) * row.mstep) or (row.otherx + (n - 1) * row.ostep)
    f:SetPoint("LEFT", row, "LEFT", x, 0)
  end
  local function PaintIcon(row, f, a, t, s)
    f.aura = a
    f.tex:SetTexture(a.icon)
    local left = a.ends and (a.ends - t)
    if a.kind == "missing" then
      f.tex:SetVertexColor(.4, .4, .4)
      f:SetAlpha(.55)
      f.time:SetText("")
    else
      f.tex:SetVertexColor(1, 1, 1)
      f:SetAlpha(1)
      if left and left > 0 and s.timers == "1" then
        local r, g, b = D.Named(s.timercolor, a)
        -- the last seconds: tenths in white / red (Cursive's "decimal duration")
        if left < Num("warn", 3) then
          local dr, dg, db = D.Named(s.decimalcolor, a)
          if dr then r, g, b = dr, dg, db end
        end
        if r then
          f.time:SetTextColor(r, g, b)
          f.time:SetText(D.TimeText(left))
        else
          f.time:SetText("")
        end
      else
        f.time:SetText("")
      end
    end
    if a.stacks and a.stacks > 1 then
      local r, g, b = D.Named(s.stackcolor, a)
      f.stack:SetTextColor(r or 1, g or 1, b or 1)
      f.stack:SetText(a.stacks)
    else
      f.stack:SetText("")
    end
    -- border by group: own class / own raid / other class / other raid
    local r, g, b = D.Named(s["border_" .. D.CatOf(a)], a)
    if r then
      f.edge:SetVertexColor(r, g, b, Num("borderalpha", 1) * (a.kind == "missing" and .5 or 1))
      f.edge:Show()
    else
      f.edge:SetVertexColor(0, 0, 0, Num("borderalpha", 1) * .6)
    end
    f:Show()
  end

  -- one row from a mob's data (t = now; the preview paints made-up mobs the same way)
  function D.PaintRow(row, u, t)
    local s = S()
    row.guid = u.guid
    row.reflect = u.reflect
    -- the bar: health, colour by reaction (players by class)
    local pct = u.hpmax > 0 and (u.hp / u.hpmax) or 0
    row.bar:SetValue(pct)
    local r, g, b = .8, .2, .2
    if s.barcolor == "custom" then r, g, b = Col(s.color, .8, .2, .2)
    elseif u.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[u.class] then
      local c = RAID_CLASS_COLORS[u.class]
      r, g, b = c.r, c.g, c.b
    elseif u.reaction and u.reaction == 4 then r, g, b = .9, .8, .2 end
    row.bar:SetStatusBarColor(r, g, b, 1)
    row.bg:SetVertexColor(r * .25, g * .25, b * .25, .8)
    local tg = u.guid == TG or u.target
    if tg and s.highlight == "1" then
      local ar, ag, ab = 1, 1, 1
      if GetAccentColor then ar, ag, ab = GetAccentColor() end
      row.edge:SetVertexColor(ar, ag, ab, 1)
    else
      row.edge:SetVertexColor(0, 0, 0, 1)
    end
    row.name:SetText(s.name == "1" and (u.name or "") or "")
    row.hp:SetText(s.hp == "1" and (math.floor(pct * 100 + .5) .. "%") or "")
    -- armour: live / total (highest seen) / removed, coloured green -> yellow -> red as it drops
    if s.armor == "1" and u.armor then
      local total = u.armormax or u.armor
      local cut = total - u.armor
      local live, tot, rem = tostring(u.armor), tostring(total), cut > 0 and ("-" .. cut) or "0"
      local show = s.armorshow or "total+removed"
      local txt = show == "live" and live or show == "total" and tot or show == "removed" and rem
        or show == "live+total" and (live .. " / " .. tot) or show == "live+removed" and (live .. " " .. rem)
        or (tot .. " " .. rem)
      if s.armorcolor == "1" and total > 0 then
        local p = u.armor / total
        local cr = p > .66 and .4 or p > .33 and 1 or 1
        local cg = p > .66 and .9 or p > .33 and .82 or .3
        row.armor:SetTextColor(cr, cg, p > .66 and .4 or .2)
      else
        row.armor:SetTextColor(.85, .85, .85)
      end
      row.armor:SetText(txt)
      row.armor:Show()
      if s.armoricon ~= "off" then row.shield:Show() else row.shield:Hide() end
    else
      row.armor:Hide()
      row.shield:Hide()
    end
    if s.marks == "1" and u.mark and u.mark > 0 and SetRaidTargetIconTexture then
      SetRaidTargetIconTexture(row.mark, u.mark)
      row.mark:Show()
    else
      row.mark:Hide()
    end
    if u.far and s.stripes == "1" then row.stripes:Show() else row.stripes:Hide() end
    -- crowd controlled / reflecting mobs fade (don't break the CC, don't cast into the reflect)
    if s.ccfade == "1" and (u.cc or u.reflect) then row:SetAlpha(.4) else row:SetAlpha(1) end
    -- a resist / immune word over the bar for a moment
    if u.flash and u.flashUntil and t < u.flashUntil then
      row.flash:SetText("|cffff5050" .. u.flash .. "|r")
      row.flash:SetAlpha(math.min(1, (u.flashUntil - t) * 2))
      row.flash:Show()
    elseif u.reflect and s.ccfade == "1" then
      row.flash:SetText("|cffff9933REFLECT|r")
      row.flash:SetAlpha(1)
      row.flash:Show()
    else
      row.flash:Hide()
    end
    -- the icons: the main group beside the bar, the "other side" group past the mark
    u.main, u.other = u.main or {}, u.other or {}
    if not u.test then D.Shown(u, u.main, u.other) end
    local per = row.per or 14
    local k = 0
    for i = 1, per do
      local a = u.main[i]
      if not a then break end
      k = k + 1
      local f = row.icons[k]
      Place(row, f, "m", i)
      PaintIcon(row, f, a, t, s)
    end
    for i = 1, OTHERMAX do
      local a = u.other[i]
      if not a or k >= MAXICONS then break end
      k = k + 1
      local f = row.icons[k]
      Place(row, f, "o", i)
      PaintIcon(row, f, a, t, s)
    end
    for i = k + 1, MAXICONS do
      local f = row.icons[i]
      if f and f:IsShown() then
        f.aura = nil
        f:Hide()
      end
    end
  end

  -- ---------------------------------------------------------------- the frame

  local frame = CreateFrame("Frame", "pfDotTracker", UIParent)
  D.frame = frame
  frame:SetFrameStrata("MEDIUM")
  frame:SetPoint("CENTER", UIParent, "CENTER", 380, -40)
  frame:SetWidth(200)
  frame:SetHeight(100)
  frame:SetClampedToScreen(true)
  frame.back = frame:CreateTexture(nil, "BACKGROUND")
  frame.back:SetTexture("Interface\\Buttons\\WHITE8X8")
  frame.back:SetPoint("TOPLEFT", frame, "TOPLEFT", -3, 3)
  frame.back:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 3, -3)
  frame.title = frame:CreateFontString(nil, "OVERLAY")
  frame.title:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 1, 3)
  frame.title:SetTextColor(.7, .7, .7)
  if UpdateMovable then UpdateMovable(frame) end

  function D.ApplyLayout()
    local s = S()
    frame:SetScale(Num("scale", 1))
    frame:SetAlpha(Num("alpha", 1))
    frame.title:SetFont(Font(), FS("fontsize", 9) + 1, "OUTLINE")
    frame.title:SetText(s.title == "1" and "OctoDoTs" or "")
    frame.back:SetVertexColor(0, 0, 0, s.backdrop == "1" and .45 or 0)
    local rows, cols = Num("rows", 8), math.max(1, Num("cols", 1))
    local gap = Num("spacing", 3)
    local h, w = 10, 100
    local total = rows * cols
    for i = 1, total do
      local row = D.rows[i] or D.NewRow(frame)
      D.rows[i] = row
      D.LayoutRow(row)
      row:ClearAllPoints()
      local col = math.floor((i - 1) / rows)
      local r = math.mod(i - 1, rows)
      local y = r * (row:GetHeight() + gap)
      local x = col * (row:GetWidth() + 8)
      if s.grow == "UP" then row:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x, y)
      else row:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y) end
      h = math.max(h, y + row:GetHeight())
      w = math.max(w, x + row:GetWidth())
    end
    for i = total + 1, table.getn(D.rows) do D.rows[i]:Hide() end
    frame:SetWidth(w)
    frame:SetHeight(h)
    D.ReadHide()
    D.dirty = true
  end
  D.UpdateConfig = D.ApplyLayout
  -- back to the default place (Cursive's "Reset UI frames")
  function D.ResetPosition()
    if C.position then C.position["pfDotTracker"] = nil end
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 380, -40)
    if UpdateMovable then UpdateMovable(frame) end
  end

  -- ---------------------------------------------------------------- made-up mobs (test, preview, layout mode)

  -- { name, mark, target, health, auras { name, icon, kind, seconds, stacks, raid key }, armour, most armour, cc }
  D.FAKE = {
    { "Ragnaros", 8, 1, .82, { { "Corruption", "Spell_Shadow_AbominationExplosion", "mine", 14 }, { "Curse of Agony", "Spell_Shadow_CurseOfSargeras", "mine", 20 },
      { "Immolate", "Spell_Fire_Immolation", "mine", 2.4 }, { "Sunder Armor", "Ability_Warrior_Sunder", "raid", 26, 5, "sunderarmor" },
      { "Curse of the Elements", "Spell_Shadow_ChillTouch", "raid", 240, 0, "curseoftheelements" },
      { "Faerie Fire", "Spell_Nature_FaerieFire", "raid", 31, 0, "faeriefire" }, { "Thunder Clap", "Spell_Nature_ThunderClap", "other", 18 } }, 3650, 5560 },
    { "Flamewaker Healer", 7, 0, .64, { { "Corruption", "Spell_Shadow_AbominationExplosion", "mine", 6 }, { "Sunder Armor", "Ability_Warrior_Sunder", "raid", 12, 3, "sunderarmor" },
      { "Faerie Fire", "Spell_Nature_FaerieFire", "missing", nil, 0, "faeriefire" } }, 2900, 3800 },
    { "Flamewaker Elite", 2, 0, .4, { { "Curse of Agony", "Spell_Shadow_CurseOfSargeras", "mine", 9 }, { "Shadow Weaving", "Spell_Shadow_BlackPlague", "raid", 13, 5, "shadowweaving" } }, 3800, 3800 },
    { "Son of Flame", 0, 0, .95, { { "Siphon Life", "Spell_Shadow_Requiem", "mine", 1.6 } }, 1200, 1200, nil, true },
    { "Lava Spawn", 1, 0, .23, { { "Immolate", "Spell_Fire_Immolation", "mine", 11 }, { "Polymorph", "Spell_Nature_Polymorph", "raid", 38, 0, "polymorph" } }, 900, 900, true },
  }
  -- a fresh copy of the made-up mobs, timers counting from now (looping in the preview)
  function D.FakeUnits(t)
    local out = {}
    for i, f in ipairs(D.FAKE) do
      local u = { guid = "fake" .. i, name = f[1], mark = f[2] > 0 and f[2] or nil, target = f[3] == 1, hp = f[4], hpmax = 1,
                  added = i, auras = {}, na = 0, test = true, armor = f[6], armormax = f[7], cc = f[8], far = f[9], main = {}, other = {} }
      for _, x in ipairs(f[5]) do
        u.na = u.na + 1
        local a = { name = x[1], icon = "Interface\\Icons\\" .. x[2], kind = x[3], stacks = x[5] or 0, key = x[6] }
        if x[4] then a.ends, a.dur, a.t = t + x[4], x[4], t end
        u.auras[u.na] = a
      end
      if i == 1 then u.flash, u.flashUntil = "RESIST", t + 2 end
      out[i] = u
    end
    return out
  end
  -- the made-up timers loop (each runs out and starts again), through the show settings
  function D.FakeTick(units, t)
    local s = S()
    for _, u in ipairs(units) do
      for i = 1, u.na do
        local a = u.auras[i]
        if a.ends and a.ends < t then a.ends = t + a.dur end
      end
      if u.flashUntil and u.flashUntil < t - 4 then u.flashUntil = t + 1.5 end
      -- (missing icons only with "show missing"; the rest as the real ones)
      local keep = s.missing
      s.missing = "0"
      D.Shown(u, u.main, u.other)
      s.missing = keep
      if keep == "1" and s.showraid == "1" then
        for i = 1, u.na do
          local a = u.auras[i]
          if a.kind == "missing" then table.insert(s.otherside == "otherraid" and u.other or u.main, a) end
        end
      end
    end
  end
  function D.Test(secs)
    D.testUntil = GetTime() + (secs or 20)
    D.fake = D.FakeUnits(GetTime())
    frame:Show()
  end
  function D.Testing()
    if D.testUntil and GetTime() < D.testUntil then return true end
    return pfUI.unlock and pfUI.unlock.IsShown and pfUI.unlock:IsShown() and true or nil
  end

  -- ---------------------------------------------------------------- the loop

  local nextScan, nextPaint, nextSlow = 0, 0, 0
  -- draws D.list (or the made-up mobs) into the rows
  function D.Paint(t)
    local s = S()
    local list = D.list
    local test = D.Testing()
    if test then
      if not D.fake then D.fake = D.FakeUnits(t) end
      D.FakeTick(D.fake, t)
      list = D.fake
    else
      D.fake = nil
    end
    local slots = D.Slots()
    local shown = 0
    for i = 1, slots do
      local row = D.rows[i]
      local u = list[i]
      if row and u then
        D.PaintRow(row, u, t)
        if not row:IsShown() then row:Show() end
        shown = shown + 1
      elseif row then
        row.guid = nil
        if row:IsShown() then row:Hide() end
      end
    end
    local show = s.show or "rows"
    local vis = test or (shown > 0 and (show ~= "combat" or UnitAffectingCombat("player"))) or show == "always"
    -- (the target bar only: the mob bars stay away, except in layout mode / a test so they can be moved)
    if s.which == "target" and not test then vis = false end
    if vis and not frame:IsShown() then frame:Show() elseif not vis and frame:IsShown() then frame:Hide() end
    frame.shown = shown
  end

  -- expiring sound: once for each of your debuffs going under the warning time
  function D.Sounds(t)
    if C.dots.sound ~= "1" then return end
    local warn = Num("warn", 3)
    for _, u in ipairs(D.list) do
      for i = 1, u.na do
        local a = u.auras[i]
        if a.kind == "mine" and a.ends then
          local left = a.ends - t
          local k = u.guid .. (a.name or a.id or "")
          if left > 0 and left < warn and D.played[k] ~= a.ends then
            D.played[k] = a.ends
            PlaySoundFile(D.IMG .. "expiring.mp3")
          end
        end
      end
    end
  end

  -- (on the event frame: the tracker itself hides while it has nothing to show)
  local ev = CreateFrame("Frame")
  D.events = ev
  ev:SetScript("OnUpdate", function()
    local t = GetTime()
    if t >= nextSlow then
      nextSlow = t + 1
      D.Evict()
      for g in pairs(D.auraSeen) do if not D.units[g] then D.auraSeen[g] = nil end end
      D.ScanGroup()
      for k, v in pairs(D.pending) do if v < t then D.pending[k] = nil end end
    end
    -- (18 Nov 2026, user: "Show both / Show Bars only / Show Single target bar only") with the target
    -- bar only, the mob bars are not read at all
    if (t >= nextScan or D.dirty) and (S().which ~= "target" or D.Testing()) then
      nextScan = t + Num("rate", .2)
      D.Scan()
      D.Sounds(t)
    end
    if t >= nextPaint then
      nextPaint = t + .1
      D.Paint(t)
    end
  end)

  -- ---------------------------------------------------------------- events

  for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "UNIT_COMBAT", "PLAYER_ENTERING_WORLD",
                       "CHAT_MSG_SPELL_SELF_DAMAGE", "RAID_TARGET_UPDATE", "PLAYER_REGEN_DISABLED" }) do
    ev:RegisterEvent(e)
  end
  pcall(ev.RegisterEvent, ev, "UNIT_CASTEVENT")
  pcall(ev.RegisterEvent, ev, "NAME_PLATE_UNIT_ADDED")

  -- your resisted / immune / missed debuff: a word on its mob's row and a sound
  D.FAILS = {
    { SPELLRESISTSELFOTHER, "RESIST" }, { SPELLIMMUNESELFOTHER, "IMMUNE" }, { IMMUNEDAMAGECLASSSELFOTHER, "IMMUNE" },
    { SPELLMISSSELFOTHER, "MISS" }, { SPELLDODGEDSELFOTHER, "DODGE" }, { SPELLPARRIEDSELFOTHER, "PARRY" },
    { SPELLBLOCKEDSELFOTHER, "BLOCK" }, { SPELLEVADEDSELFOTHER, "EVADE" }, { SPELLREFLECTSELFOTHER, "REFLECT" },
  }
  -- every debuff name we know (lower case)
  D.KNOWN = {}
  for _, v in pairs(DATA.spells) do D.KNOWN[Lower(v[1])] = true end
  function D.Failed(msg)
    if not msg or C.dots.resist ~= "1" then return end
    for _, f in ipairs(D.FAILS) do
      if type(f[1]) == "string" then
        local spell, who = cmatch(msg, f[1])
        if spell and who and D.KNOWN[Lower(spell)] then
          local best
          for g, u in pairs(D.units) do
            if u.name == who and (not best or g == TG) then best = u end
          end
          if best then best.flash, best.flashUntil = f[2], GetTime() + 2 end
          if C.dots.resistsound == "1" then PlaySoundFile(D.IMG .. "resist.mp3") end
          return f[2], spell, who
        end
      end
    end
  end

  ev:SetScript("OnEvent", function()
    local e, a1 = event, arg1
    if e == "PLAYER_TARGET_CHANGED" then
      D.Add("target")
      D.dirty = true
    elseif e == "UPDATE_MOUSEOVER_UNIT" then
      if UnitCanAttack("player", "mouseover") and not UnitIsDead("mouseover") then D.Add("mouseover") end
    elseif e == "UNIT_COMBAT" then
      if a1 and UnitCanAttack("player", a1) then D.Add(a1) end
    elseif e == "NAME_PLATE_UNIT_ADDED" then
      if a1 and UnitCanAttack("player", a1) and UnitAffectingCombat(a1) then D.Add(a1) end
    elseif e == "UNIT_CASTEVENT" then
      -- SuperWoW: anyone's cast on anyone (caster, target, START|CAST|FAIL|CHANNEL, spell id)
      local caster, target, what, id = a1, arg2, arg3, arg4
      if not target or target == "" or not id then return end
      local me = D.Me()
      if caster == me and what == "FAIL" then
        local n = string.len(target)
        for k in pairs(D.pending) do if string.sub(k, 1, n) == target then D.pending[k] = nil end end
        return
      end
      if what ~= "CAST" and what ~= "CHANNEL" then return end
      if DATA.spells[id] then
        D.cast[target] = D.cast[target] or {}
        D.cast[target][id] = { t = GetTime(), caster = caster }
        if D.seen[target] then D.seen[target][id] = nil end
        -- (its auras are read again on the next pass)
        D.auraSeen[target] = true
      end
      if (caster == me or DATA.spells[id]) and not D.units[target] then
        local ok, hostile = pcall(UnitCanAttack, "player", target)
        if ok and hostile then D.Add(target) end
      end
      -- (25 Nov 2026, code review: casts were kept for every target, tracked or not, all session) only for tracked ones
      if not D.units[target] then D.cast[target], D.auraSeen[target] = nil, nil end
      if caster == me then D.dirty = true D.readAll = true end
    elseif e == "CHAT_MSG_SPELL_SELF_DAMAGE" then
      D.Failed(a1)
    elseif e == "PLAYER_ENTERING_WORLD" then
      D.me = nil
      D.Clear()
    else
      D.dirty = true
    end
  end)

  -- ---------------------------------------------------------------- multi-DoT: cast / target the best mob without it

  -- the best mob for a spell: alive, attackable, in combat (or your target), not too far, without your
  -- debuff of that name (or with under `refresh` s of it), none just cast at; order = marks|hp|lowhp
  function D.Pick(spell, order, refresh, opts)
    local want = Lower(spell)
    if want == "" then return end
    refresh = tonumber(refresh) or 0
    opts = opts or {}
    local t = GetTime()
    TG = D.SuperWoW() and Guid("target") or "target"
    if not D.SuperWoW() then D.Plain() end
    local cands = {}
    for g, u in pairs(D.units) do
      D.Info(u)
      D.Read(u, t)
      local ok = u.attackable and (u.combat or g == TG or opts.ooc) and not D.Ignored(u.name)
      local d = u.dist or (g ~= "target" and D.Distance(g))
      if ok and d and d > (opts.range or 36) then ok = nil end
      if ok and opts.minhp and u.hpmax > 0 and u.hpmax < opts.minhp then ok = nil end
      if ok and u.cc and C.dots.ccfade == "1" then ok = nil end
      if ok and D.pending[g .. want] then ok = nil end
      if ok then
        for i = 1, u.na do
          local a = u.auras[i]
          if a.kind == "mine" and a.name and Lower(a.name) == want and (not a.ends or a.ends - t > refresh) then ok = nil end
        end
      end
      if ok then table.insert(cands, u) end
    end
    local o = string.lower(order or "")
    ORDER = (o == "lowhp" or o == "lowest_hp") and "lowhp" or (o == "hp" or o == "highest_hp") and "hp"
      or (o == "marks" or o == "raid_mark" or o == "raid_mark_square" or o == "skull") and "marks" or (C.dots.order or "marks")
    table.sort(cands, Before)
    return cands[1]
  end
  -- casts it on that mob (SuperWoW casts on a GUID without a target swap); the mob when cast
  function D.Cast(spell, order, refresh, opts)
    local u = D.Pick(spell, order, refresh, opts)
    if not u then
      if opts and opts.warn then UIErrorsFrame:AddMessage("No enemy without your " .. spell, 1, .3, .3) end
      return
    end
    if D.SuperWoW() and u.guid ~= "target" then
      CastSpellByName(spell, u.guid)
    else
      CastSpellByName(spell)
    end
    D.pending[u.guid .. Lower(spell)] = GetTime() + 1.5
    return u
  end
  function D.TargetBest(spell, order, refresh, opts)
    local u = D.Pick(spell, order, refresh, opts)
    if u and D.SuperWoW() then pcall(TargetUnit, u.guid) end
    return u
  end

  -- "Spell|ORDER|options" (Cursive's macro form) -> spell, order, refresh, opts
  function D.ParseArgs(msg)
    local parts = {}
    for p in string.gfind(msg or "", "[^|]+") do table.insert(parts, (string.gsub(p, "^%s*(.-)%s*$", "%1"))) end
    local opts, refresh = {}, 0
    for word in string.gfind(parts[3] or "", "[^,]+") do
      local _, _, k, v = string.find(word, "^%s*(%w+)%s*=%s*(%d+)")
      if k == "minhp" then opts.minhp = tonumber(v)
      elseif k == "refreshtime" or k == "refresh" then refresh = tonumber(v) or 0
      elseif k == "range" then opts.range = tonumber(v)
      elseif string.find(word, "ooc") then opts.ooc = true
      elseif string.find(word, "warn") then opts.warn = true end
    end
    return parts[1] or "", parts[2], refresh, opts
  end

  function D.Slash(msg)
    msg = msg or ""
    local _, _, cmd, rest = string.find(msg, "^%s*(%S*)%s*(.-)%s*$")
    cmd = string.lower(cmd or "")
    if cmd == "cast" or cmd == "multicurse" then
      local spell, order, refresh, opts = D.ParseArgs(rest)
      D.Cast(spell, order, refresh, opts)
    elseif cmd == "curse" then
      -- Cursive's /cursive curse: your target only, when it lacks it
      local spell, _, refresh = D.ParseArgs(rest)
      local tg = D.SuperWoW() and Guid("target") or "target"
      if not D.SuperWoW() then D.Plain() end
      local u = tg and (D.units[tg] or D.Add("target"))
      if u then
        D.Read(u, GetTime())
        for i = 1, u.na do
          local a = u.auras[i]
          if a.kind == "mine" and a.name and Lower(a.name) == Lower(spell) and (not a.ends or a.ends - GetTime() > refresh) then return end
        end
      end
      CastSpellByName(spell)
    elseif cmd == "target" then
      local spell, order, refresh, opts = D.ParseArgs(rest)
      D.TargetBest(spell, order, refresh, opts)
    elseif cmd == "test" then
      if D.testUntil and GetTime() < D.testUntil then D.testUntil = 0 else D.Test(20) end
    elseif cmd == "clear" then
      D.Clear()
    elseif cmd == "ignore" then
      D.AddIgnore(rest ~= "" and rest or UnitName("target"))
    elseif cmd == "profile" and pfUI.dotsProfiles then
      local _, _, how, name = string.find(rest, "^(%S+)%s*(.-)$")
      pfUI.dotsProfiles.Slash(how, name)
    else
      local O = pfUI.octoui and pfUI.octoui.Options
      if O and O.Open and pfUI.gui then
        pfUI.gui:Show()
        O:Open("dotgeneral")
      end
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffOctoDoTs|r: /dot cast <spell>[|marks|hp|lowhp][|minhp=N,refresh=S]  /dot target <spell>  /dot test  /dot ignore [name]  /dot profile list|load|save|delete <name>")
    end
  end
  _G.SLASH_PFDOTS1, _G.SLASH_PFDOTS2 = "/dot", "/dots"
  _G.SlashCmdList.PFDOTS = D.Slash
  -- people's Cursive macros keep working while Cursive is not loaded
  if not (IsAddOnLoaded and (IsAddOnLoaded("Cursive") or IsAddOnLoaded("Cursive-Raid"))) and not _G.SlashCmdList.CURSIVE then
    _G.SLASH_PFDOTSCURSIVE1 = "/cursive"
    _G.SlashCmdList.PFDOTSCURSIVE = D.Slash
  end

  -- ---------------------------------------------------------------- profiles (per account)

  -- every setting as text lines: key=value, raid.<key>=1|0, list.<name>=a,b,c (no "|": safe in chat too)
  local P = {}
  pfUI.dotsProfiles = P
  D.Profiles = P
  local NOPOS = { x = true, y = true }
  function P.Store()
    pfUI_cache = pfUI_cache or {}
    pfUI_cache.dotprofiles = pfUI_cache.dotprofiles or {}
    return pfUI_cache.dotprofiles
  end
  function P.Snapshot(withpos)
    local out = {}
    for k, v in pairs(C.dots) do
      if type(v) == "string" then out[k] = v
      elseif type(v) == "table" then
        local copy = {}
        for kk, vv in pairs(v) do copy[kk] = vv end
        out[k] = copy
      end
    end
    if withpos and C.position and C.position.pfDotTracker then
      local pos = {}
      for k, v in pairs(C.position.pfDotTracker) do pos[k] = v end
      out._pos = pos
    end
    return out
  end
  function P.Apply(t)
    if type(t) ~= "table" then return end
    for k, v in pairs(t) do
      if k == "_pos" then
        if type(v) == "table" and C.position then
          C.position.pfDotTracker = {}
          for kk, vv in pairs(v) do C.position.pfDotTracker[kk] = vv end
          if UpdateMovable then UpdateMovable(frame, true) end
        end
      elseif type(v) == "table" then
        local copy = {}
        for kk, vv in pairs(v) do copy[kk] = vv end
        C.dots[k] = copy
      elseif not NOPOS[k] then
        C.dots[k] = v
      end
    end
    D.ApplyLayout()
  end
  function P.Save(name)
    if not name or name == "" then return end
    P.Store()[name] = P.Snapshot(C.dots.profpos == "1")
    C.dots.profile = name
    return true
  end
  function P.Load(name)
    local t = P.Store()[name or ""]
    if not t then return end
    P.Apply(t)
    C.dots.profile = name
    return true
  end
  function P.Delete(name)
    P.Store()[name or ""] = nil
    if C.dots.profile == name then C.dots.profile = "" end
  end
  function P.Names()
    local out = {}
    for k in pairs(P.Store()) do table.insert(out, k) end
    table.sort(out)
    return out
  end
  function P.Export()
    local t = P.Snapshot(C.dots.profpos == "1")
    local lines = { "pfUI-DoTTracker-1" }
    local keys = {}
    for k in pairs(t) do table.insert(keys, k) end
    table.sort(keys)
    for _, k in ipairs(keys) do
      local v = t[k]
      if type(v) == "string" then
        table.insert(lines, k .. "=" .. string.gsub(v, "[\r\n]", " "))
      elseif k == "raid" or k == "_pos" then
        local sub = {}
        for kk in pairs(v) do table.insert(sub, kk) end
        table.sort(sub)
        for _, kk in ipairs(sub) do table.insert(lines, k .. "." .. kk .. "=" .. tostring(v[kk])) end
      else
        local items = {}
        for _, x in ipairs(v) do table.insert(items, (string.gsub(tostring(x), ",", " "))) end
        table.insert(lines, "list." .. k .. "=" .. table.concat(items, ","))
      end
    end
    return table.concat(lines, "\n")
  end
  -- text -> settings table (nothing is run: only key=value lines are read)
  function P.Parse(text)
    if not text or not string.find(text, "pfUI%-DoTTracker%-1") then return end
    local t = {}
    for line in string.gfind(text, "[^\r\n]+") do
      local _, _, k, v = string.find(line, "^%s*([%w_%.]+)=(.*)$")
      if k then
        local _, _, tbl, sub = string.find(k, "^([%w_]+)%.([%w_]+)$")
        if tbl == "list" then
          local items = {}
          for x in string.gfind(v, "[^,]+") do table.insert(items, x) end
          t[sub] = items
        elseif tbl then
          t[tbl] = t[tbl] or {}
          t[tbl][sub] = tonumber(v) and tbl == "_pos" and tonumber(v) or v
        else
          t[k] = v
        end
      end
    end
    return t
  end
  function P.Import(text)
    local t = P.Parse(text)
    if not t then return end
    P.Apply(t)
    return true
  end
  -- the ready-made looks (Cursive's default profiles, in our words)
  P.PRESETS = {
    { key = "default", label = "Default", tip = "Your DoTs and the raid's armour and spell debuffs on every enemy in combat.",
      set = { showmine = "1", showraid = "1", showother = "0", missing = "0", incombat = "1", onlytarget = "0", mineonly = "0", markedonly = "0", armor = "0", rows = "8", cols = "1" } },
    { key = "full", label = "Everything", tip = "Every debuff, missing raid debuffs, armour and two columns.",
      set = { showmine = "1", showraid = "1", showother = "1", missing = "1", incombat = "1", onlytarget = "0", mineonly = "0", markedonly = "0", armor = "1", rows = "8", cols = "2" } },
    { key = "raid", label = "Raid debuff tracker", tip = "Only the raid's debuffs, with the missing ones in grey: for raid leaders and debuffers.",
      set = { showmine = "0", showraid = "1", showother = "0", missing = "1", incombat = "1", onlytarget = "0", mineonly = "0", markedonly = "0", armor = "0", rows = "8", cols = "1" } },
    { key = "armor", label = "Live armour", tip = "The raid's armour debuffs and each enemy's armour as it drops.",
      set = { showmine = "0", showraid = "1", showother = "0", missing = "1", incombat = "1", onlytarget = "0", mineonly = "0", markedonly = "0", armor = "1", armorshow = "total+removed", rows = "8", cols = "1" } },
    { key = "mine", label = "Only my DoTs", tip = "Just your own debuffs, on enemies that have them (multi-DoTting).",
      set = { showmine = "1", showraid = "0", showother = "0", missing = "0", incombat = "1", onlytarget = "0", mineonly = "1", markedonly = "0", armor = "0", rows = "8", cols = "1" } },
    { key = "target", label = "Target only", tip = "One row: your target and everything on it.",
      set = { showmine = "1", showraid = "1", showother = "1", missing = "0", incombat = "0", onlytarget = "1", mineonly = "0", markedonly = "0", armor = "1", rows = "1", cols = "1" } },
    { key = "pvp", label = "Enemy players", tip = "Enemy players near you, every debuff on them (battlegrounds).",
      set = { showmine = "1", showraid = "1", showother = "1", missing = "0", incombat = "0", onlytarget = "0", mineonly = "0", markedonly = "0", onlyplayers = "1", onlynpcs = "0", armor = "0", rows = "10", cols = "1" } },
  }
  function P.Preset(key)
    for _, p in ipairs(P.PRESETS) do
      if p.key == key then
        if p.key ~= "pvp" then C.dots.onlyplayers = "0" end
        for k, v in pairs(p.set) do C.dots[k] = v end
        C.dots.preset = key
        D.ApplyLayout()
        return true
      end
    end
  end
  function P.Slash(how, name)
    how = string.lower(how or "")
    local say = function(t) DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffOctoDoTs|r: " .. t) end
    if how == "list" then say(table.concat(P.Names(), ", "))
    elseif how == "save" then if P.Save(name) then say("saved " .. name) end
    elseif how == "load" then if P.Load(name) then say("loaded " .. name) else say("no profile " .. (name or "")) end
    elseif how == "delete" then P.Delete(name) say("deleted " .. (name or "")) end
  end

  D.ApplyLayout()
end)
