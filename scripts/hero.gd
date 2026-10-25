extends Node2D
## Real-world body of an adventurer NPC (see heroes.gd). Fights monsters near the player, rests in town.

var h = null
var mgr = null
var sprite
var lbl
var prompt
var target = null
var atk_cd = 0.0
var skill_cd = 5.0
var hit_cd = 1.0
var anim_t = 0.0
var face = "down"
var roam = Vector2.ZERO
var roam_t = 0.0
var stuck_t = 0.0
var last_pos = Vector2.ZERO
var bolt = null
var bolt_t = 0.0
const SPEED = 56.0


func _ready():
	position = Vector2(h["pos"][0], h["pos"][1])
	last_pos = position
	add_to_group("interact")
	add_to_group("hero")
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Game.char_frames(Game.CLASSES[h["cls"]]["sheet"])
	sprite.position = Vector2(0, -12)
	add_child(sprite)
	sprite.play("idle_down")
	lbl = Label.new()
	lbl.add_theme_font_size_override("font_size", 6)
	lbl.add_theme_color_override("font_color", mgr.CLS_COL[h["cls"]])
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.position = Vector2(-40, -42)
	lbl.custom_minimum_size = Vector2(80, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lbl)
	prompt = Label.new()
	prompt.text = "[T] Adventurer"
	prompt.add_theme_font_size_override("font_size", 7)
	prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt.add_theme_constant_override("outline_size", 3)
	prompt.position = Vector2(-28, -54)
	prompt.visible = false
	add_child(prompt)


func interact():
	Game.hud.open_hero(h["id"])


func _enemy_ok(e):
	return is_instance_valid(e) and not e.is_in_group("dead") and e.get("hp") != null and e.hp > 0.0 and e.get("type") != null and e.get("d") != null


func _find_target():
	var best = null
	var bd = 230.0
	for e in get_tree().get_nodes_in_group("hurtable"):
		if not _enemy_ok(e) or not (e is Node2D):
			continue
		if e.d["mode"] != "hostile" and not e.get("angry"):
			continue
		if mgr.in_town(e.global_position):
			continue
		var dd = global_position.distance_to(e.global_position)
		if dd < bd:
			bd = dd
			best = e
	return best


func _move(dir, delta, speed = SPEED):
	if dir.length() < 0.01:
		return false
	var stp = dir.normalized() * speed * delta
	var moved = false
	if Game.world.is_walkable(global_position + Vector2(stp.x + signf(stp.x) * 5.0, 0)):
		position.x += stp.x
		moved = true
	if Game.world.is_walkable(global_position + Vector2(0, stp.y + signf(stp.y) * 4.0)):
		position.y += stp.y
		moved = true
	if absf(dir.x) > absf(dir.y):
		face = "side"
		sprite.flip_h = dir.x < 0
	else:
		face = "down" if dir.y > 0 else "up"
		sprite.flip_h = false
	return moved


func _play(anim):
	var full = "%s_%s" % [anim, face]
	if sprite.animation != full or not sprite.is_playing():
		sprite.play(full)


func _physics_process(delta):
	if get_tree().paused or h == null:
		return
	anim_t = maxf(0.0, anim_t - delta)
	atk_cd -= delta
	skill_cd -= delta
	hit_cd -= delta
	bolt_t -= delta
	if bolt_t <= 0.0 and bolt != null:
		bolt = null
		queue_redraw()
	lbl.text = "%s  Lv %d" % [h["name"], h["level"]]
	var p = Game.player
	prompt.visible = global_position.distance_to(p.global_position) < 46.0 and not Game.hud.ui_open()
	match h["act"]:
		"hunt":
			if h["act_d"].get("leave", false):
				_leave_town(delta)
			else:
				_hunt(delta)
		"town":
			_idle_town(delta)
	h["pos"] = [position.x, position.y]
	# stuck detection
	stuck_t += delta
	if stuck_t > 1.2:
		if global_position.distance_to(last_pos) < 2.0 and target == null:
			roam_t = 0.0
		last_pos = global_position
		stuck_t = 0.0


func _leave_town(delta):
	var gate = mgr.town_center() + Vector2(0, 218.0)
	if global_position.distance_to(gate) < 16.0 or global_position.distance_to(mgr.town_center()) > 260.0:
		mgr.relocate_to_field(h)
		return
	# head for the south gate, then straight out
	var goal = gate
	if absf(global_position.x - gate.x) > 24.0 and global_position.y < gate.y - 30.0:
		goal = Vector2(gate.x, global_position.y + 24.0) if absf(global_position.x - gate.x) < 5.0 else Vector2(gate.x, global_position.y)
	_move(goal - global_position, delta)
	_play("walk")
	if stuck_t > 1.1 and global_position.distance_to(last_pos) < 2.0:
		mgr.relocate_to_field(h)


