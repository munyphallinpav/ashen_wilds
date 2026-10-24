extends CharacterBody2D
## Player: class stats, inventory + equipment, skills, hunger, buffs, basic attacks per weapon type.

signal inventory_changed
signal stats_changed

var char_id = "warrior"
var cdata = {}
var level = 1
var xp = 0
var gold = 50
var stat_alloc = {"str": 0, "vit": 0, "int": 0, "mind": 0, "dex": 0, "luck": 0}
var stat_pts = 10
var skill_pts = 5
var ranks = {}
var cd = {}
var cd_max = {}
var inv = []
var bag_size = Game.BAG_CAP
var equip = {"weapon": null, "armor": null, "necklace": null, "ring1": null, "ring2": null, "bracelet1": null, "bracelet2": null}
var loadout = ["", "", "", ""]
var tomes = {}
var quests = []
var board = []
var board_t = -9999.0
var stats = {}
var res = {}
var max_hp = 100.0
var max_mp = 50.0
var hp = 100.0
var mp = 50.0
var hunger = 100.0
var buffs = {}          # id -> {"t": sec, "mods": {}}
var statuses = []       # [kind, time_left, power]
var hots = []           # [time_left, per_second]
var aim = Vector2.DOWN
var move_dir = Vector2.ZERO
var face_name = "down"
var face_flip = false
var atk_cd = 0.0
var combat_t = 0.0
var anim_lock = 0.0
var lock_anim = "attack"
var invuln = 0.0
var knock = Vector2.ZERO
var dead = false
var swinging = false
var sprite
var pivot
var wsprite
var recalc_t = 0.0
var dot_t = 0.0
var regen_acc = 0.0


func _ready():
	cdata = Game.CLASSES[char_id]
	add_to_group("player")
	collision_layer = 4
	collision_mask = 1
	var cs = CollisionShape2D.new()
	var c = CircleShape2D.new()
	c.radius = 4.5
	cs.shape = c
	cs.position = Vector2(0, -3)
	add_child(cs)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Game.char_frames(cdata["sheet"])
	sprite.position = Vector2(0, -12)
	add_child(sprite)
	sprite.play("idle_down")
	pivot = Node2D.new()
	pivot.position = Vector2(0, -9)
	add_child(pivot)
	wsprite = Sprite2D.new()
	wsprite.offset = Vector2(0, -15)
	pivot.add_child(wsprite)
	if inv.size() != bag_size:
		inv.resize(bag_size)
	recalc()
	hp = max_hp
	mp = max_mp
	refresh_weapon()


func new_game_kit():
	for k in cdata["base"]:
		pass
	var st = cdata["start"]
	equip["weapon"] = Items.roll_gear(st[0], 1, 0)
	equip["armor"] = Items.roll_gear(st[1], 1, 0)
	add_item(Items.make("potion_hp_1", 5))
	add_item(Items.make("potion_mp_1", 3))
	add_item(Items.make("cooked_meat", 4))
	add_item(Items.make("campfire", 1))
	recalc()
	hp = max_hp
	mp = max_mp
	refresh_weapon()


func origin():
	return global_position + Vector2(0, -9)


# ------------------------------------------------------------------ stats
func base_stat(k):
	return float(cdata["base"][k] + stat_alloc[k])


func gear_totals():
	var g = {}
	for sl in equip:
		var it = equip[sl]
		if it == null:
			continue
		var t = Items.totals(it)
		for k in t:
			g[k] = g.get(k, 0.0) + t[k]
	return g


func recalc():
	var g = gear_totals()
	var m = Skills.passive_mods(self)
	for id in buffs:
		var bm = buffs[id]["mods"]
		for k in bm:
			m[k] = m.get(k, 0.0) + bm[k]
	var slow = 0.0
	for s in statuses:
		if s[0] == "slow":
			slow = maxf(slow, s[2])
	var s = {}
	for k in Game.STATS:
		s[k] = base_stat(k) + g.get(k, 0.0)
	for k in Game.STATS:
		s[k] += m.get(k, 0.0)
	s["max_hp"] = (40.0 + s["vit"] * 6.0 + s["str"] * 2.0 + level * 8.0 + g.get("hp", 0.0)) * (1.0 + m.get("hp_pct", 0.0))
	s["max_mp"] = (20.0 + s["mind"] * 4.0 + s["int"] * 2.0 + level * 3.0 + g.get("mp", 0.0)) * (1.0 + m.get("mp_pct", 0.0))
	s["phy_atk"] = (5.0 + s["str"] * 1.2 + s["dex"] * 0.2 + g.get("phy_atk", 0.0)) * (1.0 + m.get("phy_atk_pct", 0.0))
	s["mag_atk"] = (5.0 + s["int"] * 1.4 + s["mind"] * 0.2 + g.get("mag_atk", 0.0)) * (1.0 + m.get("mag_atk_pct", 0.0))
	s["phy_def"] = (s["vit"] + s["str"] * 0.3 + g.get("phy_def", 0.0)) * (1.0 + m.get("phy_def_pct", 0.0))
	s["mag_def"] = (s["mind"] + s["int"] * 0.3 + g.get("mag_def", 0.0)) * (1.0 + m.get("mag_def_pct", 0.0))
	s["move_speed"] = (1.0 + g.get("move_speed", 0.0) / 100.0 + m.get("move_pct", 0.0)) * (1.0 - slow)
	s["atk_speed"] = 1.0 + s["dex"] * 0.006 + g.get("atk_speed", 0.0) / 100.0 + m.get("aspd_pct", 0.0)
	s["crit_rate"] = 5.0 + s["luck"] * 0.12 + g.get("crit_rate", 0.0) + m.get("crit_rate", 0.0)
	s["crit_dmg"] = 150.0 + s["luck"] * 0.4 + g.get("crit_dmg", 0.0) + m.get("crit_dmg", 0.0)
	s["drop"] = g.get("drop", 0.0) + s["luck"] * 0.3 + m.get("drop_pct", 0.0) * 100.0
	s["heal_pct"] = m.get("heal_pct", 0.0)
	s["hp_regen"] = 0.6 + level * 0.03 + g.get("hp_regen", 0.0) + m.get("hp_regen", 0.0)
	# Casters (mage/priest) regen scales with their pool so it keeps up with skill costs; priest sustains better, mage bursts.
	var rm = cdata.get("mp_regen_mult", 0.0)
	if rm > 0.0:
		s["mp_regen"] = (1.5 + s["mind"] * 0.06 + s["max_mp"] * 0.010) * rm + g.get("mp_regen", 0.0) + m.get("mp_regen", 0.0)
	else:
		s["mp_regen"] = 2.0 + s["mind"] * 0.05 + g.get("mp_regen", 0.0) + m.get("mp_regen", 0.0)
	for e in Game.ELEMENTS:
		res[e] = minf(g.get("res_" + e, 0.0) + m.get("res_all", 0.0) + m.get("res_" + e, 0.0), 75.0)
		s["res_" + e] = res[e]
	stats = s
	var ratio = hp / max_hp if max_hp > 0.0 else 1.0
	max_hp = s["max_hp"]
	max_mp = s["max_mp"]
	hp = minf(max_hp, ratio * max_hp) if hp < max_hp else max_hp
	mp = minf(mp, max_mp)
	stats_changed.emit()


