import json
D = {}
def act(id, name, cls, elem, kind, mana, cd, mult, per, desc, spec):
    D[id] = {"name": name, "cls": cls, "type": "active", "elem": elem, "kind": kind, "max": 20, "lvl": 1, "req": [], "pos": [0, 0],
             "mana": mana, "cd": cd, "slot": 0, "mult": mult, "per": per, "desc": desc, "spec": spec}
def pas(id, name, cls, bonus, desc, low=None):
    d = {"name": name, "cls": cls, "type": "passive", "elem": "none", "max": 20, "lvl": 1, "req": [], "pos": [0, 0], "bonus": bonus, "desc": desc}
    if low: d["low_bonus"] = low
    D[id] = d

# ---------------- Warrior
act("w_leap", "Heavy Leap", "warrior", "earth", "phy", 14, 8.0, 2.4, 0.16, "Crash down at the cursor, stunning enemies.", {"t": "tgt", "range": 100, "radius": 38, "delay": 0.3, "fx": "earth", "stun": 0.8, "kb": 220})
act("w_war", "Battle Cry", "warrior", "light", "phy", 16, 24.0, 0, 0, "BUFF: +Phy Atk and Move Speed for 15s.", {"t": "buff", "id": "warcry", "dur": 15, "fx": "aura", "mods": {"phy_atk_pct": [0.15, 0.008], "move_pct": [0.10, 0.003]}})
act("w_quake", "Earthquake", "warrior", "earth", "phy", 22, 11.0, 2.2, 0.15, "Stomp the ground: a shockwave hits everything around you.", {"t": "nova", "radius": 72, "fx": "earth", "scl": 1.4, "kb": 220, "stun": 0.5, "shake": 4})
act("w_chain", "Chain Slash", "warrior", "wind", "phy", 14, 6.0, 0.9, 0.06, "Three rapid slashes in front of you.", {"t": "arc", "reach": 40, "arc": 1.1, "hits": 3, "fx": "slash", "kb": 80, "gap": 0.12})
act("w_fort", "Fortress", "warrior", "earth", "phy", 20, 26.0, 0, 0, "BUFF: huge Phy/Magic Def for 10s.", {"t": "buff", "id": "fortress", "dur": 10, "fx": "aura", "mods": {"phy_def_pct": [0.40, 0.012], "mag_def_pct": [0.20, 0.008]}})
act("w_rend", "Rending Strike", "warrior", "dark", "phy", 12, 7.0, 1.6, 0.1, "A vicious cut that makes enemies bleed.", {"t": "arc", "reach": 38, "arc": 1.0, "fx": "slash", "kb": 100, "status": [["poison", 5.0, 0.6]]})
act("w_judg", "Judgement Blade", "warrior", "light", "phy", 30, 16.0, 3.8, 0.25, "A blade of holy light cleaves a long narrow line.", {"t": "arc", "reach": 70, "arc": 0.4, "fx": "light", "fxd": 40, "kb": 200})
# ---------------- Ranger
act("r_snipe", "Snipe", "ranger", "wind", "phy", 16, 8.0, 4.0, 0.28, "A single, deadly, perfectly aimed shot. Always crits.", {"t": "proj", "kind": "wind", "speed": 520, "life": 1.3, "crit": True, "hit_fx": "wind", "kb": 160})
act("r_trap", "Frost Trap", "ranger", "water", "phy", 14, 12.0, 0.4, 0.03, "Place a freezing field: slows and damages over 6s.", {"t": "zone", "at": "cursor", "range": 110, "radius": 42, "dur": 6.0, "tick": 0.6, "fx": "zone", "tint": [0.5, 0.8, 1.0], "status": [["slow", 1.5, 0.5]]})
act("r_multi", "Triple Shot", "ranger", "wind", "phy", 12, 4.0, 1.1, 0.08, "Fire three arrows in a spread.", {"t": "proj", "kind": "wind", "n": 3, "spread": 0.16, "speed": 330, "life": 1.0, "hit_fx": "wind"})
act("r_poison", "Venom Arrow", "ranger", "dark", "phy", 12, 6.0, 1.3, 0.09, "A poisoned arrow that deals damage over time.", {"t": "proj", "kind": "dark", "speed": 320, "life": 1.1, "hit_fx": "dark", "status": [["poison", 6.0, 0.9]]})
act("r_roll", "Evasive Roll", "ranger", "earth", "phy", 8, 7.0, 0, 0, "Roll backward, briefly invulnerable, and gain speed.", {"t": "dash", "back": True, "dist": 70, "dur": 0.18, "invuln": 0.5, "buff": ["roll", 3.0, {"move_pct": 0.25}]})
act("r_hawk", "Hawk Strike", "ranger", "wind", "phy", 22, 12.0, 1.5, 0.1, "Call down three hawk strikes near the cursor.", {"t": "tgt", "range": 140, "radius": 24, "delay": 0.35, "count": 3, "scatter": 40, "fx": "wind", "kb": 120})
act("r_storm", "Storm Volley", "ranger", "wind", "phy", 30, 15.0, 0.8, 0.05, "Release a wide storm of nine arrows.", {"t": "proj", "kind": "wind", "n": 9, "spread": 0.09, "speed": 300, "life": 1.0, "hit_fx": "wind", "status": [["stun", 0.4, 0]]})
pas_cr = None
# ---------------- Assassin
act("a_back", "Backstab", "assassin", "dark", "phy", 12, 6.0, 3.0, 0.2, "A brutal strike: always a critical hit.", {"t": "arc", "reach": 30, "arc": 0.8, "fx": "slash", "kb": 60, "crit": True})
act("a_venom", "Poison Blade", "assassin", "dark", "phy", 12, 8.0, 1.3, 0.09, "A coated blade: strong poison.", {"t": "arc", "reach": 30, "arc": 1.0, "fx": "dark", "kb": 60, "status": [["poison", 6.0, 0.9]]})
act("a_vanish", "Vanish", "assassin", "dark", "phy", 18, 22.0, 0, 0, "BUFF: +Move Speed and +Crit Rate for 8s.", {"t": "buff", "id": "vanish", "dur": 8, "fx": "dark", "mods": {"move_pct": [0.30, 0.01], "crit_rate": [25.0, 0.5]}})
act("a_fan", "Throwing Fan", "assassin", "wind", "phy", 16, 7.0, 0.9, 0.06, "Hurl five razor blades in a fan.", {"t": "proj", "kind": "wind", "n": 5, "spread": 0.12, "speed": 330, "life": 0.7, "hit_fx": "wind"})
act("a_exec", "Execute", "assassin", "dark", "phy", 24, 12.0, 3.5, 0.22, "Dash through an enemy with a lethal critical strike.", {"t": "dashhit", "dist": 80, "dur": 0.16, "crit": True, "fx": "dark"})
act("a_rift", "Shadow Rift", "assassin", "dark", "phy", 24, 14.0, 0.6, 0.04, "Tear open a rift of shadow that cuts and slows.", {"t": "zone", "at": "cursor", "range": 100, "radius": 46, "dur": 4.0, "tick": 0.5, "fx": "zone", "tint": [0.6, 0.3, 0.9], "status": [["slow", 1.0, 0.4]]})
act("a_flash", "Lightning Flash", "assassin", "light", "phy", 26, 13.0, 1.8, 0.12, "A blinding flash stuns nearby enemies.", {"t": "nova", "radius": 54, "fx": "light", "scl": 1.1, "kb": 80, "stun": 0.8})
# ---------------- Mage
act("m_nova", "Frost Nova", "mage", "water", "mag", 22, 9.0, 1.6, 0.11, "A freezing ring slows everything near you.", {"t": "nova", "radius": 62, "fx": "water", "scl": 1.3, "kb": 120, "status": [["slow", 3.0, 0.5]]})
act("m_chain", "Chain Lightning", "mage", "wind", "mag", 20, 7.0, 2.2, 0.15, "A crackling bolt that pierces and stuns.", {"t": "proj", "kind": "wind", "speed": 380, "life": 1.0, "pierce": True, "hit_fx": "wind", "status": [["stun", 0.5, 0]]})
act("m_rain", "Fire Rain", "mage", "fire", "mag", 32, 14.0, 0.8, 0.05, "Flames rain on the cursor for 3 seconds.", {"t": "zone", "at": "cursor", "range": 150, "radius": 56, "dur": 3.0, "tick": 0.4, "fx": "rain", "tint": [1.0, 0.5, 0.3], "status": [["burn", 2.5, 0.3]]})
act("m_barrier", "Mana Shield", "mage", "light", "mag", 26, 28.0, 0, 0, "BUFF: big defense and MP regen for 10s.", {"t": "buff", "id": "barrier", "dur": 10, "fx": "aura", "mods": {"phy_def_pct": [0.30, 0.01], "mag_def_pct": [0.40, 0.012], "mp_regen": [3.0, 0.1]}})
act("m_spikes", "Stone Spikes", "mage", "earth", "mag", 20, 8.0, 2.2, 0.15, "Spikes erupt in a line ahead of you and stun.", {"t": "arc", "reach": 85, "arc": 0.25, "fx": "earth", "fxd": 50, "kb": 160, "stun": 0.6})
act("m_void", "Void Orb", "mage", "dark", "mag", 28, 10.0, 3.0, 0.2, "A slow orb of void that explodes and slows.", {"t": "proj", "kind": "dark", "speed": 150, "life": 1.8, "aoe": 40, "hit_fx": "dark", "status": [["slow", 2.5, 0.4]]})
act("m_burst", "Arcane Burst", "mage", "light", "mag", 30, 12.0, 2.8, 0.19, "Detonate arcane power all around you.", {"t": "nova", "radius": 56, "fx": "light", "scl": 1.2, "kb": 200})
# ---------------- Priest
act("p_heal", "Healing Light", "priest", "light", "mag", 20, 8.0, 0, 0, "Heal yourself (scales with MIND).", {"t": "heal", "pct": 0.30, "per": 0.01})
act("p_nova", "Holy Nova", "priest", "light", "mag", 24, 10.0, 1.5, 0.1, "A holy burst that damages foes and heals you.", {"t": "nova", "radius": 58, "fx": "light", "scl": 1.2, "kb": 100, "heal": 0.25})
act("p_shield", "Divine Shield", "priest", "light", "mag", 28, 30.0, 0, 0, "BUFF: very high Phy/Magic Def for 6s.", {"t": "buff", "id": "divine", "dur": 6, "fx": "aura", "mods": {"phy_def_pct": [0.60, 0.015], "mag_def_pct": [0.60, 0.015]}})
act("p_drain", "Soul Drain", "priest", "dark", "mag", 18, 6.0, 1.8, 0.12, "A dark bolt that steals life.", {"t": "proj", "kind": "dark", "speed": 280, "life": 1.0, "hit_fx": "dark", "heal": 0.5})
act("p_purify", "Purify", "priest", "light", "mag", 22, 18.0, 0, 0, "Cleanse all debuffs, heal a little, resist all elements for 8s.", {"t": "cleanse", "pct": 0.12, "dur": 8, "res": [20.0, 0.5]})
act("p_wrath", "Wrath of Heaven", "priest", "light", "mag", 34, 13.0, 3.5, 0.24, "Two pillars of light crash down at the cursor.", {"t": "tgt", "range": 140, "radius": 34, "delay": 0.8, "count": 2, "scatter": 30, "fx": "light", "kb": 160, "tele": [1.0, 0.95, 0.5]})
act("p_haste", "Holy Haste", "priest", "wind", "mag", 20, 24.0, 0, 0, "BUFF: +Atk/Cast Speed and Move Speed for 15s.", {"t": "buff", "id": "haste", "dur": 15, "fx": "aura", "mods": {"aspd_pct": [0.30, 0.01], "move_pct": [0.20, 0.006]}})
# ---------------- Common
act("c_guard", "Guard", "common", "earth", "phy", 14, 20.0, 0, 0, "BUFF: +Phy/Magic Def for 12s.", {"t": "buff", "id": "guard", "dur": 12, "fx": "aura", "mods": {"phy_def_pct": [0.25, 0.01], "mag_def_pct": [0.25, 0.01]}})
act("c_sprint", "Sprint", "common", "wind", "phy", 10, 18.0, 0, 0, "BUFF: +40% Move Speed for 8s.", {"t": "buff", "id": "sprint", "dur": 8, "fx": "wind", "mods": {"move_pct": [0.40, 0.005]}})
# ---------------- Tome skills (spell books from the Magic Shop)
def tome(id, name, elem, desc, mult, spec):
    act(id, name, "tome", elem, "mag", 24, 10.0, mult, 0.15, desc, spec)
    D[id]["lvl"] = 5
