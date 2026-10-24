extends Node2D
## Arrows, bolts and monster missiles. Set the vars through Game.shoot({...}).
## Player projectiles roll damage on impact from "base"; hostile ones deal fixed "dmg" to the player.

var kind = "fire"
var dir = Vector2.RIGHT
var speed = 200.0
var base = 10.0
var magic = false
var element = ""
var status = []
var aoe = 0.0
var pierce = false
var life = 1.5
var kb = 80.0
var hit_fx = ""
var tint = Color.WHITE
var arrow = false
var force_crit = false
var heal = 0.0
var hit_set = []
var hostile = false
var dmg = 10.0
var lvl = 1
var healed = false


func _ready():
	z_index = 6
	rotation = dir.angle()
	var rng_kind = arrow or kind == "bullet"
	if rng_kind and not hostile:
		_make_trail()
	if arrow:
		var s = Sprite2D.new()
		s.texture = Game.tex("res://assets/items/arrow.png")
		s.scale = Vector2(1.25, 1.25)
		add_child(s)
		_make_glow(0.5 if element != "" else 0.3)
	elif kind == "bullet" and not hostile:
		var a = AnimatedSprite2D.new()
		a.sprite_frames = Game.proj_frames(kind)
		a.scale = Vector2(1.3, 1.0)
		add_child(a)
		a.play("default")
		_make_glow(0.45)
	else:
		var a = AnimatedSprite2D.new()
		a.sprite_frames = Game.proj_frames(kind)
		a.modulate = tint
		add_child(a)
		a.play("default")


var trail = null
var trail_pts = []
var sprite_glow = null


func _tint_color():
	if element != "" and Game.ELEM_COLOR.has(element):
		return Game.ELEM_COLOR[element]
	return Color(1, 0.95, 0.6) if kind == "bullet" else Color(0.95, 0.95, 0.85)


func _make_trail():
	trail = Line2D.new()
	trail.top_level = true
	trail.width = 3.0 if kind == "bullet" else 2.0
	trail.z_index = 5
	var gr = Gradient.new()
	var c = _tint_color()
	gr.set_color(0, Color(c.r, c.g, c.b, 0.0))
	gr.set_color(1, Color(c.r, c.g, c.b, 0.85))
	trail.gradient = gr
	var cv = Curve.new()
	cv.add_point(Vector2(0, 0.0))
	cv.add_point(Vector2(1, 1.0))
	trail.width_curve = cv
	add_child(trail)


func _make_glow(a):
	var g = Sprite2D.new()
	g.texture = Game.light_tex()
	g.scale = Vector2(0.2, 0.2)
	g.modulate = Color(_tint_color(), a)
	var m = CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = m
	add_child(g)


func _physics_process(delta):
	if trail != null:
		trail_pts.append(global_position)
		if trail_pts.size() > 9:
			trail_pts.pop_front()
		trail.clear_points()
		for tp in trail_pts:
			trail.add_point(tp)
	position += dir * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if Game.world.blocks_proj(global_position):
		_impact(null)
		return
	if hostile:
		var pl = Game.player
		if pl != null and not pl.dead and global_position.distance_to(pl.global_position + Vector2(0, -8)) < 8.0:
			pl.take_damage(dmg, global_position - dir * 10.0, kb, element, {"magic": magic, "lvl": lvl, "status": status})
			if hit_fx != "":
				Game.spawn_fx(hit_fx, global_position, {"scl": 0.7})
			queue_free()
		return
	for r in get_tree().get_nodes_in_group("resources"):
		if r.alive and r.coll > 0 and absf(r.global_position.x - global_position.x) < 12.0 and absf(r.global_position.y - global_position.y) < 14.0:
			if global_position.distance_to(r.global_position + Vector2(0, -6)) < r.radius:
				r.take_hit(Game.gather_power() * 0.8, Game.player)
				_impact(null)
				return
	for e in get_tree().get_nodes_in_group("hurtable"):
		if not is_instance_valid(e) or hit_set.has(e):
			continue
		if global_position.distance_to(e.global_position + Vector2(0, -8)) < e.hit_radius + 5.0:
			_impact(e)
			if pierce:
				hit_set.append(e)
			else:
				return


func _stick_ghost():
	var gs = Sprite2D.new()
	gs.texture = Game.tex("res://assets/items/arrow.png")
	gs.global_position = global_position + dir * 3.0
	gs.rotation = dir.angle()
	gs.z_index = 5
	Game.entities.add_child(gs)
	var tw = gs.create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(gs, "modulate:a", 0.0, 0.4)
	tw.tween_callback(gs.queue_free)


func _spark():
	var c = _tint_color()
	var pt = CPUParticles2D.new()
	pt.position = global_position
	pt.emitting = true
	pt.one_shot = true
	pt.explosiveness = 1.0
	pt.amount = 7
	pt.lifetime = 0.25
	pt.direction = -dir
	pt.spread = 60.0
	pt.initial_velocity_min = 40.0
	pt.initial_velocity_max = 90.0
	pt.damping_min = 80.0
	pt.damping_max = 120.0
	pt.scale_amount_min = 1.0
	pt.scale_amount_max = 1.8
	pt.color = c
	pt.z_index = 7
	Game.entities.add_child(pt)
	var tw = pt.create_tween()
	tw.tween_interval(0.5)
	tw.tween_callback(pt.queue_free)


func _impact(e):
	var pl = Game.player
	if not hostile and (arrow or kind == "bullet") and aoe <= 0.0:
		_spark()
		if arrow and e == null:
			_stick_ghost()
	if hostile:
		queue_free()
		return
	if aoe > 0.0:
		Game.area_attack(global_position, aoe, base, magic, element, kb, status, force_crit)
		Game.spawn_fx(hit_fx if hit_fx != "" else "fire", global_position, {"scl": maxf(aoe / 34.0, 0.6)})
	elif e != null:
		Game.hit(e, Game.roll_damage(pl, base, force_crit), global_position - dir * 10.0, kb, element, magic, status)
		if hit_fx != "":
			Game.spawn_fx(hit_fx, global_position, {"scl": 0.7})
	if e != null and heal > 0.0 and not healed:
		healed = true
		pl.heal(heal)
	if e == null or not pierce:
		queue_free()
