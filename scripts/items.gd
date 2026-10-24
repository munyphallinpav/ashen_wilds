extends Node
## Autoload "Items": item instances (stackables + rolled gear), rarity, affixes, tooltips, loot tables.
## Stackable: {"id": "wood", "n": 5}
## Gear:      {"sub": "sword", "rar": 2, "ilvl": 12, "name": "...", "base": {stat: v}, "aff": {stat: v}, "elem": "fire", "u": "", "n": 1}

const RARITY_WEIGHTS = [60.0, 26.0, 10.0, 3.5, 0.45, 0.05]

# stat key -> [min, max, is_percent_like]
const AFFIX_POOL = {
	"str": [1, 3, false], "vit": [1, 3, false], "int": [1, 3, false], "mind": [1, 3, false], "dex": [1, 3, false], "luck": [1, 3, false],
	"hp": [10, 30, false], "mp": [6, 18, false], "phy_atk": [1, 4, false], "mag_atk": [1, 4, false],
	"phy_def": [1, 4, false], "mag_def": [1, 4, false], "move_speed": [1.0, 3.0, true], "atk_speed": [2.0, 5.0, true],
	"crit_rate": [1.0, 2.5, true], "crit_dmg": [3.0, 8.0, true], "drop": [3.0, 8.0, true],
	"hp_regen": [0.1, 0.3, true], "mp_regen": [0.1, 0.4, true],
	"res_fire": [4.0, 9.0, true], "res_water": [4.0, 9.0, true], "res_earth": [4.0, 9.0, true],
	"res_wind": [4.0, 9.0, true], "res_light": [4.0, 9.0, true], "res_dark": [4.0, 9.0, true],
}
const STAT_LABEL = {
	"str": "STR", "vit": "VIT", "int": "INT", "mind": "MIND", "dex": "DEX", "luck": "LUCK",
	"hp": "Max HP", "mp": "Max MP", "phy_atk": "Phy Atk", "mag_atk": "Magic Atk", "phy_def": "Phy Def", "mag_def": "Magic Def",
	"move_speed": "Move Speed", "atk_speed": "Atk/Cast Speed", "crit_rate": "Crit Rate", "crit_dmg": "Crit Damage", "drop": "Drop Rate",
	"hp_regen": "HP Regen", "mp_regen": "MP Regen",
	"res_fire": "Fire Res", "res_water": "Water Res", "res_earth": "Earth Res", "res_wind": "Wind Res", "res_light": "Light Res", "res_dark": "Dark Res",
}
const PCT_STATS = ["move_speed", "atk_speed", "crit_rate", "crit_dmg", "drop", "res_fire", "res_water", "res_earth", "res_wind", "res_light", "res_dark"]


func is_gear(it):
	return it != null and it.has("sub")


func make(id, n = 1):
	return {"id": id, "n": n}


func data(it):
	return Game.ITEMS.get(it.get("id", ""), {"name": "???", "cat": "mat", "value": 1})


func cat_of(it):
	if is_gear(it):
		return "gear"
	return data(it).get("cat", "mat")


func roll_rarity(luck_bonus = 0.0, diff = 0.0):
	# luck_bonus / diff shift weight toward higher tiers
	var w = []
	var total = 0.0
	for i in range(RARITY_WEIGHTS.size()):
		var x = RARITY_WEIGHTS[i] * (1.0 + (luck_bonus * 0.02 + diff * 0.35) * i)
		if i == 0:
			x = maxf(RARITY_WEIGHTS[0] - (luck_bonus + diff * 20.0) * 0.6, 5.0)
		w.append(x)
		total += x
	var r = randf() * total
	for i in range(w.size()):
		r -= w[i]
		if r <= 0.0:
			return i
	return 0


func _scale(v, ilvl, pct):
	return v * (1.0 + ilvl * (0.012 if pct else 0.07))


func _round(k, v):
	if PCT_STATS.has(k) or k.ends_with("regen"):
		return snappedf(v, 0.1)
	return float(maxi(1, int(round(v))))