func _idle_town(delta):
	if roam_t <= 0.0 or global_position.distance_to(roam) < 6.0:
		var c = mgr.town_center()
		roam = c + Vector2(randf_range(-190, 190), randf_range(-150, 150))
		roam_t = randf_range(3.0, 7.0)
		if randf() < 0.5:
			roam = global_position
	roam_t -= delta
	var dir = roam - global_position
	if dir.length() > 6.0:
		_move(dir, delta, SPEED * 0.6)
		_play("walk")
	else:
		_play("idle")


func _hunt(delta):
	if target != null and not _enemy_ok(target):
		target = null
	if target == null:
		target = _find_target()
	var rng = mgr.CLS_RANGE[h["cls"]]
	if target == null:
		# wander in the area
		if roam_t <= 0.0 or global_position.distance_to(roam) < 6.0:
			roam = global_position + Vector2(randf_range(-110, 110), randf_range(-110, 110))
			roam_t = randf_range(2.0, 5.0)
		roam_t -= delta
		var dir = roam - global_position
		if dir.length() > 6.0:
			_move(dir, delta, SPEED * 0.8)
			_play("walk")
		else:
			_play("idle")
		return
	var dv = target.global_position - global_position
	var dist = dv.length()
	if dist > rng - 4.0:
		_move(dv, delta)
		if anim_t <= 0.0:
			_play("walk")
	else:
		if absf(dv.x) > absf(dv.y):
			face = "side"
			sprite.flip_h = dv.x < 0
		else:
			face = "down" if dv.y > 0 else "up"
			sprite.flip_h = false
		if anim_t <= 0.0:
			_play("idle")
	if dist <= rng + 2.0 and atk_cd <= 0.0:
		_attack()
	if dist <= 26.0 and hit_cd <= 0.0:
		_take_hit()
	_check_hp()


func _elem():
	return {"warrior": "", "ranger": "wind", "assassin": "dark", "mage": "fire", "priest": "light"}[h["cls"]]


func _attack():
	atk_cd = 0.9
	anim_t = 0.3
	_play("attack" if h["cls"] in ["warrior", "assassin", "ranger"] else "cast")
	var crit = randf() < 0.1
	var dm = mgr.dmg(h) * (1.8 if crit else 1.0)
	var el = _elem()
	if skill_cd <= 0.0 and h["skills"].size() > 0:
		skill_cd = randf_range(6.0, 9.0)
		var sk = Game.SKILLS[h["skills"][randi() % h["skills"].size()]]
		var fx = sk.get("elem", "fire")
		if not Game.FX.has(fx):
			fx = "slash"
		Game.spawn_fx(fx, target.global_position, {"scl": 1.2})
		Game.float_text(sk["name"], global_position + Vector2(0, -22), Color(1, 0.9, 0.5), 7)
		for e in get_tree().get_nodes_in_group("hurtable"):
			if _enemy_ok(e) and e.global_position.distance_to(target.global_position) < 56.0 and e.d["mode"] == "hostile":
				e.take_damage(dm * 2.4, global_position, 60.0, sk.get("elem", "") if sk.get("elem", "none") != "none" else "", {"lvl": h["level"], "npc": h["id"], "crit": true})
		return
	if h["cls"] in ["ranger", "mage", "priest"]:
		bolt = target.global_position - global_position
		bolt_t = 0.12
		queue_redraw()
	else:
		Game.spawn_fx("slash", target.global_position, {"scl": 0.7})
	target.take_damage(dm, global_position, 40.0, el, {"lvl": h["level"], "npc": h["id"], "crit": crit})


func _take_hit():
	hit_cd = 1.4
	if not _enemy_ok(target):
		return
	if randf() < 0.65:
		var d = target.d
		var dm = d["dmg"] * Game.mob_dmg_scale(target.level) * 0.5
		h["hp"] -= dm
		Game.float_text(str(int(dm)), global_position + Vector2(0, -16), Color(1, 0.4, 0.4), 6)
		sprite.modulate = Color(1, 0.5, 0.5)
		create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.2)
		mgr.hero_hurt(h)


func _check_hp():
	var mx = mgr.max_hp(h)
	if h["hp"] < mx * 0.35 and h["act"] == "hunt":
		if h["potions"] > 0:
			h["potions"] -= 1
			h["hp"] += mx * 0.5
			Game.float_text("+%d" % int(mx * 0.5), global_position + Vector2(0, -20), Color(0.4, 1, 0.5), 7)
			Game.spawn_fx("heal", global_position)
		else:
			mgr._recall(h)


func _draw():
	if bolt != null:
		draw_line(Vector2(0, -10), bolt + Vector2(0, -10), mgr.CLS_COL[h["cls"]], 1.5)
