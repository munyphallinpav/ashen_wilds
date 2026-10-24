extends CharacterBody2D
## Dungeon main boss. Data in Game.BOSSES, scaled by `level` (+ dungeon `diff`). Every attack is telegraphed.
##   Inferno: Breath (fire fan), Meteors, Tailspin   Treant: Roots, Thorns, Regrow    Fungal: Spores, Summon, Roots
##   Goblin King: Charge, Summon, Slam   Siren: Waterfan, Tidal ring, Summon   Golem: Boulders, Shockwave, Leap
## Below 50% HP the boss enrages: faster attacks, extra repeats and more projectiles / zones.

var boss_id = "goblin_king"
var level = 10
var diff = 0.0
var start_hp = -1.0
var d = {}
var hp = 100.0
var max_hp = 100.0
var dmg = 10.0
var defense = 10.0
var statuses = []
var dot_acc = 0.0
var mini = false
var hit_radius = 26.0
var boss_name = ""
var home = Vector2.ZERO
var engaged = false
var busy = false
var dead = false
var enraged = false
var atk_timer = 2.0
var contact_cd = 0.0
var stagger_t = 0.0
var channel_dmg = 0.0
var last_atk = ""
var dash_vel = Vector2.ZERO
var dash_t = 0.0
var dash_hit = false
var minions = []
var telegraphs = []
var rings = []
var had_tele = false
var knock = Vector2.ZERO
var sprite
var tele


func _ready():
	d = Game.BOSSES[boss_id]
	boss_name = d["name"]
	max_hp = d["hp"] * Game.mob_hp_scale(level) * 2.2 * (1.0 + diff * 0.3)
	hp = max_hp if start_hp < 0.0 else start_hp
	dmg = d["dmg"] * Game.mob_dmg_scale(level) * (1.0 + diff * 0.15)
	defense = Game.mob_def(level) * d["def"]
	hit_radius = d["radius"]
	add_to_group("hurtable")
	add_to_group("bosses")
	collision_layer = 2
	collision_mask = 1
	var cs = CollisionShape2D.new()
	var c = CircleShape2D.new()
	c.radius = 10.0
	cs.shape = c
	cs.position = Vector2(0, -6)
	add_child(cs)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Game.strip_frames(d["sheet"], 64, 64, 4, 5.0, true)
	sprite.position = Vector2(0, -26)
	add_child(sprite)
	sprite.play("default")
	tele = Node2D.new()
	tele.top_level = true
	tele.z_index = -5
	tele.draw.connect(_draw_tele)
	add_child(tele)
	home = position
	atk_timer = 1.5
	if hp < max_hp * 0.5:
		_set_enraged(false)


# ------------------------------------------------------------ main loop
func _physics_process(delta):
	if dead:
		return
	var p = Game.player
	if p == null:
		return
	var dist = global_position.distance_to(p.global_position)
	_update_telegraph(delta)
	_update_rings(delta)
	_tick_status(delta)
	stagger_t = maxf(0.0, stagger_t - delta)
	contact_cd = maxf(0.0, contact_cd - delta)

	if engaged and (dist > d["leash"] or p.dead):
		engaged = false
		busy = false
		dash_t = 0.0
		telegraphs.clear()
		sprite.modulate = Color.WHITE
	if not engaged:
		if dist < d["aggro"] and not p.dead and hp > 0.0:
			engaged = true
			atk_timer = 1.2
			Game.notify("%s awakens!" % boss_name)
		else:
			# leashed: walk home and recover
			hp = minf(max_hp, hp + max_hp * 0.04 * delta)
			var to_home = home - global_position
			velocity = to_home.normalized() * d["speed"] if to_home.length() > 6.0 else Vector2.ZERO
			move_and_slide()
			sprite.speed_scale = 1.0 if velocity != Vector2.ZERO else 0.0
			return

	var vel = Vector2.ZERO
	if dash_t > 0.0:
		dash_t -= delta
		vel = dash_vel
		if not dash_hit and dist < 24.0:
			dash_hit = true
			_hurt(1.5, 180.0)
	elif busy or stagger_t > 0.0:
		vel = Vector2.ZERO
	else:
		var to_p = p.global_position - global_position
		if dist > d["keep"]:
			vel = to_p.normalized() * d["speed"] * (1.0 - _pow("slow") * 0.5)
		elif dist < d["keep"] * 0.6:
			vel = -to_p.normalized() * d["speed"] * 0.5
		atk_timer -= delta
		if atk_timer <= 0.0:
			_start_attack()
		if dist < 30.0 and contact_cd <= 0.0:
			contact_cd = 1.0
			_hurt(0.6, 100.0)

	velocity = vel
	var stp = vel * delta
	if not Game.world.is_walkable(global_position + Vector2(stp.x + signf(stp.x) * 6.0, 0)):
		velocity.x = 0
	if not Game.world.is_walkable(global_position + Vector2(0, stp.y + signf(stp.y) * 6.0)):
		velocity.y = 0
	move_and_slide()
	if absf(vel.x) > 1.0:
		sprite.flip_h = vel.x < 0.0
	else:
		sprite.flip_h = p.global_position.x < global_position.x
	sprite.speed_scale = 1.0 if vel != Vector2.ZERO else 0.0

	var has = telegraphs.size() > 0 or rings.size() > 0
	if has or had_tele:
		tele.queue_redraw()
	had_tele = has


