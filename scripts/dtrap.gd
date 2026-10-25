extends Node2D
## Dungeon traps: bouncing boulder, poison gas vent, teleport rune, pit fall, falling boom.
## Set kind, level, rect (room in px, global), rooms (all room rects) before adding.

var kind = "boulder"
var level = 1
var rect = Rect2()
var rooms = []
var t = 0.0
var cd = 0.0
var vel = Vector2.ZERO
var rot = 0.0
var phase = 0.0
var fell = false
var boom_t = 2.0
var booms = []          # active falling bombs: [pos, time_left]
var gas_parts


func _ready():
	add_to_group("dnode")
	t = randf() * 4.0
	z_index = -1 if kind != "boulder" else 3
	if kind == "boulder":
		z_index = 3
		vel = Vector2.from_angle(randf() * TAU) * 78.0
	if kind == "gas":
		gas_parts = CPUParticles2D.new()
		gas_parts.emitting = false
		gas_parts.amount = 26
		gas_parts.lifetime = 1.6
		gas_parts.direction = Vector2(0, -1)
		gas_parts.spread = 180.0
		gas_parts.initial_velocity_min = 6.0
		gas_parts.initial_velocity_max = 20.0
		gas_parts.scale_amount_min = 3.0
		gas_parts.scale_amount_max = 6.0
		gas_parts.color = Color(0.45, 0.85, 0.3, 0.5)
		gas_parts.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		gas_parts.emission_sphere_radius = 18.0
		gas_parts.local_coords = false
		gas_parts.z_index = 4
		add_child(gas_parts)


func _hurt(frac, kb = 90.0, from = null, mult = 1.0):
	var p = Game.player
	p.take_damage((p.max_hp * frac + 6.0 * Game.mob_dmg_scale(level)) * mult, from if from != null else global_position, kb, "", {"lvl": level, "magic": false})


func _random_other_room():
	var best = []
	for r in rooms:
		if r != rect:
			best.append(r)
	if best.size() == 0:
		return null
	var r2 = best[randi() % best.size()]
	for i in range(12):
		var pos = r2.position + Vector2(randf_range(40.0, r2.size.x - 40.0), randf_range(40.0, r2.size.y - 40.0))
		if Game.dlayout.walkable(pos):
			return pos
	return r2.get_center()


func _process(delta):
	var p = Game.player
	t += delta
	cd = maxf(0.0, cd - delta)
	if p == null or p.dead or Game.dlayout == null:
		return
	match kind:
		"boulder":
			_boulder(delta, p)
		"gas":
			_gas(delta, p)
		"teleport":
			if cd <= 0.0 and p.global_position.distance_to(global_position) < 10.0:
				var dest = _random_other_room()
				if dest != null:
					cd = 4.0
					Game.spawn_fx("aura", global_position, {"scl": 0.6})
					Audio.sfx("teleport", 0.9)
					p.global_position = dest
					Game.main.cam.reset_smoothing()
					p.invuln = maxf(p.invuln, 1.0)
					Game.spawn_fx("aura", dest, {"scl": 0.6})
					Game.notify("A teleportation trap whisks you to another room!")
		"pit":
			if cd <= 0.0 and p.invuln <= 0.0 and p.global_position.distance_to(global_position) < 9.0:
				cd = 3.0
				fell = true
				Audio.sfx("hurt", 0.8, 0.6)
				Game.main.shake(3.0)
				var dest2 = _random_other_room()
				_hurt(0.10, 0.0)
				p.add_status("stun", 0.8, 0.0)
				if dest2 != null:
					p.global_position = dest2
					Game.main.cam.reset_smoothing()
				p.invuln = maxf(p.invuln, 1.2)
				Game.notify("You fall through the floor!")
		"boom":
			_boom(delta, p)
	queue_redraw()


func _boulder(delta, p):
	rot += vel.length() * delta * 0.15
	var np = global_position + vel * delta
	var rr = rect.grow(-14.0)
	if np.x < rr.position.x or np.x > rr.end.x:
		vel.x = -vel.x
		np = global_position + vel * delta
	if np.y < rr.position.y or np.y > rr.end.y:
		vel.y = -vel.y
		np = global_position + vel * delta
	global_position = np
	if cd <= 0.0 and p.global_position.distance_to(global_position + Vector2(0, -6)) < 12.0:
		cd = 1.0
		_hurt(0.09, 190.0)
		Game.main.shake(1.5)


func _gas(delta, p):
	var cyc = fmod(t, 6.0)
	var on = cyc > 3.0
	gas_parts.emitting = on
	phase = cyc
	if on and cd <= 0.0 and p.global_position.distance_to(global_position) < 32.0:
		cd = 0.6
		p.take_damage(p.max_hp * 0.012 + 2.0 * Game.mob_dmg_scale(level), global_position, 0.0, "", {"lvl": level, "magic": true})
		p.add_status("poison", 3.0, 0.5, p.max_hp * 0.02)


