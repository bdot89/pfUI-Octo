pfUI:RegisterModule("rinse", "vanilla", function ()
  -- pfUI Octo :: OctoRinse (17 Nov 2026; user: "This is my rinse version i want to FULLY implement it into pfUI keeping
  -- all the settings making it use classicAPI or any DLL where it can to make it fast instant better ... all boss lists
  -- should be there. When you ignore a spell on the boss list this is only for bosses it wont affect PvP or other
  -- debuffs elsewhere its for that boss we choose only. dont generalise spells").
  -- UpsiRinse (MIT: Otari's Rinse, Upsilon's fork with the encounter browser) rebuilt on pfUI's frames. Its encounter
  -- lists are modules\rinse-data.lua unchanged. Every option it had is here (C.rinse, api\config.lua); its saved
  -- settings and learned debuffs are copied once when UpsiRinse is loaded next to pfUI (R.Import).
  --
  -- What changed:
  --   * Boss lists are per boss. A tick on Huhuran's Wyvern Sting acts only while Huhuran is being fought (in her zone,
  --     her or her adds seen in combat, or the debuff cast by them); a hunter's Wyvern Sting in a battleground is not
  --     touched. UpsiRinse wrote every tick into one global list. "Trash & Adds" acts in that zone while no boss is up.
  --     The shipped defaults that belong to a boss (Wyvern Sting, Mutating Injection, Ignite Mana...) became that
  --     boss's ticks; the rest (Curse of Recklessness, world buffs, school filters) stay in the "Everywhere" lists.
  --   * Instant: UNIT_AURA marks the raid dirty and the next frame rescans (UpsiRinse polled every 0.1 s).
  --   * ClassicAPI: C_UnitAuras.UnitAura names every debuff with its school and caster - no tooltip scan, and debuffs
  --     past 1.12's 16 slots are seen. Range from UnitXP (true reach), else ClassicAPI / SuperWoW distance; line of
  --     sight from UnitXP or ClassicAPI. Casts on the unit with SuperWoW (no target swap), else ClassicAPI
  --     C_Spell.CastAtUnit, else UpsiRinse's target swap. nampower's queue is still announced.
  --   * Runs only where you want it (raids / dungeons / battlegrounds / arenas / world).
  local R = { debuffs = {}, prio = {}, buttons = {}, engaged = {}, seen = {}, subgroup = {}, totemAt = {}, spells = {},
              slots = {}, totems = {} }
  pfUI.rinse = R
  local DATA = pfUI.rinseData or { schools = {}, zones = {} }
  R.DATA = DATA
  local lc = pfUI.api.libclient
  local _, myClass = UnitClass("player")
  R.class = myClass

  local function S() return C.rinse end
  local function On(k) return C.rinse[k] == "1" end
  local function Num(k, d) return tonumber(C.rinse[k]) or d end
  local function Wipe(t) for k in pairs(t) do t[k] = nil end end
  local SETN = table.setn and pcall(table.setn, {}, 0) and table.setn
  local function WipeList(t)
    for i = table.getn(t), 1, -1 do t[i] = nil end
    if SETN then SETN(t, 0) end
  end

  -- ---------------------------------------------------------------- tables from UpsiRinse

  R.SCHOOLS = { "Magic", "Curse", "Disease", "Poison", "Snare" }
  R.COLOR = {
    Magic = { .2, .6, 1, "3399ff" }, Curse = { .6, 0, 1, "9900ff" }, Disease = { .6, .4, 0, "996600" },
    Poison = { 0, .6, 0, "009900" }, Snare = { .8, 0, 0, "cc0000" }, Unknown = { .69, .69, .69, "b0b0b0" },
  }
  R.SCHOOLICON = {
    Magic = "Interface\\Icons\\Spell_Holy_DispelMagic", Curse = "Interface\\Icons\\Spell_Nature_RemoveCurse",
    Disease = "Interface\\Icons\\Spell_Nature_NullifyDisease", Poison = "Interface\\Icons\\Spell_Nature_NullifyPoison",
    Snare = "Interface\\Icons\\Spell_Holy_SealOfValor", Unknown = "Interface\\Icons\\INV_Misc_QuestionMark",
  }
  R.CLASSHEX = { WARRIOR = "c79c6e", DRUID = "ff7d0a", PALADIN = "f58cba", WARLOCK = "9482c9", MAGE = "69ccf0",
                 PRIEST = "ffffff", ROGUE = "fff569", HUNTER = "abd473", SHAMAN = "0070de", UNKNOWN = "808080" }
  R.CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
  R.CLASSNAME = { WARRIOR = "Warriors", PALADIN = "Paladins", HUNTER = "Hunters", ROGUE = "Rogues", PRIEST = "Priests",
                  SHAMAN = "Shamans", MAGE = "Mages", WARLOCK = "Warlocks", DRUID = "Druids" }
  local SPELLS = {
    PALADIN = { Magic = { "Cleanse" }, Poison = { "Cleanse", "Purify" }, Disease = { "Cleanse", "Purify" }, Snare = { "Hand of Freedom" } },
    DRUID = { Curse = { "Remove Curse" }, Poison = { "Abolish Poison", "Cure Poison" } },
    PRIEST = { Magic = { "Dispel Magic" }, Disease = { "Abolish Disease", "Cure Disease" } },
    SHAMAN = { Poison = { "Cure Poison" }, Disease = { "Cure Disease" } },
    MAGE = { Curse = { "Remove Lesser Curse" } },
    WARLOCK = { Magic = { "Devour Magic" } },
    WARRIOR = {}, ROGUE = {}, HUNTER = {},
  }
  R.SPELLS = SPELLS
  local TOTEMS = { Poison = "Poison Cleansing Totem", Disease = "Disease Cleansing Totem" }
  -- (17 Nov 2026, user: "make sure it uses totems etc if better to do ... icons") a totem row shows the totem's own picture
  R.TOTEMICON = { ["Poison Cleansing Totem"] = "Interface\\Icons\\Spell_Nature_PoisonCleansingTotem",
                  ["Disease Cleansing Totem"] = "Interface\\Icons\\Spell_Nature_DiseaseCleansingTotem" }
  local TOTEM_PULSE = 5
  -- snares Hand of Freedom takes off (the server reports no school for them)
  R.SNARES = {}
  for _, n in ipairs({ "Hamstring", "Wing Clip", "Mind Flay", "Web", "Enveloping Web", "Enveloping Webs", "Encasing Webs",
    "Surge of Mana", "Hooked Net", "Agonizing Concussion", "Incapacitating Shout", "Stomp", "Tendon Rip", "Web Explosion",
    "Web Spray" }) do R.SNARES[n] = true end
  -- UpsiRinse's shipped defaults; R.Seed puts each on the bosses that list it, the rest in "Everywhere"
  R.DEF_BLACK = { "Curse of Recklessness", "Delusions of Jin'do", "Dread of Outland", "Curse of Legion", "Phase Shifted",
    "Unstable Mana", "Seed of Corruption", "Mutating Injection", "Sanctum Mind Decay", "Wyvern Sting", "Poison Mushroom",
    "Gastronomic Guilt" }
  R.DEF_PRIO = { "Tranquilizing Poison", "Wyrmkins Venom", "Slowing Poison", "Mana Buildup", "Enveloped Flames",
    "Poison Charge", "Arcane Focus", "Freezing Chill" }
  R.DEF_HIDE = { "Icicles", "Arcane Overload", "Dreamless Sleep", "Greater Dreamless Sleep", "Songflower Serenade",
    "Mol'dar's Moxie", "Fengus' Ferocity", "Slip'kik's Savvy", "Thunderfury", "Magma Shackles" }
  R.DEF_CLASSHIDE = {
    WARRIOR = { "Ancient Hysteria", "Ignite Mana", "Tainted Mind", "Moroes Curse", "Curse of Manascale" },
    ROGUE = { "Silence", "Ancient Hysteria", "Ignite Mana", "Tainted Mind", "Smoke Bomb", "Screams of the Past",
      "Moroes Curse", "Curse of Manascale" },
    WARLOCK = { "Rift Entanglement" },
  }
  -- encounters fought as more than one NPC, or with adds that cast its debuffs: any of these names in combat = that boss
  R.ALIAS = {
    ["Basalthar & Smoldaris"] = { "Basalthar", "Smoldaris" },
    ["Lucifron"] = { "Flamewaker Protector" }, ["Garr"] = { "Firesworn" }, ["Sulfuron Harbinger"] = { "Flamewaker Priest" },
    ["Majordomo Executus"] = { "Flamewaker Healer", "Flamewaker Elite" }, ["Ragnaros"] = { "Son of Flame" },
    ["Golemagg the Incinerator"] = { "Core Rager" },
    ["Razorgore the Untamed"] = { "Grethok the Controller", "Blackwing Mage", "Blackwing Legionnaire", "Death Talon Dragonspawn" },
    ["Nefarian"] = { "Lord Victor Nefarius" },
    ["The Bug Family"] = { "Lord Kri", "Princess Yauj", "Vem" },
    ["The Twin Emperors"] = { "Emperor Vek'lor", "Emperor Vek'nilash" },
    ["C'Thun"] = { "Eye of C'Thun", "Eye Tentacle", "Claw Tentacle", "Giant Claw Tentacle", "Giant Eye Tentacle" },
    ["Fankriss the Unyielding"] = { "Spawn of Fankriss" },
    ["General Rajaxx"] = { "Captain Qeez", "Captain Tuubid", "Captain Drenn", "Captain Xurrem", "Major Yeggeth",
      "Major Pakkon", "Colonel Zerran" },
    ["Ayamiss the Hunter"] = { "Hive'Zara Larva" },
    ["The Four Horsemen"] = { "Highlord Mograine", "Thane Korth'azz", "Lady Blaumeux", "Sir Zeliek" },
    ["Grand Widow Faerlina"] = { "Naxxramas Worshipper", "Naxxramas Follower" },
    ["Maexxna"] = { "Maexxna Spiderling" },
    ["Kel'Thuzad"] = { "Soldier of the Frozen Wastes", "Unstoppable Abomination", "Soul Weaver", "Guardian of Icecrown" },
    ["High Priest Venoxis"] = { "Razzashi Cobra" }, ["High Priestess Jeklik"] = { "Bloodseeker Bat", "Frenzied Bloodseeker Bat" },
    ["High Priestess Mar'li"] = { "Spawn of Mar'li" }, ["High Priest Thekal"] = { "Zealot Lor'Khan", "Zealot Zath" },
    ["Jin'do the Hexxer"] = { "Shade of Jin'do", "Powerful Healing Ward", "Brain Wash Totem" },
    ["Bloodlord Mandokir"] = { "Ohgan" }, ["Hakkar"] = { "Son of Hakkar" },
    ["Onyxia"] = { "Onyxian Whelp", "Onyxian Warder" },
  }
  -- the browser's zone that is not a place: its ticks are the "Everywhere" lists
  R.EVERYWHERE = "Unsorted"

  -- ---------------------------------------------------------------- the encounter lists

  -- R.npc[name] = { key, ... } (boss + alias names); R.byName[spell] = { key, ... } (bosses that list it)
  R.npc, R.byName, R.keyZone, R.trashKeys = {}, {}, {}, {}
  function R.Key(zone, boss) return zone .. "^" .. boss end
  function R.IsTrash(boss) return boss == "Trash & Adds" or string.find(boss, "Trash$") and true or false end
  local function AddNpc(name, key)
    R.npc[name] = R.npc[name] or {}
    table.insert(R.npc[name], key)
  end
  for _, z in ipairs(DATA.zones) do
    if z.zone ~= R.EVERYWHERE then
      for _, b in ipairs(z.bosses) do
        local key = R.Key(z.zone, b.name)
        R.keyZone[key] = z
        if R.IsTrash(b.name) then
          table.insert(R.trashKeys, key)
        else
          AddNpc(b.name, key)
          for _, a in ipairs(R.ALIAS[b.name] or {}) do AddNpc(a, key) end
          -- "A & B" encounters: each name counts
          local _, _, x, y = string.find(b.name, "^(.-) & (.-)$")
          if x then AddNpc(x, key) AddNpc(y, key) end
        end
        for _, sp in ipairs(b.spells) do
          R.byName[sp[1]] = R.byName[sp[1]] or {}
          table.insert(R.byName[sp[1]], key)
        end
      end
    end
  end
  function R.FindZone(name)
    for _, z in ipairs(DATA.zones) do if z.zone == name then return z end end
  end
  -- is this real zone (GetRealZoneText) part of the display zone z? World Bosses (no zones) = anywhere
  function R.InZone(z, real)
    if not z then return end
    if table.getn(z.zones) == 0 then return true end
    for _, n in ipairs(z.zones) do if n == real then return true end end
  end

  -- ---------------------------------------------------------------- settings

  local function Cfg(name)
    if type(C.rinse[name]) ~= "table" then C.rinse[name] = {} end
    return C.rinse[name]
  end
  R.Cfg = Cfg
  local function Yes(v) return v == true or v == "1" end

  -- "Everywhere": black / hide / priority by name (hide also takes a school), class scopes
  function R.GlobalGet(spell, what)
    if what == "b" then return Yes(Cfg("black")[spell]) end
    if what == "h" then return Yes(Cfg("hide")[spell]) end
    if what == "p" then return Yes(Cfg("priority")[spell]) end
  end
  function R.GlobalSet(spell, what, v)
    local t = what == "b" and Cfg("black") or what == "h" and Cfg("hide") or Cfg("priority")
    t[spell] = v and "1" or "0"
    if what == "p" and not v then Cfg("prioclass")[spell] = nil end
    R.dirty = true
  end
  -- per boss: C.rinse.boss[key][spell] = { b, h, p = "1", pc = { CLASS = "1" }, hc = { CLASS = "1" } }
  function R.BossEntry(key, spell, make)
    local all = Cfg("boss")
    local k = all[key]
    if not k then
      if not make then return end
      k = {}
      all[key] = k
    end
    local e = k[spell]
    if not e and make then e = {} k[spell] = e end
    return e
  end
  function R.BossGet(key, spell, what)
    local e = R.BossEntry(key, spell)
    return e and Yes(e[what]) or false
  end
  function R.BossSet(key, spell, what, v)
    local e = R.BossEntry(key, spell, true)
    e[what] = v and "1" or nil
    if what == "p" and not v then e.pc = nil end
    R.dirty = true
  end
  -- class scope of priority ("pc") or hiding ("hc"): nil key = global
  function R.ScopeTable(key, spell, kind, make)
    if not key then
      local t = kind == "pc" and Cfg("prioclass") or nil
      if kind == "pc" then
        if not t[spell] and make then t[spell] = {} end
        return t[spell]
      end
      return nil
    end
    local e = R.BossEntry(key, spell, make)
    if not e then return end
    if not e[kind] and make then e[kind] = {} end
    return e[kind]
  end
  function R.ScopeGet(key, spell, kind, class)
    if not key and kind == "hc" then return Yes((Cfg("hideclass")[class] or {})[spell]) end
    local t = R.ScopeTable(key, spell, kind)
    return t and Yes(t[class]) or false
  end
  function R.ScopeSet(key, spell, kind, class, v)
    if not key and kind == "hc" then
      local hc = Cfg("hideclass")
      hc[class] = hc[class] or {}
      hc[class][spell] = v and "1" or "0"
      R.dirty = true
      return
    end
    local t = R.ScopeTable(key, spell, kind, true)
    t[class] = v and "1" or nil
    if v and kind == "pc" then
      if key then R.BossSet(key, spell, "p", true) else R.GlobalSet(spell, "p", true) end
    end
    if not next(t) then
      if key then
        local e = R.BossEntry(key, spell)
        if e then e[kind] = nil end
      else
        Cfg("prioclass")[spell] = nil
      end
    end
    R.dirty = true
  end
  function R.ScopeClear(key, spell, kind)
    if key then
      local e = R.BossEntry(key, spell)
      if e then e[kind] = nil end
    elseif kind == "pc" then
      Cfg("prioclass")[spell] = nil
    end
    R.dirty = true
  end

  -- UpsiRinse's defaults: boss debuffs onto their bosses, the others into "Everywhere". Once.
  function R.Seed(force)
    if C.rinse.seeded == "1" and not force then return end
    C.rinse.seeded = "1"
    local function Place(list, what)
      for _, n in ipairs(list) do
        local keys = R.byName[n]
        if keys then
          for _, key in ipairs(keys) do R.BossEntry(key, n, true)[what] = "1" end
        else
          R.GlobalSet(n, what, true)
        end
      end
    end
    Place(R.DEF_BLACK, "b")
    Place(R.DEF_PRIO, "p")
    Place(R.DEF_HIDE, "h")
    for class, list in pairs(R.DEF_CLASSHIDE) do
      for _, n in ipairs(list) do
        local keys = R.byName[n]
        if keys then
          for _, key in ipairs(keys) do
            local e = R.BossEntry(key, n, true)
            e.hc = e.hc or {}
            e.hc[class] = "1"
          end
        else
          R.ScopeSet(nil, n, "hc", class, true)
        end
      end
    end
    -- schools this class cannot cure are hidden (UpsiRinse's filter); the ones it can, shown
    for _, sc in ipairs(R.SCHOOLS) do
      if Cfg("hide")[sc] == nil then Cfg("hide")[sc] = SPELLS[myClass][sc] and "0" or "1" end
    end
  end

  -- ---------------------------------------------------------------- UpsiRinse's saved settings, once

  function R.UpsiLoaded()
    return IsAddOnLoaded and (IsAddOnLoaded("UpsiRinse") or IsAddOnLoaded("Rinse")) and true or nil
  end
  local function B(v) if v == nil then return nil end return v and "1" or "0" end
  function R.Import(force)
    local g, ch = _G.RINSE_CONFIG, _G.RINSE_CHAR_CONFIG
    if type(g) ~= "table" then return end
    if C.rinse.imported == "1" and not force then return end
    C.rinse.imported = "1"
    local s = C.rinse
    local map = { PRINT = "print", MSBT = "msbt", SOUND = "sound", BACKDROP = "backdrop", FLIP = "flip",
      SHOW_HEADER = "header", SHADOWFORM = "shadowform", IGNORE_ABOLISH = "abolish", PETS = "pets", TOTEMS = "totems",
      ENC_ONLY_MINE = "onlymine" }
    for from, to in pairs(map) do if g[from] ~= nil then s[to] = B(g[from]) end end
    if tonumber(g.SCALE) then s.scale = tostring(g.SCALE) end
    if tonumber(g.OPACITY) and g.OPACITY >= .1 then s.alpha = tostring(g.OPACITY) end
    if tonumber(g.BUTTONS) then s.buttons = tostring(g.BUTTONS) end
    local function Copy(list, into)
      for _, e in ipairs(list or {}) do
        if type(e) == "table" and e.name then table.insert(into, { name = e.name, class = e.class or "UNKNOWN" }) end
      end
    end
    s.skip, s.prio = {}, {}
    Copy(g.SKIP_ARRAY, s.skip)
    Copy(g.PRIO_ARRAY, s.prio)
    -- a debuff the old browser ticked that a boss lists goes to that boss, never to every fight (user: "dont generalise")
    local function Put(name, what, v)
      local keys = R.byName[name]
      if keys and not R.SCHOOL[name] then
        for _, key in ipairs(keys) do
          local e = R.BossEntry(key, name, true)
          e[what] = v and "1" or nil
        end
      else
        if what == "b" then Cfg("black")[name] = v and "1" or "0"
        elseif what == "h" then Cfg("hide")[name] = v and "1" or "0"
        else Cfg("priority")[name] = v and "1" or "0" end
      end
    end
    if type(ch) == "table" then
      for n, v in pairs(ch.BLACKLIST or {}) do Put(n, "b", v) end
      for n, v in pairs(ch.FILTER or {}) do Put(n, "h", v) end
      for n, v in pairs(ch.PRIORITY or {}) do Put(n, "p", v) end
      for n, classes in pairs(ch.PRIORITY_CLASS or {}) do
        for class, v in pairs(classes) do
          if v then
            local keys = R.byName[n]
            if keys then
              for _, key in ipairs(keys) do
                local e = R.BossEntry(key, n, true)
                e.pc = e.pc or {}
                e.pc[class] = "1"
              end
            else
              R.ScopeSet(nil, n, "pc", class, true)
            end
          end
        end
      end
      for class, list in pairs(ch.FILTER_CLASS or {}) do
        for n, v in pairs(list) do
          local keys = R.byName[n]
          if keys then
            for _, key in ipairs(keys) do
              local e = R.BossEntry(key, n, true)
              e.hc = e.hc or {}
              e.hc[class] = v and "1" or nil
            end
          else
            R.ScopeSet(nil, n, "hc", class, v and true or false)
          end
        end
      end
    end
    -- debuffs UpsiRinse learned in game
    if type(_G.RINSE_ENCOUNTERS) == "table" then
      local L = R.Learned()
      for zone, bosses in pairs(_G.RINSE_ENCOUNTERS) do
        if type(bosses) == "table" then
          L[zone] = L[zone] or {}
          for boss, spells in pairs(bosses) do
            if type(spells) == "table" then
              L[zone][boss] = L[zone][boss] or {}
              for n, sc in pairs(spells) do L[zone][boss][n] = sc end
            end
          end
        end
      end
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff33b3ffOctoRinse|r: copied UpsiRinse's settings, lists and learned debuffs.")
    return true
  end

  -- ---------------------------------------------------------------- learning (UpsiRinse's Observe)

  R.SCHOOL = { Magic = true, Curse = true, Disease = true, Poison = true, Snare = true }
  function R.Learned()
    pfUI_cache = pfUI_cache or {}
    pfUI_cache.rinselearned = pfUI_cache.rinselearned or {}
    return pfUI_cache.rinselearned
  end
  function R.Icons()
    pfUI_cache = pfUI_cache or {}
    pfUI_cache.rinseicons = pfUI_cache.rinseicons or {}
    return pfUI_cache.rinseicons
  end
  local observed = {}
  function R.Observe(name, school, texture)
    if not R.SCHOOL[school] then return end
    local icons = R.Icons()
    if texture and icons[name] ~= texture then icons[name] = texture end
    local real = GetRealZoneText and GetRealZoneText() or ""
    local zone, boss
    for key in pairs(R.active) do
      local z = R.keyZone[key]
      if z and table.getn(z.zones) > 0 then
        zone = z.zone
        local _, _, b = string.find(key, "%^(.+)$")
        if not R.IsTrash(b) then boss = b end
      end
    end
    if not zone then
      if GetNumRaidMembers() == 0 then return end
      zone = real
    end
    boss = boss or "Trash & Adds"
    local tag = zone .. "^" .. boss
    if observed[name] == tag then return end
    observed[name] = tag
    if real == "" then return end
    local L = R.Learned()
    L[zone] = L[zone] or {}
    L[zone][boss] = L[zone][boss] or {}
    L[zone][boss][name] = school
  end

  -- ---------------------------------------------------------------- which bosses are on now

  -- R.active[key] = true for every boss whose ticks count right now
  R.active = {}
  local fightStart = 0
  function R.Engage(name)
    local keys = name and R.npc[name]
    if not keys then return end
    local real = GetRealZoneText and GetRealZoneText() or ""
    for _, key in ipairs(keys) do
      if R.InZone(R.keyZone[key], real) then R.engaged[key] = GetTime() end
    end
  end
  local function Hostile(u)
    if not UnitExists(u) or UnitIsPlayer(u) or UnitIsFriend("player", u) then return end
    if UnitIsDead and UnitIsDead(u) then return end
    return UnitAffectingCombat(u)
  end
  local WATCH = { "target", "targettarget", "mouseover", "focus", "pettarget" }
  -- (22 Nov 2026, ClassicAPI of that day: boss1-boss5 tokens) while the client names the encounter's bosses itself,
  -- they are read directly and the walk over every raid member's target is skipped
  local BOSSES = { "boss1", "boss2", "boss3", "boss4", "boss5" }
  function R.Watch()
    for _, u in ipairs(WATCH) do
      local ok, yes = pcall(Hostile, u)
      if ok and yes then R.Engage(UnitName(u)) end
    end
    if _G.C_UnitAuras then
      local any
      for _, u in ipairs(BOSSES) do
        local ok, yes = pcall(Hostile, u)
        if ok and yes then R.Engage(UnitName(u)) any = true end
      end
      if any then return end
    end
    local n = GetNumRaidMembers()
    if n > 0 then
      for i = 1, n do if Hostile("raid" .. i .. "target") then R.Engage(UnitName("raid" .. i .. "target")) end end
    else
      for i = 1, GetNumPartyMembers() do if Hostile("party" .. i .. "target") then R.Engage(UnitName("party" .. i .. "target")) end end
    end
  end
  function R.UpdateActive()
    Wipe(R.active)
    local now, real = GetTime(), GetRealZoneText and GetRealZoneText() or ""
    local fighting = UnitAffectingCombat("player")
    local bossZone = {}
    for key, at in pairs(R.engaged) do
      if now - at < 8 or (fighting and at >= fightStart) then
        R.active[key] = true
        bossZone[R.keyZone[key]] = true
      elseif now - at > 600 then
        R.engaged[key] = nil
      end
    end
    -- trash of the zone you are in, while none of its bosses is up
    for _, key in ipairs(R.trashKeys) do
      local z = R.keyZone[key]
      if table.getn(z.zones) > 0 and R.InZone(z, real) and not bossZone[z] then R.active[key] = true end
    end
  end

  -- does a tick count for this debuff on this class now? what = "b" | "h" | "p"
  local function BossRule(name, class, what)
    for key in pairs(R.active) do
      local e = R.BossEntry(key, name)
      if e then
        if what == "h" then
          if Yes(e.h) or (class and e.hc and Yes(e.hc[class])) then return true end
        elseif Yes(e[what]) then
          if what ~= "p" or not e.pc or not next(e.pc) or (class and Yes(e.pc[class])) then return true end
        end
      end
    end
  end
  function R.IsBlack(name, class) return R.GlobalGet(name, "b") or BossRule(name, class, "b") end
  function R.IsPriority(name, class)
    if R.GlobalGet(name, "p") then
      local pc = Cfg("prioclass")[name]
      if not pc or not next(pc) or (class and Yes(pc[class])) then return true end
    end
    return BossRule(name, class, "p")
  end
  function R.IsHidden(name, school, class)
    local hide = Cfg("hide")
    if Yes(hide[name]) or Yes(hide[school]) then return true end
    local hc = Cfg("hideclass")[class or ""]
    if hc and Yes(hc[name]) then return true end
    return BossRule(name, class, "h")
  end

  -- ---------------------------------------------------------------- spells

  local book = myClass == "WARLOCK" and "pet" or BOOKTYPE_SPELL or "spell"
  R.usable, R.slot, R.totem = {}, {}, {}
  function R.UpdateSpells()
    Wipe(R.usable) Wipe(R.slot) Wipe(R.totem)
    if R.ranges then Wipe(R.ranges) end
    local all = {}
    if book == "pet" then
      local n = HasPetSpells and HasPetSpells() or 0
      for i = 1, (n or 0) do
        local name = GetSpellName(i, "pet")
        if name then all[name] = i end
      end
    else
      for tab = 1, (GetNumSpellTabs and GetNumSpellTabs() or 0) do
        local _, _, offset, count = GetSpellTabInfo(tab)
        for i = (offset or 0) + 1, (offset or 0) + (count or 0) do
          local name = GetSpellName(i, book)
          if name then all[name] = i end
        end
      end
    end
    if myClass == "SHAMAN" then
      for sc, t in pairs(TOTEMS) do
        if all[t] then R.totem[sc] = t R.slot[t] = all[t] end
      end
    end
    for sc, list in pairs(SPELLS[myClass] or {}) do
      -- the strongest spell is first in the list: look from the end so it wins
      for i = table.getn(list), 1, -1 do
        local sp = list[i]
        -- a paladin hiding Magic cures poison / disease with Purify (UpsiRinse)
        if not (sp == "Cleanse" and Yes(Cfg("hide").Magic)) and all[sp] then
          R.usable[sc] = sp
          R.slot[sp] = all[sp]
        end
      end
    end
  end
  function R.CanDispel(school) return SPELLS[myClass] and SPELLS[myClass][school] ~= nil end

  -- ---------------------------------------------------------------- reading debuffs

  local scan
  local superwow = SUPERWOW_VERSION
  local function Tooltip()
    if not scan then
      scan = CreateFrame("GameTooltip", "pfRinseScan", nil, "GameTooltipTemplate")
      scan:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    return scan
  end
  -- school, name, texture, stacks, caster name, duration, end time for debuff i of unit (nil = no more); the last two
  -- only from ClassicAPI (22 Nov 2026: the Timer bars look drains each row by its debuff's time left)
  function R.Debuff(unit, i)
    local name, school, tex, stacks, caster, dur, ends
    local ca = _G.C_UnitAuras
    if ca and ca.UnitAura and lc and lc.IsToken(unit) then
      local ok, n, icon, count, dtype, d, e, source = pcall(ca.UnitAura, unit, i, "HARMFUL")
      if not ok or not n then return end
      name, tex, stacks, school = n, icon, count, dtype
      if type(d) == "number" and d > 0 and type(e) == "number" and e > 0 then dur, ends = d, e end
      if source then
        local ok2, cn = pcall(UnitName, source)
        if ok2 then caster = cn end
      end
    elseif superwow then
      local spellId
      tex, stacks, school, spellId = UnitDebuff(unit, i)
      if not tex then return end
      if spellId and SpellInfo then name = SpellInfo(spellId) end
    else
      tex, stacks, school = UnitDebuff(unit, i)
      if not tex then return end
      local tt = Tooltip()
      tt:ClearLines()
      tt:SetUnitDebuff(unit, i)
      local l = _G["pfRinseScanTextLeft1"]
      name = l and l:GetText()
    end
    if name and not school and R.SNARES[name] then school = "Snare" end
    if school == "" then school = nil end
    return school or false, name, tex, stacks or 0, caster, dur, ends
  end

  -- ---------------------------------------------------------------- range and casting

  local unitxp = pcall(UnitXP, "nop", "nop")
  R.unitxp = unitxp
  -- (20 Nov 2026, a druid friend: "it doesnt range his cleanses ... with his talent. His action bar or spell icon can
  -- read when he has range") the cure's own range, talents included: C.rinse.range when set by hand, else what its
  -- spell tooltip says ("36 yd range"), else 30. Read again when the spells change (talents, ranks).
  R.ranges = {}
  function R.Range(spell)
    local own = tonumber(C.rinse.range)
    if own and own > 0 then return own end
    if not spell then return 30 end
    if R.ranges[spell] then return R.ranges[spell] end
    local yd = 30
    local slot = R.slot[spell]
    if slot then
      local tt = Tooltip()
      tt:ClearLines()
      local good = pcall(tt.SetSpell, tt, slot, book)
      if good then
        for i = 1, 8 do
          for _, side in ipairs({ "Right", "Left" }) do
            local l = _G["pfRinseScanText" .. side .. i]
            local t = l and l:GetText()
            local _, _, n = t and string.find(t, "(%d+) yd")
            if n and tonumber(n) and tonumber(n) > 5 then yd = tonumber(n) end
          end
        end
      end
    end
    R.ranges[spell] = yd
    return yd
  end
  function R.InRange(unit, spell)
    if not unit then return false end
    local ok
    if UnitIsFriend("player", unit) and not UnitCanAttack("player", unit) then
      -- ClassicAPI: the very check the action bar's range colour uses - talents, the target's size and all
      local cs = _G.C_Spell
      if spell and cs and cs.IsSpellInRange and lc and lc.IsToken and lc.IsToken(unit) then
        local o, r = pcall(cs.IsSpellInRange, spell, unit)
        if o and r ~= nil then ok = (r == true or r == 1) end
      end
      if ok == nil and _G.C_UnitAuras and _G.IsSpellInRange and spell then
        local o, r = pcall(_G.IsSpellInRange, spell, unit)
        if o and (r == 1 or r == 0) then ok = r == 1 end
      end
      -- distances: against the cure's own range (its tooltip, or your setting)
      if ok == nil and unitxp then
        local o, d = pcall(UnitXP, "distanceBetween", "player", unit)
        if o and d then ok = d < R.Range(spell) end
      end
      if ok == nil and lc and lc.Distance then
        local d = lc.Distance(unit)
        if d then ok = d <= R.Range(spell) + 3 end
      end
    end
    if ok == nil then ok = CheckInteractDistance(unit, 4) and true or false end
    if not ok then return false end
    if unitxp then
      local o, sight = pcall(UnitXP, "inSight", "player", unit)
      if o and sight ~= nil then return sight and true or false end
    end
    if lc and lc.LineOfSight then
      local los = lc.LineOfSight(unit)
      if los ~= nil then return los end
    end
    return UnitIsVisible(unit) and true or false
  end

  local function CanBeCleansed(unit)
    return (UnitCanAssist("player", unit) and not UnitIsCharmed(unit)) or (not UnitCanAssist("player", unit) and UnitIsCharmed(unit))
  end
  R.skipNames = {}
  R.groupOf = {}   -- player name -> raid group (a party is group 1)
  R.ownerOf = {}   -- pet unit -> its owner's name
  function R.RebuildSkip()
    Wipe(R.skipNames)
    for _, e in ipairs(Cfg("skip")) do if e.name then R.skipNames[e.name] = true end end
  end
  -- (17 Nov 2026, user: "look at other addons decursive etc how these have this quick menu with classes and players and
  -- fast rules") rules on top of the named lists: never cure / cure first by class or raid group, and my group first
  function R.RuleNever(class, group)
    if class and Yes(Cfg("neverclass")[class]) then return true end
    if group and Yes(Cfg("nevergroup")[tostring(group)]) then return true end
  end
  function R.RuleFirst(name, class, group)
    if On("mygroupfirst") and name and R.subgroup[name] then return true end
    if class and Yes(Cfg("firstclass")[class]) then return true end
    if group and Yes(Cfg("firstgroup")[tostring(group)]) then return true end
  end
  local function GoodUnit(unit)
    if not unit or not UnitExists(unit) then return end
    local name = UnitName(unit)
    if not name or R.skipNames[name] then return end
    local owner = R.ownerOf[unit]
    if owner then
      -- a pet follows its owner's never-cure rules
      if R.skipNames[owner] or R.RuleNever(nil, R.groupOf[owner]) then return end
    else
      local _, class = UnitClass(unit)
      if UnitIsPlayer(unit) and R.RuleNever(class, R.groupOf[name]) then return end
    end
    return UnitIsVisible(unit) and CanBeCleansed(unit)
  end

  -- ---------------------------------------------------------------- scan order (UpsiRinse's UpdatePrio)

  local DEFAULTPRIO = { "player", "party1", "party2", "party3", "party4" }
  for i = 1, 40 do table.insert(DEFAULTPRIO, "raid" .. i) end
  local function UnitOf(name)
    if not name then return end
    if UnitName("player") == name then return "player" end
    for i = 1, 4 do if UnitName("party" .. i) == name then return "party" .. i end end
    for i = 1, 40 do if UnitName("raid" .. i) == name then return "raid" .. i end end
  end
  R.UnitOf = UnitOf
  local function PetOf(u)
    if u == "player" then return "pet" end
    return (string.gsub(u, "^(%a+)(%d+)$", "%1pet%2"))
  end
  local named, ruled, rest, seenName = {}, {}, {}, {}
  -- order: your named cure-first players, then players a cure-first rule picks, then everyone else shuffled
  -- (so the healers running it spread out, as UpsiRinse did), pets last
  function R.UpdatePrio()
    Wipe(R.subgroup)
    Wipe(R.groupOf)
    Wipe(R.ownerOf)
    local me = UnitName("player") or ""
    R.subgroup[me] = true
    if GetNumRaidMembers() > 0 then
      local mine
      for i = 1, GetNumRaidMembers() do
        local n, _, g = GetRaidRosterInfo(i)
        if n then R.groupOf[n] = g end
        if n == me then mine = g end
      end
      for n, g in pairs(R.groupOf) do if g == mine then R.subgroup[n] = true end end
    else
      R.groupOf[me] = 1
      for i = 1, GetNumPartyMembers() do
        local n = UnitName("party" .. i)
        if n then R.subgroup[n] = true R.groupOf[n] = 1 end
      end
    end
    WipeList(named) WipeList(ruled) WipeList(rest) Wipe(seenName)
    local function Add(into, u)
      local name = UnitName(u)
      if name and not seenName[name] then
        seenName[name] = true
        table.insert(into, u)
      end
    end
    for _, e in ipairs(Cfg("prio")) do
      local u = UnitOf(e.name)
      if u then Add(named, u) end
    end
    for _, u in ipairs(DEFAULTPRIO) do
      if UnitExists(u) then
        local name = UnitName(u)
        local _, class = UnitClass(u)
        if R.RuleFirst(name, class, R.groupOf[name or ""]) then Add(ruled, u) else Add(rest, u) end
      end
    end
    -- shuffle the rest, not while debuffs are on the bar (the rows would jump)
    if not (R.buttons[1] and R.buttons[1]:IsShown()) then
      local last = table.getn(rest)
      for a = 1, last do
        local b = math.random(1, last)
        rest[a], rest[b] = rest[b], rest[a]
      end
    end
    local pets = {}
    for _, u in ipairs(DEFAULTPRIO) do
      if UnitExists(u) then
        local p = PetOf(u)
        if UnitExists(p) then
          R.ownerOf[p] = UnitName(u)
          Add(pets, p)
        end
      end
    end
    local list = R.prio
    WipeList(list)
    for _, part in ipairs({ named, ruled, rest, pets }) do
      for _, u in ipairs(part) do table.insert(list, u) end
    end
  end

  -- ---------------------------------------------------------------- the scan

  local MAXD = 42
  for i = 1, MAXD do R.debuffs[i] = {} end
  local function Totem(unitName, school, isPet)
    if not On("totems") then return false end
    local t = R.totem[school]
    if not t or isPet or not R.subgroup[unitName] then return false end
    local at = R.totemAt[t]
    if at and GetTime() - at < TOTEM_PULSE then return false end
    return t
  end
  local function HasAbolish(unit, school)
    if school ~= "Poison" and school ~= "Disease" then return end
    local icon = school == "Poison" and "Interface\\Icons\\Spell_Nature_NullifyPoison_02" or "Interface\\Icons\\Spell_Nature_NullifyDisease"
    local i = 1
    while true do
      local b = UnitBuff(unit, i)
      if not b then return end
      if b == icon then return true end
      i = i + 1
    end
  end
  local shadowform
  local function Shadowform()
    for i = 0, 31 do
      local idx = GetPlayerBuff(i, "HELPFUL")
      if idx and idx > -1 and GetPlayerBuffTexture(idx) == "Interface\\Icons\\Spell_Shadow_Shadowform" then return true end
    end
  end

  local count = 0
  local function Save(unit, e, class, abolish)
    local school, name = e.school, e.name
    local isPet = string.find(unit, "pet") ~= nil
    local isPrio = R.IsPriority(name, class)
    if isPet and not On("pets") and not isPrio then return end
    if not R.usable[school] then return end
    if not On("abolish") and abolish[school] then return end
    count = count + 1
    local d = R.debuffs[count]
    local uname = UnitName(unit) or ""
    d.name, d.school, d.tex, d.stacks, d.unit, d.unitName, d.class = name, school, e.tex, e.stacks, unit, uname, class
    d.index, d.hidden, d.prio, d.dur, d.ends = e.i, false, isPrio, e.dur, e.ends
    d.totem = Totem(uname, school, isPet)
    return true
  end

  -- (22 Nov 2026, user: "use classicAPI better") each player's debuffs are read once and kept: read again only when
  -- the game says that player's auras changed (UNIT_AURA, by name - a raid member can come as raidN or partyN), on a
  -- new name behind the token, and every R.FULL_EVERY s to be safe. It used to read every debuff of up to 40 players
  -- four times a second. The 0.25 s pass now only re-checks rules, range and order.
  R.FULL_EVERY = 2
  local reads, readAt, readName = {}, {}, {}
  R.auraChanged, R.reads = {}, reads
  local function ReadUnit(unit)
    local list = reads[unit] or { abolish = {} }
    reads[unit] = list
    local _, class = UnitClass(unit)
    local n, i, cure = 0, 1, nil
    while i <= 40 do
      local school, name, tex, stacks, caster, dur, ends = R.Debuff(unit, i)
      if school == nil then break end
      if caster then R.Engage(caster) end
      if school and name and class then
        R.Observe(name, school, tex)
        n = n + 1
        local e = list[n] or {}
        list[n] = e
        e.i, e.school, e.name, e.tex, e.stacks, e.dur, e.ends = i, school, name, tex, stacks, dur, ends
        if school == "Poison" or school == "Disease" then cure = true end
      end
      i = i + 1
    end
    list.n, list.class = n, class
    -- (Abolish Poison / Disease running: a buff read only when such a debuff is there)
    list.abolish.Poison = cure and HasAbolish(unit, "Poison") or nil
    list.abolish.Disease = cure and HasAbolish(unit, "Disease") or nil
  end
  -- forget every read (roster changes, a loading screen)
  function R.ForgetReads()
    for k in pairs(readAt) do readAt[k] = nil end
  end
  local function ScanUnit(unit, now)
    local name = UnitName(unit)
    if not reads[unit] or readName[unit] ~= name or (name and R.auraChanged[name]) or now - (readAt[unit] or -100) >= R.FULL_EVERY
      or now < (readAt[unit] or 0) then
      ReadUnit(unit)
      readAt[unit], readName[unit] = now, name
    end
    local list = reads[unit]
    for k = 1, list.n do
      if count >= MAXD - 1 then break end
      Save(unit, list[k], list.class, list.abolish)
    end
  end

  -- the order inside one part of the list (lo..hi): by C.rinse.sort = order (the scan's own) | health | time
  local function SortKey(d)
    local s = C.rinse.sort
    if s == "health" then
      local mx = UnitHealthMax(d.unit) or 0
      return mx > 0 and (UnitHealth(d.unit) or 0) / mx or 1
    elseif s == "time" then
      return d.ends and (d.ends - GetTime()) or 9999
    end
  end
  local function SortPart(list, lo, hi)
    if (C.rinse.sort or "order") == "order" then return end
    for i = lo, hi do list[i].key = SortKey(list[i]) or 0 end
    -- (insertion sort: a few dozen entries, and it keeps equal ones in the scan's order)
    for i = lo + 1, hi do
      local d, j = list[i], i - 1
      while j >= lo and list[j].key > d.key do list[j + 1] = list[j] j = j - 1 end
      list[j + 1] = d
    end
  end

  function R.Scan()
    count = 0
    local now = GetTime()
    R.UpdateActive()
    if GoodUnit("target") then ScanUnit("target", now) end
    for _, u in ipairs(R.prio) do
      if GoodUnit(u) and not UnitIsUnit("target", u) then ScanUnit(u, now) end
    end
    -- (every token of a changed player has been read now; marks for players not scanned need no keeping either:
    -- they are read anew within R.FULL_EVERY once they can be)
    Wipe(R.auraChanged)
    local list = R.debuffs
    for i = 1, count do
      local d = list[i]
      if R.IsBlack(d.name, d.class) then
        -- a blacklisted debuff hides its whole school on that player (Cleanse: everything)
        for j = 1, count do
          local d2 = list[j]
          if d2.unitName == d.unitName and (d2.school == d.school or R.usable[d.school] == "Cleanse") then d2.hidden = true end
        end
      end
      if d.prio then
        for j = 1, count do
          local d2 = list[j]
          if d2.unitName == d.unitName and not d2.prio then d2.hidden = true end
        end
      end
      if shadowform and On("shadowform") and d.school == "Disease" then d.hidden = true end
      if R.IsHidden(d.name, d.school, d.class) then d.hidden = true end
    end
    -- totems first (off the global cooldown), then priority debuffs
    local front = 1
    for i = 1, count do
      if not list[i].hidden and list[i].totem then
        list[front], list[i] = list[i], list[front]
        front = front + 1
      end
    end
    for i = front, count do
      if not list[i].hidden and list[i].prio then
        list[front], list[i] = list[i], list[front]
        front = front + 1
      end
    end
    SortPart(list, front, count)
    -- range once per pass (Paint fades by it); with C.rinse.oorlast the ones you cannot reach go to the bottom
    for i = 1, count do
      local d = list[i]
      d.near = (d.totem or R.InRange(d.unit, R.usable[d.school])) and true or false
    end
    if On("oorlast") then
      local near, far = {}, {}
      for i = 1, count do table.insert(list[i].near and near or far, list[i]) end
      local k = 0
      for _, d in ipairs(near) do k = k + 1 list[k] = d end
      for _, d in ipairs(far) do k = k + 1 list[k] = d end
    end
    R.count = count
    R.Paint()
  end

  -- ---------------------------------------------------------------- the bar

  local frame = CreateFrame("Frame", "pfRinse", UIParent)
  R.frame = frame
  frame:SetFrameStrata("MEDIUM")
  frame:SetPoint("CENTER", UIParent, "CENTER", -320, 120)
  frame:SetWidth(200)
  frame:SetHeight(60)
  frame:SetClampedToScreen(true)
  frame:Hide()

  local function Font() return pfUI.font_default end
  local head = CreateFrame("Frame", nil, frame)
  frame.head = head
  head:SetHeight(20)
  head.bg = head:CreateTexture(nil, "BACKGROUND")
  head.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
  head.bg:SetAllPoints(head)
  head.line = head:CreateTexture(nil, "ARTWORK")
  head.line:SetTexture("Interface\\Buttons\\WHITE8X8")
  head.line:SetHeight(1)
  head.line:SetPoint("BOTTOMLEFT", head, "BOTTOMLEFT", 0, 0)
  head.line:SetPoint("BOTTOMRIGHT", head, "BOTTOMRIGHT", 0, 0)
  head.icon = head:CreateTexture(nil, "ARTWORK")
  head.icon:SetWidth(14)
  head.icon:SetHeight(14)
  head.icon:SetPoint("LEFT", head, "LEFT", 4, 0)
  head.icon:SetTexture("Interface\\Icons\\Spell_Holy_DispelMagic")
  head.icon:SetTexCoord(.08, .92, .08, .92)
  head.text = head:CreateFontString(nil, "OVERLAY")
  head.text:SetPoint("LEFT", head.icon, "RIGHT", 5, 0)
  head.text:SetJustifyH("LEFT")
  head.boss = head:CreateFontString(nil, "OVERLAY")
  head.boss:SetJustifyH("RIGHT")
  -- small picture buttons on the title: bosses / players / options
  head.btns = {}
  local HEADBTN = {
    { "Interface\\Icons\\INV_Misc_Book_09", "Boss lists", "Pick a raid and a boss: what to skip, hide or cure first in that fight.", "rinsebosses" },
    { "Interface\\Icons\\Spell_Holy_PrayerOfHealing", "Players", "Click: the quick menu - classes, raid groups and players. "
      .. "Left-click = cure first, right-click = never cure. Works in combat. Right-click here: the full Players page.", "rinseplayers", quick = true },
    { "Interface\\Icons\\INV_Misc_Gear_01", "Options", "OctoRinse's settings.", "rinsegeneral" },
  }
  for i, d in ipairs(HEADBTN) do
    local b = CreateFrame("Button", nil, head)
    b:SetWidth(14)
    b:SetHeight(14)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetAllPoints(b)
    b.tex:SetTexture(d[1])
    b.tex:SetTexCoord(.08, .92, .08, .92)
    b:SetAlpha(.75)
    local dd = d
    b:SetScript("OnEnter", function()
      this:SetAlpha(1)
      GameTooltip:SetOwner(this, "ANCHOR_TOP")
      GameTooltip:SetText(dd[2], 1, 1, 1)
      GameTooltip:AddLine(dd[3], .8, .82, .86, 1)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() this:SetAlpha(.75) GameTooltip:Hide() end)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function()
      if dd.quick and arg1 ~= "RightButton" then R.ToggleQuick(this) else R.OpenOptions(dd[4]) end
    end)
    if i == 1 then b:SetPoint("RIGHT", head, "RIGHT", -4, 0) else b:SetPoint("RIGHT", head.btns[i - 1], "LEFT", -4, 0) end
    head.btns[i] = b
  end
  head.boss:SetPoint("RIGHT", head.btns[table.getn(HEADBTN)], "LEFT", -6, 0)

  function R.OpenOptions(key)
    if pfUI.gui and pfUI.gui.Show and not pfUI.gui:IsShown() then pfUI.gui:Show() end
    local O = pfUI.octoui and pfUI.octoui.Options
    if O and O.Open then O:Open(key or "rinsegeneral") end
  end

  -- ---------------------------------------------------------------- quick player menu
  -- (17 Nov 2026, user: "a quick select player list when you click this not opening the full UI ... possible in combat fast
  -- changes", then with a screenshot of the first try: "look at other addons decursive etc how these have this quick menu
  -- with classes and players and fast rules"). Like Decursive's priority / skip lists (add a class, a group, the target)
  -- but as live rules: a row of class pictures and of raid groups, my-group-first and pets, then every player. Everywhere:
  -- left-click = cure first, right-click = never cure, again = off; Shift + left on a player = top of cure first. Plain
  -- frames and settings only, so all of it works in combat.

  -- the named list a player is on: "prio", index | "skip", index | nil
  function R.ListOf(name)
    for i, e in ipairs(Cfg("prio")) do if e.name == name then return "prio", i end end
    for i, e in ipairs(Cfg("skip")) do if e.name == name then return "skip", i end end
  end
  local function Drop(name)
    local where, i = R.ListOf(name)
    while where do
      table.remove(Cfg(where), i)
      where, i = R.ListOf(name)
    end
  end
  local function Changed()
    R.RebuildSkip()
    R.UpdatePrio()
    R.dirty = true
    if R.QuickPaint then R.QuickPaint() end
  end
  -- what = "prio" | "top" | "skip": toggles that list for the player
  function R.QuickSet(name, class, what)
    if not name then return end
    local where = R.ListOf(name)
    Drop(name)
    if what == "top" then
      table.insert(Cfg("prio"), 1, { name = name, class = class or "UNKNOWN" })
    elseif where ~= what then
      table.insert(Cfg(what), { name = name, class = class or "UNKNOWN" })
    end
    Changed()
  end
  -- kind = "class" | "group", key = CLASS | "1".."8", what = "first" | "never": toggles the rule (the other side goes off)
  function R.RuleSet(kind, key, what)
    local mine, other = Cfg(what .. kind), Cfg((what == "first" and "never" or "first") .. kind)
    local on = not Yes(mine[key])
    mine[key] = on and "1" or nil
    if on then other[key] = nil end
    Changed()
  end
  function R.RuleState(kind, key)
    if Yes(Cfg("first" .. kind)[key]) then return "first" end
    if Yes(Cfg("never" .. kind)[key]) then return "never" end
  end
  function R.ClearRules()
    for _, k in ipairs({ "firstclass", "neverclass", "firstgroup", "nevergroup" }) do Wipe(Cfg(k)) end
    C.rinse.mygroupfirst = "0"
    Changed()
  end
  -- the group now: { { name, class, group } }, a raid by group number, else the party (group 1)
  function R.Roster()
    local out = {}
    if GetNumRaidMembers() > 0 then
      for i = 1, GetNumRaidMembers() do
        local n, _, g, _, _, c = GetRaidRosterInfo(i)
        if n then table.insert(out, { name = n, class = c or "UNKNOWN", group = g or 1 }) end
      end
    else
      for _, u in ipairs({ "player", "party1", "party2", "party3", "party4" }) do
        if UnitExists(u) then
          local _, c = UnitClass(u)
          table.insert(out, { name = UnitName(u), class = c or "UNKNOWN", group = 1 })
        end
      end
    end
    return out
  end

  local quick
  local QW, QH, PAD = 106, 18, 8
  local GOLD, RED = { 1, .82, .3 }, { 1, .35, .35 }
  local function Q(parent, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetTexture("Interface\\Buttons\\WHITE8X8")
    return t
  end
  local function QText(parent, size, flags)
    local t = parent:CreateFontString(nil, "OVERLAY")
    t:SetFont(Font(), size, flags or "")
    t:SetJustifyH("LEFT")
    return t
  end
  local function Tip(b, title, lines)
    b:SetScript("OnEnter", function()
      if this.hl then this.hl:Show() end
      GameTooltip:SetOwner(this, "ANCHOR_TOP")
      GameTooltip:SetText(type(title) == "function" and title(this) or title, 1, 1, 1)
      local l = type(lines) == "function" and lines(this) or lines
      for _, s in ipairs(l or {}) do GameTooltip:AddLine(s, .8, .82, .86, 1) end
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if this.hl then this.hl:Hide() end GameTooltip:Hide() end)
  end
  -- paint a rule / list state on a button's back and edge
  local function State(b, st)
    if st == "first" then
      b.back:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], .25)
      b.line:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
      b.line:Show()
    elseif st == "never" then
      b.back:SetVertexColor(RED[1], RED[2], RED[3], .2)
      b.line:SetVertexColor(RED[1], RED[2], RED[3], 1)
      b.line:Show()
    else
      b.back:SetVertexColor(1, 1, 1, .05)
      b.line:Hide()
    end
  end
  local function Label(y, text)
    local t = QText(quick, 9)
    t:SetPoint("TOPLEFT", quick, "TOPLEFT", PAD, y)
    t:SetTextColor(.52, .53, .57)
    t:SetText(text)
    return t
  end
  local function SmallButton(w, h)
    local b = CreateFrame("Button", nil, quick)
    b:SetWidth(w)
    b:SetHeight(h)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.back = Q(b, "BACKGROUND")
    b.back:SetAllPoints(b)
    b.line = Q(b, "ARTWORK")
    b.line:SetHeight(2)
    b.line:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
    b.line:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
    b.hl = Q(b, "OVERLAY")
    b.hl:SetAllPoints(b)
    b.hl:SetVertexColor(1, 1, 1, .1)
    b.hl:Hide()
    return b
  end

  local function QuickFrame()
    if quick then return quick end
    quick = CreateFrame("Frame", "pfRinseQuick", UIParent)
    quick:SetFrameStrata("DIALOG")
    quick:SetClampedToScreen(true)
    quick:EnableMouse(true)
    quick.bg = Q(quick, "BACKGROUND")
    quick.bg:SetAllPoints(quick)
    quick.bg:SetVertexColor(.05, .055, .065, .96)
    quick.top = Q(quick, "BORDER")
    quick.top:SetHeight(1)
    quick.top:SetPoint("TOPLEFT", quick, "TOPLEFT", 0, 0)
    quick.top:SetPoint("TOPRIGHT", quick, "TOPRIGHT", 0, 0)
    quick.bot = Q(quick, "BORDER")
    quick.bot:SetHeight(1)
    quick.bot:SetPoint("BOTTOMLEFT", quick, "BOTTOMLEFT", 0, 0)
    quick.bot:SetPoint("BOTTOMRIGHT", quick, "BOTTOMRIGHT", 0, 0)
    -- title
    quick.icon = quick:CreateTexture(nil, "ARTWORK")
    quick.icon:SetWidth(16)
    quick.icon:SetHeight(16)
    quick.icon:SetTexCoord(.08, .92, .08, .92)
    quick.icon:SetTexture("Interface\\Icons\\Spell_Holy_PrayerOfHealing")
    quick.icon:SetPoint("TOPLEFT", quick, "TOPLEFT", PAD, -6)
    quick.title = QText(quick, 12, "OUTLINE")
    quick.title:SetPoint("LEFT", quick.icon, "RIGHT", 6, 0)
    quick.title:SetText("Who to cure")
    quick.count = QText(quick, 10)
    quick.count:SetPoint("LEFT", quick.title, "RIGHT", 8, 0)
    quick.count:SetTextColor(.6, .62, .66)
    local x = CreateFrame("Button", nil, quick)
    x:SetWidth(18)
    x:SetHeight(18)
    x:SetPoint("TOPRIGHT", quick, "TOPRIGHT", -4, -4)
    x.t = QText(x, 13, "OUTLINE")
    x.t:SetAllPoints(x)
    x.t:SetJustifyH("CENTER")
    x.t:SetText("x")
    x.t:SetTextColor(.6, .62, .66)
    x:SetScript("OnClick", function() quick:Hide() end)

    -- classes: one picture each
    quick.classLabel = Label(-30, "CLASSES")
    quick.classes = {}
    for i, c in ipairs(R.CLASSES) do
      local b = SmallButton(28, 28)
      b:SetPoint("TOPLEFT", quick, "TOPLEFT", PAD + (i - 1) * 31, -42)
      b.pic = b:CreateTexture(nil, "ARTWORK")
      b.pic:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
      b.pic:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
      b.pic:SetTexture(pfUI.media and pfUI.media["img:classicons"] or "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
      local tc = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[c]
      if tc then b.pic:SetTexCoord(tc[1], tc[2], tc[3], tc[4]) end
      b.n = QText(b, 9, "OUTLINE")
      b.n:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 2)
      b.n:SetJustifyH("RIGHT")
      b.key = c
      b:SetScript("OnClick", function() R.RuleSet("class", this.key, arg1 == "RightButton" and "never" or "first") end)
      Tip(b, function(s) return "|cff" .. R.CLASSHEX[s.key] .. R.CLASSNAME[s.key] .. "|r" end, function(s)
        local st = R.RuleState("class", s.key)
        return { st == "first" and "|cffffd24dCured first|r" or st == "never" and "|cffff6060Never cured|r" or "Normal",
          "Left-click: cure first.  Right-click: never cure.  Again: off.",
          "Counts for anyone of the class, joining later too." }
      end)
      quick.classes[i] = b
    end

    -- raid groups
    quick.groupLabel = Label(-78, "RAID GROUPS")
    quick.groups = {}
    for g = 1, 8 do
      local b = SmallButton(31, 20)
      b:SetPoint("TOPLEFT", quick, "TOPLEFT", PAD + (g - 1) * 34, -90)
      b.t = QText(b, 11, "OUTLINE")
      b.t:SetAllPoints(b)
      b.t:SetJustifyH("CENTER")
      b.t:SetText(g)
      b.key = tostring(g)
      b:SetScript("OnClick", function() R.RuleSet("group", this.key, arg1 == "RightButton" and "never" or "first") end)
      Tip(b, function(s) return "Group " .. s.key end, function(s)
        local st = R.RuleState("group", s.key)
        return { st == "first" and "|cffffd24dCured first|r" or st == "never" and "|cffff6060Never cured|r" or "Normal",
          "Left-click: cure first.  Right-click: never cure.  Again: off." }
      end)
      quick.groups[g] = b
    end

    -- quick switches
    quick.toggles = {}
    local TOG = {
      { "My group first", "mygroupfirst", "Your own raid group is cured before everyone but your named players." },
      { "Pets", "pets", "Cure pets too (off: only their cure-first debuffs)." },
    }
    for i, d in ipairs(TOG) do
      local b = SmallButton(i == 1 and 104 or 54, 20)
      b.t = QText(b, 10)
      b.t:SetAllPoints(b)
      b.t:SetJustifyH("CENTER")
      b.t:SetText(d[1])
      b.key = d[2]
      b:SetScript("OnClick", function()
        C.rinse[this.key] = C.rinse[this.key] == "1" and "0" or "1"
        Changed()
      end)
      Tip(b, d[1], { d[3], "Click: on / off." })
      quick.toggles[i] = b
    end

    -- foot
    quick.hint = QText(quick, 9)
    quick.hint:SetTextColor(.6, .62, .66)
    quick.hint:SetText("|cffffd24dLeft|r cure first   |cffffd24dShift+Left|r top   |cffff6060Right|r never   again = off")
    quick.foot = {}
    local FOOT = {
      { "Add target", function()
        if UnitExists("target") and UnitIsPlayer("target") and UnitIsFriend("player", "target") then
          local _, c = UnitClass("target")
          R.QuickSet(UnitName("target"), c, arg1 == "RightButton" and "skip" or "prio")
        end
      end, { "Your friendly target: left-click = cure first, right-click = never cure." } },
      { "Clear players", function() WipeList(Cfg("prio")) WipeList(Cfg("skip")) Changed() end, { "Empties both player lists." } },
      { "Clear rules", function() R.ClearRules() end, { "Class and group rules and My group first off." } },
      { "Full page", function() quick:Hide() R.OpenOptions("rinseplayers") end, { "The Players page in the options." } },
    }
    for i, d in ipairs(FOOT) do
      local b = SmallButton(74, 18)
      b.back:SetVertexColor(.14, .15, .17, 1)
      b.t = QText(b, 9)
      b.t:SetAllPoints(b)
      b.t:SetJustifyH("CENTER")
      b.t:SetText(d[1])
      b:SetScript("OnClick", d[2])
      Tip(b, d[1], d[3])
      quick.foot[i] = b
    end
    quick.heads, quick.cells = {}, {}
    table.insert(UISpecialFrames, "pfRinseQuick")
    quick:RegisterEvent("RAID_ROSTER_UPDATE")
    quick:RegisterEvent("PARTY_MEMBERS_CHANGED")
    quick:SetScript("OnEvent", function() if this:IsShown() then R.QuickPaint() end end)
    quick:Hide()
    return quick
  end

  local function QuickCell(i)
    local c = quick.cells[i]
    if c then return c end
    c = SmallButton(QW, QH - 2)
    c.line:ClearAllPoints()
    c.line:SetWidth(2)
    c.line:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
    c.line:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 0)
    c.t = QText(c, 10)
    c.t:SetPoint("LEFT", c, "LEFT", 6, 0)
    c.t:SetPoint("RIGHT", c, "RIGHT", -18, 0)
    c.tag = QText(c, 9, "OUTLINE")
    c.tag:SetPoint("RIGHT", c, "RIGHT", -3, 0)
    c.tag:SetJustifyH("RIGHT")
    c:SetScript("OnClick", function()
      if not this.who then return end
      local what = "prio"
      if arg1 == "RightButton" then what = "skip" elseif IsShiftKeyDown() then what = "top" end
      R.QuickSet(this.who.name, this.who.class, what)
    end)
    Tip(c, function(s) return s.who and ("|cff" .. (R.CLASSHEX[s.who.class] or "ffffff") .. s.who.name .. "|r") or "" end, function(s)
      if not s.who then return {} end
      return { s.why or "Normal", "Left-click: cure first.  Shift: to the top.  Right-click: never cure." }
    end)
    quick.cells[i] = c
    return c
  end

  function R.QuickPaint()
    if not quick then return end
    local roster = R.Roster()
    local raid = GetNumRaidMembers() > 0
    -- class counts and rule states
    local per = {}
    for _, e in ipairs(roster) do per[e.class] = (per[e.class] or 0) + 1 end
    for _, b in ipairs(quick.classes) do
      State(b, R.RuleState("class", b.key))
      b.n:SetText(per[b.key] or "")
      b.pic:SetAlpha(per[b.key] and 1 or .35)
    end
    local y = -42 - 28 - 8
    if raid then
      quick.groupLabel:Show()
      for _, b in ipairs(quick.groups) do
        State(b, R.RuleState("group", b.key))
        b:Show()
      end
      y = -90 - 20 - 8
    else
      quick.groupLabel:Hide()
      for _, b in ipairs(quick.groups) do b:Hide() end
    end
    -- switches
    local tx = PAD
    for _, b in ipairs(quick.toggles) do
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", quick, "TOPLEFT", tx, y)
      tx = tx + b:GetWidth() + 4
      State(b, nil)
      if C.rinse[b.key] == "1" then
        b.back:SetVertexColor(.25, .85, .47, .22)
        b.line:SetVertexColor(.25, .85, .47, 1)
        b.line:Show()
      end
    end
    y = y - 20 - 10
    -- players by group; people on a list who left the group stay, to be taken off
    local groups, order, here = {}, {}, {}
    for _, e in ipairs(roster) do
      if not groups[e.group] then groups[e.group] = {} table.insert(order, e.group) end
      table.insert(groups[e.group], e)
      here[e.name] = true
    end
    table.sort(order)
    local away = {}
    for _, f in ipairs({ "prio", "skip" }) do
      for _, e in ipairs(Cfg(f)) do
        if e.name and not here[e.name] then
          here[e.name] = true
          table.insert(away, { name = e.name, class = e.class, group = 0 })
        end
      end
    end
    if away[1] then groups[0] = away table.insert(order, 0) end
    local cols = math.min(4, math.max(1, table.getn(order)))
    local width = math.max(PAD * 2 + 9 * 31 - 3, PAD * 2 + cols * (QW + 4) - 4)
    for _, h in ipairs(quick.heads) do h:Hide() end
    for _, c in ipairs(quick.cells) do c:Hide() c.who = nil end
    local ci, tallest, nFirst, nNever = 0, 0, 0, 0
    for gi, g in ipairs(order) do
      local col = math.mod(gi - 1, cols)
      if col == 0 and gi > 1 then y = y - tallest - 6 tallest = 0 end
      local hx = PAD + col * (QW + 4)
      local h = quick.heads[gi]
      if not h then
        h = QText(quick, 9)
        quick.heads[gi] = h
      end
      h:ClearAllPoints()
      h:SetPoint("TOPLEFT", quick, "TOPLEFT", hx + 1, y)
      local gs = R.RuleState("group", tostring(g))
      local gcol = gs == "first" and "ffd24d" or gs == "never" and "ff6060" or "8a8f99"
      h:SetText("|cff" .. gcol .. (g == 0 and "NOT IN GROUP" or raid and ("GROUP " .. g) or "PARTY") .. "|r")
      h:Show()
      for r, e in ipairs(groups[g]) do
        ci = ci + 1
        local c = QuickCell(ci)
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", quick, "TOPLEFT", hx, y - 12 - (r - 1) * QH)
        c.who = e
        local where, idx = R.ListOf(e.name)
        local grp = g ~= 0 and g or nil
        local ruleNever = R.RuleNever(e.class, grp)
        local ruleFirst = R.RuleFirst(e.name, e.class, grp)
        c.t:SetText("|cff" .. (R.CLASSHEX[e.class] or "ffffff") .. e.name .. "|r")
        if where == "prio" then
          State(c, "first")
          c.tag:SetText("|cffffd24d" .. idx .. "|r")
          c.t:SetAlpha(1)
          c.why = "|cffffd24dCure first, number " .. idx .. "|r"
          nFirst = nFirst + 1
        elseif where == "skip" or ruleNever then
          State(c, "never")
          c.tag:SetText(where == "skip" and "|cffff6060X|r" or "|cffff6060-|r")
          c.t:SetAlpha(.5)
          c.why = where == "skip" and "|cffff6060Never cured|r" or "|cffff6060Never cured by a class / group rule|r"
          nNever = nNever + 1
        elseif ruleFirst then
          State(c, nil)
          c.back:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], .1)
          c.tag:SetText("|cffffd24d+|r")
          c.t:SetAlpha(1)
          c.why = "|cffffd24dCured early by a rule|r"
          nFirst = nFirst + 1
        else
          State(c, nil)
          c.tag:SetText("")
          c.t:SetAlpha(1)
          c.why = nil
        end
        c:Show()
      end
      tallest = math.max(tallest, 12 + table.getn(groups[g]) * QH)
    end
    y = y - tallest - 6
    quick.count:SetText(table.getn(roster) .. " in group  |cffffd24d" .. nFirst .. " first|r  |cffff6060" .. nNever .. " never|r")
    quick.hint:ClearAllPoints()
    quick.hint:SetPoint("TOPLEFT", quick, "TOPLEFT", PAD, y)
    y = y - 14
    local fw = math.floor((width - PAD * 2 - 3 * 4) / 4)
    for i, b in ipairs(quick.foot) do
      b:SetWidth(fw)
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", quick, "TOPLEFT", PAD + (i - 1) * (fw + 4), y)
    end
    y = y - 18 - PAD
    quick:SetWidth(width)
    quick:SetHeight(-y)
    local ar, ag, ab = .2, .7, 1
    if pfUI.api.GetAccentColor then
      local ok, r, g, b = pcall(pfUI.api.GetAccentColor)
      if ok and r then ar, ag, ab = r, g, b end
    end
    quick.top:SetVertexColor(ar, ag, ab, .9)
    quick.bot:SetVertexColor(ar, ag, ab, .3)
  end

  function R.ToggleQuick()
    QuickFrame()
    if quick:IsShown() then quick:Hide() return end
    quick:ClearAllPoints()
    -- beside the bar, on the side with room
    local x = frame:GetCenter()
    local sw = UIParent:GetWidth() or 1024
    if x and x * (frame:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1) > sw / 2 then
      quick:SetPoint("TOPRIGHT", frame, "TOPLEFT", -4, 0)
    else
      quick:SetPoint("TOPLEFT", frame, "TOPRIGHT", 4, 0)
    end
    R.QuickPaint()
    quick:Show()
  end

  -- (26 Nov 2026) class colours that stay readable on a dark row (shaman blue, warlock purple were too dark)
  R.BRIGHTHEX = { SHAMAN = "3d9bff", WARLOCK = "a98bf0", PRIEST = "ffffff", MAGE = "7fdcff" }
  local function NewButton(i)
    local b = CreateFrame("Button", "pfRinseButton" .. i, frame)
    b:RegisterForClicks("LeftButtonDown")
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    b.bg:SetAllPoints(b)
    b.wash = b:CreateTexture(nil, "BORDER")
    b.wash:SetTexture("Interface\\Buttons\\WHITE8X8")
    b.wash:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    b.wash:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
    b.wash:SetWidth(60)
    if b.wash.SetGradientAlpha then b.wash:SetGradientAlpha("HORIZONTAL", 1, 1, 1, .35, 1, 1, 1, 0) end
    b.edge = b:CreateTexture(nil, "ARTWORK")
    b.edge:SetTexture("Interface\\Buttons\\WHITE8X8")
    b.edge:SetWidth(3)
    b.edge:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    b.edge:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
    b.iconbg = b:CreateTexture(nil, "ARTWORK")
    b.iconbg:SetTexture("Interface\\Buttons\\WHITE8X8")
    b.icon = b:CreateTexture(nil, "OVERLAY")
    b.icon:SetTexCoord(.08, .92, .08, .92)
    b.count = b:CreateFontString(nil, "OVERLAY")
    b.count:SetJustifyH("RIGHT")
    b.debuff = b:CreateFontString(nil, "OVERLAY")
    b.debuff:SetJustifyH("LEFT")
    b.player = b:CreateFontString(nil, "OVERLAY")
    b.player:SetJustifyH("LEFT")
    b.tag = b:CreateFontString(nil, "OVERLAY")
    b.tag:SetJustifyH("RIGHT")
    -- (22 Nov 2026) seconds left, on the icon (looks with timetext, or C.rinse.showtime)
    b.timer = b:CreateFontString(nil, "OVERLAY")
    b.timer:SetJustifyH("CENTER")
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetTexture("Interface\\Buttons\\WHITE8X8")
    b.hl:SetAllPoints(b)
    b.hl:SetVertexColor(1, 1, 1, .07)
    -- (20 Nov 2026) a border in the school's colour, and the top row's pulse
    b.rim = CreateFrame("Frame", nil, b)
    b.rim:SetAllPoints(b)
    b.rim:SetFrameLevel(b:GetFrameLevel() + 2)
    b.glow = b:CreateTexture(nil, "OVERLAY")
    b.glow:SetTexture("Interface\\Buttons\\WHITE8X8")
    b.glow:SetAllPoints(b)
    b.glow:SetBlendMode("ADD")
    b.glow:Hide()
    b:SetScript("OnClick", function() R.Cleanse(this) end)
    b:SetScript("OnEnter", function()
      if not this.unit then return end
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      local c = R.COLOR[this.school] or R.COLOR.Unknown
      GameTooltip:SetText(this.debuffName or "", c[1], c[2], c[3])
      GameTooltip:AddLine((this.school or "") .. " on |cff" .. (R.CLASSHEX[this.class] or "ffffff") .. (this.unitName or "") .. "|r", 1, 1, 1)
      if this.totem then GameTooltip:AddLine("Drops " .. this.totem .. " (your group, off the global cooldown).", .25, .85, .47, 1) end
      GameTooltip:AddLine("Click: cure it. Your OctoRinse key cures the top one.", .6, .62, .66, 1)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:Hide()
    return b
  end

  -- (20 Nov 2026, user: "our rinse is quite hard to see give it different layout options ... different UI options and
  -- bar options") the looks: fill = the row's school-colour fill (0 = only the fade at its left), rim = a border in the
  -- school's colour, big = larger words, oneline = player and debuff on one line, grid = a row of big icons
  R.LOOKS = {
    { key = "octo", label = "pfUI Octo", tip = "Dark rows, a fade of the school's colour at the left, the debuff over the player." },
    { key = "bars", label = "Bars", fill = .55, edge = 4, tip = "Each row filled with its school's colour - you see what to cure from across the screen." },
    { key = "bright", label = "Bright", fill = .75, rim = 2, big = 2, edge = 4, tip = "A strong fill, a border in the school's colour and bigger words: the easiest to see." },
    { key = "compact", label = "Compact", oneline = true, small = true, tip = "Slim rows: player and debuff on one line." },
    { key = "icons", label = "Icons", grid = true, rim = 2, tip = "A row of big debuff icons, each framed in its school's colour, the player's name under it." },
    -- (22 Nov 2026, user: "more bar and layout looks to make it easier to see and better less stress")
    --   mode  what fills the row: timer = the debuff's time left (ClassicAPI), health = the player's health in their
    --         class colour, class = the class colour; else the school's colour
    --   spot  the top row (the next cure) large, the rest slim      calm  no pulse, no sound, rows stay put, soft fill
    --   wrap  big icons in rows of C.rinse.columns
    { key = "timer", label = "Timer bars", mode = "timer", fill = .6, edge = 4, timetext = true,
      tip = "Each row drains like a cast bar as its debuff runs out (ClassicAPI), the seconds on the icon - cure the shortest first." },
    { key = "health", label = "Health bars", mode = "health", fill = .7, edge = 5, rim = 1,
      tip = "Each row filled with the player's health in their class colour, the debuff's school on the left edge - save the one who is dying." },
    { key = "spotlight", label = "Spotlight", spot = true, fill = .7, rim = 2, edge = 5,
      tip = "The next cure large and bright on top, the rest small under it: one thing to look at." },
    { key = "calm", label = "Calm", calm = true, fill = .18, edge = 2, oneline = true,
      tip = "Soft colours, no pulse or sound, and rows stay where they are while their debuff lasts - nothing jumps about." },
    { key = "tiles", label = "Tiles", grid = true, wrap = true, rim = 2, timetext = true,
      tip = "Big icons in rows (Columns sets how many a row), framed in the school's colour, the seconds left on each." },
  }
  function R.Look()
    for _, l in ipairs(R.LOOKS) do if l.key == C.rinse.look then return l end end
    return R.LOOKS[1]
  end
  function R.ApplyLayout()
    local L = R.Look()
    local w, h = Num("width", 200), Num("rowh", 32)
    if L.small then h = math.max(16, math.floor(h * .66)) end
    local n = math.max(1, math.min(20, Num("buttons", 5)))
    local gap = Num("spacing", 2)
    local font, fs = Font(), Num("fontsize", 11) + (L.big or 0)
    local rim = tonumber(C.rinse.border) or L.rim or 0
    -- the Icons look: square buttons side by side (Tiles: in rows of C.rinse.columns)
    local isz = L.grid and math.max(24, math.floor(h * 1.4)) or nil
    local cols = L.wrap and math.max(1, math.min(n, Num("columns", 5))) or n
    -- Spotlight: the top row large, the others slim
    local bigH, smallH = math.floor(h * 1.7), math.max(16, math.floor(h * .7))
    R.timeText = L.timetext or On("showtime")
    -- (17 Nov 2026, user: the size "keeps resetting ... should be set always to where i put it and what size can never
    -- change") one scale only: layout mode's saved one (C.position.pfRinse.scale) wins and is mirrored into C.rinse.scale;
    -- the bar used to set its own option's scale on every option change and undo the layout mode size
    local pos = C.position and C.position["pfRinse"]
    if pos and tonumber(pos.scale) then C.rinse.scale = tostring(pos.scale) end
    frame:SetScale(Num("scale", 1))
    frame:SetAlpha(Num("alpha", 1))
    frame:SetWidth(L.grid and math.max(L.wrap and 0 or w, cols * (isz + gap) - gap) or w)
    local showHead = On("header")
    local hh = showHead and 20 or 0
    head:ClearAllPoints()
    head:SetWidth(w)
    if On("flip") then head:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0) else head:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0) end
    if showHead then head:Show() else head:Hide() end
    local ar, ag, ab = .2, .7, 1
    if pfUI.api.GetAccentColor then
      local ok, r, g, b = pcall(pfUI.api.GetAccentColor)
      if ok and r then ar, ag, ab = r, g, b end
    end
    head.bg:SetVertexColor(.06, .065, .075, On("backdrop") and .92 or 0)
    head.line:SetVertexColor(ar, ag, ab, .8)
    head.text:SetFont(font, fs, "OUTLINE")
    head.text:SetText("OctoRinse")
    head.text:SetTextColor(ar + (1 - ar) * .35, ag + (1 - ag) * .35, ab + (1 - ab) * .35)
    head.boss:SetFont(font, fs - 1, "OUTLINE")
    local y = hh + 2
    for i = 1, n do
      local b = R.buttons[i] or NewButton(i)
      R.buttons[i] = b
      b:ClearAllPoints()
      b.look = L
      -- this row's height, words and line layout (Spotlight: the first big, the rest slim on one line)
      local bh, bfs, oneline = h, fs, L.oneline
      if L.spot then
        if i == 1 then bh, bfs = bigH, fs + 4 else bh, bfs, oneline = smallH, fs - 1, true end
      end
      b.fs = bfs
      if L.grid then
        -- big icons, the player's name under each; Tiles wrap into rows
        b:SetWidth(isz)
        b:SetHeight(isz)
        local col, row = math.mod(i - 1, cols), math.floor((i - 1) / cols)
        local x, ry = col * (isz + gap), row * (isz + fs + 6)
        if On("flip") then b:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x, hh + 2 + fs + 4 + ry) else b:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -(hh + 2 + ry)) end
      else
        b:SetWidth(w)
        b:SetHeight(bh)
        if On("flip") then b:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, y) else b:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -y) end
        y = y + bh + gap
      end
      b.bg:SetVertexColor(.025, .027, .032, On("backdrop") and .94 or .6)
      -- the school-colour fill: the whole row, or the fade at its left
      b.wash:ClearAllPoints()
      b.wash:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
      b.wash:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
      b.fullW = L.grid and isz or w
      b.wash:SetWidth(L.fill and b.fullW or 60)
      if b.wash.SetGradientAlpha then
        if L.fill then local fa = math.min(L.fill, .28) b.wash:SetGradientAlpha("HORIZONTAL", 1, 1, 1, fa, 1, 1, 1, fa * .25)
        else b.wash:SetGradientAlpha("HORIZONTAL", 1, 1, 1, .35, 1, 1, 1, 0) end
      end
      b.edge:SetWidth(L.edge or 3)
      if L.grid then b.edge:Hide() else b.edge:Show() end
      -- the border in the school's colour
      if rim > 0 then
        b.rim:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = rim })
        b.rim:Show()
      else
        b.rim:Hide()
      end
      local ic = L.grid and (isz - 2 * math.max(rim, 1) - 2) or (bh - 6)
      b.iconbg:ClearAllPoints()
      if L.grid then b.iconbg:SetPoint("CENTER", b, "CENTER", 0, 0) else b.iconbg:SetPoint("LEFT", b, "LEFT", 6, 0) end
      b.iconbg:SetWidth(ic + 2)
      b.iconbg:SetHeight(ic + 2)
      b.icon:ClearAllPoints()
      b.icon:SetPoint("CENTER", b.iconbg, "CENTER", 0, 0)
      b.icon:SetWidth(ic)
      b.icon:SetHeight(ic)
      b.count:SetFont(font, bfs - 1, "OUTLINE")
      b.count:ClearAllPoints()
      b.count:SetPoint("BOTTOMRIGHT", b.icon, "BOTTOMRIGHT", 1, 0)
      b.timer:SetFont(font, math.max(9, math.floor(ic * .45)), "OUTLINE")
      b.timer:ClearAllPoints()
      b.timer:SetPoint("CENTER", b.icon, "CENTER", 0, 0)
      b.timer:SetText("")
      b.timeShown = nil
      b.debuff:SetFont(font, bfs - 1, "OUTLINE")
      b.debuff:SetShadowColor(0, 0, 0, 1)
      b.debuff:SetShadowOffset(1, -1)
      b.debuff:ClearAllPoints()
      b.player:SetFont(font, bfs + 2, "OUTLINE")
      b.player:SetShadowColor(0, 0, 0, 1)
      b.player:SetShadowOffset(1, -1)
      b.player:ClearAllPoints()
      b.tag:SetFont(font, bfs - 1, "OUTLINE")
      b.tag:ClearAllPoints()
      if L.grid then
        b.debuff:Hide()
        b.tag:Hide()
        b.player:SetPoint("TOP", b, "BOTTOM", 0, -1)
        b.player:SetWidth(isz + gap)
        b.player:SetJustifyH("CENTER")
      elseif oneline then
        -- "Player  Debuff" on one line, the school on the right
        b.debuff:Show()
        b.tag:Show()
        b.player:SetJustifyH("LEFT")
        b.player:SetPoint("LEFT", b.iconbg, "RIGHT", 6, 0)
        b.debuff:SetPoint("LEFT", b.player, "RIGHT", 6, 0)
        b.debuff:SetPoint("RIGHT", b.tag, "LEFT", -4, 0)
        b.tag:SetPoint("RIGHT", b, "RIGHT", -6, 0)
      else
        b.debuff:Show()
        b.tag:Show()
        b.player:SetJustifyH("LEFT")
        -- (26 Nov 2026) the player is the big top line, the debuff the small grey one under it
        b.player:SetPoint("TOPLEFT", b.iconbg, "TOPRIGHT", 7, 0)
        b.player:SetPoint("RIGHT", b, "RIGHT", -6, 0)
        b.debuff:SetPoint("BOTTOMLEFT", b.iconbg, "BOTTOMRIGHT", 7, 1)
        b.debuff:SetPoint("RIGHT", b, "RIGHT", -48, 0)
        b.tag:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -6, 2)
      end
    end
    for i = n + 1, table.getn(R.buttons) do R.buttons[i]:Hide() R.buttons[i].unit = nil end
    R.shown = n
    if L.grid then frame:SetHeight(hh + 2 + math.ceil(n / cols) * (isz + fs + 6))
    else frame:SetHeight(y) end
    -- Calm: rows keep their places (C.rinse.sticky does the same for any look)
    R.sticky = L.calm or On("sticky")
    R.slotOf = R.slotOf or {}
    for k in pairs(R.slotOf) do R.slotOf[k] = nil end
    R.dirty = true
  end

  local function Say(msg)
    if not On("print") then return end
    if On("msbt") and MikSBT and MikSBT.DisplayMessage then
      MikSBT.DisplayMessage(msg, MikSBT.DISPLAYTYPE_NOTIFICATION, false, 255, 255, 255)
    else
      DEFAULT_CHAT_FRAME:AddMessage("|cff33b3ffOctoRinse|r " .. msg)
    end
  end
  R.Say = Say
  local function Sound(file) if On("sound") then PlaySoundFile(file) end end
  local NOTICE, ERROR = "Sound\\Doodad\\BellTollTribal.wav", "Sound\\Interface\\Error.wav"
  local playNotice = true

  -- (22 Nov 2026) the row's fill for the looks that measure something: timer = time left of the debuff (rows without
  -- a known end stay full), health = the player's health. Called from Fill and R.Pulse (30 a second); the seconds
  -- text only changes when the whole second does.
  function R.Measure(b, now)
    local L = b.look or R.Look()
    if not b:IsShown() then return end
    local frac
    if L.mode == "timer" and b.dur and b.ends then
      frac = math.max(0, math.min(1, (b.ends - now) / b.dur))
    elseif L.mode == "health" then
      if b.hp then frac = b.hp
      elseif b.unit and UnitExists(b.unit) then
        local mx = UnitHealthMax(b.unit) or 0
        frac = mx > 0 and math.max(0, math.min(1, (UnitHealth(b.unit) or 0) / mx)) or 1
      end
      if frac then
        local pct = math.floor(frac * 100 + .5)
        if b.hpShown ~= pct then
          b.hpShown = pct
          b.tag:SetText((pct <= 35 and "|cffff5555" or "|cffffffff") .. pct .. "%|r")
        end
      end
    end
    if frac and b.fullW then b.wash:SetWidth(math.max(1, b.fullW * frac)) end
    if R.timeText then
      local s = b.ends and math.ceil(b.ends - now) or nil
      if s and s < 0 then s = 0 end
      if b.timeShown ~= s then
        b.timeShown = s
        b.timer:SetText(s and ((s <= 3 and "|cffff5555" or "|cffffffff") .. s) or "")
      end
    end
  end

  local function Fill(b, d)
    local c = R.COLOR[d.school] or R.COLOR.Unknown
    local L = b.look or R.Look()
    b.icon:SetTexture(d.totem and R.TOTEMICON[d.totem] or d.tex)
    b.iconbg:SetVertexColor(c[1], c[2], c[3], 1)
    b.edge:SetVertexColor(c[1], c[2], c[3], 1)
    -- health / class looks fill in the player's class colour, the school stays on the edge, icon frame and border
    if L.mode == "health" or L.mode == "class" then
      local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[d.class or ""]
      if cc then b.wash:SetVertexColor(cc.r, cc.g, cc.b, 1) else b.wash:SetVertexColor(.6, .6, .6, 1) end
    else
      b.wash:SetVertexColor(c[1], c[2], c[3], 1)
    end
    b.dur, b.ends, b.hp = d.dur, d.ends, d.hp
    if b.rim and b.rim:IsShown() then b.rim:SetBackdropBorderColor(c[1], c[2], c[3], 1) end
    if b.glow then b.glow:SetVertexColor(c[1], c[2], c[3]) end
    b.debuff:SetText(d.totem and ("Totem - " .. d.name) or d.name)
    b.debuff:SetTextColor(.82, .84, .88)
    b.player:SetText("|cff" .. (R.BRIGHTHEX[d.class] or R.CLASSHEX[d.class] or "ffffff") .. (d.unitName or "") .. "|r")
    b.count:SetText((d.stacks or 0) > 1 and d.stacks or "")
    b.tag:SetText(d.prio and "|cffffd24dPRIORITY|r" or d.totem and "|cff40d977TOTEM|r" or "|cff" .. c[4] .. string.upper(d.school) .. "|r")
    b.unit, b.unitName, b.class, b.school, b.totem, b.debuffName, b.index = d.unit, d.unitName, d.class, d.school, d.totem, d.name, d.index
    b:Show()
    b.hpShown = nil
    if L.mode or R.timeText then R.Measure(b, GetTime()) end
  end

  -- what each button shows: the list in order, one row a player; with R.sticky (Calm, or "Rows stay put") a player
  -- keeps the row they had while their debuff lasts and newcomers take the free rows
  local pick, taken = {}, {}
  function R.Paint()
    local list = R.debuffs
    local n = R.shown or 0
    WipeList(pick)
    Wipe(taken)
    local seen, k = {}, 0
    for di = 1, R.count do
      local d = list[di]
      if not d.hidden and not seen[d.unitName] then
        seen[d.unitName] = true
        k = k + 1
        if k > n and not R.sticky then break end
        table.insert(pick, d)
      end
    end
    local slots = {}
    if R.sticky and R.slotOf then
      -- first the players who already had a row (and still fit), then the rest in order into the free rows
      for _, d in ipairs(pick) do
        local s = R.slotOf[d.unitName]
        if s and s <= n and not slots[s] then slots[s] = d taken[d] = true end
      end
      local free = 1
      for _, d in ipairs(pick) do
        if not taken[d] then
          while free <= n and slots[free] do free = free + 1 end
          if free > n then break end
          slots[free] = d
        end
      end
      for name in pairs(R.slotOf) do R.slotOf[name] = nil end
      for s = 1, n do if slots[s] then R.slotOf[slots[s].unitName] = s end end
    else
      for s = 1, math.min(n, table.getn(pick)) do slots[s] = pick[s] end
    end
    local calm = (R.Look()).calm
    for bi = 1, n do
      local b, d = R.buttons[bi], slots[bi]
      if d then
        Fill(b, d)
        -- a totem is dropped at your feet: no range to check (d.near: worked out once in the scan)
        local near = d.near
        if near == nil then near = d.totem or R.InRange(d.unit, R.usable[d.school]) end
        b:SetAlpha(near and 1 or Num("oor", .45))
        if bi == 1 and playNotice and not calm then
          Sound(NOTICE)
          playNotice = false
        end
      else
        b:Hide()
        b.unit = nil
      end
    end
    local any = false
    for bi = 1, n do if R.buttons[bi] and R.buttons[bi]:IsShown() then any = true end end
    if not any then playNotice = true end
    -- the boss whose lists count now, on the title
    local name
    for key in pairs(R.active) do
      local _, _, bn = string.find(key, "%^(.+)$")
      if bn and (not name or R.IsTrash(name)) then name = bn end
    end
    head.boss:SetText(name and ("|cffffd24d" .. name .. "|r") or "")
  end

  -- ---------------------------------------------------------------- curing (UpsiRinse's Rinse_Cleanse)

  local errorAt, stopAt, autoattack = 0, 0, nil
  R.last = {}
  function R.Cleanse(b, tried)
    if not b or not b.unit then return false end
    local spell = b.totem or R.usable[b.school]
    if not spell then return false end
    local slot = R.slot[spell]
    local _, duration = 0, 0
    if slot then _, duration = GetSpellCooldown(slot, book) end
    local onGcd = duration == 1.5
    if tried and onGcd then return false end
    if not b.totem and not R.InRange(b.unit, spell) then
      if GetTime() > errorAt then Sound(ERROR) errorAt = GetTime() + .1 end
      return false
    end
    local casting = true
    if GetCurrentCastingInfo then
      local _, _, _, c, ch = GetCurrentCastingInfo()
      if c == 0 and ch == 0 then casting = false end
    end
    if casting and GetTime() > stopAt then
      SpellStopCasting()
      stopAt = GetTime() + .2
    end
    local c = R.COLOR[b.school] or R.COLOR.Unknown
    local line = "|cff" .. c[4] .. (b.debuffName or "") .. "|r - |cff" .. (R.CLASSHEX[b.class] or "ffffff") .. (UnitName(b.unit) or b.unitName or "") .. "|r"
    if not onGcd then Say(line) else R.last.spell, R.last.line = spell, line end
    if b.totem then
      CastSpellByName(spell)
      R.totemAt[spell] = GetTime()
    elseif superwow then
      CastSpellByName(spell, b.unit)
    elseif _G.C_Spell and _G.C_Spell.CastAtUnit and pcall(_G.C_Spell.CastAtUnit, spell, b.unit) then
      -- ClassicAPI cast on the unit, no target swap
    else
      local selfcast, assist = GetCVar("autoselfcast"), GetCVar("assistattack")
      local last = UnitName("target")
      local restore = last and autoattack and autoattack == last
      SetCVar("autoselfcast", 0)
      SetCVar("assistattack", 1)
      TargetUnit(b.unit)
      if UnitExists("target") and UnitIsUnit("target", b.unit) then
        CastSpellByName(spell)
        if last ~= UnitName("target") then TargetLastTarget() end
      end
      if restore and last and UnitExists("target") and UnitName("target") == last then AssistUnit("player") end
      SetCVar("autoselfcast", selfcast)
      SetCVar("assistattack", assist)
    end
    return true
  end
  -- the key / macro: cure the first one that can go (one may wait in the queue during the global cooldown)
  function R.Run()
    if R.aside then return end
    local tried = false
    for i = 1, (R.shown or 0) do
      if R.Cleanse(R.buttons[i], tried) then tried = true end
    end
  end

  -- ---------------------------------------------------------------- where it runs, sample rows

  function R.WhereOk()
    local z = pfUI.context and pfUI.context.Zone and pfUI.context.Zone() or "world"
    local key = ({ raid = "inraid", dungeon = "indungeon", bg = "inbg", arena = "inarena", world = "inworld" })[z] or "inworld"
    return On(key), z
  end
  R.SAMPLE = {
    { name = "Brood Affliction: Blue", school = "Magic", tex = "Interface\\Icons\\Spell_Arcane_Blink", class = "MAGE", unitName = "Frostbolt", stacks = 0 },
    { name = "Veil of Shadow", school = "Curse", tex = "Interface\\Icons\\Spell_Shadow_GatherShadows", class = "WARRIOR", unitName = "Tankguy", stacks = 0, prio = true },
    { name = "Poison Bolt Volley", school = "Poison", tex = "Interface\\Icons\\Spell_Nature_CorrosiveBreath", class = "PRIEST", unitName = "Healbot", stacks = 3 },
    { name = "Brood Affliction: Red", school = "Disease", tex = "Interface\\Icons\\Spell_Shadow_CreepingPlague", class = "ROGUE", unitName = "Stabby", stacks = 0 },
    { name = "Mind Flay", school = "Snare", tex = "Interface\\Icons\\Spell_Shadow_SiphonMana", class = "HUNTER", unitName = "Pewpew", stacks = 0 },
  }
  -- (the samples' made-up time left and health, so Timer bars / Health bars show what they do)
  local SAMPLELEFT, SAMPLEHP = { 6, 14, 3, 18, 9 }, { .62, .28, .9, .45, .75 }
  function R.Sample()
    local now = GetTime()
    for i = 1, (R.shown or 0) do
      local k = math.mod(i - 1, table.getn(R.SAMPLE)) + 1
      local d = R.SAMPLE[k]
      d.dur, d.ends, d.hp = 20, now + SAMPLELEFT[k], SAMPLEHP[k]
      Fill(R.buttons[i], d)
      R.buttons[i].unit = nil
      R.buttons[i]:SetAlpha(i == 4 and .45 or 1)
    end
    head.boss:SetText("|cffffd24dChromaggus|r")
  end
  function R.Test(secs) R.testUntil = GetTime() + (secs or 20) frame:Show() R.Sample() end
  function R.Testing()
    if R.testUntil and GetTime() < R.testUntil then return true end
    return pfUI.unlock and pfUI.unlock.IsShown and pfUI.unlock:IsShown() and true or nil
  end
  -- layout mode resized the bar (wheel, % box, width box): keep that size in OctoRinse's own setting too
  frame.OnScale = function(_, scale) C.rinse.scale = tostring(scale) end
  -- the Scale slider in the options: the same one size, saved where layout mode keeps it
  function R.SetScale(v)
    v = tonumber(v) or 1
    C.rinse.scale = tostring(v)
    C.position = C.position or {}
    C.position["pfRinse"] = C.position["pfRinse"] or {}
    C.position["pfRinse"].scale = v
    frame:SetScale(v)
  end
  function R.ResetPosition()
    if C.position then C.position["pfRinse"] = nil end
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", -320, 120)
    if UpdateMovable then UpdateMovable(frame) end
  end

  -- ---------------------------------------------------------------- events and the loop

  local ev = CreateFrame("Frame", "pfRinseEvents", UIParent)
  R.events = ev
  for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "RAID_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED", "SPELLS_CHANGED",
    "LEARNED_SPELL_IN_TAB", "UNIT_AURA", "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "ZONE_CHANGED_NEW_AREA", "UNIT_PET", "CHARACTER_POINTS_CHANGED" }) do ev:RegisterEvent(e) end
  if myClass == "PRIEST" then ev:RegisterEvent("PLAYER_AURAS_CHANGED") end
  if GetNampowerVersion then ev:RegisterEvent("SPELL_QUEUE_EVENT") end
  if not superwow then
    ev:RegisterEvent("PLAYER_ENTER_COMBAT")
    ev:RegisterEvent("PLAYER_LEAVE_COMBAT")
  end
  local prioAt
  ev:SetScript("OnEvent", function()
    if event == "UNIT_AURA" then
      -- only that player is read again (by name: tokens differ between events and the scan)
      local n = arg1 and UnitName(arg1)
      if n then R.auraChanged[n] = true else R.ForgetReads() end
      R.dirty = true
    elseif event == "PLAYER_TARGET_CHANGED" then
      R.dirty = true
    elseif event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" or event == "UNIT_PET" then
      prioAt = GetTime() + 2
    elseif event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" or event == "CHARACTER_POINTS_CHANGED" then
      -- (a talent that lengthens a cure's range: its range is read again)
      R.UpdateSpells()
    elseif event == "PLAYER_AURAS_CHANGED" then
      shadowform = Shadowform()
    elseif event == "PLAYER_REGEN_DISABLED" then
      fightStart = GetTime()
    elseif event == "PLAYER_ENTER_COMBAT" then
      autoattack = UnitName("target")
    elseif event == "PLAYER_LEAVE_COMBAT" then
      autoattack = nil
    elseif event == "SPELL_QUEUE_EVENT" then
      -- nampower: a queued cure went off (3 = NORMAL_QUEUE_POPPED)
      if arg1 == 3 and R.last.spell and GetSpellNameAndRankForId and GetSpellNameAndRankForId(arg2) == R.last.spell then
        Say(R.last.line)
        R.last.spell = nil
      end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
      R.ForgetReads()
      R.UpdateSpells()
      R.UpdatePrio()
      R.dirty = true
    end
  end)
  local nextScan, nextWatch = 0, 0
  -- the title bar hidden until the mouse is over it (C.rinse.headhover): fades in .15 s, out .4 s
  function R.HeadFade(elapsed)
    if not head:IsShown() then return end
    local want = 1
    if On("headhover") and not R.Testing() and not (quick and quick:IsShown()) and not MouseIsOver(head) then want = 0 end
    local a = head.fade or 1
    if a == want then return end
    local step = (elapsed or .02) / (want > a and .15 or .4)
    if want > a then a = math.min(want, a + step) else a = math.max(want, a - step) end
    head.fade = a
    head:SetAlpha(a)
  end
  -- (20 Nov 2026) the top row pulses in its school's colour, so the next cure stands out (C.rinse.pulse)
  function R.Pulse(now)
    local b = R.buttons and R.buttons[1]
    if not b or not b.glow then return end
    -- timer / health fills and the seconds on the icons (only the looks that show them)
    local L = R.Look()
    if L.mode or R.timeText then
      for i = 1, (R.shown or 0) do
        local bb = R.buttons[i]
        if bb and bb:IsShown() then R.Measure(bb, now or GetTime()) end
      end
    end
    if On("pulse") and not L.calm and b:IsShown() and (b.unit or R.Testing()) then
      b.glow:SetAlpha(.12 + .14 * (math.sin((now or 0) * 6) + 1) / 2)
      b.glow:Show()
    else
      b.glow:Hide()
    end
  end
  -- (22 Nov 2026, user's HUD standing alone with nothing to cure: pfRinseEvents 3 ms a second) this ran on every
  -- frame - 140 times a second at 140 fps - for a title fade, a glow pulse and timers that need far less. Now at most
  -- R.LOOP_HZ times a second (an aura change still rescans within 1 / R.LOOP_HZ s); the fade gets the time it missed.
  R.LOOP_HZ = 30
  local loopAt, loopSum = 0, 0
  ev:SetScript("OnUpdate", function()
    local now = GetTime()
    loopSum = loopSum + (arg1 or 0)
    if now < loopAt then return end
    loopAt = now + 1 / R.LOOP_HZ
    R.HeadFade(loopSum)
    loopSum = 0
    R.Pulse(now)
    if R.Testing() then
      if not frame:IsShown() then frame:Show() R.Sample() end
      return
    end
    if R.aside then frame:Hide() return end
    if prioAt and now >= prioAt then prioAt = nil R.UpdatePrio() end
    if now >= nextWatch then
      nextWatch = now + .5
      local ok = R.WhereOk()
      R.here = ok
      if ok then R.Watch() end
      if ok and R.CanAny() then frame:Show() else frame:Hide() end
    end
    if not R.here or not frame:IsShown() then return end
    -- instant: an aura change rescans on the next frame (at most 20 a second; in a raid, where auras change all the
    -- time, at most 10 - 22 Nov 2026, /pfperf in a raid); otherwise the range fade every .25 s
    local soon = GetNumRaidMembers() > 0 and .15 or .2
    if (R.dirty and now >= nextScan - soon) or now >= nextScan then
      R.dirty = nil
      nextScan = now + .25
      R.Scan()
    end
  end)
  function R.CanAny()
    for _ in pairs(R.usable) do return true end
    return On("showall")
  end

  -- ---------------------------------------------------------------- keys and commands

  _G.BINDING_HEADER_PFRINSE = "pfUI Octo: OctoRinse"
  _G.BINDING_NAME_PFRINSE = "Cure the top debuff"
  _G.BINDING_NAME_PFRINSEBOSSES = "Open the boss lists"
  _G.BINDING_NAME_PFRINSEOPTIONS = "Open OctoRinse's options"
  _G.BINDING_NAME_PFRINSEQUICK = "Quick player list (cure first / never)"
  function R.Slash(msg)
    msg = string.lower(msg or "")
    if msg == "" then R.Run()
    elseif msg == "options" or msg == "opt" then R.OpenOptions("rinsegeneral")
    elseif msg == "bosses" or msg == "encounters" then R.OpenOptions("rinsebosses")
    elseif msg == "skip" or msg == "prio" or msg == "players" then R.OpenOptions("rinseplayers")
    elseif msg == "test" then R.Test(20)
    elseif msg == "quick" then R.ToggleQuick()
    elseif msg == "versions" then R.VersionCheck()
    else DEFAULT_CHAT_FRAME:AddMessage("|cff33b3ffOctoRinse|r: /orinse (cure), /orinse quick | bosses | players | options | test | versions") end
  end
  _G.SLASH_PFORINSE1 = "/orinse"
  _G.SLASH_PFORINSE2 = "/octorinse"
  _G.SlashCmdList["PFORINSE"] = R.Slash
  -- /rinse and the Rinse() macro keep working while UpsiRinse is not loaded
  if not R.UpsiLoaded() then
    _G.SLASH_PFRINSEOLD1, _G.SLASH_PFRINSEOLD2 = "/rinse", "/upsirinse"
    _G.SlashCmdList["PFRINSEOLD"] = R.Slash
    if not _G.Rinse then _G.Rinse = function() R.Run() end end
  end

  -- version check: same prefix and words as Rinse, so guildmates on Rinse / UpsiRinse answer too
  local versions
  function R.VersionCheck()
    local chan = GetNumRaidMembers() > 0 and "RAID" or GetNumPartyMembers() > 0 and "PARTY"
    if not chan then DEFAULT_CHAT_FRAME:AddMessage("|cff33b3ffOctoRinse|r: you are not in a raid or party.") return end
    versions = {}
    SendAddonMessage("Rinse", "REPORT_ADDON_VERSION", chan)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33b3ffOctoRinse|r: asking who runs Rinse...")
    R.versionAt = GetTime() + 3
  end
  local vf = CreateFrame("Frame")
  vf:RegisterEvent("CHAT_MSG_ADDON")
  vf:SetScript("OnEvent", function()
    if arg1 ~= "Rinse" or arg4 == UnitName("player") then return end
    if arg2 == "REPORT_ADDON_VERSION" then
      pcall(SendAddonMessage, "Rinse", "V_OctoRinse " .. tostring(pfUI.version and pfUI.version.octo or "?"), arg3 or "RAID")
    elseif versions and string.find(arg2 or "", "^V_") then
      table.insert(versions, arg4 .. ": " .. string.sub(arg2, 3))
    end
  end)
  vf:SetScript("OnUpdate", function()
    if R.versionAt and GetTime() >= R.versionAt then
      R.versionAt = nil
      table.sort(versions)
      DEFAULT_CHAT_FRAME:AddMessage("|cff33b3ffOctoRinse|r: " .. table.getn(versions) .. " answered:")
      for _, v in ipairs(versions) do DEFAULT_CHAT_FRAME:AddMessage("  " .. v) end
      versions = nil
    end
  end)

  -- ---------------------------------------------------------------- start

  R.Seed()
  R.Import()
  R.RebuildSkip()
  R.UpdateSpells()
  if UpdateMovable then UpdateMovable(frame) end
  R.ApplyLayout()
  R.UpdatePrio()
  shadowform = myClass == "PRIEST" and Shadowform() or nil
  -- UpsiRinse loaded too: two bars on one key would fight; ours waits and offers to switch it off
  if R.UpsiLoaded() then
    R.aside = true
    if C.rinse.asked ~= "1" and CreateQuestionDialog then
      C.rinse.asked = "1"
      CreateQuestionDialog("OctoRinse is UpsiRinse built into pfUI Octo, with every setting copied over. Switch UpsiRinse off and reload now?",
        function()
          if DisableAddOn then DisableAddOn("UpsiRinse") DisableAddOn("Rinse") end
          ReloadUI()
        end)
    end
  end
end)