func _start_attack():
	busy = true
	var choices = d["attacks"]
	var pick = choices.pick_random()
	if pick == last_atk and choices.size() > 1:
		pick = choices.pick_random()
	if pick == "regrow" and hp > max_hp * 0.85:
		pick = "roots"
	last_atk = pick
	match pick:
		"charge":
			await _atk_charge()
		"summon":
			await _atk_summon()
		"slam":
			await _atk_slam()
		"roots":
			await _atk_roots()
		"thorns":
			await _atk_thorns()
		"regrow":
			await _atk_regrow()
		"boulders":
			await _atk_boulders()
		"shockwave":
			await _atk_shockwave()
		"leap":
			await _atk_leap()
		"breath":
			await _atk_breath()
		"meteors":
			await _atk_meteors()
		"tailspin":
			await _atk_tailspin()
		"spores":
			await _atk_spores()
		"waterfan":
			await _atk_waterfan()
		"tidal":
			await _atk_tidal()
	if dead:
		return
	sprite.modulate = Color.WHITE
	busy = false
	atk_timer = randf_range(d["cd"][0], d["cd"][1]) * (0.65 if enraged else 1.0)


func _wait(sec):
	await get_tree().create_timer(sec).timeout


# ------------------------------------------------------------ telegraph helpers
func _tele_circle(pos, r, dur, col = Color(1, 0.25, 0.1)):
	telegraphs.append({"k": "c", "pos": pos, "r": r, "t": dur, "dur": dur, "col": col})


func _tele_line(from, to, w, dur, col = Color(1, 0.25, 0.1)):
	telegraphs.append({"k": "l", "from": from, "to": to, "w": w, "t": dur, "dur": dur, "col": col})


func _update_telegraph(delta):
	if telegraphs.size() == 0:
		return
	for tl in telegraphs:
		tl["t"] -= delta
	telegraphs = telegraphs.filter(func(x): return x["t"] > 0.0)


func _update_rings(delta):
	if rings.size() == 0:
		return
	var p = Game.player
	for rg in rings:
		rg["r"] += rg["speed"] * delta
		if not rg["hit"] and p != null and not p.dead:
			var pd = p.global_position.distance_to(rg["pos"])
			if absf(pd - rg["r"]) < 9.0:
				rg["hit"] = true
				_hurt(rg["dmg"], 160.0, rg["pos"])
	rings = rings.filter(func(x): return x["r"] < x["max"])


