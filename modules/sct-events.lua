-- pfUI Octo :: combat text (what is shown) - moved here from the OctoBG addon
-- (modules/SCTEvents.lua there) on 19 Oct 2026, unchanged but for the
-- header; OctoBG's own alerts ("OctoBG alerts") arrive through CT:Notify.
--
-- Turns the game's events into combat text. Sources, no combat-log text
-- parsing for combat (so it works in any client language):
--   nampower  AUTO_ATTACK_SELF / _OTHER, SPELL_DAMAGE_EVENT_SELF / _OTHER,
--             SPELL_MISS_SELF / _OTHER, SPELL_HEAL_BY_SELF / _ON_SELF,
--             SPELL_ENERGIZE_ON_SELF, BUFF / DEBUFF_ADDED / REMOVED_SELF,
--             DAMAGE_SHIELD_SELF, ENVIRONMENTAL_DMG_SELF, SPELL_DISPEL_BY_SELF
--             (argument layouts: nampower's EVENTS.md)
--   client    combat start / end, combo points, low health / mana, your cast
--             interrupted, cooldowns, and chat lines for honor, reputation,
--             skills, experience, money, loot, killing blows, extra attacks
--             and interrupts (patterns built from the client's own GlobalStrings)
--   OctoBG    enemy cooldown alerts, Kill On Sight / detection, stealth
-- Every message type has: on / off, colour, where (screen area or the
-- nameplate), always-crit, a sound and a text format (%a amount, %s spell or
-- thing, %n the other unit's name, %t school or kind).
--
-- Eviction: merge buffers flush after mergeTime, the power throttle after
-- its seconds; spell name / icon cache wiped at 1000 entries; cooldown and
-- reactive state on zone change.

local B = pfUI.sctB
local U = B.U
local CT = B.SCT
local EV = { merge = {}, nmerge = 0, spells = {}, nspells = 0, cds = {}, power = {}, known = {}, low = {} }
CT.EV = EV

-- ---------------------------------------------------------------- message types

-- key, label, group, area, r, g, b, format, on, sound, always crit
local LIST = {
  -- damage you take (SCT)
  { "inMelee", "Melee hits on you", "in", "inc", 1, 0.15, 0.15, "-%a" },
  { "inSpell", "Spell hits on you", "in", "inc", 0.8, 0.25, 0.9, "-%a" },
  { "inDot", "Damage over time on you", "in", "inc", 0.75, 0.35, 0.85, "-%a" },
  { "inEnv", "Falling, lava, drowning...", "in", "inc", 1, 0.5, 0.2, "-%a %t" },
  { "inMiss", "Misses on you", "in", "inc", 0.4, 0.6, 1, "Miss" },
  { "inDodge", "You dodge", "in", "inc", 0.4, 0.6, 1, "Dodge" },
  { "inParry", "You parry", "in", "inc", 0.4, 0.6, 1, "Parry" },
  { "inBlock", "You block", "in", "inc", 0.4, 0.6, 1, "Block" },
  { "inResist", "You resist", "in", "inc", 0.75, 0.35, 0.85, "Resist" },
  { "inAbsorb", "You absorb", "in", "inc", 1, 1, 0.2, "Absorb" },
  { "inImmune", "Immune, evade, deflect, reflect", "in", "inc", 0.85, 0.85, 0.85, "%t" },
  { "debuffGain", "Debuffs on you", "in", "inc", 0, 0.65, 0.65, "[%s]" },
  { "debuffFade", "Debuffs fading", "in", "inc", 0, 0.5, 0.5, "-[%s]", false },
  { "interrupted", "Your cast interrupted", "in", "inc", 0.55, 0.55, 0.85, "Interrupted!" },
  -- healing and power you get (SCT frame 2)
  { "inHeal", "Heals on you", "heal", "heal", 0.15, 1, 0.15, "+%a" },
  { "inHot", "Heals over time on you", "heal", "heal", 0.1, 0.8, 0.1, "+%a", false },
  { "selfHeal", "Your heals on yourself", "heal", "heal", 0, 0.75, 0, "+%a" },
  { "inPower", "Mana, rage, energy gains", "heal", "heal", 1, 1, 0.2, "+%a %t" },
  { "buffGain", "Buffs gained", "heal", "note", 0.8, 0.8, 0.1, "[%s]" },
  { "buffFade", "Buffs fading", "heal", "note", 0.7, 0.7, 0.1, "-[%s]", false },
  { "combatIn", "Entering combat", "heal", "heal", 1, 1, 1, "+Combat", false },
  { "combatOut", "Leaving combat", "heal", "heal", 1, 1, 1, "-Combat", false },
  -- your damage (SCT - Damage)
  { "outMelee", "Your melee and Auto Shot", "out", "plate", 1, 1, 1, "%a" },
  { "outSpell", "Your spells", "out", "plate", 1, 1, 0.2, "%a" },
  { "outDot", "Your damage over time", "out", "plate", 0.95, 0.85, 0.2, "%a" },
  { "outPet", "Your pet's damage", "out", "plate", 0.65, 0.65, 0.1, "%a" },
  { "outShield", "Your damage shields (Thorns...)", "out", "plate", 0.6, 0.85, 0.4, "%a" },
  { "outMiss", "Your misses (dodge, parry, resist...)", "out", "plate", 0.75, 0.75, 0.75, "%t" },
  { "outInterrupt", "You interrupt someone", "out", "note", 1, 0.6, 0.1, "Interrupted %n: %s" },
  { "killBlow", "Killing blows", "out", "note", 1, 0.25, 0.25, "Killing Blow! %n", true, nil, true },
  -- your healing and dispels
  { "outHeal", "Your heals on others", "outheal", "out", 0.2, 1, 0.4, "+%a" },
  { "outHot", "Your heals over time on others", "outheal", "out", 0.15, 0.8, 0.3, "+%a", false },
  { "dispel", "Your dispels", "outheal", "note", 0.4, 0.8, 1, "Dispelled %s" },
  -- alerts and warnings
  { "lowHp", "Low health", "warn", "note", 1, 0.5, 0.5, "Low Health!", true, "impact", true },
  { "lowMana", "Low mana", "warn", "note", 0.5, 0.5, 1, "Low Mana!", true, "bell", true },
  { "combo", "Combo points", "warn", "heal", 1, 0.5, 0, "%a CP", false },
  { "reactive", "Reactive skills (Overpower, Revenge...)", "warn", "note", 0.9, 0.9, 0.9, "%s!", true, nil, true },
  { "extraAttack", "Extra attacks (Windfury...)", "warn", "heal", 1, 0.8, 0.4, "Extra Attack!" },
  { "proc", "Procs (your list)", "warn", "note", 1, 0.85, 0.3, "%s!", true, nil, true },
  { "cdReady", "Your cooldowns ready again", "warn", "note", 0.6, 0.9, 1, "%s ready!" },
  -- rewards (SCT messages, MSBT)
  { "honor", "Honor", "reward", "note", 0.6, 0.6, 0.9, "+%a Honor" },
  { "rep", "Reputation", "reward", "note", 0.5, 0.5, 1, "%a %s" },
  { "skill", "Skill gains", "reward", "note", 0.3, 0.5, 1, "%s: %a" },
  { "xp", "Experience", "reward", "note", 0.7, 0.4, 1, "+%a XP", false },
  { "money", "Money looted", "reward", "note", 1, 0.85, 0.2, "+%s", false },
  { "loot", "Items looted", "reward", "note", 0.9, 0.9, 0.9, "+%s", false },
  -- OctoBG's own alerts, also as combat text
  { "obgCd", "Enemy cooldown alerts", "obg", "note", 1, 0.82, 0, "%s", false },
  { "obgDetect", "Kill On Sight and detection alerts", "obg", "note", 1, 0.2, 0.2, "%s", false },
  { "obgStealth", "Stealth alerts", "obg", "note", 0.7, 0.35, 1, "%s", false },
}
CT.EVENTS, CT.EVENT = {}, {}
for i = 1, table.getn(LIST) do
  local l = LIST[i]
  local e = { key = l[1], label = l[2], group = l[3] }
  table.insert(CT.EVENTS, e)
  CT.EVENT[l[1]] = e
  B.DEFAULTS.sct.events[l[1]] = { on = (l[9] ~= false), r = l[5], g = l[6], b = l[7], area = l[4], fmt = l[8],
                                  sound = l[10] or "none", crit = l[11] and true or false,
                                  big = (l[1] == "killBlow") }   -- big: bigger, with the flash (Messages page)
end
CT.GROUPS = { { "in", "Damage you take" }, { "heal", "Healing, power and buffs you get" }, { "out", "Your damage" },
              { "outheal", "Your healing" }, { "warn", "Alerts and warnings" }, { "reward", "Rewards" },
              { "obg", "OctoBG alerts" } }

-- Sounds: the client's own files (paths checked in this install's MPQ list
-- files), BigWigs' voice clips played from BigWigs' folder (not copied), Spy's,
-- and four of your own files (db.sct.mySounds, in media\sounds\custom\).
-- Entries with `group` are headings in the menus.
local BW = "Interface\\AddOns\\BigWigs\\Sounds\\"
CT.SOUNDS = {
  { key = "none", label = "No sound" },
  { group = true, label = "Game alerts" },
  { key = "RaidWarning", label = "Raid warning" }, { key = "TellMessage", label = "Whisper" },
  { key = "igQuestListComplete", label = "Quest complete" },
  { key = "levelup", label = "Level up", file = "Sound\\Interface\\LevelUp.wav" },
  { key = "impact", label = "Impact (SCT low health)", file = "Sound\\Spells\\bind2_Impact_Base.wav" },
  { key = "bell", label = "Bell (SCT low mana)", file = "Sound\\Spells\\ShaysBell.wav" },
  { key = "gong", label = "Troll gong", file = "Sound\\Doodad\\G_GongTroll01.wav" },
  { key = "tollH", label = "Bell toll (Horde)", file = "Sound\\Doodad\\BellTollHorde.wav" },
  { key = "tollA", label = "Bell toll (Alliance)", file = "Sound\\Doodad\\BellTollAlliance.wav" },
  { key = "pvpwarn", label = "PvP warning", file = "Sound\\Spells\\PVPWarning.wav" },
  { key = "flag", label = "Flag taken", file = "Sound\\Spells\\PVPFlagTaken.wav" },
  { group = true, label = "Bang!" },
  { key = "gun1", label = "Gunshot", file = "Sound\\Item\\Weapons\\Gun\\GunFire01.wav" },
  { key = "gun2", label = "Gunshot 2", file = "Sound\\Item\\Weapons\\Gun\\GunFire02.wav" },
  { key = "gun3", label = "Gunshot 3", file = "Sound\\Item\\Weapons\\Gun\\GunFire03.wav" },
  { key = "reload", label = "Gun reload", file = "Sound\\Item\\Weapons\\Gun\\GunLoad01.wav" },
  { key = "shotgun", label = "Shotgun", file = "Sound\\Doodad\\DarkIronKegShotgun.wav" },
  { key = "dynamite", label = "Dynamite", file = "Sound\\Spells\\DynamiteExplode.wav" },
  { key = "barrel", label = "Barrel explosion", file = "Sound\\Doodad\\G_BarrelExplodeCustom0.wav" },
  { key = "firecracker", label = "Firecrackers", file = "Sound\\Doodad\\Firecrackers_ThrownExplode.wav" },
  { key = "kidney", label = "Kidney Shot hit", file = "Sound\\Spells\\Kidneyshot.wav" },
  { group = true, label = "Finishers and wins" },
  { key = "ragslay", label = "Ragnaros: Die, insect!", file = "Sound\\Creature\\Ragnaros\\RagnarosSlay01.wav" },
  { key = "ragfire", label = "Ragnaros: By fire be purged!", file = "Sound\\Creature\\Ragnaros\\RagnarosSpecialAttack01.wav" },
  { key = "nefslay", label = "Nefarian kill line", file = "Sound\\Creature\\Nefarian\\NefarianSlay.wav" },
  { key = "thadslay", label = "Thaddius kill line", file = "Sound\\Creature\\Thaddius\\THAD_NAXX_SLAY.wav" },
  { key = "kelslay", label = "Kel'Thuzad kill line", file = "Sound\\Creature\\Kelthuzad\\KEL_NAXX_SLAY01.wav" },
  { key = "patchslay", label = "Patchwerk kill line", file = "Sound\\Creature\\Patchwerk\\PAT_NAXX_SLAY.wav" },
  { key = "razslay", label = "Razuvious kill line", file = "Sound\\Creature\\Razuvious\\RAZ_NAXX_SLAY01.wav" },
  { key = "cheerH", label = "Crowd cheer (Horde)", file = "Sound\\Spells\\CrowdCheerHorde1.wav" },
  { key = "cheerA", label = "Crowd cheer (Alliance)", file = "Sound\\Spells\\CrowdCheerAlliance1.wav" },
  { key = "winH", label = "Victory (Horde)", file = "Sound\\Spells\\PVPVictoryHorde.wav" },
  { key = "winA", label = "Victory (Alliance)", file = "Sound\\Spells\\PVPVictoryAlliance.wav" },
  { group = true, label = "Voices (BigWigs)" },
  { key = "bwVictory", label = "BigWigs: Victory", file = BW .. "Victory.mp3" },
  { key = "bwGo", label = "BigWigs: Go go go", file = BW .. "gogogo.mp3" },
  { key = "bwRun", label = "BigWigs: Run away", file = BW .. "RunAway.wav" },
  { key = "bwBeware", label = "BigWigs: Beware", file = BW .. "Beware.wav" },
  { key = "bwIncoming", label = "BigWigs: Incoming", file = BW .. "incoming.mp3" },
  { key = "bwStop", label = "BigWigs: Stop casting", file = BW .. "stopcasting.mp3" },
  { key = "bwHide", label = "BigWigs: Hide", file = BW .. "hide.mp3" },
  { key = "bwAlarm", label = "BigWigs: Alarm", file = BW .. "Alarm.mp3" },
  { key = "bwAlert", label = "BigWigs: Alert", file = BW .. "Alert.mp3" },
  { key = "bwLong", label = "BigWigs: Long alarm", file = BW .. "Long.mp3" },
  { key = "bwBeep", label = "BigWigs: Beep", file = BW .. "beep.mp3" },
  { group = true, label = "Spy" },
  { key = "kos", label = "Spy: Kill On Sight", file = U.MEDIA .. "sounds\\detected-kos.wav" },
  { key = "nearby", label = "Spy: enemy nearby", file = U.MEDIA .. "sounds\\detected-nearby.wav" },
  { key = "stealth", label = "Spy: stealth", file = U.MEDIA .. "sounds\\detected-stealth.wav" },
  { key = "add", label = "Spy: list add", file = U.MEDIA .. "sounds\\list-add.wav" },
  { group = true, label = "Your own (Sounds page)" },
  { key = "my1", label = "Your sound 1", my = 1 }, { key = "my2", label = "Your sound 2", my = 2 },
  { key = "my3", label = "Your sound 3", my = 3 }, { key = "my4", label = "Your sound 4", my = 4 },
}
CT.MY_SOUNDS = U.MEDIA .. "sounds\\custom\\"
B.DEFAULTS.sct.mySounds = { "", "", "", "" }

-- The file of one of your own sounds: a bare name lives in media\sounds\custom\.
function CT.MySoundFile(i)
  local f = B.db.sct.mySounds[i]
  if not f or f == "" then return nil end
  if string.find(f, "\\", 1, true) or string.find(f, "/", 1, true) then return f end
  return CT.MY_SOUNDS .. f
end

function CT.PlaySound(key)
  if not key or key == "none" then return end
  for i = 1, table.getn(CT.SOUNDS) do
    local s = CT.SOUNDS[i]
    if s.key == key then
      if s.my then
        local f = CT.MySoundFile(s.my)
        if f then PlaySoundFile(f) end
      elseif s.file then
        PlaySoundFile(s.file)
      else
        PlaySound(s.key)
      end
      return
    end
  end
end

local SCHOOL = { [0] = "Physical", [1] = "Holy", [2] = "Fire", [3] = "Nature", [4] = "Frost", [5] = "Shadow", [6] = "Arcane" }
local SCHOOL_COLOR = { [1] = { 1, 1, 0.4 }, [2] = { 1, 0.45, 0.1 }, [3] = { 0.5, 1, 0.25 }, [4] = { 0.45, 0.75, 1 },
                       [5] = { 0.7, 0.4, 0.95 }, [6] = { 0.95, 0.65, 1 } }
local MISS = { [1] = "Miss", [2] = "Resist", [3] = "Dodge", [4] = "Parry", [5] = "Block", [6] = "Evade", [7] = "Immune",
               [8] = "Immune", [9] = "Deflect", [10] = "Absorb", [11] = "Reflect" }
-- victimState of melee: 2 dodge, 3 parry, 5 block, 6 evade, 7 immune, 8 deflect
local VICTIM = { [2] = "Dodge", [3] = "Parry", [5] = "Block", [6] = "Evade", [7] = "Immune", [8] = "Deflect" }
local MISS_EVENT = { Miss = "inMiss", Dodge = "inDodge", Parry = "inParry", Block = "inBlock", Resist = "inResist",
                     Absorb = "inAbsorb", Immune = "inImmune", Evade = "inImmune", Deflect = "inImmune", Reflect = "inImmune" }
local ENV = { [0] = "Fatigue", [1] = "Drowning", [2] = "Falling", [3] = "Lava", [4] = "Slime", [5] = "Fire", [6] = "Falling" }
local POWER = { [0] = "Mana", [1] = "Rage", [2] = "Focus", [3] = "Energy", [4] = "Happiness" }
local PERIODIC_AURA = { [3] = true, [53] = true, [89] = true }   -- periodic damage / leech / percent damage

-- ---------------------------------------------------------------- helpers

local me, pet
local function Me()
  if not me then me = U.GuidOf("player") end
  return me
end
B:On("PLAYER_ENTERING_WORLD", function()
  me, pet = U.GuidOf("player"), U.GuidOf("pet")
end)
B:On("UNIT_PET", function(ev, unit)
  if unit == "player" then pet = U.GuidOf("pet") end
end)

function EV.Spell(id)
  if not id or id == 0 then return nil end
  local c = EV.spells[id]
  if c then return c[1], c[2] end
  local name, icon
  if SpellInfo then
    local ok, n, _, t = pcall(SpellInfo, id)
    if ok then name, icon = n, t end
  end
  if not name and GetSpellNameAndRankForId then
    local ok, n = pcall(GetSpellNameAndRankForId, id)
    if ok then name = n end
  end
  if not icon and C_Spell and C_Spell.GetSpellTexture then
    local ok, t = pcall(C_Spell.GetSpellTexture, id)
    if ok then icon = t end
  end
  if EV.nspells >= 1000 then EV.spells, EV.nspells = {}, 0 end
  EV.spells[id] = { name, icon }
  EV.nspells = EV.nspells + 1
  return name, icon
end

local function NameOf(guid)
  if not guid then return nil end
  if U.GuidExists(guid) then
    local n = UnitName(guid)
    if n then return n end
  end
  local u = B.Tracker.units[guid]
  return u and u.name
end

-- 12345 -> "12345", "12,345" or "12.3k"
function EV.Num(n)
  local db = B.db.sct
  n = math.floor((n or 0) + 0.5)
  if db.abbreviate then
    if n >= 1000000 then return string.format("%.1fm", n / 1000000) end
    if n >= 10000 then return string.format("%dk", math.floor(n / 1000 + 0.5)) end
    if n >= 1000 then return string.format("%.1fk", n / 1000) end
    return tostring(n)
  end
  if db.commas and n >= 1000 then
    local s = tostring(n)
    local out = ""
    while string.len(s) > 3 do
      out = "," .. string.sub(s, -3) .. out
      s = string.sub(s, 1, -4)
    end
    return s .. out
  end
  return tostring(n)
end

-- Long spell names: cut after N letters, or initials ("Shadow Bolt" -> "SB").
function EV.Short(s)
  if not s then return s end
  local db = B.db.sct
  if db.truncate == "cut" and string.len(s) > db.truncateLen then
    return string.sub(s, 1, db.truncateLen) .. ".."
  elseif db.truncate == "initials" and string.find(s, " ") then
    local out = ""
    for w in string.gfind(s, "%S+") do out = out .. string.sub(w, 1, 1) end
    return out
  end
  return s
end

local function Fill(fmt, a, s, n, t)
  return (string.gsub(fmt, "%%([asnt%%])", function(c)
    if c == "a" then return a or "" end
    if c == "s" then return s or "" end
    if c == "n" then return n or "" end
    if c == "t" then return t or "" end
    return "%"
  end))
end

local function Listed(list, name)
  if not name or not list or list == "" then return false end
  for item in string.gfind(list, "[^,]+") do
    item = string.gsub(item, "^%s*(.-)%s*$", "%1")
    if item ~= "" and string.lower(item) == string.lower(name) then return true end
  end
  return false
end
EV.Listed = Listed

-- ---------------------------------------------------------------- spells left out
-- (9 Nov 2026, user: a friend's texts spam weapon / item procs - "options to be
-- able to ignore spells we choose or damage procs ? easily")
--   db.hideSpells  names never shown as damage, heals or misses
--   db.hideProcs   your spell damage from spells not in your spellbook (Fire
--                  Strike, Lightning Strike, Engulfing Shadows: weapon and item
--                  procs) left out; db.keepProcs = ones still shown
-- EV.recent: the spells that showed lately, newest first, for one-click hiding.
EV.SPELLTEXT = { ["in"] = true, out = true, heal = true, outheal = true }
EV.NOTSPELL = { buffGain = true, buffFade = true, combatIn = true, combatOut = true, outInterrupt = true, killBlow = true, dispel = true }
EV.PROCKEYS = { outSpell = true, outDot = true }
EV.recent, EV.book = {}, {}

function EV.Ignored(key, spell)
  local e = CT.EVENT[key]
  if not e or not EV.SPELLTEXT[e.group] or EV.NOTSPELL[key] then return false end
  local db = B.db.sct
  if Listed(db.hideSpells, spell) then return true end
  -- (the spellbook not read yet: nothing counts as a proc)
  if db.hideProcs and EV.PROCKEYS[key] and (EV.bookSize or 0) > 0 and not EV.book[spell]
      and not Listed(db.keepProcs, spell) then
    return true
  end
  EV.Saw(spell, key)
  return false
end

function EV.Saw(spell, key)
  local r = EV.recent
  for i = 1, table.getn(r) do
    if r[i].name == spell then
      if i == 1 then return end
      table.remove(r, i)
      break
    end
  end
  table.insert(r, 1, { name = spell, key = key, proc = EV.PROCKEYS[key] and (EV.bookSize or 0) > 0 and not EV.book[spell] })
  if table.getn(r) > 16 then table.remove(r) end
end

-- adds a name to a comma list setting ("hideSpells" / "keepProcs"), or takes it off
function EV.ListSet(field, name, on)
  local db = B.db.sct
  local out, had = {}, false
  for item in string.gfind(db[field] or "", "[^,]+") do
    item = string.gsub(item, "^%s*(.-)%s*$", "%1")
    if item ~= "" then
      if string.lower(item) == string.lower(name) then had = true
        if on then table.insert(out, item) end
      else table.insert(out, item) end
    end
  end
  if on and not had then table.insert(out, name) end
  db[field] = table.concat(out, ", ")
end

-- ---------------------------------------------------------------- one message

-- info: amount, spell (name), spellId, icon, name (other unit), guid (other
-- unit, for the nameplate), school, crit, kind (%t), extra, glance, crush,
-- heal (side), periodic, count
function EV:Fire(key, info)
  local db = B.db.sct
  if not db.enabled then return end
  local ev = db.events[key]
  if not ev or not ev.on then return end
  if info.spell and EV.Ignored(key, info.spell) then return end
  local where = ev.area
  local amount = info.amount
  -- filters and the small-hit size
  local small
  if amount then
    local min = 0
    local g = CT.EVENT[key].group
    if g == "in" or g == "out" then min = db.minDamage elseif key == "inPower" then min = db.minPower
    elseif g == "heal" or g == "outheal" then min = db.minHeal end
    if amount < min then return end
    if db.smallBelow > 0 and amount < db.smallBelow and not info.crit then
      if db.smallHide then return end
      small = true
    end
  end
  local spell = info.spell and EV.Short(info.spell)
  local fmt = (ev.fmt and ev.fmt ~= "") and ev.fmt or CT.EVENT[key].fmt or "%a"
  local crit = info.crit or ev.crit
  local grp = CT.EVENT[key].group
  -- Blizzard numbers: damage, heals and power as bare numbers in the game's colours
  local blizz = db.style == "blizzard" and amount and (grp == "in" or grp == "out" or grp == "heal" or grp == "outheal")
  -- crits as just the number (with the crit look) when asked
  local bare = blizz or (crit and amount and db.critLook.numberOnly)
  -- the text for an amount and count (built again when hits merge on a plate);
  -- crit marks are CT:Show's (db.critLook.mark)
  local function Build(total, count)
    if bare then
      local t = EV.Num(total)
      if count and count > 1 then t = t .. " x" .. count end
      return t
    end
    local text = Fill(fmt, total and EV.Num(total) or nil, spell, info.name, info.kind)
    if count and count > 1 then text = text .. " x" .. count end
    if info.suffix then text = text .. " " .. info.suffix end
    if info.glance and db.showGlance then text = text .. "~" end
    if info.crush and db.showGlance then text = text .. "^" end
    if spell and db.spellNames and not string.find(fmt, "%%s") then text = text .. " (" .. spell .. ")" end
    if info.school and db.schoolNames and SCHOOL[info.school] and info.school > 0 then text = text .. " <" .. SCHOOL[info.school] .. ">" end
    if info.name and db.names and not string.find(fmt, "%%n") and where ~= "plate" then text = info.name .. ": " .. text end
    if info.healer and db.healerNames then text = text .. " (" .. info.healer .. ")" end
    if info.extra and db.showResist then text = text .. " " .. info.extra end
    return text
  end
  local text = Build(amount, info.count)
  local r, g, b = ev.r, ev.g, ev.b
  if db.schoolColors and info.school and SCHOOL_COLOR[info.school] and (key == "outSpell" or key == "outDot" or key == "inSpell" or key == "inDot") then
    local c = SCHOOL_COLOR[info.school]
    r, g, b = c[1], c[2], c[3]
  end
  if blizz then
    if key == "outSpell" or key == "outDot" then r, g, b = 1, 1, 0
    elseif grp == "out" then r, g, b = 1, 1, 1
    elseif grp == "in" then r, g, b = 1, 0.15, 0.15
    elseif key == "inPower" then r, g, b = 0.4, 0.6, 1
    else r, g, b = 0.2, 1, 0.2 end
  end
  local opts = { crit = crit, icon = (db.icons and not blizz) and info.icon or nil, heal = info.heal, small = small,
                 kind = info.plateKind or (crit and "crit" or "hit"), big = ev.big }
  if where == "plate" then
    opts.guid = info.guid
    local tg = U.GuidOf("target")
    opts.target = (tg ~= nil and info.guid == tg)
    if not opts.target and not db.plates.offTarget and info.guid then return end
    if not info.guid then where = db.plates.fallback end
    -- the same attack on the same unit (hit or crit alike) adds up in one text
    if amount and info.guid then
      opts.mergeKey = key .. ":" .. (info.spellId or info.spell or "") .. ":" .. info.guid .. (info.crit and ":c" or "")
      opts.amount, opts.rebuild = amount, Build
    end
  end
  CT:Show(text, r, g, b, where, opts)
  if ev.sound and ev.sound ~= "none" then CT.PlaySound(ev.sound) end
  -- crit sounds (ClassicNumbers' crit / huge crit)
  if info.crit and amount and (key == "outMelee" or key == "outSpell" or key == "outPet") then
    if db.hugeCrit > 0 and amount >= db.hugeCrit then CT.PlaySound(db.hugeCritKey)
    elseif db.critSound > 0 and amount >= db.critSound then CT.PlaySound(db.critSoundKey) end
  end
end

-- Your target only (SCT - Damage's option) for outgoing damage.
local function TargetOk(guid)
  if not B.db.sct.targetOnly then return true end
  local tg = U.GuidOf("target")
  return tg ~= nil and guid == tg
end

-- Hits of one spell within mergeTime become one text with the total and a
-- count (MSBT's AoE merging). Not for nameplates: each plate shows its own.
local MERGEABLE = { outSpell = 1, outDot = 1, outMelee = 1, outPet = 1, outHeal = 1, outHot = 1, inHot = 1 }
function EV:Add(key, info)
  local db = B.db.sct
  local ev = db.events[key]
  if not ev or not ev.on or not db.enabled then return end
  if db.merge and MERGEABLE[key] and ev.area ~= "plate" and info.amount then
    local mk = key .. ":" .. (info.spellId or 0)
    local m = self.merge[mk]
    if m then
      m.amount = m.amount + info.amount
      m.count = m.count + 1
      if info.crit then m.crit = true end
      return
    end
    info.count = 1
    info.due = GetTime() + db.mergeTime
    self.merge[mk] = info
    self.nmerge = self.nmerge + 1
    return
  end
  self:Fire(key, info)
end

local throttleAt = {}
B:Every(0.05, function()
  local now = GetTime()
  if EV.nmerge > 0 then
    for mk, m in pairs(EV.merge) do
      if now >= m.due then
        EV.merge[mk] = nil
        EV.nmerge = EV.nmerge - 1
        local _, _, key = string.find(mk, "^([^:]+)")
        if m.count > 1 then m.name = nil end   -- several targets: no single name
        EV:Fire(key, m)
      end
    end
  end
  -- power gains held back for "throttle" seconds, then shown as one total
  local th = B.db.sct.throttlePower
  for kind, p in pairs(EV.power) do
    if now - (throttleAt[kind] or 0) >= th then
      throttleAt[kind] = now
      EV.power[kind] = nil
      EV:Fire("inPower", { amount = p, kind = kind })
    end
  end
end)

-- ---------------------------------------------------------------- teammates (AnySCT)

-- Damage your party (or raid) and their pets deal, on the nameplate of whoever
-- they hit: smaller, in their class colour, a column beside your own numbers.
-- Players named in team.names count too, on any side (a duo partner outside
-- the group, an enemy healer's target...). Your own damage is never repeated.
-- team[guid] = { name, class, pet }: rebuilt on roster changes and every 5 s.
-- named[guid] = record or false for names.names checks; wiped at 300 or zone.
local team, named, nnamed = {}, {}, 0
EV.team = team

local function AddMember(t, unit, owner)
  local g = U.GuidOf(unit)
  if not g then return end
  local _, class = UnitClass(owner or unit)
  t[g] = { name = UnitName(owner or unit), class = class, pet = owner and true or nil }
end

function EV:Roster()
  local T = B.db.sct.team
  local t = {}
  if T.on then
    local raid = GetNumRaidMembers()
    if T.who == "raid" and raid > 0 then
      for i = 1, raid do
        AddMember(t, "raid" .. i)
        if T.pets then AddMember(t, "raidpet" .. i, "raid" .. i) end
      end
    else
      for i = 1, GetNumPartyMembers() do
        AddMember(t, "party" .. i)
        if T.pets then AddMember(t, "partypet" .. i, "party" .. i) end
      end
    end
    if Me() then t[Me()] = nil end
    if pet then t[pet] = nil end
  end
  team = t
  EV.team = t
  named, nnamed = {}, 0
end

local function Teammate(guid)
  if not guid then return nil end
  local t = team[guid]
  if t then return t end
  local names = B.db.sct.team.names
  if names == "" then return nil end
  local n = named[guid]
  if n ~= nil then return n or nil end
  if nnamed >= 300 then named, nnamed = {}, 0 end
  local rec = false
  if U.GuidExists(guid) and guid ~= Me() then
    local name = UnitName(guid)
    if name and Listed(names, name) then
      local _, class = UnitClass(guid)
      rec = { name = name, class = class }
    end
  end
  named[guid] = rec
  nnamed = nnamed + 1
  return rec or nil
end
EV.Teammate = Teammate

-- One teammate hit (amount) or miss (word) on victim.
function EV:TeamHit(src, t, victim, amount, crit, word, spellId)
  local db = B.db.sct
  local T = db.team
  if not db.enabled or not T.on or not victim or victim == Me() then return end
  if word and not T.misses then return end
  if amount and amount < db.minDamage then return end
  if T.onlyTarget and victim ~= U.GuidOf("target") then return end
  local r, g, b = T.r, T.g, T.b
  local c = T.classColor and t.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[t.class]
  if c then r, g, b = c.r, c.g, c.b end
  local who = T.sourceName and t.name and (t.pet and (t.name .. "'s pet") or t.name) or nil
  local function Build(total, count)
    local s = word or EV.Num(total)
    if count and count > 1 then s = s .. " x" .. count end
    if who then s = s .. " |cffbbbbbb" .. who .. "|r" end
    return s
  end
  local opts = { guid = victim, team = true, crit = crit }
  if amount then
    opts.mergeKey = src .. ":" .. (spellId or 0) .. ":" .. victim .. (crit and ":c" or "")
    opts.amount, opts.rebuild = amount, Build
  end
  CT:Show(Build(amount, 1), r, g, b, "plate", opts)
end

B:On("PARTY_MEMBERS_CHANGED", function() EV:Roster() end)
B:On("RAID_ROSTER_UPDATE", function() EV:Roster() end)
B:On("UNIT_PET", function() EV:Roster() end)
B:On("PLAYER_ENTERING_WORLD", function() EV:Roster() end)
B:Every(5, function()
  if GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0 then EV:Roster() end
end)

-- ---------------------------------------------------------------- damage and healing (nampower)

local function Mitigation(blocked, absorb, resist)
  local t = {}
  if resist and resist > 0 then table.insert(t, "(" .. resist .. " resisted)") end
  if blocked and blocked > 0 then table.insert(t, "(" .. blocked .. " blocked)") end
  if absorb and absorb > 0 then table.insert(t, "(" .. absorb .. " absorbed)") end
  if not t[1] then return nil end
  return table.concat(t, " ")
end

local function Mit(str)
  if type(str) ~= "string" then return nil end
  local _, _, a, b, r = string.find(str, "^(%d+),(%d+),(%d+)")
  return Mitigation(tonumber(b), tonumber(a), tonumber(r))
end

-- Melee: arg1 attacker, arg2 target, arg3 damage, arg4 hitInfo, arg5
-- victimState, arg6 parts, arg7 blocked, arg8 absorbed, arg9 resisted.
local function Melee(attacker, target, dmg, hit, state, blocked, absorb, resist, outKey)
  hit = hit or 0
  local missed = math.mod(math.floor(hit / 16), 2) == 1           -- 0x10
  local crit = math.mod(math.floor(hit / 128), 2) == 1            -- 0x80
  local glance = math.mod(math.floor(hit / 16384), 2) == 1        -- 0x4000
  local crush = math.mod(math.floor(hit / 32768), 2) == 1         -- 0x8000
  local kind = VICTIM[state or 1]
  if missed then kind = "Miss" end
  if not kind and (dmg or 0) <= 0 then
    if absorb and absorb > 0 then kind = "Absorb" elseif resist and resist > 0 then kind = "Resist" end
  end
  return kind, crit, glance, crush, Mitigation(blocked, absorb, resist)
end

-- Overpower, Revenge... (only spells this character knows)
local function Reactive(spell)
  if EV.known[spell] then
    local now = GetTime()
    if now - (EV.low["r" .. spell] or 0) > 4 then
      EV.low["r" .. spell] = now
      local _, icon = nil, EV.knownIcon[spell]
      EV:Fire("reactive", { spell = spell, icon = icon })
    end
  end
end

B:On("AUTO_ATTACK_SELF", function(ev, attacker, target, dmg, hit, state, parts, blocked, absorb, resist)
  if not TargetOk(target) then return end
  local kind, crit, glance, crush, extra = Melee(attacker, target, dmg, hit, state, blocked, absorb, resist)
  if kind then
    EV:Fire("outMiss", { kind = kind, guid = target, name = NameOf(target), plateKind = "miss" })
    if kind == "Dodge" then
      Reactive("Overpower")
      Reactive("Mongoose Bite")
    end
  else
    EV:Add("outMelee", { amount = dmg, crit = crit, glance = glance, crush = crush, extra = extra, guid = target, name = NameOf(target) })
  end
end)

B:On("AUTO_ATTACK_OTHER", function(ev, attacker, target, dmg, hit, state, parts, blocked, absorb, resist)
  local my = Me()
  if target and target == my then
    local kind, crit, glance, crush, extra = Melee(attacker, target, dmg, hit, state, blocked, absorb, resist)
    if kind then
      EV:Fire(MISS_EVENT[kind] or "inMiss", { kind = kind, guid = attacker, name = NameOf(attacker), plateKind = "miss" })
      if kind == "Dodge" or kind == "Parry" or kind == "Block" then Reactive("Revenge") end
      if kind == "Parry" then
        Reactive("Riposte")
        Reactive("Counterattack")
      end
    else
      EV:Fire("inMelee", { amount = dmg, crit = crit, glance = glance, crush = crush, extra = extra, guid = attacker, name = NameOf(attacker) })
    end
  elseif attacker and pet and attacker == pet and TargetOk(target) then
    local kind, crit, glance, crush, extra = Melee(attacker, target, dmg, hit, state, blocked, absorb, resist)
    if kind then
      EV:Fire("outMiss", { kind = "Pet " .. kind, guid = target, name = NameOf(target), plateKind = "miss" })
    else
      EV:Add("outPet", { amount = dmg, crit = crit, extra = extra, guid = target, name = NameOf(target) })
    end
  elseif B.db.sct.team.on then
    local t = Teammate(attacker)
    if t then
      local kind, crit = Melee(attacker, target, dmg, hit, state, blocked, absorb, resist)
      EV:TeamHit(attacker, t, target, (not kind) and dmg or nil, crit, kind)
    end
  end
end)

-- Spell damage: arg1 target, arg2 caster, arg3 spellId, arg4 amount, arg5
-- "absorb,block,resist", arg6 hitInfo (2 = crit), arg7 school, arg8
-- "effect1,effect2,effect3,auraType" (a periodic aura type = a tick).
local function Periodic(str)
  if type(str) ~= "string" then return false end
  local _, _, aura = string.find(str, "(%d+)$")
  return PERIODIC_AURA[tonumber(aura) or 0] and true or false
end

local function SpellHit(target, caster, id, amount, mit, hit, school, eff)
  local name, icon = EV.Spell(id)
  local crit = math.mod(math.floor((hit or 0) / 2), 2) == 1
  return { amount = amount, spell = name, spellId = id, icon = icon, crit = crit, school = school, extra = Mit(mit) },
         Periodic(eff)
end

B:On("SPELL_DAMAGE_EVENT_SELF", function(ev, target, caster, id, amount, mit, hit, school, eff)
  if target == Me() or not TargetOk(target) then return end
  local info, periodic = SpellHit(target, caster, id, amount, mit, hit, school, eff)
  info.guid, info.name = target, NameOf(target)
  EV:Add(periodic and "outDot" or "outSpell", info)
end)

B:On("SPELL_DAMAGE_EVENT_OTHER", function(ev, target, caster, id, amount, mit, hit, school, eff)
  local my = Me()
  if target and target == my then
    local info, periodic = SpellHit(target, caster, id, amount, mit, hit, school, eff)
    info.guid, info.name = caster, NameOf(caster)
    EV:Fire(periodic and "inDot" or "inSpell", info)
  elseif caster and pet and caster == pet and TargetOk(target) then
    local info = SpellHit(target, caster, id, amount, mit, hit, school, eff)
    info.guid, info.name = target, NameOf(target)
    EV:Add("outPet", info)
  elseif B.db.sct.team.on then
    local t = Teammate(caster)
    if t and (B.db.sct.team.dots or not Periodic(eff)) then
      EV:TeamHit(caster, t, target, amount, math.mod(math.floor((hit or 0) / 2), 2) == 1, nil, id)
    end
  end
end)

-- Spell misses: arg1 caster, arg2 target, arg3 spellId, arg4 missInfo.
B:On("SPELL_MISS_SELF", function(ev, caster, target, id, miss)
  if target == Me() or not TargetOk(target) then return end
  local name, icon = EV.Spell(id)
  local kind = MISS[miss or 1] or "Miss"
  EV:Fire("outMiss", { kind = kind, spell = name, icon = icon, guid = target, name = NameOf(target), plateKind = "miss" })
  if kind == "Dodge" then
    Reactive("Overpower")
    Reactive("Mongoose Bite")
  end
end)

B:On("SPELL_MISS_OTHER", function(ev, caster, target, id, miss)
  local my = Me()
  if target and target == my then
    local name, icon = EV.Spell(id)
    local kind = MISS[miss or 1] or "Miss"
    EV:Fire(MISS_EVENT[kind] or "inMiss", { kind = kind, spell = name, icon = icon, guid = caster, name = NameOf(caster), plateKind = "miss" })
    if kind == "Dodge" or kind == "Parry" or kind == "Block" then Reactive("Revenge") end
    if kind == "Parry" then
      Reactive("Riposte")
      Reactive("Counterattack")
    end
  elseif caster and pet and caster == pet and TargetOk(target) then
    EV:Fire("outMiss", { kind = "Pet " .. (MISS[miss or 1] or "Miss"), guid = target, name = NameOf(target), plateKind = "miss" })
  elseif B.db.sct.team.on then
    local t = Teammate(caster)
    if t then EV:TeamHit(caster, t, target, nil, false, MISS[miss or 1] or "Miss") end
  end
end)

-- Heals: arg1 target, arg2 caster, arg3 spellId, arg4 amount, arg5 crit, arg6 periodic.
local lastHp, lastHpMax = nil, nil
B:On("UNIT_HEALTH", function(ev, unit)
  if unit == "player" then lastHp, lastHpMax = UnitHealth("player"), UnitHealthMax("player") end
end)

B:On("SPELL_HEAL_ON_SELF", function(ev, target, caster, id, amount, crit, periodic)
  local name, icon = EV.Spell(id)
  local db = B.db.sct
  local info = { amount = amount, spell = name, spellId = id, icon = icon, crit = crit == 1, heal = true, plateKind = "heal" }
  -- overheal: what went past full health (estimated from the last health seen)
  if db.overheal and lastHp and lastHpMax then
    local over = amount - (lastHpMax - lastHp)
    if over > 0 then info.extra = "{" .. EV.Num(over) .. "}" end
  end
  local self = caster == Me()
  if self then
    if not db.selfHeals then return end
    EV:Add(periodic == 1 and "inHot" or "selfHeal", info)
  else
    info.healer = NameOf(caster)
    info.guid = caster
    EV:Add(periodic == 1 and "inHot" or "inHeal", info)
  end
end)

B:On("SPELL_HEAL_BY_SELF", function(ev, target, caster, id, amount, crit, periodic)
  if target == Me() then return end   -- shown by SPELL_HEAL_ON_SELF
  local name, icon = EV.Spell(id)
  EV:Add(periodic == 1 and "outHot" or "outHeal", { amount = amount, spell = name, spellId = id, icon = icon, crit = crit == 1,
         heal = true, guid = target, name = NameOf(target), plateKind = "heal" })
end)

-- Power: arg1 target, arg2 caster, arg3 spellId, arg4 powerType, arg5 amount, arg6 periodic.
local justEnergized = 0
B:On("SPELL_ENERGIZE_ON_SELF", function(ev, target, caster, id, ptype, amount, periodic)
  local db = B.db.sct
  if ptype == -2 or ptype == 4294967294 then return end   -- health: a heal
  local kind = POWER[ptype or 0] or "Mana"
  justEnergized = GetTime()
  if not db.fullPower and UnitMana("player") >= UnitManaMax("player") and UnitPowerType("player") == ptype then return end
  if db.throttlePower > 0 then
    EV.power[kind] = (EV.power[kind] or 0) + (amount or 0)
    return
  end
  local name, icon = EV.Spell(id)
  EV:Fire("inPower", { amount = amount, kind = kind, spell = name, icon = icon })
end)

-- Regeneration ticks (energy, rage, mana) as power gains (SCT's "all power").
local lastPower
local function PowerTick(ev, unit)
  if unit ~= "player" then return end
  local p = UnitMana("player")
  if lastPower and B.db.sct.regen and p > lastPower and GetTime() - justEnergized > 0.2 then
    local kind = POWER[UnitPowerType("player")] or "Mana"
    if B.db.sct.throttlePower > 0 then
      EV.power[kind] = (EV.power[kind] or 0) + (p - lastPower)
    else
      EV:Fire("inPower", { amount = p - lastPower, kind = kind })
    end
  end
  lastPower = p
end
B:On("UNIT_MANA", PowerTick)
B:On("UNIT_RAGE", PowerTick)
B:On("UNIT_ENERGY", PowerTick)
B:On("UNIT_FOCUS", PowerTick)

-- Damage shields: arg1 owner, arg2 attacker hit by it, arg3 damage, arg4 school.
B:On("DAMAGE_SHIELD_SELF", function(ev, owner, attacker, dmg, school)
  if owner ~= Me() or not TargetOk(attacker) then return end
  EV:Fire("outShield", { amount = dmg, school = school, guid = attacker, name = NameOf(attacker) })
end)

-- Environment: arg1 unit, arg2 type, arg3 damage, arg4 absorb, arg5 resist.
B:On("ENVIRONMENTAL_DMG_SELF", function(ev, unit, kind, dmg, absorb, resist)
  if unit ~= Me() then return end
  EV:Fire("inEnv", { amount = dmg, kind = ENV[kind or 2] or "Falling", extra = Mitigation(0, absorb, resist) })
end)

-- Dispels: arg1 caster, arg2 target, arg3 spellId of the aura removed.
B:On("SPELL_DISPEL_BY_SELF", function(ev, caster, target, id)
  local name, icon = EV.Spell(id)
  EV:Fire("dispel", { spell = name, icon = icon, guid = target, name = NameOf(target) })
end)

-- Auras on you: arg1 guid, arg2 slot (0 = hidden), arg3 spellId, arg4 stacks, arg7 state (0 added, 1 removed, 2 stacks).
-- (26 Oct 2026, user: "[Inner Fire (30)]" shown twice, one over the other)
-- nampower sends the same aura news more than once (a refresh, a slot move),
-- so a stack change only shows when the stacks went up, and the same text
-- never shows twice within 1.5 s. Charges going down (Inner Fire, Lightning
-- Shield) are not news.
local auraStacks, auraShown = {}, {}
local function Aura(gain, debuff)
  return function(ev, guid, slot, id, stacks, level, raw, state)
    if guid ~= Me() or slot == 0 then return end
    local name, icon = EV.Spell(id)
    if not name or Listed(B.db.sct.hideAuras, name) then return end
    local key = (debuff and "d" or "b") .. tostring(id)
    local before = auraStacks[key]
    if state == 1 or not gain then auraStacks[key] = nil else auraStacks[key] = stacks or 1 end
    local label = name
    if state == 2 then
      if not gain or (before and (stacks or 1) <= before) then return end
      label = name .. " (" .. (stacks or 1) .. ")"
    end
    local shown = (gain and "+" or "-") .. key .. label
    local now = GetTime()
    if (auraShown[shown] or 0) > now then return end
    auraShown[shown] = now + 1.5
    if gain and not debuff and Listed(B.db.sct.procs, name) then
      EV:Fire("proc", { spell = label, icon = icon })
    elseif debuff then
      EV:Fire(gain and "debuffGain" or "debuffFade", { spell = label, icon = icon })
    else
      EV:Fire(gain and "buffGain" or "buffFade", { spell = label, icon = icon })
    end
  end
end
B:On("BUFF_ADDED_SELF", Aura(true, false))
B:On("BUFF_REMOVED_SELF", Aura(false, false))
B:On("DEBUFF_ADDED_SELF", Aura(true, true))
B:On("DEBUFF_REMOVED_SELF", Aura(false, true))

-- ---------------------------------------------------------------- client events

B:On("PLAYER_REGEN_DISABLED", function() EV:Fire("combatIn", {}) end)
B:On("PLAYER_REGEN_ENABLED", function() EV:Fire("combatOut", {}) end)
B:On("SPELLCAST_INTERRUPTED", function() EV:Fire("interrupted", {}) end)

local lastCP = 0
B:On("PLAYER_COMBO_POINTS", function()
  local cp = GetComboPoints and GetComboPoints() or 0
  if cp > lastCP then
    EV:Fire("combo", { amount = cp, crit = cp >= 5, suffix = (cp >= 5) and "Finish It!" or nil })
  end
  lastCP = cp
end)

-- Low health / mana: once each time it drops under the threshold.
local function Low(ev, unit)
  if unit ~= "player" then return end
  local db = B.db.sct
  local hp, max = UnitHealth("player"), UnitHealthMax("player")
  if max and max > 0 and not UnitIsDeadOrGhost("player") then
    local below = hp / max * 100 < db.lowHp
    if below and not EV.low.hp then EV:Fire("lowHp", {}) end
    EV.low.hp = below
  end
  if UnitPowerType("player") == 0 then
    local mp, mmax = UnitMana("player"), UnitManaMax("player")
    if mmax and mmax > 0 then
      local below = mp / mmax * 100 < db.lowMana
      if below and not EV.low.mana then EV:Fire("lowMana", {}) end
      EV.low.mana = below
    end
  end
end
B:On("UNIT_HEALTH", Low)
B:On("UNIT_MANA", Low)

-- Execute: an enemy target under 20 % (warriors who know it).
local executeShown
local function Execute()
  if not EV.known.Execute then return end
  if UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target") then
    local hp, max = UnitHealth("target"), UnitHealthMax("target")
    local under = max and max > 0 and hp / max < 0.2
    if under and executeShown ~= U.GuidOf("target") then
      executeShown = U.GuidOf("target") or "?"
      Reactive("Execute")
    elseif not under and executeShown == U.GuidOf("target") then
      executeShown = nil
    end
  end
end
B:On("UNIT_HEALTH", function(ev, unit) if unit == "target" then Execute() end end)
B:On("PLAYER_TARGET_CHANGED", function() executeShown = nil Execute() end)

-- The spellbook: which reactive spells this character knows, and cooldowns.
local REACTIVES = { "Overpower", "Revenge", "Execute", "Riposte", "Counterattack", "Mongoose Bite" }
EV.knownIcon = {}
local function ScanBook()
  EV.known, EV.knownIcon, EV.book = {}, {}, {}
  local want = {}
  for i = 1, table.getn(REACTIVES) do want[REACTIVES[i]] = true end
  local i = 1
  while true do
    local name = GetSpellName(i, BOOKTYPE_SPELL or "spell")
    if not name then break end
    EV.book[name] = true
    if want[name] then
      EV.known[name] = i
      EV.knownIcon[name] = GetSpellTexture(i, BOOKTYPE_SPELL or "spell")
    end
    i = i + 1
    if i > 400 then break end
  end
  EV.bookSize = i - 1
end
B:On("SPELLS_CHANGED", ScanBook)
B:On("LEARNED_SPELL_IN_TAB", ScanBook)
B:On("PLAYER_ENTERING_WORLD", ScanBook)

-- Cooldowns ready (MSBT): spells with a cooldown of at least cdReadyMin
-- seconds announce themselves when they are back.
local cdScanAt, cdDirty = 0, false
B:On("SPELL_UPDATE_COOLDOWN", function() cdDirty = true end)
B:Every(0.2, function()
  local db = B.db.sct
  if not db.enabled or not db.events.cdReady.on then return end
  local now = GetTime()
  if cdDirty and now - cdScanAt > 0.3 and EV.bookSize then
    cdDirty, cdScanAt = false, now
    local book = BOOKTYPE_SPELL or "spell"
    for i = 1, EV.bookSize do
      local start, dur, enabled = GetSpellCooldown(i, book)
      if start and start > 0 and dur and dur >= math.max(2, db.cdReadyMin) and enabled == 1 then
        local name = GetSpellName(i, book)
        if name and not Listed(db.cdExclude, name) then
          EV.cds[name] = { ends = start + dur, icon = GetSpellTexture(i, book) }
        end
      end
    end
  end
  for name, c in pairs(EV.cds) do
    if now >= c.ends then
      EV.cds[name] = nil
      EV:Fire("cdReady", { spell = name, icon = c.icon })
    end
  end
end)

-- ---------------------------------------------------------------- chat lines

-- A Lua pattern from one of the client's own format strings ("You have
-- slain %s!" -> "^You have slain (.+)!$").
local function Pattern(global, fallback)
  local s = (type(global) == "string") and global or fallback
  s = string.gsub(s, "([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
  s = string.gsub(s, "%%s", "(.+)")
  s = string.gsub(s, "%%d", "(%%d+)")
  return "^" .. s .. "$"
end

local P = {}
B:On("OBG_LOADED", function()
  P.slain = Pattern(SELFKILLOTHER, "You have slain %s!")
  P.honor = Pattern(COMBATLOG_HONORGAIN, "%s dies, honorable kill Rank: %s (Estimated Honor Points: %d)")
  P.award = Pattern(COMBATLOG_HONORAWARD, "You have been awarded %d honor points.")
  P.repUp = Pattern(FACTION_STANDING_INCREASED, "Your %s reputation has increased by %d.")
  P.repDown = Pattern(FACTION_STANDING_DECREASED, "Your %s reputation has decreased by %d.")
  P.skill = Pattern(SKILL_RANK_UP, "Your skill in %s has increased to %d.")
  P.xp = Pattern(COMBATLOG_XPGAIN_FIRSTPERSON, "%s dies, you gain %d experience.")
  P.xp2 = Pattern(COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED, "You gain %d experience.")
  P.money = Pattern(YOU_LOOT_MONEY, "You loot %s")
  P.share = Pattern(LOOT_MONEY_SPLIT, "Your share of the loot is %s.")
  P.loot = Pattern(LOOT_ITEM_SELF, "You receive loot: %s.")
  P.lootN = Pattern(LOOT_ITEM_SELF_MULTIPLE, "You receive loot: %sx%d.")
  P.push = Pattern(LOOT_ITEM_PUSHED_SELF, "You receive item: %s.")
  P.pushN = Pattern(LOOT_ITEM_PUSHED_SELF_MULTIPLE, "You receive item: %sx%d.")
  P.extra = Pattern(SPELLEXTRAATTACKSSELF, "You gain %d extra attacks through %s.")
  P.extra1 = Pattern(SPELLEXTRAATTACKSSELF_SINGULAR, "You gain %d extra attack through %s.")
  P.interrupt = Pattern(SPELLINTERRUPTSELFOTHER, "You interrupt %s's %s.")
end)

B:On("CHAT_MSG_COMBAT_HOSTILE_DEATH", function(ev, msg)
  if not msg or not P.slain then return end
  local _, _, who = string.find(msg, P.slain)
  if who then
    EV:Fire("killBlow", { name = who })
    if B.db.sct.killSound ~= "none" then CT.PlaySound(B.db.sct.killSound) end
  end
end)

B:On("CHAT_MSG_COMBAT_HONOR_GAIN", function(ev, msg)
  if not msg or not P.honor then return end
  local _, _, who, rank, pts = string.find(msg, P.honor)
  if pts then
    EV:Fire("honor", { amount = tonumber(pts), name = who, spell = rank })
    return
  end
  local _, _, award = string.find(msg, P.award)
  if award then EV:Fire("honor", { amount = tonumber(award) }) end
end)

B:On("CHAT_MSG_COMBAT_FACTION_CHANGE", function(ev, msg)
  if not msg or not P.repUp then return end
  local _, _, fac, n = string.find(msg, P.repUp)
  if n then EV:Fire("rep", { amount = tonumber(n), spell = fac, kind = "+" }) return end
  _, _, fac, n = string.find(msg, P.repDown)
  if n then EV:Fire("rep", { amount = -tonumber(n), spell = fac, kind = "-" }) end
end)

B:On("CHAT_MSG_SKILL", function(ev, msg)
  if not msg or not P.skill then return end
  local _, _, skill, n = string.find(msg, P.skill)
  if n then EV:Fire("skill", { amount = tonumber(n), spell = skill }) end
end)

B:On("CHAT_MSG_COMBAT_XP_GAIN", function(ev, msg)
  if not msg or not P.xp then return end
  local _, _, who, n = string.find(msg, P.xp)
  if not n then _, _, n = string.find(msg, P.xp2) end
  if not n then _, _, n = string.find(msg, "(%d+)") end
  if n then EV:Fire("xp", { amount = tonumber(n), name = who }) end
end)

B:On("CHAT_MSG_MONEY", function(ev, msg)
  if not msg or not P.money then return end
  local _, _, cash = string.find(msg, P.money)
  if not cash then _, _, cash = string.find(msg, P.share) end
  if cash then EV:Fire("money", { spell = cash }) end
end)

B:On("CHAT_MSG_LOOT", function(ev, msg)
  if not msg or not P.loot then return end
  local _, _, item, n = string.find(msg, P.lootN)
  if not item then _, _, item, n = string.find(msg, P.pushN) end
  if not item then _, _, item = string.find(msg, P.loot) end
  if not item then _, _, item = string.find(msg, P.push) end
  if item then
    -- the item link's text, without the link codes
    local _, _, plain = string.find(item, "%[(.-)%]")
    EV:Fire("loot", { spell = (plain or item) .. ((n and tonumber(n) > 1) and (" x" .. n) or "") })
  end
end)

local function SelfBuff(ev, msg)
  if not msg or not P.extra then return end
  if string.find(msg, P.extra) or string.find(msg, P.extra1) then EV:Fire("extraAttack", {}) end
end
B:On("CHAT_MSG_SPELL_SELF_BUFF", SelfBuff)
B:On("CHAT_MSG_SPELL_ITEM_ENCHANTMENTS", SelfBuff)

B:On("CHAT_MSG_SPELL_SELF_DAMAGE", function(ev, msg)
  if not msg or not P.interrupt then return end
  local _, _, who, spell = string.find(msg, P.interrupt)
  if who then EV:Fire("outInterrupt", { name = who, spell = spell }) end
end)

-- ---------------------------------------------------------------- OctoBG's alerts

-- Cooldowns.lua and Nearby.lua call this with their alert text.
function CT:Notify(key, text, r, g, b)
  local db = B.db.sct
  local ev = db.events[key]
  if not db.enabled or not ev or not ev.on then return end
  local fmt = (ev.fmt and ev.fmt ~= "") and ev.fmt or "%s"
  CT:Show(Fill(fmt, nil, text, nil, nil), r or ev.r, g or ev.g, b or ev.b, ev.area == "plate" and "note" or ev.area, { crit = ev.crit })
  if ev.sound and ev.sound ~= "none" then CT.PlaySound(ev.sound) end
end

-- ---------------------------------------------------------------- the game's own numbers

-- 1.12's floating damage over targets (CombatDamage) and SuperWoW's healing
-- numbers (HealingText, the CVar SuperAPI's options use).
-- The game's own floating numbers: CombatDamage and PetMeleeDamage (WoW.exe),
-- HealingText (SuperWoW). 1.12 has no other combat text of its own.
local GAME_CVARS = { dmg = "CombatDamage", pet = "PetMeleeDamage", heal = "HealingText" }

-- "fct": this client also has Blizzard's scrolling combat text over your
-- character (Blizzard_CombatText in patch-4.mpq, LoadOnDemand, backported):
-- heals you get, damage you take... It is switched by the saved UI variable
-- SHOW_COMBAT_TEXT ("1" / "0", UIOptionsFrame.lua), and
-- CombatText_UpdateDisplayedMessages() (un)registers its events.
--
-- Its heals carry the healer as a GUID under SuperWoW ("+875 [0x...]").
-- SuperAPI renames them by hooking CombatText_AddMessage when SuperAPI loads -
-- but the addon loads on demand: if it loads later (switched on after login),
-- its own CombatText_AddMessage replaces that hook and the GUIDs show until a
-- /reload. CT:FixHealerNames puts the same fix on whenever it is missing.
-- (11 Nov 2026, dennis on Discord, a hunter shooting: "sct-events.lua:1155: stack overflow" on every
-- line.) It ran at every ADDON_LOADED, and each time the function on top was not exactly its own -
-- pfUI's superwow.lua wraps CombatText_AddMessage too - it wrapped again, with ONE shared "original":
-- the older wrapper then called the newer one's original, which called the older wrapper... forever.
-- Now each wrapper keeps its own original, and a function it has seen (its own wrappers and every
-- function it wrapped, wrapped by others or not) is never wrapped again.
local seenAdd = {}
CT.seenAdd = seenAdd
function CT:FixHealerNames()
  local cur = CombatText_AddMessage
  if not cur or seenAdd[cur] then return end
  if SuperAPI and cur == SuperAPI.CombatText_AddMessage and SuperAPI.CombatText_AddMessageOriginal then return end
  local origAdd = cur
  seenAdd[cur] = true
  local fixedAdd
  fixedAdd = function(message, a1, a2, a3, a4, a5, a6)
    if type(message) == "string" and string.find(message, "[0x", 1, true) then
      message = string.gsub(message, " %[(0x%x+)%]", function(hex)
        local ok, me = pcall(UnitIsUnit, hex, "player")
        if ok and me then return "" end
        local ok2, n = pcall(UnitName, hex)
        if ok2 and n then return " [" .. n .. "]" end
        return ""
      end)
    end
    return origAdd(message, a1, a2, a3, a4, a5, a6)
  end
  seenAdd[fixedAdd] = true
  CombatText_AddMessage = fixedAdd
end

local function FctSet(on)
  SHOW_COMBAT_TEXT = on and "1" or "0"
  if on and not CombatText_UpdateDisplayedMessages and LoadAddOn then pcall(LoadAddOn, "Blizzard_CombatText") end
  CT:FixHealerNames()
  if CombatText_UpdateDisplayedMessages and CombatText then pcall(CombatText_UpdateDisplayedMessages) end
end

function CT:GameNumbers(which, on)
  if which == "fct" then
    FctSet(on)
    return
  end
  local cvar = GAME_CVARS[which] or "CombatDamage"
  local ok = pcall(SetCVar, cvar, on and "1" or "0")
  if not ok then B:Print(cvar .. ": not on this client") end
end

function CT:GameNumbersOn(which)
  if which == "fct" then return SHOW_COMBAT_TEXT == "1" end
  local ok, v = pcall(GetCVar, GAME_CVARS[which] or "CombatDamage")
  return ok and v == "1"
end

-- whenever an addon (Blizzard_CombatText) loads, the healer names stay names
B:On("ADDON_LOADED", function() CT:FixHealerNames() end)

-- The master switch (top of every combat text page, the quick bar, /obg sct
-- on | off): off gives the game's own numbers back, on takes them away again
-- so nothing shows twice.
function CT:SetEnabled(on)
  local db = B.db.sct
  db.enabled = on and true or false
  if not on then
    self:Clear()
    if self:Testing() then self:TestMode(false) end
  end
  for _, w in ipairs({ "dmg", "pet", "heal" }) do
    pcall(SetCVar, GAME_CVARS[w], on and "0" or "1")   -- HealingText exists only with SuperWoW
  end
  FctSet(not on)   -- Blizzard's scrolling text over your character
  B:Print("combat text " .. (on and "|cff55ff55on|r - the game's own numbers are off" or
    "|cffff5555off|r - the game's own damage and healing numbers are back"))
  if B.Options then B.Options:Refresh() end
end

-- Spy-style nameplates: the plates must be up for text to rise from them.
B:On("PLAYER_ENTERING_WORLD", function()
  local db = B.db.sct
  if db.enabled and db.plates.autoShow and ShowNameplates then ShowNameplates() end
  -- once: the game's own damage / SuperWoW healing numbers would show twice
  -- (SCT - Damage switched the game's off by default too)
  if db.enabled and not db.gameNumbersDone then
    db.gameNumbersDone = true
    local off = {}
    if CT:GameNumbersOn("dmg") then CT:GameNumbers("dmg", false) table.insert(off, "damage") end
    if CT:GameNumbersOn("heal") then CT:GameNumbers("heal", false) table.insert(off, "healing") end
    if off[1] then
      B:Print("combat text: the game's own " .. table.concat(off, " and ") .. " numbers are off so nothing shows twice - "
        .. "/obg sct to switch them back on")
    end
  end
  -- once (added later, so its own flag): Blizzard's scrolling text over you
  if db.enabled and not db.gameFctDone then
    db.gameFctDone = true
    if CT:GameNumbersOn("fct") then
      CT:GameNumbers("fct", false)
      B:Print("combat text: the game's scrolling text over your character is off so heals don't show twice - "
        .. "/obg sct off gives the game's text back")
    end
  end
  CT:FixHealerNames()
  local cv = { "NP_EnableSpellHealEvents", "NP_EnableSpellEnergizeEvents" }
  for i = 1, table.getn(cv) do
    local ok, v = pcall(GetCVar, cv[i])
    if ok and v ~= nil and v ~= "1" then pcall(SetCVar, cv[i], "1") end
  end
end)

B:On("OBG_ZONE", function()
  EV.merge, EV.nmerge, EV.power, EV.cds = {}, 0, {}, {}
  executeShown = nil
end)

-- ---------------------------------------------------------------- tests

-- Every nameplate on screen with a GUID (enemies with V, friends with Shift-V).
function CT:Plates()
  local out = {}
  local kids = { WorldFrame:GetChildren() }
  for i = 1, table.getn(kids) do
    local k = kids[i]
    if k:IsVisible() then
      local g = self:PlateGuid(k)
      if g then table.insert(out, g) end
    end
  end
  return out
end

local SPELLS = { { "Fireball", 2 }, { "Frostbolt", 4 }, { "Shadow Bolt", 5 }, { "Mortal Strike", 0 }, { "Holy Shock", 1 },
                 { "Arcane Missiles", 6 }, { "Wrath", 3 } }

-- One round of sample texts through the real message types, so colours,
-- areas, nameplates and crit styles show as they are set.
function CT:TestRound()
  local r = math.random
  local tg = U.GuidOf("target")
  local plates = self:Plates()
  -- your damage: on every plate (or the fallback area with none on screen)
  local n = math.min(table.getn(plates), 6)
  for i = 1, math.max(1, n) do
    local g = plates[i]
    local sp = SPELLS[r(1, table.getn(SPELLS))]
    local roll = r(1, 10)
    if roll <= 4 then
      EV:Fire("outMelee", { amount = r(200, 900), crit = roll == 1, guid = g, name = "Test" })
    elseif roll <= 8 then
      EV:Fire("outSpell", { amount = r(400, 2600), crit = roll == 5, spell = sp[1], school = sp[2], guid = g, name = "Test" })
    elseif roll == 9 then
      EV:Fire("outMiss", { kind = "Dodge", guid = g, plateKind = "miss" })
    else
      EV:Fire("outDot", { amount = r(80, 300), spell = "Corruption", school = 5, guid = g })
    end
  end
  if tg and n == 0 then EV:Fire("outSpell", { amount = r(800, 2000), spell = "Fireball", school = 2, guid = tg }) end
  -- a teammate's hit in its column beside yours
  if B.db.sct.team.on and n > 0 then
    EV:TeamHit("test", { name = "Teammate", class = "PALADIN" }, plates[r(1, n)], r(150, 1200), r(1, 6) == 1)
  end
  -- damage and healing you take
  local roll = r(1, 6)
  if roll <= 3 then EV:Fire("inMelee", { amount = r(150, 700), crit = roll == 1 })
  elseif roll == 4 then EV:Fire("inSpell", { amount = r(300, 1200), spell = "Frostbolt", school = 4 })
  elseif roll == 5 then EV:Fire("inParry", { kind = "Parry" })
  else EV:Fire("inDot", { amount = r(60, 200), spell = "Shadow Word: Pain", school = 5 }) end
  if r(1, 2) == 1 then EV:Fire("inHeal", { amount = r(300, 2000), spell = "Flash Heal", healer = "Testpriest", heal = true, crit = r(1, 5) == 1 }) end
  if r(1, 3) == 1 then EV:Fire("inPower", { amount = r(10, 30), kind = "Rage" }) end
  -- something for the notification and other areas now and then
  local note = r(1, 8)
  if note == 1 then EV:Fire("killBlow", { name = "Testrogue" })
  elseif note == 2 then EV:Fire("honor", { amount = r(20, 200) })
  elseif note == 3 then EV:Fire("buffGain", { spell = "Blessing of Might" })
  elseif note == 4 then EV:Fire("reactive", { spell = "Overpower" }) end
  if self.areaTest then
    CT:Show("Extra " .. r(10, 99), 0.7, 0.7, 1, "extra", {})
  end
end

function CT:Testing()
  return self.testUntil and GetTime() < self.testUntil
end

-- Test mode: a round every 0.8 s for a minute (or until switched off).
function CT:TestMode(on)
  if on then
    if not B.db.sct.enabled then
      B.db.sct.enabled = true
      B:Print("combat text switched on for the test")
    end
    self.testUntil = GetTime() + 60
    if B.Threat then B.Threat:Sample(60) end
    if table.getn(self:Plates()) == 0 then
      B:Print("combat text test: no nameplates on screen - press V (enemies) or Shift-V (friendly) to see text rise from plates")
    end
  else
    self.testUntil = nil
    if B.Threat then B.Threat.sampleUntil = nil end
  end
  if B.Options then B.Options:Refresh() end
end

B:Every(0.8, function()
  if not CT.testUntil then return end
  if GetTime() >= CT.testUntil then
    CT.testUntil = nil
    if B.Options then B.Options:Refresh() end
    return
  end
  CT:TestRound()
end)

-- A burst on every plate on screen: hit, crit, miss and heal each.
function CT:TestPlates()
  local plates = self:Plates()
  if table.getn(plates) == 0 then
    B:Print("no nameplates on screen - press V (enemies) or Shift-V (friendly), e.g. in a city")
    return
  end
  for i = 1, math.min(table.getn(plates), 10) do
    local g = plates[i]
    CT:Show("1234", 1, 1, 1, "plate", { guid = g, target = true, kind = "hit" })
    CT:Show("2468", 1, 0.85, 0.2, "plate", { guid = g, target = true, crit = true, kind = "crit" })
    CT:Show("Dodge", 0.75, 0.75, 0.75, "plate", { guid = g, target = true, kind = "miss" })
    CT:Show("+850", 0.2, 1, 0.4, "plate", { guid = g, target = true, kind = "heal", heal = true })
  end
end

-- ---------------------------------------------------------------- previews

function CT:Preview(what)
  local tg = U.GuidOf("target")
  if what == "plate" then
    if not tg or not CT:Plate(tg) then
      B:Print("target an enemy with its nameplate showing (V) to preview nameplate text")
      return
    end
    EV:Fire("outMelee", { amount = 1234, guid = tg, name = UnitName("target") })
    EV:Fire("outSpell", { amount = 3456, crit = true, spell = "Fireball", school = 2, guid = tg, name = UnitName("target") })
    EV:Fire("outMiss", { kind = "Dodge", guid = tg, plateKind = "miss" })
    return
  end
  EV:Fire("inMelee", { amount = 512, crit = (what == "crit") })
  EV:Fire("inSpell", { amount = 860, school = 4, spell = "Frostbolt" })
  EV:Fire("inDodge", { kind = "Dodge" })
  EV:Fire("inHeal", { amount = 1300, spell = "Flash Heal", healer = "Healbot", heal = true, crit = (what == "crit") })
  EV:Fire("inPower", { amount = 25, kind = "Rage" })
  EV:Fire("outSpell", { amount = 2468, crit = (what == "crit"), spell = "Shadow Bolt", school = 5, guid = tg })
  EV:Fire("lowHp", {})
  EV:Fire("honor", { amount = 198 })
end
