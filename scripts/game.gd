extends Node
## Global singleton "Game": data tables (classes, skills, gear, monsters, biomes, dungeons, recipes),
## input map, combat helpers, save-file helpers.

const TILE = 16
const W = 240
const H = 240
const MAX_LEVEL = 100
const BAG_CAP = 40      # starting bag size
const BAG_MAX = 120
const BAG_STEP = 8
const STACK = 99
const SLOT_COUNT = 6

const ANIMS = ["idle", "walk", "run", "attack", "cast"]
const ANIM_FRAMES = {"idle": 2, "walk": 4, "run": 4, "attack": 4, "cast": 4}
const ANIM_FPS = {"idle": 3.0, "walk": 8.0, "run": 12.0, "attack": 14.0, "cast": 12.0}
const DIRS = ["down", "up", "side"]

const ELEMENTS = ["light", "dark", "fire", "water", "earth", "wind"]
const STATS = ["str", "vit", "int", "mind", "dex", "luck"]
const STAT_NAMES = {"str": "STR", "vit": "VIT", "int": "INT", "mind": "MIND", "dex": "DEX", "luck": "LUCK"}
const STAT_HELP = {
	"str": "Phy Atk, HP", "vit": "HP, Phy Def", "int": "Magic Atk, MP",
	"mind": "MP, Magic Def", "dex": "Attack / Casting Speed", "luck": "Crit Rate, Crit Dmg, Drop Rate",
}
const RARITY_NAMES = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical"]
const RARITY_MULT = [1.0, 1.25, 1.55, 1.9, 2.4, 3.0]
var RARITY_COLORS = [Color("#c8c8d0"), Color("#5fd35f"), Color("#4a9aff"), Color("#b060ff"), Color("#ff9a2a"), Color("#ff4a6a")]
var ELEM_COLOR = {"light": Color("#fff0a0"), "dark": Color("#9a5ae0"), "fire": Color("#ff8a2a"), "water": Color("#62b4f2"),
	"earth": Color("#c8a468"), "wind": Color("#b8f4ff"), "none": Color("#d0d0d8")}

# ------------------------------------------------------------------ classes
const CLASSES = {
	"warrior": {"name": "Warrior", "kind": "phy", "sheet": "res://assets/characters/warrior.png",
		"desc": "Sword & Shield. Tough melee fighter.\nHigh base STR.",
		"base": {"str": 14, "vit": 12, "int": 3, "mind": 4, "dex": 6, "luck": 5},
		"weapons": ["sword", "spear", "hammer"], "armors": ["heavy", "leather"], "start": ["sword", "heavy"]},
	"ranger": {"name": "Ranger", "kind": "phy", "sheet": "res://assets/characters/ranger.png",
		"desc": "Bow & Arrow. Long-range hunter.\nHigh base DEX.",
		"base": {"str": 5, "vit": 7, "int": 3, "mind": 5, "dex": 15, "luck": 9},
		"weapons": ["bow", "gun"], "armors": ["light", "leather"], "start": ["bow", "leather"]},
	"assassin": {"name": "Assassin", "kind": "phy", "sheet": "res://assets/characters/assassin.png",
		"desc": "Dagger. Fast, lethal burst melee.\nHigh base LUCK.",
		"base": {"str": 8, "vit": 6, "int": 3, "mind": 4, "dex": 10, "luck": 15},
		"weapons": ["dagger"], "armors": ["light", "leather"], "start": ["dagger", "light"]},
	"mage": {"name": "Mage", "kind": "mag", "sheet": "res://assets/characters/mage.png",
		"desc": "Wand / Grimoire. Elemental destruction.\nHigh base INT.",
		"base": {"str": 2, "vit": 5, "int": 16, "mind": 8, "dex": 6, "luck": 5},
		"weapons": ["wand", "grimoire"], "armors": ["robe", "light"], "start": ["wand", "robe"], "mp_regen_mult": 1.0},
	"priest": {"name": "Priest", "kind": "mag", "sheet": "res://assets/characters/priest.png",
		"desc": "Wand / Grimoire. Buffs, debuffs, holy light.\nHigh base MIND.",
		"base": {"str": 2, "vit": 7, "int": 8, "mind": 16, "dex": 5, "luck": 5},
		"weapons": ["wand", "grimoire"], "armors": ["robe", "light"], "start": ["grimoire", "robe"], "mp_regen_mult": 1.25},
}

