extends CharacterBody2D
## Animals and monsters with levels. Set `type`, `level`, `mini` before adding to the tree.
## Abilities (d["abil"]): dash (pounce), slam (ground pound), ranged, breath (fire fan), poison (contact), drain (lifesteal).

var type = "slime"
var level = 1
var mini = false
var uid = -1              # dungeon mob id (for persistence), -1 = overworld
var diff = 0.0            # dungeon difficulty bonus
var d = {}
var hp = -1.0
var max_hp = 10.0
var dmg = 5.0
var defense = 5.0
var hit_radius = 7.0
var angry = false
var wander_t = 0.0
var wander_dir = Vector2.ZERO
var atk_cd = 0.0
var spec_cd = 3.0
var flee_t = 0.0
var statuses = []         # [kind, time_left, power]
var dot_acc = 0.0
var knock = Vector2.ZERO
var bar_t = 0.0
var trail_hp = 1.0
var t = 0.0
var state = "move"       # move / wind / dash / stunned_by_slam
var state_t = 0.0
var state_data = {}
var dash_vel = Vector2.ZERO
var dash_hit = false
var sprite
var base_scale = 1.0


func _ready():
	d = Game.MOBS[type]
	var lv = maxi(level, 1)
	var tier_hp = 4.5 if mini else 1.0
	max_hp = d["hp"] * Game.mob_hp_scale(lv) * tier_hp * (1.0 + diff * 0.3)
	if hp < 0.0:
		hp = max_hp
	dmg = d["dmg"] * Game.mob_dmg_scale(lv) * (1.4 if mini else 1.0) * (1.0 + diff * 0.15)
	defense = Game.mob_def(lv) * d["def"] * (1.5 if mini else 1.0)
	hit_radius = d["radius"] * (1.3 if mini else 1.0)
	add_to_group("hurtable")
	collision_layer = 2
	collision_mask = 1
	var cs = CollisionShape2D.new()
	var c = CircleShape2D.new()
	c.radius = 5.0
	cs.shape = c
	cs.position = Vector2(0, -3)
	add_child(cs)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Game.strip_frames(d["sheet"], d["fw"], d["fw"], 4, d["fps"], true)
	sprite.position = Vector2(0, -d["fw"] * 0.375)
	if mini:
		base_scale = 1.35
		sprite.scale = Vector2(base_scale, base_scale)
		sprite.modulate = Color(1.0, 0.88, 0.62)
	add_child(sprite)
	sprite.play("default")
	t = randf() * 10.0
	wander_t = randf() * 2.0
	spec_cd = randf_range(1.0, 4.0)


func _physics_process(delta):
	var p = Game.player
	if p == null:
		return
	var dist = global_position.distance_to(p.global_position)
	if dist > 450.0:
		return
	t += delta
	atk_cd = maxf(0.0, atk_cd - delta)
	spec_cd = maxf(0.0, spec_cd - delta)
	flee_t = maxf(0.0, flee_t - delta)
	bar_t = maxf(0.0, bar_t - delta)
	_tick_status(delta)
	if not is_inside_tree():
		return
	var stun = _has("stun")
	var slow = _pow("slow")
	var weak = _pow("weak")

	var dir = Vector2.ZERO
	var spd = d["speed"] * (1.0 - slow) * (1.15 if mini else 1.0)
	if stun:
		spd = 0.0
	elif state == "wind":
		state_t -= delta
		spd = 0.0
		if state_t <= 0.0:
			_finish_windup()
	elif state == "dash":
		state_t -= delta
		velocity = dash_vel
		if not dash_hit and not p.dead and dist < hit_radius + 6.0:
			dash_hit = true
			_hurt_player(1.3, 150.0)
		if state_t <= 0.0:
			state = "move"
			dash_vel = Vector2.ZERO
		_move(delta)
		return
	elif d["mode"] == "passive":
		if flee_t > 0.0 or (dist < 70.0 and not p.dead):
			dir = (global_position - p.global_position).normalized()
		else:
			dir = _wander(delta)
	else:
		var aggro = d["aggro"] * (1.4 if Game.is_night and Game.cur_dungeon == null else 1.0)
		if dist > 260.0:
			angry = false
		if not p.dead and (dist < aggro or angry):
			dir = _combat_dir(p, dist)
		else:
			dir = _wander(delta)
	if d["hop"]:
		spd *= 0.25 + absf(sin(t * 5.0)) * 1.2
	velocity = dir * spd + knock
	knock = knock.move_toward(Vector2.ZERO, 400.0 * delta)
	_move(delta)
	if absf(dir.x) > 0.05:
		sprite.flip_h = dir.x < 0.0
	sprite.speed_scale = 1.0 if (dir != Vector2.ZERO or d["hop"]) else 0.0
	queue_redraw()


func _move(delta):
	var stp = velocity * delta
	if not Game.world.is_walkable(global_position + Vector2(stp.x + signf(stp.x) * 4.0, 0)):
		velocity.x = 0
	if not Game.world.is_walkable(global_position + Vector2(0, stp.y + signf(stp.y) * 4.0)):
		velocity.y = 0
	move_and_slide()