func roll_gear(sub, ilvl, rar = -1, unique = "", luck = 0.0, diff = 0.0):
	if rar < 0:
		rar = roll_rarity(luck, diff)
	var it = {"sub": sub, "rar": rar, "ilvl": ilvl, "n": 1, "base": {}, "aff": {}, "elem": "", "u": "", "name": "", "ench": 0}
	var mult = Game.RARITY_MULT[rar]
	var lv = 1.0 + ilvl * 0.1
	if Game.WEAPONS.has(sub):
		var w = Game.WEAPONS[sub]
		var key = "phy_atk" if w["kind"] == "phy" else "mag_atk"
		it["base"][key] = float(int(round(w["atk"] * lv * mult)))
		it["name"] = w["name"]
		if rar >= 2 and randf() < 0.45 + rar * 0.1:
			it["elem"] = Game.ELEMENTS[randi() % Game.ELEMENTS.size()]
	elif Game.ARMORS.has(sub):
		var a = Game.ARMORS[sub]
		it["base"]["phy_def"] = float(int(round(a["pdef"] * lv * mult)))
		it["base"]["mag_def"] = float(int(round(a["mdef"] * lv * mult)))
		if a.has("mp"):
			it["base"]["mp"] = float(int(round(a["mp"] * lv * mult)))
		it["name"] = a["name"]
	else:
		var ac = Game.ACCS[sub]
		for k in ac["base"]:
			it["base"][k] = float(int(round(ac["base"][k] * lv * mult)))
		it["name"] = ac["name"]
	if unique != "":
		var u = Game.UNIQUES[unique]
		it["u"] = unique
		it["name"] = u["name"]
		it["elem"] = u["elem"]
		for k in u["aff"]:
			it["aff"][k] = _round(k, _scale(u["aff"][k], ilvl, PCT_STATS.has(k) or k.ends_with("regen")))
		return it
	var keys = AFFIX_POOL.keys()
	var count = rar
	var tries = 0
	while it["aff"].size() < count and tries < 40:
		tries += 1
		var k = keys[randi() % keys.size()]
		if it["aff"].has(k):
			continue
		if sub == "ring" and k == "hp":
			continue
		var p = AFFIX_POOL[k]
		var v = randf_range(p[0], p[1]) * (0.75 + rar * 0.12)
		it["aff"][k] = _round(k, _scale(v, ilvl, p[2]))
	if it["elem"] != "":
		it["name"] = it["elem"].capitalize() + "-" + it["name"]
	return it


func roll_random_gear(ilvl, rar = -1, luck = 0.0, diff = 0.0):
	var subs = []
	subs.append_array(Game.WEAPONS.keys())
	subs.append_array(Game.ARMORS.keys())
	subs.append_array(Game.ACCS.keys())
	# bias: accessories & armor somewhat less than weapons
	return roll_gear(subs[randi() % subs.size()], ilvl, rar, "", luck, diff)


func name_of(it):
	if is_gear(it):
		var e = int(it.get("ench", 0))
		return ("+%d " % e if e > 0 else "") + it["name"]
	return data(it)["name"]


func color_of(it):
	if is_gear(it):
		return Game.RARITY_COLORS[it["rar"]]
	return Color(0.9, 0.9, 0.92)


func icon(it):
	if is_gear(it):
		return Game.tex("res://assets/items/gear_%s.png" % it["sub"])
	var p = "res://assets/items/%s.png" % it["id"]
	return Game.tex(p)


func value(it):
	if is_gear(it):
		var v = 8.0 + it["ilvl"] * 6.0
		v *= pow(2.2, it["rar"]) * (1.0 + 0.25 * int(it.get("ench", 0)))
		if it["u"] != "":
			v *= 1.5
		return int(v)
	return int(data(it).get("value", 1))


func enchant_mult(it):
	return 1.0 + 0.1 * int(it.get("ench", 0))


## All stat contributions of a gear item (base + affixes, enchant applied).
func totals(it):
	var t = {}
	if it == null:
		return t
	var eb = enchant_mult(it)
	var ea = 1.0 + 0.04 * int(it.get("ench", 0))
	for k in it["base"]:
		t[k] = t.get(k, 0.0) + it["base"][k] * eb
	for k in it["aff"]:
		t[k] = t.get(k, 0.0) + it["aff"][k] * ea
	return t


## Relative worth of one point of each stat for a class kind ("phy" or "mag"), used for the upgrade verdict.
func stat_weight(k, kind):
	var w = {"hp": 0.15, "mp": 0.1, "phy_def": 0.8, "mag_def": 0.8, "crit_rate": 3.0, "crit_dmg": 0.6, "atk_speed": 2.0, "move_speed": 1.2,
		"hp_regen": 6.0, "mp_regen": 6.0, "vit": 1.0, "luck": 0.5, "drop": 0.3}
	if w.has(k):
		return w[k]
	if k.begins_with("res_"):
		return 0.4
	if kind == "phy":
		return {"phy_atk": 1.4, "str": 1.2, "dex": 1.0, "mag_atk": 0.05, "int": 0.05, "mind": 0.3}.get(k, 0.3)
	return {"mag_atk": 1.4, "int": 1.5, "mind": 1.1, "phy_atk": 0.05, "str": 0.05, "dex": 0.3}.get(k, 0.3)