# ------------------------------------------------------------------ skills
# type active/passive, kind phy/mag (which attack stat scales it), slot 0-3 = Q E R F, pos = [col,row] in the tree.
# Rank cap = 1 + (player level - lvl) / 3, up to max.  Damage multiplier = mult + per * (rank - 1).
var SKILLS = {
	# ---------------- Warrior
	"w_cleave": {"name": "Flame Cleave", "cls": "warrior", "type": "active", "elem": "fire", "kind": "phy", "max": 20, "lvl": 1, "req": [], "pos": [1, 0],
		"mana": 8, "cd": 3.0, "slot": 0, "mult": 1.8, "per": 0.12, "desc": "A burning sword arc that hits all enemies in front and sets them on fire."},
	"w_bash": {"name": "Shield Bash", "cls": "warrior", "type": "active", "elem": "earth", "kind": "phy", "max": 20, "lvl": 4, "req": [["w_cleave", 2]], "pos": [0, 1],
		"mana": 12, "cd": 6.0, "slot": 1, "mult": 1.3, "per": 0.09, "stun": 1.0, "desc": "Slams your shield into enemies ahead: heavy knockback and a stun."},
	"w_whirl": {"name": "Whirlwind", "cls": "warrior", "type": "active", "elem": "wind", "kind": "phy", "max": 20, "lvl": 10, "req": [["w_bash", 2]], "pos": [1, 2],
		"mana": 20, "cd": 10.0, "slot": 2, "mult": 0.75, "per": 0.05, "hits": 5, "desc": "Spin with your blade, striking everything around you five times."},
	"w_iron": {"name": "Iron Will", "cls": "warrior", "type": "passive", "elem": "none", "max": 20, "lvl": 2, "req": [], "pos": [2, 1],
		"bonus": {"hp_pct": 0.015, "phy_def_pct": 0.015}, "desc": "+1.5% max HP and +1.5% Phy Def per rank."},
	"w_berserk": {"name": "Berserker", "cls": "warrior", "type": "passive", "elem": "none", "max": 20, "lvl": 8, "req": [["w_iron", 2]], "pos": [2, 2],
		"bonus": {"phy_atk_pct": 0.015}, "low_bonus": {"phy_atk_pct": 0.02}, "desc": "+1.5% Phy Atk per rank, and +2% more per rank below half HP."},
	# ---------------- Ranger
	"r_pierce": {"name": "Piercing Shot", "cls": "ranger", "type": "active", "elem": "wind", "kind": "phy", "max": 20, "lvl": 1, "req": [], "pos": [1, 0],
		"mana": 8, "cd": 3.0, "slot": 0, "mult": 1.7, "per": 0.12, "desc": "A wind-charged arrow that pierces through every enemy in its path."},
	"r_rain": {"name": "Arrow Rain", "cls": "ranger", "type": "active", "elem": "water", "kind": "phy", "max": 20, "lvl": 4, "req": [["r_pierce", 2]], "pos": [0, 1],
		"mana": 18, "cd": 9.0, "slot": 1, "mult": 0.55, "per": 0.04, "ticks": 6, "radius": 50.0, "desc": "Call down a storm of arrows at the cursor for 3s. Slows enemies."},
	"r_volley": {"name": "Fire Volley", "cls": "ranger", "type": "active", "elem": "fire", "kind": "phy", "max": 20, "lvl": 10, "req": [["r_rain", 2]], "pos": [1, 2],
		"mana": 16, "cd": 7.0, "slot": 2, "mult": 0.9, "per": 0.06, "arrows": 5, "desc": "Loose a fan of five flaming arrows that ignite targets."},
	"r_eagle": {"name": "Eagle Eye", "cls": "ranger", "type": "passive", "elem": "none", "max": 20, "lvl": 2, "req": [], "pos": [2, 1],
		"bonus": {"crit_rate": 0.5, "crit_dmg": 1.0}, "desc": "+0.5% Crit Rate and +1% Crit Damage per rank."},
	"r_fleet": {"name": "Fleet Footed", "cls": "ranger", "type": "passive", "elem": "none", "max": 20, "lvl": 8, "req": [["r_eagle", 2]], "pos": [2, 2],
		"bonus": {"move_pct": 0.01, "aspd_pct": 0.012}, "desc": "+1% Move Speed and +1.2% Attack Speed per rank."},
	# ---------------- Assassin
	"a_shadow": {"name": "Shadow Strike", "cls": "assassin", "type": "active", "elem": "dark", "kind": "phy", "max": 20, "lvl": 1, "req": [], "pos": [1, 0],
		"mana": 10, "cd": 5.0, "slot": 0, "mult": 2.2, "per": 0.14, "desc": "Dash through the shadows toward the cursor, striking enemies on the way. Always crits."},
	"a_flurry": {"name": "Blade Flurry", "cls": "assassin", "type": "active", "elem": "wind", "kind": "phy", "max": 20, "lvl": 4, "req": [["a_shadow", 2]], "pos": [0, 1],
		"mana": 14, "cd": 7.0, "slot": 1, "mult": 0.5, "per": 0.035, "hits": 6, "desc": "Six lightning-fast cuts in front of you."},
	"a_smoke": {"name": "Smoke Bomb", "cls": "assassin", "type": "active", "elem": "dark", "kind": "phy", "max": 20, "lvl": 10, "req": [["a_flurry", 2]], "pos": [1, 2],
		"mana": 20, "cd": 14.0, "slot": 2, "mult": 0.0, "per": 0.0, "radius": 56.0, "dur": 4.0, "desc": "A smoke cloud slows and weakens enemies; you gain speed while inside."},
	"a_lethal": {"name": "Lethal Precision", "cls": "assassin", "type": "passive", "elem": "none", "max": 20, "lvl": 2, "req": [], "pos": [2, 1],
		"bonus": {"crit_rate": 0.5, "crit_dmg": 1.5}, "desc": "+0.5% Crit Rate and +1.5% Crit Damage per rank."},
	"a_veil": {"name": "Shadow Veil", "cls": "assassin", "type": "passive", "elem": "none", "max": 20, "lvl": 8, "req": [["a_lethal", 2]], "pos": [2, 2],
		"bonus": {"move_pct": 0.012, "aspd_pct": 0.012}, "desc": "+1.2% Move Speed and +1.2% Attack Speed per rank."},
	# ---------------- Mage
	"m_fire": {"name": "Fireball", "cls": "mage", "type": "active", "elem": "fire", "kind": "mag", "max": 20, "lvl": 1, "req": [], "pos": [1, 0],
		"mana": 12, "cd": 2.5, "slot": 0, "mult": 2.0, "per": 0.14, "radius": 38.0, "desc": "An exploding fireball. Burns everything in the blast."},
	"m_lance": {"name": "Ice Lance", "cls": "mage", "type": "active", "elem": "water", "kind": "mag", "max": 20, "lvl": 4, "req": [["m_fire", 2]], "pos": [0, 1],
		"mana": 14, "cd": 4.0, "slot": 1, "mult": 1.8, "per": 0.12, "desc": "A piercing lance of ice that slows every enemy it hits."},
	"m_meteor": {"name": "Meteor Strike", "cls": "mage", "type": "active", "elem": "earth", "kind": "mag", "max": 20, "lvl": 10, "req": [["m_lance", 2]], "pos": [1, 2],
		"mana": 34, "cd": 14.0, "slot": 2, "mult": 4.2, "per": 0.3, "radius": 54.0, "desc": "Call a meteor onto the cursor after a short delay. Huge area damage."},
	"m_arcane": {"name": "Arcane Mastery", "cls": "mage", "type": "passive", "elem": "none", "max": 20, "lvl": 2, "req": [], "pos": [2, 1],
		"bonus": {"mag_atk_pct": 0.015}, "desc": "+1.5% Magic Atk per rank."},
	"m_flow": {"name": "Mana Flow", "cls": "mage", "type": "passive", "elem": "none", "max": 20, "lvl": 8, "req": [["m_arcane", 2]], "pos": [2, 2],
		"bonus": {"mp_pct": 0.015, "mp_regen": 0.08}, "desc": "+1.5% max MP and +0.08 MP/s regeneration per rank."},
	# ---------------- Priest
	"p_smite": {"name": "Holy Smite", "cls": "priest", "type": "active", "elem": "light", "kind": "mag", "max": 20, "lvl": 1, "req": [], "pos": [1, 0],
		"mana": 10, "cd": 2.5, "slot": 0, "mult": 1.6, "per": 0.11, "heal": 0.3, "desc": "A bolt of light that smites a foe and heals you for part of the damage."},
	"p_bless": {"name": "Blessing", "cls": "priest", "type": "active", "elem": "light", "kind": "mag", "max": 20, "lvl": 4, "req": [["p_smite", 2]], "pos": [0, 1],
		"mana": 24, "cd": 25.0, "slot": 1, "mult": 0.0, "per": 0.0, "dur": 20.0, "desc": "BUFF: +Atk, +Def and HP regeneration for 20s."},
	"p_curse": {"name": "Curse of Frailty", "cls": "priest", "type": "active", "elem": "dark", "kind": "mag", "max": 20, "lvl": 10, "req": [["p_bless", 2]], "pos": [1, 2],
		"mana": 22, "cd": 14.0, "slot": 2, "mult": 0.4, "per": 0.03, "radius": 60.0, "dur": 5.0, "desc": "DEBUFF zone: enemies take +25% damage, deal 30% less, and rot."},
	"p_grace": {"name": "Divine Grace", "cls": "priest", "type": "passive", "elem": "none", "max": 20, "lvl": 2, "req": [], "pos": [2, 1],
		"bonus": {"mp_regen": 0.08, "heal_pct": 0.02}, "desc": "+0.08 MP/s and +2% healing power per rank."},
	"p_sanct": {"name": "Sanctuary", "cls": "priest", "type": "passive", "elem": "none", "max": 20, "lvl": 8, "req": [["p_grace", 2]], "pos": [2, 2],
		"bonus": {"hp_regen": 0.15, "mag_def_pct": 0.015}, "desc": "+0.15 HP/s and +1.5% Magic Def per rank."},
	# ---------------- Common (every class)
	"c_mend": {"name": "Mend", "cls": "common", "type": "active", "elem": "light", "kind": "mag", "max": 20, "lvl": 3, "req": [], "pos": [0, 1],
		"mana": 18, "cd": 15.0, "slot": 4, "mult": 0.0, "per": 0.0, "desc": "Heal over 4 seconds (scales with max HP, MIND and rank)."},
	"c_tough": {"name": "Toughness", "cls": "common", "type": "passive", "elem": "none", "max": 20, "lvl": 1, "req": [], "pos": [2, 0],
		"bonus": {"hp_pct": 0.01}, "desc": "+1% max HP per rank."},
	"c_focus": {"name": "Focus", "cls": "common", "type": "passive", "elem": "none", "max": 20, "lvl": 1, "req": [], "pos": [2, 1],
		"bonus": {"mp_pct": 0.01}, "desc": "+1% max MP per rank."},
	"c_swift": {"name": "Swift Feet", "cls": "common", "type": "passive", "elem": "none", "max": 20, "lvl": 5, "req": [["c_tough", 1]], "pos": [3, 0],
		"bonus": {"move_pct": 0.008}, "desc": "+0.8% Move Speed per rank."},
	"c_fortune": {"name": "Fortune", "cls": "common", "type": "passive", "elem": "none", "max": 20, "lvl": 5, "req": [["c_focus", 1]], "pos": [3, 1],
		"bonus": {"drop_pct": 0.01, "luck": 0.5}, "desc": "+1% drop rate and +0.5 LUCK per rank."},
	"c_ward": {"name": "Elemental Ward", "cls": "common", "type": "passive", "elem": "none", "max": 20, "lvl": 10, "req": [["c_swift", 2], ["c_fortune", 2]], "pos": [3, 2],
		"bonus": {"res_all": 0.6}, "desc": "+0.6% resistance to every element per rank."},
}

# ------------------------------------------------------------------ gear
const WEAPONS = {
	"sword": {"name": "Sword", "kind": "phy", "atk": 12, "style": "swing", "cd": 0.5, "reach": 28.0, "arc": 1.1},
	"spear": {"name": "Spear", "kind": "phy", "atk": 13, "style": "thrust", "cd": 0.55, "reach": 42.0, "arc": 0.35},
	"hammer": {"name": "Hammer", "kind": "phy", "atk": 20, "style": "swing", "cd": 0.95, "reach": 28.0, "arc": 1.4, "smash": true},
	"dagger": {"name": "Dagger", "kind": "phy", "atk": 8, "style": "swing", "cd": 0.3, "reach": 22.0, "arc": 0.9},
	"wand": {"name": "Wand", "kind": "mag", "atk": 10, "style": "bolt", "cd": 0.4, "mana": 2, "proj": "arcane"},
	"grimoire": {"name": "Grimoire", "kind": "mag", "atk": 14, "style": "orb", "cd": 0.8, "mana": 4, "proj": "dark"},
	"bow": {"name": "Bow", "kind": "phy", "atk": 11, "style": "arrow", "cd": 0.5},
	"gun": {"name": "Gun", "kind": "phy", "atk": 16, "style": "bullet", "cd": 0.85},
}
const ARMORS = {
	"heavy": {"name": "Heavy Armor", "pdef": 14, "mdef": 4},
	"light": {"name": "Light Armor", "pdef": 8, "mdef": 8},
	"leather": {"name": "Leather Armor", "pdef": 10, "mdef": 6},
	"robe": {"name": "Robe", "pdef": 3, "mdef": 14, "mp": 12},
}
const ACCS = {
	"necklace": {"name": "Necklace", "base": {"hp": 25}},
	"ring": {"name": "Ring", "base": {"phy_atk": 3, "mag_atk": 3}},
	"bracelet": {"name": "Bracelet", "base": {"phy_def": 3, "mag_def": 3}},
}
const EQUIP_SLOTS = ["weapon", "armor", "necklace", "ring1", "ring2", "bracelet1", "bracelet2"]
const SLOT_NAMES = {"weapon": "Weapon", "armor": "Armor", "necklace": "Necklace", "ring1": "Ring", "ring2": "Ring", "bracelet1": "Bracelet", "bracelet2": "Bracelet"}

