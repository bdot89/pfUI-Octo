-- GENERATED from UpsiRinse EncounterDB.lua (MIT, Otari - Upsilon fork) for OctoRinse (modules rinse.lua).
-- The encounter lists exactly as UpsiRinse ships them: zone -> bosses -> { debuff, school, note }.
pfUI.rinseData = { schools = { "Magic", "Curse", "Disease", "Poison", "Snare" } }

pfUI.rinseData.zones = {

{ zone = "Molten Core", zones = { "Molten Core" }, bosses = {
	{ name = "Lucifron", spells = {
		{ "Impending Doom", "Magic" },
		{ "Lucifron's Curse", "Curse" },
		{ "Dominate Mind", "Magic", "Cast by the Flamewaker Protectors" },
		{ "Thunderclap", "Magic", "Cast by the Flamewaker Protectors" },
	}},
	{ name = "Magmadar", spells = {
		{ "Panic", "Magic", "Fear effect, dispellable here" },
	}},
	{ name = "Basalthar & Smoldaris", spells = {} },
	{ name = "Garr", spells = {
		{ "Magma Shackles", "Magic", "Hidden by default" },
		{ "Immolate", "Magic", "Cast by the Firesworn adds" },
	}},
	{ name = "Baron Geddon", spells = {
		{ "Ignite Mana", "Magic", "Mana users only" },
	}},
	{ name = "Shazzrah", spells = {
		{ "Shazzrah's Curse", "Curse", "Doubles magic damage taken" },
	}},
	{ name = "Sulfuron Harbinger", spells = {
		{ "Immolate", "Magic", "Cast by the Flamewaker Priests" },
		{ "Shadow Word: Pain", "Magic", "Cast by the Flamewaker Priests" },
	}},
	{ name = "Golemagg the Incinerator", spells = {} },
	{ name = "Sorcerer-Thane Thaurissan", spells = {} },
	{ name = "Incindis", spells = {} },
	{ name = "Majordomo Executus", spells = {} },
	{ name = "Ragnaros", spells = {} },
	{ name = "Trash & Adds", spells = {
		{ "Ancient Dread", "Magic", "Ancient Core Hound" },
		{ "Ancient Despair", "Magic", "Ancient Core Hound" },
		{ "Cauterizing Flames", "Magic", "Ancient Core Hound" },
		{ "Withering Heat", "Magic", "Ancient Core Hound" },
		{ "Ancient Hysteria", "Curse", "Ancient Core Hound. Hidden for warriors and rogues by default" },
		{ "Soul Burn", "Magic", "Firelord, Lava Annihilator" },
		{ "Incite Flames", "Magic", "Firewalker" },
		{ "Wildfire", "Magic", "Shadowforge Blazeweaver" },
		{ "Shadow Word: Pain", "Magic", "Shadowforge Hierophant" },
		{ "Mind Flay", "Snare", "Shadowforge Hierophant" },
		{ "Fire Shield", "Magic" },
	}},
}},

{ zone = "Blackwing Lair", zones = { "Blackwing Lair" }, bosses = {
	{ name = "Razorgore the Untamed", spells = {
		{ "Greater Polymorph", "Magic", "Grethok the Controller" },
		{ "Slow", "Magic", "Grethok the Controller" },
	}},
	{ name = "Vaelastrasz the Corrupt", spells = {} },
	{ name = "Broodlord Lashlayer", spells = {} },
	{ name = "Firemaw", spells = {} },
	{ name = "Ebonroc", spells = {} },
	{ name = "Flamegor", spells = {} },
	-- Each Brood Affliction is a different school on purpose, so the encounter
	-- needs every kind of dispeller. Bronze is not dispellable at all.
	{ name = "Chromaggus", spells = {
		{ "Brood Affliction: Blue", "Magic" },
		{ "Brood Affliction: Black", "Curse" },
		{ "Brood Affliction: Red", "Disease" },
		{ "Brood Affliction: Green", "Poison" },
	}},
	{ name = "Nefarian", spells = {
		{ "Veil of Shadow", "Curse", "Blocks healing, decurse fast" },
		{ "Fear", "Magic", "Lord Victor Nefarius, phase one" },
		{ "Silence", "Magic", "Lord Victor Nefarius, phase one" },
	}},
	{ name = "Ezzel Darkbrewer", spells = {} },
	{ name = "Trash & Adds", spells = {
		{ "Greater Polymorph", "Magic", "Blackwing Spellbinder" },
		{ "Fire Shield", "Magic", "Death Talon Wyrmguard" },
		{ "Bottle of Poison", "Poison", "Blackwing Technician" },
		{ "Brood Power: Blue", "Magic", "Blue Drakonid" },
		{ "Mark of Flames", "Magic", "Death Talon Captain" },
		{ "Flame Shock", "Magic", "Death Talon Flamescale" },
		{ "Thunderclap", "Magic", "Enraged Felguard" },
		{ "Fire Shield", "Magic", "Twilight Geomancer" },
	}},
}},

{ zone = "Ahn'Qiraj Temple", zones = { "Ahn'Qiraj" }, bosses = {
	{ name = "The Prophet Skeram", spells = {} },
	{ name = "The Bug Family", spells = {
		{ "Toxic Volley", "Poison", "Lord Kri" },
		{ "Panic", "Magic", "Princess Yauj" },
		{ "Toxic Vapors", "Poison" },
		{ "Poison Cloud", "Poison" },
	}},
	{ name = "Battleguard Sartura", spells = {} },
	{ name = "Fankriss the Unyielding", spells = {} },
	{ name = "Viscidus", spells = {
		{ "Poison Bolt Volley", "Poison" },
	}},
	{ name = "Princess Huhuran", spells = {
		{ "Wyvern Sting", "Poison", "Blacklisted by default - deals heavy damage when dispelled" },
		{ "Noxious Poison", "Poison" },
	}},
	{ name = "The Twin Emperors", spells = {} },
	{ name = "Ouro", spells = {} },
	{ name = "C'Thun", spells = {
		{ "Mind Flay", "Snare", "Eye Tentacle" },
		{ "Hamstring", "Snare", "Claw Tentacle" },
	}},
	{ name = "Trash & Adds", spells = {
		{ "Thunderclap", "Magic", "Anubisath Sentinel" },
		{ "Plague", "Disease", "Anubisath Defender, Sentinel, Warder" },
		{ "Cause Insanity", "Magic", "Qiraji Brainwasher, Qiraji Mindslayer" },
		{ "Mind Flay", "Snare", "Qiraji Brainwasher, Qiraji Mindslayer" },
		{ "Crippling Poison", "Poison", "Vekniss Hive Crawler" },
		{ "Mind-numbing Poison", "Poison", "Vekniss Hive Crawler" },
		{ "Poison Bolt", "Poison", "Vekniss Hive Crawler" },
		{ "Vekniss Catalyst", "Poison", "Vekniss Wasp" },
	}},
}},

{ zone = "Ruins of Ahn'Qiraj", zones = { "Ruins of Ahn'Qiraj" }, bosses = {
	{ name = "Kurinnaxx", spells = {} },
	{ name = "General Rajaxx", spells = {} },
	{ name = "Moam", spells = {} },
	{ name = "Buru the Gorger", spells = {} },
	{ name = "Ayamiss the Hunter", spells = {
		{ "Paralyze", "Magic" },
	}},
	{ name = "Ossirian the Unscarred", spells = {
		{ "Curse of Tongues", "Curse" },
	}},
	{ name = "Trash & Adds", spells = {
		{ "Plague", "Disease", "Anubisath Guardian" },
		{ "Poison Bolt", "Poison", "Flesh Hunter" },
		{ "Venom Spit", "Poison", "Hive'Zara Soldier" },
		{ "Hive'Zara Catalyst", "Poison", "Hive'Zara Wasp" },
		{ "Thunderclap", "Magic", "Qiraji Warrior" },
	}},
}},

{ zone = "Naxxramas", zones = { "Naxxramas" }, bosses = {
	{ name = "Anub'Rekhan", spells = {} },
	{ name = "Grand Widow Faerlina", spells = {
		{ "Poison Bolt Volley", "Poison" },
	}},
	{ name = "Maexxna", spells = {
		{ "Necrotic Poison", "Poison" },
	}},
	{ name = "Noth the Plaguebringer", spells = {
		{ "Curse of the Plaguebringer", "Curse" },
		{ "Cripple", "Magic" },
	}},
	{ name = "Heigan the Unclean", spells = {
		{ "Decrepit Fever", "Disease" },
	}},
	{ name = "Loatheb", spells = {} },
	{ name = "Patchwerk", spells = {} },
	{ name = "Grobbulus", spells = {
		{ "Mutating Injection", "Disease", "Blacklisted by default - explodes when dispelled" },
	}},
	{ name = "Gluth", spells = {} },
	{ name = "Thaddius", spells = {} },
	{ name = "Instructor Razuvious", spells = {} },
	{ name = "Gothik the Harvester", spells = {} },
	{ name = "The Four Horsemen", spells = {} },
	{ name = "Sapphiron", spells = {
		{ "Life Drain", "Curse" },
	}},
	{ name = "Kel'Thuzad", spells = {
		{ "Frostbolt", "Magic" },
		{ "Detonate Mana", "Magic" },
	}},
	{ name = "Spider Wing Trash", spells = {
		{ "Poison Charge", "Poison", "Priority by default" },
		{ "Necrotic Poison", "Poison" },
		{ "Web", "Snare", "Crypt Guard" },
		{ "Mind Flay", "Snare", "Eye Stalk" },
	}},
	{ name = "Plague Wing Trash", spells = {
		{ "Retching Plague", "Disease", "Bile Retcher, Diseased Maggot" },
		{ "Putrid Bite", "Disease", "Plagued Bat" },
	}},
	{ name = "Construct Wing Trash", spells = {
		{ "Slime Bolt", "Poison", "Stitched Spewer" },
		{ "Embalming Cloud", "Disease" },
	}},
	{ name = "Military Wing Trash", spells = {
		{ "Veil of Darkness", "Curse", "Deathknight" },
		{ "Veil of Shadow", "Curse", "Dread Creeper" },
		{ "Cone of Cold", "Magic", "Necro Knight" },
		{ "Frost Nova", "Magic", "Necro Knight, Unholy Staff" },
		{ "Polymorph", "Magic", "Unholy Staff" },
		{ "Thunderclap", "Magic", "Skeletal Smith" },
		{ "Stomp", "Snare", "Spectral Horse" },
		{ "Drain Life", "Magic", "Spectral Rider" },
		{ "Fear", "Magic", "Spectral Trainee" },
	}},
}},

{ zone = "Zul'Gurub", zones = { "Zul'Gurub" }, bosses = {
	{ name = "High Priest Venoxis", spells = {
		{ "Holy Fire", "Magic" },
		{ "Venom Spit", "Poison" },
	}},
	{ name = "High Priestess Jeklik", spells = {
		{ "Mind Flay", "Snare" },
		{ "Shadow Word: Pain", "Magic" },
		{ "Sonic Burst", "Magic", "Silence" },
	}},
	{ name = "High Priestess Mar'li", spells = {
		{ "Drain Life", "Magic" },
		{ "Poison Bolt Volley", "Poison" },
		{ "Corrosive Poison", "Poison" },
		{ "Enveloping Webs", "Snare" },
	}},
	{ name = "High Priest Thekal", spells = {
		{ "Silence", "Magic", "Hidden for rogues by default" },
	}},
	{ name = "High Priestess Arlokk", spells = {
		{ "Shadow Word: Pain", "Magic" },
	}},
	{ name = "Bloodlord Mandokir", spells = {} },
	{ name = "Jin'do the Hexxer", spells = {
		{ "Delusions of Jin'do", "Curse", "Blacklisted by default" },
		{ "Hex", "Magic" },
	}},
	{ name = "Hakkar", spells = {
		{ "Cause Insanity", "Magic" },
		{ "Poisonous Blood", "Poison" },
	}},
	{ name = "Gahz'ranka", spells = {
		{ "Frost Breath", "Magic" },
	}},
	{ name = "Hazza'rah", spells = {
		{ "Sleep", "Magic" },
	}},
	{ name = "Gri'lek", spells = {} },
	{ name = "Renataki", spells = {} },
	{ name = "Wushoolay", spells = {} },
	{ name = "Trash & Adds", spells = {
		{ "Infected Bite", "Disease", "Gurubashi Bat Rider, Razzashi Raptor" },
		{ "Thunderclap", "Magic", "Gurubashi Berserker" },
		{ "Drain Life", "Magic", "Hakkari Blood Priest" },
		{ "Wyvern Sting", "Poison", "Hakkari Shadow Hunter" },
		{ "Hex", "Magic", "Hakkari Witch Doctor" },
		{ "Venom Spit", "Poison", "Razzashi Adder" },
		{ "Poison", "Poison", "Razzashi Cobra" },
		{ "Tranquilizing Poison", "Poison", "Razzashi Serpent. Priority by default" },
		{ "Fear", "Magic", "Soulflayer" },
		{ "Curse of the Elements", "Curse", "Voodoo Slave" },
		{ "Curse of Blood", "Curse", "Withered Mistress" },
		{ "Veil of Shadow", "Curse", "Withered Mistress" },
		{ "Tendon Rip", "Snare", "Zulian Crocolisk" },
	}},
}},

{ zone = "Onyxia's Lair", zones = { "Onyxia's Lair" }, bosses = {
	{ name = "Broodcommander Axelus", spells = {} },
	{ name = "Onyxia", spells = {} },
	{ name = "Trash & Adds", spells = {
		{ "Flame Lash", "Magic", "Onyxian Warder" },
	}},
}},

{ zone = "Karazhan Crypt", zones = { "Karazhan Crypt" }, bosses = {
	{ name = "Alarus", spells = {
		{ "Curse of the Plague Rat", "Curse" },
	}},
	{ name = "Archlich Enkhraz", spells = {
		{ "Chill Nova", "Magic" },
		{ "Consuming Shadows", "Magic" },
		{ "Fear", "Magic" },
		{ "Freeze", "Magic" },
	}},
	{ name = "Commander Andreon", spells = {
		{ "Banshee Curse", "Curse" },
	}},
	{ name = "Guard Captain Gort", spells = {
		{ "Banshee Curse", "Curse" },
	}},
	{ name = "Hivaxxis", spells = {
		{ "Paralyzing Poison", "Poison" },
		{ "Poison Mind", "Poison" },
		{ "Web Spray", "Snare" },
	}},
	{ name = "Trash & Adds", spells = {
		{ "Drowning Death", "Magic", "Drowned Sinner" },
		{ "Frostbolt", "Magic", "Forgotten Soul" },
		{ "Frost Nova", "Magic", "Forgotten Soul" },
		{ "Banshee Shriek", "Magic", "Forlorn Shrieker" },
		{ "Wailing Dead", "Curse", "Forlorn Shrieker" },
		{ "Putrid Bite", "Disease", "Ravenous Strigoi" },
		{ "Ghoul Plague", "Disease", "Rotten Zombie" },
		{ "Deadly Poison", "Poison", "Tomb Creeper" },
		{ "Web Explosion", "Snare", "Tomb Creeper" },
		{ "Veil of Shadow", "Curse", "Unseen Stalker" },
	}},
}},

{ zone = "Blackrock Spire", zones = { "Blackrock Spire" }, bosses = {
	{ name = "Pyroguard Emberseer", spells = {} },
	{ name = "Solakar Flamewreath", spells = {} },
	{ name = "The Beast", spells = {
		{ "Immolate", "Magic" },
	}},
	{ name = "General Drakkisath", spells = {
		{ "Thunderclap", "Magic" },
	}},
	{ name = "Warchief Rend Blackhand", spells = {
		{ "Freeze", "Magic", "Cast by Gyth" },
	}},
	{ name = "Trash & Adds", spells = {
		{ "Curse of Thorns", "Curse", "Blackhand Dreadweaver" },
		{ "Veil of Shadow", "Curse", "Blackhand Dreadweaver" },
		{ "Frost Nova", "Magic", "Blackhand Summoner" },
		{ "Frostbolt", "Magic", "Chromatic Whelp" },
		{ "Flame Buffet", "Magic", "Rage Talon Fire Tongue" },
		{ "Sacrifice", "Magic" },
	}},
}},

{ zone = "Karazhan - Lower", zones = { "Tower of Karazhan" }, bosses = {
	{ name = "Moroes", spells = {
		{ "Moroes Curse", "Curse", "Hidden for warriors and rogues by default" },
		{ "Smoke Bomb", "Magic", "Silence. Hidden for rogues by default" },
		{ "Agonizing Concussion", "Snare" },
	}},
	{ name = "Clawlord Howlfang", spells = {
		{ "Shadowbane Curse", "Curse" },
	}},
	{ name = "Brood Queen Araxxna", spells = {
		{ "Leeching Bite", "Poison" },
		{ "Brood Venom Volley", "Poison" },
		{ "Encasing Webs", "Snare" },
	}},
	{ name = "Grizikil", spells = {} },
	{ name = "Lord Blackwald II", spells = {
		{ "Blackwalds Boon", "Curse" },
	}},
	{ name = "Trash & Adds", spells = {
		{ "Phantom Scream", "Magic", "Phantom Servant. Silence" },
		{ "The Servant's Curse", "Curse", "Phantom Servant" },
		{ "Hamstring", "Snare", "Dark Rider Champion" },
		{ "Curse of Weakness", "Curse", "Phantom Guardsman" },
		{ "Frost Shock", "Magic", "Grellkin Primalist" },
		{ "Drain Mana", "Magic", "Grellkin Shadow Weaver" },
		{ "Leeching Bite", "Poison", "Skitterweb Crawler" },
		{ "Darkfang Venom", "Poison", "Skitterweb Darkfang" },
		{ "Brood Venom Volley", "Poison", "Skitterweb Venomfang" },
		{ "Corrosive Bolt", "Poison", "Skitterweb Venomfang" },
		{ "Fire Shield", "Magic" },
	}},
}},

{ zone = "Karazhan - Upper", zones = { "Tower of Karazhan" }, bosses = {
	{ name = "Anomalus", spells = {
		{ "Arcane Dampening", "Magic" },
		{ "Arcane Overload", "Magic", "Hidden by default" },
		{ "Arcane Prison", "Unknown" },
		{ "Manabound Strikes", "Unknown" },
	}},
	{ name = "Keeper Gnarlmoon", spells = {
		{ "Blue Moon", "Unknown" },
		{ "Red Moon", "Unknown" },
	}},
	{ name = "Ley-Watcher Incantagos", spells = {
		{ "Curse of Manascale", "Curse", "Hidden for warriors and rogues by default" },
		{ "Guided Ley-Beam", "Unknown" },
	}},
	{ name = "Rupturan the Broken", spells = {} },
	{ name = "Chess Event", spells = {
		{ "King's Curse", "Curse" },
		{ "Howl of Terror", "Magic", "Broken Rook" },
		{ "Charming Presence", "Magic" },
		{ "Dark Subservience", "Unknown" },
	}},
	{ name = "Echo of Medivh", spells = {
		{ "Arcane Focus", "Magic", "Priority by default - tank" },
		{ "Freezing Chill", "Magic", "Priority by default - tank" },
		{ "Corruption of Medivh", "Unknown" },
		{ "Doom of Medivh", "Unknown" },
	}},
	{ name = "Sanv Tas'dal", spells = {
		{ "Phase Shifted", "Magic", "Blacklisted by default" },
	}},
	{ name = "Mephistroth", spells = {
		{ "Dread of Outland", "Curse", "Blacklisted by default" },
		{ "Curse of Legion", "Curse", "Blacklisted by default" },
		{ "Shackles of the Legion", "Unknown" },
	}},
	{ name = "Kruul", spells = {
		{ "Mark of the Highlord", "Unknown" },
	}},
	{ name = "Trash & Adds", spells = {
		{ "Mana Buildup", "Magic", "Priority by default - dispel or the carrier explodes" },
		{ "Unstable Mana", "Magic", "Unstable Arcane Elemental. Blacklisted by default" },
		{ "Chilled", "Magic" },
		{ "Mind Flay", "Snare" },
		{ "Enveloped Flames", "Unknown", "Priority by default - shows up on pets too" },
		{ "Overflowing Arcana", "Unknown" },
		{ "Astral Insight", "Unknown" },
	}},
}},

{ zone = "Emerald Sanctum", zones = { "Emerald Sanctum", "The Emerald Sanctum" }, bosses = {
	{ name = "Erennius", spells = {
		{ "Poison Bolt Volley", "Poison" },
		{ "Wail of Erennius", "Magic", "Mass sleep" },
		{ "Howl of Erennius", "Unknown", "Silence" },
	}},
	{ name = "Solnius", spells = {
		{ "Sanctum Mind Decay", "Unknown", "Blacklisted by default" },
		{ "Poison Bolt Volley", "Poison" },
	}},
	{ name = "Trash & Adds", spells = {
		{ "Poison Bolt Volley", "Poison", "Sanctum Wyrm" },
		{ "Wyrmkins Venom", "Poison", "Sanctum Wyrmkin. Priority by default" },
		{ "Emerald Supression", "Unknown", "Sanctum Supressor" },
		{ "Dreamstate", "Unknown", "Sanctum Dreamer" },
	}},
}},

{ zone = "The Black Morass", zones = { "The Black Morass", "Black Morass" }, bosses = {
	{ name = "Chronar", spells = {
		{ "Incapacitating Shout", "Snare" },
	}},
	{ name = "Antnormi", spells = {} },
	{ name = "Epidamu", spells = {
		{ "Drain Mana", "Magic" },
	}},
	{ name = "Mossheart", spells = {
		{ "Moss Covered Hands", "Magic" },
		{ "Entangling Roots", "Magic" },
	}},
	{ name = "Rotmaw", spells = {
		{ "Contagion of Rot", "Disease" },
	}},
	{ name = "Drifting Avatar of Sand", spells = {} },
	{ name = "Time-Lord Epochronos", spells = {
		{ "Devouring Plague", "Magic" },
	}},
	{ name = "Trash & Adds", spells = {
		{ "Paralyzing Poison", "Poison", "Blackfang Tarantula" },
		{ "Poison", "Poison", "Darkwater Python" },
		{ "Darken Vision", "Magic", "Infinite Riftweaver" },
		{ "Amplify Flames", "Magic", "Echo of Kael'thas Sunstrider" },
	}},
}},

{ zone = "Timbermaw Hold", zones = { "Timbermaw Hold" }, bosses = {
	{ name = "Karrsh the Sentinel", spells = {
		{ "Seed of Corruption", "Magic", "Blacklisted by default - explodes when dispelled" },
	}},
	{ name = "Archdruid Kronn", spells = {
		{ "Dream Fever", "Disease" },
	}},
	{ name = "Chieftain Partath", spells = {} },
	{ name = "Peroth'arn", spells = {} },
	{ name = "Loktanag the Vile", spells = {
		{ "Infected Secretion", "Unknown" },
	}},
	{ name = "Ormanos the Cracked", spells = {} },
	{ name = "Rotgrowl", spells = {} },
	{ name = "Ursol", spells = {} },
}},

{ zone = "Dire Maul", zones = { "Dire Maul" }, bosses = {
	{ name = "King Gordok", spells = {} },
	{ name = "Captain Kromcrush", spells = {} },
}},

{ zone = "World Bosses", zones = {}, bosses = {
	{ name = "Azuregos", spells = {
		{ "Chill", "Magic", "Dispel the tank first" },
	}},
	{ name = "Lord Kazzak", spells = {
		{ "Mark of Kazzak", "Curse" },
		{ "Twisted Reflection", "Magic" },
	}},
	{ name = "Emeriss", spells = {
		{ "Volatile Infection", "Disease" },
		{ "Sleep", "Magic" },
	}},
	{ name = "Lethon", spells = {
		{ "Sleep", "Magic" },
	}},
	{ name = "Taerar", spells = {
		{ "Sleep", "Magic" },
		{ "Poison Cloud", "Poison" },
	}},
	{ name = "Ysondre", spells = {
		{ "Curse of Thorns", "Curse" },
		{ "Silence", "Magic", "Hidden for rogues by default" },
		{ "Sleep", "Magic" },
	}},
	{ name = "Concavius", spells = {
		{ "Piercing Shadow", "Curse" },
		{ "Veil of Shadow", "Curse" },
	}},
	{ name = "Nerubian Overseer", spells = {
		{ "Corrosive Poison", "Poison" },
		{ "Necrotic Poison", "Poison" },
		{ "Poison Cloud", "Poison" },
	}},
	{ name = "Atiesh", spells = {
		{ "Breath of Sargeras", "Curse", "Melee and hunters only" },
	}},
	{ name = "Ostarius", spells = {} },
	{ name = "Doctor Weavil", spells = {} },
	{ name = "Twilight Corrupter", spells = {} },
	{ name = "Dark Reaver of Karazhan", spells = {} },
}},

{ zone = "Unsorted", zones = {}, bosses = {
	{ name = "Not yet placed", spells = {
		{ "Tranquilizing Poison", "Poison", "Priority by default" },
		{ "Slowing Poison", "Poison", "Priority by default" },
		{ "Poison Mushroom", "Poison", "Blacklisted by default" },
		{ "Gastronomic Guilt", "Unknown", "Blacklisted by default" },
		{ "Curse of Recklessness", "Curse", "Blacklisted by default" },
		{ "Screams of the Past", "Unknown", "Hidden for rogues by default" },
		{ "Rift Entanglement", "Unknown", "Hidden for warlocks by default" },
		{ "Tainted Mind", "Unknown", "Hidden for warriors and rogues by default" },
		{ "Icicles", "Unknown", "Hidden by default" },
	}},
	{ name = "Snares (Hand of Freedom)", spells = {
		{ "Hamstring", "Snare" },
		{ "Wing Clip", "Snare" },
		{ "Mind Flay", "Snare" },
		{ "Web", "Snare" },
		{ "Enveloping Web", "Snare" },
		{ "Encasing Webs", "Snare" },
		{ "Surge of Mana", "Snare" },
		{ "Hooked Net", "Snare" },
	}},
	{ name = "Buffs & Consumables", spells = {
		{ "Dreamless Sleep", "Magic", "Hidden by default" },
		{ "Greater Dreamless Sleep", "Magic", "Hidden by default" },
		{ "Songflower Serenade", "Magic", "Hidden by default" },
		{ "Mol'dar's Moxie", "Magic", "Hidden by default" },
		{ "Fengus' Ferocity", "Magic", "Hidden by default" },
		{ "Slip'kik's Savvy", "Magic", "Hidden by default" },
		{ "Thunderfury", "Magic", "Hidden by default" },
	}},
}},

}