func weapon_sub():
	var w = equip["weapon"]
	return w["sub"] if w != null else ""


func weapon_def():
	var sub = weapon_sub()
	if sub == "":
		return {"name": "Fists", "kind": "phy", "atk": 0, "style": "swing", "cd": 0.5, "reach": 18.0, "arc": 1.0}
	return Game.WEAPONS[sub]


func refresh_weapon():
	var w = equip["weapon"]
	wsprite.texture = Items.icon(w) if w != null else null
	if w != null:
		wsprite.modulate = Color.WHITE


func add_buff(id, dur, mods):
	buffs[id] = {"t": dur, "mods": mods}
	recalc()


func add_status(kind, dur, pw, dmg_hint = 0.0):
	if kind == "burn" or kind == "poison":
		var dps = dmg_hint * pw / maxf(dur, 0.1)
		statuses.append([kind, dur, dps])
	else:
		statuses.append([kind, dur, pw])
	recalc()


func heal(amount):
	if dead:
		return
	Audio.sfx("heal", 0.6, 1.0, 0.4)
	var a = amount
	hp = minf(max_hp, hp + a)
	Game.float_text("+%d" % int(a), global_position, Color(0.4, 1, 0.5))


func heal_over(total, dur):
	hots.append([dur, total / dur])


func xp_to_next():
	return Game.xp_need(level)


func add_xp(n):
	if level >= Game.MAX_LEVEL:
		return
	xp += int(n)
	var lv_up = false
	while level < Game.MAX_LEVEL and xp >= Game.xp_need(level):
		xp -= Game.xp_need(level)
		level += 1
		stat_pts += 10
		skill_pts += 5
		lv_up = true
	if level >= Game.MAX_LEVEL:
		xp = 0
	if lv_up:
		recalc()
		hp = max_hp
		mp = max_mp
		Game.notify("LEVEL UP! Lv %d  (+10 stat pts, +5 skill pts)" % level)
		Audio.sfx("levelup", 1.0)
		Game.float_text("LEVEL UP", global_position, Color(1, 0.9, 0.3), 10)
		Game.spawn_fx("aura", global_position + Vector2(0, -8))
	stats_changed.emit()


func alloc_stat(k):
	if stat_pts <= 0:
		return false
	stat_alloc[k] += 1
	stat_pts -= 1
	recalc()
	return true


func respec_cost():
	return 40 * level


func respec():
	var cost = respec_cost()
	if gold < cost:
		Game.notify("Need %dg to reset stats" % cost)
		return false
	var total = 0
	for k in stat_alloc:
		total += stat_alloc[k]
		stat_alloc[k] = 0
	gold -= cost
	stat_pts += total
	recalc()
	return true


func add_gold(n):
	gold += int(n)
	if n > 0:
		Audio.sfx("coin", 0.7)
		Game.float_text("+%dg" % n, global_position + Vector2(0, -8), Color(1, 0.85, 0.2))
	inventory_changed.emit()


# ------------------------------------------------------------------ main loop
var dash_cd = 0.0
const DASH_CD = 1.4


## Default ability for every class (Ctrl or right mouse button): short dash with brief invulnerability.
func try_dash():
	if dash_cd <= 0.0 and not dead:
		Audio.sfx("dash", 0.8)
	if dash_cd > 0.0 or dead:
		return
	dash_cd = DASH_CD
	var dir = move_dir if move_dir != Vector2.ZERO else aim
	var target = dash_target(60.0, dir)
	var start = global_position
	invuln = maxf(invuln, 0.3)
	Game.spawn_fx("wind", start + Vector2(0, -6), {"scl": 0.6})
	var tw = create_tween()
	tw.tween_property(self, "global_position", target, 0.14)
	for i in range(5):
		Game.ghost_at(self, start.lerp(target, i / 4.0) + Vector2(0, -6))
		await get_tree().create_timer(0.03).timeout