# Boss-dungeon unique gear: fixed stats (scaled by item level). 'boss' = boss id that drops it.
const UNIQUES = {
	"dragonfang_sword": {"name": "Dragonfang Greatsword", "sub": "sword", "elem": "fire", "boss": "inferno", "aff": {"str": 6, "phy_atk": 10, "crit_dmg": 8.0, "res_fire": 15.0}},
	"inferno_pistol": {"name": "Emberflare Pistol", "sub": "gun", "elem": "fire", "boss": "inferno", "aff": {"dex": 6, "phy_atk": 8, "crit_rate": 3.0, "atk_speed": 8.0}},
	"drakescale_plate": {"name": "Drakescale Plate", "sub": "heavy", "elem": "", "boss": "inferno", "aff": {"vit": 8, "phy_def": 14, "res_fire": 30.0, "hp": 60}},
	"heartwood_bow": {"name": "Heartwood Longbow", "sub": "bow", "elem": "earth", "boss": "treant", "aff": {"dex": 7, "phy_atk": 9, "crit_rate": 3.0, "hp": 40}},
	"verdant_robe": {"name": "Dryad's Verdant Robe", "sub": "robe", "elem": "", "boss": "treant", "aff": {"mind": 7, "mag_def": 14, "hp_regen": 0.6, "res_earth": 20.0}},
	"stalker_leathers": {"name": "Stalker's Leathers", "sub": "leather", "elem": "", "boss": "treant", "aff": {"dex": 6, "phy_def": 10, "move_speed": 6.0, "luck": 5}},
	"spore_grimoire": {"name": "Sporelord's Grimoire", "sub": "grimoire", "elem": "dark", "boss": "fungal", "aff": {"int": 8, "mag_atk": 12, "mp": 40, "res_dark": 15.0}},
	"mycelium_ring": {"name": "Mycelium Ring", "sub": "ring", "elem": "", "boss": "fungal", "aff": {"mind": 6, "mp_regen": 0.8, "crit_rate": 2.0, "mag_atk": 8}},
	"venomfang_dagger": {"name": "Venomfang Dagger", "sub": "dagger", "elem": "dark", "boss": "fungal", "aff": {"luck": 8, "phy_atk": 8, "crit_rate": 4.0, "crit_dmg": 10.0}},
	"kingsbane_spear": {"name": "Kingsbane Spear", "sub": "spear", "elem": "", "boss": "goblin_king", "aff": {"str": 7, "phy_atk": 10, "atk_speed": 6.0, "hp": 40}},
	"crown_pendant": {"name": "Goblin Crown Pendant", "sub": "necklace", "elem": "", "boss": "goblin_king", "aff": {"luck": 8, "drop": 12.0, "hp": 50, "phy_atk": 5}},
	"tidecaller_wand": {"name": "Tidecaller Wand", "sub": "wand", "elem": "water", "boss": "siren", "aff": {"int": 7, "mag_atk": 10, "atk_speed": 8.0, "res_water": 20.0}},
	"pearl_bracelet": {"name": "Siren's Pearl Bracelet", "sub": "bracelet", "elem": "", "boss": "siren", "aff": {"mind": 7, "mag_def": 10, "phy_def": 6, "mp": 30}},
	"windrunner_mail": {"name": "Windrunner Mail", "sub": "light", "elem": "", "boss": "siren", "aff": {"dex": 7, "phy_def": 8, "mag_def": 8, "move_speed": 8.0}},
	"titan_maul": {"name": "Titan Maul", "sub": "hammer", "elem": "earth", "boss": "golem", "aff": {"str": 9, "phy_atk": 14, "crit_dmg": 10.0, "res_earth": 20.0}},
	"stoneheart_amulet": {"name": "Stoneheart Amulet", "sub": "necklace", "elem": "", "boss": "golem", "aff": {"vit": 8, "hp": 90, "phy_def": 10, "res_earth": 25.0}},
}

# ------------------------------------------------------------------ stackable items
# cat: cons (potions) / food / mat / place
const ITEMS = {
	"wood": {"name": "Wood", "cat": "mat", "value": 2}, "stone": {"name": "Stone", "cat": "mat", "value": 2},
	"iron_ore": {"name": "Iron Ore", "cat": "mat", "value": 6}, "coal": {"name": "Coal", "cat": "mat", "value": 5},
	"iron_ingot": {"name": "Iron Ingot", "cat": "mat", "value": 20}, "hide": {"name": "Hide", "cat": "mat", "value": 6},
	"gel": {"name": "Slime Gel", "cat": "mat", "value": 4}, "herb": {"name": "Herb", "cat": "mat", "value": 4},
	"mushroom": {"name": "Mushroom", "cat": "mat", "value": 4}, "bone": {"name": "Bone", "cat": "mat", "value": 5},
	"wolf_fang": {"name": "Wolf Fang", "cat": "mat", "value": 12}, "tiger_claw": {"name": "Tiger Claw", "cat": "mat", "value": 18},
	"bear_pelt": {"name": "Bear Pelt", "cat": "mat", "value": 22}, "goblin_ear": {"name": "Goblin Ear", "cat": "mat", "value": 8},
	"ogre_tooth": {"name": "Ogre Tooth", "cat": "mat", "value": 25}, "rotten_flesh": {"name": "Rotten Flesh", "cat": "mat", "value": 4},
	"bark": {"name": "Ancient Bark", "cat": "mat", "value": 20}, "petal": {"name": "Dryad Petal", "cat": "mat", "value": 15},
	"lizard_scale": {"name": "Lizard Scale", "cat": "mat", "value": 14}, "mermaid_pearl": {"name": "Mermaid Pearl", "cat": "mat", "value": 35},
	"blood_vial": {"name": "Blood Vial", "cat": "mat", "value": 30}, "wyvern_wing": {"name": "Wyvern Wing", "cat": "mat", "value": 60},
	"dragon_scale": {"name": "Dragon Scale", "cat": "mat", "value": 120}, "phoenix_feather": {"name": "Phoenix Feather", "cat": "mat", "value": 150},
	"ember_core": {"name": "Ember Core", "cat": "mat", "value": 200}, "spore_core": {"name": "Spore Core", "cat": "mat", "value": 200},
	"siren_pearl": {"name": "Siren Pearl", "cat": "mat", "value": 200}, "goblin_crown": {"name": "Goblin Crown", "cat": "mat", "value": 150},
	"heartwood": {"name": "Heartwood", "cat": "mat", "value": 120}, "golem_core": {"name": "Golem Core", "cat": "mat", "value": 180},
	"potion_hp_1": {"name": "Minor Health Potion", "cat": "cons", "use": "hp", "pct": 0.30, "value": 15},
	"potion_hp_2": {"name": "Health Potion", "cat": "cons", "use": "hp", "pct": 0.60, "value": 45},
	"potion_hp_3": {"name": "Greater Health Potion", "cat": "cons", "use": "hp", "pct": 1.0, "value": 120},
	"potion_mp_1": {"name": "Minor Mana Potion", "cat": "cons", "use": "mp", "pct": 0.30, "value": 15},
	"potion_mp_2": {"name": "Mana Potion", "cat": "cons", "use": "mp", "pct": 0.60, "value": 45},
	"potion_mp_3": {"name": "Greater Mana Potion", "cat": "cons", "use": "mp", "pct": 1.0, "value": 120},
	"meat": {"name": "Raw Meat", "cat": "food", "hunger": 8, "heal": 0.03, "value": 3},
	"cooked_meat": {"name": "Cooked Meat", "cat": "food", "hunger": 30, "heal": 0.10, "value": 10},
	"stew": {"name": "Hearty Stew", "cat": "food", "hunger": 50, "heal": 0.20, "buff": "well_fed", "value": 28},
	"mushroom_soup": {"name": "Mushroom Soup", "cat": "food", "hunger": 35, "heal": 0.10, "buff": "focused", "value": 24},
	"campfire": {"name": "Campfire Kit", "cat": "place", "value": 20},
	"book_t_fire": {"name": "Spell Book: Ember Burst", "cat": "book", "skill": "t_fire", "value": 400},
	"book_t_water": {"name": "Spell Book: Tidal Wave", "cat": "book", "skill": "t_water", "value": 400},
	"book_t_earth": {"name": "Spell Book: Rock Fall", "cat": "book", "skill": "t_earth", "value": 450},
	"book_t_wind": {"name": "Spell Book: Gale Slash", "cat": "book", "skill": "t_wind", "value": 450},
	"book_t_light": {"name": "Spell Book: Radiance", "cat": "book", "skill": "t_light", "value": 600},
	"book_t_dark": {"name": "Spell Book: Shadow Bolt", "cat": "book", "skill": "t_dark", "value": 600},
}
const HP_POTIONS = ["potion_hp_3", "potion_hp_2", "potion_hp_1"]
const MP_POTIONS = ["potion_mp_3", "potion_mp_2", "potion_mp_1"]
const FOODS = ["stew", "mushroom_soup", "cooked_meat", "meat"]
var FOOD_BUFFS = {
	"well_fed": {"name": "Well Fed", "t": 300.0, "mods": {"hp_pct": 0.10, "hp_regen": 0.5}},
	"focused": {"name": "Focused", "t": 300.0, "mods": {"mag_atk_pct": 0.05, "mp_regen": 0.6}},
}