func _boom(delta, p):
	var inroom = rect.has_point(p.global_position)
	if inroom:
		boom_t -= delta
		if boom_t <= 0.0:
			boom_t = randf_range(1.8, 3.0)
			var target = p.global_position + Vector2(randf_range(-26, 26), randf_range(-20, 20))
			booms.append([target, 1.1])
			Game.telegraph(target, 26.0, 1.1, Color(1, 0.55, 0.1))
	for b in booms:
		b[1] -= delta
	for b in booms.duplicate():
		if b[1] <= 0.0:
			booms.erase(b)
			Game.spawn_fx("fire", b[0], {"scl": 0.9})
			Audio.sfx("magic_hit", 0.9, 0.6)
			Game.main.shake(2.0)
			if p.global_position.distance_to(b[0]) < 26.0:
				_hurt(0.13, 140.0, b[0])


func _draw():
	match kind:
		"boulder":
			draw_circle(Vector2(0, 2), 9, Color(0, 0, 0, 0.25))
			draw_circle(Vector2(0, -6), 10, Color(0.34, 0.31, 0.3))
			draw_circle(Vector2(-2, -8), 8, Color(0.5, 0.46, 0.44))
			draw_circle(Vector2(-4, -10), 3.5, Color(0.68, 0.64, 0.6))
			for i in range(3):
				var a = rot + i * 2.1
				draw_line(Vector2(0, -6) + Vector2.from_angle(a) * 2, Vector2(0, -6) + Vector2.from_angle(a) * 8, Color(0.2, 0.18, 0.18), 1.5)
			draw_arc(Vector2(0, -6), 10, 0, TAU, 20, Color(0.12, 0.1, 0.1), 1.5)
		"gas":
			var warn = phase > 2.0 and phase <= 3.0
			draw_circle(Vector2.ZERO, 5, Color(0.2, 0.28, 0.16))
			draw_circle(Vector2.ZERO, 3, Color(0.05, 0.08, 0.05))
			for i in range(4):
				draw_line(Vector2(-4 + i * 2.6, -1), Vector2(-4 + i * 2.6, 2), Color(0.12, 0.18, 0.1), 1)
			if warn:
				draw_circle(Vector2(0, -3), 4 + 2.0 * sin(t * 25.0), Color(0.5, 0.9, 0.3, 0.5))
			if phase > 3.0:
				draw_circle(Vector2.ZERO, 32, Color(0.4, 0.8, 0.25, 0.14))
				draw_arc(Vector2.ZERO, 32, 0, TAU, 30, Color(0.5, 0.9, 0.3, 0.45), 1.0)
		"teleport":
			var a = 0.55 + 0.35 * sin(t * 3.0)
			draw_circle(Vector2.ZERO, 9, Color(0.5, 0.25, 0.8, 0.18))
			draw_arc(Vector2.ZERO, 8, t, t + 4.5, 16, Color(0.8, 0.5, 1.0, a), 1.5)
			draw_arc(Vector2.ZERO, 5, -t * 1.3, -t * 1.3 + 4.0, 12, Color(0.9, 0.7, 1.0, a), 1.0)
			draw_circle(Vector2.ZERO, 1.5, Color(1, 0.9, 1, a))
		"pit":
			if fell or cd > 0.0:
				draw_circle(Vector2.ZERO, 8, Color(0.02, 0.02, 0.03))
				draw_arc(Vector2.ZERO, 8, 0, TAU, 20, Color(0.25, 0.2, 0.18), 1.5)
			else:
				# faintly cracked floor
				draw_line(Vector2(-6, -2), Vector2(-1, 0), Color(0, 0, 0, 0.35), 1)
				draw_line(Vector2(-1, 0), Vector2(2, -3), Color(0, 0, 0, 0.35), 1)
				draw_line(Vector2(-1, 0), Vector2(1, 4), Color(0, 0, 0, 0.35), 1)
				draw_line(Vector2(1, 4), Vector2(6, 3), Color(0, 0, 0, 0.35), 1)
		"boom":
			for b in booms:
				var k = 1.0 - clampf(b[1] / 1.1, 0.0, 1.0)
				var lp = to_local(b[0]) + Vector2(0, -90.0 * (1.0 - k) * (1.0 - k))
				draw_circle(lp + Vector2(0, 2), 5, Color(0, 0, 0, 0.3))
				draw_circle(lp, 5, Color(0.12, 0.12, 0.14))
				draw_circle(lp + Vector2(-1.5, -1.5), 2, Color(0.4, 0.4, 0.45))
				draw_line(lp + Vector2(2, -4), lp + Vector2(4, -8), Color(0.8, 0.6, 0.3), 1.5)
				draw_circle(lp + Vector2(4, -8), 1.5 + sin(t * 40.0) * 0.5, Color(1, 0.7, 0.2))