var recall_t = 0.0
var recall_cd = 0.0
const RECALL_TIME = 3.0
const RECALL_CD = 20.0


var recall_dest = null     # null = town, else a dungeon record to teleport to


func teleport_cost(rec):
	return 20 + 2 * int(rec["level"])


func start_teleport_dungeon(rec):
	if dead or recall_t > 0.0:
		return
	if Game.cur_dungeon != null:
		Game.notify("Leave the dungeon first")
		return
	if recall_cd > 0.0:
		Game.notify("Teleport ready in %ds" % ceili(recall_cd))
		return
	if gold < teleport_cost(rec):
		Game.notify("Need %dg to teleport there" % teleport_cost(rec))
		return
	recall_dest = rec
	recall_t = RECALL_TIME
	Game.notify("Teleporting to the dungeon... (stand still)")


func start_recall():
	recall_dest = null
	if dead or recall_t > 0.0:
		return
	if recall_cd > 0.0:
		Game.notify("Recall ready in %ds" % ceili(recall_cd))
		return
	if Game.world != null and Game.cur_dungeon == null and absf(position.x - Game.world.spawn_pos.x) < Game.world.TOWN_HX - 16.0 and absf(position.y - Game.world.spawn_pos.y) < Game.world.TOWN_HY - 16.0:
		Game.notify("You are already in town")
		return
	recall_t = RECALL_TIME
	Game.notify("Recalling to town... (stand still)")


func _recall_tick(delta, moving):
	recall_cd = maxf(0.0, recall_cd - delta)
	if recall_t <= 0.0:
		return
	if moving:
		recall_t = 0.0
		Game.notify("Recall cancelled")
		return
	recall_t -= delta
	sprite.modulate = Color(0.6, 0.85, 1.0).lerp(Color.WHITE, 0.5 + 0.5 * sin(recall_t * 14.0))
	if recall_t <= 0.0:
		sprite.modulate = Color.WHITE
		recall_cd = RECALL_CD
		if recall_dest != null:
			var rec = recall_dest
			recall_dest = null
			if gold < teleport_cost(rec) or not Game.dungeons.has(rec):
				Game.notify("Teleport failed")
				return
			gold -= teleport_cost(rec)
			global_position = Vector2(rec["pos"][0], rec["pos"][1]) + Vector2(0, 22)
			Game.main.cam.reset_smoothing()
			invuln = 1.0
			Audio.sfx("teleport", 1.0)
			Game.notify("Teleported to the dungeon (-%dg)" % teleport_cost(rec))
			return
		if Game.cur_dungeon != null:
			Game.main.leave_dungeon(false)
		global_position = Game.world.spawn_pos
		Game.main.cam.reset_smoothing()
		invuln = 1.0
		Audio.sfx("teleport", 1.0)
		Game.notify("You return to town.")


var dust
var dust_t = 0.0


func _make_dust():
	dust = CPUParticles2D.new()
	dust.local_coords = false
	dust.amount = 10
	dust.lifetime = 0.45
	dust.emitting = false
	dust.direction = Vector2(0, -1)
	dust.spread = 120.0
	dust.initial_velocity_min = 6.0
	dust.initial_velocity_max = 16.0
	dust.gravity = Vector2.ZERO
	dust.scale_amount_min = 1.4
	dust.scale_amount_max = 2.6
	dust.z_index = -1
	var sc = Curve.new()
	sc.add_point(Vector2(0, 1))
	sc.add_point(Vector2(1, 0))
	dust.scale_amount_curve = sc
	dust.position = Vector2(0, -1)
	add_child(dust)


func _update_dust(delta):
	if dust == null:
		_make_dust()
	dust_t -= delta
	if dust_t <= 0.0:
		dust_t = 0.3
		var t = Game.world.tile_at(global_position) if Game.dlayout == null else 5
		var c = Color(0.62, 0.55, 0.45, 0.7)
		match t:
			2: c = Color(0.92, 0.82, 0.58, 0.8)
			3, 4: c = Color(0.55, 0.78, 0.4, 0.7)
			6: c = Color(0.65, 0.65, 0.72, 0.7)
			7: c = Color(0.7, 0.5, 0.9, 0.7)
			8, 9: c = Color(0.35, 0.3, 0.3, 0.8)
		dust.color = c
	dust.emitting = velocity.length() > 70.0 and not dead