# ------------------------------------------------------------------ crafting
# "needs": item -> count. "fire": needs a campfire nearby. "gear": forge a random-rarity weapon/armor/accessory.
const RECIPES = [
	{"name": "Iron Ingot", "out": "iron_ingot", "n": 1, "needs": {"iron_ore": 2, "coal": 1}, "fire": true},
	{"name": "Campfire Kit", "out": "campfire", "n": 1, "needs": {"wood": 5, "stone": 4}},
	{"name": "Cooked Meat", "out": "cooked_meat", "n": 1, "needs": {"meat": 1, "wood": 1}, "fire": true},
	{"name": "Hearty Stew", "out": "stew", "n": 1, "needs": {"meat": 2, "herb": 2, "mushroom": 1}, "fire": true},
	{"name": "Mushroom Soup", "out": "mushroom_soup", "n": 1, "needs": {"mushroom": 4, "herb": 1}, "fire": true},
	{"name": "Minor Health Potion", "out": "potion_hp_1", "n": 1, "needs": {"herb": 2, "gel": 1}},
	{"name": "Health Potion", "out": "potion_hp_2", "n": 1, "needs": {"herb": 4, "gel": 3}},
	{"name": "Greater Health Potion", "out": "potion_hp_3", "n": 1, "needs": {"herb": 10, "gel": 8, "phoenix_feather": 1}},
	{"name": "Minor Mana Potion", "out": "potion_mp_1", "n": 1, "needs": {"mushroom": 2, "gel": 1}},
	{"name": "Mana Potion", "out": "potion_mp_2", "n": 1, "needs": {"mushroom": 4, "gel": 3}},
	{"name": "Greater Mana Potion", "out": "potion_mp_3", "n": 1, "needs": {"mushroom": 8, "gel": 6, "mermaid_pearl": 1}},
	{"name": "Forge Sword", "gear": "sword", "needs": {"iron_ingot": 3, "wood": 1}, "fire": true},
	{"name": "Forge Spear", "gear": "spear", "needs": {"iron_ingot": 2, "wood": 3}, "fire": true},
	{"name": "Forge Hammer", "gear": "hammer", "needs": {"iron_ingot": 4, "stone": 4, "wood": 2}, "fire": true},
	{"name": "Forge Dagger", "gear": "dagger", "needs": {"iron_ingot": 2, "hide": 1}, "fire": true},
	{"name": "Carve Wand", "gear": "wand", "needs": {"wood": 3, "gel": 5}},
	{"name": "Bind Grimoire", "gear": "grimoire", "needs": {"hide": 3, "gel": 5, "herb": 3}},
	{"name": "Craft Bow", "gear": "bow", "needs": {"wood": 4, "hide": 2}},
	{"name": "Forge Gun", "gear": "gun", "needs": {"iron_ingot": 4, "coal": 3, "wood": 2}, "fire": true},
	{"name": "Forge Heavy Armor", "gear": "heavy", "needs": {"iron_ingot": 8, "hide": 2}, "fire": true},
	{"name": "Stitch Light Armor", "gear": "light", "needs": {"hide": 4, "iron_ingot": 2}},
	{"name": "Cure Leather Armor", "gear": "leather", "needs": {"hide": 8}},
	{"name": "Weave Robe", "gear": "robe", "needs": {"herb": 6, "gel": 4, "hide": 2}},
	{"name": "Craft Necklace", "gear": "necklace", "needs": {"iron_ingot": 2, "gel": 2}, "fire": true},
	{"name": "Forge Ring", "gear": "ring", "needs": {"iron_ingot": 2, "stone": 2}, "fire": true},
	{"name": "Forge Bracelet", "gear": "bracelet", "needs": {"iron_ingot": 3, "hide": 1}, "fire": true},
]

# ------------------------------------------------------------------ monsters
# hp/dmg are BASE values scaled by level (mob_hp_scale / mob_dmg_scale) and tier. def is a multiplier of mob_def(level).
# abil: dash (pounce / swoop), slam (ground pound), ranged, breath (fire fan), poison (contact poison), drain (lifesteal)
const MOBS = {
	"slime": {"name": "Slime", "hp": 30, "dmg": 8, "def": 0.5, "speed": 24, "aggro": 85, "mode": "hostile", "xp": 1.0, "radius": 7, "sheet": "res://assets/mobs/slime.png", "fw": 32, "fps": 6,
		"hop": true, "elem": "water", "res": {"fire": -20}, "abil": [], "magic": false, "tier": 0.8, "gold": 0.8,
		"loot": [["gel", 0.8]]},
	"wolf": {"name": "Wolf", "hp": 45, "dmg": 9, "def": 0.8, "speed": 56, "aggro": 115, "mode": "hostile", "xp": 1.3, "radius": 8, "sheet": "res://assets/mobs/wolf.png", "fw": 32, "fps": 9,
		"hop": false, "elem": "", "res": {}, "abil": [], "magic": false, "tier": 1.0, "gold": 1.0,
		"loot": [["wolf_fang", 0.5], ["hide", 0.4], ["meat", 0.5]]},
	"tiger": {"name": "Tiger", "hp": 70, "dmg": 12, "def": 0.9, "speed": 58, "aggro": 120, "mode": "hostile", "xp": 1.8, "radius": 9, "sheet": "res://assets/mobs/tiger.png", "fw": 32, "fps": 9,
		"hop": false, "elem": "", "res": {}, "abil": ["dash"], "magic": false, "tier": 1.3, "gold": 1.3,
		"loot": [["tiger_claw", 0.5], ["meat", 0.5], ["hide", 0.3]]},
	"bear": {"name": "Bear", "hp": 110, "dmg": 13, "def": 1.2, "speed": 40, "aggro": 100, "mode": "hostile", "xp": 2.0, "radius": 10, "sheet": "res://assets/mobs/bear.png", "fw": 32, "fps": 7,
		"hop": false, "elem": "earth", "res": {"earth": 20}, "abil": ["slam"], "magic": false, "tier": 1.5, "gold": 1.4,
		"loot": [["bear_pelt", 0.5], ["meat", 0.5], ["hide", 0.4]]},
	"goblin": {"name": "Goblin", "hp": 40, "dmg": 9, "def": 0.7, "speed": 38, "aggro": 105, "mode": "hostile", "xp": 1.2, "radius": 7, "sheet": "res://assets/mobs/goblin.png", "fw": 32, "fps": 7,
		"hop": false, "elem": "", "res": {}, "abil": [], "magic": false, "tier": 1.0, "gold": 1.5,
		"loot": [["goblin_ear", 0.6], ["iron_ore", 0.3], ["wood", 0.3], ["coal", 0.2]]},
	"ogre": {"name": "Ogre", "hp": 140, "dmg": 15, "def": 1.3, "speed": 32, "aggro": 95, "mode": "hostile", "xp": 2.4, "radius": 11, "sheet": "res://assets/mobs/ogre.png", "fw": 32, "fps": 6,
		"hop": false, "elem": "earth", "res": {"earth": 15}, "abil": ["slam"], "magic": false, "tier": 1.7, "gold": 1.8,
		"loot": [["ogre_tooth", 0.5], ["iron_ore", 0.4], ["stone", 0.4]]},
	"skeleton": {"name": "Skeleton", "hp": 55, "dmg": 10, "def": 1.0, "speed": 40, "aggro": 110, "mode": "hostile", "xp": 1.5, "radius": 8, "sheet": "res://assets/mobs/skeleton.png", "fw": 32, "fps": 7,
		"hop": false, "elem": "dark", "res": {"dark": 30, "light": -40, "fire": -10}, "abil": [], "magic": false, "tier": 1.1, "gold": 1.1,
		"loot": [["bone", 0.8], ["iron_ore", 0.2]]},
	"zombie": {"name": "Zombie", "hp": 80, "dmg": 10, "def": 0.8, "speed": 26, "aggro": 90, "mode": "hostile", "xp": 1.5, "radius": 8, "sheet": "res://assets/mobs/zombie.png", "fw": 32, "fps": 5,
		"hop": false, "elem": "dark", "res": {"dark": 30, "light": -40, "fire": -20}, "abil": ["poison"], "magic": false, "tier": 1.2, "gold": 1.0,
		"loot": [["rotten_flesh", 0.7], ["bone", 0.3]]},
	"treant": {"name": "Treant", "hp": 130, "dmg": 12, "def": 1.3, "speed": 28, "aggro": 95, "mode": "hostile", "xp": 2.2, "radius": 10, "sheet": "res://assets/mobs/treant_s.png", "fw": 32, "fps": 5,
		"hop": false, "elem": "earth", "res": {"earth": 30, "water": 30, "fire": -40}, "abil": ["slam"], "magic": false, "tier": 1.6, "gold": 1.4,
		"loot": [["bark", 0.7], ["wood", 0.8], ["herb", 0.4]]},
	"dryad": {"name": "Dryad", "hp": 60, "dmg": 11, "def": 0.6, "speed": 40, "aggro": 130, "mode": "hostile", "xp": 1.7, "radius": 7, "sheet": "res://assets/mobs/dryad.png", "fw": 32, "fps": 7,
		"hop": false, "elem": "earth", "res": {"earth": 20, "fire": -30}, "abil": ["ranged"], "proj": "thorn", "magic": true, "tier": 1.2, "gold": 1.2,
		"loot": [["petal", 0.6], ["herb", 0.7]]},
	"lizard": {"name": "Lizardman", "hp": 60, "dmg": 11, "def": 1.0, "speed": 44, "aggro": 105, "mode": "hostile", "xp": 1.5, "radius": 8, "sheet": "res://assets/mobs/lizard.png", "fw": 32, "fps": 8,
		"hop": false, "elem": "fire", "res": {"fire": 20, "water": -20}, "abil": ["poison"], "magic": false, "tier": 1.1, "gold": 1.1,
		"loot": [["lizard_scale", 0.6], ["meat", 0.3]]},
	"mermaid": {"name": "Mermaid", "hp": 55, "dmg": 11, "def": 0.6, "speed": 36, "aggro": 130, "mode": "hostile", "xp": 1.7, "radius": 7, "sheet": "res://assets/mobs/mermaid.png", "fw": 32, "fps": 6,
		"hop": false, "elem": "water", "res": {"water": 40, "wind": -30}, "abil": ["ranged"], "proj": "water", "magic": true, "tier": 1.2, "gold": 1.3, "water": true,
		"loot": [["mermaid_pearl", 0.4], ["gel", 0.4]]},
	"vampire": {"name": "Vampire", "hp": 90, "dmg": 13, "def": 0.9, "speed": 52, "aggro": 125, "mode": "hostile", "xp": 2.3, "radius": 8, "sheet": "res://assets/mobs/vampire.png", "fw": 32, "fps": 8,
		"hop": false, "elem": "dark", "res": {"dark": 40, "light": -50}, "abil": ["dash", "drain"], "magic": false, "tier": 1.5, "gold": 1.6,
		"loot": [["blood_vial", 0.5], ["bone", 0.2]]},
	"wyvern": {"name": "Wyvern", "hp": 120, "dmg": 15, "def": 1.0, "speed": 60, "aggro": 135, "mode": "hostile", "xp": 3.0, "radius": 12, "sheet": "res://assets/mobs/wyvern.png", "fw": 48, "fps": 8,
		"hop": false, "elem": "wind", "res": {"wind": 50, "earth": -30}, "abil": ["dash"], "magic": false, "tier": 2.0, "gold": 2.0,
		"loot": [["wyvern_wing", 0.5], ["lizard_scale", 0.4]]},
	"dragon": {"name": "Dragon", "hp": 300, "dmg": 20, "def": 1.5, "speed": 42, "aggro": 150, "mode": "hostile", "xp": 6.0, "radius": 15, "sheet": "res://assets/mobs/dragon.png", "fw": 48, "fps": 6,
		"hop": false, "elem": "fire", "res": {"fire": 60, "water": -20, "wind": -10}, "abil": ["breath", "slam"], "proj": "fire", "magic": true, "tier": 3.0, "gold": 4.0,
		"loot": [["dragon_scale", 0.9], ["coal", 0.6]]},
	"phoenix": {"name": "Phoenix", "hp": 160, "dmg": 16, "def": 0.8, "speed": 56, "aggro": 150, "mode": "hostile", "xp": 4.0, "radius": 10, "sheet": "res://assets/mobs/phoenix.png", "fw": 32, "fps": 9,
		"hop": false, "elem": "fire", "res": {"fire": 80, "water": -30, "light": 20}, "abil": ["ranged"], "proj": "fire", "magic": true, "tier": 2.2, "gold": 2.5,
		"loot": [["phoenix_feather", 0.8], ["coal", 0.3]]},
	"deer": {"name": "Deer", "hp": 30, "dmg": 0, "def": 0.5, "speed": 58, "aggro": 0, "mode": "passive", "xp": 0.6, "radius": 8, "sheet": "res://assets/mobs/deer.png", "fw": 32, "fps": 9,
		"hop": false, "elem": "", "res": {}, "abil": [], "magic": false, "tier": 0.6, "gold": 0.0,
		"loot": [["meat", 1.0], ["hide", 0.7]]},
}

