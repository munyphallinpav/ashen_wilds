extends Node
## Adventurer NPCs ("heroes") and the guild dungeon board.
## Heroes have a class, level, gold, skills, gear and inventory like the player. They roam the world hunting monsters
## (as real fighters when you are close, simulated when far away), sell loot, buy potions and gear, take guild quests,
## and play dungeons listed on the guild board. Everybody (you and them) can list dungeons and earns a cut when others play them.
const HeroScript = preload("res://scripts/hero.gd")
const NAMES = ["Aria", "Bram", "Cora", "Dorn", "Elyse", "Fenn", "Gwen", "Hale", "Isolde", "Joren", "Kira", "Lorn", "Mira", "Nox", "Orin",
	"Pia", "Quill", "Rhea", "Soren", "Tamsin", "Ulric", "Vera", "Wren", "Xander", "Yara", "Zeph", "Alder", "Briar", "Cael", "Dara",
	"Eryk", "Flora", "Garrick", "Hazel", "Ivo", "Jessa", "Kael", "Lyra", "Mace", "Nyla", "Osric", "Petra", "Rook", "Sable", "Tobin",
	"Una", "Vance", "Willa", "Yorick", "Zora"]
const CLS = ["warrior", "ranger", "assassin", "mage", "priest"]
const CLS_DMG = {"warrior": 1.0, "ranger": 1.05, "assassin": 1.15, "mage": 1.2, "priest": 0.8}
const CLS_HP = {"warrior": 1.25, "ranger": 0.95, "assassin": 0.9, "mage": 0.85, "priest": 1.0}
const CLS_RANGE = {"warrior": 18.0, "ranger": 110.0, "assassin": 16.0, "mage": 100.0, "priest": 90.0}
const CLS_COL = {"warrior": Color(1, 0.6, 0.4), "ranger": Color(0.6, 1, 0.5), "assassin": Color(0.8, 0.6, 1), "mage": Color(0.5, 0.8, 1), "priest": Color(1, 1, 0.7)}
const NPC_LISTING_MAX = 12

var nodes = {}
var t_sim = 0.0
var t_sync = 0.0
var t_pop = 6.0
var notify_t = 0.0
var pending_note = ""


func _ready():
	Game.heroes_mgr = self


func _exit_tree():
	if Game.heroes_mgr == self:
		Game.heroes_mgr = null


# ---------------------------------------------------------------- creation / stats
func town_center():
	return Vector2(Game.W * 8.0, Game.H * 8.0)


func get_hero(id) -> Variant:
	for h in Game.heroes:
		if h["id"] == id:
			return h
	return null


func get_listing(id) -> Variant:
	for l in Game.listings:
		if l["id"] == id:
			return l
	return null


func start_new():
	Game.heroes = []
	Game.listings = []
	Game.stash = {"gold": 0, "items": []}
	Game.listing_slots = 3
	Game.hero_next = 1
	Game.hero_base = randi_range(2, 5)
	var plv = Game.player.level if Game.player != null else 1
	for i in range(Game.hero_base):
		new_hero(clampi(plv + randi_range(0, 2), 1, 100))
	ensure_board()


func target_count():
	return mini(Game.HERO_MAX, Game.hero_base + int(Game.player.level * 0.48))


func new_hero(level):
	var used = []
	for h0 in Game.heroes:
		used.append(h0["name"])
	var nm = ""
	for i in range(30):
		nm = NAMES[randi() % NAMES.size()]
		if not used.has(nm):
			break
	if used.has(nm):
		nm += str(Game.hero_next)
	var cls = CLS[randi() % CLS.size()]
	var c = town_center() + Vector2(randf_range(-60, 60), randf_range(20, 70))
	var h = {"id": "h%d" % Game.hero_next, "name": nm, "cls": cls, "level": level, "xp": 0.0, "gold": 40 + level * 10, "hp": 1.0,
		"pos": [c.x, c.y], "act": "town", "act_t": randf_range(3.0, 9.0), "act_d": {}, "gear": {}, "inv": [], "potions": 3,
		"kills": 0, "deaths": 0, "earned": 0, "skills": [], "listing": -1, "runs": 0, "last": "Joined the guild"}
	Game.hero_next += 1
	var info = Game.CLASSES[cls]
	h["gear"][Game.slot_of(info["start"][0])] = Items.roll_gear(info["start"][0], maxi(1, level), 0)
	h["gear"][Game.slot_of(info["start"][1])] = Items.roll_gear(info["start"][1], maxi(1, level), 0)
	for i in range(maxi(0, level / 6)):
		_try_gear(h, level, -1)
	refresh_skills(h)
	h["hp"] = max_hp(h)
	Game.heroes.append(h)
	return h