func _combat_dir(p, dist):
	var abil = d["abil"]
	var to = (p.global_position - global_position).normalized()
	var reach = hit_radius + 7.0
	# specials
	if spec_cd <= 0.0 and not p.dead:
		if abil.has("ranged") and dist > 45.0 and dist < 150.0:
			_begin_windup("ranged", 0.45, to)
			return Vector2.ZERO
		if abil.has("breath") and dist < 130.0:
			_begin_windup("breath", 0.7, to)
			return Vector2.ZERO
		if abil.has("slam") and dist < 34.0:
			_begin_windup("slam", 0.65, to)
			return Vector2.ZERO
		if abil.has("dash") and dist > 40.0 and dist < 120.0:
			_begin_windup("dash", 0.4, to)
			return Vector2.ZERO
	# melee
	if dist < reach and atk_cd <= 0.0:
		_hurt_player(1.0, 90.0)
		atk_cd = 1.1
		knock = -to * 60.0
	if abil.has("ranged") and dist < 45.0:
		return -to          # kite
	if d.get("hop", false) == false and abil.has("ranged") and dist < 90.0:
		return Vector2.ZERO
	return to


func _begin_windup(kind, dur, to):
	state = "wind"
	state_t = dur
	state_data = {"kind": kind, "dir": to}
	if kind == "slam":
		Game.telegraph(global_position, 34.0, dur, Color(1, 0.3, 0.2))
	elif kind == "dash":
		sprite.modulate = Color(1.0, 0.6, 0.6)
	else:
		sprite.modulate = Color(1.0, 0.85, 0.5)


func _finish_windup():
	var kind = state_data.get("kind", "")
	var p = Game.player
	state = "move"
	sprite.modulate = Color(1.0, 0.88, 0.62) if mini else Color.WHITE
	if p == null:
		return
	var to = (p.global_position - global_position).normalized()
	var org = global_position + Vector2(0, -8)
	if kind == "ranged":
		_fire(org, to, 1.0)
		spec_cd = randf_range(2.0, 3.5)
	elif kind == "breath":
		for i in range(5):
			_fire(org, to.rotated((i - 2) * 0.2), 0.8)
		spec_cd = randf_range(3.5, 5.0)
	elif kind == "slam":
		Game.spawn_fx("earth", global_position, {"scl": 0.8})
		if p.global_position.distance_to(global_position) < 36.0:
			_hurt_player(1.5, 200.0)
		spec_cd = randf_range(3.0, 5.0)
	elif kind == "dash":
		state = "dash"
		state_t = 0.3
		dash_hit = false
		dash_vel = to * 230.0
		spec_cd = randf_range(2.5, 4.0)


func _fire(org, dir, mult):
	var w = 1.0 - _pow("weak")
	Game.shoot({"position": org + dir * 8.0, "dir": dir, "speed": 120.0, "kind": d.get("proj", "arcane"), "hostile": true,
		"dmg": dmg * mult * w, "magic": d["magic"], "element": d["elem"], "life": 2.0, "kb": 60.0, "lvl": level, "hit_fx": ""})


func _hurt_player(mult, kb):
	var p = Game.player
	if p == null or p.dead:
		return
	var st = []
	if d["abil"].has("poison"):
		st.append(["poison", 4.0, 0.5])
	var w = 1.0 - _pow("weak")
	var before = p.hp
	p.take_damage(dmg * mult * w, global_position, kb, d["elem"], {"magic": d["magic"], "lvl": level, "status": st})
	if d["abil"].has("drain") and p.hp < before:
		hp = minf(max_hp, hp + (before - p.hp) * 0.5)


func _wander(delta):
	wander_t -= delta
	if wander_t <= 0.0:
		wander_t = randf_range(1.5, 4.0)
		wander_dir = Vector2.RIGHT.rotated(randf() * TAU) if randf() < 0.6 else Vector2.ZERO
	return wander_dir * 0.5


# ------------------------------------------------------------------ status effects
func _has(kind):
	for s in statuses:
		if s[0] == kind:
			return true
	return false


func _pow(kind):
	var v = 0.0
	for s in statuses:
		if s[0] == kind:
			v = maxf(v, s[2])
	return v


func apply_statuses(list, dmg_hint):
	for st in list:
		var kind = st[0]
		var dur = st[1]
		var pw = st[2]
		if kind == "stun" and mini:
			dur *= 0.6
		if kind == "burn" or kind == "poison":
			pw = dmg_hint * pw / maxf(dur, 0.1)
			if dmg_hint <= 0.0:
				pw = max_hp * 0.01
		var found = false
		for s in statuses:
			if s[0] == kind:
				s[1] = maxf(s[1], dur)
				s[2] = maxf(s[2], pw)
				found = true
		if not found:
			statuses.append([kind, dur, pw])
	if list.size() > 0:
		queue_redraw()