func _draw_tele():
	for tl in telegraphs:
		var f = 1.0 - tl["t"] / tl["dur"]
		var c = tl["col"]
		if tl["k"] == "c":
			tele.draw_circle(tl["pos"], tl["r"], Color(c.r, c.g, c.b, 0.12 + 0.2 * f))
			tele.draw_circle(tl["pos"], tl["r"] * f, Color(c.r, c.g, c.b, 0.3))
			tele.draw_arc(tl["pos"], tl["r"], 0.0, TAU, 40, Color(c.r, c.g, c.b, 0.9), 1.5)
		else:
			var dv = tl["to"] - tl["from"]
			var n = dv.normalized().orthogonal() * tl["w"] * 0.5
			var col = Color(c.r, c.g, c.b, 0.12 + 0.3 * f)
			tele.draw_colored_polygon(PackedVector2Array([tl["from"] + n, tl["to"] + n, tl["to"] - n, tl["from"] - n]), col)
	for rg in rings:
		tele.draw_arc(rg["pos"], rg["r"], 0.0, TAU, 56, Color(0.95, 0.85, 0.6, 0.9), 3.0)
		tele.draw_arc(rg["pos"], maxf(1.0, rg["r"] - 4.0), 0.0, TAU, 56, Color(0.7, 0.6, 0.45, 0.5), 2.0)


func _flash_warning():
	sprite.modulate = Color(1, 0.6, 0.6)


# ------------------------------------------------------------ GOBLIN KING
func _atk_charge():
	var times = 3 if enraged else 1
	for i in range(times):
		var p = Game.player
		var dir = (p.global_position - global_position).normalized()
		_tele_line(global_position, global_position + dir * 190.0, 26.0, 0.8)
		_flash_warning()
		await _wait(0.8)
		if dead:
			return
		sprite.modulate = Color.WHITE
		dash_vel = dir * 270.0
		dash_t = 0.55
		dash_hit = false
		await _wait(0.65)
		if dead:
			return
	stagger_t = 1.2
	Game.float_text("Staggered!", global_position + Vector2(0, -20), Color(0.6, 1, 0.6))
	await _wait(0.6)


func _atk_summon():
	_tele_circle(global_position, 36.0, 0.9, Color(0.4, 1, 0.3))
	await _wait(0.9)
	if dead:
		return
	minions = minions.filter(func(m): return is_instance_valid(m))
	var n = 4 if enraged else 3
	for i in range(n):
		if minions.size() >= 6:
			break
		var pos = global_position + Vector2.RIGHT.rotated(TAU * i / n + randf()) * 42.0
		if Game.world.is_walkable(pos):
			minions.append(Game.world.spawn_mob(d["summon"].pick_random(), pos, maxi(1, level - 2)))
			Game.spawn_fx("wind", pos, {"tint": Color(0.5, 1, 0.4)})
	await _wait(0.6)


func _atk_slam():
	var r = 48.0
	var pos = global_position
	_tele_circle(pos, r, 0.9)
	_flash_warning()
	await _wait(0.9)
	if dead:
		return
	Game.spawn_fx("fire", pos)
	for i in range(6):
		Game.spawn_fx("earth", pos + Vector2.RIGHT.rotated(TAU * i / 6.0) * r * 0.7, {"tint": Color(0.9, 0.8, 0.6)})
	var p = Game.player
	if p.global_position.distance_to(pos) < r:
		_hurt(1.3, 200.0, pos)
	await _wait(0.5)


# ------------------------------------------------------------ ELDER TREANT
func _atk_roots():
	var n = 7 if enraged else 4
	var dur = 0.85 if enraged else 1.1
	var p = Game.player
	var centers = [p.global_position]
	for i in range(n - 1):
		centers.append(p.global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(25.0, 85.0))
	for c in centers:
		_tele_circle(c, 24.0, dur, Color(0.5, 0.9, 0.2))
	await _wait(dur)
	if dead:
		return
	for c in centers:
		Game.spawn_fx("earth", c, {"tint": Color(0.6, 1.0, 0.5)})
		if p.global_position.distance_to(c) < 24.0:
			_hurt(1.1, 160.0, c)
	await _wait(0.5)


func _atk_thorns():
	_tele_circle(global_position, 30.0, 0.6, Color(0.5, 1, 0.3))
	await _wait(0.6)
	var rounds = 2 if enraged else 1
	for r in range(rounds):
		if dead:
			return
		var off = randf() * TAU
		for i in range(12):
			var dir = Vector2.RIGHT.rotated(off + TAU * i / 12.0)
			Game.shoot({"position": global_position + Vector2(0, -14) + dir * 14.0, "kind": "thorn", "dir": dir,
				"speed": 115.0, "dmg": dmg * 0.8, "life": 2.2, "hostile": true, "lvl": level, "element": d["elem"], "magic": d["magic"]})
		await _wait(0.8)


