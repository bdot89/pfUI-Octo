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
  -- (20 Nov 2026, user: "demo.lua:37: bad argument #2 to 'random' (interval is empty)" over and over in a demo - the
  -- wipe kept picking from the living after the last one died) an empty list gives nothing
  local function Pick(list)
    local n = list and table.getn(list) or 0
    if n < 1 then return nil end
    return list[math.random(1, n)]
  end

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
    DM.tank, DM.offtank = DM.units.raid2, DM.units.raid3
    DM.units.raid2.leader = true
  end

  -- the dungeon / PvP group: four with you (party1-4)
  DM.PARTY = { { "WARRIOR", "tank", 6200, 1, 100 }, { "PRIEST", "heal", 3900, 0, 5200 }, { "MAGE", "dps", 3700, 0, 5600 },
    { "ROGUE", "dps", 4100, 3, 100 } }
  function DM.MakeParty()
    DM.units, DM.list = {}, {}
    for i, m in ipairs(DM.PARTY) do
      local u = { token = "party" .. i, name = DM.NAMES[i + 10], class = m[1], cl = DM.LOCAL[m[1]] or m[1], role = m[2],
        max = math.floor(m[3] * Rand(.95, 1.08)), ptype = m[4], pmax = m[5], group = 1, level = 60, player = true,
        debuffs = {}, buffs = DM.BUFFS }
      u.hp, u.pw = u.max, u.ptype == 1 and 0 or u.pmax
      DM.units[u.token] = u
      table.insert(DM.list, u)
    end
    DM.tank, DM.offtank = DM.units.party1, DM.units.party4
    DM.units.party1.leader, DM.units.party1.mark = true, 6
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

  -- the target dummy demo (user: "a dummy ... different levels it will change to bosses"): one dummy on your
  -- target that steps through every rank, DM.RANKTIME seconds each (Next = the next one now), so every crest,
  -- dragon, colour and frame look shows in turn. It never dies: near the end its health fills again.
  DM.RANKTIME = 12
  DM.DUMMIES = {
    { name = "Training Dummy", ctype = "Mechanical", level = 60, cls = "normal", max = 120000, label = "Normal" },
    { name = "Elite Training Dummy", ctype = "Mechanical", level = 62, cls = "elite", max = 380000, label = "Elite" },
    { name = "Rare Training Dummy", ctype = "Mechanical", level = 61, cls = "rare", max = 200000, label = "Rare" },
    { name = "Rare Elite Training Dummy", ctype = "Mechanical", level = 62, cls = "rareelite", max = 520000, label = "Rare elite" },
    { name = "Boss Training Dummy", ctype = "Mechanical", level = -1, cls = "worldboss", max = 2400000, label = "World boss" },
  }
  for _, d in ipairs(DM.DUMMIES) do d.abilities, d.melee = {}, { 0, 0 } end

  -- the dungeon demo (5): two packs (a kill order by marks, one sheeped, a caster to kick), then the end boss
  -- (kick = a party member interrupts it most of the time; cc = it stands polymorphed until it is the last one)
  DM.PACKS = {
    {
      { name = "Scarlet Defender", ctype = "Humanoid", level = 61, cls = "elite", max = 14000, melee = { 350, 600 }, mark = 8,
        abilities = { { name = "Shield Bash", icon = I .. "Ability_Warrior_ShieldBash", every = 10, what = "some", n = 1, dmg = { 200, 350 } } } },
      { name = "Scarlet Sorcerer", ctype = "Humanoid", level = 60, cls = "elite", max = 9000, melee = { 150, 250 }, mark = 7,
        abilities = { { name = "Fireball", icon = I .. "Spell_Fire_FlameBolt", every = 6, cast = 3, kick = true, what = "some", n = 1, dmg = { 900, 1300 } },
          { name = "Frost Nova", icon = I .. "Spell_Frost_FrostNova", every = 14, what = "raid", dmg = { 150, 250 },
            debuff = { I .. "Spell_Frost_FrostNova", "Magic", 6 } } } },
      { name = "Scarlet Chaplain", ctype = "Humanoid", level = 60, cls = "elite", max = 10000, melee = { 200, 300 }, mark = 5, cc = true,
        abilities = { { name = "Smite", icon = I .. "Spell_Holy_HolySmite", every = 7, cast = 2, kick = true, what = "some", n = 1, dmg = { 600, 900 } } } },
    },
    {
      { name = "Scarlet Myrmidon", ctype = "Humanoid", level = 61, cls = "elite", max = 15000, melee = { 400, 700 }, mark = 8,
        abilities = { { name = "Enrage", icon = I .. "Spell_Shadow_UnholyFrenzy", every = 18, what = "tank", dmg = { 500, 800 },
          say = "Scarlet Myrmidon goes into a frenzy!" } } },
      { name = "Scarlet Adept", ctype = "Humanoid", level = 60, cls = "elite", max = 8500, melee = { 150, 250 }, mark = 7,
        abilities = { { name = "Shadow Bolt", icon = I .. "Spell_Shadow_ShadowBolt", every = 5, cast = 2.5, kick = true, what = "some", n = 1, dmg = { 800, 1100 } },
          { name = "Curse of Weakness", icon = I .. "Spell_Shadow_CurseOfMannoroth", every = 12, what = "some", n = 2, dmg = { 50, 100 },
            debuff = { I .. "Spell_Shadow_CurseOfMannoroth", "Curse", 12 } } } },
      { name = "Scarlet Monk", ctype = "Humanoid", level = 60, cls = "elite", max = 11000, melee = { 300, 500 }, mark = 1,
        abilities = { { name = "Kick", icon = I .. "Ability_Kick", every = 9, what = "some", n = 1, dmg = { 150, 250 } } } },
      { name = "Scarlet Torturer", ctype = "Humanoid", level = 60, cls = "elite", max = 9000, melee = { 250, 400 }, mark = 5, cc = true,
        abilities = { { name = "Poison", icon = I .. "Spell_Nature_CorrosiveBreath", every = 8, what = "some", n = 1, dmg = { 200, 300 },
          debuff = { I .. "Spell_Nature_CorrosiveBreath", "Poison", 10 } } } },
    },
  }
  DM.DBOSSES = {
    { name = "High Inquisitor Varra", ctype = "Humanoid", level = 63, cls = "elite", max = 95000, melee = { 600, 1000 },
      abilities = {
        { name = "Holy Smite", icon = I .. "Spell_Holy_HolySmite", every = 8, cast = 2.5, kick = true, what = "some", n = 1, dmg = { 1200, 1600 } },
        { name = "Hammer of Justice", icon = I .. "Spell_Holy_SealOfMight", every = 15, what = "tank", dmg = { 300, 500 },
          debuff = { I .. "Spell_Holy_SealOfMight", "Magic", 6 }, say = "High Inquisitor Varra stuns the tank!" },
        { name = "Consecration", icon = I .. "Spell_Holy_InnerFire", every = 12, what = "raid", dmg = { 250, 400 } },
      } },
    { name = "Archmage Vorlath", ctype = "Humanoid", level = 63, cls = "elite", max = 90000, melee = { 400, 700 },
      abilities = {
        { name = "Pyroblast", icon = I .. "Spell_Fire_Fireball02", every = 12, cast = 4, kick = true, what = "some", n = 1, dmg = { 1800, 2400 },
          say = "Archmage Vorlath begins to cast Pyroblast - kick it!" },
        { name = "Arcane Explosion", icon = I .. "Spell_Nature_WispSplode", every = 9, what = "raid", dmg = { 350, 500 } },
        { name = "Polymorph", icon = I .. "Spell_Nature_Polymorph", every = 16, what = "some", n = 1, dmg = { 0, 0 },
          debuff = { I .. "Spell_Nature_Polymorph", "Magic", 8 } },
      } },
  }

  -- the PvP demo: enemy players one after another on your target, their class spells (most casts kicked)
  DM.ENEMYNAMES = { "Kragnor", "Velith", "Sarduk", "Mirthis", "Oglak", "Teralyn", "Durzak", "Ysmera", "Brakka", "Zelthis", "Orvane", "Thessa" }
  DM.ENEMY = {
    MAGE = { 3400, { { name = "Frostbolt", icon = I .. "Spell_Frost_FrostBolt02", every = 4, cast = 2.5, kick = true, what = "some", n = 1, dmg = { 800, 1100 } },
      { name = "Polymorph", icon = I .. "Spell_Nature_Polymorph", every = 15, cast = 1.5, kick = true, what = "some", n = 1, dmg = { 0, 0 },
        debuff = { I .. "Spell_Nature_Polymorph", "Magic", 8 } },
      { name = "Frost Nova", icon = I .. "Spell_Frost_FrostNova", every = 12, what = "raid", dmg = { 100, 200 }, debuff = { I .. "Spell_Frost_FrostNova", "Magic", 6 } } } },
    WARRIOR = { 5200, { { name = "Mortal Strike", icon = I .. "Ability_Warrior_SavageBlow", every = 6, what = "some", n = 1, dmg = { 900, 1400 },
      debuff = { I .. "Ability_CriticalStrike", "", 10 } },
      { name = "Hamstring", icon = I .. "Ability_ShockWave", every = 8, what = "some", n = 1, dmg = { 50, 100 }, debuff = { I .. "Ability_ShockWave", "", 15 } } } },
    PRIEST = { 3800, { { name = "Mind Blast", icon = I .. "Spell_Shadow_UnholyFrenzy", every = 6, cast = 1.5, kick = true, what = "some", n = 1, dmg = { 700, 900 } },
      { name = "Psychic Scream", icon = I .. "Spell_Shadow_PsychicScream", every = 20, what = "raid", dmg = { 0, 0 }, debuff = { I .. "Spell_Shadow_PsychicScream", "Magic", 6 },
        say = "Psychic Scream - your group is feared!" } } },
    ROGUE = { 4000, { { name = "Sinister Strike", icon = I .. "Spell_Shadow_RitualOfSacrifice", every = 3, what = "some", n = 1, dmg = { 350, 550 } },
      { name = "Kidney Shot", icon = I .. "Ability_Rogue_KidneyShot", every = 16, what = "some", n = 1, dmg = { 100, 200 }, debuff = { I .. "Ability_Rogue_KidneyShot", "", 5 } } } },
    WARLOCK = { 4300, { { name = "Shadow Bolt", icon = I .. "Spell_Shadow_ShadowBolt", every = 4, cast = 3, kick = true, what = "some", n = 1, dmg = { 900, 1200 } },
      { name = "Fear", icon = I .. "Spell_Shadow_Possession", every = 14, cast = 1.5, kick = true, what = "some", n = 1, dmg = { 0, 0 },
        debuff = { I .. "Spell_Shadow_Possession", "Magic", 8 } },
      { name = "Corruption", icon = I .. "Spell_Shadow_AbominationExplosion", every = 9, what = "some", n = 2, dmg = { 100, 150 },
        debuff = { I .. "Spell_Shadow_AbominationExplosion", "Magic", 18 } } } },
    HUNTER = { 4400, { { name = "Aimed Shot", icon = I .. "INV_Spear_07", every = 7, cast = 3, kick = false, what = "some", n = 1, dmg = { 1100, 1500 } },
      { name = "Viper Sting", icon = I .. "Ability_Hunter_AimedShot", every = 12, what = "some", n = 1, dmg = { 50, 100 },
        debuff = { I .. "Ability_Hunter_AimedShot", "Poison", 8 } } } },
    DRUID = { 4200, { { name = "Wrath", icon = I .. "Spell_Nature_AbolishMagic", every = 4, cast = 2, kick = true, what = "some", n = 1, dmg = { 500, 700 } },
      { name = "Entangling Roots", icon = I .. "Spell_Nature_StrangleVines", every = 13, cast = 1.5, kick = true, what = "some", n = 1, dmg = { 100, 200 },
        debuff = { I .. "Spell_Nature_StrangleVines", "Magic", 10 } } } },
    SHAMAN = { 4500, { { name = "Lightning Bolt", icon = I .. "Spell_Nature_Lightning", every = 4, cast = 2.5, kick = true, what = "some", n = 1, dmg = { 800, 1000 } },
      { name = "Frost Shock", icon = I .. "Spell_Frost_FrostShock", every = 9, what = "some", n = 1, dmg = { 500, 700 }, debuff = { I .. "Spell_Frost_FrostShock", "Magic", 8 } } } },
    PALADIN = { 4800, { { name = "Hammer of Justice", icon = I .. "Spell_Holy_SealOfMight", every = 14, what = "some", n = 1, dmg = { 200, 300 },
      debuff = { I .. "Spell_Holy_SealOfMight", "Magic", 6 } },
      { name = "Judgement", icon = I .. "Spell_Holy_RighteousFury", every = 8, what = "some", n = 1, dmg = { 500, 700 } } } },
  }
  function DM.EnemyDef()
    local mine = _G.UnitFactionGroup and _G.UnitFactionGroup("player") or "Alliance"
    local them = mine == "Horde" and "Alliance" or "Horde"
    local classes = { "MAGE", "WARRIOR", "PRIEST", "ROGUE", "WARLOCK", "HUNTER", "DRUID", them == "Horde" and "SHAMAN" or "PALADIN" }
    local class = Pick(classes)
    local e = DM.ENEMY[class]
    return { name = Pick(DM.ENEMYNAMES), ctype = "Humanoid", level = 60, cls = "normal", max = math.floor(e[1] * Rand(.9, 1.15)),
      melee = { 250, 450 }, abilities = e[2], player = true, class = class, faction = them }
  end
  -- the battleground's own lines (flags), in their chat colours
  DM.BGLINES = {
    { "BG_SYSTEM_HORDE", "The Alliance Flag was picked up by %s!" }, { "BG_SYSTEM_ALLIANCE", "The Horde flag was picked up by %s!" },
    { "BG_SYSTEM_HORDE", "The Alliance Flag was dropped by %s!" }, { "BG_SYSTEM_ALLIANCE", "%s captured the Horde flag!" },
    { "BG_SYSTEM_NEUTRAL", "The Horde flag was returned to its base by %s!" },
  }

  -- the AFK demo: chat while you are away (pfUI's AFK screen shows say / whisper / party / guild)
  DM.AFKCHAT = {
    { "GUILD", "anyone up for ZG tonight?" }, { "WHISPER", "hey, are you selling that cloak?" }, { "PARTY", "brb, getting a drink" },
    { "GUILD", "grats on the epic mount!" }, { "SAY", "nice transmog" }, { "WHISPER", "lfm for strat, need a healer - you in?" },
    { "GUILD", "raid invites in 15 minutes" }, { "OFFICER", "who has the bank key?" }, { "WHISPER", "u there?" },
    { "GUILD", "Onyxia down! well played everyone" }, { "PARTY", "ready when you are" },
  }

  -- the showcase: the raid demo underneath, a caption stepping through what pfUI Octo does, each with its own test
  DM.SHOWTIME = 9
  DM.SHOW = {
    { "Raid frames: pfUI's own raid frames, sized and coloured by your settings." },
    { "Your target: the boss with its crest or dragons, its cast bar and health.", function() end },
    { "OctoRinse: debuffs you can cure, ready to click.", function() local R = pfUI.rinse if R and R.Test then R.Test(DM.SHOWTIME) end end },
    { "Threat: the threat meter and the warning label on your target.", function()
      local TH = pfUI.meters and pfUI.meters.threat if TH and TH.Sample then TH.Sample(DM.SHOWTIME) end end },
    { "Meters: damage and healing - click a bar for its breakdown." },
    { "Combat text: hits, crits, heals and messages where you set them." },
    { "Nameplates: looks, threat colours and casts on every plate.", function() local P = pfUI.plates if P and P.Test then P.Test(DM.SHOWTIME) end end },
    { "Action bars: proc glows, cooldowns and press effects.", function() local AB = pfUI.barsOcto if AB and AB.Test then AB.Test(DM.SHOWTIME) end end },
    { "Swing timer: your swings, the target's and your shots.", function() local ST = pfUI.swing if ST and ST.Test then ST.Test(DM.SHOWTIME) end end },
    { "OctoDoTs: every DoT on every mob, with its timer.", function() local D = pfUI.dots if D and D.Test then D.Test(DM.SHOWTIME) end end },
  }

  local function NewMob(def)
    local b = { name = def.name, ctype = def.ctype, level = def.level, cls = def.cls, max = def.max, hp = def.max,
      def = def, enemy = true, mark = def.mark or 8, debuffs = {}, buffs = {}, next = {} }
    -- (an enemy player: its class, its flag, the other faction)
    if def.player then
      b.player, b.class, b.cl, b.pvp, b.faction, b.mark = true, def.class, DM.LOCAL[def.class] or def.class, true, def.faction, nil
    end
    if def.cc then
      b.cc = true
      b.debuffs = { { tex = I .. "Spell_Nature_Polymorph", type = "Magic", left = 999, count = 1 } }
    end
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
  -- (20 Nov 2026, user: "when it demos an over threat the boss target does not change") you as a pretend unit, from
  -- your real health and power, for the boss's target when it turns to you
  local meData = { isMe = true, player = true, debuffs = {}, buffs = {} }
  function DM.MeData()
    local d = meData
    d.name = _G.UnitName("player")
    d.cl, d.class = _G.UnitClass("player")
    d.hp, d.max = _G.UnitHealth("player") or 1, _G.UnitHealthMax("player") or 1
    d.pw, d.pmax, d.ptype = _G.UnitMana("player") or 0, _G.UnitManaMax("player") or 0, _G.UnitPowerType("player") or 0
    d.level = _G.UnitLevel("player") or 60
    return d
  end
  -- whoever the boss is on: the tank, someone who pulled it off (DM.aggroWho), or you (DM.aggroMe)
  function DM.BossTarget()
    if DM.aggroMe then return DM.MeData() end
    if DM.aggroWho then
      for _, u in ipairs(DM.list or {}) do if u.name == DM.aggroWho and not u.dead then return u end end
    end
    local tk = DM.tank
    if tk and tk.dead then tk = DM.offtank end
    return tk
  end
  local function Fake(u)
    if not DM.on or type(u) ~= "string" then return nil end
    u = string.lower(u)
    local d = DM.units[u]
    if d then return d end
    if u == "target" or u == "playertarget" then return S().target == "1" and DM.boss or nil end
    if u == "targettarget" then return S().target == "1" and DM.boss and DM.BossTarget() or nil end
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
    UnitInRaid = function(d) return (d.player and DM.roster == "raid") and 1 or nil end,
    UnitInParty = function(d) return d.player and 1 or nil end,
    UnitIsPartyLeader = function(d) return d.leader and 1 or nil end,
    UnitAffectingCombat = function(d) return DM.fight and 1 or nil end,
    UnitIsPVP = function(d) return d.pvp and 1 or nil end,
    UnitIsAFK = function(d) return nil end,
    UnitIsFeignDeath = function(d) return nil end,
    UnitIsCharmed = function(d) return nil end,
    UnitIsTapped = function(d) return nil end,
    UnitFactionGroup = function(d) if d.faction then return d.faction, d.faction end if d.player then return _G.UnitFactionGroup("player") end end,
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
      local pa = (fa and (fa.isMe and "me" or fa)) or (type(a) == "string" and (string.lower(a) == "player" or Is1(a)) and "me")
      local pb = (fb and (fb.isMe and "me" or fb)) or (type(b) == "string" and (string.lower(b) == "player" or Is1(b)) and "me")
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
  -- a party of five (dungeon, PvP): no raid
  DM.PARTYROSTER = {
    GetNumRaidMembers = function() return 0 end,
    GetNumPartyMembers = function() return 4 end,
    GetRaidRosterInfo = function() return nil end,
  }

  -- not really in a group: nothing may be said to one (the pretend raid makes pfUI think it is in one)
  function DM.NotGrouped()
    return (_G.GetNumRaidMembers and _G.GetNumRaidMembers() or 0) == 0 and (_G.GetNumPartyMembers and _G.GetNumPartyMembers() or 0) == 0
  end
  DM.GROUPCHAN = { RAID = true, PARTY = true, RAID_WARNING = true, BATTLEGROUND = true }

  -- put the answers into pfUI's environment / take them out again (exactly what was there before);
  -- roster = "raid" (40) | "party" (5) | nil (the target dummy and AFK: only the target or nothing)
  function DM.Install(roster)
    DM.roster = roster
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
    -- (20 Nov 2026) you: your cooldowns, reactive abilities and procs
    if DM.kit then DM.YouInstall(Put) end
    if roster == "party" then
      for name, fn in pairs(DM.PARTYROSTER) do Put(name, fn) end
    elseif roster == "raid" then
      for name, fn in pairs(ROSTER) do Put(name, fn) end
      -- "am I in a raid?" asked of the player
      rawset(env, "UnitInRaid", function(u)
        if type(u) == "string" and string.lower(u) == "player" then return 1 end
        local d = Fake(u)
        if d then return d.player and 1 or nil end
        return DM.orig.UnitInRaid(u)
      end)
    end
    -- (user's first run, 19 Nov 2026) nothing goes out to a raid that is not there: pfUI's threat asks, price
    -- sharing, pull timers... are dropped while you are not really grouped
    Put("SendAddonMessage", function(prefix, text, chan, who)
      if DM.GROUPCHAN[chan or ""] and DM.NotGrouped() then return end
      return DM.orig.SendAddonMessage(prefix, text, chan, who)
    end)
    Put("SendChatMessage", function(msg, chan, lang, who)
      if DM.GROUPCHAN[chan or ""] and DM.NotGrouped() then return end
      -- (the AFK demo: pfUI's AFK screen ends with SendChatMessage("", "AFK") - that would mark you AFK for real)
      if chan == "AFK" and DM.kind == "afk" then return end
      return DM.orig.SendChatMessage(msg, chan, lang, who)
    end)
    -- pfUI's mob health (libhealth) asks the game itself: the boss showed "0 - 93%" on the target frame
    local lh = pfUI.libhealth
    if lh and lh.GetUnitHealth then
      DM.lhGet = lh.GetUnitHealth
      lh.GetUnitHealth = function(self, u)
        local d = Fake(u)
        if d then return math.max(0, math.floor(d.hp)), d.max, true end
        return DM.lhGet(self, u)
      end
    end
    -- the threat meter: never ask the server about a pretend boss; DM.Threat fills it
    local TH = pfUI.meters and pfUI.meters.threat
    if TH and TH.Ask then
      DM.thAsk = TH.Ask
      TH.Ask = function() end
    end
  end
  -- quiet = at PLAYER_LOGOUT: table writes only, no window refresh (it may ask units)
  function DM.Uninstall(quiet)
    local env = pfUI.env
    for name, was in pairs(DM.saved or {}) do rawset(env, name, was[1]) end
    DM.saved, DM.orig = nil, nil
    if DM.lhGet and pfUI.libhealth then pfUI.libhealth.GetUnitHealth = DM.lhGet end
    DM.lhGet = nil
    local TH = pfUI.meters and pfUI.meters.threat
    if TH then TH.demoPredict, TH.demoPending, TH.demoPredictFor = nil, nil, nil end
    -- (the pretend fight's threat history must not run on into a real fight's predictions)
    if TH then TH.samples, TH.hist, TH.others, TH.all = {}, {}, {}, nil end
    DM.dotk = nil
    DM.thEvent, DM.forceWipe, DM.aggroMe, DM.aggroWho, DM.autoNext, DM.autoStep = nil, nil, nil, nil, nil, nil
    if TH and DM.thAsk then
      TH.Ask = DM.thAsk
      TH.list, TH.base = nil, nil
      if not quiet and pfUI.meters.Changed then pcall(pfUI.meters.Changed) end
    end
    DM.thAsk = nil
  end

  -- ---------------------------------------------------------------- threat
  -- a made-up threat list on the boss, the shape the server's answers have (meters-threat.lua TH.list): the main
  -- tank on top, damage dealers below, healers low, you somewhere in between - sometimes close to the tank, so the
  -- warnings and the label show too
  function DM.Threat(dt)
    local M = pfUI.meters
    local TH = M and M.threat
    if not TH then return end
    if DM.kind == "pvp" or DM.kind == "afk" then
      if TH.list then TH.list = nil if M.Changed then pcall(M.Changed) end end
      return
    end
    -- (20 Nov 2026, user: "it should be constantly showing a live threat meter running a cycle that matches the mode
    -- and event we are in") between pulls (kill, wipe, rest) the last fight's list stays on the meter
    if not DM.fight or not DM.boss then
      if TH.list then
        TH.at = GetTime()
        if M.RefreshThreat then pcall(M.RefreshThreat) end
      end
      return
    end
    DM.tt = DM.tt or {}
    DM.trate = DM.trate or {}
    DM.dotk = DM.dotk or {}
    local me = _G.UnitName("player") or "You"
    local list = {}
    if DM.kind == "dummy" then
      DM.tt[me] = (DM.tt[me] or 0) + dt * Rand(500, 900)
      list = { { name = me, tank = true, threat = math.floor(DM.tt[me]), perc = 100, melee = true } }
    else
      -- every raider's steady pace for this fight (a little noise each step, no jumps)
      for _, u in ipairs(DM.list) do
        if not u.dead then
          local k = DM.trate[u.name]
          if not k then
            k = (u.role == "tank" and (u == DM.tank and 1300 or 650)) or (u.role == "heal" and Rand(90, 200)) or Rand(300, 760)
            DM.trate[u.name] = k
          end
          DM.tt[u.name] = (DM.tt[u.name] or 0) + dt * k * Rand(.9, 1.1)
        end
      end
      -- you: climbing towards the tank now and then
      local push = math.mod(math.floor(DM.pt / 20), 2) == 1 and 1300 or 600
      DM.tt[me] = (DM.tt[me] or 0) + dt * Rand(push * .85, push)
      local holderU = DM.tank and not DM.tank.dead and DM.tank or DM.offtank
      local tankNow = holderU and DM.tt[holderU.name] or 0
      -- (20 Nov 2026) the threat cycle on its own, every 25 s of a fight while no event of yours runs: a DoT player's
      -- DoTs pull them ("DoTs <name> in 4 s", then the boss turns to them), then you overthreat, then a melee player pulls
      -- at their pace (the Next line) - each time the tank taunts it back
      if not DM.thEvent and tankNow > 0 and DM.pt > 8 and DM.t >= (DM.autoNext or 0) then
        DM.autoNext = DM.t + 25
        DM.autoStep = math.mod((DM.autoStep or 0), 3) + 1
        local pickDot, pickMelee
        for _, u in ipairs(DM.list) do
          if not u.dead and u ~= DM.tank and u ~= DM.offtank and u.name ~= me then
            if not pickDot and (u.class == "WARLOCK" or u.class == "PRIEST") then pickDot = u.name end
            if not pickMelee and (u.class == "ROGUE" or u.class == "WARRIOR") and u.role == "dps" then pickMelee = u.name end
          end
        end
        if DM.autoStep == 1 and pickDot then DM.thEvent = { kind = "dotsOther", t = 0, who = pickDot, auto = true }
        elseif DM.autoStep == 2 then DM.thEvent = { kind = "over", t = 0, auto = true }
        elseif pickMelee then DM.thEvent = { kind = "pace", t = 0, who = pickMelee, auto = true } end
      end
      -- (20 Nov 2026) the Overthreat / DoTs pull events (DM.EVENTS): you against the tank's threat, then aggro
      local ev = DM.thEvent
      DM.aggroMe, DM.aggroWho = nil, nil
      if ev and ev.who and tankNow > 0 then
        -- another player: their DoTs (or their pace) carry them past their pull point, the boss turns to them
        ev.t = ev.t + dt
        local caster = ev.kind == "dotsOther"
        local at = tankNow * (caster and 1.3 or 1.1)
        -- their countdown on the meter (the DoTs line or the Next line, and their own seconds)
        TH.demoPredictFor = function(name)
          if name ~= ev.who or ev.turned or not DM.thEvent then return end
          local cur = DM.tt[ev.who] or 0
          return { pending = caster and at * .17 or 0, room = at - cur, aggroIn = math.max(0, 6 - ev.t), stopNow = caster or nil }
        end
        if ev.t < 6 then
          if caster then
            DM.dotk[ev.who] = .22
            DM.tt[ev.who] = at * (.9 + .09 * ev.t / 6)
          else
            DM.dotk[ev.who] = false
            DM.trate[ev.who] = (DM.trate[holderU.name] or 1300) * 1.6
            DM.tt[ev.who] = math.max(DM.tt[ev.who] or 0, at * (.9 + .09 * ev.t / 6))
          end
        else
          if not ev.turned then
            ev.turned, ev.at = true, ev.t
            Warn((DM.boss and DM.boss.name or "The boss") .. " turns to " .. ev.who .. "!")
          end
          DM.tt[ev.who] = at * 1.02
          DM.aggroWho = ev.who
          if ev.t - ev.at > 5 then
            DM.tt[ev.who] = tankNow * .6
            DM.trate[ev.who], DM.dotk[ev.who] = nil, nil
            DM.thEvent, DM.aggroWho = nil, nil
            DM.Chat("SYSTEM", (holderU and holderU.name or "The tank") .. " taunts " .. (DM.boss and DM.boss.name or "the boss") .. " back from " .. ev.who .. ".")
          end
        end
      elseif ev and tankNow > 0 then
        TH.demoPredictFor = nil
        ev.t = ev.t + dt
        local TH0 = TH
        if ev.kind == "dots" and ev.t < 5 then
          -- just past the tank, under the pull point; DoTs on their way do the rest in 5 s
          DM.tt[me] = tankNow * 1.03
          TH0.demoPredict = function()
            local left = math.max(0, 5 - ev.t)
            return { pending = tankNow * .12, room = tankNow * .07, aggroIn = left, stopNow = true }
          end
        else
          TH0.demoPredict = nil
          if ev.kind == "over" and ev.t < 2 then
            DM.tt[me] = tankNow * (.95 + .2 * ev.t / 2)
          else
            -- the boss turns to you for a while, then the tank taunts it back
            if not ev.turned then
              ev.turned, ev.at = true, ev.t
              Warn((DM.boss and DM.boss.name or "The boss") .. " turns to " .. me .. "!")
            end
            DM.tt[me] = tankNow * 1.16
            DM.aggroMe = true
            if ev.t - ev.at > 6 then
              DM.tt[me] = tankNow * .7
              DM.thEvent, DM.aggroMe = nil, nil
              DM.Chat("SYSTEM", (holderU and holderU.name or "The tank") .. " taunts " .. (DM.boss and DM.boss.name or "the boss") .. " back.")
            end
          end
        end
      else
        TH.demoPredict, TH.demoPredictFor = nil, nil
      end
      -- (20 Nov 2026, user: the preview showed DoT lines the real meter never did) the pretend raid's DoT classes and
      -- you (when your class has DoTs) have DoTs ticking on the boss: the threat window's DoTs / Next lines and each
      -- player's countdown come from them, as in a real fight
      DM.dotk = DM.dotk or {}
      TH.demoPending = function(name, now)
        if not DM.on or not DM.fight then return end
        local k = DM.dotk[name]
        if k == nil then
          local cls
          if name == me then cls = DM.kit and DM.kit.dots and table.getn(DM.kit.dots) > 0 and "dots"
          else
            for _, u in ipairs(DM.list or {}) do if u.name == name then cls = u.class end end
          end
          k = (cls == "dots" or cls == "WARLOCK" or cls == "PRIEST" or cls == "DRUID" or cls == "HUNTER") and Rand(.04, .1) or false
          DM.dotk[name] = k
        end
        if not k then return 0, {} end
        local tankT = holderU and DM.tt[holderU.name] or 0
        if tankT <= 0 then return 0, {} end
        local each = tankT * k / 4
        local first = 3 - math.mod(DM.t or 0, 3)
        local steps = {}
        for i = 1, 4 do table.insert(steps, { first + (i - 1) * 3, each }) end
        return each * 4, steps
      end
      -- (casters at range: they pull at 130% of the tank, melee at 110%)
      local RANGED = { MAGE = true, WARLOCK = true, PRIEST = true, HUNTER = true, DRUID = true, SHAMAN = true }
      for name, v in pairs(DM.tt) do
        local dead, melee = false, true
        for _, u in ipairs(DM.list) do
          if u.name == name then
            if u.dead then dead = true end
            if RANGED[u.class or ""] and u.role ~= "tank" then melee = false end
          end
        end
        if name == me then melee = not (DM.kit and not DM.kit.melee) end
        if not dead then table.insert(list, { name = name, tank = false, threat = math.floor(v), perc = 0, melee = melee }) end
      end
      local holder = DM.tank and not DM.tank.dead and DM.tank.name or (DM.offtank and DM.offtank.name)
      if DM.aggroMe then holder = me end
      if DM.aggroWho then holder = DM.aggroWho end
      local tankT = 0
      for _, e in ipairs(list) do if e.name == holder then e.tank = true tankT = e.threat end end
      for _, e in ipairs(list) do
        if e.tank then e.perc = 100 elseif tankT > 0 then e.perc = math.floor(e.threat / tankT * 1000 + .5) / 10 end
      end
      table.sort(list, function(a, b) return a.threat > b.threat end)
    end
    TH.list, TH.at, TH.estimated, TH.base = list, GetTime(), nil, nil
    if TH.Warn then pcall(TH.Warn) end
    if M.RefreshThreat then pcall(M.RefreshThreat) end
    if TH.Draw then pcall(TH.Draw) end
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
      -- (on whoever the boss is on - you after an overthreat: your combat text)
      local tk = DM.BossTarget and DM.BossTarget() or DM.tank
      if tk and tk.isMe then
        DM.CT("inSpell", { amount = math.floor(Rand(a.dmg[1], a.dmg[2])), spell = a.name, school = 0 })
        return
      end
      if tk and tk.dead then tk = DM.offtank end
      if tk and not tk.dead then hits = { tk } else hits = { Pick(alive) } end
    else
      for _ = 1, math.min(a.n or 1, table.getn(alive)) do table.insert(hits, Pick(alive)) end
    end
    for _, u in ipairs(hits) do
      Hurt(u, Rand(a.dmg[1], a.dmg[2]) * (u.role == "tank" and .8 or 1))
      if a.debuff then AddDebuff(u, a.debuff) end
    end
    -- (20 Nov 2026) what hits the whole group hits you too: in your combat text
    if a.what == "raid" and a.dmg[2] > 0 then DM.CT("inSpell", { amount = math.floor(Rand(a.dmg[1], a.dmg[2])), spell = a.name, school = 2 }) end
  end
  DM.Use = Use
  -- a message through your combat text (its own event, so your colours, areas and filters decide)
  function DM.CT(kind, data)
    local CT = S().ctext == "1" and pfUI.sct and pfUI.sct.CT
    local EV = CT and CT.EV
    if EV and EV.Fire then pcall(EV.Fire, EV, kind, data) end
  end

  -- chat lines of the demo: in the chat frame's own colours (nothing is sent, nothing is logged)
  function DM.Chat(kind, text)
    local i = _G.ChatTypeInfo and _G.ChatTypeInfo[kind]
    local f = _G.DEFAULT_CHAT_FRAME
    if f and f.AddMessage then f:AddMessage(text, i and i.r or 1, i and i.g or 1, i and i.b or 1) end
  end

  -- how long a fight lasts with the whole group alive (seconds); fewer damage dealers = longer
  function DM.KillTime()
    local k, ph = DM.kind, DM.phase
    if k == "dungeon" then return ph == "boss" and 45 or 9 end
    if k == "pvp" then return 12 end
    return ph == "trash" and 14 or 70
  end
  local function CountDps()
    local n = 0
    for _, u in ipairs(DM.list or {}) do if not u.dead and u.role == "dps" then n = n + 1 end end
    return n
  end

  -- the next mob of a dungeon pack to kill: marked order, the sheeped one last
  local function NextInPack()
    local best
    for _, m in ipairs(DM.pack or {}) do
      if not m.dead and (not best or (best.cc and not m.cc)) then best = m end
    end
    if best and best.cc then best.cc, best.debuffs = nil, {} end
    return best
  end

  function DM.SetPhase(ph)
    local was = DM.phase
    DM.phase, DM.pt = ph, 0
    if ph == "trash" or ph == "boss" then DM.tt, DM.lastFight, DM.dotk, DM.trate = {}, ph, {}, {} end
    if ph == "dummy" then
      DM.rank = math.mod(DM.rank or 0, table.getn(DM.DUMMIES)) + 1
      DM.boss = NewMob(DM.DUMMIES[DM.rank])
      DM.boss.mark = nil
      DM.fight = true
      DM.tt = {}
    elseif ph == "afk" then
      DM.boss, DM.fight = nil, false
      local cam = _G.pfAFKCam
      DM.afkUsesOwn = not (cam and cam.start)
      if DM.afkUsesOwn then DM.OwnAfk(true)
      else
        pcall(cam.start, cam)
        local ov = cam.overlay
        if ov and not DM.afkNote then
          DM.afkNote = ov:CreateFontString(nil, "OVERLAY")
          DM.afkNote:SetFont(pfUI.font_default or STANDARD_TEXT_FONT, 14, "OUTLINE")
          DM.afkNote:SetPoint("TOP", ov, "TOP", 0, -52)
          DM.afkNote:SetText("|cff33ccffpfUI Octo demo|r - click or press any key to end it")
        end
        if DM.afkNote then DM.afkNote:Show() end
      end
      DM.chatAt = 1
    elseif ph == "trash" then
      DM.fight = true
      if DM.kind == "dungeon" then
        DM.packIndex = math.mod(DM.packIndex or 0, table.getn(DM.PACKS)) + 1
        DM.pack = {}
        for _, def in ipairs(DM.PACKS[DM.packIndex]) do table.insert(DM.pack, NewMob(def)) end
        DM.boss = NextInPack()
        Warn("Pulling: skull first - moon stays sheeped")
      elseif DM.kind == "pvp" then
        DM.pack = nil
        DM.boss = NewMob(DM.EnemyDef())
        DM.Chat("BG_SYSTEM_NEUTRAL", DM.boss.name .. " (" .. (DM.boss.cl or "") .. ") attacks your group!")
      else
        DM.pack = nil
        DM.boss = NewMob(DM.TRASH)
        Warn("Pull in 3... 2... 1...")
      end
    elseif ph == "boss" then
      DM.pack = nil
      DM.fight = true
      if DM.kind == "dungeon" then
        DM.dbossIndex = math.mod(DM.dbossIndex or 0, table.getn(DM.DBOSSES)) + 1
        DM.boss = NewMob(DM.DBOSSES[DM.dbossIndex])
        DM.willWipe = false
      else
        -- (after a wipe the same boss again, as a raid would)
        if not DM.retry then DM.bossIndex = math.mod(DM.bossIndex or 0, table.getn(DM.BOSSES)) + 1 end
        DM.boss = NewMob(DM.BOSSES[DM.bossIndex])
        DM.pulls = (DM.pulls or 0) + 1
        local every = tonumber(S().wipes) or 0
        DM.willWipe = every > 0 and math.mod(DM.pulls, every) == 0
      end
      DM.retry, DM.trashDone = nil, nil
      Warn(DM.boss.name .. " engaged!")
      DM.Joins(true)
    elseif ph == "ended" then
      DM.fight = false
      DM.forceWipe, DM.thEvent = nil, nil
      local b = DM.boss
      if b then b.cast = nil end
      if DM.wiped then
        DM.retry, DM.trashDone = true, true
        Warn("Wipe! Run back and rebuff.")
      elseif DM.kind == "pvp" and b then
        Warn("Killing blow: " .. b.name .. "!")
        DM.Chat("COMBAT_HONOR_GAIN", b.name .. " dies, honorable kill Rank: Knight (Estimated Honor Points: " .. math.random(120, 199) .. ")")
      elseif DM.kind == "dungeon" and was == "trash" then
        DM.packsDone = (DM.packsDone or 0) + 1
      elseif b then
        Warn(b.name .. " is defeated!")
      end
    elseif ph == "rest" then
      DM.fight = false
      DM.boss, DM.pack = nil, nil
      -- (20 Nov 2026, user: "when i use wipe event it should then do resses one at a time starting with ressers first
      -- so we can track the res icons") the living are healed up; the dead get up one res at a time (DM.ResStep)
      local anyDead
      for _, u in ipairs(DM.list) do
        if u.dead then anyDead = true
        else
          u.hp, u.debuffs, u.cast = u.max, {}, nil
          if u.ptype ~= 1 then u.pw = u.pmax else u.pw = 0 end
        end
      end
      if anyDead and DM.kind ~= "pvp" then DM.StartRes() end
      DM.wiped = nil
    end
    DM.dpsFull = CountDps()
    DM.dirty, DM.adirty = true, true
    DM.Touch(true)
    if DM.onPhase then pcall(DM.onPhase, ph) end
  end

  -- what comes after a fight ended / a rest
  function DM.AfterEnded()
    local k = DM.kind
    if k == "pvp" then return "trash" end
    if k == "dungeon" then
      if DM.lastFight == "boss" then return "rest" end
      if (DM.packsDone or 0) >= table.getn(DM.PACKS) then return "boss" end
      return "trash"
    end
    return "rest"
  end
  function DM.AfterRest()
    if DM.kind == "dungeon" then DM.packsDone = 0 return "trash" end
    return DM.trashDone and "boss" or "trash"
  end

  -- the AFK demo: chat lines on the AFK screen; the screen closing ends the demo
  local function AfkStep(dt)
    local cam = _G.pfAFKCam
    local up = DM.afkUsesOwn and DM.afkOwn and DM.afkOwn:IsShown() or (not DM.afkUsesOwn and cam and cam._spinning)
    if DM.pt > 1 and not up then DM.Stop() return end
    DM.chatAt = (DM.chatAt or 0) - dt
    if DM.chatAt > 0 then return end
    DM.chatAt = Rand(3, 6)
    local c = Pick(DM.AFKCHAT)
    local who = Pick(DM.NAMES)
    local chat = DM.afkUsesOwn and DM.afkOwn and DM.afkOwn.chat or (cam and cam.overlay and cam.overlay.chat)
    local i = _G.ChatTypeInfo and _G.ChatTypeInfo[c[1]]
    local tag = ({ GUILD = "[Guild] ", OFFICER = "[Officer] ", PARTY = "[Party] ", WHISPER = "", SAY = "" })[c[1]] or ""
    local line = tag .. who .. (c[1] == "WHISPER" and " whispers" or (c[1] == "SAY" and " says" or "")) .. ": " .. c[2]
    if chat and chat.AddMessage then chat:AddMessage(line, i and i.r or 1, i and i.g or 1, i and i.b or 1, 1) end
  end

  -- one step of the pretend fight, dt seconds of demo time
  function DM.Step(dt)
    DM.t = DM.t + dt
    DM.pt = DM.pt + dt
    local ph = DM.phase
    if DM.kind == "showcase" then
      DM.showT = (DM.showT or 0) + dt
      if DM.showT >= DM.SHOWTIME then DM.ShowNext() end
    end
    if ph == "afk" then AfkStep(dt) return end
    if ph == "dummy" then
      local b = DM.boss
      if b then
        b.hp = b.hp - dt * b.max / 40 * Rand(.6, 1.4)
        if b.hp < b.max * .05 then b.hp = b.max end
        DM.dirty = true
      end
      DM.YouStep(dt)
      if DM.pt >= DM.RANKTIME then DM.SetPhase("dummy") end
      return
    end
    -- PvP: the dead come back from the graveyard; the battleground's flag lines now and then
    if DM.kind == "pvp" then
      for _, u in ipairs(DM.list) do
        if u.dead then
          u.deadT = (u.deadT or 0) + dt
          if u.deadT > 12 then u.dead, u.hp, u.debuffs, u.deadT, DM.dirty = nil, u.max, {}, nil, true end
        end
      end
      DM.bgAt = (DM.bgAt or 8) - dt
      if DM.bgAt <= 0 then
        DM.bgAt = Rand(18, 30)
        local l = Pick(DM.BGLINES)
        DM.Chat(l[1], string.format(l[2], math.random() < .5 and Pick(DM.ENEMYNAMES) or Pick(DM.list).name))
      end
    end
    if DM.resq and not DM.forceWipe then DM.ResStep(dt) end
    if ph == "rest" then
      -- (the next pull waits for everyone to be up)
      if DM.pt >= DM.PHASES.rest and not DM.resq then DM.SetPhase(DM.AfterRest()) end
      return
    end
    if ph == "ended" then
      local hold = 3
      if DM.kind == "raid" or DM.kind == "showcase" then hold = DM.PHASES.ended end
      if DM.pt >= hold then DM.SetPhase(DM.AfterEnded()) end
      return
    end
    local b = DM.boss
    if not b then return end
    -- the boss: melee on the tank (and the rest of a pack too), its abilities on their timers, its cast bar
    local function Swing(m)
      m.swing = m.swing - dt
      if m.swing <= 0 then
        m.swing = 2
        -- (the boss hits whoever it is on - you too, after an overthreat: in your combat text)
        local tk = (m == DM.boss) and DM.BossTarget() or DM.tank
        if tk and tk.dead then tk = DM.offtank end
        if DM.kind == "pvp" then tk = Pick(Alive()) end
        local hit = Rand(m.def.melee[1], m.def.melee[2]) * ((m.enrageUntil and DM.t < m.enrageUntil) and 2 or 1)
        if tk and tk.isMe then DM.CT("inMelee", { amount = math.floor(hit) })
        elseif tk then Hurt(tk, hit) end
      end
    end
    Swing(b)
    for _, m in ipairs(DM.pack or {}) do
      if m ~= b and not m.dead and not m.cc then Swing(m) end
    end
    if b.cast then
      -- (dungeon / PvP: most casts get kicked a moment after they start)
      local a = b.cast.a
      if a.kick and not b.cast.tried and GetTime() - b.cast.start > .6 / DM.speed then
        b.cast.tried = true
        if math.random() < .6 and DM.kind ~= "raid" and DM.kind ~= "showcase" then
          local kicker = DM.offtank and not DM.offtank.dead and DM.offtank.name or "Your group"
          DM.Chat("PARTY", kicker .. " interrupts " .. b.name .. "'s " .. a.name .. ".")
          b.cast = nil
          DM.Touch(false)
        end
      end
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
    -- you: your rotation, cooldowns, procs
    DM.YouStep(dt)
    -- the group: healers heal the lowest, damage dealers drain the mob, mana goes down
    local alive = Alive()
    local dps = 0
    for _, u in ipairs(alive) do
      if u.role == "dps" then dps = dps + 1 end
      if u.ptype == 1 then u.pw = math.min(100, (u.pw or 0) + dt * 6)
      elseif u.ptype == 3 then u.pw = math.max(0, math.min(100, (u.pw or 0) + dt * 10 - (math.random() < .3 and 20 or 0)))
      elseif u.role ~= "heal" then u.pw = math.max(0, (u.pw or 0) - dt * 25) end
    end
    DM.healAcc = (DM.healAcc or 0) + dt
    while DM.healAcc >= .5 do
      DM.healAcc = DM.healAcc - .5
      for _, h in ipairs(alive) do
        if h.role == "heal" and (h.pw or 0) > 200 and not (DM.willWipe and DM.pt > 40) and not DM.forceWipe then
          local low, worst = nil, 1
          for _, u in ipairs(alive) do
            local f = u.hp / u.max
            if not u.dead and f < worst then low, worst = u, f end
          end
          if low and worst < .95 then
            low.hp = math.min(low.max, low.hp + Rand(900, 1800))
            h.pw = h.pw - Rand(120, 260)
          end
          -- (now and then a heal lands on you, by that healer's own spell)
          if math.random() < .05 then
            DM.CT("inHeal", { amount = math.floor(Rand(600, 2200)), spell = DM.HEALSPELL[h.class] or "Heal", healer = h.name,
              heal = true, crit = math.random(1, 6) == 1 })
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
    if DM.forceWipe or (DM.willWipe and DM.phase == "boss" and DM.pt > 40) then
      for _ = 1, 3 do
        local u = Pick(alive)
        if u then Hurt(u, u.max * .6) end
      end
      -- (everyone down: the wipe is over - in PvP too, where a dead group does not end the fight by itself)
      if DM.forceWipe and table.getn(Alive()) == 0 then
        DM.forceWipe = nil
        if DM.kind == "pvp" then
          DM.wiped = true
          DM.SetPhase("ended")
          return
        end
      end
    end
    b.hp = b.hp - dt * b.max / DM.KillTime() * Rand(.8, 1.2) * (dps + 1) / ((DM.dpsFull or dps) + 1)
    if b.hp <= 0 then
      b.hp, b.dead = 0, true
      -- (a dungeon pack: the next mob, until the pack is down)
      local nxt = DM.pack and NextInPack()
      if nxt then
        DM.boss = nxt
        DM.Touch(true)
        return
      end
      if ph == "trash" then DM.trashDone = true end
      DM.SetPhase("ended")
      return
    end
    if table.getn(Alive()) == 0 and DM.kind ~= "pvp" then
      DM.wiped = true
      DM.SetPhase("ended")
    end
  end

  -- ---------------------------------------------------------------- you, your class
  -- (20 Nov 2026, user: "make sure the demo uses spells that are to your class also the procs etc you have set up
  -- everything should work as a direct test to you") A kit per class: hits { name, icon, school, cooldown },
  -- dots / debuffs { name, icon, seconds, stacks }, heals, procs { name, icon, seconds }, reactive (spell names).
  -- Icons from your own spellbook when you know the spell; spells you know first. In every fight you "cast": your
  -- spells and crits in combat text, your DoTs / debuffs on the pretend boss (target frame, OctoDoTs), the cooldown and
  -- the global cooldown on your action bars and CoolDownManager (GetSpellCooldown / GetActionCooldown answered in
  -- pfUI's environment), your procs as buffs on you (UnitBuff("player") - the action bar proc glows) and reactive
  -- abilities usable (IsUsableAction - the reactive glows), with your own glow list (C.bars.glow_names) among them.
  DM.KITS = {
    WARRIOR = { melee = true, power = "Rage",
      hits = { { "Mortal Strike", "Ability_Warrior_SavageBlow", 0, 6 }, { "Bloodthirst", "Spell_Nature_BloodLust", 0, 6 },
        { "Whirlwind", "Ability_Whirlwind", 0, 10 }, { "Shield Slam", "INV_Shield_05", 0, 6 }, { "Overpower", "Ability_MeleeDamage", 0, 5 },
        { "Revenge", "Ability_Warrior_Revenge", 0, 5 }, { "Execute", "INV_Sword_48", 0 }, { "Heroic Strike", "Ability_Rogue_Ambush", 0 },
        { "Cleave", "Ability_Warrior_Cleave", 0 } },
      dots = { { "Rend", "Ability_Gouge", 21 }, { "Deep Wounds", "Ability_BackStab", 12 } },
      debuffs = { { "Sunder Armor", "Ability_Warrior_Sunder", 30, 5 }, { "Demoralizing Shout", "Ability_Warrior_WarCry", 30 },
        { "Thunder Clap", "Spell_Nature_ThunderClap", 26 } },
      procs = { { "Enrage", "Spell_Shadow_UnholyFrenzy", 12 }, { "Flurry", "Ability_GhoulFrenzy", 15 } },
      reactive = { "Overpower", "Revenge", "Execute" } },
    ROGUE = { melee = true, power = "Energy",
      hits = { { "Sinister Strike", "Spell_Shadow_RitualOfSacrifice", 0 }, { "Backstab", "Ability_BackStab", 0 },
        { "Eviscerate", "Ability_Rogue_Eviscerate", 0 }, { "Hemorrhage", "Spell_Shadow_LifeDrain", 0 }, { "Riposte", "Ability_Warrior_Challange", 0, 6 } },
      dots = { { "Rupture", "Ability_Rogue_Rupture", 16 }, { "Garrote", "Ability_Rogue_Garrote", 18 } },
      debuffs = { { "Expose Armor", "Ability_Warrior_Riposte", 30 }, { "Wound Poison", "INV_Misc_Herb_16", 15, 5 } },
      procs = { { "Slice and Dice", "Ability_Rogue_SliceDice", 21 }, { "Adrenaline Rush", "Spell_Shadow_ShadowWordDominate", 15 } },
      reactive = { "Riposte" } },
    MAGE = { power = "Mana",
      hits = { { "Fireball", "Spell_Fire_FlameBolt", 2 }, { "Frostbolt", "Spell_Frost_FrostBolt02", 4 }, { "Arcane Missiles", "Spell_Nature_StarFall", 6 },
        { "Fire Blast", "Spell_Fire_Fireball", 2, 8 }, { "Scorch", "Spell_Fire_SoulBurn", 2 }, { "Cone of Cold", "Spell_Frost_Glacier", 4, 10 } },
      dots = { { "Ignite", "Spell_Fire_Incinerate", 4 } },
      debuffs = { { "Fire Vulnerability", "Spell_Fire_SoulBurn", 30, 5 }, { "Winter's Chill", "Spell_Frost_ChillingBlast", 15, 5 } },
      procs = { { "Clearcasting", "Spell_Shadow_ManaBurn", 15 } }, reactive = {} },
    WARLOCK = { power = "Mana",
      hits = { { "Shadow Bolt", "Spell_Shadow_ShadowBolt", 5 }, { "Searing Pain", "Spell_Fire_SoulBurn", 2 }, { "Conflagrate", "Spell_Fire_Fireball", 2, 10 },
        { "Soul Fire", "Spell_Fire_Fireball02", 2 } },
      dots = { { "Corruption", "Spell_Shadow_AbominationExplosion", 18 }, { "Curse of Agony", "Spell_Shadow_CurseOfSargeras", 24 },
        { "Immolate", "Spell_Fire_Immolation", 15 }, { "Siphon Life", "Spell_Shadow_Requiem", 30 } },
      debuffs = { { "Curse of the Elements", "Spell_Shadow_ChillTouch", 300 }, { "Shadow Vulnerability", "Spell_Shadow_BlackPlague", 12, 5 } },
      procs = { { "Shadow Trance", "Spell_Shadow_Twilight", 10 } }, reactive = {} },
    PRIEST = { power = "Mana",
      hits = { { "Mind Blast", "Spell_Shadow_UnholyFrenzy", 5, 8 }, { "Mind Flay", "Spell_Shadow_SiphonMana", 5 }, { "Smite", "Spell_Holy_HolySmite", 1 },
        { "Holy Fire", "Spell_Holy_SearingLight", 1 } },
      dots = { { "Shadow Word: Pain", "Spell_Shadow_ShadowWordPain", 18 }, { "Devouring Plague", "Spell_Shadow_BlackPlague", 24 },
        { "Vampiric Embrace", "Spell_Shadow_UnsummonBuilding", 60 } },
      debuffs = { { "Shadow Weaving", "Spell_Shadow_BlackPlague", 15, 5 } },
      heals = { { "Flash Heal", "Spell_Holy_FlashHeal" }, { "Greater Heal", "Spell_Holy_GreaterHeal" }, { "Renew", "Spell_Holy_Renew" },
        { "Prayer of Healing", "Spell_Holy_PrayerOfHealing02" } },
      procs = { { "Inner Focus", "Spell_Frost_WindWalkOn", 15 }, { "Spirit Tap", "Spell_Shadow_Requiem", 15 } }, reactive = {} },
    DRUID = { power = "Mana",
      hits = { { "Wrath", "Spell_Nature_AbolishMagic", 3 }, { "Starfire", "Spell_Arcane_StarFire", 6 }, { "Shred", "Spell_Shadow_VampiricAura", 0 },
        { "Claw", "Ability_Druid_Rake", 0 }, { "Ferocious Bite", "Ability_Druid_FerociousBite", 0 }, { "Maul", "Ability_Druid_Maul", 0 } },
      dots = { { "Moonfire", "Spell_Nature_StarFall", 12 }, { "Insect Swarm", "Spell_Nature_InsectSwarm", 12 }, { "Rake", "Ability_Druid_Disembowel", 9 },
        { "Rip", "Ability_GhoulFrenzy", 12 } },
      debuffs = { { "Faerie Fire", "Spell_Nature_FaerieFire", 40 } },
      heals = { { "Healing Touch", "Spell_Nature_HealingTouch" }, { "Regrowth", "Spell_Nature_ResistNature" }, { "Rejuvenation", "Spell_Nature_Rejuvenation" } },
      procs = { { "Clearcasting", "Spell_Shadow_ManaBurn", 15 } }, reactive = {} },
    HUNTER = { power = "Mana",
      hits = { { "Aimed Shot", "INV_Spear_07", 0, 6 }, { "Multi-Shot", "Ability_UpgradeMoonGlaive", 0, 10 }, { "Arcane Shot", "Ability_ImpalingBolt", 6, 6 },
        { "Auto Shot", "Ability_Whirlwind", 0 }, { "Raptor Strike", "Ability_MeleeDamage", 0, 6 }, { "Mongoose Bite", "Ability_Hunter_SwiftStrike", 0, 5 } },
      dots = { { "Serpent Sting", "Ability_Hunter_Quickshot", 15 } },
      debuffs = { { "Hunter's Mark", "Ability_Hunter_SniperShot", 120 } },
      procs = { { "Quick Shots", "Ability_Warrior_InnerRage", 12 }, { "Rapid Fire", "Ability_Hunter_RunningShot", 15 } },
      reactive = { "Mongoose Bite", "Counterattack" } },
    PALADIN = { melee = true, power = "Mana",
      hits = { { "Judgement", "Spell_Holy_RighteousFury", 1, 10 }, { "Seal of Command", "Ability_Warrior_InnerRage", 1 },
        { "Holy Shock", "Spell_Holy_SearingLight", 1, 30 }, { "Exorcism", "Spell_Holy_Excorcism_02", 1, 15 }, { "Hammer of Wrath", "Ability_ThunderClap", 1, 6 } },
      dots = { { "Consecration", "Spell_Holy_InnerFire", 8 } },
      debuffs = { { "Judgement of the Crusader", "Spell_Holy_HolySmite", 10 }, { "Judgement of Wisdom", "Spell_Holy_RighteousnessAura", 10 } },
      heals = { { "Holy Light", "Spell_Holy_HolyBolt" }, { "Flash of Light", "Spell_Holy_FlashHeal" } },
      procs = { { "Vengeance", "Ability_Racial_Avatar", 8 } }, reactive = { "Hammer of Wrath" } },
    SHAMAN = { power = "Mana",
      hits = { { "Lightning Bolt", "Spell_Nature_Lightning", 3 }, { "Chain Lightning", "Spell_Nature_ChainLightning", 3, 6 },
        { "Earth Shock", "Spell_Nature_EarthShock", 3, 6 }, { "Frost Shock", "Spell_Frost_FrostShock", 4, 6 }, { "Stormstrike", "Spell_Holy_SealOfMight", 0, 20 } },
      dots = { { "Flame Shock", "Spell_Fire_FlameShock", 12 } },
      debuffs = { { "Stormstrike", "Spell_Holy_SealOfMight", 12 } },
      heals = { { "Healing Wave", "Spell_Nature_MagicImmunity" }, { "Lesser Healing Wave", "Spell_Nature_HealingWaveLesser" },
        { "Chain Heal", "Spell_Nature_HealingWaveGreater" } },
      procs = { { "Clearcasting", "Spell_Shadow_ManaBurn", 15 }, { "Flurry", "Ability_GhoulFrenzy", 15 } }, reactive = {} },
  }
  DM.GCD = 1.5
  DM.HEALSPELL = { PRIEST = "Flash Heal", DRUID = "Healing Touch", PALADIN = "Holy Light", SHAMAN = "Healing Wave" }
  local ICONS = "Interface\\Icons\\"
  local function Base(tex)
    if type(tex) ~= "string" then return nil end
    local _, _, b = string.find(tex, "([^\\]+)$")
    return b and string.lower(b)
  end

  -- your kit: the class's lists with your spellbook's icons, the spells you know first
  function DM.MakeKit()
    local _, class = _G.UnitClass("player")
    local src = DM.KITS[class or ""] or DM.KITS.WARRIOR
    local book = {}
    if _G.GetSpellName then
      for i = 1, 300 do
        local name = _G.GetSpellName(i, "spell")
        if not name then break end
        local tex = _G.GetSpellTexture and _G.GetSpellTexture(i, "spell")
        book[name] = { index = i, tex = tex }
      end
    end
    local kit = { class = class, melee = src.melee, power = src.power, byTex = {}, known = 0 }
    local function List(from, kind)
      local mine, other = {}, {}
      for _, e in ipairs(from or {}) do
        local b = book[e[1]]
        local x = { name = e[1], icon = (b and b.tex) or (ICONS .. e[2]), school = (kind == "hits" and e[3]) or nil,
          cd = (kind == "hits" and e[4]) or nil, dur = (kind ~= "hits" and e[3]) or nil, stacks = (kind ~= "hits" and e[4]) or nil, known = b and true }
        if b then table.insert(mine, x) kit.known = kit.known + 1 else table.insert(other, x) end
        kit.byTex[Base(x.icon) or ""] = x.name
      end
      -- spells you know; the class's own when you know none of them (a low level character)
      if table.getn(mine) > 0 then return mine end
      return other
    end
    kit.hits, kit.dots, kit.debuffs = List(src.hits, "hits"), List(src.dots, "dots"), List(src.debuffs, "debuffs")
    kit.heals, kit.procs = List(src.heals, "heals"), List(src.procs, "procs")
    kit.reactive = {}
    for _, n in ipairs(src.reactive or {}) do kit.reactive[string.lower(n)] = true end
    -- your own proc glow list (Action Bars > Buttons: glow names)
    for n in string.gfind((C.bars and C.bars.glow_names) or "", "[^,]+") do
      n = string.gsub(string.gsub(n, "^%s+", ""), "%s+$", "")
      if n ~= "" then kit.reactive[string.lower(n)] = true end
    end
    DM.kit = kit
    DM.cds, DM.procs, DM.react, DM.gcd = {}, {}, {}, nil
    DM.slots = nil   -- your bars read again at the first cast
    DM.nextCast, DM.nextProc, DM.nextReact, DM.nextSwing, DM.nextTick = .5, 6, 10, 1, 3
    return kit
  end

  -- what the game's cooldown / usable / buff calls answer for you while a demo runs
  local function SpellCD(name)
    local now = GetTime()
    local c = name and DM.cds[name]
    if c and now < c.start + c.dur then return c.start, c.dur, 1 end
    local g = DM.gcd
    if g and now < g + DM.GCD / DM.speed then return g, DM.GCD / DM.speed, 1 end
  end
  DM.SpellCD = SpellCD
  local function ActionName(slot)
    local tex = _G.GetActionTexture and _G.GetActionTexture(slot)
    return tex and DM.kit and DM.kit.byTex[Base(tex) or ""]
  end
  DM.ActionName = ActionName
  function DM.YouInstall(Put)
    local env = pfUI.env
    Put("GetSpellCooldown", function(i, book)
      if DM.kit and book == "spell" and _G.GetSpellName then
        local s, d, e = SpellCD((_G.GetSpellName(i, book)))
        if s then return s, d, e end
      end
      return DM.orig.GetSpellCooldown(i, book)
    end)
    Put("GetActionCooldown", function(slot)
      -- (20 Nov 2026, user: "all spells on action bars should rotate as they were being used") the slot the demo
      -- just used, then the global cooldown on every slot with something on it
      local c = DM.slotcd and DM.slotcd[slot]
      local now = GetTime()
      if c and now < c.start + c.dur then return c.start, c.dur, 1 end
      local name = DM.kit and ActionName(slot)
      if name then
        local s, d, e = SpellCD(name)
        if s then return s, d, e end
      end
      if DM.kit and DM.gcd and DM.slotset and DM.slotset[slot] and now < DM.gcd + DM.GCD / DM.speed then
        return DM.gcd, DM.GCD / DM.speed, 1
      end
      return DM.orig.GetActionCooldown(slot)
    end)
    -- your trinkets go on cooldown in turn too (gear slot bar, trinket bar, character window)
    Put("GetInventoryItemCooldown", function(unit, slot)
      local c = DM.invcd and type(unit) == "string" and string.lower(unit) == "player" and DM.invcd[slot]
      if c and GetTime() < c.start + c.dur then return c.start, c.dur, 1 end
      return DM.orig.GetInventoryItemCooldown(unit, slot)
    end)
    Put("IsUsableAction", function(slot)
      local name = DM.kit and ActionName(slot)
      local r = name and DM.react[string.lower(name)]
      if r and GetTime() < r then return 1, nil end
      return DM.orig.IsUsableAction(slot)
    end)
    -- your procs after your real buffs (UnitBuff is wrapped for pretend units already: this one also knows "player")
    local inner = rawget(env, "UnitBuff")
    rawset(env, "UnitBuff", function(u, i)
      if type(u) == "string" and string.lower(u) == "player" and DM.kit then
        local tex, cnt = DM.orig.UnitBuff(u, i)
        if tex then return tex, cnt end
        local n = 0
        while DM.orig.UnitBuff(u, n + 1) do n = n + 1 if n > 40 then break end end
        local k, now = 0, GetTime()
        for _, p in ipairs(DM.kit.procs) do
          local e = DM.procs[p.name]
          if e and now < e then
            k = k + 1
            if n + k == i then return p.icon, 1 end
          end
        end
        return nil
      end
      return inner(u, i)
    end)
  end

  -- pfUI's action bars redraw cooldowns / usable / auras only when the game says so: the pretend casts say it to them
  -- (their own event handler, the way the game would; event / arg1 put back after)
  function DM.Poke(ev)
    local bars = pfUI.bars
    local fn = bars and bars.GetScript and bars:GetScript("OnEvent")
    if not fn then return end
    local e, t, a = _G.event, _G.this, _G.arg1
    _G.event, _G.this, _G.arg1 = ev, bars, nil
    pcall(fn)
    _G.event, _G.this, _G.arg1 = e, t, a
  end

  -- every action slot with something on it (1-120), read once at the start of a demo
  function DM.ReadSlots()
    DM.slots, DM.slotset, DM.slotcd, DM.invcd, DM.slotAt, DM.trinketN = {}, {}, {}, {}, 0, 0
    local has = DM.orig and DM.orig.HasAction or _G.HasAction
    for slot = 1, 120 do
      local good, on = pcall(has or function() end, slot)
      if good and on then
        table.insert(DM.slots, slot)
        DM.slotset[slot] = true
      end
    end
    return table.getn(DM.slots)
  end
  function DM.UseNextSlot(now)
    if not DM.slots then DM.ReadSlots() end
    local n = table.getn(DM.slots)
    if n > 0 then
      -- the next slot that is not on its own cooldown already
      for _ = 1, n do
        DM.slotAt = math.mod(DM.slotAt or 0, n) + 1
        local slot = DM.slots[DM.slotAt]
        local c = DM.slotcd[slot]
        if not c or now >= c.start + c.dur then
          DM.slotcd[slot] = { start = now, dur = Rand(8, 45) / DM.speed }
          DM.lastSlot = slot
          break
        end
      end
    end
    -- a trinket every 6th cast, the two in turn (2 min)
    DM.trinketN = (DM.trinketN or 0) + 1
    if math.mod(DM.trinketN, 6) == 0 then
      local inv = math.mod(math.floor(DM.trinketN / 6), 2) == 0 and 13 or 14
      local c = DM.invcd[inv]
      if not c or now >= c.start + c.dur then DM.invcd[inv] = { start = now, dur = 120 / DM.speed } end
      DM.Poke("BAG_UPDATE_COOLDOWN")
    end
  end

  -- one step of you: the global cooldown, your next spell, your DoT ticks and swings, procs and reactive windows
  function DM.YouStep(dt)
    local kit, b = DM.kit, DM.boss
    if not kit or not b or not DM.fight then return end
    local CT = S().ctext == "1" and pfUI.sct and pfUI.sct.CT
    local EV = CT and CT.EV
    local function Fire(kind, data) if EV and EV.Fire then pcall(EV.Fire, EV, kind, data) end end
    local now = GetTime()
    -- your melee swings (warriors, rogues, paladins)
    if kit.melee then
      DM.nextSwing = DM.nextSwing - dt
      if DM.nextSwing <= 0 then
        DM.nextSwing = 2.4
        local roll = math.random(1, 10)
        if roll == 1 then Fire("outMiss", { kind = "Dodge", plateKind = "miss" })
        else Fire("outMelee", { amount = math.random(250, 700), crit = roll <= 3 }) end
      end
    end
    -- your DoTs tick
    DM.nextTick = DM.nextTick - dt
    if DM.nextTick <= 0 then
      DM.nextTick = 3
      for _, e in ipairs(b.debuffs) do
        if e.mine and e.dot then Fire("outDot", { amount = math.random(90, 340), spell = e.name, school = 5 }) end
      end
    end
    -- the next spell, once the global cooldown is over
    DM.nextCast = DM.nextCast - dt
    if DM.nextCast <= 0 then
      DM.nextCast = DM.GCD
      DM.gcd = now
      DM.pokeCD = true
      -- (20 Nov 2026, user: "all spells on action bars should rotate as they were being used ... trinkets anything")
      -- the next slot on your bars is "used": its own cooldown sweep (8 - 45 s), every slot the global cooldown;
      -- every few casts a trinket
      DM.UseNextSlot(now)
      local pick, dot
      -- a DoT or debuff that is missing or nearly gone first, then a hit off cooldown, then the first hit (the filler)
      for _, list in ipairs({ kit.dots, kit.debuffs }) do
        for _, d in ipairs(list) do
          if not pick then
            local on
            for _, e in ipairs(b.debuffs) do if e.name == d.name then on = e end end
            if not on or on.left < 3 then pick, dot = d, list == kit.dots end
          end
        end
      end
      if not pick then
        for _, h in ipairs(kit.hits) do
          if not pick and h.cd and not (DM.cds[h.name] and now < DM.cds[h.name].start + DM.cds[h.name].dur) then pick = h end
        end
      end
      -- (healers heal a hurt raider half the time)
      local hurt
      if kit.heals[1] and DM.list and math.random() < .5 then
        for _, u in ipairs(DM.list) do if not u.dead and u.hp < u.max * .8 then hurt = u end end
      end
      if hurt then
        local h = Pick(kit.heals)
        local amt = math.random(800, 2400)
        hurt.hp = math.min(hurt.max, hurt.hp + amt)
        Fire("outHeal", { amount = amt, spell = h.name, crit = math.random(1, 6) == 1, name = hurt.name })
        DM.dirty = true
        return
      end
      pick = pick or kit.hits[1]
      if not pick then return end
      if pick.dur then
        -- on the boss: your DoT / debuff (refreshed, stacked)
        local on
        for _, e in ipairs(b.debuffs) do if e.name == pick.name then on = e end end
        if on then on.left, on.count = pick.dur, math.min(pick.stacks or 1, (on.count or 1) + 1)
        elseif table.getn(b.debuffs) < 16 then
          table.insert(b.debuffs, { name = pick.name, tex = pick.icon, type = "", left = pick.dur, count = 1, mine = true, dot = dot })
        end
        DM.adirty = true
        if dot then Fire("outDot", { amount = math.random(90, 340), spell = pick.name, school = 5 }) end
      else
        local crit = math.random(1, 5) == 1
        Fire("outSpell", { amount = math.floor(math.random(700, 2400) * (crit and 1.5 or 1)), crit = crit, spell = pick.name, school = pick.school or 0 })
        if pick.cd then DM.cds[pick.name] = { start = now, dur = pick.cd / DM.speed } end
      end
    end
    -- your debuffs on the boss run down
    for i = table.getn(b.debuffs), 1, -1 do
      local e = b.debuffs[i]
      if e.mine then
        e.left = e.left - dt
        if e.left <= 0 then table.remove(b.debuffs, i) DM.adirty = true end
      end
    end
    -- a proc now and then (as a buff on you), a reactive window
    DM.nextProc = DM.nextProc - dt
    if DM.nextProc <= 0 and kit.procs[1] then
      DM.nextProc = Rand(14, 24)
      local p = Pick(kit.procs)
      DM.procs[p.name] = now + (p.dur or 10) / DM.speed
      Fire("buffGain", { spell = p.name, icon = p.icon })
      DM.Poke("PLAYER_AURAS_CHANGED")
    end
    DM.nextReact = DM.nextReact - dt
    if DM.nextReact <= 0 then
      DM.nextReact = Rand(10, 16)
      for name in pairs(kit.reactive) do
        DM.react[name] = now + 5 / DM.speed
      end
      for _, h in ipairs(kit.hits) do
        if kit.reactive[string.lower(h.name)] then Fire("reactive", { spell = h.name, icon = h.icon }) break end
      end
      DM.reactOn = true
      DM.Poke("ACTIONBAR_UPDATE_USABLE")
    end
    -- the bars' redraws: a cast (cooldowns), a reactive window closing (usable)
    if DM.pokeCD then DM.pokeCD = nil DM.Poke("ACTIONBAR_UPDATE_COOLDOWN") end
    if DM.reactOn then
      local any = false
      for _, t in pairs(DM.react) do if now < t then any = true end end
      if not any then DM.reactOn = nil DM.Poke("ACTIONBAR_UPDATE_USABLE") end
    end
  end

  -- the meters' test fight with you in it: your class's row gets your name and your kit's spells (put back at Stop;
  -- the fight is made again the next time either way)
  function DM.YourMeters(on)
    local M = pfUI.meters
    local TM = M and M.test
    local R = TM and TM.ROSTER
    if not R then return end
    if on and DM.kit then
      for _, row in ipairs(R) do
        if row[2] == DM.kit.class and not DM.meterRow then
          DM.meterRow = { row, row[1], row[3] }
          local spells = {}
          if DM.kit.melee then table.insert(spells, { (T and T["Melee"]) or "Melee", 300, 600, 1 }) end
          for _, h in ipairs(DM.kit.hits) do table.insert(spells, { h.name, 600, 1500, h.cd or 3 }) end
          for _, d in ipairs(DM.kit.dots) do table.insert(spells, { d.name, 100, 300, 3, dot = true }) end
          for _, h in ipairs(DM.kit.heals) do table.insert(spells, { h.name, 800, 2000, 4, heal = true }) end
          row[1], row[3] = _G.UnitName("player") or row[1], spells
        end
      end
      M.testSeg = nil
    elseif DM.meterRow then
      local m = DM.meterRow
      m[1][1], m[1][3] = m[2], m[3]
      DM.meterRow = nil
      M.testSeg = nil
    end
  end

  -- OctoDoTs' sample mobs and the DoT target bar with your class's DoTs (put back at Stop)
  function DM.YourDots(on)
    local D, TB = pfUI.dots, pfUI.dotsTarget
    local kit = DM.kit
    if on and kit then
      local function Short(icon) local _, _, b = string.find(icon or "", "([^\\]+)$") return b or "INV_Misc_QuestionMark" end
      local mine = {}
      for _, d in ipairs(kit.dots) do table.insert(mine, { d.name, Short(d.icon), "mine", d.dur }) end
      for _, d in ipairs(kit.debuffs) do table.insert(mine, { d.name, Short(d.icon), "mine", d.dur, d.stacks }) end
      if D and D.FAKE then
        DM.savedDFake = DM.savedDFake or D.FAKE
        local boss = (DM.boss and DM.boss.name) or "Training Dummy"
        D.FAKE = {
          { boss, 8, 1, .82, mine, 3650, 5560 },
          { "Scarlet Defender", 7, 0, .55, { mine[1] }, 2900, 3800 },
          { "Scarlet Sorcerer", 5, 0, .3, { mine[2] or mine[1] }, 1200, 1200, true },
        }
      end
      if TB and TB.FAKE then
        DM.savedTBFake = DM.savedTBFake or TB.FAKE
        local t = {}
        for i, d in ipairs(mine) do if i <= 5 then table.insert(t, { d[1], d[2], d[4] or 12, i * 2 }) end end
        if t[1] then TB.FAKE = t end
      end
    else
      if D and DM.savedDFake then D.FAKE = DM.savedDFake end
      if TB and DM.savedTBFake then TB.FAKE = DM.savedTBFake end
      DM.savedDFake, DM.savedTBFake = nil, nil
    end
  end

  -- ---------------------------------------------------------------- the rest of pfUI Octo joins in
  -- (19 Nov 2026, user: "does the cooldown manager all feature this also ... make sure everything works with the demo you
  -- choose and make sure it is all cycling properly") Modules that read only you (your spells, cooldowns, swings, DoTs)
  -- cannot see a pretend fight, so each one's own test effect runs, started again before it runs out, for as long as
  -- the demo does. CooldownManager, OctoTotems and OctoConsumes draw their layout-mode samples while DM.ShowSamples().
  function DM.ShowSamples() return DM.on and DM.kind ~= "afk" end
  DM.TESTS = {
    plates = function(s) local P = pfUI.plates if P and P.Test then P.Test(s) end end,
    bars = function(s) local AB = pfUI.barsOcto if AB and AB.Test then AB.Test(s) end end,
    swing = function(s) local ST = pfUI.swing if ST and ST.Test then ST.Test(s) end end,
    dots = function(s) local D = pfUI.dots if D and D.Test then D.Test(s) end end,
    dottarget = function(s) local TB = pfUI.dotsTarget if TB and TB.Test then TB.Test(s) end end,
    range = function(s) local RG = pfUI.range if RG and RG.Test then RG.Test(s) end end,
  }
  DM.CYCLES = {
    raid = { "plates", "bars", "swing", "dots", "dottarget", "range" },
    dungeon = { "plates", "bars", "swing", "dots", "dottarget", "range" },
    pvp = { "plates", "bars", "swing", "dots", "dottarget", "range" },
    dummy = { "bars", "swing", "dots", "dottarget", "range" },
    showcase = { "bars", "swing", "dottarget", "range" },
  }
  DM.CYCLETIME = 20
  -- t: seconds the tests last (nil = start them for the next stretch; 0 = end them now)
  function DM.Cycle(t)
    local list = DM.CYCLES[DM.kind or ""]
    if not list then return end
    for _, key in ipairs(list) do
      local fn = DM.TESTS[key]
      if fn then pcall(fn, t or (DM.CYCLETIME + 3)) end
    end
    DM.cycled = GetTime()
  end
  -- every pfUI module the demo touched, for the tests and the Demo mode page
  function DM.Cycled()
    local out = {}
    for _, key in ipairs(DM.CYCLES[DM.kind or ""] or {}) do table.insert(out, key) end
    return out
  end

  -- ---------------------------------------------------------------- the frames that should show
  -- (19 Nov 2026, user: "no party frames are showing up") the group frames are shown by the demo itself, and any that
  -- still is not on screen after a moment is named in chat with the reason - so a setting never looks like a bug
  function DM.Expected()
    local uf, out = pfUI.uf, {}
    if not uf then return out end
    local cfg = C.unitframes or {}
    if DM.roster == "party" then
      if cfg.raidforgroup == "1" then
        for i = 2, 5 do if uf.raid and uf.raid[i] then table.insert(out, { uf.raid[i], "Raid frame " .. i, cfg.raid }) end end
      else
        for i = 1, 4 do if uf.group and uf.group[i] then table.insert(out, { uf.group[i], "Party frame " .. i, cfg.group }) end end
      end
    elseif DM.roster == "raid" then
      for i = 2, 40 do
        local f = uf.raid and uf.raid[i]
        if f then table.insert(out, { f, "Raid frame " .. i, cfg.raid }) end
      end
    end
    if DM.boss and S().target == "1" and uf.target then table.insert(out, { uf.target, "Target frame", cfg.target }) end
    return out
  end
  function DM.Why(f, c)
    if c and c.visible == "0" then return "it is switched off (Unit Frames > Frame: Show this frame)" end
    if f.label and string.sub(f.label, 1, 5) == "party" and C.unitframes.group.hide_in_raid == "1" and DM.roster == "raid" then
      return "party frames hide in raids (Unit Frames > All frames: Hide party frames in a raid)"
    end
    local p = f:GetParent()
    if p and p.IsVisible and not p:IsVisible() then return "what it sits on is hidden (" .. (p:GetName() or "a hidden frame") .. ")" end
    local l, r = f:GetLeft(), f:GetRight()
    local w = UIParent:GetWidth() or 0
    if l and r and (r < 0 or l > w) then return "it is off the edge of the screen (Move Frames to bring it back)" end
    return "something hid it"
  end
  -- shows every frame the demo needs; report = say in chat which still are not there
  function DM.Ensure(report)
    local missing = {}
    for _, e in ipairs(DM.Expected()) do
      local f, c = e[1], e[3]
      if not f:IsShown() and not (c and c.visible == "0") then
        if f.UpdateVisibility then pcall(f.UpdateVisibility, f) end
        if not f:IsShown() and Fake((f.label or "") .. (f.id or "")) then f:Show() end
        f.update_full = true
      end
      if not f:IsVisible() then table.insert(missing, e[2] .. ": " .. DM.Why(f, c)) end
    end
    if report and table.getn(missing) > 0 then
      DM.Chat("SYSTEM", "|cff33ccffpfUI|r Demo: not on screen - " .. table.concat(missing, "; ", 1, math.min(4, table.getn(missing)))
        .. (table.getn(missing) > 4 and (" (and " .. (table.getn(missing) - 4) .. " more)") or ""))
    end
    return missing
  end

  -- ---------------------------------------------------------------- an AFK screen of its own
  -- (19 Nov 2026, user's run: "the AFK screen is switched off") without pfUI's AFK camera module the demo has its own:
  -- the camera turns, the interface fades away, a clock and the chat on a dark band; any click or key ends it
  function DM.OwnAfk(on)
    local s = DM.afkOwn
    if on then
      if not s then
        s = CreateFrame("Button", "pfDemoAfk", _G.WorldFrame)
        s:SetAllPoints(_G.WorldFrame)
        s:SetFrameStrata("DIALOG")
        s:EnableMouse(true)
        local top = s:CreateTexture(nil, "BACKGROUND")
        top:SetTexture("Interface\\Buttons\\WHITE8X8")
        top:SetPoint("TOPLEFT", s, "TOPLEFT") top:SetPoint("TOPRIGHT", s, "TOPRIGHT") top:SetHeight(110)
        top:SetGradientAlpha("VERTICAL", 0, 0, 0, 0, 0, 0, 0, .9)
        local bot = s:CreateTexture(nil, "BACKGROUND")
        bot:SetTexture("Interface\\Buttons\\WHITE8X8")
        bot:SetPoint("BOTTOMLEFT", s, "BOTTOMLEFT") bot:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT") bot:SetHeight(200)
        bot:SetGradientAlpha("VERTICAL", 0, 0, 0, .9, 0, 0, 0, 0)
        s.clock = s:CreateFontString(nil, "OVERLAY")
        s.clock:SetFont(pfUI.font_default or STANDARD_TEXT_FONT, 32, "OUTLINE")
        s.clock:SetPoint("TOP", s, "TOP", 0, -14)
        s.note = s:CreateFontString(nil, "OVERLAY")
        s.note:SetFont(pfUI.font_default or STANDARD_TEXT_FONT, 14, "OUTLINE")
        s.note:SetPoint("TOP", s.clock, "BOTTOM", 0, -6)
        s.note:SetText("|cff33ccffpfUI Octo demo|r - AFK screen. Click or press any key to end it.")
        s.chat = CreateFrame("ScrollingMessageFrame", nil, s)
        s.chat:SetPoint("BOTTOMLEFT", s, "BOTTOMLEFT", 14, 14)
        s.chat:SetWidth(520) s.chat:SetHeight(150)
        s.chat:SetFont(pfUI.font_default or STANDARD_TEXT_FONT, 13, "OUTLINE")
        s.chat:SetJustifyH("LEFT")
        s.chat:SetFading(false)
        s.chat:SetMaxLines(60)
        s:SetScript("OnClick", function() DM.Stop() end)
        s:EnableKeyboard(true)
        s:SetScript("OnKeyDown", function() DM.Stop() end)
        s:SetScript("OnUpdate", function()
          if (this.tick or 0) > GetTime() then return end
          this.tick = GetTime() + 1
          local h, m = _G.GetGameTime and _G.GetGameTime()
          if h then this.clock:SetText(string.format("%.2d|cff33ccff:|r%.2d", h, m)) end
        end)
        DM.afkOwn = s
      end
      s.chat:Clear()
      s.ui = UIParent:IsShown()
      if s.ui then UIParent:Hide() end
      if _G.MoveViewRightStart then pcall(_G.MoveViewRightStart, .08) end
      s:Show()
    elseif s and s:IsShown() then
      s:Hide()
      if _G.MoveViewRightStop then pcall(_G.MoveViewRightStop) end
      if s.ui and not UIParent:IsShown() then UIParent:Show() end
    end
  end

  -- the showcase: the next caption and its test
  function DM.ShowNext()
    DM.showT = 0
    DM.showIndex = math.mod(DM.showIndex or 0, table.getn(DM.SHOW)) + 1
    local s = DM.SHOW[DM.showIndex]
    DM.caption = s[1]
    if s[2] then pcall(s[2]) end
    if DM.PaintBar then DM.PaintBar() end
  end

  -- the meter test fight and the combat text test while a boss is up
  function DM.Joins(on)
    local M = pfUI.meters
    if S().meters == "1" and M and M.TestMode then
      if on and not M.testOn then DM.metersMine = true pcall(M.TestMode, true)
      elseif not on and DM.metersMine then DM.metersMine = nil pcall(M.TestMode, false) end
    end
    -- (20 Nov 2026) combat text: no longer combat text's own test round (other classes' spells) - your own spells
    -- from DM.YouStep / DM.CT go through it. The combat text switches on for the demo if it was off.
    local CT = pfUI.sct and pfUI.sct.CT
    local B = pfUI.sct and pfUI.sct.B
    if S().ctext == "1" and CT and B and B.db and B.db.sct then
      if on and not B.db.sct.enabled then DM.ctOn = true B.db.sct.enabled = true
      elseif not on and DM.ctOn then DM.ctOn = nil B.db.sct.enabled = false end
    end
  end

  -- ---------------------------------------------------------------- start / stop
  DM.KINDS = {
    { key = "raid", label = "Raid (40)", ready = true },
    { key = "dungeon", label = "Dungeon (5)" }, { key = "pvp", label = "PvP" }, { key = "afk", label = "AFK" },
    { key = "dummy", label = "Target dummy" }, { key = "showcase", label = "Showcase" },
  }
  DM.READY = { raid = true, dummy = true, dungeon = true, pvp = true, afk = true, showcase = true }
  DM.LABEL = { raid = "Raid", dummy = "Target dummy", dungeon = "Dungeon", pvp = "PvP", afk = "AFK", showcase = "Showcase" }
  -- which pretend group each demo has
  DM.ROSTERS = { raid = "raid", showcase = "raid", dungeon = "party", pvp = "party" }
  -- (20 Nov 2026, user: a Start in a fight said no in chat, then Stop did nothing and nothing started again until a
  -- reload.) A step that errors in the game must never leave the demo half on: Start's setup and every one of Stop's
  -- steps run in pcall, and Stop always ends with the demo off and every function back.
  local function Try(fn, a)
    if not fn then return true end
    local good, err = pcall(fn, a)
    if not good then DM.lastError = err end
    return good
  end
  function DM.Start(kind)
    kind = kind or "raid"
    if not DM.READY[kind] then kind = "raid" end
    if _G.UnitAffectingCombat and _G.UnitAffectingCombat("player") then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r Demo: not while you are in a fight - start it again once the fight is over.")
      return false
    end
    if DM.on then DM.Stop(true) end
    DM.lastError = nil
    local good, err = pcall(DM.Begin, kind)
    if good then return true end
    -- half started: everything back, and say why
    DM.on = true
    DM.Stop(true)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r Demo could not start: " .. tostring(err))
    return false
  end
  function DM.Begin(kind)
    math.randomseed(math.floor((GetTime() or 0) * 1000))
    local roster = DM.ROSTERS[kind]
    if roster == "raid" then DM.MakeRaid() elseif roster == "party" then DM.MakeParty()
    else DM.units, DM.list, DM.tank, DM.offtank = {}, {}, nil, nil end
    DM.kind, DM.on, DM.paused, DM.t = kind, true, false, 0
    DM.speed = tonumber(S().speed) or 1
    DM.pulls, DM.bossIndex, DM.dbossIndex, DM.packIndex, DM.packsDone = 0, 0, 0, 0, 0
    DM.trashDone, DM.rank, DM.retry, DM.wiped, DM.pack = nil, 0, nil, nil, nil
    DM.showIndex, DM.showT, DM.caption, DM.bgAt = 0, 0, nil, 8
    -- (20 Nov 2026) your class: your spells, cooldowns and procs in every demo but AFK
    if kind == "afk" then DM.kit = nil else DM.MakeKit() end
    DM.Install(roster)
    if kind == "dummy" then DM.SetPhase("dummy")
    elseif kind == "afk" then DM.SetPhase("afk")
    else DM.SetPhase("trash") end
    DM.Regroup()
    if kind ~= "afk" then DM.YourMeters(true) DM.Joins(true) end
    if kind == "showcase" then DM.ShowNext() end
    DM.YourDots(DM.kit and true)
    DM.Cycle()
    DM.ensureAt, DM.reported = GetTime() + 1.5, nil
    DM.bar:Show()
    DM.PaintBar()
    return true
  end
  function DM.Stop(quiet)
    if not DM.on then
      -- (nothing running, but the bar was left up by an older half start: hide it)
      if DM.bar:IsShown() then DM.bar:Hide() end
      return
    end
    Try(DM.Joins, false)
    Try(DM.YourMeters, false)
    Try(DM.Cycle, .01)
    Try(DM.YourDots, false)
    Try(DM.OwnAfk, false)
    local wasKind = DM.kind
    DM.on, DM.boss, DM.fight, DM.pack, DM.caption = false, nil, false, nil, nil
    Try(DM.Uninstall)
    DM.slots, DM.slotset, DM.slotcd, DM.invcd = nil, nil, nil, nil
    -- (no res icon may stay behind)
    if DM.resq then
      local lp = pfUI.api and pfUI.api.libpredict
      for r in pairs(DM.resq.busy or {}) do if lp and lp.RessStop then pcall(lp.RessStop, lp, r.name) end end
      DM.resq = nil
    end
    if DM.kit then
      DM.kit = nil
      Try(DM.Poke, "ACTIONBAR_UPDATE_COOLDOWN")
      Try(DM.Poke, "ACTIONBAR_UPDATE_USABLE")
      Try(DM.Poke, "PLAYER_AURAS_CHANGED")
    end
    Try(DM.Regroup)
    if wasKind == "afk" then
      if DM.afkNote then DM.afkNote:Hide() end
      local cam = _G.pfAFKCam
      if cam and cam._spinning and cam.stop then pcall(cam.stop, cam) end
    end
    DM.bar:Hide()
    if DM.lastError and not quiet then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r Demo: a part did not stop cleanly (" .. tostring(DM.lastError) .. ") - the rest is back.")
    end
    if not quiet then DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r Demo stopped: everything is back as it was.") end
  end
  function DM.Next()
    if not DM.on then return end
    if DM.kind == "showcase" then DM.ShowNext() return end
    local ph = DM.phase
    if ph == "dummy" then DM.SetPhase("dummy") DM.PaintBar() return end
    if ph == "afk" then return end
    if ph == "trash" or ph == "boss" then
      for _, m in ipairs(DM.pack or {}) do m.hp, m.dead = 0, true end
      if DM.boss then DM.boss.hp, DM.boss.dead = 0, true end
      if ph == "trash" then DM.trashDone = true end
      DM.SetPhase("ended")
    elseif ph == "ended" then DM.SetPhase(DM.AfterEnded())
    else DM.SetPhase(DM.AfterRest()) end
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

  -- ---------------------------------------------------------------- resurrections, one at a time
  -- Every living resser (priest, paladin, shaman, druid) casts a res on one of the dead - the dead ressers first, so more
  -- hands get up sooner - with its cast bar and pfUI's res icon on the target (libpredict:Ress, as HealComm does); when
  -- the cast ends the target is up. Nobody able to res: a Soulstone gets a resser up first.
  DM.RESSPELL = { PRIEST = { "Resurrection", I .. "Spell_Holy_Resurrection" }, PALADIN = { "Redemption", I .. "Spell_Holy_Resurrection" },
    SHAMAN = { "Ancestral Spirit", I .. "Spell_Nature_Regenerate" }, DRUID = { "Rebirth", I .. "Spell_Nature_Reincarnation" } }
  DM.RESTIME = 3.5
  local function LP() return pfUI.api and pfUI.api.libpredict end
  function DM.StartRes()
    DM.resq = { busy = {}, wait = 1.5 }
    DM.Chat("SYSTEM", "Release and wait for a res - ressers first.")
  end
  function DM.ResStep(dt)
    local q = DM.resq
    if not q then return end
    local now = GetTime()
    local dead, alive = {}, {}
    for _, u in ipairs(DM.list or {}) do if u.dead then table.insert(dead, u) else table.insert(alive, u) end end
    -- casts that finished: the target is up
    for resser, c in pairs(q.busy) do
      if now >= c.finish then
        q.busy[resser] = nil
        resser.cast = nil
        local lp = LP()
        if lp and lp.RessStop then pcall(lp.RessStop, lp, resser.name) end
        local t = c.target
        if t.dead then
          t.dead, t.hp, t.debuffs, t.cast, t.deadT = nil, t.max * .35, {}, nil, nil
          if t.ptype ~= 1 then t.pw = (t.pmax or 0) * .35 else t.pw = 0 end
          DM.Chat("SYSTEM", resser.name .. " resurrects " .. t.name .. ".")
        end
        resser.resRest = now + .6 / DM.speed
        DM.dirty, DM.adirty = true, true
        DM.Touch(true)
      end
    end
    if table.getn(dead) == 0 then
      local casting
      for _ in pairs(q.busy) do casting = true end
      if not casting then
        DM.resq = nil
        Warn("Everyone is up - rebuff and go")
        if DM.phase == "rest" then DM.pt = 0 end
      end
      return
    end
    q.wait = (q.wait or 0) - dt
    if q.wait > 0 then return end
    -- who is being ressed already
    local taken = {}
    for _, c in pairs(q.busy) do taken[c.target] = true end
    local function NextTarget()
      for _, u in ipairs(dead) do if not taken[u] and DM.RESSPELL[u.class or ""] then return u end end
      for _, u in ipairs(dead) do if not taken[u] then return u end end
    end
    local ressers = 0
    for _, r in ipairs(alive) do
      local sp = DM.RESSPELL[r.class or ""]
      if sp then
        ressers = ressers + 1
        if not q.busy[r] and now >= (r.resRest or 0) then
          local t = NextTarget()
          if not t then break end
          taken[t] = true
          q.busy[r] = { target = t, finish = now + DM.RESTIME / DM.speed }
          r.cast = { name = sp[1], icon = sp[2], start = now, finish = now + DM.RESTIME / DM.speed }
          local lp = LP()
          if lp and lp.Ress then pcall(lp.Ress, lp, r.name, t.name) end
          DM.dirty = true
        end
      end
    end
    -- nobody alive can res: a Soulstone on a dead resser
    if ressers == 0 then
      local first
      for _, u in ipairs(dead) do if not first and DM.RESSPELL[u.class or ""] then first = u end end
      first = first or dead[1]
      first.dead, first.hp, first.debuffs = nil, first.max * .5, {}
      if first.ptype ~= 1 then first.pw = (first.pmax or 0) * .5 end
      DM.Chat("SYSTEM", first.name .. " uses a Soulstone.")
      q.wait = 1.5 / DM.speed
      DM.dirty, DM.adirty = true, true
      DM.Touch(true)
    end
  end

  -- ---------------------------------------------------------------- events on demand
  -- (20 Nov 2026, user: "a button we can press during the test that triggers events. E.g Overthreat, wipe, party getting
  -- ressed, etc etc the most we can have to fully test our setup") Each runs on the demo that is on; one that needs a
  -- fight starts the boss first. The demo bar's Events menu and the Demo mode page's buttons list the same DM.EVENTS.
  local function Fight()
    if DM.fight and DM.boss and (DM.phase == "boss" or DM.phase == "trash") then return true end
    if DM.kind == "afk" or DM.kind == "dummy" then return false end
    DM.SetPhase(DM.kind == "pvp" and "trash" or "boss")
    return true
  end
  local function Me() return _G.UnitName("player") or "You" end
  local function Dead()
    local out = {}
    for _, u in ipairs(DM.list or {}) do if u.dead then table.insert(out, u) end end
    return out
  end
  local function Healer()
    for _, u in ipairs(Alive()) do if u.role == "heal" then return u end end
    return Alive()[1]
  end
  local function Res(u, by, how)
    u.dead, u.hp, u.debuffs, u.cast, u.deadT = nil, u.max * .35, {}, nil, nil
    DM.Chat("SYSTEM", (by and by.name or "Someone") .. " " .. (how or "resurrects") .. " " .. u.name .. ".")
    DM.dirty, DM.adirty = true, true
  end
  DM.CURES = {
    { I .. "Spell_Shadow_CurseOfSargeras", "Curse", 18 }, { I .. "Spell_Nature_CorrosiveBreath", "Poison", 14 },
    { I .. "Spell_Shadow_CreepingPlague", "Disease", 16 }, { I .. "Spell_Frost_FrostNova", "Magic", 12 },
    { I .. "Spell_Shadow_Possession", "Magic", 12 },
  }
  DM.EVENTS = {
    { key = "over", label = "Overthreat", icon = I .. "Ability_Warrior_Challange", group = "Threat",
      tip = "You climb past the pull point and the boss turns to you: your threat window, label, popup and sound.",
      fn = function()
        if not Fight() then return end
        DM.thEvent = { kind = "over", t = 0 }
      end },
    { key = "dots", label = "DoTs pull aggro", icon = I .. "Spell_Shadow_AbominationExplosion", group = "Threat",
      tip = "Just under the pull point with DoTs still ticking: \"DoTs pull in 5 s\" counts down, the popup comes, then you pull.",
      fn = function()
        if not Fight() then return end
        DM.thEvent = { kind = "dots", t = 0 }
      end },
    { key = "tank", label = "Tank dies", icon = I .. "INV_Shield_05", group = "Threat",
      tip = "The main tank dies: the off-tank takes the boss, the threat list changes holder.",
      fn = function()
        if not Fight() then return end
        local tk = DM.tank
        if tk and not tk.dead then Hurt(tk, tk.max * 3) DM.Chat("SYSTEM", tk.name .. " dies.") Warn(tk.name .. " is down - off-tank, taunt!") end
      end },
    { key = "aoe", label = "Raid-wide damage", icon = I .. "Spell_Fire_SelfDestruct", group = "Fight",
      tip = "A big hit on everyone: low health bars, heal prediction, your incoming damage text.",
      fn = function()
        if not Fight() then return end
        local b = DM.boss
        Use(b, { what = "raid", name = "Shadow Flame", dmg = { 2200, 3400 } })
        Warn((b and b.name or "The boss") .. " casts Shadow Flame!")
      end },
    { key = "cast", label = "Boss casts a big spell", icon = I .. "Spell_Shadow_ShadowBolt", group = "Fight",
      tip = "A 4 second cast on the boss's cast bar (target frame, nameplate) that hits the raid when it ends.",
      fn = function()
        if not Fight() then return end
        local b, now = DM.boss, GetTime()
        b.cast = { name = "Shadow Bolt Volley", icon = I .. "Spell_Shadow_ShadowBolt", start = now, finish = now + 4 / DM.speed,
          a = { what = "raid", name = "Shadow Bolt Volley", dmg = { 900, 1500 }, kick = true } }
        DM.Touch(false)
      end },
    { key = "debuffs", label = "Debuffs to cure", icon = I .. "Spell_Holy_DispelMagic", group = "Fight",
      tip = "Curses, poisons, diseases and magic on ten raiders: raid frame debuff colours, OctoRinse, dispel markers.",
      fn = function()
        if not Fight() then return end
        local alive = Alive()
        for _ = 1, math.min(10, table.getn(alive)) do AddDebuff(Pick(alive), Pick(DM.CURES)) end
        DM.adirty = true
      end },
    { key = "enrage", label = "Boss enrages", icon = I .. "Spell_Shadow_UnholyFrenzy", group = "Fight",
      tip = "A raid warning and an emote: the boss hits the tank twice as hard for 15 seconds.",
      fn = function()
        if not Fight() then return end
        local b = DM.boss
        b.enrageUntil = DM.t + 15
        DM.Chat("MONSTER_EMOTE", b.name .. " becomes enraged!")
        Warn(b.name .. " is ENRAGED!")
      end },
    { key = "oom", label = "Healers run out of mana", icon = I .. "INV_Potion_76", group = "Fight",
      tip = "Every healer's mana drops near zero: mana bars, low-mana warnings; healing stops until they drink.",
      fn = function()
        for _, u in ipairs(Alive()) do if u.role == "heal" then u.pw = (u.pmax or 1000) * .03 end end
        DM.dirty = true
      end },
    { key = "death", label = "Someone dies", icon = I .. "Ability_Rogue_FeignDeath", group = "Deaths",
      tip = "A random raider dies: grey frame, the meters' deaths, a res to come.",
      fn = function()
        if not Fight() then return end
        local alive = {}
        for _, u in ipairs(Alive()) do if u ~= DM.tank and u.role ~= "heal" then table.insert(alive, u) end end
        local u = Pick(table.getn(alive) > 0 and alive or Alive())
        if u then Hurt(u, u.max * 3) DM.Chat("SYSTEM", u.name .. " dies.") end
      end },
    { key = "bres", label = "Battle res", icon = I .. "Spell_Nature_Reincarnation", group = "Deaths",
      tip = "One dead raider is brought back mid-fight (Rebirth).",
      fn = function()
        local d = Dead()
        if table.getn(d) == 0 then DM.Chat("SYSTEM", "Nobody is dead - press Someone dies first.") return end
        Res(Pick(d), Healer(), "casts Rebirth on")
      end },
    { key = "res", label = "Res everyone", icon = I .. "Spell_Holy_Resurrection", group = "Deaths",
      tip = "Every dead raider is resurrected, one after another in chat.",
      fn = function()
        local d = Dead()
        if table.getn(d) == 0 then DM.Chat("SYSTEM", "Nobody is dead - press Wipe or Someone dies first.") return end
        -- one at a time, ressers first, each with its cast bar and res icon (DM.ResStep)
        if not DM.resq then DM.StartRes() end
      end },
    { key = "wipe", label = "Wipe", icon = I .. "Spell_Shadow_DeathScream", group = "Deaths",
      tip = "The raid goes down over a few seconds; after it, the same boss again (Res everyone to bring them up at once).",
      fn = function()
        if not Fight() then return end
        -- (resses still going stop: nobody gets up while the raid goes down)
        if DM.resq then
          local lp = pfUI.api and pfUI.api.libpredict
          for r in pairs(DM.resq.busy or {}) do r.cast = nil if lp and lp.RessStop then pcall(lp.RessStop, lp, r.name) end end
          DM.resq = nil
        end
        DM.forceWipe = true
        Warn("Wipe incoming!")
      end },
    { key = "kill", label = "Kill the boss", icon = I .. "INV_Misc_Head_Dragon_01", group = "Deaths",
      tip = "The boss dies at once: kill message, meters' fight ends, the rest after it.",
      fn = function()
        if not Fight() then return end
        DM.boss.hp = 1
      end },
  }
  function DM.Event(key)
    if not DM.on then
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r Demo: start a demo first, then trigger events.")
      return false
    end
    if DM.kind == "afk" then return false end
    for _, e in ipairs(DM.EVENTS) do
      if e.key == key then
        local good, err = pcall(e.fn)
        if not good then DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffpfUI|r Demo event failed: " .. tostring(err)) return false end
        DM.dirty, DM.adirty = true, true
        if DM.Touch then pcall(DM.Touch, false) end
        DM.PaintBar()
        return true
      end
    end
    return false
  end
  -- the Events menu (the demo bar's button)
  function DM.EventMenu(anchor)
    local W = pfUI.octoui and pfUI.octoui.W
    if not W or not W.Menu then return end
    local opts, last = {}, nil
    for _, e in ipairs(DM.EVENTS) do
      if e.group ~= last then table.insert(opts, { label = e.group, group = true }) last = e.group end
      table.insert(opts, { key = e.key, label = e.label, icon = e.icon, tip = e.tip })
    end
    if DM.menu then DM.menu:Hide() end
    DM.menu = W.Menu(anchor, opts, 190, function(k) DM.Event(k) end)
    if DM.menu then DM.menu:Show() end
  end

  -- ---------------------------------------------------------------- the bar at the top of the screen
  local bar = CreateFrame("Frame", "pfDemoBar", UIParent)
  DM.bar = bar
  bar:SetWidth(690)
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
  bar.next = Btn("Next", 48, function() DM.Next() end, "Skips to the next part: the next pull, mob, enemy, rank or showcase step.")
  bar.speedb = Btn("1x", 40, function() DM.CycleSpeed() end, "Demo speed: 0.5x, 1x, 2x, 4x.")
  bar.pause = Btn("Pause", 56, function() DM.paused = not DM.paused DM.PaintBar() end, "Holds the fight where it is.")
  bar.events = Btn("Events", 60, function() DM.EventMenu(this) end,
    "Make something happen now: overthreat, DoTs pulling, a wipe, a res, a tank death, debuffs to cure, a big cast...")
  local x = -6
  for _, b in ipairs(bar.buttons) do
    b:SetPoint("RIGHT", bar, "RIGHT", x, 0)
    x = x - b:GetWidth() - 4
  end
  -- the showcase's caption: a line under the bar
  bar.caption = bar:CreateFontString(nil, "OVERLAY")
  bar.caption:SetFont(pfUI.font_default or STANDARD_TEXT_FONT, 14, "OUTLINE")
  bar.caption:SetPoint("TOP", bar, "BOTTOM", 0, -8)
  bar.caption:SetTextColor(1, .9, .55)
  local PHASENAME = { trash = "Trash", boss = "Boss", ended = "", rest = "Rest" }
  DM.TRASHNAME = { dungeon = "Pack", pvp = "Enemy" }
  local function Clock(s) s = math.floor(s or 0) return math.floor(s / 60) .. ":" .. string.format("%02d", math.mod(s, 60)) end
  DM.Clock = Clock
  function DM.PaintBar()
    if not DM.on then return end
    if DM.caption then bar.caption:SetText(DM.caption) bar.caption:Show() else bar.caption:Hide() end
    local b = DM.boss
    local what = PHASENAME[DM.phase] or ""
    if DM.phase == "trash" and DM.TRASHNAME[DM.kind] then
      what = DM.TRASHNAME[DM.kind]
      if DM.kind == "dungeon" then what = what .. " " .. (DM.packIndex or 1) end
    end
    if DM.phase == "ended" then
      what = DM.wiped and "|cffff5544Wipe|r" or "|cff55ff66Kill|r"
      if DM.kind == "dungeon" and DM.lastFight == "trash" then what = "|cff55ff66Pack down|r" end
    end
    if b and b.player and b.cl then b = { name = b.name .. " (" .. b.cl .. ")", hp = b.hp, max = b.max } end
    local line = "|cff33ccffDEMO|r  " .. (DM.LABEL[DM.kind] or "Raid") .. "  |cff888888-|r  " .. what
    if DM.phase == "dummy" and b then
      local d = DM.DUMMIES[DM.rank]
      line = "|cff33ccffDEMO|r  Target dummy  |cff888888-|r  |cffffffff" .. (d and d.label or "") .. "|r " .. math.floor(b.hp / b.max * 100 + .5)
        .. "%  |cff888888next rank in " .. math.max(0, math.ceil((DM.RANKTIME - DM.pt) / math.max(DM.speed, .1))) .. " s|r"
    elseif b and (DM.phase == "boss" or DM.phase == "trash") then
      line = line .. ": |cffffffff" .. b.name .. "|r " .. math.floor(b.hp / b.max * 100 + .5) .. "%"
    end
    if DM.phase ~= "dummy" then line = line .. "  |cff888888" .. Clock(DM.pt) .. "|r" end
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
    -- the other modules' tests again before they run out; the frames that should show, shown (and once, said)
    if GetTime() - (DM.cycled or 0) >= DM.CYCLETIME then DM.Cycle() end
    if DM.ensureAt and GetTime() >= DM.ensureAt then
      DM.ensureAt = GetTime() + 2
      DM.Ensure(not DM.reported)
      DM.reported = true
    end
    local dt = acc
    acc = 0
    if DM.paused then return end
    DM.dirty, DM.adirty = false, false
    DM.Step(dt * DM.speed)
    DM.Threat(dt * DM.speed)
    if DM.adirty then DM.Touch(false, true) end
    if DM.dirty or DM.fight then DM.Touch(false) end
  end)
  -- (20 Nov 2026, crash #132 twice, found by the pfUI continuation session from the .dmp: ACCESS_VIOLATION at
  -- 0x004648AC reading 0x24 = the object manager lookup from UnitName with the object manager already freed.) On a
  -- DISCONNECT the client leaves the world, frees the object manager, and only THEN fires PLAYER_LOGOUT: any unit call
  -- (UnitName, a frame refresh, a plate or bar test) from a PLAYER_LOGOUT handler crashes it. So:
  --   PLAYER_LEAVING_WORLD (the world still there): the full visual DM.Stop.
  --   PLAYER_LOGOUT: DM.Logout - plain table writes only, so the saved settings are clean; no unit, frame or CVar call
  --   (afkcam.lua: resetting CVars on PLAYER_LOGOUT crashes the client too).
  function DM.Logout()
    if not DM.on then return end
    DM.on, DM.fight, DM.boss, DM.pack, DM.kit = false, false, nil, nil, nil
    -- the one saved setting the demo may have switched for itself: combat text on
    local B = pfUI.sct and pfUI.sct.B
    if DM.ctOn and B and B.db and B.db.sct then B.db.sct.enabled = false end
    DM.ctOn = nil
    -- pfUI's own functions back (rawset into pfUI's environment, no calls)
    DM.Uninstall(true)
    DM.YourDots(false)
    DM.YourMeters(false)
    DM.metersMine = nil
    tick:SetScript("OnUpdate", nil)
    tick:UnregisterAllEvents()
  end
  tick:RegisterEvent("PLAYER_REGEN_DISABLED")
  tick:RegisterEvent("PLAYER_LEAVING_WORLD")
  tick:RegisterEvent("PLAYER_LOGOUT")
  tick:SetScript("OnEvent", function()
    if event == "PLAYER_LOGOUT" then DM.Logout() return end
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