func _tick_status(delta):
	dot_acc += delta
	var tick = dot_acc >= 0.5
	for s in statuses:
		s[1] -= delta
		if tick and (s[0] == "burn" or s[0] == "poison"):
			_dot(s[2] * 0.5, s[0])
			if not is_inside_tree():
				return
	if tick:
		dot_acc = 0.0
	statuses = statuses.filter(func(s): return s[1] > 0.0)


func _dot(amount, kind):
	hp -= amount
	Game.float_text(str(maxi(1, int(amount))), global_position, Color(1, 0.55, 0.2) if kind == "burn" else Color(0.6, 1, 0.4), 7)
	bar_t = 4.0
	if hp <= 0.0:
		_die()


func take_damage(amount, from_pos, kb = 80.0, element = "", opts = {}):
	if hp <= 0.0:
		return
	var lvl = opts.get("lvl", 1)
	var dm = amount * Game.def_factor(defense, lvl)
	if element != "":
		dm *= 1.0 - float(d["res"].get(element, 0)) / 100.0
	dm *= 1.0 + _pow("vuln")
	dm = maxf(1.0, dm)
	hp -= dm
	var crit = opts.get("crit", false)
	var col = Color(1, 0.9, 0.4) if not crit else Color(1.0, 0.55, 0.15)
	Game.float_text(str(int(round(dm))) + ("!" if crit else ""), global_position, col, 9 if crit else 8)
	Audio.sfx("crit" if crit else "hit", 0.8)
	if kb > 0.0 and not mini:
		knock = (global_position - from_pos).normalized() * kb
	elif kb > 0.0:
		knock = (global_position - from_pos).normalized() * kb * 0.4
	modulate = Color(1, 0.4, 0.4)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.2)
	bar_t = 4.0
	if d["mode"] == "passive":
		flee_t = 4.0
	else:
		angry = true
	var st = opts.get("status", [])
	if st.size() > 0:
		apply_statuses(st, dm)
	if hp <= 0.0:
		_die()


func _die():
	if is_in_group("dead"):
		return
	add_to_group("dead")
	Audio.sfx("enemy_die", 0.8)
	var p = Game.player
	var luck = 0.0
	var pl_level = 1
	if p != null:
		luck = p.stats["drop"]
		pl_level = p.level
	var loot = Items.roll_drops(type, level, mini, luck, diff)
	if mini:
		var g = Items.roll_random_gear(level, maxi(1, Items.roll_rarity(luck * 0.5, 0.6 + diff)), luck, diff)
		loot.append(g)
	Items.scatter(loot, global_position)
	Game.chips(global_position + Vector2(0, -8), Color(0.8, 0.2, 0.2), 8)
	if p != null:
		var xp = d["xp"] * 4.0 * pow(maxf(level, 1), 1.3) * (3.0 if mini else 1.0)
		if pl_level > level + 8:
			xp *= 0.3
		p.add_xp(xp)
		var gold = d["gold"] * (3.0 + level * 2.2) * randf_range(0.6, 1.4) * (5.0 if mini else 1.0)
		if gold >= 1.0:
			p.add_gold(int(gold))
	if p != null:
		p.quest_event("kill", type)
		if mini:
			p.quest_event("mini", "")
	if uid >= 0 and Game.main != null:
		Game.main.dungeon_mob_killed(uid)
	remove_from_group("hurtable")
	queue_free()


func _draw():
	var show = hp < max_hp and bar_t > 0.0
	if mini or show:
		var w = 22.0 if not mini else 30.0
		var bh = 4.0 if not mini else 5.0
		var top = -d["fw"] * (0.8 if not mini else 1.0) - 3.0
		var frac = clampf(hp / max_hp, 0.0, 1.0)
		trail_hp = maxf(frac, trail_hp - 0.012) if trail_hp > frac else frac
		var col = Color(0.35, 0.85, 0.3).lerp(Color(0.92, 0.2, 0.18), 1.0 - frac) if not mini else Color(1.0, 0.65, 0.15)
		draw_rect(Rect2(-w / 2.0 - 1, top - 1, w + 2, bh + 2), Color(0.02, 0.02, 0.05, 0.9))
		draw_rect(Rect2(-w / 2.0, top, w * trail_hp, bh), Color(1, 0.9, 0.6, 0.9))
		draw_rect(Rect2(-w / 2.0, top, w * frac, bh), col.darkened(0.35))
		draw_rect(Rect2(-w / 2.0, top, w * frac, ceilf(bh * 0.55)), col)
		draw_rect(Rect2(-w / 2.0, top, w * frac, 1), col.lightened(0.5))
		var font = ThemeDB.fallback_font
		var label = "Lv%d %s%s" % [level, "* " if mini else "", d["name"]]
		var sz = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 6)
		var lp = Vector2(-sz.x / 2.0, top - 3)
		draw_string(font, lp + Vector2(0.6, 0.6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(0, 0, 0, 0.9))
		draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(1, 0.85, 0.4) if mini else Color(1, 1, 1, 0.95))
	if _has("stun"):
		draw_string(ThemeDB.fallback_font, Vector2(-4, -d["fw"] - 2), "*", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 0.4))