func _atk_regrow():
	channel_dmg = 0.0
	sprite.modulate = Color(0.6, 1, 0.6)
	Game.float_text("Regrowing! Hit it hard!", global_position + Vector2(0, -20), Color(0.5, 1, 0.5))
	for i in range(8):
		if dead:
			return
		_tele_circle(global_position, 36.0, 0.25, Color(0.3, 1, 0.4))
		hp = minf(max_hp, hp + max_hp * 0.008)
		await _wait(0.25)
		if channel_dmg > max_hp * 0.07:
			stagger_t = 1.2
			Game.float_text("Interrupted!", global_position + Vector2(0, -20), Color(1, 0.9, 0.3))
			break


# ------------------------------------------------------------ STONE GOLEM
func _atk_boulders():
	var p = Game.player
	var dir = (p.global_position - global_position).normalized()
	var n = 5 if enraged else 3
	_tele_line(global_position, global_position + dir * 160.0, 20.0, 0.9)
	_flash_warning()
	await _wait(0.9)
	if dead:
		return
	for i in range(n):
		var a = dir.rotated((i - (n - 1) / 2.0) * 0.22)
		Game.shoot({"position": global_position + Vector2(0, -16) + a * 18.0, "kind": "boulder", "dir": a,
			"speed": 150.0, "dmg": dmg * 0.9, "life": 2.0, "hostile": true, "lvl": level, "element": d["elem"], "magic": d["magic"]})
	await _wait(0.6)


func _atk_shockwave():
	var count = 2 if enraged else 1
	for i in range(count):
		_tele_circle(global_position, 30.0, 0.8, Color(1, 0.7, 0.3))
		_flash_warning()
		await _wait(0.8)
		if dead:
			return
		rings.append({"pos": global_position, "r": 10.0, "speed": 120.0, "max": 175.0, "hit": false, "dmg": 1.1})
		Game.spawn_fx("earth", global_position, {"tint": Color(0.9, 0.8, 0.6)})
		await _wait(0.5)
	await _wait(0.8)


func _atk_leap():
	var p = Game.player
	var target = p.global_position
	_tele_circle(target, 40.0, 1.1)
	var tw = create_tween()
	tw.tween_property(sprite, "position:y", -110.0, 0.4)
	await _wait(0.9)
	if dead:
		return
	if Game.world.is_walkable(target):
		global_position = target
	await _wait(0.2)
	var tw2 = create_tween()
	tw2.tween_property(sprite, "position:y", -26.0, 0.12)
	await _wait(0.12)
	if dead:
		return
	Game.spawn_fx("fire", global_position)
	if p.global_position.distance_to(global_position) < 40.0:
		_hurt(1.4, 220.0)
	rings.append({"pos": global_position, "r": 8.0, "speed": 110.0, "max": 130.0 if not enraged else 170.0, "hit": false, "dmg": 0.8})
	stagger_t = 0.8
	await _wait(0.8)


# ------------------------------------------------------------ INFERNO / FUNGAL / SIREN
func _atk_breath():
	var p = Game.player
	var dir = (p.global_position - global_position).normalized()
	_tele_line(global_position, global_position + dir * 170.0, 60.0, 0.9, Color(1, 0.45, 0.1))
	_flash_warning()
	await _wait(0.9)
	if dead:
		return
	var bursts = 2 if enraged else 1
	for b in range(bursts):
		var n = 9 if enraged else 7
		for i in range(n):
			var a = dir.rotated((i - (n - 1) / 2.0) * 0.14)
			Game.shoot({"position": global_position + Vector2(0, -16) + a * 18.0, "kind": "fire", "dir": a, "speed": 170.0,
				"dmg": dmg * 0.7, "life": 1.3, "hostile": true, "lvl": level, "element": "fire", "magic": true,
				"status": [["burn", 3.0, 0.3]]})
		await _wait(0.4)
	await _wait(0.3)