func tier(h):
	var s = 0.0
	for it in h["gear"].values():
		s += float(it["rar"]) + 0.3 * float(it.get("ench", 0))
	return s / maxf(1.0, float(h["gear"].size()))


func max_hp(h):
	return (70.0 + h["level"] * 30.0) * CLS_HP[h["cls"]] * (1.0 + 0.06 * tier(h))


func dmg(h):
	return 9.0 * Game.mob_dmg_scale(h["level"]) * CLS_DMG[h["cls"]] * (1.0 + 0.12 * tier(h))


func power(h):
	return h["level"] * (1.0 + 0.12 * tier(h)) * (0.9 + 0.1 * CLS_DMG[h["cls"]])


func refresh_skills(h):
	var list = []
	for id in Game.SKILLS:
		var s = Game.SKILLS[id]
		if s.get("cls", "") == h["cls"] and s.get("type", "") == "active" and int(s.get("lvl", 1)) <= h["level"]:
			list.append(id)
	list.sort_custom(func(a, b): return Game.SKILLS[a]["lvl"] > Game.SKILLS[b]["lvl"])
	h["skills"] = list.slice(0, 4)


func add_xp(h, amount):
	var plv = Game.player.level if Game.player != null else 1
	var cap = plv + 6
	if h["level"] >= cap:
		amount *= 0.1
	elif h["level"] < plv * 0.85:
		amount *= 2.0
	h["xp"] += amount
	while h["level"] < 100 and h["xp"] >= Game.xp_need(h["level"]):
		h["xp"] -= Game.xp_need(h["level"])
		h["level"] += 1
		refresh_skills(h)
		h["hp"] = max_hp(h)
		if h["level"] % 3 == 0:
			_try_gear(h, h["level"], -1)
		if h["level"] % 5 == 0 and h["listing"] < 0:
			_make_hero_listing(h)


func _try_gear(h, ilvl, rar):
	for i in range(8):
		var it = Items.roll_random_gear(ilvl, rar)
		if not Items.can_equip(it, h["cls"]):
			continue
		var slot = Game.slot_of(it["sub"])
		var old = h["gear"].get(slot, null)
		if old == null or Items.score(it) > Items.score(old):
			h["gear"][slot] = it
			return true
	return false


func _add_inv(h, it):
	if Items.is_gear(it):
		var slot = Game.slot_of(it["sub"])
		var old = h["gear"].get(slot, null)
		if Items.can_equip(it, h["cls"]) and (old == null or Items.score(it) > Items.score(old)):
			h["gear"][slot] = it
			return
	for s in h["inv"]:
		if not Items.is_gear(it) and not Items.is_gear(s) and s["id"] == it["id"] and not s.has("bp"):
			s["n"] += it["n"]
			return
	if h["inv"].size() < 14:
		h["inv"].append(it)


# ---------------------------------------------------------------- credit from real kills
func credit_kill(id, type, level, mini, pos):
	var h = get_hero(id)
	if h == null:
		return
	var d = Game.MOBS[type]
	var xp = d["xp"] * 4.0 * pow(maxf(level, 1), 1.3) * (3.0 if mini else 1.0)
	var gold = d["gold"] * (3.0 + level * 2.2) * randf_range(0.6, 1.4) * (5.0 if mini else 1.0)
	h["gold"] += int(gold)
	h["earned"] += int(gold)
	h["kills"] += 1
	add_xp(h, xp)
	for it in Items.roll_drops(type, level, mini, 0.0, 0.0):
		_add_inv(h, it)
	h["last"] = "Slew a %s" % d["name"]