# ------------------------------------------------------------------ biomes (overworld) and dungeons
const TILE_BIOME = {2: "beach", 3: "plains", 4: "forest", 5: "plains", 6: "mountain", 7: "mushroom", 8: "volcanic", 9: "volcanic"}
const BIOMES = {
	"beach": {"name": "Beach", "lvl": 0, "mobs": {"lizard": 3, "mermaid": 3, "slime": 2, "deer": 1}, "dungeon": "beach"},
	"plains": {"name": "Plains", "lvl": 0, "mobs": {"slime": 4, "wolf": 3, "goblin": 3, "deer": 3, "ogre": 1, "tiger": 1}, "dungeon": "plains"},
	"forest": {"name": "Forest", "lvl": 3, "mobs": {"wolf": 3, "tiger": 2, "bear": 2, "treant": 2, "dryad": 2, "goblin": 2, "deer": 3}, "dungeon": "forest"},
	"mushroom": {"name": "Mushroom Grove", "lvl": 6, "mobs": {"zombie": 3, "slime": 3, "dryad": 2, "goblin": 2, "vampire": 1}, "dungeon": "mushroom"},
	"mountain": {"name": "Highlands", "lvl": 10, "mobs": {"bear": 2, "ogre": 3, "skeleton": 3, "vampire": 2, "wyvern": 1}, "dungeon": "cave"},
	"volcanic": {"name": "Volcanic Wastes", "lvl": 18, "mobs": {"lizard": 3, "skeleton": 2, "wyvern": 2, "dragon": 1, "phoenix": 1}, "dungeon": "lava"},
}
const DUNGEONS = {
	"lava": {"name": "Magma Cavern", "tile": 0, "boss": "inferno", "mobs": ["lizard", "skeleton", "wyvern", "phoenix", "ogre"], "mini": ["dragon", "ogre", "wyvern"], "color": "#ff6a20"},
	"forest": {"name": "Verdant Labyrinth", "tile": 1, "boss": "treant", "mobs": ["wolf", "bear", "treant", "dryad", "goblin", "tiger"], "mini": ["bear", "treant", "tiger"], "color": "#6ac060"},
	"mushroom": {"name": "Spore Warren", "tile": 2, "boss": "fungal", "mobs": ["slime", "zombie", "dryad", "goblin", "vampire"], "mini": ["zombie", "vampire", "dryad"], "color": "#c8a0ff"},
	"plains": {"name": "Overgrown Ruins", "tile": 3, "boss": "goblin_king", "mobs": ["slime", "wolf", "goblin", "ogre", "tiger"], "mini": ["ogre", "tiger", "goblin"], "color": "#fff0a0"},
	"beach": {"name": "Sunken Grotto", "tile": 4, "boss": "siren", "mobs": ["mermaid", "lizard", "skeleton", "slime", "zombie"], "mini": ["mermaid", "lizard", "skeleton"], "color": "#6ae0f0"},
	"cave": {"name": "Deep Cave", "tile": 5, "boss": "golem", "mobs": ["skeleton", "zombie", "vampire", "bear", "ogre"], "mini": ["ogre", "vampire", "bear"], "color": "#8aa8ff"},
}
# main bosses of the dungeons. attacks map to boss.gd (_atk_<name>). magic = their projectiles/zones are magic damage.
const BOSSES = {
	"inferno": {"name": "Infernal Drake Vulkar", "hp": 300, "dmg": 14, "def": 1.2, "speed": 44, "radius": 26, "aggro": 210, "leash": 540, "keep": 55, "cd": [1.8, 3.0],
		"attacks": ["breath", "meteors", "tailspin"], "sheet": "res://assets/mobs/boss_inferno.png", "elem": "fire", "magic": true, "res": {"fire": 80, "water": -30, "wind": -10},
		"mats": {"ember_core": [1, 2], "dragon_scale": [3, 5]}, "xp": 30.0, "hint": "Stay out of the flame fan and keep moving from the meteors."},
	"treant": {"name": "Elder Treant Morwen", "hp": 300, "dmg": 13, "def": 1.3, "speed": 30, "radius": 26, "aggro": 210, "leash": 540, "keep": 60, "cd": [2.2, 3.4],
		"attacks": ["roots", "thorns", "regrow"], "sheet": "res://assets/mobs/boss_treant.png", "elem": "earth", "magic": false, "res": {"fire": -40, "water": 40, "earth": 50},
		"mats": {"heartwood": [2, 4], "bark": [3, 5], "herb": [4, 8]}, "xp": 30.0, "hint": "Weak to fire. Burst it down when it tries to regrow."},
	"fungal": {"name": "Sporelord Mycelia", "hp": 300, "dmg": 13, "def": 1.0, "speed": 34, "radius": 26, "aggro": 210, "leash": 540, "keep": 55, "cd": [2.0, 3.2],
		"attacks": ["spores", "summon", "roots"], "summon": ["zombie", "slime"], "sheet": "res://assets/mobs/boss_fungal.png", "elem": "dark", "magic": true, "res": {"dark": 40, "light": -40, "fire": -30},
		"mats": {"spore_core": [1, 2], "mushroom": [5, 10], "rotten_flesh": [3, 6]}, "xp": 30.0, "hint": "Kill the minions fast. Light and fire hurt it."},
	"goblin_king": {"name": "Goblin King Grukk", "hp": 300, "dmg": 14, "def": 1.0, "speed": 52, "radius": 24, "aggro": 210, "leash": 540, "keep": 30, "cd": [2.0, 3.2],
		"attacks": ["charge", "summon", "slam"], "summon": ["goblin"], "sheet": "res://assets/mobs/boss_goblin_king.png", "elem": "", "magic": false, "res": {},
		"mats": {"goblin_crown": [1, 1], "iron_ingot": [2, 4], "goblin_ear": [4, 8]}, "xp": 25.0, "hint": "Dodge the charge line, then punish him while he is staggered."},
	"siren": {"name": "Siren Queen Thalassa", "hp": 300, "dmg": 13, "def": 0.9, "speed": 40, "radius": 24, "aggro": 210, "leash": 540, "keep": 70, "cd": [2.0, 3.2],
		"attacks": ["waterfan", "tidal", "summon"], "summon": ["mermaid"], "sheet": "res://assets/mobs/boss_siren.png", "elem": "water", "magic": true, "res": {"water": 70, "wind": -30, "earth": -20},
		"mats": {"siren_pearl": [1, 2], "mermaid_pearl": [2, 4], "gel": [4, 8]}, "xp": 28.0, "hint": "Stay out of the tide ring. Wind and earth hurt her."},
	"golem": {"name": "Stone Golem Brokk", "hp": 300, "dmg": 15, "def": 1.8, "speed": 34, "radius": 28, "aggro": 210, "leash": 540, "keep": 50, "cd": [2.2, 3.4],
		"attacks": ["boulders", "shockwave", "leap"], "sheet": "res://assets/mobs/boss_golem.png", "elem": "earth", "magic": false, "res": {"earth": 80, "wind": 30, "water": -10},
		"mats": {"golem_core": [1, 2], "iron_ore": [4, 8], "stone": [6, 12]}, "xp": 32.0, "hint": "Heavily armored. Keep moving: leaps and shockwaves are telegraphed."},
}