func _atk_meteors():
	var p = Game.player
	var n = 8 if enraged else 5
	var centers = []
	for i in range(n):
		var c = p.global_position + Vector2.RIGHT.rotated(randf() * TAU) * (randf_range(0.0, 70.0) if i > 0 else 0.0)
		centers.append(c)
		_tele_circle(c, 26.0, 1.1 + i * 0.1, Color(1, 0.4, 0.1))
	await _wait(1.1)
	for i in range(n):
		if dead:
			return
		var c = centers[i]
		Game.spawn_fx("fire", c, {"scl": 0.8})
		Game.spawn_fx("earth", c, {"scl": 0.5})
		if Game.player.global_position.distance_to(c) < 26.0:
			_hurt(1.2, 200.0, c)
		await _wait(0.1)
	await _wait(0.4)


func _atk_tailspin():
	var r = 62.0
	_tele_circle(global_position, r, 0.9, Color(1, 0.35, 0.1))
	_flash_warning()
	await _wait(0.9)
	if dead:
		return
	Game.spawn_fx("spin", global_position, {"scl": 1.2, "tint": Color(1.0, 0.6, 0.4)})
	if Game.player.global_position.distance_to(global_position) < r:
		_hurt(1.5, 260.0)
	rings.append({"pos": global_position, "r": r, "speed": 90.0, "max": r + 70.0, "hit": false, "dmg": 0.7})
	await _wait(0.9)


func _atk_spores():
	_tele_circle(global_position, 32.0, 0.6, Color(0.7, 0.4, 1.0))
	await _wait(0.6)
	var rounds = 3 if enraged else 2
	for r in range(rounds):
		if dead:
			return
		var off = randf() * TAU
		for i in range(10):
			var dir = Vector2.RIGHT.rotated(off + TAU * i / 10.0)
			Game.shoot({"position": global_position + Vector2(0, -14) + dir * 14.0, "kind": "spore", "dir": dir,
				"speed": 100.0, "dmg": dmg * 0.7, "life": 2.4, "hostile": true, "lvl": level, "element": "dark", "magic": true,
				"status": [["poison", 4.0, 0.5]]})
		await _wait(0.9)


func _atk_waterfan():
	var p = Game.player
	var dir = (p.global_position - global_position).normalized()
	_tele_line(global_position, global_position + dir * 160.0, 50.0, 0.8, Color(0.3, 0.7, 1.0))
	await _wait(0.8)
	if dead:
		return
	for b in range(3 if enraged else 2):
		var n = 7
		for i in range(n):
			var a = dir.rotated((i - 3) * 0.16 + b * 0.05)
			Game.shoot({"position": global_position + Vector2(0, -16) + a * 18.0, "kind": "water", "dir": a, "speed": 160.0,
				"dmg": dmg * 0.65, "life": 1.5, "hostile": true, "lvl": level, "element": "water", "magic": true,
				"status": [["slow", 2.5, 0.35]]})
		await _wait(0.45)


func _atk_tidal():
	var count = 3 if enraged else 2
	for i in range(count):
		_tele_circle(global_position, 34.0, 0.7, Color(0.3, 0.7, 1.0))
		await _wait(0.7)
		if dead:
			return
		rings.append({"pos": global_position, "r": 10.0, "speed": 100.0, "max": 190.0, "hit": false, "dmg": 1.0})
		Game.spawn_fx("water", global_position, {"scl": 1.3})
		await _wait(0.9)


# ------------------------------------------------------------ helpers / statuses
func _hurt(mult, kb, from = null):
	var p = Game.player
	if p == null or p.dead:
		return
	var w = 1.0 - _pow("weak")
	p.take_damage(dmg * mult * w, global_position if from == null else from, kb, d["elem"], {"magic": d["magic"], "lvl": level})


func _pow(kind):
	var v = 0.0
	for s in statuses:
		if s[0] == kind:
			v = maxf(v, s[2])
	return v