# ---------------------------------------------------------------- per-frame
func _process(delta):
	if Game.player == null or Game.world == null:
		return
	t_sim += delta
	if t_sim >= 1.0:
		var dt = t_sim
		t_sim = 0.0
		for h in Game.heroes:
			_sim(h, dt)
	t_sync += delta
	if t_sync >= 0.6:
		t_sync = 0.0
		_sync_nodes()
	t_pop += delta
	if t_pop >= 15.0:
		t_pop = 0.0
		ensure_board()
		if Game.heroes.size() < target_count():
			var h = new_hero(clampi(Game.player.level + randi_range(-3, 1), 1, 100))
			Game.notify("%s the %s joined the Adventurer Guild" % [h["name"], Game.CLASSES[h["cls"]]["name"]])
	notify_t -= delta
	if pending_note != "" and notify_t <= 0.0:
		Game.notify(pending_note)
		pending_note = ""
		notify_t = 25.0


func _sync_nodes():
	var p = Game.player
	for h in Game.heroes:
		var id = h["id"]
		var pos = Vector2(h["pos"][0], h["pos"][1])
		var want = Game.dlayout == null and (h["act"] == "hunt" or h["act"] == "town") and pos.distance_to(p.global_position) < 480.0
		if want and not nodes.has(id):
			var n = HeroScript.new()
			n.h = h
			n.mgr = self
			Game.entities.add_child(n)
			nodes[id] = n
		elif nodes.has(id):
			var nd = nodes[id]
			if not is_instance_valid(nd):
				nodes.erase(id)
			elif not want and (Game.dlayout != null or h["act"] not in ["hunt", "town"] or pos.distance_to(p.global_position) > 640.0):
				nd.queue_free()
				nodes.erase(id)


func has_node_for(h):
	return nodes.has(h["id"]) and is_instance_valid(nodes[h["id"]])


# ---------------------------------------------------------------- simulation (1 tick per second)
func _set_act(h, act, t, d = {}):
	h["act"] = act
	h["act_t"] = t
	h["act_d"] = d


func in_town(pos):
	var c = town_center()
	return absf(pos.x - c.x) < 256.0 and absf(pos.y - c.y) < 208.0


func random_hunt_pos(level):
	var best = null
	for i in range(60):
		var pos = Vector2(randf_range(64.0, Game.W * 16.0 - 64.0), randf_range(64.0, Game.H * 16.0 - 64.0))
		if in_town(pos) or pos.distance_to(town_center()) < 330.0:
			continue
		if not Game.world.open_area(int(pos.x / 16.0), int(pos.y / 16.0), 1):
			continue
		best = pos
		if absi(Game.world.level_at(pos) - level) <= 6:
			return pos
	return best if best != null else town_center() + Vector2(0, 420)


func _sim(h, dt):
	var node = has_node_for(h)
	h["act_t"] -= dt
	match h["act"]:
		"hunt":
			if not node:
				_sim_hunt(h, dt)
			if h["act_t"] <= 0.0:
				_next(h)
		"recall":
			if h["act_t"] <= 0.0:
				var c = town_center() + Vector2(randf_range(-70, 70), randf_range(40, 90))
				h["pos"] = [c.x, c.y]
				_set_act(h, "town", randf_range(8.0, 16.0))
				_arrive_town(h)
		"town":
			h["hp"] = minf(max_hp(h), h["hp"] + max_hp(h) * 0.12 * dt)
			if h["act_t"] <= 0.0:
				_next(h)
		"quest":
			if h["act_t"] <= 0.0:
				var g = 30 + h["level"] * 14
				h["gold"] += g
				h["earned"] += g
				add_xp(h, 30.0 * pow(float(h["level"]), 1.3))
				h["last"] = "Finished guild quest: %s" % h["act_d"].get("name", "quest")
				_next(h)
		"dungeon":
			if h["act_t"] <= 0.0:
				_resolve_run(h)
				_next(h)


func _sim_hunt(h, dt):
	var rate = 0.07 * (1.0 + 0.1 * tier(h)) * (0.8 + 0.2 * CLS_DMG[h["cls"]])
	h["act_d"]["k"] = h["act_d"].get("k", 0.0) + rate * dt
	while h["act_d"]["k"] >= 1.0:
		h["act_d"]["k"] -= 1.0
		var types = []
		for t in Game.MOBS:
			if Game.MOBS[t]["mode"] == "hostile" and t != "mimic":
				types.append(t)
		var t2 = types[randi() % types.size()]
		credit_kill(h["id"], t2, h["level"], false, Vector2.ZERO)
		h["hp"] -= max_hp(h) * randf_range(0.03, 0.09)
		if h["hp"] < max_hp(h) * 0.35:
			if h["potions"] > 0:
				h["potions"] -= 1
				h["hp"] += max_hp(h) * 0.5
			else:
				_recall(h)
				return
	# slow drift so the hero is not frozen in place
	if randf() < 0.2:
		var np = Vector2(h["pos"][0], h["pos"][1]) + Vector2(randf_range(-40, 40), randf_range(-40, 40))
		if Game.world.is_walkable(np):
			h["pos"] = [np.x, np.y]


