BCS = BCS or {}

BCS["L"] = {
	SET_PATTERN = "(.+) %(%d/%d%)",

	["%+(%d+)%% Critical Strike"] = "%+(%d+)%% Critical Strike",
	["([%d.]+)%% chance to crit"] = "([%d.]+)%% chance to crit",

	["^Set: Improves your chance to hit by (%d)%%."] = "^Set: Improves your chance to hit by (%d)%%.",
	["^Set: Improves your chance to get a critical strike with spells by (%d)%%."] = "^Set: Improves your chance to get a critical strike with spells by (%d)%%.",
	["^Set: Improves your chance to hit with spells by (%d)%%."] = "^Set: Improves your chance to hit with spells by (%d)%%.",
	["^Set: Increases damage and healing done by magical spells and effects by up to (%d+)%."] = "^Set: Increases damage and healing done by magical spells and effects by up to (%d+)%.",
	["^Set: Increases healing done by spells and effects by up to (%d+)%."] = "^Set: Increases healing done by spells and effects by up to (%d+)%.",
	["^Set: Allows (%d+)%% of your Mana regeneration to continue while casting."] = "^Set: Allows (%d+)%% of your Mana regeneration to continue while casting.",
	["^Set: Improves your chance to get a critical strike by (%d)%%."] = "^Set: Improves your chance to get a critical strike by (%d)%%.",
	["^Set: Restores (%d+) mana per 5 sec."] = "^Set: Restores (%d+) mana per 5 sec.",

	["Equip: Improves your chance to hit by (%d)%%."] = ITEM_SPELL_TRIGGER_ONEQUIP .. " Improves your chance to hit by (%d)%%.",
	["Equip: Improves your chance to get a critical strike with spells by (%d)%%."] = ITEM_SPELL_TRIGGER_ONEQUIP .. " Improves your chance to get a critical strike with spells by (%d)%%.",
	["Equip: Improves your chance to hit with spells by (%d)%%."] = ITEM_SPELL_TRIGGER_ONEQUIP .. " Improves your chance to hit with spells by (%d)%%.",
	["Equip: Improves your chance to get a critical strike by (%d)%%."] = ITEM_SPELL_TRIGGER_ONEQUIP .. " Improves your chance to get a critical strike by (%d)%%.",
	["Increases your chance to hit with melee weapons by (%d)%%."] = "Increases your chance to hit with melee weapons by (%d)%%.",
	["Increases your critical strike chance with ranged weapons by (%d)%%."] = "Increases your critical strike chance with ranged weapons by (%d)%%.",
	["Increases hit chance by (%d+)%%, and by an additional (%d+)%% while dual wielding"] = "Increases hit chance by (%d+)%%, and by an additional (%d+)%% while dual wielding",
	["Increases your critical strike chance with all attacks by (%d)%%."] = "Increases your critical strike chance with all attacks by (%d)%%.",
	["Increases spell damage and healing by up to (%d+)%% of your total Spirit."] = "Increases spell damage and healing by up to (%d+)%% of your total Spirit.",
	["Allows (%d+)%% of your Mana regeneration to continue while casting."] = "Allows (%d+)%% of your Mana regeneration to continue while casting.",
	["Reduces the chance that the opponent can resist your Frost and Fire spells by (%d)%%."] = "Reduces the chance that the opponent can resist your Frost and Fire spells by (%d)%%.",
	["Reduces the chance that the opponent can resist your Arcane spells by (%d+)%%."] = "Reduces the chance that the opponent can resist your Arcane spells by (%d+)%%.",
	["Reduces your target's chance to resist your Shadow spells by (%d+)%%."] = "Reduces your target's chance to resist your Shadow spells by (%d+)%%.",

	["Equip: Increases damage done by Arcane spells and effects by up to (%d+)."] = ITEM_SPELL_TRIGGER_ONEQUIP .. " Increases damage done by Arcane spells and effects by up to (%d+).",
	["Equip: Increases damage done by Fire spells and effects by up to (%d+)."] = ITEM_SPELL_TRIGGER_ONEQUIP .. " Increases damage done by Fire spells and effects by up to (%d+).",
	["Equip: Increases damage done by Frost spells and effects by up to (%d+)."] = ITEM_SPELL_TRIGGER_ONEQUIP .. " Increases damage done by Frost spells and effects by up to (%d+).",
	["Equip: Increases damage done by Holy spells and effects by up to (%d+)."] = ITEM_SPELL_TRIGGER_ONEQUIP .. " Increases damage done by Holy spells and effects by up to (%d+).",
	["Equip: Increases damage done by Nature spells and effects by up to (%d+)."] = ITEM_SPELL_TRIGGER_ONEQUIP .. " Increases damage done by Nature spells and effects by up to (%d+).",
	["Equip: Increases damage done by Shadow spells and effects by up to (%d+)."] = ITEM_SPELL_TRIGGER_ONEQUIP .. " Increases damage done by Shadow spells and effects by up to (%d+).",

	["^Set: Increases damage done by Arcane spells and effects by up to (%d+)"] = "^Set: Increases damage done by Arcane spells and effects by up to (%d+)",
	["^Set: Increases damage done by Fire spells and effects by up to (%d+)"] = "^Set: Increases damage done by Fire spells and effects by up to (%d+)",
	["^Set: Increases damage done by Frost spells and effects by up to (%d+)"] = "^Set: Increases damage done by Frost spells and effects by up to (%d+)",
	["^Set: Increases damage done by Holy spells and effects by up to (%d+)"] = "^Set: Increases damage done by Holy spells and effects by up to (%d+)",
	["^Set: Increases damage done by Nature spells and effects by up to (%d+)"] = "^Set: Increases damage done by Nature spells and effects by up to (%d+)",
	["^Set: Increases damage done by Shadow spells and effects by up to (%d+)"] = "^Set: Increases damage done by Shadow spells and effects by up to (%d+)",

	["Spell Damage %+(%d+)"] = "Spell Damage %+(%d+)",
	["Spell damage is increased by up to (%d+)"] = "Spell damage is increased by up to (%d+)",
	["Spell damage increased by up to (%d+)"] = "Spell damage increased by up to (%d+)",
	["Spell Damage increased by (%d+)"] = "Spell Damage increased by (%d+)",
	["^%+(%d+) Spell Power"] = "^%+(%d+) Spell Power",

	["Arcane Damage %+(%d+)"] = "Arcane Damage %+(%d+)",
	["Fire Damage %+(%d+)"] = "Fire Damage %+(%d+)",
	["Frost Damage %+(%d+)"] = "Frost Damage %+(%d+)",
	["Holy Damage %+(%d+)"] = "Holy Damage %+(%d+)",
	["Nature Damage %+(%d+)"] = "Nature Damage %+(%d+)",
	["Shadow Damage %+(%d+)"] = "Shadow Damage %+(%d+)",

	["Healing Spells %+(%d+)"] = "Healing Spells %+(%d+)",
	["^Healing %+(%d+) and %d+ mana per 5 sec."] = "^Healing %+(%d+) and %d+ mana per 5 sec.",

	["Equip: Restores (%d+) mana per 5 sec."] = ITEM_SPELL_TRIGGER_ONEQUIP .. " Restores (%d+) mana per 5 sec.",
	["+(%d)%% Ranged Hit"] = "+(%d)%% Ranged Hit",
	["+(%d)%% Ranged Crit"] = "+(%d)%% Ranged Crit",

	-- Random Bonuses // https://wow.gamepedia.com/index.php?title=SuffixId&oldid=204406
	["^%+(%d+) Damage and Healing Spells"] = "^%+(%d+) Damage and Healing Spells",
	["^%+(%d+) Arcane Spell Damage"] = "^%+(%d+) Arcane Spell Damage",
	["^%+(%d+) Fire Spell Damage"] = "^%+(%d+) Fire Spell Damage",
	["^%+(%d+) Frost Spell Damage"] = "^%+(%d+) Frost Spell Damage",
	["^%+(%d+) Holy Spell Damage"] = "^%+(%d+) Holy Spell Damage",
	["^%+(%d+) Nature Spell Damage"] = "^%+(%d+) Nature Spell Damage",
	["^%+(%d+) Shadow Spell Damage"] = "^%+(%d+) Shadow Spell Damage",
	["^%+(%d+) mana every 5 sec."] = "^%+(%d+) mana every 5 sec.",
	["Restores (%d+) mana every 1 sec."] = "Restores (%d+) mana every 1 sec.",
	["(%d+)%% of your Mana regeneration continuing while casting."] = "(%d+)%% of your Mana regeneration continuing while casting.",
	["(%d+)%% of your mana regeneration to continue while casting."] = "(%d+)%% of your mana regeneration to continue while casting.",

	-- Wizard Oils
	["^Brilliant Wizard Oil"] = "^Brilliant Wizard Oil",
	["^Lesser Wizard Oil"] = "^Lesser Wizard Oil",
	["^Minor Wizard Oil"] = "^Minor Wizard Oil",
	["^Wizard Oil"] = "^Wizard Oil",

	-- Mana Oils
	["^Brilliant Mana Oil"] = "^Brilliant Mana Oil",
	["^Lesser Mana Oil"] = "^Lesser Mana Oil",
	["^Minor Mana Oil"] = "^Minor Mana Oil",

	-- snowflakes ZG enchants
	["/Hit %+(%d+)"] = "/Hit %+(%d+)",
	["/Spell Hit %+(%d+)"] = "/Spell Hit %+(%d+)",
	["^Mana Regen %+(%d+)"] = "^Mana Regen %+(%d+)",
	["^Healing %+%d+ and (%d+) mana per 5 sec."] = "^Healing %+%d+ and (%d+) mana per 5 sec.",
	["^%+(%d+) Healing Spells"] = "^%+(%d+) Healing Spells",
	["^%+(%d+) Spell Damage and Healing"] = "^%+(%d+) Spell Damage and Healing",

	["Equip: Increases damage and healing done by magical spells and effects by up to (%d+)%."] = "Equip: Increases damage and healing done by magical spells and effects by up to (%d+)%.",
	["Equip: Increases healing done by spells and effects by up to (%d+)."] = "Equip: Increases healing done by spells and effects by up to (%d+).",

	-- auras
	["Critical strike chance increased by (%d+)%%."] = "Critical strike chance increased by (%d+)%%.",
	["Chance to hit increased by (%d)%%."] = "Chance to hit increased by (%d)%%.",
	["Magical damage dealt is increased by up to (%d+)."] = "Magical damage dealt is increased by up to (%d+).",
	["Arcane damage dealt by spells and abilities is increased by up to (%d+)"] = "Arcane damage dealt by spells and abilities is increased by up to (%d+)",
	["Fire damage dealt by spells and abilities is increased by up to (%d+)"] = "Fire damage dealt by spells and abilities is increased by up to (%d+)",
	["Frost damage dealt by spells and abilities is increased by up to (%d+)"] = "Frost damage dealt by spells and abilities is increased by up to (%d+)",
	["Nature damage dealt by spells and abilities is increased by up to (%d+)"] = "Nature damage dealt by spells and abilities is increased by up to (%d+)",
	["Shadow damage dealt by spells and abilities is increased by up to (%d+)"] = "Shadow damage dealt by spells and abilities is increased by up to (%d+)",
	["Holy damage dealt by spells and abilities is increased by up to (%d+)"] = "Holy damage dealt by spells and abilities is increased by up to (%d+)",
	["Healing done by magical spells is increased by up to (%d+)."] = "Healing done by magical spells is increased by up to (%d+).",
	["Increases healing done by magical spells by up to (%d+) for 3600 sec."] = "Increases healing done by magical spells by up to (%d+) for 3600 sec.",
	["Healing increased by up to (%d+)."] = "Healing increased by up to (%d+).",
	["Healing spells increased by up to (%d+)."] = "Healing spells increased by up to (%d+).",
	["Chance to hit reduced by (%d+)%%."] = "Chance to hit reduced by (%d+)%%.",
	["Chance to hit decreased by (%d+)%% and %d+ Nature damage every %d+ sec."] = "Chance to hit decreased by (%d+)%% and %d+ Nature damage every %d+ sec.",
	["Lowered chance to hit."] = "Lowered chance to hit.", -- 5917	Fumble (25%)
	["Increases hitpoints by 300. 15%% haste to melee attacks. (%d+) mana regen every 5 seconds."] = "Increases hitpoints by 300. 15%% haste to melee attacks. (%d+) mana regen every 5 seconds.",
	["Restores (%d+) mana per 5 sec."] = "Restores (%d+) mana per 5 sec.",
	["Regenerating (%d+) Mana every 5 seconds."] = "Regenerating (%d+) Mana every 5 seconds.",
	["Regenerate (%d+) mana per 5 sec."] = "Regenerate (%d+) mana per 5 sec.",
	["Mana Regeneration increased by (%d+) every 5 seconds."] = "Mana Regeneration increased by (%d+) every 5 seconds.",
	["Improves your chance to hit by (%d+)%%."] = "Improves your chance to hit by (%d+)%%.",
	["Chance for a critical hit with a spell increased by (%d+)%%."] = "Chance for a critical hit with a spell increased by (%d+)%%.",
	["While active, target's critical hit chance with spells and attacks increases by 10%%."] = "While active, target's critical hit chance with spells and attacks increases by 10%%.", --??
	["Increases attack power by %d+ and chance to hit by (%d+)%%."] = "Increases attack power by %d+ and chance to hit by (%d+)%%.",
	["Holy spell critical hit chance increased by (%d+)%%."] = "Holy spell critical hit chance increased by (%d+)%%.",
	["Destruction spell critical hit chance increased by (%d+)%%."] = "Destruction spell critical hit chance increased by (%d+)%%.",
	["Arcane spell critical hit chance increased by (%d+)%%.\r\nArcane spell critical hit damage increased by (%d+)%%."] = "Arcane spell critical hit chance increased by (%d+)%%.\r\nArcane spell critical hit damage increased by (%d+)%%.",
	["Spell hit chance increased by (%d+)%%."] = "Spell hit chance increased by (%d+)%%.",
	["Agility increased by 25, Critical hit chance increases by (%d)%%."] = "Agility increased by 25, Critical hit chance increases by (%d)%%.",
	["Increases chance for a melee, ranged, or spell critical by (%d+)%% and all attributes by %d+."] = "Increases chance for a melee, ranged, or spell critical by (%d+)%% and all attributes by %d+.",
	["Spell critical-hit chance reduced by (%d+)%%."] = "Spell critical-hit chance reduced by (%d+)%%.",
	["Increases critical chance of spells by 10%%, melee and ranged by 5%% and grants 140 attack power. 120 minute duration."] = "Increases critical chance of spells by 10%%, melee and ranged by 5%% and grants 140 attack power. 120 minute duration.",
	["Critical strike chance with spells and melee attacks increased by (%d+)%%."] = "Critical strike chance with spells and melee attacks increased by (%d+)%%.",
	["Increases ranged and melee critical chance by (%d+)%%."] = "Increases ranged and melee critical chance by (%d+)%%.",
	["Equip: Increases the critical chance provided by Leader of the Pack and Moonkin Aura by (%d)%%."] = "Equip: Increases the critical chance provided by Leader of the Pack and Moonkin Aura by (%d)%%.",
	["Your damage and healing done by magical spells and effects is increased by up to (%d+)"] = "Your damage and healing done by magical spells and effects is increased by up to (%d+)",
	["Spell damage and healing increased by up to (%d+)"] = "Spell damage and healing increased by up to (%d+)",

	-- druid
	["Increases the damage and critical strike chance of your Moonfire spell by (%d+)%%."] = "Increases the damage and critical strike chance of your Moonfire spell by (%d+)%%.",
	["Increases the critical effect chance of your Regrowth spell by (%d+)%%."] = "Increases the critical effect chance of your Regrowth spell by (%d+)%%.",
	["Moonkin Aura"] = "Moonkin Aura",
	["Moonkin Form"] = "Moonkin Form",
	["Tree of Life Form"] = "Tree of Life Form",
	["Tree of Life Aura"] = "Tree of Life Aura",
	["Mana regeneration increased by (%d+)%%.  (%d+)%% Mana regeneration may continue while casting."] = "Mana regeneration increased by (%d+)%%.  (%d+)%% Mana regeneration may continue while casting.",
	["Also increases chance to hit with melee attacks and spells by (%d+)%%."] = "Also increases chance to hit with melee attacks and spells by (%d+)%%.",

	-- paladin
	["Increases healing done by spells and effects by up to (%d+)%% of your Armor from items"] = "Increases healing done by spells and effects by up to (%d+)%% of your Armor from items",
	["Increases the critical effect chance of your Holy Light and Flash of Light by (%d+)%%."] = "Increases the critical effect chance of your Holy Light and Flash of Light by (%d+)%%.",
	["Improves your chance to get a critical strike with Holy Shock by (%d+)%%."] = "Improves your chance to get a critical strike with Holy Shock by (%d+)%%.",
	["Increases your chance to hit with melee attacks and spells by (%d+)%%."] = "Increases your chance to hit with melee attacks and spells by (%d+)%%.",
	["Increases your armor value from items by (%d+)%%."] = "Increases your armor value from items by (%d+)%%.",
	-- shaman
	["Increases the critical strike chance of your Lightning Bolt and Chain Lightning spells by an additional (%d+)%%."] = "Increases the critical strike chance of your Lightning Bolt and Chain Lightning spells by an additional (%d+)%%.",
	["Increases the critical effect chance of your healing and lightning spells by (%d+)%%."] = "Increases the critical effect chance of your healing and lightning spells by (%d+)%%.",
	["Elemental Mastery"] = "Elemental Mastery",
	["Increases your chance to hit with spells and melee attacks by (%d+)%%"] = "Increases your chance to hit with spells and melee attacks by (%d+)%%",
	["Increases your chance to hit with spells by (%d+)%%"] = "Increases your chance to hit with spells by (%d+)%%",

	-- warlock
	["Increases the critical strike chance of your Destruction spells by (%d+)%%."] = "Increases the critical strike chance of your Destruction spells by (%d+)%%.",
	["Increases the critical strike chance of your Searing Pain spell by (%d+)%%."] = "Increases the critical strike chance of your Searing Pain spell by (%d+)%%.",
	["Increases critical strike chance of Fire spells by (%d+)%%"] = "Increases critical strike chance of Fire spells by (%d+)%%",
	["Reduces the chance for enemies to resist your Affliction spells by (%d+)%%."] = "Reduces the chance for enemies to resist your Affliction spells by (%d+)%%.",
    ["Firestone"] = "Firestone",

	-- mage
	["Increases the critical strike chance of your Arcane Explosion and Arcane Missiles spells by an additional (%d+)%%."] = "Increases the critical strike chance of your Arcane Explosion and Arcane Missiles spells by an additional (%d+)%%.",
	["Increases the critical strike chance of your Fire Blast and Scorch spells by (%d+)%%."] = "Increases the critical strike chance of your Fire Blast and Scorch spells by (%d+)%%.",
	["Increases the critical strike chance of your Flamestrike spell by (%d+)%%."] = "Increases the critical strike chance of your Flamestrike spell by (%d+)%%.",
	["Increases the critical strike chance of your Fire spells by (%d+)%%."] = "Increases the critical strike chance of your Fire spells by (%d+)%%.",
	["Increases the critical strike chance of all your spells against frozen targets by (%d+)%%."] = "Increases the critical strike chance of all your spells against frozen targets by (%d+)%%.",
	["Increases your spell damage and critical srike chance by (%d+)%%."] = "Increases your spell damage and critical srike chance by (%d+)%%.",
	["Increases critical strike chance from Fire damage spells by (%d+)%%."] = "Increases critical strike chance from Fire damage spells by (%d+)%%.",

	-- priest
	["Reduces the chance for enemies to resist your Holy and Discipline spells by (%d+)%%."] = "Reduces the chance for enemies to resist your Holy and Discipline spells by (%d+)%%.",
	["Increases the critical effect chance of your Holy and Discipline spells by (%d+)%%."] = "Increases the critical effect chance of your Holy and Discipline spells by (%d+)%%.",
	["Increases your spell damage by %d+%% and the critical strike chance of your offensive spells by (%d)%%"] = "Increases your spell damage by %d+%% and the critical strike chance of your offensive spells by (%d)%%",
	["Increases your spell damage and the critical strike chance of your offensive spells by (%d+)%%"] = "Increases your spell damage and the critical strike chance of your offensive spells by (%d+)%%",
	["^Set: Improves your chance to get a critical strike with Holy spells by (%d)%%."] = "^Set: Improves your chance to get a critical strike with Holy spells by (%d)%%.",
	["^Set: Increases your chance of a critical hit with Prayer of Healing by (%d+)%%."] = "^Set: Increases your chance of a critical hit with Prayer of Healing by (%d+)%%.",
	["Inner Focus"] = "Inner Focus",
	["Increases the effects of your Inner Fire spell by (%d+)%%."] = "Increases the effects of your Inner Fire spell by (%d+)%%.",
	["Improved Shadowform"] = "Improved Shadowform",
	["Shadowform"] = "Shadowform",

	-- defense
	DEFENSE_TOOLTIP = [[|cffffffffDefense Skill|r]],
	DEFENSE_TOOLTIP_SUB = [[Higher defense makes you harder to hit and makes monsters less likely to land a crushing blow.]],

	PLAYER_DODGE_TOOLTIP = [[|cffffffffDodge|r]],
	PLAYER_DODGE_TOOLTIP_SUB = [[Your chance to dodge enemy melee attacks.
	Players can not dodge attacks from behind.]],

	PLAYER_PARRY_TOOLTIP = [[|cffffffffParry|r]],
	PLAYER_PARRY_TOOLTIP_SUB = [[Your chance to parry enemy melee attacks.
	Players and monsters can not parry attacks from behind.]],

	PLAYER_BLOCK_TOOLTIP = [[|cffffffffBlock|r]],
	PLAYER_BLOCK_TOOLTIP_SUB = [[Your chance to block enemy physical attacks with a shield.
	Players and monsters can not block attacks from behind.]],

	TOTAL_AVOIDANCE_TOOLTIP = [[|cffffffffAvoidance|r]],
	TOTAL_AVOIDANCE_TOOLTIP_SUB = [[Your total chance to avoid enemy physical attacks.]],

	-- melee
	MELEE_HIT_TOOLTIP = [[|cffffffffMelee Hit|r]],
	MELEE_HIT_TOOLTIP_SUB = [[Increases chance to hit with melee attacks.]],
	MELEE_CRIT_TOOLTIP = [[|cffffffffMelee Crit|r]],
	MELEE_CRIT_TOOLTIP_SUB = [[Your chance to land a critical strike with melee attacks.]],
	MELEE_WEAPON_SKILL_TOOLTIP = [[|cffffffffMelee Weapon Skill|r]],
	MELEE_WEAPON_SKILL_TOOLTIP_SUB = [[Higher weapon skill reduces your chance to miss and increases damage of your glancing blows, while using melee weapons.]],

	--boss
	MELEE_MISS_VS_BOSS_TOOLTIP = [[|cffffffffChance To Miss Boss(lvl 63)|r]],
	MELEE_MISS_VS_BOSS_TOOLTIP_SUB = [[Melee attack miss chance due to mob being higher level than you.]],
	MELEE_DODGE_VS_BOSS_TOOLTIP = [[|cffffffffChance Boss(lvl 63) Dodges|r]],
	MELEE_DODGE_VS_BOSS_TOOLTIP_SUB = [[The formula is 5%% dodge chance + (your weapon skill - 315) * 0.1%%.]],
	MELEE_GLANCE_VS_BOSS_TOOLTIP = [[|cffffffffPercent Glancing Damage vs Boss(lvl 63)|r]],
	MELEE_GLANCE_VS_BOSS_TOOLTIP_SUB = [[Against lvl 63 Boss you have a 40%% chance to do a glancing blow that does reduced damage.  The amount of damage reduction is based on your weapon skill but the formula is too complicated to show here.]],
	MELEE_CRIT_CAP_VS_BOSS_TOOLTIP = [[|cffffffffCritical Chance Cap|r]],
	MELEE_CRIT_CAP_VS_BOSS_TOOLTIP_SUB = [[A critical hit can only happen if an attack is not already a miss, dodged, or glancing.  This means your crit cap is (100%% - miss chance%% - dodge chance%% - glance chance%%).  Any crit chance you have over your crit cap is wasted.]],
	MELEE_EFF_CRIT_VS_BOSS_TOOLTIP = [[|cffffffffEffective Critical Chance|r]],
	MELEE_EFF_CRIT_VS_BOSS_TOOLTIP_SUB = [[If you are under your crit cap, this will match your normal crit chance.	If you are over your crit cap, this will be your crit cap.]],

	-- ranged
	RANGED_WEAPON_SKILL_TOOLTIP = [[|cffffffffRanged Weapon Skill|r]],
	RANGED_WEAPON_SKILL_TOOLTIP_SUB = [[Higher weapon skill reduces your chance to miss with a ranged weapon.]],
	RANGED_CRIT_TOOLTIP = [[|cffffffffRanged Crit|r]],
	RANGED_CRIT_TOOLTIP_SUB = [[Your chance to land a critical strike with ranged weapons.]],
	RANGED_HIT_TOOLTIP = [[|cffffffffRanged Hit|r]],
	RANGED_HIT_TOOLTIP_SUB = [[Increases chance to hit with ranged weapons.]],

	-- spells
	SPELL_HIT_TOOLTIP = [[|cffffffffSpell Hit|r]],
	SPELL_HIT_SECONDARY_TOOLTIP = [[|cffffffffSpell Hit (%d%%|cff20ff20+%d%% %s|r|cffffffff)|r]],
	SPELL_HIT_TOOLTIP_SUB = [[Increases chance to land a harmful spell.]],

	SPELL_CRIT_TOOLTIP = [[|cffffffffSpell Crit|r]],
	SPELL_CRIT_TOOLTIP_SUB = [[Your chance to land a critical strike with spells.]],

	SPELL_POWER_TOOLTIP = [[|cffffffffSpell Power %d|r]],
	SPELL_POWER_TOOLTIP_SUB = [[Increases damage done by spells and effects.]],
	SPELL_POWER_SECONDARY_TOOLTIP = [[|cffffffffSpell Power %d (%d|cff20ff20+%d %s|r|cffffffff)|r]],
	SPELL_POWER_SECONDARY_TOOLTIP_SUB = [[Increases damage done by spells and effects.]],

	SPELL_SCHOOL_TOOLTIP = [[|cffffffff%s Spell Power %s|r]],
	SPELL_SCHOOL_SECONDARY_TOOLTIP = [[|cffffffff%s Spell Power %d (%d|cff20ff20+%d|r|cffffffff)|r]],
	SPELL_SCHOOL_TOOLTIP_SUB = [[Increases damage done by %s spells and effects.]],

	SPELL_HEALING_POWER_TOOLTIP = [[|cffffffffHealing Power %d|r]],
	SPELL_HEALING_POWER_SECONDARY_TOOLTIP = [[|cffffffffHealing Power %d (%d|cff20ff20+%d|r|cffffffff)|r]],
	SPELL_HEALING_POWER_TOOLTIP_SUB = [[Increases healing done by spells and effects.]],

	SPELL_MANA_REGEN_TOOLTIP = [[|cffffffffMana Regeneration: %d |cffffffff(%d)|r]],
	SPELL_MANA_REGEN_TOOLTIP_SUB = [[Mana regen when not casting and (while casting).
	Mana regenerates every 2 seconds and the amount is dependent on your total spirit and MP5.
	Spirit Regen: %d
	Regen while casting: %d%%
	MP5 Regen: %d
	MP5 Regen (2s): %d]],

	SPELL_HASTE_TOOLTIP = "Spell Haste",
	SPELL_HASTE_TOOLTIP_SUB = "Reduces cast time of your spells.",

	PLAYERSTAT_BASE_STATS = "Base Stats",
	PLAYERSTAT_DEFENSES = "Defenses",
	PLAYERSTAT_DEFENSES_BOSS = "Defenses vs Boss",
	PLAYERSTAT_MELEE_COMBAT = "Melee",
	PLAYERSTAT_MELEE_BOSS = "Melee vs Boss",
	PLAYERSTAT_RANGED_COMBAT = "Ranged",
	PLAYERSTAT_SPELL_COMBAT = "Spell",
	PLAYERSTAT_SPELL_SCHOOLS = "Schools",
	WEAPON_SKILL_COLON = "Wep Skill:",
	MISS_CHANCE_COLON = "Miss %:",
	DODGE_CHANCE_COLON = "Dodge %:",
	GLANCE_REDUCTION_COLON = "Glance Dmg:",
	CRIT_CAP_COLON = "Crit Cap:",
	BOSS_CRIT_COLON = "Eff. Crit:",
	MELEE_HIT_RATING_COLON = "Hit Rating:",
	RANGED_HIT_RATING_COLON = "Hit Rating:",
	SPELL_HIT_RATING_COLON = "Hit Rating:",
	MELEE_CRIT_COLON = "Crit Chance:",
	RANGED_CRIT_COLON = "Crit Chance:",
	SPELL_CRIT_COLON = "Crit Chance:",
	MANA_REGEN_COLON = "Regen:",
	HEAL_POWER_COLON = "Healing:",
	HASTE_COLON = "Haste:",
	ARMOR_PEN_COLON = "Traget's armor reduction:",
	DODGE_COLON = DODGE .. ":",
	PARRY_COLON = PARRY .. ":",
	BLOCK_COLON = BLOCK .. ":",
	TOTAL_COLON = "Total:",
	SPELL_POWER_COLON = "Power:",
	SPELL_SCHOOL_ARCANE = "Arcane",
	SPELL_SCHOOL_FIRE = "Fire",
	SPELL_SCHOOL_FROST = "Frost",
	SPELL_SCHOOL_HOLY = "Holy",
	SPELL_SCHOOL_NATURE = "Nature",
	SPELL_SCHOOL_SHADOW = "Shadow",

	BLOCK_VALUE = "Block Value: %d",
	IRONCLAD = "Healing power from Ironclad: %d",

	HIT_FIRE = "Fire spells: %.f%%",
	HIT_FROST = "Frost spells: %.f%%",
	HIT_ARCANE = "Arcane spells: %.f%%",
	HIT_AFFLICTION = "Affliction spells: %.f%%",
	HIT_SHADOW = "Shadow spells: %.f%%",
	HIT_HOLY_DISC = "Holy and Discipline spells: %.f%%",
	SPELL_PEN = "Target's resistances reduction: %d",

	CRIT_MOONFIRE = "Moonfire: %.2f%%",
	CRIT_REGROWTH = "Regrowth: %.2f%%",
	CRIT_HOLYLIGHT = "Holy Light: %.2f%%",
	CRIT_FLASHOFLIGHT = "Flash of Light: %.2f%%",
	CRIT_HOLYSHOCK = "Holy Shock: %.2f%%",
	CRIT_SEARING = "Searing Pain: %.2f%%",
	CRIT_HEALING = "Healing spells: %.2f%%",
	CRIT_HOLY = "Holy spells: %.2f%%",
	CRIT_DISC = "Discipline spells: %.2f%%",
	CRIT_SHADOW = "Shadow spells: %.2f%%",
	CRIT_OFFENCE = "Offensive spells: %.2f%%",
	CRIT_PRAYER = "Prayer of Healing: %.2f%%",
	CRIT_ARCANE = "Arcane spells: %.2f%%",
	CRIT_FIRE = "Fire spells: %.2f%%",
	CRIT_FIREBLAST = "Fire Blast: %.2f%%",
	CRIT_SCORCH = "Scorch: %.2f%%",
	CRIT_FLAMESTRIKE = "Flamestrike: %.2f%%",
	CRIT_FROZEN = "Frozen targets: %.2f%%",
	CRIT_LIGHTNINGBOLT = "Lightning Bolt: %.2f%%",
	CRIT_CHAINLIGHTNING = "Chain Lightning: %.2f%%",
	CRIT_LIGHTNINGSHIELD = "Lightning Shield: %.2f%%",
	CRIT_FIREFROST = "Fire and Frost spells: %.2f%%",

	["Equip: Improves your chance to get a critical strike with missile weapons by (%d)%%."] = "Equip: Improves your chance to get a critical strike with missile weapons by (%d)%%.",
	["(%d)%% Spell Critical Strike"] = "(%d)%% Spell Critical Strike",

	["Increases spell critical chance by (%d)%%."] = "Increases spell critical chance by (%d)%%.",
	["Chance to get a critical strike with spells is increased by (%d+)%%"] = "Chance to get a critical strike with spells is increased by (%d+)%%",

	["Equip: Increases your spell damage by up to (%d+) and your healing by up to %d+."] = "Equip: Increases your spell damage by up to (%d+) and your healing by up to %d+.",
	["Equip: Increases your spell damage by up to %d+ and your healing by up to (%d+)."] = "Equip: Increases your spell damage by up to %d+ and your healing by up to (%d+).",
	["^Equip: Allows (%d+)%% of your Mana regeneration to continue while casting."] = "^Equip: Allows (%d+)%% of your Mana regeneration to continue while casting.",

	["Healing %+(%d+)"] = "Healing %+(%d+)",
	["Healing done is increased by up to (%d+)"] = "Healing done is increased by up to (%d+)",
	["Healing Bonus increased by (%d+)"] = "Healing Bonus increased by (%d+)",

	["Increases damage and healing done by magical spells and effects by up to (%d+)%."] = "Increases damage and healing done by magical spells and effects by up to (%d+)%.",
	["Magical damage dealt by spells and abilities is increased by up to (%d+)"] = "Magical damage dealt by spells and abilities is increased by up to (%d+)",
	["Increased damage done by magical spells and effects by (%d+)."] = "Increased damage done by magical spells and effects by (%d+).",
	["Increases healing done by magical spells and effects by up to (%d+)."] = "Increases healing done by magical spells and effects by up to (%d+).",
	["Improves your chance to hit and get a critical strike with spells by (%d+)%%"] = "Improves your chance to hit and get a critical strike with spells by (%d+)%%",
	["Increases damage done by magical spells and effects by up to (%d+)"] = "Increases damage done by magical spells and effects by up to (%d+)",

	["Restores (%d+) mana per 5 seconds."] = "Restores (%d+) mana per 5 seconds.",
	["Allows (%d+)%% of mana regeneration while casting."] = "Allows (%d+)%% of mana regeneration while casting.",

	-- Block value
	["(%d+) Block"] = "(%d+) Block",
	["Equip: Increases the block value of your shield by (%d+)."] = "Equip: Increases the block value of your shield by (%d+).",
	["Block Value %+(%d+)"] = "Block Value %+(%d+)",
	["amount of damage absorbed by your shield by (%d+)%%"] = "amount of damage absorbed by your shield by (%d+)%%",
	["increases the amount blocked by (%d+)%%"] = "increases the amount blocked by (%d+)%%",
	["increases block amount by (%d+)%%"] = "increases block amount by (%d+)%%",
	["Block value increased by (%d+)"] = "Block value increased by (%d+)",
	["Block Value increased by (%d+)"] = "Block Value increased by (%d+)",
	["^Stoneskin$"] = "^Stoneskin$",

	["to all party members"] = "to all party members",
	["Healing Bonus increased by (%d+)"] = "Healing Bonus increased by (%d+)",

	-- Haste
	["^Equip: Increases your attack and casting speed by (%d+)%%"] = "^Equip: Increases your attack and casting speed by (%d+)%%",
	["^Set: Increases your attack and casting speed by (%d+)%%"] = "^Set: Increases your attack and casting speed by (%d+)%%",
	["^Equip: Increases your casting speed by (%d+)%%"] = "^Equip: Increases your casting speed by (%d+)%%",
	["^Attack Speed %+(%d+)%%"] = "^Attack Speed %+(%d+)%%",
	["^%+(%d+)%% Haste"] = "^%+(%d+)%% Haste",
	["Increases your total intellect by %d+%% and your spell casting speed by (%d+)%%"] = "Increases your total intellect by %d+%% and your spell casting speed by (%d+)%%",
	["Zeal increases your attack and casting speed by an additional (%d+)%% per stack"] = "Zeal increases your attack and casting speed by an additional (%d+)%% per stack",
	["^Increases attack speed by (%d+)%% and spell casting speed by (%d+)%%"] = "^Increases attack speed by (%d+)%% and spell casting speed by (%d+)%%",
	["^Increases attack and spell casting speed by (%d+)%%"] = "^Increases attack and spell casting speed by (%d+)%%",
	["Increases your melee attack speed by (%d+)%%"] = "Increases your melee attack speed by (%d+)%%",
	["increases casting speed by (%d+)%%"] = "increases casting speed by (%d+)%%",
	["^Increases casting and attack speed by (%d+)%%"] = "^Increases casting and attack speed by (%d+)%%",
	["^Increases attack and casting speed by (%d+)%%"] = "^Increases attack and casting speed by (%d+)%%",
	["^Casting speed increased by (%d+)%%"] = "^Casting speed increased by (%d+)%%",
	["^Attack and casting speed increased by (%d+)%%"] = "^Attack and casting speed increased by (%d+)%%",
	["^Increases your attack and casting speed by (%d+)%%"] = "^Increases your attack and casting speed by (%d+)%%", -- spell:28145
	["Increases your melee attack speed by (%d+)%%"] = "Increases your melee attack speed by (%d+)%%",

	-- Armor penetration
	["^Equip: Your attacks ignore (%d+) of the target's armor"] = "^Equip: Your attacks ignore (%d+) of the target's armor",
	["^Set: Your attacks ignore (%d+) of the target's armor"] = "^Set: Your attacks ignore (%d+) of the target's armor",
	["^Ignore (%d+) of enemies' armor"] = "^Ignore (%d+) of enemies' armor",
	["^Current target's armor is reduced by (%d+)"] = "^Current target's armor is reduced by (%d+)",
	["Causes your attacks to ignore (%d+) of your target's Armor per level"] = "Causes your attacks to ignore (%d+) of your target's Armor per level",
	["One-Handed Maces"] = "One-Handed Maces",
	["Two-Handed Maces"] = "Two-Handed Maces",

	-- Spell penetration
	["^Equip: Decreases the magical resistances of your spell targets by (%d+)"] = "^Equip: Decreases the magical resistances of your spell targets by (%d+)",
	["^Set: Decreases the magical resistances of your spell targets by (%d+)"] = "^Set: Decreases the magical resistances of your spell targets by (%d+)",
	["^%+(%d+) Spell Penetration"] = "^%+(%d+) Spell Penetration",


	["^Equip: Improves your chance to hit with spells and attacks by (%d+)%%"] = "^Equip: Improves your chance to hit with spells and attacks by (%d+)%%",
	["continue (%d+)%% of their Mana regeneration"] = "continue (%d+)%% of their Mana regeneration",

	-- Health regeneration
	["^Equip: Restores (%d+) health per 5 sec"] = "^Equip: Restores (%d+) health per 5 sec",
	["^Equip: Restores (%d+) health every 5 sec"] = "^Equip: Restores (%d+) health every 5 sec",
	["^Set: Restores (%d+) health per 5 sec"] = "^Set: Restores (%d+) health per 5 sec",
	["^Set: Restores (%d+) health every 5 sec"] = "^Set: Restores (%d+) health every 5 sec",

	-- General / Resistances / Extra categories
	PLAYERSTAT_GENERAL = "General",
	PLAYERSTAT_RESISTANCES = "Resistances",
	PLAYERSTAT_EXTRA = "Extra",

	HP_REGEN_COLON = "HP Regen:",
	MP5_COLON = "MP5:",
	MP5_CASTING_COLON = "MP5 Casting:",
	MOVE_SPEED_COLON = "Speed:",
	MELEE_HASTE_COLON = "Melee Haste:",
	SPELL_HASTE_COLON = "Spell Haste:",
	ARMOR_PEN_SHORT_COLON = "Armor Pen:",
	SPELL_PEN_COLON = "Spell Pen:",
	BLOCK_VALUE_COLON = "Block Value:",
	CRIT_TAKEN_COLON = "Crit Taken:",

	HEALTH_TOOLTIP = [[|cffffffffHealth %d / %d|r]],
	HEALTH_TOOLTIP_SUB = [[Your maximum health. Each point of Stamina gives 10 health (1 for each of the first 20).]],

	HP_REGEN_TOOLTIP = [[|cffffffffHealth Regeneration: %d |cffffffff(%d)|r]],
	HP_REGEN_TOOLTIP_SUB = [[Health regained every 2 seconds out of combat and (in combat).
From Spirit: %d
Health per 5 sec from gear: %d
Estimate from the vanilla Spirit formula. Sitting, food and buffs are not counted.]],

	MANA_TOOLTIP = [[|cffffffffMana %d / %d|r]],
	MANA_TOOLTIP_SUB = [[Your maximum mana. Each point of Intellect gives 15 mana (1 for each of the first 20).]],

	MP5_TOOLTIP = [[|cffffffffMana per 5 sec: %d|r]],
	MP5_TOOLTIP_SUB = [[Mana regained every 5 seconds while not casting (outside the five second rule).
From Spirit: %d
From gear and buffs: %d]],
	MP5_CASTING_TOOLTIP = [[|cffffffffMana per 5 sec while casting: %d|r]],
	MP5_CASTING_TOOLTIP_SUB = [[Mana regained every 5 seconds while casting (inside the five second rule).
From Spirit (%d%% keeps going): %d
From gear and buffs: %d]],

	MOVE_SPEED_TOOLTIP = [[|cffffffffMovement Speed %d%%|r]],
	MOVE_SPEED_TOOLTIP_SUB = [[Your run speed compared to normal (7 yards per second). Mounts and speed buffs count.
Run: %.1f yards per second
Swim: %d%%]],
	MOVE_SPEED_MISSING = [[|cffffffffMovement Speed|r]],
	MOVE_SPEED_MISSING_SUB = [[Reading movement speed needs ClassicAPI.dll (GetUnitSpeed).]],

	RESIST_TOOLTIP_SUB = [[Average damage of this school you resist:
vs level %d: %d%%
vs level %d (boss): %d%%]],

	MELEE_HASTE_TOOLTIP = [[|cffffffffMelee and Ranged Haste|r]],
	MELEE_HASTE_TOOLTIP_SUB = [[Makes your auto attacks faster. Counts gear, buffs and talents.]],
	SPELL_HASTE_LIVE = "Live value from ClassicAPI: %d%%",
	ARMOR_PEN_TOOLTIP = [[|cffffffffArmor Penetration|r]],
	ARMOR_PEN_TOOLTIP_SUB = [[Target armor ignored by your physical attacks.]],
	SPELL_PEN_TOOLTIP = [[|cffffffffSpell Penetration|r]],
	SPELL_PEN_TOOLTIP_SUB = [[Lowers the target's resistance to your spells.]],
	BLOCK_VALUE_TOOLTIP = [[|cffffffffBlock Value %d|r]],
	BLOCK_VALUE_TOOLTIP_SUB = [[Damage stopped by a successful block. Needs a shield.]],
	CRIT_TAKEN_TOOLTIP = [[|cffffffffChance a level %d boss crits you|r]],
	CRIT_TAKEN_TOOLTIP_SUB = [[5%% base, changed by 0.04%% for each point of the boss's weapon skill (%d) against your defense (%d). Talents and buffs that lower crit chance are not counted.]],
	CRIT_TAKEN_NEED = "%d more defense for crit immunity.",
	CRIT_TAKEN_IMMUNE = "Crit immune against bosses.",

	-- Enchant panel
	ENCHANTS_TITLE = "Enchants",
	ENCHANTS_BUTTON_TOOLTIP = "Enchants",
	ENCHANTS_BUTTON_TOOLTIP_SUB = "Show or hide the list of enchants on your gear.",
	ENCHANT_MISSING = "Not enchanted",
	ENCHANT_BUCKLE = "Buckle: %s",
	ENCHANT_NO_BUCKLE = "No buckle",
	ENCHANT_UNKNOWN = "Enchant #%d",
	ENCHANT_TEMP_UNKNOWN = "Temporary enchant",
	ENCHANTS_NONE = "No enchantable gear equipped.",
	ENCHANTS_SLASH_HELP = "/bcs enchants - show or hide the enchant panel",
	ENCHANTS_SLASH_HELP_INSPECT = "/bcs inspect - show or hide the enchant panel on the inspect window",
	ENCHANTS_INSPECT_TOOLTIP_SUB = "Show or hide the list of enchants on this player's gear.",
	ENCHANTS_INSPECT_ON = "Enchant panel on the inspect window: shown",
	ENCHANTS_INSPECT_OFF = "Enchant panel on the inspect window: hidden",

	-- Stats on the inspect window
	INSPECT_GEAR_NOTE = "Added up from their gear, enchants and set bonuses. Your client isn't sent other players' base stats, talents or buffs.",
	INSPECT_REAL_NOTE = "The client knows this value for this player.",
	INSPECT_RANGED_AP_COLON = "Ranged AP:",
	INSPECT_HP5_COLON = "HP5:",
	INSPECT_HP5_TOOLTIP = [[|cffffffffHealth per 5 sec: %d|r]],
	INSPECT_HP5 = "Health regained every 5 seconds from their gear, in and out of combat.",
	INSPECT_MP5 = "Mana regained every 5 seconds from their gear, while casting too. Spirit regen isn't included.",
	INSPECT_BLOCK_VALUE = "Block value from their shield and gear. Strength adds more.",
	INSPECT_HEALTH_REAL = "Their maximum health, as your group shares it.",
	INSPECT_HEALTH_GEAR = "Health their gear gives: 10 per point of Stamina plus health bonuses. Group members show their real maximum.",
	INSPECT_MANA_REAL = "Their maximum mana, as your group shares it.",
	INSPECT_MANA_GEAR = "Mana their gear gives: 15 per point of Intellect plus mana bonuses. Group members show their real maximum.",
	INSPECT_SPEED = "Their current run speed compared to normal (7 yards per second).",
	INSPECT_SCHOOL_TOOLTIP = "%s Spell Power",
}