func apply_statuses(list, dmg_hint):
	for st in list:
		var kind = st[0]
		if kind == "stun":
			continue
		var dur = st[1]
		var pw = st[2]
		if kind == "burn" or kind == "poison":
			pw = dmg_hint * pw / maxf(dur, 0.1)
			if dmg_hint <= 0.0:
				pw = max_hp * 0.002
		var found = false
		for s in statuses:
			if s[0] == kind:
				s[1] = maxf(s[1], dur)
				s[2] = maxf(s[2], pw)
				found = true
		if not found:
			statuses.append([kind, dur, pw])


func _tick_status(delta):
	dot_acc += delta
	var tick = dot_acc >= 0.5
	for s in statuses:
		s[1] -= delta
		if tick and (s[0] == "burn" or s[0] == "poison"):
			hp -= s[2] * 0.5
			Game.float_text(str(maxi(1, int(s[2] * 0.5))), global_position + Vector2(0, -16), Color(1, 0.55, 0.2), 7)
			if hp <= 0.0:
				_die()
				return
	if tick:
		dot_acc = 0.0
	statuses = statuses.filter(func(s): return s[1] > 0.0)


# ------------------------------------------------------------ damage / death
func _set_enraged(announce = true):
	enraged = true
	sprite.self_modulate = Color(1, 0.72, 0.72)
	if announce:
		Game.notify("%s is enraged!" % boss_name)


func take_damage(amount, _from_pos, _kb = 0.0, element = "", opts = {}):
	if dead:
		return
	Audio.sfx("hit", 0.9)
	var mult = Game.def_factor(defense, opts.get("lvl", 1))
	if element != "":
		mult *= 1.0 - float(d["res"].get(element, 0)) / 100.0
	if stagger_t > 0.0:
		mult *= 1.25
	mult *= 1.0 + _pow("vuln")
	var dm = maxf(1.0, amount * mult)
	hp -= dm
	channel_dmg += dm
	if not engaged:
		engaged = true
		Game.notify("%s awakens!" % boss_name)
	var col = Color(1, 0.9, 0.4)
	if opts.get("crit", false):
		col = Color(1.0, 0.55, 0.15)
	Game.float_text(str(int(round(dm))), global_position + Vector2(0, -16), col, 9 if opts.get("crit", false) else 8)
	var st = opts.get("status", [])
	if st.size() > 0:
		apply_statuses(st, dm)
	modulate = Color(1, 0.5, 0.5)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.15)
	if hp <= 0.0:
		_die()
	elif hp < max_hp * 0.5 and not enraged:
		_set_enraged()


func _die():
	Audio.sfx("boss_roar", 1.0, 0.7)
	if dead:
		return
	dead = true
	remove_from_group("hurtable")
	remove_from_group("bosses")
	telegraphs.clear()
	rings.clear()
	tele.queue_redraw()
	var p = Game.player
	var luck = p.stats["drop"] if p != null else 0.0
	var loot = []
	for id in d["mats"]:
		var rg = d["mats"][id]
		loot.append(Items.make(id, randi_range(rg[0], rg[1])))
	for i in range(2):
		loot.append(Items.roll_random_gear(level, maxi(2, Items.roll_rarity(luck * 0.5, 1.5 + diff)), luck, diff))
	Items.scatter(loot, global_position)
	if p != null:
		p.add_xp(d["xp"] * 4.0 * pow(float(level), 1.3))
		p.add_gold(int(20.0 * (3.0 + level * 2.2) * randf_range(0.8, 1.3)))
	Game.notify("%s has been defeated!" % boss_name)
	for m in minions:
		if is_instance_valid(m) and m.is_inside_tree():
			m.take_damage(99999.0, global_position, 0.0, "")
	for i in range(8):
		var kinds = ["fire", "earth", "wind"]
		Game.spawn_fx(kinds.pick_random(), global_position + Vector2(randf_range(-26, 26), randf_range(-30, 6)))
	Game.chips(global_position + Vector2(0, -20), Color(0.9, 0.8, 0.4), 16)
	if Game.main != null:
		Game.main.dungeon_boss_killed(self)
	var tw = create_tween()
	tw.tween_property(sprite, "modulate:a", 0.0, 1.2)
	tw.tween_callback(queue_free)