func _recall(h):
	_set_act(h, "recall", 8.0)
	h["last"] = "Recalled to town"
	if has_node_for(h):
		Game.spawn_fx("light", nodes[h["id"]].global_position)


func hero_hurt(h):
	if h["hp"] <= 0.0:
		h["deaths"] += 1
		h["gold"] = int(h["gold"] * 0.9)
		h["hp"] = max_hp(h) * 0.5
		h["last"] = "Was defeated and recalled"
		_recall(h)


func _arrive_town(h):
	var total = 0
	var keep = []
	for it in h["inv"]:
		total += int(Items.value(it) * 0.5) * int(it["n"] if not Items.is_gear(it) else 1)
	h["inv"] = keep
	h["gold"] += total
	while h["potions"] < 5 and h["gold"] >= 25:
		h["potions"] += 1
		h["gold"] -= 25
	var cost = 60 + h["level"] * 40
	if h["gold"] >= cost * 1.5:
		h["gold"] -= cost
		_try_gear(h, h["level"], Items.roll_rarity(0.0, 0.0))
	h["hp"] = maxf(h["hp"], max_hp(h) * 0.6)
	h["last"] = "Sold loot (+%dg) and restocked" % total


func _next(h):
	var in_t = h["act"] == "town"
	if h["act"] != "town" and h["act"] != "recall" and (h["hp"] < max_hp(h) * 0.5 or h["inv"].size() >= 12 or (h["potions"] == 0 and h["gold"] >= 25)):
		_recall(h)
		return
	var r = randf()
	var cand = _candidates(h)
	if r < 0.22 and cand.size() > 0:
		var l = cand[randi() % cand.size()]
		_set_act(h, "dungeon", randf_range(70.0, 130.0), {"listing": l["id"]})
		h["last"] = "Entered %s" % l["name"]
		if in_t:
			pass
	elif r < 0.37:
		var types = []
		for t in Game.MOBS:
			if Game.MOBS[t]["mode"] == "hostile" and t != "mimic":
				types.append(t)
		var mt = types[randi() % types.size()]
		_set_act(h, "quest", randf_range(45.0, 95.0), {"name": "Hunt %d %ss" % [randi_range(6, 14), Game.MOBS[mt]["name"]]})
		h["last"] = "Took guild quest: %s" % h["act_d"]["name"]
	else:
		var np = random_hunt_pos(h["level"])
		var was_town = in_town(Vector2(h["pos"][0], h["pos"][1]))
		_set_act(h, "hunt", randf_range(50.0, 110.0))
		if was_town:
			# walks out the south gate (real hero) or simply appears in the field (simulated)
			if has_node_for(h):
				h["act_d"]["leave"] = true
			else:
				h["pos"] = [np.x, np.y]
		elif not has_node_for(h):
			h["pos"] = [np.x, np.y]
		h["last"] = "Hunting monsters"


func relocate_to_field(h):
	if has_node_for(h):
		nodes[h["id"]].queue_free()
		nodes.erase(h["id"])
	var np = random_hunt_pos(h["level"])
	h["pos"] = [np.x, np.y]
	h["act_d"].erase("leave")


# ---------------------------------------------------------------- guild dungeon board
func _candidates(h):
	var out = []
	for l in Game.listings:
		if l["owner"] == h["id"]:
			continue
		var rk = int(l["bp"]["rank"])
		if rk >= h["level"] - 6 and rk <= h["level"] + 10 and l["cut"] <= 0.25:
			out.append(l)
	return out


func npc_listing_count():
	var n = 0
	for l in Game.listings:
		if l["owner"] != "player":
			n += 1
	return n


## keep a few adventurer dungeons on the board, ranked around the player's level
func ensure_board():
	if npc_listing_count() >= 3:
		return
	for h in Game.heroes:
		if h["listing"] < 0 or get_listing(h["listing"]) == null:
			_make_hero_listing(h, Game.player.level + randi_range(-2, 6))
			if npc_listing_count() >= 3:
				return
	# still short (very few adventurers): let them list a second dungeon
	for h in Game.heroes:
		if npc_listing_count() >= 3:
			return
		_make_hero_listing(h, Game.player.level + randi_range(-2, 6))