tome("t_fire", "Ember Burst", "fire", "Spell book: a fiery nova that burns.", 2.4, {"t": "nova", "radius": 60, "fx": "fire", "scl": 1.2, "kb": 140, "status": [["burn", 3.0, 0.4]]})
tome("t_water", "Tidal Wave", "water", "Spell book: a crashing wave that knocks back and slows.", 2.2, {"t": "arc", "reach": 75, "arc": 0.7, "fx": "water", "fxd": 40, "kb": 320, "status": [["slow", 3.0, 0.5]]})
tome("t_earth", "Rock Fall", "earth", "Spell book: boulders fall around the cursor.", 1.8, {"t": "tgt", "range": 140, "radius": 28, "delay": 0.5, "count": 4, "scatter": 50, "fx": "earth", "kb": 150, "stun": 0.4})
tome("t_wind", "Gale Slash", "wind", "Spell book: three piercing blades of wind.", 1.6, {"t": "proj", "kind": "wind", "n": 3, "spread": 0.2, "speed": 340, "life": 1.0, "pierce": True, "hit_fx": "wind"})
tome("t_light", "Radiance", "light", "Spell book: radiant burst that heals you.", 2.0, {"t": "nova", "radius": 56, "fx": "light", "scl": 1.2, "kb": 100, "heal": 0.3})
tome("t_dark", "Shadow Bolt", "dark", "Spell book: a huge piercing bolt of darkness.", 3.2, {"t": "proj", "kind": "dark", "speed": 260, "life": 1.2, "pierce": True, "hit_fx": "dark"})