func _physics_process(delta):
	if dead:
		return
	_update_dust(delta)
	atk_cd = maxf(0.0, atk_cd - delta)
	combat_t = maxf(0.0, combat_t - delta)
	anim_lock = maxf(0.0, anim_lock - delta)
	invuln = maxf(0.0, invuln - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	for k in cd.keys():
		cd[k] = maxf(0.0, cd[k] - delta)
	_tick_effects(delta)
	_recall_tick(delta, recall_t > 0.0 and (Input.get_vector("move_left", "move_right", "move_up", "move_down").length() > 0.1 or atk_cd > 0.0))

	var stunned = _is_stunned()
	var blocked = Game.hud != null and Game.hud.ui_open()
	var to_mouse = get_global_mouse_position() - origin()
	if to_mouse.length() > 2.0:
		aim = to_mouse.normalized()

	var dir = Vector2.ZERO
	if not blocked and not stunned:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	move_dir = dir
	var running = Game.run_on and dir != Vector2.ZERO
	var spd = 60.0 * stats["move_speed"] * (1.6 if running else 1.0)
	if anim_lock > 0.0:
		spd *= 0.6
	if hunger <= 0.0:
		spd *= 0.8
	velocity = dir * spd + knock
	knock = knock.move_toward(Vector2.ZERO, 500.0 * delta)
	var stp = velocity * delta
	if not Game.world.is_walkable(global_position + Vector2(stp.x + signf(stp.x) * 3.0, 0)):
		velocity.x = 0
	if not Game.world.is_walkable(global_position + Vector2(0, stp.y + signf(stp.y) * 3.0)):
		velocity.y = 0
	move_and_slide()

	if combat_t > 0.0:
		_update_face(aim)
	elif dir != Vector2.ZERO:
		_update_face(dir)
	var anim = "idle"
	if anim_lock > 0.0:
		anim = lock_anim
	elif dir != Vector2.ZERO:
		anim = "run" if running else "walk"
	var full = anim + "_" + face_name
	if sprite.animation != full:
		sprite.play(full)
	sprite.flip_h = face_flip

	pivot.visible = equip["weapon"] != null
	if not swinging:
		pivot.rotation = lerp_angle(pivot.rotation, aim.angle() + PI / 2.0, 0.35)
		pivot.position = Vector2(0, -9) + aim * 3.0
	pivot.z_index = -1 if face_name == "up" else 0

	if not blocked and not stunned:
		if Input.is_action_just_pressed("dash"):
			try_dash()
		if Input.is_action_pressed("attack") and atk_cd <= 0.0 and anim_lock <= 0.0:
			basic_attack()
		for i in range(4):
			if Input.is_action_just_pressed("skill_%d" % i):
				var sid = Skills.slot_skill(self, i)
				if sid != "":
					Skills.cast(self, sid)
				else:
					Game.notify("No skill equipped in that slot (K)")
		for i in range(1, 5):
			if Input.is_action_just_pressed("quick_%d" % i):
				quick_use(i)


func _is_stunned():
	for s in statuses:
		if s[0] == "stun":
			return true
	return false


func _tick_effects(delta):
	# regen
	var in_combat = combat_t > 0.0
	hp = minf(max_hp, hp + stats["hp_regen"] * (0.35 if in_combat else 1.0) * delta)
	mp = minf(max_mp, mp + stats["mp_regen"] * (1.0 if in_combat else 1.6) * delta)
	for h in hots:
		h[0] -= delta
		hp = minf(max_hp, hp + h[1] * delta)
	hots = hots.filter(func(h): return h[0] > 0.0)
	# hunger
	hunger = maxf(0.0, hunger - 0.11 * delta)
	if hunger <= 0.0:
		hp = maxf(1.0, hp - max_hp * 0.008 * delta)
	# buffs / statuses
	var changed = false
	for id in buffs.keys():
		buffs[id]["t"] -= delta
		if buffs[id]["t"] <= 0.0:
			buffs.erase(id)
			changed = true
	dot_t += delta
	var tick = dot_t >= 0.5
	for s in statuses:
		s[1] -= delta
		if tick and (s[0] == "burn" or s[0] == "poison"):
			_raw_damage(s[2] * 0.5, Color(1, 0.55, 0.2) if s[0] == "burn" else Color(0.6, 1, 0.4))
	if tick:
		dot_t = 0.0
	var before = statuses.size()
	statuses = statuses.filter(func(s): return s[1] > 0.0)
	if statuses.size() != before:
		changed = true
	recalc_t += delta
	if changed or recalc_t > 0.5:
		recalc_t = 0.0
		recalc()
	if hp <= 0.0 and not dead:
		_die()


func _raw_damage(amount, col):
	if dead:
		return
	hp -= amount
	Game.float_text(str(maxi(1, int(amount))), global_position, col)
	if hp <= 0.0:
		_die()


func _update_face(v):
	if absf(v.x) >= absf(v.y):
		face_name = "side"
		face_flip = v.x < 0.0
	else:
		face_name = "down" if v.y > 0.0 else "up"
		face_flip = false


func start_anim(anim_name, dur):
	anim_lock = dur
	lock_anim = anim_name
	combat_t = 4.0 if combat_t < 4.0 and false else maxf(combat_t, 0.8)
	_update_face(aim)
	sprite.flip_h = face_flip
	sprite.play(anim_name + "_" + face_name)


func shake(a):
	if Game.main != null and Game.main.has_method("shake"):
		Game.main.shake(a)


func target_pos(max_r):
	var d = get_global_mouse_position() - global_position
	if d.length() > max_r:
		d = d.normalized() * max_r
	return global_position + d


func dash_target(dist, dir = null):
	var d = aim if dir == null else dir
	if d == Vector2.ZERO:
		d = aim
	d = d.normalized()
	var last = global_position
	var steps = int(dist / 4.0)
	for i in range(1, steps + 1):
		var pt = global_position + d * (4.0 * i)
		if not Game.world.is_walkable(pt):
			break
		last = pt
	return last


# ------------------------------------------------------------------ inventory
func bag_upgrade_cost():
	if bag_size >= Game.BAG_MAX:
		return -1
	var n = (bag_size - Game.BAG_CAP) / Game.BAG_STEP
	return 250 * (n + 1) * (n + 1)


func upgrade_bag():
	var c = bag_upgrade_cost()
	if c < 0:
		Game.notify("Your bag is already at maximum size")
		return false
	if gold < c:
		Game.notify("Need %d gold to expand the bag" % c)
		return false
	gold -= c
	bag_size += Game.BAG_STEP
	inv.resize(bag_size)
	Game.notify("Bag expanded to %d slots!" % bag_size)
	inventory_changed.emit()
	return true


func free_slots():
	var n = 0
	for it in inv:
		if it == null:
			n += 1
	return n


func count(id):
	var n = 0
	for it in inv:
		if it != null and not it.has("sub") and it["id"] == id:
			n += it["n"]
	return n


func can_hold(it):
	if free_slots() > 0:
		return true
	if not it.has("sub"):
		var room = 0
		for s in inv:
			if s != null and not s.has("sub") and s["id"] == it["id"]:
				room += Game.STACK - s["n"]
		return room >= it["n"]
	return false


func add_item(it, silent = false):
	var left = it["n"]
	if not it.has("sub"):
		for s in inv:
			if left <= 0:
				break
			if s != null and not s.has("sub") and s["id"] == it["id"] and s["n"] < Game.STACK:
				var t = mini(left, Game.STACK - s["n"])
				s["n"] += t
				left -= t
		while left > 0:
			var idx = inv.find(null)
			if idx < 0:
				break
			var t = mini(left, Game.STACK)
			inv[idx] = {"id": it["id"], "n": t}
			left -= t
	else:
		var idx = inv.find(null)
		if idx >= 0:
			inv[idx] = it
			left = 0
	if not silent and left < it["n"]:
		var col = Items.color_of(it)
		Game.float_text("+%d %s" % [it["n"] - left, Items.name_of(it)], global_position, col)
	inventory_changed.emit()
	return left <= 0


func remove_item(id, n):
	var left = n
	for i in range(inv.size()):
		var s = inv[i]
		if left <= 0:
			break
		if s != null and not s.has("sub") and s["id"] == id:
			var t = mini(left, s["n"])
			s["n"] -= t
			left -= t
			if s["n"] <= 0:
				inv[i] = null
	inventory_changed.emit()


func sort_inv():
	var items = []
	for s in inv:
		if s != null:
			items.append(s)
	merge_stacks(items)
	items.sort_custom(func(a, b):
		var ka = Items.sort_key(a)
		var kb = Items.sort_key(b)
		if ka != kb:
			return ka < kb
		if Items.is_gear(a) and Items.is_gear(b):
			if a["rar"] != b["rar"]:
				return a["rar"] > b["rar"]
			return Items.score(a) > Items.score(b)
		return Items.name_of(a) < Items.name_of(b))
	inv.fill(null)
	for i in range(items.size()):
		inv[i] = items[i]
	inventory_changed.emit()


func merge_stacks(items = null):
	var own = items == null
	if own:
		items = []
		for s in inv:
			if s != null:
				items.append(s)
	var by_id = {}
	var out = []
	for s in items:
		if Items.is_gear(s):
			out.append(s)
			continue
		by_id[s["id"]] = by_id.get(s["id"], 0) + s["n"]
	for id in by_id:
		var left = by_id[id]
		while left > 0:
			var t = mini(left, Game.STACK)
			out.append({"id": id, "n": t})
			left -= t
	items.clear()
	items.append_array(out)
	if own:
		inv.fill(null)
		for i in range(items.size()):
			inv[i] = items[i]
		inventory_changed.emit()


func split_stack(i, n):
	var s = inv[i]
	if s == null or Items.is_gear(s) or n <= 0 or n >= s["n"]:
		return false
	var idx = inv.find(null)
	if idx < 0:
		Game.notify("No free slot")
		return false
	s["n"] -= n
	inv[idx] = {"id": s["id"], "n": n}
	inventory_changed.emit()
	return true


func discard(i, n):
	var s = inv[i]
	if s == null:
		return
	n = mini(n, s["n"])
	var out = s.duplicate(true)
	out["n"] = n
	s["n"] -= n
	if s["n"] <= 0:
		inv[i] = null
	Game.drop_item(out, global_position + aim * 16.0).delay = 2.5
	inventory_changed.emit()


func equip_from(i):
	Audio.sfx("equip", 0.8)
	var it = inv[i]
	if it == null or not Items.is_gear(it):
		return false
	if not Items.can_equip(it, char_id):
		Game.notify("%s cannot equip that" % cdata["name"])
		return false
	var slot = equip_slot_for(it)
	var old = equip[slot]
	equip[slot] = it
	inv[i] = old
	recalc()
	refresh_weapon()
	inventory_changed.emit()
	return true


func equip_slot_for(it):
	var base = Items.slot_of(it)
	if base == "ring" or base == "bracelet":
		if equip[base + "1"] == null:
			return base + "1"
		if equip[base + "2"] == null:
			return base + "2"
		return base + "1"
	return base


func unequip(slot):
	var it = equip[slot]
	if it == null:
		return false
	var idx = inv.find(null)
	if idx < 0:
		Game.notify("Bag is full")
		return false
	inv[idx] = it
	equip[slot] = null
	recalc()
	refresh_weapon()
	inventory_changed.emit()
	return true


func use_slot(i):
	var it = inv[i]
	if it == null:
		return
	if Items.is_gear(it):
		equip_from(i)
		return
	if _use_item(it):
		it["n"] -= 1
		if it["n"] <= 0:
			inv[i] = null
		inventory_changed.emit()


func _use_item(it):
	var d = Game.ITEMS[it["id"]]
	var cat = d["cat"]
	if cat == "cons":
		if d["use"] == "hp":
			if hp >= max_hp:
				Game.notify("HP is full")
				return false
			heal(max_hp * d["pct"] * (1.0 + stats["heal_pct"]))
		else:
			if mp >= max_mp:
				Game.notify("MP is full")
				return false
			mp = minf(max_mp, mp + max_mp * d["pct"])
			Game.float_text("+%d MP" % int(max_mp * d["pct"]), global_position, Color(0.4, 0.7, 1.0))
		return true
	if cat == "food":
		if hunger >= 99.0 and hp >= max_hp:
			Game.notify("Not hungry")
			return false
		hunger = minf(100.0, hunger + d["hunger"])
		hp = minf(max_hp, hp + max_hp * d["heal"])
		if d.has("buff"):
			var b = Game.FOOD_BUFFS[d["buff"]]
			add_buff(d["buff"], b["t"], b["mods"])
		Game.float_text("Yum", global_position, Color(1, 0.9, 0.5))
		return true
	if cat == "book":
		var sk = d["skill"]
		if tomes.has(sk):
			Game.notify("You already know %s" % Game.SKILLS[sk]["name"])
			return false
		tomes[sk] = true
		Game.notify("Learned %s! Spend skill points in the Tomes tab (K)." % Game.SKILLS[sk]["name"])
		Game.spawn_fx("light", global_position + Vector2(0, -6))
		return true
	if cat == "place":
		var pos = get_global_mouse_position()
		if pos.distance_to(global_position) > 72.0 or not Game.world.is_walkable(pos):
			Game.notify("Can't place that there")
			return false
		Game.world.add_campfire(pos)
		return true
	Game.notify("Can't use that")
	return false


func quick_use(n):
	var list = []
	if n == 1:
		list = ["potion_hp_1", "potion_hp_2", "potion_hp_3"]
	elif n == 2:
		list = ["potion_mp_1", "potion_mp_2", "potion_mp_3"]
	elif n == 3:
		list = ["meat", "cooked_meat", "mushroom_soup", "stew"]
		list.reverse()
		list = ["cooked_meat", "stew", "mushroom_soup", "meat"]
	else:
		list = ["campfire"]
	for id in list:
		for i in range(inv.size()):
			var s = inv[i]
			if s != null and not Items.is_gear(s) and s["id"] == id:
				use_slot(i)
				return
	Game.notify("Nothing to use")


func quick_count(n):
	var list = [["potion_hp_1", "potion_hp_2", "potion_hp_3"], ["potion_mp_1", "potion_mp_2", "potion_mp_3"], ["cooked_meat", "stew", "mushroom_soup", "meat"], ["campfire"]][n - 1]
	var c = 0
	for id in list:
		c += count(id)
	return c


func can_afford(needs):
	for k in needs:
		if count(k) < needs[k]:
			return false
	return true


func craft(r):
	if not can_afford(r["needs"]):
		Game.notify("Missing materials")
		return
	if r.get("fire", false) and not Game.near_fire(global_position):
		Game.notify("Stand near a campfire!")
		return
	var out
	if r.has("gear"):
		out = Items.roll_gear(r["gear"], maxi(1, level), Items.roll_rarity(stats["luck"] * 0.5, 0.0), "", stats["luck"])
	else:
		out = Items.make(r["out"], r["n"])
	# consume first (frees slots), then add; roll back if no room
	for k in r["needs"]:
		remove_item(k, r["needs"][k])
	if not can_hold(out):
		for k in r["needs"]:
			add_item(Items.make(k, r["needs"][k]), true)
		Game.notify("Bag is full!")
		return
	add_item(out, true)
	Game.notify("Crafted %s" % Items.name_of(out))
	if Items.is_gear(out):
		Game.float_text(Game.RARITY_NAMES[out["rar"]], global_position, Items.color_of(out), 9)


# ------------------------------------------------------------------ basic attacks
func basic_attack():
	var w = weapon_def()
	var kind = w["kind"]
	var style = w["style"]
	atk_cd = w["cd"] / stats["atk_speed"]
	var base = stats["phy_atk"] if kind == "phy" else stats["mag_atk"]
	var elem = ""
	if equip["weapon"] != null:
		elem = equip["weapon"]["elem"]
	if style == "swing" or style == "thrust":
		_melee(w, base, elem)
	elif style == "arrow" or style == "bullet":
		_ranged(w, base, elem)
	else:
		_magic(w, base, elem)


func _melee(w, base, elem):
	Audio.sfx("swing", 0.8, 1.0, 0.08)
	var d = aim
	start_anim("attack", 0.28)
	swinging = true
	var ang = d.angle() + PI / 2.0
	var tw = create_tween()
	if w["style"] == "thrust":
		pivot.rotation = ang
		tw.tween_property(pivot, "position", Vector2(0, -9) + d * 14.0, 0.09)
		tw.tween_property(pivot, "position", Vector2(0, -9), 0.14)
	else:
		pivot.rotation = ang - 1.2
		tw.tween_property(pivot, "rotation", ang + 1.2, 0.2).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): swinging = false)
	await get_tree().create_timer(0.09 / stats["atk_speed"]).timeout
	if dead:
		return
	var origin_p = origin()
	var reach = w["reach"]
	var arc = w["arc"]
	var magic = w["kind"] == "mag"
	for e in Game.enemies_in_arc(origin_p, d, reach, arc, false):
		Game.hit(e, Game.roll_damage(self, base), origin_p, 110.0, elem, magic)
	# gathering by attacking
	var gp = 1.0 + stats["str"] * 0.07 + (equip["weapon"]["base"].get("phy_atk", 0.0) * 0.04 if equip["weapon"] != null else 0.0)
	var best = null
	var bd = 1.0e9
	for r in get_tree().get_nodes_in_group("resources"):
		if not r.alive:
			continue
		var to = r.global_position + Vector2(0, -6) - origin_p
		var dist = to.length()
		if dist <= reach + r.radius + 6.0 and absf(angle_difference(d.angle(), to.angle())) <= arc + 0.4:
			if w.get("smash", false):
				r.take_hit(gp * 1.5, self)
			elif dist < bd:
				bd = dist
				best = r
	if best != null:
		best.take_hit(gp, self)
	if w.get("smash", false):
		Game.spawn_fx("earth", global_position + d * 28.0, {"scl": 0.7})
		shake(1.5)