func _make_hero_listing(h, rank = -1):
	if npc_listing_count() >= NPC_LISTING_MAX:
		return
	if rank < 0:
		rank = h["level"] + randi_range(-1, 3)
	var bp = Game.random_bp(rank, "%s's Trial" % h["name"])
	var cut = snappedf(randf_range(0.05, 0.25), 0.05)
	var l = add_listing(h["id"], bp["name"], bp, cut)
	h["listing"] = l["id"]
	h["last"] = "Listed a dungeon on the board"


func add_listing(owner, nm, bp, cut):
	var l = {"id": Game.listing_next, "owner": owner, "name": nm, "bp": bp, "cut": cut, "runs": 0, "earned": 0}
	Game.listing_next += 1
	Game.listings.append(l)
	return l


func owner_name(l):
	if l["owner"] == "player":
		return "You"
	var h = get_hero(l["owner"])
	return h["name"] if h != null else "Unknown"


func dungeon_value(bp):
	var rank = int(bp["rank"])
	var diff = mini(rank / 21, 4)
	var base = 3.0 + rank * 2.2
	var mobs = 0
	var minis = 0
	var chests = 3 + diff
	if bp.get("manual", false):
		mobs = 0
		chests = 0
		for k in bp["map"]["rooms"]:
			var rd = bp["map"]["rooms"][k]
			mobs += rd["mobs"].size() + rd["spawners"].size() * 2
			for e in rd["mobs"]:
				if e.get("m", false):
					minis += 1
			chests += rd["chests"].size()
			if rd["rand"]["live"] and rd["rand"]["mobs"]:
				mobs += 4
		mobs = maxi(mobs, 3)
	else:
		var rooms = maxi(1, int(bp["grid"]) * int(bp["grid"]) - 2)
		mobs = rooms * int(bp["mobs"]) + int(bp["spawners"]) * 2
		minis = int(bp["minis"])
	var xp_unit = pow(float(rank), 1.3)
	return {"gold": mobs * base * 0.9 + minis * base * 5.0 + chests * base * (2.0 + diff) * 1.2 + 20.0 * base,
		"xp": mobs * 4.0 * xp_unit * 1.2 + minis * 12.0 * xp_unit + 80.0 * xp_unit,
		"items": int(minis * 1.5 + chests + mobs * 0.15 + 2)}


func _loot_roll(rank):
	if randf() < 0.4:
		return Items.roll_random_gear(rank, -1)
	var types = []
	for t in Game.MOBS:
		if Game.MOBS[t]["mode"] == "hostile" and t != "mimic":
			types.append(t)
	var drops = Items.roll_drops(types[randi() % types.size()], rank, false, 0.0, 0.0)
	return drops[0] if drops.size() > 0 else null


func _resolve_run(h):
	var l = get_listing(int(h["act_d"].get("listing", -1)))
	if l == null:
		h["last"] = "The dungeon was gone"
		return
	var rank = int(l["bp"]["rank"])
	var ratio = power(h) / maxf(1.0, float(rank))
	var p = clampf(0.55 + (ratio - 1.0) * 0.9, 0.12, 0.95)
	var ok = randf() < p
	var f = 1.0 if ok else 0.3
	var val = dungeon_value(l["bp"])
	var gold_total = val["gold"] * 0.5 * f
	var cut = l["cut"]
	var to_owner = int(gold_total * cut)
	var mine = int(gold_total - to_owner)
	h["gold"] += mine
	h["earned"] += mine
	add_xp(h, val["xp"] * 0.5 * f)
	var owner_items = []
	for i in range(maxi(1, int(val["items"] * f))):
		var it = _loot_roll(rank)
		if it == null:
			continue
		if randf() < cut:
			owner_items.append(it)
		else:
			_add_inv(h, it)
	_pay_owner(l, to_owner, owner_items, h["name"], ok)
	l["runs"] += 1
	if not ok:
		h["hp"] = max_hp(h) * 0.3
	h["runs"] += 1
	h["last"] = ("Cleared %s" % l["name"]) if ok else ("Failed %s" % l["name"])