# ---------------- Passives (8 more per class)
pas("w_vit", "Stout Heart", "warrior", {"hp_pct": 0.012}, "+1.2% max HP per rank.")
pas("w_edge", "Weapon Mastery", "warrior", {"phy_atk_pct": 0.012}, "+1.2% Phy Atk per rank.")
pas("w_guard", "Guard Training", "warrior", {"phy_def_pct": 0.015}, "+1.5% Phy Def per rank.")
pas("w_crit", "Battle Instinct", "warrior", {"crit_rate": 0.4, "crit_dmg": 1.0}, "+0.4% Crit Rate, +1% Crit Dmg per rank.")
pas("w_regen", "Second Wind", "warrior", {"hp_regen": 0.12}, "+0.12 HP/s per rank.")
pas("w_haste", "Combat Rhythm", "warrior", {"aspd_pct": 0.01}, "+1% Attack Speed per rank.")
pas("w_last", "Last Stand", "warrior", {"vit": 0.4}, "+0.4 VIT per rank, and +2% Phy Def per rank below half HP.", {"phy_def_pct": 0.02})
pas("w_brute", "Brute Force", "warrior", {"str": 0.6}, "+0.6 STR per rank.")
pas("r_aim", "Steady Aim", "ranger", {"phy_atk_pct": 0.012}, "+1.2% Phy Atk per rank.")
pas("r_dex", "Nimble Fingers", "ranger", {"dex": 0.6}, "+0.6 DEX per rank.")
pas("r_hunt", "Hunter's Luck", "ranger", {"drop_pct": 0.012, "luck": 0.3}, "+1.2% Drop Rate, +0.3 LUCK per rank.")
pas("r_vit", "Trail Hardened", "ranger", {"hp_pct": 0.01}, "+1% max HP per rank.")
pas("r_wind", "Wind Walker", "ranger", {"res_wind": 1.5, "move_pct": 0.006}, "+1.5% Wind Res, +0.6% Move Speed per rank.")
pas("r_deadly", "Deadly Shot", "ranger", {"crit_dmg": 2.0}, "+2% Crit Damage per rank.")
pas("r_camo", "Camouflage", "ranger", {"phy_def_pct": 0.012, "mag_def_pct": 0.012}, "+1.2% Phy and Magic Def per rank.")
pas("r_focus", "Focus Breath", "ranger", {"mp_regen": 0.1}, "+0.1 MP/s per rank.")
pas("a_agile", "Agility", "assassin", {"dex": 0.6}, "+0.6 DEX per rank.")
pas("a_lucky", "Fortune's Edge", "assassin", {"luck": 0.7}, "+0.7 LUCK per rank.")
pas("a_edge", "Keen Edge", "assassin", {"phy_atk_pct": 0.014}, "+1.4% Phy Atk per rank.")
pas("a_dodge", "Evasion", "assassin", {"phy_def_pct": 0.01, "move_pct": 0.006}, "+1% Phy Def, +0.6% Move Speed per rank.")
pas("a_dark", "Dark Affinity", "assassin", {"res_dark": 1.5, "mag_def_pct": 0.01}, "+1.5% Dark Res, +1% Magic Def per rank.")
pas("a_loot", "Pickpocket", "assassin", {"drop_pct": 0.015}, "+1.5% Drop Rate per rank.")
pas("a_vit", "Toughened", "assassin", {"hp_pct": 0.01}, "+1% max HP per rank.")
pas("a_mp", "Shadow Focus", "assassin", {"mp_pct": 0.012, "mp_regen": 0.08}, "+1.2% max MP, +0.08 MP/s per rank.")
pas("m_int", "Brilliant Mind", "mage", {"int": 0.7}, "+0.7 INT per rank.")
pas("m_crit", "Spell Crit", "mage", {"crit_rate": 0.4, "crit_dmg": 1.2}, "+0.4% Crit Rate, +1.2% Crit Dmg per rank.")
pas("m_cast", "Quick Casting", "mage", {"aspd_pct": 0.012}, "+1.2% Casting Speed per rank.")
pas("m_res", "Elemental Attunement", "mage", {"res_fire": 1.0, "res_water": 1.0, "res_earth": 1.0, "res_wind": 1.0}, "+1% Fire/Water/Earth/Wind Res per rank.")
pas("m_ward", "Arcane Ward", "mage", {"mag_def_pct": 0.015}, "+1.5% Magic Def per rank.")
pas("m_vit", "Vital Magic", "mage", {"hp_pct": 0.01}, "+1% max HP per rank.")
pas("m_pool", "Deep Reserves", "mage", {"mp_pct": 0.015}, "+1.5% max MP per rank.")
pas("m_focus", "Meditation", "mage", {"mp_regen": 0.12}, "+0.12 MP/s per rank.")
pas("p_mind", "Serene Mind", "priest", {"mind": 0.7}, "+0.7 MIND per rank.")
pas("p_hands", "Healing Hands", "priest", {"heal_pct": 0.02}, "+2% healing power per rank.")
pas("p_blessed", "Blessed", "priest", {"res_light": 1.5, "res_dark": 1.0}, "+1.5% Light Res, +1% Dark Res per rank.")
pas("p_mag", "Holy Power", "priest", {"mag_atk_pct": 0.013}, "+1.3% Magic Atk per rank.")
pas("p_vit", "Pious Vigor", "priest", {"hp_pct": 0.012}, "+1.2% max HP per rank.")
pas("p_pool", "Wellspring", "priest", {"mp_pct": 0.015}, "+1.5% max MP per rank.")
pas("p_speed", "Devout Speed", "priest", {"aspd_pct": 0.01, "move_pct": 0.006}, "+1% Cast Speed, +0.6% Move Speed per rank.")
pas("p_aura", "Aura of Faith", "priest", {"phy_def_pct": 0.01, "mag_def_pct": 0.01}, "+1% Phy and Magic Def per rank.")

out = "extends RefCounted\n## Generated by tools/gen_skill_data.py: extra skills merged into Game.SKILLS.\n\nconst DATA = " + json.dumps(D, indent=1) + "\n"
open("scripts/skill_data.gd", "w").write(out)
print(len(D))