func worth(it, cls):
	var kind = Game.CLASSES[cls]["kind"] if cls != "" and Game.CLASSES.has(cls) else "phy"
	var s = 0.0
	var t = totals(it)
	for k in t:
		s += t[k] * stat_weight(k, kind)
	return s


## The item currently worn that `it` would replace (for rings/bracelets: the weaker of the two when both are full, or null if a slot is free).
func compare_target(it, p):
	if not is_gear(it) or p == null:
		return null
	var base = slot_of(it)
	if base == "ring" or base == "bracelet":
		var a = p.equip[base + "1"]
		var b = p.equip[base + "2"]
		if a == null or b == null:
			return null
		return a if worth(a, p.char_id) <= worth(b, p.char_id) else b
	return p.equip[base]


## Tooltip lines for `it` with per-stat differences versus `other` (the worn item). Also returns the verdict.
func compare_lines(it, other, cls):
	var out = []
	out.append([name_of(it), color_of(it)])
	var sub_name = ""
	if Game.WEAPONS.has(it["sub"]):
		sub_name = Game.WEAPONS[it["sub"]]["name"]
	elif Game.ARMORS.has(it["sub"]):
		sub_name = Game.ARMORS[it["sub"]]["name"]
	else:
		sub_name = Game.ACCS[it["sub"]]["name"]
	out.append(["%s %s  (iLv %d)" % [Game.RARITY_NAMES[it["rar"]], sub_name, it["ilvl"]], color_of(it)])
	if it["elem"] != "":
		out.append(["Element: " + it["elem"].capitalize(), Game.ELEM_COLOR[it["elem"]]])
	if cls != "" and not can_equip(it, cls):
		out.append(["Your class cannot equip this", Color(1, 0.4, 0.4)])
	var nt = totals(it)
	var ot = totals(other)
	var keys = []
	for k in nt:
		keys.append(k)
	for k in ot:
		if not keys.has(k):
			keys.append(k)
	var up = Color(0.45, 1.0, 0.5)
	var down = Color(1.0, 0.45, 0.4)
	var same = Color(0.85, 0.85, 0.85)
	for k in keys:
		var nv = nt.get(k, 0.0)
		var ov = ot.get(k, 0.0)
		var d = nv - ov
		var is_pct = PCT_STATS.has(k)
		var lab = STAT_LABEL.get(k, k)
		var txt = ""
		if nv > 0.0:
			txt = stat_text(k, nv)
		else:
			txt = "Lose %s" % lab
		var col = same
		if other != null and absf(d) >= 0.05:
			var ds = ("%+.1f" % d) if (is_pct or k.ends_with("regen")) else ("%+d" % int(round(d)))
			txt += "  (%s)" % ds
			col = up if d > 0 else down
		elif other == null:
			col = Color(1, 1, 1) if it["base"].has(k) else Color(0.55, 0.85, 1.0)
		out.append([txt, col])
	if it["u"] != "":
		out.append(["Unique", Color(1.0, 0.8, 0.3)])
	if other == null:
		out.append(["Empty slot - nothing to compare", Color(0.7, 0.8, 1.0)])
	else:
		var ns = worth(it, cls)
		var os = worth(other, cls)
		var pct = (ns - os) / maxf(os, 1.0) * 100.0
		if pct > 4.0:
			out.append(["UPGRADE  (+%d%%)" % int(round(pct)), up])
		elif pct < -4.0:
			out.append(["DOWNGRADE  (%d%%)" % int(round(pct)), down])
		else:
			out.append(["Sidegrade  (about equal)", Color(1, 0.9, 0.5)])
	out.append(["Sell value: %dg" % value(it), Color(1, 0.85, 0.3)])
	return out


func slot_of(it):
	return Game.slot_of(it["sub"])


func can_equip(it, cls):
	if not is_gear(it):
		return false
	var c = Game.CLASSES[cls]
	var sub = it["sub"]
	if Game.WEAPONS.has(sub):
		return c["weapons"].has(sub)
	if Game.ARMORS.has(sub):
		return c["armors"].has(sub)
	return true


func can_stack(a, b):
	return not is_gear(a) and not is_gear(b) and a["id"] == b["id"]


func stat_text(k, v):
	var lab = STAT_LABEL.get(k, k)
	if PCT_STATS.has(k):
		return "+%s%% %s" % [str(snappedf(v, 0.1)), lab]
	if k.ends_with("regen"):
		return "+%s %s/s" % [str(snappedf(v, 0.1)), lab]
	return "+%d %s" % [int(v), lab]