## gold / items arriving at the owner of a listing (the player's go to the stash, a hero's to its purse)
func _pay_owner(l, gold, items, who, ok):
	l["earned"] += gold
	if l["owner"] == "player":
		Game.stash["gold"] += gold
		for it in items:
			if Game.stash["items"].size() < 60:
				Game.stash["items"].append(it)
		pending_note = "%s %s your dungeon \"%s\": +%dg for you" % [who, "cleared" if ok else "attempted", l["name"], gold]
	else:
		var oh = get_hero(l["owner"])
		if oh != null:
			oh["gold"] += gold
			oh["earned"] += gold
			for it in items:
				_add_inv(oh, it)


## the player paid the owner of a listing a share of a reward (gold) while running it
func player_paid_owner(l, gold):
	_pay_owner(l, gold, [], "You", true)


func player_item_cut(l, it):
	if l["owner"] == "player":
		return
	var oh = get_hero(l["owner"])
	if oh != null:
		_add_inv(oh, it)


func collect_stash():
	var p = Game.player
	var g = int(Game.stash["gold"])
	p.add_gold(g)
	Game.stash["gold"] = 0
	var left = []
	for it in Game.stash["items"]:
		if not p.add_item(it, true):
			left.append(it)
	Game.stash["items"] = left
	Game.notify("Collected %dg%s" % [g, " (bag full - items left)" if left.size() > 0 else ""])


func list_seal(inv_idx, cut):
	var p = Game.player
	var it = p.inv[inv_idx]
	var mine = 0
	for l in Game.listings:
		if l["owner"] == "player":
			mine += 1
	if it == null or not it.has("bp") or mine >= Game.listing_slots:
		return false
	p.inv[inv_idx] = null
	p.inventory_changed.emit()
	add_listing("player", it["bp"]["name"], it["bp"].duplicate(true), cut)
	return true


func withdraw(l):
	var p = Game.player
	var it = {"id": "dungeon_seal", "n": 1, "bp": l["bp"].duplicate(true)}
	if not p.add_item(it, true):
		Game.notify("Bag is full")
		return false
	Game.listings.erase(l)
	return true


func slot_cost():
	return 400 * (Game.listing_slots - 2)


# ---------------------------------------------------------------- save / load
func to_save():
	return {"heroes": Game.heroes, "hero_next": Game.hero_next, "hero_base": Game.hero_base, "listings": Game.listings,
		"listing_next": Game.listing_next, "slots": Game.listing_slots, "stash": Game.stash}


func from_save(d):
	if not d.has("heroes"):
		start_new()
		return
	Game.heroes = []
	for h in d["heroes"]:
		h["level"] = int(h["level"])
		h["gold"] = int(h["gold"])
		h["potions"] = int(h["potions"])
		h["kills"] = int(h["kills"])
		h["deaths"] = int(h["deaths"])
		h["earned"] = int(h["earned"])
		h["listing"] = int(h["listing"])
		h["runs"] = int(h.get("runs", 0))
		var gear = {}
		for k in h["gear"]:
			gear[k] = Game.player._fix_item(h["gear"][k])
		h["gear"] = gear
		var inv = []
		for it in h["inv"]:
			var f = Game.player._fix_item(it)
			if f != null:
				inv.append(f)
		h["inv"] = inv
		if h["act"] == "dungeon" and not h["act_d"].has("listing"):
			h["act"] = "town"
		Game.heroes.append(h)
	Game.hero_next = int(d["hero_next"])
	Game.hero_base = int(d["hero_base"])
	Game.listings = []
	for l in d.get("listings", []):
		l["id"] = int(l["id"])
		l["cut"] = float(l["cut"])
		l["runs"] = int(l["runs"])
		l["earned"] = int(l["earned"])
		l["bp"] = Game.fix_bp(l["bp"])
		if l["owner"] != "player" and get_hero(str(l["owner"])) == null:
			continue
		Game.listings.append(l)
	Game.listing_next = int(d["listing_next"])
	Game.listing_slots = clampi(int(d["slots"]), 3, Game.SLOTS_MAX)
	var st = d.get("stash", {"gold": 0, "items": []})
	Game.stash = {"gold": int(st["gold"]), "items": []}
	for it in st["items"]:
		var f2 = Game.player._fix_item(it)
		if f2 != null:
			Game.stash["items"].append(f2)