# ------------------------------------------------------------------ world props
var RES = {
	"oak": {"tex": "res://assets/world/tree_oak.png", "stump": "res://assets/world/stump.png", "hp": 9, "drops": {"wood": [2, 4]}, "radius": 8, "coll": 4, "respawn": 80.0, "xp": 2, "chip": Color(0.55, 0.38, 0.2)},
	"pine": {"tex": "res://assets/world/tree_pine.png", "stump": "res://assets/world/stump.png", "hp": 11, "drops": {"wood": [2, 5]}, "radius": 8, "coll": 4, "respawn": 90.0, "xp": 2, "chip": Color(0.45, 0.32, 0.18)},
	"palm": {"tex": "res://assets/world/tree_palm.png", "stump": "res://assets/world/stump.png", "hp": 8, "drops": {"wood": [2, 3]}, "radius": 7, "coll": 3, "respawn": 80.0, "xp": 2, "chip": Color(0.6, 0.48, 0.3)},
	"shroom": {"tex": "res://assets/world/tree_shroom.png", "stump": "res://assets/world/stump.png", "hp": 9, "drops": {"mushroom": [2, 4], "wood": [0, 2]}, "radius": 8, "coll": 4, "respawn": 80.0, "xp": 2, "chip": Color(0.7, 0.4, 0.9)},
	"dead": {"tex": "res://assets/world/tree_dead.png", "stump": "res://assets/world/stump.png", "hp": 10, "drops": {"wood": [2, 4], "coal": [0, 1]}, "radius": 7, "coll": 3, "respawn": 90.0, "xp": 2, "chip": Color(0.3, 0.22, 0.2)},
	"rock": {"tex": "res://assets/world/rock.png", "stump": "", "hp": 12, "drops": {"stone": [2, 4]}, "radius": 9, "coll": 7, "respawn": 120.0, "xp": 2, "chip": Color(0.7, 0.72, 0.78)},
	"iron": {"tex": "res://assets/world/iron_ore.png", "stump": "", "hp": 18, "drops": {"iron_ore": [1, 3]}, "radius": 9, "coll": 7, "respawn": 150.0, "xp": 5, "chip": Color(0.88, 0.57, 0.35)},
	"coal": {"tex": "res://assets/world/coal_ore.png", "stump": "", "hp": 15, "drops": {"coal": [1, 3]}, "radius": 9, "coll": 7, "respawn": 150.0, "xp": 4, "chip": Color(0.2, 0.2, 0.24)},
	"herb": {"tex": "res://assets/world/herb_bush.png", "stump": "", "hp": 2, "drops": {"herb": [1, 3]}, "radius": 5, "coll": 0, "respawn": 70.0, "xp": 1, "chip": Color(0.3, 0.7, 0.3)},
	"mushpatch": {"tex": "res://assets/world/mushroom_patch.png", "stump": "", "hp": 2, "drops": {"mushroom": [1, 3]}, "radius": 5, "coll": 0, "respawn": 70.0, "xp": 1, "chip": Color(0.8, 0.4, 0.6)},
}

const FX = {
	"fire": ["res://assets/spells/fire_hit.png", 48, 48, 5, 14.0, false], "water": ["res://assets/spells/water_hit.png", 48, 48, 5, 14.0, false],
	"earth": ["res://assets/spells/earth_hit.png", 48, 48, 5, 14.0, false], "wind": ["res://assets/spells/wind_hit.png", 48, 48, 5, 14.0, false],
	"light": ["res://assets/spells/light_hit.png", 48, 48, 5, 14.0, false], "dark": ["res://assets/spells/dark_hit.png", 48, 48, 5, 14.0, false],
	"slash": ["res://assets/spells/slash_hit.png", 48, 48, 5, 18.0, false], "spin": ["res://assets/spells/spin_hit.png", 64, 64, 6, 16.0, false],
	"bash": ["res://assets/spells/bash_hit.png", 48, 48, 5, 14.0, false], "aura": ["res://assets/spells/aura_hit.png", 48, 48, 6, 10.0, false],
	"zone": ["res://assets/spells/zone_hit.png", 64, 64, 6, 8.0, true], "heal": ["res://assets/spells/heal_hit.png", 32, 48, 6, 10.0, false],
	"rain": ["res://assets/spells/rain_hit.png", 64, 64, 6, 10.0, true], "smoke": ["res://assets/spells/smoke_hit.png", 64, 64, 6, 8.0, true],
}

# ------------------------------------------------------------------ NPCs (village traders)
const NPCS = {
	"guild": {"name": "Guildmaster Hale", "sign": "Adventurer Guild", "style": "knight", "pos": [-80, -72], "kind": "guild"},
	"gear": {"name": "Brannoc (Gear Shop)", "sign": "Gear Shop", "style": "warrior", "pos": [-176, -72], "kind": "shop", "gear": "random",
		"stock": ["iron_ingot", "coal", "iron_ore", "wood", "stone", "hide"], "buys": ["mat"], "rate": 0.5},
	"smith": {"name": "Gorn (Blacksmith)", "sign": "Blacksmith", "style": "smith", "pos": [80, -72], "kind": "smith"},
	"potion": {"name": "Elma (Potion Shop)", "sign": "Potion Shop", "style": "priest", "pos": [-80, 150], "kind": "shop", "gear": "none",
		"stock": ["potion_hp_1", "potion_hp_2", "potion_hp_3", "potion_mp_1", "potion_mp_2", "potion_mp_3", "herb", "gel"], "buys": ["cons"], "rate": 0.5},
	"food": {"name": "Mira (Food Shop)", "sign": "Food Shop", "style": "merchant", "pos": [80, 150], "kind": "shop", "gear": "none",
		"stock": ["meat", "cooked_meat", "stew", "mushroom_soup", "mushroom", "campfire"], "buys": ["food", "place"], "rate": 0.5},
	"artifact": {"name": "Vex (Artifact Shop)", "sign": "Artifact Shop", "style": "assassin", "pos": [176, -72], "kind": "shop", "gear": "limited",
		"stock": [], "buys": [], "rate": 0.5},
	"magic": {"name": "Selene (Magic Shop)", "sign": "Magic Shop", "style": "mage", "pos": [-176, 150], "kind": "shop", "gear": "none",
		"stock": ["book_t_fire", "book_t_water", "book_t_earth", "book_t_wind", "book_t_light", "book_t_dark"], "buys": ["book", "mat"], "rate": 0.5},
}
var shop_stock = {}   # npc id -> {"t": play_time, "items": [...]} (rolled gear stock, refreshes over time)

const QUEST_MATS = ["gel", "hide", "herb", "mushroom", "wood", "stone", "iron_ore", "coal", "bone", "wolf_fang", "goblin_ear", "meat"]


## Build a guild quest scaled to the player's level.
func make_quest(level):
	var kinds = ["kill", "kill", "collect", "collect", "mini", "dungeon"]
	var k = kinds[randi() % kinds.size()]
	var q = {"kind": k, "have": 0, "xp": 0, "gold": 0, "item": null}
	var lv = maxi(level, 1)
	if k == "kill":
		var cands = []
		for t in MOBS:
			if MOBS[t]["mode"] == "hostile":
				cands.append(t)
		q["target"] = cands[randi() % cands.size()]
		q["need"] = randi_range(8, 16)
		q["name"] = "Hunt %d %s" % [q["need"], MOBS[q["target"]]["name"]]
		q["xp"] = int(q["need"] * 4.0 * pow(lv, 1.3) * 0.8)
		q["gold"] = int(q["need"] * (6.0 + lv * 2.0))
	elif k == "collect":
		q["target"] = QUEST_MATS[randi() % QUEST_MATS.size()]
		q["need"] = randi_range(10, 25)
		q["name"] = "Deliver %d %s" % [q["need"], ITEMS[q["target"]]["name"]]
		q["xp"] = int(q["need"] * 2.0 * pow(lv, 1.2))
		q["gold"] = int(q["need"] * (5.0 + lv * 1.2))
	elif k == "mini":
		q["target"] = ""
		q["need"] = 2
		q["name"] = "Defeat 2 dungeon mini bosses"
		q["xp"] = int(pow(lv, 1.5) * 60.0)
		q["gold"] = int(250.0 + lv * 60.0)
	else:
		q["target"] = ""
		q["need"] = 1
		q["name"] = "Clear a dungeon (defeat its main boss)"
		q["xp"] = int(pow(lv, 1.5) * 150.0)
		q["gold"] = int(600.0 + lv * 150.0)
	q["gear"] = randf() < 0.35 or k == "dungeon"
	q["level"] = lv
	return q