func _ranged(w, base, elem):
	var d = aim
	start_anim("attack", 0.28)
	swinging = true
	pivot.rotation = d.angle() + PI / 2.0
	var tw = create_tween()
	tw.tween_property(pivot, "position", Vector2(0, -9) - d * 3.0, 0.1)
	tw.tween_property(pivot, "position", Vector2(0, -9), 0.1)
	tw.tween_callback(func(): swinging = false)
	await get_tree().create_timer(0.12 / stats["atk_speed"]).timeout
	if dead:
		return
	var bullet = w["style"] == "bullet"
	_muzzle(d, bullet)
	Game.shoot({"position": origin() + d * 10.0, "dir": d, "speed": 380.0 if bullet else 320.0, "base": base * (1.0 if not bullet else 1.1),
		"magic": false, "element": elem, "life": 1.1, "kb": 70.0, "arrow": not bullet, "kind": "bullet" if bullet else "arrow"})


func _muzzle(d, bullet):
	Audio.sfx("gun" if bullet else "bow", 0.8)
	var g = Sprite2D.new()
	g.texture = Game.light_tex()
	g.global_position = origin() + d * (13.0 if bullet else 8.0)
	g.scale = Vector2(0.5, 0.5) if bullet else Vector2(0.28, 0.28)
	g.modulate = Color(1, 0.9, 0.5, 0.9) if bullet else Color(1, 1, 1, 0.5)
	var m = CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = m
	g.z_index = 7
	Game.entities.add_child(g)
	var tw = g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.1)
	tw.tween_callback(g.queue_free)
	if bullet:
		Game.main.shake(1.0)