## Tooltip lines: array of [text, color]
func lines(it, cls = ""):
	var out = []
	if it == null:
		return out
	if is_gear(it):
		out.append([name_of(it), color_of(it)])
		var sub_name = ""
		if Game.WEAPONS.has(it["sub"]):
			sub_name = Game.WEAPONS[it["sub"]]["name"]
		elif Game.ARMORS.has(it["sub"]):
			sub_name = Game.ARMORS[it["sub"]]["name"]
		else:
			sub_name = Game.ACCS[it["sub"]]["name"]
		out.append(["%s %s  (iLv %d)" % [Game.RARITY_NAMES[it["rar"]], sub_name, it["ilvl"]], color_of(it)])
		if it["elem"] != "":
			out.append(["Element: " + it["elem"].capitalize(), Game.ELEM_COLOR[it["elem"]]])
		var eb = enchant_mult(it)
		for k in it["base"]:
			out.append([stat_text(k, it["base"][k] * eb), Color(1, 1, 1)])
		for k in it["aff"]:
			out.append([stat_text(k, it["aff"][k] * (1.0 + 0.04 * int(it.get("ench", 0)))), Color(0.55, 0.85, 1.0)])
		if it["u"] != "":
			out.append(["Unique", Color(1.0, 0.8, 0.3)])
		if cls != "" and not can_equip(it, cls):
			out.append(["Your class cannot equip this", Color(1, 0.4, 0.4)])
	else:
		var d = data(it)
		out.append([d["name"], Color(0.95, 0.95, 0.95)])
		var cat = d.get("cat", "mat")
		var label = {"cons": "Potion", "food": "Food", "mat": "Material", "place": "Placeable", "book": "Spell Book"}.get(cat, cat)
		out.append([label, Color(0.7, 0.7, 0.75)])
		if d.has("use"):
			out.append(["Restores %d%% %s" % [int(d["pct"] * 100), d["use"].to_upper()], Color(0.6, 1, 0.6)])
		if d.has("hunger"):
			out.append(["+%d hunger, +%d%% HP" % [d["hunger"], int(d["heal"] * 100)], Color(0.6, 1, 0.6)])
		if d.has("skill"):
			out.append(["Teaches: %s (use from bag)" % Game.SKILLS[d["skill"]]["name"], Color(0.7, 0.8, 1.0)])
		if d.has("buff"):
			out.append(["Grants %s" % Game.FOOD_BUFFS[d["buff"]]["name"], Color(1, 0.9, 0.5)])
	out.append(["Sell value: %dg" % value(it), Color(1, 0.85, 0.3)])
	return out


## numeric usefulness for comparing and auto-sort
func score(it):
	if not is_gear(it):
		return 0.0
	var s = 0.0
	for k in it["base"]:
		s += it["base"][k]
	for k in it["aff"]:
		s += it["aff"][k] * 1.5
	return s + it["rar"] * 10.0


func sort_key(it):
	var order = {"gear": 0, "cons": 1, "food": 2, "book": 3, "place": 4, "mat": 5}
	return order.get(cat_of(it), 5)


# ------------------------------------------------------------------ loot
## Returns list of items dropped by a mob. tier: 0 normal, 1 mini boss.
func roll_drops(mob_id, level, mini, luck_pct, diff = 0.0):
	var d = Game.MOBS[mob_id]
	var out = []
	var mult = (1.0 + luck_pct / 100.0) * (2.0 if mini else 1.0)
	for l in d["loot"]:
		if randf() < minf(l[1] * mult, 1.0):
			var n = 1 + (randi() % 2 if mini else 0)
			out.append(make(l[0], n))
	var gear_chance = (0.07 * d["tier"] + (0.45 if mini else 0.0)) * (1.0 + luck_pct / 100.0)
	if randf() < gear_chance:
		out.append(roll_random_gear(maxi(1, level), -1, luck_pct, diff + (0.5 if mini else 0.0)))
	if randf() < 0.04 * mult:
		out.append(make(["potion_hp_1", "potion_mp_1", "potion_hp_2", "potion_mp_2"][randi() % 4], 1))
	return out


func scatter(items, pos):
	var i = 0
	for it in items:
		var a = TAU * float(i) / maxf(items.size(), 1.0) + randf() * 0.5
		Game.drop_item(it, pos + Vector2(cos(a), sin(a)) * (6.0 + 4.0 * items.size()))
		i += 1


func boss_unique_for(boss_id):
	var list = []
	for k in Game.UNIQUES:
		if Game.UNIQUES[k]["boss"] == boss_id:
			list.append(k)
	return list