# ------------------------------------------------------------------ runtime state
var world = null
var entities = null
var player = null
var hud = null
var main = null
var map = null
var waypoint = null
var sel_dungeon = null    # dungeon record selected on the map
var is_night = false
var pending_load = null
var current_slot = 1
var play_time = 0.0
var dungeons = []          # active dungeon records (see main.gd)
var cur_dungeon = null     # record of the dungeon the player is inside (or null)
var dlayout = null         # layout of the current dungeon

var _cache = {}
var _last_text = ""
var _last_ms = 0


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	SKILLS.merge(preload("res://scripts/skill_data.gd").DATA.duplicate(true))
	_layout_skills()
	_key("move_up", KEY_W)
	_key("move_up", KEY_UP)
	_key("move_down", KEY_S)
	_key("move_down", KEY_DOWN)
	_key("move_left", KEY_A)
	_key("move_left", KEY_LEFT)
	_key("move_right", KEY_D)
	_key("move_right", KEY_RIGHT)
	_key("run", KEY_SHIFT)
	_key("skill_0", KEY_Q)
	_key("skill_1", KEY_E)
	_key("skill_2", KEY_R)
	_key("skill_3", KEY_F)
	_key("quick_1", KEY_1)
	_key("quick_2", KEY_2)
	_key("quick_3", KEY_3)
	_key("quick_4", KEY_4)
	_key("craft", KEY_B)
	_key("inventory", KEY_I)
	_key("character", KEY_C)
	_key("skills", KEY_K)
	_key("map", KEY_M)
	_key("minimap", KEY_N)
	_key("interact", KEY_T)
	_key("help", KEY_H)
	_key("recall", KEY_G)
	_key("dash", KEY_CTRL)
	var rm = InputEventMouseButton.new()
	rm.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("dash", rm)
	_key("quicksave", KEY_F5)
	_key("attack", KEY_SPACE)
	var m = InputEventMouseButton.new()
	m.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", m)
	load_settings()


# Order of skills in each tree (10 actives + 10 passives per class). Row r -> level requirement.
const ACT_ORDER = {
	"warrior": ["w_cleave", "w_bash", "w_whirl", "w_chain", "w_leap", "w_rend", "w_war", "w_fort", "w_quake", "w_judg"],
	"ranger": ["r_pierce", "r_rain", "r_volley", "r_multi", "r_poison", "r_roll", "r_hawk", "r_trap", "r_storm", "r_snipe"],
	"assassin": ["a_shadow", "a_flurry", "a_smoke", "a_back", "a_venom", "a_fan", "a_vanish", "a_rift", "a_flash", "a_exec"],
	"mage": ["m_fire", "m_lance", "m_meteor", "m_nova", "m_chain", "m_spikes", "m_barrier", "m_void", "m_rain", "m_burst"],
	"priest": ["p_smite", "p_bless", "p_curse", "p_heal", "p_drain", "p_nova", "p_haste", "p_shield", "p_purify", "p_wrath"],
}
const PAS_ORDER = {
	"warrior": ["w_iron", "w_berserk", "w_vit", "w_edge", "w_guard", "w_crit", "w_regen", "w_haste", "w_last", "w_brute"],
	"ranger": ["r_eagle", "r_fleet", "r_aim", "r_dex", "r_hunt", "r_vit", "r_wind", "r_deadly", "r_camo", "r_focus"],
	"assassin": ["a_lethal", "a_veil", "a_agile", "a_lucky", "a_edge", "a_dodge", "a_dark", "a_loot", "a_vit", "a_mp"],
	"mage": ["m_arcane", "m_flow", "m_int", "m_crit", "m_cast", "m_res", "m_ward", "m_vit", "m_pool", "m_focus"],
	"priest": ["p_grace", "p_sanct", "p_mind", "p_hands", "p_blessed", "p_mag", "p_vit", "p_pool", "p_speed", "p_aura"],
}
const ACT_LVL = [1, 4, 10, 18, 28]
const PAS_LVL = [2, 6, 12, 20, 30]


func _layout_skills():
	for cls in ACT_ORDER:
		for list_info in [[ACT_ORDER[cls], 0, ACT_LVL], [PAS_ORDER[cls], 3, PAS_LVL]]:
			var ids = list_info[0]
			for i in range(ids.size()):
				var sk = SKILLS[ids[i]]
				sk["pos"] = [list_info[1] + i % 2, i / 2]
				sk["lvl"] = list_info[2][i / 2]
				sk["req"] = [] if i == 0 else [[ids[maxi(i - 2, 0) if i >= 2 else 0], 2]]
	# common tree
	var c_act = ["c_mend", "c_guard", "c_sprint"]
	var c_lvl = [1, 3, 8, 12]
	for i in range(c_act.size()):
		var sk = SKILLS[c_act[i]]
		sk["pos"] = [i % 2, i / 2]
		sk["lvl"] = c_lvl[i]
		sk["req"] = [] if i < 2 else [[c_act[i - 2], 2]]
	var c_pas = ["c_tough", "c_focus", "c_swift", "c_fortune", "c_ward"]
	for i in range(c_pas.size()):
		var sk = SKILLS[c_pas[i]]
		sk["pos"] = [3 + i % 2, i / 2]
		sk["lvl"] = [1, 1, 5, 5, 10][i]
		sk["req"] = [] if i < 2 else [[c_pas[i - 2], 2]]
	var tomes = ["t_fire", "t_water", "t_earth", "t_wind", "t_light", "t_dark"]
	for i in range(tomes.size()):
		SKILLS[tomes[i]]["pos"] = [i % 3, i / 3]
		SKILLS[tomes[i]]["req"] = []


signal binds_changed

# Rebindable shortcuts (skill slots, quick items, dash, recall). Saved in user://settings.json.
const BIND_ACTIONS = [["skill_0", "Skill slot 1"], ["skill_1", "Skill slot 2"], ["skill_2", "Skill slot 3"], ["skill_3", "Skill slot 4"],
	["quick_1", "Quick item 1"], ["quick_2", "Quick item 2"], ["quick_3", "Quick item 3"], ["quick_4", "Quick item 4"],
	["run", "Run on/off"], ["dash", "Dash"], ["recall", "Recall to town"]]
const DEFAULT_KEYS = {"skill_0": KEY_Q, "skill_1": KEY_E, "skill_2": KEY_R, "skill_3": KEY_F, "quick_1": KEY_1, "quick_2": KEY_2,
	"quick_3": KEY_3, "quick_4": KEY_4, "run": KEY_SHIFT, "dash": KEY_CTRL, "recall": KEY_G}
var run_on = false
const SETTINGS_PATH = "user://settings.json"


var _wind_mat = {}
var _light_tex = null


## Shared wind-sway material (strength / height per kind of sprite).
func wind_material(strength = 1.6, height = 32.0):
	var key = "%s_%s" % [strength, height]
	if not _wind_mat.has(key):
		var m = ShaderMaterial.new()
		m.shader = load("res://scripts/wind.gdshader")
		m.set_shader_parameter("strength", strength)
		m.set_shader_parameter("height", height)
		_wind_mat[key] = m
	return _wind_mat[key]


func light_tex():
	if _light_tex == null:
		var gt = GradientTexture2D.new()
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 128
		gt.height = 128
		var gr = Gradient.new()
		gr.set_color(0, Color(1, 1, 1, 1))
		gr.set_color(1, Color(0, 0, 0, 0))
		gt.gradient = gr
		_light_tex = gt
	return _light_tex


## Warm flickering lamp light: almost off by day, full at night (CanvasModulate darkens the world).
func make_light(color, energy, scale_f = 1.0):
	var l = load("res://scripts/night_light.gd").new()
	l.texture = light_tex()
	l.color = color
	l.base = energy
	l.texture_scale = scale_f
	return l


func skill_icon(id):
	var path = "res://assets/skillicons/%s.png" % id
	return tex(path) if ResourceLoader.exists(path) else tex("res://assets/items/elem_none.png")


func key_of(action):
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return ev.physical_keycode
	return 0


func key_label(action):
	var k = key_of(action)
	return OS.get_keycode_string(k) if k != 0 else "-"


func _apply_key(action, code):
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
	var ev2 = InputEventKey.new()
	ev2.physical_keycode = code
	InputMap.action_add_event(action, ev2)


## Returns "" on success or an error message. Swaps with another rebindable action that already uses the key.
func set_bind(action, code):
	if code == KEY_ESCAPE:
		return "Esc cannot be assigned"
	var bind_names = []
	for b in BIND_ACTIONS:
		bind_names.append(b[0])
	for a in InputMap.get_actions():
		if a in bind_names or String(a).begins_with("ui_"):
			continue
		for ev in InputMap.action_get_events(a):
			if ev is InputEventKey and ev.physical_keycode == code:
				return "%s is already used by another control" % OS.get_keycode_string(code)
	var old = key_of(action)
	for other in bind_names:
		if other != action and key_of(other) == code:
			_apply_key(other, old)
	_apply_key(action, code)
	save_settings()
	binds_changed.emit()
	return ""