func _magic(w, base, elem):
	if mp < w["mana"]:
		Game.notify("Not enough mana")
		atk_cd = 0.3
		return
	mp -= w["mana"]
	var d = aim
	start_anim("cast", 0.28)
	swinging = true
	pivot.rotation = d.angle() + PI / 2.0
	var tw = create_tween()
	tw.tween_property(pivot, "scale", Vector2(1.3, 1.3), 0.1)
	tw.tween_property(pivot, "scale", Vector2(1, 1), 0.1)
	tw.tween_callback(func(): swinging = false)
	await get_tree().create_timer(0.12 / stats["atk_speed"]).timeout
	if dead:
		return
	var pk = w["proj"]
	if elem != "" and ["fire", "water", "wind", "light", "dark"].has(elem):
		pk = elem
	Game.shoot({"position": origin() + d * 14.0, "dir": d, "speed": 240.0, "kind": pk, "base": base, "magic": true, "element": elem,
		"life": 1.3, "kb": 60.0, "hit_fx": "wind" if pk == "arcane" else pk})


# ------------------------------------------------------------------ damage taken
func take_damage(amount, from_pos, kb = 100.0, element = "", opts = {}):
	if dead or invuln > 0.0:
		return
	if recall_t > 0.0:
		recall_t = 0.0
		sprite.modulate = Color.WHITE
		Game.notify("Recall interrupted")
	Audio.sfx("hurt", 0.9, 1.0, 0.1)
	var magic = opts.get("magic", false)
	var lvl = opts.get("lvl", level)
	var df = stats["mag_def"] if magic else stats["phy_def"]
	var dmg = amount * Game.def_factor(df, lvl)
	if element != "" and res.has(element):
		dmg *= 1.0 - res[element] / 100.0
	dmg = maxf(1.0, dmg)
	hp -= dmg
	invuln = 0.5
	combat_t = 4.0
	knock = (global_position - from_pos).normalized() * kb * 0.8
	Game.float_text(str(int(round(dmg))), global_position, Color(1, 0.3, 0.3))
	sprite.modulate = Color(1, 0.4, 0.4)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.3)
	shake(1.0)
	for st in opts.get("status", []):
		if randf() < 0.75:
			add_status(st[0], st[1], st[2], dmg)
	if hp <= 0.0:
		_die()