func reset_binds():
	for a in DEFAULT_KEYS:
		_apply_key(a, DEFAULT_KEYS[a])
	save_settings()
	binds_changed.emit()


func save_settings():
	var d = {}
	for b in BIND_ACTIONS:
		d[b[0]] = key_of(b[0])
	var f = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"binds": d}))


func load_settings():
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or not data.has("binds"):
		return
	for a in data["binds"]:
		if DEFAULT_KEYS.has(a) and int(data["binds"][a]) != 0:
			_apply_key(a, int(data["binds"][a]))


func _key(action, code):
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev = InputEventKey.new()
	ev.physical_keycode = code
	InputMap.action_add_event(action, ev)


func _process(delta):
	if player != null and not get_tree().paused:
		play_time += delta


# ------------------------------------------------------------------ resources / frames
func tex(path):
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]


func char_frames(sheet):
	var key = "cf:" + sheet
	if _cache.has(key):
		return _cache[key]
	var sf = SpriteFrames.new()
	sf.remove_animation("default")
	var t = tex(sheet)
	var row = 0
	for a in ANIMS:
		for di in range(3):
			var nm = a + "_" + DIRS[di]
			sf.add_animation(nm)
			sf.set_animation_speed(nm, ANIM_FPS[a])
			sf.set_animation_loop(nm, a == "idle" or a == "walk" or a == "run")
			for f in range(ANIM_FRAMES[a]):
				var at = AtlasTexture.new()
				at.atlas = t
				at.region = Rect2(f * 32, (row * 3 + di) * 32, 32, 32)
				sf.add_frame(nm, at)
		row += 1
	_cache[key] = sf
	return sf


func strip_frames(path, fw, fh, count, fps, loop):
	var key = "sf:" + path
	if _cache.has(key):
		return _cache[key]
	var sf = SpriteFrames.new()
	sf.set_animation_speed("default", fps)
	sf.set_animation_loop("default", loop)
	var t = tex(path)
	for i in range(count):
		var at = AtlasTexture.new()
		at.atlas = t
		at.region = Rect2(i * fw, 0, fw, fh)
		sf.add_frame("default", at)
	_cache[key] = sf
	return sf


func proj_frames(kind):
	return strip_frames("res://assets/spells/%s_proj.png" % kind, 32, 32, 4, 14.0, true)


func fx_frames(kind):
	var e = FX[kind]
	return strip_frames(e[0], e[1], e[2], e[3], e[4], e[5])


# ------------------------------------------------------------------ formulas
func xp_need(l):
	return int(30.0 * pow(l, 1.5))


func mob_hp_scale(l):
	return 1.0 + l * 0.4 + l * l * 0.02


func mob_dmg_scale(l):
	return 1.0 + l * 0.15 + l * l * 0.006


func mob_def(l):
	return 4.0 + l * 6.0


func def_factor(def, atk_level):
	var k = 100.0 + 25.0 * atk_level
	return k / (k + maxf(def, 0.0))


func slot_of(sub):
	if WEAPONS.has(sub):
		return "weapon"
	if ARMORS.has(sub):
		return "armor"
	return sub


# ------------------------------------------------------------------ UI helpers
func notify(text):
	var now = Time.get_ticks_msec()
	if text == _last_text and now - _last_ms < 1200:
		return
	_last_text = text
	_last_ms = now
	if hud != null:
		hud.notify(text)


func float_text(txt, pos, color = Color.WHITE, size = 8):
	if entities == null:
		return
	var l = Label.new()
	l.text = str(txt)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	l.position = pos + Vector2(-8, -30)
	l.z_index = 50
	entities.add_child(l)
	var tw = l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 14, 0.8)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.tween_callback(l.queue_free)


func chips(pos, color, amount = 6):
	if entities == null:
		return
	var p = CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.gravity = Vector2(0, 260)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 80.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 2.5
	p.color = color
	p.z_index = 20
	entities.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


# ------------------------------------------------------------------ spawning helpers
func shoot(params):
	var p = load("res://scripts/projectile.gd").new()
	for k in params:
		p.set(k, params[k])
	entities.add_child(p)
	return p


func spawn_fx(kind, pos, opts = {}):
	var f = load("res://scripts/fx.gd").new()
	f.kind = kind
	f.position = pos
	for k in opts:
		f.set(k, opts[k])
	entities.add_child(f)
	return f


func zone(params):
	var z = load("res://scripts/zone.gd").new()
	for k in params:
		z.set(k, params[k])
	entities.add_child(z)
	return z


func telegraph(pos, radius, dur, col = Color(1, 0.3, 0.1)):
	var t = load("res://scripts/telegraph.gd").new()
	t.position = pos
	t.radius = radius
	t.dur = dur
	t.col = col
	entities.add_child(t)
	return t


func drop_item(it, pos):
	var dr = load("res://scripts/drop.gd").new()
	dr.item = it
	dr.position = pos
	entities.add_child(dr)
	return dr


func near_fire(pos):
	for f in get_tree().get_nodes_in_group("fire"):
		if f.global_position.distance_to(pos) < 60.0:
			return true
	return false


# ------------------------------------------------------------------ combat helpers
func roll_damage(p, base, force_crit = false):
	var crit = force_crit or randf() * 100.0 < p.stats["crit_rate"]
	var amt = base * randf_range(0.92, 1.08)
	if crit:
		amt *= p.stats["crit_dmg"] / 100.0
	return {"amt": amt, "crit": crit}


func hit(target, roll, from_pos, kb, element, magic, status = []):
	if not is_instance_valid(target):
		return
	target.take_damage(roll["amt"], from_pos, kb, element, {"magic": magic, "crit": roll["crit"], "lvl": player.level, "status": status, "player": true})


func gather_power():
	if player == null:
		return 1.0
	return 1.0 + player.stats["str"] * 0.07 + (player.equip["weapon"]["base"].get("phy_atk", 0.0) * 0.04 if player.equip["weapon"] != null else 0.0)


## Ranged / area attacks also chop trees and break ore (each resource ignores repeat chips for 0.25 s).
func chip_resources(pos, radius, power_mult = 0.6):
	if player == null:
		return
	var gp = gather_power() * power_mult
	for r in get_tree().get_nodes_in_group("resources"):
		if r.alive and pos.distance_to(r.global_position + Vector2(0, -6)) <= radius + r.radius:
			r.chip(gp, player)


func enemies_in_circle(pos, radius, gather = true):
	if gather:
		chip_resources(pos, radius)
	var out = []
	for e in get_tree().get_nodes_in_group("hurtable"):
		if is_instance_valid(e) and pos.distance_to(e.global_position + Vector2(0, -6)) <= radius + e.hit_radius:
			out.append(e)
	return out


func enemies_in_arc(origin, dir, reach, arc, gather = true):
	if gather and player != null:
		for r in get_tree().get_nodes_in_group("resources"):
			if r.alive:
				var tr = r.global_position + Vector2(0, -6) - origin
				if tr.length() <= reach + r.radius and absf(angle_difference(dir.angle(), tr.angle())) <= arc + 0.3:
					r.chip(gather_power() * 0.7, player)
	var out = []
	for e in get_tree().get_nodes_in_group("hurtable"):
		if not is_instance_valid(e):
			continue
		var to = e.global_position + Vector2(0, -6) - origin
		if to.length() <= reach + e.hit_radius and absf(angle_difference(dir.angle(), to.angle())) <= arc:
			out.append(e)
	return out


## Damage everything in a circle. base is the un-rolled damage (each target gets its own crit roll).
func area_attack(pos, radius, base, magic, element, kb, status = [], force_crit = false):
	var n = 0
	for e in enemies_in_circle(pos, radius):
		hit(e, roll_damage(player, base, force_crit), pos, kb, element, magic, status)
		n += 1
	return n


# ------------------------------------------------------------------ save files (user://saves/slot_N.json)
func slot_path(i):
	return "user://saves/slot_%d.json" % i


func read_slot(i):
	var p = slot_path(i)
	if not FileAccess.file_exists(p):
		return null
	var f = FileAccess.open(p, FileAccess.READ)
	if f == null:
		return null
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or not data.has("seed") or data.get("version", 0) < 3:
		return null
	return data


func write_slot(i, data):
	DirAccess.make_dir_recursive_absolute("user://saves")
	var f = FileAccess.open(slot_path(i), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	return true


func delete_slot(i):
	if FileAccess.file_exists(slot_path(i)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(i)))


func slot_summary(i):
	var d = read_slot(i)
	if d == null:
		return ""
	var mins = int(d.get("play_time", 0.0) / 60.0)
	var cls = CLASSES.get(d["char"], {"name": "?"})["name"]
	return "%s Lv %d | %dg | %d min | %s" % [cls, int(d["player"]["level"]), int(d["player"].get("gold", 0)), mins, str(d.get("time", ""))]


func ghost_at(p, pt):
	if entities == null or p.sprite == null:
		return
	var s = Sprite2D.new()
	s.texture = p.sprite.sprite_frames.get_frame_texture(p.sprite.animation, p.sprite.frame)
	s.flip_h = p.sprite.flip_h
	s.position = pt + Vector2(0, -6)
	s.modulate = Color(0.55, 0.4, 1.0, 0.7)
	s.z_index = 5
	entities.add_child(s)
	var tw = s.create_tween()
	tw.tween_property(s, "modulate:a", 0.0, 0.3)
	tw.tween_callback(s.queue_free)