func _die():
	if dead:
		return
	Audio.sfx("death", 1.0)
	dead = true
	hp = 0.0
	sprite.rotation = deg_to_rad(90)
	pivot.visible = false
	statuses.clear()
	buffs.clear()
	hots.clear()
	Game.hud.show_death(true)
	await get_tree().create_timer(2.5).timeout
	var lost = int(gold * 0.05)
	gold -= lost
	if Game.cur_dungeon != null:
		Game.main.leave_dungeon(false)
	dead = false
	recalc()
	hp = max_hp
	mp = max_mp
	hunger = maxf(hunger, 40.0)
	invuln = 2.0
	sprite.rotation = 0.0
	position = Game.world.spawn_pos
	knock = Vector2.ZERO
	Game.hud.show_death(false)
	if lost > 0:
		Game.notify("You dropped %dg" % lost)


# ------------------------------------------------------------------ quests
func quest_event(kind, target):
	for q in quests:
		if q["kind"] == kind and (q["target"] == target or q["target"] == ""):
			if q["have"] < q["need"]:
				q["have"] += 1
				if q["have"] >= q["need"]:
					Game.notify("Quest ready: %s (return to the Guild)" % q["name"])


func quest_progress(q):
	if q["kind"] == "collect":
		return mini(count(q["target"]), q["need"])
	return q["have"]


func quest_ready(q):
	return quest_progress(q) >= q["need"]


func quest_turn_in(q):
	if not quest_ready(q):
		return false
	var reward_item = null
	if q["gear"]:
		reward_item = Items.roll_random_gear(q["level"], maxi(1, Items.roll_rarity(stats["luck"] * 0.5, 0.8)), stats["luck"], 0.3)
		if not can_hold(reward_item):
			Game.notify("Bag is full!")
			return false
	if q["kind"] == "collect":
		remove_item(q["target"], q["need"])
	quests.erase(q)
	add_gold(q["gold"])
	add_xp(q["xp"])
	if reward_item != null:
		add_item(reward_item)
	Game.notify("Quest complete! +%dg +%d XP" % [q["gold"], q["xp"]])
	return true


# ------------------------------------------------------------------ enchanting
func enchant_cost(it):
	var e = int(it.get("ench", 0))
	return {"gold": int(Items.value(it) * 0.3 + 40 * (e + 1)), "ingots": 1 + e}


func enchant_chance(it):
	var e = int(it.get("ench", 0))
	return [1.0, 1.0, 1.0, 0.8, 0.65, 0.5, 0.4, 0.3, 0.2, 0.15][mini(e, 9)]


func enchant(it):
	if int(it.get("ench", 0)) >= 10:
		Game.notify("Already +10")
		return
	var c = enchant_cost(it)
	if gold < c["gold"] or count("iron_ingot") < c["ingots"]:
		Game.notify("Need %dg and %d Iron Ingots" % [c["gold"], c["ingots"]])
		return
	gold -= c["gold"]
	remove_item("iron_ingot", c["ingots"])
	if randf() < enchant_chance(it):
		it["ench"] = int(it.get("ench", 0)) + 1
		Game.notify("Enchant success! %s" % Items.name_of(it))
		Game.spawn_fx("light", global_position + Vector2(0, -6))
	else:
		Game.notify("Enchant failed...")
	recalc()
	inventory_changed.emit()


func reroll_cost(it):
	return {"gold": int(Items.value(it) * 0.5 + 60), "ingots": 2}


func reroll(it):
	if it["u"] != "" or it["aff"].size() == 0:
		Game.notify("This item cannot be re-rolled")
		return
	var c = reroll_cost(it)
	if gold < c["gold"] or count("iron_ingot") < c["ingots"]:
		Game.notify("Need %dg and %d Iron Ingots" % [c["gold"], c["ingots"]])
		return
	gold -= c["gold"]
	remove_item("iron_ingot", c["ingots"])
	var fresh = Items.roll_gear(it["sub"], it["ilvl"], it["rar"])
	it["aff"] = fresh["aff"]
	Game.notify("Affixes re-rolled")
	recalc()
	inventory_changed.emit()


# ------------------------------------------------------------------ save / load
func make_save():
	var eq = {}
	for s in equip:
		eq[s] = equip[s]
	return {"pos": [global_position.x, global_position.y], "hp": hp, "mp": mp, "level": level, "xp": xp, "gold": gold,
		"loadout": loadout, "tomes": tomes, "quests": quests, "board": board, "alloc": stat_alloc, "stat_pts": stat_pts, "skill_pts": skill_pts, "ranks": ranks, "hunger": hunger,
		"inv": inv, "bag": bag_size, "equip": eq}


func _fix_item(it):
	if it == null:
		return null
	it["n"] = int(it.get("n", 1))
	if it.has("sub"):
		it["rar"] = int(it["rar"])
		it["ilvl"] = int(it["ilvl"])
		it["ench"] = int(it.get("ench", 0))
	elif not Game.ITEMS.has(it.get("id", "")):
		return null
	return it


func apply_save(d):
	level = int(d["level"])
	xp = int(d["xp"])
	gold = int(d["gold"])
	stat_pts = int(d["stat_pts"])
	skill_pts = int(d["skill_pts"])
	hunger = float(d.get("hunger", 100.0))
	for k in d["alloc"]:
		stat_alloc[k] = int(d["alloc"][k])
	ranks = {}
	for k in d["ranks"]:
		if Game.SKILLS.has(k):
			ranks[k] = int(d["ranks"][k])
	loadout = ["", "", "", ""]
	var lo = d.get("loadout", [])
	for i in range(mini(4, lo.size())):
		loadout[i] = str(lo[i]) if Game.SKILLS.has(str(lo[i])) else ""
	tomes = {}
	for k in d.get("tomes", {}):
		if Game.SKILLS.has(k):
			tomes[k] = true
	quests = []
	for q in d.get("quests", []):
		q["have"] = int(q["have"])
		q["need"] = int(q["need"])
		q["gold"] = int(q["gold"])
		q["xp"] = int(q["xp"])
		q["level"] = int(q["level"])
		quests.append(q)
	board = []
	for q in d.get("board", []):
		q["have"] = int(q["have"])
		q["need"] = int(q["need"])
		q["gold"] = int(q["gold"])
		q["xp"] = int(q["xp"])
		q["level"] = int(q["level"])
		board.append(q)
	bag_size = clampi(int(d.get("bag", Game.BAG_CAP)), Game.BAG_CAP, Game.BAG_MAX)
	inv.resize(bag_size)
	inv.fill(null)
	for i in range(mini(d["inv"].size(), bag_size)):
		inv[i] = _fix_item(d["inv"][i])
	for s in equip:
		equip[s] = _fix_item(d["equip"].get(s))
	recalc()
	hp = minf(float(d["hp"]), max_hp)
	mp = minf(float(d["mp"]), max_mp)
	position = Vector2(d["pos"][0], d["pos"][1])
	refresh_weapon()
	inventory_changed.emit()
